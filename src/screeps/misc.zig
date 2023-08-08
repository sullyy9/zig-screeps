const std = @import("std");

const js = @import("js_bind.zig");

const Effect = struct {
    obj: js.Object,

    const Self = @This();
    pub usingnamespace js.ObjectReference(Self);

    pub fn getID(self: *const Self) u32 {
        return self.obj.get("effect", u32);
    }

    pub fn getLevel(self: *const Self) u32 {
        return self.obj.get("level", u32);
    }

    pub fn getTicksRemaining(self: *const Self) u32 {
        return self.obj.get("ticksRemaining", u32);
    }
};
