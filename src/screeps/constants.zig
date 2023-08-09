const std = @import("std");

const creep = @import("creep.zig");
const spawn = @import("spawn.zig");
const source = @import("source.zig");
const js = @import("js_bind.zig");

const Spawn = spawn.Spawn;
const Creep = creep.Creep;
const Source = source.Source;

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

/// TODO Find a better way to handle this.
pub const Resource = enum {
    energy,
    power,
    hydrogen,
    oxygen,
    utrium,
    lemergium,
    keanium,
    zynthium,
    catalyst,
    ghodium,
    silicon,
    metal,
    biomass,
    mist,
    hydroxide,
    zynthium_keanite,
    utrium_lemergite,
    utrium_hydride,
    utrium_oxide,
    keanium_hydride,
    keanium_oxide,
    lemergium_hydride,
    lemergium_oxide,
    zynthium_hydride,
    zynthium_oxide,
    ghodium_hydride,
    ghodium_oxide,
    utrium_acid,
    utrium_alkalide,
    keanium_acid,
    keanium_alkalide,
    lemergium_acid,
    lemergium_alkalide,
    zynthium_acid,
    zynthium_alkalide,
    ghodium_acid,
    ghodium_alkalide,
    catalyzed_utrium_acid,
    catalyzed_utrium_alkalide,
    catalyzed_keanium_acid,
    catalyzed_keanium_alkalide,
    catalyzed_lemergium_acid,
    catalyzed_lemergium_alkalide,
    catalyzed_zynthium_acid,
    catalyzed_zynthium_alkalide,
    catalyzed_ghodium_acid,
    catalyzed_ghodium_alkalide,
    ops,
    utrium_bar,
    lemergium_bar,
    zynthium_bar,
    keanium_bar,
    ghodium_melt,
    oxidant,
    reductant,
    purifier,
    battery,
    composite,
    crystal,
    liquid,
    wire,
    button,
    transistor,
    microchip,
    circuit,
    device,
    cell,
    phlegm,
    tissue,
    muscle,
    organoid,
    organism,
    alloy,
    tube,
    fixtures,
    frame,
    hydraulics,
    machine,
    condensate,
    concentrate,
    extract,
    spirit,
    emanation,
    essence,

    const Self = @This();
    pub const js_tag = js.Value.Tag.num;

    comptime {
        js.assertIsJSObjectReference(Self);
    }

    const str_table = [@typeInfo(Self).Enum.fields.len][]const u8{
        "energy",
        "power",

        "H",
        "O",
        "U",
        "L",
        "K",
        "Z",
        "X",
        "G",

        "silicon",
        "metal",
        "biomass",
        "mist",

        "OH",
        "ZK",
        "UL",

        "UH",
        "UO",
        "KH",
        "KO",
        "LH",
        "LO",
        "ZH",
        "ZO",
        "GH",
        "GO",

        "UH2O",
        "UHO2",
        "KH2O",
        "KHO2",
        "LH2O",
        "LHO2",
        "ZH2O",
        "ZHO2",
        "GH2O",
        "GHO2",

        "XUH2O",
        "XUHO2",
        "XKH2O",
        "XKHO2",
        "XLH2O",
        "XLHO2",
        "XZH2O",
        "XZHO2",
        "XGH2O",
        "XGHO2",

        "ops",

        "utrium_bar",
        "lemergium_bar",
        "zynthium_bar",
        "keanium_bar",
        "ghodium_melt",
        "oxidant",
        "reductant",
        "purifier",
        "battery",

        "composite",
        "crystal",
        "liquid",

        "wire",
        "switch",
        "transistor",
        "microchip",
        "circuit",
        "device",

        "cell",
        "phlegm",
        "tissue",
        "muscle",
        "organoid",
        "organism",

        "alloy",
        "tube",
        "fixtures",
        "frame",
        "hydraulics",
        "machine",

        "condensate",
        "concentrate",
        "extract",
        "spirit",
        "emanation",
        "essence",
    };

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
        const value_str = js.String.fromValue(value).getOwnedSlice(std.heap.page_allocator);
        defer std.heap.page_allocator.free(value_str);

        for (Self.str_table) |str, i| {
            if (std.mem.eql(u8, value_str, str)) {
                return @intToEnum(Self, i);
            }
        }
        @panic("Failed to convert value to Resource");
    }

    /// Description
    /// -----------
    /// Return a generic Value.
    ///
    /// Returns
    /// -------
    /// Generic value referencing the Javascript object.
    ///
    pub fn asValue(self: Self) js.Value {
        return js.String.from(Self.str_table[@enumToInt(self)]).asValue();
    }
};
