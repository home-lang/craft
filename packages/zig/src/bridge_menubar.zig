const std = @import("std");
const builtin = @import("builtin");
const logging = @import("logging.zig");
const menubar_collapse = @import("menubar_collapse.zig");

const log = logging.menu;

/// Bridge for JavaScript ↔ native menu bar collapse management.
/// Receives messages from the webview and delegates to menubar_collapse.zig.
pub const MenubarCollapseBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        _ = self;

        if (std.mem.eql(u8, action, "init")) {
            menubar_collapse.init();
        } else if (std.mem.eql(u8, action, "collapse")) {
            menubar_collapse.collapse();
        } else if (std.mem.eql(u8, action, "expand")) {
            menubar_collapse.expand();
        } else if (std.mem.eql(u8, action, "toggle")) {
            menubar_collapse.toggle();
        } else if (std.mem.eql(u8, action, "getState")) {
            // Return current state via JS callback
            const collapsed = menubar_collapse.isCollapsed();
            const initialized = menubar_collapse.isInitialized();
            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf, "window.__craftBridgeResult('menubarCollapse:getState',{{collapsed:{s},initialized:{s}}});", .{
                if (collapsed) "true" else "false",
                if (initialized) "true" else "false",
            }) catch return;
            const macos = @import("macos.zig");
            macos.tryEvalJS(js) catch {};
        } else if (std.mem.eql(u8, action, "setAutoCollapse")) {
            // Parse delay from data (seconds as string)
            if (data.len > 0) {
                const delay = std.fmt.parseInt(u32, data, 10) catch 0;
                menubar_collapse.setAutoCollapse(delay);
            }
        } else if (std.mem.eql(u8, action, "poll")) {
            // Periodic check for auto-collapse timer
            menubar_collapse.checkAutoCollapse();
        } else {
            log.debug("Unknown menubarCollapse action: {s}", .{action});
        }
    }
};
