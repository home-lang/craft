const std = @import("std");
const compat_mutex = @import("compat_mutex.zig");

/// Advanced Inter-Process Communication Module
/// Provides structured message passing between processes
pub const MessageType = enum {
    request,
    response,
    event,
    stream,
};

pub const Message = struct {
    id: u64,
    type: MessageType,
    channel: []const u8,
    data: []const u8,
    timestamp: i64,
    sender: ?[]const u8,
};

pub const MessageHandler = *const fn (Message) void;

pub const IPC = struct {
    channels: std.StringHashMap(std.ArrayList(MessageHandler)),
    pending_requests: std.AutoHashMap(u64, MessageHandler),
    next_id: std.atomic.Value(u64),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) IPC {
        return IPC{
            .channels = std.StringHashMap(std.ArrayList(MessageHandler)).init(allocator),
            .pending_requests = std.AutoHashMap(u64, MessageHandler).init(allocator),
            .next_id = std.atomic.Value(u64).init(1),
            .allocator = allocator,
        };
    }

    /// Atomically reserve the next message id. Safe for concurrent callers.
    fn allocId(self: *IPC) u64 {
        return self.next_id.fetchAdd(1, .monotonic);
    }

    pub fn deinit(self: *IPC) void {
        var iter = self.channels.iterator();
        while (iter.next()) |entry| {
            // The hashmap stored a duped copy of the channel name (see
            // `on`). Free it here so deinit doesn't leak the keys.
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.channels.deinit();
        self.pending_requests.deinit();
    }

    /// Subscribe to a channel. The `channel` slice is duped so callers may
    /// free or reuse their buffer immediately after this returns; the
    /// previous implementation borrowed the slice and crashed on `off()` /
    /// iteration if the caller's buffer was freed first.
    pub fn on(self: *IPC, channel: []const u8, handler: MessageHandler) !void {
        const result = try self.channels.getOrPut(channel);
        if (!result.found_existing) {
            // First insertion — replace the borrowed key with a duped copy.
            const owned = try self.allocator.dupe(u8, channel);
            errdefer self.allocator.free(owned);
            result.key_ptr.* = owned;
            result.value_ptr.* = .empty;
        }
        try result.value_ptr.append(self.allocator, handler);
    }

    /// Unsubscribe from a channel
    pub fn off(self: *IPC, channel: []const u8, handler: MessageHandler) void {
        if (self.channels.getPtr(channel)) |handlers| {
            for (handlers.items, 0..) |h, i| {
                if (h == handler) {
                    _ = handlers.swapRemove(i);
                    break;
                }
            }
        }
    }

    /// Get current timestamp using a thread-safe atomic counter. Previously
    /// used a non-atomic static counter that could drop increments and break
    /// message ordering under concurrent `send`/`request` calls.
    fn currentTimestamp() i64 {
        const S = struct {
            var counter: std.atomic.Value(i64) = std.atomic.Value(i64).init(0);
        };
        return S.counter.fetchAdd(1, .monotonic) + 1;
    }

    /// Send a message to a channel
    pub fn send(self: *IPC, channel: []const u8, data: []const u8) !void {
        const id = self.allocId();
        const msg = Message{
            .id = id,
            .type = .event,
            .channel = channel,
            .data = data,
            .timestamp = currentTimestamp(),
            .sender = null,
        };

        if (self.channels.get(channel)) |handlers| {
            for (handlers.items) |handler| {
                handler(msg);
            }
        }
    }

    /// Send request and wait for response
    pub fn request(self: *IPC, channel: []const u8, data: []const u8, handler: MessageHandler) !u64 {
        const id = self.allocId();

        try self.pending_requests.put(id, handler);

        const msg = Message{
            .id = id,
            .type = .request,
            .channel = channel,
            .data = data,
            .timestamp = currentTimestamp(),
            .sender = null,
        };

        if (self.channels.get(channel)) |handlers| {
            for (handlers.items) |h| {
                h(msg);
            }
        }

        return id;
    }

    /// Send response to a request
    pub fn respond(self: *IPC, request_id: u64, data: []const u8) !void {
        if (self.pending_requests.get(request_id)) |handler| {
            const msg = Message{
                .id = request_id,
                .type = .response,
                .channel = "",
                .data = data,
                .timestamp = currentTimestamp(),
                .sender = null,
            };
            handler(msg);
            _ = self.pending_requests.remove(request_id);
        }
    }

    /// Broadcast to all channels
    pub fn broadcast(self: *IPC, data: []const u8) !void {
        var iter = self.channels.iterator();
        while (iter.next()) |entry| {
            try self.send(entry.key_ptr.*, data);
        }
    }
};

