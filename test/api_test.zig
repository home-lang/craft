const std = @import("std");
const testing = std.testing;
const api = @import("../src/api.zig");

test "API version is 0.0.1" {
    try testing.expectEqual(@as(u32, 0), api.current_version.major);
    try testing.expectEqual(@as(u32, 0), api.current_version.minor);
    try testing.expectEqual(@as(u32, 1), api.current_version.patch);
}

test "Result type - Ok variant" {
    const ResultType = api.Result(i32, api.Error);
    const result = ResultType{ .ok = 42 };

    try testing.expect(result == .ok);
    try testing.expectEqual(@as(i32, 42), result.ok);
}

test "Result type - Err variant" {
    const ResultType = api.Result(i32, api.Error);
    const result = ResultType{ .err = api.Error.WindowCreationFailed };

    try testing.expect(result == .err);
    try testing.expectEqual(api.Error.WindowCreationFailed, result.err);
}

test "Result type - unwrap" {
    const ResultType = api.Result(i32, api.Error);
    const result = ResultType{ .ok = 42 };

    try testing.expectEqual(@as(i32, 42), result.unwrap());
}

test "Result type - expect" {
    const ResultType = api.Result(i32, api.Error);
    const result = ResultType{ .ok = 42 };

    try testing.expectEqual(@as(i32, 42), result.expect("Should have value"));
}

test "Result type - isOk and isErr" {
    const ResultType = api.Result(i32, api.Error);
    const ok_result = ResultType{ .ok = 42 };
    const err_result = ResultType{ .err = api.Error.InvalidURL };

    try testing.expect(ok_result.isOk());
    try testing.expect(!ok_result.isErr());
    try testing.expect(!err_result.isOk());
    try testing.expect(err_result.isErr());
}

test "WindowBuilder - basic creation" {
    const builder = api.WindowBuilder.new("Test Window", "http://localhost:3000");

    try testing.expectEqualStrings("Test Window", builder.title);
    try testing.expectEqualStrings("http://localhost:3000", builder.url);
    try testing.expectEqual(@as(u32, 800), builder.width);
    try testing.expectEqual(@as(u32, 600), builder.height);
}

test "WindowBuilder - with custom size" {
    const builder = api.WindowBuilder.new("Test", "http://localhost:3000")
        .size(1200, 800);

    try testing.expectEqual(@as(u32, 1200), builder.width);
    try testing.expectEqual(@as(u32, 800), builder.height);
}

test "WindowBuilder - with position" {
    const builder = api.WindowBuilder.new("Test", "http://localhost:3000")
        .position(100, 200);

    try testing.expectEqual(@as(?i32, 100), builder.x);
    try testing.expectEqual(@as(?i32, 200), builder.y);
}

test "WindowBuilder - fullscreen" {
    const builder = api.WindowBuilder.new("Test", "http://localhost:3000")
        .fullscreen(true);

    try testing.expect(builder.is_fullscreen);
}

test "WindowBuilder - resizable" {
    const builder = api.WindowBuilder.new("Test", "http://localhost:3000")
        .resizable(false);

    try testing.expect(!builder.is_resizable);
}

test "WindowBuilder - frameless" {
    const builder = api.WindowBuilder.new("Test", "http://localhost:3000")
        .frameless(true);

    try testing.expect(builder.is_frameless);
}

test "WindowBuilder - transparent" {
    const builder = api.WindowBuilder.new("Test", "http://localhost:3000")
        .transparent(true);

    try testing.expect(builder.is_transparent);
}

test "WindowBuilder - always on top" {
    const builder = api.WindowBuilder.new("Test", "http://localhost:3000")
        .alwaysOnTop(true);

    try testing.expect(builder.is_always_on_top);
}

test "WindowBuilder - chaining" {
    const builder = api.WindowBuilder.new("Test", "http://localhost:3000")
        .size(1920, 1080)
        .position(0, 0)
        .fullscreen(true)
        .resizable(false)
        .frameless(true)
        .transparent(true)
        .alwaysOnTop(true);

    try testing.expectEqual(@as(u32, 1920), builder.width);
    try testing.expectEqual(@as(u32, 1080), builder.height);
    try testing.expectEqual(@as(?i32, 0), builder.x);
    try testing.expectEqual(@as(?i32, 0), builder.y);
    try testing.expect(builder.is_fullscreen);
    try testing.expect(!builder.is_resizable);
    try testing.expect(builder.is_frameless);
    try testing.expect(builder.is_transparent);
    try testing.expect(builder.is_always_on_top);
}

test "Event - ResizeEvent" {
    const event = api.Event{ .window_resize = .{ .width = 800, .height = 600 } };

    try testing.expect(event == .window_resize);
    try testing.expectEqual(@as(u32, 800), event.window_resize.width);
    try testing.expectEqual(@as(u32, 600), event.window_resize.height);
}

test "Event - KeyEvent" {
    const event = api.Event{ .key_down = .{
        .key = .A,
        .modifiers = .{ .ctrl = true, .shift = false },
    } };

    try testing.expect(event == .key_down);
    try testing.expectEqual(api.KeyCode.A, event.key_down.key);
    try testing.expect(event.key_down.modifiers.ctrl);
    try testing.expect(!event.key_down.modifiers.shift);
}

