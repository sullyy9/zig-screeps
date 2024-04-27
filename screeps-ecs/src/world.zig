const std = @import("std");
const assert = std.debug.assert;
const Tuple = std.meta.Tuple;
const Allocator = std.mem.Allocator;
const StructField = std.builtin.Type.StructField;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const AutoHashMapUnmanaged = std.AutoHashMapUnmanaged;

const archetype = @import("archetype.zig");
const ArchetypeTable = archetype.ArchetypeTable;

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
};
