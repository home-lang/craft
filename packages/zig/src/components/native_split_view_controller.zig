const std = @import("std");
const macos = @import("../macos.zig");
const ViewControllerWrapper = @import("view_controller_wrapper.zig").ViewControllerWrapper;

/// Wrapper for NSSplitViewController with native macOS sidebar support
/// Provides Liquid Glass material, floating sidebar, and background extension effects
pub const NativeSplitViewController = struct {
    split_view_controller: macos.objc.id,
    split_view: macos.objc.id,
    sidebar_item: ?macos.objc.id,
    content_item: ?macos.objc.id,
    sidebar_view_controller: ?*ViewControllerWrapper,
    content_view_controller: ?*ViewControllerWrapper,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*NativeSplitViewController {
        const self = try allocator.create(NativeSplitViewController);
        errdefer allocator.destroy(self);

        // Create NSSplitViewController
        const NSSplitViewController = macos.getClass("NSSplitViewController");
        const split_view_controller = macos.msgSend0(macos.msgSend0(NSSplitViewController, "alloc"), "init");

        // Get the split view
        const split_view = macos.msgSend0(split_view_controller, "splitView");

        // Configure split view
        _ = macos.msgSend1(split_view, "setVertical:", @as(c_int, 1)); // YES - horizontal split (sidebar on left)
        _ = macos.msgSend1(split_view, "setDividerStyle:", @as(c_long, 1)); // NSSplitViewDividerStyleThin

        // Set autosave name for split position persistence
        const autosaveName = macos.createNSString("CraftMainSplitView");
        _ = macos.msgSend1(split_view, "setAutosaveName:", autosaveName);

        self.* = .{
            .split_view_controller = split_view_controller,
            .split_view = split_view,
            .sidebar_item = null,
            .content_item = null,
            .sidebar_view_controller = null,
            .content_view_controller = null,
            .allocator = allocator,
        };

        return self;
    }

    pub fn deinit(self: *NativeSplitViewController) void {
        if (self.sidebar_view_controller) |vc| vc.deinit();
        if (self.content_view_controller) |vc| vc.deinit();
        self.allocator.destroy(self);
    }

    /// Get the split view controller (to set as window content view controller)
    pub fn getSplitViewController(self: *NativeSplitViewController) macos.objc.id {
        return self.split_view_controller;
    }

    /// Get the split view itself
    pub fn getSplitView(self: *NativeSplitViewController) macos.objc.id {
        return self.split_view;
    }

    /// Add a sidebar with native Liquid Glass material
    /// This creates a floating glass sidebar with proper insets
    pub fn setSidebar(self: *NativeSplitViewController, sidebar_view: macos.objc.id) !void {
        // Wrap the sidebar view in a view controller
        const view_controller_wrapper = try ViewControllerWrapper.init(self.allocator, sidebar_view);
        self.sidebar_view_controller = view_controller_wrapper;

        // Create NSSplitViewItem with sidebar behavior
        const NSSplitViewItem = macos.getClass("NSSplitViewItem");

        // Create split view item with the view controller
        const sidebar_item = macos.msgSend1(
            NSSplitViewItem,
            "splitViewItemWithViewController:",
            view_controller_wrapper.getViewController()
        );

        // CRITICAL: Set behavior to .sidebar for Liquid Glass material
        // NSSplitViewItemBehaviorSidebar = 1
        _ = macos.msgSend1(sidebar_item, "setBehavior:", @as(c_long, 1));

        // Configure sidebar constraints BEFORE adding to split view
        _ = macos.msgSend1(sidebar_item, "setCanCollapse:", @as(c_int, 0)); // NO - don't allow collapse
        _ = macos.msgSend1(sidebar_item, "setMinimumThickness:", @as(f64, 240.0));
        _ = macos.msgSend1(sidebar_item, "setMaximumThickness:", @as(f64, 350.0));

        // CRITICAL: Set holding priority to prevent compression to zero width
        // Use 751 (higher than NSLayoutPriorityDefaultHigh = 750) to ensure visibility
        _ = macos.msgSend1(sidebar_item, "setHoldingPriority:", @as(f32, 751.0));

        // CRITICAL: Enable full-height layout for modern sidebar appearance
        _ = macos.msgSend1(sidebar_item, "setAllowsFullHeightLayout:", @as(c_int, 1)); // YES

        // Add sidebar item to split view controller
        _ = macos.msgSend1(self.split_view_controller, "addSplitViewItem:", sidebar_item);

        // CRITICAL: Explicitly uncollapse AFTER adding to split view
        _ = macos.msgSend1(sidebar_item, "setCollapsed:", @as(c_int, 0)); // NO - not collapsed

        self.sidebar_item = sidebar_item;

        // Debug: Log split view item configuration and view frames
        const collapsed = macos.msgSend0(sidebar_item, "isCollapsed");

        // Get the sidebar view controller's view frame
        const sidebar_vc = view_controller_wrapper.getViewController();
        const sidebar_vc_view = macos.msgSend0(sidebar_vc, "view");

        // Properly read the frame using direct objc_msgSend (ARM64 handles structs directly)
        const msgSendFrame = @as(*const fn (macos.objc.id, macos.objc.SEL) callconv(.c) macos.NSRect, @ptrCast(&macos.objc.objc_msgSend));
        const sidebar_frame = msgSendFrame(sidebar_vc_view, macos.sel("frame"));

        // Get split view frame for comparison
        const split_view_frame = msgSendFrame(self.split_view, macos.sel("frame"));

        std.debug.print("[SplitViewController] ========== SIDEBAR DIAGNOSTICS ==========\\n", .{});
        std.debug.print("[SplitViewController] Sidebar collapsed: {*}\\n", .{collapsed});
        std.debug.print("[SplitViewController] Sidebar view: {*}\\n", .{sidebar_vc_view});
        std.debug.print("[SplitViewController] Sidebar frame: origin=({d:.1}, {d:.1}) size=({d:.1}x{d:.1})\\n", .{
            sidebar_frame.origin.x,
            sidebar_frame.origin.y,
            sidebar_frame.size.width,
            sidebar_frame.size.height,
        });
        std.debug.print("[SplitViewController] Split view frame: origin=({d:.1}, {d:.1}) size=({d:.1}x{d:.1})\\n", .{
            split_view_frame.origin.x,
            split_view_frame.origin.y,
            split_view_frame.size.width,
            split_view_frame.size.height,
        });

        // Check if sidebar has zero width (the smoking gun!)
        if (sidebar_frame.size.width == 0) {
            std.debug.print("[SplitViewController] ⚠️  WARNING: Sidebar has ZERO width!\\n", .{});
        }
        if (sidebar_frame.size.height == 0) {
            std.debug.print("[SplitViewController] ⚠️  WARNING: Sidebar has ZERO height!\\n", .{});
        }

        std.debug.print("[SplitViewController] ===========================================\\n", .{});
    }

    /// Set the content view (typically a WKWebView)
    /// Enables background extension effect to extend beneath sidebar
    pub fn setContent(self: *NativeSplitViewController, content_view: macos.objc.id) !void {
        // Wrap the content view in a view controller
        const view_controller_wrapper = try ViewControllerWrapper.init(self.allocator, content_view);
        self.content_view_controller = view_controller_wrapper;

        // Create NSSplitViewItem with content behavior
        const NSSplitViewItem = macos.getClass("NSSplitViewItem");

        const content_item = macos.msgSend1(
            NSSplitViewItem,
            "splitViewItemWithViewController:",
            view_controller_wrapper.getViewController()
        );

        // Set behavior to .contentList for main content area
        // NSSplitViewItemBehaviorContentList = 3
        _ = macos.msgSend1(content_item, "setBehavior:", @as(c_long, 3));

        // CRITICAL: Enable automatic safe area adjustment for background extension
        // This allows content to extend beneath the sidebar with blur effect
        _ = macos.msgSend1(content_item, "setAutomaticallyAdjustsSafeAreaInsets:", @as(c_int, 1)); // YES

        // Content should not collapse
        _ = macos.msgSend1(content_item, "setCanCollapse:", @as(c_int, 0)); // NO

        // CRITICAL: Set LOWER holding priority for content so sidebar gets its space first
        // Use 250 (NSLayoutPriorityDefaultLow) so content compresses before sidebar
        _ = macos.msgSend1(content_item, "setHoldingPriority:", @as(f32, 250.0));

        // Add content item to split view controller
        _ = macos.msgSend1(self.split_view_controller, "addSplitViewItem:", content_item);

        self.content_item = content_item;

        std.debug.print("[SplitViewController] Content added with background extension enabled\\n", .{});

        // CRITICAL FIX: After both items are added, force the split view to respect constraints
        // This is necessary because the split view might not properly layout until told to do so
        if (self.sidebar_item) |sidebar_item| {
            // Re-enforce sidebar minimum thickness after content is added
            _ = macos.msgSend1(sidebar_item, "setMinimumThickness:", @as(f64, 240.0));

            // Force the split view to layout with proper divider position
            // Set initial position to 240px for sidebar
            const sidebar_width: f64 = 240.0;
            _ = macos.msgSend2(
                self.split_view,
                "setPosition:ofDividerAtIndex:",
                sidebar_width,
                @as(c_long, 0)
            );

            std.debug.print("[SplitViewController] ✓ Forced split view divider to position: {d}px\\n", .{sidebar_width});
        }
    }

    /// Get the root view of the split view controller (for setting as window content view)
    pub fn getView(self: *NativeSplitViewController) macos.objc.id {
        return macos.msgSend0(self.split_view_controller, "view");
    }

    /// Force set divider position AFTER layout (must be called after split view is in window hierarchy)
    pub fn setDividerPosition(self: *NativeSplitViewController, position: f64) void {
        // Re-enforce sidebar minimum thickness before setting position
        if (self.sidebar_item) |sidebar_item| {
            _ = macos.msgSend1(sidebar_item, "setMinimumThickness:", @as(f64, 240.0));
        }

        // Force divider to exact position
        _ = macos.msgSend2(
            self.split_view,
            "setPosition:ofDividerAtIndex:",
            position,
            @as(c_long, 0)
        );

        std.debug.print("[SplitViewController] ✓ Set divider position to {d}px\n", .{position});
    }
};
