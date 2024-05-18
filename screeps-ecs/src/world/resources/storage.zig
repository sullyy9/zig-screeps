const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const typeid = @import("../typeid.zig");
const typeID = typeid.typeID;

/// Type errased storage for resources.
pub const Storage = struct {
    const Self = @This();

    type_id: usize,
    alignment: usize,
    memory: []u8,

    pub fn init(allocator: Allocator, resource: anytype) Allocator.Error!Self {
        const memory = try allocator.alloc(u8, @sizeOf(@TypeOf(resource)));
        errdefer allocator.free(memory);

        @memcpy(memory, std.mem.asBytes(&resource));

        return Self{
            .type_id = typeID(@TypeOf(resource)),
            .alignment = @alignOf(@TypeOf(resource)),
            .memory = memory,
        };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        if (self.memory.len > 0) allocator.free(self.memory);
    }

    /// Determine if the storage contains an object of the given type.
    pub fn is(self: *const Self, comptime T: type) bool {
        return typeID(T) == self.type_id;
    }

    /// Obtain the object contained within.
    pub fn as(self: *const Self, comptime T: type) T {
        assert(typeID(T) == self.type_id);
        return @as(*const T, @alignCast(@ptrCast(self.memory.ptr))).*;
    }

    /// Obtain a pointer to the object contained within.
    pub fn asPtr(self: *Self, comptime T: type) *T {
        assert(typeID(T) == self.type_id);
        return @as(*T, @alignCast(@ptrCast(self.memory.ptr)));
    }

    /// Obtain a const pointer to the object contained within.
    pub fn asPtrConst(self: *Self, comptime T: type) *const T {
        assert(typeID(T) == self.type_id);
        return @as(*const T, @alignCast(@ptrCast(self.memory.ptr)));
    }
};

pub const Test = struct {
    const testing = std.testing;
    const allocator = std.testing.allocator;

    const components = @import("../../testing/mod.zig");
    const Movement = components.Movement;

    test "as" {
        const input = Movement{ .walking = 7 };
        var storage = try Storage.init(allocator, input);
        defer storage.deinit(allocator);

        try testing.expectEqual(input, storage.as(Movement));
    }

    test "asPtr" {
        const input = Movement{ .walking = 7 };
        var storage = try Storage.init(allocator, input);
        defer storage.deinit(allocator);

        try testing.expectEqual(input, storage.asPtr(Movement).*);

        storage.asPtr(Movement).* = Movement{ .running = 2 };
        try testing.expectEqual(Movement{ .running = 2 }, storage.asPtr(Movement).*);
    }
};
