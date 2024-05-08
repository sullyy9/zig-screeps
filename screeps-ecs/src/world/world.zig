const std = @import("std");
const json = std.json;
const Tuple = std.meta.Tuple;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const StructField = std.builtin.Type.StructField;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const AutoHashMapUnmanaged = std.AutoHashMapUnmanaged;

const archetype = @import("archetype.zig");
const ArchetypeTable = archetype.ArchetypeTable;
const assertIsComponent = archetype.assertIsComponent;

pub const EntityID = struct {
    const Self = @This();

    id: usize,

    pub fn jsonStringify(self: *const Self, jw: anytype) !void {
        try jw.write(self.id);
    }

    pub fn jsonParse(
        allocator: Allocator,
        source: anytype,
        options: json.ParseOptions,
    ) json.ParseError(@TypeOf(source.*))!Self {
        var self: Self = undefined;

        self.id = try json.innerParse(
            @TypeOf(self.id),
            allocator,
            source,
            options,
        );

        return self;
    }
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

    pub fn jsonStringify(self: *const Self, jw: anytype) !void {
        try jw.beginObject();

        try jw.objectField("entity_count");
        try jw.write(self.entity_count);

        try jw.objectField("entities");
        try jw.beginArray();
        var entity_iter = self.entities.iterator();
        while (entity_iter.next()) |entry| {
            try jw.beginObject();
            try jw.objectField("id");
            try jw.write(entry.key_ptr);

            try jw.objectField("index");
            try jw.write(entry.value_ptr);
            try jw.endObject();
        }
        try jw.endArray();

        try jw.objectField("archetypes");
        try jw.write(self.archetypes);

        try jw.endObject();
    }

    pub fn jsonParse(
        allocator: Allocator,
        source: anytype,
        options: json.ParseOptions,
    ) json.ParseError(@TypeOf(source.*))!Self {
        var self = Self{
            .allocator = allocator,
            .entity_count = undefined,
            .entities = .{},
            .archetypes = undefined,
        };

        if (try source.next() != .object_begin) return error.UnexpectedToken;

        while (try source.peekNextTokenType() != .object_end) {
            const object_key = try json.innerParse(
                []const u8,
                allocator,
                source,
                options,
            );
            defer allocator.free(object_key);

            if (std.mem.eql(u8, object_key, "entity_count")) {
                self.entity_count = try json.innerParse(
                    @TypeOf(self.entity_count),
                    allocator,
                    source,
                    options,
                );
            } else if (std.mem.eql(u8, object_key, "entities")) {
                const entities = try json.innerParse(
                    []const struct { id: EntityID, index: EntityIdx },
                    allocator,
                    source,
                    options,
                );

                try self.entities.ensureTotalCapacity(allocator, @intCast(entities.len));
                for (entities) |entity| self.entities.putAssumeCapacity(entity.id, entity.index);
            } else if (std.mem.eql(u8, object_key, "archetypes")) {
                self.archetypes = try json.innerParse(
                    @TypeOf(self.archetypes),
                    allocator,
                    source,
                    options,
                );
            } else {
                return error.UnknownField;
            }
        }

        if (try source.next() != .object_end) return error.UnexpectedToken;

        return self;
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

    const components = @import("../testing/components.zig");
    const ID = components.ID;
    const Name = components.Name;
    const Funky = components.Funky;
    const NameAndID = components.NameAndID;
    const FunkyNameAndID = components.FunkyNameAndID;

    const NameSortCtx = struct {
        fn lessThan(_: void, lhs: Name, rhs: Name) bool {
            return Name.order(lhs, rhs) == .lt;
        }
    };

    const NameAndIDSortCtx = struct {
        fn lessThan(_: void, lhs: NameAndID, rhs: NameAndID) bool {
            return NameAndID.order(lhs, rhs) == .lt;
        }
    };

    test "newEntity" {
        var world = World.init(allocator);
        defer world.deinit();

        const entity_in = NameAndID.init(Name.init("test"), ID.init(69));
        const entity = try world.newEntity(entity_in);

        const entity_out = try world.getEntity(entity, NameAndID);
        try testing.expectEqual(entity_in, entity_out);

        const result = world.getEntity(entity, FunkyNameAndID);
        try testing.expectError(Error.ComponentMissing, result);
    }

    test "getComponent" {
        var world = World.init(allocator);
        defer world.deinit();

        const entity_in = NameAndID.init(Name.init("test"), ID.init(69));
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

        _ = try world.newEntity(NameAndID.init(names[0], ID.init(1)));
        _ = try world.newEntity(NameAndID.init(names[1], ID.init(2)));
        _ = try world.newEntity(NameAndID.init(names[2], ID.init(3)));
        _ = try world.newEntity(FunkyNameAndID.init(names[3], ID.init(4), Funky{ .in_a_good_way = 6 }));
        _ = try world.newEntity(FunkyNameAndID.init(names[4], ID.init(5), Funky{ .in_a_bad_way = 4 }));

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

        _ = try world.newEntity(NameAndID.init(names[0], ID.init(1)));
        _ = try world.newEntity(NameAndID.init(names[1], ID.init(2)));
        _ = try world.newEntity(NameAndID.init(names[2], ID.init(3)));
        _ = try world.newEntity(FunkyNameAndID.init(names[3], ID.init(4), Funky{ .in_a_good_way = 6 }));
        _ = try world.newEntity(FunkyNameAndID.init(names[4], ID.init(5), Funky{ .in_a_bad_way = 4 }));

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

        var entities = [_]NameAndID{
            NameAndID.initRaw("test1", 1),
            NameAndID.initRaw("test2", 2),
            NameAndID.initRaw("test3", 3),
            NameAndID.initRaw("test4", 4),
            NameAndID.initRaw("test5", 5),
        };

        _ = try world.newEntity(entities[0]);
        _ = try world.newEntity(entities[1]);
        _ = try world.newEntity(entities[2]);
        _ = try world.newEntity(FunkyNameAndID.init(entities[3].name, entities[3].id, Funky{ .in_a_good_way = 6 }));
        _ = try world.newEntity(FunkyNameAndID.init(entities[4].name, entities[4].id, Funky{ .in_a_bad_way = 4 }));

        var iter = world.iter(&.{ Name, ID });

        var collected = ArrayList(NameAndID).init(allocator);
        defer collected.deinit();
        while (iter.next()) |item| try collected.append(NameAndID.init(item[0].*, item[1].*));

        std.sort.insertion(NameAndID, &entities, {}, NameAndIDSortCtx.lessThan);
        std.sort.insertion(NameAndID, collected.items, {}, NameAndIDSortCtx.lessThan);

        try testing.expectEqualSlices(NameAndID, &entities, collected.items);
    }

    test "iterMut Multiple" {
        var world = World.init(allocator);
        defer world.deinit();

        var entities = [_]NameAndID{
            NameAndID.initRaw("test1", 1),
            NameAndID.initRaw("test2", 2),
            NameAndID.initRaw("test3", 3),
            NameAndID.initRaw("test4", 4),
            NameAndID.initRaw("test5", 5),
        };

        _ = try world.newEntity(entities[0]);
        _ = try world.newEntity(entities[1]);
        _ = try world.newEntity(entities[2]);
        _ = try world.newEntity(FunkyNameAndID.init(entities[3].name, entities[3].id, Funky{ .in_a_good_way = 6 }));
        _ = try world.newEntity(FunkyNameAndID.init(entities[4].name, entities[4].id, Funky{ .in_a_bad_way = 4 }));

        var iter = world.iterMut(&.{ Name, ID });
        while (iter.next()) |item| item[1].id += 10;
        for (&entities) |*item| item.id.id += 10;

        iter = world.iterMut(&.{ Name, ID });

        var collected = ArrayList(NameAndID).init(allocator);
        defer collected.deinit();
        while (iter.next()) |item| try collected.append(NameAndID.init(item[0].*, item[1].*));

        std.sort.insertion(NameAndID, &entities, {}, NameAndIDSortCtx.lessThan);
        std.sort.insertion(NameAndID, collected.items, {}, NameAndIDSortCtx.lessThan);

        try testing.expectEqualSlices(NameAndID, &entities, collected.items);
    }

    test "JSON serialization/deserialization" {
        var world = World.init(allocator);
        defer world.deinit();

        const entities = .{
            NameAndID.initRaw("test1", 1),
            NameAndID.initRaw("test2", 2),
            NameAndID.initRaw("test3", 3),
            FunkyNameAndID.init(Name.init("test4"), ID.init(4), Funky{ .in_a_good_way = 6 }),
            FunkyNameAndID.init(Name.init("test5"), ID.init(5), Funky{ .in_a_bad_way = 4 }),
        };

        var ids: [entities.len]EntityID = undefined;
        inline for (entities, 0..) |entity, i| ids[i] = try world.newEntity(entity);

        const data = try json.stringifyAlloc(allocator, world, .{ .whitespace = .indent_4 });
        defer allocator.free(data);

        const world_parsed = try json.parseFromSlice(World, allocator, data, .{});
        defer world_parsed.deinit();

        inline for (ids, entities) |id, entity| {
            const value = try world_parsed.value.getEntity(id, @TypeOf(entity));
            try testing.expectEqual(entity, value);
        }
    }
};
