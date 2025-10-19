const std = @import("std");
const testing = std.testing;
const bridge = @import("../src/bridge.zig");

test "Bridge - init and deinit" {
    var b = bridge.Bridge.init(testing.allocator);
    defer b.deinit();

    try testing.expectEqual(@as(usize, 0), b.handlers.count());
}

test "Bridge - registerHandler" {
    var b = bridge.Bridge.init(testing.allocator);
    defer b.deinit();

    const testHandler = struct {
        fn handler(message: []const u8) anyerror![]const u8 {
            _ = message;
            return "test response";
        }
    }.handler;

    try b.registerHandler("test", testHandler);

    try testing.expectEqual(@as(usize, 1), b.handlers.count());
    try testing.expect(b.handlers.contains("test"));
}

test "Bridge - registerHandler multiple" {
    var b = bridge.Bridge.init(testing.allocator);
    defer b.deinit();

    const handler1 = struct {
        fn handler(message: []const u8) anyerror![]const u8 {
            _ = message;
            return "handler1";
        }
    }.handler;

    const handler2 = struct {
        fn handler(message: []const u8) anyerror![]const u8 {
            _ = message;
            return "handler2";
        }
    }.handler;

    try b.registerHandler("handler1", handler1);
    try b.registerHandler("handler2", handler2);

    try testing.expectEqual(@as(usize, 2), b.handlers.count());
    try testing.expect(b.handlers.contains("handler1"));
    try testing.expect(b.handlers.contains("handler2"));
}

test "Bridge - handleMessage success" {
    var b = bridge.Bridge.init(testing.allocator);
    defer b.deinit();

    const testHandler = struct {
        fn handler(message: []const u8) anyerror![]const u8 {
            _ = message;
            return "test response";
        }
    }.handler;

    try b.registerHandler("test", testHandler);

    const response = try b.handleMessage("test", "test message");
    try testing.expectEqualStrings("test response", response);
}

test "Bridge - handleMessage not found" {
    var b = bridge.Bridge.init(testing.allocator);
    defer b.deinit();

    const result = b.handleMessage("nonexistent", "test message");
    try testing.expectError(error.HandlerNotFound, result);
}

test "Bridge - handleMessage with data" {
    var b = bridge.Bridge.init(testing.allocator);
    defer b.deinit();

    const echoHandler = struct {
        fn handler(message: []const u8) anyerror![]const u8 {
            return message;
        }
    }.handler;

    try b.registerHandler("echo", echoHandler);

    const response = try b.handleMessage("echo", "Hello, World!");
    try testing.expectEqualStrings("Hello, World!", response);
}

test "Bridge - generateInjectionScript" {
    var b = bridge.Bridge.init(testing.allocator);
    defer b.deinit();

    const script = try b.generateInjectionScript();

    try testing.expect(script.len > 0);
    try testing.expect(std.mem.indexOf(u8, script, "window.zyte") != null);
    try testing.expect(std.mem.indexOf(u8, script, "send:") != null);
    try testing.expect(std.mem.indexOf(u8, script, "notify:") != null);
    try testing.expect(std.mem.indexOf(u8, script, "readFile:") != null);
    try testing.expect(std.mem.indexOf(u8, script, "writeFile:") != null);
    try testing.expect(std.mem.indexOf(u8, script, "openDialog:") != null);
    try testing.expect(std.mem.indexOf(u8, script, "getClipboard:") != null);
    try testing.expect(std.mem.indexOf(u8, script, "setClipboard:") != null);
    try testing.expect(std.mem.indexOf(u8, script, "zyte:ready") != null);
}

test "Bridge - notifyHandler" {
    const result = try bridge.notifyHandler("test notification");
    try testing.expectEqualStrings("OK", result);
}

test "Bridge - readFileHandler" {
    const result = try bridge.readFileHandler("test path");
    try testing.expectEqualStrings("File contents here", result);
}

test "Bridge - writeFileHandler" {
    const result = try bridge.writeFileHandler("test data");
    try testing.expectEqualStrings("OK", result);
}

test "Bridge - handler replacement" {
    var b = bridge.Bridge.init(testing.allocator);
    defer b.deinit();

    const handler1 = struct {
        fn handler(message: []const u8) anyerror![]const u8 {
            _ = message;
            return "first";
        }
    }.handler;

    const handler2 = struct {
        fn handler(message: []const u8) anyerror![]const u8 {
            _ = message;
            return "second";
        }
    }.handler;

    try b.registerHandler("test", handler1);
    const response1 = try b.handleMessage("test", "msg");
    try testing.expectEqualStrings("first", response1);

    try b.registerHandler("test", handler2);
    const response2 = try b.handleMessage("test", "msg");
    try testing.expectEqualStrings("second", response2);

    try testing.expectEqual(@as(usize, 1), b.handlers.count());
}

test "MessageHandler - type definition" {
    const testHandler: bridge.MessageHandler = struct {
        fn handler(message: []const u8) anyerror![]const u8 {
            _ = message;
            return "response";
        }
    }.handler;

    const result = try testHandler("test");
    try testing.expectEqualStrings("response", result);
}
