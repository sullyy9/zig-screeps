const std = @import("std");

const jsbind = @import("../jsbind/jsbind.zig");
const JSArray = jsbind.JSArray;
const JSObject = jsbind.JSObject;
const JSString = jsbind.JSString;
const jsObjectProperty = jsbind.jsObjectProperty;
const JSObjectReference = jsbind.JSObjectReference;

const constants = @import("constants.zig");
const SearchTarget = constants.SearchTarget;

pub const Room = struct {
    obj: JSObject,

    const Self = @This();
    pub usingnamespace JSObjectReference(Self);

    pub const getName = jsObjectProperty(Self, "name", JSString);

    pub fn find(self: *const Self, comptime target: SearchTarget) JSArray(target.getType()) {
        return self.obj.call("find", &.{target}, JSArray(target.getType()));
    }
};

pub const RoomPosition = struct {
    obj: JSObject,

    const Self = @This();
    pub usingnamespace JSObjectReference(Self);

    pub const getRoomName = jsObjectProperty(Self, "roomName", JSString);
    pub const getX = jsObjectProperty(Self, "x", u32);
    pub const getY = jsObjectProperty(Self, "y", u32);
};
