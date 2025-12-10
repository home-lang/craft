const std = @import("std");
const craft = @import("../../src/main.zig");

/// Notifications Example
///
/// Demonstrates how to use native notifications in Craft:
/// - Basic notifications
/// - Notifications with body text
/// - Notifications with sound
/// - Notifications with actions

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Craft Notifications Demo ===\n\n", .{});

    var notifications = craft.Notifications.init(allocator);
    defer notifications.deinit();

    // Demo 1: Basic notification
    std.debug.print("1. Sending basic notification...\n", .{});
    try notifications.send(.{
        .title = "Hello from Craft!",
    });
    std.debug.print("   Sent!\n", .{});

    std.time.sleep(2 * std.time.ns_per_s);

    // Demo 2: Notification with body
    std.debug.print("\n2. Sending notification with body...\n", .{});
    try notifications.send(.{
        .title = "Download Complete",
        .body = "Your file has been downloaded successfully.",
    });
    std.debug.print("   Sent!\n", .{});

    std.time.sleep(2 * std.time.ns_per_s);

    // Demo 3: Notification with sound
    std.debug.print("\n3. Sending notification with sound...\n", .{});
    try notifications.send(.{
        .title = "New Message",
        .body = "You have a new message from John.",
        .sound = "Glass", // macOS sound name
    });
    std.debug.print("   Sent!\n", .{});

    std.time.sleep(2 * std.time.ns_per_s);

    // Demo 4: Notification with action
    std.debug.print("\n4. Sending notification with action button...\n", .{});
    const actions = [_]craft.NotificationAction{
        .{ .id = "view", .title = "View" },
    };
    try notifications.send(.{
        .title = "Reminder",
        .body = "Meeting starts in 5 minutes",
        .actions = &actions,
        .tag = "meeting-reminder",
    });
    std.debug.print("   Sent!\n", .{});

    std.debug.print("\n=== Demo Complete ===\n", .{});
}

// Example: Using notifications through the App API
pub fn appNotificationExample() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = craft.App.init(allocator);
    defer app.deinit();

    // Send notification through app
    try app.notify(.{
        .title = "App Notification",
        .body = "This notification was sent through the App API.",
    });
}
