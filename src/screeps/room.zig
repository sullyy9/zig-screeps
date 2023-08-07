const std = @import("std");

const js = @import("js_bind.zig");

pub const Room = struct {
    obj: js.Object,

    const Self = @This();
    pub const js_tag = js.Value.Tag.object;

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
    /// Return the reference of the Javascript object this holds.
    ///
    /// Returns
    /// -------
    /// Reference to a Javascript object.
    ///
    pub fn getRef(self: *const Self) u64 {
        return self.obj.getRef();
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
};
