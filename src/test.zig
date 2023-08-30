const std = @import("std");

const modules = @import("modules.zig");
const convar = @import("convar.zig");
const hud = @import("hud.zig");
const engine = @import("engine.zig");
const datamap = @import("datamap.zig");

pub var feature = modules.Feature{
    .init = init,
    .deinit = deinit,
    .onPaint = onPaint,
};

var datamap_print = convar.ConCommand{
    .base = .{
        .name = "datamap_print",
        .help_str = "Print datamap",
    },
    .command_callback = datamap_print_Fn,
};

const Vector = struct {
    x: f32,
    y: f32,
    z: f32,
};

const PlayerFields = struct {
    var abs_origin: ?usize = null;
    var abs_velocity: ?usize = null;
    var max_speed: ?usize = null;
    var flags: ?usize = null;
};

fn datamap_print_Fn(args: *const convar.CCommand) callconv(.C) void {
    if (args.argc != 2) {
        std.log.info("Usage: datamap_print <class name>", .{});
        return;
    }

    if (datamap.server_map.get(args.args(1))) |player_map| {
        var it = player_map.iterator();
        while (it.next()) |kv| {
            std.log.info("{s}: {}", .{ kv.key_ptr.*, kv.value_ptr.* });
        }
    } else {
        std.log.info("Cannot find map", .{});
    }
}

fn init() void {
    feature.loaded = false;

    datamap_print.register();

    feature.loaded = true;
}

fn deinit() void {}

fn onPaint() void {
    hud.imatsystem.drawSetColor(.{ .r = 0, .g = 255, .b = 255 });
    hud.imatsystem.drawFilledRect(0, 0, 100, 200);
}
