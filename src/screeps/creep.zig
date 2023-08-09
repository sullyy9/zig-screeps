const std = @import("std");
const builtin = @import("builtin");

const js = @import("js_bind.zig");

const room = @import("room.zig");
const misc = @import("misc.zig");
const constants = @import("constants.zig");

const RoomObject = room.RoomObject;
const Store = misc.Store;
const Resource = constants.Resource;
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
    pub fn getName(self: *const Self) js.String {
        return self.obj.get("name", js.String);
    }

    pub fn getStore(self: *const Self) Store {
        return self.obj.get("store", Store);
    }

    pub fn moveTo(self: *const Self, target: anytype) !void {
        var result: ErrorVal = undefined;
        if (builtin.mode == std.builtin.Mode.Debug) {
            const options = js.Object.init();
            options.set("visualizePathStyle", js.Object.init());

            result = self.obj.call("moveTo", &.{ target, options }, ErrorVal);
        } else {
            result = self.obj.call("moveTo", &.{target}, ErrorVal);
        }

        if (result.toError()) |err| {
            return err;
        }
    }

    pub fn harvest(self: *const Self, target: anytype) !void {
        const result = self.obj.call("harvest", &.{target}, ErrorVal);
        if (result.toError()) |err| {
            return err;
        }
    }

    pub fn transfer(self: *const Self, target: anytype, resource: Resource) !void {
        const result = self.obj.call("transfer", &.{ target, resource }, ErrorVal);
        if (result.toError()) |err| {
            return err;
        }
    }

    pub fn transferAmmount(self: *const Self, target: anytype, resource: Resource, quantity: u32) !void {
        const result = self.obj.call("transfer", &.{ target, resource, quantity }, ErrorVal);
        if (result.toError()) |err| {
            return err;
        }
    }

    pub fn drop(self: *const Self, resource: Resource) !void {
        const result = self.obj.call("drop", &.{resource}, ErrorVal);
        if (result.toError()) |err| {
            return err;
        }
    }

    pub fn dropAmmount(self: *const Self, resource: Resource, quantity: u32) !void {
        const result = self.obj.call("drop", &.{ resource, quantity }, ErrorVal);
        if (result.toError()) |err| {
            return err;
        }
    }
};
