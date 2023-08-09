pub const Module = struct {
    init: *const fn () void,
    deinit: *const fn () void,
    loaded: bool = false,
};

const modules: []const *Module = mods: {
    var mods: []const *Module = &.{};
    for (&.{
        @import("engine.zig"),
        @import("convar.zig"),
    }) |file| {
        mods = mods ++ .{&file.module};
    }
    break :mods mods;
};

pub fn init() bool {
    for (modules) |module| {
        module.init();
        if (!module.loaded) {
            return false;
        }
    }
    return true;
}

pub fn deinit() void {
    for (modules) |module| {
        if (!module.loaded) {
            break;
        }
        module.deinit();
    }
}
