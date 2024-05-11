const std = @import("std");

const query_module = @import("../query.zig");
const isQuery = query_module.isQuery;

pub const Error = error{
    invalid_type,
};

pub fn requireIsSystemParam(comptime T: type) Error!void {
    if (!isQuery(T)) return Error.invalid_type;
}

pub fn isSystemParam(comptime T: type) bool {
    return if (requireIsSystemParam(T)) |_| true else |_| false;
}

pub fn assertIsSystemParam(comptime T: type) void {
    requireIsSystemParam(T) catch |err| switch (err) {
        Error.invalid_type => @compileError(std.fmt.comptimePrint(
            "Type '{}' does not fullfill the requirements of SystemParam. " ++
                "SystemParams must be of type Query " ++
                "Type is '{}'",
            .{ T, T },
        )),
    };
}
