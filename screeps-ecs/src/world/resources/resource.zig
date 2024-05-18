const std = @import("std");

pub const Resource = struct {
    pub const resource_tag = {};
};

pub const Error = error{
    invalid_type,
    not_tagged,
};

/// Check if a type fullfills the requirements of `Resource`.
///
/// Returns
/// -------
/// Reason the type doesn't fullfill the requirements or `void` if it does.
///
pub fn requireIsResource(comptime T: type) Error!void {
    return switch (@typeInfo(T)) {
        .Struct, .Union => if (@hasDecl(T, "resource_tag")) {} else Error.not_tagged,
        else => Error.invalid_type,
    };
}

/// Determine if a type fullfills the requirements of `Resource`.
pub fn isResource(comptime T: type) bool {
    requireIsResource(T) catch return false;
    return true;
}

/// Assert that a type fullfills the requirements of `Resource`.
///
/// Causes a compile error if the type does not fullfill the requirements.
///
pub fn assertIsResource(comptime T: type) void {
    comptime requireIsResource(T) catch |err| switch (err) {
        Error.invalid_type => @compileError(std.fmt.comptimePrint(
            "Type '{s}' does not fullfill the requirements of Resource. " ++
                "Resources may be 'struct' or 'union' types. " ++
                "Type is of type '{s}'",
            .{ @typeName(T), @tagName(@typeInfo(T)) },
        )),

        Error.not_tagged => @compileError(std.fmt.comptimePrint(
            "Type '{s}' does not fullfill the requirements of Resource. " ++
                "Resources must contain the 'resource_tag' declaration. " ++
                "Type does not contain the tag",
            .{@typeName(T)},
        )),
    };
}

pub const Test = struct {
    const testing = std.testing;

    test "positive" {
        try requireIsResource(struct {
            usingnamespace Resource;
        });

        try testing.expect(isResource(struct {
            usingnamespace Resource;
        }));

        try requireIsResource(union {
            usingnamespace Resource;
        });

        try testing.expect(isResource(union {
            usingnamespace Resource;
        }));

        try requireIsResource(union(enum) {
            usingnamespace Resource;
        });

        try testing.expect(isResource(union(enum) {
            usingnamespace Resource;
        }));
    }

    test "negative" {
        try testing.expectError(Error.invalid_type, requireIsResource(void));
        try testing.expectError(Error.invalid_type, requireIsResource(i32));
        try testing.expectError(Error.invalid_type, requireIsResource(u32));
        try testing.expectError(Error.invalid_type, requireIsResource(f32));
        try testing.expectError(Error.invalid_type, requireIsResource(enum {}));
        try testing.expectError(Error.not_tagged, requireIsResource(struct {}));
        try testing.expectError(Error.not_tagged, requireIsResource(union {}));

        try testing.expect(!isResource(void));
        try testing.expect(!isResource(i32));
        try testing.expect(!isResource(u32));
        try testing.expect(!isResource(f32));
        try testing.expect(!isResource(enum {}));
        try testing.expect(!isResource(struct {}));
        try testing.expect(!isResource(union {}));
    }
};
