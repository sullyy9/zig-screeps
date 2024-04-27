const std = @import("std");
const Build = std.Build;
const CrossTarget = std.zig.CrossTarget;
const LazyPath = Build.LazyPath;

const ai = @import("screeps_ai");
const bindings = @import("screeps_bindings");

pub fn build(b: *Build) !void {
    const target_native = b.resolveTargetQuery(.{});
    const target_wasm = b.resolveTargetQuery(CrossTarget{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    const optimize = b.standardOptimizeOption(.{});

    const screeps_ai = b.dependency("screeps_ai", .{
        .target = target_wasm,
        .optimize = optimize,
    });

    // Convert absolute paths to relative.
    const js_main_path = try absToRelPath(b, ai.getJSMain());
    defer b.allocator.free(js_main_path);
    const js_src_path = try absToRelPath(b, bindings.getJSSrc());
    defer b.allocator.free(js_src_path);

    b.installFile(js_main_path, "bin/main.js");
    b.installFile(js_src_path, "bin/heap.js");
    b.installArtifact(screeps_ai.artifact("screeps-ai"));

    const screeps_ecs = b.dependency("screeps_ecs", .{
        .target = target_native,
        .optimize = optimize,
    });

    const run_ecs_tests = b.addRunArtifact(screeps_ecs.artifact("screeps-ecs-test"));
    run_ecs_tests.has_side_effects = true;

    const test_ecs_step = b.step("test-ecs", "Run tests");
    test_ecs_step.dependOn(&run_ecs_tests.step);

    const test_all_step = b.step("test-all", "Run tests");
    test_all_step.dependOn(&run_ecs_tests.step);
}

fn absToRelPath(b: *Build, abs: []const u8) std.mem.Allocator.Error![]u8 {
    const rel_path_size = std.mem.replacementSize(u8, abs, b.pathFromRoot("."), ".");
    const rel_path = try b.allocator.alloc(u8, rel_path_size);
    _ = std.mem.replace(u8, abs, b.pathFromRoot("."), ".", rel_path);
    return rel_path;
}
