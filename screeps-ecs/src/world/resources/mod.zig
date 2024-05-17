const storage = @import("storage.zig");

pub const ResourceStorage = storage.Storage;

test {
    const std = @import("std");
    std.testing.refAllDeclsRecursive(@import("storage.zig"));
}
