const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = std.Target.Query.parse(.{
            .arch_os_abi = "x86-native-gnu",
        }) catch unreachable,
    });
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "pod",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();

    const zhook = b.addModule("zhook", .{
        .root_source_file = b.path("libs/zhook/zhook.zig"),
    });
    lib.root_module.addImport("zhook", zhook);

    b.installArtifact(lib);
}
