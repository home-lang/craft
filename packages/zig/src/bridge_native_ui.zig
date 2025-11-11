const std = @import("std");
const macos = @import("macos.zig");
const NativeSidebar = @import("components/native_sidebar.zig").NativeSidebar;
const NativeFileBrowser = @import("components/native_file_browser.zig").NativeFileBrowser;
const NativeSplitView = @import("components/native_split_view.zig").NativeSplitView;

/// Bridge handler for native UI components
/// Routes messages from JavaScript to native AppKit components
pub const NativeUIBridge = struct {
    allocator: std.mem.Allocator,
    window: ?macos.objc.id,
    sidebars: std.StringHashMap(*NativeSidebar),
    file_browsers: std.StringHashMap(*NativeFileBrowser),
    split_views: std.StringHashMap(*NativeSplitView),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) NativeUIBridge {
        return .{
            .allocator = allocator,
            .window = null,
            .sidebars = std.StringHashMap(*NativeSidebar).init(allocator),
            .file_browsers = std.StringHashMap(*NativeFileBrowser).init(allocator),
            .split_views = std.StringHashMap(*NativeSplitView).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        // Clean up all sidebars
        var sidebar_iter = self.sidebars.iterator();
        while (sidebar_iter.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.sidebars.deinit();

        // Clean up all file browsers
        var browser_iter = self.file_browsers.iterator();
        while (browser_iter.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.file_browsers.deinit();

        // Clean up all split views
        var split_iter = self.split_views.iterator();
        while (split_iter.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.split_views.deinit();
    }

    pub fn setWindow(self: *Self, window: macos.objc.id) void {
        self.window = window;
    }

    /// Handle incoming messages from JavaScript
    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        _ = self; // TODO: Use self when implementing component creation
        _ = data; // TODO: Parse JSON data when needed

        if (std.mem.eql(u8, action, "createSidebar")) {
            std.debug.print("[NativeUI] createSidebar action received\n", .{});
            // TODO: Implement JSON parsing and sidebar creation
        } else if (std.mem.eql(u8, action, "createFileBrowser")) {
            std.debug.print("[NativeUI] createFileBrowser action received\n", .{});
            // TODO: Implement JSON parsing and file browser creation
        } else if (std.mem.eql(u8, action, "createSplitView")) {
            std.debug.print("[NativeUI] createSplitView action received\n", .{});
            // TODO: Implement JSON parsing and split view creation
        } else {
            std.debug.print("[NativeUI] Unknown action: {s}\n", .{action});
        }
    }
};
