const storage = @import("storage.zig");
const resource = @import("resource.zig");

pub const Resource = resource.Resource;
pub const ConstraintError = resource.Error;
pub const isResource = resource.isResource;
pub const assertIsResource = resource.assertIsResource;
pub const requireIsResource = resource.requireIsResource;

pub const ResourceStorage = storage.Storage;

test {
    const std = @import("std");
    std.testing.refAllDeclsRecursive(@import("storage.zig"));
    std.testing.refAllDeclsRecursive(@import("resource.zig"));
}
