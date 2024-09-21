const tier0 = @import("tier0.zig");

const HookManager = @import("zhook/zhook.zig").HookManager;
pub var hook_manager: HookManager = undefined;

pub const Module = struct {
    init: *const fn () void,
    deinit: *const fn () void,

    loaded: bool = false,
};

pub const Feature = struct {
    init: *const fn () void,
    deinit: *const fn () void,

    onTick: ?*const fn () void = null,
    onPaint: ?*const fn () void = null,

    loaded: bool = false,
};

const modules: []const *Module = mods: {
    var mods: []const *Module = &.{};
    for (&.{
        @import("engine.zig"),
        @import("client.zig"),
        @import("convar.zig"),
        @import("hud.zig"),
        @import("datamap.zig"),
    }) |file| {
        mods = mods ++ .{&file.module};
    }
    break :mods mods;
};

const features: []const *Feature = mods: {
    var mods: []const *Feature = &.{};
    for (&.{
        @import("test.zig"),
        @import("oobent.zig"),
    }) |file| {
        mods = mods ++ .{&file.feature};
    }
    break :mods mods;
};

pub fn init() bool {
    hook_manager = HookManager.init(tier0.allocator);

    for (modules) |module| {
        module.init();
        if (!module.loaded) {
            return false;
        }
    }

    for (features) |feature| {
        feature.init();
    }

    return true;
}

pub fn deinit() void {
    for (modules) |module| {
        if (!module.loaded) {
            return;
        }
        module.deinit();
        module.loaded = false;
    }

    for (features) |feature| {
        if (!feature.loaded) {
            continue;
        }
        feature.deinit();
        feature.loaded = false;
    }

    hook_manager.deinit();
}

pub fn emitTick() void {
    for (features) |feature| {
        if (!feature.loaded) {
            continue;
        }
        if (feature.onTick) |onTick| {
            onTick();
        }
    }
}

pub fn emitPaint() void {
    for (features) |feature| {
        if (!feature.loaded) {
            continue;
        }
        if (feature.onPaint) |onPaint| {
            onPaint();
        }
    }
}
