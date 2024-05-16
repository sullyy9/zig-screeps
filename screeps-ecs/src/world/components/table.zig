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

    /// Create an empty `ArchetypeTable` with no components.
    pub fn initVoid() Self {
        return Self{
            .row_len = 0,
            .row_capacity = 0,
            .columns = &.{},
        };
    }

    /// Create an empty `ArchetypeTable` for a given `Archetype`.
    ///
    /// Asserts that `Arch` is an `Archetype`.
    ///
    /// Parameters
    /// ----------
    /// - `Arch` : Type of the `Archetype` that will be stored in the table.
    ///
    pub fn initEmpty(allocator: Allocator, comptime Arch: type) Allocator.Error!Self {
        comptime assertIsArchetype(Arch);

        const fields: []const StructField = std.meta.fields(Arch);

        var columns = try allocator.alloc(ComponentList, fields.len);
        errdefer allocator.free(columns);

        inline for (fields, 0..) |field, i| columns[i] = ComponentList.init(field.type);

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

    /// Return the number of rows in the table.
    pub fn rows(self: *const Self) usize {
        return self.row_len;
    }

    /// Determine if the table contains a column for a given `Component`.
    ///
    /// Asserts that `Comp` fullfills the requirements of `Component`.
    ///
    /// Parameters
    /// ----------
    /// - `Comp` : Type of the `Component`.
    ///
    pub fn hasComponent(self: *const Self, comptime Comp: type) bool {
        comptime assertIsComponent(Comp);

        for (self.columns) |column| {
            if (column.type_id == comptime typeID(Comp)) return true;
        }

        return false;
    }

    /// Determine if the table contains columns for each `Component` in a given `Archetype`.
    ///
    /// Does not determine if the table contains columns for additonal `Components` not in the
    /// `Archetype`.
    /// Asserts that `Arch` fullfills the requirements of `Archetype`.
    ///
    /// Parameters
    /// ----------
    /// - `Arch` : Type of the `Archetype`.
    ///
    pub fn hasComponentsOf(self: *const Self, comptime Arch: type) bool {
        comptime assertIsArchetype(Arch);

        // Check that this table has a column for each component.
        inline for (std.meta.fields(Arch)) |f| {
            const field: StructField = f;
            if (!self.hasComponent(field.type)) return false;
        }

        return true;
    }

    /// Add a new `Component` to each entity in the table.
    ///
    /// The value of the `Compoenent` will be set to `undefined` for each entity.
    ///
    /// Parameters
    /// ----------
    /// - `allocator` : Allocator.
    /// - `Comp`      : Type of the `Component` to add.
    ///
    pub fn addComponent(self: *Self, allocator: Allocator, comptime Comp: type) Allocator.Error!void {
        comptime assertIsComponent(Comp);
        assert(!hasComponent(self, Comp));

        // Create the new column with each element set to undefined.
        var new_column = try ComponentList.initCapacity(allocator, Comp, self.row_capacity);
        errdefer new_column.deinit(allocator);

        // Allocate memory for the new slice of columns and copy over the old ones.
        const old_columns = self.columns;
        defer allocator.free(old_columns);

        self.columns = try allocator.alloc(ComponentList, old_columns.len + 1);
        @memcpy(self.columns[0..old_columns.len], old_columns);

        // Copy the new column into the last element of the slice.
        self.columns[self.columns.len - 1] = new_column;
    }

    /// Ensure that the ammount of memory allocated for the table is enough to contain at least a
    /// given number of rows.
    ///
    /// Asserts that `capacity` is not less than the current number of rows.
    ///
    /// Parameters
    /// ----------
    /// - `allocator` : Allocator.
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
    /// least a given number of rows.
    ///
    /// Parameters
    /// ----------
    /// - `allocator` : Allocator.
    /// - `unused`    : Minimum number of rows this table should be able to add without
    ///                 reallocation.
    ///
    pub fn ensureUnusedCapacity(self: *Self, allocator: Allocator, unused: usize) Allocator.Error!void {
        const current = self.row_capacity - self.row_len;
        if (current >= unused) return;

        const extra = unused - current;
        try self.ensureTotalCapacity(allocator, self.row_capacity + extra);
    }

    /// Add a new entity into the table and return it's index.
    ///
    /// Asserts that the type of `entity` fullfills the requirements of `Archetype`.
    /// Asserts that the table contains each `Component` in the `entity` `Archetype`.
    ///
    /// Parameters
    /// ----------
    /// - `allocator` : Allocator.
    /// - `entity`    : Entity to add.
    ///
    pub fn addEntity(self: *Self, allocator: Allocator, entity: anytype) Allocator.Error!usize {
        comptime assertIsArchetype(@TypeOf(entity));
        assert(self.hasComponentsOf(@TypeOf(entity)));

        try self.ensureUnusedCapacity(allocator, 1);

        inline for (std.meta.fields(@TypeOf(entity))) |f| {
            const field: StructField = f;

            const column = self.getColumnPtr(field.type);
            column.replace(self.row_len, @field(entity, field.name));
        }

        const index = self.row_len;
        self.row_len += 1;
        return index;
    }

    /// Set the value of a `Component` in an enity given its row.
    ///
    /// Asserts that `row` is contained within the table.
    /// Asserts that the type of `value` fullfills the requirements of `Component`.
    ///
    /// Parameters
    /// ----------
    /// - `row`   : Row of the entity to modify.
    /// - `value` : Value to set the `Component` to.
    ///
    pub fn setComponent(self: *Self, row: usize, value: anytype) void {
        comptime assertIsComponent(@TypeOf(value));
        assert(row < self.row_len);

        for (self.columns) |*column| {
            if (column.type_id == typeID(@TypeOf(value))) {
                column.replace(row, value);
                return;
            }
        }
    }

    /// Get a pointer to an entities `Component` given its row.
    ///
    /// Asserts that `row` is contained within the table.
    /// Asserts that `Comp` fullfills the requirements of `Component`.
    /// Panics if the table doesn't contain `Components` of type `Comp`.
    ///
    /// Parameters
    /// ----------
    /// - `row`  : Row of the entity.
    /// - `Comp` : Type of the `Component`.
    ///
    pub fn getComponentPtr(self: *Self, row: usize, comptime Comp: type) *Comp {
        comptime assertIsComponent(Comp);
        assert(row < self.row_len);

        for (self.columns) |*column| {
            if (column.type_id == typeID(Comp)) {
                return column.getPtr(row, Comp);
            }
        }

        std.debug.panic("Table does not contain component: {}", .{Comp});
    }

    /// Get a const pointer to an entities `Component` given its row.
    ///
    /// Asserts that `row` is contained within the table.
    /// Asserts that `Comp` fullfills the requirements of `Component`.
    /// Panics if the table doesn't contain `Components` of type `Comp`.
    ///
    /// Parameters
    /// ----------
    /// - `row`  : Row of the entity.
    /// - `Comp` : Type of the `Component`.
    ///
    pub fn getComponentPtrConst(self: *const Self, row: usize, comptime Comp: type) *const Comp {
        comptime assertIsComponent(Comp);
        assert(row < self.row_len);

        for (self.columns) |*column| {
            if (column.type_id == typeID(Comp)) {
                return column.getPtrConst(row, Comp);
            }
        }

        std.debug.panic("Table does not contain component: {}", .{Comp});
    }

    /// Get a slice over a given `Component` for all entities.
    ///
    /// Asserts that `Comp` fullfills the requirements of `Component`.
    ///
    /// Parameters
    /// ----------
    /// - `Comp` : Type of the `Component`.
    ///
    pub fn getComponentSlice(self: *Self, comptime Comp: type) []Comp {
        comptime assertIsComponent(Comp);

        const column = self.getColumnPtr(Comp);
        return column.asSlice(Comp);
    }

    /// Get a const slice over a given `Component` for all entities.
    ///
    /// Asserts that `Comp` fullfills the requirements of `Component`.
    ///
    /// Parameters
    /// ----------
    /// - `Comp` : Type of the `Component`.
    ///
    pub fn getComponentSliceConst(self: *const Self, comptime Component: type) []const Component {
        comptime assertIsComponent(Component);

        const column = self.getColumnPtrConst(Component);
        return column.asSliceConst(Component);
    }

    /// Obtain an iterator over mutable values of a given component.
    pub fn iterComponents(self: *Self, comptime Component: type) ComponentIter(Component) {
        comptime assertIsComponent(Component);
        return ComponentIter(Component).init(self.getComponentSlice(Component));
    }

    /// Obtain an iterator over immutable values of a given component.
    pub fn iterComponentsConst(self: *const Self, comptime Component: type) ComponentIterConst(Component) {
        comptime assertIsComponent(Component);
        return ComponentIterConst(Component).init(self.getComponentSliceConst(Component));
    }

    fn getColumnPtr(self: *Self, comptime Component: type) *ComponentList {
        comptime assertIsComponent(Component);

        for (self.columns) |*column| {
            if (column.type_id == typeID(Component)) {
                return column;
            }
        }

        std.debug.panic("No column for component: {}", .{Component});
    }

    fn getColumnPtrConst(self: *const Self, comptime Component: type) *const ComponentList {
        comptime assertIsComponent(Component);

        for (self.columns) |*column| {
            if (column.type_id == typeID(Component)) {
                return column;
            }
        }

        std.debug.panic("No column for component: {}", .{Component});
    }
};

