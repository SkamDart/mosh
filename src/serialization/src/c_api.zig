const std = @import("std");
const user_message = @import("messages/user_message.zig");
const host_message = @import("messages/host_message.zig");
const transport_instruction = @import("messages/transport_instruction.zig");
const serialization = @import("serialization.zig");

// Opaque handles for C++
pub const MoshUserMessage = opaque {};
pub const MoshHostMessage = opaque {};
pub const MoshTransportInstruction = opaque {};

// User Message API
export fn mosh_user_message_create() ?*MoshUserMessage {
    const allocator = std.heap.c_allocator;
    const msg = allocator.create(user_message.UserMessage) catch return null;
    msg.* = user_message.UserMessage.init(allocator);
    return @ptrCast(msg);
}

export fn mosh_user_message_destroy(msg: ?*MoshUserMessage) void {
    if (msg) |m| {
        const message: *user_message.UserMessage = @ptrCast(@alignCast(m));
        message.deinit();
        std.heap.c_allocator.destroy(message);
    }
}

export fn mosh_user_message_add_keystroke(msg: ?*MoshUserMessage, keys: [*c]const u8, len: usize) bool {
    if (msg) |m| {
        const message: *user_message.UserMessage = @ptrCast(@alignCast(m));
        const keys_slice = keys[0..len];
        const keys_copy = std.heap.c_allocator.dupe(u8, keys_slice) catch return false;
        message.instructions.append(.{ .keystroke = .{ .keys = keys_copy } }) catch {
            std.heap.c_allocator.free(keys_copy);
            return false;
        };
        return true;
    }
    return false;
}

export fn mosh_user_message_add_resize(msg: ?*MoshUserMessage, width: u32, height: u32) bool {
    if (msg) |m| {
        const message: *user_message.UserMessage = @ptrCast(@alignCast(m));
        message.instructions.append(.{ .resize = .{ .width = width, .height = height } }) catch return false;
        return true;
    }
    return false;
}

export fn mosh_user_message_serialize(msg: ?*const MoshUserMessage, buffer: [*c]u8, buffer_size: usize, out_size: *usize) bool {
    if (msg) |m| {
        const message: *const user_message.UserMessage = @ptrCast(@alignCast(m));
        var writer = serialization.Writer.init(buffer[0..buffer_size]);
        message.serialize(&writer) catch return false;
        out_size.* = writer.pos;
        return true;
    }
    return false;
}

export fn mosh_user_message_deserialize(buffer: [*c]const u8, buffer_size: usize) ?*MoshUserMessage {
    const allocator = std.heap.c_allocator;
    var reader = serialization.Reader.init(buffer[0..buffer_size]);
    const msg = user_message.UserMessage.deserialize(&reader, allocator) catch return null;
    const heap_msg = allocator.create(user_message.UserMessage) catch return null;
    heap_msg.* = msg;
    return @ptrCast(heap_msg);
}

export fn mosh_user_message_get_instruction_count(msg: ?*const MoshUserMessage) usize {
    if (msg) |m| {
        const message: *const user_message.UserMessage = @ptrCast(@alignCast(m));
        return message.instructions.items.len;
    }
    return 0;
}

export fn mosh_user_message_get_instruction_type(msg: ?*const MoshUserMessage, index: usize) u8 {
    if (msg) |m| {
        const message: *const user_message.UserMessage = @ptrCast(@alignCast(m));
        if (index < message.instructions.items.len) {
            return @intFromEnum(message.instructions.items[index]);
        }
    }
    return 0;
}

export fn mosh_user_message_get_keystroke_keys(msg: ?*const MoshUserMessage, index: usize, out_data: *[*c]const u8, out_len: *usize) bool {
    if (msg) |m| {
        const message: *const user_message.UserMessage = @ptrCast(@alignCast(m));
        if (index < message.instructions.items.len) {
            switch (message.instructions.items[index]) {
                .keystroke => |*k| {
                    out_data.* = k.keys.ptr;
                    out_len.* = k.keys.len;
                    return true;
                },
                else => return false,
            }
        }
    }
    return false;
}

