const std = @import("std");
const craft = @import("../../src/main.zig");

/// Hot Reload Example
///
/// Demonstrates how to use hot reload in Craft:
/// - File watching for changes
/// - WebSocket server for browser/mobile reload
/// - State preservation across reloads

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Craft Hot Reload Demo ===\n\n", .{});

    // Demo 1: Basic file watcher
    std.debug.print("1. Setting up file watcher...\n", .{});

    var hot_reload = try craft.HotReload.init(allocator, .{
        .enabled = true,
        .watch_paths = &[_][]const u8{
            "src/",
            "index.html",
        },
        .ignore_patterns = &[_][]const u8{ ".git", "node_modules", ".zig-cache" },
        .debounce_ms = 300,
    });
    defer hot_reload.deinit();

    // Set reload callback
    hot_reload.setCallback(onReload);
    hot_reload.start();
    std.debug.print("   File watcher started!\n", .{});

    // Demo 2: WebSocket reload server (for browser/mobile)
    std.debug.print("\n2. Starting WebSocket reload server...\n", .{});

    var reload_server = craft.ReloadServer.init(allocator, .{
        .enabled = true,
        .port = 3456,
        .host = "0.0.0.0",
        .broadcast = true,
    });
    defer reload_server.deinit();

    try reload_server.start();
    std.debug.print("   Server running on ws://localhost:3456\n", .{});

    // Demo 3: Poll for changes (in real app, this would be in event loop)
    std.debug.print("\n3. Watching for file changes...\n", .{});
    std.debug.print("   (Modify a watched file to trigger reload)\n", .{});
    std.debug.print("   Press Ctrl+C to stop\n\n", .{});

    var iterations: usize = 0;
    while (iterations < 30) : (iterations += 1) { // Run for ~30 seconds
        // Check for file changes
        try hot_reload.poll();

        // Simulate periodic status
        if (iterations % 10 == 0) {
            std.debug.print("   Connected clients: {d}\n", .{reload_server.getClientCount()});
        }

        std.time.sleep(1 * std.time.ns_per_s);
    }

    std.debug.print("\n=== Demo Complete ===\n", .{});
}

fn onReload() void {
    std.debug.print("   [HOT RELOAD] Changes detected! Reloading...\n", .{});
}

// Example: Integrating hot reload with App
pub fn appWithHotReload() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = craft.App.init(allocator);
    defer app.deinit();

    // Enable hot reload
    app.hot_reload_config = .{
        .enabled = true,
        .watch_paths = &[_][]const u8{"web/"},
        .debounce_ms = 300,
    };

    // Create window with hot reload script injected
    const html =
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\    <title>Hot Reload Demo</title>
    ++ craft.hotreload_module.client_script ++
        \\</head>
        \\<body>
        \\    <h1>Edit this file and save!</h1>
        \\    <p>The page will automatically reload.</p>
        \\</body>
        \\</html>
    ;

    _ = try app.createWindow("Hot Reload Demo", 800, 600, html);
    try app.run();
}

// Example: Mobile hot reload (iOS/Android)
pub fn mobileHotReload() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Start reload server that mobile devices can connect to
    var server = craft.ReloadServer.init(allocator, .{
        .enabled = true,
        .port = 3456,
        .host = "0.0.0.0", // Listen on all interfaces
        .broadcast = true,
        .platform = .both, // iOS and Android
    });
    defer server.deinit();

    try server.start();
    std.debug.print("Mobile hot reload server started\n", .{});
    std.debug.print("Connect from iOS/Android to ws://<your-ip>:3456\n", .{});

    // In your HTML, include the mobile client script:
    // craft.hotreload_module.mobile_client_script

    // Trigger reload when files change
    // server.triggerReload();

    // Or just reload CSS (faster, no state loss)
    // server.triggerCSSReload();
}
