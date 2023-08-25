const jsbind = @import("jsbind.zig");
const JSArray = jsbind.JSArray;
const JSObject = jsbind.JSObject;
const JSString = jsbind.JSString;
const jsObjectProperty = jsbind.jsObjectProperty;
const JSObjectReference = jsbind.JSObjectReference;

const room = @import("room.zig");
const spawn = @import("spawn.zig");
const creep = @import("creep.zig");
const constants = @import("constants.zig");

const Spawn = spawn.Spawn;
const Creep = creep.Creep;
const Room = room.Room;
const ScreepsError = constants.ScreepsError;

pub const Game = struct {
    obj: JSObject,

    const Self = @This();
    pub usingnamespace JSObjectReference(Self);

    pub const getTime = jsObjectProperty(Self, "time", u32);

    /// Description
    /// -----------
    /// Return a Game instance from a reference to the Javascript Game object.
    ///
    /// Parameters
    /// ----------
    /// - ref: Reference of the Javascript Game object.
    ///
    pub fn fromRef(ref: u64) Self {
        return Self{ .obj = JSObject.fromRef(ref) };
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
        const spawns = self.obj.get("spawns", JSObject);

        const has_spawn = spawns.call("hasOwnProperty", &.{JSString.from(name)}, bool);
        if (!has_spawn) {
            return ScreepsError.NotFound;
        }

        return Spawn{
            .name = name,
            .obj = spawns.get(name, JSObject),
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
    pub fn getSpawns(self: *const Self) JSArray(Spawn) {
        const spawns = self.obj.get("spawns", JSObject);
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
    pub fn getCreeps(self: *const Self) JSArray(Creep) {
        const creeps = self.obj.get("creeps", JSObject);
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
    pub fn getRooms(self: *const Self) JSArray(Room) {
        const creeps = self.obj.get("rooms", JSObject);
        return creeps.getValues(Room);
    }

    pub fn getCreepByName(self: *const Self, name: []const u8) Creep {
        const creeps = self.obj.get("creeps", JSObject);
        return creeps.get(name, Creep); // Should check it exists first.
    }

    pub fn getObjectByID(self: *const Self, id: []const u8, comptime T: type) ?T {
        return self.obj.call("getObjectById", &.{JSString.from(id)}, ?T);
    }
};
