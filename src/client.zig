const std = @import("std");

const interfaces = @import("interfaces.zig");
const modules = @import("modules.zig");

const Virtual = std.builtin.CallingConvention.Thiscall;

pub var module = modules.Module{
    .init = init,
    .deinit = deinit,
};

const IClientEntityList = extern struct {
    _vt: [*]*const anyopaque,

    const VTIndex = struct {
        const getClientEntity = 3;
        const getHighestEntityIndex = 6;
    };

    pub fn getClientEntity(self: *IClientEntityList, index: c_int) ?*anyopaque {
        const _getClientEntity: *const fn (this: *anyopaque, index: c_int) callconv(Virtual) ?*anyopaque = @ptrCast(self._vt[VTIndex.getClientEntity]);
        return _getClientEntity(self, index);
    }

    pub fn getHighestEntityIndex(self: *IClientEntityList) c_int {
        const _getHighestEntityIndex: *const fn (this: *anyopaque) callconv(Virtual) c_int = @ptrCast(self._vt[VTIndex.getHighestEntityIndex]);
        return _getHighestEntityIndex(self);
    }
};

pub var entlist: *IClientEntityList = undefined;

fn init() void {
    module.loaded = false;
    const clientFactory = interfaces.getFactory("client.dll") orelse {
        std.log.err("Failed to get client interface factory", .{});
        return;
    };

    entlist = @ptrCast(clientFactory("VClientEntityList003", null) orelse {
        std.log.err("Failed to get IClientEntityList interface", .{});
        return;
    });

    module.loaded = true;
}

fn deinit() void {}