pub fn ComponentIterConst(comptime Component: type) type {
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

pub fn ComponentIter(comptime Component: type) type {
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

    const components = @import("../../testing/components.zig");
    const ID = components.ID;
    const Name = components.Name;
    const Funky = components.Funky;
    const NameAndID = components.NameAndID;
    const FunkyNameAndID = components.FunkyNameAndID;

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

    test "addComponent" {
        var arch = ArchetypeTable.initVoid();
        defer arch.deinit(allocator);

        try arch.addComponent(allocator, Name);
        try testing.expectEqual(arch.columns.len, 1);

        try arch.addComponent(allocator, ID);
        try testing.expectEqual(arch.columns.len, 2);
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

        _ = try arch.addEntity(allocator, NameAndID.initRaw("test", 69));
        try arch.ensureUnusedCapacity(allocator, unused_capacity);

        for (arch.columns) |column| {
            try testing.expect(column.memory.len >= column.type_size * (unused_capacity + 1));
        }
    }

    test "addEntity" {
        var arch = try ArchetypeTable.initEmpty(allocator, NameAndID);
        defer arch.deinit(allocator);

        const index = try arch.addEntity(allocator, NameAndID.initRaw("test", 69));
        try testing.expectEqual(Name.init("test"), arch.getComponentPtrConst(index, Name).*);
        try testing.expectEqual(ID.init(69), arch.getComponentPtrConst(index, ID).*);

        const index2 = try arch.addEntity(allocator, NameAndID.initRaw("test2", 42));
        try testing.expectEqual(Name.init("test2"), arch.getComponentPtrConst(index2, Name).*);
        try testing.expectEqual(ID.init(42), arch.getComponentPtrConst(index2, ID).*);
    }

    test "setComponent" {
        var arch = try ArchetypeTable.initEmpty(allocator, NameAndID);
        defer arch.deinit(allocator);

        const capacity = 5;
        try arch.ensureTotalCapacity(allocator, capacity);
        _ = try arch.addEntity(allocator, NameAndID.initRaw("test", 69));

        arch.setComponent(0, Name.init("test name"));

        try testing.expectEqual(Name.init("test name"), arch.getComponentPtrConst(0, Name).*);
    }

    test "getComponentSlice" {
        var arch = try ArchetypeTable.initEmpty(allocator, NameAndID);
        defer arch.deinit(allocator);

        _ = try arch.addEntity(allocator, NameAndID.initRaw("test1", 69));
        _ = try arch.addEntity(allocator, NameAndID.initRaw("test2", 70));
        _ = try arch.addEntity(allocator, NameAndID.initRaw("test3", 71));

        const names = arch.getComponentSlice(Name);
        const ids = arch.getComponentSlice(ID);

        try testing.expectEqual(Name.init("test1"), names[0]);
        try testing.expectEqual(Name.init("test2"), names[1]);
        try testing.expectEqual(Name.init("test3"), names[2]);

        try testing.expectEqual(ID.init(69), ids[0]);
        try testing.expectEqual(ID.init(70), ids[1]);
        try testing.expectEqual(ID.init(71), ids[2]);

        try testing.expectEqual(3, names.len);
        try testing.expectEqual(3, ids.len);

        names[1] = Name.init("test4");
        try testing.expectEqual(Name.init("test4"), arch.getComponentPtrConst(1, Name).*);
    }

    test "getComponentSliceConst" {
        var arch = try ArchetypeTable.initEmpty(allocator, NameAndID);
        defer arch.deinit(allocator);

        _ = try arch.addEntity(allocator, NameAndID.initRaw("test1", 69));
        _ = try arch.addEntity(allocator, NameAndID.initRaw("test2", 70));
        _ = try arch.addEntity(allocator, NameAndID.initRaw("test3", 71));

        const names = arch.getComponentSliceConst(Name);
        const ids = arch.getComponentSliceConst(ID);

        try testing.expectEqual(Name.init("test1"), names[0]);
        try testing.expectEqual(Name.init("test2"), names[1]);
        try testing.expectEqual(Name.init("test3"), names[2]);

        try testing.expectEqual(ID.init(69), ids[0]);
        try testing.expectEqual(ID.init(70), ids[1]);
        try testing.expectEqual(ID.init(71), ids[2]);

        try testing.expectEqual(3, names.len);
        try testing.expectEqual(3, ids.len);
    }

    test "iterComponents" {
        var arch = try ArchetypeTable.initEmpty(allocator, NameAndID);
        defer arch.deinit(allocator);

        _ = try arch.addEntity(allocator, NameAndID.initRaw("test1", 69));
        _ = try arch.addEntity(allocator, NameAndID.initRaw("test2", 70));
        _ = try arch.addEntity(allocator, NameAndID.initRaw("test3", 71));

        var names = arch.iterComponents(Name);
        var ids = arch.iterComponents(ID);

        try testing.expectEqual(Name.init("test1"), names.next().?.*);
        try testing.expectEqual(Name.init("test2"), names.next().?.*);
        try testing.expectEqual(Name.init("test3"), names.next().?.*);
        try testing.expect(null == names.next());

        try testing.expectEqual(ID.init(69), ids.next().?.*);
        try testing.expectEqual(ID.init(70), ids.next().?.*);
        try testing.expectEqual(ID.init(71), ids.next().?.*);
        try testing.expect(null == ids.next());

        var names2 = arch.iterComponents(Name);
        _ = names2.next();
        names2.next().?.* = Name.init("test4");
        try testing.expectEqual(Name.init("test4"), arch.getComponentPtrConst(1, Name).*);
    }

    test "iterComponentsConst" {
        var arch = try ArchetypeTable.initEmpty(allocator, NameAndID);
        defer arch.deinit(allocator);

        _ = try arch.addEntity(allocator, NameAndID.initRaw("test1", 69));
        _ = try arch.addEntity(allocator, NameAndID.initRaw("test2", 70));
        _ = try arch.addEntity(allocator, NameAndID.initRaw("test3", 71));

        var names = arch.iterComponentsConst(Name);
        var ids = arch.iterComponentsConst(ID);

        try testing.expectEqual(Name.init("test1"), names.next().?.*);
        try testing.expectEqual(Name.init("test2"), names.next().?.*);
        try testing.expectEqual(Name.init("test3"), names.next().?.*);
        try testing.expect(null == names.next());

        try testing.expectEqual(ID.init(69), ids.next().?.*);
        try testing.expectEqual(ID.init(70), ids.next().?.*);
        try testing.expectEqual(ID.init(71), ids.next().?.*);
        try testing.expect(null == ids.next());
    }
};
