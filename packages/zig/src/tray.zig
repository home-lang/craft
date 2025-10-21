const std = @import("std");

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

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, title: []const u8) Self {
        return .{
            .title = title,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.platform_handle) |handle| {
            const builtin = @import("builtin");
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
        const builtin = @import("builtin");
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
            const builtin = @import("builtin");
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
            const builtin = @import("builtin");
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
            const builtin = @import("builtin");
            switch (builtin.target.os.tag) {
                .macos => try macosSetTooltip(handle, tooltip),
                .windows => try windowsSetTooltip(handle, tooltip),
                .linux => try linuxSetTooltip(handle, tooltip),
                else => {},
            }
        }
    }
};

// ============================================================================
// macOS Implementation using NSStatusBar
// ============================================================================

const objc = @cImport({
    @cInclude("objc/message.h");
    @cInclude("objc/runtime.h");
});

fn macosCreate(title: []const u8, icon_text: ?[]const u8) !*anyopaque {
    _ = title;

    // Get NSStatusBar systemStatusBar
    const NSStatusBar = objc.objc_getClass("NSStatusBar");
    const systemStatusBar = objc.objc_msgSend(NSStatusBar, objc.sel_registerName("systemStatusBar"));

    // Create status item with variable length
    const NSVariableStatusItemLength: f64 = -1.0;
    const statusItem = objc.objc_msgSend(systemStatusBar, objc.sel_registerName("statusItemWithLength:"), NSVariableStatusItemLength);

    // Get the button
    const button = objc.objc_msgSend(statusItem, objc.sel_registerName("button"));

    // Set initial title if provided
    if (icon_text) |text| {
        const NSString = objc.objc_getClass("NSString");
        const titleStr = objc.objc_msgSend(NSString, objc.sel_registerName("stringWithUTF8String:"), text.ptr);
        _ = objc.objc_msgSend(button, objc.sel_registerName("setTitle:"), titleStr);
    }

    // Retain the status item so it doesn't get deallocated
    _ = objc.objc_msgSend(statusItem, objc.sel_registerName("retain"));

    return @ptrFromInt(@as(usize, @intCast(@intFromPtr(statusItem))));
}

fn macosSetTitle(handle: *anyopaque, title: []const u8) !void {
    const statusItem = @as(*objc.id, @ptrCast(@alignCast(handle)));

    // Get the button
    const button = objc.objc_msgSend(statusItem.*, objc.sel_registerName("button"));

    // Create NSString from title
    const NSString = objc.objc_getClass("NSString");
    const titleStr = objc.objc_msgSend(NSString, objc.sel_registerName("stringWithUTF8String:"), title.ptr);

    // Set title on button
    _ = objc.objc_msgSend(button, objc.sel_registerName("setTitle:"), titleStr);
}

fn macosSetTooltip(handle: *anyopaque, tooltip: []const u8) !void {
    const statusItem = @as(*objc.id, @ptrCast(@alignCast(handle)));

    // Get the button
    const button = objc.objc_msgSend(statusItem.*, objc.sel_registerName("button"));

    // Create NSString from tooltip
    const NSString = objc.objc_getClass("NSString");
    const tooltipStr = objc.objc_msgSend(NSString, objc.sel_registerName("stringWithUTF8String:"), tooltip.ptr);

    // Set tooltip on button
    _ = objc.objc_msgSend(button, objc.sel_registerName("setToolTip:"), tooltipStr);
}

fn macosHide(handle: *anyopaque) void {
    const statusItem = @as(*objc.id, @ptrCast(@alignCast(handle)));

    // Set visible to NO
    _ = objc.objc_msgSend(statusItem.*, objc.sel_registerName("setVisible:"), @as(c_int, 0));
}

fn macosDestroy(handle: *anyopaque) void {
    const statusItem = @as(*objc.id, @ptrCast(@alignCast(handle)));

    // Get status bar and remove item
    const NSStatusBar = objc.objc_getClass("NSStatusBar");
    const systemStatusBar = objc.objc_msgSend(NSStatusBar, objc.sel_registerName("systemStatusBar"));
    _ = objc.objc_msgSend(systemStatusBar, objc.sel_registerName("removeStatusItem:"), statusItem.*);

    // Release
    _ = objc.objc_msgSend(statusItem.*, objc.sel_registerName("release"));
}

// ============================================================================
// Windows Implementation (Stubs for now)
// ============================================================================

fn windowsCreate(_: []const u8, _: ?[]const u8) !*anyopaque {
    // TODO: Implement Shell_NotifyIcon
    return error.NotImplemented;
}

fn windowsSetTitle(_: *anyopaque, _: []const u8) !void {
    // TODO: Implement
}

fn windowsSetTooltip(_: *anyopaque, _: []const u8) !void {
    // TODO: Implement
}

fn windowsHide(_: *anyopaque) void {
    // TODO: Implement
}

fn windowsDestroy(_: *anyopaque) void {
    // TODO: Implement
}

// ============================================================================
// Linux Implementation (Stubs for now)
// ============================================================================

fn linuxCreate(_: []const u8, _: ?[]const u8) !*anyopaque {
    // TODO: Implement libappindicator
    return error.NotImplemented;
}

fn linuxSetTitle(_: *anyopaque, _: []const u8) !void {
    // TODO: Implement
}

fn linuxSetTooltip(_: *anyopaque, _: []const u8) !void {
    // TODO: Implement
}

fn linuxHide(_: *anyopaque) void {
    // TODO: Implement
}

fn linuxDestroy(_: *anyopaque) void {
    // TODO: Implement
}
