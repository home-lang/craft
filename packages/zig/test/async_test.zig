const std = @import("std");
const testing = std.testing;
const async_mod = @import("../src/async.zig");

// Task tests
var test_context = TestContext{ .value = 0, .executed = false };

const TestContext = struct {
    value: i32,
    executed: bool,
};

fn testTaskFn(ctx: *anyopaque) !void {
    const context: *TestContext = @ptrCast(@alignCast(ctx));
    context.value = 42;
    context.executed = true;
}

fn failingTaskFn(ctx: *anyopaque) !void {
    _ = ctx;
    return error.TestError;
}

test "Task - initialization" {
    var task = async_mod.Task.init(testTaskFn, &test_context);

    try testing.expect(!task.completed);
    try testing.expectEqual(@as(?anyerror!void, null), task.result);
}

test "Task - run successful task" {
    test_context = .{ .value = 0, .executed = false };
    var task = async_mod.Task.init(testTaskFn, &test_context);

    task.run();

    try testing.expect(task.isComplete());
    try testing.expectEqual(@as(i32, 42), test_context.value);
    try testing.expect(test_context.executed);
}

test "Task - run failing task" {
    var task = async_mod.Task.init(failingTaskFn, &test_context);

    task.run();

    try testing.expect(task.isComplete());
    const result = task.getResult();
    try testing.expect(result != null);
}

test "Task - isComplete" {
    test_context = .{ .value = 0, .executed = false };
    var task = async_mod.Task.init(testTaskFn, &test_context);

    try testing.expect(!task.isComplete());

    task.run();

    try testing.expect(task.isComplete());
}

test "Task - getResult" {
    test_context = .{ .value = 0, .executed = false };
    var task = async_mod.Task.init(testTaskFn, &test_context);

    try testing.expectEqual(@as(?anyerror!void, null), task.getResult());

    task.run();

    try testing.expect(task.getResult() != null);
}

// Promise tests
var promise_callback_value: ?[]const u8 = null;
var promise_error_value: ?anyerror = null;

fn promiseCallback(value: []const u8) void {
    promise_callback_value = value;
}

fn promiseErrorCallback(err: anyerror) void {
    promise_error_value = err;
}

test "Promise - initialization" {
    const allocator = testing.allocator;
    var promise = async_mod.Promise.init(allocator);
    defer promise.deinit();

    try testing.expectEqual(async_mod.Promise.State.pending, promise.state);
    try testing.expectEqual(@as(?anyerror![]const u8, null), promise.result);
}

test "Promise - resolve" {
    const allocator = testing.allocator;
    var promise = async_mod.Promise.init(allocator);
    defer promise.deinit();

    promise_callback_value = null;
    try promise.then(promiseCallback);

    promise.resolve("success");

    try testing.expectEqual(async_mod.Promise.State.fulfilled, promise.state);
    try testing.expectEqualStrings("success", promise_callback_value.?);
}

test "Promise - reject" {
    const allocator = testing.allocator;
    var promise = async_mod.Promise.init(allocator);
    defer promise.deinit();

    promise_error_value = null;
    try promise.catch_(promiseErrorCallback);

    promise.reject(error.TestFailure);

    try testing.expectEqual(async_mod.Promise.State.rejected, promise.state);
    try testing.expectEqual(error.TestFailure, promise_error_value.?);
}

test "Promise - then after resolve" {
    const allocator = testing.allocator;
    var promise = async_mod.Promise.init(allocator);
    defer promise.deinit();

    promise.resolve("immediate");

    promise_callback_value = null;
    try promise.then(promiseCallback);

    try testing.expectEqualStrings("immediate", promise_callback_value.?);
}

test "Promise - catch after reject" {
    const allocator = testing.allocator;
    var promise = async_mod.Promise.init(allocator);
    defer promise.deinit();

    promise.reject(error.AlreadyRejected);

    promise_error_value = null;
    try promise.catch_(promiseErrorCallback);

    try testing.expectEqual(error.AlreadyRejected, promise_error_value.?);
}

test "Promise - resolve only once" {
    const allocator = testing.allocator;
    var promise = async_mod.Promise.init(allocator);
    defer promise.deinit();

    promise_callback_value = null;
    try promise.then(promiseCallback);

    promise.resolve("first");
    promise.resolve("second");

    try testing.expectEqualStrings("first", promise_callback_value.?);
}

test "Promise - reject only once" {
    const allocator = testing.allocator;
    var promise = async_mod.Promise.init(allocator);
    defer promise.deinit();

    promise_error_value = null;
    try promise.catch_(promiseErrorCallback);

    promise.reject(error.FirstError);
    promise.reject(error.SecondError);

    try testing.expectEqual(error.FirstError, promise_error_value.?);
}

test "Promise - multiple then callbacks" {
    const allocator = testing.allocator;
    var promise = async_mod.Promise.init(allocator);
    defer promise.deinit();

    var count: usize = 0;
    const counter = struct {
        fn callback(value: []const u8) void {
            _ = value;
            count += 1;
        }
    }.callback;

    try promise.then(counter);
    try promise.then(counter);
    try promise.then(counter);

    promise.resolve("trigger");

    try testing.expectEqual(@as(usize, 3), count);
}

