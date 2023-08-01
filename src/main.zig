const std = @import("std");
const fmt = std.fmt;
const logging = std.log.scoped(.main);
const allocator = std.heap.page_allocator;

const js = @import("sysjs");

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

const BindingError = error{
    UnexpectedType,
};

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

    fn to_error(self: ScreepsErrorVal) ?ScreepsError {
        switch (self) {
            ScreepsErrorVal.ok => return null,
            ScreepsErrorVal.not_owner => return ScreepsError.NotOwner,
            ScreepsErrorVal.no_path => return ScreepsError.NoPath,
            ScreepsErrorVal.name_exists => return ScreepsError.NameExists,
            ScreepsErrorVal.busy => return ScreepsError.Busy,
            ScreepsErrorVal.not_found => return ScreepsError.NotFound,
            ScreepsErrorVal.not_enough_resources => return ScreepsError.NotEnoughResources,
            ScreepsErrorVal.invalid_target => return ScreepsError.InvalidTarget,
            ScreepsErrorVal.full => return ScreepsError.Full,
            ScreepsErrorVal.not_in_range => return ScreepsError.NotInRange,
            ScreepsErrorVal.invalid_args => return ScreepsError.InvalidArgs,
            ScreepsErrorVal.tired => return ScreepsError.Tired,
            ScreepsErrorVal.no_bodypart => return ScreepsError.NoBodypart,
            ScreepsErrorVal.rcl_not_enough => return ScreepsError.RclNotEnough,
            ScreepsErrorVal.gcl_not_enough => return ScreepsError.GclNotEnough,
        }
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
        // Grab the list of spawns
        const spawns: js.Object = blk: {
            const spawns: js.Value = game.get("spawns");

            if (!spawns.is(.object)) {
                return BindingError.UnexpectedType;
            }

            break :blk spawns.view(.object);
        };

        // Determine if a spawn with the given name exists.
        const has_spawn: bool = blk: {
            const has_spawn = spawns.call("hasOwnProperty", &.{js.createString(name).toValue()});

            if (!has_spawn.is(.bool)) {
                return BindingError.UnexpectedType;
            }

            break :blk has_spawn.view(.bool);
        };

        if (!has_spawn) {
            return ScreepsError.NotFound;
        }

        // Grab the desired spawn object.
        const spawn: js.Object = blk: {
            const spawn = spawns.get(name);

            if (!spawn.is(.object)) {
                return BindingError.UnexpectedType;
            }

            break :blk spawn.view(.object);
        };

        return Spawn{
            .name = name,
            .obj = spawn,
        };
    }

    /// Spawn a new creep.
    ///
    fn spawnCreep(self: *const Spawn, blueprint: *const Creep) !void {
        const parts: js.Object = js.createArray();

        for (blueprint.parts) |part, i| {
            parts.setIndex(i, js.createString(@tagName(part)).toValue());
        }

        const result = self.obj.call("spawnCreep", &.{ parts.toValue(), js.createString(blueprint.name).toValue() });

        if (!result.is(js.Value.Tag.num)) {
            return BindingError.UnexpectedType;
        }

        const error_val = @floatToInt(i32, result.view(.num));
        const error_code: ScreepsErrorVal = @intToEnum(ScreepsErrorVal, error_val);
        if (error_code.to_error()) |err| {
            return err;
        }
    }
};

export fn run(game_ref: u32) void {
    const game = js.Object{ .ref = game_ref };

    if (Spawn.fromGame(&game, "Spawn1")) |spawn| {
        const creep = Creep{ .name = "Harvester", .parts = &[_]Creep.Part{ .work, .carry, .move } };

        spawn.spawnCreep(&creep) catch |err| {
            logging.err("{}", .{err});
        };
    } else |err| {
        logging.err("{}", .{err});
    }
}
