const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;

const World = @import("../world/mod.zig").World;

const SystemParam = @import("param.zig").SystemParam;
const Registry = @import("registry.zig").Registry;

pub const Scheduler = struct {
    const Self = @This();

    pub fn init() Self {
        return .{};
    }

    pub fn run(self: *Self, world: *World, comptime systems: Registry) void {
        _ = self;
        
        inline for (systems.systems[0..systems.count]) |system| {
            const func: *const system.Type() = @ptrCast(system.ptr);

            var args: system.args = undefined;
            inline for (&args) |*arg| {
                arg.* = switch (SystemParam.init(@TypeOf(arg.*))) {
                    .query => |Q| Q.init(world),
                    .world_ptr => world,

                    .resource_ptr => |Res| brk: {
                        if (world.getResourcePtr(Res)) |resource| break :brk resource;

                        std.debug.panic(
                            "Resource '{s}' requested by system '{s}' is not available",
                            .{ @typeName(Res), system.name() },
                        );
                    },

                    .resource_ptr_const => |Res| brk: {
                        if (world.getResourcePtrConst(Res)) |resource| break :brk resource;

                        std.debug.panic(
                            "Resource '{s}' requested by system '{s}' is not available",
                            .{ @typeName(Res), system.name() },
                        );
                    },

                    .opt_resource_ptr => |Res| world.getResourcePtr(Res),
                    .opt_resource_ptr_const => |Res| world.getResourcePtrConst(Res),
                };
            }

            @call(.auto, func, args);
        }
    }
};
