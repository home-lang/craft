//! Notifications Module
//!
//! Provides local and push notification functionality:
//! - Schedule local notifications
//! - Handle push notifications
//! - Notification actions and categories
//! - Badge management
//! - Sound and vibration control
//!
//! Example usage:
//! ```zig
//! var notif = NotificationManager.init(allocator);
//! defer notif.deinit();
//!
//! try notif.requestPermission(.{});
//!
//! const notification = NotificationPresets.reminder("Meeting", "Team sync in 10 minutes", 600);
//! try notif.schedule(notification);
//! ```

const std = @import("std");
const builtin = @import("builtin");

/// Notification priority levels
pub const Priority = enum {
    min,
    low,
    default,
    high,
    max,

    pub fn toString(self: Priority) []const u8 {
        return switch (self) {
            .min => "min",
            .low => "low",
            .default => "default",
            .high => "high",
            .max => "max",
        };
    }

    /// Get Android importance level
    pub fn toAndroidImportance(self: Priority) i32 {
        return switch (self) {
            .min => 1,
            .low => 2,
            .default => 3,
            .high => 4,
            .max => 5,
        };
    }
};

/// Notification category for grouping
pub const Category = enum {
    general,
    social,
    message,
    email,
    event,
    reminder,
    alarm,
    promo,
    progress,
    transport,
    system,
    service,
    error_cat,
    status,

    pub fn toString(self: Category) []const u8 {
        return switch (self) {
            .general => "general",
            .social => "social",
            .message => "message",
            .email => "email",
            .event => "event",
            .reminder => "reminder",
            .alarm => "alarm",
            .promo => "promo",
            .progress => "progress",
            .transport => "transport",
            .system => "system",
            .service => "service",
            .error_cat => "error",
            .status => "status",
        };
    }
};

/// Sound options for notifications
pub const Sound = union(enum) {
    default: void,
    none: void,
    custom: []const u8,
    critical: f32, // volume 0.0 - 1.0

    pub fn isEnabled(self: Sound) bool {
        return switch (self) {
            .none => false,
            else => true,
        };
    }
};

/// Notification trigger types
pub const Trigger = union(enum) {
    /// Trigger immediately
    immediate: void,

    /// Trigger after time interval (seconds)
    time_interval: u64,

    /// Trigger at specific timestamp (Unix timestamp)
    timestamp: i64,

    /// Trigger at calendar date/time
    calendar: CalendarTrigger,

    /// Trigger based on location (geofence)
    location: LocationTrigger,

    pub const CalendarTrigger = struct {
        year: ?u16 = null,
        month: ?u8 = null, // 1-12
        day: ?u8 = null, // 1-31
        hour: ?u8 = null, // 0-23
        minute: ?u8 = null, // 0-59
        second: ?u8 = null, // 0-59
        weekday: ?u8 = null, // 1-7 (Sunday = 1)
        repeats: bool = false,
    };

    pub const LocationTrigger = struct {
        latitude: f64,
        longitude: f64,
        radius: f64, // meters
        on_entry: bool = true,
        on_exit: bool = false,
        repeats: bool = false,
    };
};

/// Notification action button
pub const Action = struct {
    id: []const u8,
    title: []const u8,
    icon: ?[]const u8 = null,
    destructive: bool = false,
    authentication_required: bool = false,
    foreground: bool = false,
    text_input: ?TextInputConfig = null,

    pub const TextInputConfig = struct {
        button_title: []const u8 = "Send",
        placeholder: []const u8 = "",
    };
};

/// Notification attachment (image, video, audio)
pub const Attachment = struct {
    id: []const u8,
    url: []const u8,
    mime_type: ?[]const u8 = null,
    thumbnail_hidden: bool = false,
};

/// Progress indicator for notifications
pub const Progress = struct {
    current: u32,
    max: u32,
    indeterminate: bool = false,

    pub fn percentage(self: Progress) f32 {
        if (self.max == 0) return 0;
        return @as(f32, @floatFromInt(self.current)) / @as(f32, @floatFromInt(self.max)) * 100.0;
    }
};

