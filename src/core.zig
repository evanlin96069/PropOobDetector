const std = @import("std");

pub var gpa: std.mem.Allocator = undefined;

var gpa_state: std.heap.GeneralPurposeAllocator(.{
    .stack_trace_frames = 8,
}) = undefined;

pub fn init() void {
    gpa_state = .{};
    gpa = gpa_state.allocator();
}

pub fn deinit() void {
    _ = gpa_state.deinit();
}
