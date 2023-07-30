const std = @import("std");
const js = @import("sysjs");

const allocator = std.heap.page_allocator;

extern "sysjs" fn wzLogWrite(str: [*]const u8, len: u32) void;
extern "sysjs" fn wzPanic(str: [*]const u8, len: u32) void;
extern "sysjs" fn wzLogFlush() void;

//////////////////////////////////////////////////

fn print(str: []const u8) void {
    wzLogWrite(str.ptr, str.len);
    wzLogFlush();
}

//////////////////////////////////////////////////

const Creep = struct {
    const Part = enum {
        WORK,
        MOVE,
        CARRY,
        ATTACK,
        RANGED_ATTACK,
        HEAL,
        TOUGH,
        CLAIM,
    };

    name: []const u8,
    parts: []const Part, // std.ArrayList(Part),
};

export fn run(game_ref: u32) void {
    const game = js.Object{ .ref = game_ref };

    const spawns = game.get("spawns").view(.object);
    const spawn1: js.Object = spawns.get("Spawn1").view(.object);

    const parts: js.Object = js.createArray();
    parts.setIndex(0, js.createString("work").toValue());
    parts.setIndex(1, js.createString("carry").toValue());
    parts.setIndex(2, js.createString("move").toValue());
    _ = spawn1.call("spawnCreep", &.{ parts.toValue(), js.createString("harvester1").toValue() });

    const creep = Creep{ .name = "Harvester", .parts = &[_]Creep.Part{ Creep.Part.WORK, Creep.Part.CARRY, Creep.Part.MOVE } };
    _ = creep;
}
