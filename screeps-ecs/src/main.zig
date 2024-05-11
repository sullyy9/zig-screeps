const ecs = @import("ecs.zig");
const query = @import("query.zig");
const world = @import("world/mod.zig");
const system = @import("system/mod.zig");

pub const ECS = ecs.ECS;
pub const Query = query.Query;
pub const SystemRegistry = system.Registry;
pub const EntityID = world.EntityID;

test {
    const std = @import("std");
    std.testing.refAllDeclsRecursive(@import("ecs.zig"));
    std.testing.refAllDeclsRecursive(@import("query.zig"));
    std.testing.refAllDeclsRecursive(@import("world/mod.zig"));
}
