const world = @import("world.zig");
const components = @import("components/mod.zig");
const resources = @import("resources/mod.zig");

pub const isComponent = components.isComponent;
pub const assertIsComponent = components.assertIsComponent;
pub const requireIsComponent = components.requireIsComponent;

pub const Resource = resources.Resource;
pub const isResource = resources.isResource;
pub const assertIsResource = resources.assertIsResource;
pub const requireIsResource = resources.requireIsResource;
pub const ResourceConstraintError = resources.ConstraintError;

pub const assertIsArchetype = components.assertIsArchetype;

pub const World = world.World;
pub const EntityID = world.EntityID;
pub const ArchetypeTable = components.ArchetypeTable;

test {
    const std = @import("std");
    std.testing.refAllDeclsRecursive(@import("world.zig"));
    std.testing.refAllDeclsRecursive(@import("typeid.zig"));
    std.testing.refAllDeclsRecursive(@import("components/mod.zig"));
    std.testing.refAllDeclsRecursive(@import("resources/mod.zig"));
}
