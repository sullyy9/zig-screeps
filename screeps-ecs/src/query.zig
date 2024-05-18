const std = @import("std");
const Tuple = std.meta.Tuple;
const assert = std.debug.assert;

const world_module = @import("world/mod.zig");
const World = world_module.World;
const ArchetypeTable = world_module.ArchetypeTable;
const assertIsComponent = world_module.assertIsComponent;

pub const Error = error{
    invalid_type,
    not_tagged,
};

pub fn requireIsQuery(comptime T: type) Error!void {
    switch (@typeInfo(T)) {
        .Struct, .Union, .Enum => {},
        else => return Error.invalid_type,
    }

    if (!@hasDecl(T, "querytag")) return Error.not_tagged;
}

pub fn isQuery(comptime T: type) bool {
    requireIsQuery(T) catch return false;
    return true;
}

pub fn assertIsQuery(comptime T: type) void {
    requireIsQuery(T) catch |err| switch (err) {
        Error.invalid_type => @compileError(std.fmt.comptimePrint(
            "Type '{}' does not fullfill the requirements of Query. " ++
                "Queries must be of type struct, enum or union. " ++
                "Type is '{}'",
            .{ T, @tagName(@typeInfo(T)) },
        )),

        Error.not_tagged => @compileError(std.fmt.comptimePrint(
            "Type '{}' does not fullfill the requirements of Query. " ++
                "Queries must be contain the declaration 'querytag'. " ++
                "Type does not contain the declaration 'querytag'",
            .{T},
        )),
    };
}

/// Assert that a type is a valid Query Data type.
/// Must be a pointer to a component or a tuple of pointers to components
fn assertIsQueryData(comptime Data: type) void {
    comptime switch (@typeInfo(Data)) {
        .Pointer => |T| assertIsComponent(T.child),
        else => @compileError(std.fmt.comptimePrint(
            "Type '{}' does not fullfill the requirements of Data. " ++
                "Data must be a tuple of Component pointers. " ++
                "Type is of type '{s}'",
            .{ Data, @tagName(@typeInfo(Data)) },
        )),
    };
}

fn assertIsQueryFilter(comptime Filter: type) void {
    _ = Filter;
}

/// Return the number of mutable pointer types in a slice of types.
fn countMutablePointers(comptime Ts: []const type) usize {
    comptime var count = 0;
    inline for (Ts) |T| {
        if (@typeInfo(T) == .Pointer and !@typeInfo(T).Pointer.is_const) {
            count += 1;
        }
    }
    return count;
}

/// Return the number of mutable pointer types in a slice of types.
fn countImmutablePointers(comptime Ts: []const type) usize {
    comptime var count = 0;
    inline for (Ts) |T| {
        if (@typeInfo(T) == .Pointer and @typeInfo(T).Pointer.is_const) {
            count += 1;
        }
    }
    return count;
}

/// Split a slice of pointer types into and array of mutable pointers and an array of immutable
/// pointers.
fn splitPointersMutability(comptime Ts: []const type) Tuple(&.{ [countMutablePointers(Ts)]type, [countImmutablePointers(Ts)]type }) {
    comptime var mutable: [countMutablePointers(Ts)]type = undefined;
    comptime var immutable: [countImmutablePointers(Ts)]type = undefined;

    comptime var mutable_count = 0;
    comptime var immutable_count = 0;

    inline for (Ts) |T| {
        assert(@typeInfo(T) == .Pointer);

        if (@typeInfo(T).Pointer.is_const) {
            immutable[immutable_count] = T;
            immutable_count += 1;
        } else {
            mutable[mutable_count] = T;
            mutable_count += 1;
        }
    }

    return .{ mutable, immutable };
}

/// Map each pointer in a slice to it's child type.
fn mapPointersToChildTypes(comptime Ts: []const type) [Ts.len]type {
    comptime var Us: [Ts.len]type = undefined;

    inline for (Ts, 0..) |T, i| {
        assert(@typeInfo(T) == .Pointer);
        Us[i] = @typeInfo(T).Pointer.child;
    }

    return Us;
}

/// Map each type in a slice to mutable slices of that type.
fn mapTypesToMutableSlices(comptime Ts: []const type) [Ts.len]type {
    comptime var Us: [Ts.len]type = undefined;

    inline for (Ts, 0..) |T, i| {
        Us[i] = []T;
    }

    return Us;
}

