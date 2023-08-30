const std = @import("std");

const modules = @import("modules.zig");
const hook = @import("hook.zig");
const core = @import("core.zig");

pub var server_map: std.StringHashMap(std.StringHashMap(usize)) = undefined;
pub var client_map: std.StringHashMap(std.StringHashMap(usize)) = undefined;

const DataMap = extern struct {
    data_desc: [*]TypeDescription,
    data_num_fields: c_int,
    data_class_name: [*:0]const u8,
    base_map: ?*DataMap,
    chains_validated: bool,
    packed_offsets_computed: bool,
    packed_size: c_int,

    const FieldType = enum(c_int) {
        FIELD_VOID = 0, // No type or value
        FIELD_FLOAT, // Any floating point value
        FIELD_STRING, // A string ID (return from ALLOC_STRING)
        FIELD_VECTOR, // Any vector, QAngle, or AngularImpulse
        FIELD_QUATERNION, // A quaternion
        FIELD_INTEGER, // Any integer or enum
        FIELD_BOOLEAN, // boolean, implemented as an int, I may use this as a hint for compression
        FIELD_SHORT, // 2 byte integer
        FIELD_CHARACTER, // a byte
        FIELD_COLOR32, // 8-bit per channel r,g,b,a (32bit color)
        FIELD_EMBEDDED, // an embedded object with a datadesc, recursively traverse and embedded class/structure based on an additional typedescription
        FIELD_CUSTOM, // special type that contains function pointers to it's read/write/parse functions

        FIELD_CLASSPTR, // CBaseEntity *
        FIELD_EHANDLE, // Entity handle
        FIELD_EDICT, // edict_t *

        FIELD_POSITION_VECTOR, // A world coordinate (these are fixed up across level transitions automagically)
        FIELD_TIME, // a floating point time (these are fixed up automatically too!)
        FIELD_TICK, // an integer tick count( fixed up similarly to time)
        FIELD_MODELNAME, // Engine string that is a model name (needs precache)
        FIELD_SOUNDNAME, // Engine string that is a sound name (needs precache)

        FIELD_INPUT, // a list of inputed data fields (all derived from CMultiInputVar)
        FIELD_FUNCTION, // A class function pointer (Think, Use, etc)

        FIELD_VMATRIX, // a vmatrix (output coords are NOT worldspace)

        // NOTE: Use float arrays for local transformations that don't need to be fixed up.
        FIELD_VMATRIX_WORLDSPACE, // A VMatrix that maps some local space to world space (translation is fixed up on level transitions)
        FIELD_MATRIX3X4_WORLDSPACE, // matrix3x4_t that maps some local space to world space (translation is fixed up on level transitions)

        FIELD_INTERVAL, // a start and range floating point interval ( e.g., 3.2->3.6 == 3.2 and 0.4 )
        FIELD_MODELINDEX, // a model index
        FIELD_MATERIALINDEX, // a material index (using the material precache string table)

        FIELD_VECTOR2D, // 2 floats
    };

    const TypeDescription = extern struct {
        field_type: FieldType,
        field_name: [*:0]const u8,
        field_offset: [2]c_int,
        field_size: c_ushort,
        flags: c_short,
        external_name: [*:0]const u8,
        save_restore_ops: *anyopaque,
        inputFunc: *anyopaque,
        td: *DataMap,
        field_size_in_bytes: c_int,
        override_field: *TypeDescription,
        override_count: c_int,
        field_tolerance: f32,
    };

    const DataMapInfo = struct {
        num_fields: c_int,
        map: *DataMap,

        fn fromPattern(pattern: [*]const u8) DataMapInfo {
            const num_fields: *align(1) const c_int = @ptrCast(pattern + 6);
            const map: *align(1) const *DataMap = @ptrCast(pattern + 12);
            return DataMapInfo{
                .num_fields = num_fields.*,
                .map = map.*,
            };
        }
    };
};

pub var module = modules.Module{
    .init = init,
    .deinit = deinit,
};

fn isAddressLegal(addr: usize, start: usize, len: usize) bool {
    return addr >= start and addr <= start + len;
}

fn doesMapLooksValid(map: *const DataMap, start: usize, len: usize) bool {
    if (!isAddressLegal(@intFromPtr(map), start, len)) {
        return false;
    }

    if (!isAddressLegal(@intFromPtr(map.data_desc), start, len)) {
        return false;
    }

    if (!isAddressLegal(@intFromPtr(map.data_class_name), start, len)) {
        return false;
    }

    var i: u32 = 0;
    while (i < 64) : (i += 1) {
        if (map.data_class_name[i] == 0) {
            return i > 0;
        }
    }

    return false;
}

