const std = @import("std");
const testing = std.testing;

extern "logging" fn log(str: [*]const u8, len: u32) void;

//////////////////////////////////////////////////

fn print(str: []const u8) void {
    log(str.ptr, str.len);
}

//////////////////////////////////////////////////

export fn run() void {
    const allocator = std.heap.page_allocator;
    const string = std.fmt.allocPrint(allocator, "test format {d}", .{1234}) catch return;
    print(string);
}
