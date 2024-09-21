const std = @import("std");

const Hook = @import("Hook.zig");

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

pub fn hookVMT(self: *HookManager, vt: [*]*const anyopaque, index: usize, target: *const anyopaque) !*const anyopaque {
    var hook = try Hook.hookVMT(vt, index, target);
    errdefer hook.unhook();

    try self.hooks.append(hook);

    return hook.orig.?;
}

pub fn hookDetour(self: *HookManager, func: *const anyopaque, target: *const anyopaque) !*const anyopaque {
    var hook = try Hook.hookDetour(func, target, self.alloc);
    errdefer hook.unhook();

    try self.hooks.append(hook);

    return hook.orig.?;
}
