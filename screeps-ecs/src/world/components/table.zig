const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const StructField = std.builtin.Type.StructField;

const typeID = @import("../typeid.zig").typeID;
const ComponentList = @import("storage.zig").ComponentList;
const assertIsComponent = @import("component.zig").assertIsComponent;
const assertIsArchetype = @import("archetype.zig").assertIsArchetype;

/// Table containing entities of a certain archetype.
pub const ArchetypeTable = struct {
    const Self = @This();

    row_len: usize,
    row_capacity: usize,

    columns: []ComponentList,

    /// Initialise an ArchetypeTable for an archetype with no components.
    pub fn initVoid() Self {
        return Self{
            .row_len = 0,
            .row_capacity = 0,
            .columns = &.{},
        };
    }

    pub fn initEmpty(allocator: Allocator, comptime Archetype: type) Allocator.Error!Self {
        comptime assertIsArchetype(Archetype);

        const fields: []const StructField = std.meta.fields(Archetype);
        var columns = try allocator.alloc(ComponentList, fields.len);

        inline for (fields, 0..) |field, i| columns[i] = ComponentList.initEmpty(field.type);

        return Self{
            .row_len = 0,
            .row_capacity = 0,
            .columns = columns,
        };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        for (self.columns) |*column| column.deinit(allocator);
        allocator.free(self.columns);
    }

    pub fn rows(self: *const Self) usize {
        return self.row_len;
    }

    /// Determine if this table contains a given component.
    pub fn hasComponent(self: *const Self, comptime Component: type) bool {
        comptime assertIsComponent(Component);

        for (self.columns) |column| {
            if (column.type_id == typeID(Component)) {
                return true;
            }
        }

        return false;
    }

    /// Determine if this table contains all of the archetypes components. Does not determine if the
    /// table contains additional components not present in the archetype.
    pub fn hasComponentsOf(self: *const Self, comptime Archetype: type) bool {
        comptime assertIsArchetype(Archetype);

        // Check that this table has a column for each component.
        inline for (std.meta.fields(Archetype)) |f| {
            const field: StructField = f;
            if (!self.hasComponent(field.type)) {
                return false;
            }
        }

        return true;
    }

    /// Ensure that the ammount of memory allocated for the table is enough to contain at least the
    /// given ammount of rows.
    ///
    /// Parameters
    /// ----------
    /// - `self`      : Self
    /// - `allocator` : Allocator
    /// - `capacity`  : Minimum number of rows this table should be able to contain. Must not be
    ///                 less than the current table length.
    ///
    pub fn ensureTotalCapacity(self: *Self, allocator: Allocator, capacity: usize) Allocator.Error!void {
        assert(capacity >= self.row_len);

        // Extend the capacity of each column.
        for (self.columns) |*column| {
            const old_memory = column.memory;
            column.memory = try allocator.alloc(u8, column.type_size * capacity);

            @memcpy(column.memory[0..old_memory.len], old_memory);
            allocator.free(old_memory);
        }

        self.row_capacity = capacity;
    }

    /// Ensure that the ammount of unused memory allocated for the table is enough to contain at
    /// least the given ammount of rows.
    ///
    /// Parameters
    /// ----------
    /// - `self`      : Self
    /// - `allocator` : Allocator
    /// - `unused`    : Minimum number of rows this table should be able to add without
    ///                 reallocation.
    ///
    pub fn ensureUnusedCapacity(self: *Self, allocator: Allocator, unused: usize) Allocator.Error!void {
        const current = self.row_capacity - self.row_len;
        if (current >= unused) return;

        const extra = unused - current;
        try self.ensureTotalCapacity(allocator, self.row_capacity + extra);
    }

    /// Insert a new row and return it's index.
    pub fn insertRow(self: *Self, allocator: Allocator, value: anytype) Allocator.Error!usize {
        comptime assertIsArchetype(@TypeOf(value));
        assert(self.hasComponentsOf(@TypeOf(value)));

        try self.ensureUnusedCapacity(allocator, 1);

        inline for (std.meta.fields(@TypeOf(value))) |f| {
            const field: StructField = f;

            const column = self.getColumnMut(field.type);
            column.set(self.row_len, @field(value, field.name));
        }

        const index = self.row_len;
        self.row_len += 1;
        return index;
    }

    /// Add a new component to the archetype this table covers. The value of the component for every
    /// row will be undefined.
    pub fn addComponent(self: *Self, allocator: Allocator, comptime Component: type) Allocator.Error!void {
        comptime assertIsComponent(Component);
        assert(!hasComponent(self, Component));

        // Create the new column with each element set to undefined.
        const new_column = try ComponentList.initCapacity(allocator, Component, self.row_capacity);

        // Allocate memory for the new slice of columns and copy over the old ones.
        const old_columns = self.columns;
        defer allocator.free(old_columns);

        self.columns = try allocator.alloc(ComponentList, old_columns.len + 1);
        @memcpy(self.columns[0..old_columns.len], old_columns);

        // Copy the new column into the last element of the slice.
        self.columns[self.columns.len - 1] = new_column;
    }

    /// Set the value of a component on a given row.
    pub fn setComponent(self: *Self, row: usize, value: anytype) void {
        comptime assertIsComponent(@TypeOf(value));
        assert(row < self.row_len);

        for (self.columns) |*column| {
            if (column.type_id == typeID(@TypeOf(value))) {
                column.set(row, value);
                return;
            }
        }
    }

    /// Get an immutable pointer to a component on a given row.
    pub fn getComponent(self: *const Self, row: usize, comptime Component: type) *const Component {
        comptime assertIsComponent(Component);
        assert(row < self.row_len);

        for (self.columns) |*column| {
            if (column.type_id == typeID(Component)) {
                return column.get(row, Component);
            }
        }

        std.debug.panic("Table does not contain component: {}", .{Component});
    }

    /// Get an mutable pointer to a component on a given row.
    pub fn getComponentMut(self: *Self, row: usize, comptime Component: type) *Component {
        comptime assertIsComponent(Component);
        assert(row < self.row_len);

        for (self.columns) |*column| {
            if (column.type_id == typeID(Component)) {
                return column.getMut(row, Component);
            }
        }

        std.debug.panic("Table does not contain component: {}", .{Component});
    }

    /// Obtain an immutable slice of all values of a given component.
    pub fn getComponentSlice(self: *const Self, comptime Component: type) []const Component {
        comptime assertIsComponent(Component);

        const column = self.getColumn(Component);
        return column.asSlice(Component);
    }

    /// Obtain a mutable slice of all values of a given component.
    pub fn getComponentSliceMut(self: *Self, comptime Component: type) []Component {
        comptime assertIsComponent(Component);

        const column = self.getColumnMut(Component);
        return column.asSliceMut(Component);
    }

    /// Obtain an iterator over immutable values of a given component.
    pub fn iterComponents(self: *const Self, comptime Component: type) ComponentIter(Component) {
        comptime assertIsComponent(Component);
        return ComponentIter(Component).init(self.getComponentSlice(Component));
    }

    /// Obtain an iterator over mutable values of a given component.
    pub fn iterComponentsMut(self: *Self, comptime Component: type) ComponentIterMut(Component) {
        comptime assertIsComponent(Component);
        return ComponentIterMut(Component).init(self.getComponentSliceMut(Component));
    }

    fn getColumn(self: *const Self, comptime Component: type) *const ComponentList {
        comptime assertIsComponent(Component);

        for (self.columns) |*column| {
            if (column.type_id == typeID(Component)) {
                return column;
            }
        }

        std.debug.panic("No column for component: {}", .{Component});
    }

    fn getColumnMut(self: *Self, comptime Component: type) *ComponentList {
        comptime assertIsComponent(Component);

        for (self.columns) |*column| {
            if (column.type_id == typeID(Component)) {
                return column;
            }
        }

        std.debug.panic("No column for component: {}", .{Component});
    }
};

