const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const typeID = @import("../typeid.zig").typeID;
const assertIsComponent = @import("component.zig").assertIsComponent;

/// Type erased list of components.
pub const ComponentList = struct {
    const Self = @This();

    type_id: usize,
    type_size: usize,
    type_alignment: usize,
    memory: []u8,

    pub fn initEmpty(Component: type) Self {
        comptime assertIsComponent(Component);

        return Self{
            .type_id = typeID(Component),
            .type_size = @sizeOf(Component),
            .type_alignment = @alignOf(Component),
            .memory = &.{},
        };
    }

    pub fn initCapacity(allocator: Allocator, Component: type, capacity: usize) Allocator.Error!Self {
        comptime assertIsComponent(Component);

        return Self{
            .type_id = typeID(Component),
            .type_size = @sizeOf(Component),
            .type_alignment = @alignOf(Component),
            .memory = try allocator.alloc(u8, @sizeOf(Component) * capacity),
        };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        if (self.memory.len > 0) {
            allocator.free(self.memory);
        }
    }

    pub fn set(self: *Self, index: usize, value: anytype) void {
        assert(index < self.memory.len);
        assert(typeID(@TypeOf(value)) == self.type_id);

        const beg = index * self.type_size;
        const end = beg + self.type_size;

        @memcpy(self.memory[beg..end], std.mem.asBytes(&value));
    }

    pub fn get(self: *const Self, index: usize, T: type) *const T {
        assert(index < self.memory.len);
        assert(typeID(T) == self.type_id);

        const beg = index * self.type_size;
        const end = beg + self.type_size;

        const bytes = self.memory[beg..end];
        return @as(*const T, @alignCast(@ptrCast(bytes.ptr)));
    }

    pub fn getMut(self: *Self, index: usize, T: type) *T {
        assert(index < self.memory.len);
        assert(typeID(T) == self.type_id);

        const beg = index * self.type_size;
        const end = beg + self.type_size;

        const bytes = self.memory[beg..end];
        return @as(*T, @alignCast(@ptrCast(bytes.ptr)));
    }

    pub fn asSlice(self: *const Self, comptime T: type) []const T {
        assert(typeID(T) == self.type_id);

        const ptr = @as([*]const T, @alignCast(@ptrCast(self.memory.ptr)));
        const len = @divExact(self.memory.len, self.type_size);
        return ptr[0..len];
    }

    pub fn asSliceMut(self: *Self, comptime T: type) []T {
        assert(typeID(T) == self.type_id);

        const ptr = @as([*]T, @alignCast(@ptrCast(self.memory.ptr)));
        const len = @divExact(self.memory.len, self.type_size);
        return ptr[0..len];
    }
};
