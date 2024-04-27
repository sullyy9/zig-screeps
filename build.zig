const std = @import("std");
const Build = std.Build;
const CrossTarget = std.zig.CrossTarget;
const LazyPath = Build.LazyPath;

const ai = @import("screeps_ai");
const bindings = @import("screeps_bindings");

pub fn build(b: *Build) !void {
    const target = b.resolveTargetQuery(CrossTarget{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    const optimize = b.standardOptimizeOption(.{});

    const screeps_ai = b.dependency("screeps_ai", .{
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(screeps_ai.artifact("screeps-ai"));

    // Convert absolute paths to relative.
    const js_main_path_size = std.mem.replacementSize(u8, ai.getJSMain(), b.pathFromRoot("."), ".");
    const js_main_path = try b.allocator.alloc(u8, js_main_path_size);
    _ = std.mem.replace(u8, ai.getJSMain(), b.pathFromRoot("."), ".", js_main_path);

    const js_src_path_size = std.mem.replacementSize(u8, bindings.getJSSrc(), b.pathFromRoot("."), ".");
    const js_src_path = try b.allocator.alloc(u8, js_src_path_size);
    _ = std.mem.replace(u8, bindings.getJSSrc(), b.pathFromRoot("."), ".", js_src_path);

    b.installFile(js_main_path, "bin/main.js");
    b.installFile(js_src_path, "bin/heap.js");
}
