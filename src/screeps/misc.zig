const std = @import("std");

const js = @import("js_bind.zig");

pub const Effect = struct {
    obj: js.Object,

    const Self = @This();
    pub usingnamespace js.ObjectReference(Self);

    pub const getID = js.ObjectProperty(Self, "effect", u32);
    pub const getLevel = js.ObjectProperty(Self, "level", u32);
    pub const getTicksRemaining = js.ObjectProperty(Self, "ticksRemaining", u32);
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
