const std = @import("std");

pub fn hookVirtual(vt: [*]*const anyopaque, index: u32, target: *const anyopaque) ?*const anyopaque {
    var old: std.os.windows.DWORD = undefined;
    std.os.windows.VirtualProtect(@ptrCast(vt + index), @sizeOf(*anyopaque), std.os.windows.PAGE_READWRITE, &old) catch {
        return null;
    };

    const orig: *const anyopaque = vt[index];
    vt[index] = target;
    return orig;
}

pub fn unhookVirtual(vt: [*]*const anyopaque, index: u32, orig: *const anyopaque) void {
    vt[index] = orig;
}

inline fn isHex(c: u8) bool {
    return (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F');
}

pub fn parsePattern(comptime str: []const u8) []const ?u8 {
    return comptime blk: {
        @setEvalBranchQuota(10_000);
        var it = std.mem.split(u8, str, " ");
        var pat: []const ?u8 = &.{};

        while (it.next()) |byte| {
            if (byte.len != 2) {
                @compileError("Each byte should be 2 characters");
            }
            if (byte[0] == '?') {
                if (byte[1] != '?') {
                    @compileError("The second question mark is missing");
                }
                pat = pat ++ .{null};
            } else if (isHex(byte[0])) {
                if (!isHex(byte[1])) {
                    @compileError("The second hex digit is missing");
                }
                const n = try std.fmt.parseInt(u8, byte, 16);
                pat = pat ++ .{n};
            } else {
                @compileError("Only hex digits, spaces and question marks are allowed");
            }
        }
        break :blk pat;
    };
}

pub fn scanFirst(mem: []const u8, comptime pat: []const ?u8) ?usize {
    var i: usize = 0;
    while (i < mem.len - pat.len) : (i += 1) {
        var found = true;
        for (pat, 0..) |byte, j| {
            if (byte) |b| {
                if (b != mem[i + j]) {
                    found = false;
                    break;
                }
            }
        }

        if (found) {
            return i;
        }
    }

    return null;
}

pub fn scanAll(mem: []const u8, comptime pat: []const ?u8, data: *std.ArrayList(usize)) !void {
    var base: usize = 0;
    while (scanFirst(mem[base..], pat)) |offset| {
        try data.append(base + offset);
        base += offset + pat.len;
    }
}

pub const DynLib = struct {
    dll: std.DynLib,
    info: std.os.windows.MODULEINFO,
    mem: []const u8,

    pub fn open(path: []const u8) !DynLib {
        var lib = try std.DynLib.open(path);
        var info: std.os.windows.MODULEINFO = undefined;
        if (std.os.windows.kernel32.K32GetModuleInformation(std.os.windows.kernel32.GetCurrentProcess(), lib.dll, &info, @sizeOf(std.os.windows.MODULEINFO)) == 0) {
            return error.GetModuleInformation;
        }

        var ptr: [*]const u8 = @ptrCast(lib.dll);

        return DynLib{
            .dll = lib,
            .info = info,
            .mem = ptr[0..info.SizeOfImage],
        };
    }

    pub fn close(self: *DynLib) void {
        self.dll.close();
    }
};
