const world = @import("world.zig");
const components = @import("components/mod.zig");

pub const isComponent = components.isComponent;
pub const assertIsComponent = components.assertIsComponent;
pub const requireIsComponent = components.requireIsComponent;

pub const assertIsArchetype = components.assertIsArchetype;

pub const World = world.World;
pub const EntityID = world.EntityID;
pub const ArchetypeTable = components.ArchetypeTable;

test {
    const std = @import("std");
    std.testing.refAllDeclsRecursive(@import("world.zig"));
    std.testing.refAllDeclsRecursive(@import("typeid.zig"));
    std.testing.refAllDeclsRecursive(@import("resource.zig"));
    std.testing.refAllDeclsRecursive(@import("components/mod.zig"));
}
