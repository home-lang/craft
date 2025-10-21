const std = @import("std");
const builtin = @import("builtin");

/// Bridge handler for window control messages from JavaScript
pub const WindowBridge = struct {
    allocator: std.mem.Allocator,
    window_handle: ?*anyopaque = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn setWindowHandle(self: *Self, handle: *anyopaque) void {
        self.window_handle = handle;
    }

    /// Handle window-related messages from JavaScript
    pub fn handleMessage(self: *Self, action: []const u8) !void {
        if (std.mem.eql(u8, action, "show")) {
            try self.show();
        } else if (std.mem.eql(u8, action, "hide")) {
            try self.hide();
        } else if (std.mem.eql(u8, action, "toggle")) {
            try self.toggle();
        } else if (std.mem.eql(u8, action, "minimize")) {
            try self.minimize();
        } else if (std.mem.eql(u8, action, "close")) {
            try self.close();
        } else {
            std.debug.print("Unknown window action: {s}\n", .{action});
        }
    }

    fn show(self: *Self) !void {
        if (self.window_handle == null) {
            std.debug.print("Warning: Window handle not set\n", .{});
            return;
        }

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            const window = @as(macos.objc.id, @ptrFromInt(@intFromPtr(self.window_handle.?)));
            macos.showWindow(window);
        }
    }

    fn hide(self: *Self) !void {
        if (self.window_handle == null) {
            std.debug.print("Warning: Window handle not set\n", .{});
            return;
        }

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            const window = @as(macos.objc.id, @ptrFromInt(@intFromPtr(self.window_handle.?)));
            macos.hideWindow(window);
        }
    }

    fn toggle(self: *Self) !void {
        if (self.window_handle == null) {
            std.debug.print("Warning: Window handle not set\n", .{});
            return;
        }

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            const window = @as(macos.objc.id, @ptrFromInt(@intFromPtr(self.window_handle.?)));

            // Check if window is visible
            const is_visible = macos.msgSend0(window, "isVisible");
            const visible = @as(i64, @bitCast(is_visible)) != 0;

            if (visible) {
                macos.hideWindow(window);
            } else {
                macos.showWindow(window);
            }
        }
    }

    fn minimize(self: *Self) !void {
        if (self.window_handle == null) {
            std.debug.print("Warning: Window handle not set\n", .{});
            return;
        }

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            const window = @as(macos.objc.id, @ptrFromInt(@intFromPtr(self.window_handle.?)));
            macos.minimizeWindow(window);
        }
    }

    fn close(self: *Self) !void {
        if (self.window_handle == null) {
            std.debug.print("Warning: Window handle not set\n", .{});
            return;
        }

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            const window = @as(macos.objc.id, @ptrFromInt(@intFromPtr(self.window_handle.?)));
            macos.closeWindow(window);
        }
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};
