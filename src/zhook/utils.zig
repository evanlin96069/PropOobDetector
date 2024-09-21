const std = @import("std");

pub inline fn isHex(c: u8) bool {
    return (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F');
}

pub fn makeHex(comptime str: []const u8) []const u8 {
    return comptime blk: {
        @setEvalBranchQuota(10000);
        var it = std.mem.splitSequence(u8, str, " ");
        var pat: []const u8 = &.{};

        while (it.next()) |byte| {
            if (byte.len != 2) {
                @compileError("Each byte should be 2 characters");
            }
            if (isHex(byte[0])) {
                if (!isHex(byte[1])) {
                    @compileError("The second hex digit is missing");
                }
                const n = try std.fmt.parseInt(u8, byte, 16);
                pat = pat ++ .{n};
            } else {
                @compileError("Only hex digits are allowed");
            }
        }
        break :blk pat;
    };
}
