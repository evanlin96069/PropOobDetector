const std = @import("std");

pub fn hookVirtual(vt: [*]*const anyopaque, index: u32, target: *const anyopaque) ?*const anyopaque {
    var old: std.os.windows.DWORD = undefined;
    std.os.windows.VirtualProtect(@ptrCast(vt + index), @sizeOf(*anyopaque), std.os.windows.PAGE_READWRITE, &old) catch {
        return null;
    };

    const orig: *const anyopaque = vt[index];
    vt[index] = target;
    return orig;
}

pub fn unhookVirtual(vt: [*]*const anyopaque, index: u32, orig: *const anyopaque) void {
    vt[index] = orig;
}
