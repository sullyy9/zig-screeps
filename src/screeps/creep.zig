const std = @import("std");
const builtin = @import("builtin");

const jsbind = @import("jsbind.zig");
const JSArray = jsbind.JSArray;
const JSObject = jsbind.JSObject;
const JSString = jsbind.JSString;
const jsObjectProperty = jsbind.jsObjectProperty;
const JSObjectReference = jsbind.JSObjectReference;

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
    obj: JSObject,

    const Self = @This();
    pub usingnamespace JSObjectReference(Self);

    pub usingnamespace RoomObject(Self);

    pub const getBody = jsObjectProperty(Self, "body", JSArray(undefined)); // TODO create Body type.
    pub const getFatigue = jsObjectProperty(Self, "fatigue", u32);
    pub const getHits = jsObjectProperty(Self, "hits", u32);
    pub const getHitsMax = jsObjectProperty(Self, "hitsMax", u32);
    pub const getID = jsObjectProperty(Self, "id", JSString);
    pub const getIsMine = jsObjectProperty(Self, "my", bool);
    pub const getName = jsObjectProperty(Self, "name", JSString);
    pub const getOwner = jsObjectProperty(Self, "owner", undefined); // TODO create Owner type.
    pub const getSaying = jsObjectProperty(Self, "saying", JSString);
    pub const getIsSpawning = jsObjectProperty(Self, "spawning", bool);
    pub const getStore = jsObjectProperty(Self, "store", Store);
    pub const getTicksToLive = jsObjectProperty(Self, "ticksToLive", u32);

    pub fn moveTo(self: *const Self, target: anytype) !void {
        var result: ErrorVal = undefined;
        if (builtin.mode == std.builtin.Mode.Debug) {
            const options = JSObject.init();
            options.set("visualizePathStyle", JSObject.init());

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
