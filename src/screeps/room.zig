const std = @import("std");

const js = @import("js_bind.zig");
const constants = @import("constants.zig");
const misc = @import("misc.zig");

const Effect = misc.Effect;
const SearchTarget = constants.SearchTarget;

pub const Room = struct {
    obj: js.Object,

    const Self = @This();
    pub usingnamespace js.ObjectReference(Self);

    pub const getName = js.ObjectProperty(Self, "name", js.String);

    pub fn find(self: *const Self, comptime target: SearchTarget) js.Array(target.getType()) {
        return self.obj.call("find", &.{target}, js.Array(target.getType()));
    }
};

pub fn RoomObject(comptime Self: type) type {
    js.assertIsJSObjectReference(Self);

    return struct {
        pub const getEffects = js.ObjectProperty(Self, "effects", js.Array(Effect));
        pub const getPos = js.ObjectProperty(Self, "pos", RoomPosition);
        pub const getRoom = js.ObjectProperty(Self, "room", Room);
        pub const getID = js.ObjectProperty(Self, "id", js.String);
    };
}

pub const RoomPosition = struct {
    obj: js.Object,

    const Self = @This();
    pub usingnamespace js.ObjectReference(Self);

    pub const getRoomName = js.ObjectProperty(Self, "roomName", js.String);
    pub const getX = js.ObjectProperty(Self, "x", u32);
    pub const getY = js.ObjectProperty(Self, "y", u32);
};
