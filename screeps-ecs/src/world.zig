const std = @import("std");
const assert = std.debug.assert;
const Tuple = std.meta.Tuple;
const Allocator = std.mem.Allocator;
const StructField = std.builtin.Type.StructField;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const AutoHashMapUnmanaged = std.AutoHashMapUnmanaged;

const archetype = @import("archetype.zig");
const ArchetypeTable = archetype.ArchetypeTable;
const assertIsComponent = archetype.assertIsComponent;

const query = @import("query.zig");
const Query = query.Query;

pub const EntityID = struct {
    id: usize,
};

pub const EntityIdx = struct {
    table: usize,
    row: usize,
};

const Error = error{
    EntityInvalid,
    ComponentMissing,
};

pub const World = struct {
    const Self = @This();

    allocator: Allocator,

    entity_count: usize,
    entities: AutoHashMapUnmanaged(EntityID, EntityIdx),
    archetypes: ArrayListUnmanaged(ArchetypeTable),

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .entity_count = 0,
            .entities = .{},
            .archetypes = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.archetypes.items) |*table| {
            table.deinit(self.allocator);
        }

        self.entities.deinit(self.allocator);
        self.archetypes.deinit(self.allocator);
    }

    pub fn newEntity(self: *Self, entity: anytype) Allocator.Error!EntityID {
        const Arch: type = @TypeOf(entity);
        const table: *ArchetypeTable, const index: usize = self.findTableMut(Arch) orelse try self.createTable(Arch);

        const row_index = try table.insertRow(self.allocator, entity);

        const entity_index = EntityIdx{
            .table = index,
            .row = row_index,
        };
        const entity_id = self.nextEntityID();

        try self.entities.put(self.allocator, entity_id, entity_index);
        return entity_id;
    }

    /// Return a copy of an entity given it's ID.
    pub fn getEntity(self: *const Self, id: EntityID, comptime Archetype: type) Error!Archetype {
        assert(@typeInfo(Archetype) == .Struct);

        // Find the entities archetype table.
        const index = self.entities.get(id) orelse return Error.EntityInvalid;
        assert(index.table < self.archetypes.items.len);
        const table = self.archetypes.items[index.table];

        if (!table.hasComponentsOf(Archetype)) {
            return Error.ComponentMissing;
        }

        // Build a copy of the entity.
        var entity: Archetype = undefined;
        inline for (std.meta.fields(Archetype)) |f| {
            const field: StructField = f;
            @field(entity, field.name) = table.getComponent(index.row, field.type).*;
        }

        return entity;
    }

    /// Return an immutable pointer to the given component of an entity.
    pub fn getComponent(self: *const Self, id: EntityID, comptime Component: type) Error!*const Component {
        // Find the entities archetype table.
        const index = self.entities.get(id) orelse return Error.EntityInvalid;
        assert(index.table < self.archetypes.items.len);
        const table = self.archetypes.items[index.table];

        if (!table.hasComponent(Component)) {
            return Error.ComponentMissing;
        }

        return table.getComponent(index.row, Component);
    }

    /// Return an mutable pointer to the given component of an entity.
    pub fn getComponentMut(self: *Self, id: EntityID, comptime Component: type) Error!*Component {
        // Find the entities archetype table.
        const index = self.entities.get(id) orelse return Error.EntityInvalid;
        assert(index.table < self.archetypes.items.len);
        const table = &self.archetypes.items[index.table];

        if (!table.hasComponent(Component)) {
            return Error.ComponentMissing;
        }

        return table.getComponentMut(index.row, Component);
    }

    pub fn iter(self: *const Self, comptime Components: []const type) ComponentIter(Components) {
        inline for (Components) |Component| {
            comptime assertIsComponent(Component);
        }

        return ComponentIter(Components).init(self.archetypes.items);
    }

    pub fn iterMut(self: *const Self, comptime Components: []const type) ComponentIterMut(Components) {
        inline for (Components) |Component| {
            comptime assertIsComponent(Component);
        }

        return ComponentIterMut(Components).init(self.archetypes.items);
    }

    fn nextEntityID(self: *Self) EntityID {
        const id = EntityID{ .id = self.entity_count };
        self.entity_count += 1;
        return id;
    }

    fn createTable(self: *Self, comptime Archetype: type) Allocator.Error!Tuple(&.{ *ArchetypeTable, usize }) {
        const table = try ArchetypeTable.initEmpty(self.allocator, Archetype);

        const index = self.archetypes.items.len;
        try self.archetypes.append(self.allocator, table);
        return .{ &self.archetypes.items[index], index };
    }

    fn getTable(self: *const Self, id: EntityID) ?*const ArchetypeTable {
        const index = try self.entities.get(id);
        assert(index.table < self.archetypes.items.len);
        return &self.archetypes.items[index.table];
    }

    fn findTable(self: *const Self, comptime Archetype: type) ?Tuple(&.{ *const ArchetypeTable, usize }) {
        for (self.archetypes.items, 0..) |*table, i| {
            if (table.hasComponentsOf(Archetype)) {
                return .{ table, i };
            }
        }

        return null;
    }

    fn findTableMut(self: *Self, comptime Archetype: type) ?Tuple(&.{ *ArchetypeTable, usize }) {
        for (self.archetypes.items, 0..) |*table, i| {
            if (table.hasComponentsOf(Archetype)) {
                return .{ table, i };
            }
        }

        return null;
    }
};

