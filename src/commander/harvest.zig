const std = @import("std");
const json = std.json;

const screeps = @import("../screeps/screeps.zig");
const Game = screeps.Game;
const Room = screeps.Room;
const Spawn = screeps.Spawn;
const Creep = screeps.Creep;
const Source = screeps.Source;
const Resource = screeps.Resource;
const SearchTarget = screeps.SearchTarget;
const ScreepsError = screeps.ScreepsError;

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

        var sources = std.ArrayList(Source).init(allocator);
        errdefer sources.deinit();

        for (loader.sources) |id| {
            if (game.getObjectByID(id, Source)) |source| {
                try sources.append(source);
            }
        }

        return Self{
            .room = spawns.items[0].getRoom(),
            .creeps = try creeps.toOwnedSlice(),
            .spawns = try spawns.toOwnedSlice(),
            .sources = try sources.toOwnedSlice(),
        };
    }

    pub fn run(self: *const Self, creeps: []const Creep) !void {
        const source = self.room.find(SearchTarget.sources).get(0);
        const spawn = self.spawns[0];

        for (creeps) |creep| {
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
