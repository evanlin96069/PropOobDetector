const std = @import("std");

const interfaces = @import("interfaces.zig");
const tier0 = @import("tier0.zig");

const Module = @import("modules.zig").Module;

const Virtual = std.builtin.CallingConvention.Thiscall;

pub const FCvar = packed struct(c_uint) {
    unregistered: bool = false,
    development_only: bool = false,
    game_dll: bool = false,
    client_dll: bool = false,
    hidden: bool = false,
    protected: bool = false,
    sp_only: bool = false,
    archive: bool = false,
    notify: bool = false,
    user_info: bool = false,
    printable_only: bool = false,
    unlogged: bool = false,
    never_as_string: bool = false,
    replicated: bool = false,
    cheat: bool = false,
    _pad_0: u1 = 0,
    demo: bool = false,
    dont_record: bool = false,
    _pad_1: u4 = 0,
    not_connected: bool = false,
    _pad_2: u9 = 0,
};

const ConCommandBase = extern struct {
    _vt: *align(@alignOf(*anyopaque)) const anyopaque = undefined,
    next: ?*ConCommandBase = null,
    registered: bool = false,
    name: [*:0]const u8,
    help_string: [*:0]const u8 = "",
    flags: FCvar = .{},

    const VTable = extern struct {
        destruct: *const anyopaque,
        isCommand: *const fn (this: *anyopaque) callconv(Virtual) bool,
        isFlagSet: *const anyopaque,
        addFlags: *const anyopaque,
        getName: *const anyopaque,
        getHelpText: *const anyopaque,
        isRegistered: *const anyopaque,
        getDLLIdentifier: *const fn (this: *anyopaque) callconv(Virtual) c_int,

        create: *const anyopaque,
        init: *const anyopaque,
    };

    fn getDLLIdentifier(this: *anyopaque) callconv(Virtual) c_int {
        _ = this;
        return ICvar.dll_identifier;
    }

    fn vt(self: *ConCommandBase) *const VTable {
        return @ptrCast(self._vt);
    }

    pub fn isCommand(self: *ConCommandBase) bool {
        return self.vt().isCommand(self);
    }
};

pub const CCommand = extern struct {
    argc: c_int,
    argv_0_size: c_int,
    args_buffer: [max_length]u8,
    argv_buffer: [max_length]u8,
    argv: [max_argc][*:0]const u8,

    const max_argc = 64;
    const max_length = 512;

    pub fn args(self: *const CCommand, index: usize) []const u8 {
        return std.mem.span(self.argv[index]);
    }
};

pub const ConCommand = extern struct {
    base: ConCommandBase,
    command_callback: CommandCallbackFn,
    completion_callback: ?CommandCompletionCallbackFn = null,

    callback_flags: packed struct(u8) {
        has_completion_callback: bool = false,
        using_new_command_callback: bool = true,
        using_command_callback_interface: bool = false,
        _pad_0: u5 = 0,
    } = .{},

    const CommandCallbackFn = *const fn (args: *const CCommand) callconv(.C) void;
    const CommandCompletionCallbackFn = *const fn (partial: [*:0]const u8, commands: [*][*]u8) callconv(.C) void;

    var vtable: VTable = undefined;

    const VTable = extern struct {
        base: ConCommandBase.VTable,
        autoCompleteSuggest: *const anyopaque,
        canAutoComplete: *const anyopaque,
        dispatch: *const anyopaque,
    };

    fn vt(self: *ConCommand) *const VTable {
        return @ptrCast(self.base._vt);
    }

    pub fn register(self: *ConCommand) void {
        self.base._vt = &vtable;
        icvar.registerConCommandBase(@ptrCast(self));
    }
};

const IConVar = extern struct {
    _vt: *align(@alignOf(*anyopaque)) const anyopaque = &vtable,

    var vtable: VTable = undefined;

    const VTable = extern struct {
        setInt: *const fn (this: *anyopaque, value: c_int) callconv(Virtual) void,
        setFloat: *const fn (this: *anyopaque, value: f32) callconv(Virtual) void,
        setString: *const fn (this: *anyopaque, value: [*:0]const u8) callconv(Virtual) void,
        getName: *const anyopaque,
        isFlagSet: *const anyopaque,
    };
};

