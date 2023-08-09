const std = @import("std");

pub const CreateInterfaceFn = *const fn (name: [*:0]const u8, ret: ?*c_int) callconv(.C) ?*align(@alignOf(*anyopaque)) anyopaque;

pub var engineFactory: CreateInterfaceFn = undefined;
pub var serverFactory: CreateInterfaceFn = undefined;

pub const IAppSystem = extern struct {
    _vt: *align(4) const anyopaque,

    pub const VTable = extern struct {
        connect: *const anyopaque,
        disconnect: *const anyopaque,
        queryInterface: *const anyopaque,
        init: *const anyopaque,
        shutdown: *const anyopaque,
    };
};