pub fn ComponentIter(comptime Component: type) type {
    assertIsComponent(Component);

    return struct {
        const Self = @This();

        count: usize,
        components: []const Component,

        pub fn init(components: []const Component) Self {
            return Self{
                .count = 0,
                .components = components,
            };
        }

        pub fn next(self: *Self) ?*const Component {
            if (self.count >= self.components.len) {
                return null;
            }

            const value = &self.components[self.count];
            self.count += 1;
            return value;
        }
    };
}

pub fn ComponentIterMut(comptime Component: type) type {
    return struct {
        const Self = @This();

        count: usize,
        components: []Component,

        pub fn init(components: []Component) Self {
            return Self{
                .count = 0,
                .components = components,
            };
        }

        pub fn next(self: *Self) ?*Component {
            if (self.count >= self.components.len) {
                return null;
            }

            const value = &self.components[self.count];
            self.count += 1;
            return value;
        }
    };
}

pub const Test = struct {
    const testing = std.testing;
    const allocator = std.testing.allocator;

    const Name = struct {
        const Self = @This();

        name: []const u8,

        pub fn init(name: []const u8) Self {
            return Self{ .name = name };
        }
    };

    const ID = struct {
        const Self = @This();

        big_id: u64,
        smol_id: u8,

        pub fn init(big: u64, smol: u8) Self {
            return Self{ .big_id = big, .smol_id = smol };
        }
    };

    const Funky = struct {
        const Self = @This();

        in_a_good_way: bool,
        in_a_bad_way: bool,

        pub fn initInAGoodWay() Self {
            return Self{ .in_a_bad_way = false, .in_a_good_way = true };
        }

        pub fn initInABadWay() Self {
            return Self{ .in_a_bad_way = true, .in_a_good_way = false };
        }
    };

    const NameAndID = struct {
        const Self = @This();

        name: Name,
        id: ID,

        pub fn init(name: Name, id: ID) Self {
            return Self{ .name = name, .id = id };
        }
    };

    const FunkyNameAndID = struct {
        const Self = @This();

        name: Name,
        id: ID,
        funky: Funky,

        pub fn init(name: Name, id: ID, funky: Funky) Self {
            return Self{ .name = name, .id = id, .funky = funky };
        }
    };

    test "hasComponent" {
        var arch = try ArchetypeTable.initEmpty(allocator, NameAndID);
        defer arch.deinit(allocator);

        try testing.expect(arch.hasComponent(Name));
        try testing.expect(arch.hasComponent(ID));
        try testing.expect(!arch.hasComponent(Funky));
    }

    test "hasComponentsOf" {
        var arch = try ArchetypeTable.initEmpty(allocator, NameAndID);
        defer arch.deinit(allocator);

        try testing.expect(arch.hasComponentsOf(NameAndID));
        try testing.expect(!arch.hasComponentsOf(FunkyNameAndID));

        try arch.addComponent(allocator, Funky);

        try testing.expect(arch.hasComponentsOf(NameAndID));
        try testing.expect(arch.hasComponentsOf(FunkyNameAndID));
    }

    test "ensureTotalCapacity" {
        var arch = try ArchetypeTable.initEmpty(allocator, NameAndID);
        defer arch.deinit(allocator);

        const capacity = 5;
        try arch.ensureTotalCapacity(allocator, capacity);

        try testing.expectEqual(arch.columns.len, 2);
        for (arch.columns) |column| {
            try testing.expect(column.memory.len >= column.type_size * capacity);
        }
    }

    test "ensureUnusedCapacity" {
        var arch = try ArchetypeTable.initEmpty(allocator, NameAndID);
        defer arch.deinit(allocator);

        const unused_capacity = 5;
        try arch.ensureUnusedCapacity(allocator, unused_capacity);

        try testing.expectEqual(arch.columns.len, 2);
        for (arch.columns) |column| {
            try testing.expect(column.memory.len >= column.type_size * unused_capacity);
        }

        _ = try arch.insertRow(allocator, NameAndID.init(Name.init("test"), ID.init(69, 42)));
        try arch.ensureUnusedCapacity(allocator, unused_capacity);

        for (arch.columns) |column| {
            try testing.expect(column.memory.len >= column.type_size * (unused_capacity + 1));
        }
    }

    test "addComponent" {
        var arch = ArchetypeTable.initVoid();
        defer arch.deinit(allocator);

        try arch.addComponent(allocator, Name);
        try testing.expectEqual(arch.columns.len, 1);

        try arch.addComponent(allocator, ID);
        try testing.expectEqual(arch.columns.len, 2);
    }

    test "insertRow" {
        var arch = try ArchetypeTable.initEmpty(allocator, NameAndID);
        defer arch.deinit(allocator);

        const index = try arch.insertRow(allocator, NameAndID.init(Name.init("test"), ID.init(69, 42)));
        try testing.expectEqual(Name.init("test"), arch.getComponent(index, Name).*);
        try testing.expectEqual(ID.init(69, 42), arch.getComponent(index, ID).*);

        const index2 = try arch.insertRow(allocator, NameAndID.init(Name.init("test2"), ID.init(96, 24)));
        try testing.expectEqual(Name.init("test2"), arch.getComponent(index2, Name).*);
        try testing.expectEqual(ID.init(96, 24), arch.getComponent(index2, ID).*);
    }

    test "set" {
        var arch = try ArchetypeTable.initEmpty(allocator, NameAndID);
        defer arch.deinit(allocator);

        const capacity = 5;
        try arch.ensureTotalCapacity(allocator, capacity);
        _ = try arch.insertRow(allocator, NameAndID.init(Name.init("test"), ID.init(69, 42)));

        arch.setComponent(0, Name.init("test name"));

        try testing.expectEqual(Name.init("test name"), arch.getComponent(0, Name).*);
    }

    test "getComponentSlice" {
        var arch = try ArchetypeTable.initEmpty(allocator, NameAndID);
        defer arch.deinit(allocator);

        _ = try arch.insertRow(allocator, NameAndID.init(Name.init("test1"), ID.init(69, 42)));
        _ = try arch.insertRow(allocator, NameAndID.init(Name.init("test2"), ID.init(70, 43)));
        _ = try arch.insertRow(allocator, NameAndID.init(Name.init("test3"), ID.init(71, 44)));

        const names = arch.getComponentSlice(Name);
        const ids = arch.getComponentSlice(ID);

        try testing.expectEqual(Name.init("test1"), names[0]);
        try testing.expectEqual(Name.init("test2"), names[1]);
        try testing.expectEqual(Name.init("test3"), names[2]);

        try testing.expectEqual(ID.init(69, 42), ids[0]);
        try testing.expectEqual(ID.init(70, 43), ids[1]);
        try testing.expectEqual(ID.init(71, 44), ids[2]);

        try testing.expectEqual(3, names.len);
        try testing.expectEqual(3, ids.len);
    }

    test "getComponentSliceMut" {
        var arch = try ArchetypeTable.initEmpty(allocator, NameAndID);
        defer arch.deinit(allocator);

        _ = try arch.insertRow(allocator, NameAndID.init(Name.init("test1"), ID.init(69, 42)));
        _ = try arch.insertRow(allocator, NameAndID.init(Name.init("test2"), ID.init(70, 43)));
        _ = try arch.insertRow(allocator, NameAndID.init(Name.init("test3"), ID.init(71, 44)));

        const names = arch.getComponentSliceMut(Name);
        const ids = arch.getComponentSliceMut(ID);

        try testing.expectEqual(Name.init("test1"), names[0]);
        try testing.expectEqual(Name.init("test2"), names[1]);
        try testing.expectEqual(Name.init("test3"), names[2]);

        try testing.expectEqual(ID.init(69, 42), ids[0]);
        try testing.expectEqual(ID.init(70, 43), ids[1]);
        try testing.expectEqual(ID.init(71, 44), ids[2]);

        try testing.expectEqual(3, names.len);
        try testing.expectEqual(3, ids.len);

        names[1] = Name.init("test4");
        try testing.expectEqual(Name.init("test4"), arch.getComponent(1, Name).*);
    }

    test "iter" {
        var arch = try ArchetypeTable.initEmpty(allocator, NameAndID);
        defer arch.deinit(allocator);

        _ = try arch.insertRow(allocator, NameAndID.init(Name.init("test1"), ID.init(69, 42)));
        _ = try arch.insertRow(allocator, NameAndID.init(Name.init("test2"), ID.init(70, 43)));
        _ = try arch.insertRow(allocator, NameAndID.init(Name.init("test3"), ID.init(71, 44)));

        var names = arch.iterComponents(Name);
        var ids = arch.iterComponents(ID);

        try testing.expectEqual(Name.init("test1"), names.next().?.*);
        try testing.expectEqual(Name.init("test2"), names.next().?.*);
        try testing.expectEqual(Name.init("test3"), names.next().?.*);
        try testing.expect(null == names.next());

        try testing.expectEqual(ID.init(69, 42), ids.next().?.*);
        try testing.expectEqual(ID.init(70, 43), ids.next().?.*);
        try testing.expectEqual(ID.init(71, 44), ids.next().?.*);
        try testing.expect(null == ids.next());
    }

    test "iterMut" {
        var arch = try ArchetypeTable.initEmpty(allocator, NameAndID);
        defer arch.deinit(allocator);

        _ = try arch.insertRow(allocator, NameAndID.init(Name.init("test1"), ID.init(69, 42)));
        _ = try arch.insertRow(allocator, NameAndID.init(Name.init("test2"), ID.init(70, 43)));
        _ = try arch.insertRow(allocator, NameAndID.init(Name.init("test3"), ID.init(71, 44)));

        var names = arch.iterComponentsMut(Name);
        var ids = arch.iterComponentsMut(ID);

        try testing.expectEqual(Name.init("test1"), names.next().?.*);
        try testing.expectEqual(Name.init("test2"), names.next().?.*);
        try testing.expectEqual(Name.init("test3"), names.next().?.*);
        try testing.expect(null == names.next());

        try testing.expectEqual(ID.init(69, 42), ids.next().?.*);
        try testing.expectEqual(ID.init(70, 43), ids.next().?.*);
        try testing.expectEqual(ID.init(71, 44), ids.next().?.*);
        try testing.expect(null == ids.next());

        var names2 = arch.iterComponentsMut(Name);
        _ = names2.next();
        names2.next().?.* = Name.init("test4");
        try testing.expectEqual(Name.init("test4"), arch.getComponent(1, Name).*);
    }
};
