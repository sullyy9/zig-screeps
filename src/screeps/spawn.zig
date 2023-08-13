const std = @import("std");

const jsbind = @import("jsbind.zig");
const JSArray = jsbind.JSArray;
const JSObject = jsbind.JSObject;
const JSString = jsbind.JSString;
const jsObjectProperty = jsbind.jsObjectProperty;
const JSObjectReference = jsbind.JSObjectReference;

const constants = @import("constants.zig");
const ErrorVal = constants.ErrorVal;
const ScreepsError = constants.ScreepsError;

const creep = @import("creep.zig");
const Creep = creep.Creep;
const CreepBlueprint = creep.Blueprint;

const object = @import("object.zig");
const Store = object.Store;
const RoomObject = object.RoomObject;
const OwnedObject = object.OwnedObject;
const DamageableObject = object.DamageableObject;

pub const Spawn = struct {
    obj: JSObject,

    const Self = @This();
    pub usingnamespace JSObjectReference(Self);
    pub usingnamespace RoomObject(Self);
    pub usingnamespace OwnedObject(Self);
    pub usingnamespace DamageableObject(Self);

    pub const getName = jsObjectProperty(Self, "name", JSString);
    pub const getID = jsObjectProperty(Self, "id", JSString);
    pub const getStore = jsObjectProperty(Self, "store", Store);
    // pub const getSpawning = jsObjectProperty(Self, "spawning", bool);

    /// Spawn a new creep.
    ///
    pub fn spawnCreep(self: *const Spawn, blueprint: *const CreepBlueprint) !void {
        const parts = JSArray(JSString).new();

        for (blueprint.parts, 0..) |part, i| {
            parts.set(i, JSString.from(@tagName(part)));
        }

        const result = self.obj.call("spawnCreep", &.{ parts, JSString.from(blueprint.name) }, ErrorVal);
        if (result.toError()) |err| {
            return err;
        }
    }
};
