const std = @import("std");
const Build = std.Build;
const LazyPath = Build.LazyPath;

pub fn build(b: *Build) void {
    const lib = b.addSharedLibrary(.{
        .name = "zig-screeps",
        .root_source_file = LazyPath.relative("src/main.zig"),
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
        .optimize = b.standardOptimizeOption(.{}),
    });
    lib.rdynamic = true;

    const sysjs_mod = b.createModule(.{
        .source_file = LazyPath.relative("lib/mach-sysjs/src/main.zig"),
    });

    lib.addModule("sysjs", sysjs_mod);

    b.installArtifact(lib);
}
