const std = @import("std");
const StructField = std.builtin.Type.StructField;

pub fn assertIsArchetype(comptime Archetype: type) void {
    comptime switch (@typeInfo(Archetype)) {
        .Struct => {
            for (std.meta.fields(Archetype), 0..) |f1, i| {
                const field1: StructField = f1;
                for (std.meta.fields(Archetype), 0..) |f2, j| {
                    const field2: StructField = f2;

                    if (i == j) continue;

                    if (field1.type == field2.type) {
                        @compileError(std.fmt.comptimePrint(
                            "Type '{}' does not fullfill the requirements of Archetype. " ++
                                "All archetype fields must have unique types. " ++
                                "Fields '{s}' and '{s}' are both of type '{}'",
                            .{ Archetype, field1.name, field2.name, field1.type },
                        ));
                    }
                }
            }
        },
        else => @compileError(std.fmt.comptimePrint(
            "Type '{}' does not fullfill the requirements of Archetype. " ++
                "Archetypes may only be struct types. " ++
                "Type was of type '{}'",
            .{
                Archetype,
                @tagName(@typeInfo(Archetype)),
            },
        )),
    };
}
