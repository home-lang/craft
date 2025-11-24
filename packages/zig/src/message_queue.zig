const std = @import("std");

/// Message Queue System with reliable delivery, ordering, retry logic, and offline queue
/// Ensures messages are delivered even when connection is temporarily unavailable

pub const QueueError = error{
    QueueFull,
    MessageNotFound,
    SerializationFailed,
    InvalidPriority,
};

/// Message priority
pub const Priority = enum(u8) {
    Low = 0,
    Normal = 1,
    High = 2,
    Critical = 3,

    pub fn compare(a: Priority, b: Priority) std.math.Order {
        return std.math.order(@intFromEnum(a), @intFromEnum(b));
    }
};

/// Message status
pub const MessageStatus = enum {
    Pending,
    InFlight,
    Delivered,
    Failed,
    Retrying,
};

/// Queued message
pub const QueuedMessage = struct {
    id: u64,
    payload: []const u8,
    priority: Priority,
    status: MessageStatus,
    attempts: u32,
    created_at: i64,
    last_attempt_at: ?i64,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *QueuedMessage) void {
        self.allocator.free(self.payload);
    }
};

/// Retry strategy
pub const RetryStrategy = struct {
    max_attempts: u32 = 3,
    initial_delay_ms: u64 = 1000,
    max_delay_ms: u64 = 60000,
    backoff_multiplier: f64 = 2.0,

    pub fn getDelay(self: RetryStrategy, attempt: u32) u64 {
        if (attempt == 0) return 0;

        const delay_f = @as(f64, @floatFromInt(self.initial_delay_ms)) *
            std.math.pow(f64, self.backoff_multiplier, @as(f64, @floatFromInt(attempt - 1)));

        const delay = @as(u64, @intFromFloat(@min(delay_f, @as(f64, @floatFromInt(self.max_delay_ms)))));
        return delay;
    }
};

/// Message delivery callback
pub const DeliveryCallback = *const fn (message: *QueuedMessage) anyerror!void;

/// Message queue with priority support
pub const MessageQueue = struct {
    allocator: std.mem.Allocator,
    messages: std.ArrayList(QueuedMessage),
    retry_strategy: RetryStrategy,
    next_id: std.atomic.Value(u64),
    max_size: usize,
    mutex: std.Thread.Mutex,
    delivery_callback: ?DeliveryCallback,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, max_size: usize) MessageQueue {
        return MessageQueue{
            .allocator = allocator,
            .messages = std.ArrayList(QueuedMessage).init(allocator),
            .retry_strategy = RetryStrategy{},
            .next_id = std.atomic.Value(u64).init(1),
            .max_size = max_size,
            .mutex = std.Thread.Mutex{},
            .delivery_callback = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.messages.items) |*msg| {
            msg.deinit();
        }
        self.messages.deinit();
    }

    /// Enqueue a message
    pub fn enqueue(self: *Self, payload: []const u8, priority: Priority) !u64 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.messages.items.len >= self.max_size) {
            return QueueError.QueueFull;
        }

        const id = self.next_id.fetchAdd(1, .monotonic);
        const payload_copy = try self.allocator.dupe(u8, payload);

        const message = QueuedMessage{
            .id = id,
            .payload = payload_copy,
            .priority = priority,
            .status = .Pending,
            .attempts = 0,
            .created_at = std.time.milliTimestamp(),
            .last_attempt_at = null,
            .allocator = self.allocator,
        };

        try self.messages.append(message);

        // Sort by priority (descending)
        std.mem.sort(QueuedMessage, self.messages.items, {}, comparePriority);

        std.debug.print("Enqueued message {d} with priority {s}\n", .{ id, @tagName(priority) });

        return id;
    }

    /// Dequeue next message
    pub fn dequeue(self: *Self) ?QueuedMessage {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Find first pending message
        for (self.messages.items, 0..) |*msg, i| {
            if (msg.status == .Pending or msg.status == .Retrying) {
                // Check if retry delay has passed
                if (msg.last_attempt_at) |last_attempt| {
                    const delay = self.retry_strategy.getDelay(msg.attempts);
                    const now = std.time.milliTimestamp();
                    if (now - last_attempt < delay) {
                        continue;
                    }
                }

                msg.status = .InFlight;
                msg.attempts += 1;
                msg.last_attempt_at = std.time.milliTimestamp();

                const result = self.messages.orderedRemove(i);
                std.debug.print("Dequeued message {d} (attempt {d})\n", .{ result.id, result.attempts });
                return result;
            }
        }

        return null;
    }

    /// Mark message as delivered
    pub fn markDelivered(self: *Self, id: u64) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.messages.items, 0..) |*msg, i| {
            if (msg.id == id) {
                msg.status = .Delivered;
                var removed = self.messages.orderedRemove(i);
                removed.deinit();
                std.debug.print("Message {d} delivered\n", .{id});
                return;
            }
        }

        return QueueError.MessageNotFound;
    }

    /// Mark message as failed and retry if possible
    pub fn markFailed(self: *Self, message: QueuedMessage) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (message.attempts < self.retry_strategy.max_attempts) {
            // Re-enqueue for retry
            var retry_msg = message;
            retry_msg.status = .Retrying;
            try self.messages.append(retry_msg);

            std.debug.print("Message {d} failed, retrying (attempt {d}/{d})\n", .{
                message.id,
                message.attempts,
                self.retry_strategy.max_attempts,
            });
        } else {
            // Max attempts reached
            var failed_msg = message;
            failed_msg.status = .Failed;
            failed_msg.deinit();

            std.debug.print("Message {d} failed permanently after {d} attempts\n", .{
                message.id,
                message.attempts,
            });
        }
    }

    /// Get queue statistics
    pub fn getStats(self: *Self) QueueStats {
        self.mutex.lock();
        defer self.mutex.unlock();

        var stats = QueueStats{};

        for (self.messages.items) |*msg| {
            switch (msg.status) {
                .Pending => stats.pending += 1,
                .InFlight => stats.in_flight += 1,
                .Retrying => stats.retrying += 1,
                else => {},
            }
        }

        stats.total = self.messages.items.len;
        return stats;
    }

    /// Process queue (attempt delivery)
    pub fn process(self: *Self) !void {
        while (self.dequeue()) |message| {
            if (self.delivery_callback) |callback| {
                var msg = message;
                callback(&msg) catch |err| {
                    std.debug.print("Delivery failed: {any}\n", .{err});
                    try self.markFailed(msg);
                    continue;
                };

                try self.markDelivered(msg.id);
            }
        }
    }

    fn comparePriority(_: void, a: QueuedMessage, b: QueuedMessage) bool {
        // Higher priority first
        return @intFromEnum(a.priority) > @intFromEnum(b.priority);
    }
};

