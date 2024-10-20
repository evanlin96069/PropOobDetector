const std = @import("std");

const kuroko = @import("kuroko");

const Feature = @import("Feature.zig");

const modules = @import("../modules.zig");
const tier0 = modules.tier0;
const tier1 = modules.tier1;

pub var feature: Feature = .{
    .name = "Oob entity",
    .shouldLoad = shouldLoad,
    .init = init,
    .deinit = deinit,
};

var krk_run = tier1.ConCommand.init(.{
    .name = "krk_run",
    .help_string = "Runs inline kuroko script.",
    .command_callback = krk_run_Fn,
});

fn printResult(result: kuroko.KrkValue) void {
    var sb: kuroko.StringBuilder = std.mem.zeroes(kuroko.StringBuilder);
    if (!sb.pushStringFormat(" => %R", .{result.value})) {
        kuroko.KrkVM.dumpTraceback();
    } else {
        std.log.info("{s}", .{sb.toString()});
    }
    sb.discard();
}

fn krk_run_Fn(args: *const tier1.CCommand) callconv(.C) void {
    if (args.argc != 2) {
        std.log.info("krk_run <script>", .{});
        return;
    }

    const result = kuroko.KrkVM.interpret(args.argv[1], "<stdin>");
    if (!result.isNone()) {
        kuroko.KrkVM.getInstance().builtins.fields.attachNamedValue("_", result);
        printResult(result);
    }
    kuroko.KrkVM.resetStack();
}

export fn krk_fwrite(ptr: [*]const u8, size_of_type: usize, item_count: usize, stream: *std.c.FILE) usize {
    if (@intFromPtr(kuroko.krk_getStdout()) == @intFromPtr(stream)) {
        tier0.msg("%s", ptr);
        return size_of_type * item_count;
    }

    if (@intFromPtr(kuroko.krk_getStderr()) == @intFromPtr(stream)) {
        tier0.warning("%s", ptr);
        return size_of_type * item_count;
    }

    return std.c.fwrite(ptr, size_of_type, item_count, stream);
}

export fn krk_fflush(stream: *std.c.FILE) c_int {
    _ = stream;
    return 0;
}

fn shouldLoad() bool {
    return true;
}

fn init() bool {
    kuroko.KrkVM.init(.{});
    _ = kuroko.KrkVM.startModule("__main__");

    krk_run.register();

    return true;
}

fn deinit() void {
    kuroko.KrkVM.deinit();
}
