const std = @import("std");

const modules = @import("modules.zig");
const Feature = modules.Feature;
const convar = @import("convar.zig");
const engine = @import("engine.zig");
const datamap = @import("datamap.zig");
const zhook = @import("zhook/zhook.zig");

const Virtual = std.builtin.CallingConvention.Thiscall;

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

var origSetSignonState: *const fn (this: *anyopaque, state: c_int) callconv(Virtual) void = undefined;
fn hookedSetSignonState(this: *anyopaque, state: c_int) callconv(Virtual) void {
    origSetSignonState(this, state);
    std.log.debug("SetSigonState: {d}", .{state});
}

const SetSignonState_patterns = zhook.mem.makePatterns(.{
    "56 8B F1 8B ?? ?? ?? ?? ?? 8B 01 8B 50 ?? FF D2 84 C0 75 ?? 8B",
    "55 8B EC 56 8B F1 8B ?? ?? ?? ?? ?? 8B 01 8B 50 ?? FF D2 84",
});

fn init() void {
    feature.loaded = false;

    pod_datamap_print.register();
    pod_datamap_walk.register();

    feature.loaded = true;

    const engine_dll = zhook.mem.getModule("engine.dll") orelse return;
    const SetSignonState_match = zhook.mem.scanUniquePatterns(engine_dll, SetSignonState_patterns) orelse {
        std.log.debug("Failed to find SetSignonState", .{});
        return;
    };

    origSetSignonState = @ptrCast(modules.hook_manager.hookDetour(SetSignonState_match.ptr, hookedSetSignonState) catch {
        std.log.debug("Failed to hook SetSignonState", .{});
        return;
    });
}

fn deinit() void {}
