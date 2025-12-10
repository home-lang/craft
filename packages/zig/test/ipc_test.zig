const std = @import("std");
const testing = std.testing;
const ipc = @import("../src/ipc.zig");

// Global counters for tests that need callbacks to increment counters
var broadcast_count: usize = 0;
var stream_chunk_count: usize = 0;

fn broadcastCounterHandler(_: ipc.Message) void {
    broadcast_count += 1;
}

fn streamChunkCounterHandler(_: ipc.Message) void {
    stream_chunk_count += 1;
}

// MessageType tests
test "MessageType - all variants" {
    try testing.expectEqual(ipc.MessageType.request, .request);
    try testing.expectEqual(ipc.MessageType.response, .response);
    try testing.expectEqual(ipc.MessageType.event, .event);
    try testing.expectEqual(ipc.MessageType.stream, .stream);
}

// Message struct tests
test "Message - request creation" {
    const msg = ipc.Message{
        .id = 1,
        .type = .request,
        .channel = "test",
        .data = "hello",
        .timestamp = 1234567890,
        .sender = "app1",
    };

    try testing.expectEqual(@as(u64, 1), msg.id);
    try testing.expectEqual(ipc.MessageType.request, msg.type);
    try testing.expectEqualStrings("test", msg.channel);
    try testing.expectEqualStrings("hello", msg.data);
    try testing.expectEqual(@as(i64, 1234567890), msg.timestamp);
    try testing.expectEqualStrings("app1", msg.sender.?);
}

test "Message - response creation" {
    const msg = ipc.Message{
        .id = 2,
        .type = .response,
        .channel = "test",
        .data = "world",
        .timestamp = 1234567891,
        .sender = null,
    };

    try testing.expectEqual(@as(u64, 2), msg.id);
    try testing.expectEqual(ipc.MessageType.response, msg.type);
    try testing.expectEqual(@as(?[]const u8, null), msg.sender);
}

test "Message - event creation" {
    const msg = ipc.Message{
        .id = 3,
        .type = .event,
        .channel = "events",
        .data = "click",
        .timestamp = 1234567892,
        .sender = null,
    };

    try testing.expectEqual(ipc.MessageType.event, msg.type);
    try testing.expectEqualStrings("events", msg.channel);
}

test "Message - stream creation" {
    const msg = ipc.Message{
        .id = 4,
        .type = .stream,
        .channel = "data-stream",
        .data = "chunk1",
        .timestamp = 1234567893,
        .sender = "streamer",
    };

    try testing.expectEqual(ipc.MessageType.stream, msg.type);
    try testing.expectEqualStrings("data-stream", msg.channel);
    try testing.expectEqualStrings("chunk1", msg.data);
}

// IPC tests
test "IPC - initialization" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    try testing.expectEqual(@as(u64, 1), instance.next_id);
}

test "IPC - subscribe to channel" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    try instance.on("test-channel", testHandler);

    const handlers = instance.channels.get("test-channel");
    try testing.expect(handlers != null);
    try testing.expectEqual(@as(usize, 1), handlers.?.items.len);
}

test "IPC - multiple subscribers" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    try instance.on("test-channel", testHandler);
    try instance.on("test-channel", testHandler2);

    const handlers = instance.channels.get("test-channel");
    try testing.expectEqual(@as(usize, 2), handlers.?.items.len);
}

test "IPC - unsubscribe from channel" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    try instance.on("test-channel", testHandler);
    try instance.on("test-channel", testHandler2);

    instance.off("test-channel", testHandler);

    const handlers = instance.channels.get("test-channel");
    try testing.expectEqual(@as(usize, 1), handlers.?.items.len);
}

test "IPC - unsubscribe from non-existent channel" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    // Should not crash
    instance.off("non-existent", testHandler);
}

var received_message: ?ipc.Message = null;

fn testHandler(msg: ipc.Message) void {
    received_message = msg;
}

fn testHandler2(msg: ipc.Message) void {
    _ = msg;
}

test "IPC - send message" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    received_message = null;

    try instance.on("test", testHandler);
    try instance.send("test", "hello");

    try testing.expect(received_message != null);
    try testing.expectEqualStrings("hello", received_message.?.data);
    try testing.expectEqualStrings("test", received_message.?.channel);
    try testing.expectEqual(ipc.MessageType.event, received_message.?.type);
}

test "IPC - send to channel with no subscribers" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    // Should not crash
    try instance.send("empty-channel", "data");
}

test "IPC - request/response pattern" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    received_message = null;

    try instance.on("request-channel", testHandler);
    const request_id = try instance.request("request-channel", "ping", testHandler);

    try testing.expect(received_message != null);
    try testing.expectEqual(ipc.MessageType.request, received_message.?.type);
    try testing.expectEqualStrings("ping", received_message.?.data);

    // Simulate response
    received_message = null;
    try instance.respond(request_id, "pong");

    try testing.expect(received_message != null);
    try testing.expectEqual(ipc.MessageType.response, received_message.?.type);
    try testing.expectEqualStrings("pong", received_message.?.data);
}

