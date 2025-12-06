const std = @import("std");
const testing = std.testing;
const bridge_bluetooth = @import("../src/bridge_bluetooth.zig");
const bridge_error = @import("../src/bridge_error.zig");

test "BluetoothBridge - init" {
    const allocator = testing.allocator;
    const bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);

    try testing.expectEqual(allocator, bluetooth.allocator);
    try testing.expect(bluetooth.is_scanning == false);
}

test "BluetoothBridge - handleMessage unknown action" {
    const allocator = testing.allocator;
    var bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);
    defer bluetooth.deinit();

    // Unknown action should not crash - it reports error to JS
    try bluetooth.handleMessage("unknownAction", "{}");
}

test "BluetoothBridge - handleMessage isAvailable" {
    const allocator = testing.allocator;
    var bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);
    defer bluetooth.deinit();

    try bluetooth.handleMessage("isAvailable", "{\"callbackId\":\"cb1\"}");
    try bluetooth.handleMessage("isAvailable", "{}");
}

test "BluetoothBridge - handleMessage isEnabled" {
    const allocator = testing.allocator;
    var bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);
    defer bluetooth.deinit();

    try bluetooth.handleMessage("isEnabled", "{\"callbackId\":\"cb1\"}");
    try bluetooth.handleMessage("isEnabled", "{}");
}

test "BluetoothBridge - handleMessage getPowerState" {
    const allocator = testing.allocator;
    var bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);
    defer bluetooth.deinit();

    try bluetooth.handleMessage("getPowerState", "{\"callbackId\":\"cb1\"}");
    try bluetooth.handleMessage("getPowerState", "{}");
}

test "BluetoothBridge - handleMessage getConnectedDevices" {
    const allocator = testing.allocator;
    var bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);
    defer bluetooth.deinit();

    try bluetooth.handleMessage("getConnectedDevices", "{\"callbackId\":\"cb1\"}");
    try bluetooth.handleMessage("getConnectedDevices", "{}");
}

test "BluetoothBridge - handleMessage getPairedDevices" {
    const allocator = testing.allocator;
    var bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);
    defer bluetooth.deinit();

    try bluetooth.handleMessage("getPairedDevices", "{\"callbackId\":\"cb1\"}");
    try bluetooth.handleMessage("getPairedDevices", "{}");
}

test "BluetoothBridge - handleMessage startDiscovery" {
    const allocator = testing.allocator;
    var bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);
    defer bluetooth.deinit();

    try testing.expect(bluetooth.is_scanning == false);

    try bluetooth.handleMessage("startDiscovery", "{}");

    // On macOS, this should set is_scanning to true
    // On other platforms, it might be a no-op
}

test "BluetoothBridge - handleMessage stopDiscovery" {
    const allocator = testing.allocator;
    var bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);
    defer bluetooth.deinit();

    // Start then stop discovery
    try bluetooth.handleMessage("startDiscovery", "{}");
    try bluetooth.handleMessage("stopDiscovery", "{}");

    // Should be stopped
    try testing.expect(bluetooth.is_scanning == false);
}

test "BluetoothBridge - handleMessage isDiscovering" {
    const allocator = testing.allocator;
    var bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);
    defer bluetooth.deinit();

    // Initially not discovering
    try bluetooth.handleMessage("isDiscovering", "{\"callbackId\":\"cb1\"}");
    try testing.expect(bluetooth.is_scanning == false);

    // Start discovery
    try bluetooth.handleMessage("startDiscovery", "{}");

    // Check again
    try bluetooth.handleMessage("isDiscovering", "{\"callbackId\":\"cb2\"}");
}

test "BluetoothBridge - handleMessage connectDevice valid address" {
    const allocator = testing.allocator;
    var bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);
    defer bluetooth.deinit();

    try bluetooth.handleMessage("connectDevice", "{\"address\":\"00:11:22:33:44:55\"}");
}

test "BluetoothBridge - handleMessage connectDevice missing address" {
    const allocator = testing.allocator;
    var bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);
    defer bluetooth.deinit();

    // Should handle missing address gracefully
    try bluetooth.handleMessage("connectDevice", "{}");
}

