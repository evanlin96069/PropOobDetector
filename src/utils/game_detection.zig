const modules = @import("../modules.zig");
const tier1 = modules.tier1;

pub fn doesGameLooksLikePortal() bool {
    return tier1.icvar.findCommand("upgrade_portalgun") != null;
}
