const std = @import("std");
const macos = @import("../macos.zig");

/// Floating Liquid Glass Sidebar Container (Tahoe style)
/// Content extends full-width, sidebar floats on top with translucent glass
pub const ManualSplitView = struct {
    container_view: macos.objc.id, // Main container that holds everything
    glass_sidebar_view: ?macos.objc.id, // The NSVisualEffectView with Liquid Glass
    sidebar_content_view: ?macos.objc.id, // The actual sidebar content (goes inside glass view)
    content_view: ?macos.objc.id,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*ManualSplitView {
        const self = try allocator.create(ManualSplitView);
        errdefer allocator.destroy(self);

        // Create a plain NSView as container (NOT NSSplitView)
        const NSView = macos.getClass("NSView");
        const container_view = macos.msgSend0(macos.msgSend0(NSView, "alloc"), "init");

        // CRITICAL: Set autoresizing mask so container resizes with window
        // NSViewWidthSizable = 2, NSViewHeightSizable = 16
        const autoresizing_mask: c_ulong = 2 | 16;
        _ = macos.msgSend1(container_view, "setAutoresizingMask:", autoresizing_mask);

        self.* = .{
            .container_view = container_view,
            .glass_sidebar_view = null,
            .sidebar_content_view = null,
            .content_view = null,
            .allocator = allocator,
        };

        return self;
    }

    pub fn deinit(self: *ManualSplitView) void {
        self.allocator.destroy(self);
    }

    /// Get the container view (to set as window content view)
    pub fn getSplitView(self: *ManualSplitView) macos.objc.id {
        return self.container_view;
    }

    /// Add content view - THIS GOES FIRST (full-width background)
    pub fn addContent(self: *ManualSplitView, content_view: macos.objc.id) void {
        self.content_view = content_view;

        // Add content as first subview (will be behind sidebar)
        _ = macos.msgSend1(self.container_view, "addSubview:", content_view);

        std.debug.print("[FloatingSidebar] ✓ Added full-width content view\n", .{});
    }

    /// Add floating sidebar with Liquid Glass - THIS GOES ON TOP
    pub fn addSidebar(self: *ManualSplitView, sidebar_view: macos.objc.id) void {
        // CRITICAL: Create Liquid Glass visual effect view as floating sidebar
        const NSVisualEffectView = macos.getClass("NSVisualEffectView");
        const glass_view = macos.msgSend0(macos.msgSend0(NSVisualEffectView, "alloc"), "init");

        // Set material to .sidebar (NSVisualEffectMaterialSidebar = 5)
        _ = macos.msgSend1(glass_view, "setMaterial:", @as(c_long, 5));

        // CRITICAL: Set blending mode to .withinWindow (1) so sidebar blurs content BEHIND it
        _ = macos.msgSend1(glass_view, "setBlendingMode:", @as(c_long, 1));

        // Set state to .active (NSVisualEffectStateActive = 1) to always show effect
        _ = macos.msgSend1(glass_view, "setState:", @as(c_long, 1));

        // Add rounded corners for modern floating appearance
        _ = macos.msgSend1(glass_view, "setWantsLayer:", @as(c_int, 1)); // YES
        const layer = macos.msgSend0(glass_view, "layer");
        _ = macos.msgSend1(layer, "setCornerRadius:", @as(f64, 10.0));
        _ = macos.msgSend1(layer, "setMasksToBounds:", @as(c_int, 1)); // YES

        // Add the sidebar content as a subview of the glass view
        _ = macos.msgSend1(glass_view, "addSubview:", sidebar_view);

        // Add the floating glass sidebar to container (on top of content)
        _ = macos.msgSend1(self.container_view, "addSubview:", glass_view);

        // Store both views
        self.glass_sidebar_view = glass_view;
        self.sidebar_content_view = sidebar_view;

        std.debug.print("[FloatingSidebar] ✓ Added floating Liquid Glass sidebar\n", .{});
    }

    /// Set the frame and layout floating sidebar with proper insets
    pub fn setFrame(self: *ManualSplitView, frame: macos.NSRect) void {
        const msgSendSetFrame = @as(*const fn (macos.objc.id, macos.objc.SEL, macos.NSRect) callconv(.c) void, @ptrCast(&macos.objc.objc_msgSend));
        msgSendSetFrame(self.container_view, macos.sel("setFrame:"), frame);

        // CRITICAL: Content view extends FULL WIDTH (background layer)
        if (self.content_view) |content| {
            const content_frame = macos.NSRect{
                .origin = .{ .x = 0, .y = 0 },
                .size = .{ .width = frame.size.width, .height = frame.size.height },
            };
            msgSendSetFrame(content, macos.sel("setFrame:"), content_frame);
        }

        // CRITICAL: Floating glass sidebar on top with insets (Tahoe style)
        if (self.glass_sidebar_view) |glass_view| {
            // Sidebar dimensions and insets
            const sidebar_width: f64 = 260.0; // Slightly wider for modern look
            const top_inset: f64 = 0.0; // NO top margin - sidebar extends to very top (traffic lights float on top)
            const left_inset: f64 = 12.0; // Left margin
            const bottom_inset: f64 = 12.0; // Bottom margin

            const sidebar_frame = macos.NSRect{
                .origin = .{ .x = left_inset, .y = bottom_inset },
                .size = .{ .width = sidebar_width, .height = frame.size.height - top_inset - bottom_inset },
            };
            msgSendSetFrame(glass_view, macos.sel("setFrame:"), sidebar_frame);

            // Layout the sidebar content to fill the glass view (with padding)
            if (self.sidebar_content_view) |content| {
                const content_frame = macos.NSRect{
                    .origin = .{ .x = 0, .y = 0 },
                    .size = .{ .width = sidebar_width, .height = frame.size.height - top_inset - bottom_inset },
                };
                msgSendSetFrame(content, macos.sel("setFrame:"), content_frame);
            }
        }

        std.debug.print("[FloatingSidebar] ✓ Laid out floating sidebar over full-width content\n", .{});
    }

    /// Force the container to layout its subviews
    pub fn layoutSubviews(self: *ManualSplitView) void {
        _ = macos.msgSend1(self.container_view, "setNeedsLayout:", @as(c_int, 1)); // YES
        _ = macos.msgSend0(self.container_view, "layoutSubtreeIfNeeded");
    }
};
