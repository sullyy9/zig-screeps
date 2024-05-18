const std = @import("std");

const query = @import("../query.zig");
const isQuery = query.isQuery;

const world = @import("../world/mod.zig");
const World = world.World;
const isResource = world.isResource;

pub const Error = error{
    invalid_type,
};

fn isWorldPointer(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info != .Pointer) return false;
    if (info.Pointer.child != World) return false;

    return true;
}

fn isResourcePointer(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info != .Pointer) return false;
    if (info.Pointer.is_const) return false;
    if (!isResource(info.Pointer.child)) return false;

    return true;
}

fn isResourceConstPointer(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info != .Pointer) return false;
    if (!info.Pointer.is_const) return false;
    if (!isResource(info.Pointer.child)) return false;

    return true;
}

fn isOptionalResourcePointer(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info != .Optional) return false;
    return isResourcePointer(info.Optional.child);
}

fn isOptionalResourceConstPointer(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info != .Optional) return false;
    return isResourceConstPointer(info.Optional.child);
}

pub fn requireIsSystemParam(comptime T: type) Error!void {
    if (!isQuery(T) and
        !isWorldPointer(T) and
        !isResourcePointer(T) and
        !isResourceConstPointer(T) and
        !isOptionalResourcePointer(T) and
        !isOptionalResourceConstPointer(T))
    {
        return Error.invalid_type;
    }
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

pub const SystemParam = union(enum) {
    const Self = @This();

    query: type,
    world_ptr: type,

    resource_ptr: type,
    resource_ptr_const: type,

    opt_resource_ptr: type,
    opt_resource_ptr_const: type,

    pub fn init(comptime T: type) Self {
        if (comptime isQuery(T)) {
            return .{ .query = T };
        } else if (comptime isWorldPointer(T)) {
            return .{ .world_ptr = T };
        } else if (comptime isResourcePointer(T)) {
            return .{ .resource_ptr = @typeInfo(T).Pointer.child };
        } else if (comptime isResourceConstPointer(T)) {
            return .{ .resource_ptr_const = @typeInfo(T).Pointer.child };
        } else if (comptime isOptionalResourcePointer(T)) {
            return .{ .opt_resource_ptr = @typeInfo(@typeInfo(T).Optional.child).Pointer.child };
        } else if (comptime isOptionalResourceConstPointer(T)) {
            return .{ .opt_resource_ptr_const = @typeInfo(@typeInfo(T).Optional.child).Pointer.child };
        }

        @compileError("Unexpected type");
    }
};
