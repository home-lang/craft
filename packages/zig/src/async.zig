const std = @import("std");
const compat_mutex = @import("compat_mutex.zig");
const io_context = @import("io_context.zig");

/// Async/Await System for Craft
/// Provides non-blocking I/O and task scheduling
pub const Task = struct {
    fn_ptr: *const fn (*anyopaque) anyerror!void,
    context: *anyopaque,
    result: ?anyerror!void,
    completed: bool,
    mutex: compat_mutex.Mutex,

    pub fn init(fn_ptr: *const fn (*anyopaque) anyerror!void, context: *anyopaque) Task {
        return Task{
            .fn_ptr = fn_ptr,
            .context = context,
            .result = null,
            .completed = false,
            .mutex = .{},
        };
    }

    pub fn run(self: *Task) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.result = self.fn_ptr(self.context);
        self.completed = true;
    }

    pub fn isComplete(self: *Task) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.completed;
    }

    pub fn getResult(self: *Task) ?anyerror!void {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.result;
    }
};

pub const AsyncFile = struct {
    path: []const u8,
    file: ?std.Io.File,
    allocator: std.mem.Allocator,

    // Context types need to be at struct level to be accessible from task functions
    const ReadContext = struct {
        file: *AsyncFile,
        data: []u8,
    };

    const WriteContext = struct {
        file: *AsyncFile,
        data: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator, path: []const u8) AsyncFile {
        return AsyncFile{
            .path = path,
            .file = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AsyncFile) void {
        if (self.file) |file| {
            file.close(io_context.get());
        }
    }

    pub fn readAsync(self: *AsyncFile) !Task {
        const context = try self.allocator.create(ReadContext);
        context.* = .{ .file = self, .data = &[_]u8{} };

        return Task.init(readTask, @ptrCast(context));
    }

    fn readTask(ctx: *anyopaque) !void {
        const context: *ReadContext = @ptrCast(@alignCast(ctx));
        const io = io_context.get();
        const file = try std.Io.Dir.cwd().openFile(io, context.file.path, .{});
        defer file.close(io);

        const file_stat = try file.stat(io);
        const size = file_stat.size;
        const content = try context.file.allocator.alloc(u8, size);
        _ = try file.readPositional(io, &.{content}, 0);
        context.data = content;
    }

    pub fn writeAsync(self: *AsyncFile, data: []const u8) !Task {
        const context = try self.allocator.create(WriteContext);
        context.* = .{ .file = self, .data = data };

        return Task.init(writeTask, @ptrCast(context));
    }

    fn writeTask(ctx: *anyopaque) !void {
        const context: *WriteContext = @ptrCast(@alignCast(ctx));
        const io = io_context.get();
        const file = try std.Io.Dir.cwd().createFile(io, context.file.path, .{});
        defer file.close(io);

        try file.writeStreamingAll(io, context.data);
    }
};

pub const StreamReader = struct {
    file: std.Io.File,
    buffer: []u8,
    buffer_size: usize,
    position: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, file: std.Io.File, buffer_size: usize) !StreamReader {
        const buffer = try allocator.alloc(u8, buffer_size);
        return StreamReader{
            .file = file,
            .buffer = buffer,
            .buffer_size = buffer_size,
            .position = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *StreamReader) void {
        self.allocator.free(self.buffer);
    }

    pub fn readChunk(self: *StreamReader) !?[]const u8 {
        const io = io_context.get();
        const bytes_read = try self.file.readPositional(io, &.{self.buffer}, self.position);
        if (bytes_read == 0) return null;

        self.position += bytes_read;
        return self.buffer[0..bytes_read];
    }

    pub fn readLine(self: *StreamReader) !?[]const u8 {
        var line: std.ArrayList(u8) = .{};
        defer line.deinit(self.allocator);

        while (true) {
            const chunk = try self.readChunk() orelse return null;

            for (chunk) |byte| {
                if (byte == '\n') {
                    return try line.toOwnedSlice(self.allocator);
                }
                try line.append(self.allocator, byte);
            }
        }
    }

    pub fn skip(self: *StreamReader, bytes: usize) !void {
        self.position += bytes;
    }

    pub fn getPosition(self: StreamReader) usize {
        return self.position;
    }
};

pub const StreamWriter = struct {
    file: std.Io.File,
    buffer: std.ArrayList(u8),
    auto_flush_size: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, file: std.Io.File, auto_flush_size: usize) StreamWriter {
        return StreamWriter{
            .file = file,
            .buffer = .{},
            .auto_flush_size = auto_flush_size,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *StreamWriter) void {
        self.flush() catch {};
        self.buffer.deinit(self.allocator);
    }

    pub fn write(self: *StreamWriter, data: []const u8) !void {
        try self.buffer.appendSlice(self.allocator, data);

        if (self.buffer.items.len >= self.auto_flush_size) {
            try self.flush();
        }
    }

    pub fn writeLine(self: *StreamWriter, line: []const u8) !void {
        try self.write(line);
        try self.write("\n");
    }

    pub fn flush(self: *StreamWriter) !void {
        if (self.buffer.items.len == 0) return;

        try self.file.writeStreamingAll(io_context.get(), self.buffer.items);
        self.buffer.clearRetainingCapacity();
    }
};

pub const Promise = struct {
    state: State,
    value: ?[]const u8,
    err: ?anyerror,
    callbacks: std.ArrayList(Callback),
    error_callbacks: std.ArrayList(ErrorCallback),
    mutex: compat_mutex.Mutex,
    allocator: std.mem.Allocator,

    pub const State = enum {
        pending,
        fulfilled,
        rejected,
    };

    const Callback = *const fn ([]const u8) void;
    const ErrorCallback = *const fn (anyerror) void;

    pub fn init(allocator: std.mem.Allocator) Promise {
        return Promise{
            .state = .pending,
            .value = null,
            .err = null,
            .callbacks = .{},
            .error_callbacks = .{},
            .mutex = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Promise) void {
        self.callbacks.deinit(self.allocator);
        self.error_callbacks.deinit(self.allocator);
    }

    pub fn resolve(self: *Promise, val: []const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.state != .pending) return;

        self.state = .fulfilled;
        self.value = val;

        for (self.callbacks.items) |callback| {
            callback(val);
        }
    }

    pub fn reject(self: *Promise, error_val: anyerror) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.state != .pending) return;

        self.state = .rejected;
        self.err = error_val;

        for (self.error_callbacks.items) |callback| {
            callback(error_val);
        }
    }

    pub fn then(self: *Promise, callback: Callback) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.state == .fulfilled) {
            if (self.value) |val| {
                callback(val);
            }
        } else {
            try self.callbacks.append(self.allocator, callback);
        }
    }

    pub fn catch_(self: *Promise, callback: ErrorCallback) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.state == .rejected) {
            if (self.err) |error_val| {
                callback(error_val);
            }
        } else {
            try self.error_callbacks.append(self.allocator, callback);
        }
    }
};

