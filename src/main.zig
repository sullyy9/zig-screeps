const std = @import("std");
const fmt = std.fmt;
const logging = std.log.scoped(.main);
const allocator = std.heap.page_allocator;

const screeps = @import("screeps/screeps.zig");
const js = screeps.js;

const Game = screeps.Game;
const Creep = screeps.Creep;
const Spawn = screeps.Spawn;
const ArrayIterator = js.ArrayIterator;

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
    //

    const spawns = try game.getSpawns();
    var iter: ArrayIterator(Spawn) = spawns.iterate();

    while (try iter.next()) |spawn| {
        const name = spawn.getName(allocator) catch "Failed to get name";
        defer allocator.free(name);

        logging.info("spawn: {s}", .{name});
    }

    const spawn = try game.getSpawn("Spawn1");
    const creep = Creep{ .name = "Harvester", .parts = &[_]Creep.Part{ .work, .carry, .move } };
    try spawn.spawnCreep(&creep);

    return screeps.ScreepsError.NotOwner;
}
