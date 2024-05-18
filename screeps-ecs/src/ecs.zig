const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;

const World = @import("world/mod.zig").World;

const system_module = @import("system/mod.zig");
const SystemParam = system_module.SystemParam;
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

        pub fn loadWorld(self: *Self, memory: []const u8) !void {
            const parsed_world = try json.parseFromSlice(World, self.world.allocator, memory, .{});
            self.world = parsed_world.value;
        }

        pub fn saveWorld(self: *Self, writer: anytype) !void {
            try json.stringify(self.world, .{}, writer);
        }

        pub fn tick(self: *Self) void {
            inline for (self.systems.systems[0..self.systems.count]) |system| {
                const func: *const system.Type() = @ptrCast(system.ptr);

                var args: system.args = undefined;
                inline for (&args) |*arg| {
                    arg.* = switch (SystemParam.init(@TypeOf(arg.*))) {
                        .query => |Q| Q.init(&self.world),
                        .world_ptr => &self.world,

                        .resource_ptr => |Res| brk: {
                            if (self.world.getResourcePtr(Res)) |resource| break :brk resource;

                            std.debug.panic(
                                "Resource '{s}' requested by system '{s}' is not available",
                                .{ @typeName(Res), system.name() },
                            );
                        },

                        .resource_ptr_const => |Res| brk: {
                            if (self.world.getResourcePtrConst(Res)) |resource| break :brk resource;

                            std.debug.panic(
                                "Resource '{s}' requested by system '{s}' is not available",
                                .{ @typeName(Res), system.name() },
                            );
                        },

                        .opt_resource_ptr => |Res| self.world.getResourcePtr(Res),
                        .opt_resource_ptr_const => |Res| self.world.getResourcePtrConst(Res),
                    };
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

    const components = @import("testing/mod.zig");
    const ID = components.ID;
    const Name = components.Name;
    const Funky = components.Funky;
    const Counter = components.Counter;
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

        _ = try ecs.world.addEntity(entities[0]);
        _ = try ecs.world.addEntity(entities[1]);
        _ = try ecs.world.addEntity(entities[2]);
        _ = try ecs.world.addEntity(FunkyNameAndID.fromNameAndID(entities[3], .{ .in_a_good_way = 6 }));
        _ = try ecs.world.addEntity(FunkyNameAndID.fromNameAndID(entities[4], .{ .in_a_bad_way = 4 }));

        for (&entities) |*ent| ent.id.id += 10;

        ecs.tick();
        try testing.expectEqual(1, call_count);

        var iter = ecs.world.iterComponentsConst(&.{ Name, ID });
        var collected = ArrayList(NameAndID).init(allocator);
        defer collected.deinit();
        while (iter.next()) |item| try collected.append(NameAndID.init(item[0].*, item[1].*));

        std.sort.insertion(NameAndID, &entities, {}, NameAndIDSortCtx.lessThan);
        std.sort.insertion(NameAndID, collected.items, {}, NameAndIDSortCtx.lessThan);

        try testing.expectEqualSlices(NameAndID, &entities, collected.items);
    }

    fn testAddNameAndID(world: *World) void {
        _ = world.addEntity(NameAndID.initRaw("added-test", 1)) catch |err| {
            std.debug.panic("Failed to add entity: {!}", .{err});
        };
    }

    test "world access" {
        comptime var systems = SystemRegistry.init();
        comptime systems.addSystem(testAddNameAndID);

        var ecs = ECS(systems).init(allocator);
        defer ecs.deinit();

        ecs.tick();

        var iter = ecs.world.iterComponentsConst(&.{ Name, ID });
        var collected = ArrayList(NameAndID).init(allocator);
        defer collected.deinit();
        while (iter.next()) |item| try collected.append(NameAndID.init(item[0].*, item[1].*));

        try testing.expectEqualSlices(NameAndID, &.{NameAndID.initRaw("added-test", 1)}, collected.items);
    }

    fn counterResInc(count: *Counter, count_const: *const Counter) void {
        _ = count_const;
        count.increment();
    }

    test "resource access" {
        comptime var systems = SystemRegistry.init();
        comptime systems.addSystem(counterResInc);

        var ecs = ECS(systems).init(allocator);
        defer ecs.deinit();

        try ecs.world.putResource(Counter.init());

        ecs.tick();

        try testing.expectEqual(1, ecs.world.getResource(Counter).?.count);
    }

    fn counterResInsertOrInc(world: *World, count: ?*Counter, count_const: ?*const Counter) void {
        _ = count_const;
        if (count) |c| {
            c.increment();
        } else {
            world.putResource(Counter.init()) catch |err| {
                std.debug.panic("Failed to add resource: {!}", .{err});
            };
        }
    }

    test "optional resource access" {
        comptime var systems = SystemRegistry.init();
        comptime systems.addSystem(counterResInsertOrInc);

        var ecs = ECS(systems).init(allocator);
        defer ecs.deinit();

        ecs.tick();
        try testing.expectEqual(0, ecs.world.getResource(Counter).?.count);
        ecs.tick();
        try testing.expectEqual(1, ecs.world.getResource(Counter).?.count);
    }
};
