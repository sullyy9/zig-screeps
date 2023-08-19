const std = @import("std");

const MemoryError = error{
    InvalidKey,
    InvalidUserSpace,
};

/// Description
/// -----------
/// Manager for persistant memory.
/// Provides access to a json section for reading / writing.
///
pub const MemoryManager = struct {
    memory: []u8,
    memory_key: *[4]u8,
    memory_user_len: *[4]u8,
    memory_user_space: []u8,

    user_index: u32,

    // Static sections.
    const key_value: []const u8 = "isok";
    const key_base: u32 = 0;
    const key_end: u32 = key_base + key_value.len;

    const user_len_base: u32 = key_end;
    const user_len_end: u32 = user_len_base + @sizeOf(u32);
    const user_base: u32 = user_len_end;

    const Self = @This();
    pub const Writer = std.io.Writer(*Self, error{OutOfMemory}, write);

    pub fn init(memory: []u8) Self {
        return Self{
            .memory = memory,
            .memory_key = memory[Self.key_base..Self.key_end],
            .memory_user_len = memory[Self.user_len_base..Self.user_len_end],
            .memory_user_space = memory[Self.user_base..memory.len],
            .user_index = 0,
        };
    }

    pub fn fromSaved(memory: []u8) !Self {
        if (memory.len < key_end) {
            return MemoryError.InvalidKey;
        }

        const memory_key = memory[Self.key_base..Self.key_end];
        if (!std.mem.eql(u8, memory_key, Self.key_value)) {
            return MemoryError.InvalidKey;
        }

        const memory_user_len = memory[Self.user_len_base..Self.user_len_end];
        const user_end = Self.user_base + std.mem.readInt(u32, memory_user_len, .Little);

        if (user_end <= Self.user_base or user_end >= memory.len) {
            return MemoryError.InvalidUserSpace;
        }

        return Self{
            .memory = memory,
            .memory_key = memory_key,
            .memory_user_len = memory_user_len,
            .memory_user_space = memory[Self.user_base..user_end],
            .user_index = 0,
        };
    }

    pub fn deinit(self: *const Self) void {
        @memcpy(self.memory_key, Self.key_value);
        std.mem.writeInt(u32, self.memory_user_len, self.user_index, .Little);
    }

    pub fn writer(self: *Self) Writer {
        return .{ .context = self };
    }

    pub fn write(self: *Self, data: []const u8) !usize {
        const end = self.user_index + data.len;

        if (end > self.memory_user_space.len) {
            const remaining = self.memory_user_space.len - self.user_index;
            @memcpy(self.memory_user_space, data[0..remaining]);
            self.user_index += remaining;
            return remaining;
        } else {
            @memcpy(self.memory_user_space[self.user_index..end], data);
            self.user_index += data.len;
            return data.len;
        }
    }

    pub fn getMemory(self: *const Self) []const u8 {
        return self.memory_user_space;
    }
};
