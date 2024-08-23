const std = @import("std");

const interfaces = @import("interfaces.zig");
const modules = @import("modules.zig");

const sdk = @import("sdk.zig");
const Edict = sdk.Edict;
const Vector = sdk.Vector;
const Ray = sdk.Ray;
const Trace = sdk.Trace;
const ITraceFilter = sdk.ITraceFilter;

const Virtual = std.builtin.CallingConvention.Thiscall;

pub var module = modules.Module{
    .init = init,
    .deinit = deinit,
};

pub var sdk_version: u32 = 0;

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

const IEngineTrace = extern struct {
    _vt: [*]*const anyopaque,

    const VTIndex = struct {
        const traceRay = 4;
        const pointOutsideWorld = 16;
    };

    pub fn traceRay(self: *IEngineTrace, ray: *const Ray, mask: c_uint, filter: ?*ITraceFilter, trace: *Trace) void {
        const _traceRay: *const fn (this: *anyopaque, ray: *const Ray, mask: c_uint, filter: ?*ITraceFilter, trace: *Trace) callconv(Virtual) void = @ptrCast(self._vt[VTIndex.traceRay]);
        _traceRay(self, ray, mask, filter, trace);
    }

    pub fn pointOutsideWorld(self: *IEngineTrace, pt_test: Vector) bool {
        const _pointOutsideWorld: *const fn (this: *anyopaque, pt_test: *const Vector) callconv(Virtual) bool = @ptrCast(self._vt[VTIndex.pointOutsideWorld]);
        return _pointOutsideWorld(self, &pt_test);
    }
};

pub var server: *IVEngineServer = undefined;
pub var client: *IVEngineClient = undefined;

pub var trace_server: *IEngineTrace = undefined;
pub var trace_client: *IEngineTrace = undefined;

fn init() void {
    module.loaded = false;

    server = @ptrCast(interfaces.engineFactory("VEngineServer021", null) orelse {
        std.log.err("Failed to get IVEngineServer interface", .{});
        return;
    });

    const client_info = interfaces.create(interfaces.engineFactory, "VEngineClient", .{ 14, 13 }) orelse {
        std.log.err("Failed to get IVEngineClient interface", .{});
        return;
    };
    client = @ptrCast(client_info.interface);
    sdk_version = if (client_info.version == 14) 2013 else 2007;

    server = @ptrCast(interfaces.engineFactory("VEngineServer021", null) orelse {
        std.log.err("Failed to get IVEngineServer interface", .{});
        return;
    });

    trace_server = @ptrCast(interfaces.engineFactory("EngineTraceServer003", null) orelse {
        std.log.err("Failed to get EngineTraceServer interface", .{});
        return;
    });

    trace_client = @ptrCast(interfaces.engineFactory("EngineTraceClient003", null) orelse {
        std.log.err("Failed to get EngineTraceClient interface", .{});
        return;
    });

    module.loaded = true;
}

fn deinit() void {}