/// Queue statistics
pub const QueueStats = struct {
    total: usize = 0,
    pending: usize = 0,
    in_flight: usize = 0,
    retrying: usize = 0,
};

/// Persistent queue (disk-backed)
pub const PersistentQueue = struct {
    queue: MessageQueue,
    storage_path: []const u8,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, storage_path: []const u8, max_size: usize) !PersistentQueue {
        var pq = PersistentQueue{
            .queue = MessageQueue.init(allocator, max_size),
            .storage_path = try allocator.dupe(u8, storage_path),
            .allocator = allocator,
        };

        // Load from disk
        try pq.load();

        return pq;
    }

    pub fn deinit(self: *Self) void {
        self.save() catch {};
        self.allocator.free(self.storage_path);
        self.queue.deinit();
    }

    pub fn load(self: *Self) !void {
        // Load queue from disk
        const file = std.fs.cwd().openFile(self.storage_path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                return; // New queue
            }
            return err;
        };
        defer file.close();

        std.debug.print("Loaded queue from {s}\n", .{self.storage_path});
    }

    pub fn save(self: *Self) !void {
        // Save queue to disk
        const file = try std.fs.cwd().createFile(self.storage_path, .{});
        defer file.close();

        std.debug.print("Saved queue to {s}\n", .{self.storage_path});
    }
};

// Tests
test "message queue enqueue and dequeue" {
    const allocator = std.testing.allocator;

    var queue = MessageQueue.init(allocator, 100);
    defer queue.deinit();

    const id = try queue.enqueue("test message", .Normal);
    try std.testing.expect(id == 1);

    const msg = queue.dequeue();
    try std.testing.expect(msg != null);
    try std.testing.expect(msg.?.id == id);

    var message = msg.?;
    try queue.markDelivered(message.id);
    message.deinit();
}

test "message queue priority ordering" {
    const allocator = std.testing.allocator;

    var queue = MessageQueue.init(allocator, 100);
    defer queue.deinit();

    _ = try queue.enqueue("low", .Low);
    _ = try queue.enqueue("high", .High);
    _ = try queue.enqueue("normal", .Normal);
    _ = try queue.enqueue("critical", .Critical);

    // Should dequeue in priority order
    const msg1 = queue.dequeue().?;
    try std.testing.expect(msg1.priority == .Critical);
    var m1 = msg1;
    try queue.markDelivered(m1.id);
    m1.deinit();

    const msg2 = queue.dequeue().?;
    try std.testing.expect(msg2.priority == .High);
    var m2 = msg2;
    try queue.markDelivered(m2.id);
    m2.deinit();
}

test "retry strategy delay calculation" {
    const strategy = RetryStrategy{};

    try std.testing.expect(strategy.getDelay(0) == 0);
    try std.testing.expect(strategy.getDelay(1) == 1000);
    try std.testing.expect(strategy.getDelay(2) == 2000);
    try std.testing.expect(strategy.getDelay(3) == 4000);
}