test "IPC - respond to non-existent request" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    // Should not crash
    try instance.respond(999, "data");
}

test "IPC - broadcast to all channels" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    // Reset global counter
    broadcast_count = 0;

    try instance.on("channel1", broadcastCounterHandler);
    try instance.on("channel2", broadcastCounterHandler);
    try instance.on("channel3", broadcastCounterHandler);

    try instance.broadcast("broadcast-data");

    try testing.expectEqual(@as(usize, 3), broadcast_count);
}

test "IPC - message id incrementing" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    try instance.on("test", testHandler);

    try instance.send("test", "msg1");
    const id1 = received_message.?.id;

    try instance.send("test", "msg2");
    const id2 = received_message.?.id;

    try testing.expect(id2 > id1);
}

// SharedMemory tests
test "SharedMemory - create" {
    const allocator = testing.allocator;
    var mem = try ipc.SharedMemory.create(allocator, "test-mem", 1024);
    defer mem.deinit();

    try testing.expectEqualStrings("test-mem", mem.name);
    try testing.expectEqual(@as(usize, 1024), mem.size);
    try testing.expectEqual(@as(usize, 1024), mem.data.len);
}

test "SharedMemory - write and read" {
    const allocator = testing.allocator;
    var mem = try ipc.SharedMemory.create(allocator, "test-mem", 1024);
    defer mem.deinit();

    const data = "Hello, World!";
    try mem.write(0, data);

    const read_data = try mem.read(0, data.len);
    try testing.expectEqualStrings(data, read_data);
}

test "SharedMemory - write at offset" {
    const allocator = testing.allocator;
    var mem = try ipc.SharedMemory.create(allocator, "test-mem", 1024);
    defer mem.deinit();

    try mem.write(100, "offset");
    const read_data = try mem.read(100, 6);
    try testing.expectEqualStrings("offset", read_data);
}

test "SharedMemory - write out of bounds" {
    const allocator = testing.allocator;
    var mem = try ipc.SharedMemory.create(allocator, "test-mem", 10);
    defer mem.deinit();

    const result = mem.write(5, "too long data");
    try testing.expectError(error.OutOfBounds, result);
}

test "SharedMemory - read out of bounds" {
    const allocator = testing.allocator;
    var mem = try ipc.SharedMemory.create(allocator, "test-mem", 10);
    defer mem.deinit();

    const result = mem.read(5, 10);
    try testing.expectError(error.OutOfBounds, result);
}

test "SharedMemory - multiple writes" {
    const allocator = testing.allocator;
    var mem = try ipc.SharedMemory.create(allocator, "test-mem", 1024);
    defer mem.deinit();

    try mem.write(0, "first");
    try mem.write(10, "second");
    try mem.write(20, "third");

    try testing.expectEqualStrings("first", try mem.read(0, 5));
    try testing.expectEqualStrings("second", try mem.read(10, 6));
    try testing.expectEqualStrings("third", try mem.read(20, 5));
}

// MessageQueue tests
test "MessageQueue - initialization" {
    const allocator = testing.allocator;
    var queue = ipc.MessageQueue.init(allocator);
    defer queue.deinit();

    try testing.expectEqual(@as(usize, 0), queue.size());
}

test "MessageQueue - push and pop" {
    const allocator = testing.allocator;
    var queue = ipc.MessageQueue.init(allocator);
    defer queue.deinit();

    const msg = ipc.Message{
        .id = 1,
        .type = .event,
        .channel = "test",
        .data = "data",
        .timestamp = 123,
        .sender = null,
    };

    try queue.push(msg);
    try testing.expectEqual(@as(usize, 1), queue.size());

    const popped = queue.pop();
    try testing.expect(popped != null);
    try testing.expectEqual(@as(u64, 1), popped.?.id);
    try testing.expectEqual(@as(usize, 0), queue.size());
}

test "MessageQueue - FIFO order" {
    const allocator = testing.allocator;
    var queue = ipc.MessageQueue.init(allocator);
    defer queue.deinit();

    const msg1 = ipc.Message{
        .id = 1,
        .type = .event,
        .channel = "test",
        .data = "first",
        .timestamp = 123,
        .sender = null,
    };

    const msg2 = ipc.Message{
        .id = 2,
        .type = .event,
        .channel = "test",
        .data = "second",
        .timestamp = 124,
        .sender = null,
    };

    try queue.push(msg1);
    try queue.push(msg2);

    const first = queue.pop();
    try testing.expectEqualStrings("first", first.?.data);

    const second = queue.pop();
    try testing.expectEqualStrings("second", second.?.data);
}

