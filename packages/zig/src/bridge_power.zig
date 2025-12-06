const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");
const logging = @import("logging.zig");

const BridgeError = bridge_error.BridgeError;
const log = logging.power;

/// Power management bridge for sleep/wake events, battery status
pub const PowerBridge = struct {
    allocator: std.mem.Allocator,
    sleep_disabled: bool = false,
    assertion_id: u32 = 0,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    /// Handle power-related messages from JavaScript
    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        self.handleMessageInternal(action, data) catch |err| {
            self.reportError(action, err);
        };
    }

    fn handleMessageInternal(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "getBatteryLevel")) {
            try self.getBatteryLevel(data);
        } else if (std.mem.eql(u8, action, "isCharging")) {
            try self.isCharging(data);
        } else if (std.mem.eql(u8, action, "isPluggedIn")) {
            try self.isPluggedIn(data);
        } else if (std.mem.eql(u8, action, "getBatteryState")) {
            try self.getBatteryState(data);
        } else if (std.mem.eql(u8, action, "getTimeRemaining")) {
            try self.getTimeRemaining(data);
        } else if (std.mem.eql(u8, action, "preventSleep")) {
            try self.preventSleep(data);
        } else if (std.mem.eql(u8, action, "allowSleep")) {
            try self.allowSleep(data);
        } else if (std.mem.eql(u8, action, "isLowPowerMode")) {
            try self.isLowPowerMode(data);
        } else if (std.mem.eql(u8, action, "getThermalState")) {
            try self.getThermalState(data);
        } else if (std.mem.eql(u8, action, "getUptimeSeconds")) {
            try self.getUptimeSeconds(data);
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

    /// Get battery level (0-100)
    /// JSON: {"callbackId": "cb1"}
    fn getBatteryLevel(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        log.debug("getBatteryLevel", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Use IOKit to get battery info via NSProcessInfo for simplicity
            const NSProcessInfo = macos.getClass("NSProcessInfo");
            const process_info = macos.msgSend0(NSProcessInfo, "processInfo");

            // Check if running on battery (lowPowerModeEnabled gives us some info)
            // For actual battery level, we'd need IOKit - return -1 for desktop Macs
            _ = process_info;

            // Simplified: return -1 for devices without battery
            // In a full implementation, use IOPSCopyPowerSourcesInfo
            const level: i32 = -1;

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftPowerCallback)window.__craftPowerCallback('{s}','getBatteryLevel',{d});", .{ callback_id, level }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Check if device is charging
    /// JSON: {"callbackId": "cb1"}
    fn isCharging(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        log.debug("isCharging", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Desktop Macs are always "charging" (plugged in)
            // For MacBooks, would need IOPSCopyPowerSourcesInfo
            const charging = false;

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftPowerCallback)window.__craftPowerCallback('{s}','isCharging',{});", .{ callback_id, charging }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Check if device is plugged in (on AC power)
    /// JSON: {"callbackId": "cb1"}
    fn isPluggedIn(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        log.debug("isPluggedIn", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // For desktop Macs, always true
            // For MacBooks, would need IOPSCopyPowerSourcesInfo
            const plugged_in = true;

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftPowerCallback)window.__craftPowerCallback('{s}','isPluggedIn',{});", .{ callback_id, plugged_in }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Get battery state (unknown, unplugged, charging, charged, noBattery)
    /// JSON: {"callbackId": "cb1"}
    fn getBatteryState(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        log.debug("getBatteryState", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Default to "noBattery" for desktop Macs
            // Full implementation would use IOPSCopyPowerSourcesInfo
            const state = "noBattery";

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftPowerCallback)window.__craftPowerCallback('{s}','getBatteryState','{s}');", .{ callback_id, state }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Get time remaining on battery (minutes, -1 if calculating or N/A)
    /// JSON: {"callbackId": "cb1"}
    fn getTimeRemaining(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        log.debug("getTimeRemaining", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Return -1 for desktop Macs or when not applicable
            const remaining: i32 = -1;

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftPowerCallback)window.__craftPowerCallback('{s}','getTimeRemaining',{d});", .{ callback_id, remaining }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Prevent system from sleeping
    /// JSON: {"reason": "Downloading file"}
    fn preventSleep(self: *Self, data: []const u8) !void {
        var reason: []const u8 = "Application request";

        if (std.mem.indexOf(u8, data, "\"reason\":\"")) |idx| {
            const start = idx + 10;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                reason = data[start..end];
            }
        }

        log.debug("preventSleep: {s}", .{reason});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Use NSProcessInfo to disable sleep
            const NSProcessInfo = macos.getClass("NSProcessInfo");
            const process_info = macos.msgSend0(NSProcessInfo, "processInfo");

            // beginActivityWithOptions:reason:
            // NSActivityUserInitiated | NSActivityIdleSystemSleepDisabled = 0x00FFFFFF | 0x00000001
            const activity_options: u64 = 0x00FFFFFF;

            const NSString = macos.getClass("NSString");
            const reason_str = macos.msgSend1(NSString, "stringWithUTF8String:", @as([*c]const u8, @ptrCast(reason.ptr)));

            _ = macos.msgSend2(process_info, "beginActivityWithOptions:reason:", activity_options, reason_str);

            self.sleep_disabled = true;
        }
    }

    /// Allow system to sleep again
    /// JSON: {}
    fn allowSleep(self: *Self, data: []const u8) !void {
        _ = data;

        log.debug("allowSleep", .{});

        if (builtin.os.tag == .macos) {
            // Note: In a full implementation, we'd need to track the activity token
            // and call endActivity: on it. For now, just mark as allowed.
            self.sleep_disabled = false;
        }
    }

    /// Check if Low Power Mode is enabled
    /// JSON: {"callbackId": "cb1"}
    fn isLowPowerMode(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        log.debug("isLowPowerMode", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const NSProcessInfo = macos.getClass("NSProcessInfo");
            const process_info = macos.msgSend0(NSProcessInfo, "processInfo");
            const low_power = macos.msgSend0Bool(process_info, "isLowPowerModeEnabled");

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftPowerCallback)window.__craftPowerCallback('{s}','isLowPowerMode',{});", .{ callback_id, low_power }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Get thermal state (nominal, fair, serious, critical)
    /// JSON: {"callbackId": "cb1"}
    fn getThermalState(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        log.debug("getThermalState", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const NSProcessInfo = macos.getClass("NSProcessInfo");
            const process_info = macos.msgSend0(NSProcessInfo, "processInfo");

            // thermalState returns NSProcessInfoThermalState enum (0-3)
            const thermal_state: i64 = @intCast(@intFromPtr(macos.msgSend0(process_info, "thermalState")));

            const state_str = switch (thermal_state) {
                0 => "nominal",
                1 => "fair",
                2 => "serious",
                3 => "critical",
                else => "unknown",
            };

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftPowerCallback)window.__craftPowerCallback('{s}','getThermalState','{s}');", .{ callback_id, state_str }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Get system uptime in seconds
    /// JSON: {"callbackId": "cb1"}
    fn getUptimeSeconds(self: *Self, data: []const u8) !void {
        _ = self;
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        log.debug("getUptimeSeconds", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const NSProcessInfo = macos.getClass("NSProcessInfo");
            const process_info = macos.msgSend0(NSProcessInfo, "processInfo");

            // systemUptime returns NSTimeInterval (double)
            const uptime: f64 = macos.msgSend0Double(process_info, "systemUptime");
            const uptime_int: i64 = @intFromFloat(uptime);

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftPowerCallback)window.__craftPowerCallback('{s}','getUptimeSeconds',{d});", .{ callback_id, uptime_int }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    pub fn deinit(self: *Self) void {
        if (self.sleep_disabled) {
            // Would release activity assertion here
            self.sleep_disabled = false;
        }
    }
};

/// Global power bridge instance
var global_power_bridge: ?*PowerBridge = null;

pub fn getGlobalPowerBridge() ?*PowerBridge {
    return global_power_bridge;
}

pub fn setGlobalPowerBridge(bridge: *PowerBridge) void {
    global_power_bridge = bridge;
}