pub const ConVar = extern struct {
    base1: ConCommandBase,
    base2: IConVar = .{},
    parent: *ConVar = undefined,
    default_value: [*:0]const u8 = "",

    // Dynamically allocated
    string_value: ?[*:0]u8 = null,
    string_length: c_int = 0,

    float_value: f32 = 0.0,
    int_value: c_int = 0,

    has_min: bool = false,
    min_value: f32 = 0.0,
    has_max: bool = false,
    max_value: f32 = 0.0,

    change_callback: ?ChangeCallbackFn = null,

    const ChangeCallbackFn = *const fn (cvar: *IConVar, old_string: [*:0]const u8, old_value: f32) callconv(.C) void;

    var vtable: extern struct {
        rtti: *const anyopaque,
        vtable: VTable,
    } = undefined;

    const VTable = extern struct {
        base: ConCommandBase.VTable,
        _setString: *const anyopaque,
        _setFloat: *const anyopaque,
        _setInt: *const anyopaque,
        clampValue: *const anyopaque,
        changeStringValue: *const anyopaque,
        create: *const fn (
            this: *anyopaque,
            name: [*:0]const u8,
            default_value: [*:0]const u8,
            flags: FCvar,
            help_string: [*:0]const u8,
            has_min: bool,
            min_value: f32,
            has_max: bool,
            max_value: f32,
            callback: ?ChangeCallbackFn,
        ) callconv(Virtual) void,
    };

    fn vt1(self: *ConVar) *const VTable {
        return @ptrCast(self.base1._vt);
    }

    fn vt2(self: *ConVar) *const IConVar.VTable {
        return @ptrCast(self.base2._vt);
    }

    fn register(self: *ConVar) void {
        self.base1._vt = &ConVar.vtable.vtable;

        self.vt1().create(
            self,
            self.base1.name,
            self.default_value,
            self.base1.flags,
            self.base1.help_string,
            self.has_min,
            self.min_value,
            self.has_max,
            self.max_value,
            self.change_callback,
        );

        icvar.registerConCommandBase(@ptrCast(self));
    }

    pub fn getString(self: *ConVar) [:0]const u8 {
        if (self.base1.flags.never_as_string) {
            return "FCVAR_NEVER_AS_STRING";
        }

        if (self.parent.string_value) |s| {
            return std.mem.span(s);
        }

        return "";
    }

    pub fn getFloat(self: *ConVar) f32 {
        return self.parent.float_value;
    }

    pub fn getInt(self: *ConVar) i32 {
        return @intCast(self.parent.int_value);
    }

    pub fn getBool(self: *ConVar) bool {
        return self.getInt() != 0;
    }

    pub fn setString(self: *ConVar, value: [*:0]const u8) void {
        self.vt2().setString(&self.base2, value);
    }

    pub fn setFloat(self: *ConVar, value: f32) void {
        self.vt2().setFloat(&self.base2, value);
    }

    pub fn setInt(self: *ConVar, value: i32) void {
        self.vt2().setInt(&self.base2, @intCast(value));
    }
};

pub const Variable = extern struct {
    cvar: ConVar,
    next: ?*Variable = null,

    var head: ?*Variable = null;

    pub fn register(self: *Variable) void {
        self.cvar.register();

        self.next = Variable.head;
        Variable.head = self;
    }

    pub fn getString(self: *Variable) [:0]const u8 {
        return self.cvar.getString();
    }

    pub fn getFloat(self: *Variable) f32 {
        return self.cvar.getFloat();
    }

    pub fn getInt(self: *Variable) i32 {
        return self.cvar.getInt();
    }

    pub fn getBool(self: *Variable) bool {
        return self.cvar.getBool();
    }

    pub fn setString(self: *Variable, value: [*:0]const u8) void {
        self.cvar.setString(value);
    }

    pub fn setFloat(self: *Variable, value: f32) void {
        self.cvar.setFloat(value);
    }

    pub fn setInt(self: *Variable, value: i32) void {
        self.cvar.setInt(value);
    }
};