/// Main notification structure
pub const Notification = struct {
    /// Unique identifier
    id: []const u8 = "default",

    /// Title text
    title: []const u8,

    /// Subtitle (iOS) / Subtext (Android)
    subtitle: ?[]const u8 = null,

    /// Body text
    body: ?[]const u8 = null,

    /// Badge number (0 to clear)
    badge: ?u32 = null,

    /// Sound configuration
    sound: Sound = .default,

    /// When to trigger
    trigger: Trigger = .immediate,

    /// Priority level
    priority: Priority = .default,

    /// Category for grouping
    category: Category = .general,

    /// Thread/group identifier
    thread_id: ?[]const u8 = null,

    /// Action buttons
    actions: ?[]const Action = null,

    /// Attachments
    attachments: ?[]const Attachment = null,

    /// Progress indicator
    progress: ?Progress = null,

    /// Custom data payload (as JSON string)
    user_info: ?[]const u8 = null,

    /// Silent notification (no alert)
    silent: bool = false,

    /// Foreground presentation options (iOS)
    foreground_presentation: ForegroundPresentation = .{},

    /// Android-specific options
    android: AndroidOptions = .{},

    /// iOS-specific options
    ios: IOSOptions = .{},

    pub const ForegroundPresentation = struct {
        show_alert: bool = true,
        play_sound: bool = true,
        update_badge: bool = true,
        show_banner: bool = true,
        show_list: bool = true,
    };

    pub const AndroidOptions = struct {
        channel_id: ?[]const u8 = null,
        small_icon: ?[]const u8 = null,
        large_icon: ?[]const u8 = null,
        color: ?u32 = null, // ARGB
        ongoing: bool = false,
        auto_cancel: bool = true,
        only_alert_once: bool = false,
        show_when: bool = true,
        group_key: ?[]const u8 = null,
        group_summary: bool = false,
        ticker: ?[]const u8 = null,
        visibility: Visibility = .private,

        pub const Visibility = enum {
            public,
            private,
            secret,
        };
    };

    pub const IOSOptions = struct {
        interruption_level: InterruptionLevel = .active,
        relevance_score: f64 = 0.0, // 0.0 - 1.0
        target_content_id: ?[]const u8 = null,

        pub const InterruptionLevel = enum {
            passive,
            active,
            time_sensitive,
            critical,
        };
    };
};

/// Notification channel (Android)
pub const Channel = struct {
    id: []const u8,
    name: []const u8,
    description: ?[]const u8 = null,
    importance: Priority = .default,
    sound: Sound = .default,
    vibration: bool = true,
    lights: bool = true,
    light_color: ?u32 = null, // ARGB
    show_badge: bool = true,
    bypass_dnd: bool = false,

    pub fn init(id: []const u8, name: []const u8) Channel {
        return .{
            .id = id,
            .name = name,
        };
    }
};

/// Permission status
pub const PermissionStatus = enum {
    not_determined,
    denied,
    authorized,
    provisional,
    ephemeral,

    pub fn isGranted(self: PermissionStatus) bool {
        return self == .authorized or self == .provisional or self == .ephemeral;
    }

    pub fn toString(self: PermissionStatus) []const u8 {
        return switch (self) {
            .not_determined => "not_determined",
            .denied => "denied",
            .authorized => "authorized",
            .provisional => "provisional",
            .ephemeral => "ephemeral",
        };
    }
};

/// Notification settings
pub const NotificationSettings = struct {
    authorization_status: PermissionStatus = .not_determined,
    sound_enabled: bool = true,
    badge_enabled: bool = true,
    alert_enabled: bool = true,
    lock_screen_enabled: bool = true,
    notification_center_enabled: bool = true,
    critical_alert_enabled: bool = false,
    announcement_enabled: bool = false,
};

/// Notification response (when user interacts)
pub const NotificationResponse = struct {
    notification_id: []const u8,
    action_id: ?[]const u8 = null,
    text_input: ?[]const u8 = null,
    user_info: ?[]const u8 = null,
    foreground: bool = true,
};

/// Notification errors
pub const NotificationError = error{
    PermissionDenied,
    InvalidTrigger,
    InvalidNotification,
    SchedulingFailed,
    ChannelNotFound,
    NotSupported,
    SystemError,
    OutOfMemory,
};

