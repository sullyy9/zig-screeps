const std = @import("std");

const jsbind = @import("jsbind.zig");
const JSObject = jsbind.JSObject;
const jsObjectProperty = jsbind.jsObjectProperty;
const JSObjectReference = jsbind.JSObjectReference;

pub const Effect = struct {
    obj: JSObject,

    const Self = @This();
    pub usingnamespace JSObjectReference(Self);

    pub const getID = jsObjectProperty(Self, "effect", u32);
    pub const getLevel = jsObjectProperty(Self, "level", u32);
    pub const getTicksRemaining = jsObjectProperty(Self, "ticksRemaining", u32);
};

pub const Store = struct {
    obj: JSObject,

    const Self = @This();
    pub usingnamespace JSObjectReference(Self);

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
