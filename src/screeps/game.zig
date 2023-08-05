const js = @import("js_bind.zig");
const spawn = @import("spawn.zig");
const constants = @import("constants.zig");

const Spawn = spawn.Spawn;
const ScreepsError = constants.ScreepsError;

pub const Game = struct {
    obj: js.Object,

    const Self = @This();
    pub const js_tag = js.Value.Tag.object;

    pub fn fromRef(ref: u64) Self {
        return Self{ .obj = js.Object.fromRef(ref) };
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
    /// Return the spawn with the given name.
    ///
    /// Parameters
    /// ----------
    /// name: Name of the spawn.
    ///
    /// Returns
    /// -------
    /// The spawn or an error.
    ///
    pub fn getSpawn(self: *const Self, name: []const u8) !Spawn {
        const spawns = try self.obj.get("spawns", js.Object);

        const has_spawn = try spawns.call("hasOwnProperty", &.{js.String.from(name)}, bool);
        if (!has_spawn) {
            return ScreepsError.NotFound;
        }

        return Spawn{
            .name = name,
            .obj = try spawns.get(name, js.Object),
        };
    }
};
