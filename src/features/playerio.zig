const std = @import("std");

const Feature = @import("Feature.zig");

const datamap = @import("datamap.zig");
const texthud = @import("texthud.zig");

const event = @import("../event.zig");
const game_detection = @import("../utils/game_detection.zig");

const modules = @import("../modules.zig");
const tier1 = modules.tier1;
const ConVar = tier1.ConVar;
const engine = modules.engine;
const client = modules.client;
const server = modules.server;

const sdk = @import("sdk");
const Vector = sdk.Vector;
const QAngle = sdk.QAngle;
const CUserCmd = sdk.CUserCmd;

pub const PlayerInfo = struct {
    position: Vector = .{},
    angles: QAngle = .{},
    velocity: Vector = .{},
    ducked: bool = false,
    grounded: bool = false,
    entity_friction: f32 = 0.0,

    tick_time: f32 = 0.015,

    // ConVars
    accelerate: f32 = 0.0,
    airaccelerate: f32 = 0.0,
    friction: f32 = 0.0,
    maxspeed: f32 = 0.0,
    stopspeed: f32 = 0.0,
};

pub fn getPlayer(is_server: bool) ?*anyopaque {
    if (is_server) {
        return (engine.server.pEntityOfEntIndex(1) orelse {
            return null;
        }).getIServerEntity();
    }
    return client.entlist.getClientEntity(1);
}

pub const PlayerField = struct {
    m_vecAbsOrigin: usize,
    m_vecAbsVelocity: usize,
    m_surfaceFriction: usize,
    m_flMaxspeed: usize,
    m_bDucked: usize,
    m_hGroundEntity: usize,

    m_vecPreviouslyPredictedOrigin: usize = 0, // server-only
};

var server_player_field: PlayerField = undefined;
var client_player_field: PlayerField = undefined;

pub fn getPlayerField(is_server: bool) *const PlayerField {
    return if (is_server) &server_player_field else &client_player_field;
}

pub fn getPlayerInfo(player: *anyopaque, is_server: bool) PlayerInfo {
    const player_field: *const PlayerField = getPlayerField(is_server);

    // Basic player info
    const position = datamap.getField(Vector, player, player_field.m_vecAbsOrigin).*;
    const angles = engine.client.getViewAngles();
    const velocity = datamap.getField(Vector, player, player_field.m_vecAbsVelocity).*;

    const ducked = datamap.getField(bool, player, player_field.m_bDucked).*;

    // Gournded
    const index_mask = ((1 << 11) - 1);
    const grounded = (datamap.getField(c_long, player, player_field.m_hGroundEntity).* & index_mask) != index_mask;

    // Entity friction
    var entity_friction = datamap.getField(f32, player, player_field.m_surfaceFriction).*;
    if (is_server) {
        const previously_predicted_origin = datamap.getField(Vector, player, player_field.m_vecPreviouslyPredictedOrigin).*;
        if (!Vector.eql(position, previously_predicted_origin)) {
            if (velocity.z <= 140.0) {
                if (grounded) {
                    entity_friction = 1.0;
                } else if (velocity.z > 0.0) {
                    entity_friction = 0.25;
                }
            }
        }
    }

    // ConVars
    const accelerate = sv_accelerate.getFloat();
    const airaccelerate = if (game_detection.doesGameLooksLikePortal()) 15 else sv_airaccelerate.getFloat();
    const friction = sv_friction.getFloat();
    var maxspeed = datamap.getField(f32, player, player_field.m_flMaxspeed).*;
    maxspeed = if (maxspeed > 0) @min(maxspeed, sv_maxspeed.getFloat()) else sv_maxspeed.getFloat();
    const stopspeed = sv_stopspeed.getFloat();

    return PlayerInfo{
        .position = position,
        .angles = angles,
        .velocity = velocity,
        .ducked = ducked,
        .grounded = grounded,
        .entity_friction = entity_friction,

        .tick_time = 0.015,

        .accelerate = accelerate,
        .airaccelerate = airaccelerate,
        .friction = friction,
        .maxspeed = maxspeed,
        .stopspeed = stopspeed,
    };
}

