const world = @import("../world/mod.zig");
const Resource = world.Resource;

pub const Counter = struct {
    const Self = @This();

    pub usingnamespace Resource;

    count: u32,

    pub fn init() Self {
        return Self{ .count = 0 };
    }

    pub fn increment(self: *Self) void {
        self.count += 1;
    }
};

pub const Movement = union(enum) {
    const Self = @This();

    pub usingnamespace Resource;

    standing: bool,
    walking: u32,
    running: i32,
};
