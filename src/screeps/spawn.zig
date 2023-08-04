const js = @import("../js_bind.zig");
const constants = @import("constants.zig");
const creep = @import("creep.zig");

const Creep = creep.Creep;
const ErrorVal = constants.ErrorVal;
const ScreepsError = constants.ScreepsError;

pub const Spawn = struct {
    name: []const u8,
    obj: js.Object,

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

    /// Spawn a new creep.
    ///
    pub fn spawnCreep(self: *const Spawn, blueprint: *const Creep) !void {
        const parts: js.Array = js.Array.new();

        for (blueprint.parts) |part, i| {
            parts.set(i, js.String.from(@tagName(part)));
        }

        const result = try self.obj.call("spawnCreep", &.{ parts, js.String.from(blueprint.name) }, ErrorVal);
        if (result.toError()) |err| {
            return err;
        }
    }
};
