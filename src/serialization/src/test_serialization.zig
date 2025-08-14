const std = @import("std");
const testing = std.testing;
const serialization = @import("serialization.zig");
const user_message = @import("messages/user_message.zig");
const host_message = @import("messages/host_message.zig");
const transport_instruction = @import("messages/transport_instruction.zig");

test "serialization writer and reader basic types" {
    var buffer: [1024]u8 = undefined;
    var writer = serialization.Writer.init(&buffer);

    try writer.writeU8(0x42);
    try writer.writeU16(0x1234);
    try writer.writeU32(0xDEADBEEF);
    try writer.writeU64(0x123456789ABCDEF0);

    var reader = serialization.Reader.init(writer.getWritten());
    
    try testing.expectEqual(@as(u8, 0x42), try reader.readU8());
    try testing.expectEqual(@as(u16, 0x1234), try reader.readU16());
    try testing.expectEqual(@as(u32, 0xDEADBEEF), try reader.readU32());
    try testing.expectEqual(@as(u64, 0x123456789ABCDEF0), try reader.readU64());
}

test "serialization writer and reader bytes" {
    var buffer: [1024]u8 = undefined;
    var writer = serialization.Writer.init(&buffer);

    const test_data = "Hello, Mosh!";
    try writer.writeBytes(test_data);

    var reader = serialization.Reader.init(writer.getWritten());
    const allocator = testing.allocator;
    
    const read_data = try reader.readBytes(allocator);
    defer allocator.free(read_data);
    
    try testing.expectEqualStrings(test_data, read_data);
}

test "user message serialization round trip" {
    const allocator = testing.allocator;
    var buffer: [4096]u8 = undefined;

    // Create a user message
    var msg = user_message.UserMessage.init(allocator);
    defer msg.deinit();

    // Add keystroke
    const keys = try allocator.dupe(u8, "hello");
    try msg.instructions.append(.{ .keystroke = .{ .keys = keys } });

    // Add resize
    try msg.instructions.append(.{ .resize = .{ .width = 80, .height = 24 } });

    // Serialize
    var writer = serialization.Writer.init(&buffer);
    try msg.serialize(&writer);

    // Deserialize
    var reader = serialization.Reader.init(writer.getWritten());
    var decoded_msg = try user_message.UserMessage.deserialize(&reader, allocator);
    defer decoded_msg.deinit();

    // Verify
    try testing.expectEqual(@as(usize, 2), decoded_msg.instructions.items.len);
    
    // Check keystroke
    try testing.expect(decoded_msg.instructions.items[0] == .keystroke);
    try testing.expectEqualStrings("hello", decoded_msg.instructions.items[0].keystroke.keys);
    
    // Check resize
    try testing.expect(decoded_msg.instructions.items[1] == .resize);
    try testing.expectEqual(@as(u32, 80), decoded_msg.instructions.items[1].resize.width);
    try testing.expectEqual(@as(u32, 24), decoded_msg.instructions.items[1].resize.height);
}

test "host message serialization round trip" {
    const allocator = testing.allocator;
    var buffer: [4096]u8 = undefined;

    // Create a host message
    var msg = host_message.HostMessage.init(allocator);
    defer msg.deinit();

    // Add host bytes
    const host_data = try allocator.dupe(u8, "terminal output");
    try msg.instructions.append(.{ .host_bytes = .{ .hoststring = host_data } });

    // Add echo ack
    try msg.instructions.append(.{ .echo_ack = .{ .echo_ack_num = 12345 } });

    // Add resize
    try msg.instructions.append(.{ .resize = .{ .width = 120, .height = 40 } });

    // Serialize
    var writer = serialization.Writer.init(&buffer);
    try msg.serialize(&writer);

    // Deserialize
    var reader = serialization.Reader.init(writer.getWritten());
    var decoded_msg = try host_message.HostMessage.deserialize(&reader, allocator);
    defer decoded_msg.deinit();

    // Verify
    try testing.expectEqual(@as(usize, 3), decoded_msg.instructions.items.len);
    
    // Check host bytes
    try testing.expect(decoded_msg.instructions.items[0] == .host_bytes);
    try testing.expectEqualStrings("terminal output", decoded_msg.instructions.items[0].host_bytes.hoststring);
    
    // Check echo ack
    try testing.expect(decoded_msg.instructions.items[1] == .echo_ack);
    try testing.expectEqual(@as(u64, 12345), decoded_msg.instructions.items[1].echo_ack.echo_ack_num);
    
    // Check resize
    try testing.expect(decoded_msg.instructions.items[2] == .resize);
    try testing.expectEqual(@as(u32, 120), decoded_msg.instructions.items[2].resize.width);
    try testing.expectEqual(@as(u32, 40), decoded_msg.instructions.items[2].resize.height);
}

test "transport instruction serialization round trip" {
    const allocator = testing.allocator;
    var buffer: [4096]u8 = undefined;

    // Create a transport instruction with all fields
    var inst = transport_instruction.TransportInstruction{
        .protocol_version = 42,
        .old_num = 100,
        .new_num = 101,
        .ack_num = 99,
        .throwaway_num = 50,
        .diff = try allocator.dupe(u8, "diff data"),
        .chaff = try allocator.dupe(u8, "chaff data"),
    };
    defer inst.deinit(allocator);

    // Serialize
    var writer = serialization.Writer.init(&buffer);
    try inst.serialize(&writer);

    // Deserialize
    var reader = serialization.Reader.init(writer.getWritten());
    var decoded_inst = try transport_instruction.TransportInstruction.deserialize(&reader, allocator);
    defer decoded_inst.deinit(allocator);

    // Verify all fields
    try testing.expectEqual(@as(u32, 42), decoded_inst.protocol_version.?);
    try testing.expectEqual(@as(u64, 100), decoded_inst.old_num.?);
    try testing.expectEqual(@as(u64, 101), decoded_inst.new_num.?);
    try testing.expectEqual(@as(u64, 99), decoded_inst.ack_num.?);
    try testing.expectEqual(@as(u64, 50), decoded_inst.throwaway_num.?);
    try testing.expectEqualStrings("diff data", decoded_inst.diff.?);
    try testing.expectEqualStrings("chaff data", decoded_inst.chaff.?);
}

test "transport instruction partial fields" {
    const allocator = testing.allocator;
    var buffer: [4096]u8 = undefined;

    // Create a transport instruction with only some fields
    var inst = transport_instruction.TransportInstruction{
        .new_num = 200,
        .ack_num = 199,
        .diff = try allocator.dupe(u8, "partial diff"),
    };
    defer inst.deinit(allocator);

    // Serialize
    var writer = serialization.Writer.init(&buffer);
    try inst.serialize(&writer);

    // Deserialize
    var reader = serialization.Reader.init(writer.getWritten());
    var decoded_inst = try transport_instruction.TransportInstruction.deserialize(&reader, allocator);
    defer decoded_inst.deinit(allocator);

    // Verify only set fields are present
    try testing.expect(decoded_inst.protocol_version == null);
    try testing.expect(decoded_inst.old_num == null);
    try testing.expectEqual(@as(u64, 200), decoded_inst.new_num.?);
    try testing.expectEqual(@as(u64, 199), decoded_inst.ack_num.?);
    try testing.expect(decoded_inst.throwaway_num == null);
    try testing.expectEqualStrings("partial diff", decoded_inst.diff.?);
    try testing.expect(decoded_inst.chaff == null);
}