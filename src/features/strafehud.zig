const std = @import("std");

const modules = @import("../modules.zig");
const tier0 = modules.tier0;
const tier1 = modules.tier1;
const ConVar = tier1.ConVar;
const engine = modules.engine;
const client = modules.client;
const vgui = modules.vgui;

const playerio = @import("playerio.zig");
const PlayerInfo = playerio.PlayerInfo;

const sdk = @import("sdk");
const Vector = sdk.Vector;
const Color = sdk.Color;
const CUserCmd = sdk.CUserCmd;

const event = @import("../event.zig");
const strafe = @import("../utils/strafe.zig");
const ent_utils = @import("../utils/ent_utils.zig");

const Feature = @import("Feature.zig");

pub var feature: Feature = .{
    .name = "strafe",
    .shouldLoad = shouldLoad,
    .init = init,
    .deinit = deinit,
};

var pod_strafehud = tier1.Variable.init(.{
    .name = "pod_strafehud",
    .help_string = "Draw the strafe HUD.",
    .default_value = "0",
});

var pod_strafehud_x = tier1.Variable.init(.{
    .name = "pod_strafehud_x",
    .help_string = "The X position for the strafe HUD.",
    .default_value = "-10",
});

var pod_strafehud_y = tier1.Variable.init(.{
    .name = "pod_strafehud_y",
    .help_string = "The Y position for the strafe HUD.",
    .default_value = "-10",
});

var pod_strafehud_size = tier1.Variable.init(.{
    .name = "pod_strafehud_size",
    .help_string = "The width and height of the strafe HUD.",
    .default_value = "256",
    .min_value = 1,
});

var pod_strafehud_detial_scale = tier1.Variable.init(.{
    .name = "pod_strafehud_detial_scale",
    .help_string = "The detail scale for the lines of the strafe HUD.",
    .default_value = "4",
    .min_value = 0,
    .max_value = 64,
});

var pod_strafehud_match_accel_scale = tier1.Variable.init(.{
    .name = "pod_strafehud_match_accel_scale",
    .help_string = "Match the scales for minimum and maximum deceleration.",
    .default_value = "0",
});

var pod_strafehud_lock_mode = tier1.Variable.init(.{
    .name = "pod_strafehud_lock_mode",
    .help_string =
    \\Lock mode used by the strafe HUD:
    \\0 - view direction
    \\1 - velocity direction
    \\2 - absolute angles
    ,
    .default_value = "1",
    .min_value = 0,
    .max_value = 2,
});

var wish_dir: Vector = undefined;
var accel_values: std.ArrayList(f32) = undefined;

fn onCreateMove(is_server: bool, cmd: *CUserCmd) void {
    if (!pod_strafehud.getBool()) {
        return;
    }
    const player = ent_utils.getPlayer(is_server) orelse {
        return;
    };

    const player_info = playerio.getPlayerInfo(player, is_server);

    setData(&player_info, cmd);
}

fn setData(player: *const PlayerInfo, cmd: *CUserCmd) void {
    const old_vel = strafe.getGroundFrictionVelocity(player).getlength2D();

    const best_ang = strafe.getFastestStrafeAngle(player);
    var biggest_accel = strafe.getVelocityAfterMove(player, @cos(best_ang), @sin(best_ang)).getlength2D() - old_vel;
    var smallest_accel: f32 = 0.0;

    var rel_ang: f32 = 0.0;
    const lock_mode = pod_strafehud_lock_mode.getInt();
    if (lock_mode > 0) {
        const vel_ang = strafe.getVelocityAngles(player).x;
        const look_ang = player.angles.y;

        rel_ang += look_ang;
        if (lock_mode == 1) {
            rel_ang -= vel_ang;
        }
        rel_ang = std.math.degreesToRadians(rel_ang);
    }

    const speed = cmd.forward_move * cmd.forward_move +
        cmd.side_move * cmd.side_move +
        cmd.up_move * cmd.up_move;
    if (speed > player.maxspeed * player.maxspeed) {
        const ratio = player.maxspeed / @sqrt(speed);
        cmd.forward_move *= ratio;
        cmd.side_move *= ratio;
        cmd.up_move *= ratio;
    }

    wish_dir = .{
        .x = @cos(rel_ang) * cmd.side_move - @sin(rel_ang) * cmd.forward_move,
        .y = @sin(rel_ang) * cmd.side_move + @cos(rel_ang) * cmd.forward_move,
    };

    if (wish_dir.getlength2D() > 1.0) {
        wish_dir = wish_dir.normalize();
    }

    const detail: usize = @intFromFloat(@as(f32, @floatFromInt(pod_strafehud_size.getInt())) * pod_strafehud_detial_scale.getFloat());
    accel_values.resize(detail) catch return;

    var i: usize = 0;
    while (i < detail) : (i += 1) {
        const ang = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(detail)) * 2.0 * std.math.pi + rel_ang;
        const new_vel = strafe.getVelocityAfterMove(player, @cos(ang), @sin(ang)).getlength2D();
        const accel = new_vel - old_vel;
        accel_values.items[i] = accel;

        if (accel > biggest_accel) {
            biggest_accel = accel;
        }
        if (i == 0 or accel < smallest_accel) {
            smallest_accel = accel;
        }
    }

    if (pod_strafehud_match_accel_scale.getBool()) {
        const max: f32 = @max(biggest_accel, @abs(smallest_accel));
        smallest_accel = -max;
        biggest_accel = max;
    }

    for (accel_values.items) |*accel| {
        if (accel.* > 0 and biggest_accel > 0) {
            accel.* /= biggest_accel;
        }
        if (accel.* < 0 and smallest_accel < 0) {
            accel.* /= -smallest_accel;
        }
    }
}