const PosTextHUD = struct {
    var cl_showpos: ?*ConVar = null;

    fn shouldDraw() bool {
        if (cl_showpos == null) {
            cl_showpos = tier1.icvar.findVar("cl_showpos");
        }

        if (cl_showpos) |v| {
            return v.getBool();
        }

        return false;
    }

    fn paint() void {
        var origin: Vector = client.mainViewOrigin().*;
        var angles: QAngle = client.mainViewAngles().*;
        var vel: Vector = .{};

        const player = getPlayer(false);
        if (player) |p| {
            vel = datamap.getField(Vector, p, client_player_field.m_vecAbsVelocity).*;
            if (cl_showpos.?.getInt() == 2) {
                origin = datamap.getField(Vector, p, client_player_field.m_vecAbsOrigin).*;
                angles = engine.client.getViewAngles();
            }
        }
        texthud.drawTextHUD("pos:  {d:.2} {d:.2} {d:.2}", .{ origin.x, origin.y, origin.z });
        texthud.drawTextHUD("ang:  {d:.2} {d:.2} {d:.2}", .{ angles.x, angles.y, angles.z });
        texthud.drawTextHUD("vel:  {d:.2}", .{vel.getlength2D()});
    }

    fn register() void {
        texthud.addHUDElement(.{
            .shouldDraw = shouldDraw,
            .paint = paint,
        });
    }
};

var pod_hud_vars = tier1.Variable.init(.{
    .name = "pod_hud_vars",
    .help_string = "Show player movement variables.",
    .default_value = "0",
});

const PlayerioTextHUD = struct {
    var player_info: PlayerInfo = .{};

    fn onCreateMove(is_server: bool, cmd: *CUserCmd) void {
        _ = cmd;
        const player = getPlayer(is_server) orelse return;
        player_info = getPlayerInfo(player, is_server);
    }

    fn shouldDraw() bool {
        return pod_hud_vars.getBool();
    }

    fn paint() void {
        texthud.drawTextHUD("ducked: {s}", .{if (player_info.ducked) "true" else "false"});
        texthud.drawTextHUD("grounded: {s}", .{if (player_info.grounded) "true" else "false"});
        texthud.drawTextHUD("entity friction: {d:.2}", .{player_info.entity_friction});
        texthud.drawTextHUD("accelerate: {d:.2}", .{player_info.accelerate});
        texthud.drawTextHUD("airaccelerate: {d:.2}", .{player_info.airaccelerate});
        texthud.drawTextHUD("friction: {d:.2}", .{player_info.friction});
        texthud.drawTextHUD("maxspeed: {d:.2}", .{player_info.maxspeed});
        texthud.drawTextHUD("stopspeed: {d:.2}", .{player_info.stopspeed});
    }

    fn register() void {
        if (event.create_move.works) {
            event.create_move.connect(onCreateMove);
            pod_hud_vars.register();
            texthud.addHUDElement(.{
                .shouldDraw = shouldDraw,
                .paint = paint,
            });
        }
    }
};

pub var feature: Feature = .{
    .name = "playerio",
    .shouldLoad = shouldLoad,
    .init = init,
    .deinit = deinit,
};

var sv_friction: *ConVar = undefined;
var sv_maxspeed: *ConVar = undefined;
var sv_stopspeed: *ConVar = undefined;
var sv_accelerate: *ConVar = undefined;
var sv_airaccelerate: *ConVar = undefined;

fn shouldLoad() bool {
    return datamap.feature.loaded;
}

