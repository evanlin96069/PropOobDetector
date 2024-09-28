const std = @import("std");

const tier0 = @import("modules.zig").tier0;

fn Event(comptime CallbackFn: type) type {
    return struct {
        const Self = @This();

        alloc: std.mem.Allocator,
        callbacks: std.ArrayList(CallbackFn),

        pub fn init(alloc: std.mem.Allocator) Self {
            return Self{
                .alloc = alloc,
                .callbacks = std.ArrayList(CallbackFn).init(alloc),
            };
        }

        pub fn deinit(self: *Self) void {
            self.callbacks.deinit();
        }

        pub fn emit(self: *const Self, args: anytype) void {
            for (self.callbacks.items) |callback| {
                @call(.auto, callback, args);
            }
        }

        pub fn connect(self: *Self, callback: CallbackFn) void {
            self.callbacks.append(callback) catch unreachable;
        }
    };
}

pub var paint = Event(*const fn () void).init(tier0.allocator);
pub var tick = Event(*const fn () void).init(tier0.allocator);
pub var session_start = Event(*const fn () void).init(tier0.allocator);

pub fn deinit() void {
    paint.deinit();
    tick.deinit();
    session_start.deinit();
}