test "Event - MouseEvent" {
    const event = api.Event{ .mouse_down = .{
        .button = .left,
        .x = 100,
        .y = 200,
        .modifiers = .{},
    } };

    try testing.expect(event == .mouse_down);
    try testing.expectEqual(api.MouseButton.left, event.mouse_down.button);
    try testing.expectEqual(@as(i32, 100), event.mouse_down.x);
    try testing.expectEqual(@as(i32, 200), event.mouse_down.y);
}

test "IPCMessage - request" {
    const payload = api.IPCMessage.Payload{ .string = "test data" };
    const msg = api.IPCMessage.request(1, payload);

    try testing.expectEqual(@as(u64, 1), msg.id);
    try testing.expectEqual(api.IPCMessage.MessageType.request, msg.type);
    try testing.expectEqualStrings("test data", msg.payload.string);
}

test "IPCMessage - response" {
    const payload = api.IPCMessage.Payload{ .int = 42 };
    const msg = api.IPCMessage.response(1, payload);

    try testing.expectEqual(@as(u64, 1), msg.id);
    try testing.expectEqual(api.IPCMessage.MessageType.response, msg.type);
    try testing.expectEqual(@as(i64, 42), msg.payload.int);
}

test "IPCMessage - event" {
    const payload = api.IPCMessage.Payload{ .bool = true };
    const msg = api.IPCMessage.event(payload);

    try testing.expectEqual(api.IPCMessage.MessageType.event, msg.type);
    try testing.expect(msg.payload.bool);
}

test "Promise - basic creation" {
    const allocator = testing.allocator;
    var promise = try api.Promise(i32).init(allocator);
    defer promise.deinit();

    try testing.expectEqual(api.Promise(i32).State.pending, promise.state);
}

test "Promise - resolve" {
    const allocator = testing.allocator;
    var promise = try api.Promise(i32).init(allocator);
    defer promise.deinit();

    promise.resolve(42);

    try testing.expectEqual(api.Promise(i32).State.resolved, promise.state);
    try testing.expectEqual(@as(i32, 42), promise.value.?);
}

test "Promise - reject" {
    const allocator = testing.allocator;
    var promise = try api.Promise(i32).init(allocator);
    defer promise.deinit();

    promise.reject(api.Error.InvalidURL);

    try testing.expectEqual(api.Promise(i32).State.rejected, promise.state);
    try testing.expectEqual(api.Error.InvalidURL, promise.error_value.?);
}

test "Promise - isPending" {
    const allocator = testing.allocator;
    var promise = try api.Promise(i32).init(allocator);
    defer promise.deinit();

    try testing.expect(promise.isPending());

    promise.resolve(42);
    try testing.expect(!promise.isPending());
}

test "Promise - isResolved" {
    const allocator = testing.allocator;
    var promise = try api.Promise(i32).init(allocator);
    defer promise.deinit();

    try testing.expect(!promise.isResolved());

    promise.resolve(42);
    try testing.expect(promise.isResolved());
}

test "Promise - isRejected" {
    const allocator = testing.allocator;
    var promise = try api.Promise(i32).init(allocator);
    defer promise.deinit();

    try testing.expect(!promise.isRejected());

    promise.reject(api.Error.InvalidURL);
    try testing.expect(promise.isRejected());
}

test "KeyCode enum - comprehensive" {
    try testing.expectEqual(api.KeyCode.A, .A);
    try testing.expectEqual(api.KeyCode.Escape, .Escape);
    try testing.expectEqual(api.KeyCode.Enter, .Enter);
    try testing.expectEqual(api.KeyCode.Space, .Space);
    try testing.expectEqual(api.KeyCode.F1, .F1);
}

test "MouseButton enum" {
    try testing.expectEqual(api.MouseButton.left, .left);
    try testing.expectEqual(api.MouseButton.right, .right);
    try testing.expectEqual(api.MouseButton.middle, .middle);
}

test "Modifiers - all false by default" {
    const modifiers = api.Modifiers{};

    try testing.expect(!modifiers.ctrl);
    try testing.expect(!modifiers.alt);
    try testing.expect(!modifiers.shift);
    try testing.expect(!modifiers.meta);
}

test "Modifiers - individual flags" {
    const modifiers = api.Modifiers{
        .ctrl = true,
        .shift = true,
    };

    try testing.expect(modifiers.ctrl);
    try testing.expect(!modifiers.alt);
    try testing.expect(modifiers.shift);
    try testing.expect(!modifiers.meta);
}

test "Error enum - all error types" {
    try testing.expectEqual(api.Error.WindowCreationFailed, .WindowCreationFailed);
    try testing.expectEqual(api.Error.InvalidURL, .InvalidURL);
    try testing.expectEqual(api.Error.InitializationFailed, .InitializationFailed);
    try testing.expectEqual(api.Error.IPCError, .IPCError);
}
