const std = @import("std");

const modules = @import("../../../modules.zig");
const engine = modules.engine;

const game_detection = @import("../../../utils/game_detection.zig");

const kuroko = @import("kuroko");
const VM = kuroko.KrkVM;
const KrkValue = kuroko.KrkValue;
const KrkString = kuroko.KrkString;
const KrkInstance = kuroko.KrkInstance;

pub fn createModule() *KrkInstance {
    const module = KrkInstance.create(VM.getInstance().base_classes.moduleClass);
    VM.push(module.asValue());
    module.fields.attachNamedValue("__name__", KrkString.copyString("game").asValue());
    module.fields.attachNamedValue("__file__", KrkValue.noneValue());

    module.setDoc("@brief Game-related functions.");

    module.bindFunction("get_game_dir", get_game_dir).setDoc(
        \\@brief Gets the absolute path to the game directory.
    );

    module.bindFunction("is_portal", is_portal).setDoc(
        \\@brief Does game looks like Portal?
    );

    return module;
}

fn get_game_dir(argc: c_int, argv: [*]const KrkValue, has_kw: c_int) callconv(.C) KrkValue {
    _ = has_kw;
    _ = argv;
    if (argc != 0) {
        return VM.getInstance().exceptions.argumentError.runtimeError("get_name() takes no arguments (%d given)", .{argc});
    }

    return KrkString.copyString(engine.client.getGameDirectory()).asValue();
}

fn is_portal(argc: c_int, argv: [*]const KrkValue, has_kw: c_int) callconv(.C) KrkValue {
    _ = has_kw;
    _ = argv;
    if (argc != 0) {
        return VM.getInstance().exceptions.argumentError.runtimeError("get_name() takes no arguments (%d given)", .{argc});
    }

    return KrkValue.boolValue(game_detection.doesGameLooksLikePortal());
}
