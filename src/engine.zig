const std = @import("std");

const interfaces = @import("interfaces.zig");
const modules = @import("modules.zig");

const Virtual = std.builtin.CallingConvention.Thiscall;

pub var module = modules.Module{
    .init = init,
    .deinit = deinit,
};

const Edict = extern struct {
    state_flags: c_int,
    network_serial_number: c_int,
    networkable: *anyopaque,
    unknown: *anyopaque,
    freetime: f32,
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

    pub fn getPlayer(self: *IVEngineServer) ?*anyopaque {
        const edict: *Edict = self.pEntityOfEntIndex(1) orelse return null;
        return edict.unknown;
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

pub var engine_server: *IVEngineServer = undefined;
pub var engine_client: *IVEngineClient = undefined;

fn init() void {
    engine_server = @ptrCast(interfaces.engineFactory("VEngineServer021", null) orelse {
        std.log.err("Failed to get IVEngineServer interface", .{});
        return;
    });

    const engine_client_info = interfaces.create(interfaces.engineFactory, "VEngineClient", .{ 13, 14 }) orelse {
        std.log.err("Failed to get IVEngineClient interface", .{});
        return;
    };
    engine_client = @ptrCast(engine_client_info.interface);
}

fn deinit() void {}
