const std = @import("std");

const js = @import("js_bind.zig");
const constants = @import("constants.zig");
const creep = @import("creep.zig");

const Creep = creep.Creep;
const CreepBlueprint = creep.Blueprint;
const ErrorVal = constants.ErrorVal;
const ScreepsError = constants.ScreepsError;

pub const Spawn = struct {
    name: []const u8,
    obj: js.Object,

    const Self = @This();
    pub const js_tag = js.Value.Tag.object;

    comptime {
        js.assertIsJSObjectReference(Self);
    }

    /// Description
    /// -----------
    /// Return a new Spawn from a generic value referencing an existing Javascript object.
    ///
    /// Parameters
    /// ----------
    /// - value: Generic value type.
    ///
    /// Returns
    /// -------
    /// New Spawn referencing an existing Javascript object.
    ///
    pub fn fromValue(value: *const js.Value) Self {
        return Self{ .name = "", .obj = js.Object.fromValue(value) };
    }

    /// Description
    /// -----------
    /// Return a generic Value referening this Javascript object.
    ///
    /// Returns
    /// -------
    /// Generic value referencing the Javascript object.
    ///
    pub fn asValue(self: *const Self) js.Value {
        return js.Value{ .tag = .object, .val = .{ .ref = self.obj.ref } };
    }

    /// Description
    /// -----------
    /// Return the name of the Spawn.
    ///
    /// Returns
    /// -------
    /// The spawn's name.
    ///
    pub fn getName(self: *const Self) !js.String {
        return self.obj.get("name", js.String);
    }

    /// Spawn a new creep.
    ///
    pub fn spawnCreep(self: *const Spawn, blueprint: *const CreepBlueprint) !void {
        const parts = js.Array(js.String).new();

        for (blueprint.parts) |part, i| {
            parts.set(i, js.String.from(@tagName(part)));
        }

        const result = try self.obj.call("spawnCreep", &.{ parts, js.String.from(blueprint.name) }, ErrorVal);
        if (result.toError()) |err| {
            return err;
        }
    }
};
