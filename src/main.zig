const std = @import("std");
const fmt = std.fmt;
const logging = std.log.scoped(.main);
const allocator = std.heap.page_allocator;

const screeps = @import("screeps/screeps.zig");
const js = screeps.js;

const world = @import("world.zig");

const ArrayIterator = js.ArrayIterator;
const JSString = js.String;

const Game = screeps.Game;
const Spawn = screeps.Spawn;
const Creep = screeps.Creep;
const World = world.World;

const CreepBlueprint = screeps.CreepBlueprint;
const CreepPart = screeps.CreepPart;

const SearchTarget = screeps.SearchTarget;

extern "sysjs" fn wzLogObject(ref: u64) void;
extern "sysjs" fn wzLogWrite(str: [*]const u8, len: u32) void;
extern "sysjs" fn wzLogFlush() void;

// 100KB of persistant memory.
var persistant_memory: [1024 * 100]u8 = undefined;

export fn persistantMemoryAddress() *[persistant_memory.len]u8 {
    return &persistant_memory;
}

export fn persistantMemoryLength() u32 {
    return persistant_memory.len;
}

export fn run(game_ref: u32) void {
    const game = Game.fromRef(game_ref);

    run_internal(&game) catch |err| {
        logging.err("{!}", .{err});
    };
}

//////////////////////////////////////////////////

pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    // Implementation here
    const str_pre = fmt.allocPrint(allocator, "| {s: <4} | {s: <8} | ", .{ @tagName(message_level), @tagName(scope) }) catch return;
    defer allocator.free(str_pre);

    const str_msg = fmt.allocPrint(allocator, format, args) catch return;
    defer allocator.free(str_msg);

    wzLogWrite(str_pre.ptr, str_pre.len);
    wzLogWrite(str_msg.ptr, str_msg.len);
    wzLogFlush();
}

//////////////////////////////////////////////////

///
/// Commander  <-  Directives  <-  Senior Commander | Receive objectives.
/// Commander <--> Observers   <-  World            | Evaluate world state.
/// Commander  ->  Action      ->  World            | Work towards objectives with currently available resources.
/// Commander  ->  Desire      ->  Senior Commander | Report resources required to improve efficacy.
///
/// Commander defines what parameters it needs to observe. Observers provide a lens through which
/// to view them.
///
const Commander = struct {
    const Self = @This();

    pub fn setDirectives(self: *const Self) void {
        _ = self;
    }

    pub fn run(self: *const Self) void {
        _ = self;
    }
};

//////////////////////////////////////////////////

fn run_internal(game: *const Game) !void {
    logging.info(" ", .{});
    logging.info("Module start", .{});
    logging.info("--------------------", .{});

    // Load the world state. We can either do this via a combination of:
    // 1. Investigating the Game object (possibly quite slow due to lots of boundry crossing).
    // 2. Using data saved in persistant memory from the previous state (presumably faster???).
    //
    // It's possible for persistant memory to be completely wiped out so loading entirely from the
    // Game needs to be possible.
    //
    // Things like creep and structure ID's are good candidates for storing in memory.
    // Memory format? intended to be JSON but would something like ProtBuf be faster?

    const world_state: World = try World.fromGame(allocator, game);
    defer world_state.deinit();

    for (world_state.spawns) |spawn| {
        const name_obj: JSString = try spawn.getName();
        const name = try name_obj.getOwnedSlice(allocator);
        defer allocator.free(name);

        logging.info("spawn name: {s}", .{name});

        if (std.mem.eql(u8, name, "Spawn1")) {
            const creep = CreepBlueprint{ .name = "Harvester", .parts = &[_]CreepPart{ .work, .carry, .move } };
            spawn.spawnCreep(&creep) catch {};
        }
    }

    for (world_state.creeps) |creep| {
        const name_obj: JSString = try creep.getName();
        const name = try name_obj.getOwnedSlice(allocator);
        defer allocator.free(name);

        logging.info("creep name: {s}", .{name});
    }

    for (world_state.rooms) |room| {
        const name_obj: JSString = try room.getName();
        const name = try name_obj.getOwnedSlice(allocator);
        defer allocator.free(name);
        logging.info("room name: {s}", .{name});

        const sources = try room.find(SearchTarget.sources);
        _ = sources;
    }
}
