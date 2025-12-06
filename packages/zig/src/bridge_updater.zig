const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");
const logging = @import("logging.zig");

const log = logging.scoped("UpdaterBridge");

const BridgeError = bridge_error.BridgeError;

/// Auto-updater bridge using Sparkle framework
/// Sparkle must be linked with the application for this to work
pub const UpdaterBridge = struct {
    allocator: std.mem.Allocator,
    updater: ?*anyopaque = null,
    feed_url: ?[]const u8 = null,
    automatic_checks: bool = true,
    check_interval: u32 = 86400, // 24 hours in seconds

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    /// Handle updater-related messages from JavaScript
    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        self.handleMessageInternal(action, data) catch |err| {
            self.reportError(action, err);
        };
    }

    fn handleMessageInternal(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "configure")) {
            try self.configure(data);
        } else if (std.mem.eql(u8, action, "checkForUpdates")) {
            try self.checkForUpdates();
        } else if (std.mem.eql(u8, action, "checkForUpdatesInBackground")) {
            try self.checkForUpdatesInBackground();
        } else if (std.mem.eql(u8, action, "setAutomaticChecks")) {
            try self.setAutomaticChecks(data);
        } else if (std.mem.eql(u8, action, "setCheckInterval")) {
            try self.setCheckInterval(data);
        } else if (std.mem.eql(u8, action, "setFeedURL")) {
            try self.setFeedURL(data);
        } else if (std.mem.eql(u8, action, "getLastUpdateCheckDate")) {
            try self.getLastUpdateCheckDate();
        } else if (std.mem.eql(u8, action, "getUpdateInfo")) {
            try self.getUpdateInfo();
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

    /// Configure the updater with initial settings
    /// JSON: {"feedURL": "https://example.com/appcast.xml", "automaticChecks": true, "checkInterval": 86400}
    fn configure(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        // Initialize SUUpdater shared instance
        const SUUpdater = macos.getClass("SUUpdater");
        if (SUUpdater == null) {
            log.debug("Sparkle framework not available", .{});
            self.sendStatus("unavailable", "Sparkle framework not linked");
            return;
        }

        self.updater = macos.msgSend0(SUUpdater, "sharedUpdater");
        if (self.updater == null) {
            log.debug("Failed to get shared updater", .{});
            return;
        }

        // Parse and set feed URL
        if (std.mem.indexOf(u8, data, "\"feedURL\":\"")) |idx| {
            const start = idx + 11;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                const url = data[start..end];
                self.feed_url = try self.allocator.dupe(u8, url);

                // Create NSURL
                const NSString = macos.getClass("NSString");
                const url_str = macos.msgSend1(
                    NSString,
                    "stringWithUTF8String:",
                    @as([*c]const u8, @ptrCast(url.ptr)),
                );
                const NSURL = macos.getClass("NSURL");
                const nsurl = macos.msgSend1(NSURL, "URLWithString:", url_str);

                // Set feed URL on updater
                _ = macos.msgSend1(self.updater.?, "setFeedURL:", nsurl);
                log.debug("Feed URL set: {s}", .{url});
            }
        }

        // Parse automatic checks
        if (std.mem.indexOf(u8, data, "\"automaticChecks\":true")) |_| {
            self.automatic_checks = true;
            _ = macos.msgSend1Bool(self.updater.?, "setAutomaticallyChecksForUpdates:", true);
        } else if (std.mem.indexOf(u8, data, "\"automaticChecks\":false")) |_| {
            self.automatic_checks = false;
            _ = macos.msgSend1Bool(self.updater.?, "setAutomaticallyChecksForUpdates:", false);
        }

        // Parse check interval
        if (std.mem.indexOf(u8, data, "\"checkInterval\":")) |idx| {
            const start = idx + 16;
            var end = start;
            while (end < data.len and data[end] >= '0' and data[end] <= '9') : (end += 1) {}
            if (end > start) {
                const interval = std.fmt.parseInt(u32, data[start..end], 10) catch 86400;
                self.check_interval = interval;
                _ = macos.msgSend1Double(self.updater.?, "setUpdateCheckInterval:", @floatFromInt(interval));
                log.debug("Check interval set: {d}s", .{interval});
            }
        }

        self.sendStatus("configured", "Updater configured successfully");
    }

    /// Check for updates and show UI if available
    fn checkForUpdates(self: *Self) !void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        if (self.updater == null) {
            // Try to get shared updater
            const SUUpdater = macos.getClass("SUUpdater");
            if (SUUpdater != null) {
                self.updater = macos.msgSend0(SUUpdater, "sharedUpdater");
            }
        }

        if (self.updater) |updater| {
            log.debug("Checking for updates...", .{});
            _ = macos.msgSend1(updater, "checkForUpdates:", @as(?*anyopaque, null));
            self.sendStatus("checking", "Checking for updates");
        } else {
            self.sendStatus("unavailable", "Updater not initialized");
        }
    }

    /// Check for updates silently in background
    fn checkForUpdatesInBackground(self: *Self) !void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        if (self.updater == null) {
            const SUUpdater = macos.getClass("SUUpdater");
            if (SUUpdater != null) {
                self.updater = macos.msgSend0(SUUpdater, "sharedUpdater");
            }
        }

        if (self.updater) |updater| {
            log.debug("Checking for updates in background...", .{});
            _ = macos.msgSend0(updater, "checkForUpdatesInBackground");
            self.sendStatus("checking_background", "Checking for updates in background");
        }
    }

    /// Enable/disable automatic update checks
    /// JSON: {"enabled": true}
    fn setAutomaticChecks(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        const enabled = std.mem.indexOf(u8, data, "\"enabled\":true") != null;
        self.automatic_checks = enabled;

        if (self.updater) |updater| {
            _ = macos.msgSend1Bool(updater, "setAutomaticallyChecksForUpdates:", enabled);
            log.debug("Automatic checks: {}", .{enabled});
        }
    }

    /// Set the update check interval in seconds
    /// JSON: {"interval": 86400}
    fn setCheckInterval(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        if (std.mem.indexOf(u8, data, "\"interval\":")) |idx| {
            const start = idx + 11;
            var end = start;
            while (end < data.len and data[end] >= '0' and data[end] <= '9') : (end += 1) {}
            if (end > start) {
                const interval = std.fmt.parseInt(u32, data[start..end], 10) catch return;
                self.check_interval = interval;

                if (self.updater) |updater| {
                    _ = macos.msgSend1Double(updater, "setUpdateCheckInterval:", @floatFromInt(interval));
                    log.debug("Check interval: {d}s", .{interval});
                }
            }
        }
    }

    /// Set the appcast feed URL
    /// JSON: {"url": "https://example.com/appcast.xml"}
    fn setFeedURL(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        if (std.mem.indexOf(u8, data, "\"url\":\"")) |idx| {
            const start = idx + 7;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                const url = data[start..end];

                if (self.feed_url) |old_url| {
                    self.allocator.free(old_url);
                }
                self.feed_url = try self.allocator.dupe(u8, url);

                if (self.updater) |updater| {
                    const NSString = macos.getClass("NSString");
                    const url_str = macos.msgSend1(
                        NSString,
                        "stringWithUTF8String:",
                        @as([*c]const u8, @ptrCast(url.ptr)),
                    );
                    const NSURL = macos.getClass("NSURL");
                    const nsurl = macos.msgSend1(NSURL, "URLWithString:", url_str);
                    _ = macos.msgSend1(updater, "setFeedURL:", nsurl);
                    log.debug("Feed URL: {s}", .{url});
                }
            }
        }
    }

    /// Get the last update check date
    fn getLastUpdateCheckDate(self: *Self) !void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        if (self.updater) |updater| {
            const date = macos.msgSend0(updater, "lastUpdateCheckDate");
            if (date) |d| {
                // Get time interval since 1970
                const interval = macos.msgSend0Double(d, "timeIntervalSince1970");
                const timestamp: i64 = @intFromFloat(interval * 1000); // Convert to milliseconds

                var buf: [128]u8 = undefined;
                const js = std.fmt.bufPrint(&buf, "if(window.__craftUpdaterLastCheck)window.__craftUpdaterLastCheck({d});", .{timestamp}) catch return;

                macos.tryEvalJS(js) catch {};
            }
        }
    }

    /// Get current update info if available
    fn getUpdateInfo(self: *Self) !void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        // Send current configuration
        var buf: [512]u8 = undefined;
        const js = std.fmt.bufPrint(&buf,
            \\if(window.__craftUpdaterInfo)window.__craftUpdaterInfo({{
            \\"automaticChecks":{},
            \\"checkInterval":{d},
            \\"feedURL":"{s}"
            \\}});
        , .{
            self.automatic_checks,
            self.check_interval,
            self.feed_url orelse "",
        }) catch return;

        macos.tryEvalJS(js) catch {};
    }

    /// Send status update to JavaScript
    fn sendStatus(self: *Self, status: []const u8, message: []const u8) void {
        _ = self;
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        var buf: [256]u8 = undefined;
        const js = std.fmt.bufPrint(&buf,
            \\if(window.__craftUpdaterStatus)window.__craftUpdaterStatus('{s}','{s}');
        , .{ status, message }) catch return;

        macos.tryEvalJS(js) catch {};
    }

    pub fn deinit(self: *Self) void {
        if (self.feed_url) |url| {
            self.allocator.free(url);
        }
    }
};

/// Global updater bridge instance
var global_updater_bridge: ?*UpdaterBridge = null;

pub fn getGlobalUpdaterBridge() ?*UpdaterBridge {
    return global_updater_bridge;
}

pub fn setGlobalUpdaterBridge(bridge: *UpdaterBridge) void {
    global_updater_bridge = bridge;
}
