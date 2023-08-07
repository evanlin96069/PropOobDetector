const std = @import("std");

const interfaces = @import("interfaces.zig");

const Virtual = std.builtin.CallingConvention.Thiscall;

pub const FCvar = packed struct(c_uint) {
    unregistered: bool = false,
    _launcher: bool = false,
    _game_dll: bool = false,
    _client_dll: bool = false,
    _material_system: bool = false,
    protected: bool = false,
    sponly: bool = false,
    archive: bool = false,
    notify: bool = false,
    userinfo: bool = false,
    printable_only: bool = false,
    unlogged: bool = false,
    never_as_string: bool = false,
    replicated: bool = false,
    cheat: bool = false,
    _studiorender: bool = false,
    demo: bool = false,
    dont_record: bool = false,
    _plugin: bool = false,
    _datacache: bool = false,
    _tool_system: bool = false,
    _files_ystem: bool = false,
    not_connected: bool = false,
    _sound_system: bool = false,
    acrhive_xbox: bool = false,
    input_system: bool = false,
    _network_system: bool = false,
    _vphysics: bool = false,
    _available: u4 = 0,

    fn setPluginFlag(self: *FCvar) void {
        // We use `create` to register commands/cvars,
        // it will set the gamm dll flag since we steal the vtable from it.
        // We want to remove it and add the plugin flag.
        self._launcher = false;
        self._game_dll = false;
        self._client_dll = false;
        self._material_system = false;
        self._studiorender = false;
        self._plugin = true;
        self._datacache = false;
        self._tool_system = false;
        self._files_ystem = false;
        self._sound_system = false;
        self._network_system = false;
        self._vphysics = false;
    }
};

pub const ConCommandBase = extern struct {
    _vt: *align(4) const anyopaque = undefined,
    next: ?*ConCommandBase = null,
    registered: bool = false,
    name: [*:0]const u8,
    help_str: [*:0]const u8 = "",
    flags: FCvar = .{},

    const VTable = extern struct {
        destruct: *const anyopaque,
        isCommand: *const fn (this: *anyopaque) callconv(Virtual) bool,
        isBitSet: *const anyopaque,
        addFlags: *const anyopaque,
        getName: *const anyopaque,
        getHelpText: *const anyopaque,
        isRegistered: *const anyopaque,

        create: *const anyopaque,
        init: *const anyopaque,
    };

    fn vt(self: *ConCommandBase) *const VTable {
        return @ptrCast(self._vt);
    }

    pub fn isCommand(self: *ConCommandBase) bool {
        return self.vt().isCommand(self);
    }
};

pub const ConCommand = extern struct {
    base: ConCommandBase,
    command_callback: CommandCallbackFn,
    completion_callback: ?CommandCompletionCallbackFn = null,
    has_completion_callback: bool = false,

    const CommandCallbackFn = *const fn () callconv(.C) void;
    const CommandCompletionCallbackFn = *const fn (partial: [*:0]const u8, commands: [*][*]u8) callconv(.C) void;

    var vtable: *align(4) const anyopaque = undefined;

    const VTable = extern struct {
        base: ConCommandBase.VTable,
        autoCompleteSuggest: *const anyopaque,
        canAutoComplete: *const anyopaque,

        dispatch: *const anyopaque,
        create: *const fn (this: *anyopaque, name: [*:0]const u8, callback: CommandCallbackFn, help_str: [*:0]const u8, flags: FCvar, completion_func: ?CommandCompletionCallbackFn) callconv(Virtual) void,
    };

    fn vt(self: *ConCommand) *const VTable {
        return @ptrCast(self.base._vt);
    }

    pub fn register(self: *ConCommand) void {
        self.base._vt = vtable;
        self.vt().create(self, self.base.name, self.command_callback, self.base.help_str, self.base.flags, self.completion_callback);
        self.base.flags.setPluginFlag();
    }
};

