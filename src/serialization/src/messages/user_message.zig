const std = @import("std");
const serialization = @import("../serialization.zig");

pub const UserInstructionType = enum(u8) {
    keystroke = 1,
    resize = 2,
};

pub const Keystroke = struct {
    keys: []const u8,

    pub fn serialize(self: *const Keystroke, writer: *serialization.Writer) !void {
        try writer.writeBytes(self.keys);
    }

    pub fn deserialize(reader: *serialization.Reader, allocator: std.mem.Allocator) !Keystroke {
        return .{ .keys = try reader.readBytes(allocator) };
    }

    pub fn deinit(self: *Keystroke, allocator: std.mem.Allocator) void {
        allocator.free(self.keys);
    }
};

pub const ResizeMessage = struct {
    width: u32,
    height: u32,

    pub fn serialize(self: *const ResizeMessage, writer: *serialization.Writer) !void {
        try writer.writeU32(self.width);
        try writer.writeU32(self.height);
    }

    pub fn deserialize(reader: *serialization.Reader) !ResizeMessage {
        return .{
            .width = try reader.readU32(),
            .height = try reader.readU32(),
        };
    }
};

pub const UserInstruction = union(UserInstructionType) {
    keystroke: Keystroke,
    resize: ResizeMessage,

    pub fn serialize(self: *const UserInstruction, writer: *serialization.Writer) !void {
        try writer.writeU8(@intFromEnum(self.*));
        switch (self.*) {
            .keystroke => |*k| try k.serialize(writer),
            .resize => |*r| try r.serialize(writer),
        }
    }

    pub fn deserialize(reader: *serialization.Reader, allocator: std.mem.Allocator) !UserInstruction {
        const inst_type = try reader.readU8();
        return switch (@as(UserInstructionType, @enumFromInt(inst_type))) {
            .keystroke => .{ .keystroke = try Keystroke.deserialize(reader, allocator) },
            .resize => .{ .resize = try ResizeMessage.deserialize(reader) },
        };
    }

    pub fn deinit(self: *UserInstruction, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .keystroke => |*k| k.deinit(allocator),
            .resize => {},
        }
    }
};

pub const UserMessage = struct {
    instructions: std.ArrayList(UserInstruction),

    pub fn init(allocator: std.mem.Allocator) UserMessage {
        return .{ .instructions = std.ArrayList(UserInstruction).init(allocator) };
    }

    pub fn serialize(self: *const UserMessage, writer: *serialization.Writer) !void {
        try writer.writeU16(@intCast(self.instructions.items.len));
        for (self.instructions.items) |*inst| {
            try inst.serialize(writer);
        }
    }

    pub fn deserialize(reader: *serialization.Reader, allocator: std.mem.Allocator) !UserMessage {
        const count = try reader.readU16();
        var msg = UserMessage.init(allocator);
        errdefer msg.deinit();

        var i: usize = 0;
        while (i < count) : (i += 1) {
            try msg.instructions.append(try UserInstruction.deserialize(reader, allocator));
        }
        return msg;
    }

    pub fn deinit(self: *UserMessage) void {
        for (self.instructions.items) |*inst| {
            inst.deinit(self.instructions.allocator);
        }
        self.instructions.deinit();
    }
};