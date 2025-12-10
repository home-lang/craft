const std = @import("std");
const craft = @import("../../src/api.zig");

/// Example: Converting a Web App to Native Desktop + Mobile
///
/// This example shows how to take an existing web application (HTML/CSS/JS)
/// and wrap it in a native desktop or mobile app using Craft.

// Embed the web app HTML at compile time
const app_html = @embedFile("app.html");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Detect platform
    const builtin = @import("builtin");

    switch (builtin.target.os.tag) {
        .macos => {
            // Desktop: Create window with embedded HTML
            try runDesktop(allocator);
        },
        .ios, .tvos, .watchos => {
            // Mobile: Use iOS app infrastructure
            try runMobile(allocator);
        },
        .linux => {
            // Could be Linux desktop or Android
            // For now, treat as desktop
            try runDesktop(allocator);
        },
        .windows => {
            try runDesktop(allocator);
        },
        else => {
            std.debug.print("Unsupported platform\n", .{});
            return error.UnsupportedPlatform;
        },
    }
}

/// Run as desktop application
fn runDesktop(allocator: std.mem.Allocator) !void {
    std.debug.print("Starting desktop application...\n", .{});

    // Initialize app
    var app = craft.App.init(allocator);
    defer app.deinit();

    // Simple API (matches README example):
    // _ = try app.createWindow("My Web App", 1200, 800, app_html);

    // Or with options:
    _ = try app.createWindowAdvanced("My Web App", 1200, 800, app_html, .{
        .resizable = true,
        .titlebar_hidden = false,
        .dev_tools = true, // Enable for development
    });

    // Run the application
    try app.run();
}

/// Run as mobile (iOS) application
fn runMobile(allocator: std.mem.Allocator) !void {
    const ios = @import("../../src/ios.zig");

    std.debug.print("Starting iOS application...\n", .{});

    // Configure iOS app
    var app = ios.CraftAppDelegate.init(allocator, .{
        .name = "My Web App",
        .initial_content = .{ .html = app_html },
        .status_bar_style = .light,
        .orientations = &[_]ios.CraftAppDelegate.AppConfig.Orientation{
            .portrait,
            .landscape_left,
            .landscape_right,
        },
        .enable_inspector = true, // For development
    });

    // Set up lifecycle callbacks
    app.onLaunch(onAppLaunch);
    app.onBackground(onAppBackground);
    app.onForeground(onAppForeground);

    // Run the app (blocks until app terminates)
    try app.run();
}

fn onAppLaunch() void {
    std.debug.print("App launched!\n", .{});
}

fn onAppBackground() void {
    std.debug.print("App went to background\n", .{});
}

fn onAppForeground() void {
    std.debug.print("App came to foreground\n", .{});
}

// ============================================================================
// Alternative: Simple one-liner for quick apps
// ============================================================================

pub fn simpleExample() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // One-liner to create a desktop app from HTML
    var app = craft.App.init(allocator);
    defer app.deinit();

    _ = try app.createWindowWithHTML(
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
    ,
        .{},
    );

    try app.run();
}
