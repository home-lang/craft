const std = @import("std");
const builtin = @import("builtin");

/// Bridge handler for app-level control messages from JavaScript
pub const AppBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    /// Handle app-related messages from JavaScript
    pub fn handleMessage(self: *Self, action: []const u8) !void {
        if (std.mem.eql(u8, action, "hideDockIcon")) {
            try self.hideDockIcon();
        } else if (std.mem.eql(u8, action, "showDockIcon")) {
            try self.showDockIcon();
        } else if (std.mem.eql(u8, action, "quit")) {
            try self.quit();
        } else if (std.mem.eql(u8, action, "getInfo")) {
            try self.getInfo();
        } else {
            std.debug.print("Unknown app action: {s}\n", .{action});
        }
    }

    fn hideDockIcon(self: *Self) !void {
        _ = self;
        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            const NSApplication = macos.getClass("NSApplication");
            const app = macos.msgSend0(NSApplication, "sharedApplication");

            // NSApplicationActivationPolicyAccessory = 1 (hides dock icon)
            const NSApplicationActivationPolicyAccessory: c_long = 1;
            _ = macos.msgSend1(app, "setActivationPolicy:", NSApplicationActivationPolicyAccessory);

            std.debug.print("[Bridge] Dock icon hidden\n", .{});
        }
    }

    fn showDockIcon(self: *Self) !void {
        _ = self;
        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            const NSApplication = macos.getClass("NSApplication");
            const app = macos.msgSend0(NSApplication, "sharedApplication");

            // NSApplicationActivationPolicyRegular = 0 (shows dock icon)
            const NSApplicationActivationPolicyRegular: c_long = 0;
            _ = macos.msgSend1(app, "setActivationPolicy:", NSApplicationActivationPolicyRegular);

            std.debug.print("[Bridge] Dock icon shown\n", .{});
        }
    }

    fn quit(self: *Self) !void {
        _ = self;
        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            const NSApplication = macos.getClass("NSApplication");
            const app = macos.msgSend0(NSApplication, "sharedApplication");
            macos.msgSendVoid0(app, "terminate:");
        } else {
            std.process.exit(0);
        }
    }

    fn getInfo(self: *Self) !void {
        _ = self;
        // This would return app info as JSON
        // For now, just log it
        std.debug.print("[Bridge] App info requested\n", .{});
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};
