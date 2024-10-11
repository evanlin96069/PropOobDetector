const std = @import("std");

const playerio = @import("../features/playerio.zig");
const PlayerInfo = playerio.PlayerInfo;

const sdk = @import("sdk");
const Vector = sdk.Vector;
const QAngle = sdk.QAngle;

pub fn getVelocityAngles(player: *const PlayerInfo) Vector {
    var velocity_angles = player.velocity;
    if (velocity_angles.getlength() == 0) {
        return Vector{};
    }

    velocity_angles = velocity_angles.normalize();

    const yaw: f32 = std.math.atan2(velocity_angles.y, velocity_angles.x);
    const pitch: f32 = std.math.atan2(velocity_angles.z, velocity_angles.getlength2D());

    return Vector{
        .x = std.math.radiansToDegrees(yaw),
        .y = std.math.radiansToDegrees(pitch),
    };
}

pub fn getGroundFrictionVelocity(player: *const PlayerInfo) Vector {
    const friction = player.friction * player.entity_friction;
    var vel = player.velocity;

    if (player.grounded) {
        if (vel.getlength2D() >= player.stopspeed) {
            vel = vel.scale(1.0 - player.tick_time * friction);
        } else if (vel.getlength2D() >= @max(0.1, player.tick_time * player.stopspeed * friction)) {
            vel = vel.subtract(vel.normalize().scale(player.tick_time * player.stopspeed * friction));
        } else {
            vel = Vector{};
        }

        if (vel.getlength2D() < 1.0) {
            vel = Vector{};
        }
    }

    return vel;
}

pub fn getMaxSpeed(player: *const PlayerInfo, wish_dir: Vector, not_aired: bool) f32 {
    const duck_multiplier: f32 = if (player.grounded and player.ducked) 0.33333333 else 1.0;
    var scaled_wish_dir = wish_dir.scale(player.maxspeed);
    const max_speed = @min(player.maxspeed, scaled_wish_dir.getlength2D()) * duck_multiplier;
    if (player.grounded or not_aired) {
        return max_speed;
    }
    return @min(player.wish_speed_cap, max_speed);
}

pub fn getMaxAccel(player: *const PlayerInfo, wish_dir: Vector) f32 {
    const accel: f32 = if (player.grounded) player.accelerate else player.airaccelerate;
    return player.entity_friction * player.tick_time * getMaxSpeed(player, wish_dir, true) * accel;
}

pub fn createWishDir(player: *const PlayerInfo, forward_move: f32, side_move: f32) Vector {
    var wish_dir: Vector = .{
        .x = side_move,
        .y = forward_move,
    };

    if (wish_dir.getlength2D() > 1.0) {
        wish_dir = wish_dir.normalize();
    }

    const yaw = std.math.degreesToRadians(player.angles.y);

    wish_dir = Vector{
        .x = @sin(yaw) * wish_dir.x + @cos(yaw) * wish_dir.y,
        .y = -@cos(yaw) * wish_dir.x + @sin(yaw) * wish_dir.y,
    };

    const aircontrol_limit = 300;
    if (!player.grounded and player.velocity.getlength2D() > 300) {
        if (@abs(player.velocity.x) > aircontrol_limit * 0.5 and player.velocity.x * wish_dir.x < 0) {
            wish_dir.x = 0;
        }
        if (@abs(player.velocity.y) > aircontrol_limit * 0.5 and player.velocity.y * wish_dir.y < 0) {
            wish_dir.y = 0;
        }
    }

    return wish_dir;
}

pub fn getVelocityAfterMove(player: *const PlayerInfo, forward_move: f32, side_move: f32) Vector {
    const vel = getGroundFrictionVelocity(player);

    const wish_dir = createWishDir(player, forward_move, side_move);
    if (wish_dir.getlength2D() == 0) {
        return vel;
    }

    const max_speed = getMaxSpeed(player, wish_dir, false);
    const max_accel = getMaxAccel(player, wish_dir);

    const accel_diff = max_speed - vel.dotProduct(wish_dir.normalize());

    if (accel_diff <= 0) {
        return vel;
    }

    const accel_force = @min(max_accel, accel_diff);

    return vel.add(wish_dir.normalize().scale(accel_force));
}

pub fn getFastestStrafeAngle(player: *const PlayerInfo) f32 {
    const vel = getGroundFrictionVelocity(player);
    if (vel.getlength2D() == 0) {
        return 0;
    }

    const wish_dir: Vector = .{
        .x = 0,
        .y = 1,
    };

    const max_speed = getMaxSpeed(player, wish_dir, false);
    const max_accel = getMaxAccel(player, wish_dir);

    const cos_ang = (max_speed - max_accel) / vel.getlength2D();

    return std.math.acos(@min(@max(cos_ang, 0.0), 1.0));
}
