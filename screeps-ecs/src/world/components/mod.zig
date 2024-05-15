const archetype = @import("archetype.zig");
const component = @import("component.zig");
const table = @import("table.zig");

pub const isComponent = component.isComponent;
pub const assertIsComponent = component.assertIsComponent;
pub const requireIsComponent = component.requireIsComponent;

pub const assertIsArchetype = archetype.assertIsArchetype;

pub const ArchetypeTable = table.ArchetypeTable;

test {
    const std = @import("std");
    std.testing.refAllDeclsRecursive(@import("archetype.zig"));
    std.testing.refAllDeclsRecursive(@import("component.zig"));
    std.testing.refAllDeclsRecursive(@import("storage.zig"));
    std.testing.refAllDeclsRecursive(@import("table.zig"));
}
