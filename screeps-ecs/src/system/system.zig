const std = @import("std");

const query_module = @import("../query.zig");
const assertIsQuery = query_module.assertIsQuery;

const param_module = @import("param.zig");
const isSystemParam = param_module.isSystemParam;
const assertIsSystemParam = param_module.assertIsSystemParam;

pub const Error = error{
    not_a_function,
    invalid_parameter_type,
    invalid_return_type,
};

pub fn requireIsSystem(comptime T: type) Error!void {
    const info = @typeInfo(T);
    if (info != .Fn) return Error.not_a_function;

    const args = comptime std.meta.ArgsTuple(T);
    inline for (std.meta.fields(args)) |field| {
        if (!isSystemParam(field.type)) return Error.invalid_parameter_type;
    }

    if (info.Fn.return_type != void) return Error.invalid_return_type;
}

pub fn isSystem(comptime T: type) bool {
    requireIsSystem(T) catch return false;
    return true;
}

pub fn assertIsSystem(comptime T: type) void {
    requireIsSystem(T) catch |err| switch (err) {
        Error.not_a_function => @compileError(std.fmt.comptimePrint(
            "Type '{}' does not fullfill the requirements of System. " ++
                "Systems must be functions. " ++
                "Type is '{}'",
            .{ T, @tagName(@typeInfo(T)) },
        )),

        Error.invalid_parameter_type => {
            const args = comptime std.meta.ArgsTuple(T);
            inline for (std.meta.fields(args)) |field| assertIsSystemParam(field.type);
        },

        Error.invalid_return_type => @compileError(std.fmt.comptimePrint(
            "Type '{}' does not fullfill the requirements of System. " ++
                "System return type must be 'void'. " ++
                "Return type is '{}'",
            .{ T, @typeInfo(T).Fn.return_type },
        )),
    };
}

/// Compile time wrapper over an ECS system.
pub const SystemWrapper = struct {
    const Self = @This();

    ptr: *const anyopaque,
    args: type,
    info: std.builtin.Type,

    pub fn init(comptime func: anytype) Self {
        assertIsSystem(@TypeOf(func));

        return Self{
            .ptr = @ptrCast(&func),
            .args = comptime std.meta.ArgsTuple(@TypeOf(func)),
            .info = @typeInfo(@TypeOf(func)),
        };
    }

    pub fn Type(self: *const Self) type {
        return @Type(self.info);
    }

    pub fn call(self: *const Self) void {
        const func: *const fn () void = @ptrCast(self.ptr);
        func(1);
    }
};
