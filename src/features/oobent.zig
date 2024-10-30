const std = @import("std");

const event = @import("../event.zig");

const modules = @import("../modules.zig");
const tier0 = modules.tier0;
const tier1 = modules.tier1;
const engine = modules.engine;

const datamap = @import("datamap.zig");
const texthud = @import("texthud.zig");

const Feature = @import("Feature.zig");

const sdk = @import("sdk");
const Edict = sdk.Edict;
const Vector = sdk.Vector;
const Ray = sdk.Ray;
const Trace = sdk.Trace;
const ITraceFilter = sdk.ITraceFilter;

pub var feature: Feature = .{
    .name = "Oob entity",
    .shouldLoad = shouldLoad,
    .init = init,
    .deinit = deinit,
};

var field_m_iClassname: usize = undefined;
var field_m_Collision: usize = undefined;

const EntityInfo = struct {
    index: c_int,
    name: []u8,
    pos: Vector,
};

var oob_ents: std.ArrayList(EntityInfo) = undefined;

var vkrk_print_oob_ents = tier1.ConCommand.init(.{
    .name = "vkrk_print_oob_ents",
    .help_string = "Prints entities that are oob.",
    .command_callback = print_oob_ents_Fn,
});

fn print_oob_ents_Fn(args: *const tier1.CCommand) callconv(.C) void {
    _ = args;

    if (engine.server.pEntityOfEntIndex(0) == null) {
        std.log.info("Server not loaded", .{});
        return;
    }

    std.log.info("oob entity count: {d}", .{oob_ents.items.len});

    for (oob_ents.items) |ent| {
        std.log.info("({d}) {s} [{d:.2}, {d:.2}, {d:.2}]", .{ ent.index, ent.name, ent.pos.x, ent.pos.y, ent.pos.z });
    }
}

var vkrk_hud_oob_ents = tier1.Variable.init(.{
    .name = "vkrk_hud_oob_ents",
    .help_string = "Shows entities that are oob.",
    .default_value = "0",
});

fn shouldHitEntity(_: *anyopaque, server_entity: *anyopaque, contents_mask: c_int) callconv(.Thiscall) bool {
    _ = server_entity;
    _ = contents_mask;
    return false;
}

fn getTraceType(_: *anyopaque) callconv(.Thiscall) c_int {
    const trace_world_only = 1;
    return trace_world_only;
}

const vt_TraceFilterWorldOnly = ITraceFilter.VTable{
    .shouldHitEntity = &shouldHitEntity,
    .getTraceType = &getTraceType,
};

const ignore_classes = [_][]const u8{
    "physicsshadowclone",
    "portalsimulator_collisionentity",
    "phys_bone_follower",
    "generic_actor",
    "prop_dynamic",
    "prop_door_rotating",
    "prop_portal_stats_display",
    "func_brush",
    "func_door",
    "func_door_rotating",
    "func_rotating",
    "func_tracktrain",
    "func_rot_button",
    "func_button",
};

fn detect_oob_ents(comptime CCollisionProperty: type) void {
    for (oob_ents.items) |ent| {
        tier0.allocator.free(ent.name);
    }
    oob_ents.clearAndFree();

    if (engine.server.pEntityOfEntIndex(0) == null) {
        return;
    }

    var i: c_int = 2;
    outer: while (i < sdk.MAX_EDICTS) : (i += 1) {
        const ed = engine.server.pEntityOfEntIndex(i) orelse continue;
        const ent = ed.getIServerEntity() orelse continue;

        const class_name = datamap.getField([*:0]const u8, ent, field_m_iClassname).*;

        for (ignore_classes) |class| {
            if (std.mem.eql(u8, std.mem.span(class_name), class)) {
                continue :outer;
            }
        }

        const col_prop = datamap.getField(CCollisionProperty, ent, field_m_Collision);
        if (!col_prop.isSolid()) {
            continue;
        }
        const pos = col_prop.worldSpaceCenter();

        if (!engine.trace_server.pointOutsideWorld(pos)) {
            continue;
        }

        var tr: Trace = undefined;
        var ray: Ray = undefined;
        ray.init(pos, Vector.add(pos, Vector{ .x = 1, .y = 1, .z = 1 }));

        var filter = ITraceFilter{
            ._vt = @ptrCast(&vt_TraceFilterWorldOnly),
        };

        const brush_only = 0x1400b;
        engine.trace_server.traceRay(&ray, brush_only, &filter, &tr);

        if (tr.start_solid) {
            continue;
        }

        const name = std.fmt.allocPrint(tier0.allocator, "{s}", .{class_name}) catch continue;

        const ent_info = EntityInfo{
            .index = i,
            .name = name,
            .pos = pos,
        };

        oob_ents.append(ent_info) catch continue;
    }
}

fn shouldLoad() bool {
    return texthud.feature.loaded and event.tick.works;
}

fn onTick() void {
    if (engine.sdk_version == 2013) {
        detect_oob_ents(sdk.CCollisionPropertyV2);
    } else {
        detect_oob_ents(sdk.CCollisionPropertyV1);
    }
}

const OobentTextHUD = struct {
    fn shouldDraw() bool {
        return vkrk_hud_oob_ents.getBool();
    }

    fn paint() void {
        if (engine.server.pEntityOfEntIndex(0) == null) {
            texthud.drawTextHUD("oob entity: Server not loaded", .{});
            return;
        }

        texthud.drawTextHUD("oob entity count: {d}", .{oob_ents.items.len});

        for (oob_ents.items) |ent| {
            texthud.drawColorTextHUD(
                .{
                    .r = 255,
                    .g = 200,
                    .b = 200,
                },
                "({d}) {s}",
                .{ ent.index, ent.name },
            );
        }
    }

    fn register() void {
        vkrk_hud_oob_ents.register();
        texthud.addHUDElement(.{
            .shouldDraw = shouldDraw,
            .paint = paint,
        });
    }
};

fn init() bool {
    if (datamap.server_map.get("CBaseEntity")) |map| {
        field_m_iClassname = map.get("m_iClassname") orelse {
            std.log.debug("Cannot find CBaseEntity::m_iClassname offset", .{});
            return false;
        };
        field_m_Collision = map.get("m_hMovePeer") orelse {
            std.log.debug("Cannot find CBaseEntity::m_hMovePeer offset", .{});
            return false;
        };
        field_m_Collision += 4; // m_Collision is not in datamap, use field before it
    } else {
        std.log.info("Cannot find CBaseEntity data map", .{});
        return false;
    }

    oob_ents = std.ArrayList(EntityInfo).init(tier0.allocator);

    vkrk_print_oob_ents.register();

    OobentTextHUD.register();

    event.tick.connect(onTick);

    return true;
}

fn deinit() void {
    for (oob_ents.items) |ent| {
        tier0.allocator.free(ent.name);
    }
    oob_ents.deinit();
}
