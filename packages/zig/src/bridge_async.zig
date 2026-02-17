const std = @import("std");
const compat_mutex = @import("compat_mutex.zig");

/// Bidirectional async communication system with binary data transfer
/// Provides Promise-based responses, streaming, and binary protocol
pub const BridgeError = error{
    MessageTooLarge,
    InvalidMessage,
    SerializationFailed,
    DeserializationFailed,
    Timeout,
    ChannelClosed,
};

/// Message type
pub const MessageType = enum(u8) {
    Request = 0,
    Response = 1,
    Stream = 2,
    Binary = 3,
    Error = 4,
};

/// Message header (binary protocol)
pub const MessageHeader = packed struct {
    magic: u32 = 0x43524654, // "CRFT"
    version: u8 = 1,
    type: MessageType,
    id: u32,
    payload_len: u32,

    pub fn encode(self: MessageHeader) [14]u8 {
        var buffer: [14]u8 = undefined;
        std.mem.writeInt(u32, buffer[0..4], self.magic, .little);
        buffer[4] = self.version;
        buffer[5] = @intFromEnum(self.type);
        std.mem.writeInt(u32, buffer[6..10], self.id, .little);
        std.mem.writeInt(u32, buffer[10..14], self.payload_len, .little);
        return buffer;
    }

    pub fn decode(buffer: *const [14]u8) !MessageHeader {
        const magic = std.mem.readInt(u32, buffer[0..4], .little);
        if (magic != 0x43524654) {
            return BridgeError.InvalidMessage;
        }

        return MessageHeader{
            .magic = magic,
            .version = buffer[4],
            .type = @enumFromInt(buffer[5]),
            .id = std.mem.readInt(u32, buffer[6..10], .little),
            .payload_len = std.mem.readInt(u32, buffer[10..14], .little),
        };
    }
};

/// Message payload
pub const Message = struct {
    header: MessageHeader,
    payload: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, msg_type: MessageType, id: u32, payload: []const u8) !Message {
        if (payload.len > std.math.maxInt(u32)) {
            return BridgeError.MessageTooLarge;
        }

        const payload_copy = try allocator.dupe(u8, payload);

        return Message{
            .header = MessageHeader{
                .type = msg_type,
                .id = id,
                .payload_len = @intCast(payload.len),
            },
            .payload = payload_copy,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Message) void {
        self.allocator.free(self.payload);
    }

    pub fn encode(self: *const Message, allocator: std.mem.Allocator) ![]u8 {
        const total_len = 14 + self.payload.len;
        const buffer = try allocator.alloc(u8, total_len);

        const header_bytes = self.header.encode();
        @memcpy(buffer[0..14], &header_bytes);
        @memcpy(buffer[14..], self.payload);

        return buffer;
    }

    pub fn decode(allocator: std.mem.Allocator, buffer: []const u8) !Message {
        if (buffer.len < 14) {
            return BridgeError.InvalidMessage;
        }

        const header_bytes: *const [14]u8 = buffer[0..14];
        const header = try MessageHeader.decode(header_bytes);

        if (buffer.len != 14 + header.payload_len) {
            return BridgeError.InvalidMessage;
        }

        const payload = try allocator.dupe(u8, buffer[14..]);

        return Message{
            .header = header,
            .payload = payload,
            .allocator = allocator,
        };
    }
};