export fn mosh_user_message_get_resize_dimensions(msg: ?*const MoshUserMessage, index: usize, width: *u32, height: *u32) bool {
    if (msg) |m| {
        const message: *const user_message.UserMessage = @ptrCast(@alignCast(m));
        if (index < message.instructions.items.len) {
            switch (message.instructions.items[index]) {
                .resize => |*r| {
                    width.* = r.width;
                    height.* = r.height;
                    return true;
                },
                else => return false,
            }
        }
    }
    return false;
}

// Host Message API
export fn mosh_host_message_create() ?*MoshHostMessage {
    const allocator = std.heap.c_allocator;
    const msg = allocator.create(host_message.HostMessage) catch return null;
    msg.* = host_message.HostMessage.init(allocator);
    return @ptrCast(msg);
}

export fn mosh_host_message_destroy(msg: ?*MoshHostMessage) void {
    if (msg) |m| {
        const message: *host_message.HostMessage = @ptrCast(@alignCast(m));
        message.deinit();
        std.heap.c_allocator.destroy(message);
    }
}

export fn mosh_host_message_add_host_bytes(msg: ?*MoshHostMessage, bytes: [*c]const u8, len: usize) bool {
    if (msg) |m| {
        const message: *host_message.HostMessage = @ptrCast(@alignCast(m));
        const bytes_slice = bytes[0..len];
        const bytes_copy = std.heap.c_allocator.dupe(u8, bytes_slice) catch return false;
        message.instructions.append(.{ .host_bytes = .{ .hoststring = bytes_copy } }) catch {
            std.heap.c_allocator.free(bytes_copy);
            return false;
        };
        return true;
    }
    return false;
}

export fn mosh_host_message_add_resize(msg: ?*MoshHostMessage, width: u32, height: u32) bool {
    if (msg) |m| {
        const message: *host_message.HostMessage = @ptrCast(@alignCast(m));
        message.instructions.append(.{ .resize = .{ .width = width, .height = height } }) catch return false;
        return true;
    }
    return false;
}

export fn mosh_host_message_add_echo_ack(msg: ?*MoshHostMessage, echo_ack_num: u64) bool {
    if (msg) |m| {
        const message: *host_message.HostMessage = @ptrCast(@alignCast(m));
        message.instructions.append(.{ .echo_ack = .{ .echo_ack_num = echo_ack_num } }) catch return false;
        return true;
    }
    return false;
}

export fn mosh_host_message_serialize(msg: ?*const MoshHostMessage, buffer: [*c]u8, buffer_size: usize, out_size: *usize) bool {
    if (msg) |m| {
        const message: *const host_message.HostMessage = @ptrCast(@alignCast(m));
        var writer = serialization.Writer.init(buffer[0..buffer_size]);
        message.serialize(&writer) catch return false;
        out_size.* = writer.pos;
        return true;
    }
    return false;
}

export fn mosh_host_message_deserialize(buffer: [*c]const u8, buffer_size: usize) ?*MoshHostMessage {
    const allocator = std.heap.c_allocator;
    var reader = serialization.Reader.init(buffer[0..buffer_size]);
    const msg = host_message.HostMessage.deserialize(&reader, allocator) catch return null;
    const heap_msg = allocator.create(host_message.HostMessage) catch return null;
    heap_msg.* = msg;
    return @ptrCast(heap_msg);
}

export fn mosh_host_message_get_instruction_count(msg: ?*const MoshHostMessage) usize {
    if (msg) |m| {
        const message: *const host_message.HostMessage = @ptrCast(@alignCast(m));
        return message.instructions.items.len;
    }
    return 0;
}

export fn mosh_host_message_get_instruction_type(msg: ?*const MoshHostMessage, index: usize) u8 {
    if (msg) |m| {
        const message: *const host_message.HostMessage = @ptrCast(@alignCast(m));
        if (index < message.instructions.items.len) {
            return @intFromEnum(message.instructions.items[index]);
        }
    }
    return 0;
}

