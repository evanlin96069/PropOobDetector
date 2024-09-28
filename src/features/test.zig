const std = @import("std");

const modules = @import("../modules.zig");
const convar = modules.tier1;
const hud = modules.vgui;
const engine = modules.engine;

const datamap = @import("datamap.zig");

const Color = @import("sdk").Color;

const Feature = @import("Feature.zig");

pub var feature: Feature = .{
    .init = init,
    .deinit = deinit,
    .onPaint = paint,
    .onSessionStart = onSessionStart,
};

var pod_hud_debug = convar.Variable.init(.{
    .name = "pod_hud_debug",
    .flags = .{
        .hidden = true,
    },
    .help_string = "Draw test HUD.",
    .default_value = "0",
});

var pod_datamap_print = convar.ConCommand.init(.{
    .name = "pod_datamap_print",
    .flags = .{
        .hidden = true,
    },
    .help_string = "Prints all datamaps.",
    .command_callback = datamap_print_Fn,
});

fn datamap_print_Fn(args: *const convar.CCommand) callconv(.C) void {
    _ = args;

    var server_it = datamap.server_map.iterator();
    std.log.info("Server datamaps:", .{});
    while (server_it.next()) |kv| {
        std.log.info("    {s}", .{kv.key_ptr.*});
    }

    var client_it = datamap.client_map.iterator();
    std.log.info("Client datamaps:", .{});
    while (client_it.next()) |kv| {
        std.log.info("    {s}", .{kv.key_ptr.*});
    }
}

var pod_datamap_walk = convar.ConCommand.init(.{
    .name = "pod_datamap_walk",
    .flags = .{
        .hidden = true,
    },
    .help_string = "Walk through a datamap and print all offsets.",
    .command_callback = datamap_walk_Fn,
});

fn datamap_walk_Fn(args: *const convar.CCommand) callconv(.C) void {
    if (args.argc != 2) {
        std.log.info("Usage: pod_datamap_walk <class name>", .{});
        return;
    }

    if (datamap.server_map.get(args.args(1))) |map| {
        std.log.info("Server map:", .{});
        var it = map.iterator();
        while (it.next()) |kv| {
            std.log.info("    {s}: {d}", .{ kv.key_ptr.*, kv.value_ptr.* });
        }
    }

    if (datamap.client_map.get(args.args(1))) |map| {
        std.log.info("Client map:", .{});
        var it = map.iterator();
        while (it.next()) |kv| {
            std.log.info("    {s}: {d}", .{ kv.key_ptr.*, kv.value_ptr.* });
        }
    }
}

fn paint() void {
    if (pod_hud_debug.getBool()) {
        const screen = hud.imatsystem.getScreenSize();
        const cols = 8;
        const rows = 8;
        const padding: i32 = 10;

        const rect_width = @divFloor(screen.wide - padding * (cols + 1), cols);
        const rect_height = @divFloor(screen.tall - padding * (rows + 1), rows);

        const colors = [_]Color{
            .{ .r = 0, .g = 0, .b = 0 },
            .{ .r = 87, .g = 80, .b = 104 },
            .{ .r = 242, .g = 154, .b = 48 },
            .{ .r = 225, .g = 216, .b = 239 },
        };

        var row: i32 = 0;
        while (row < rows) : (row += 1) {
            var col: i32 = 0;
            while (col < cols) : (col += 1) {
                const x0 = padding + col * (rect_width + padding);
                const y0 = padding + row * (rect_height + padding);
                const x1 = x0 + rect_width;
                const y1 = y0 + rect_height;

                hud.imatsystem.drawSetColor(colors[@as(u32, @intCast(row + col)) % colors.len]);
                hud.imatsystem.drawFilledRect(x0, y0, x1, y1);
            }
        }
    }
}

fn onSessionStart() void {
    std.log.debug("Session Start!", .{});
}

fn init() void {
    feature.loaded = false;

    pod_datamap_print.register();
    pod_datamap_walk.register();

    pod_hud_debug.register();

    feature.loaded = true;
}

fn deinit() void {}
