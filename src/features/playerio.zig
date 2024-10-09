const std = @import("std");

const Feature = @import("Feature.zig");

const datamap = @import("datamap.zig");
const texthud = @import("texthud.zig");

const modules = @import("../modules.zig");
const tier1 = modules.tier1;
const ConVar = tier1.ConVar;
const engine = modules.engine;
const client = modules.client;

const sdk = @import("sdk");
const Vector = sdk.Vector;
const QAngle = sdk.QAngle;
const CUserCmd = sdk.CUserCmd;

pub const PlayerInfo = struct {
    position: Vector,
    angles: QAngle,
    velocity: Vector,
    surface_friction: f32,
    max_speed: f32,
    ducked: bool,
    grounded: bool,
    old_buttons: i32,
    tick_time: f32,
};

pub fn getPlayer(server: bool) ?*anyopaque {
    if (server) {
        return (engine.server.pEntityOfEntIndex(1) orelse {
            return null;
        }).getIServerEntity();
    }
    return client.entlist.getClientEntity(1);
}

pub fn getPlayerInfo(player: *anyopaque, cmd: *CUserCmd, player_field: PlayerField) PlayerInfo {
    const old_buttons = datamap.getField(c_int, player, player_field.m_nOldButtons).*;

    const index_mask = ((1 << 11) - 1);
    const in_jump = (1 << 1);
    var grounded = (datamap.getField(c_long, player, player_field.m_hGroundEntity).* & index_mask) != index_mask;
    if (grounded and (cmd.buttons & in_jump) == 1 and (old_buttons & in_jump) == 0) {
        grounded = false;
    }

    return PlayerInfo{
        .position = datamap.getField(Vector, player, player_field.m_vecAbsOrigin).*,
        .angles = engine.client.getViewAngles(),
        .velocity = datamap.getField(Vector, player, player_field.m_vecAbsVelocity).*,
        .surface_friction = datamap.getField(f32, player, player_field.m_surfaceFriction).*,
        .max_speed = datamap.getField(f32, player, player_field.m_flMaxspeed).*,
        .ducked = datamap.getField(bool, player, player_field.m_bDucked).*,
        .grounded = grounded,
        .old_buttons = old_buttons,
        .tick_time = 0.015,
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

pub var feature: Feature = .{
    .name = "playerio",
    .shouldLoad = shouldLoad,
    .init = init,
    .deinit = deinit,
};

pub var sv_friction: *ConVar = undefined;
pub var sv_stopspeed: *ConVar = undefined;
pub var sv_accelerate: *ConVar = undefined;
pub const portal_sv_airaccelerate = 15.0;

pub const PlayerField = struct {
    m_vecAbsOrigin: usize,
    m_vecAbsVelocity: usize,
    m_surfaceFriction: usize,
    m_flMaxspeed: usize,
    m_bDucked: usize,
    m_hGroundEntity: usize,
    m_nOldButtons: usize,
};

pub var server_player_field: PlayerField = undefined;
pub var client_player_field: PlayerField = undefined;

fn shouldLoad() bool {
    return datamap.feature.loaded;
}

fn init() bool {
    const _sv_friction = tier1.icvar.findVar("sv_friction");
    const _sv_stopspeed = tier1.icvar.findVar("sv_stopspeed");
    const _sv_accelerate = tier1.icvar.findVar("sv_accelerate");

    if (_sv_friction == null) {
        std.log.debug("sv_friction not found", .{});
    }
    if (_sv_stopspeed == null) {
        std.log.debug("sv_stopspeed not found", .{});
    }
    if (_sv_accelerate == null) {
        std.log.debug("sv_accelerate not found", .{});
    }

    if (_sv_friction == null or
        _sv_stopspeed == null or
        _sv_accelerate == null)
    {
        return false;
    }

    sv_friction = _sv_friction.?;
    sv_stopspeed = _sv_stopspeed.?;
    sv_accelerate = _sv_accelerate.?;

    if (datamap.server_map.get("CBasePlayer")) |map| {
        const m_vecAbsOrigin = map.get("m_vecAbsOrigin");
        const m_vecAbsVelocity = map.get("m_vecAbsVelocity");
        const m_flMaxspeed = map.get("m_flMaxspeed");
        const m_bDucked = map.get("m_Local.m_bDucked");
        const m_hGroundEntity = map.get("m_hGroundEntity");
        const m_nOldButtons = map.get("m_Local.m_nOldButtons");
        const m_bSinglePlayerGameEnding = map.get("m_bSinglePlayerGameEnding");
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
        if (m_nOldButtons == null) {
            std.log.debug("Cannot find CBasePlayer::m_Local.m_nOldButtons offset", .{});
        }
        if (m_bSinglePlayerGameEnding == null) {
            std.log.debug("Cannot find CBasePlayer::m_bSinglePlayerGameEnding offset", .{});
        }

        if (m_vecAbsOrigin == null or
            m_vecAbsVelocity == null or
            m_flMaxspeed == null or
            m_bDucked == null or
            m_hGroundEntity == null or
            m_nOldButtons == null or
            m_bSinglePlayerGameEnding == null)
        {
            return false;
        }

        server_player_field.m_vecAbsOrigin = m_vecAbsOrigin.?;
        server_player_field.m_vecAbsVelocity = m_vecAbsVelocity.?;
        server_player_field.m_flMaxspeed = m_flMaxspeed.?;
        server_player_field.m_bDucked = m_bDucked.?;
        server_player_field.m_hGroundEntity = m_hGroundEntity.?;
        server_player_field.m_nOldButtons = m_nOldButtons.?;
        server_player_field.m_surfaceFriction = (m_bSinglePlayerGameEnding.? & ~@as(usize, @intCast(3))) - 4;
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
        const m_nOldButtons = map.get("m_Local.m_nOldButtons");
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
        if (m_nOldButtons == null) {
            std.log.debug("Cannot find C_BasePlayer::m_Local.m_nOldButtons offset", .{});
        }
        if (m_surfaceFriction == null) {
            std.log.debug("Cannot find C_BasePlayer::m_surfaceFriction offset", .{});
        }

        if (m_vecAbsOrigin == null or
            m_vecAbsVelocity == null or
            m_flMaxspeed == null or
            m_bDucked == null or
            m_hGroundEntity == null or
            m_nOldButtons == null or
            m_surfaceFriction == null)
        {
            return false;
        }

        client_player_field.m_vecAbsOrigin = m_vecAbsOrigin.?;
        client_player_field.m_vecAbsVelocity = m_vecAbsVelocity.?;
        client_player_field.m_flMaxspeed = m_flMaxspeed.?;
        client_player_field.m_bDucked = m_bDucked.?;
        client_player_field.m_hGroundEntity = m_hGroundEntity.?;
        client_player_field.m_nOldButtons = m_nOldButtons.?;
        client_player_field.m_surfaceFriction = m_surfaceFriction.?;
    } else {
        std.log.debug("Cannot find C_BasePlayer datamap", .{});
        return false;
    }

    PosTextHUD.register();

    return true;
}

fn deinit() void {}
