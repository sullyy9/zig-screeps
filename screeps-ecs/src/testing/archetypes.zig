const std = @import("std");

const components = @import("components.zig");
const ID = components.ID;
const Name = components.Name;
const Funky = components.Funky;

pub const NameAndID = struct {
    const Self = @This();

    name: Name,
    id: ID,

    pub fn init(name: Name, id: ID) Self {
        return Self{ .name = name, .id = id };
    }

    pub fn initRaw(name: []const u8, id: u64) Self {
        return Self{ .name = Name.init(name), .id = ID.init(id) };
    }

    pub fn order(lhs: Self, rhs: Self) std.math.Order {
        return switch (ID.order(lhs.id, rhs.id)) {
            .eq => Name.order(lhs.name, rhs.name),
            .gt => .gt,
            .lt => .lt,
        };
    }
};

pub const FunkyNameAndID = struct {
    const Self = @This();

    name: Name,
    id: ID,
    funky: Funky,

    pub fn init(name: Name, id: ID, funky: Funky) Self {
        return Self{ .name = name, .id = id, .funky = funky };
    }

    pub fn initRaw(name: []const u8, id: u64, funky: Funky) Self {
        return Self{ .name = Name.init(name), .id = ID.init(id), .funky = funky };
    }

    pub fn fromNameAndID(from: NameAndID, funky: Funky) Self {
        return Self{ .name = from.name, .id = from.id, .funky = funky };
    }

    pub fn order(lhs: Self, rhs: Self) std.math.Order {
        return switch (ID.order(lhs.id, rhs.id)) {
            .eq => switch (Name.order(lhs.name, rhs.name)) {
                .eq => Funky.order(lhs.funky, rhs.funky),
                else => |ord| ord,
            },
            else => |ord| ord,
        };
    }
};
