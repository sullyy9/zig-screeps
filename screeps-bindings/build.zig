const std = @import("std");
const Build = std.Build;
const CrossTarget = std.zig.CrossTarget;

var builder_instance: ?*std.Build = null;

pub fn build(b: *Build) void {
    builder_instance = b;
    
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("screeps-bindings", .{
        .root_source_file = .{ .path = "src/main.zig" },
        .optimize = optimize,
        .target = target,
    });
}

pub fn getJSSrc() []u8 {
    const b = builder_instance orelse @panic("Builder instance not initialized!");
    return b.pathFromRoot("src/jsbind/heap.js");
}
