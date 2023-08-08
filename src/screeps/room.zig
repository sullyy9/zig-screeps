const std = @import("std");

const js = @import("js_bind.zig");
const constants = @import("constants.zig");

const SearchTarget = constants.SearchTarget;

pub const Room = struct {
    obj: js.Object,

    const Self = @This();
    pub const js_tag = js.Value.Tag.object;

    comptime {
        js.assertIsJSObjectReference(Self);
    }

    /// Description
    /// -----------
    /// Return a new Room from a generic value referencing an existing Javascript object.
    ///
    /// Parameters
    /// ----------
    /// - value: Generic value type.
    ///
    /// Returns
    /// -------
    /// New Room referencing an existing Javascript object.
    ///
    pub fn fromValue(value: *const js.Value) Self {
        return Self{ .obj = js.Object.fromValue(value) };
    }

    /// Description
    /// -----------
    /// Return a generic Value referening this Javascript object.
    ///
    /// Returns
    /// -------
    /// Generic value referencing the Javascript object.
    ///
    pub fn asValue(self: *const Self) js.Value {
        return js.Value{ .tag = .object, .val = .{ .ref = self.obj.ref } };
    }

    /// Description
    /// -----------
    /// Return the name of the Room.
    ///
    /// Returns
    /// -------
    /// The room's name.
    ///
    pub fn getName(self: *const Self) !js.String {
        return self.obj.get("name", js.String);
    }

    pub fn find(self: *const Self, comptime target: SearchTarget) !js.Array(target.getType()) {
        return self.obj.call("find", &.{target}, js.Array(target.getType()));
    }
};

const RoomPosition = struct {
    obj: js.Object,

    const Self = @This();
    pub const js_tag = js.Value.Tag.object;

    comptime {
        js.assertIsJSObjectReference(Self);
    }

    /// Description
    /// -----------
    /// Return a new RoomPosition from a generic value referencing an existing Javascript object.
    ///
    /// Parameters
    /// ----------
    /// - value: Generic value type.
    ///
    /// Returns
    /// -------
    /// New RoomPosition referencing an existing Javascript object.
    ///
    pub fn fromValue(value: *const js.Value) Self {
        return Self{ .obj = js.Object.fromValue(value) };
    }

    /// Description
    /// -----------
    /// Return a generic Value referening this Javascript object.
    ///
    /// Returns
    /// -------
    /// Generic value referencing the Javascript object.
    ///
    pub fn asValue(self: *const Self) js.Value {
        return self.obj.asValue();
    }

    pub fn getX(self: *const Self) !u32 {
        return self.obj.get("x", u32);
    }

    pub fn getY(self: *const Self) !u32 {
        return self.obj.get("y", u32);
    }
};

pub const RoomObject = struct {
    obj: js.Object,

    const Self = @This();
    pub const js_tag = js.Value.Tag.object;

    comptime {
        js.assertIsJSObjectReference(Self);
    }

    /// Description
    /// -----------
    /// Return a new RoomPosition from a generic value referencing an existing Javascript object.
    ///
    /// Parameters
    /// ----------
    /// - value: Generic value type.
    ///
    /// Returns
    /// -------
    /// New RoomPosition referencing an existing Javascript object.
    ///
    pub fn fromValue(value: *const js.Value) Self {
        return Self{ .obj = js.Object.fromValue(value) };
    }

    /// Description
    /// -----------
    /// Return a generic Value referening this Javascript object.
    ///
    /// Returns
    /// -------
    /// Generic value referencing the Javascript object.
    ///
    pub fn asValue(self: *const Self) js.Value {
        return self.obj.asValue();
    }

    pub fn effects(self: *const Self) void {
        _ = self;
        unreachable;
    }

    pub fn pos(self: *const Self) !RoomPosition {
        return self.obj.pos();
    }

    pub fn room(self: *const Self) Room {
        _ = self;
        unreachable;
    }
};

pub const Source = struct {
    obj: js.Object,

    const Self = @This();
    pub const js_tag = js.Value.Tag.object;

    comptime {
        js.assertIsJSObjectReference(Self);
    }

    /// Description
    /// -----------
    /// Return a new Source from a generic value referencing an existing Javascript object.
    ///
    /// Parameters
    /// ----------
    /// - value: Generic value type.
    ///
    /// Returns
    /// -------
    /// New Source referencing an existing Javascript object.
    ///
    pub fn fromValue(value: *const js.Value) Self {
        return Self{ .obj = js.Object.fromValue(value) };
    }

    /// Description
    /// -----------
    /// Return a generic Value referening this Javascript object.
    ///
    /// Returns
    /// -------
    /// Generic value referencing the Javascript object.
    ///
    pub fn asValue(self: *const Self) js.Value {
        return self.obj.asValue();
    }

    /// Description
    /// -----------
    /// Return the reference of the Javascript object this holds.
    ///
    /// Returns
    /// -------
    /// Reference to a Javascript object.
    ///
    pub fn getRef(self: *const Self) u64 {
        return self.obj.getRef();
    }

    pub fn pos(self: *const Self) !RoomPosition {
        return self.obj.call("pos", &.{}, RoomPosition);
    }
};
