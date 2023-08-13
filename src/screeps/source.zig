const jsbind = @import("jsbind.zig");
const JSArray = jsbind.JSArray;
const JSObject = jsbind.JSObject;
const JSString = jsbind.JSString;
const jsObjectProperty = jsbind.jsObjectProperty;
const JSObjectReference = jsbind.JSObjectReference;

const object = @import("object.zig");
const RoomObject = object.RoomObject;

pub const Source = struct {
    obj: JSObject,

    const Self = @This();
    pub usingnamespace JSObjectReference(Self);
    pub usingnamespace RoomObject(Self);
};
