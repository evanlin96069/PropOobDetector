const std = @import("std");
const builtin = @import("builtin");

const x86 = @import("x86.zig");

const loadValue = @import("mem.zig").loadValue;

const Hook = @This();

const HookType = enum {
    vmt,
    detour,
};

const HookData = union(HookType) {
    const HookVMTResult = struct {
        vt: [*]*const anyopaque,
        index: u32,
    };

    const HookDetourResult = struct {
        alloc: std.mem.Allocator,
        func: [*]u8,
        trampoline: []u8,
    };

    vmt: HookVMTResult,
    detour: HookDetourResult,
};

orig: ?*const anyopaque,
data: HookData,

pub fn hookVMT(vt: [*]*const anyopaque, index: usize, target: *const anyopaque) !Hook {
    try memoryProtect(@ptrCast(vt + index), @sizeOf(*anyopaque), .ReadWrite);

    const orig: *const anyopaque = vt[index];
    vt[index] = target;

    return Hook{
        .orig = orig,
        .data = .{
            .vmt = .{
                .vt = vt,
                .index = index,
            },
        },
    };
}

pub fn hookDetour(func: *anyopaque, target: *const anyopaque, alloc: std.mem.Allocator) !Hook {
    const mem: [*]u8 = @ptrCast(func);

    // Hook the underlying thing if the function jmp immediately.
    while (mem[0] == x86.Opcode.Op1.jmpiw) {
        mem += loadValue(i32, mem + 1) + 5;
    }

    try memoryProtect(@ptrCast(mem), 5, .ReadWrite);

    var len: usize = 0;
    while (len < 5) {
        // CALL and JMP instructions use relative offsets rather than absolute addresses.
        // We can't copy them into the trampoline directly. Just returns an error for now.
        if (mem[len] == x86.Opcode.Op1.call) {
            return error.BadHookInstruction;
        }

        if (mem[len] == x86.Opcode.Op1.jmpiw) {
            return error.BadHookInstruction;
        }

        len += try x86.x86_len(mem + len);
    }

    var trampoline = try alloc.alloc(u8, len + 5);
    @memcpy(trampoline, mem[0..len]);
    trampoline[len] = x86.Opcode.Op1.jmpiw;
    const jmp1_offset: *i32 = @ptrCast(trampoline.ptr + len + 1);
    jmp1_offset.* = @intFromPtr(func) - (@intFromPtr(trampoline.ptr) + 5);

    mem[0] = x86.Opcode.Op1.jmpiw;
    const jmp2_offset: *i32 = @ptrCast(mem + 1);
    jmp2_offset.* = @intFromPtr(target) - (@intFromPtr(func) + 5);

    return Hook{
        .orig = trampoline.ptr,
        .data = .{ .detour = .{
            .alloc = alloc,
            .func = mem,
            .trampoline = trampoline,
        } },
    };
}

pub fn unhook(self: *Hook) void {
    const orig = self.orig orelse return;
    switch (self.data) {
        .vmt => |v| {
            v.vt[v.index] = orig;
        },
        .detour => |v| {
            @memcpy(v.func, v.trampoline[0 .. v.trampoline.len - 5]);
        },
    }
    self.orig = null;
}

const Protection = enum {
    ReadOnly,
    ReadWrite,
    NoAccess,

    fn toNative(self: Protection) u32 {
        return switch (builtin.target.os.tag) {
            .windows => switch (self) {
                .ReadOnly => std.os.windows.PAGE_READONLY,
                .ReadWrite => std.os.windows.PAGE_READWRITE,
                .NoAccess => std.os.windows.PAGE_NOACCESS,
            },
            .linux => switch (self) {
                .ReadOnly => std.os.linux.PROT.READ,
                .ReadWrite => std.os.linux.PROT.READ | std.os.linux.PROT.WRITE,
                .NoAccess => std.os.linux.PROT.NONE,
            },
            else => @compileError("Unsupported OS"),
        };
    }
};

fn memoryProtect(ptr: *anyopaque, len: usize, new_protect: Protection) !void {
    const native_protect = new_protect.toNative();

    switch (builtin.target.os.tag) {
        .windows => {
            var old_protect: std.os.windows.DWORD = undefined;
            try std.os.windows.VirtualProtect(ptr, len, native_protect, &old_protect);
        },
        .linux => {
            ptr = @ptrFromInt(@intFromPtr(ptr) & ~(4095));
            len = len + 4095 & ~(4095);
            if (std.os.linux.mprotect(@ptrCast(ptr), len, native_protect) != 0) {
                return error.MemoryProtectError;
            }
        },
        else => @compileError("Unsupported OS"),
    }
}
