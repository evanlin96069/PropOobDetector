const modules = @import("../modules.zig");
const engine = modules.engine;
const client = modules.client;

const sdk = @import("sdk");
const IServerUnknown = sdk.IServerUnknown;

pub fn getServerPlayer() ?*IServerUnknown {
    if (engine.server.pEntityOfEntIndex(1)) |ed| {
        return ed.getIServerEntity();
    }
    return null;
}

pub fn getPlayer(is_server: bool) ?*anyopaque {
    if (is_server) {
        if (engine.server.pEntityOfEntIndex(1)) |ed| {
            return ed.getIServerEntity();
        }
        return null;
    }
    return client.entlist.getClientEntity(1);
}
