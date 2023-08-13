const jsbind = @import("jsbind.zig");
const JSArray = jsbind.JSArray;
const JSObject = jsbind.JSObject;
const JSString = jsbind.JSString;
const jsObjectProperty = jsbind.jsObjectProperty;
const JSObjectReference = jsbind.JSObjectReference;

const room = @import("room.zig");
const Room = room.Room;
const RoomPosition = room.RoomPosition;

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

pub const Owner = struct {
    obj: JSObject,

    const Self = @This();
    pub usingnamespace JSObjectReference(Self);

    pub const getUsername = jsObjectProperty(Self, "username", JSString);
};

pub fn RoomObject(comptime Self: type) type {
    return struct {
        pub const getEffects = jsObjectProperty(Self, "effects", JSArray(Effect));
        pub const getPos = jsObjectProperty(Self, "pos", RoomPosition);
        pub const getRoom = jsObjectProperty(Self, "room", Room);
    };
}

pub fn OwnedObject(comptime Self: type) type {
    return struct {
        pub const getIsMy = jsObjectProperty(Self, "my", bool);
        pub const getOwner = jsObjectProperty(Self, "owner", Owner);
    };
}

pub fn DamageableObject(comptime Self: type) type {
    return struct {
        pub const getHits = jsObjectProperty(Self, "hits", u32);
        pub const getHitsMax = jsObjectProperty(Self, "hitsMax", u32);
    };
}