pub fn ComponentIter(comptime Components: []const type) type {
    comptime var Slices: [Components.len]type = undefined;
    comptime var Pointers: [Components.len]type = undefined;

    inline for (Components, 0..) |Component, i| {
        assertIsComponent(Component);

        Slices[i] = []const Component;
        Pointers[i] = *const Component;
    }

    const ComponentSlices = Slices;
    const ComponentPointers = Pointers;

    const NextComponent = if (ComponentPointers.len == 1) brk: {
        break :brk ComponentPointers[0];
    } else brk: {
        break :brk Tuple(&ComponentPointers);
    };

    return struct {
        const Self = @This();

        table: isize,
        tables: []const ArchetypeTable,

        row: usize,
        columns: Tuple(&ComponentSlices),

        pub fn init(tables: []const ArchetypeTable) Self {
            var columns: Tuple(&ComponentSlices) = undefined;
            inline for (0..columns.len) |i| {
                columns[i] = &.{};
            }

            return Self{
                .table = -1,
                .row = 0,
                .tables = tables,
                .columns = columns,
            };
        }

        pub fn next(self: *Self) ?NextComponent {
            if (self.row < self.columns[0].len) {
                var components: Tuple(&ComponentPointers) = undefined;
                inline for (0..self.columns.len) |i| {
                    components[i] = &self.columns[i][self.row];
                }
                self.row += 1;

                return if (components.len == 1) components[0] else components;
            }

            // If we've exhausted this table, move to the next one that isn't empty and contains
            // the component.
            while (true) {
                self.table += 1;
                if (self.table >= self.tables.len) {
                    return null;
                }

                const table = self.tables[@intCast(self.table)];
                if (table.hasComponentsOf(Tuple(Components)) and table.rows() > 0) {
                    break;
                }
            }

            // Build the tuple of component columns from the next table.
            self.row = 1;
            inline for (Components, 0..) |Component, i| {
                self.columns[i] = self.tables[@intCast(self.table)].getComponentSlice(Component);
            }

            // Construct the return value.
            var components: Tuple(&ComponentPointers) = undefined;
            inline for (0..self.columns.len) |i| {
                components[i] = &self.columns[i][0];
            }
            return if (components.len == 1) components[0] else components;
        }
    };
}