/// Notification manager
pub const NotificationManager = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    channels: std.StringHashMapUnmanaged(Channel),
    scheduled: std.StringHashMapUnmanaged(Notification),
    settings: NotificationSettings,
    delegate: ?*const NotificationDelegate = null,
    badge_count: u32 = 0,

    /// Callback delegate for notification events
    pub const NotificationDelegate = struct {
        context: *anyopaque,
        on_received: ?*const fn (*anyopaque, Notification) void = null,
        on_response: ?*const fn (*anyopaque, NotificationResponse) void = null,
        on_error: ?*const fn (*anyopaque, NotificationError) void = null,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .channels = .empty,
            .scheduled = .empty,
            .settings = .{},
            .delegate = null,
            .badge_count = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.channels.deinit(self.allocator);
        self.scheduled.deinit(self.allocator);
    }

    /// Set notification delegate
    pub fn setDelegate(self: *Self, delegate: *const NotificationDelegate) void {
        self.delegate = delegate;
    }

    /// Request notification permission
    pub fn requestPermission(self: *Self, options: RequestOptions) NotificationError!PermissionStatus {
        _ = options;

        // Platform-specific permission request
        if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
            return self.requestPermissionDarwin();
        } else if (comptime builtin.os.tag == .linux) {
            // Linux typically doesn't require permission
            self.settings.authorization_status = .authorized;
            return .authorized;
        } else if (comptime builtin.os.tag == .windows) {
            return self.requestPermissionWindows();
        }

        return .authorized;
    }

    pub const RequestOptions = struct {
        alert: bool = true,
        sound: bool = true,
        badge: bool = true,
        critical_alert: bool = false,
        provisional: bool = false,
        announcement: bool = false,
    };

    fn requestPermissionDarwin(self: *Self) PermissionStatus {
        // In real implementation, use UNUserNotificationCenter
        self.settings.authorization_status = .authorized;
        return .authorized;
    }

    fn requestPermissionWindows(self: *Self) PermissionStatus {
        // In real implementation, use Windows notification API
        self.settings.authorization_status = .authorized;
        return .authorized;
    }

    /// Get current permission status
    pub fn getPermissionStatus(self: *Self) PermissionStatus {
        return self.settings.authorization_status;
    }

    /// Get notification settings
    pub fn getSettings(self: *Self) NotificationSettings {
        return self.settings;
    }

    /// Create notification channel (Android)
    pub fn createChannel(self: *Self, channel: Channel) NotificationError!void {
        self.channels.put(self.allocator, channel.id, channel) catch return NotificationError.OutOfMemory;
    }

    /// Delete notification channel
    pub fn deleteChannel(self: *Self, channel_id: []const u8) void {
        _ = self.channels.remove(channel_id);
    }

    /// Get channel by ID
    pub fn getChannel(self: *Self, channel_id: []const u8) ?Channel {
        return self.channels.get(channel_id);
    }

    /// Get all channels
    pub fn getAllChannels(self: *Self, allocator: std.mem.Allocator) ![]Channel {
        var list: std.ArrayListUnmanaged(Channel) = .empty;
        errdefer list.deinit(allocator);

        var iter = self.channels.iterator();
        while (iter.next()) |entry| {
            try list.append(allocator, entry.value_ptr.*);
        }

        return list.toOwnedSlice(allocator);
    }

    /// Schedule a notification
    pub fn schedule(self: *Self, notification: Notification) NotificationError!void {
        if (!self.settings.authorization_status.isGranted()) {
            return NotificationError.PermissionDenied;
        }

        // Validate trigger
        switch (notification.trigger) {
            .time_interval => |interval| {
                if (interval == 0) return NotificationError.InvalidTrigger;
            },
            .calendar => |cal| {
                if (cal.hour) |h| if (h > 23) return NotificationError.InvalidTrigger;
                if (cal.minute) |m| if (m > 59) return NotificationError.InvalidTrigger;
                if (cal.month) |mo| if (mo < 1 or mo > 12) return NotificationError.InvalidTrigger;
                if (cal.day) |d| if (d < 1 or d > 31) return NotificationError.InvalidTrigger;
            },
            else => {},
        }

        // Platform-specific scheduling
        if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
            try self.scheduleDarwin(notification);
        } else if (comptime builtin.os.tag == .linux) {
            try self.scheduleLinux(notification);
        } else if (comptime builtin.os.tag == .windows) {
            try self.scheduleWindows(notification);
        }

        self.scheduled.put(self.allocator, notification.id, notification) catch return NotificationError.OutOfMemory;
    }

    fn scheduleDarwin(self: *Self, notification: Notification) NotificationError!void {
        _ = self;

        const macos = @import("macos.zig");

        // Get UNUserNotificationCenter
        const UNUserNotificationCenter = macos.getClass("UNUserNotificationCenter") orelse
            return NotificationError.NotSupported;

        const center = macos.msgSend0(UNUserNotificationCenter, "currentNotificationCenter");
        if (center == null) return NotificationError.SystemError;

        // Create UNMutableNotificationContent
        const UNMutableNotificationContent = macos.getClass("UNMutableNotificationContent") orelse
            return NotificationError.NotSupported;

        const content = macos.msgSend0(macos.msgSend0(UNMutableNotificationContent, "alloc"), "init");
        if (content == null) return NotificationError.OutOfMemory;

        // Set title
        const NSString = macos.getClass("NSString") orelse return NotificationError.NotSupported;
        const title_str = macos.msgSend0(NSString, "alloc");
        const title_z = std.heap.c_allocator.dupeZ(u8, notification.title) catch
            return NotificationError.OutOfMemory;
        defer std.heap.c_allocator.free(title_z);
        const title_ns = macos.msgSend1(title_str, "initWithUTF8String:", title_z.ptr);
        _ = macos.msgSend1(content, "setTitle:", title_ns);

        // Set body if present
        if (notification.body) |body| {
            const body_str = macos.msgSend0(NSString, "alloc");
            const body_z = std.heap.c_allocator.dupeZ(u8, body) catch
                return NotificationError.OutOfMemory;
            defer std.heap.c_allocator.free(body_z);
            const body_ns = macos.msgSend1(body_str, "initWithUTF8String:", body_z.ptr);
            _ = macos.msgSend1(content, "setBody:", body_ns);
        }

        // Set sound
        if (notification.sound.isEnabled()) {
            const UNNotificationSound = macos.getClass("UNNotificationSound") orelse return NotificationError.NotSupported;
            const sound = macos.msgSend0(UNNotificationSound, "defaultSound");
            _ = macos.msgSend1(content, "setSound:", sound);
        }

        // Create trigger based on notification type
        var trigger: ?*anyopaque = null;
        switch (notification.trigger) {
            .immediate => {
                // No trigger for immediate
            },
            .time_interval => |interval| {
                const UNTimeIntervalNotificationTrigger = macos.getClass("UNTimeIntervalNotificationTrigger") orelse
                    return NotificationError.NotSupported;
                const TriggerFn = *const fn (?*anyopaque, ?*anyopaque, f64, bool) callconv(.c) ?*anyopaque;
                const trigger_fn: TriggerFn = @ptrCast(&macos.objc.objc_msgSend);
                trigger = trigger_fn(
                    UNTimeIntervalNotificationTrigger,
                    macos.sel("triggerWithTimeInterval:repeats:"),
                    @floatFromInt(interval),
                    false,
                );
            },
            .calendar => |cal| {
                const UNCalendarNotificationTrigger = macos.getClass("UNCalendarNotificationTrigger") orelse
                    return NotificationError.NotSupported;
                const NSDateComponents = macos.getClass("NSDateComponents") orelse
                    return NotificationError.NotSupported;

                const components = macos.msgSend0(macos.msgSend0(NSDateComponents, "alloc"), "init");

                const SetIntFn = *const fn (?*anyopaque, ?*anyopaque, c_long) callconv(.c) void;
                const set_fn: SetIntFn = @ptrCast(&macos.objc.objc_msgSend);

                if (cal.hour) |h| set_fn(components, macos.sel("setHour:"), @intCast(h));
                if (cal.minute) |m| set_fn(components, macos.sel("setMinute:"), @intCast(m));
                if (cal.day) |d| set_fn(components, macos.sel("setDay:"), @intCast(d));
                if (cal.month) |mo| set_fn(components, macos.sel("setMonth:"), @intCast(mo));

                trigger = macos.msgSend2(
                    UNCalendarNotificationTrigger,
                    "triggerWithDateMatchingComponents:repeats:",
                    components,
                    @as(?*anyopaque, if (cal.repeats) @ptrFromInt(1) else null),
                );
            },
            else => {},
        }

        // Create request
        const UNNotificationRequest = macos.getClass("UNNotificationRequest") orelse
            return NotificationError.NotSupported;

        const id_str = macos.msgSend0(NSString, "alloc");
        const id_z = std.heap.c_allocator.dupeZ(u8, notification.id) catch
            return NotificationError.OutOfMemory;
        defer std.heap.c_allocator.free(id_z);
        const id_ns = macos.msgSend1(id_str, "initWithUTF8String:", id_z.ptr);

        const request = macos.msgSend3(
            UNNotificationRequest,
            "requestWithIdentifier:content:trigger:",
            id_ns,
            content,
            trigger,
        );

        // Add to notification center
        _ = macos.msgSend2(center, "addNotificationRequest:withCompletionHandler:", request, @as(?*anyopaque, null));
    }

    fn scheduleLinux(self: *Self, notification: Notification) NotificationError!void {
        _ = self;

        // Use libnotify via dynamic loading or fall back to notify-send
        // Try native libnotify first
        const libnotify = struct {
            extern "notify" fn notify_init(app_name: [*:0]const u8) callconv(.c) c_int;
            extern "notify" fn notify_notification_new(
                summary: [*:0]const u8,
                body: ?[*:0]const u8,
                icon: ?[*:0]const u8,
            ) callconv(.c) ?*anyopaque;
            extern "notify" fn notify_notification_set_urgency(
                notification: *anyopaque,
                urgency: c_int,
            ) callconv(.c) void;
            extern "notify" fn notify_notification_show(
                notification: *anyopaque,
                error_ptr: ?*?*anyopaque,
            ) callconv(.c) c_int;
        };

        // Try to use libnotify
        const use_libnotify = @hasDecl(libnotify, "notify_init");

        if (use_libnotify) {
            // Initialize libnotify
            _ = libnotify.notify_init("craft");

            // Create notification
            const title_z = std.heap.c_allocator.dupeZ(u8, notification.title) catch
                return NotificationError.OutOfMemory;
            defer std.heap.c_allocator.free(title_z);

            var body_z: ?[:0]u8 = null;
            if (notification.body) |body| {
                body_z = std.heap.c_allocator.dupeZ(u8, body) catch
                    return NotificationError.OutOfMemory;
            }
            defer if (body_z) |b| std.heap.c_allocator.free(b);

            const notif = libnotify.notify_notification_new(
                title_z.ptr,
                if (body_z) |b| b.ptr else null,
                null,
            ) orelse return NotificationError.SystemError;

            // Set urgency based on priority
            const urgency: c_int = switch (notification.priority) {
                .min, .low => 0, // NOTIFY_URGENCY_LOW
                .default => 1, // NOTIFY_URGENCY_NORMAL
                .high, .max => 2, // NOTIFY_URGENCY_CRITICAL
            };
            libnotify.notify_notification_set_urgency(notif, urgency);

            // Show notification
            if (libnotify.notify_notification_show(notif, null) == 0) {
                return NotificationError.SystemError;
            }
        } else {
            // Fall back to notify-send command
            var args = std.ArrayList([]const u8).init(std.heap.c_allocator);
            defer args.deinit();

            args.append("notify-send") catch return NotificationError.OutOfMemory;

            // Set urgency
            args.append("--urgency") catch return NotificationError.OutOfMemory;
            const urgency = switch (notification.priority) {
                .min, .low => "low",
                .default => "normal",
                .high, .max => "critical",
            };
            args.append(urgency) catch return NotificationError.OutOfMemory;

            // Set category
            args.append("--category") catch return NotificationError.OutOfMemory;
            args.append(notification.category.toString()) catch return NotificationError.OutOfMemory;

            // Add title
            args.append(notification.title) catch return NotificationError.OutOfMemory;

            // Add body if present
            if (notification.body) |body| {
                args.append(body) catch return NotificationError.OutOfMemory;
            }

            var child = std.process.Child.init(args.items, std.heap.c_allocator);
            child.spawn() catch return NotificationError.SystemError;
        }
    }

    fn scheduleWindows(self: *Self, notification: Notification) NotificationError!void {
        _ = self;

        if (builtin.os.tag != .windows) return NotificationError.NotSupported;

        // Windows Toast Notification using Shell API
        // For a full implementation, we'd use WinRT COM interfaces
        // Here we use a simpler approach with PowerShell for cross-version compatibility

        const windows = struct {
            extern "shell32" fn ShellExecuteA(
                hwnd: ?*anyopaque,
                lpOperation: [*:0]const u8,
                lpFile: [*:0]const u8,
                lpParameters: ?[*:0]const u8,
                lpDirectory: ?[*:0]const u8,
                nShowCmd: i32,
            ) callconv(.winapi) isize;
        };

        // Build PowerShell command for toast notification
        var cmd_buf: [2048]u8 = undefined;

        const body_text = notification.body orelse "";
        const ps_cmd = std.fmt.bufPrint(&cmd_buf,
            \\[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
            \\$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
            \\$textNodes = $template.GetElementsByTagName('text')
            \\$textNodes.Item(0).AppendChild($template.CreateTextNode('{s}')) | Out-Null
            \\$textNodes.Item(1).AppendChild($template.CreateTextNode('{s}')) | Out-Null
            \\$toast = [Windows.UI.Notifications.ToastNotification]::new($template)
            \\[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Craft').Show($toast)
        , .{ notification.title, body_text }) catch return NotificationError.OutOfMemory;

        // Build full command
        var full_cmd: [4096]u8 = undefined;
        const cmd_str = std.fmt.bufPrint(&full_cmd, "-ExecutionPolicy Bypass -Command \"{s}\"", .{ps_cmd}) catch
            return NotificationError.OutOfMemory;

        const cmd_z = std.heap.c_allocator.dupeZ(u8, cmd_str) catch return NotificationError.OutOfMemory;
        defer std.heap.c_allocator.free(cmd_z);

        const result = windows.ShellExecuteA(
            null,
            "open",
            "powershell.exe",
            cmd_z.ptr,
            null,
            0, // SW_HIDE
        );

        if (result <= 32) {
            return NotificationError.SystemError;
        }
    }

    /// Cancel a scheduled notification
    pub fn cancel(self: *Self, notification_id: []const u8) void {
        _ = self.scheduled.remove(notification_id);

        // Platform-specific cancellation
        if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
            self.cancelDarwin(notification_id);
        }
    }

    fn cancelDarwin(self: *Self, notification_id: []const u8) void {
        _ = self;
        _ = notification_id;
        // In real implementation, use UNUserNotificationCenter
    }

    /// Cancel all scheduled notifications
    pub fn cancelAll(self: *Self) void {
        self.scheduled.clearRetainingCapacity();
    }

    /// Get all pending notifications
    pub fn getPending(self: *Self, allocator: std.mem.Allocator) ![]Notification {
        var list: std.ArrayListUnmanaged(Notification) = .empty;
        errdefer list.deinit(allocator);

        var iter = self.scheduled.iterator();
        while (iter.next()) |entry| {
            try list.append(allocator, entry.value_ptr.*);
        }

        return list.toOwnedSlice(allocator);
    }

    /// Get pending notification count
    pub fn getPendingCount(self: *Self) usize {
        return self.scheduled.count();
    }

    /// Set badge number
    pub fn setBadge(self: *Self, count: u32) NotificationError!void {
        if (!self.settings.badge_enabled) {
            return;
        }

        self.badge_count = count;

        if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
            self.setBadgeDarwin(count);
        }
    }

    fn setBadgeDarwin(self: *Self, count: u32) void {
        _ = self;
        _ = count;
        // In real implementation, use NSApplication.dockTile or UIApplication
    }

    /// Get badge number
    pub fn getBadge(self: *Self) u32 {
        return self.badge_count;
    }

    /// Clear badge
    pub fn clearBadge(self: *Self) NotificationError!void {
        return self.setBadge(0);
    }

    /// Increment badge
    pub fn incrementBadge(self: *Self) NotificationError!void {
        return self.setBadge(self.badge_count + 1);
    }

    /// Present notification immediately (for testing)
    pub fn presentImmediately(self: *Self, notification: Notification) NotificationError!void {
        var immediate_notif = notification;
        immediate_notif.trigger = .immediate;
        try self.schedule(immediate_notif);
    }

    /// Check if notifications are available on this platform
    pub fn isAvailable(self: *Self) bool {
        _ = self;
        return comptime (builtin.os.tag == .macos or
            builtin.os.tag.isDarwin() or
            builtin.os.tag == .linux or
            builtin.os.tag == .windows);
    }
};

