const std = @import("std");
const interfaces = @import("interfaces.zig");
const modules = @import("modules.zig");
const hook = @import("hook.zig");

const Virtual = std.builtin.CallingConvention.Thiscall;

pub var module = modules.Module{
    .init = init,
    .deinit = deinit,
};

const IPanel = extern struct {
    _vt: [*]*const anyopaque,

    const VTIndex = struct {
        var getName: usize = undefined;
        var paintTraverse: usize = undefined;
    };

    var ORIG_PaintTraverse: *const fn (this: *anyopaque, vgui_panel: c_uint, force_repaint: bool, allow_force: bool) callconv(Virtual) void = undefined;

    fn Hooked_PaintTraverse(this: *anyopaque, vgui_panel: c_uint, force_repaint: bool, allow_force: bool) callconv(Virtual) void {
        const S = struct {
            var panel_id: ?c_uint = null;
        };

        ORIG_PaintTraverse(this, vgui_panel, force_repaint, allow_force);
        if (S.panel_id) |panel| {
            if (panel == vgui_panel) {
                // draw
                imatsystem.drawSetColor(.{ .r = 0, .g = 255, .b = 255 });
                imatsystem.drawFilledRect(0, 0, 100, 200);
            }
        } else {
            if (std.mem.eql(u8, std.mem.span(ipanel.getName(vgui_panel)), "FocusOverlayPanel")) {
                S.panel_id = vgui_panel;
            }
        }
    }

    fn getName(self: *IPanel, vgui_panel: c_uint) [*:0]const u8 {
        const _getName: *const fn (this: *anyopaque, vgui_panel: c_uint) callconv(Virtual) [*:0]const u8 = @ptrCast(self._vt[VTIndex.getName]);
        return _getName(self, vgui_panel);
    }
};

var ipanel: *IPanel = undefined;

const Color = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
};

const IMatSystemSurface = extern struct {
    _vt: [*]*const anyopaque,

    const VTIndex = struct {
        var drawSetColor: usize = 10;
        var drawFilledRect: usize = 12;
        var drawOutlinedRect: usize = 14;
        var drawLine: usize = 15;
        var drawSetTextFont: usize = 17;
        var drawSetTextColor: usize = 18;
        var drawSetTextPos: usize = 20;
        var drawPrintText: usize = 22;
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
        getDefaultScheme: usize = 4,
        getIScheme: usize = 8,
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
        getFont: usize = 3,
    };

    pub fn getFont(self: *IScheme, name: [*:0]const u8, proportional: bool) c_ulong {
        const _getFont: *const fn (this: *anyopaque, name: [*:0]const u8, proportional: bool) callconv(Virtual) c_ulong = @ptrCast(self._vt[VTIndex.getFont]);
        return _getFont(self, name, proportional);
    }
};

pub var imatsystem: *IMatSystemSurface = undefined;
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
            IPanel.VTIndex.getName = 35;
            IPanel.VTIndex.paintTraverse = 40;
            IMatSystemSurface.VTIndex.getScreenSize = 37;
            IMatSystemSurface.VTIndex.getFontTall = 67;
            IMatSystemSurface.VTIndex.getTextSize = 72;
        },
        8 => {
            IPanel.VTIndex.getName = 36;
            IPanel.VTIndex.paintTraverse = 41;
            IMatSystemSurface.VTIndex.getScreenSize = 38;
            IMatSystemSurface.VTIndex.getFontTall = 69;
            IMatSystemSurface.VTIndex.getTextSize = 75;
        },
        else => unreachable,
    }

    ipanel = @ptrCast(interfaces.engineFactory("VGUI_Panel009", null) orelse {
        std.log.err("Failed to get IPanel interface", .{});
        return;
    });

    IPanel.ORIG_PaintTraverse = @ptrCast(hook.hookVirtual(ipanel._vt, IPanel.VTIndex.paintTraverse, IPanel.Hooked_PaintTraverse) orelse {
        std.log.err("Failed to hook PaintTraverse", .{});
        return;
    });

    module.loaded = true;
}

fn deinit() void {
    hook.unhookVirtual(ipanel._vt, IPanel.VTIndex.paintTraverse, IPanel.ORIG_PaintTraverse);
}
