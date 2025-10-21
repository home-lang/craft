const std = @import("std");
const builtin = @import("builtin");

/// System Tray / Status Bar Icon Support
/// Cross-platform implementation for macOS, Windows, and Linux
pub const SystemTray = struct {
    title: []const u8,
    icon_text: ?[]const u8 = null,
    tooltip: ?[]const u8 = null,
    visible: bool = true,
    allocator: std.mem.Allocator,

    // Platform-specific handles
    platform_handle: ?*anyopaque = null,

    // Click callback
    click_callback: ?*const fn () void = null,

    // Menu handle
    menu_handle: ?*anyopaque = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, title: []const u8) Self {
        return .{
            .title = title,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.platform_handle) |handle| {
            switch (builtin.target.os.tag) {
                .macos => macosDestroy(handle),
                .windows => windowsDestroy(handle),
                .linux => linuxDestroy(handle),
                else => {},
            }
        }
    }

    /// Create and show the system tray icon
    pub fn show(self: *Self) !void {
        switch (builtin.target.os.tag) {
            .macos => {
                self.platform_handle = try macosCreate(self.title, self.icon_text);
            },
            .windows => {
                self.platform_handle = try windowsCreate(self.title, self.icon_text);
            },
            .linux => {
                self.platform_handle = try linuxCreate(self.title, self.icon_text);
            },
            else => return error.PlatformNotSupported,
        }
        self.visible = true;
    }

    /// Hide the system tray icon
    pub fn hide(self: *Self) void {
        self.visible = false;
        if (self.platform_handle) |handle| {
            switch (builtin.target.os.tag) {
                .macos => macosHide(handle),
                .windows => windowsHide(handle),
                .linux => linuxHide(handle),
                else => {},
            }
        }
    }

    /// Update the tray icon text/title (for text-based menubar items)
    pub fn setTitle(self: *Self, title: []const u8) !void {
        self.icon_text = title;
        if (self.platform_handle) |handle| {
            switch (builtin.target.os.tag) {
                .macos => try macosSetTitle(handle, title),
                .windows => try windowsSetTitle(handle, title),
                .linux => try linuxSetTitle(handle, title),
                else => {},
            }
        }
    }

    /// Set tooltip text
    pub fn setTooltip(self: *Self, tooltip: []const u8) !void {
        self.tooltip = tooltip;
        if (self.platform_handle) |handle| {
            switch (builtin.target.os.tag) {
                .macos => try macosSetTooltip(handle, tooltip),
                .windows => try windowsSetTooltip(handle, tooltip),
                .linux => try linuxSetTooltip(handle, tooltip),
                else => {},
            }
        }
    }

    /// Set click callback
    pub fn setClickCallback(self: *Self, callback: *const fn () void) void {
        self.click_callback = callback;
    }

    /// Trigger click event (called from platform code)
    pub fn triggerClick(self: *Self) void {
        if (self.click_callback) |callback| {
            callback();
        }
    }

    /// Attach a menu to the tray icon
    pub fn setMenu(self: *Self, menu_handle: *anyopaque) !void {
        self.menu_handle = menu_handle;
        if (self.platform_handle) |handle| {
            switch (builtin.target.os.tag) {
                .macos => try macosSetMenu(handle, menu_handle),
                .windows => {}, // Windows tray menus handled differently
                .linux => {},   // Linux tray menus handled differently
                else => {},
            }
        }
    }
};

// ============================================================================
// macOS Implementation using NSStatusBar
// ============================================================================

const objc = if (builtin.target.os.tag == .macos) @cImport({
    @cInclude("objc/message.h");
    @cInclude("objc/runtime.h");
}) else struct {};

