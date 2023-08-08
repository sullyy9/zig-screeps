const std = @import("std");

const js = @import("js_bind.zig");

const room = @import("room.zig");
const constants = @import("constants.zig");

const RoomObject = room.RoomObject;
const ErrorVal = constants.ErrorVal;

/// The possible parts a creep can be made up from. In the Screeps API, these are defined as
/// strings. They are named here such that @tagname will give the correct string for each.
pub const Part = enum {
    work,
    move,
    carry,
    attack,
    ranged_attack,
    heal,
    tough,
    claim,
};

pub const Blueprint = struct {
    name: []const u8,
    parts: []const Part,
};

pub const Creep = struct {
    obj: js.Object,

    const Self = @This();
    pub usingnamespace js.ObjectReference(Self);

    /// Description
    /// -----------
    /// Return the name of the Creep.
    ///
    /// Returns
    /// -------
    /// The creeps name.
    ///
    pub fn getName(self: *const Self) !js.String {
        return self.obj.get("name", js.String);
    }

    pub fn moveTo(self: *const Self, target: anytype) !void {
        const result = try self.obj.call("moveTo", &.{target}, ErrorVal);
        if (result.toError()) |err| {
            return err;
        }
    }
};