/// Notification presets for common use cases
pub const NotificationPresets = struct {
    /// Simple text notification
    pub fn simple(title: []const u8, body: []const u8) Notification {
        return .{
            .title = title,
            .body = body,
        };
    }

    /// Reminder notification
    pub fn reminder(title: []const u8, body: []const u8, delay_seconds: u64) Notification {
        return .{
            .title = title,
            .body = body,
            .category = .reminder,
            .trigger = .{ .time_interval = delay_seconds },
            .sound = .default,
        };
    }

    /// Alarm notification
    pub fn alarm(title: []const u8, body: []const u8, hour: u8, minute: u8) Notification {
        return .{
            .title = title,
            .body = body,
            .category = .alarm,
            .priority = .max,
            .trigger = .{
                .calendar = .{
                    .hour = hour,
                    .minute = minute,
                    .repeats = false,
                },
            },
            .sound = .{ .critical = 1.0 },
            .ios = .{
                .interruption_level = .time_sensitive,
            },
        };
    }

    /// Daily recurring notification
    pub fn daily(title: []const u8, body: []const u8, hour: u8, minute: u8) Notification {
        return .{
            .title = title,
            .body = body,
            .trigger = .{
                .calendar = .{
                    .hour = hour,
                    .minute = minute,
                    .repeats = true,
                },
            },
        };
    }

    /// Weekly recurring notification
    pub fn weekly(title: []const u8, body: []const u8, weekday: u8, hour: u8, minute: u8) Notification {
        return .{
            .title = title,
            .body = body,
            .trigger = .{
                .calendar = .{
                    .weekday = weekday,
                    .hour = hour,
                    .minute = minute,
                    .repeats = true,
                },
            },
        };
    }

    /// Progress notification
    pub fn progressNotification(title: []const u8, current: u32, max: u32) Notification {
        return .{
            .title = title,
            .category = .progress,
            .progress = .{
                .current = current,
                .max = max,
            },
            .sound = .none,
            .android = .{
                .ongoing = true,
                .auto_cancel = false,
            },
        };
    }

    /// Message notification with reply action
    pub fn message(title: []const u8, body: []const u8, thread_id: []const u8) Notification {
        return .{
            .title = title,
            .body = body,
            .category = .message,
            .thread_id = thread_id,
            .actions = &[_]Action{
                .{
                    .id = "reply",
                    .title = "Reply",
                    .text_input = .{
                        .button_title = "Send",
                        .placeholder = "Type a message...",
                    },
                },
                .{
                    .id = "mark_read",
                    .title = "Mark as Read",
                },
            },
        };
    }

    /// Silent notification (for background updates)
    pub fn silent() Notification {
        return .{
            .title = "",
            .silent = true,
            .sound = .none,
        };
    }

    /// Error/alert notification
    pub fn errorAlert(title: []const u8, body: []const u8) Notification {
        return .{
            .title = title,
            .body = body,
            .category = .error_cat,
            .priority = .high,
            .sound = .default,
        };
    }
};

