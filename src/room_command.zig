const std = @import("std");
const json = std.json;
const rand = std.rand;

const screeps = @import("screeps/screeps.zig");
const Game = screeps.Game;
const Room = screeps.Room;
const Spawn = screeps.Spawn;
const Creep = screeps.Creep;
const Source = screeps.Source;
const Resource = screeps.Resource;
const CreepPart = screeps.CreepPart;
const SearchTarget = screeps.SearchTarget;
const ScreepsError = screeps.ScreepsError;
const CreepBlueprint = screeps.CreepBlueprint;

pub const RoomCommanderLoader = struct {
    creeps: []const []const u8,
    spawns: []const []const u8,

    harvest_command: HarvestCommanderLoader,

    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.creeps);
        self.allocator.free(self.spawns);
        self.harvest_command.deinit();
    }

    pub fn jsonStringify(self: *const Self, jw: anytype) !void {
        try jw.beginObject();

        try jw.objectField("creeps");
        try jw.write(self.creeps);

        try jw.objectField("spawns");
        try jw.write(self.spawns);

        try jw.objectField("harvest_command");
        try jw.write(self.harvest_command);

        try jw.endObject();
    }

    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: json.ParseOptions) json.ParseError(@TypeOf(source.*))!Self {
        if (try source.next() != .object_begin) return error.UnexpectedToken;

        var self: Self = Self{
            .creeps = undefined,
            .spawns = undefined,
            .harvest_command = undefined,
            .allocator = allocator,
        };

        while (true) {
            var name_token: ?json.Token = try source.nextAllocMax(
                allocator,
                .alloc_if_needed,
                options.max_value_len.?,
            );

            const field_name = switch (name_token.?) {
                inline .string, .allocated_string => |slice| slice,
                .object_end => break,
                else => return error.UnexpectedToken,
            };

            if (std.mem.eql(u8, field_name, "creeps")) {
                self.creeps = try json.innerParse([]const []const u8, allocator, source, options);
            } else if (std.mem.eql(u8, field_name, "spawns")) {
                self.spawns = try json.innerParse([]const []const u8, allocator, source, options);
            } else if (std.mem.eql(u8, field_name, "harvest_command")) {
                self.harvest_command = try json.innerParse(HarvestCommanderLoader, allocator, source, options);
            } else {
                try source.skipValue();
            }

            switch (name_token.?) {
                .allocated_number, .allocated_string => |slice| {
                    allocator.free(slice);
                },
                else => {},
            }
        }

        return self;
    }
};