test "BluetoothBridge - handleMessage disconnectDevice valid address" {
    const allocator = testing.allocator;
    var bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);
    defer bluetooth.deinit();

    try bluetooth.handleMessage("disconnectDevice", "{\"address\":\"00:11:22:33:44:55\"}");
}

test "BluetoothBridge - handleMessage disconnectDevice missing address" {
    const allocator = testing.allocator;
    var bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);
    defer bluetooth.deinit();

    // Should handle missing address gracefully
    try bluetooth.handleMessage("disconnectDevice", "{}");
}

test "BluetoothBridge - handleMessage openBluetoothPreferences" {
    const allocator = testing.allocator;
    var bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);
    defer bluetooth.deinit();

    try bluetooth.handleMessage("openBluetoothPreferences", "{}");
}

test "BluetoothBridge - scanning state management" {
    const allocator = testing.allocator;
    var bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);
    defer bluetooth.deinit();

    // Initially not scanning
    try testing.expect(bluetooth.is_scanning == false);

    // Start scanning
    try bluetooth.handleMessage("startDiscovery", "{}");

    // Stop scanning
    try bluetooth.handleMessage("stopDiscovery", "{}");
    try testing.expect(bluetooth.is_scanning == false);
}

test "BluetoothBridge - deinit while scanning" {
    const allocator = testing.allocator;
    var bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);

    // Start scanning
    bluetooth.is_scanning = true;

    // Should clean up properly
    bluetooth.deinit();

    try testing.expect(bluetooth.is_scanning == false);
}

test "BluetoothBridge - global bridge functions" {
    const allocator = testing.allocator;
    var bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);
    defer bluetooth.deinit();

    // Test that global functions exist and work
    _ = bridge_bluetooth.getGlobalBluetoothBridge();
    bridge_bluetooth.setGlobalBluetoothBridge(&bluetooth);

    const global = bridge_bluetooth.getGlobalBluetoothBridge();
    try testing.expect(global != null);
}

test "BluetoothBridge - multiple sequential calls" {
    const allocator = testing.allocator;
    var bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);
    defer bluetooth.deinit();

    // Should handle multiple calls without issues
    try bluetooth.handleMessage("isAvailable", "{\"callbackId\":\"cb1\"}");
    try bluetooth.handleMessage("isEnabled", "{\"callbackId\":\"cb2\"}");
    try bluetooth.handleMessage("getPowerState", "{\"callbackId\":\"cb3\"}");
    try bluetooth.handleMessage("startDiscovery", "{}");
    try bluetooth.handleMessage("getConnectedDevices", "{\"callbackId\":\"cb4\"}");
    try bluetooth.handleMessage("stopDiscovery", "{}");
}

test "BluetoothBridge - callback ID extraction" {
    const allocator = testing.allocator;
    var bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);
    defer bluetooth.deinit();

    // Test various callback ID formats
    try bluetooth.handleMessage("isAvailable", "{\"callbackId\":\"simple\"}");
    try bluetooth.handleMessage("isEnabled", "{\"callbackId\":\"with-dashes\"}");
    try bluetooth.handleMessage("getPowerState", "{\"callbackId\":\"with_underscores\"}");
    try bluetooth.handleMessage("getConnectedDevices", "{\"callbackId\":\"123456\"}");
}

test "BluetoothBridge - MAC address formats" {
    const allocator = testing.allocator;
    var bluetooth = bridge_bluetooth.BluetoothBridge.init(allocator);
    defer bluetooth.deinit();

    // Test different MAC address formats
    try bluetooth.handleMessage("connectDevice", "{\"address\":\"00:11:22:33:44:55\"}");
    try bluetooth.handleMessage("connectDevice", "{\"address\":\"AA:BB:CC:DD:EE:FF\"}");
    try bluetooth.handleMessage("connectDevice", "{\"address\":\"aa:bb:cc:dd:ee:ff\"}");
}
