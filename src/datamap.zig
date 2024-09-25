const std = @import("std");

const tier0 = @import("tier0.zig");

const Module = @import("modules.zig").Module;

const zhook = @import("zhook/zhook.zig");
const MatchedPattern = zhook.mem.MatchedPattern;

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
        none = 0, // No type or value
        float, // Any floating point value
        string, // A string ID (return from ALLOC_STRING)
        vector, // Any vector, QAngle, or AngularImpulse
        quaternion, // A quaternion
        integer, // Any integer or enum
        boolean, // boolean, implemented as an int, I may use this as a hint for compression
        short, // 2 byte integer
        character, // a byte
        color32, // 8-bit per channel r,g,b,a (32bit color)
        embedded, // an embedded object with a datadesc, recursively traverse and embedded class/structure based on an additional typedescription
        custom, // special type that contains function pointers to it's read/write/parse functions

        classptr, // CBaseEntity *
        ehandle, // Entity handle
        edict, // edict_t *

        position_vector, // A world coordinate (these are fixed up across level transitions automagically)
        time, // a floating point time (these are fixed up automatically too!)
        tick, // an integer tick count( fixed up similarly to time)
        model_name, // Engine string that is a model name (needs precache)
        sound_name, // Engine string that is a sound name (needs precache)

        input, // a list of inputed data fields (all derived from CMultiInputVar)
        function, // A class function pointer (Think, Use, etc)

        vmatrix, // a vmatrix (output coords are NOT worldspace)

        // NOTE: Use float arrays for local transformations that don't need to be fixed up.
        vmatrix_worldspace, // A VMatrix that maps some local space to world space (translation is fixed up on level transitions)
        matrix3x4_worldspace, // matrix3x4_t that maps some local space to world space (translation is fixed up on level transitions)

        interval, // a start and range floating point interval ( e.g., 3.2->3.6 == 3.2 and 0.4 )
        model_index, // a model index
        material_index, // a material index (using the material precache string table)

        vector2d, // 2 floats
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

        fn fromPattern(pattern: MatchedPattern) DataMapInfo {
            const num_field_offset: usize = 6;
            const map_offset: usize = if (pattern.index == 2) 17 else 12;

            const num_fields: *align(1) const c_int = @ptrCast(pattern.ptr + num_field_offset);
            const map: *align(1) const *DataMap = @ptrCast(pattern.ptr + map_offset);
            return DataMapInfo{
                .num_fields = num_fields.*,
                .map = map.*,
            };
        }
    };
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

fn addFields(
    out_map: *std.StringHashMap(usize),
    datamap: *DataMap,
    base_offset: usize,
    prefix: []u8,
) !void {
    if (datamap.base_map) |base_map| {
        try addFields(out_map, base_map, base_offset, prefix);
    }

    var i: u32 = 0;
    while (i < datamap.data_num_fields) : (i += 1) {
        const desc: *DataMap.TypeDescription = &datamap.data_desc[i];
        switch (desc.field_type) {
            .none,
            .function,
            .input,
            => {
                continue;
            },
            else => {},
        }

        // FTYPEDESC_INPUT | FTYPEDESC_OUTPUT
        if (desc.flags & (0x0008 | 0x0010) != 0) {
            continue;
        }

        const offset: usize = @intCast(desc.field_offset[0]);
        const name = std.mem.span(desc.field_name);

        if (desc.field_type == .embedded) {
            const field_prefix = try tier0.allocator.alloc(u8, name.len + 1);
            defer tier0.allocator.free(field_prefix);

            @memcpy(field_prefix[0..name.len], name);
            field_prefix[name.len] = '.';

            try addFields(out_map, desc.td, offset, field_prefix);
        } else {
            const key = try tier0.allocator.alloc(u8, prefix.len + name.len);

            @memcpy(key[0..prefix.len], prefix);
            @memcpy(key[prefix.len..], name);

            try out_map.put(key, base_offset + offset);
        }
    }
}

pub fn getField(comptime T: type, ptr: *anyopaque, offset: usize) *T {
    const base: [*]u8 = @ptrCast(ptr);
    const field: *T = @alignCast(@ptrCast(base + offset));
    return field;
}

fn addMap(datamap: *DataMap, dll_map: *std.StringHashMap(std.StringHashMap(usize))) !void {
    var map = std.StringHashMap(usize).init(tier0.allocator);
    errdefer map.deinit();

    try addFields(&map, datamap, 0, "");

    const key = std.mem.span(datamap.data_class_name);
    var value_ptr = dll_map.getPtr(key);
    if (value_ptr != null) {
        value_ptr.?.deinit();
    }
    try dll_map.put(key, map);
}

const datamap_patterns = zhook.mem.makePatterns(.{
    "C7 05 ?? ?? ?? ?? ?? ?? ?? ?? C7 05 ?? ?? ?? ?? ?? ?? ?? ?? B8",
    "C7 05 ?? ?? ?? ?? ?? ?? ?? ?? C7 05 ?? ?? ?? ?? ?? ?? ?? ?? C3",
    "C7 05 ?? ?? ?? ?? ?? ?? ?? ?? B8 ?? ?? ?? ?? C7 05",
});

pub var module: Module = .{
    .init = init,
    .deinit = deinit,
};

fn init() void {
    module.loaded = false;

    const server_dll = zhook.mem.getModule("server") orelse return;
    const client_dll = zhook.mem.getModule("client") orelse return;

    var server_patterns = std.ArrayList(MatchedPattern).init(tier0.allocator);
    defer server_patterns.deinit();
    zhook.mem.scanAllPatterns(server_dll, datamap_patterns[0..], &server_patterns) catch {
        return;
    };

    var client_patterns = std.ArrayList(MatchedPattern).init(tier0.allocator);
    defer client_patterns.deinit();
    zhook.mem.scanAllPatterns(client_dll, datamap_patterns[0..], &client_patterns) catch {
        return;
    };

    server_map = std.StringHashMap(std.StringHashMap(usize)).init(tier0.allocator);
    client_map = std.StringHashMap(std.StringHashMap(usize)).init(tier0.allocator);

    for (server_patterns.items) |pattern| {
        const info = DataMap.DataMapInfo.fromPattern(pattern);

        if (info.num_fields > 0 and doesMapLooksValid(info.map, @intFromPtr(server_dll.ptr), server_dll.len)) {
            addMap(info.map, &server_map) catch {
                server_map.deinit();
                client_map.deinit();
                return;
            };
        }
    }

    for (client_patterns.items) |pattern| {
        const info = DataMap.DataMapInfo.fromPattern(pattern);

        if (info.num_fields > 0 and doesMapLooksValid(info.map, @intFromPtr(client_dll.ptr), client_dll.len)) {
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
        var inner_it = kv.value_ptr.iterator();
        while (inner_it.next()) |inner_kv| {
            tier0.allocator.free(inner_kv.key_ptr.*);
        }
        kv.value_ptr.deinit();
    }
    server_map.deinit();

    it = client_map.iterator();
    while (it.next()) |kv| {
        var inner_it = kv.value_ptr.iterator();
        while (inner_it.next()) |inner_kv| {
            tier0.allocator.free(inner_kv.key_ptr.*);
        }
        kv.value_ptr.deinit();
    }
    client_map.deinit();
}
