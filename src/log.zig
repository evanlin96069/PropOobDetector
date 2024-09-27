const std = @import("std");

const tier0 = @import("modules.zig").tier0;

const Context = struct {
    fmtFn: tier0.FmtFn,
};

fn writeFn(context: Context, bytes: []const u8) error{}!usize {
    if (bytes[0] == 0x1B) {
        // Console color code, possibly from a stack trace.
        // Ignore up to the terminating 'm'
        if (std.mem.indexOfScalar(u8, bytes, 'm')) |len| {
            return len + 1;
        }
    }
    context.fmtFn("%.*s", bytes.len, bytes.ptr);
    return bytes.len;
}

var log_mutex: std.Thread.Mutex = .{};

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    if (!tier0.module.loaded) return;

    const scope_prefix = if (scope == .default) "" else ("[" ++ @tagName(scope) ++ "] ");
    const context: Context = switch (level) {
        .err => .{ .fmtFn = tier0.warning },
        .warn => .{ .fmtFn = tier0.warning },
        .info => .{ .fmtFn = tier0.msg },
        .debug => .{ .fmtFn = tier0.devMsg },
    };

    log_mutex.lock();
    defer log_mutex.unlock();

    std.fmt.format(
        std.io.Writer(Context, error{}, writeFn){ .context = context },
        scope_prefix ++ format ++ "\n",
        args,
    ) catch unreachable;
}