/// Channel presets for common categories
pub const ChannelPresets = struct {
    pub fn general() Channel {
        return .{
            .id = "general",
            .name = "General",
            .description = "General notifications",
            .importance = .default,
        };
    }

    pub fn messages() Channel {
        return .{
            .id = "messages",
            .name = "Messages",
            .description = "Message notifications",
            .importance = .high,
        };
    }

    pub fn reminders() Channel {
        return .{
            .id = "reminders",
            .name = "Reminders",
            .description = "Reminder notifications",
            .importance = .high,
            .bypass_dnd = false,
        };
    }

    pub fn alarms() Channel {
        return .{
            .id = "alarms",
            .name = "Alarms",
            .description = "Alarm notifications",
            .importance = .max,
            .bypass_dnd = true,
        };
    }

    pub fn silent() Channel {
        return .{
            .id = "silent",
            .name = "Silent",
            .description = "Silent notifications",
            .importance = .low,
            .sound = .none,
            .vibration = false,
        };
    }

    pub fn downloads() Channel {
        return .{
            .id = "downloads",
            .name = "Downloads",
            .description = "Download progress notifications",
            .importance = .low,
            .sound = .none,
        };
    }
};

// Type aliases for backwards compatibility with main.zig
pub const Notifications = NotificationManager;
pub const NotificationOptions = Notification.ForegroundPresentation;
pub const NotificationAction = Action;

