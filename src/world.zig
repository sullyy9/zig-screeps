const std = @import("std");

const screeps = @import("screeps/screeps.zig");

const Array = screeps.js.Array;
const ArrayIterator = screeps.js.ArrayIterator;

const Game = screeps.Game;
const Room = screeps.Room;
const Spawn = screeps.Spawn;
const Creep = screeps.Creep;

pub const World = struct {
    allocator: std.mem.Allocator,
    rooms: []Room,
    spawns: []Spawn,
    creeps: []Creep,

    const Self = @This();

    /// Description
    /// -----------
    /// Return a new empty World instance. Deinitialise with deinit.
    ///
    /// Parameters
    /// ----------
    /// allocator: Allocator.
    ///
    /// Returns
    /// -------
    /// A new empty World instance.
    ///
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .spawners = undefined,
            .creeps = undefined,
        };
    }

    /// Description
    /// -----------
    /// Release all allocated memory.
    ///
    pub fn deinit(self: *const Self) void {
        if (self.spawns.len != 0) {
            self.allocator.free(self.spawns);
        }
        if (self.creeps.len != 0) {
            self.allocator.free(self.creeps);
        }
    }

    /// Description
    /// -----------
    /// Return a new World instance loaded solely from the game object.
    /// This method requires more WASM <-> Javascript boundry crossing so is presumably slower.
    ///
    /// Parameters
    /// ----------
    /// allocator: Allocator.
    /// game: Game object to load the World instance from.
    ///
    /// Returns
    /// -------
    /// A new World instance.
    ///
    pub fn fromGame(allocator: std.mem.Allocator, game: *const Game) !Self {
        const spawns = blk: {
            const spawns = try game.getSpawns();
            break :blk try spawns.getOwnedSlice(allocator);
        };
        errdefer allocator.free(spawns);

        const creeps = blk: {
            const creeps = try game.getCreeps();
            break :blk try creeps.getOwnedSlice(allocator);
        };
        errdefer allocator.free(creeps);

        const rooms = blk: {
            const rooms = try game.getRooms();
            break :blk try rooms.getOwnedSlice(allocator);
        };
        errdefer allocator.free(rooms);

        return Self{
            .allocator = allocator,
            .spawns = spawns,
            .creeps = creeps,
            .rooms = rooms,
        };
    }

    /// Description
    /// -----------
    /// Return a new World instance loaded from memory and the game object.
    /// This method uses ID's stored in memory to know what objects to request from the Game object.
    /// If persistant memory gets wiped out, this method won't be viable.
    ///
    /// Parameters
    /// ----------
    /// game: Game object to load the World instance from.
    /// memory: Memory to load the World instance from.
    ///
    /// Returns
    /// -------
    /// A new World instance.
    ///
    pub fn fromMemory(allocator: std.mem.Allocator, game: *const Game, memory: []const u8) Self {
        _ = allocator;
        _ = memory;
        _ = game;
        unreachable;
    }
};
