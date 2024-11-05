const modules = @import("../modules.zig");
const tier1 = modules.tier1;

pub fn doesGameLooksLikePortal() bool {
    const S = struct {
        var cached = false;
        var result: ?*tier1.ConCommand = null;
    };

    if (!S.cached) {
        S.result = tier1.icvar.findCommand("upgrade_portalgun");
        S.cached = true;
    }

    return S.result != null;
}
