const ecs = @import("ecs.zig");
const query = @import("query.zig");
const world = @import("world.zig");

pub const ECS = ecs.ECS;
pub const Query = query.Query;
pub const Systems = ecs.Systems;
pub const EntityID = world.EntityID;

test {
    const std = @import("std");
    std.testing.refAllDeclsRecursive(@import("ecs.zig"));
    std.testing.refAllDeclsRecursive(@import("query.zig"));
    std.testing.refAllDeclsRecursive(@import("world.zig"));
    std.testing.refAllDeclsRecursive(@import("typeid.zig"));
    std.testing.refAllDeclsRecursive(@import("archetype.zig"));
}
