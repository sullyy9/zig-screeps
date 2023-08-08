const js = @import("js_bind.zig");

const room = @import("room.zig");

const RoomObject = room.RoomObject;

pub const Source = struct {
    obj: js.Object,

    const Self = @This();
    pub usingnamespace js.ObjectReference(Self);
    pub usingnamespace RoomObject(Self);
};
