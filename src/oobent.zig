const std = @import("std");

const Virtual = std.builtin.CallingConvention.Thiscall;

const core = @import("core.zig");
const modules = @import("modules.zig");
const convar = @import("convar.zig");
const hud = @import("hud.zig");
const engine = @import("engine.zig");
const datamap = @import("datamap.zig");

const sdk = @import("sdk.zig");
const Edict = sdk.Edict;
const Vector = sdk.Vector;
const Ray = sdk.Ray;
const Trace = sdk.Trace;
const ITraceFilter = sdk.ITraceFilter;

pub var feature = modules.Feature{
    .init = init,
    .deinit = deinit,
    .onTick = onTick,
    .onPaint = onPaint,
};

var field_m_iClassname: usize = undefined;
var field_m_Collision: usize = undefined;

var font_DefaultFixedOutline: c_ulong = 0;
var font_DefaultFixedOutline_tall: c_int = 0;

const EntityInfo = struct {
    index: c_int,
    name: []u8,
    pos: Vector,
};

var oob_ents: std.ArrayList(EntityInfo) = undefined;

var pod_print_oob_ent = convar.ConCommand{
    .base = .{
        .name = "pod_print_oob_ent",
        .help_str = "Prints entities that are oob.",
    },
    .command_callback = print_oob_ent_Fn,
};

var pod_hud_oob_ent = convar.Variable{
    .cvar = .{
        .base1 = .{
            .name = "pod_hud_oob_ent",
            .help_str = "Shows entities that are oob.",
        },
        .default_value = "0",
    },
};

fn print_oob_ent_Fn(args: *const convar.CCommand) callconv(.C) void {
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

fn shouldHitEntity(_: *anyopaque, server_entity: *anyopaque, contents_mask: c_int) callconv(Virtual) bool {
    _ = server_entity;
    _ = contents_mask;
    return false;
}

fn getTraceType(_: *anyopaque) callconv(Virtual) c_int {
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

fn detect_oob_ent(comptime CCollisionProperty: type) void {
    for (oob_ents.items) |ent| {
        core.gpa.free(ent.name);
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

        var name = std.fmt.allocPrint(core.gpa, "{s}", .{class_name}) catch continue;

        const ent_info = EntityInfo{
            .index = i,
            .name = name,
            .pos = pos,
        };

        oob_ents.append(ent_info) catch continue;
    }
}

fn onTick() void {
    if (engine.sdk_version == 2013) {
        detect_oob_ent(sdk.CCollisionPropertyV2);
    } else {
        detect_oob_ent(sdk.CCollisionPropertyV1);
    }
}

fn onPaint() void {
    if (!pod_hud_oob_ent.getBool()) {
        return;
    }

    const x = 2;
    var offset: c_int = 0;

    hud.imatsystem.drawSetTextFont(font_DefaultFixedOutline);
    hud.imatsystem.drawSetTextColor(.{ .r = 255, .g = 255, .b = 255 });
    hud.imatsystem.drawSetTextPos(x, 2 + offset * (font_DefaultFixedOutline_tall + 2));

    if (engine.server.pEntityOfEntIndex(0) == null) {
        hud.imatsystem.drawPrintText("oob entity: Server not loaded", .{});
        return;
    }

    hud.imatsystem.drawPrintText("oob entity count: {d}", .{oob_ents.items.len});
    offset += 1;

    hud.imatsystem.drawSetTextColor(.{ .r = 255, .g = 200, .b = 200 });

    for (oob_ents.items) |ent| {
        hud.imatsystem.drawSetTextPos(x, 2 + offset * (font_DefaultFixedOutline_tall + 2));
        hud.imatsystem.drawPrintText("({d}) {s}", .{ ent.index, ent.name });
        offset += 1;
    }
}

fn init() void {
    feature.loaded = false;

    if (datamap.server_map.get("CBaseEntity")) |map| {
        field_m_iClassname = map.get("m_iClassname") orelse return;
        field_m_Collision = map.get("m_hMovePeer") orelse return;
        field_m_Collision += 4; // m_Collision is not in datamap, use field before it
    } else {
        std.log.info("Cannot find CBaseEntity data map", .{});
        return;
    }

    font_DefaultFixedOutline = hud.ischeme.getFont("DefaultFixedOutline", false);
    font_DefaultFixedOutline_tall = hud.imatsystem.getFontTall(font_DefaultFixedOutline);

    pod_print_oob_ent.register();
    pod_hud_oob_ent.register();

    oob_ents = std.ArrayList(EntityInfo).init(core.gpa);

    feature.loaded = true;
}

fn deinit() void {
    oob_ents.deinit();
}
