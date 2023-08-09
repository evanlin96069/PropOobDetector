const std = @import("std");

const modules = @import("modules.zig");
const interfaces = @import("interfaces.zig");

const Virtual = std.builtin.CallingConvention.Thiscall;

const QAngle = extern struct {
    x: f32,
    y: f32,
    z: f32,
};

const IVEngineClient = extern struct {
    _vt: [*]*const anyopaque,

    pub fn clientCmd(self: *IVEngineClient, cmd: [*:0]const u8) void {
        const _clientCmd: *const fn (this: *anyopaque, cmd: [*:0]const u8) callconv(Virtual) void = @ptrCast(self._vt[9]);
        _clientCmd(self, cmd);
    }

    pub fn getViewAngles(self: *IVEngineClient) QAngle {
        var va: QAngle = undefined;
        const _getViewAngles: *const fn (this: *anyopaque, va: *QAngle) callconv(Virtual) void = @ptrCast(self._vt[21]);
        _getViewAngles(self, &va);
        return va;
    }

    pub fn setViewAngles(self: *IVEngineClient, va: QAngle) void {
        const _setViewAngles: *const fn (this: *anyopaque, va: *QAngle) callconv(Virtual) void = @ptrCast(self._vt[22]);
        _setViewAngles(self, &va);
    }

    pub fn cmdArgc(self: *IVEngineClient) i32 {
        const _cmdArgc: *const fn (this: *anyopaque) callconv(Virtual) c_int = @ptrCast(self._vt[34]);
        return @intCast(_cmdArgc(self));
    }

    pub fn cmdArgv(self: *IVEngineClient, arg: i32) void {
        const _cmdArgv: *const fn (this: *anyopaque, arg: c_int) callconv(Virtual) *[*:0]u8 = @ptrCast(self._vt[35]);
        return _cmdArgv(self, @intCast(arg));
    }
};

pub var client: *IVEngineClient = undefined;

pub var module = modules.Module{
    .init = init,
    .deinit = deinit,
};

fn init() void {
    module.loaded = false;
    client = @ptrCast(interfaces.engineFactory("VEngineClient012", null) orelse {
        std.log.err("Failed to get VEngineClient", .{});
        return;
    });

    module.loaded = true;
}

fn deinit() void {}