pub fn ComponentIterMut(comptime Components: []const type) type {
    comptime var Slices: [Components.len]type = undefined;
    comptime var Pointers: [Components.len]type = undefined;

    inline for (Components, 0..) |Component, i| {
        assertIsComponent(Component);

        Slices[i] = []Component;
        Pointers[i] = *Component;
    }

    const ComponentSlices = Slices;
    const ComponentPointers = Pointers;

    const NextComponent = if (ComponentPointers.len == 1) brk: {
        break :brk ComponentPointers[0];
    } else brk: {
        break :brk Tuple(&ComponentPointers);
    };

    return struct {
        const Self = @This();

        table: isize,
        tables: []ArchetypeTable,

        row: usize,
        columns: Tuple(&ComponentSlices),

        pub fn init(tables: []ArchetypeTable) Self {
            var columns: Tuple(&ComponentSlices) = undefined;
            inline for (0..columns.len) |i| {
                columns[i] = &.{};
            }

            return Self{
                .table = -1,
                .row = 0,
                .tables = tables,
                .columns = columns,
            };
        }

        pub fn next(self: *Self) ?NextComponent {
            if (self.row < self.columns[0].len) {
                var components: Tuple(&ComponentPointers) = undefined;
                inline for (0..self.columns.len) |i| {
                    components[i] = &self.columns[i][self.row];
                }

                self.row += 1;

                return if (components.len == 1) components[0] else components;
            }

            // If we've exhausted this table, move to the next one that isn't empty and contains
            // the component.
            while (true) {
                self.table += 1;
                if (self.table >= self.tables.len) {
                    return null;
                }

                const table = self.tables[@intCast(self.table)];
                if (table.hasComponentsOf(Tuple(Components)) and table.rows() > 0) {
                    break;
                }
            }

            // Build the tuple of component columns from the next table.
            self.row = 1;
            inline for (Components, 0..) |Component, i| {
                self.columns[i] = self.tables[@intCast(self.table)].getComponentSliceMut(Component);
            }

            // Construct the return value.
            var components: Tuple(&ComponentPointers) = undefined;
            inline for (0..self.columns.len) |i| {
                components[i] = &self.columns[i][0];
            }
            return if (components.len == 1) components[0] else components;
        }
    };
}

