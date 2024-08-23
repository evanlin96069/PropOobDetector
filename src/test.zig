const std = @import("std");

const modules = @import("modules.zig");
const convar = @import("convar.zig");
const engine = @import("engine.zig");
const datamap = @import("datamap.zig");

pub var feature = modules.Feature{
    .init = init,
    .deinit = deinit,
};

var pod_print_datamap = convar.ConCommand{
    .base = .{
        .name = "pod_print_datamap",
        .flags = .{
            .hidden = true,
        },
        .help_str = "Prints datamap of a class.",
    },
    .command_callback = print_datamap_Fn,
};

fn print_datamap_Fn(args: *const convar.CCommand) callconv(.C) void {
    if (args.argc != 2) {
        std.log.info("Usage: datamap_print <class name>", .{});
        return;
    }

    if (datamap.server_map.get(args.args(1))) |map| {
        var it = map.iterator();
        while (it.next()) |kv| {
            std.log.info("{s}: {}", .{ kv.key_ptr.*, kv.value_ptr.* });
        }
    } else {
        std.log.info("Cannot find map", .{});
    }
}

fn init() void {
    feature.loaded = false;

    pod_print_datamap.register();

    feature.loaded = true;
}

fn deinit() void {}
