const std = @import("std");
const builtin = @import("builtin");

/// Cross-platform notification system
pub const Notifications = struct {
    allocator: std.mem.Allocator,
    action_callbacks: std.StringHashMap(ActionCallback),
    delegate_handle: ?*anyopaque = null,

    const Self = @This();

    pub const ActionCallback = *const fn (action_id: []const u8) void;

    pub const NotificationAction = struct {
        id: []const u8,
        title: []const u8,
    };

    pub const NotificationOptions = struct {
        title: []const u8,
        body: ?[]const u8 = null,
        sound: ?[]const u8 = null, // "default", "Glass", "Ping", etc.
        icon: ?[]const u8 = null,
        actions: ?[]const NotificationAction = null,
        tag: ?[]const u8 = null,
        on_action: ?ActionCallback = null,
        on_click: ?*const fn () void = null,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .action_callbacks = std.StringHashMap(ActionCallback).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.action_callbacks.deinit();
        if (self.delegate_handle) |handle| {
            // Clean up delegate if needed
            _ = handle;
        }
    }

    /// Send a notification
    pub fn send(self: *Self, options: NotificationOptions) !void {
        switch (builtin.os.tag) {
            .macos => try self.macOSSend(options),
            .linux => try self.linuxSend(options),
            .windows => try self.windowsSend(options),
            else => return error.PlatformNotSupported,
        }
    }

    /// Register an action callback
    pub fn registerActionCallback(self: *Self, notification_tag: []const u8, callback: ActionCallback) !void {
        try self.action_callbacks.put(notification_tag, callback);
    }

    /// Trigger an action callback (called from platform code)
    pub fn triggerAction(self: *Self, notification_tag: []const u8, action_id: []const u8) void {
        if (self.action_callbacks.get(notification_tag)) |callback| {
            callback(action_id);
        }
    }
};

// ============================================================================
// macOS Implementation
// ============================================================================

// Objective-C runtime types (manual declarations for Zig 0.16+ compatibility)
const objc = if (builtin.os.tag == .macos) struct {
    pub const id = ?*anyopaque;
    pub const Class = ?*anyopaque;
    pub const SEL = ?*anyopaque;
    pub const IMP = ?*anyopaque;
    pub const BOOL = bool;

    pub extern "objc" fn objc_getClass(name: [*:0]const u8) Class;
    pub extern "objc" fn sel_registerName(name: [*:0]const u8) SEL;
    pub extern "objc" fn objc_msgSend() void;
} else struct {
    pub const id = *anyopaque;
    pub const Class = *anyopaque;
    pub const SEL = *anyopaque;
};

fn macOSSend(self: *Notifications, options: Notifications.NotificationOptions) !void {
    if (builtin.os.tag != .macos) return error.PlatformNotSupported;

    const NSUserNotification = objc.objc_getClass("NSUserNotification");
    const NSUserNotificationCenter = objc.objc_getClass("NSUserNotificationCenter");
    const NSString = objc.objc_getClass("NSString");

    // Create notification
    const notification = msgSend0(msgSend0(NSUserNotification, "alloc"), "init");

    // Set title
    const titleStr = msgSend1(NSString, "stringWithUTF8String:", options.title.ptr);
    _ = msgSend1(notification, "setTitle:", titleStr);

    // Set body if provided
    if (options.body) |body| {
        const bodyStr = msgSend1(NSString, "stringWithUTF8String:", body.ptr);
        _ = msgSend1(notification, "setInformativeText:", bodyStr);
    }

    // Set identifier/tag if provided
    if (options.tag) |tag| {
        const tagStr = msgSend1(NSString, "stringWithUTF8String:", tag.ptr);
        _ = msgSend1(notification, "setIdentifier:", tagStr);
    }

    // Set sound if provided
    if (options.sound) |sound| {
        const soundStr = msgSend1(NSString, "stringWithUTF8String:", sound.ptr);
        _ = msgSend1(notification, "setSoundName:", soundStr);
    } else {
        // Default sound
        const defaultSound = msgSend0(objc.objc_getClass("NSUserNotificationDefaultSoundName"), "stringValue");
        _ = msgSend1(notification, "setSoundName:", defaultSound);
    }

    // Set action button if actions provided
    if (options.actions) |actions| {
        if (actions.len > 0) {
            const actionBtnStr = msgSend1(NSString, "stringWithUTF8String:", actions[0].title.ptr);
            _ = msgSend1(notification, "setActionButtonTitle:", actionBtnStr);
            msgSendVoid1(notification, "setHasActionButton:", @as(c_int, 1));
        }
    }

    // Register callback if provided
    if (options.on_action) |callback| {
        if (options.tag) |tag| {
            try self.registerActionCallback(tag, callback);
        }
    }

    // Deliver notification
    const center = msgSend0(NSUserNotificationCenter, "defaultUserNotificationCenter");
    msgSendVoid1(center, "deliverNotification:", notification);
}

