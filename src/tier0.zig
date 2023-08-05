const std = @import("std");

pub fn init() !void {
    var lib = try std.DynLib.open(names.lib);
    defer lib.close();

    inline for (comptime std.meta.fieldNames(@TypeOf(names))) |field| {
        if (comptime std.mem.eql(u8, field, "lib")) continue;
        const func = &@field(@This(), field);
        const name = @field(names, field);
        func.* = lib.lookup(@TypeOf(func.*), name) orelse return error.SymbolNotFound;
    }

    ready = true;

    std.log.debug("tier0 loaded", .{});
}

pub const FmtFn = *const fn (fmt: [*:0]const u8, ...) callconv(.C) void;
pub var msg: FmtFn = undefined;
pub var warning: FmtFn = undefined;
pub var devMsg: FmtFn = undefined;
pub var ready: bool = false;

const names = .{
    .lib = "tier0.dll",
    .msg = "Msg",
    .warning = "Warning",
    .devMsg = "?DevMsg@@YAXPBDZZ",
};
