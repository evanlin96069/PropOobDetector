const std = @import("std");
const testing = std.testing;

const isHex = @import("utils.zig").isHex;
const makeHex = @import("utils.zig").makeHex;

pub fn makePattern(comptime str: []const u8) []const ?u8 {
    return comptime blk: {
        @setEvalBranchQuota(10000);
        var it = std.mem.splitSequence(u8, str, " ");
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

pub fn makePatterns(comptime arr: anytype) []const []const ?u8 {
    return comptime blk: {
        var patterns: []const []const ?u8 = &.{};
        for (arr) |str| {
            const pat: []const []const ?u8 = &.{makePattern(str)};
            patterns = patterns ++ pat;
        }
        break :blk patterns;
    };
}

pub fn scanFirst(mem: []const u8, pattern: []const ?u8) ?usize {
    if (mem.len < pattern.len) {
        return null;
    }

    var offset: usize = 0;
    outer: while (offset < mem.len - pattern.len) : (offset += 1) {
        for (pattern, 0..) |byte, j| {
            if (byte) |b| {
                if (b != mem[offset + j]) {
                    continue :outer;
                }
            }
        }
        return offset;
    }

    return null;
}

pub fn scanUnique(mem: []const u8, pattern: []const ?u8) ?usize {
    if (scanFirst(mem, pattern)) |offset| {
        if (scanFirst(mem[offset + pattern.len ..], pattern) != null) {
            return null;
        }
        return offset;
    }
    return null;
}

pub const Patterns = struct {
    name: []const u8,
    patterns: []const []const u8,
};

pub const MatchedPattern = struct {
    index: usize,
    ptr: [*]const u8,
};

pub fn scanAllPatterns(mem: []const u8, patterns: []const []const ?u8, data: *std.ArrayList(MatchedPattern)) !void {
    for (patterns, 0..) |pattern, i| {
        var base: usize = 0;
        while (scanFirst(mem[base..], pattern)) |offset| {
            try data.append(MatchedPattern{
                .index = i,
                .ptr = mem.ptr + base + offset,
            });
            base += offset + pattern.len;
        }
    }
}

pub fn scanUniquePatterns(mem: []const u8, patterns: []const []const ?u8) ?MatchedPattern {
    var match: ?MatchedPattern = null;
    for (patterns, 0..) |pattern, i| {
        if (scanUnique(mem, pattern)) |offset| {
            if (match != null) {
                return null;
            }
            match = .{
                .index = i,
                .ptr = mem.ptr + offset,
            };
        }
    }
    return match;
}

test "Scan unique patterns" {
    const mem: []const u8 = &[_]u8{ 0xF6, 0x05, 0x12, 0x34, 0x56, 0x78, 0x12 };
    const test_patterns = makePatterns(.{
        "00 00 ?? ?? 12",
        "12 ?? 56",
        "F6 05 00 34",
    });

    const result = scanUniquePatterns(mem, test_patterns[0..]);
    try testing.expect(result != null);
    if (result) |r| {
        try testing.expectEqual(1, r.index);
        try testing.expectEqual(mem.ptr + 2, r.ptr);
    }
}

pub fn loadValue(T: type, ptr: [*]const u8) T {
    const val: *align(1) const T = @ptrCast(ptr);
    return val.*;
}

test "Load value from memory" {
    const mem = makeHex("E9 B1 9A 78 56"); // jmp
    try testing.expectEqual(0x56789AB1, loadValue(u32, mem.ptr + 1));
}

pub fn getModule(module_name: []const u8) ?[]const u8 {
    const path_w = std.os.windows.sliceToPrefixedFileW(null, module_name) catch return null;
    const dll = std.os.windows.kernel32.GetModuleHandleW(path_w.span()) orelse return null;
    var info: std.os.windows.MODULEINFO = undefined;
    if (std.os.windows.kernel32.K32GetModuleInformation(std.os.windows.kernel32.GetCurrentProcess(), dll, &info, @sizeOf(std.os.windows.MODULEINFO)) == 0) {
        return null;
    }
    const mem: [*]const u8 = @ptrCast(dll);
    return mem[0..info.SizeOfImage];
}
