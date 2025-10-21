const std = @import("std");
const builtin = @import("builtin");

/// Cross-platform notification system
pub const Notifications = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub const NotificationOptions = struct {
        title: []const u8,
        body: ?[]const u8 = null,
        sound: ?[]const u8 = null, // "default", "Glass", "Ping", etc.
        icon: ?[]const u8 = null,
        actions: ?[]const []const u8 = null,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Send a notification
    pub fn send(self: *Self, options: NotificationOptions) !void {
        _ = self;
        switch (builtin.os.tag) {
            .macos => try macOSSend(options),
            .linux => try linuxSend(options),
            .windows => try windowsSend(options),
            else => return error.PlatformNotSupported,
        }
    }
};

// ============================================================================
// macOS Implementation
// ============================================================================

const objc = if (builtin.os.tag == .macos) @cImport({
    @cInclude("objc/message.h");
    @cInclude("objc/runtime.h");
}) else struct {};

fn macOSSend(options: Notifications.NotificationOptions) !void {
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

    // Set sound if provided
    if (options.sound) |sound| {
        const soundStr = msgSend1(NSString, "stringWithUTF8String:", sound.ptr);
        _ = msgSend1(notification, "setSoundName:", soundStr);
    } else {
        // Default sound
        const defaultSound = msgSend0(objc.objc_getClass("NSUserNotificationDefaultSoundName"), "stringValue");
        _ = msgSend1(notification, "setSoundName:", defaultSound);
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

fn linuxSend(options: Notifications.NotificationOptions) !void {
    if (builtin.os.tag != .linux) return error.PlatformNotSupported;

    // TODO: Implement using libnotify
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

fn windowsSend(options: Notifications.NotificationOptions) !void {
    if (builtin.os.tag != .windows) return error.PlatformNotSupported;

    // TODO: Implement using Windows Toast Notifications API
    // For now, use a simple message box approach
    _ = options;
    std.debug.print("Notification: {s}\n", .{options.title});
}
