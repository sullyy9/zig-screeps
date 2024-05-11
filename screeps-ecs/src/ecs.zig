const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;

const world = @import("world/world.zig");
const World = world.World;

const system_module = @import("system/mod.zig");
const SystemRegistry = system_module.Registry;

pub fn ECS(comptime systems: SystemRegistry) type {
    return struct {
        const Self = @This();

        world: World,
        comptime systems: SystemRegistry = systems,

        pub fn init(allocator: Allocator) Self {
            return Self{
                .world = World.init(allocator),
                .systems = systems,
            };
        }

        pub fn deinit(self: *Self) void {
            self.world.deinit();
        }

        pub fn tick(self: *Self) void {
            inline for (self.systems.systems[0..self.systems.count]) |system| {
                const func: *const system.Type() = @ptrCast(system.ptr);

                var args: system.args = undefined;
                inline for (&args) |*arg| {
                    arg.* = @TypeOf(arg.*).init(&self.world);
                }

                @call(.auto, func, args);
            }
        }
    };
}

pub const Test = struct {
    const testing = std.testing;
    const ArrayList = std.ArrayList;
    const allocator = std.testing.allocator;

    const components = @import("testing/components.zig");
    const ID = components.ID;
    const Name = components.Name;
    const Funky = components.Funky;
    const NameAndID = components.NameAndID;
    const FunkyNameAndID = components.FunkyNameAndID;

    const Query = @import("query.zig").Query;

    const NameAndIDSortCtx = struct {
        fn lessThan(_: void, lhs: NameAndID, rhs: NameAndID) bool {
            return NameAndID.order(lhs, rhs) == .lt;
        }
    };

    var call_count: u32 = 0;
    fn testSystem() void {
        call_count += 1;
    }

    fn testIDsAdd10(query: Query(&.{ *const Name, *ID }, void)) void {
        var iter = query.iterMut();
        while (iter.next()) |item| {
            const name, var id = item;

            if (std.mem.startsWith(u8, name.name, "test")) {
                id.id += 10;
            }
        }
    }

    test "addSystem" {
        comptime var systems = SystemRegistry.init();
        comptime systems.addSystem(testSystem);
        comptime systems.addSystem(testIDsAdd10);

        var ecs = ECS(systems).init(allocator);
        defer ecs.deinit();

        var entities = [_]NameAndID{
            NameAndID.initRaw("test1", 1),
            NameAndID.initRaw("test2", 2),
            NameAndID.initRaw("test3", 3),
            NameAndID.initRaw("test4", 4),
            NameAndID.initRaw("test5", 5),
        };

        _ = try ecs.world.newEntity(entities[0]);
        _ = try ecs.world.newEntity(entities[1]);
        _ = try ecs.world.newEntity(entities[2]);
        _ = try ecs.world.newEntity(FunkyNameAndID.init(entities[3].name, entities[3].id, Funky{ .in_a_good_way = 6 }));
        _ = try ecs.world.newEntity(FunkyNameAndID.init(entities[4].name, entities[4].id, Funky{ .in_a_bad_way = 4 }));

        for (&entities) |*ent| ent.id.id += 10;

        ecs.tick();
        try testing.expectEqual(1, call_count);

        var iter = ecs.world.iter(&.{ Name, ID });
        var collected = ArrayList(NameAndID).init(allocator);
        defer collected.deinit();
        while (iter.next()) |item| try collected.append(NameAndID.init(item[0].*, item[1].*));

        std.sort.insertion(NameAndID, &entities, {}, NameAndIDSortCtx.lessThan);
        std.sort.insertion(NameAndID, collected.items, {}, NameAndIDSortCtx.lessThan);

        try testing.expectEqualSlices(NameAndID, &entities, collected.items);
    }
};