pub const RoomCommander = struct {
    room: Room,
    creeps: []const Creep,
    spawns: []const Spawn,

    harvest_command: HarvestCommander,

    const Self = @This();
    pub const Loader = RoomCommanderLoader;

    /// Description
    /// -----------
    /// Deinitialise the room command.
    ///
    pub fn deinit(self: *const Self) void {
        self.state.deinit();
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
    pub fn init(allocator: std.mem.Allocator, room: Room) !Self {
        // Get creep.
        const creeps = try room.find(SearchTarget.my_creeps).getOwnedSlice(allocator);
        errdefer allocator.free(creeps);

        // Get spawn.
        const spawns = try room.find(SearchTarget.my_spawns).getOwnedSlice(allocator);
        errdefer allocator.free(spawns);

        // Get sources.
        const sources = try room.find(SearchTarget.sources).getOwnedSlice(allocator);
        errdefer allocator.free(sources);

        return Self{
            .room = room,
            .creeps = creeps,
            .spawns = spawns,
            .harvest_command = HarvestCommander.init(room, creeps, spawns, sources),
        };
    }

    pub fn fromLoader(allocator: std.mem.Allocator, loader: *const Self.Loader, game: *const Game) !Self {
        var creeps = try allocator.alloc(Creep, loader.creeps.len);
        errdefer allocator.free(creeps);
        for (creeps, loader.creeps) |*creep, id| {
            creep.* = game.getObjectByID(id, Creep);
        }

        var spawns = try allocator.alloc(Spawn, loader.spawns.len);
        errdefer allocator.free(spawns);
        for (spawns, loader.spawns) |*spawn, id| {
            spawn.* = game.getObjectByID(id, Spawn);
        }

        return Self{
            .room = spawns[0].getRoom(),
            .creeps = creeps,
            .spawns = spawns,
            .harvest_command = try HarvestCommander.fromLoader(allocator, &loader.harvest_command, game),
        };
    }

    pub fn run(self: *const Self) !void {
        try self.harvest_command.run();

        if (self.harvest_command.getProposal()) |prop| {
            switch (prop) {
                .build_creep => {
                    var rng = rand.DefaultPrng.init(0);

                    var postfix: [4]u8 = undefined;
                    for (&postfix) |*byte| {
                        byte.* = rng.random().intRangeAtMost(u8, 0x30, 0x7E);
                    }

                    // rng.random().bytes(&postfix);

                    self.spawns[0].spawnCreep(&CreepBlueprint{
                        .name = "Harv-" ++ postfix,
                        .parts = &[_]CreepPart{ .work, .carry, .move },
                    }) catch {};
                },
            }
        }
    }

    pub fn toLoader(self: *const Self, allocator: std.mem.Allocator) !Self.Loader {
        var creep_ids = try std.ArrayList([]const u8).initCapacity(allocator, self.creeps.len);
        errdefer creep_ids.deinit();

        for (self.creeps) |creep| {
            creep_ids.appendAssumeCapacity(try creep.getID().getOwnedSlice(allocator));
        }

        var spawn_ids = try std.ArrayList([]const u8).initCapacity(allocator, self.spawns.len);
        errdefer spawn_ids.deinit();

        for (self.spawns) |spawn| {
            spawn_ids.appendAssumeCapacity(try spawn.getID().getOwnedSlice(allocator));
        }

        return Self.Loader{
            .creeps = try creep_ids.toOwnedSlice(),
            .spawns = try spawn_ids.toOwnedSlice(),
            .harvest_command = try self.harvest_command.toLoader(allocator),
            .allocator = allocator,
        };
    }
};

pub const HarvesterProposal = enum {
    build_creep,
};

pub const HarvestCommanderLoader = struct {
    creeps: []const []const u8,
    spawns: []const []const u8,
    sources: []const []const u8,

    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.creeps);
        self.allocator.free(self.spawns);
        self.allocator.free(self.sources);
    }

    pub fn jsonStringify(self: *const Self, jw: anytype) !void {
        try jw.beginObject();

        try jw.objectField("creeps");
        try jw.write(self.creeps);

        try jw.objectField("spawns");
        try jw.write(self.spawns);

        try jw.objectField("sources");
        try jw.write(self.sources);

        try jw.endObject();
    }

    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: json.ParseOptions) json.ParseError(@TypeOf(source.*))!Self {
        if (try source.next() != .object_begin) return error.UnexpectedToken;

        var self: Self = Self{
            .creeps = undefined,
            .spawns = undefined,
            .sources = undefined,
            .allocator = allocator,
        };

        while (true) {
            var name_token: ?json.Token = try source.nextAllocMax(
                allocator,
                .alloc_if_needed,
                options.max_value_len.?,
            );

            const field_name = switch (name_token.?) {
                inline .string, .allocated_string => |slice| slice,
                .object_end => break,
                else => return error.UnexpectedToken,
            };

            if (std.mem.eql(u8, field_name, "creeps")) {
                self.creeps = try json.innerParse([]const []const u8, allocator, source, options);
            } else if (std.mem.eql(u8, field_name, "spawns")) {
                self.spawns = try json.innerParse([]const []const u8, allocator, source, options);
            } else if (std.mem.eql(u8, field_name, "sources")) {
                self.sources = try json.innerParse([]const []const u8, allocator, source, options);
            } else {
                try source.skipValue();
            }

            switch (name_token.?) {
                .allocated_number, .allocated_string => |slice| {
                    allocator.free(slice);
                },
                else => {},
            }
        }

        return self;
    }
};