// ============================================================================
// Tests
// ============================================================================

test "Priority toString" {
    try std.testing.expectEqualStrings("min", Priority.min.toString());
    try std.testing.expectEqualStrings("default", Priority.default.toString());
    try std.testing.expectEqualStrings("max", Priority.max.toString());
}

test "Priority toAndroidImportance" {
    try std.testing.expectEqual(@as(i32, 1), Priority.min.toAndroidImportance());
    try std.testing.expectEqual(@as(i32, 3), Priority.default.toAndroidImportance());
    try std.testing.expectEqual(@as(i32, 5), Priority.max.toAndroidImportance());
}

test "Category toString" {
    try std.testing.expectEqualStrings("general", Category.general.toString());
    try std.testing.expectEqualStrings("message", Category.message.toString());
    try std.testing.expectEqualStrings("alarm", Category.alarm.toString());
}

test "Sound isEnabled" {
    const default_sound: Sound = .default;
    const no_sound: Sound = .none;
    const custom_sound: Sound = .{ .custom = "alert.wav" };

    try std.testing.expect(default_sound.isEnabled());
    try std.testing.expect(!no_sound.isEnabled());
    try std.testing.expect(custom_sound.isEnabled());
}

test "Progress percentage" {
    const progress = Progress{ .current = 50, .max = 100 };
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), progress.percentage(), 0.01);

    const zero_max = Progress{ .current = 0, .max = 0 };
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), zero_max.percentage(), 0.01);
}

