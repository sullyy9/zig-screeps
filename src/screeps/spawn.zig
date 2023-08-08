const std = @import("std");

const js = @import("js_bind.zig");
const constants = @import("constants.zig");
const creep = @import("creep.zig");

const Creep = creep.Creep;
const CreepBlueprint = creep.Blueprint;
const ErrorVal = constants.ErrorVal;
const ScreepsError = constants.ScreepsError;

pub const Spawn = struct {
    obj: js.Object,

    const Self = @This();
    pub usingnamespace js.ObjectReference(Self);

    /// Description
    /// -----------
    /// Return the name of the Spawn.
    ///
    /// Returns
    /// -------
    /// The spawn's name.
    ///
    pub fn getName(self: *const Self) js.String {
        return self.obj.get("name", js.String);
    }

    /// Spawn a new creep.
    ///
    pub fn spawnCreep(self: *const Spawn, blueprint: *const CreepBlueprint) !void {
        const parts = js.Array(js.String).new();

        for (blueprint.parts) |part, i| {
            parts.set(i, js.String.from(@tagName(part)));
        }

        const result = self.obj.call("spawnCreep", &.{ parts, js.String.from(blueprint.name) }, ErrorVal);
        if (result.toError()) |err| {
            return err;
        }
    }
};
