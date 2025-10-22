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
            macos.showWindow(self.window_handle.?);
        }
    }

    fn hide(self: *Self) !void {
        if (self.window_handle == null) {
            std.debug.print("Warning: Window handle not set\n", .{});
            return;
        }

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            macos.hideWindow(self.window_handle.?);
        }
    }

    fn toggle(self: *Self) !void {
        if (self.window_handle == null) {
            std.debug.print("Warning: Window handle not set\n", .{});
            return;
        }

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            macos.toggleWindow(self.window_handle.?);
        }
    }

    fn minimize(self: *Self) !void {
        if (self.window_handle == null) {
            std.debug.print("Warning: Window handle not set\n", .{});
            return;
        }

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            macos.minimizeWindow(self.window_handle.?);
        }
    }

    fn close(self: *Self) !void {
        if (self.window_handle == null) {
            std.debug.print("Warning: Window handle not set\n", .{});
            return;
        }

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            macos.closeWindow(self.window_handle.?);
        }
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};