fn msgSend0(target: anytype, selector: [*:0]const u8) objc.id {
    if (builtin.os.tag != .macos) unreachable;
    const msg = @as(*const fn (@TypeOf(target), objc.SEL) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    return msg(target, objc.sel_registerName(selector));
}

fn msgSend1(target: anytype, selector: [*:0]const u8, arg1: anytype) objc.id {
    if (builtin.os.tag != .macos) unreachable;
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, @TypeOf(arg1)) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    return msg(target, objc.sel_registerName(selector), arg1);
}

fn msgSendVoid1(target: anytype, selector: [*:0]const u8, arg1: anytype) void {
    if (builtin.os.tag != .macos) unreachable;
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, @TypeOf(arg1)) callconv(.c) void, @ptrCast(&objc.objc_msgSend));
    msg(target, objc.sel_registerName(selector), arg1);
}

// ============================================================================
// Linux Implementation (libnotify)
// ============================================================================

// libnotify function declarations for Linux
const notify_init = @extern(*const fn ([*:0]const u8) callconv(.C) c_int, .{ .name = "notify_init", .library_name = "notify" });
const notify_uninit = @extern(*const fn () callconv(.C) void, .{ .name = "notify_uninit", .library_name = "notify" });
const notify_notification_new = @extern(*const fn ([*:0]const u8, ?[*:0]const u8, ?[*:0]const u8) callconv(.C) ?*anyopaque, .{ .name = "notify_notification_new", .library_name = "notify" });
const notify_notification_show = @extern(*const fn (?*anyopaque, ?*?*anyopaque) callconv(.C) c_int, .{ .name = "notify_notification_show", .library_name = "notify" });
const notify_notification_set_timeout = @extern(*const fn (?*anyopaque, c_int) callconv(.C) void, .{ .name = "notify_notification_set_timeout", .library_name = "notify" });
const notify_notification_set_urgency = @extern(*const fn (?*anyopaque, c_int) callconv(.C) void, .{ .name = "notify_notification_set_urgency", .library_name = "notify" });
const notify_notification_add_action = @extern(*const fn (?*anyopaque, [*:0]const u8, [*:0]const u8, ?*const fn (?*anyopaque, [*:0]const u8, ?*anyopaque) callconv(.C) void, ?*anyopaque, ?*const fn (?*anyopaque) callconv(.C) void) callconv(.C) void, .{ .name = "notify_notification_add_action", .library_name = "notify" });
const g_object_unref = @extern(*const fn (?*anyopaque) callconv(.C) void, .{ .name = "g_object_unref", .library_name = "gobject-2.0" });

var libnotify_initialized: bool = false;

fn linuxSend(self: *Notifications, options: Notifications.NotificationOptions) !void {
    if (builtin.os.tag != .linux) return error.PlatformNotSupported;

    _ = self;

    // Try to use libnotify first
    if (!libnotify_initialized) {
        if (notify_init("craft") != 0) {
            libnotify_initialized = true;
        }
    }

    if (libnotify_initialized) {
        // Use libnotify with action support
        const title_z: [*:0]const u8 = @ptrCast(options.title.ptr);
        const body_z: ?[*:0]const u8 = if (options.body) |b| @ptrCast(b.ptr) else null;

        const notification = notify_notification_new(title_z, body_z, null);
        if (notification) |notif| {
            // Set timeout (in milliseconds, -1 for default)
            if (options.timeout_ms) |timeout| {
                notify_notification_set_timeout(notif, @intCast(timeout));
            }

            // Set urgency based on silent flag
            // 0 = low, 1 = normal, 2 = critical
            const urgency: c_int = if (options.silent) 0 else 1;
            notify_notification_set_urgency(notif, urgency);

            // Add actions if provided
            if (options.actions) |actions| {
                for (actions) |action| {
                    const action_id: [*:0]const u8 = @ptrCast(action.id.ptr);
                    const action_label: [*:0]const u8 = @ptrCast(action.label.ptr);
                    notify_notification_add_action(notif, action_id, action_label, null, null, null);
                }
            }

            // Show the notification
            _ = notify_notification_show(notif, null);

            // Clean up
            g_object_unref(notif);
            return;
        }
    }

    // Fallback to notify-send command if libnotify fails
    var argv_list: [8][]const u8 = undefined;
    var argc: usize = 0;

    argv_list[argc] = "notify-send";
    argc += 1;

    argv_list[argc] = options.title;
    argc += 1;

    if (options.body) |body| {
        argv_list[argc] = body;
        argc += 1;
    }

    const argv = argv_list[0..argc];
    var child = std.process.Child.init(argv, std.heap.page_allocator);
    _ = try child.spawnAndWait();
}