fn msgSend0(target: anytype, selector: [*:0]const u8) if (builtin.target.os.tag == .macos) objc.id else *anyopaque {
    if (builtin.target.os.tag != .macos) unreachable;
    const msg = @as(*const fn (@TypeOf(target), objc.SEL) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    return msg(target, objc.sel_registerName(selector));
}

fn msgSend1(target: anytype, selector: [*:0]const u8, arg1: anytype) if (builtin.target.os.tag == .macos) objc.id else *anyopaque {
    if (builtin.target.os.tag != .macos) unreachable;
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, @TypeOf(arg1)) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    return msg(target, objc.sel_registerName(selector), arg1);
}

fn msgSendVoid1(target: anytype, selector: [*:0]const u8, arg1: anytype) void {
    if (builtin.target.os.tag != .macos) unreachable;
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, @TypeOf(arg1)) callconv(.c) void, @ptrCast(&objc.objc_msgSend));
    msg(target, objc.sel_registerName(selector), arg1);
}

fn macosCreate(title: []const u8, icon_text: ?[]const u8) !*anyopaque {
    if (builtin.target.os.tag != .macos) return error.PlatformNotSupported;

    // Get NSStatusBar systemStatusBar
    const NSStatusBar = objc.objc_getClass("NSStatusBar");
    const systemStatusBar = msgSend0(NSStatusBar, "systemStatusBar");

    // Create status item with variable length
    const NSVariableStatusItemLength: f64 = -1.0;
    const statusItem = msgSend1(systemStatusBar, "statusItemWithLength:", NSVariableStatusItemLength);

    // Get the button
    const button = msgSend0(statusItem, "button");

    // Set initial title - EXACTLY like working test does it
    // Just use the raw title pointer directly (title is already null-terminated)
    const text_to_display = icon_text orelse title;

    const NSString = objc.objc_getClass("NSString");
    const titleStr = msgSend1(NSString, "stringWithUTF8String:", text_to_display.ptr);
    _ = msgSend1(button, "setTitle:", titleStr);

    // Make sure the status item is visible
    const visible: c_int = 1;
    msgSendVoid1(statusItem, "setVisible:", visible);

    // Retain the status item so it doesn't get deallocated
    _ = msgSend0(statusItem, "retain");

    return @ptrFromInt(@as(usize, @intCast(@intFromPtr(statusItem))));
}

fn macosSetTitle(handle: *anyopaque, title: []const u8) !void {
    if (builtin.target.os.tag != .macos) return;

    const statusItem: objc.id = @ptrFromInt(@intFromPtr(handle));

    // Get the button
    const button = msgSend0(statusItem, "button");

    // Create NSString from title
    const NSString = objc.objc_getClass("NSString");
    const titleStr = msgSend1(NSString, "stringWithUTF8String:", title.ptr);

    // Set title on button
    _ = msgSend1(button, "setTitle:", titleStr);
}

fn macosSetTooltip(handle: *anyopaque, tooltip: []const u8) !void {
    if (builtin.target.os.tag != .macos) return;

    const statusItem: objc.id = @ptrFromInt(@intFromPtr(handle));

    // Get the button
    const button = msgSend0(statusItem, "button");

    // Create NSString from tooltip
    const NSString = objc.objc_getClass("NSString");
    const tooltipStr = msgSend1(NSString, "stringWithUTF8String:", tooltip.ptr);

    // Set tooltip on button
    _ = msgSend1(button, "setToolTip:", tooltipStr);
}

fn macosHide(handle: *anyopaque) void {
    if (builtin.target.os.tag != .macos) return;

    const statusItem: objc.id = @ptrFromInt(@intFromPtr(handle));

    // Set visible to NO
    msgSendVoid1(statusItem, "setVisible:", @as(c_int, 0));
}

fn macosDestroy(handle: *anyopaque) void {
    if (builtin.target.os.tag != .macos) return;

    const statusItem: objc.id = @ptrFromInt(@intFromPtr(handle));

    // Get status bar and remove item
    const NSStatusBar = objc.objc_getClass("NSStatusBar");
    const systemStatusBar = msgSend0(NSStatusBar, "systemStatusBar");
    _ = msgSend1(systemStatusBar, "removeStatusItem:", statusItem);

    // Release
    _ = msgSend0(statusItem, "release");
}