pub const HarvestCommander = struct {
    room: Room,
    creeps: []const Creep,
    spawns: []const Spawn,
    sources: []const Source,

    const Self = @This();
    pub const Loader = HarvestCommanderLoader;

    pub fn init(room: Room, creeps: []const Creep, spawns: []const Spawn, sources: []const Source) Self {
        return Self{
            .room = room,
            .creeps = creeps,
            .spawns = spawns,
            .sources = sources,
        };
    }

    pub fn fromLoader(allocator: std.mem.Allocator, loader: *const Self.Loader, game: *const Game) !Self {
        var creeps = try allocator.alloc(Creep, loader.creeps.len);
        errdefer allocator.free(creeps);
        for (creeps, loader.creeps) |*creep, id| {
            creep.* = game.getObjectByID(id, Creep);
        }

        var spawns = try allocator.alloc(Spawn, loader.spawns.len);
        errdefer allocator.free(spawns);
        for (spawns, loader.spawns) |*spawn, id| {
            spawn.* = game.getObjectByID(id, Spawn);
        }

        var sources = try allocator.alloc(Source, loader.sources.len);
        errdefer allocator.free(sources);
        for (sources, loader.sources) |*source, id| {
            source.* = game.getObjectByID(id, Source);
        }

        return Self{
            .room = spawns[0].getRoom(),
            .creeps = creeps,
            .spawns = spawns,
            .sources = sources,
        };
    }

    pub fn run(self: *const Self) !void {
        const source = self.room.find(SearchTarget.sources).get(0);
        const spawn = self.spawns[0];

        for (self.creeps) |creep| {
            if (creep.getStore().getFreeCapacity() == 0) {
                creep.transfer(spawn, Resource.energy) catch |err| switch (err) {
                    ScreepsError.NotInRange => creep.moveTo(spawn) catch |err2| switch (err2) {
                        ScreepsError.Tired => return,
                        else => return err2,
                    },
                    ScreepsError.Full => try creep.drop(Resource.energy),
                    else => return err,
                };
            } else creep.harvest(source) catch |err| {
                if (err == ScreepsError.NotInRange) {
                    try creep.moveTo(source);
                } else return err;
            };
        }
    }

    pub fn getProposal(self: *const Self) ?HarvesterProposal {
        if (self.creeps.len < 3) {
            return HarvesterProposal.build_creep;
        }

        return null;
    }

    pub fn toLoader(self: *const Self, allocator: std.mem.Allocator) !HarvestCommanderLoader {
        var creep_ids = try std.ArrayList([]const u8).initCapacity(allocator, self.creeps.len);
        errdefer creep_ids.deinit();

        for (self.creeps) |creep| {
            creep_ids.appendAssumeCapacity(try creep.getID().getOwnedSlice(allocator));
        }

        var spawn_ids = try std.ArrayList([]const u8).initCapacity(allocator, self.spawns.len);
        errdefer spawn_ids.deinit();

        for (self.spawns) |spawn| {
            spawn_ids.appendAssumeCapacity(try spawn.getID().getOwnedSlice(allocator));
        }

        var source_ids = try std.ArrayList([]const u8).initCapacity(allocator, self.sources.len);
        errdefer source_ids.deinit();

        for (self.sources) |source| {
            source_ids.appendAssumeCapacity(try source.getID().getOwnedSlice(allocator));
        }

        return HarvestCommanderLoader{
            .creeps = try creep_ids.toOwnedSlice(),
            .spawns = try spawn_ids.toOwnedSlice(),
            .sources = try source_ids.toOwnedSlice(),
            .allocator = allocator,
        };
    }
};
