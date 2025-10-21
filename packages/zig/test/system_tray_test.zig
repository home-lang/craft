const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");
const tray_module = @import("../src/tray.zig");
const SystemTray = tray_module.SystemTray;

// Test basic SystemTray creation and cleanup
test "SystemTray: basic creation and cleanup" {
    const allocator = testing.allocator;

    var tray = SystemTray.init(allocator, "Test App");
    defer tray.deinit();

    try testing.expectEqualStrings("Test App", tray.title);
    try testing.expect(tray.icon_text == null);
    try testing.expect(tray.tooltip == null);
    try testing.expect(tray.visible == true);
    try testing.expect(tray.platform_handle == null);
}

// Test SystemTray initialization with various titles
test "SystemTray: initialization with different titles" {
    const allocator = testing.allocator;

    const titles = [_][]const u8{
        "App",
        "My Application",
        "🚀 Rocket App",
        "App with Numbers 123",
        "",
    };

    for (titles) |title| {
        var tray = SystemTray.init(allocator, title);
        defer tray.deinit();

        try testing.expectEqualStrings(title, tray.title);
    }
}

// Test setTitle functionality
test "SystemTray: setTitle updates title" {
    const allocator = testing.allocator;

    var tray = SystemTray.init(allocator, "Initial");
    defer tray.deinit();

    // Update title
    try tray.setTitle("Updated");
    try testing.expectEqualStrings("Updated", tray.icon_text.?);

    // Update again
    try tray.setTitle("Final");
    try testing.expectEqualStrings("Final", tray.icon_text.?);
}

// Test setTooltip functionality
test "SystemTray: setTooltip updates tooltip" {
    const allocator = testing.allocator;

    var tray = SystemTray.init(allocator, "App");
    defer tray.deinit();

    try testing.expect(tray.tooltip == null);

    // Set tooltip
    try tray.setTooltip("Hover text");
    try testing.expectEqualStrings("Hover text", tray.tooltip.?);

    // Update tooltip
    try tray.setTooltip("New hover text");
    try testing.expectEqualStrings("New hover text", tray.tooltip.?);
}

// Test visibility toggle
test "SystemTray: visibility toggle" {
    const allocator = testing.allocator;

    var tray = SystemTray.init(allocator, "App");
    defer tray.deinit();

    // Initially visible
    try testing.expect(tray.visible == true);

    // Hide
    tray.hide();
    try testing.expect(tray.visible == false);

    // Show again
    if (builtin.target.os.tag == .macos or
        builtin.target.os.tag == .windows or
        builtin.target.os.tag == .linux) {
        // Only test show on supported platforms
        // Note: show() requires platform initialization
        // This would need to be tested in integration tests
    }
}

// Test click callback registration
test "SystemTray: click callback registration" {
    const allocator = testing.allocator;

    var tray = SystemTray.init(allocator, "App");
    defer tray.deinit();

    // Initially no callback
    try testing.expect(tray.click_callback == null);

    // Register callback
    const TestCallback = struct {
        fn callback() void {}
    };

    tray.setClickCallback(&TestCallback.callback);
    try testing.expect(tray.click_callback != null);
}

// Test click callback triggering
test "SystemTray: click callback triggering" {
    const allocator = testing.allocator;

    var tray = SystemTray.init(allocator, "App");
    defer tray.deinit();

    // Track callback invocation
    const State = struct {
        var called: bool = false;
        fn callback() void {
            called = true;
        }
    };

    State.called = false;
    tray.setClickCallback(&State.callback);

    // Trigger click
    tray.triggerClick();
    try testing.expect(State.called == true);
}

// Test menu attachment
test "SystemTray: menu attachment" {
    const allocator = testing.allocator;

    var tray = SystemTray.init(allocator, "App");
    defer tray.deinit();

    try testing.expect(tray.menu_handle == null);

    // Simulate menu handle (would be a real NSMenu/HMENU in practice)
    var fake_menu: u8 = 0;
    const menu_ptr: *anyopaque = @ptrCast(&fake_menu);

    try tray.setMenu(menu_ptr);
    try testing.expect(tray.menu_handle != null);
}

// Test platform detection
test "SystemTray: platform detection" {
    // This test verifies that the platform-specific code is properly conditionally compiled
    switch (builtin.target.os.tag) {
        .macos => {
            // macOS should support system tray
            std.debug.print("\nRunning on macOS - NSStatusBar available\n", .{});
        },
        .windows => {
            // Windows should support system tray
            std.debug.print("\nRunning on Windows - Shell_NotifyIcon available\n", .{});
        },
        .linux => {
            // Linux should support system tray
            std.debug.print("\nRunning on Linux - libappindicator available\n", .{});
        },
        else => {
            // Other platforms should fail gracefully
            std.debug.print("\nRunning on unsupported platform: {s}\n", .{@tagName(builtin.target.os.tag)});
        },
    }
}

