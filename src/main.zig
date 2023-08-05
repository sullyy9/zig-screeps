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

export fn run(game_ref: u32) void {
    const game = Game.fromRef(game_ref);

    if (game.getSpawn("Spawn1")) |spawn| {
        const creep = Creep{ .name = "Harvester", .parts = &[_]Creep.Part{ .work, .carry, .move } };

        spawn.spawnCreep(&creep) catch |err| {
            logging.err("{}", .{err});
        };
    } else |err| {
        logging.err("{}", .{err});
    }
}