/// Shared memory for fast IPC
pub const SharedMemory = struct {
    const Backing = struct {
        data: []u8,
        allocator: std.mem.Allocator,
        references: usize = 1,
    };

    var registry_mutex: compat_mutex.Mutex = .{};
    var registry: std.StringHashMapUnmanaged(*Backing) = .empty;

    name: []const u8,
    size: usize,
    data: []u8,
    allocator: std.mem.Allocator,
    backing: *Backing,

    pub fn create(allocator: std.mem.Allocator, name: []const u8, size: usize) !SharedMemory {
        registry_mutex.lock();
        defer registry_mutex.unlock();
        if (registry.contains(name)) return error.AlreadyExists;

        const backing_allocator = std.heap.page_allocator;
        const owned_name = try backing_allocator.dupe(u8, name);
        errdefer backing_allocator.free(owned_name);
        const data = try backing_allocator.alloc(u8, size);
        errdefer backing_allocator.free(data);
        @memset(data, 0);
        const backing = try backing_allocator.create(Backing);
        errdefer backing_allocator.destroy(backing);
        backing.* = .{ .data = data, .allocator = backing_allocator };
        try registry.put(backing_allocator, owned_name, backing);

        return SharedMemory{
            .name = owned_name,
            .size = size,
            .data = data,
            .allocator = allocator,
            .backing = backing,
        };
    }

    pub fn open(allocator: std.mem.Allocator, name: []const u8) !SharedMemory {
        registry_mutex.lock();
        defer registry_mutex.unlock();
        const entry = registry.getEntry(name) orelse return error.NotFound;
        entry.value_ptr.*.references += 1;
        return .{
            .name = entry.key_ptr.*,
            .size = entry.value_ptr.*.data.len,
            .data = entry.value_ptr.*.data,
            .allocator = allocator,
            .backing = entry.value_ptr.*,
        };
    }

    pub fn deinit(self: *SharedMemory) void {
        registry_mutex.lock();
        defer registry_mutex.unlock();
        self.backing.references -= 1;
        if (self.backing.references == 0) {
            const removed = registry.fetchRemove(self.name).?;
            self.backing.allocator.free(removed.key);
            self.backing.allocator.free(self.backing.data);
            self.backing.allocator.destroy(self.backing);
        }
    }

    pub fn write(self: *SharedMemory, offset: usize, data: []const u8) !void {
        if (offset + data.len > self.size) return error.OutOfBounds;
        @memcpy(self.data[offset .. offset + data.len], data);
    }

    pub fn read(self: *SharedMemory, offset: usize, len: usize) ![]const u8 {
        if (offset + len > self.size) return error.OutOfBounds;
        return self.data[offset .. offset + len];
    }
};

/// Message queue for async IPC
pub const MessageQueue = struct {
    messages: std.ArrayList(Message),
    mutex: compat_mutex.Mutex,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MessageQueue {
        return MessageQueue{
            .messages = .empty,
            .mutex = compat_mutex.Mutex{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MessageQueue) void {
        self.messages.deinit(self.allocator);
    }

    pub fn push(self: *MessageQueue, msg: Message) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.messages.append(self.allocator, msg);
    }

    pub fn pop(self: *MessageQueue) ?Message {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.messages.items.len == 0) return null;
        return self.messages.orderedRemove(0);
    }

    pub fn peek(self: *MessageQueue) ?Message {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.messages.items.len == 0) return null;
        return self.messages.items[0];
    }

    pub fn size(self: *MessageQueue) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.messages.items.len;
    }

    pub fn clear(self: *MessageQueue) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.messages.clearRetainingCapacity();
    }
};

/// RPC (Remote Procedure Call) support
pub const RPC = struct {
    ipc: *IPC,
    procedures: std.StringHashMap(RPCHandler),
    allocator: std.mem.Allocator,

    pub const RPCHandler = *const fn ([]const u8) []const u8;

    pub fn init(allocator: std.mem.Allocator, ipc: *IPC) RPC {
        return RPC{
            .ipc = ipc,
            .procedures = std.StringHashMap(RPCHandler).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RPC) void {
        self.procedures.deinit();
    }

    /// Register a remote procedure
    pub fn register(self: *RPC, name: []const u8, handler: RPCHandler) !void {
        try self.procedures.put(name, handler);
    }

    /// Call a remote procedure
    pub fn call(self: *RPC, name: []const u8, args: []const u8) ![]const u8 {
        if (self.procedures.get(name)) |handler| {
            return handler(args);
        }
        return error.ProcedureNotFound;
    }

    /// Call async with callback
    pub fn callAsync(self: *RPC, name: []const u8, args: []const u8, callback: MessageHandler) !void {
        const channel = try std.fmt.allocPrint(self.allocator, "rpc:{s}", .{name});
        defer self.allocator.free(channel);

        _ = try self.ipc.request(channel, args, callback);
    }
};

/// Stream support for continuous data transfer
pub const Stream = struct {
    ipc: *IPC,
    channel: []const u8,
    chunk_size: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, ipc: *IPC, channel: []const u8) Stream {
        return Stream{
            .ipc = ipc,
            .channel = channel,
            .chunk_size = 4096,
            .allocator = allocator,
        };
    }

    pub fn write(self: *Stream, data: []const u8) !void {
        var offset: usize = 0;
        while (offset < data.len) {
            const chunk_end = @min(offset + self.chunk_size, data.len);
            const chunk = data[offset..chunk_end];

            try self.ipc.send(self.channel, chunk);
            offset = chunk_end;
        }
    }

    pub fn onData(self: *Stream, handler: MessageHandler) !void {
        try self.ipc.on(self.channel, handler);
    }

    pub fn close(self: *Stream) !void {
        try self.ipc.send(self.channel, "");
    }
};
