const std = @import("std");

const Virtual = std.builtin.CallingConvention.Thiscall;

pub fn init() !void {
    var lib = try std.DynLib.open("tier0.dll");
    defer lib.close();

    inline for (comptime std.meta.fieldNames(@TypeOf(names))) |field| {
        const func = &@field(@This(), field);
        const name = @field(names, field);
        func.* = lib.lookup(@TypeOf(func.*), name) orelse return error.SymbolNotFound;
    }

    memalloc = (lib.lookup(**MemAlloc, "g_pMemAlloc") orelse return error.SymbolNotFound).*;

    ready = true;

    std.log.debug("tier0 loaded", .{});
}

pub const FmtFn = *const fn (fmt: [*:0]const u8, ...) callconv(.C) void;
pub var msg: FmtFn = undefined;
pub var warning: FmtFn = undefined;
pub var devMsg: FmtFn = undefined;

pub var ready: bool = false;

const names = .{
    .msg = "Msg",
    .warning = "Warning",
    .devMsg = "?DevMsg@@YAXPBDZZ",
};

pub var memalloc: *MemAlloc = undefined;

const MemAlloc = extern struct {
    _vt: *align(@alignOf(*anyopaque)) const anyopaque,

    const VTable = extern struct {
        _alloc: *const anyopaque,
        alloc: *const fn (this: *anyopaque, size: usize) callconv(Virtual) *anyopaque,
        _realloc: *const anyopaque,
        realloc: *const fn (this: *anyopaque, mem: *anyopaque, size: usize) callconv(Virtual) *anyopaque,
        _free: *const anyopaque,
        free: *const fn (this: *anyopaque, mem: *anyopaque) callconv(Virtual) void,
    };

    fn vt(self: *MemAlloc) *const VTable {
        return @ptrCast(self._vt);
    }

    pub fn alloc(self: *MemAlloc, size: usize) *anyopaque {
        return self.vt().alloc(self, size);
    }

    pub fn realloc(self: *MemAlloc, mem: *anyopaque, size: usize) *anyopaque {
        return self.vt().realloc(self, mem, size);
    }

    pub fn free(self: *MemAlloc, mem: *anyopaque) void {
        self.vt().free(self, mem);
    }
};
