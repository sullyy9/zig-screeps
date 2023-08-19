const std = @import("std");
const fmt = std.fmt;
const json = std.json;
const logging = std.log.scoped(.main);
const allocator = std.heap.wasm_allocator;

const screeps = @import("screeps/screeps.zig");
const JSString = screeps.JSString;

const Game = screeps.Game;
const Spawn = screeps.Spawn;
const Creep = screeps.Creep;
const Source = screeps.Source;
const CreepBlueprint = screeps.CreepBlueprint;
const CreepPart = screeps.CreepPart;

const SearchTarget = screeps.SearchTarget;
const Resource = screeps.Resource;

const ScreepsError = screeps.ScreepsError;

const world = @import("world.zig");
const World = world.World;

const roomcmd = @import("room_command.zig");
const RoomCommander = roomcmd.RoomCommander;

const state = @import("state/state.zig");
const WorldState = state.WorldState;

const memory = @import("memory.zig");
const MemoryManager = memory.MemoryManager;

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

pub const std_options = struct {
    pub const logFn = log;
};

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

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = error_return_trace;
    _ = ret_addr;

    logging.err("PANIC - {s}", .{msg});

    while (true) {
        @breakpoint();
    }
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
    var room_command = if (MemoryManager.fromSaved(&persistant_memory)) |manager| blk: {
        logging.info("Persistant memory valid. Loading state from memory...", .{});

        const loader = try json.parseFromSlice(
            RoomCommander.Loader,
            allocator,
            manager.getMemory(),
            .{ .ignore_unknown_fields = true },
        );

        break :blk try RoomCommander.fromLoader(allocator, &loader.value, game);
    } else |err| blk: {
        logging.info(
            "Persistant memory invalid - {}. Re-initialising state from game object...",
            .{err},
        );

        break :blk try RoomCommander.init(allocator, game.getRooms().get(0));
    };

    // Run.
    logging.info("Running commanders...", .{});
    try room_command.run();

    // Save state for next loop
    logging.info("Saving state...", .{});
    var memory_manager = MemoryManager.init(&persistant_memory);
    defer memory_manager.deinit();

    const loader = try room_command.toLoader(allocator);
    try json.stringify(loader, .{}, memory_manager.writer());

    logging.info("--------------------", .{});
    logging.info(" ", .{});
}
