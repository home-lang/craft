const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");
const logging = @import("logging.zig");

const BridgeError = bridge_error.BridgeError;
const log = logging.notification;

/// Bridge handler for native macOS notifications
/// Uses UNUserNotificationCenter for modern notification support
pub const NotificationBridge = struct {
    allocator: std.mem.Allocator,
    notification_center: ?*anyopaque = null,
    delegate: ?*anyopaque = null,
    pending_callbacks: std.StringHashMap([]const u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        const self = Self{
            .allocator = allocator,
            .pending_callbacks = std.StringHashMap([]const u8).init(allocator),
        };

        // Note: Notification center setup is deferred until first use
        // UNUserNotificationCenter requires proper app initialization

        return self;
    }

    fn ensureNotificationCenter(self: *Self) void {
        // Already initialized
        if (self.notification_center != null) return;

        if (comptime builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        // Get UNUserNotificationCenter - may fail if app not properly initialized
        const UNUserNotificationCenter = macos.getClass("UNUserNotificationCenter");
        if (UNUserNotificationCenter == null) {
            log.warn("UNUserNotificationCenter class not available", .{});
            return;
        }

        // Try to get the notification center - this can crash if called too early
        // so we defer this until actually needed
        self.notification_center = macos.msgSend0(UNUserNotificationCenter, "currentNotificationCenter");

        if (self.notification_center) |center| {
            // UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge
            const options: c_ulong = (1 << 0) | (1 << 1) | (1 << 2);

            // Request authorization
            const msg = @as(*const fn (@TypeOf(center), @import("macos.zig").objc.SEL, c_ulong, ?*anyopaque) callconv(.c) void, @ptrCast(&@import("macos.zig").objc.objc_msgSend));
            msg(center, macos.sel("requestAuthorizationWithOptions:completionHandler:"), options, null);

            log.debug("Notification center initialized", .{});
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
        if (builtin.os.tag == .linux) {
            try self.linuxShowNotification(data);
            return;
        } else if (builtin.os.tag == .windows) {
            try self.windowsShowNotification(data);
            return;
        }
        if (comptime builtin.os.tag != .macos) return;

        self.ensureNotificationCenter();
        const center = self.notification_center orelse return BridgeError.NativeCallFailed;
        const macos = @import("macos.zig");

        const ShowParams = struct {
            id: []const u8 = "default",
            title: []const u8 = "",
            body: []const u8 = "",
            subtitle: []const u8 = "",
            sound: bool = true,
        };

        const parsed = std.json.parseFromSlice(ShowParams, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        const params = parsed.value;

        const id = params.id;
        const title = params.title;
        const body = params.body;
        const subtitle = params.subtitle;
        const sound = params.sound;

        log.debug("show: id={s}, title={s}, body={s}", .{ id, title, body });

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

        log.debug("Notification scheduled: {s}", .{id});
    }

    /// Schedule a notification for later
    /// JSON: {"id": "reminder", "title": "Reminder", "body": "Time to take a break", "delay": 60}
    fn scheduleNotification(self: *Self, data: []const u8) !void {
        if (builtin.os.tag == .linux) {
            // Linux: notify-send doesn't support scheduling, show immediately with a note
            try self.linuxShowNotification(data);
            return;
        } else if (builtin.os.tag == .windows) {
            // Windows: Show immediately for simplicity
            try self.windowsShowNotification(data);
            return;
        }
        if (comptime builtin.os.tag != .macos) return;

        self.ensureNotificationCenter();
        const center = self.notification_center orelse return BridgeError.NativeCallFailed;
        const macos = @import("macos.zig");

        const ScheduleParams = struct {
            id: []const u8 = "scheduled",
            title: []const u8 = "",
            body: []const u8 = "",
            delay: f64 = 60.0,
        };

        const parsed = std.json.parseFromSlice(ScheduleParams, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        const params = parsed.value;

        const id = params.id;
        const title = params.title;
        const body = params.body;
        const delay = params.delay;

        log.debug("schedule: id={s}, delay={d}s", .{ id, delay });

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
        if (builtin.os.tag == .linux or builtin.os.tag == .windows) {
            // Linux/Windows: notify-send doesn't support cancellation
            _ = &data;
            log.debug("cancel: not supported on this platform", .{});
            return;
        }
        if (comptime builtin.os.tag != .macos) return;

        self.ensureNotificationCenter();
        const center = self.notification_center orelse return BridgeError.NativeCallFailed;
        const macos = @import("macos.zig");

        const IdParams = struct {
            id: []const u8 = "",
        };

        const parsed = std.json.parseFromSlice(IdParams, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        const id = parsed.value.id;

        if (id.len == 0) return BridgeError.MissingData;

        log.debug("cancel: {s}", .{id});

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
        if (builtin.os.tag == .linux or builtin.os.tag == .windows) {
            log.debug("cancelAll: not supported on this platform", .{});
            return;
        }
        if (comptime builtin.os.tag != .macos) return;

        self.ensureNotificationCenter();
        const center = self.notification_center orelse return BridgeError.NativeCallFailed;
        const macos = @import("macos.zig");

        log.debug("cancelAll", .{});

        _ = macos.msgSend0(center, "removeAllPendingNotificationRequests");
        _ = macos.msgSend0(center, "removeAllDeliveredNotifications");
    }

    /// Set app badge count
    /// JSON: {"count": 5}
    fn setBadgeCount(self: *Self, data: []const u8) !void {
        if (builtin.os.tag == .linux or builtin.os.tag == .windows) {
            _ = &data;
            log.debug("setBadge: not supported on this platform", .{});
            return;
        }
        if (comptime builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        const BadgeParams = struct {
            count: i64 = 0,
        };

        const parsed = std.json.parseFromSlice(BadgeParams, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        const count = parsed.value.count;

        log.debug("setBadge: {}", .{count});

        // Set dock badge
        const NSApplication = macos.getClass("NSApplication");
        const app = macos.msgSend0(NSApplication, "sharedApplication");
        const dock_tile = macos.msgSend0(app, "dockTile");

        if (count > 0) {
            // Use bufPrintZ to produce a guaranteed null-terminated slice.
            // The previous version cast a non-null-terminated bufPrint slice
            // to `[*:0]const u8`, which is undefined behavior — the ObjC
            // `initWithUTF8String:` implementation reads until it finds a
            // zero byte, potentially overrunning into adjacent stack.
            var buf: [32]u8 = undefined;
            const count_str = std.fmt.bufPrintZ(&buf, "{}", .{count}) catch "0";

            const NSString = macos.getClass("NSString");
            const ns_count = macos.msgSend1(macos.msgSend0(NSString, "alloc"), "initWithUTF8String:", count_str.ptr);
            _ = macos.msgSend1(dock_tile, "setBadgeLabel:", ns_count);
        } else {
            _ = macos.msgSend1(dock_tile, "setBadgeLabel:", @as(?*anyopaque, null));
        }
    }

    /// Clear app badge
    fn clearBadge(self: *Self) !void {
        if (builtin.os.tag == .linux or builtin.os.tag == .windows) {
            log.debug("clearBadge: not supported on this platform", .{});
            return;
        }
        if (comptime builtin.os.tag != .macos) return;
        _ = self;

        const macos = @import("macos.zig");

        log.debug("clearBadge", .{});

        const NSApplication = macos.getClass("NSApplication");
        const app = macos.msgSend0(NSApplication, "sharedApplication");
        const dock_tile = macos.msgSend0(app, "dockTile");
        _ = macos.msgSend1(dock_tile, "setBadgeLabel:", @as(?*anyopaque, null));
    }

    /// Request notification permission
    fn requestPermission(self: *Self) !void {
        if (builtin.os.tag == .linux or builtin.os.tag == .windows) {
            // Linux/Windows: permissions are typically not required
            log.debug("requestPermission: granted by default on this platform", .{});
            bridge_error.sendResultToJS(self.allocator, "requestPermission", "{\"granted\":true}");
            return;
        }
        if (comptime builtin.os.tag != .macos) return;

        self.ensureNotificationCenter();
        const center = self.notification_center orelse return BridgeError.NativeCallFailed;
        const macos = @import("macos.zig");

        log.debug("requestPermission", .{});

        // UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge
        const options: c_ulong = (1 << 0) | (1 << 1) | (1 << 2);

        const msg = @as(*const fn (@TypeOf(center), @import("macos.zig").objc.SEL, c_ulong, ?*anyopaque) callconv(.c) void, @ptrCast(&@import("macos.zig").objc.objc_msgSend));
        msg(center, macos.sel("requestAuthorizationWithOptions:completionHandler:"), options, null);
    }

    // ============================================
    // Linux Notification Implementation (notify-send)
    // ============================================

    fn linuxShowNotification(self: *Self, data: []const u8) !void {
        const LinuxNotifParams = struct {
            title: []const u8 = "Notification",
            body: []const u8 = "",
            style: []const u8 = "normal",
        };

        const parsed = std.json.parseFromSlice(LinuxNotifParams, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        const params = parsed.value;

        const title = params.title;
        const body = params.body;
        const urgency = if (std.mem.eql(u8, params.style, "critical"))
            "critical"
        else if (std.mem.eql(u8, params.style, "low"))
            "low"
        else
            "normal";

        log.debug("Linux show: title={s}, body={s}", .{ title, body });

        // Build args for notify-send
        var args = std.ArrayList([]const u8).init(self.allocator);
        defer args.deinit();

        try args.append("notify-send");
        try args.append("--urgency");
        try args.append(urgency);
        try args.append(title);
        if (body.len > 0) {
            try args.append(body);
        }

        var child = std.process.Child.init(args.items, self.allocator);
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;

        try child.spawn();
        _ = try child.wait();

        log.debug("Linux: notification sent", .{});
    }

    // ============================================
    // Windows Notification Implementation (PowerShell Toast)
    // ============================================

    fn windowsShowNotification(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .windows) {
            _ = &self;
            _ = &data;
            return;
        }

        const WinNotifParams = struct {
            title: []const u8 = "Notification",
            body: []const u8 = "",
        };

        const parsed = std.json.parseFromSlice(WinNotifParams, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        const title = parsed.value.title;
        const body = parsed.value.body;

        log.debug("Windows show: title={s}, body={s}", .{ title, body });

        // Use PowerShell to show toast notification
        // This is a simple approach that works without additional dependencies
        const ps_script = try std.fmt.allocPrint(self.allocator,
            \\[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
            \\$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
            \\$textNodes = $template.GetElementsByTagName("text")
            \\$textNodes.Item(0).AppendChild($template.CreateTextNode("{s}")) > $null
            \\$textNodes.Item(1).AppendChild($template.CreateTextNode("{s}")) > $null
            \\$toast = [Windows.UI.Notifications.ToastNotification]::new($template)
            \\[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Craft App").Show($toast)
        , .{ title, body });
        defer self.allocator.free(ps_script);

        var child = std.process.Child.init(&.{ "powershell", "-Command", ps_script }, self.allocator);
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;

        try child.spawn();
        _ = try child.wait();

        log.debug("Windows: notification sent", .{});
    }

    pub fn deinit(self: *Self) void {
        var it = self.pending_callbacks.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.pending_callbacks.deinit();
    }
};
