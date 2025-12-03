const std = @import("std");
const builtin = @import("builtin");

/// Bridge handler for app-level control messages from JavaScript
pub const AppBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    /// Handle app-related messages from JavaScript
    pub fn handleMessage(self: *Self, action: []const u8) !void {
        self.handleMessageWithData(action, null) catch |err| {
            std.debug.print("[AppBridge] Error handling {s}: {}\n", .{ action, err });
        };
    }

    pub fn handleMessageWithData(self: *Self, action: []const u8, data: ?[]const u8) !void {
        if (std.mem.eql(u8, action, "hideDockIcon")) {
            try self.hideDockIcon();
        } else if (std.mem.eql(u8, action, "showDockIcon")) {
            try self.showDockIcon();
        } else if (std.mem.eql(u8, action, "quit")) {
            try self.quit();
        } else if (std.mem.eql(u8, action, "getInfo")) {
            try self.getInfo();
        } else if (std.mem.eql(u8, action, "notify")) {
            try self.notify(data);
        } else if (std.mem.eql(u8, action, "setBadge")) {
            try self.setBadge(data);
        } else if (std.mem.eql(u8, action, "bounce")) {
            try self.bounce();
        } else {
            std.debug.print("[AppBridge] Unknown action: {s}\n", .{action});
        }
    }

    fn hideDockIcon(self: *Self) !void {
        _ = self;
        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            const NSApplication = macos.getClass("NSApplication");
            const app = macos.msgSend0(NSApplication, "sharedApplication");

            // NSApplicationActivationPolicyAccessory = 1 (hides dock icon)
            const NSApplicationActivationPolicyAccessory: c_long = 1;
            _ = macos.msgSend1(app, "setActivationPolicy:", NSApplicationActivationPolicyAccessory);

            std.debug.print("[Bridge] Dock icon hidden\n", .{});
        }
    }

    fn showDockIcon(self: *Self) !void {
        _ = self;
        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            const NSApplication = macos.getClass("NSApplication");
            const app = macos.msgSend0(NSApplication, "sharedApplication");

            // NSApplicationActivationPolicyRegular = 0 (shows dock icon)
            const NSApplicationActivationPolicyRegular: c_long = 0;
            _ = macos.msgSend1(app, "setActivationPolicy:", NSApplicationActivationPolicyRegular);

            std.debug.print("[Bridge] Dock icon shown\n", .{});
        }
    }

    fn quit(self: *Self) !void {
        _ = self;
        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            const NSApplication = macos.getClass("NSApplication");
            const app = macos.msgSend0(NSApplication, "sharedApplication");
            macos.msgSendVoid0(app, "terminate:");
        } else {
            std.process.exit(0);
        }
    }

    fn getInfo(self: *Self) !void {
        _ = self;
        // This would return app info as JSON
        // For now, just log it
        std.debug.print("[Bridge] App info requested\n", .{});
    }

    fn notify(self: *Self, data: ?[]const u8) !void {
        _ = self;
        if (data == null) return;
        const json_data = data.?;

        // Parse title and body from JSON {"title": "...", "body": "..."}
        var title: []const u8 = "Notification";
        var body: []const u8 = "";

        if (std.mem.indexOf(u8, json_data, "\"title\":\"")) |idx| {
            const start = idx + 9;
            if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                title = json_data[start..end];
            }
        }

        if (std.mem.indexOf(u8, json_data, "\"body\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                body = json_data[start..end];
            }
        }

        std.debug.print("[AppBridge] Sending notification: {s} - {s}\n", .{ title, body });

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            macos.showNotification(title, body) catch |err| {
                std.debug.print("[AppBridge] Notification error: {}\n", .{err});
            };
        }
    }

    fn setBadge(self: *Self, data: ?[]const u8) !void {
        _ = self;
        if (data == null) return;

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Parse badge from {"badge": "..."}
            var badge: []const u8 = "";
            if (std.mem.indexOf(u8, data.?, "\"badge\":\"")) |idx| {
                const start = idx + 9;
                if (std.mem.indexOfPos(u8, data.?, start, "\"")) |end| {
                    badge = data.?[start..end];
                }
            }

            // Get dock tile and set badge
            const NSApplication = macos.getClass("NSApplication");
            const app = macos.msgSend0(NSApplication, "sharedApplication");
            const dock_tile = macos.msgSend0(app, "dockTile");

            if (badge.len > 0) {
                const badge_cstr = try std.heap.c_allocator.dupeZ(u8, badge);
                defer std.heap.c_allocator.free(badge_cstr);
                const NSString = macos.getClass("NSString");
                const str_alloc = macos.msgSend0(NSString, "alloc");
                const ns_badge = macos.msgSend1(str_alloc, "initWithUTF8String:", badge_cstr.ptr);
                _ = macos.msgSend1(dock_tile, "setBadgeLabel:", ns_badge);
            } else {
                _ = macos.msgSend1(dock_tile, "setBadgeLabel:", @as(?*anyopaque, null));
            }
        }
    }

    fn bounce(self: *Self) !void {
        _ = self;
        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            const NSApplication = macos.getClass("NSApplication");
            const app = macos.msgSend0(NSApplication, "sharedApplication");

            // NSApplicationActivateIgnoringOtherApps + request user attention
            // NSInformationalRequest = 10
            const NSInformationalRequest: c_long = 10;
            _ = macos.msgSend1(app, "requestUserAttention:", NSInformationalRequest);
        }
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};
