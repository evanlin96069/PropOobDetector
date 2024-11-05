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
const KrkClass = kuroko.KrkClass;

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
    module.bindFunction("find_var", find_var).setDoc(
        \\@brief Finds a ConVar.
        \\@arguments var_name
        \\@return `ConVar` if found, `None` if not found.
    );

    ConVar.class = KrkClass.makeClass(module, ConVar, "ConVar", null);
    ConVar.class.setDoc("Interface to a ConVar.");
    ConVar.class.alloc_size = @sizeOf(ConVar);
    ConVar.class.bindMethod("get_name", ConVar.get_name).setDoc(
        \\@brief Get the name of the ConVar.
    );
    ConVar.class.bindMethod("get_default", ConVar.get_default).setDoc(
        \\@brief Get the default string value of the ConVar.
    );
    ConVar.class.bindMethod("set_val", ConVar.set_val).setDoc(
        \\@brief Set the value of the ConVar.
        \\@arguments value
        \\
        \\@p value can be str, float, int, or bool.
    );
    ConVar.class.bindMethod("get_string", ConVar.get_string).setDoc(
        \\@brief Get the string value of the ConVar.
    );
    ConVar.class.bindMethod("get_float", ConVar.get_float).setDoc(
        \\@brief Get the float value of the ConVar.
    );
    ConVar.class.bindMethod("get_int", ConVar.get_int).setDoc(
        \\@brief Get the int value of the ConVar.
    );
    ConVar.class.bindMethod("get_bool", ConVar.get_bool).setDoc(
        \\@brief Get the bool value of the ConVar.
    );
    _ = ConVar.class.bindMethod("__repr__", ConVar.__repr__);
    ConVar.class.bindMethod("__init__", ConVar.__init__).setDoc(
        \\@note ConVar objects can not be initialized using this constructor.
    );
    ConVar.class.finalizeClass();

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

fn find_var(argc: c_int, argv: [*]const KrkValue, has_kw: c_int) callconv(.C) KrkValue {
    var var_name: [*:0]const u8 = undefined;
    if (!kuroko.parseArgs(
        "exec",
        argc,
        argv,
        has_kw,
        "s",
        &.{"var_name"},
        .{&var_name},
    )) {
        return KrkValue.noneValue();
    }

    const cvar = tier1.icvar.findVar(var_name) orelse {
        return KrkValue.noneValue();
    };

    const inst = KrkInstance.create(ConVar.class);
    const cvar_inst: *ConVar = @ptrCast(inst);
    cvar_inst.cvar = cvar;

    return inst.asValue();
}

const ConVar = extern struct {
    inst: KrkInstance,
    cvar: *tier1.ConVar,

    var class: *KrkClass = undefined;

    fn isConVar(v: KrkValue) bool {
        return v.isInstanceOf(class);
    }

    fn asConVar(v: KrkValue) *ConVar {
        return @ptrCast(v.asObject());
    }

    fn __repr__(argc: c_int, argv: [*]const KrkValue, has_kw: c_int) callconv(.C) KrkValue {
        _ = has_kw;
        if (argc != 1) {
            return VM.getInstance().exceptions.argumentError.runtimeError("get_name() takes no arguments (%d given)", .{argc - 1});
        }

        const self = asConVar(argv[0]);
        return KrkValue.stringFromFormat("<ConVar %s at %p>", .{ self.cvar.base1.name, @intFromPtr(self) });
    }

    fn __init__(argc: c_int, argv: [*]const KrkValue, has_kw: c_int) callconv(.C) KrkValue {
        _ = argc;
        _ = argv;
        _ = has_kw;
        return VM.getInstance().exceptions.typeError.runtimeError("ConVar objects can not be instantiated.", .{});
    }

    fn get_name(argc: c_int, argv: [*]const KrkValue, has_kw: c_int) callconv(.C) KrkValue {
        _ = has_kw;
        if (argc != 1) {
            return VM.getInstance().exceptions.argumentError.runtimeError("get_name() takes no arguments (%d given)", .{argc - 1});
        }

        const self = asConVar(argv[0]);
        return KrkString.copyString(self.cvar.base1.name).asValue();
    }

    fn get_default(argc: c_int, argv: [*]const KrkValue, has_kw: c_int) callconv(.C) KrkValue {
        _ = has_kw;
        if (argc != 1) {
            return VM.getInstance().exceptions.argumentError.runtimeError("get_default() takes no arguments (%d given)", .{argc - 1});
        }

        const self = asConVar(argv[0]);
        return KrkString.copyString(self.cvar.default_value).asValue();
    }

    fn set_val(argc: c_int, argv: [*]const KrkValue, has_kw: c_int) callconv(.C) KrkValue {
        _ = has_kw;
        if (argc != 2) {
            return VM.getInstance().exceptions.argumentError.runtimeError("set_val() takes exactly 1 argument (%d given)", .{argc - 1});
        }

        const self = asConVar(argv[0]);

        const value = argv[1];
        if (value.isString()) {
            self.cvar.setString(value.asCString());
        } else if (value.isFloat()) {
            self.cvar.setFloat(@floatCast(value.asFloat()));
        } else if (value.isInt()) {
            self.cvar.setInt(@intCast(value.asInt()));
        } else if (value.isBool()) {
            self.cvar.setInt(@intFromBool(value.asBool()));
        } else {
            return VM.getInstance().exceptions.typeError.runtimeError("bad value type for set_val()", .{});
        }

        return KrkValue.noneValue();
    }

    fn get_string(argc: c_int, argv: [*]const KrkValue, has_kw: c_int) callconv(.C) KrkValue {
        _ = has_kw;
        if (argc != 1) {
            return VM.getInstance().exceptions.argumentError.runtimeError("get_string() takes no arguments (%d given)", .{argc - 1});
        }

        const self = asConVar(argv[0]);
        return KrkString.copyString(self.cvar.getString()).asValue();
    }

    fn get_float(argc: c_int, argv: [*]const KrkValue, has_kw: c_int) callconv(.C) KrkValue {
        _ = has_kw;
        if (argc != 1) {
            return VM.getInstance().exceptions.argumentError.runtimeError("get_float() takes no arguments (%d given)", .{argc - 1});
        }

        const self = asConVar(argv[0]);
        return KrkValue.floatValue(self.cvar.getFloat());
    }

    fn get_int(argc: c_int, argv: [*]const KrkValue, has_kw: c_int) callconv(.C) KrkValue {
        _ = has_kw;
        if (argc != 1) {
            return VM.getInstance().exceptions.argumentError.runtimeError("get_int() takes no arguments (%d given)", .{argc - 1});
        }

        const self = asConVar(argv[0]);
        return KrkValue.intValue(self.cvar.getInt());
    }

    fn get_bool(argc: c_int, argv: [*]const KrkValue, has_kw: c_int) callconv(.C) KrkValue {
        _ = has_kw;
        if (argc != 1) {
            return VM.getInstance().exceptions.argumentError.runtimeError("get_bool() takes no arguments (%d given)", .{argc - 1});
        }

        const self = asConVar(argv[0]);
        return KrkValue.boolValue(self.cvar.getBool());
    }
};
