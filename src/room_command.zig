const std = @import("std");
const rand = std.rand;

const screeps = @import("screeps/screeps.zig");
const Room = screeps.Room;
const Spawn = screeps.Spawn;
const Creep = screeps.Creep;
const Source = screeps.Source;
const Resource = screeps.Resource;
const CreepPart = screeps.CreepPart;
const SearchTarget = screeps.SearchTarget;
const ScreepsError = screeps.ScreepsError;
const CreepBlueprint = screeps.CreepBlueprint;

pub const RoomObjects = struct {
    spawns: []const Spawn,
    creeps: []const Creep,
    sources: []const Source,

    allocator: std.mem.Allocator,

    const Self = @This();

    /// Description
    /// -----------
    /// Deinitialise the room objects object.
    ///
    pub fn deinit(self: *const Self) void {
        self.allocator.free(self.spawns);
        self.allocator.free(self.creeps);
    }

    /// Description
    /// -----------
    /// Load the objects present within a given room.
    ///
    /// Parameters
    /// ----------
    /// allocator: Allocator
    /// room: Room to load objects from.
    ///
    /// Returns
    /// -------
    /// A new set of room objects.
    ///
    pub fn fromRoom(allocator: std.mem.Allocator, room: Room) !Self {
        const spawns = try room.find(SearchTarget.my_spawns).getOwnedSlice(allocator);
        errdefer allocator.free(spawns);

        const creeps = try room.find(SearchTarget.my_creeps).getOwnedSlice(allocator);
        errdefer allocator.free(creeps);

        const sources = try room.find(SearchTarget.sources).getOwnedSlice(allocator);
        errdefer allocator.free(sources);

        return Self{
            .spawns = spawns,
            .creeps = creeps,
            .sources = sources,

            .allocator = allocator,
        };
    }
};

pub const RoomCommand = struct {
    room: Room,
    objects: RoomObjects,

    harvest_command: HarvesterCommand,

    const Self = @This();

    /// Description
    /// -----------
    /// Deinitialise the room command.
    ///
    pub fn deinit(self: *const Self) void {
        self.objects.deinit();
    }

    /// Description
    /// -----------
    /// Create a new room command with control over the given room and any structures and creeps.
    ///
    /// Parameters
    /// ----------
    /// room: Room the commander will control.
    /// objects: Objects present within the room to be placed under the commanders control. Assumes
    ///          ownership of allocated memory.
    ///
    /// Returns
    /// -------
    /// A new room command.
    ///
    pub fn init(room: Room, objects: RoomObjects) Self {
        return Self{
            .room = room,
            .objects = objects,
            .harvest_command = HarvesterCommand.init(room, objects),
        };
    }

    pub fn run(self: *const Self) !void {
        try self.harvest_command.run();

        if (self.harvest_command.getProposal()) |prop| {
            switch (prop) {
                .build_creep => {
                    var rng = rand.DefaultPrng.init(0);

                    var postfix: [4]u8 = undefined;
                    rng.random().bytes(&postfix);

                    self.objects.spawns[0].spawnCreep(&CreepBlueprint{
                        .name = "Harv-" ++ postfix,
                        .parts = &[_]CreepPart{ .work, .carry, .move },
                    }) catch {};
                },
            }
        }
    }
};

pub const HarvesterProposal = enum {
    build_creep,
};

pub const HarvesterCommand = struct {
    room: Room,
    objects: RoomObjects,

    const Self = @This();

    pub fn init(room: Room, objects: RoomObjects) Self {
        return Self{
            .room = room,
            .objects = objects,
        };
    }

    pub fn run(self: *const Self) !void {
        const source = self.room.find(SearchTarget.sources).get(0);

        for (self.objects.creeps) |creep| {
            if (creep.getStore().getFreeCapacity() == 0) {
                creep.transfer(self.objects.spawns[0], Resource.energy) catch |err| {
                    switch (err) {
                        ScreepsError.NotInRange => try creep.moveTo(self.objects.spawns[0]),
                        ScreepsError.Full => try creep.drop(Resource.energy),
                        else => return err,
                    }
                };
            } else creep.harvest(source) catch |err| {
                if (err == ScreepsError.NotInRange) {
                    try creep.moveTo(source);
                } else return err;
            };
        }
    }

    pub fn getProposal(self: *const Self) ?HarvesterProposal {
        if (self.objects.creeps.len < 3) {
            return HarvesterProposal.build_creep;
        }

        return null;
    }
};
