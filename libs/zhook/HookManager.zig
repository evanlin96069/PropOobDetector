const std = @import("std");

const Hook = @import("Hook.zig");
const mem = @import("mem.zig");

const HookManager = @This();

alloc: std.mem.Allocator,
hooks: std.ArrayList(Hook),

pub fn init(alloc: std.mem.Allocator) HookManager {
    return HookManager{
        .alloc = alloc,
        .hooks = std.ArrayList(Hook).init(alloc),
    };
}

pub fn deinit(self: *HookManager) void {
    for (self.hooks.items) |*hook| {
        hook.unhook();
    }

    self.hooks.deinit();
}

pub fn findAndHook(self: *HookManager, T: type, comptime module_name: []const u8, patterns: []const []const ?u8, target: *const anyopaque) !T {
    const module = mem.getModule(comptime module_name) orelse return error.ModuleNotFound;
    const match = mem.scanUniquePatterns(module, patterns) orelse {
        return error.PatternNotFound;
    };

    return self.hookDetour(T, match.ptr, target);
}

pub fn hookVMT(self: *HookManager, T: type, vt: [*]*const anyopaque, index: usize, target: *const anyopaque) !T {
    var hook = try Hook.hookVMT(vt, index, target);
    errdefer hook.unhook();

    try self.hooks.append(hook);

    return @ptrCast(hook.orig.?);
}

pub fn hookDetour(self: *HookManager, T: type, func: *const anyopaque, target: *const anyopaque) !T {
    var hook = try Hook.hookDetour(@constCast(func), target, self.alloc);
    errdefer hook.unhook();

    try self.hooks.append(hook);

    return @ptrCast(hook.orig.?);
}
