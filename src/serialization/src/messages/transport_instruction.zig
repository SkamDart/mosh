const std = @import("std");
const serialization = @import("../serialization.zig");

pub const TransportInstructionFlags = packed struct {
    has_protocol_version: bool = false,
    has_old_num: bool = false,
    has_new_num: bool = false,
    has_ack_num: bool = false,
    has_throwaway_num: bool = false,
    has_diff: bool = false,
    has_chaff: bool = false,
    _padding: u1 = 0,
};

pub const TransportInstruction = struct {
    protocol_version: ?u32 = null,
    old_num: ?u64 = null,
    new_num: ?u64 = null,
    ack_num: ?u64 = null,
    throwaway_num: ?u64 = null,
    diff: ?[]const u8 = null,
    chaff: ?[]const u8 = null,

    pub fn serialize(self: *const TransportInstruction, writer: *serialization.Writer) !void {
        const flags = TransportInstructionFlags{
            .has_protocol_version = self.protocol_version != null,
            .has_old_num = self.old_num != null,
            .has_new_num = self.new_num != null,
            .has_ack_num = self.ack_num != null,
            .has_throwaway_num = self.throwaway_num != null,
            .has_diff = self.diff != null,
            .has_chaff = self.chaff != null,
        };

        try writer.writeU8(@bitCast(flags));

        if (self.protocol_version) |v| try writer.writeU32(v);
        if (self.old_num) |v| try writer.writeU64(v);
        if (self.new_num) |v| try writer.writeU64(v);
        if (self.ack_num) |v| try writer.writeU64(v);
        if (self.throwaway_num) |v| try writer.writeU64(v);
        if (self.diff) |v| try writer.writeBytes(v);
        if (self.chaff) |v| try writer.writeBytes(v);
    }

    pub fn deserialize(reader: *serialization.Reader, allocator: std.mem.Allocator) !TransportInstruction {
        const flags_byte = try reader.readU8();
        const flags: TransportInstructionFlags = @bitCast(flags_byte);

        var inst = TransportInstruction{};

        if (flags.has_protocol_version) inst.protocol_version = try reader.readU32();
        if (flags.has_old_num) inst.old_num = try reader.readU64();
        if (flags.has_new_num) inst.new_num = try reader.readU64();
        if (flags.has_ack_num) inst.ack_num = try reader.readU64();
        if (flags.has_throwaway_num) inst.throwaway_num = try reader.readU64();
        if (flags.has_diff) inst.diff = try reader.readBytes(allocator);
        if (flags.has_chaff) inst.chaff = try reader.readBytes(allocator);

        return inst;
    }

    pub fn deinit(self: *TransportInstruction, allocator: std.mem.Allocator) void {
        if (self.diff) |d| allocator.free(d);
        if (self.chaff) |c| allocator.free(c);
    }
};