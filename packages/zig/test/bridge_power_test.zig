const std = @import("std");
const testing = std.testing;
const bridge_power = @import("../src/bridge_power.zig");
const bridge_error = @import("../src/bridge_error.zig");

test "PowerBridge - init" {
    const allocator = testing.allocator;
    const power = bridge_power.PowerBridge.init(allocator);

    try testing.expectEqual(allocator, power.allocator);
    try testing.expect(power.sleep_disabled == false);
    try testing.expectEqual(@as(u32, 0), power.assertion_id);
}

test "PowerBridge - handleMessage unknown action" {
    const allocator = testing.allocator;
    var power = bridge_power.PowerBridge.init(allocator);
    defer power.deinit();

    // Unknown action should not crash - it reports error to JS
    try power.handleMessage("unknownAction", "{}");
}

test "PowerBridge - handleMessage getBatteryLevel" {
    const allocator = testing.allocator;
    var power = bridge_power.PowerBridge.init(allocator);
    defer power.deinit();

    // Should not crash with valid or missing callback ID
    try power.handleMessage("getBatteryLevel", "{\"callbackId\":\"cb1\"}");
    try power.handleMessage("getBatteryLevel", "{}");
}

test "PowerBridge - handleMessage isCharging" {
    const allocator = testing.allocator;
    var power = bridge_power.PowerBridge.init(allocator);
    defer power.deinit();

    try power.handleMessage("isCharging", "{\"callbackId\":\"cb1\"}");
    try power.handleMessage("isCharging", "{}");
}

test "PowerBridge - handleMessage isPluggedIn" {
    const allocator = testing.allocator;
    var power = bridge_power.PowerBridge.init(allocator);
    defer power.deinit();

    try power.handleMessage("isPluggedIn", "{\"callbackId\":\"cb1\"}");
    try power.handleMessage("isPluggedIn", "{}");
}

test "PowerBridge - handleMessage getBatteryState" {
    const allocator = testing.allocator;
    var power = bridge_power.PowerBridge.init(allocator);
    defer power.deinit();

    try power.handleMessage("getBatteryState", "{\"callbackId\":\"cb1\"}");
    try power.handleMessage("getBatteryState", "{}");
}

test "PowerBridge - handleMessage getTimeRemaining" {
    const allocator = testing.allocator;
    var power = bridge_power.PowerBridge.init(allocator);
    defer power.deinit();

    try power.handleMessage("getTimeRemaining", "{\"callbackId\":\"cb1\"}");
    try power.handleMessage("getTimeRemaining", "{}");
}

test "PowerBridge - handleMessage preventSleep" {
    const allocator = testing.allocator;
    var power = bridge_power.PowerBridge.init(allocator);
    defer power.deinit();

    // Test with reason
    try power.handleMessage("preventSleep", "{\"reason\":\"Downloading file\"}");

    // On macOS, this should set sleep_disabled to true
    // On other platforms, it's a no-op
    // We can't reliably test the platform-specific behavior in unit tests

    // Test with empty reason
    try power.handleMessage("preventSleep", "{}");
}

test "PowerBridge - handleMessage allowSleep" {
    const allocator = testing.allocator;
    var power = bridge_power.PowerBridge.init(allocator);
    defer power.deinit();

    // First prevent sleep
    try power.handleMessage("preventSleep", "{\"reason\":\"Test\"}");

    // Then allow it
    try power.handleMessage("allowSleep", "{}");
}

test "PowerBridge - handleMessage isLowPowerMode" {
    const allocator = testing.allocator;
    var power = bridge_power.PowerBridge.init(allocator);
    defer power.deinit();

    try power.handleMessage("isLowPowerMode", "{\"callbackId\":\"cb1\"}");
    try power.handleMessage("isLowPowerMode", "{}");
}

test "PowerBridge - handleMessage getThermalState" {
    const allocator = testing.allocator;
    var power = bridge_power.PowerBridge.init(allocator);
    defer power.deinit();

    try power.handleMessage("getThermalState", "{\"callbackId\":\"cb1\"}");
    try power.handleMessage("getThermalState", "{}");
}

test "PowerBridge - handleMessage getUptimeSeconds" {
    const allocator = testing.allocator;
    var power = bridge_power.PowerBridge.init(allocator);
    defer power.deinit();

    try power.handleMessage("getUptimeSeconds", "{\"callbackId\":\"cb1\"}");
    try power.handleMessage("getUptimeSeconds", "{}");
}

test "PowerBridge - sleep_disabled state management" {
    const allocator = testing.allocator;
    var power = bridge_power.PowerBridge.init(allocator);
    defer power.deinit();

    // Initially should be false
    try testing.expect(power.sleep_disabled == false);

    // After prevent sleep (on macOS), should be true
    // On other platforms, might stay false
    try power.handleMessage("preventSleep", "{\"reason\":\"Test\"}");

    // After allow sleep, should be false
    try power.handleMessage("allowSleep", "{}");
    try testing.expect(power.sleep_disabled == false);
}

test "PowerBridge - deinit with sleep disabled" {
    const allocator = testing.allocator;
    var power = bridge_power.PowerBridge.init(allocator);

    power.sleep_disabled = true;

    // Should clean up properly
    power.deinit();

    try testing.expect(power.sleep_disabled == false);
}

test "PowerBridge - global bridge functions" {
    const allocator = testing.allocator;
    var power = bridge_power.PowerBridge.init(allocator);
    defer power.deinit();

    // Test that global functions exist and work
    _ = bridge_power.getGlobalPowerBridge();
    bridge_power.setGlobalPowerBridge(&power);

    const global = bridge_power.getGlobalPowerBridge();
    try testing.expect(global != null);
}

test "PowerBridge - multiple sequential calls" {
    const allocator = testing.allocator;
    var power = bridge_power.PowerBridge.init(allocator);
    defer power.deinit();

    // Should handle multiple calls without issues
    try power.handleMessage("getBatteryLevel", "{\"callbackId\":\"cb1\"}");
    try power.handleMessage("isCharging", "{\"callbackId\":\"cb2\"}");
    try power.handleMessage("preventSleep", "{\"reason\":\"Test\"}");
    try power.handleMessage("getThermalState", "{\"callbackId\":\"cb3\"}");
    try power.handleMessage("allowSleep", "{}");
}

test "PowerBridge - callback ID extraction" {
    const allocator = testing.allocator;
    var power = bridge_power.PowerBridge.init(allocator);
    defer power.deinit();

    // Test various callback ID formats
    try power.handleMessage("getBatteryLevel", "{\"callbackId\":\"simple\"}");
    try power.handleMessage("getBatteryLevel", "{\"callbackId\":\"with-dashes\"}");
    try power.handleMessage("getBatteryLevel", "{\"callbackId\":\"with_underscores\"}");
    try power.handleMessage("getBatteryLevel", "{\"callbackId\":\"123456\"}");
}
