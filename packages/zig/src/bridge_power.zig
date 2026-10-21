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
    activity_token: ?*anyopaque = null,

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

            const cross_bridge = @import("bridge.zig");
            cross_bridge.evalJS(js) catch |err| {
                std.log.debug("JS eval failed for getBatteryLevel callback: {}", .{err});
            };
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
            // Desktop Macs are always "charging" (plugged in)
            // For MacBooks, would need IOPSCopyPowerSourcesInfo
            const charging = false;

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftPowerCallback)window.__craftPowerCallback('{s}','isCharging',{});", .{ callback_id, charging }) catch return;

            const cross_bridge = @import("bridge.zig");
            cross_bridge.evalJS(js) catch |err| {
                std.log.debug("JS eval failed for isCharging callback: {}", .{err});
            };
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
            // For desktop Macs, always true
            // For MacBooks, would need IOPSCopyPowerSourcesInfo
            const plugged_in = true;

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftPowerCallback)window.__craftPowerCallback('{s}','isPluggedIn',{});", .{ callback_id, plugged_in }) catch return;

            const cross_bridge = @import("bridge.zig");
            cross_bridge.evalJS(js) catch |err| {
                std.log.debug("JS eval failed for isPluggedIn callback: {}", .{err});
            };
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
            // Default to "noBattery" for desktop Macs
            // Full implementation would use IOPSCopyPowerSourcesInfo
            const state = "noBattery";

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftPowerCallback)window.__craftPowerCallback('{s}','getBatteryState','{s}');", .{ callback_id, state }) catch return;

            const cross_bridge = @import("bridge.zig");
            cross_bridge.evalJS(js) catch |err| {
                std.log.debug("JS eval failed for getBatteryState callback: {}", .{err});
            };
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
            // Return -1 for desktop Macs or when not applicable
            const remaining: i32 = -1;

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftPowerCallback)window.__craftPowerCallback('{s}','getTimeRemaining',{d});", .{ callback_id, remaining }) catch return;

            const cross_bridge = @import("bridge.zig");
            cross_bridge.evalJS(js) catch |err| {
                std.log.debug("JS eval failed for getTimeRemaining callback: {}", .{err});
            };
        }
    }

    /// Prevent system from sleeping
    /// JSON: {"reason": "Downloading file"}
    fn preventSleep(self: *Self, data: []const u8) !void {
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, data, .{}) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        if (parsed.value != .object) return BridgeError.InvalidJSON;
        const reason = if (parsed.value.object.get("reason")) |value| blk: {
            if (value != .string) return BridgeError.InvalidJSON;
            break :blk value.string;
        } else "Application request";

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            const process_info = macos.msgSend0(macos.getClass("NSProcessInfo"), "processInfo");
            const reason_z = try @import("memory.zig").dupeZ(self.allocator, u8, reason);
            defer self.allocator.free(reason_z);
            const reason_str = macos.msgSend1(macos.getClass("NSString"), "stringWithUTF8String:", reason_z.ptr);
            // NSActivityIdleDisplaySleepDisabled | NSActivityUserInitiated.
            // UserInitiated includes IdleSystemSleepDisabled; display sleep is separate.
            const activity_options: u64 = (1 << 40) | 0x00FFFFFF;
            const token = macos.msgSend2(process_info, "beginActivityWithOptions:reason:", activity_options, reason_str);
            if (token == null) return BridgeError.NativeCallFailed;
            _ = macos.msgSend0(token, "retain");
            // Acquire before releasing: replacement must not leave a gap or leak.
            try self.allowSleep("{}");
            self.activity_token = token;
            self.sleep_disabled = true;
        }
    }

    /// Release the exact activity acquired by preventSleep. Safe to repeat.
    fn allowSleep(self: *Self, data: []const u8) !void {
        _ = data;
        if (builtin.os.tag == .macos) {
            if (self.activity_token) |token| {
                const macos = @import("macos.zig");
                const process_info = macos.msgSend0(macos.getClass("NSProcessInfo"), "processInfo");
                _ = macos.msgSend1(process_info, "endActivity:", token);
                _ = macos.msgSend0(token, "release");
                self.activity_token = null;
            }
        }
        self.sleep_disabled = false;
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
            const low_power = macos.msgSendBool(process_info, "isLowPowerModeEnabled");

            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "if(window.__craftPowerCallback)window.__craftPowerCallback('{s}','isLowPowerMode',{});", .{ callback_id, low_power }) catch return;

            const cross_bridge = @import("bridge.zig");
            cross_bridge.evalJS(js) catch |err| {
                std.log.debug("JS eval failed for isLowPowerMode callback: {}", .{err});
            };
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

            const cross_bridge = @import("bridge.zig");
            cross_bridge.evalJS(js) catch |err| {
                std.log.debug("JS eval failed for getThermalState callback: {}", .{err});
            };
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

            const cross_bridge = @import("bridge.zig");
            cross_bridge.evalJS(js) catch |err| {
                std.log.debug("JS eval failed for getUptimeSeconds callback: {}", .{err});
            };
        }
    }

    pub fn deinit(self: *Self) void {
        self.allowSleep("{}") catch {};
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

test "native power activity is replaced and released" {
    if (builtin.os.tag != .macos) return;
    var power = PowerBridge.init(std.testing.allocator);
    defer power.deinit();
    try power.preventSleep("{\"reason\":\"Native lifecycle test\"}");
    try std.testing.expect(power.activity_token != null);
    const first = power.activity_token;
    try power.preventSleep("{}");
    try std.testing.expect(power.activity_token != null);
    try std.testing.expect(power.activity_token != first);
    try power.allowSleep("{}");
    try std.testing.expect(power.activity_token == null);
    try std.testing.expect(!power.sleep_disabled);
    try power.allowSleep("{}");
}

test "native power deinit ends its activity" {
    if (builtin.os.tag != .macos) return;
    var power = PowerBridge.init(std.testing.allocator);
    try power.preventSleep("{}");
    power.deinit();
    try std.testing.expect(power.activity_token == null);
    try std.testing.expect(!power.sleep_disabled);
}
