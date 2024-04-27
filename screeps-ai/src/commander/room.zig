const std = @import("std");
const json = std.json;
const rand = std.rand;
const logging = std.log.scoped(.roomcmd);

const screeps = @import("screeps-bindings");
const Game = screeps.Game;
const Room = screeps.Room;
const Spawn = screeps.Spawn;
const Creep = screeps.Creep;
const Source = screeps.Source;
const CreepPart = screeps.CreepPart;
const SearchTarget = screeps.SearchTarget;
const CreepBlueprint = screeps.CreepBlueprint;

const harvest = @import("harvest.zig");
const HarvestCommander = harvest.HarvestCommander;
const HarvestCommanderLoader = harvest.HarvestCommanderLoader;

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
            const name_token: ?json.Token = try source.nextAllocMax(
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
    game: Game,
    room: Room,
    creeps: []const Creep,
    spawns: []const Spawn,

    harvest_command: HarvestCommander,

    allocator: std.mem.Allocator,

    const Self = @This();
    pub const Loader = RoomCommanderLoader;

    /// Description
    /// -----------
    /// Deinitialise the room command.
    ///
    pub fn deinit(self: *const Self) void {
        self.allocator.free(self.creeps);
        self.allocator.free(self.spawns);
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
    pub fn init(allocator: std.mem.Allocator, game: Game, room: Room) !Self {
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
            .game = game,
            .room = room,
            .creeps = creeps,
            .spawns = spawns,
            .harvest_command = HarvestCommander.init(room, creeps, spawns, sources),
            .allocator = allocator,
        };
    }

    pub fn run(self: *const Self) !void {
        logging.info("Running - Creeps: {}", .{self.creeps.len});
        try self.harvest_command.run(self.creeps);

        if (self.harvest_command.getProposal()) |prop| {
            switch (prop) {
                .build_creep => {
                    const creep_name = try self.createUniqueName();
                    defer self.allocator.free(creep_name);

                    self.spawns[0].spawnCreep(&CreepBlueprint{
                        .name = creep_name,
                        .parts = &[_]CreepPart{ .work, .carry, .move },
                    }) catch {};
                },
            }
        }
    }

    pub fn fromLoader(allocator: std.mem.Allocator, loader: *const Self.Loader, game: Game) !Self {
        var creeps = std.ArrayList(Creep).init(allocator);
        errdefer creeps.deinit();

        for (loader.creeps) |id| {
            if (game.getObjectByID(id, Creep)) |creep| {
                try creeps.append(creep);
            }
        }

        var spawns = std.ArrayList(Spawn).init(allocator);
        errdefer spawns.deinit();

        for (loader.spawns) |id| {
            if (game.getObjectByID(id, Spawn)) |spawn| {
                try spawns.append(spawn);
            }
        }

        return Self{
            .game = game,
            .room = spawns.items[0].getRoom(),
            .creeps = try creeps.toOwnedSlice(),
            .spawns = try spawns.toOwnedSlice(),
            .harvest_command = try HarvestCommander.fromLoader(allocator, &loader.harvest_command, &game),
            .allocator = allocator,
        };
    }

    pub fn toLoader(self: *const Self, allocator: std.mem.Allocator) !Self.Loader {
        var creep_ids = try std.ArrayList([]const u8).initCapacity(allocator, self.creeps.len);
        errdefer creep_ids.deinit();

        for (self.creeps) |creep| {
            creep_ids.appendAssumeCapacity(try creep.getID().getOwnedSlice(allocator));
        }

        // Add any creeps that are about to spawn.
        if (self.spawns[0].getSpawning()) |spawning| {
            if (spawning.getRemainingTime() == 1) {
                const name = try spawning.getName().getOwnedSlice(self.allocator);
                defer self.allocator.free(name);

                const id = try self.game.getCreepByName(name).getID().getOwnedSlice(self.allocator);
                logging.info("New creep with id: {s}", .{id});
                try creep_ids.append(id);
            }
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

    fn createUniqueName(self: *const Self) ![]const u8 {
        const spawn_name = try self.spawns[0].getName().getOwnedSlice(self.allocator);
        defer self.allocator.free(spawn_name);

        const time = self.game.getTime();
        return std.fmt.allocPrint(self.allocator, "Harv-{s}-{}", .{ spawn_name, time });
    }
};