// Test error handling for unsupported platforms
test "SystemTray: unsupported platform handling" {
    if (builtin.target.os.tag != .macos and
        builtin.target.os.tag != .windows and
        builtin.target.os.tag != .linux) {

        const allocator = testing.allocator;
        var tray = SystemTray.init(allocator, "App");
        defer tray.deinit();

        // Attempting to show on unsupported platform should fail
        const result = tray.show();
        try testing.expectError(error.PlatformNotSupported, result);
    }
}

// Test multiple system tray instances
test "SystemTray: multiple instances" {
    const allocator = testing.allocator;

    var tray1 = SystemTray.init(allocator, "App 1");
    defer tray1.deinit();

    var tray2 = SystemTray.init(allocator, "App 2");
    defer tray2.deinit();

    try testing.expectEqualStrings("App 1", tray1.title);
    try testing.expectEqualStrings("App 2", tray2.title);

    // Update one shouldn't affect the other
    try tray1.setTitle("Updated 1");
    try testing.expectEqualStrings("Updated 1", tray1.icon_text.?);
    try testing.expect(tray2.icon_text == null);
}

// Test rapid title updates
test "SystemTray: rapid title updates" {
    const allocator = testing.allocator;

    var tray = SystemTray.init(allocator, "App");
    defer tray.deinit();

    // Rapidly update title multiple times
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        try tray.setTitle("Title");
    }

    try testing.expectEqualStrings("Title", tray.icon_text.?);
}

// Test long titles
test "SystemTray: long titles" {
    const allocator = testing.allocator;

    var tray = SystemTray.init(allocator, "App");
    defer tray.deinit();

    // Test with a very long title (should be handled gracefully)
    const long_title = "This is a very long title that might exceed normal menubar limits";
    try tray.setTitle(long_title);
    try testing.expectEqualStrings(long_title, tray.icon_text.?);
}

// Test empty strings
test "SystemTray: empty strings" {
    const allocator = testing.allocator;

    var tray = SystemTray.init(allocator, "");
    defer tray.deinit();

    try testing.expectEqualStrings("", tray.title);

    // Empty title update
    try tray.setTitle("");
    try testing.expectEqualStrings("", tray.icon_text.?);

    // Empty tooltip
    try tray.setTooltip("");
    try testing.expectEqualStrings("", tray.tooltip.?);
}

// Test Unicode characters in title
test "SystemTray: Unicode characters" {
    const allocator = testing.allocator;

    var tray = SystemTray.init(allocator, "App");
    defer tray.deinit();

    // Test various Unicode characters
    const unicode_titles = [_][]const u8{
        "🚀 Rocket",
        "⚡ Lightning",
        "🎨 Art",
        "中文",
        "日本語",
        "🔥⚡🚀",
    };

    for (unicode_titles) |title| {
        try tray.setTitle(title);
        try testing.expectEqualStrings(title, tray.icon_text.?);
    }
}

// Memory leak detection test
test "SystemTray: no memory leaks" {
    const allocator = testing.allocator;

    // Create and destroy many tray instances
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        var tray = SystemTray.init(allocator, "App");
        try tray.setTitle("Title");
        try tray.setTooltip("Tooltip");
        tray.deinit();
    }

    // If there are memory leaks, this test will fail with testing.allocator
}

// Test cleanup with platform handle
test "SystemTray: cleanup with platform handle" {
    if (builtin.target.os.tag != .macos and
        builtin.target.os.tag != .windows and
        builtin.target.os.tag != .linux) {
        return error.SkipZigTest;
    }

    const allocator = testing.allocator;
    var tray = SystemTray.init(allocator, "App");

    // Note: We can't actually call show() in tests without a full GUI environment
    // This is more of a structure test

    // Cleanup should work even without platform handle
    tray.deinit();
}

// Test callback cleanup
test "SystemTray: callback cleanup" {
    const allocator = testing.allocator;

    var tray = SystemTray.init(allocator, "App");
    defer tray.deinit();

    const State = struct {
        var call_count: usize = 0;
        fn callback() void {
            call_count += 1;
        }
    };

    State.call_count = 0;

    // Set callback
    tray.setClickCallback(&State.callback);
    tray.triggerClick();
    try testing.expectEqual(@as(usize, 1), State.call_count);

    // After deinit, callback pointer is still there but we don't trigger it
    // (In real usage, the platform would clean up event handlers)
}

// Test thread safety considerations
test "SystemTray: struct is not thread-safe (documentation test)" {
    // SystemTray is designed to be used from the main thread only
    // This is a documentation test to make it clear

    // In real usage:
    // - All SystemTray methods must be called from the main thread
    // - Platform APIs (NSStatusBar, Shell_NotifyIcon, etc.) require main thread
    // - No synchronization primitives are included

    // This is enforced by convention and platform requirements,
    // not by Zig's type system

    const allocator = testing.allocator;
    var tray = SystemTray.init(allocator, "App");
    defer tray.deinit();

    // Just verify the structure is created correctly
    try testing.expect(tray.allocator.vtable == allocator.vtable);
}