test "MessageQueue - pop from empty queue" {
    const allocator = testing.allocator;
    var queue = ipc.MessageQueue.init(allocator);
    defer queue.deinit();

    const result = queue.pop();
    try testing.expectEqual(@as(?ipc.Message, null), result);
}

test "MessageQueue - peek" {
    const allocator = testing.allocator;
    var queue = ipc.MessageQueue.init(allocator);
    defer queue.deinit();

    const msg = ipc.Message{
        .id = 1,
        .type = .event,
        .channel = "test",
        .data = "data",
        .timestamp = 123,
        .sender = null,
    };

    try queue.push(msg);

    const peeked = queue.peek();
    try testing.expect(peeked != null);
    try testing.expectEqual(@as(u64, 1), peeked.?.id);
    try testing.expectEqual(@as(usize, 1), queue.size()); // Size unchanged
}

test "MessageQueue - peek empty queue" {
    const allocator = testing.allocator;
    var queue = ipc.MessageQueue.init(allocator);
    defer queue.deinit();

    const result = queue.peek();
    try testing.expectEqual(@as(?ipc.Message, null), result);
}

test "MessageQueue - clear" {
    const allocator = testing.allocator;
    var queue = ipc.MessageQueue.init(allocator);
    defer queue.deinit();

    const msg = ipc.Message{
        .id = 1,
        .type = .event,
        .channel = "test",
        .data = "data",
        .timestamp = 123,
        .sender = null,
    };

    try queue.push(msg);
    try queue.push(msg);
    try queue.push(msg);

    try testing.expectEqual(@as(usize, 3), queue.size());

    queue.clear();
    try testing.expectEqual(@as(usize, 0), queue.size());
}

// RPC tests
fn addHandler(args: []const u8) []const u8 {
    _ = args;
    return "42";
}

fn greetHandler(args: []const u8) []const u8 {
    _ = args;
    return "Hello!";
}

test "RPC - initialization" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    var rpc = ipc.RPC.init(allocator, &instance);
    defer rpc.deinit();
}

test "RPC - register procedure" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    var rpc = ipc.RPC.init(allocator, &instance);
    defer rpc.deinit();

    try rpc.register("add", addHandler);

    const handler = rpc.procedures.get("add");
    try testing.expect(handler != null);
}

test "RPC - call procedure" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    var rpc = ipc.RPC.init(allocator, &instance);
    defer rpc.deinit();

    try rpc.register("add", addHandler);

    const result = try rpc.call("add", "2,3");
    try testing.expectEqualStrings("42", result);
}

test "RPC - call non-existent procedure" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    var rpc = ipc.RPC.init(allocator, &instance);
    defer rpc.deinit();

    const result = rpc.call("nonexistent", "args");
    try testing.expectError(error.ProcedureNotFound, result);
}

test "RPC - multiple procedures" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    var rpc = ipc.RPC.init(allocator, &instance);
    defer rpc.deinit();

    try rpc.register("add", addHandler);
    try rpc.register("greet", greetHandler);

    try testing.expectEqualStrings("42", try rpc.call("add", "2,3"));
    try testing.expectEqualStrings("Hello!", try rpc.call("greet", "World"));
}

// Stream tests
test "Stream - initialization" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    const stream = ipc.Stream.init(allocator, &instance, "test-stream");

    try testing.expectEqualStrings("test-stream", stream.channel);
    try testing.expectEqual(@as(usize, 4096), stream.chunk_size);
}

test "Stream - write small data" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    received_message = null;
    try instance.on("stream-channel", testHandler);

    var stream = ipc.Stream.init(allocator, &instance, "stream-channel");
    try stream.write("small data");

    try testing.expect(received_message != null);
    try testing.expectEqualStrings("small data", received_message.?.data);
}

test "Stream - write chunked data" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    // Reset global counter
    stream_chunk_count = 0;

    try instance.on("stream-channel", streamChunkCounterHandler);

    var stream = ipc.Stream.init(allocator, &instance, "stream-channel");
    stream.chunk_size = 10;

    try stream.write("0123456789abcdefghij"); // 20 bytes, should create 2 chunks

    try testing.expectEqual(@as(usize, 2), stream_chunk_count);
}

test "Stream - onData handler" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    received_message = null;

    var stream = ipc.Stream.init(allocator, &instance, "data-stream");
    try stream.onData(testHandler);

    try instance.send("data-stream", "stream-data");

    try testing.expect(received_message != null);
    try testing.expectEqualStrings("stream-data", received_message.?.data);
}

test "Stream - close" {
    const allocator = testing.allocator;
    var instance = ipc.IPC.init(allocator);
    defer instance.deinit();

    received_message = null;

    try instance.on("stream-channel", testHandler);

    var stream = ipc.Stream.init(allocator, &instance, "stream-channel");
    try stream.close();

    try testing.expect(received_message != null);
    try testing.expectEqualStrings("", received_message.?.data); // Empty data signals close
}
