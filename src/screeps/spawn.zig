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

    /// Load a Spawn from the game world.
    ///
    pub fn fromGame(game: *const js.Object, name: []const u8) !Spawn {
        const spawns = try game.get("spawns", js.Object);

        const has_spawn = try spawns.call("hasOwnProperty", &.{js.String.from(name)}, bool);
        if (!has_spawn) {
            return constants.ScreepsError.NotFound;
        }

        return Spawn{
            .name = name,
            .obj = try spawns.get(name, js.Object),
        };
    }

    /// Description
    /// -----------
    /// Return the reference of the Javascript object this holds.
    ///
    /// Returns
    /// -------
    /// Reference to a Javascript object.
    ///
    pub fn getRef(self: *const Self) u64 {
        return self.obj.getRef();
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
