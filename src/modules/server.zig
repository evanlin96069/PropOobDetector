const std = @import("std");

const CUserCmd = @import("sdk").CUserCmd;

const Module = @import("Module.zig");

pub var module: Module = .{
    .name = "server",
    .init = init,
    .deinit = deinit,
};

fn init() bool {
    return true;
}

fn deinit() void {}