const ICvar = extern struct {
    _vt: *align(@alignOf(*anyopaque)) const anyopaque,

    const VTable = extern struct {
        base: interfaces.IAppSystem.VTable,

        allocateDLLIDentifier: *const fn (this: *anyopaque) callconv(Virtual) c_int,

        registerConCommandBase: *const fn (this: *anyopaque, cmd: *ConCommandBase) callconv(Virtual) void,
        unregisterConCommand: *const anyopaque,
        unregisterConCommands: *const fn (this: *anyopaque, id: c_int) callconv(Virtual) void,

        getCommandLineValue: *const anyopaque,

        findCommandBaseConst: *const anyopaque,
        findCommandBase: *const fn (this: *anyopaque, name: [*:0]const u8) callconv(Virtual) ?*ConCommandBase,
        findVarConst: *const anyopaque,
        findVar: *const fn (this: *anyopaque, name: [*:0]const u8) callconv(Virtual) ?*ConVar,
        findCommandConst: *const anyopaque,
        findCommand: *const fn (this: *anyopaque, name: [*:0]const u8) callconv(Virtual) ?*ConCommand,

        getCommandsConst: *const anyopaque,
        getCommands: *const fn (this: *anyopaque) callconv(Virtual) *ConCommandBase,

        installGlobalChangeCallback: *const anyopaque,
        removeGlobalChangeCallback: *const anyopaque,
        callGlobalChangeCallbacks: *const anyopaque,

        installConsoleDisplayFunc: *const anyopaque,
        removeConsoleDisplayFunc: *const anyopaque,
        consoleColorPrintf: *const anyopaque,
        consolePrintf: *const anyopaque,
        consoleDPrintf: *const anyopaque,

        revertFlaggedConVar: *const anyopaque,
        installCVarQuery: *const anyopaque,
    };

    var dll_identifier: c_int = undefined;

    fn vt(self: *ICvar) *const VTable {
        return @ptrCast(self._vt);
    }

    fn allocateDLLIDentifier(self: *ICvar) void {
        dll_identifier = self.vt().allocateDLLIDentifier(self);
    }

    fn unregisterConCommands(self: *ICvar) void {
        self.vt().unregisterConCommands(self, dll_identifier);
    }

    fn registerConCommandBase(self: *ICvar, cmd: *ConCommandBase) void {
        self.vt().registerConCommandBase(self, cmd);
        cmd.registered = true;
    }

    pub fn findCommandBase(self: *ICvar, name: [*:0]const u8) ?*ConCommandBase {
        return self.vt().findCommandBase(self, name);
    }

    pub fn findVar(self: *ICvar, name: [*:0]const u8) ?*ConVar {
        return self.vt().findVar(self, name);
    }

    pub fn findCommand(self: *ICvar, name: [*:0]const u8) ?*ConCommand {
        return self.vt().findCommand(self, name);
    }
};

pub var icvar: *ICvar = undefined;

const cvars: []const *ConCommandBase = vars: {
    var vars: []const *ConCommandBase = &.{};
    for (&.{
        @import("main.zig"),
    }) |file| {
        for (@typeInfo(file).Struct.decls) |decl| {
            const decl_ptr = &@field(file, decl.name);
            const decl_type = @TypeOf(decl_ptr.*);
            if (decl_type == ConCommand or decl_type == ConVar) {
                const base: *ConCommandBase = @ptrCast(decl_ptr);
                vars = vars ++ .{base};
            }
        }
    }
    break :vars vars;
};

pub var module: Module = .{
    .init = init,
    .deinit = deinit,
};

fn init() void {
    module.loaded = false;

    icvar = @ptrCast(interfaces.engineFactory("VEngineCvar004", null) orelse {
        std.log.err("Failed to get ICvar interface", .{});
        return;
    });

    icvar.allocateDLLIDentifier();

    const cvar = icvar.findVar("sv_gravity") orelse {
        std.log.err("Failed to get ConVar vtable", .{});
        return;
    };
    const cmd = icvar.findCommand("kill") orelse {
        std.log.err("Failed to get ConCommand vtable", .{});
        return;
    };

    // Stealing vtables from existing command and cvar
    const cvar_vt_ptr: *const ConVar.VTable = @ptrCast(cvar.base1._vt);
    ConVar.vtable.vtable = cvar_vt_ptr.*;
    ConVar.vtable.vtable.base.getDLLIdentifier = ConCommandBase.getDLLIdentifier;
    const iconvar_vt_ptr: *const IConVar.VTable = @ptrCast(cvar.base2._vt);
    IConVar.vtable = iconvar_vt_ptr.*;
    const rtti_ptr: [*]const *const anyopaque = @ptrCast(cvar.base1._vt);
    ConVar.vtable.rtti = (rtti_ptr - 1)[0];

    const cmd_vt_ptr: *const ConCommand.VTable = @ptrCast(cmd.base._vt);
    ConCommand.vtable = cmd_vt_ptr.*;
    ConCommand.vtable.base.getDLLIdentifier = ConCommandBase.getDLLIdentifier;

    module.loaded = true;
}

fn deinit() void {
    icvar.unregisterConCommands();
    var it = Variable.head;
    while (it) |curr| : (it = curr.next) {
        if (curr.cvar.string_value) |s| {
            tier0.allocator.free(std.mem.span(s));
        }
    }
}