pub const Test = struct {
    const testing = std.testing;
    const allocator = std.testing.allocator;

    const ArrayList = std.ArrayList;

    const Name = struct {
        const Self = @This();

        name: []const u8,

        pub fn init(name: []const u8) Self {
            return Self{ .name = name };
        }

        pub fn order(lhs: Self, rhs: Self) std.math.Order {
            return std.mem.order(u8, lhs.name, rhs.name);
        }
    };

    const ID = struct {
        const Self = @This();

        big_id: u64,
        smol_id: u8,

        pub fn init(big: u64, smol: u8) Self {
            return Self{ .big_id = big, .smol_id = smol };
        }

        pub fn order(lhs: Self, rhs: Self) std.math.Order {
            switch (std.math.order(lhs.big_id, rhs.big_id)) {
                .eq => return std.math.order(lhs.smol_id, rhs.smol_id),
                .gt => return .gt,
                .lt => return .lt,
            }
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

        pub fn order(lhs: Self, rhs: Self) std.math.Order {
            switch (ID.order(lhs.id, rhs.id)) {
                .eq => return Name.order(lhs.name, rhs.name),
                .gt => return .gt,
                .lt => return .lt,
            }
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

    const NameSortCtx = struct {
        fn lessThan(_: void, lhs: Name, rhs: Name) bool {
            return Name.order(lhs, rhs) == .lt;
        }
    };

    test "newEntity" {
        var world = World.init(allocator);
        defer world.deinit();

        const entity_in = NameAndID.init(Name.init("test"), ID.init(69, 42));
        const entity = try world.newEntity(entity_in);

        const entity_out = try world.getEntity(entity, NameAndID);
        try testing.expectEqual(entity_in, entity_out);

        const result = world.getEntity(entity, FunkyNameAndID);
        try testing.expectError(Error.ComponentMissing, result);
    }

    test "getComponent" {
        var world = World.init(allocator);
        defer world.deinit();

        const entity_in = NameAndID.init(Name.init("test"), ID.init(69, 42));
        const entity = try world.newEntity(entity_in);

        const name = try world.getComponent(entity, Name);
        try testing.expectEqual(entity_in.name, name.*);

        const name_mut = try world.getComponentMut(entity, Name);
        name_mut.* = Name.init("mutated");

        const mutated_name = try world.getComponent(entity, Name);
        try testing.expectEqual(Name.init("mutated"), mutated_name.*);
    }

    test "iter" {
        var world = World.init(allocator);
        defer world.deinit();

        var names = [_]Name{
            Name.init("test1"),
            Name.init("test2"),
            Name.init("test3"),
            Name.init("test4"),
            Name.init("test5"),
        };

        _ = try world.newEntity(NameAndID.init(names[0], ID.init(69, 42)));
        _ = try world.newEntity(NameAndID.init(names[1], ID.init(70, 43)));
        _ = try world.newEntity(NameAndID.init(names[2], ID.init(71, 44)));
        _ = try world.newEntity(FunkyNameAndID.init(names[3], ID.init(69, 42), Funky.initInAGoodWay()));
        _ = try world.newEntity(FunkyNameAndID.init(names[4], ID.init(70, 43), Funky.initInABadWay()));

        var iter = world.iter(&.{Name});

        var collected = ArrayList(Name).init(allocator);
        defer collected.deinit();
        while (iter.next()) |name| try collected.append(name.*);

        std.sort.insertion(Name, &names, {}, NameSortCtx.lessThan);
        std.sort.insertion(Name, collected.items, {}, NameSortCtx.lessThan);

        try testing.expectEqualSlices(Name, &names, collected.items);
    }

    test "iterMut" {
        var world = World.init(allocator);
        defer world.deinit();

        var names = [_]Name{
            Name.init("test1"),
            Name.init("test2"),
            Name.init("test3"),
            Name.init("test4"),
            Name.init("test5"),
        };

        _ = try world.newEntity(NameAndID.init(names[0], ID.init(69, 42)));
        _ = try world.newEntity(NameAndID.init(names[1], ID.init(70, 43)));
        _ = try world.newEntity(NameAndID.init(names[2], ID.init(71, 44)));
        _ = try world.newEntity(FunkyNameAndID.init(names[3], ID.init(69, 42), Funky.initInAGoodWay()));
        _ = try world.newEntity(FunkyNameAndID.init(names[4], ID.init(70, 43), Funky.initInABadWay()));

        var iter = world.iterMut(&.{Name});

        var collected = ArrayList(Name).init(allocator);
        defer collected.deinit();
        while (iter.next()) |name| try collected.append(name.*);

        std.sort.insertion(Name, &names, {}, NameSortCtx.lessThan);
        std.sort.insertion(Name, collected.items, {}, NameSortCtx.lessThan);

        try testing.expectEqualSlices(Name, &names, collected.items);
    }

    test "iter Multiple" {
        var world = World.init(allocator);
        defer world.deinit();

        const names_and_ids: [5]Tuple(&.{ Name, ID }) = .{
            .{ Name.init("test1"), ID.init(69, 42) },
            .{ Name.init("test2"), ID.init(70, 43) },
            .{ Name.init("test3"), ID.init(71, 44) },
            .{ Name.init("test4"), ID.init(69, 42) },
            .{ Name.init("test5"), ID.init(70, 43) },
        };

        _ = try world.newEntity(NameAndID.init(names_and_ids[0][0], names_and_ids[0][1]));
        _ = try world.newEntity(NameAndID.init(names_and_ids[1][0], names_and_ids[1][1]));
        _ = try world.newEntity(NameAndID.init(names_and_ids[2][0], names_and_ids[2][1]));
        _ = try world.newEntity(FunkyNameAndID.init(names_and_ids[3][0], names_and_ids[3][1], Funky.initInAGoodWay()));
        _ = try world.newEntity(FunkyNameAndID.init(names_and_ids[4][0], names_and_ids[4][1], Funky.initInABadWay()));

        var name_iter = world.iter(&.{ Name, ID });

        var seen: [names_and_ids.len]bool = undefined;
        @memset(&seen, false);

        while (name_iter.next()) |next| {
            const name, const id = next;

            for (names_and_ids, 0..) |expected, i| {
                const expected_name, const expected_id = expected;

                if (std.meta.eql(name.*, expected_name) and std.meta.eql(id.*, expected_id)) {
                    try testing.expect(seen[i] == false);
                    seen[i] = true;
                    break;
                }
            }
        }

        try testing.expect(std.mem.allEqual(bool, &seen, true));
    }

    test "iterMut Multiple" {
        var world = World.init(allocator);
        defer world.deinit();

        const names_and_ids: [5]Tuple(&.{ Name, ID }) = .{
            .{ Name.init("test1"), ID.init(69, 42) },
            .{ Name.init("test2"), ID.init(70, 43) },
            .{ Name.init("test3"), ID.init(71, 44) },
            .{ Name.init("test4"), ID.init(69, 42) },
            .{ Name.init("test5"), ID.init(70, 43) },
        };

        _ = try world.newEntity(NameAndID.init(names_and_ids[0][0], names_and_ids[0][1]));
        _ = try world.newEntity(NameAndID.init(names_and_ids[1][0], names_and_ids[1][1]));
        _ = try world.newEntity(NameAndID.init(names_and_ids[2][0], names_and_ids[2][1]));
        _ = try world.newEntity(FunkyNameAndID.init(names_and_ids[3][0], names_and_ids[3][1], Funky.initInAGoodWay()));
        _ = try world.newEntity(FunkyNameAndID.init(names_and_ids[4][0], names_and_ids[4][1], Funky.initInABadWay()));

        var name_iter = world.iterMut(&.{ Name, ID });

        var seen: [names_and_ids.len]bool = undefined;
        @memset(&seen, false);

        while (name_iter.next()) |next| {
            const name, const id = next;

            for (names_and_ids, 0..) |expected, i| {
                const expected_name, const expected_id = expected;

                if (std.meta.eql(name.*, expected_name) and std.meta.eql(id.*, expected_id)) {
                    try testing.expect(seen[i] == false);
                    seen[i] = true;
                    break;
                }
            }
        }
        try testing.expect(std.mem.allEqual(bool, &seen, true));
    }

    test "iterMut Mutation" {
        var world = World.init(allocator);
        defer world.deinit();

        var names_and_ids: [5]Tuple(&.{ Name, ID }) = .{
            .{ Name.init("test1"), ID.init(69, 42) },
            .{ Name.init("test2"), ID.init(70, 43) },
            .{ Name.init("test3"), ID.init(71, 44) },
            .{ Name.init("test4"), ID.init(69, 42) },
            .{ Name.init("test5"), ID.init(70, 43) },
        };

        _ = try world.newEntity(NameAndID.init(names_and_ids[0][0], names_and_ids[0][1]));
        _ = try world.newEntity(NameAndID.init(names_and_ids[1][0], names_and_ids[1][1]));
        _ = try world.newEntity(NameAndID.init(names_and_ids[2][0], names_and_ids[2][1]));
        _ = try world.newEntity(FunkyNameAndID.init(names_and_ids[3][0], names_and_ids[3][1], Funky.initInAGoodWay()));
        _ = try world.newEntity(FunkyNameAndID.init(names_and_ids[4][0], names_and_ids[4][1], Funky.initInABadWay()));

        var iter = world.iterMut(&.{ Name, ID });
        while (iter.next()) |next| {
            _, const id = next;
            id.big_id += 10;
        }

        for (&names_and_ids) |*item| {
            const id = &item[1];
            id.big_id += 10;
        }

        var seen: [names_and_ids.len]bool = undefined;
        @memset(&seen, false);

        iter = world.iterMut(&.{ Name, ID });
        while (iter.next()) |next| {
            const name, const id = next;

            for (names_and_ids, 0..) |expected, i| {
                const expected_name, const expected_id = expected;

                if (std.meta.eql(name.*, expected_name) and std.meta.eql(id.*, expected_id)) {
                    try testing.expect(seen[i] == false);
                    seen[i] = true;
                    break;
                }
            }
        }
        try testing.expect(std.mem.allEqual(bool, &seen, true));
    }
};
