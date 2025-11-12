const std = @import("std");
const macos = @import("macos.zig");

/// Test helper functions for E2E UI testing
pub const TestHelpers = struct {
    /// Check if a split view's sidebar pane is visible (non-zero width)
    pub fn isSidebarPaneVisible(split_view: macos.objc.id) bool {
        // Use regular subviews (for plain NSView container used in floating sidebar)
        const subviews = macos.msgSend0(split_view, "subviews");
        const count = macos.msgSend0(subviews, "count");
        const count_val = @intFromPtr(count);

        if (count_val < 2) {
            std.debug.print("[E2E Test] FAILED: Container has less than 2 subviews\n", .{});
            return false;
        }

        // Get the sidebar pane (first subview in floating architecture)
        const sidebar_pane = macos.msgSend1(subviews, "objectAtIndex:", @as(c_ulong, 0));

        // Get the frame using proper objc_msgSend for struct returns
        const msgSendFrame = @as(*const fn (macos.objc.id, macos.objc.SEL) callconv(.c) macos.NSRect, @ptrCast(&macos.objc.objc_msgSend));
        const sidebar_pane_frame = msgSendFrame(sidebar_pane, macos.sel("frame"));

        std.debug.print("[E2E Test] Sidebar pane frame: origin=({d:.1}, {d:.1}) size=({d:.1}x{d:.1})\n", .{
            sidebar_pane_frame.origin.x,
            sidebar_pane_frame.origin.y,
            sidebar_pane_frame.size.width,
            sidebar_pane_frame.size.height,
        });

        // Check if sidebar pane has non-zero width
        if (sidebar_pane_frame.size.width == 0) {
            std.debug.print("[E2E Test] FAILED: Sidebar pane has ZERO width\n", .{});
            return false;
        }

        if (sidebar_pane_frame.size.width < 200) {
            std.debug.print("[E2E Test] WARNING: Sidebar pane width ({d:.1}px) is less than minimum (200px)\n", .{sidebar_pane_frame.size.width});
            return false;
        }

        std.debug.print("[E2E Test] SUCCESS: Sidebar pane is visible with width {d:.1}px\n", .{sidebar_pane_frame.size.width});
        return true;
    }

    /// Get comprehensive diagnostics for a split view and its controller
    pub fn dumpSplitViewDiagnostics(split_view: macos.objc.id, window: macos.objc.id) void {
        const msgSendFrame = @as(*const fn (macos.objc.id, macos.objc.SEL) callconv(.c) macos.NSRect, @ptrCast(&macos.objc.objc_msgSend));

        // Get window frame
        const window_content_view = macos.msgSend0(window, "contentView");
        const window_frame = msgSendFrame(window_content_view, macos.sel("frame"));

        // Get split view frame
        const split_view_frame = msgSendFrame(split_view, macos.sel("frame"));

        std.debug.print("\n========== E2E TEST DIAGNOSTICS ==========\n", .{});
        std.debug.print("[E2E Test] Window content frame: ({d:.1}x{d:.1})\n", .{
            window_frame.size.width,
            window_frame.size.height,
        });
        std.debug.print("[E2E Test] Split view frame: ({d:.1}x{d:.1})\n", .{
            split_view_frame.size.width,
            split_view_frame.size.height,
        });

        // Get all subviews (includes dividers, etc)
        const subviews = macos.msgSend0(split_view, "subviews");
        const subview_count = macos.msgSend0(subviews, "count");
        const count_val = @intFromPtr(subview_count);
        std.debug.print("[E2E Test] Total subviews: {d}\n", .{count_val});

        // For floating sidebar: first subview is content (full-width), second is glass sidebar
        if (count_val >= 2) {
            const pane0 = macos.msgSend1(subviews, "objectAtIndex:", @as(c_ulong, 0));
            const pane1 = macos.msgSend1(subviews, "objectAtIndex:", @as(c_ulong, 1));

            const pane0_frame = msgSendFrame(pane0, macos.sel("frame"));
            const pane1_frame = msgSendFrame(pane1, macos.sel("frame"));

            std.debug.print("[E2E Test] Subview 0 (content - background) frame: origin=({d:.1}, {d:.1}) size=({d:.1}x{d:.1})\n", .{
                pane0_frame.origin.x,
                pane0_frame.origin.y,
                pane0_frame.size.width,
                pane0_frame.size.height,
            });
            std.debug.print("[E2E Test] Subview 1 (floating glass sidebar) frame: origin=({d:.1}, {d:.1}) size=({d:.1}x{d:.1})\n", .{
                pane1_frame.origin.x,
                pane1_frame.origin.y,
                pane1_frame.size.width,
                pane1_frame.size.height,
            });

            // Check basic visibility
            const pane0_hidden = @intFromPtr(macos.msgSend0(pane0, "isHidden"));
            const pane1_hidden = @intFromPtr(macos.msgSend0(pane1, "isHidden"));
            std.debug.print("[E2E Test] Pane 0 visibility: isHidden={d}\n", .{pane0_hidden});
            std.debug.print("[E2E Test] Pane 1 visibility: isHidden={d}\n", .{pane1_hidden});

            // Check for zero-width issues
            if (pane0_frame.size.width == 0) {
                std.debug.print("[E2E Test] ⚠️  CRITICAL: Sidebar pane has ZERO width!\n", .{});
            }
            if (pane0_frame.size.height == 0) {
                std.debug.print("[E2E Test] ⚠️  CRITICAL: Sidebar pane has ZERO height!\n", .{});
            }

            // CRITICAL CHECK: Are both panes at the same position in split view coordinates?
            if (pane0_frame.origin.x == pane1_frame.origin.x and pane0_frame.origin.y == pane1_frame.origin.y) {
                std.debug.print("[E2E Test] ⚠️  CRITICAL: PANES ARE OVERLAPPING - both at same origin!\n", .{});
                std.debug.print("[E2E Test] ⚠️  This means NSSplitView is NOT arranging panes side-by-side!\n", .{});
            }
        }

        std.debug.print("==========================================\n\n", .{});
    }

    /// Wait for layout to settle (simulates runloop iterations)
    pub fn waitForLayout() void {
        // Sleep for a short time to allow AppKit to process layout
        std.time.sleep(100 * std.time.ns_per_ms); // 100ms
    }
};
