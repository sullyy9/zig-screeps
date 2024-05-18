//! Collection of component and archetype types for testing.
//!

const std = @import("std");

pub const Name = struct {
    const Self = @This();

    name: []const u8,

    pub fn init(name: []const u8) Self {
        return Self{ .name = name };
    }

    pub fn order(lhs: Self, rhs: Self) std.math.Order {
        return std.mem.order(u8, lhs.name, rhs.name);
    }
};

pub const ID = struct {
    const Self = @This();

    id: u64,

    pub fn init(id: u64) Self {
        return Self{ .id = id };
    }

    pub fn order(lhs: Self, rhs: Self) std.math.Order {
        return std.math.order(lhs.id, rhs.id);
    }
};

pub const FunkyTag = enum {
    const Self = @This();

    in_a_good_way,
    in_a_bad_way,

    pub fn order(lhs: Self, rhs: Self) std.math.Order {
        if (lhs == .in_a_good_way and rhs == .in_a_bad_way) {
            return .gt;
        }

        if (lhs == .in_a_bad_way and rhs == .in_a_good_way) {
            return .lt;
        }

        return .eq;
    }
};

pub const Funky = union(FunkyTag) {
    const Self = @This();
    const Tag = std.meta.Tag(Self);

    in_a_good_way: u32,
    in_a_bad_way: u32,

    pub fn order(lhs: Self, rhs: Self) std.math.Order {
        switch (Tag.order(std.meta.Tag(lhs), std.meta.Tag(rhs))) {
            .eq => {
                return switch (lhs) {
                    .in_a_good_way => std.math.order(lhs.in_a_good_way, rhs.in_a_good_way),
                    .in_a_bad_way => std.math.order(lhs.in_a_bad_way, rhs.in_a_bad_way),
                };
            },
            .gt => return .gt,
            .lt => return .lt,
        }
    }
};
