const std = @import("std");

const modules = @import("../../../modules.zig");
const tier0 = modules.tier0;
const tier1 = modules.tier1;
const engine = modules.engine;

const kuroko = @import("kuroko");
const VM = kuroko.KrkVM;
const KrkValue = kuroko.KrkValue;
const KrkString = kuroko.KrkString;
const KrkInstance = kuroko.KrkInstance;

pub fn createModule() *KrkInstance {
    const module = KrkInstance.create(VM.getInstance().base_classes.moduleClass);
    VM.push(module.asValue());
    module.fields.attachNamedValue("__name__", KrkString.copyString("console").asValue());
    module.fields.attachNamedValue("__file__", KrkValue.noneValue());

    module.setDoc("@brief Console operations.");
    module.bindFunction("exec", exec).setDoc(
        \\@brief Runs a console command.
        \\@arguments command
        \\
        \\Runs @p command using `IVEngineClient::ClientCmd`.
    );

    return module;
}

fn exec(argc: c_int, argv: [*]const KrkValue, has_kw: c_int) callconv(.C) KrkValue {
    var cmd: [*:0]const u8 = undefined;
    if (!kuroko.parseArgs(
        "exec",
        argc,
        argv,
        has_kw,
        "s",
        &.{"command"},
        .{&cmd},
    )) {
        return KrkValue.noneValue();
    }

    engine.client.clientCmd(cmd);

    return KrkValue.noneValue();
}