test "PermissionStatus isGranted" {
    try std.testing.expect(!PermissionStatus.not_determined.isGranted());
    try std.testing.expect(!PermissionStatus.denied.isGranted());
    try std.testing.expect(PermissionStatus.authorized.isGranted());
    try std.testing.expect(PermissionStatus.provisional.isGranted());
}

test "PermissionStatus toString" {
    try std.testing.expectEqualStrings("authorized", PermissionStatus.authorized.toString());
    try std.testing.expectEqualStrings("denied", PermissionStatus.denied.toString());
}

test "NotificationManager initialization" {
    var manager = NotificationManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectEqual(PermissionStatus.not_determined, manager.getPermissionStatus());
    try std.testing.expect(manager.isAvailable());
}

test "NotificationManager requestPermission" {
    var manager = NotificationManager.init(std.testing.allocator);
    defer manager.deinit();

    const status = try manager.requestPermission(.{});
    try std.testing.expect(status.isGranted());
}

test "NotificationManager createChannel" {
    var manager = NotificationManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.createChannel(ChannelPresets.general());
    try manager.createChannel(ChannelPresets.messages());

    const channel = manager.getChannel("general");
    try std.testing.expect(channel != null);
    try std.testing.expectEqualStrings("General", channel.?.name);
}

test "NotificationManager deleteChannel" {
    var manager = NotificationManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.createChannel(ChannelPresets.general());
    manager.deleteChannel("general");

    try std.testing.expect(manager.getChannel("general") == null);
}

test "NotificationManager getAllChannels" {
    var manager = NotificationManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.createChannel(ChannelPresets.general());
    try manager.createChannel(ChannelPresets.messages());

    const channels = try manager.getAllChannels(std.testing.allocator);
    defer std.testing.allocator.free(channels);

    try std.testing.expectEqual(@as(usize, 2), channels.len);
}

test "NotificationManager schedule" {
    // UNUserNotificationCenter requires an app bundle; skip in test binaries
    if (comptime @import("builtin").os.tag == .macos) return error.SkipZigTest;

    var manager = NotificationManager.init(std.testing.allocator);
    defer manager.deinit();

    _ = try manager.requestPermission(.{});

    const notification = NotificationPresets.simple("Test", "Test body");
    try manager.schedule(notification);

    const pending = try manager.getPending(std.testing.allocator);
    defer std.testing.allocator.free(pending);

    try std.testing.expectEqual(@as(usize, 1), pending.len);
    try std.testing.expectEqual(@as(usize, 1), manager.getPendingCount());
}

test "NotificationManager cancel" {
    if (comptime @import("builtin").os.tag == .macos) return error.SkipZigTest;

    var manager = NotificationManager.init(std.testing.allocator);
    defer manager.deinit();

    _ = try manager.requestPermission(.{});

    var notification = NotificationPresets.simple("Test", "Test body");
    notification.id = "test-id";
    try manager.schedule(notification);

    manager.cancel("test-id");

    const pending = try manager.getPending(std.testing.allocator);
    defer std.testing.allocator.free(pending);

    try std.testing.expectEqual(@as(usize, 0), pending.len);
}

test "NotificationManager cancelAll" {
    if (comptime @import("builtin").os.tag == .macos) return error.SkipZigTest;

    var manager = NotificationManager.init(std.testing.allocator);
    defer manager.deinit();

    _ = try manager.requestPermission(.{});

    var n1 = NotificationPresets.simple("Test 1", "Body 1");
    n1.id = "id1";
    var n2 = NotificationPresets.simple("Test 2", "Body 2");
    n2.id = "id2";

    try manager.schedule(n1);
    try manager.schedule(n2);

    manager.cancelAll();

    try std.testing.expectEqual(@as(usize, 0), manager.getPendingCount());
}