/// Async channel for bidirectional communication
pub const AsyncChannel = struct {
    allocator: std.mem.Allocator,
    next_id: std.atomic.Value(u32),
    pending: std.StringHashMap(*PendingRequest),
    mutex: compat_mutex.Mutex,

    const Self = @This();

    pub const PendingRequest = struct {
        id: u32,
        promise: Promise,
    };

    pub const Promise = struct {
        resolved: std.atomic.Value(bool),
        result: ?[]const u8,
        err: ?anyerror,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Promise {
            return Promise{
                .resolved = std.atomic.Value(bool).init(false),
                .result = null,
                .err = null,
                .allocator = allocator,
            };
        }

        pub fn resolve(self: *Promise, result: []const u8) !void {
            self.result = try self.allocator.dupe(u8, result);
            self.resolved.store(true, .release);
        }

        pub fn reject(self: *Promise, err: anyerror) void {
            self.err = err;
            self.resolved.store(true, .release);
        }

        pub fn wait(self: *Promise, timeout_ms: u64) ![]const u8 {
            const start = std.time.milliTimestamp();
            while (!self.resolved.load(.acquire)) {
                if (timeout_ms > 0 and std.time.milliTimestamp() - start > timeout_ms) {
                    return BridgeError.Timeout;
                }
                std.time.sleep(1 * std.time.ns_per_ms);
            }

            if (self.err) |err| {
                return err;
            }

            return self.result.?;
        }

        pub fn deinit(self: *Promise) void {
            if (self.result) |result| {
                self.allocator.free(result);
            }
        }
    };

    pub fn init(allocator: std.mem.Allocator) AsyncChannel {
        return AsyncChannel{
            .allocator = allocator,
            .next_id = std.atomic.Value(u32).init(1),
            .pending = std.StringHashMap(*PendingRequest).init(allocator),
            .mutex = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var it = self.pending.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.promise.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.pending.deinit();
    }

    /// Send a request and get a promise
    pub fn request(self: *Self, payload: []const u8) !*Promise {
        const id = self.next_id.fetchAdd(1, .monotonic);

        const msg = try Message.init(self.allocator, .Request, id, payload);
        defer {
            var m = msg;
            m.deinit();
        }

        const encoded = try msg.encode(self.allocator);
        defer self.allocator.free(encoded);

        // In real implementation, would send via IPC/WebSocket/etc
        std.debug.print("Bridge: Sending request {d} ({d} bytes)\n", .{ id, encoded.len });

        // Create pending request
        const pending = try self.allocator.create(PendingRequest);
        pending.* = PendingRequest{
            .id = id,
            .promise = Promise.init(self.allocator),
        };

        const id_str = try std.fmt.allocPrint(self.allocator, "{d}", .{id});
        defer self.allocator.free(id_str);

        self.mutex.lock();
        defer self.mutex.unlock();
        try self.pending.put(id_str, pending);

        return &pending.promise;
    }

    /// Handle incoming response
    pub fn handleResponse(self: *Self, msg: Message) !void {
        const id_str = try std.fmt.allocPrint(self.allocator, "{d}", .{msg.header.id});
        defer self.allocator.free(id_str);

        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.pending.get(id_str)) |pending| {
            if (msg.header.type == .Response) {
                try pending.promise.resolve(msg.payload);
            } else if (msg.header.type == .Error) {
                pending.promise.reject(BridgeError.InvalidMessage);
            }

            _ = self.pending.remove(id_str);
        }
    }

    /// Send binary data
    pub fn sendBinary(self: *Self, data: []const u8) !void {
        const id = self.next_id.fetchAdd(1, .monotonic);
        const msg = try Message.init(self.allocator, .Binary, id, data);
        defer {
            var m = msg;
            m.deinit();
        }

        const encoded = try msg.encode(self.allocator);
        defer self.allocator.free(encoded);

        std.debug.print("Bridge: Sending binary data {d} ({d} bytes)\n", .{ id, encoded.len });
    }

    /// Start streaming
    pub fn stream(self: *Self, payload: []const u8) !u32 {
        const id = self.next_id.fetchAdd(1, .monotonic);
        const msg = try Message.init(self.allocator, .Stream, id, payload);
        defer {
            var m = msg;
            m.deinit();
        }

        const encoded = try msg.encode(self.allocator);
        defer self.allocator.free(encoded);

        std.debug.print("Bridge: Starting stream {d}\n", .{id});
        return id;
    }
};

// Tests
test "message encode and decode" {
    const allocator = std.testing.allocator;

    const payload = "hello world";
    var msg = try Message.init(allocator, .Request, 42, payload);
    defer msg.deinit();

    const encoded = try msg.encode(allocator);
    defer allocator.free(encoded);

    var decoded = try Message.decode(allocator, encoded);
    defer decoded.deinit();

    try std.testing.expectEqual(msg.header.id, decoded.header.id);
    try std.testing.expectEqual(msg.header.type, decoded.header.type);
    try std.testing.expectEqualStrings(msg.payload, decoded.payload);
}

test "async channel request" {
    const allocator = std.testing.allocator;

    var channel = AsyncChannel.init(allocator);
    defer channel.deinit();

    const promise = try channel.request("test request");
    defer promise.deinit();

    // Simulate response
    var response = try Message.init(allocator, .Response, 1, "test response");
    defer response.deinit();

    try channel.handleResponse(response);

    const result = try promise.wait(1000);
    try std.testing.expectEqualStrings("test response", result);
}
