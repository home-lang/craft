const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Bridge handler for native macOS notifications
/// Uses UNUserNotificationCenter for modern notification support
pub const NotificationBridge = struct {
    allocator: std.mem.Allocator,
    notification_center: ?*anyopaque = null,
    delegate: ?*anyopaque = null,
    pending_callbacks: std.StringHashMap([]const u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        var self = Self{
            .allocator = allocator,
            .pending_callbacks = std.StringHashMap([]const u8).init(allocator),
        };

        if (builtin.os.tag == .macos) {
            self.setupNotificationCenter();
        }

        return self;
    }

    fn setupNotificationCenter(self: *Self) void {
        const macos = @import("macos.zig");

        // Get UNUserNotificationCenter
        const UNUserNotificationCenter = macos.getClass("UNUserNotificationCenter");
        if (UNUserNotificationCenter == null) {
            std.debug.print("[NotificationBridge] UNUserNotificationCenter not available\n", .{});
            return;
        }

        self.notification_center = macos.msgSend0(UNUserNotificationCenter, "currentNotificationCenter");

        // Request authorization
        if (self.notification_center) |center| {
            // UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge
            const options: c_ulong = (1 << 0) | (1 << 1) | (1 << 2);

            // Create completion handler block (simplified - just log result)
            const msg = @as(*const fn (@TypeOf(center), @import("macos.zig").objc.SEL, c_ulong, ?*anyopaque) callconv(.c) void, @ptrCast(&@import("macos.zig").objc.objc_msgSend));
            msg(center, macos.sel("requestAuthorizationWithOptions:completionHandler:"), options, null);

            std.debug.print("[NotificationBridge] Notification center initialized\n", .{});
        }
    }

    /// Handle notification-related messages from JavaScript
    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        self.handleMessageInternal(action, data) catch |err| {
            self.reportError(action, err);
        };
    }

    fn handleMessageInternal(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "show")) {
            try self.showNotification(data);
        } else if (std.mem.eql(u8, action, "schedule")) {
            try self.scheduleNotification(data);
        } else if (std.mem.eql(u8, action, "cancel")) {
            try self.cancelNotification(data);
        } else if (std.mem.eql(u8, action, "cancelAll")) {
            try self.cancelAllNotifications();
        } else if (std.mem.eql(u8, action, "setBadge")) {
            try self.setBadgeCount(data);
        } else if (std.mem.eql(u8, action, "clearBadge")) {
            try self.clearBadge();
        } else if (std.mem.eql(u8, action, "requestPermission")) {
            try self.requestPermission();
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

    /// Show an immediate notification
    /// JSON: {"id": "notif1", "title": "Hello", "body": "World", "sound": true, "actionId": "open"}
    fn showNotification(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) return;

        const center = self.notification_center orelse return BridgeError.NativeCallFailed;
        const macos = @import("macos.zig");

        // Parse notification data
        var id: []const u8 = "default";
        var title: []const u8 = "";
        var body: []const u8 = "";
        var subtitle: []const u8 = "";
        var sound: bool = true;

        // Parse id
        if (std.mem.indexOf(u8, data, "\"id\":\"")) |idx| {
            const start = idx + 6;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                id = data[start..end];
            }
        }

        // Parse title
        if (std.mem.indexOf(u8, data, "\"title\":\"")) |idx| {
            const start = idx + 9;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                title = data[start..end];
            }
        }

        // Parse body
        if (std.mem.indexOf(u8, data, "\"body\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                body = data[start..end];
            }
        }

        // Parse subtitle
        if (std.mem.indexOf(u8, data, "\"subtitle\":\"")) |idx| {
            const start = idx + 12;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                subtitle = data[start..end];
            }
        }

        // Parse sound
        if (std.mem.indexOf(u8, data, "\"sound\":false")) |_| {
            sound = false;
        }

        std.debug.print("[NotificationBridge] show: id={s}, title={s}, body={s}\n", .{ id, title, body });

        // Create UNMutableNotificationContent
        const UNMutableNotificationContent = macos.getClass("UNMutableNotificationContent");
        const content = macos.msgSend0(macos.msgSend0(UNMutableNotificationContent, "alloc"), "init");

        // Set title
        if (title.len > 0) {
            const title_cstr = try self.allocator.dupeZ(u8, title);
            defer self.allocator.free(title_cstr);
            const NSString = macos.getClass("NSString");
            const str_alloc = macos.msgSend0(NSString, "alloc");
            const ns_title = macos.msgSend1(str_alloc, "initWithUTF8String:", title_cstr.ptr);
            _ = macos.msgSend1(content, "setTitle:", ns_title);
        }

        // Set body
        if (body.len > 0) {
            const body_cstr = try self.allocator.dupeZ(u8, body);
            defer self.allocator.free(body_cstr);
            const NSString = macos.getClass("NSString");
            const str_alloc = macos.msgSend0(NSString, "alloc");
            const ns_body = macos.msgSend1(str_alloc, "initWithUTF8String:", body_cstr.ptr);
            _ = macos.msgSend1(content, "setBody:", ns_body);
        }

        // Set subtitle
        if (subtitle.len > 0) {
            const subtitle_cstr = try self.allocator.dupeZ(u8, subtitle);
            defer self.allocator.free(subtitle_cstr);
            const NSString = macos.getClass("NSString");
            const str_alloc = macos.msgSend0(NSString, "alloc");
            const ns_subtitle = macos.msgSend1(str_alloc, "initWithUTF8String:", subtitle_cstr.ptr);
            _ = macos.msgSend1(content, "setSubtitle:", ns_subtitle);
        }

        // Set sound
        if (sound) {
            const UNNotificationSound = macos.getClass("UNNotificationSound");
            const default_sound = macos.msgSend0(UNNotificationSound, "defaultSound");
            _ = macos.msgSend1(content, "setSound:", default_sound);
        }

        // Create trigger (nil for immediate)
        const trigger: ?*anyopaque = null;

        // Create request
        const id_cstr = try self.allocator.dupeZ(u8, id);
        defer self.allocator.free(id_cstr);
        const NSString = macos.getClass("NSString");
        const str_alloc = macos.msgSend0(NSString, "alloc");
        const ns_id = macos.msgSend1(str_alloc, "initWithUTF8String:", id_cstr.ptr);

        const UNNotificationRequest = macos.getClass("UNNotificationRequest");
        const request = macos.msgSend3(UNNotificationRequest, "requestWithIdentifier:content:trigger:", ns_id, content, trigger);

        // Add to notification center
        _ = macos.msgSend2(center, "addNotificationRequest:withCompletionHandler:", request, @as(?*anyopaque, null));

        std.debug.print("[NotificationBridge] Notification scheduled: {s}\n", .{id});
    }

    /// Schedule a notification for later
    /// JSON: {"id": "reminder", "title": "Reminder", "body": "Time to take a break", "delay": 60}
    fn scheduleNotification(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) return;

        const center = self.notification_center orelse return BridgeError.NativeCallFailed;
        const macos = @import("macos.zig");

        // Parse data
        var id: []const u8 = "scheduled";
        var title: []const u8 = "";
        var body: []const u8 = "";
        var delay: f64 = 60.0;

        if (std.mem.indexOf(u8, data, "\"id\":\"")) |idx| {
            const start = idx + 6;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                id = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"title\":\"")) |idx| {
            const start = idx + 9;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                title = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"body\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                body = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"delay\":")) |idx| {
            var start = idx + 8;
            while (start < data.len and (data[start] == ' ' or data[start] == '\t')) : (start += 1) {}
            var end = start;
            while (end < data.len and ((data[end] >= '0' and data[end] <= '9') or data[end] == '.')) : (end += 1) {}
            if (end > start) {
                delay = std.fmt.parseFloat(f64, data[start..end]) catch 60.0;
            }
        }

        std.debug.print("[NotificationBridge] schedule: id={s}, delay={d}s\n", .{ id, delay });

        // Create content
        const UNMutableNotificationContent = macos.getClass("UNMutableNotificationContent");
        const content = macos.msgSend0(macos.msgSend0(UNMutableNotificationContent, "alloc"), "init");

        if (title.len > 0) {
            const title_cstr = try self.allocator.dupeZ(u8, title);
            defer self.allocator.free(title_cstr);
            const NSString = macos.getClass("NSString");
            const ns_title = macos.msgSend1(macos.msgSend0(NSString, "alloc"), "initWithUTF8String:", title_cstr.ptr);
            _ = macos.msgSend1(content, "setTitle:", ns_title);
        }

        if (body.len > 0) {
            const body_cstr = try self.allocator.dupeZ(u8, body);
            defer self.allocator.free(body_cstr);
            const NSString = macos.getClass("NSString");
            const ns_body = macos.msgSend1(macos.msgSend0(NSString, "alloc"), "initWithUTF8String:", body_cstr.ptr);
            _ = macos.msgSend1(content, "setBody:", ns_body);
        }

        // Add default sound
        const UNNotificationSound = macos.getClass("UNNotificationSound");
        const default_sound = macos.msgSend0(UNNotificationSound, "defaultSound");
        _ = macos.msgSend1(content, "setSound:", default_sound);

        // Create time interval trigger
        const UNTimeIntervalNotificationTrigger = macos.getClass("UNTimeIntervalNotificationTrigger");
        const msg_trigger = @as(*const fn (@TypeOf(UNTimeIntervalNotificationTrigger), @import("macos.zig").objc.SEL, f64, bool) callconv(.c) *anyopaque, @ptrCast(&@import("macos.zig").objc.objc_msgSend));
        const trigger = msg_trigger(UNTimeIntervalNotificationTrigger, macos.sel("triggerWithTimeInterval:repeats:"), delay, false);

        // Create request
        const id_cstr = try self.allocator.dupeZ(u8, id);
        defer self.allocator.free(id_cstr);
        const NSString = macos.getClass("NSString");
        const ns_id = macos.msgSend1(macos.msgSend0(NSString, "alloc"), "initWithUTF8String:", id_cstr.ptr);

        const UNNotificationRequest = macos.getClass("UNNotificationRequest");
        const request = macos.msgSend3(UNNotificationRequest, "requestWithIdentifier:content:trigger:", ns_id, content, trigger);

        // Add to center
        _ = macos.msgSend2(center, "addNotificationRequest:withCompletionHandler:", request, @as(?*anyopaque, null));
    }

    /// Cancel a pending notification
    /// JSON: {"id": "reminder"}
    fn cancelNotification(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) return;

        const center = self.notification_center orelse return BridgeError.NativeCallFailed;
        const macos = @import("macos.zig");

        var id: []const u8 = "";
        if (std.mem.indexOf(u8, data, "\"id\":\"")) |idx| {
            const start = idx + 6;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                id = data[start..end];
            }
        }

        if (id.len == 0) return BridgeError.MissingData;

        std.debug.print("[NotificationBridge] cancel: {s}\n", .{id});

        const id_cstr = try self.allocator.dupeZ(u8, id);
        defer self.allocator.free(id_cstr);

        const NSString = macos.getClass("NSString");
        const ns_id = macos.msgSend1(macos.msgSend0(NSString, "alloc"), "initWithUTF8String:", id_cstr.ptr);

        const NSArray = macos.getClass("NSArray");
        const ids_array = macos.msgSend1(NSArray, "arrayWithObject:", ns_id);

        _ = macos.msgSend1(center, "removePendingNotificationRequestsWithIdentifiers:", ids_array);
        _ = macos.msgSend1(center, "removeDeliveredNotificationsWithIdentifiers:", ids_array);
    }

    /// Cancel all pending notifications
    fn cancelAllNotifications(self: *Self) !void {
        if (builtin.os.tag != .macos) return;

        const center = self.notification_center orelse return BridgeError.NativeCallFailed;
        const macos = @import("macos.zig");

        std.debug.print("[NotificationBridge] cancelAll\n", .{});

        _ = macos.msgSend0(center, "removeAllPendingNotificationRequests");
        _ = macos.msgSend0(center, "removeAllDeliveredNotifications");
    }

    /// Set app badge count
    /// JSON: {"count": 5}
    fn setBadgeCount(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) return;
        _ = self;

        const macos = @import("macos.zig");

        var count: i64 = 0;
        if (std.mem.indexOf(u8, data, "\"count\":")) |idx| {
            var start = idx + 8;
            while (start < data.len and (data[start] == ' ' or data[start] == '\t')) : (start += 1) {}
            var end = start;
            while (end < data.len and data[end] >= '0' and data[end] <= '9') : (end += 1) {}
            if (end > start) {
                count = std.fmt.parseInt(i64, data[start..end], 10) catch 0;
            }
        }

        std.debug.print("[NotificationBridge] setBadge: {}\n", .{count});

        // Set dock badge
        const NSApplication = macos.getClass("NSApplication");
        const app = macos.msgSend0(NSApplication, "sharedApplication");
        const dock_tile = macos.msgSend0(app, "dockTile");

        if (count > 0) {
            var buf: [32]u8 = undefined;
            const count_str = std.fmt.bufPrint(&buf, "{}", .{count}) catch "0";
            const count_cstr = @as([*:0]const u8, @ptrCast(count_str.ptr));

            const NSString = macos.getClass("NSString");
            const ns_count = macos.msgSend1(macos.msgSend0(NSString, "alloc"), "initWithUTF8String:", count_cstr);
            _ = macos.msgSend1(dock_tile, "setBadgeLabel:", ns_count);
        } else {
            _ = macos.msgSend1(dock_tile, "setBadgeLabel:", @as(?*anyopaque, null));
        }
    }

    /// Clear app badge
    fn clearBadge(self: *Self) !void {
        if (builtin.os.tag != .macos) return;
        _ = self;

        const macos = @import("macos.zig");

        std.debug.print("[NotificationBridge] clearBadge\n", .{});

        const NSApplication = macos.getClass("NSApplication");
        const app = macos.msgSend0(NSApplication, "sharedApplication");
        const dock_tile = macos.msgSend0(app, "dockTile");
        _ = macos.msgSend1(dock_tile, "setBadgeLabel:", @as(?*anyopaque, null));
    }

    /// Request notification permission
    fn requestPermission(self: *Self) !void {
        if (builtin.os.tag != .macos) return;

        const center = self.notification_center orelse return BridgeError.NativeCallFailed;
        const macos = @import("macos.zig");

        std.debug.print("[NotificationBridge] requestPermission\n", .{});

        // UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge
        const options: c_ulong = (1 << 0) | (1 << 1) | (1 << 2);

        const msg = @as(*const fn (@TypeOf(center), @import("macos.zig").objc.SEL, c_ulong, ?*anyopaque) callconv(.c) void, @ptrCast(&@import("macos.zig").objc.objc_msgSend));
        msg(center, macos.sel("requestAuthorizationWithOptions:completionHandler:"), options, null);
    }

    pub fn deinit(self: *Self) void {
        var it = self.pending_callbacks.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.pending_callbacks.deinit();
    }
};
