const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Union = std.builtin.Type.Union;
const Struct = std.builtin.Type.Struct;
const Optional = std.builtin.Type.Optional;
const StructField = std.builtin.Type.StructField;

pub const Error = error{
    invalid_type,
    contains_invalid_type,
};

fn isValidType(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .Struct => |info| isValidStruct(info),
        .Union => |info| isValidUnion(info),
        .Optional => |info| isValidType(info.child),
        .ErrorUnion => |info| isValidType(info.payload),
        .Array => |info| isValidType(info.child),

        .Type,
        .Void,
        .NoReturn,
        .ComptimeFloat,
        .ComptimeInt,
        .Undefined,
        .Null,
        .Fn,
        .Frame,
        .AnyFrame,
        .Vector,
        => false,

        else => true,
    };
}

fn isValidStruct(comptime info: Struct) bool {
    inline for (info.fields) |field| if (!isValidType(field.type)) return false;
    return true;
}

fn isValidUnion(comptime info: Union) bool {
    inline for (info.fields) |field| if (!isValidType(field.type)) return false;
    return true;
}

/// Check if a type fullfills the requirements of `Component`.
///
/// Returns
/// -------
/// Reason the type doesn't fullfill the requirements.
///
pub fn requireIsComponent(comptime T: type) Error!void {
    return switch (@typeInfo(T)) {
        .Struct,
        .Union,
        .Optional,
        .ErrorUnion,
        .Array,
        => if (!isValidType(T)) Error.contains_invalid_type else {},

        .Type,
        .Void,
        .NoReturn,
        .ComptimeFloat,
        .ComptimeInt,
        .Undefined,
        .Null,
        .Fn,
        .Frame,
        .AnyFrame,
        .Vector,
        => Error.invalid_type,

        else => {},
    };
}

/// Determine if a type fullfills the requirements of `Component`.
pub fn isComponent(comptime T: type) bool {
    requireIsComponent(T) catch return false;
    return true;
}

/// Assert that a type fullfills the requirements of `Component`.
pub fn assertIsComponent(comptime T: type) void {
    requireIsComponent(T) catch |err| switch (err) {
        Error.invalid_type => @compileError(std.fmt.comptimePrint(
            "Type '{s}' does not fullfill the requirements of Component. " ++
                "Components may not be '{s}' types",
            .{ @typeName(T), @tagName(@typeInfo(T)) },
        )),

        Error.contains_invalid_type => @compileError(std.fmt.comptimePrint(
            "Type '{s}' does not fullfill the requirements of Component. " ++
                "Components may not be composed of '{s}' types",
            .{ @typeName(T), @tagName(@typeInfo(T)) },
        )),
    };
}

pub const Test = struct {
    const testing = std.testing;

    test "primitives" {
        try requireIsComponent(i8);
        try requireIsComponent(u8);
        try requireIsComponent(i32);
        try requireIsComponent(u32);
        try requireIsComponent(f32);
        try requireIsComponent(*f32);
        try requireIsComponent(?i32);
        try requireIsComponent(Error!i32);

        try testing.expectError(error.invalid_type, requireIsComponent(fn (void) void));
        try testing.expectError(error.invalid_type, requireIsComponent(void));
        try testing.expectError(error.invalid_type, requireIsComponent(noreturn));
        try testing.expectError(error.invalid_type, requireIsComponent(@TypeOf(4)));
    }

    test "arrays" {
        try requireIsComponent([8]i8);
        try requireIsComponent([8]u8);
        try requireIsComponent([8]i32);
        try requireIsComponent([8]u32);
        try requireIsComponent([8]f32);
        try requireIsComponent([]f32);
        try requireIsComponent([8]?i32);
        try requireIsComponent(?[8]i32);
        try requireIsComponent([8]Error!i32);
        try requireIsComponent(Error![8]i32);
    }

    test "structs" {
        try requireIsComponent(struct { a: i8, b: u8 });
        try requireIsComponent(struct { a: i32, b: u32 });
        try requireIsComponent(struct { a: f32 });
        try requireIsComponent(struct { a: *f32 });
        try requireIsComponent(*struct { a: f32 });
        try requireIsComponent(struct { a: ?i32 });
        try requireIsComponent(struct { a: Error!i32 });
        try requireIsComponent(struct {});

        try testing.expectError(error.contains_invalid_type, requireIsComponent(struct { a: *u32, b: fn (void) void }));
        try testing.expectError(error.contains_invalid_type, requireIsComponent(struct { a: *f32, b: void }));
    }

    test "unions" {
        try requireIsComponent(union { a: i8, b: u8 });
        try requireIsComponent(union { a: i32, b: u32 });
        try requireIsComponent(union { a: f32 });
        try requireIsComponent(union { a: *f32 });
        try requireIsComponent(*union { a: f32 });
        try requireIsComponent(union { a: ?i32 });
        try requireIsComponent(union { a: Error!i32 });
        try requireIsComponent(union {});

        try testing.expectError(error.contains_invalid_type, requireIsComponent(union { a: *u32, b: fn (void) void }));
        try testing.expectError(error.contains_invalid_type, requireIsComponent(union { a: *f32, b: void }));
    }
};
