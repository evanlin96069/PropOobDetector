const std = @import("std");

const kuroko = @import("kuroko");

const Feature = @import("Feature.zig");

const modules = @import("../modules.zig");
const tier0 = modules.tier0;
const tier1 = modules.tier1;
const engine = modules.engine;

const VM = kuroko.KrkVM;
const KrkValue = kuroko.KrkValue;

pub var feature: Feature = .{
    .name = "kuroko",
    .shouldLoad = shouldLoad,
    .init = init,
    .deinit = deinit,
};

const krk_from_file = "<console>";

var krk_path: [*:0]const u8 = undefined;

var krk_interpret = tier1.ConCommand.init(.{
    .name = "krk_interpret",
    .help_string = "Runs the text as a Kuroko script.",
    .command_callback = krk_interpret_Fn,
});

fn printResult(result: KrkValue) void {
    var sb: kuroko.StringBuilder = std.mem.zeroes(kuroko.StringBuilder);
    if (!sb.pushStringFormat(" => %R", .{result.value})) {
        VM.dumpTraceback();
    } else {
        std.log.info("{s}", .{sb.toString()});
    }
    sb.discard();
}

fn krk_interpret_Fn(args: *const tier1.CCommand) callconv(.C) void {
    if (args.argc != 2) {
        std.log.info("krk_interpret <code>", .{});
        return;
    }

    const result = VM.interpret(args.argv[1], krk_from_file);
    if (!result.isNone()) {
        VM.getInstance().builtins.fields.attachNamedValue("_", result);
        printResult(result);
    }
    VM.resetStack();
}

var krk_run = tier1.ConCommand.init(.{
    .name = "krk_run",
    .help_string = "Runs a Kuroko script file.",
    .command_callback = krk_run_Fn,
});

fn krk_run_Fn(args: *const tier1.CCommand) callconv(.C) void {
    if (args.argc != 2 or args.args(1).len == 0) {
        std.log.info("krk_run <file>", .{});
        return;
    }

    const ext = ".krk";

    var path = std.ArrayList(u8).init(tier0.allocator);
    defer path.deinit();

    path.appendSlice(args.args(1)) catch return;
    if (std.fs.path.extension(path.items).len == 0) {
        path.appendSlice(ext) catch return;
    }

    if (!std.fs.path.isAbsolute(path.items)) {
        path.insertSlice(0, std.mem.span(krk_path)) catch return;
    }

    path.append(0) catch return;

    _ = VM.runFile(@ptrCast(path.items.ptr), krk_from_file);
    VM.resetStack();
}

var krk_reset = tier1.ConCommand.init(.{
    .name = "krk_reset",
    .help_string = "Resets the Kuroko VM.",
    .command_callback = krk_reset_Fn,
});

fn krk_reset_Fn(args: *const tier1.CCommand) callconv(.C) void {
    _ = args;
    resetKrkVM();
}

fn resetKrkVM() void {
    VM.deinit();
    initKrkVM();
}

fn initKrkVM() void {
    VM.init(.{});
    _ = kuroko.KrkVM.startModule("__main__");

    VM.push(VM.getInstance().system.asValue().getAttribute("module_paths"));
    VM.push(VM.peek(0).getAttribute("insert"));
    VM.push(KrkValue.intValue(0));

    VM.push(kuroko.KrkString.copyString(krk_path).asValue());
    _ = VM.callStack(2); // module_paths.inset(0, krk_path)
    _ = VM.pop();
}

fn shouldLoad() bool {
    return true;
}

var path_buf = std.mem.zeroes([256]u8);

var stdout: *std.c.FILE = undefined;
var stderr: *std.c.FILE = undefined;

fn init() bool {
    krk_path = @ptrCast((std.fmt.bufPrint(
        &path_buf,
        "{s}\\kuroko\\",
        .{engine.client.getGameDirectory()},
    ) catch return false).ptr);

    stdout = kuroko.krk_getStdout();
    stderr = kuroko.krk_getStderr();

    initKrkVM();

    krk_interpret.register();
    krk_run.register();
    krk_reset.register();

    return true;
}

fn deinit() void {
    VM.deinit();
}

export fn krk_fwrite(ptr: [*]const u8, size_of_type: usize, item_count: usize, stream: *std.c.FILE) usize {
    if (@intFromPtr(stdout) == @intFromPtr(stream)) {
        tier0.msg("%s", ptr);
        return size_of_type * item_count;
    }

    if (@intFromPtr(stderr) == @intFromPtr(stream)) {
        tier0.warning("%s", ptr);
        return size_of_type * item_count;
    }

    return std.c.fwrite(ptr, size_of_type, item_count, stream);
}

export fn krk_fflush(stream: *std.c.FILE) c_int {
    _ = stream;
    return 0;
}
