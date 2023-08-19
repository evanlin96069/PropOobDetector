const std = @import("std");

const interfaces = @import("interfaces.zig");
const modules = @import("modules.zig");
const hook = @import("hook.zig");

const Virtual = std.builtin.CallingConvention.Thiscall;

pub var module = modules.Module{
    .init = init,
    .deinit = deinit,
};

const Panel = extern struct {
    _vt: [*]*const anyopaque,

    const VTIndex = struct {
        const setEnabled = 67;
        const paint: usize = 123;
    };

    var origPaint: *const fn (this: *anyopaque) callconv(Virtual) void = undefined;

    fn setEnabled(self: *Panel, state: bool) void {
        const _setEnabled: *const fn (this: *anyopaque, state: bool) callconv(Virtual) void = @ptrCast(self._vt[VTIndex.setEnabled]);
        _setEnabled(self, state);
    }

    fn hookedPaint(this: *Panel) callconv(Virtual) void {
        if (this == toolspanel) {
            imatsystem.drawSetColor(.{ .r = 0, .g = 255, .b = 255 });
            imatsystem.drawFilledRect(0, 0, 200, 100);
        }
        origPaint(this);
    }
};

const IEngineVGui = extern struct {
    _vt: *align(@alignOf(*anyopaque)) const anyopaque = undefined,

    const VTable = extern struct {
        destruct: *const anyopaque,
        getPanel: *const fn (this: *anyopaque, panel_type: c_int) callconv(Virtual) c_uint,
        isGameUIVisible: *const fn (this: *anyopaque) callconv(Virtual) bool,
    };

    fn vt(self: *IEngineVGui) *const VTable {
        return @ptrCast(self._vt);
    }

    pub fn isGameUIVisible(self: *IEngineVGui) bool {
        return self.vt().isGameUIVisible(self);
    }

    fn findEngineToolsPanel(self: *IEngineVGui) bool {
        var addr: [*]const u8 = @ptrCast(self.vt().getPanel);

        // MOV
        if (addr[0] != 0x8B) {
            return false;
        }
        addr += 5;

        // CALL
        if (addr[0] != 0xE8) {
            return false;
        }
        addr += 1;
        const offset: *align(1) const u32 = @ptrCast(addr);
        addr += 4;

        const getRootPanel: *const fn (this: *anyopaque, panel_type: c_int) callconv(Virtual) *Panel = @ptrCast(addr + offset.*);
        toolspanel = getRootPanel(self, 3);
        return true;
    }
};

const Color = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
};

const IMatSystemSurface = extern struct {
    _vt: [*]*const anyopaque,

    const VTIndex = struct {
        const drawSetColor: usize = 10;
        const drawFilledRect: usize = 12;
        const drawOutlinedRect: usize = 14;
        const drawLine: usize = 15;
        const drawSetTextFont: usize = 17;
        const drawSetTextColor: usize = 18;
        const drawSetTextPos: usize = 20;
        const drawPrintText: usize = 22;
        var getScreenSize: usize = undefined;
        var getFontTall: usize = undefined;
        var getTextSize: usize = undefined;
    };

    pub fn drawSetColor(self: *IMatSystemSurface, color: Color) void {
        const _drawSetColor: *const fn (this: *anyopaque, color: Color) callconv(Virtual) void = @ptrCast(self._vt[VTIndex.drawSetColor]);
        _drawSetColor(self, color);
    }

    pub fn drawFilledRect(self: *IMatSystemSurface, x0: c_int, y0: c_int, x1: c_int, y1: c_int) void {
        const _drawFilledRect: *const fn (this: *anyopaque, x0: c_int, y0: c_int, x1: c_int, y1: c_int) callconv(Virtual) void = @ptrCast(self._vt[VTIndex.drawFilledRect]);
        _drawFilledRect(self, x0, y0, x1, y1);
    }

    pub fn drawOutlinedRect(self: *IMatSystemSurface, x0: c_int, y0: c_int, x1: c_int, y1: c_int) void {
        const _drawOutlinedRect: *const fn (this: *anyopaque, x0: c_int, y0: c_int, x1: c_int, y1: c_int) callconv(Virtual) void = @ptrCast(self._vt[VTIndex.drawOutlinedRect]);
        _drawOutlinedRect(self, x0, y0, x1, y1);
    }

    pub fn drawLine(self: *IMatSystemSurface, x0: c_int, y0: c_int, x1: c_int, y1: c_int) void {
        const _drawLine: *const fn (this: *anyopaque, x0: c_int, y0: c_int, x1: c_int, y1: c_int) callconv(Virtual) void = @ptrCast(self._vt[VTIndex.drawLine]);
        _drawLine(self, x0, y0, x1, y1);
    }

    pub fn drawSetTextFont(self: *IMatSystemSurface, font: c_ulong) void {
        const _drawSetTextFont: *const fn (this: *anyopaque, font: c_ulong) callconv(Virtual) void = @ptrCast(self._vt[VTIndex.drawSetTextFont]);
        _drawSetTextFont(self, font);
    }

    pub fn drawSetTextColor(self: *IMatSystemSurface, color: Color) void {
        const _drawSetTextColor: *const fn (this: *anyopaque, color: Color) callconv(Virtual) void = @ptrCast(self._vt[VTIndex.drawSetTextColor]);
        _drawSetTextColor(self, color);
    }

    pub fn drawSetTextPos(self: *IMatSystemSurface, x: c_int, y: c_int) void {
        const _drawSetTextPos: *const fn (this: *anyopaque, x: c_int, y: c_int) callconv(Virtual) void = @ptrCast(self._vt[VTIndex.drawSetTextPos]);
        _drawSetTextPos(self, x, y);
    }
};

