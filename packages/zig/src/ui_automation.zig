const std = @import("std");
const macos = @import("macos.zig");

/// UI Automation framework for E2E testing using macOS Accessibility APIs
/// Similar to Playwright but for native macOS UI
pub const UIAutomation = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) UIAutomation {
        return .{ .allocator = allocator };
    }

    /// Find a button by its title/label
    pub fn findButton(self: *UIAutomation, window: macos.objc.id, button_title: []const u8) ?macos.objc.id {
        _ = self;

        // Get the window's content view
        const content_view = macos.msgSend0(window, "contentView");

        // Search for button recursively in view hierarchy
        const button_title_ns = macos.createNSString(button_title);
        return findButtonRecursive(content_view, button_title_ns);
    }

    fn findButtonRecursive(view: macos.objc.id, target_title: macos.objc.id) ?macos.objc.id {
        // Check if this view is a button with matching title
        const view_class = macos.msgSend0(view, "class");
        const class_name = macos.msgSend0(view_class, "description");

        // Get UTF8 string from NSString
        const utf8_cstr = macos.msgSend0(class_name, "UTF8String");
        if (utf8_cstr != @as(?*const u8, null)) {
            const class_str = std.mem.span(@as([*:0]const u8, @ptrCast(utf8_cstr)));

            // Check if it's a button
            if (std.mem.indexOf(u8, class_str, "Button") != null) {
                // Check if title matches
                const title = macos.msgSend0(view, "title");
                if (title != @as(macos.objc.id, null)) {
                    const is_equal = macos.msgSend1(title, "isEqualToString:", target_title);
                    if (@intFromPtr(is_equal) == 1) {
                        return view;
                    }
                }
            }
        }

        // Recursively search subviews
        const subviews = macos.msgSend0(view, "subviews");
        if (subviews == @as(macos.objc.id, null)) return null;

        const count = macos.msgSend0(subviews, "count");
        const count_val = @intFromPtr(count);

        var i: usize = 0;
        while (i < count_val) : (i += 1) {
            const subview = macos.msgSend1(subviews, "objectAtIndex:", @as(c_ulong, @intCast(i)));
            if (findButtonRecursive(subview, target_title)) |button| {
                return button;
            }
        }

        return null;
    }

    /// Click a button programmatically
    pub fn clickButton(self: *UIAutomation, button: macos.objc.id) void {
        _ = self;

        std.debug.print("[UIAutomation] Clicking button programmatically\n", .{});

        // Simulate button click by calling performClick:
        _ = macos.msgSend1(button, "performClick:", @as(?*anyopaque, null));

        std.debug.print("[UIAutomation] ✓ Button clicked\n", .{});
    }

    /// Check if a view is visible on screen
    pub fn isViewVisible(self: *UIAutomation, view: macos.objc.id) bool {
        _ = self;

        // Check if view has non-zero frame
        const msgSendFrame = @as(*const fn (macos.objc.id, macos.objc.SEL) callconv(.c) macos.NSRect, @ptrCast(&macos.objc.objc_msgSend));
        const frame = msgSendFrame(view, macos.sel("frame"));

        if (frame.size.width == 0 or frame.size.height == 0) {
            std.debug.print("[UIAutomation] View has zero size: {d}x{d}\n", .{ frame.size.width, frame.size.height });
            return false;
        }

        // Check if view is in window hierarchy
        const window = macos.msgSend0(view, "window");
        if (window == @as(macos.objc.id, null)) {
            std.debug.print("[UIAutomation] View is not in window hierarchy\n", .{});
            return false;
        }

        // Check if view is hidden
        const is_hidden = macos.msgSend0(view, "isHidden");
        if (@intFromPtr(is_hidden) == 1) {
            std.debug.print("[UIAutomation] View is hidden\n", .{});
            return false;
        }

        std.debug.print("[UIAutomation] ✓ View is visible: {d}x{d}\n", .{ frame.size.width, frame.size.height });
        return true;
    }

    /// Wait for a condition with timeout (in milliseconds)
    pub fn waitFor(self: *UIAutomation, condition_fn: *const fn () bool, timeout_ms: u64) bool {
        _ = self;

        const start_time = std.time.milliTimestamp();
        const timeout = @as(i64, @intCast(timeout_ms));

        while (true) {
            if (condition_fn()) {
                return true;
            }

            const elapsed = std.time.milliTimestamp() - start_time;
            if (elapsed >= timeout) {
                return false;
            }

            // Sleep for 50ms before checking again
            std.time.sleep(50 * std.time.ns_per_ms);
        }
    }

    /// Execute JavaScript in the webview and get result
    pub fn executeScript(self: *UIAutomation, webview: macos.objc.id, script: []const u8) void {
        _ = self;

        const script_ns = macos.createNSString(script);
        _ = macos.msgSend2(webview, "evaluateJavaScript:completionHandler:", script_ns, @as(?*anyopaque, null));

        std.debug.print("[UIAutomation] Executed script: {s}\n", .{script});
    }

    /// Get all split view panes
    pub fn getSplitViewPanes(self: *UIAutomation, split_view: macos.objc.id) !std.ArrayList(macos.objc.id) {
        var panes = std.ArrayList(macos.objc.id).init(self.allocator);

        const subviews = macos.msgSend0(split_view, "subviews");
        if (subviews == @as(macos.objc.id, null)) return panes;

        const count = macos.msgSend0(subviews, "count");
        const count_val = @intFromPtr(count);

        var i: usize = 0;
        while (i < count_val) : (i += 1) {
            const pane = macos.msgSend1(subviews, "objectAtIndex:", @as(c_ulong, @intCast(i)));
            try panes.append(pane);
        }

        return panes;
    }

    /// Verify sidebar is visible by checking split view panes
    pub fn verifySidebarVisible(self: *UIAutomation, split_view: macos.objc.id) !bool {
        const panes = try self.getSplitViewPanes(split_view);
        defer panes.deinit();

        if (panes.items.len < 2) {
            std.debug.print("[UIAutomation] ❌ Split view has less than 2 panes\n", .{});
            return false;
        }

        // Check if first pane (sidebar) is visible
        const sidebar_pane = panes.items[0];
        const is_visible = self.isViewVisible(sidebar_pane);

        if (!is_visible) {
            std.debug.print("[UIAutomation] ❌ Sidebar pane is NOT visible\n", .{});
            return false;
        }

        std.debug.print("[UIAutomation] ✅ Sidebar pane IS visible\n", .{});
        return true;
    }
};
