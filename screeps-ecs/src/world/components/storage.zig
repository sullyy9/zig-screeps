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

    /// Create an empty `ComponentList`.
    ///
    /// Parameters
    /// ----------
    /// - `T` : Type of the component that will be stored in the list.
    ///
    pub fn init(comptime T: type) Self {
        comptime assertIsComponent(T);

        return Self{
            .type_id = typeID(T),
            .type_size = @sizeOf(T),
            .type_alignment = @alignOf(T),
            .memory = &.{},
        };
    }

    /// Create an empty `ComponentList` with a given capacity.
    ///
    /// Parameters
    /// ----------
    /// - `T`        : Type of the component that will be stored in the list.
    /// - `capacity` : Capacity of the list.
    ///
    pub fn initCapacity(allocator: Allocator, comptime T: type, capacity: usize) Allocator.Error!Self {
        comptime assertIsComponent(T);

        return Self{
            .type_id = typeID(T),
            .type_size = @sizeOf(T),
            .type_alignment = @alignOf(T),
            .memory = try allocator.alloc(u8, @sizeOf(T) * capacity),
        };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        if (self.memory.len > 0) {
            allocator.free(self.memory);
        }
    }

    /// Replace the value of a component at a given index.
    ///
    /// Asserts that `index` is contained within the list.
    /// Asserts that the type of `value` is the component type contained within the list.
    ///
    /// Parameters
    /// ----------
    /// - `index` : Index of the component.
    /// - `value` : Value to set the component to.
    ///
    pub fn replace(self: *Self, index: usize, value: anytype) void {
        assert(index < self.memory.len);
        assert(typeID(@TypeOf(value)) == self.type_id);

        const beg = index * self.type_size;
        const end = beg + self.type_size;

        @memcpy(self.memory[beg..end], std.mem.asBytes(&value));
    }

    /// Get a pointer to a component at a given index.
    ///
    /// Asserts that `index` is contained within the list.
    /// Asserts that `T` is the component type contained within the list.
    ///
    /// Parameters
    /// ----------
    /// - `index` : Index of the component.
    /// - `T`     : Type of the component.
    ///
    pub fn getPtr(self: *Self, index: usize, comptime T: type) *T {
        assert(index < self.memory.len);
        assert(typeID(T) == self.type_id);

        const beg = index * self.type_size;
        const end = beg + self.type_size;

        const bytes = self.memory[beg..end];
        return @as(*T, @alignCast(@ptrCast(bytes.ptr)));
    }

    /// Get a const pointer to a component at a given index.
    ///
    /// Asserts that `index` is contained within the list.
    /// Asserts that `T` is the component type contained within the list.
    ///
    /// Parameters
    /// ----------
    /// - `index` : Index of the component.
    /// - `T`     : Type of the component.
    ///
    pub fn getPtrConst(self: *const Self, index: usize, comptime T: type) *const T {
        assert(index < self.memory.len);
        assert(typeID(T) == self.type_id);

        const beg = index * self.type_size;
        const end = beg + self.type_size;

        const bytes = self.memory[beg..end];
        return @as(*const T, @alignCast(@ptrCast(bytes.ptr)));
    }

    /// Get a slice over the list.
    ///
    /// Asserts that `T` is the component type contained within the list.
    ///
    /// Parameters
    /// ----------
    /// - `T` : Type of the components constained within the list.
    ///
    pub fn asSlice(self: *Self, comptime T: type) []T {
        assert(typeID(T) == self.type_id);

        const ptr = @as([*]T, @alignCast(@ptrCast(self.memory.ptr)));
        const len = @divExact(self.memory.len, self.type_size);
        return ptr[0..len];
    }

    /// Get a const slice over the list.
    ///
    /// Asserts that `T` is the component type contained within the list.
    ///
    /// Parameters
    /// ----------
    /// - `T` : Type of the components constained within the list.
    ///
    pub fn asSliceConst(self: *const Self, comptime T: type) []const T {
        assert(typeID(T) == self.type_id);

        const ptr = @as([*]const T, @alignCast(@ptrCast(self.memory.ptr)));
        const len = @divExact(self.memory.len, self.type_size);
        return ptr[0..len];
    }
};
