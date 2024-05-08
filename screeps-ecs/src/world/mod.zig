const world = @import("world.zig");
pub const archetype = @import("archetype.zig");

pub const ArchetypeTable = archetype.ArchetypeTable;
pub const World = world.World;
pub const EntityID = world.EntityID;

test {
    const std = @import("std");
    std.testing.refAllDeclsRecursive(@import("world.zig"));
    std.testing.refAllDeclsRecursive(@import("typeid.zig"));
    std.testing.refAllDeclsRecursive(@import("archetype.zig"));
}
