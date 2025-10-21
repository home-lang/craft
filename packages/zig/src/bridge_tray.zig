const std = @import("std");
const builtin = @import("builtin");

/// Bridge handler for system tray messages from JavaScript
pub const TrayBridge = struct {
    allocator: std.mem.Allocator,
    tray_handle: ?*anyopaque = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn setTrayHandle(self: *Self, handle: *anyopaque) void {
        self.tray_handle = handle;
    }

    /// Handle tray-related messages from JavaScript
    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "setTitle")) {
            try self.setTitle(data);
        } else if (std.mem.eql(u8, action, "setTooltip")) {
            try self.setTooltip(data);
        } else if (std.mem.eql(u8, action, "setMenu")) {
            try self.setMenu(data);
        } else {
            std.debug.print("Unknown tray action: {s}\n", .{action});
        }
    }

    fn setTitle(self: *Self, title: []const u8) !void {
        if (self.tray_handle == null) {
            std.debug.print("Warning: Tray handle not set\n", .{});
            return;
        }

        if (builtin.os.tag == .macos) {
            const macos = @import("tray.zig");
            try macos.macosSetTitle(self.tray_handle.?, title);
        }
    }

    fn setTooltip(self: *Self, tooltip: []const u8) !void {
        if (self.tray_handle == null) {
            std.debug.print("Warning: Tray handle not set\n", .{});
            return;
        }

        if (builtin.os.tag == .macos) {
            const macos = @import("tray.zig");
            try macos.macosSetTooltip(self.tray_handle.?, tooltip);
        }
    }

    fn setMenu(self: *Self, menu_json: []const u8) !void {
        _ = self;
        // Menu handling will be implemented in bridge_menu.zig
        std.debug.print("Menu setting not yet implemented: {s}\n", .{menu_json});
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};
