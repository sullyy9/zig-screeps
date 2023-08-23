const std = @import("std");

const MemoryError = error{
    InvalidKey,
    InvalidUserSpace,

    SectionEmpty,

    WriteOverflow,
};

const MemoryInfo = struct {
    id: u8,
    offset: u24,
    len: u24,

    const Self = @This();
    const byte_len = 7;

    fn toBytes(self: *const Self, buffer: []u8) void {
        std.mem.writeInt(u8, buffer[0..1], self.id, .Little);
        std.mem.writeInt(u24, buffer[1..4], self.offset, .Little);
        std.mem.writeInt(u24, buffer[4..7], self.len, .Little);
    }

    fn fromBytes(bytes: []const u8) Self {
        return Self{
            .id = std.mem.readInt(u8, bytes[0..1], .Little),
            .offset = std.mem.readInt(u24, bytes[1..4], .Little),
            .len = std.mem.readInt(u24, bytes[4..7], .Little),
        };
    }
};

pub const MemoryMeta = struct {
    const key: []const u8 = "isok";

    const info_len = 10;
    const info_byte_len = MemoryInfo.byte_len * info_len;
};

pub const MemoryLoader = struct {
    memory: []const u8,
    sections: [Meta.info_len][]const u8,

    const Self = @This();
    const Meta = MemoryMeta;

    pub fn init(memory: []const u8) !Self {
        if (memory.len < Meta.key.len) {
            return MemoryError.InvalidKey;
        }

        const memory_key = memory[0..Meta.key.len];
        if (!std.mem.eql(u8, memory_key, Meta.key)) {
            return MemoryError.InvalidKey;
        }

        const memory_info = memory[Meta.key.len..(Meta.key.len + Meta.info_byte_len)];
        var info: [Meta.info_len]MemoryInfo = undefined;

        for (0..Meta.info_len) |i| {
            const beg = i * MemoryInfo.byte_len;
            const end = beg + MemoryInfo.byte_len;
            info[i] = MemoryInfo.fromBytes(memory_info[beg..end]);
        }

        var sections: [Meta.info_len][]const u8 = undefined;
        for (&sections, info) |*section, inf| {
            const beg = inf.offset;
            const end = beg + inf.len;
            section.* = memory[beg..end];
        }

        return Self{
            .memory = memory,
            .sections = sections,
        };
    }

    pub fn getSection(self: *const Self, id: u8) ![]const u8 {
        if (self.sections[id].len == 0) return MemoryError.SectionEmpty;
        return self.sections[id];
    }
};

pub const MemoryWriter = struct {
    memory: []u8,

    // Sub-sections.
    memory_key: *[Meta.key.len]u8,
    memory_info: *[Meta.info_byte_len]u8,
    memory_user: []u8,

    // For building.
    info: [Meta.info_len]MemoryInfo,
    info_index: ?usize,

    const Self = @This();
    const Meta = MemoryMeta;

    pub const Writer = std.io.Writer(*Self, MemoryError, write);

    pub fn init(memory: []u8) Self {
        return Self{
            .memory = memory,
            .memory_key = memory[0..Meta.key.len],
            .memory_info = memory[Meta.key.len..(Meta.key.len + Meta.info_byte_len)],
            .memory_user = memory[(Meta.key.len + Meta.info_byte_len)..memory.len],

            .info = undefined,
            .info_index = null,
        };
    }

    pub fn deinit(self: *const Self) void {
        @memcpy(self.memory_key, Meta.key);

        if (self.info_index) |index| {
            for (self.info[0..(index + 1)], 0..) |info, i| {
                const beg = i * MemoryInfo.byte_len;
                const end = beg + MemoryInfo.byte_len;
                info.toBytes(self.memory_info[beg..end]);
            }

            const beg = (index + 1) * MemoryInfo.byte_len;
            @memset(self.memory_info[beg..], 0);
        } else {
            @memset(self.memory_info, 0);
        }
    }

    pub fn nextSectionWriter(self: *Self) Writer {
        if (self.info_index) |_| {
            const last_info = self.info[self.info_index.?];
            self.info_index.? += 1;

            self.info[self.info_index.?] = MemoryInfo{
                .id = @intCast(self.info_index.?),
                .offset = last_info.offset + last_info.len,
                .len = 0,
            };
        } else {
            self.info_index = 0;
            self.info[self.info_index.?] = MemoryInfo{
                .id = @intCast(self.info_index.?),
                .offset = Meta.key.len + Meta.info_byte_len,
                .len = 0,
            };
        }

        return .{ .context = self };
    }

    pub fn write(self: *Self, data: []const u8) !usize {
        const beg = self.info[self.info_index.?].offset + self.info[self.info_index.?].len;
        const end = beg + data.len;

        if (end > self.memory_user.len) {
            return MemoryError.WriteOverflow;
        }

        @memcpy(self.memory[beg..end], data);
        self.info[self.info_index.?].len += @as(u24, @intCast(data.len));

        return data.len;
    }
};

/// Description
/// -----------
/// Manager for persistant memory.
/// Provides access to a json section for reading / writing.
///
/// Key
/// Info section
/// user sections
///
pub const MemoryManager = struct {
    memory: []u8,
    memory_key: *[4]u8,

    // info_table: *[10]MemorySectionInfo,

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