fn init() bool {
    sv_friction = tier1.icvar.findVar("sv_friction") orelse return false;
    sv_maxspeed = tier1.icvar.findVar("sv_maxspeed") orelse return false;
    sv_stopspeed = tier1.icvar.findVar("sv_stopspeed") orelse return false;
    sv_accelerate = tier1.icvar.findVar("sv_accelerate") orelse return false;
    sv_airaccelerate = tier1.icvar.findVar("sv_airaccelerate") orelse return false;

    if (datamap.server_map.get("CBasePlayer")) |map| {
        const m_vecAbsOrigin = map.get("m_vecAbsOrigin");
        const m_vecAbsVelocity = map.get("m_vecAbsVelocity");
        const m_flMaxspeed = map.get("m_flMaxspeed");
        const m_bDucked = map.get("m_Local.m_bDucked");
        const m_hGroundEntity = map.get("m_hGroundEntity");
        const m_bSinglePlayerGameEnding = map.get("m_bSinglePlayerGameEnding");
        const m_vecPreviouslyPredictedOrigin = map.get("m_vecPreviouslyPredictedOrigin");
        if (m_vecAbsOrigin == null) {
            std.log.debug("Cannot find CBasePlayer::m_vecAbsOrigin offset", .{});
        }
        if (m_vecAbsVelocity == null) {
            std.log.debug("Cannot find CBasePlayer::m_vecAbsVelocity offset", .{});
        }
        if (m_flMaxspeed == null) {
            std.log.debug("Cannot find CBasePlayer::m_flMaxspeed offset", .{});
        }
        if (m_bDucked == null) {
            std.log.debug("Cannot find CBasePlayer::m_Local.m_bDucked offset", .{});
        }
        if (m_hGroundEntity == null) {
            std.log.debug("Cannot find CBasePlayer::m_hGroundEntity offset", .{});
        }
        if (m_bSinglePlayerGameEnding == null) {
            std.log.debug("Cannot find CBasePlayer::m_bSinglePlayerGameEnding offset", .{});
        }
        if (m_vecPreviouslyPredictedOrigin == null) {
            std.log.debug("Cannot find CBasePlayer::m_vecPreviouslyPredictedOrigin offset", .{});
        }

        if (m_vecAbsOrigin == null or
            m_vecAbsVelocity == null or
            m_flMaxspeed == null or
            m_bDucked == null or
            m_hGroundEntity == null or
            m_bSinglePlayerGameEnding == null or
            m_vecPreviouslyPredictedOrigin == null)
        {
            return false;
        }

        server_player_field.m_vecAbsOrigin = m_vecAbsOrigin.?;
        server_player_field.m_vecAbsVelocity = m_vecAbsVelocity.?;
        server_player_field.m_flMaxspeed = m_flMaxspeed.?;
        server_player_field.m_bDucked = m_bDucked.?;
        server_player_field.m_hGroundEntity = m_hGroundEntity.?;
        server_player_field.m_surfaceFriction = (m_bSinglePlayerGameEnding.? & ~@as(usize, @intCast(3))) - 4;
        server_player_field.m_vecPreviouslyPredictedOrigin = m_vecPreviouslyPredictedOrigin.?;
    } else {
        std.log.debug("Cannot find CBasePlayer datamap", .{});
        return false;
    }

    if (datamap.client_map.get("C_BasePlayer")) |map| {
        const m_vecAbsOrigin = map.get("m_vecAbsOrigin");
        const m_vecAbsVelocity = map.get("m_vecAbsVelocity");
        const m_flMaxspeed = map.get("m_flMaxspeed");
        const m_bDucked = map.get("m_Local.m_bDucked");
        const m_hGroundEntity = map.get("m_hGroundEntity");
        const m_surfaceFriction = map.get("m_surfaceFriction");
        if (m_vecAbsOrigin == null) {
            std.log.debug("Cannot find C_BasePlayer::m_vecAbsOrigin offset", .{});
        }
        if (m_vecAbsVelocity == null) {
            std.log.debug("Cannot find C_BasePlayer::m_vecAbsVelocity offset", .{});
        }
        if (m_flMaxspeed == null) {
            std.log.debug("Cannot find C_BasePlayer::m_flMaxspeed offset", .{});
        }
        if (m_bDucked == null) {
            std.log.debug("Cannot find C_BasePlayer::m_Local.m_bDucked offset", .{});
        }
        if (m_hGroundEntity == null) {
            std.log.debug("Cannot find C_BasePlayer::m_hGroundEntity offset", .{});
        }
        if (m_surfaceFriction == null) {
            std.log.debug("Cannot find C_BasePlayer::m_surfaceFriction offset", .{});
        }

        if (m_vecAbsOrigin == null or
            m_vecAbsVelocity == null or
            m_flMaxspeed == null or
            m_bDucked == null or
            m_hGroundEntity == null or
            m_surfaceFriction == null)
        {
            return false;
        }

        client_player_field.m_vecAbsOrigin = m_vecAbsOrigin.?;
        client_player_field.m_vecAbsVelocity = m_vecAbsVelocity.?;
        client_player_field.m_flMaxspeed = m_flMaxspeed.?;
        client_player_field.m_bDucked = m_bDucked.?;
        client_player_field.m_hGroundEntity = m_hGroundEntity.?;
        client_player_field.m_surfaceFriction = m_surfaceFriction.?;
    } else {
        std.log.debug("Cannot find C_BasePlayer datamap", .{});
        return false;
    }

    PosTextHUD.register();

    if (event.create_move.works) {
        PlayerioTextHUD.register();
    }

    return true;
}

fn deinit() void {}
