const std = @import("std");
const testing = std.testing;
const events = @import("../src/events.zig");

// EventType tests
test "EventType - window events" {
    try testing.expectEqual(events.EventType.window_created, .window_created);
    try testing.expectEqual(events.EventType.window_closed, .window_closed);
    try testing.expectEqual(events.EventType.window_resized, .window_resized);
    try testing.expectEqual(events.EventType.window_moved, .window_moved);
    try testing.expectEqual(events.EventType.window_focused, .window_focused);
    try testing.expectEqual(events.EventType.window_blurred, .window_blurred);
    try testing.expectEqual(events.EventType.window_minimized, .window_minimized);
    try testing.expectEqual(events.EventType.window_maximized, .window_maximized);
    try testing.expectEqual(events.EventType.window_restored, .window_restored);
}

test "EventType - application events" {
    try testing.expectEqual(events.EventType.app_started, .app_started);
    try testing.expectEqual(events.EventType.app_stopped, .app_stopped);
    try testing.expectEqual(events.EventType.app_paused, .app_paused);
    try testing.expectEqual(events.EventType.app_resumed, .app_resumed);
}

test "EventType - webview events" {
    try testing.expectEqual(events.EventType.webview_loaded, .webview_loaded);
    try testing.expectEqual(events.EventType.webview_failed, .webview_failed);
    try testing.expectEqual(events.EventType.webview_navigating, .webview_navigating);
}

test "EventType - custom events" {
    try testing.expectEqual(events.EventType.custom, .custom);
}

// Event struct tests
test "Event - basic creation" {
    const event = events.Event{
        .event_type = .window_created,
        .timestamp = 1234567890,
    };

    try testing.expectEqual(events.EventType.window_created, event.event_type);
    try testing.expectEqual(@as(i64, 1234567890), event.timestamp);
    try testing.expectEqual(@as(?*anyopaque, null), event.data);
    try testing.expectEqual(@as(?[]const u8, null), event.custom_name);
}

test "Event - with custom name" {
    const event = events.Event{
        .event_type = .custom,
        .timestamp = 1234567890,
        .custom_name = "my-custom-event",
    };

    try testing.expectEqual(events.EventType.custom, event.event_type);
    try testing.expectEqualStrings("my-custom-event", event.custom_name.?);
}

test "Event - with data" {
    var data: i32 = 42;
    const event = events.Event{
        .event_type = .window_resized,
        .timestamp = 1234567890,
        .data = @ptrCast(&data),
    };

    try testing.expect(event.data != null);
    const retrieved_data: *i32 = @ptrCast(@alignCast(event.data.?));
    try testing.expectEqual(@as(i32, 42), retrieved_data.*);
}

// EventEmitter tests
var callback_count: usize = 0;
var last_event: ?events.Event = null;

fn testCallback(event: events.Event) void {
    callback_count += 1;
    last_event = event;
}

fn testCallback2(event: events.Event) void {
    _ = event;
    callback_count += 1;
}

test "EventEmitter - initialization" {
    const allocator = testing.allocator;
    var emitter = events.EventEmitter.init(allocator);
    defer emitter.deinit();

    try testing.expectEqual(@as(usize, 0), emitter.listeners.count());
}

test "EventEmitter - on" {
    const allocator = testing.allocator;
    var emitter = events.EventEmitter.init(allocator);
    defer emitter.deinit();

    try emitter.on("test-event", testCallback);

    const callbacks = emitter.listeners.get("test-event");
    try testing.expect(callbacks != null);
    try testing.expectEqual(@as(usize, 1), callbacks.?.items.len);
}

test "EventEmitter - multiple listeners" {
    const allocator = testing.allocator;
    var emitter = events.EventEmitter.init(allocator);
    defer emitter.deinit();

    try emitter.on("test-event", testCallback);
    try emitter.on("test-event", testCallback2);

    const callbacks = emitter.listeners.get("test-event");
    try testing.expectEqual(@as(usize, 2), callbacks.?.items.len);
}

test "EventEmitter - off" {
    const allocator = testing.allocator;
    var emitter = events.EventEmitter.init(allocator);
    defer emitter.deinit();

    try emitter.on("test-event", testCallback);
    try emitter.on("test-event", testCallback2);

    const removed = emitter.off("test-event", testCallback);
    try testing.expect(removed);

    const callbacks = emitter.listeners.get("test-event");
    try testing.expectEqual(@as(usize, 1), callbacks.?.items.len);
}

