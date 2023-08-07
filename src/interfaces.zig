const std = @import("std");

pub const CreateInterfaceFn = *const fn (name: [*:0]const u8, ret: ?*c_int) callconv(.C) ?*align(@alignOf(*anyopaque)) anyopaque;

pub var engineFactory: CreateInterfaceFn = undefined;
pub var serverFactory: CreateInterfaceFn = undefined;

const Virtual = std.builtin.CallingConvention.Thiscall;

pub const IAppSystem = extern struct {
    _vt: *align(4) const anyopaque,

    pub const VTable = extern struct {
        connect: *const anyopaque,
        disconnect: *const anyopaque,
        queryInterface: *const anyopaque,
        init: *const anyopaque,
        shutdown: *const anyopaque,
    };
};

const QAngle = extern struct {
    x: f32,
    y: f32,
    z: f32,
};

const IVEngineClient = extern struct {
    _vt: [*]*anyopaque,

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

pub var engine: *IVEngineClient = undefined;
