const system_module = @import("system.zig");
const SystemWrapper = system_module.SystemWrapper;
const asserIsSystem = system_module.assertIsSystem;

/// This needs to be a seperate object since the list of systems needs to be created at comptime.
/// TODO: Rather than statically allocating an array could use buidler pattern?:
/// fn addSystem([N]System) -> [N+1]System
pub const Registry = struct {
    const Self = @This();

    count: usize,
    systems: [128]SystemWrapper,

    pub fn init() Self {
        return Self{
            .count = 0,
            .systems = undefined,
        };
    }

    pub inline fn addSystem(comptime self: *Self, comptime system: anytype) void {
        asserIsSystem(@TypeOf(system));

        if (self.count >= self.systems.len) @compileError("Too many systems!");

        self.systems[self.count] = SystemWrapper.init(system);
        self.count += 1;
    }
};
