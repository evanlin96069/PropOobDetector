const std = @import("std");

const Feature = @import("../Feature.zig");

const modules = @import("../../modules.zig");
const tier0 = modules.tier0;
const tier1 = modules.tier1;
const engine = modules.engine;

const kuroko = @import("kuroko");
const VM = kuroko.KrkVM;
const KrkValue = kuroko.KrkValue;
const KrkString = kuroko.KrkString;
const KrkInstance = kuroko.KrkInstance;
const StringBuilder = kuroko.StringBuilder;

const vkrk_console = @import("modules/vkrk_console.zig");
const vkrk_game = @import("modules/vkrk_game.zig");

pub var feature: Feature = .{
    .name = "kuroko",
    .shouldLoad = shouldLoad,
    .init = init,
    .deinit = deinit,
};

const krk_from_file = "<console>";

var krk_path: [*:0]const u8 = undefined;

var vkrk_interpret = tier1.ConCommand.init(.{
    .name = "vkrk_interpret",
    .help_string = "Runs the text as a Kuroko script.",
    .command_callback = vkrk_interpret_Fn,
});

fn printResult(result: KrkValue) void {
    var sb: StringBuilder = std.mem.zeroes(StringBuilder);
    if (!sb.pushStringFormat(" => %R", .{result.value})) {
        VM.dumpTraceback();
    } else {
        std.log.info("{s}", .{sb.toString()});
    }
    sb.discard();
}

fn vkrk_interpret_Fn(args: *const tier1.CCommand) callconv(.C) void {
    if (args.argc != 2) {
        std.log.info("vkrk_interpret <code>", .{});
        return;
    }

    const result = VM.interpret(args.argv[1], krk_from_file);
    if (!result.isNone()) {
        VM.getInstance().builtins.fields.attachNamedValue("_", result);
        printResult(result);
    }
    VM.resetStack();
}

var vkrk_run = tier1.ConCommand.init(.{
    .name = "vkrk_run",
    .help_string = "Runs a Kuroko script file.",
    .command_callback = vkrk_run_Fn,
});

fn vkrk_run_Fn(args: *const tier1.CCommand) callconv(.C) void {
    if (args.argc != 2 or args.args(1).len == 0) {
        std.log.info("vkrk_run <file>", .{});
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
    .name = "vkrk_reset",
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

    const module = VKrkModule.createModule();
    VM.getInstance().modules.attachNamedValue("vkuroko", module.asValue());
    VM.resetStack();

    _ = VM.startModule("__main__");

    VM.push(VM.getInstance().system.asValue().getAttribute("module_paths"));
    VM.push(VM.peek(0).getAttribute("insert"));
    VM.push(KrkValue.intValue(0));

    VM.push(KrkString.copyString(krk_path).asValue());
    _ = VM.callStack(2); // module_paths.inset(0, krk_path)
    _ = VM.pop();
}

const VKrkModule = struct {
    pub fn createModule() *KrkInstance {
        const module = KrkInstance.create(VM.getInstance().base_classes.moduleClass);
        VM.push(module.asValue());
        module.fields.attachNamedValue("__name__", KrkString.copyString("vkuroko").asValue());
        module.fields.attachNamedValue("__file__", KrkValue.noneValue());

        module.setDoc("@brief Source Engine module.");

        module.fields.attachNamedValue("console", vkrk_console.createModule().asValue());
        module.fields.attachNamedValue("game", vkrk_game.createModule().asValue());

        return module;
    }
};

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

    vkrk_interpret.register();
    vkrk_run.register();
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
