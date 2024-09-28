const builtin = @import("builtin");
const tier0 = @import("modules.zig").tier0;

const Module = @import("modules/Module.zig");
const Feature = @import("features/Feature.zig");

const HookManager = @import("zhook").HookManager;

pub var hook_manager: HookManager = undefined;

const modules: []const *Module = mods: {
    var mods: []const *Module = &.{};
    for (&.{
        @import("modules/tier0.zig"),
        @import("modules/tier1.zig"),
        @import("modules/engine.zig"),
        @import("modules/client.zig"),
        @import("modules/vgui.zig"),
    }) |file| {
        mods = mods ++ .{&file.module};
    }
    break :mods mods;
};

const features: []const *Feature = mods: {
    var mods: []const *Feature = &.{};
    for (&.{
        @import("features/datamap.zig"),
        @import("features/oobent.zig"),
    }) |file| {
        mods = mods ++ .{&file.feature};
    }

    if (builtin.mode == .Debug) {
        mods = mods ++ .{&@import("features/test.zig").feature};
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