test "EventEmitter - off non-existent callback" {
    const allocator = testing.allocator;
    var emitter = events.EventEmitter.init(allocator);
    defer emitter.deinit();

    const removed = emitter.off("test-event", testCallback);
    try testing.expect(!removed);
}

test "EventEmitter - off non-existent event" {
    const allocator = testing.allocator;
    var emitter = events.EventEmitter.init(allocator);
    defer emitter.deinit();

    try emitter.on("event1", testCallback);

    const removed = emitter.off("event2", testCallback);
    try testing.expect(!removed);
}

test "EventEmitter - emit" {
    const allocator = testing.allocator;
    var emitter = events.EventEmitter.init(allocator);
    defer emitter.deinit();

    callback_count = 0;
    last_event = null;

    try emitter.on("window_created", testCallback);

    const event = events.Event{
        .event_type = .window_created,
        .timestamp = 1234567890,
    };

    emitter.emit(event);

    try testing.expectEqual(@as(usize, 1), callback_count);
    try testing.expect(last_event != null);
    try testing.expectEqual(events.EventType.window_created, last_event.?.event_type);
}

test "EventEmitter - emit with multiple listeners" {
    const allocator = testing.allocator;
    var emitter = events.EventEmitter.init(allocator);
    defer emitter.deinit();

    callback_count = 0;

    try emitter.on("test-event", testCallback);
    try emitter.on("test-event", testCallback2);

    const event = events.Event{
        .event_type = .custom,
        .timestamp = 1234567890,
        .custom_name = "test-event",
    };

    emitter.emit(event);

    try testing.expectEqual(@as(usize, 2), callback_count);
}

test "EventEmitter - emit to event with no listeners" {
    const allocator = testing.allocator;
    var emitter = events.EventEmitter.init(allocator);
    defer emitter.deinit();

    callback_count = 0;

    const event = events.Event{
        .event_type = .window_created,
        .timestamp = 1234567890,
    };

    emitter.emit(event);

    try testing.expectEqual(@as(usize, 0), callback_count);
}

test "EventEmitter - emit custom event" {
    const allocator = testing.allocator;
    var emitter = events.EventEmitter.init(allocator);
    defer emitter.deinit();

    callback_count = 0;
    last_event = null;

    try emitter.on("my-custom-event", testCallback);

    const event = events.Event{
        .event_type = .custom,
        .timestamp = 1234567890,
        .custom_name = "my-custom-event",
    };

    emitter.emit(event);

    try testing.expectEqual(@as(usize, 1), callback_count);
    try testing.expect(last_event != null);
}

test "EventEmitter - emit custom event without name" {
    const allocator = testing.allocator;
    var emitter = events.EventEmitter.init(allocator);
    defer emitter.deinit();

    callback_count = 0;

    try emitter.on("custom", testCallback);

    const event = events.Event{
        .event_type = .custom,
        .timestamp = 1234567890,
        .custom_name = null,
    };

    emitter.emit(event);

    // Should not trigger callback since custom_name is null
    try testing.expectEqual(@as(usize, 0), callback_count);
}

test "EventEmitter - multiple events" {
    const allocator = testing.allocator;
    var emitter = events.EventEmitter.init(allocator);
    defer emitter.deinit();

    callback_count = 0;

    try emitter.on("window_created", testCallback);
    try emitter.on("window_closed", testCallback2);

    const event1 = events.Event{
        .event_type = .window_created,
        .timestamp = 1234567890,
    };

    const event2 = events.Event{
        .event_type = .window_closed,
        .timestamp = 1234567891,
    };

    emitter.emit(event1);
    emitter.emit(event2);

    try testing.expectEqual(@as(usize, 2), callback_count);
}

// Global counters for callback testing (must be at module level)
var global_event_count1: usize = 0;
var global_event_count2: usize = 0;

fn eventCounter1Callback(event: events.Event) void {
    _ = event;
    global_event_count1 += 1;
}

fn eventCounter2Callback(event: events.Event) void {
    _ = event;
    global_event_count2 += 1;
}

