const std = @import("std");
const testing = std.testing;
const android = @import("../src/android.zig");

// ============================================================================
// JNI Types Tests
// ============================================================================

test "JNI - type definitions" {
    // Verify JNI type sizes match expected values
    try testing.expectEqual(@as(usize, @sizeOf(i32)), @sizeOf(android.jni.jint));
    try testing.expectEqual(@as(usize, @sizeOf(i64)), @sizeOf(android.jni.jlong));
    try testing.expectEqual(@as(usize, @sizeOf(u8)), @sizeOf(android.jni.jboolean));
    try testing.expectEqual(@as(usize, @sizeOf(f32)), @sizeOf(android.jni.jfloat));
    try testing.expectEqual(@as(usize, @sizeOf(f64)), @sizeOf(android.jni.jdouble));
}

// ============================================================================
// CraftActivity Tests
// ============================================================================

test "CraftActivity - Theme enum" {
    try testing.expectEqual(android.CraftActivity.Theme.light, .light);
    try testing.expectEqual(android.CraftActivity.Theme.dark, .dark);
    try testing.expectEqual(android.CraftActivity.Theme.system, .system);
}

test "CraftActivity - Orientation enum" {
    try testing.expectEqual(android.CraftActivity.Orientation.portrait, .portrait);
    try testing.expectEqual(android.CraftActivity.Orientation.landscape, .landscape);
    try testing.expectEqual(android.CraftActivity.Orientation.sensor, .sensor);
    try testing.expectEqual(android.CraftActivity.Orientation.unspecified, .unspecified);
}

test "CraftActivity - Content union" {
    const html_content = android.CraftActivity.Content{ .html = "<h1>Hello</h1>" };
    const url_content = android.CraftActivity.Content{ .url = "https://example.com" };
    const asset_content = android.CraftActivity.Content{ .asset = "index.html" };

    switch (html_content) {
        .html => |h| try testing.expectEqualStrings("<h1>Hello</h1>", h),
        else => return error.UnexpectedContent,
    }

    switch (url_content) {
        .url => |u| try testing.expectEqualStrings("https://example.com", u),
        else => return error.UnexpectedContent,
    }

    switch (asset_content) {
        .asset => |a| try testing.expectEqualStrings("index.html", a),
        else => return error.UnexpectedContent,
    }
}

test "CraftActivity - ActivityConfig defaults" {
    const config = android.CraftActivity.ActivityConfig{};

    try testing.expectEqualStrings("Craft App", config.name);
    try testing.expectEqualStrings("com.craft.app", config.package_name);
    try testing.expectEqual(android.CraftActivity.Theme.light, config.theme);
    try testing.expectEqual(android.CraftActivity.Orientation.portrait, config.orientation);
    try testing.expect(!config.fullscreen);
    try testing.expect(config.hardware_accelerated);
    try testing.expect(config.enable_javascript);
    try testing.expect(config.enable_dom_storage);
    try testing.expect(!config.allow_file_access);
    try testing.expect(!config.enable_inspector);
}

test "CraftActivity - ActivityConfig custom" {
    const config = android.CraftActivity.ActivityConfig{
        .name = "My App",
        .package_name = "com.example.myapp",
        .theme = .dark,
        .orientation = .landscape,
        .fullscreen = true,
        .enable_inspector = true,
        .allow_file_access = true,
    };

    try testing.expectEqualStrings("My App", config.name);
    try testing.expectEqualStrings("com.example.myapp", config.package_name);
    try testing.expectEqual(android.CraftActivity.Theme.dark, config.theme);
    try testing.expectEqual(android.CraftActivity.Orientation.landscape, config.orientation);
    try testing.expect(config.fullscreen);
    try testing.expect(config.enable_inspector);
    try testing.expect(config.allow_file_access);
}

test "CraftActivity - init" {
    const config = android.CraftActivity.ActivityConfig{
        .name = "Test App",
        .package_name = "com.test.app",
        .initial_content = .{ .html = "<h1>Test</h1>" },
    };

    const activity = android.CraftActivity.init(testing.allocator, config);

    try testing.expectEqualStrings("Test App", activity.config.name);
    try testing.expectEqualStrings("com.test.app", activity.config.package_name);
    try testing.expect(activity.js_bridge == null);
    try testing.expect(activity.webview == null);
    try testing.expect(activity.on_create == null);
    try testing.expect(activity.on_resume == null);
    try testing.expect(activity.on_pause == null);
    try testing.expect(activity.on_destroy == null);
    try testing.expect(activity.on_back_pressed == null);
}

