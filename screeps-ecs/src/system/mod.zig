const param = @import("param.zig");
const system = @import("system.zig");
const registry = @import("registry.zig");
const scheduler = @import("scheduler.zig");

pub const isSystem = system.isSystem;
pub const assertIsSystem = system.assertIsSystem;
pub const requireIsSystem = system.requireIsSystem;

pub const Registry = registry.Registry;
pub const Scheduler = scheduler.Scheduler;

test {
    const std = @import("std");
    std.testing.refAllDeclsRecursive(@import("param.zig"));
    std.testing.refAllDeclsRecursive(@import("system.zig"));
    std.testing.refAllDeclsRecursive(@import("registry.zig"));
    std.testing.refAllDeclsRecursive(@import("scheduler.zig"));
}
