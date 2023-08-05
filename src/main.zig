const std = @import("std");

pub const CreateInterfaceFn = *const fn (name: [*:0]const u8, ret: ?*c_int) callconv(.C) ?*align(@alignOf(*anyopaque)) anyopaque;

const Method = std.builtin.CallingConvention.Thiscall;

fn load(_: *anyopaque, interfaceFactory: CreateInterfaceFn, gameServerFactory: CreateInterfaceFn) callconv(Method) bool {
    _ = interfaceFactory;
    _ = gameServerFactory;

    return true;
}

fn unload(_: *anyopaque) callconv(Method) void {}

fn pause(_: *anyopaque) callconv(Method) void {}

fn unpause(_: *anyopaque) callconv(Method) void {}

fn getPluginDescription(_: *anyopaque) callconv(Method) [*:0]const u8 {
    return "zig plugin";
}

fn levelInit(_: *anyopaque, map_name: [*:0]const u8) callconv(Method) void {
    _ = map_name;
}

pub const Edict = extern struct {
    state_flags: c_int,
    network_serial_number: c_int,
    networkable: *anyopaque,
    unk: *anyopaque,
    freetime: f32,
};

fn serverActivate(_: *anyopaque, edict_list: [*]Edict, edict_count: c_int, client_max: c_int) callconv(Method) void {
    _ = edict_list;
    _ = edict_count;
    _ = client_max;
}

fn gameFrame(_: *anyopaque, simulating: bool) callconv(Method) void {
    _ = simulating;
}

fn levelShutdown(_: *anyopaque) callconv(Method) void {}

fn clientActive(_: *anyopaque, entity: *Edict) callconv(Method) void {
    _ = entity;
}

fn clientDisconnect(_: *anyopaque, entity: *Edict) callconv(Method) void {
    _ = entity;
}

fn clientPutInServer(_: *anyopaque, entity: *Edict, player_name: [*:0]const u8) callconv(Method) void {
    _ = entity;
    _ = player_name;
}

fn setCommandClient(_: *anyopaque, index: c_int) callconv(Method) void {
    _ = index;
}

fn clientSettingsChanged(_: *anyopaque, entity: *Edict) callconv(Method) void {
    _ = entity;
}

fn clientConnect(_: *anyopaque, allow: *bool, entity: *Edict, name: [*:0]const u8, addr: [*:0]const u8, reject: [*:0]u8, max_reject_len: c_int) callconv(Method) c_int {
    _ = allow;
    _ = entity;
    _ = name;
    _ = addr;
    _ = reject;
    _ = max_reject_len;
    return 0;
}

fn clientCommand(_: *anyopaque, entity: *Edict) callconv(Method) c_int {
    _ = entity;
    return 0;
}

fn networkIdValidated(_: *anyopaque, user_name: [*:0]const u8, network_id: [*:0]const u8) callconv(Method) c_int {
    _ = user_name;
    _ = network_id;
    return 0;
}

const vtalbe_plugin = [_]*anyopaque{
    @ptrCast(@constCast(&load)),
    @ptrCast(@constCast(&unload)),
    @ptrCast(@constCast(&pause)),
    @ptrCast(@constCast(&unpause)),
    @ptrCast(@constCast(&getPluginDescription)),
    @ptrCast(@constCast(&levelInit)),
    @ptrCast(@constCast(&serverActivate)),
    @ptrCast(@constCast(&gameFrame)),
    @ptrCast(@constCast(&levelShutdown)),
    @ptrCast(@constCast(&clientActive)),
    @ptrCast(@constCast(&clientDisconnect)),
    @ptrCast(@constCast(&clientPutInServer)),
    @ptrCast(@constCast(&setCommandClient)),
    @ptrCast(@constCast(&clientSettingsChanged)),
    @ptrCast(@constCast(&clientConnect)),
    @ptrCast(@constCast(&clientCommand)),
    @ptrCast(@constCast(&networkIdValidated)),
};

var plugin = &vtalbe_plugin;

export fn CreateInterface(name: [*:0]u8, ret: ?*c_int) ?*anyopaque {
    if (!std.mem.eql(u8, std.mem.span(name), "ISERVERPLUGINCALLBACKS001")) {
        if (ret) |r| r.* = 0;
        return @ptrCast(&plugin);
    }

    if (ret) |r| r.* = 1;
    return null;
}
