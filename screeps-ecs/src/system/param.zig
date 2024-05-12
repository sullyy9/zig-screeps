const std = @import("std");

const query_module = @import("../query.zig");
const isQuery = query_module.isQuery;

const world_module = @import("../world/mod.zig");
const World = world_module.World;

pub const Error = error{
    invalid_type,
};

pub fn isWorldPointer(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info != .Pointer) return false;
    if (info.Pointer.child != World) return false;

    return true;
}

pub fn requireIsSystemParam(comptime T: type) Error!void {
    if (!isQuery(T) and !isWorldPointer(T)) return Error.invalid_type;
}

pub fn isSystemParam(comptime T: type) bool {
    requireIsSystemParam(T) catch return false;
    return true;
}

pub fn assertIsSystemParam(comptime T: type) void {
    requireIsSystemParam(T) catch |err| switch (err) {
        Error.invalid_type => @compileError(std.fmt.comptimePrint(
            "Type '{}' does not fullfill the requirements of SystemParam. " ++
                "SystemParams must be of type Query or World" ++
                "Type is '{}'",
            .{ T, T },
        )),
    };
}
