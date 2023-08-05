const std = @import("std");
const fmt = std.fmt;
const logging = std.log.scoped(.main);
const allocator = std.heap.page_allocator;

const js = @import("js_bind.zig");
const screeps = @import("screeps/screeps.zig");

const Creep = screeps.Creep;
const Spawn = screeps.Spawn;

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