fn onPaint() void {
    if (!pod_strafehud.getBool() or !engine.client.isInGame()) {
        return;
    }

    const screen = vgui.imatsystem.getScreenSize();
    const pad = 5;
    var size = pod_strafehud_size.getInt();
    var x: i32 = pod_strafehud_x.getInt();
    var y: i32 = pod_strafehud_y.getInt();

    if (x < 0) {
        x += screen.wide - size;
    }
    if (y < 0) {
        y += screen.tall - size;
    }

    const bg_color: Color = .{
        .r = 0,
        .g = 0,
        .b = 0,
        .a = 192,
    };
    const lines_color: Color = .{
        .r = 64,
        .g = 64,
        .b = 64,
    };
    const wish_dir_color: Color = .{
        .r = 0,
        .g = 0,
        .b = 255,
    };
    const accel_color: Color = .{
        .r = 0,
        .g = 255,
        .b = 0,
    };
    const decel_color: Color = .{
        .r = 255,
        .g = 0,
        .b = 0,
    };
    const nocel_color: Color = .{
        .r = 255,
        .g = 255,
        .b = 0,
    };

    vgui.imatsystem.drawSetColor(bg_color);
    vgui.imatsystem.drawFilledRect(x, y, x + size, y + size);
    x += pad;
    y += pad;
    size -= pad * 2;

    const mid_x = x + @divFloor(size, 2);
    const mid_y = y + @divFloor(size, 2);

    const dx = @as(f32, @floatFromInt(size)) * 0.5;
    const dy = @as(f32, @floatFromInt(size)) * 0.5;

    vgui.imatsystem.drawSetColor(lines_color);
    // Containing rect
    vgui.imatsystem.drawOutlinedRect(x, y, x + size, y + size);

    // Circles
    vgui.imatsystem.drawOutlinedCircle(mid_x, mid_y, @divFloor(size, 2), 32);
    vgui.imatsystem.drawOutlinedCircle(mid_x, mid_y, @divFloor(size, 4), 32);

    // Half-lines and diagonals
    vgui.imatsystem.drawLine(mid_x, y, mid_x, y + size);
    vgui.imatsystem.drawLine(x, mid_y, x + size, mid_y);
    vgui.imatsystem.drawLine(x, y, x + size, y + size);
    vgui.imatsystem.drawLine(x, y + size, x + size, y);

    // Acceleration line
    const detail: f32 = @floatFromInt(accel_values.items.len);
    for (accel_values.items, 0..) |accel, i| {
        const ang1 = (@as(f32, @floatFromInt(i)) / detail) * 2.0 * std.math.pi;
        const i_2 = if (i + 1 >= accel_values.items.len) 0 else i + 1;
        const ang2 = (@as(f32, @floatFromInt(i_2)) / detail) * 2.0 * std.math.pi;

        const a1 = @min(@max(accel, -1.0), 1.0);
        const a2 = @min(@max(accel_values.items[i_2], -1.0), 1.0);

        const ad1 = (a1 + 1.0) * 0.5;
        const ad2 = (a2 + 1.0) * 0.5;
        var line_color = nocel_color;
        if ((ad1 != 0 and ad2 != 0) and a1 * a2 > 0) {
            line_color = if (a1 >= 0.0) accel_color else decel_color;
        }

        vgui.imatsystem.drawSetColor(line_color);
        vgui.imatsystem.drawLine(
            mid_x + @as(i32, @intFromFloat(@sin(ang1) * dx * ad1)),
            mid_y - @as(i32, @intFromFloat(@cos(ang1) * dy * ad1)),
            mid_x + @as(i32, @intFromFloat(@sin(ang2) * dx * ad2)),
            mid_y - @as(i32, @intFromFloat(@cos(ang2) * dy * ad2)),
        );
    }

    // Wish dir
    vgui.imatsystem.drawSetColor(wish_dir_color);

    const x0 = mid_x;
    const y0 = mid_y;
    const x1 = mid_x + @as(i32, @intFromFloat(wish_dir.x * dx));
    const y1 = mid_y - @as(i32, @intFromFloat(wish_dir.y * dy));

    const half_thickness = 1;

    const slope = @as(f32, @floatFromInt(y1 - y0)) / @as(f32, @floatFromInt(x1 - x0));
    if (@abs(slope) <= 1) {
        var i: i32 = -half_thickness;
        while (i <= half_thickness) : (i += 1) {
            vgui.imatsystem.drawLine(x0, y0 + i, x1, y1 + i);
        }
    } else {
        var i: i32 = -half_thickness;
        while (i <= half_thickness) : (i += 1) {
            vgui.imatsystem.drawLine(x0 + i, y0, x1 + i, y1);
        }
    }
}

fn shouldLoad() bool {
    return playerio.feature.loaded and
        event.paint.works and
        event.create_move.works;
}

fn init() bool {
    accel_values = std.ArrayList(f32).init(tier0.allocator);

    event.create_move.connect(onCreateMove);
    event.paint.connect(onPaint);

    pod_strafehud.register();
    pod_strafehud_x.register();
    pod_strafehud_y.register();
    pod_strafehud_size.register();
    pod_strafehud_detial_scale.register();
    pod_strafehud_match_accel_scale.register();
    pod_strafehud_lock_mode.register();

    return true;
}

fn deinit() void {
    accel_values.deinit();
}
