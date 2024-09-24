const std = @import("std");

const Virtual = std.builtin.CallingConvention.Thiscall;

pub const MAX_EDICTS = 1 << 11;

const FEdict = packed struct(c_uint) {
    changed: bool = false,
    free: bool = false,
    full: bool = false,
    always: bool = false,
    dont_send: bool = false,
    pvs_check: bool = false,
    pending_dormant_check: bool = false,
    dirty_pvs_information: bool = false,
    full_edict_changed: bool = false,
    _pad_0: u23,
};

pub const Edict = extern struct {
    state_flags: FEdict,
    network_serial_number: c_int,
    networkable: *anyopaque,
    unknown: *anyopaque,
    freetime: f32,

    pub fn getOffsetField(self: *Edict, comptime T: type, offset: usize) *T {
        const addr: [*]const u8 = @ptrCast(self.unknown);
        return @ptrCast(addr + offset);
    }

    pub fn getIServerEntity(self: *Edict) ?*anyopaque {
        if (self.state_flags.full) {
            return self.unknown;
        }
        return null;
    }
};

pub const Color = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
};

pub const Vector = extern struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn add(a: Vector, b: Vector) Vector {
        var res: Vector = undefined;
        res.x = a.x + b.x;
        res.y = a.y + b.y;
        res.z = a.z + b.z;
        return res;
    }

    pub fn subtract(a: Vector, b: Vector) Vector {
        var res: Vector = undefined;
        res.x = a.x - b.x;
        res.y = a.y - b.y;
        res.z = a.z - b.z;
        return res;
    }

    pub fn eql(a: Vector, b: Vector) bool {
        return (a.x == b.x) and (a.y == b.y) and (a.z == b.z);
    }

    pub fn lerp(a: Vector, b: Vector, t: f32) Vector {
        var res: Vector = undefined;
        res.x = a.x + (b.x - a.x) * t;
        res.y = a.y + (b.y - a.y) * t;
        res.z = a.z + (b.z - a.z) * t;
        return res;
    }

    pub fn dotProduct(a: Vector, b: Vector) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn transform(v: Vector, m: Matrix3x4) Vector {
        var res: Vector = undefined;
        res.x = dotProduct(v, Vector{ .x = m.mat_val[0][0], .y = m.mat_val[0][1], .z = m.mat_val[0][2] }) + m.mat_val[0][3];
        res.y = dotProduct(v, Vector{ .x = m.mat_val[1][0], .y = m.mat_val[1][1], .z = m.mat_val[1][2] }) + m.mat_val[1][3];
        res.z = dotProduct(v, Vector{ .x = m.mat_val[2][0], .y = m.mat_val[2][1], .z = m.mat_val[2][2] }) + m.mat_val[2][3];
        return res;
    }

    pub fn clear(self: *Vector) void {
        self.x = 0.0;
        self.y = 0.0;
        self.z = 0.0;
    }

    pub fn getlengthSqr(self: *Vector) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }
};

const VectorAligned = extern struct {
    base: Vector,
    w: f32 = 0.0,
};

pub const QAngle = Vector;

pub const Matrix3x4 = extern struct {
    mat_val: [3][4]f32,
};

pub const Ray = extern struct {
    start: VectorAligned,
    delta: VectorAligned,
    start_offset: VectorAligned,
    extents: VectorAligned,
    is_ray: bool,
    is_swept: bool,

    pub fn init(self: *Ray, start: Vector, end: Vector) void {
        self.delta.base = Vector.subtract(end, start);

        self.is_swept = (self.delta.base.getlengthSqr() != 0);

        self.extents.base.clear();
        self.is_ray = true;

        self.start_offset.base.clear();
        self.start.base = start;
    }
};

const Surface = extern struct {
    name: [*:0]u8,
    surface_props: c_short,
    flags: c_ushort,
};

const Plane = extern struct {
    normal: Vector,
    dist: f32,
    plane_type: u8,
    sign_bits: u8,
    pad: u16,
};

pub const Trace = extern struct {
    startpos: Vector,
    endpos: Vector,
    plane: Plane,
    fraction: f32,
    content: c_int,
    disp_flags: c_ushort,
    all_solid: bool,
    start_solid: bool,

    fraction_left_solid: f32,
    surface: Surface,
    hit_group: c_int,
    physics_bone: c_short,
    ent: *anyopaque,
    hitbox: c_int,
};

pub const ITraceFilter = extern struct {
    _vt: *align(@alignOf(*anyopaque)) const anyopaque = undefined,

    pub const VTable = extern struct {
        shouldHitEntity: *const fn (_: *anyopaque, server_entity: *anyopaque, contents_mask: c_int) callconv(Virtual) bool,
        getTraceType: *const fn (_: *anyopaque) callconv(Virtual) c_int,
    };
};