pub const EventLoop = struct {
    tasks: std.ArrayList(*Task),
    running: bool,
    mutex: compat_mutex.Mutex,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) EventLoop {
        return EventLoop{
            .tasks = .{},
            .running = false,
            .mutex = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *EventLoop) void {
        self.tasks.deinit(self.allocator);
    }

    pub fn submit(self: *EventLoop, task: *Task) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.tasks.append(self.allocator, task);
    }

    pub fn run(self: *EventLoop) void {
        self.running = true;

        while (self.running) {
            self.mutex.lock();

            var i: usize = 0;
            while (i < self.tasks.items.len) {
                const task = self.tasks.items[i];

                if (!task.isComplete()) {
                    // Spawn thread to run task
                    const thread = std.Thread.spawn(.{}, runTask, .{task}) catch {
                        i += 1;
                        continue;
                    };
                    thread.detach();
                }

                if (task.isComplete()) {
                    _ = self.tasks.swapRemove(i);
                } else {
                    i += 1;
                }
            }

            self.mutex.unlock();

            // Small sleep to prevent busy waiting
            std.time.sleep(1_000_000); // 1ms
        }
    }

    fn runTask(task: *Task) void {
        task.run();
    }

    pub fn stop(self: *EventLoop) void {
        self.running = false;
    }
};

pub const Channels = struct {
    pub fn Channel(comptime T: type) type {
        return struct {
            buffer: std.ArrayList(T),
            mutex: compat_mutex.Mutex,
            condition: std.Thread.Condition,
            closed: bool,
            allocator: std.mem.Allocator,

            const Self = @This();

            pub fn init(allocator: std.mem.Allocator) Self {
                return Self{
                    .buffer = .{},
                    .mutex = .{},
                    .condition = .{},
                    .closed = false,
                    .allocator = allocator,
                };
            }

            pub fn deinit(self: *Self) void {
                self.buffer.deinit(self.allocator);
            }

            pub fn send(self: *Self, value: T) !void {
                self.mutex.lock();
                defer self.mutex.unlock();

                if (self.closed) return error.ChannelClosed;

                try self.buffer.append(self.allocator, value);
                self.condition.signal();
            }

            pub fn receive(self: *Self) !T {
                self.mutex.lock();
                defer self.mutex.unlock();

                while (self.buffer.items.len == 0) {
                    if (self.closed) return error.ChannelClosed;
                    self.condition.wait(&self.mutex.inner);
                }

                return self.buffer.orderedRemove(0);
            }

            pub fn tryReceive(self: *Self) ?T {
                self.mutex.lock();
                defer self.mutex.unlock();

                if (self.buffer.items.len == 0) return null;
                return self.buffer.orderedRemove(0);
            }

            pub fn close(self: *Self) void {
                self.mutex.lock();
                defer self.mutex.unlock();

                self.closed = true;
                self.condition.broadcast();
            }
        };
    }
};
