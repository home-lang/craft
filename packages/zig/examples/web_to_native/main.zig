const std = @import("std");
const craft = @import("craft");
const builtin = @import("builtin");

/// Example: Converting a Web App to Native Desktop + Mobile
///
/// This example shows how to take an existing web application (HTML/CSS/JS)
/// and wrap it in a native desktop or mobile app using Craft.
///
/// Supported platforms:
/// - Desktop: macOS, Linux, Windows
/// - Mobile: iOS, Android

// Embed the web app HTML at compile time
const app_html = @embedFile("app.html");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Detect platform and run appropriate version
    switch (builtin.target.os.tag) {
        .macos, .windows => {
            // Desktop
            try runDesktop(allocator);
        },
        .ios, .tvos, .watchos => {
            // iOS
            try runIOS(allocator);
        },
        .linux => {
            // Could be Linux desktop or Android
            if (builtin.target.abi == .android) {
                try runAndroid(allocator);
            } else {
                try runDesktop(allocator);
            }
        },
        else => {
            std.debug.print("Unsupported platform\n", .{});
            return error.UnsupportedPlatform;
        },
    }
}

/// Run as desktop application (macOS, Linux, Windows)
fn runDesktop(allocator: std.mem.Allocator) !void {
    std.debug.print("Starting desktop application...\n", .{});

    // Initialize app
    var app = craft.App.init(allocator);
    defer app.deinit();

    // Create window with embedded HTML
    _ = try app.createWindow("My Web App", 1200, 800, app_html);

    // Run the application
    try app.run();
}

/// Run as iOS application
fn runIOS(allocator: std.mem.Allocator) !void {
    std.debug.print("Starting iOS application...\n", .{});

    // Configure iOS app
    var app = craft.ios.CraftAppDelegate.init(allocator, .{
        .name = "My Web App",
        .initial_content = .{ .html = app_html },
        .status_bar_style = .light,
        .orientations = &[_]craft.ios.CraftAppDelegate.AppConfig.Orientation{
            .portrait,
            .landscape_left,
            .landscape_right,
        },
        .enable_inspector = true, // For development
    });

    // Set up lifecycle callbacks
    app.onLaunch(onIOSAppLaunch);
    app.onBackground(onIOSAppBackground);
    app.onForeground(onIOSAppForeground);

    // Run the app (blocks until app terminates)
    try app.run();
}

/// Run as Android application
fn runAndroid(allocator: std.mem.Allocator) !void {
    std.debug.print("Starting Android application...\n", .{});

    // Configure Android app
    var app = craft.android.CraftActivity.init(allocator, .{
        .name = "My Web App",
        .package_name = "com.example.mywebapp",
        .initial_content = .{ .html = app_html },
        .theme = .system,
        .orientation = .sensor, // Allow rotation
        .enable_javascript = true,
        .enable_dom_storage = true,
        .enable_inspector = true, // For development
    });
    defer app.deinit();

    // Set up lifecycle callbacks
    app.onCreate(onAndroidCreate);
    app.onResume(onAndroidResume);
    app.onPause(onAndroidPause);
    app.onDestroy(onAndroidDestroy);
    app.onBackPressed(onAndroidBackPressed);

    // Run the app
    try app.run();

    // Register custom JavaScript handlers after bridge is initialized
    if (app.getBridge()) |bridge| {
        try bridge.registerHandler("nativeAction", handleNativeAction);
    }
}

// ============================================================================
// iOS Lifecycle Callbacks
// ============================================================================

fn onIOSAppLaunch() void {
    std.debug.print("[iOS] App launched!\n", .{});
}

fn onIOSAppBackground() void {
    std.debug.print("[iOS] App went to background\n", .{});
}

fn onIOSAppForeground() void {
    std.debug.print("[iOS] App came to foreground\n", .{});
}

// ============================================================================
// Android Lifecycle Callbacks
// ============================================================================

fn onAndroidCreate() void {
    std.debug.print("[Android] Activity created!\n", .{});
}

fn onAndroidResume() void {
    std.debug.print("[Android] Activity resumed\n", .{});
}

fn onAndroidPause() void {
    std.debug.print("[Android] Activity paused\n", .{});
}

fn onAndroidDestroy() void {
    std.debug.print("[Android] Activity destroyed\n", .{});
}

fn onAndroidBackPressed() bool {
    std.debug.print("[Android] Back button pressed\n", .{});
    // Return false to allow default back behavior
    // Return true to consume the event (prevent back navigation)
    return false;
}

fn handleNativeAction(params: []const u8, bridge: *craft.android.JSBridge, callback_id: []const u8) void {
    std.debug.print("[Android] Native action called with: {s}\n", .{params});
    bridge.sendResponse(callback_id, "{ \"success\": true }") catch {};
}

// ============================================================================
// Alternative: Simple one-liner for quick apps
// ============================================================================

pub fn simpleDesktopExample() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // One-liner to create a desktop app from HTML
    var app = craft.App.init(allocator);
    defer app.deinit();

    _ = try app.createWindow(
        "Simple App",
        800,
        600,
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\    <style>
        \\        body { font-family: system-ui; padding: 20px; }
        \\        button { padding: 10px 20px; font-size: 16px; }
        \\    </style>
        \\</head>
        \\<body>
        \\    <h1>Hello from Craft!</h1>
        \\    <button onclick="alert('Clicked!')">Click Me</button>
        \\</body>
        \\</html>
    );

    try app.run();
}

pub fn simpleAndroidExample() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // One-liner to create an Android app from HTML
    try craft.android.quickStart(allocator,
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\    <meta name="viewport" content="width=device-width, initial-scale=1.0">
        \\    <style>
        \\        body { font-family: Roboto, sans-serif; padding: 20px; }
        \\        button { padding: 14px 28px; font-size: 16px; }
        \\    </style>
        \\</head>
        \\<body>
        \\    <h1>Hello from Craft Android!</h1>
        \\    <button onclick="CraftBridge.postMessage(JSON.stringify({method:'showToast',params:{message:'Hello!'}}))">
        \\        Show Toast
        \\    </button>
        \\</body>
        \\</html>
    );
}
