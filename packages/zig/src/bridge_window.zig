const std = @import("std");
const builtin = @import("builtin");

/// Bridge handler for window control messages from JavaScript
pub const WindowBridge = struct {
    allocator: std.mem.Allocator,
    window_handle: ?*anyopaque = null,
    webview_handle: ?*anyopaque = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn setWindowHandle(self: *Self, handle: *anyopaque) void {
        self.window_handle = handle;
    }

    pub fn setWebViewHandle(self: *Self, handle: *anyopaque) void {
        self.webview_handle = handle;
    }

    /// Handle window-related messages from JavaScript
    /// action: the action name, data: optional JSON data string
    pub fn handleMessage(self: *Self, action: []const u8) !void {
        self.handleMessageWithData(action, null) catch |err| {
            std.debug.print("[WindowBridge] Error handling {s}: {}\n", .{ action, err });
        };
    }

    pub fn handleMessageWithData(self: *Self, action: []const u8, data: ?[]const u8) !void {
        if (std.mem.eql(u8, action, "show")) {
            try self.show();
        } else if (std.mem.eql(u8, action, "hide")) {
            try self.hide();
        } else if (std.mem.eql(u8, action, "toggle")) {
            try self.toggle();
        } else if (std.mem.eql(u8, action, "focus")) {
            try self.focus();
        } else if (std.mem.eql(u8, action, "minimize")) {
            try self.minimize();
        } else if (std.mem.eql(u8, action, "maximize")) {
            try self.maximize();
        } else if (std.mem.eql(u8, action, "close")) {
            try self.close();
        } else if (std.mem.eql(u8, action, "center")) {
            try self.center();
        } else if (std.mem.eql(u8, action, "toggleFullscreen")) {
            try self.toggleFullscreen();
        } else if (std.mem.eql(u8, action, "setFullscreen")) {
            try self.setFullscreen(data);
        } else if (std.mem.eql(u8, action, "setSize")) {
            try self.setSize(data);
        } else if (std.mem.eql(u8, action, "setPosition")) {
            try self.setPosition(data);
        } else if (std.mem.eql(u8, action, "setTitle")) {
            try self.setTitle(data);
        } else if (std.mem.eql(u8, action, "reload")) {
            try self.reload();
        } else {
            std.debug.print("[WindowBridge] Unknown action: {s}\n", .{action});
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

    fn focus(self: *Self) !void {
        if (self.window_handle == null) return;

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            // makeKeyAndOrderFront focuses the window
            macos.showWindow(self.window_handle.?);
        }
    }

    fn maximize(self: *Self) !void {
        if (self.window_handle == null) return;

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            // On macOS, "zoom" is the maximize equivalent
            macos.msgSendVoid0(self.window_handle.?, "zoom:");
        }
    }

    fn center(self: *Self) !void {
        if (self.window_handle == null) return;

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            macos.msgSendVoid0(self.window_handle.?, "center");
        }
    }

    fn toggleFullscreen(self: *Self) !void {
        if (self.window_handle == null) return;

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            macos.toggleFullscreen(self.window_handle.?);
        }
    }

    fn setFullscreen(self: *Self, data: ?[]const u8) !void {
        if (self.window_handle == null) return;
        _ = data; // TODO: Parse fullscreen boolean from data

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            macos.toggleFullscreen(self.window_handle.?);
        }
    }

    fn setSize(self: *Self, data: ?[]const u8) !void {
        if (self.window_handle == null) return;
        _ = data;

        // TODO: setWindowSize has a bug in macos.zig with @bitCast
        // For now, just log the request
        std.debug.print("[WindowBridge] setSize requested (not yet implemented)\n", .{});
    }

    fn setPosition(self: *Self, data: ?[]const u8) !void {
        if (self.window_handle == null) return;

        if (data) |json_data| {
            var x: i32 = 100;
            var y: i32 = 100;

            if (std.mem.indexOf(u8, json_data, "\"x\":")) |idx| {
                const start = idx + 4;
                var end = start;
                while (end < json_data.len and ((json_data[end] >= '0' and json_data[end] <= '9') or json_data[end] == '-')) : (end += 1) {}
                if (end > start) {
                    x = std.fmt.parseInt(i32, json_data[start..end], 10) catch 100;
                }
            }

            if (std.mem.indexOf(u8, json_data, "\"y\":")) |idx| {
                const start = idx + 4;
                var end = start;
                while (end < json_data.len and ((json_data[end] >= '0' and json_data[end] <= '9') or json_data[end] == '-')) : (end += 1) {}
                if (end > start) {
                    y = std.fmt.parseInt(i32, json_data[start..end], 10) catch 100;
                }
            }

            if (builtin.os.tag == .macos) {
                const macos = @import("macos.zig");
                macos.setWindowPosition(self.window_handle.?, x, y);
            }
        }
    }

    fn setTitle(self: *Self, data: ?[]const u8) !void {
        if (self.window_handle == null) return;

        if (data) |json_data| {
            // Extract title from {"title": "..."}
            if (std.mem.indexOf(u8, json_data, "\"title\":\"")) |idx| {
                const start = idx + 9;
                if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                    const title = json_data[start..end];

                    if (builtin.os.tag == .macos) {
                        const macos = @import("macos.zig");
                        const title_cstr = try self.allocator.dupeZ(u8, title);
                        defer self.allocator.free(title_cstr);

                        const NSString = macos.getClass("NSString");
                        const str_alloc = macos.msgSend0(NSString, "alloc");
                        const ns_title = macos.msgSend1(str_alloc, "initWithUTF8String:", title_cstr.ptr);
                        _ = macos.msgSend1(self.window_handle.?, "setTitle:", ns_title);
                    }
                }
            }
        }
    }

    fn reload(self: *Self) !void {
        if (self.webview_handle == null) {
            std.debug.print("[WindowBridge] No webview handle for reload\n", .{});
            return;
        }

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            macos.reloadWindow(self.webview_handle.?);
        }
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};
