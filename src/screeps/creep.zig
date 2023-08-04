pub const Creep = struct {
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

    name: []const u8,
    parts: []const Part,
};
