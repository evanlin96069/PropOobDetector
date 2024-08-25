const std = @import("std");

const Feature = @import("modules.zig").Feature;
const convar = @import("convar.zig");
const engine = @import("engine.zig");
const datamap = @import("datamap.zig");

pub var feature: Feature = .{
    .init = init,
    .deinit = deinit,
};

var pod_datamap_print = convar.ConCommand{
    .base = .{
        .name = "pod_datamap_print",
        .flags = .{
            .hidden = true,
        },
        .help_string = "Prints all datamaps.",
    },
    .command_callback = datamap_print_Fn,
};

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

var pod_datamap_walk = convar.ConCommand{
    .base = .{
        .name = "pod_datamap_walk",
        .flags = .{
            .hidden = true,
        },
        .help_string = "Walk through a datamap and print all offsets.",
    },
    .command_callback = datamap_walk_Fn,
};

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
    } else {
        std.log.info("Cannot find server map", .{});
    }

    if (datamap.client_map.get(args.args(1))) |map| {
        std.log.info("Client map:", .{});
        var it = map.iterator();
        while (it.next()) |kv| {
            std.log.info("    {s}: {d}", .{ kv.key_ptr.*, kv.value_ptr.* });
        }
    } else {
        std.log.info("Cannot find client map", .{});
    }
}

fn init() void {
    feature.loaded = false;

    pod_datamap_print.register();
    pod_datamap_walk.register();

    feature.loaded = true;
}

fn deinit() void {}
