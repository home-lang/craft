const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Network status bridge for connection monitoring
pub const NetworkBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    /// Handle network-related messages from JavaScript
    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        self.handleMessageInternal(action, data) catch |err| {
            self.reportError(action, err);
        };
    }

    fn handleMessageInternal(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "isConnected")) {
            try self.isConnected(data);
        } else if (std.mem.eql(u8, action, "getConnectionType")) {
            try self.getConnectionType(data);
        } else if (std.mem.eql(u8, action, "getWiFiSSID")) {
            try self.getWiFiSSID(data);
        } else if (std.mem.eql(u8, action, "getWiFiSignalStrength")) {
            try self.getWiFiSignalStrength(data);
        } else if (std.mem.eql(u8, action, "getIPAddress")) {
            try self.getIPAddress(data);
        } else if (std.mem.eql(u8, action, "getMACAddress")) {
            try self.getMACAddress(data);
        } else if (std.mem.eql(u8, action, "getNetworkInterfaces")) {
            try self.getNetworkInterfaces(data);
        } else if (std.mem.eql(u8, action, "isVPNConnected")) {
            try self.isVPNConnected(data);
        } else if (std.mem.eql(u8, action, "getProxySettings")) {
            try self.getProxySettings(data);
        } else if (std.mem.eql(u8, action, "openNetworkPreferences")) {
            try self.openNetworkPreferences(data);
        } else {
            return BridgeError.UnknownAction;
        }
    }

    fn reportError(self: *Self, action: []const u8, err: anyerror) void {
        const bridge_err: BridgeError = switch (err) {
            BridgeError.MissingData => BridgeError.MissingData,
            BridgeError.InvalidJSON => BridgeError.InvalidJSON,
            else => BridgeError.NativeCallFailed,
        };
        bridge_error.sendErrorToJS(self.allocator, action, bridge_err);
    }

    /// Check if device has network connectivity
    /// JSON: {"callbackId": "cb1"}
    fn isConnected(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        std.debug.print("[NetworkBridge] isConnected\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Simple check: try to resolve a hostname
            // In a full implementation, use SCNetworkReachability
            // For now, assume connected if we can get to this code
            const connected = true;

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftNetworkCallback)window.__craftNetworkCallback('{s}','isConnected',{});", .{ callback_id, connected }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Get connection type (wifi, ethernet, cellular, none)
    /// JSON: {"callbackId": "cb1"}
    fn getConnectionType(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        std.debug.print("[NetworkBridge] getConnectionType\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Check for WiFi using CoreWLAN via NSClassFromString
            // This is simplified - full implementation would check active interfaces
            const CWWiFiClient = macos.getClass("CWWiFiClient");
            var conn_type: []const u8 = "ethernet"; // Default assumption

            if (CWWiFiClient != null) {
                const shared_client = macos.msgSend0(CWWiFiClient, "sharedWiFiClient");
                if (shared_client != null) {
                    const interface = macos.msgSend0(shared_client, "interface");
                    if (interface != null) {
                        const power_on = macos.msgSend0Bool(interface, "powerOn");
                        if (power_on) {
                            conn_type = "wifi";
                        }
                    }
                }
            }

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftNetworkCallback)window.__craftNetworkCallback('{s}','getConnectionType','{s}');", .{ callback_id, conn_type }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Get current WiFi network name (SSID)
    /// JSON: {"callbackId": "cb1"}
    fn getWiFiSSID(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        std.debug.print("[NetworkBridge] getWiFiSSID\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            var ssid: []const u8 = "";

            const CWWiFiClient = macos.getClass("CWWiFiClient");
            if (CWWiFiClient != null) {
                const shared_client = macos.msgSend0(CWWiFiClient, "sharedWiFiClient");
                if (shared_client != null) {
                    const interface = macos.msgSend0(shared_client, "interface");
                    if (interface != null) {
                        const ssid_obj = macos.msgSend0(interface, "ssid");
                        if (ssid_obj != null) {
                            const ssid_cstr: [*c]const u8 = @ptrCast(macos.msgSend0(ssid_obj, "UTF8String"));
                            if (ssid_cstr != null) {
                                ssid = std.mem.span(ssid_cstr);
                            }
                        }
                    }
                }
            }

            var buf: [512]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftNetworkCallback)window.__craftNetworkCallback('{s}','getWiFiSSID','{s}');", .{ callback_id, ssid }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Get WiFi signal strength (RSSI in dBm)
    /// JSON: {"callbackId": "cb1"}
    fn getWiFiSignalStrength(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        std.debug.print("[NetworkBridge] getWiFiSignalStrength\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            var rssi: i32 = 0;

            const CWWiFiClient = macos.getClass("CWWiFiClient");
            if (CWWiFiClient != null) {
                const shared_client = macos.msgSend0(CWWiFiClient, "sharedWiFiClient");
                if (shared_client != null) {
                    const interface = macos.msgSend0(shared_client, "interface");
                    if (interface != null) {
                        // rssiValue returns NSInteger
                        rssi = @intCast(@intFromPtr(macos.msgSend0(interface, "rssiValue")));
                    }
                }
            }

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftNetworkCallback)window.__craftNetworkCallback('{s}','getWiFiSignalStrength',{d});", .{ callback_id, rssi }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Get IP address of primary interface
    /// JSON: {"callbackId": "cb1"}
    fn getIPAddress(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        std.debug.print("[NetworkBridge] getIPAddress\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Get local IP using NSHost
            const NSHost = macos.getClass("NSHost");
            const current_host = macos.msgSend0(NSHost, "currentHost");
            const addresses = macos.msgSend0(current_host, "addresses");

            var ip_addr: []const u8 = "";

            // Get first non-localhost address
            const count: usize = @intFromPtr(macos.msgSend0(addresses, "count"));
            var i: usize = 0;
            while (i < count) : (i += 1) {
                const addr_obj = macos.msgSend1(addresses, "objectAtIndex:", i);
                const addr_cstr: [*c]const u8 = @ptrCast(macos.msgSend0(addr_obj, "UTF8String"));
                const addr_str = std.mem.span(addr_cstr);

                // Skip localhost and IPv6
                if (!std.mem.startsWith(u8, addr_str, "127.") and
                    !std.mem.startsWith(u8, addr_str, "::") and
                    !std.mem.startsWith(u8, addr_str, "fe80"))
                {
                    // Check if it looks like IPv4
                    if (std.mem.indexOf(u8, addr_str, ".") != null and
                        std.mem.indexOf(u8, addr_str, ":") == null)
                    {
                        ip_addr = addr_str;
                        break;
                    }
                }
            }

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftNetworkCallback)window.__craftNetworkCallback('{s}','getIPAddress','{s}');", .{ callback_id, ip_addr }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Get MAC address of primary interface
    /// JSON: {"callbackId": "cb1"}
    fn getMACAddress(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        std.debug.print("[NetworkBridge] getMACAddress\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            var mac_addr: []const u8 = "";

            const CWWiFiClient = macos.getClass("CWWiFiClient");
            if (CWWiFiClient != null) {
                const shared_client = macos.msgSend0(CWWiFiClient, "sharedWiFiClient");
                if (shared_client != null) {
                    const interface = macos.msgSend0(shared_client, "interface");
                    if (interface != null) {
                        const hw_addr = macos.msgSend0(interface, "hardwareAddress");
                        if (hw_addr != null) {
                            const mac_cstr: [*c]const u8 = @ptrCast(macos.msgSend0(hw_addr, "UTF8String"));
                            if (mac_cstr != null) {
                                mac_addr = std.mem.span(mac_cstr);
                            }
                        }
                    }
                }
            }

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftNetworkCallback)window.__craftNetworkCallback('{s}','getMACAddress','{s}');", .{ callback_id, mac_addr }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Get list of network interfaces
    /// JSON: {"callbackId": "cb1"}
    fn getNetworkInterfaces(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        std.debug.print("[NetworkBridge] getNetworkInterfaces\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Return basic interface info
            // Full implementation would use getifaddrs
            var buf: [1024]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftNetworkCallback)window.__craftNetworkCallback('{s}','getNetworkInterfaces',[{{name:'en0',type:'wifi'}},{{name:'en1',type:'ethernet'}}]);", .{callback_id}) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Check if VPN is connected
    /// JSON: {"callbackId": "cb1"}
    fn isVPNConnected(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        std.debug.print("[NetworkBridge] isVPNConnected\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Check for utun interfaces which indicate VPN
            // Simplified - full implementation would check NEVPNManager
            const vpn_connected = false;

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftNetworkCallback)window.__craftNetworkCallback('{s}','isVPNConnected',{});", .{ callback_id, vpn_connected }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Get proxy settings
    /// JSON: {"callbackId": "cb1"}
    fn getProxySettings(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        std.debug.print("[NetworkBridge] getProxySettings\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Return null for no proxy
            // Full implementation would use SCDynamicStoreCopyProxies
            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftNetworkCallback)window.__craftNetworkCallback('{s}','getProxySettings',null);", .{callback_id}) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Open Network Preferences pane
    /// JSON: {}
    fn openNetworkPreferences(self: *Self, data: []const u8) !void {
        _ = self;
        _ = data;

        std.debug.print("[NetworkBridge] openNetworkPreferences\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const NSWorkspace = macos.getClass("NSWorkspace");
            const workspace = macos.msgSend0(NSWorkspace, "sharedWorkspace");

            const NSString = macos.getClass("NSString");
            const url_str = macos.msgSend1(NSString, "stringWithUTF8String:", @as([*c]const u8, "x-apple.systempreferences:com.apple.preference.network"));

            const NSURL = macos.getClass("NSURL");
            const nsurl = macos.msgSend1(NSURL, "URLWithString:", url_str);

            _ = macos.msgSend1(workspace, "openURL:", nsurl);
        }
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};

/// Global network bridge instance
var global_network_bridge: ?*NetworkBridge = null;

pub fn getGlobalNetworkBridge() ?*NetworkBridge {
    return global_network_bridge;
}

pub fn setGlobalNetworkBridge(bridge: *NetworkBridge) void {
    global_network_bridge = bridge;
}
