const std = @import("std");

const interfaces = @import("interfaces.zig");
const modules = @import("modules.zig");

const Virtual = std.builtin.CallingConvention.Thiscall;

pub var module = modules.Module{
    .init = init,
    .deinit = deinit,
};

pub const Edict = extern struct {
    state_flags: c_int,
    network_serial_number: c_int,
    networkable: *anyopaque,
    unknown: *anyopaque,
    freetime: f32,

    pub fn getOffsetField(self: *Edict, comptime T: type, offset: usize) *T {
        const addr: [*]const u8 = @ptrCast(self.unknown);
        return @ptrCast(addr + offset);
    }
};

const IVEngineServer = extern struct {
    _vt: [*]*const anyopaque,

    const VTIndex = struct {
        const pEntityOfEntIndex = 19;
    };

    pub fn pEntityOfEntIndex(self: *IVEngineServer, index: c_int) ?*Edict {
        const _pEntityOfEntIndex: *const fn (this: *anyopaque, index: c_int) callconv(Virtual) ?*Edict = @ptrCast(self._vt[VTIndex.pEntityOfEntIndex]);
        return _pEntityOfEntIndex(self, index);
    }
};

const IVEngineClient = extern struct {
    _vt: [*]*const anyopaque,

    const VTIndex = struct {
        const clientCmd = 7;
    };

    pub fn clientCmd(self: *IVEngineClient, command: [*:0]const u8) void {
        const _clientCmd: *const fn (this: *anyopaque, command: [*:0]const u8) callconv(Virtual) void = @ptrCast(self._vt[VTIndex.clientCmd]);
        _clientCmd(self, command);
    }
};

pub var server: *IVEngineServer = undefined;
pub var client: *IVEngineClient = undefined;

fn init() void {
    module.loaded = false;

    server = @ptrCast(interfaces.engineFactory("VEngineServer021", null) orelse {
        std.log.err("Failed to get IVEngineServer interface", .{});
        return;
    });

    const client_info = interfaces.create(interfaces.engineFactory, "VEngineClient", .{ 13, 14 }) orelse {
        std.log.err("Failed to get IVEngineClient interface", .{});
        return;
    };
    client = @ptrCast(client_info.interface);

    module.loaded = true;
}

fn deinit() void {}
