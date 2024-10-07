const std = @import("std");

const event = @import("../event.zig");

const modules = @import("../modules.zig");
const tier0 = modules.tier0;
const tier1 = modules.tier1;
const vgui = modules.vgui;
const engine = modules.engine;

const datamap = @import("datamap.zig");

const Feature = @import("Feature.zig");

const sdk = @import("sdk");
const Edict = sdk.Edict;
const Vector = sdk.Vector;
const Ray = sdk.Ray;
const Trace = sdk.Trace;
const ITraceFilter = sdk.ITraceFilter;

pub var feature: Feature = .{
    .name = "oobent",
    .shouldLoad = shouldLoad,
    .init = init,
    .deinit = deinit,
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

var pod_print_oob_ents = tier1.ConCommand.init(.{
    .name = "pod_print_oob_ents",
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

var pod_hud_oob_ents = tier1.Variable.init(.{
    .name = "pod_hud_oob_ents",
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
    return event.paint.works and event.tick.works;
}

fn onTick() void {
    if (engine.sdk_version == 2013) {
        detect_oob_ents(sdk.CCollisionPropertyV2);
    } else {
        detect_oob_ents(sdk.CCollisionPropertyV1);
    }
}

var cl_showfps: ?*tier1.ConVar = null;
var cl_showpos: ?*tier1.ConVar = null;

fn onPaint() void {
    if (!engine.client.isInGame()) {
        return;
    }

    if (!pod_hud_oob_ents.getBool()) {
        return;
    }

    const screen = vgui.imatsystem.getScreenSize();

    const x = screen.wide - 300 + 2;
    var offset: c_int = 0;

    if (cl_showfps == null) {
        cl_showfps = tier1.icvar.findVar("cl_showfps");
    }
    if (cl_showpos == null) {
        cl_showpos = tier1.icvar.findVar("cl_showpos");
    }

    if (cl_showfps) |v| {
        if (v.getBool()) {
            offset += 1;
        }
    }
    if (cl_showpos) |v| {
        if (v.getBool()) {
            offset += 3;
        }
    }

    vgui.imatsystem.drawSetTextFont(font_DefaultFixedOutline);
    vgui.imatsystem.drawSetTextColor(.{
        .r = 255,
        .g = 255,
        .b = 255,
        .a = 255,
    });
    vgui.imatsystem.drawSetTextPos(x, 2 + offset * (font_DefaultFixedOutline_tall + 2));

    if (engine.server.pEntityOfEntIndex(0) == null) {
        vgui.imatsystem.drawPrintText("oob entity: Server not loaded", .{});
        return;
    }

    vgui.imatsystem.drawPrintText("oob entity count: {d}", .{oob_ents.items.len});
    offset += 1;

    vgui.imatsystem.drawSetTextColor(.{
        .r = 255,
        .g = 200,
        .b = 200,
        .a = 255,
    });

    for (oob_ents.items) |ent| {
        vgui.imatsystem.drawSetTextPos(x, 2 + offset * (font_DefaultFixedOutline_tall + 2));
        vgui.imatsystem.drawPrintText("({d}) {s}", .{ ent.index, ent.name });
        offset += 1;
    }
}

fn init() bool {
    if (datamap.server_map.get("CBaseEntity")) |map| {
        field_m_iClassname = map.get("m_iClassname") orelse return false;
        field_m_Collision = map.get("m_hMovePeer") orelse return false;
        field_m_Collision += 4; // m_Collision is not in datamap, use field before it
    } else {
        std.log.info("Cannot find CBaseEntity data map", .{});
        return false;
    }

    font_DefaultFixedOutline = vgui.ischeme.getFont("DefaultFixedOutline", false);
    font_DefaultFixedOutline_tall = vgui.imatsystem.getFontTall(font_DefaultFixedOutline);

    oob_ents = std.ArrayList(EntityInfo).init(tier0.allocator);

    pod_print_oob_ents.register();
    pod_hud_oob_ents.register();

    event.paint.connect(onPaint);
    event.tick.connect(onTick);

    return true;
}

fn deinit() void {
    for (oob_ents.items) |ent| {
        tier0.allocator.free(ent.name);
    }
    oob_ents.deinit();
}
