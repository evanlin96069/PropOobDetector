const std = @import("std");

const core = @import("core.zig");
const interfaces = @import("interfaces.zig");
const tier0 = @import("modules.zig").tier0;

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = @import("log.zig").log,
};

const IServerPluginCallbacks = extern struct {
    _vt: *align(@alignOf(*anyopaque)) const anyopaque,
};

var plugin_loaded: bool = false;
var skip_unload: bool = false;

fn load(_: *anyopaque, interfaceFactory: interfaces.CreateInterfaceFn, gameServerFactory: interfaces.CreateInterfaceFn) callconv(.Thiscall) bool {
    if (plugin_loaded) {
        std.log.warn("Plugin already loaded", .{});
        skip_unload = true;
        return false;
    }
    plugin_loaded = true;

    interfaces.engineFactory = interfaceFactory;
    interfaces.serverFactory = gameServerFactory;

    if (!core.init()) {
        return false;
    }

    return true;
}

fn unload(_: *anyopaque) callconv(.Thiscall) void {
    if (skip_unload) {
        skip_unload = false;
        return;
    }

    core.deinit();

    plugin_loaded = false;
}

fn pause(_: *anyopaque) callconv(.Thiscall) void {}

fn unpause(_: *anyopaque) callconv(.Thiscall) void {}

fn getPluginDescription(_: *anyopaque) callconv(.Thiscall) [*:0]const u8 {
    return "Prop Oob Detector - evanlin96069";
}

fn levelInit(_: *anyopaque, map_name: [*:0]const u8) callconv(.Thiscall) void {
    _ = map_name;
}

fn serverActivate(
    _: *anyopaque,
    edict_list: [*]*anyopaque,
    edict_count: c_int,
    client_max: c_int,
) callconv(.Thiscall) void {
    _ = edict_list;
    _ = edict_count;
    _ = client_max;
}

fn gameFrame(_: *anyopaque, simulating: bool) callconv(.Thiscall) void {
    if (simulating) {
        core.emitTick();
    }
}

fn levelShutdown(_: *anyopaque) callconv(.Thiscall) void {}

fn clientActive(_: *anyopaque, entity: *anyopaque) callconv(.Thiscall) void {
    _ = entity;
}

fn clientDisconnect(_: *anyopaque, entity: *anyopaque) callconv(.Thiscall) void {
    _ = entity;
}

fn clientPutInServer(_: *anyopaque, entity: *anyopaque, player_name: [*:0]const u8) callconv(.Thiscall) void {
    _ = entity;
    _ = player_name;
}

fn setCommandClient(_: *anyopaque, index: c_int) callconv(.Thiscall) void {
    _ = index;
}

fn clientSettingsChanged(_: *anyopaque, entity: *anyopaque) callconv(.Thiscall) void {
    _ = entity;
}

fn clientConnect(
    _: *anyopaque,
    allow: *bool,
    entity: *anyopaque,
    name: [*:0]const u8,
    addr: [*:0]const u8,
    reject: [*:0]u8,
    max_reject_len: c_int,
) callconv(.Thiscall) c_int {
    _ = allow;
    _ = entity;
    _ = name;
    _ = addr;
    _ = reject;
    _ = max_reject_len;
    return 0;
}

fn clientCommand(_: *anyopaque, entity: *anyopaque, args: *const anyopaque) callconv(.Thiscall) c_int {
    _ = entity;
    _ = args;
    return 0;
}

fn networkIdValidated(_: *anyopaque, user_name: [*:0]const u8, network_id: [*:0]const u8) callconv(.Thiscall) c_int {
    _ = user_name;
    _ = network_id;
    return 0;
}

fn onQueryCvarValueFinished(
    _: *anyopaque,
    cookie: c_int,
    player_entity: *anyopaque,
    status: c_int,
    cvar_name: [*:0]const u8,
    cvar_value: [*:0]const u8,
) callconv(.Thiscall) void {
    _ = cvar_value;
    _ = cvar_name;
    _ = status;
    _ = player_entity;
    _ = cookie;
}

const vt_IServerPluginCallbacks = [_]*const anyopaque{
    &load,
    &unload,
    &pause,
    &unpause,
    &getPluginDescription,
    &levelInit,
    &serverActivate,
    &gameFrame,
    &levelShutdown,
    &clientActive,
    &clientDisconnect,
    &clientPutInServer,
    &setCommandClient,
    &clientSettingsChanged,
    &clientConnect,
    &clientCommand,
    &networkIdValidated,
    &onQueryCvarValueFinished,
};

const plugin: IServerPluginCallbacks = .{
    ._vt = @ptrCast(&vt_IServerPluginCallbacks),
};

export fn CreateInterface(name: [*:0]u8, ret: ?*c_int) ?*const IServerPluginCallbacks {
    if (std.mem.eql(u8, std.mem.span(name), "ISERVERPLUGINCALLBACKS002")) {
        if (ret) |r| r.* = 0;
        return &plugin;
    }

    if (ret) |r| r.* = 1;
    return null;
}
