const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const typeid = @import("typeid.zig");
const typeID = typeid.typeID;

pub const archetype = @import("archetype.zig");
pub const world = @import("world.zig");
pub const ecs = @import("ecs.zig");
pub const query = @import("query.zig");

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}