test "CraftActivity - lifecycle callbacks" {
    var activity = android.CraftActivity.init(testing.allocator, .{});

    var create_called = false;
    var resume_called = false;
    var pause_called = false;
    var destroy_called = false;

    const Callbacks = struct {
        var create_flag: *bool = undefined;
        var resume_flag: *bool = undefined;
        var pause_flag: *bool = undefined;
        var destroy_flag: *bool = undefined;

        fn onCreate() void {
            create_flag.* = true;
        }
        fn onResume() void {
            resume_flag.* = true;
        }
        fn onPause() void {
            pause_flag.* = true;
        }
        fn onDestroy() void {
            destroy_flag.* = true;
        }
    };

    Callbacks.create_flag = &create_called;
    Callbacks.resume_flag = &resume_called;
    Callbacks.pause_flag = &pause_called;
    Callbacks.destroy_flag = &destroy_called;

    activity.onCreate(Callbacks.onCreate);
    activity.onResume(Callbacks.onResume);
    activity.onPause(Callbacks.onPause);
    activity.onDestroy(Callbacks.onDestroy);

    try testing.expect(activity.on_create != null);
    try testing.expect(activity.on_resume != null);
    try testing.expect(activity.on_pause != null);
    try testing.expect(activity.on_destroy != null);

    // Invoke callbacks
    if (activity.on_create) |cb| cb();
    if (activity.on_resume) |cb| cb();
    if (activity.on_pause) |cb| cb();
    if (activity.on_destroy) |cb| cb();

    try testing.expect(create_called);
    try testing.expect(resume_called);
    try testing.expect(pause_called);
    try testing.expect(destroy_called);
}

test "CraftActivity - onBackPressed callback" {
    var activity = android.CraftActivity.init(testing.allocator, .{});

    const Callback = struct {
        fn onBackPressed() bool {
            return true; // Consume event
        }
    };

    activity.onBackPressed(Callback.onBackPressed);
    try testing.expect(activity.on_back_pressed != null);

    if (activity.on_back_pressed) |cb| {
        const consumed = cb();
        try testing.expect(consumed);
    }
}

// ============================================================================
// JSBridge Tests
// ============================================================================

test "JSBridge - init and deinit" {
    var bridge = android.JSBridge.init(testing.allocator);
    defer bridge.deinit();

    try testing.expect(bridge.activity == null);
    // Built-in handlers should be registered
    try testing.expect(bridge.handlers.get("getPlatform") != null);
    try testing.expect(bridge.handlers.get("showToast") != null);
    try testing.expect(bridge.handlers.get("vibrate") != null);
    try testing.expect(bridge.handlers.get("setClipboard") != null);
    try testing.expect(bridge.handlers.get("getClipboard") != null);
    try testing.expect(bridge.handlers.get("share") != null);
    try testing.expect(bridge.handlers.get("openURL") != null);
    try testing.expect(bridge.handlers.get("getNetworkStatus") != null);
    try testing.expect(bridge.handlers.get("showAlert") != null);
}

test "JSBridge - registerHandler" {
    var bridge = android.JSBridge.init(testing.allocator);
    defer bridge.deinit();

    const handler = struct {
        fn handle(_: []const u8, _: *android.JSBridge, _: []const u8) void {}
    }.handle;

    try bridge.registerHandler("customHandler", handler);
    try testing.expect(bridge.handlers.get("customHandler") != null);
}

test "JSBridge - registerHandler overwrites" {
    var bridge = android.JSBridge.init(testing.allocator);
    defer bridge.deinit();

    const handler1 = struct {
        fn handle(_: []const u8, _: *android.JSBridge, _: []const u8) void {}
    }.handle;

    const handler2 = struct {
        fn handle(_: []const u8, _: *android.JSBridge, _: []const u8) void {}
    }.handle;

    try bridge.registerHandler("test", handler1);
    try bridge.registerHandler("test", handler2);

    // Should not error, just overwrite
    try testing.expect(bridge.handlers.get("test") != null);
}

test "JSBridge - handleMessage with unknown method" {
    var bridge = android.JSBridge.init(testing.allocator);
    defer bridge.deinit();

    // This should not crash, just silently fail (no activity to send error)
    bridge.handleMessage("{\"method\":\"unknownMethod\",\"callbackId\":\"123\",\"params\":{}}");
}

