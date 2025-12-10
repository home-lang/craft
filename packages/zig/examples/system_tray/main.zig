const std = @import("std");
const craft = @import("../../src/main.zig");

/// System Tray Example
///
/// Demonstrates how to use system tray / menubar icons in Craft:
/// - Creating a tray icon
/// - Setting title/text
/// - Setting tooltip
/// - Click callbacks
/// - Animated icons

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Craft System Tray Demo ===\n\n", .{});

    // Create system tray
    var tray = craft.SystemTray.init(allocator, "Craft Demo");
    defer tray.deinit();

    // Set initial icon text (emoji works on macOS)
    tray.icon_text = "🚀 Craft";

    // Set tooltip
    try tray.setTooltip("Craft Framework Demo App");

    // Set click callback
    tray.setClickCallback(onTrayClick);

    // Show the tray icon
    std.debug.print("1. Creating tray icon...\n", .{});
    try tray.show();
    std.debug.print("   Tray icon visible!\n", .{});

    // Wait a moment
    std.time.sleep(3 * std.time.ns_per_s);

    // Update the title
    std.debug.print("\n2. Updating tray title...\n", .{});
    try tray.setTitle("📊 Active");
    std.debug.print("   Title updated!\n", .{});

    std.time.sleep(3 * std.time.ns_per_s);

    // Demo animation
    std.debug.print("\n3. Starting animation...\n", .{});
    const frames = [_][]const u8{
        "⏳ Loading.",
        "⏳ Loading..",
        "⏳ Loading...",
    };
    try tray.animate(&frames, 500); // 500ms per frame

    std.time.sleep(5 * std.time.ns_per_s);

    // Stop animation
    std.debug.print("\n4. Stopping animation...\n", .{});
    tray.stopAnimation();
    try tray.setTitle("✅ Done");
    std.debug.print("   Animation stopped!\n", .{});

    std.time.sleep(3 * std.time.ns_per_s);

    // Hide tray
    std.debug.print("\n5. Hiding tray...\n", .{});
    tray.hide();
    std.debug.print("   Tray hidden!\n", .{});

    std.debug.print("\n=== Demo Complete ===\n", .{});
}

fn onTrayClick() void {
    std.debug.print("[Tray] Icon clicked!\n", .{});
}

// Example: Using tray through the App API
pub fn appTrayExample() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = craft.App.init(allocator);
    defer app.deinit();

    // Create tray through app
    const tray = try app.createSystemTray("My App");
    tray.icon_text = "🎯";
    try tray.show();

    // Create window
    _ = try app.createWindow("My App", 800, 600,
        \\<html><body><h1>App with Tray</h1></body></html>
    );

    try app.run();
}

// Example: Multiple tray icons
pub fn multipleTrayExample() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = craft.App.init(allocator);
    defer app.deinit();

    // Create multiple tray icons
    const tray1 = try app.createSystemTray("Status");
    tray1.icon_text = "🟢";
    try tray1.show();

    const tray2 = try app.createAdditionalTray("CPU");
    tray2.icon_text = "💻 45%";
    try tray2.show();

    const tray3 = try app.createAdditionalTray("Memory");
    tray3.icon_text = "🧠 2.1GB";
    try tray3.show();
}
