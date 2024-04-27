const std = @import("std");
const Build = std.Build;
const CrossTarget = std.zig.CrossTarget;

var builder_instance: ?*std.Build = null;

pub fn build(b: *Build) !void {
    builder_instance = b;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "screeps-ai",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.entry = .disabled;
    exe.rdynamic = true;

    const screeps_bindings = b.dependency("screeps_bindings", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("screeps-bindings", screeps_bindings.module("screeps-bindings"));

    b.installArtifact(exe);
}

pub fn getJSMain() []u8 {
    const b = builder_instance orelse @panic("Builder instance not initialized!");
    return b.pathFromRoot("src/main.js");
}