test "Promise - multiple catch callbacks" {
    const allocator = testing.allocator;
    var promise = async_mod.Promise.init(allocator);
    defer promise.deinit();

    var count: usize = 0;
    const counter = struct {
        fn callback(err: anyerror) void {
            _ = err;
            count += 1;
        }
    }.callback;

    try promise.catch_(counter);
    try promise.catch_(counter);

    promise.reject(error.TestError);

    try testing.expectEqual(@as(usize, 2), count);
}

// EventLoop tests
test "EventLoop - initialization" {
    const allocator = testing.allocator;
    var loop = async_mod.EventLoop.init(allocator);
    defer loop.deinit();

    try testing.expect(!loop.running);
    try testing.expectEqual(@as(usize, 0), loop.tasks.items.len);
}

test "EventLoop - submit task" {
    const allocator = testing.allocator;
    var loop = async_mod.EventLoop.init(allocator);
    defer loop.deinit();

    test_context = .{ .value = 0, .executed = false };
    var task = async_mod.Task.init(testTaskFn, &test_context);

    try loop.submit(&task);

    try testing.expectEqual(@as(usize, 1), loop.tasks.items.len);
}

test "EventLoop - stop" {
    const allocator = testing.allocator;
    var loop = async_mod.EventLoop.init(allocator);
    defer loop.deinit();

    loop.running = true;
    loop.stop();

    try testing.expect(!loop.running);
}

// Channel tests
test "Channel - initialization" {
    const allocator = testing.allocator;
    var channel = async_mod.Channels.Channel(i32).init(allocator);
    defer channel.deinit();

    try testing.expect(!channel.closed);
    try testing.expectEqual(@as(usize, 0), channel.buffer.items.len);
}

test "Channel - send and receive" {
    const allocator = testing.allocator;
    var channel = async_mod.Channels.Channel(i32).init(allocator);
    defer channel.deinit();

    try channel.send(42);

    const value = try channel.receive();
    try testing.expectEqual(@as(i32, 42), value);
}

test "Channel - tryReceive empty" {
    const allocator = testing.allocator;
    var channel = async_mod.Channels.Channel(i32).init(allocator);
    defer channel.deinit();

    const value = channel.tryReceive();
    try testing.expectEqual(@as(?i32, null), value);
}

test "Channel - tryReceive with data" {
    const allocator = testing.allocator;
    var channel = async_mod.Channels.Channel(i32).init(allocator);
    defer channel.deinit();

    try channel.send(100);

    const value = channel.tryReceive();
    try testing.expectEqual(@as(i32, 100), value.?);
}

test "Channel - close" {
    const allocator = testing.allocator;
    var channel = async_mod.Channels.Channel(i32).init(allocator);
    defer channel.deinit();

    channel.close();

    try testing.expect(channel.closed);
}

test "Channel - send to closed channel" {
    const allocator = testing.allocator;
    var channel = async_mod.Channels.Channel(i32).init(allocator);
    defer channel.deinit();

    channel.close();

    const result = channel.send(42);
    try testing.expectError(error.ChannelClosed, result);
}

test "Channel - receive from closed empty channel" {
    const allocator = testing.allocator;
    var channel = async_mod.Channels.Channel(i32).init(allocator);
    defer channel.deinit();

    channel.close();

    const result = channel.receive();
    try testing.expectError(error.ChannelClosed, result);
}

test "Channel - FIFO order" {
    const allocator = testing.allocator;
    var channel = async_mod.Channels.Channel(i32).init(allocator);
    defer channel.deinit();

    try channel.send(1);
    try channel.send(2);
    try channel.send(3);

    try testing.expectEqual(@as(i32, 1), try channel.receive());
    try testing.expectEqual(@as(i32, 2), try channel.receive());
    try testing.expectEqual(@as(i32, 3), try channel.receive());
}

test "Channel - string type" {
    const allocator = testing.allocator;
    var channel = async_mod.Channels.Channel([]const u8).init(allocator);
    defer channel.deinit();

    try channel.send("hello");
    try channel.send("world");

    try testing.expectEqualStrings("hello", try channel.receive());
    try testing.expectEqualStrings("world", try channel.receive());
}

test "Channel - struct type" {
    const Point = struct { x: i32, y: i32 };

    const allocator = testing.allocator;
    var channel = async_mod.Channels.Channel(Point).init(allocator);
    defer channel.deinit();

    try channel.send(.{ .x = 10, .y = 20 });

    const point = try channel.receive();
    try testing.expectEqual(@as(i32, 10), point.x);
    try testing.expectEqual(@as(i32, 20), point.y);
}

test "Channel - multiple sends before receive" {
    const allocator = testing.allocator;
    var channel = async_mod.Channels.Channel(i32).init(allocator);
    defer channel.deinit();

    try channel.send(1);
    try channel.send(2);
    try channel.send(3);
    try channel.send(4);
    try channel.send(5);

    try testing.expectEqual(@as(usize, 5), channel.buffer.items.len);

    _ = try channel.receive();
    try testing.expectEqual(@as(usize, 4), channel.buffer.items.len);
}
