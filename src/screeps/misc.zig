const std = @import("std");

const js = @import("js_bind.zig");

pub const Effect = struct {
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

pub const Store = struct {
    obj: js.Object,

    const Self = @This();
    pub usingnamespace js.ObjectReference(Self);

    pub fn getCapacity(self: *const Self) u32 {
        return self.obj.call("getCapacity", &.{}, u32);
    }

    pub fn getFreeCapacity(self: *const Self) u32 {
        return self.obj.call("getFreeCapacity", &.{}, u32);
    }

    pub fn getUsedCapacity(self: *const Self) u32 {
        return self.obj.call("getUsedCapacity", &.{}, u32);
    }
};
