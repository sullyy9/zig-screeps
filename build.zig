const std = @import("std");

const sysjs = @import("lib/mach-sysjs/build.zig");

pub fn build(b: *std.build.Builder) void {
    const lib = b.addSharedLibrary("zig-screeps", "src/main.zig", b.version(0, 0, 0));
    lib.rdynamic = true;

    lib.addPackage(sysjs.pkg);

    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();
    lib.setBuildMode(mode);

    lib.install();

    const main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
