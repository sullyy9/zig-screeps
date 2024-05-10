const world = @import("world.zig");
const component = @import("component.zig");

pub const archetype = @import("archetype.zig");

pub const isComponent = component.isComponent;
pub const assertIsComponent = component.assertIsComponent;
pub const requireIsComponent = component.requireIsComponent;

pub const ArchetypeTable = archetype.ArchetypeTable;
pub const World = world.World;
pub const EntityID = world.EntityID;

test {
    const std = @import("std");
    std.testing.refAllDeclsRecursive(@import("world.zig"));
    std.testing.refAllDeclsRecursive(@import("typeid.zig"));
    std.testing.refAllDeclsRecursive(@import("archetype.zig"));
    std.testing.refAllDeclsRecursive(@import("component.zig"));
}
