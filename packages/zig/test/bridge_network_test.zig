const std = @import("std");
const testing = std.testing;
const bridge_network = @import("../src/bridge_network.zig");
const bridge_error = @import("../src/bridge_error.zig");

test "NetworkBridge - init" {
    const allocator = testing.allocator;
    const network = bridge_network.NetworkBridge.init(allocator);

    try testing.expectEqual(allocator, network.allocator);
}

test "NetworkBridge - handleMessage unknown action" {
    const allocator = testing.allocator;
    var network = bridge_network.NetworkBridge.init(allocator);
    defer network.deinit();

    // Unknown action should not crash - it reports error to JS
    try network.handleMessage("unknownAction", "{}");
}

test "NetworkBridge - handleMessage isConnected" {
    const allocator = testing.allocator;
    var network = bridge_network.NetworkBridge.init(allocator);
    defer network.deinit();

    try network.handleMessage("isConnected", "{\"callbackId\":\"cb1\"}");
    try network.handleMessage("isConnected", "{}");
}

test "NetworkBridge - handleMessage getConnectionType" {
    const allocator = testing.allocator;
    var network = bridge_network.NetworkBridge.init(allocator);
    defer network.deinit();

    try network.handleMessage("getConnectionType", "{\"callbackId\":\"cb1\"}");
    try network.handleMessage("getConnectionType", "{}");
}

test "NetworkBridge - handleMessage getWiFiSSID" {
    const allocator = testing.allocator;
    var network = bridge_network.NetworkBridge.init(allocator);
    defer network.deinit();

    try network.handleMessage("getWiFiSSID", "{\"callbackId\":\"cb1\"}");
    try network.handleMessage("getWiFiSSID", "{}");
}

test "NetworkBridge - handleMessage getWiFiSignalStrength" {
    const allocator = testing.allocator;
    var network = bridge_network.NetworkBridge.init(allocator);
    defer network.deinit();

    try network.handleMessage("getWiFiSignalStrength", "{\"callbackId\":\"cb1\"}");
    try network.handleMessage("getWiFiSignalStrength", "{}");
}

test "NetworkBridge - handleMessage getIPAddress" {
    const allocator = testing.allocator;
    var network = bridge_network.NetworkBridge.init(allocator);
    defer network.deinit();

    try network.handleMessage("getIPAddress", "{\"callbackId\":\"cb1\"}");
    try network.handleMessage("getIPAddress", "{}");
}

test "NetworkBridge - handleMessage getMACAddress" {
    const allocator = testing.allocator;
    var network = bridge_network.NetworkBridge.init(allocator);
    defer network.deinit();

    try network.handleMessage("getMACAddress", "{\"callbackId\":\"cb1\"}");
    try network.handleMessage("getMACAddress", "{}");
}

test "NetworkBridge - handleMessage getNetworkInterfaces" {
    const allocator = testing.allocator;
    var network = bridge_network.NetworkBridge.init(allocator);
    defer network.deinit();

    try network.handleMessage("getNetworkInterfaces", "{\"callbackId\":\"cb1\"}");
    try network.handleMessage("getNetworkInterfaces", "{}");
}

test "NetworkBridge - handleMessage isVPNConnected" {
    const allocator = testing.allocator;
    var network = bridge_network.NetworkBridge.init(allocator);
    defer network.deinit();

    try network.handleMessage("isVPNConnected", "{\"callbackId\":\"cb1\"}");
    try network.handleMessage("isVPNConnected", "{}");
}

test "NetworkBridge - handleMessage getProxySettings" {
    const allocator = testing.allocator;
    var network = bridge_network.NetworkBridge.init(allocator);
    defer network.deinit();

    try network.handleMessage("getProxySettings", "{\"callbackId\":\"cb1\"}");
    try network.handleMessage("getProxySettings", "{}");
}

test "NetworkBridge - handleMessage openNetworkPreferences" {
    const allocator = testing.allocator;
    var network = bridge_network.NetworkBridge.init(allocator);
    defer network.deinit();

    try network.handleMessage("openNetworkPreferences", "{}");
}

test "NetworkBridge - deinit" {
    const allocator = testing.allocator;
    var network = bridge_network.NetworkBridge.init(allocator);

    // Should not crash
    network.deinit();
}

test "NetworkBridge - global bridge functions" {
    const allocator = testing.allocator;
    var network = bridge_network.NetworkBridge.init(allocator);
    defer network.deinit();

    // Test that global functions exist and work
    _ = bridge_network.getGlobalNetworkBridge();
    bridge_network.setGlobalNetworkBridge(&network);

    const global = bridge_network.getGlobalNetworkBridge();
    try testing.expect(global != null);
}

test "NetworkBridge - multiple sequential calls" {
    const allocator = testing.allocator;
    var network = bridge_network.NetworkBridge.init(allocator);
    defer network.deinit();

    // Should handle multiple calls without issues
    try network.handleMessage("isConnected", "{\"callbackId\":\"cb1\"}");
    try network.handleMessage("getConnectionType", "{\"callbackId\":\"cb2\"}");
    try network.handleMessage("getWiFiSSID", "{\"callbackId\":\"cb3\"}");
    try network.handleMessage("getIPAddress", "{\"callbackId\":\"cb4\"}");
    try network.handleMessage("isVPNConnected", "{\"callbackId\":\"cb5\"}");
}

test "NetworkBridge - callback ID extraction" {
    const allocator = testing.allocator;
    var network = bridge_network.NetworkBridge.init(allocator);
    defer network.deinit();

    // Test various callback ID formats
    try network.handleMessage("isConnected", "{\"callbackId\":\"simple\"}");
    try network.handleMessage("getConnectionType", "{\"callbackId\":\"with-dashes\"}");
    try network.handleMessage("getWiFiSSID", "{\"callbackId\":\"with_underscores\"}");
    try network.handleMessage("getIPAddress", "{\"callbackId\":\"123456\"}");
}

test "NetworkBridge - all actions with empty callback" {
    const allocator = testing.allocator;
    var network = bridge_network.NetworkBridge.init(allocator);
    defer network.deinit();

    // All these should handle empty/missing callback gracefully
    try network.handleMessage("isConnected", "{}");
    try network.handleMessage("getConnectionType", "{}");
    try network.handleMessage("getWiFiSSID", "{}");
    try network.handleMessage("getWiFiSignalStrength", "{}");
    try network.handleMessage("getIPAddress", "{}");
    try network.handleMessage("getMACAddress", "{}");
    try network.handleMessage("getNetworkInterfaces", "{}");
    try network.handleMessage("isVPNConnected", "{}");
    try network.handleMessage("getProxySettings", "{}");
}

test "NetworkBridge - malformed JSON" {
    const allocator = testing.allocator;
    var network = bridge_network.NetworkBridge.init(allocator);
    defer network.deinit();

    // Should handle malformed JSON gracefully
    try network.handleMessage("isConnected", "not json");
    try network.handleMessage("getConnectionType", "{invalid}");
    try network.handleMessage("getWiFiSSID", "");
}

test "NetworkBridge - repeated init and deinit" {
    const allocator = testing.allocator;

    // Should be able to create and destroy multiple instances
    var network1 = bridge_network.NetworkBridge.init(allocator);
    network1.deinit();

    var network2 = bridge_network.NetworkBridge.init(allocator);
    network2.deinit();

    var network3 = bridge_network.NetworkBridge.init(allocator);
    defer network3.deinit();

    try network3.handleMessage("isConnected", "{\"callbackId\":\"test\"}");
}
