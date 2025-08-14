const std = @import("std");
const serialization = @import("../serialization.zig");
const user_message = @import("user_message.zig");

pub const HostInstructionType = enum(u8) {
    host_bytes = 1,
    resize = 2,
    echo_ack = 3,
};

pub const HostBytes = struct {
    hoststring: []const u8,

    pub fn serialize(self: *const HostBytes, writer: *serialization.Writer) !void {
        try writer.writeBytes(self.hoststring);
    }

    pub fn deserialize(reader: *serialization.Reader, allocator: std.mem.Allocator) !HostBytes {
        return .{ .hoststring = try reader.readBytes(allocator) };
    }

    pub fn deinit(self: *HostBytes, allocator: std.mem.Allocator) void {
        allocator.free(self.hoststring);
    }
};

pub const EchoAck = struct {
    echo_ack_num: u64,

    pub fn serialize(self: *const EchoAck, writer: *serialization.Writer) !void {
        try writer.writeU64(self.echo_ack_num);
    }

    pub fn deserialize(reader: *serialization.Reader) !EchoAck {
        return .{ .echo_ack_num = try reader.readU64() };
    }
};

pub const HostInstruction = union(HostInstructionType) {
    host_bytes: HostBytes,
    resize: user_message.ResizeMessage,
    echo_ack: EchoAck,

    pub fn serialize(self: *const HostInstruction, writer: *serialization.Writer) !void {
        try writer.writeU8(@intFromEnum(self.*));
        switch (self.*) {
            .host_bytes => |*h| try h.serialize(writer),
            .resize => |*r| try r.serialize(writer),
            .echo_ack => |*e| try e.serialize(writer),
        }
    }

    pub fn deserialize(reader: *serialization.Reader, allocator: std.mem.Allocator) !HostInstruction {
        const inst_type = try reader.readU8();
        return switch (@as(HostInstructionType, @enumFromInt(inst_type))) {
            .host_bytes => .{ .host_bytes = try HostBytes.deserialize(reader, allocator) },
            .resize => .{ .resize = try user_message.ResizeMessage.deserialize(reader) },
            .echo_ack => .{ .echo_ack = try EchoAck.deserialize(reader) },
        };
    }

    pub fn deinit(self: *HostInstruction, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .host_bytes => |*h| h.deinit(allocator),
            .resize => {},
            .echo_ack => {},
        }
    }
};

pub const HostMessage = struct {
    instructions: std.ArrayList(HostInstruction),

    pub fn init(allocator: std.mem.Allocator) HostMessage {
        return .{ .instructions = std.ArrayList(HostInstruction).init(allocator) };
    }

    pub fn serialize(self: *const HostMessage, writer: *serialization.Writer) !void {
        try writer.writeU16(@intCast(self.instructions.items.len));
        for (self.instructions.items) |*inst| {
            try inst.serialize(writer);
        }
    }

    pub fn deserialize(reader: *serialization.Reader, allocator: std.mem.Allocator) !HostMessage {
        const count = try reader.readU16();
        var msg = HostMessage.init(allocator);
        errdefer msg.deinit();

        var i: usize = 0;
        while (i < count) : (i += 1) {
            try msg.instructions.append(try HostInstruction.deserialize(reader, allocator));
        }
        return msg;
    }

    pub fn deinit(self: *HostMessage) void {
        for (self.instructions.items) |*inst| {
            inst.deinit(self.instructions.allocator);
        }
        self.instructions.deinit();
    }
};