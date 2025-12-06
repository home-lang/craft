const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");
const logging = @import("logging.zig");

const BridgeError = bridge_error.BridgeError;
const log = logging.scoped("Bluetooth");

/// Bluetooth bridge for device discovery and connection
pub const BluetoothBridge = struct {
    allocator: std.mem.Allocator,
    is_scanning: bool = false,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    /// Handle bluetooth-related messages from JavaScript
    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        self.handleMessageInternal(action, data) catch |err| {
            self.reportError(action, err);
        };
    }

    fn handleMessageInternal(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "isAvailable")) {
            try self.isAvailable(data);
        } else if (std.mem.eql(u8, action, "isEnabled")) {
            try self.isEnabled(data);
        } else if (std.mem.eql(u8, action, "getPowerState")) {
            try self.getPowerState(data);
        } else if (std.mem.eql(u8, action, "getConnectedDevices")) {
            try self.getConnectedDevices(data);
        } else if (std.mem.eql(u8, action, "getPairedDevices")) {
            try self.getPairedDevices(data);
        } else if (std.mem.eql(u8, action, "startDiscovery")) {
            try self.startDiscovery(data);
        } else if (std.mem.eql(u8, action, "stopDiscovery")) {
            try self.stopDiscovery(data);
        } else if (std.mem.eql(u8, action, "isDiscovering")) {
            try self.isDiscovering(data);
        } else if (std.mem.eql(u8, action, "connectDevice")) {
            try self.connectDevice(data);
        } else if (std.mem.eql(u8, action, "disconnectDevice")) {
            try self.disconnectDevice(data);
        } else if (std.mem.eql(u8, action, "openBluetoothPreferences")) {
            try self.openBluetoothPreferences(data);
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

    /// Check if Bluetooth is available on this device
    /// JSON: {"callbackId": "cb1"}
    fn isAvailable(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        log.debug("isAvailable", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Check if IOBluetooth framework is available
            const IOBluetoothHostController = macos.getClass("IOBluetoothHostController");
            const available = IOBluetoothHostController != null;

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftBluetoothCallback)window.__craftBluetoothCallback('{s}','isAvailable',{});", .{ callback_id, available }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Check if Bluetooth is enabled (powered on)
    /// JSON: {"callbackId": "cb1"}
    fn isEnabled(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        log.debug("isEnabled", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            var enabled = false;

            const IOBluetoothHostController = macos.getClass("IOBluetoothHostController");
            if (IOBluetoothHostController != null) {
                const default_controller = macos.msgSend0(IOBluetoothHostController, "defaultController");
                if (default_controller != null) {
                    // powerState: 0 = off, 1 = on, 2 = initializing
                    const power_state: i32 = @intCast(@intFromPtr(macos.msgSend0(default_controller, "powerState")));
                    enabled = power_state == 1;
                }
            }

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftBluetoothCallback)window.__craftBluetoothCallback('{s}','isEnabled',{});", .{ callback_id, enabled }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Get Bluetooth power state (off, on, initializing, unknown)
    /// JSON: {"callbackId": "cb1"}
    fn getPowerState(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        log.debug("getPowerState", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            var state: []const u8 = "unknown";

            const IOBluetoothHostController = macos.getClass("IOBluetoothHostController");
            if (IOBluetoothHostController != null) {
                const default_controller = macos.msgSend0(IOBluetoothHostController, "defaultController");
                if (default_controller != null) {
                    const power_state: i32 = @intCast(@intFromPtr(macos.msgSend0(default_controller, "powerState")));
                    state = switch (power_state) {
                        0 => "off",
                        1 => "on",
                        2 => "initializing",
                        else => "unknown",
                    };
                }
            }

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftBluetoothCallback)window.__craftBluetoothCallback('{s}','getPowerState','{s}');", .{ callback_id, state }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Get list of connected Bluetooth devices
    /// JSON: {"callbackId": "cb1"}
    fn getConnectedDevices(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        log.debug("getConnectedDevices", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Get connected devices from IOBluetoothDevice
            const IOBluetoothDevice = macos.getClass("IOBluetoothDevice");

            var result_buf: [4096]u8 = undefined;
            var result_pos: usize = 0;

            const prefix = "[";
            @memcpy(result_buf[result_pos .. result_pos + prefix.len], prefix);
            result_pos += prefix.len;

            if (IOBluetoothDevice != null) {
                const paired_devices = macos.msgSend0(IOBluetoothDevice, "pairedDevices");
                if (paired_devices != null) {
                    const count: usize = @intFromPtr(macos.msgSend0(paired_devices, "count"));
                    var first = true;

                    var i: usize = 0;
                    while (i < count) : (i += 1) {
                        const device = macos.msgSend1(paired_devices, "objectAtIndex:", i);
                        if (device != null) {
                            // Check if connected
                            const is_connected = macos.msgSend0Bool(device, "isConnected");
                            if (is_connected) {
                                if (!first) {
                                    result_buf[result_pos] = ',';
                                    result_pos += 1;
                                }
                                first = false;

                                // Get device name
                                const name_obj = macos.msgSend0(device, "name");
                                var name: []const u8 = "Unknown";
                                if (name_obj != null) {
                                    const name_cstr: [*c]const u8 = @ptrCast(macos.msgSend0(name_obj, "UTF8String"));
                                    if (name_cstr != null) {
                                        name = std.mem.span(name_cstr);
                                    }
                                }

                                // Get device address
                                const addr_obj = macos.msgSend0(device, "addressString");
                                var addr: []const u8 = "";
                                if (addr_obj != null) {
                                    const addr_cstr: [*c]const u8 = @ptrCast(macos.msgSend0(addr_obj, "UTF8String"));
                                    if (addr_cstr != null) {
                                        addr = std.mem.span(addr_cstr);
                                    }
                                }

                                const entry = std.fmt.bufPrint(result_buf[result_pos..], "{{\"name\":\"{s}\",\"address\":\"{s}\",\"connected\":true}}", .{ name, addr }) catch break;
                                result_pos += entry.len;
                            }
                        }
                    }
                }
            }

            result_buf[result_pos] = ']';
            result_pos += 1;

            var buf: [4500]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftBluetoothCallback)window.__craftBluetoothCallback('{s}','getConnectedDevices',{s});", .{ callback_id, result_buf[0..result_pos] }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Get list of paired Bluetooth devices
    /// JSON: {"callbackId": "cb1"}
    fn getPairedDevices(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        log.debug("getPairedDevices", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const IOBluetoothDevice = macos.getClass("IOBluetoothDevice");

            var result_buf: [4096]u8 = undefined;
            var result_pos: usize = 0;

            const prefix = "[";
            @memcpy(result_buf[result_pos .. result_pos + prefix.len], prefix);
            result_pos += prefix.len;

            if (IOBluetoothDevice != null) {
                const paired_devices = macos.msgSend0(IOBluetoothDevice, "pairedDevices");
                if (paired_devices != null) {
                    const count: usize = @intFromPtr(macos.msgSend0(paired_devices, "count"));
                    var first = true;

                    var i: usize = 0;
                    while (i < count and i < 20) : (i += 1) { // Limit to 20 devices
                        const device = macos.msgSend1(paired_devices, "objectAtIndex:", i);
                        if (device != null) {
                            if (!first) {
                                result_buf[result_pos] = ',';
                                result_pos += 1;
                            }
                            first = false;

                            const name_obj = macos.msgSend0(device, "name");
                            var name: []const u8 = "Unknown";
                            if (name_obj != null) {
                                const name_cstr: [*c]const u8 = @ptrCast(macos.msgSend0(name_obj, "UTF8String"));
                                if (name_cstr != null) {
                                    name = std.mem.span(name_cstr);
                                }
                            }

                            const addr_obj = macos.msgSend0(device, "addressString");
                            var addr: []const u8 = "";
                            if (addr_obj != null) {
                                const addr_cstr: [*c]const u8 = @ptrCast(macos.msgSend0(addr_obj, "UTF8String"));
                                if (addr_cstr != null) {
                                    addr = std.mem.span(addr_cstr);
                                }
                            }

                            const is_connected = macos.msgSend0Bool(device, "isConnected");

                            const entry = std.fmt.bufPrint(result_buf[result_pos..], "{{\"name\":\"{s}\",\"address\":\"{s}\",\"connected\":{}}}", .{ name, addr, is_connected }) catch break;
                            result_pos += entry.len;
                        }
                    }
                }
            }

            result_buf[result_pos] = ']';
            result_pos += 1;

            var buf: [4500]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftBluetoothCallback)window.__craftBluetoothCallback('{s}','getPairedDevices',{s});", .{ callback_id, result_buf[0..result_pos] }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Start Bluetooth device discovery
    /// JSON: {}
    fn startDiscovery(self: *Self, data: []const u8) !void {
        _ = data;

        log.debug("startDiscovery", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Note: Full implementation would use IOBluetoothDeviceInquiry
            // This requires setting up a delegate for callbacks
            self.is_scanning = true;

            // Send acknowledgment
            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftBluetoothCallback)window.__craftBluetoothCallback('','startDiscovery',{{started:true}});", .{}) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Stop Bluetooth device discovery
    /// JSON: {}
    fn stopDiscovery(self: *Self, data: []const u8) !void {
        _ = data;

        log.debug("stopDiscovery", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            self.is_scanning = false;

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftBluetoothCallback)window.__craftBluetoothCallback('','stopDiscovery',{{stopped:true}});", .{}) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Check if currently discovering devices
    /// JSON: {"callbackId": "cb1"}
    fn isDiscovering(self: *Self, data: []const u8) !void {
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        log.debug("isDiscovering", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftBluetoothCallback)window.__craftBluetoothCallback('{s}','isDiscovering',{});", .{ callback_id, self.is_scanning }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Connect to a Bluetooth device
    /// JSON: {"address": "XX:XX:XX:XX:XX:XX"}
    fn connectDevice(self: *Self, data: []const u8) !void {
        _ = self;
        var address: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"address\":\"")) |idx| {
            const start = idx + 11;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                address = data[start..end];
            }
        }

        if (address.len == 0) return BridgeError.MissingData;

        log.debug("connectDevice: {s}", .{address});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Note: Connecting to arbitrary devices requires IOBluetoothDevice APIs
            // This is a placeholder - full implementation would use:
            // [IOBluetoothDevice deviceWithAddressString:] then openConnection

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftBluetoothCallback)window.__craftBluetoothCallback('','connectDevice',{{address:'{s}',status:'pending'}});", .{address}) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Disconnect from a Bluetooth device
    /// JSON: {"address": "XX:XX:XX:XX:XX:XX"}
    fn disconnectDevice(self: *Self, data: []const u8) !void {
        _ = self;
        var address: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"address\":\"")) |idx| {
            const start = idx + 11;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                address = data[start..end];
            }
        }

        if (address.len == 0) return BridgeError.MissingData;

        log.debug("disconnectDevice: {s}", .{address});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftBluetoothCallback)window.__craftBluetoothCallback('','disconnectDevice',{{address:'{s}',status:'disconnected'}});", .{address}) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Open Bluetooth Preferences pane
    /// JSON: {}
    fn openBluetoothPreferences(self: *Self, data: []const u8) !void {
        _ = self;
        _ = data;

        log.debug("openBluetoothPreferences", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const NSWorkspace = macos.getClass("NSWorkspace");
            const workspace = macos.msgSend0(NSWorkspace, "sharedWorkspace");

            const NSString = macos.getClass("NSString");
            const url_str = macos.msgSend1(NSString, "stringWithUTF8String:", @as([*c]const u8, "x-apple.systempreferences:com.apple.preference.Bluetooth"));

            const NSURL = macos.getClass("NSURL");
            const nsurl = macos.msgSend1(NSURL, "URLWithString:", url_str);

            _ = macos.msgSend1(workspace, "openURL:", nsurl);
        }
    }

    pub fn deinit(self: *Self) void {
        if (self.is_scanning) {
            self.is_scanning = false;
        }
    }
};

/// Global bluetooth bridge instance
var global_bluetooth_bridge: ?*BluetoothBridge = null;

pub fn getGlobalBluetoothBridge() ?*BluetoothBridge {
    return global_bluetooth_bridge;
}

pub fn setGlobalBluetoothBridge(bridge: *BluetoothBridge) void {
    global_bluetooth_bridge = bridge;
}
