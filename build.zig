const std = @import("std");
const Build = std.Build;
const CrossTarget = std.zig.CrossTarget;

pub fn build(b: *Build) void {
    const target = b.resolveTargetQuery(CrossTarget{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zig-screeps",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.entry = .disabled;
    exe.rdynamic = true;

    const sysjs_mod = b.createModule(.{
        .root_source_file = b.path("lib/mach-sysjs/src/main.zig"),
    });

    exe.root_module.addImport("sysjs", sysjs_mod);

    b.installFile("src/main.js", "./lib/main.js");
    b.installFile("lib/mach-sysjs/src/mach-sysjs.js", "./lib/mach-sysjs.js");

    b.installArtifact(exe);
}