/// Map each type in a slice to immutable slices of that type.
fn mapTypesToImmutableSlices(comptime Ts: []const type) [Ts.len]type {
    comptime var Us: [Ts.len]type = undefined;

    inline for (Ts, 0..) |T, i| {
        Us[i] = []const T;
    }

    return Us;
}

/// Generator for querying World components.
///
/// Parameters
/// ----------
/// data: Slice of pointers to .
/// Filter: Todo.
///
pub fn Query(comptime data: []const type, comptime Filter: type) type {
    inline for (data) |Data| comptime assertIsQueryData(Data);
    comptime assertIsQueryFilter(Filter);

    return struct {
        const Self = @This();

        const querytag = {};

        world: *World,

        pub fn init(world: *World) Self {
            return Self{
                .world = world,
            };
        }

        pub fn iterMut(self: *const Self) IterMut(data, Filter) {
            return IterMut(data, Filter).init(self.world);
        }
    };
}

pub fn IterMut(comptime data: []const type, comptime Filter: type) type {
    inline for (data) |Data| comptime assertIsQueryData(Data);
    comptime assertIsQueryFilter(Filter);

    const ColumnIndex = union(enum) {
        mutable: usize,
        immutable: usize,
    };

    // Maps a data index to an index into either the current immutable or mutable column.
    comptime var data_column_lut_builder: [data.len]ColumnIndex = undefined;

    comptime var mutable_count = 0;
    comptime var immutable_count = 0;
    inline for (data, 0..) |Data, i| {
        if (@typeInfo(Data).Pointer.is_const) {
            data_column_lut_builder[i] = ColumnIndex{ .immutable = immutable_count };
            immutable_count += 1;
        } else {
            data_column_lut_builder[i] = ColumnIndex{ .mutable = mutable_count };
            mutable_count += 1;
        }
    }

    const data_column_lut = data_column_lut_builder;

    const mutable_component_pointers, const immutable_component_pointers = splitPointersMutability(data);

    const mutable_components = mapPointersToChildTypes(&mutable_component_pointers);
    const immutable_components = mapPointersToChildTypes(&immutable_component_pointers);
    const all_components = mutable_components ++ immutable_components;

    const MutableComponentSlices: type = Tuple(&mapTypesToMutableSlices(&mutable_components));
    const ImmutableComponentSlices: type = Tuple(&mapTypesToImmutableSlices(&immutable_components));

    return struct {
        const Self = @This();
        const Item: type = Tuple(data);

        table: isize,
        row: usize,

        tables: []ArchetypeTable,

        // Component columns of the current table.
        columns: ImmutableComponentSlices,
        columns_mut: MutableComponentSlices,

        pub fn init(world: *World) Self {
            var columns: ImmutableComponentSlices = undefined;
            var columns_mut: MutableComponentSlices = undefined;

            inline for (0..columns.len) |i| columns[i] = &.{};
            inline for (0..columns_mut.len) |i| columns_mut[i] = &.{};

            return Self{
                .table = -1,
                .row = 0,
                .tables = world.archetypes.items,

                .columns = columns,
                .columns_mut = columns_mut,
            };
        }

        pub fn next(self: *Self) ?Item {
            const current_row_len = if (self.columns.len != 0) brk: {
                break :brk self.columns[0].len;
            } else brk: {
                break :brk self.columns_mut[0].len;
            };

            if (self.row < current_row_len) {
                var next_components: Item = undefined;
                inline for (0..next_components.len) |i| {
                    switch (data_column_lut[i]) {
                        .immutable => |j| next_components[i] = &self.columns[j][self.row],
                        .mutable => |j| next_components[i] = &self.columns_mut[j][self.row],
                    }
                }

                self.row += 1;
                return next_components;
            }

            // If we've exhausted this table, move to the next one that isn't empty and contains
            // the component.
            self.table = self.nextTableIndex() orelse return null;
            self.row = 1;

            inline for (immutable_components, 0..) |Component, i| {
                self.columns[i] = self.tables[@intCast(self.table)].getComponentSliceConst(Component);
            }

            inline for (mutable_components, 0..) |Component, i| {
                self.columns_mut[i] = self.tables[@intCast(self.table)].getComponentSlice(Component);
            }

            var next_components: Item = undefined;
            inline for (0..next_components.len) |i| {
                switch (data_column_lut[i]) {
                    .immutable => |j| next_components[i] = &self.columns[j][0],
                    .mutable => |j| next_components[i] = &self.columns_mut[j][0],
                }
            }
            return next_components;
        }

        fn nextTableIndex(self: *const Self) ?isize {
            const next_table: usize = @intCast(self.table + 1);

            for (self.tables[next_table..], next_table..) |table, i| {
                const has_components = table.hasComponentsOf(Tuple(&all_components));
                const not_empty = table.rows() > 0;

                if (has_components and not_empty) return @intCast(i);
            }

            return null;
        }
    };
}

