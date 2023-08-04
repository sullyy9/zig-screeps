const js = @import("../js_bind.zig");

pub const Game = struct {
    obj: js.Object,

    const Self = @This();

    pub fn fromRef(ref: u64) Self {
        return Self{ .obj = js.Object.fromRef(ref) };
    }

    pub fn spawns(self: *const Self) !js.Object {
        return self.obj.get("spawns", js.Object);
    }
};