test "JSBridge - handleMessage with getPlatform" {
    var bridge = android.JSBridge.init(testing.allocator);
    defer bridge.deinit();

    // This should not crash (no activity to send response, but handler runs)
    bridge.handleMessage("{\"method\":\"getPlatform\",\"callbackId\":\"456\",\"params\":{}}");
}

// ============================================================================
// AndroidFeatures Tests
// ============================================================================

test "AndroidFeatures - DeviceInfo struct" {
    const info = android.AndroidFeatures.DeviceInfo{
        .manufacturer = "Samsung",
        .model = "Galaxy S21",
        .os_version = "13",
        .sdk_version = 33,
    };

    try testing.expectEqualStrings("Samsung", info.manufacturer);
    try testing.expectEqualStrings("Galaxy S21", info.model);
    try testing.expectEqualStrings("13", info.os_version);
    try testing.expectEqual(@as(i32, 33), info.sdk_version);
}

test "AndroidFeatures - getDeviceInfo" {
    const info = android.AndroidFeatures.getDeviceInfo();

    // Returns default values in non-Android environment
    try testing.expectEqualStrings("Unknown", info.manufacturer);
    try testing.expectEqualStrings("Android Device", info.model);
    try testing.expectEqualStrings("14", info.os_version);
    try testing.expectEqual(@as(i32, 34), info.sdk_version);
}

test "AndroidFeatures - isNetworkConnected" {
    // Returns true by default in non-Android environment
    const connected = android.AndroidFeatures.isNetworkConnected();
    try testing.expect(connected);
}

test "AndroidFeatures - hasPermission" {
    // Returns false by default in non-Android environment
    const has_camera = android.AndroidFeatures.hasPermission("android.permission.CAMERA");
    try testing.expect(!has_camera);
}

test "AndroidFeatures - getClipboard" {
    // Returns empty string in non-Android environment
    const text = try android.AndroidFeatures.getClipboard(testing.allocator);
    try testing.expectEqualStrings("", text);
}

// ============================================================================
// Quick Start Helper Tests
// ============================================================================

test "quickStart function exists" {
    // Just verify the function signature compiles
    const func = android.quickStart;
    try testing.expect(@TypeOf(func) == fn (std.mem.Allocator, []const u8) anyerror!void);
}

// ============================================================================
// Integration Tests
// ============================================================================

test "CraftActivity - full lifecycle simulation" {
    var activity = android.CraftActivity.init(testing.allocator, .{
        .name = "Integration Test App",
        .package_name = "com.test.integration",
        .initial_content = .{ .html = "<h1>Test</h1>" },
        .theme = .system,
        .orientation = .sensor,
    });
    defer activity.deinit();

    // Set up all lifecycle callbacks
    var lifecycle_order = std.ArrayList([]const u8).init(testing.allocator);
    defer lifecycle_order.deinit();

    // Note: We can't easily test the actual callback invocation order
    // without modifying the activity internals, so we just verify setup
    try testing.expectEqualStrings("Integration Test App", activity.config.name);
    try testing.expectEqual(android.CraftActivity.Theme.system, activity.config.theme);
    try testing.expectEqual(android.CraftActivity.Orientation.sensor, activity.config.orientation);
}

test "JSBridge - message parsing" {
    var bridge = android.JSBridge.init(testing.allocator);
    defer bridge.deinit();

    // Test with various JSON formats
    const messages = [_][]const u8{
        "{\"method\":\"getPlatform\",\"callbackId\":\"1\",\"params\":{}}",
        "{\"method\":\"showToast\",\"callbackId\":\"2\",\"params\":{\"message\":\"Hello\"}}",
        "{\"method\":\"vibrate\",\"callbackId\":\"3\",\"params\":{\"duration\":100}}",
    };

    for (messages) |msg| {
        // Should not crash
        bridge.handleMessage(msg);
    }
}

test "Activity with JSBridge integration" {
    var activity = android.CraftActivity.init(testing.allocator, .{
        .name = "Bridge Test",
    });
    defer activity.deinit();

    // Run initializes the bridge
    try activity.run();

    // Bridge should now be available
    try testing.expect(activity.js_bridge != null);

    if (activity.getBridge()) |bridge| {
        // Register custom handler
        const handler = struct {
            fn handle(_: []const u8, b: *android.JSBridge, callback_id: []const u8) void {
                b.sendResponse(callback_id, "{}") catch {};
            }
        }.handle;

        try bridge.registerHandler("customTest", handler);
        try testing.expect(bridge.handlers.get("customTest") != null);
    }
}
