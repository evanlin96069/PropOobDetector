const std = @import("std");

const interfaces = @import("../interfaces.zig");

const Module = @import("Module.zig");

const core = @import("../core.zig");
const event = @import("../event.zig");

const sdk = @import("sdk");
const Edict = sdk.Edict;
const Vector = sdk.Vector;
const Ray = sdk.Ray;
const Trace = sdk.Trace;
const ITraceFilter = sdk.ITraceFilter;

const zhook = @import("zhook");

pub var module: Module = .{
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
        const _pEntityOfEntIndex: *const fn (this: *anyopaque, index: c_int) callconv(.Thiscall) ?*Edict = @ptrCast(self._vt[VTIndex.pEntityOfEntIndex]);
        return _pEntityOfEntIndex(self, index);
    }
};

const IVEngineClient = extern struct {
    _vt: [*]*const anyopaque,

    const VTIndex = struct {
        const clientCmd = 7;
        const isInGame = 26;
    };

    pub fn clientCmd(self: *IVEngineClient, command: [*:0]const u8) void {
        const _clientCmd: *const fn (this: *anyopaque, command: [*:0]const u8) callconv(.Thiscall) void = @ptrCast(self._vt[VTIndex.clientCmd]);
        _clientCmd(self, command);
    }

    pub fn isInGame(self: *IVEngineClient) bool {
        const _isInGame: *const fn (this: *anyopaque) callconv(.Thiscall) bool = @ptrCast(self._vt[VTIndex.isInGame]);
        return _isInGame(self);
    }
};

const IEngineTrace = extern struct {
    _vt: [*]*const anyopaque,

    const VTIndex = struct {
        const traceRay = 4;
        const pointOutsideWorld = 16;
    };

    pub fn traceRay(self: *IEngineTrace, ray: *const Ray, mask: c_uint, filter: ?*ITraceFilter, trace: *Trace) void {
        const _traceRay: *const fn (this: *anyopaque, ray: *const Ray, mask: c_uint, filter: ?*ITraceFilter, trace: *Trace) callconv(.Thiscall) void = @ptrCast(self._vt[VTIndex.traceRay]);
        _traceRay(self, ray, mask, filter, trace);
    }

    pub fn pointOutsideWorld(self: *IEngineTrace, pt_test: Vector) bool {
        const _pointOutsideWorld: *const fn (this: *anyopaque, pt_test: *const Vector) callconv(.Thiscall) bool = @ptrCast(self._vt[VTIndex.pointOutsideWorld]);
        return _pointOutsideWorld(self, &pt_test);
    }
};

pub var server: *IVEngineServer = undefined;
pub var client: *IVEngineClient = undefined;

pub var trace_server: *IEngineTrace = undefined;
pub var trace_client: *IEngineTrace = undefined;

pub const SignonState = enum(c_int) {
    none = 0,
    challenge,
    connected,
    new,
    prespawn,
    spawn,
    full,
    changelevel,
};

fn hookedSetSignonState(this: *anyopaque, state: SignonState) callconv(.Thiscall) void {
    origSetSignonState.?(this, state);

    if (state == .full) {
        event.session_start.emit(.{});
    }
}

const SetSignonStateFunc = *const @TypeOf(hookedSetSignonState);
var origSetSignonState: ?SetSignonStateFunc = null;

const SetSignonState_patterns = zhook.mem.makePatterns(.{
    "56 8B F1 8B ?? ?? ?? ?? ?? 8B 01 8B 50 ?? FF D2 84 C0 75 ?? 8B",
    "55 8B EC 56 8B F1 8B ?? ?? ?? ?? ?? 8B 01 8B 50 ?? FF D2 84",
    "55 8B EC 56 8B F1 8B 0D ?? ?? ?? ?? 8B 01 8B 40 ?? FF D0 84 C0",
});

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

    origSetSignonState = core.hook_manager.findAndHook(
        SetSignonStateFunc,
        "engine",
        SetSignonState_patterns,
        hookedSetSignonState,
    ) catch |e| blk: {
        switch (e) {
            error.PatternNotFound => std.log.debug("Failed to find SetSignonState", .{}),
            else => std.log.debug("Failed to hook SetSignonState", .{}),
        }
        break :blk null;
    };

    module.loaded = true;
}

fn deinit() void {}
