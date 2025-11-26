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

fn linuxSend(self: *Notifications, options: Notifications.NotificationOptions) !void {
    if (builtin.os.tag != .linux) return error.PlatformNotSupported;

    _ = self;

    // TODO: Implement using libnotify with action support
    // For now, use notify-send command
    const argv = [_][]const u8{
        "notify-send",
        options.title,
        options.body orelse "",
    };

    var child = std.process.Child.init(&argv, std.heap.page_allocator);
    _ = try child.spawnAndWait();
}

// ============================================================================
// Windows Implementation (Toast Notifications)
// ============================================================================

fn windowsSend(self: *Notifications, options: Notifications.NotificationOptions) !void {
    if (builtin.os.tag != .windows) return error.PlatformNotSupported;

    _ = self;

    // TODO: Implement using Windows Toast Notifications API with action buttons
    // For now, use a simple message box approach
    std.debug.print("Notification: {s}\n", .{options.title});
}