const ISchemeManager = extern struct {
    _vt: [*]*const anyopaque,

    const VTIndex = struct {
        const getDefaultScheme: usize = 4;
        const getIScheme: usize = 8;
    };

    fn getDefaultScheme(self: *ISchemeManager) c_ulong {
        const _getDefaultScheme: *const fn (this: *anyopaque) callconv(Virtual) c_ulong = @ptrCast(self._vt[VTIndex.getDefaultScheme]);
        return _getDefaultScheme(self);
    }

    fn getIScheme(self: *ISchemeManager, font: c_ulong) *IScheme {
        const _getIScheme: *const fn (this: *anyopaque, font: c_ulong) callconv(Virtual) *IScheme = @ptrCast(self._vt[VTIndex.getIScheme]);
        return _getIScheme(self, font);
    }
};

const IScheme = extern struct {
    _vt: [*]*const anyopaque,

    const VTIndex = struct {
        const getFont: usize = 3;
    };

    pub fn getFont(self: *IScheme, name: [*:0]const u8, proportional: bool) c_ulong {
        const _getFont: *const fn (this: *anyopaque, name: [*:0]const u8, proportional: bool) callconv(Virtual) c_ulong = @ptrCast(self._vt[VTIndex.getFont]);
        return _getFont(self, name, proportional);
    }
};

pub var imatsystem: *IMatSystemSurface = undefined;
pub var ienginevgui: *IEngineVGui = undefined;
var toolspanel: *Panel = undefined;
var ischeme_mgr: *ISchemeManager = undefined;
pub var ischeme: *IScheme = undefined;

fn init() void {
    module.loaded = false;

    const imatsystem_info = interfaces.create(interfaces.engineFactory, "MatSystemSurface", .{ 6, 8 }) orelse {
        std.log.err("Failed to get IMatSystem interface", .{});
        return;
    };
    imatsystem = @ptrCast(imatsystem_info.interface);
    switch (imatsystem_info.version) {
        6 => {
            IMatSystemSurface.VTIndex.getScreenSize = 37;
            IMatSystemSurface.VTIndex.getFontTall = 67;
            IMatSystemSurface.VTIndex.getTextSize = 72;
        },
        8 => {
            IMatSystemSurface.VTIndex.getScreenSize = 38;
            IMatSystemSurface.VTIndex.getFontTall = 69;
            IMatSystemSurface.VTIndex.getTextSize = 75;
        },
        else => unreachable,
    }

    ienginevgui = @ptrCast(interfaces.engineFactory("VEngineVGui001", null) orelse {
        std.log.err("Failed to get IEngineVgui interface", .{});
        return;
    });

    if (!ienginevgui.findEngineToolsPanel()) {
        std.log.err("Failed to find tools panel", .{});
        return;
    }

    toolspanel.setEnabled(true);

    Panel.origPaint = @ptrCast(hook.hookVirtual(toolspanel._vt, Panel.VTIndex.paint, Panel.hookedPaint) orelse {
        std.log.err("Failed to hook Paint", .{});
        return;
    });

    module.loaded = true;
}

fn deinit() void {
    hook.unhookVirtual(toolspanel._vt, Panel.VTIndex.paint, Panel.origPaint);
}
