const std = @import("std");

const jsbind = @import("jsbind.zig");
const JSArray = jsbind.JSArray;
const JSObject = jsbind.JSObject;
const JSString = jsbind.JSString;
const jsObjectProperty = jsbind.jsObjectProperty;
const JSObjectReference = jsbind.JSObjectReference;

const constants = @import("constants.zig");
const creep = @import("creep.zig");

const Creep = creep.Creep;
const CreepBlueprint = creep.Blueprint;
const ErrorVal = constants.ErrorVal;
const ScreepsError = constants.ScreepsError;

pub const Spawn = struct {
    obj: JSObject,

    const Self = @This();
    pub usingnamespace JSObjectReference(Self);

    pub const getName = jsObjectProperty(Self, "name", JSString);

    /// Spawn a new creep.
    ///
    pub fn spawnCreep(self: *const Spawn, blueprint: *const CreepBlueprint) !void {
        const parts = JSArray(JSString).new();

        for (blueprint.parts) |part, i| {
            parts.set(i, JSString.from(@tagName(part)));
        }

        const result = self.obj.call("spawnCreep", &.{ parts, JSString.from(blueprint.name) }, ErrorVal);
        if (result.toError()) |err| {
            return err;
        }
    }
};
