const std = @import("std");
const fmt = std.fmt;
const logging = std.log.scoped(.main);
const allocator = std.heap.page_allocator;

const js = @import("js_bind.zig");

extern "sysjs" fn wzLogWrite(str: [*]const u8, len: u32) void;
extern "sysjs" fn wzLogFlush() void;

//////////////////////////////////////////////////

pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    // Implementation here
    const str_pre = fmt.allocPrint(allocator, "{s} - {s} - ", .{ @tagName(message_level), @tagName(scope) }) catch return;
    defer allocator.free(str_pre);

    const str_msg = fmt.allocPrint(allocator, format, args) catch return;
    defer allocator.free(str_msg);

    wzLogWrite(str_pre.ptr, str_pre.len);
    wzLogWrite(str_msg.ptr, str_msg.len);
    wzLogFlush();
}

//////////////////////////////////////////////////

const ScreepsErrorVal = enum(i32) {
    ok = 0,
    not_owner = -1,
    no_path = -2,
    name_exists = -3,
    busy = -4,
    not_found = -5,
    not_enough_resources = -6,
    invalid_target = -7,
    full = -8,
    not_in_range = -9,
    invalid_args = -10,
    tired = -11,
    no_bodypart = -12,
    rcl_not_enough = -14,
    gcl_not_enough = -15,
    _,

    fn toError(self: ScreepsErrorVal) ?ScreepsError {
        return switch (self) {
            ScreepsErrorVal.not_owner => ScreepsError.NotOwner,
            ScreepsErrorVal.no_path => ScreepsError.NoPath,
            ScreepsErrorVal.name_exists => ScreepsError.NameExists,
            ScreepsErrorVal.busy => ScreepsError.Busy,
            ScreepsErrorVal.not_found => ScreepsError.NotFound,
            ScreepsErrorVal.not_enough_resources => ScreepsError.NotEnoughResources,
            ScreepsErrorVal.invalid_target => ScreepsError.InvalidTarget,
            ScreepsErrorVal.full => ScreepsError.Full,
            ScreepsErrorVal.not_in_range => ScreepsError.NotInRange,
            ScreepsErrorVal.invalid_args => ScreepsError.InvalidArgs,
            ScreepsErrorVal.tired => ScreepsError.Tired,
            ScreepsErrorVal.no_bodypart => ScreepsError.NoBodypart,
            ScreepsErrorVal.rcl_not_enough => ScreepsError.RclNotEnough,
            ScreepsErrorVal.gcl_not_enough => ScreepsError.GclNotEnough,
            else => null,
        };
    }
};

const ScreepsError = error{
    NotOwner,
    NoPath,
    NameExists,
    Busy,
    NotFound,
    NotEnoughResources,
    InvalidTarget,
    Full,
    NotInRange,
    InvalidArgs,
    Tired,
    NoBodypart,
    RclNotEnough,
    GclNotEnough,
};

const Creep = struct {
    /// The possible parts a creep can be made up from. In the Screeps API, these are defined as
    /// strings. They are named here such that @tagname will give the correct string for each.
    const Part = enum {
        work,
        move,
        carry,
        attack,
        ranged_attack,
        heal,
        tough,
        claim,
    };

    name: []const u8,
    parts: []const Part,
};

const Spawn = struct {
    name: []const u8,
    obj: js.Object,

    /// Load a Spawn from the game world.
    ///
    fn fromGame(game: *const js.Object, name: []const u8) !Spawn {
        const spawns = try game.get("spawns", js.Object);

        const has_spawn = try spawns.call("hasOwnProperty", &.{js.String.from(name)}, bool);
        if (!has_spawn) {
            return ScreepsError.NotFound;
        }

        return Spawn{
            .name = name,
            .obj = try spawns.get(name, js.Object),
        };
    }

    /// Spawn a new creep.
    ///
    fn spawnCreep(self: *const Spawn, blueprint: *const Creep) !void {
        const parts: js.Array = js.Array.new();

        for (blueprint.parts) |part, i| {
            parts.set(i, js.String.from(@tagName(part)));
        }

        const result = try self.obj.call("spawnCreep", &.{ parts, js.String.from(blueprint.name) }, ScreepsErrorVal);
        if (result.toError()) |err| {
            return err;
        }
    }
};

export fn run(game_ref: u32) void {
    const game = js.Object.fromRef(game_ref);

    if (Spawn.fromGame(&game, "Spawn1")) |spawn| {
        const creep = Creep{ .name = "Harvester", .parts = &[_]Creep.Part{ .work, .carry, .move } };

        spawn.spawnCreep(&creep) catch |err| {
            logging.err("{}", .{err});
        };
    } else |err| {
        logging.err("{}", .{err});
    }
}
