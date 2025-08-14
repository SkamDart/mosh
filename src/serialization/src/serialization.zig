const std = @import("std");
const builtin = @import("builtin");

pub const SerializationError = error{
    BufferTooSmall,
    InvalidData,
    OutOfMemory,
};

pub const Writer = struct {
    buffer: []u8,
    pos: usize = 0,

    pub fn init(buffer: []u8) Writer {
        return .{ .buffer = buffer };
    }

    pub fn writeU8(self: *Writer, value: u8) !void {
        if (self.pos + 1 > self.buffer.len) return SerializationError.BufferTooSmall;
        self.buffer[self.pos] = value;
        self.pos += 1;
    }

    pub fn writeU16(self: *Writer, value: u16) !void {
        if (self.pos + 2 > self.buffer.len) return SerializationError.BufferTooSmall;
        std.mem.writeInt(u16, self.buffer[self.pos..][0..2], value, .big);
        self.pos += 2;
    }

    pub fn writeU32(self: *Writer, value: u32) !void {
        if (self.pos + 4 > self.buffer.len) return SerializationError.BufferTooSmall;
        std.mem.writeInt(u32, self.buffer[self.pos..][0..4], value, .big);
        self.pos += 4;
    }

    pub fn writeU64(self: *Writer, value: u64) !void {
        if (self.pos + 8 > self.buffer.len) return SerializationError.BufferTooSmall;
        std.mem.writeInt(u64, self.buffer[self.pos..][0..8], value, .big);
        self.pos += 8;
    }

    pub fn writeBytes(self: *Writer, data: []const u8) !void {
        try self.writeU32(@intCast(data.len));
        if (self.pos + data.len > self.buffer.len) return SerializationError.BufferTooSmall;
        @memcpy(self.buffer[self.pos..][0..data.len], data);
        self.pos += data.len;
    }

    pub fn getWritten(self: *const Writer) []const u8 {
        return self.buffer[0..self.pos];
    }
};

pub const Reader = struct {
    buffer: []const u8,
    pos: usize = 0,

    pub fn init(buffer: []const u8) Reader {
        return .{ .buffer = buffer };
    }

    pub fn readU8(self: *Reader) !u8 {
        if (self.pos + 1 > self.buffer.len) return SerializationError.InvalidData;
        const value = self.buffer[self.pos];
        self.pos += 1;
        return value;
    }

    pub fn readU16(self: *Reader) !u16 {
        if (self.pos + 2 > self.buffer.len) return SerializationError.InvalidData;
        const value = std.mem.readInt(u16, self.buffer[self.pos..][0..2], .big);
        self.pos += 2;
        return value;
    }

    pub fn readU32(self: *Reader) !u32 {
        if (self.pos + 4 > self.buffer.len) return SerializationError.InvalidData;
        const value = std.mem.readInt(u32, self.buffer[self.pos..][0..4], .big);
        self.pos += 4;
        return value;
    }

    pub fn readU64(self: *Reader) !u64 {
        if (self.pos + 8 > self.buffer.len) return SerializationError.InvalidData;
        const value = std.mem.readInt(u64, self.buffer[self.pos..][0..8], .big);
        self.pos += 8;
        return value;
    }

    pub fn readBytes(self: *Reader, allocator: std.mem.Allocator) ![]u8 {
        const len = try self.readU32();
        if (self.pos + len > self.buffer.len) return SerializationError.InvalidData;
        const data = try allocator.alloc(u8, len);
        @memcpy(data, self.buffer[self.pos..][0..len]);
        self.pos += len;
        return data;
    }
};