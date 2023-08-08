const std = @import("std");

const creep = @import("creep.zig");
const spawn = @import("spawn.zig");
const room = @import("room.zig");
const js = @import("js_bind.zig");

const Spawn = spawn.Spawn;
const Creep = creep.Creep;
const Source = room.Source;

pub const ErrorVal = enum(i32) {
    ok = 0,
    not_owner = -1,
    no_path = -2,
    name_exists = -3,
    busy = -4,
    not_found = -5,
    not_enough_resources = -6,
    invalid_target = -7,
    full = -8,
    not_in_range = -9,
    invalid_args = -10,
    tired = -11,
    no_bodypart = -12,
    rcl_not_enough = -14,
    gcl_not_enough = -15,
    _,

    const Self = @This();
    pub const js_tag = js.Value.Tag.num;

    comptime {
        js.assertIsJSObjectReference(Self);
    }

    /// Description
    /// -----------
    /// Return a new Game from a generic value referencing an existing Javascript object.
    ///
    /// Parameters
    /// ----------
    /// - value: Generic value type.
    ///
    /// Returns
    /// -------
    /// New Game referencing an existing Javascript object.
    ///
    pub fn fromValue(value: *const js.Value) Self {
        return @intToEnum(Self, @floatToInt(@typeInfo(Self).Enum.tag_type, value.val.num));
    }

    /// Description
    /// -----------
    /// Return a generic Value.
    ///
    /// Returns
    /// -------
    /// Generic value referencing the Javascript object.
    ///
    pub fn asValue(self: *const Self) js.Value {
        return js.Value{ .tag = .num, .val = .{ .num = std.math.lossyCast(f64, @enumToInt(self.*)) } };
    }

    pub fn toError(self: ErrorVal) ?ScreepsError {
        return switch (self) {
            ErrorVal.not_owner => ScreepsError.NotOwner,
            ErrorVal.no_path => ScreepsError.NoPath,
            ErrorVal.name_exists => ScreepsError.NameExists,
            ErrorVal.busy => ScreepsError.Busy,
            ErrorVal.not_found => ScreepsError.NotFound,
            ErrorVal.not_enough_resources => ScreepsError.NotEnoughResources,
            ErrorVal.invalid_target => ScreepsError.InvalidTarget,
            ErrorVal.full => ScreepsError.Full,
            ErrorVal.not_in_range => ScreepsError.NotInRange,
            ErrorVal.invalid_args => ScreepsError.InvalidArgs,
            ErrorVal.tired => ScreepsError.Tired,
            ErrorVal.no_bodypart => ScreepsError.NoBodypart,
            ErrorVal.rcl_not_enough => ScreepsError.RclNotEnough,
            ErrorVal.gcl_not_enough => ScreepsError.GclNotEnough,
            else => null,
        };
    }
};

pub const ScreepsError = error{
    NotOwner,
    NoPath,
    NameExists,
    Busy,
    NotFound,
    NotEnoughResources,
    InvalidTarget,
    Full,
    NotInRange,
    InvalidArgs,
    Tired,
    NoBodypart,
    RclNotEnough,
    GclNotEnough,
};

pub const SearchTarget = enum(u32) {
    exit_top = 1,
    exit_right = 3,
    exit_bottom = 5,
    exit_left = 7,
    exit = 10,
    creeps = 101,
    my_creeps = 102,
    hostile_creeps = 103,
    sources_active = 104,
    sources = 105,
    dropped_resources = 106,
    structures = 107,
    my_structures = 108,
    hostile_structures = 109,
    flags = 110,
    construction_sites = 111,
    my_spawns = 112,
    hostile_spawns = 113,
    my_construction_sites = 114,
    hostile_construction_sites = 115,
    minerals = 116,
    nukes = 117,
    tombstones = 118,
    power_creeps = 119,
    my_power_creeps = 120,
    hostile_power_creeps = 121,
    deposits = 122,
    ruins = 123,

    const Self = @This();
    pub const js_tag = js.Value.Tag.num;

    comptime {
        js.assertIsJSObjectReference(Self);
    }

    /// Description
    /// -----------
    /// Return a new Game from a generic value referencing an existing Javascript object.
    ///
    /// Parameters
    /// ----------
    /// - value: Generic value type.
    ///
    /// Returns
    /// -------
    /// New Game referencing an existing Javascript object.
    ///
    pub fn fromValue(value: *const js.Value) Self {
        return @intToEnum(Self, @floatToInt(@typeInfo(Self).Enum.tag_type, value.val.num));
    }

    /// Description
    /// -----------
    /// Return a generic Value.
    ///
    /// Returns
    /// -------
    /// Generic value referencing the Javascript object.
    ///
    pub fn asValue(self: *const Self) js.Value {
        return js.Value{ .tag = .num, .val = .{ .num = std.math.lossyCast(f64, @enumToInt(self.*)) } };
    }

    pub fn getType(comptime self: Self) type {
        return switch (self) {
            Self.exit_top => unreachable,
            Self.exit_right => unreachable,
            Self.exit_bottom => unreachable,
            Self.exit_left => unreachable,
            Self.exit => unreachable,
            Self.creeps => Creep,
            Self.my_creeps => Creep,
            Self.hostile_creeps => Creep,
            Self.sources_active => Source,
            Self.sources => Source,
            Self.dropped_resources => unreachable,
            Self.structures => unreachable,
            Self.my_structures => unreachable,
            Self.hostile_structures => unreachable,
            Self.flags => unreachable,
            Self.construction_sites => unreachable,
            Self.my_spawns => Spawn,
            Self.hostile_spawns => Spawn,
            Self.my_construction_sites => unreachable,
            Self.hostile_construction_sites => unreachable,
            Self.minerals => unreachable,
            Self.nukes => unreachable,
            Self.tombstones => unreachable,
            Self.power_creeps => unreachable,
            Self.my_power_creeps => unreachable,
            Self.hostile_power_creeps => unreachable,
            Self.deposits => unreachable,
            Self.ruins => unreachable,
        };
    }
};
