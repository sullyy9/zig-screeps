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

    /// Description
    /// -----------
    /// Return the name of the Room.
    ///
    /// Returns
    /// -------
    /// The room's name.
    ///
    pub fn getName(self: *const Self) js.String {
        return self.obj.get("name", js.String);
    }

    pub fn find(self: *const Self, comptime target: SearchTarget) js.Array(target.getType()) {
        return self.obj.call("find", &.{target}, js.Array(target.getType()));
    }
};

pub fn RoomObject(comptime Self: type) type {
    js.assertIsJSObjectReference(Self);

    return struct {
        pub fn getEffects(self: *const Self) js.Array(Effect) {
            return self.obj.get("effects", js.Array(Effect));
        }

        pub fn getPos(self: *const Self) RoomPosition {
            return self.obj.get("pos", RoomPosition);
        }

        pub fn getRoom(self: *const Self) Room {
            return self.obj.get("room", Room);
        }

        pub fn getID(self: *const Self) js.String {
            return self.obj.get("id", js.String);
        }
    };
}

pub const RoomPosition = struct {
    obj: js.Object,

    const Self = @This();
    pub usingnamespace js.ObjectReference(Self);

    pub fn getRoomName(self: *const Self) js.String {
        return self.obj.get("roomName", js.String);
    }

    pub fn getX(self: *const Self) u32 {
        return self.obj.get("x", u32);
    }

    pub fn getY(self: *const Self) u32 {
        return self.obj.get("y", u32);
    }
};