fn macosSetMenu(handle: *anyopaque, menu: *anyopaque) !void {
    if (builtin.target.os.tag != .macos) return;

    const statusItem: objc.id = @ptrFromInt(@intFromPtr(handle));
    const nsMenu: objc.id = @ptrFromInt(@intFromPtr(menu));

    // Set the menu on the status item
    _ = msgSend1(statusItem, "setMenu:", nsMenu);
}

// ============================================================================
// Windows Implementation using Shell_NotifyIcon
// ============================================================================

const windows_tray = if (builtin.target.os.tag == .windows) @import("windows_tray.zig") else struct {};

fn windowsCreate(title: []const u8, _: ?[]const u8) !*anyopaque {
    if (builtin.target.os.tag != .windows) {
        return error.PlatformNotSupported;
    }

    const tray = try std.heap.c_allocator.create(windows_tray.WindowsTray);
    errdefer std.heap.c_allocator.destroy(tray);

    // Pass null to let WindowsTray create its own message-only window
    tray.* = try windows_tray.WindowsTray.init(std.heap.c_allocator, null, title);

    return @ptrCast(tray);
}

fn windowsSetTitle(handle: *anyopaque, title: []const u8) !void {
    if (builtin.target.os.tag != .windows) return;

    const tray = @as(*windows_tray.WindowsTray, @ptrCast(@alignCast(handle)));
    try tray.setTitle(title);
}

fn windowsSetTooltip(handle: *anyopaque, tooltip: []const u8) !void {
    if (builtin.target.os.tag != .windows) return;

    const tray = @as(*windows_tray.WindowsTray, @ptrCast(@alignCast(handle)));
    try tray.setTooltip(tooltip);
}

fn windowsHide(_: *anyopaque) void {
    // Windows doesn't have a hide function; you delete and re-add
    // For now, this is a no-op
}

fn windowsDestroy(handle: *anyopaque) void {
    if (builtin.target.os.tag != .windows) return;

    const tray = @as(*windows_tray.WindowsTray, @ptrCast(@alignCast(handle)));
    tray.deinit();
    std.heap.c_allocator.destroy(tray);
}

// ============================================================================
// Linux Implementation using libappindicator3
// ============================================================================

const linux_tray = if (builtin.target.os.tag == .linux) @import("linux_tray.zig") else struct {};

fn linuxCreate(title: []const u8, icon_text: ?[]const u8) !*anyopaque {
    if (builtin.target.os.tag != .linux) {
        return error.PlatformNotSupported;
    }

    const tray = try std.heap.c_allocator.create(linux_tray.LinuxTray);
    errdefer std.heap.c_allocator.destroy(tray);

    const display_title = if (icon_text) |text| text else title;
    tray.* = try linux_tray.LinuxTray.init(std.heap.c_allocator, display_title);

    return @ptrCast(tray);
}

fn linuxSetTitle(handle: *anyopaque, title: []const u8) !void {
    if (builtin.target.os.tag != .linux) return;

    const tray = @as(*linux_tray.LinuxTray, @ptrCast(@alignCast(handle)));
    try tray.setLabel(title);
}

fn linuxSetTooltip(handle: *anyopaque, tooltip: []const u8) !void {
    if (builtin.target.os.tag != .linux) return;

    const tray = @as(*linux_tray.LinuxTray, @ptrCast(@alignCast(handle)));
    try tray.setTooltip(tooltip);
}

fn linuxHide(_: *anyopaque) void {
    // libappindicator doesn't have a direct hide function
    // Status is set to passive on deinit
}

fn linuxDestroy(handle: *anyopaque) void {
    if (builtin.target.os.tag != .linux) return;

    const tray = @as(*linux_tray.LinuxTray, @ptrCast(@alignCast(handle)));
    tray.deinit();
    std.heap.c_allocator.destroy(tray);
}
