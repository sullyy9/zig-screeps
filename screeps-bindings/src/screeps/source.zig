const jsbind = @import("../jsbind/jsbind.zig");
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

    pub const getID = jsObjectProperty(Self, "id", JSString);
    pub const getEnergy = jsObjectProperty(Self, "energy", u32);
    pub const getEnergyCapacity = jsObjectProperty(Self, "energyCapacity", u32);
};
