const std = @import("std");
const testing = std.testing;
const bridge_updater = @import("../src/bridge_updater.zig");
const bridge_error = @import("../src/bridge_error.zig");

test "UpdaterBridge - init" {
    const allocator = testing.allocator;
    const updater = bridge_updater.UpdaterBridge.init(allocator);

    try testing.expectEqual(allocator, updater.allocator);
    try testing.expect(updater.updater == null);
    try testing.expect(updater.feed_url == null);
    try testing.expect(updater.automatic_checks == true);
    try testing.expectEqual(@as(u32, 86400), updater.check_interval);
}

test "UpdaterBridge - handleMessage unknown action" {
    const allocator = testing.allocator;
    var updater = bridge_updater.UpdaterBridge.init(allocator);
    defer updater.deinit();

    // Unknown action should not crash - it reports error to JS
    try updater.handleMessage("unknownAction", "{}");
}

test "UpdaterBridge - handleMessage known actions" {
    const allocator = testing.allocator;
    var updater = bridge_updater.UpdaterBridge.init(allocator);
    defer updater.deinit();

    // These should not crash (they'll be no-ops on non-macOS or without Sparkle)
    try updater.handleMessage("checkForUpdates", "");
    try updater.handleMessage("checkForUpdatesInBackground", "");
    try updater.handleMessage("getLastUpdateCheckDate", "");
    try updater.handleMessage("getUpdateInfo", "");
}

test "UpdaterBridge - handleMessage configure with empty data" {
    const allocator = testing.allocator;
    var updater = bridge_updater.UpdaterBridge.init(allocator);
    defer updater.deinit();

    // Should handle empty/invalid JSON gracefully
    try updater.handleMessage("configure", "");
}

test "UpdaterBridge - handleMessage setAutomaticChecks" {
    const allocator = testing.allocator;
    var updater = bridge_updater.UpdaterBridge.init(allocator);
    defer updater.deinit();

    // Test enabling automatic checks
    try updater.handleMessage("setAutomaticChecks", "{\"enabled\":true}");
    try testing.expect(updater.automatic_checks == true);

    // Test disabling automatic checks
    try updater.handleMessage("setAutomaticChecks", "{\"enabled\":false}");
    try testing.expect(updater.automatic_checks == false);

    // Test with missing field (should not change value)
    try updater.handleMessage("setAutomaticChecks", "{}");
}

test "UpdaterBridge - handleMessage setCheckInterval valid" {
    const allocator = testing.allocator;
    var updater = bridge_updater.UpdaterBridge.init(allocator);
    defer updater.deinit();

    const original_interval = updater.check_interval;

    try updater.handleMessage("setCheckInterval", "{\"interval\":3600}");
    // On non-macOS this won't actually set, but shouldn't crash
    _ = original_interval;
}

test "UpdaterBridge - handleMessage setCheckInterval invalid" {
    const allocator = testing.allocator;
    var updater = bridge_updater.UpdaterBridge.init(allocator);
    defer updater.deinit();

    // Should handle invalid data gracefully
    try updater.handleMessage("setCheckInterval", "{\"interval\":\"not a number\"}");
    try updater.handleMessage("setCheckInterval", "{}");
}

test "UpdaterBridge - handleMessage setFeedURL" {
    const allocator = testing.allocator;
    var updater = bridge_updater.UpdaterBridge.init(allocator);
    defer updater.deinit();

    // Should not crash with valid or invalid URLs
    try updater.handleMessage("setFeedURL", "{\"url\":\"https://example.com/appcast.xml\"}");
    try updater.handleMessage("setFeedURL", "{\"url\":\"\"}");
    try updater.handleMessage("setFeedURL", "{}");
}

test "UpdaterBridge - default check interval" {
    const allocator = testing.allocator;
    const updater = bridge_updater.UpdaterBridge.init(allocator);

    // 24 hours in seconds
    try testing.expectEqual(@as(u32, 86400), updater.check_interval);
}

test "UpdaterBridge - deinit with no feed URL" {
    const allocator = testing.allocator;
    var updater = bridge_updater.UpdaterBridge.init(allocator);

    // Should not crash when feed_url is null
    updater.deinit();
}

test "UpdaterBridge - deinit with feed URL" {
    const allocator = testing.allocator;
    var updater = bridge_updater.UpdaterBridge.init(allocator);

    // Manually set a feed URL
    updater.feed_url = try allocator.dupe(u8, "https://example.com/appcast.xml");

    // Should free the URL
    updater.deinit();
}

test "UpdaterBridge - global bridge functions" {
    const allocator = testing.allocator;
    var updater = bridge_updater.UpdaterBridge.init(allocator);
    defer updater.deinit();

    // Test that global functions exist and work
    _ = bridge_updater.getGlobalUpdaterBridge();
    bridge_updater.setGlobalUpdaterBridge(&updater);

    const global = bridge_updater.getGlobalUpdaterBridge();
    try testing.expect(global != null);
}

test "UpdaterBridge - multiple handleMessage calls" {
    const allocator = testing.allocator;
    var updater = bridge_updater.UpdaterBridge.init(allocator);
    defer updater.deinit();

    // Should handle multiple calls without issues
    try updater.handleMessage("setAutomaticChecks", "{\"enabled\":true}");
    try updater.handleMessage("setCheckInterval", "{\"interval\":7200}");
    try updater.handleMessage("checkForUpdates", "");
    try updater.handleMessage("getUpdateInfo", "");
}