export fn mosh_host_message_get_host_bytes(msg: ?*const MoshHostMessage, index: usize, out_data: *[*c]const u8, out_len: *usize) bool {
    if (msg) |m| {
        const message: *const host_message.HostMessage = @ptrCast(@alignCast(m));
        if (index < message.instructions.items.len) {
            switch (message.instructions.items[index]) {
                .host_bytes => |*h| {
                    out_data.* = h.hoststring.ptr;
                    out_len.* = h.hoststring.len;
                    return true;
                },
                else => return false,
            }
        }
    }
    return false;
}

export fn mosh_host_message_get_resize_dimensions_host(msg: ?*const MoshHostMessage, index: usize, width: *u32, height: *u32) bool {
    if (msg) |m| {
        const message: *const host_message.HostMessage = @ptrCast(@alignCast(m));
        if (index < message.instructions.items.len) {
            switch (message.instructions.items[index]) {
                .resize => |*r| {
                    width.* = r.width;
                    height.* = r.height;
                    return true;
                },
                else => return false,
            }
        }
    }
    return false;
}

export fn mosh_host_message_get_echo_ack_num(msg: ?*const MoshHostMessage, index: usize, echo_ack_num: *u64) bool {
    if (msg) |m| {
        const message: *const host_message.HostMessage = @ptrCast(@alignCast(m));
        if (index < message.instructions.items.len) {
            switch (message.instructions.items[index]) {
                .echo_ack => |*e| {
                    echo_ack_num.* = e.echo_ack_num;
                    return true;
                },
                else => return false,
            }
        }
    }
    return false;
}

// Transport Instruction API
export fn mosh_transport_instruction_create() ?*MoshTransportInstruction {
    const allocator = std.heap.c_allocator;
    const inst = allocator.create(transport_instruction.TransportInstruction) catch return null;
    inst.* = .{};
    return @ptrCast(inst);
}

export fn mosh_transport_instruction_destroy(inst: ?*MoshTransportInstruction) void {
    if (inst) |i| {
        const instruction: *transport_instruction.TransportInstruction = @ptrCast(@alignCast(i));
        instruction.deinit(std.heap.c_allocator);
        std.heap.c_allocator.destroy(instruction);
    }
}

export fn mosh_transport_instruction_set_protocol_version(inst: ?*MoshTransportInstruction, version: u32) void {
    if (inst) |i| {
        const instruction: *transport_instruction.TransportInstruction = @ptrCast(@alignCast(i));
        instruction.protocol_version = version;
    }
}

export fn mosh_transport_instruction_set_old_num(inst: ?*MoshTransportInstruction, num: u64) void {
    if (inst) |i| {
        const instruction: *transport_instruction.TransportInstruction = @ptrCast(@alignCast(i));
        instruction.old_num = num;
    }
}

export fn mosh_transport_instruction_set_new_num(inst: ?*MoshTransportInstruction, num: u64) void {
    if (inst) |i| {
        const instruction: *transport_instruction.TransportInstruction = @ptrCast(@alignCast(i));
        instruction.new_num = num;
    }
}

export fn mosh_transport_instruction_set_ack_num(inst: ?*MoshTransportInstruction, num: u64) void {
    if (inst) |i| {
        const instruction: *transport_instruction.TransportInstruction = @ptrCast(@alignCast(i));
        instruction.ack_num = num;
    }
}

export fn mosh_transport_instruction_set_throwaway_num(inst: ?*MoshTransportInstruction, num: u64) void {
    if (inst) |i| {
        const instruction: *transport_instruction.TransportInstruction = @ptrCast(@alignCast(i));
        instruction.throwaway_num = num;
    }
}

export fn mosh_transport_instruction_set_diff(inst: ?*MoshTransportInstruction, diff_data: [*c]const u8, len: usize) bool {
    if (inst) |i| {
        const instruction: *transport_instruction.TransportInstruction = @ptrCast(@alignCast(i));
        if (instruction.diff) |d| std.heap.c_allocator.free(d);
        const diff_copy = std.heap.c_allocator.dupe(u8, diff_data[0..len]) catch return false;
        instruction.diff = diff_copy;
        return true;
    }
    return false;
}