fn addFields(datamap: *DataMap, base_offset: usize, out_map: *std.StringHashMap(usize)) !void {
    if (datamap.base_map) |base_map| {
        try addFields(base_map, base_offset, out_map);
    }

    var i: u32 = 0;
    while (i < datamap.data_num_fields) : (i += 1) {
        const desc: *DataMap.TypeDescription = &datamap.data_desc[i];
        switch (desc.field_type) {
            // TODO support embedded field
            .FIELD_VOID, .FIELD_FUNCTION, .FIELD_INPUT, .FIELD_EMBEDDED => {
                continue;
            },
            else => {},
        }

        // FTYPEDESC_INPUT | FTYPEDESC_OUTPUT
        if (desc.flags & (0x0008 | 0x0010) != 0) {
            continue;
        }

        const offset: usize = @intCast(desc.field_offset[0]);
        try out_map.put(std.mem.span(desc.field_name), base_offset + offset);
    }
}

fn addMap(datamap: *DataMap, dll_map: *std.StringHashMap(std.StringHashMap(usize))) !void {
    var map = std.StringHashMap(usize).init(core.gpa);
    errdefer map.deinit();

    try addFields(datamap, 0, &map);

    const key = std.mem.span(datamap.data_class_name);
    var value_ptr = dll_map.getPtr(key);
    if (value_ptr != null) {
        value_ptr.?.deinit();
    }
    try dll_map.put(key, map);
}

fn init() void {
    module.loaded = false;

    const datamap_pattern1 = comptime hook.parsePattern("C7 05 ?? ?? ?? ?? ?? ?? ?? ?? C7 05 ?? ?? ?? ?? ?? ?? ?? ?? B8");
    const datamap_pattern2 = comptime hook.parsePattern("C7 05 ?? ?? ?? ?? ?? ?? ?? ?? C7 05 ?? ?? ?? ?? ?? ?? ?? ?? C3");

    var server_dll = hook.DynLib.open("server.dll") catch {
        return;
    };
    defer server_dll.close();

    var client_dll = hook.DynLib.open("client.dll") catch {
        return;
    };
    defer client_dll.close();

    var server_patterns = std.ArrayList(usize).init(core.gpa);
    defer server_patterns.deinit();
    hook.scanAll(server_dll.mem, datamap_pattern1, &server_patterns) catch {
        return;
    };
    hook.scanAll(server_dll.mem, datamap_pattern2, &server_patterns) catch {
        return;
    };

    var client_patterns = std.ArrayList(usize).init(core.gpa);
    defer client_patterns.deinit();
    hook.scanAll(client_dll.mem, datamap_pattern1, &client_patterns) catch {
        return;
    };
    hook.scanAll(client_dll.mem, datamap_pattern2, &client_patterns) catch {
        return;
    };

    server_map = std.StringHashMap(std.StringHashMap(usize)).init(core.gpa);
    client_map = std.StringHashMap(std.StringHashMap(usize)).init(core.gpa);

    for (server_patterns.items) |pattern| {
        const info = DataMap.DataMapInfo.fromPattern(server_dll.mem.ptr + pattern);

        if (info.num_fields > 0 and doesMapLooksValid(info.map, @intFromPtr(server_dll.mem.ptr), server_dll.info.SizeOfImage)) {
            addMap(info.map, &server_map) catch {
                server_map.deinit();
                client_map.deinit();
                return;
            };
        }
    }

    for (client_patterns.items) |pattern| {
        const info = DataMap.DataMapInfo.fromPattern(client_dll.mem.ptr + pattern);

        if (info.num_fields > 0 and doesMapLooksValid(info.map, @intFromPtr(client_dll.mem.ptr), client_dll.info.SizeOfImage)) {
            addMap(info.map, &client_map) catch {
                server_map.deinit();
                client_map.deinit();
                return;
            };
        }
    }

    module.loaded = true;
}

fn deinit() void {
    var it = server_map.iterator();
    while (it.next()) |kv| {
        kv.value_ptr.deinit();
    }
    server_map.deinit();

    it = client_map.iterator();
    while (it.next()) |kv| {
        kv.value_ptr.deinit();
    }
    client_map.deinit();
}
