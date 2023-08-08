const js = @import("js_bind.zig");
const room = @import("room.zig");
const spawn = @import("spawn.zig");
const creep = @import("creep.zig");
const constants = @import("constants.zig");

const Spawn = spawn.Spawn;
const Creep = creep.Creep;
const Room = room.Room;
const ScreepsError = constants.ScreepsError;

pub const Game = struct {
    obj: js.Object,

    const Self = @This();
    pub usingnamespace js.ObjectReference(Self);

    /// Description
    /// -----------
    /// Return a Game instance from a reference to the Javascript Game object.
    ///
    /// Parameters
    /// ----------
    /// - ref: Reference of the Javascript Game object.
    ///
    pub fn fromRef(ref: u64) Self {
        return Self{ .obj = js.Object.fromRef(ref) };
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

    /// Description
    /// -----------
    /// Return an array of all owned spawners.
    ///
    /// Returns
    /// -------
    /// A Javascript array of owned spawns.
    ///
    pub fn getSpawns(self: *const Self) !js.Array(Spawn) {
        const spawns = try self.obj.get("spawns", js.Object);
        return spawns.getValues(Spawn);
    }

    /// Description
    /// -----------
    /// Return an array of all owned creeps.
    ///
    /// Returns
    /// -------
    /// A Javascript array of owned creeps.
    ///
    pub fn getCreeps(self: *const Self) !js.Array(Creep) {
        const creeps = try self.obj.get("creeps", js.Object);
        return creeps.getValues(Creep);
    }

    /// Description
    /// -----------
    /// Return an array of all visible rooms.
    ///
    /// Returns
    /// -------
    /// A Javascript array of visible rooms.
    ///
    pub fn getRooms(self: *const Self) !js.Array(Room) {
        const creeps = try self.obj.get("rooms", js.Object);
        return creeps.getValues(Room);
    }
};