pub const CCollisionPropertyV1 = extern struct {
    _vt: [*]*const anyopaque,

    outer: *anyopaque,

    mins: Vector,
    maxs: Vector,
    radius: f32,

    solid_flags: c_ushort,

    partition: c_ushort,
    surround_type: u8,

    solid_type: u8,
    trigger_bloat: u8,

    specified_surrounding_mins: Vector,
    specified_surrounding_maxs: Vector,

    surrounding_mins: Vector,
    surrounding_maxs: Vector,

    const VTIndex = struct {
        const getCollisionOrigin = 8;
        const getCollisionAngles = 9;
        const collisionToWorldTransform = 10;
    };

    fn getCollisionOrigin(self: *CCollisionPropertyV1) Vector {
        const _getCollisionOrigin: *const fn (this: *anyopaque) callconv(Virtual) *Vector = @ptrCast(self._vt[VTIndex.getCollisionOrigin]);
        return _getCollisionOrigin(self).*;
    }

    fn getCollisionAngles(self: *CCollisionPropertyV1) QAngle {
        const _getCollisionAngles: *const fn (this: *anyopaque) callconv(Virtual) *QAngle = @ptrCast(self._vt[VTIndex.getCollisionAngles]);
        return _getCollisionAngles(self).*;
    }

    fn collisionToWorldTransform(self: *CCollisionPropertyV1) Matrix3x4 {
        const _collisionToWorldTransform: *const fn (this: *anyopaque) callconv(Virtual) *const Matrix3x4 = @ptrCast(self._vt[VTIndex.collisionToWorldTransform]);
        return _collisionToWorldTransform(self).*;
    }

    pub fn isSolid(self: *CCollisionPropertyV1) bool {
        const solid_none = 0;
        const not_solid = 4;
        return (self.solid_type != solid_none) and ((self.solid_flags & not_solid) == 0);
    }

    fn isBoundsDefinedInEntitySpace(self: *CCollisionPropertyV1) bool {
        const force_world_aliged = 64;
        const solid_bbox = 2;
        const solid_none = 0;
        return ((self.solid_flags & force_world_aliged) == 0) and
            (self.solid_type != solid_bbox) and (self.solid_type != solid_none);
    }

    pub fn worldSpaceCenter(self: *CCollisionPropertyV1) Vector {
        const obb_center = Vector.lerp(self.mins, self.maxs, 0.5);
        if (!self.isBoundsDefinedInEntitySpace() or self.getCollisionAngles().eql(QAngle{ .x = 0, .y = 0, .z = 0 })) {
            return Vector.add(obb_center, self.getCollisionOrigin());
        }
        return Vector.transform(obb_center, self.collisionToWorldTransform());
    }
};

pub const CCollisionPropertyV2 = extern struct {
    _vt: [*]*const anyopaque,

    outer: *anyopaque,

    mins_pre_scaled: Vector,
    maxs_pre_scaled: Vector,
    mins: Vector,
    maxs: Vector,
    radius: f32,

    solid_flags: c_ushort,

    partition: c_ushort,
    surround_type: u8,

    solid_type: u8,
    trigger_bloat: u8,

    specified_surrounding_mins_pre_scaled: Vector,
    specified_surrounding_maxs_pre_scaled: Vector,
    specified_surrounding_mins: Vector,
    specified_surrounding_maxs: Vector,

    surrounding_mins: Vector,
    surrounding_maxs: Vector,

    const VTIndex = struct {
        const getCollisionOrigin = 10;
        const getCollisionAngles = 11;
        const collisionToWorldTransform = 12;
    };

    fn getCollisionOrigin(self: *CCollisionPropertyV2) Vector {
        const _getCollisionOrigin: *const fn (this: *anyopaque) callconv(Virtual) *Vector = @ptrCast(self._vt[VTIndex.getCollisionOrigin]);
        return _getCollisionOrigin(self).*;
    }

    fn getCollisionAngles(self: *CCollisionPropertyV2) QAngle {
        const _getCollisionAngles: *const fn (this: *anyopaque) callconv(Virtual) *QAngle = @ptrCast(self._vt[VTIndex.getCollisionAngles]);
        return _getCollisionAngles(self).*;
    }

    fn collisionToWorldTransform(self: *CCollisionPropertyV2) Matrix3x4 {
        const _collisionToWorldTransform: *const fn (this: *anyopaque) callconv(Virtual) *const Matrix3x4 = @ptrCast(self._vt[VTIndex.collisionToWorldTransform]);
        return _collisionToWorldTransform(self).*;
    }

    pub fn isSolid(self: *CCollisionPropertyV2) bool {
        const solid_none = 0;
        const not_solid = 4;
        return (self.solid_type != solid_none) and ((self.solid_flags & not_solid) == 0);
    }

    fn isBoundsDefinedInEntitySpace(self: *CCollisionPropertyV2) bool {
        const force_world_aliged = 64;
        const solid_bbox = 2;
        const solid_none = 0;
        return ((self.solid_flags & force_world_aliged) == 0) and
            (self.solid_type != solid_bbox) and (self.solid_type != solid_none);
    }

    pub fn worldSpaceCenter(self: *CCollisionPropertyV2) Vector {
        const obb_center = Vector.lerp(self.mins, self.maxs, 0.5);
        if (!self.isBoundsDefinedInEntitySpace() or self.getCollisionAngles().eql(QAngle{ .x = 0, .y = 0, .z = 0 })) {
            return Vector.add(obb_center, self.getCollisionOrigin());
        }
        return Vector.transform(obb_center, self.collisionToWorldTransform());
    }
};