pub const Test = struct {
    const testing = std.testing;
    const ArrayList = std.ArrayList;
    const allocator = std.testing.allocator;

    const components = @import("testing/mod.zig");
    const ID = components.ID;
    const Name = components.Name;
    const Funky = components.Funky;
    const NameAndID = components.NameAndID;
    const FunkyNameAndID = components.FunkyNameAndID;

    const NameAndIDSortCtx = struct {
        fn lessThan(_: void, lhs: NameAndID, rhs: NameAndID) bool {
            return NameAndID.order(lhs, rhs) == .lt;
        }
    };

    test "Query" {
        var world = World.init(allocator);
        defer world.deinit();

        var entities = [_]NameAndID{
            NameAndID.initRaw("test1", 1),
            NameAndID.initRaw("test2", 2),
            NameAndID.initRaw("test3", 3),
            NameAndID.initRaw("test4", 4),
            NameAndID.initRaw("test5", 5),
        };

        _ = try world.addEntity(entities[0]);
        _ = try world.addEntity(entities[1]);
        _ = try world.addEntity(entities[2]);
        _ = try world.addEntity(FunkyNameAndID.fromNameAndID(entities[3], Funky{ .in_a_good_way = 6 }));
        _ = try world.addEntity(FunkyNameAndID.fromNameAndID(entities[4], Funky{ .in_a_bad_way = 4 }));

        var query = Query(&.{ *const Name, *const ID }, void).init(&world);

        var collected = ArrayList(NameAndID).init(allocator);
        defer collected.deinit();
        var iter = query.iterMut();
        while (iter.next()) |item| try collected.append(NameAndID.init(item[0].*, item[1].*));

        std.sort.insertion(NameAndID, &entities, {}, NameAndIDSortCtx.lessThan);
        std.sort.insertion(NameAndID, collected.items, {}, NameAndIDSortCtx.lessThan);

        try testing.expectEqualSlices(NameAndID, &entities, collected.items);
    }

    test "Query Mutation" {
        var world = World.init(allocator);
        defer world.deinit();

        var entities = [_]NameAndID{
            NameAndID.initRaw("test1", 1),
            NameAndID.initRaw("test2", 2),
            NameAndID.initRaw("test3", 3),
            NameAndID.initRaw("test4", 4),
            NameAndID.initRaw("test5", 5),
        };

        _ = try world.addEntity(entities[0]);
        _ = try world.addEntity(entities[1]);
        _ = try world.addEntity(entities[2]);
        _ = try world.addEntity(FunkyNameAndID.fromNameAndID(entities[3], Funky{ .in_a_good_way = 6 }));
        _ = try world.addEntity(FunkyNameAndID.fromNameAndID(entities[4], Funky{ .in_a_bad_way = 4 }));

        var query = Query(&.{ *const Name, *ID }, void).init(&world);
        var iter = query.iterMut();
        while (iter.next()) |item| item[1].id += 10;
        for (&entities) |*ent| ent.id.id += 10;

        query = Query(&.{ *const Name, *ID }, void).init(&world);

        var collected = ArrayList(NameAndID).init(allocator);
        defer collected.deinit();

        iter = query.iterMut();
        while (iter.next()) |item| try collected.append(NameAndID.init(item[0].*, item[1].*));

        std.sort.insertion(NameAndID, &entities, {}, NameAndIDSortCtx.lessThan);
        std.sort.insertion(NameAndID, collected.items, {}, NameAndIDSortCtx.lessThan);

        try testing.expectEqualSlices(NameAndID, &entities, collected.items);
    }
};