test "NotificationManager badge" {
    var manager = NotificationManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectEqual(@as(u32, 0), manager.getBadge());

    try manager.setBadge(5);
    try std.testing.expectEqual(@as(u32, 5), manager.getBadge());

    try manager.incrementBadge();
    try std.testing.expectEqual(@as(u32, 6), manager.getBadge());

    try manager.clearBadge();
    try std.testing.expectEqual(@as(u32, 0), manager.getBadge());
}

test "NotificationPresets simple" {
    const notif = NotificationPresets.simple("Hello", "World");
    try std.testing.expectEqualStrings("Hello", notif.title);
    try std.testing.expectEqualStrings("World", notif.body.?);
}

test "NotificationPresets reminder" {
    const notif = NotificationPresets.reminder("Reminder", "Don't forget!", 300);
    try std.testing.expectEqual(Category.reminder, notif.category);
    try std.testing.expectEqual(@as(u64, 300), notif.trigger.time_interval);
}

test "NotificationPresets alarm" {
    const notif = NotificationPresets.alarm("Wake Up", "Time to start your day", 7, 30);
    try std.testing.expectEqual(Category.alarm, notif.category);
    try std.testing.expectEqual(Priority.max, notif.priority);
    try std.testing.expectEqual(@as(u8, 7), notif.trigger.calendar.hour.?);
    try std.testing.expectEqual(@as(u8, 30), notif.trigger.calendar.minute.?);
}

test "NotificationPresets daily" {
    const notif = NotificationPresets.daily("Daily", "Your daily update", 9, 0);
    try std.testing.expect(notif.trigger.calendar.repeats);
}

test "NotificationPresets weekly" {
    const notif = NotificationPresets.weekly("Weekly", "Weekly report", 2, 10, 0);
    try std.testing.expectEqual(@as(u8, 2), notif.trigger.calendar.weekday.?);
    try std.testing.expect(notif.trigger.calendar.repeats);
}

test "NotificationPresets progressNotification" {
    const notif = NotificationPresets.progressNotification("Downloading", 50, 100);
    try std.testing.expect(notif.progress != null);
    try std.testing.expectEqual(@as(u32, 50), notif.progress.?.current);
    try std.testing.expectEqual(@as(u32, 100), notif.progress.?.max);
}

test "NotificationPresets message" {
    const notif = NotificationPresets.message("John", "Hello!", "chat-123");
    try std.testing.expectEqual(Category.message, notif.category);
    try std.testing.expectEqualStrings("chat-123", notif.thread_id.?);
    try std.testing.expect(notif.actions != null);
    try std.testing.expectEqual(@as(usize, 2), notif.actions.?.len);
}

test "NotificationPresets silent" {
    const notif = NotificationPresets.silent();
    try std.testing.expect(notif.silent);
    try std.testing.expect(!notif.sound.isEnabled());
}

test "NotificationPresets errorAlert" {
    const notif = NotificationPresets.errorAlert("Error", "Something went wrong");
    try std.testing.expectEqual(Category.error_cat, notif.category);
    try std.testing.expectEqual(Priority.high, notif.priority);
}

test "ChannelPresets" {
    const general = ChannelPresets.general();
    try std.testing.expectEqualStrings("general", general.id);
    try std.testing.expectEqual(Priority.default, general.importance);

    const alarms = ChannelPresets.alarms();
    try std.testing.expectEqual(Priority.max, alarms.importance);
    try std.testing.expect(alarms.bypass_dnd);

    const silent = ChannelPresets.silent();
    try std.testing.expect(!silent.sound.isEnabled());
    try std.testing.expect(!silent.vibration);

    const downloads = ChannelPresets.downloads();
    try std.testing.expectEqualStrings("downloads", downloads.id);
}

test "Channel init" {
    const channel = Channel.init("test", "Test Channel");
    try std.testing.expectEqualStrings("test", channel.id);
    try std.testing.expectEqualStrings("Test Channel", channel.name);
}

test "Notification trigger validation" {
    var manager = NotificationManager.init(std.testing.allocator);
    defer manager.deinit();

    _ = try manager.requestPermission(.{});

    // Invalid time interval (0)
    var invalid_notif = NotificationPresets.simple("Test", "Body");
    invalid_notif.trigger = .{ .time_interval = 0 };

    const result = manager.schedule(invalid_notif);
    try std.testing.expectError(NotificationError.InvalidTrigger, result);
}

test "Notification permission denied" {
    var manager = NotificationManager.init(std.testing.allocator);
    defer manager.deinit();

    // Don't request permission
    const notif = NotificationPresets.simple("Test", "Body");
    const result = manager.schedule(notif);
    try std.testing.expectError(NotificationError.PermissionDenied, result);
}