pub const ConVar = extern struct {
    base: ConCommandBase,
    parent: ?*ConVar = null,
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

    const ChangeCallbackFn = *const fn (cvar: *ConVar, old_string: [*:0]const u8) callconv(.C) void;

    var vtable: *align(4) const anyopaque = undefined;

    const VTable = extern struct {
        base: ConCommandBase.VTable,
        setInt: *const fn (this: *anyopaque, value: c_int) callconv(Virtual) void,
        setFloat: *const fn (this: *anyopaque, value: f32) callconv(Virtual) void,
        setString: *const fn (this: *anyopaque, value: [*:0]const u8) callconv(Virtual) void,

        _setInt: *const anyopaque,
        _setFloat: *const anyopaque,
        _setString: *const anyopaque,
        clampValue: *const anyopaque,
        changeStringValue: *const anyopaque,
        create: *const fn (this: *anyopaque, name: [*:0]const u8, default_value: [*:0]const u8, flags: FCvar, help_str: [*:0]const u8, has_min: bool, min_value: f32, has_max: bool, max_value: f32, callback: ?ChangeCallbackFn) callconv(Virtual) void,
    };

    fn vt(self: *ConVar) *const VTable {
        return @ptrCast(self.base._vt);
    }

    pub fn register(self: *ConVar) void {
        self.base._vt = vtable;
        // Using the tier0 Alloc to allocate the cvar string will crash, so we just use create.
        self.vt().create(self, self.base.name, self.default_value, self.base.flags, self.base.help_str, self.has_min, self.min_value, self.has_max, self.max_value, self.change_callback);
        self.base.flags.setPluginFlag();
    }

    pub fn getString(self: *ConVar) [*:0]const u8 {
        if (self.base.flags.never_as_string) {
            return "FCVAR_NEVER_AS_STRING";
        }

        return self.parent.string_value orelse "";
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
        self.vt().setString(self, value);
    }

    pub fn setFloat(self: *ConVar, value: f32) void {
        self.vt().setFloat(self, value);
    }

    pub fn setInt(self: *ConVar, value: i32) void {
        self.vt().setInt(self, @intCast(value));
    }
};

const ICvar = extern struct {
    _vt: *align(4) const anyopaque,

    const VTable = extern struct {
        base: interfaces.IAppSystem.VTable,
        registerConCommandBase: *const anyopaque,
        getCommandLineValue: *const anyopaque,
        findVar: *const fn (this: *anyopaque, name: [*:0]const u8) callconv(Virtual) ?*ConVar,
        findVarConst: *const anyopaque,
        getCommands: *const fn (this: *anyopaque) callconv(Virtual) *ConCommandBase,
        unlinkVariables: *const anyopaque,
        installGlobalChangeCallback: *const anyopaque,
        callGlobalChangeCallback: *const anyopaque,
    };

    fn vt(self: *ICvar) *const VTable {
        return @ptrCast(self._vt);
    }

    pub fn findVar(self: *ICvar, name: [*:0]const u8) ?*ConVar {
        return self.vt().findVar(self, name);
    }

    fn getCommands(self: *ICvar) *ConCommandBase {
        return self.vt().getCommands(self);
    }

    pub fn findCommand(self: *ICvar, name: [*:0]const u8) ?*ConCommandBase {
        var it: ?*ConCommandBase = self.getCommands();
        while (it) |cmd| : (it = cmd.next) {
            if (std.mem.eql(u8, std.mem.span(name), std.mem.span(cmd.name))) {
                return cmd;
            }
        }
        return null;
    }

    fn getGlobalCommandListHead(self: *ICvar) ?*?*ConCommandBase {
        var addr: [*]const u8 = @ptrCast(self.vt().getCommands);

        // JMPIW
        if (addr[0] != 0xE9) return null;
        const offset: *align(1) const u32 = @ptrCast(addr + 1);
        addr += 5 + offset.*;

        // MOVEAXII
        if (addr[0] != 0xA1) return null;

        const head: *align(1) const *?*ConCommandBase = @ptrCast(addr + 1);
        return head.*;
    }
};

pub var icvar: *ICvar = undefined;

pub fn init() bool {
    icvar = @ptrCast(interfaces.engineFactory("VEngineCvar003", null) orelse {
        std.log.err("Failed to get ICvar interface", .{});
        return false;
    });

    const cvar = icvar.findVar("sv_gravity") orelse {
        std.log.err("Failed to get ConVar vtable", .{});
        return false;
    };
    const cmd = icvar.findCommand("kill") orelse {
        std.log.err("Failed to get ConCommand vtable", .{});
        return false;
    };

    // Stealing vtables from existing command and cvar
    ConVar.vtable = cvar.base._vt;
    ConCommand.vtable = cmd._vt;

    return true;
}

pub fn deinit() void {
    var head: *?*ConCommandBase = icvar.getGlobalCommandListHead() orelse return;
    var prev: ?*ConCommandBase = null;
    var it: ?*ConCommandBase = head.*;
    while (it) |cmd| : (it = cmd.next) {
        var found = false;
        if (cmd.flags._plugin) {
            for (cvars) |cvar| {
                if (cmd == cvar) {
                    found = true;
                    break;
                }
            }
        }

        if (!found) {
            prev = cmd;
            continue;
        }

        if (prev) |_prev| {
            _prev.next = cmd.next;
        } else {
            head.* = cmd.next;
        }
        // We probably need to free the cvar string, but calling the destructor crashes...
    }
}

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
