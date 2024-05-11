const system = @import("system.zig");
const registry = @import("registry.zig");

pub const isSystem = system.isSystem;
pub const assertIsSystem = system.assertIsSystem;
pub const requireIsSystem = system.requireIsSystem;

pub const Registry = registry.Registry;