export fn mosh_transport_instruction_set_chaff(inst: ?*MoshTransportInstruction, chaff_data: [*c]const u8, len: usize) bool {
    if (inst) |i| {
        const instruction: *transport_instruction.TransportInstruction = @ptrCast(@alignCast(i));
        if (instruction.chaff) |c| std.heap.c_allocator.free(c);
        const chaff_copy = std.heap.c_allocator.dupe(u8, chaff_data[0..len]) catch return false;
        instruction.chaff = chaff_copy;
        return true;
    }
    return false;
}

export fn mosh_transport_instruction_serialize(inst: ?*const MoshTransportInstruction, buffer: [*c]u8, buffer_size: usize, out_size: *usize) bool {
    if (inst) |i| {
        const instruction: *const transport_instruction.TransportInstruction = @ptrCast(@alignCast(i));
        var writer = serialization.Writer.init(buffer[0..buffer_size]);
        instruction.serialize(&writer) catch return false;
        out_size.* = writer.pos;
        return true;
    }
    return false;
}

export fn mosh_transport_instruction_deserialize(buffer: [*c]const u8, buffer_size: usize) ?*MoshTransportInstruction {
    const allocator = std.heap.c_allocator;
    var reader = serialization.Reader.init(buffer[0..buffer_size]);
    const inst = transport_instruction.TransportInstruction.deserialize(&reader, allocator) catch return null;
    const heap_inst = allocator.create(transport_instruction.TransportInstruction) catch return null;
    heap_inst.* = inst;
    return @ptrCast(heap_inst);
}

// Transport Instruction accessors
export fn mosh_transport_instruction_get_protocol_version(inst: ?*const MoshTransportInstruction, out_value: *u32) bool {
    if (inst) |i| {
        const instruction: *const transport_instruction.TransportInstruction = @ptrCast(@alignCast(i));
        if (instruction.protocol_version) |v| {
            out_value.* = v;
            return true;
        }
    }
    return false;
}

export fn mosh_transport_instruction_get_old_num(inst: ?*const MoshTransportInstruction, out_value: *u64) bool {
    if (inst) |i| {
        const instruction: *const transport_instruction.TransportInstruction = @ptrCast(@alignCast(i));
        if (instruction.old_num) |v| {
            out_value.* = v;
            return true;
        }
    }
    return false;
}

export fn mosh_transport_instruction_get_new_num(inst: ?*const MoshTransportInstruction, out_value: *u64) bool {
    if (inst) |i| {
        const instruction: *const transport_instruction.TransportInstruction = @ptrCast(@alignCast(i));
        if (instruction.new_num) |v| {
            out_value.* = v;
            return true;
        }
    }
    return false;
}

export fn mosh_transport_instruction_get_ack_num(inst: ?*const MoshTransportInstruction, out_value: *u64) bool {
    if (inst) |i| {
        const instruction: *const transport_instruction.TransportInstruction = @ptrCast(@alignCast(i));
        if (instruction.ack_num) |v| {
            out_value.* = v;
            return true;
        }
    }
    return false;
}

export fn mosh_transport_instruction_get_throwaway_num(inst: ?*const MoshTransportInstruction, out_value: *u64) bool {
    if (inst) |i| {
        const instruction: *const transport_instruction.TransportInstruction = @ptrCast(@alignCast(i));
        if (instruction.throwaway_num) |v| {
            out_value.* = v;
            return true;
        }
    }
    return false;
}

export fn mosh_transport_instruction_get_diff(inst: ?*const MoshTransportInstruction, out_data: *[*c]const u8, out_len: *usize) bool {
    if (inst) |i| {
        const instruction: *const transport_instruction.TransportInstruction = @ptrCast(@alignCast(i));
        if (instruction.diff) |d| {
            out_data.* = d.ptr;
            out_len.* = d.len;
            return true;
        }
    }
    return false;
}

export fn mosh_transport_instruction_get_chaff(inst: ?*const MoshTransportInstruction, out_data: *[*c]const u8, out_len: *usize) bool {
    if (inst) |i| {
        const instruction: *const transport_instruction.TransportInstruction = @ptrCast(@alignCast(i));
        if (instruction.chaff) |c| {
            out_data.* = c.ptr;
            out_len.* = c.len;
            return true;
        }
    }
    return false;
}