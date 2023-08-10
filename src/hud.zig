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

    fn getName(self: *IPanel, vgui_panel: c_uint) [*:0]const u8 {
        const _getName: *const fn (this: *anyopaque, vgui_panel: c_uint) callconv(Virtual) [*:0]const u8 = @ptrCast(self._vt[35]);
        return _getName(self, vgui_panel);
    }
};

var ipanel: *IPanel = undefined;

const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
};

const IMatSystemSurface = extern struct {
    _vt: [*]*const anyopaque,

    fn drawSetColor(self: *IMatSystemSurface, color: Color) void {
        const _drawSetColor: *const fn (this: *anyopaque, color: Color) callconv(Virtual) void = @ptrCast(self._vt[10]);
        _drawSetColor(self, color);
    }

    fn drawFilledRect(self: *IMatSystemSurface, x0: c_int, y0: c_int, x1: c_int, y1: c_int) void {
        const _drawFilledRect: *const fn (this: *anyopaque, x0: c_int, y0: c_int, x1: c_int, y1: c_int) callconv(Virtual) void = @ptrCast(self._vt[12]);
        _drawFilledRect(self, x0, y0, x1, y1);
    }
};

var imatsystem: *IMatSystemSurface = undefined;

const vtidx_PaintTraverse = 40;
var ORIG_PaintTraverse: *const fn (this: *anyopaque, vgui_panel: c_uint, force_repaint: bool, allow_force: bool) callconv(Virtual) void = undefined;

var panel_id: ?c_uint = null;
fn Hooked_PaintTraverse(this: *anyopaque, vgui_panel: c_uint, force_repaint: bool, allow_force: bool) callconv(Virtual) void {
    ORIG_PaintTraverse(this, vgui_panel, force_repaint, allow_force);
    // if (panel_id) |panel| {
    //     if (panel == vgui_panel) {
    //         // draw
    //         imatsystem.drawSetColor(.{ .r = 0, .g = 255, .b = 255 });
    //         imatsystem.drawFilledRect(0, 0, 100, 200);
    //     }
    // } else {
    //     if (std.mem.eql(u8, std.mem.span(ipanel.getName(vgui_panel)), "FocusOverlayPanel")) {
    //         panel_id = vgui_panel;
    //     }
    // }
}

fn init() void {
    module.loaded = false;

    ipanel = @ptrCast(interfaces.engineFactory("VGUI_Panel009", null) orelse {
        std.log.err("Failed to get IPanel interface", .{});
        return;
    });

    imatsystem = @ptrCast(interfaces.engineFactory("MatSystemSurface004", null) orelse {
        std.log.err("Failed to get IMatSystemSurface interface", .{});
        return;
    });

    ORIG_PaintTraverse = @ptrCast(hook.hookVirtual(ipanel._vt, vtidx_PaintTraverse, Hooked_PaintTraverse) orelse {
        std.log.err("Failed to hook PaintTraverse", .{});
        return;
    });

    module.loaded = true;
}

fn deinit() void {
    hook.unhookVirtual(ipanel._vt, vtidx_PaintTraverse, ORIG_PaintTraverse);
}