test "EventEmitter - different event types" {
    const allocator = testing.allocator;
    var emitter = events.EventEmitter.init(allocator);
    defer emitter.deinit();

    global_event_count1 = 0;
    global_event_count2 = 0;

    try emitter.on("app_started", eventCounter1Callback);
    try emitter.on("app_stopped", eventCounter2Callback);

    const event1 = events.Event{
        .event_type = .app_started,
        .timestamp = 1,
    };

    const event2 = events.Event{
        .event_type = .app_stopped,
        .timestamp = 2,
    };

    emitter.emit(event1);
    emitter.emit(event1);
    emitter.emit(event2);

    try testing.expectEqual(@as(usize, 2), global_event_count1);
    try testing.expectEqual(@as(usize, 1), global_event_count2);
}

test "EventEmitter - window events" {
    const allocator = testing.allocator;
    var emitter = events.EventEmitter.init(allocator);
    defer emitter.deinit();

    callback_count = 0;

    try emitter.on("window_resized", testCallback);
    try emitter.on("window_moved", testCallback);
    try emitter.on("window_focused", testCallback);

    emitter.emit(.{ .event_type = .window_resized, .timestamp = 1 });
    emitter.emit(.{ .event_type = .window_moved, .timestamp = 2 });
    emitter.emit(.{ .event_type = .window_focused, .timestamp = 3 });

    try testing.expectEqual(@as(usize, 3), callback_count);
}

test "EventEmitter - application lifecycle events" {
    const allocator = testing.allocator;
    var emitter = events.EventEmitter.init(allocator);
    defer emitter.deinit();

    callback_count = 0;

    try emitter.on("app_started", testCallback);
    try emitter.on("app_paused", testCallback);
    try emitter.on("app_resumed", testCallback);
    try emitter.on("app_stopped", testCallback);

    emitter.emit(.{ .event_type = .app_started, .timestamp = 1 });
    emitter.emit(.{ .event_type = .app_paused, .timestamp = 2 });
    emitter.emit(.{ .event_type = .app_resumed, .timestamp = 3 });
    emitter.emit(.{ .event_type = .app_stopped, .timestamp = 4 });

    try testing.expectEqual(@as(usize, 4), callback_count);
}

test "EventEmitter - webview events" {
    const allocator = testing.allocator;
    var emitter = events.EventEmitter.init(allocator);
    defer emitter.deinit();

    callback_count = 0;

    try emitter.on("webview_loaded", testCallback);
    try emitter.on("webview_failed", testCallback);
    try emitter.on("webview_navigating", testCallback);

    emitter.emit(.{ .event_type = .webview_loaded, .timestamp = 1 });
    emitter.emit(.{ .event_type = .webview_failed, .timestamp = 2 });
    emitter.emit(.{ .event_type = .webview_navigating, .timestamp = 3 });

    try testing.expectEqual(@as(usize, 3), callback_count);
}

// Global emitter tests
test "Global emitter - init and deinit" {
    const allocator = testing.allocator;

    events.initGlobalEmitter(allocator);
    defer events.deinitGlobalEmitter();
}

test "Global emitter - on and emit" {
    const allocator = testing.allocator;

    events.initGlobalEmitter(allocator);
    defer events.deinitGlobalEmitter();

    callback_count = 0;

    try events.on("window_created", testCallback);

    events.emit(.{ .event_type = .window_created, .timestamp = 1 });

    try testing.expectEqual(@as(usize, 1), callback_count);
}

test "Global emitter - off" {
    const allocator = testing.allocator;

    events.initGlobalEmitter(allocator);
    defer events.deinitGlobalEmitter();

    callback_count = 0;

    try events.on("test-event", testCallback);

    const removed = events.off("test-event", testCallback);
    try testing.expect(removed);

    events.emit(.{ .event_type = .custom, .timestamp = 1, .custom_name = "test-event" });

    try testing.expectEqual(@as(usize, 0), callback_count);
}

test "Global emitter - multiple events" {
    const allocator = testing.allocator;

    events.initGlobalEmitter(allocator);
    defer events.deinitGlobalEmitter();

    callback_count = 0;

    try events.on("app_started", testCallback);
    try events.on("app_stopped", testCallback);

    events.emit(.{ .event_type = .app_started, .timestamp = 1 });
    events.emit(.{ .event_type = .app_stopped, .timestamp = 2 });

    try testing.expectEqual(@as(usize, 2), callback_count);
}

test "Global emitter - without initialization" {
    callback_count = 0;

    try events.on("test", testCallback);
    events.emit(.{ .event_type = .custom, .timestamp = 1, .custom_name = "test" });
    const removed = events.off("test", testCallback);

    // Should not crash even when global emitter is not initialized
    try testing.expect(!removed);
    try testing.expectEqual(@as(usize, 0), callback_count);
}