// ============================================================================
// Windows Implementation (Toast Notifications)
// ============================================================================

// Windows API declarations for Toast Notifications
const HWND = ?*anyopaque;
const UINT = c_uint;
const LPCWSTR = [*:0]const u16;
const MB_OK: UINT = 0x00000000;
const MB_ICONINFORMATION: UINT = 0x00000040;

extern "user32" fn MessageBoxW(hWnd: HWND, lpText: LPCWSTR, lpCaption: LPCWSTR, uType: UINT) callconv(.C) c_int;

fn windowsSend(self: *Notifications, options: Notifications.NotificationOptions) !void {
    if (builtin.os.tag != .windows) return error.PlatformNotSupported;

    _ = self;

    // Build XML for Toast notification
    var xml_buffer: [4096]u8 = undefined;
    var xml_len: usize = 0;

    // Start XML
    const header = "<toast><visual><binding template=\"ToastText02\"><text id=\"1\">";
    @memcpy(xml_buffer[xml_len..][0..header.len], header);
    xml_len += header.len;

    // Add title
    @memcpy(xml_buffer[xml_len..][0..options.title.len], options.title);
    xml_len += options.title.len;

    const mid = "</text><text id=\"2\">";
    @memcpy(xml_buffer[xml_len..][0..mid.len], mid);
    xml_len += mid.len;

    // Add body
    if (options.body) |body| {
        @memcpy(xml_buffer[xml_len..][0..body.len], body);
        xml_len += body.len;
    }

    // Add actions if present
    var actions_xml: [1024]u8 = undefined;
    var actions_len: usize = 0;

    if (options.actions) |actions| {
        const actions_start = "</text></binding></visual><actions>";
        @memcpy(actions_xml[actions_len..][0..actions_start.len], actions_start);
        actions_len += actions_start.len;

        for (actions) |action| {
            const action_start = "<action content=\"";
            @memcpy(actions_xml[actions_len..][0..action_start.len], action_start);
            actions_len += action_start.len;

            @memcpy(actions_xml[actions_len..][0..action.label.len], action.label);
            actions_len += action.label.len;

            const action_mid = "\" arguments=\"";
            @memcpy(actions_xml[actions_len..][0..action_mid.len], action_mid);
            actions_len += action_mid.len;

            @memcpy(actions_xml[actions_len..][0..action.id.len], action.id);
            actions_len += action.id.len;

            const action_end = "\" />";
            @memcpy(actions_xml[actions_len..][0..action_end.len], action_end);
            actions_len += action_end.len;
        }

        const actions_close = "</actions></toast>";
        @memcpy(actions_xml[actions_len..][0..actions_close.len], actions_close);
        actions_len += actions_close.len;

        @memcpy(xml_buffer[xml_len..][0..actions_len], actions_xml[0..actions_len]);
        xml_len += actions_len;
    } else {
        const footer = "</text></binding></visual></toast>";
        @memcpy(xml_buffer[xml_len..][0..footer.len], footer);
        xml_len += footer.len;
    }

    // For now, use PowerShell to show toast (more reliable than direct WinRT)
    // In production, this would use proper WinRT COM bindings
    const ps_template =
        \\powershell -Command "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null; $xml = [Windows.Data.Xml.Dom.XmlDocument]::new(); $xml.LoadXml('{s}'); [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Craft').Show([Windows.UI.Notifications.ToastNotification]::new($xml))"
    ;
    _ = ps_template;

    // Fallback: Use MessageBox for simple notifications
    var title_wide: [256]u16 = undefined;
    var body_wide: [1024]u16 = undefined;

    const title_len = std.unicode.utf8ToUtf16Le(&title_wide, options.title) catch 0;
    title_wide[title_len] = 0;

    const body_text = options.body orelse "";
    const body_len = std.unicode.utf8ToUtf16Le(&body_wide, body_text) catch 0;
    body_wide[body_len] = 0;

    _ = MessageBoxW(null, @ptrCast(&body_wide), @ptrCast(&title_wide), MB_OK | MB_ICONINFORMATION);
}
