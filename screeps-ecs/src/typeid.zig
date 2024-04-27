const std = @import("std");
const assert = std.debug.assert;
const StructField = std.builtin.Type.StructField;

fn structStringLen(comptime fields: []const StructField) usize {
    comptime var len = 0;

    inline for (fields) |field| {
        len += field.name.len;
        len += @typeName(field.type).len;
    }

    return len;
}

fn typeString(comptime T: type) []const u8 {
    switch (@typeInfo(T)) {
        .Struct => {
            const name_len = comptime structStringLen(std.meta.fields(T));

            var struct_name: [name_len]u8 = undefined;
            comptime var beg = 0;

            inline for (std.meta.fields(T)) |f| {
                const field: StructField = f;

                const field_name = field.name ++ @typeName(field.type);
                const end = beg + field_name.len;
                @memcpy(struct_name[beg..end], field_name);
                beg = end;
            }

            return &struct_name;
        },
        .Type,
        .Void,
        .Bool,
        .NoReturn,
        .Int,
        .Float,
        .Pointer,
        .Array,
        .ComptimeFloat,
        .ComptimeInt,
        .Undefined,
        .Null,
        .Optional,
        .ErrorUnion,
        .ErrorSet,
        .Fn,
        => return @typeName(T),
        else => @compileError("Unsuported type!"),
    }
}

/// Return a unique ID for a given type.
///
/// Two structs are considered unique if any of their fields differ in name or type.
pub fn typeID(comptime T: type) usize {
    switch (comptime @sizeOf(usize)) {
        4 => return comptime std.hash.Fnv1a_32.hash(typeString(T)),
        8 => return comptime std.hash.Fnv1a_64.hash(typeString(T)),
        16 => return comptime std.hash.Fnv1a_128.hash(typeString(T)),
        else => @compileError("Size of usize not supported!"),
    }
}

test "typeID" {
    const testing = std.testing;
    
    const TestStruct = struct {
        thingy: usize,
    };

    const TestStruct2 = struct {
        smol_thingy: u8,
    };

    const TestStruct3 = struct {
        thingy: usize,
    };

    const Alias = u64;

    try testing.expect(typeID(u8) == typeID(u8));
    try testing.expect(typeID(usize) != typeID(u8));
    try testing.expect(typeID(TestStruct) == typeID(TestStruct));
    try testing.expect(typeID(TestStruct) != typeID(TestStruct2));
    try testing.expect(typeID(TestStruct) == typeID(TestStruct3));
    try testing.expect(typeID(Alias) == typeID(u64));
}
