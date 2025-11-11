const std = @import("std");
const macos = @import("../macos.zig");
const OutlineViewDataSource = @import("outline_view_datasource.zig").OutlineViewDataSource;
const OutlineViewDelegate = @import("outline_view_delegate.zig").OutlineViewDelegate;

/// High-level wrapper for NSOutlineView-based sidebar
/// Integrates data source and delegate into a complete component
pub const NativeSidebar = struct {
    outline_view: macos.objc.id,
    scroll_view: macos.objc.id,
    data_source: OutlineViewDataSource,
    delegate: OutlineViewDelegate,
    allocator: std.mem.Allocator,

    pub const SidebarSection = struct {
        id: []const u8,
        header: ?[]const u8,
        items: []const SidebarItem,
    };

    pub const SidebarItem = struct {
        id: []const u8,
        label: []const u8,
        icon: ?[]const u8 = null,
        badge: ?[]const u8 = null,
    };

    pub fn init(allocator: std.mem.Allocator) !*NativeSidebar {
        const self = try allocator.create(NativeSidebar);
        errdefer allocator.destroy(self);

        // Create data source and delegate
        var data_source = try OutlineViewDataSource.init(allocator);
        errdefer data_source.deinit();

        var delegate = try OutlineViewDelegate.init(allocator);
        errdefer delegate.deinit();

        // Create NSOutlineView
        const NSOutlineView = macos.getClass("NSOutlineView");
        const outline_view = macos.msgSend0(macos.msgSend0(NSOutlineView, "alloc"), "init");

        // Configure outline view
        _ = macos.msgSend1(outline_view, "setDataSource:", data_source.getInstance());
        _ = macos.msgSend1(outline_view, "setDelegate:", delegate.getInstance());

        // Add single column for the outline view
        const NSTableColumn = macos.getClass("NSTableColumn");
        const column = macos.msgSend0(macos.msgSend0(NSTableColumn, "alloc"), "init");

        const identifier = macos.createNSString("MainColumn");
        _ = macos.msgSend1(column, "setIdentifier:", identifier);
        _ = macos.msgSend1(column, "setWidth:", @as(f64, 240.0));
        _ = macos.msgSend1(outline_view, "addTableColumn:", column);
        _ = macos.msgSend1(outline_view, "setOutlineTableColumn:", column);

        // Configure appearance
        _ = macos.msgSend1(outline_view, "setHeaderView:", @as(?*anyopaque, null));
        _ = macos.msgSend1(outline_view, "setRowSizeStyle:", @as(c_long, 1)); // NSTableViewRowSizeStyleDefault
        _ = macos.msgSend1(outline_view, "setSelectionHighlightStyle:", @as(c_long, 1)); // NSTableViewSelectionHighlightStyleSourceList
        _ = macos.msgSend1(outline_view, "setFloatsGroupRows:", @as(c_int, 0));
        _ = macos.msgSend1(outline_view, "setIndentationPerLevel:", @as(f64, 0.0)); // No indentation

        // Create NSScrollView to wrap the outline view
        const NSScrollView = macos.getClass("NSScrollView");
        const scroll_view = macos.msgSend0(macos.msgSend0(NSScrollView, "alloc"), "init");

        _ = macos.msgSend1(scroll_view, "setDocumentView:", outline_view);
        _ = macos.msgSend1(scroll_view, "setHasVerticalScroller:", @as(c_int, 1));
        _ = macos.msgSend1(scroll_view, "setHasHorizontalScroller:", @as(c_int, 0));
        _ = macos.msgSend1(scroll_view, "setBorderType:", @as(c_long, 0)); // NSNoBorder

        // Set background color to match macOS sidebar
        const NSColor = macos.getClass("NSColor");
        const bgColor = macos.msgSend0(NSColor, "controlBackgroundColor");
        _ = macos.msgSend1(outline_view, "setBackgroundColor:", bgColor);

        self.* = .{
            .outline_view = outline_view,
            .scroll_view = scroll_view,
            .data_source = data_source,
            .delegate = delegate,
            .allocator = allocator,
        };

        return self;
    }

    pub fn deinit(self: *NativeSidebar) void {
        self.delegate.deinit();
        self.data_source.deinit();
        self.allocator.destroy(self);
    }

    /// Get the scroll view (top-level view to add to window)
    pub fn getView(self: *NativeSidebar) macos.objc.id {
        return self.scroll_view;
    }

    /// Add a section to the sidebar
    pub fn addSection(self: *NativeSidebar, section: SidebarSection) !void {
        var new_section = OutlineViewDataSource.DataStore.Section{
            .id = try self.allocator.dupe(u8, section.id),
            .header = if (section.header) |h| try self.allocator.dupe(u8, h) else null,
            .items = std.ArrayList(OutlineViewDataSource.DataStore.Section.Item).init(self.allocator),
            .is_expanded = true,
        };

        // Add items to section
        for (section.items) |item| {
            const new_item = OutlineViewDataSource.DataStore.Section.Item{
                .id = try self.allocator.dupe(u8, item.id),
                .label = try self.allocator.dupe(u8, item.label),
                .icon = if (item.icon) |icon| try self.allocator.dupe(u8, icon) else null,
                .badge = if (item.badge) |badge| try self.allocator.dupe(u8, badge) else null,
            };
            try new_section.items.append(new_item);
        }

        try self.data_source.data.sections.append(new_section);

        // Reload data
        _ = macos.msgSend0(self.outline_view, "reloadData");

        // Expand all sections by default
        const section_count = self.data_source.data.sections.items.len;
        if (section_count > 0) {
            const last_section = &self.data_source.data.sections.items[section_count - 1];
            const section_ptr = @intFromPtr(@as(*const anyopaque, @ptrCast(last_section)));
            const item_id = @as(macos.objc.id, @intFromPtr(section_ptr));
            _ = macos.msgSend1(self.outline_view, "expandItem:", item_id);
        }
    }

    /// Set the selected item programmatically
    pub fn setSelectedItem(self: *NativeSidebar, item_id: []const u8) void {
        // Find the item in the data structure
        var row_index: c_long = 0;

        for (self.data_source.data.sections.items) |*section| {
            row_index += 1; // Section itself takes a row

            for (section.items.items) |*item| {
                if (std.mem.eql(u8, item.id, item_id)) {
                    // Select this row
                    _ = macos.msgSend1(self.outline_view, "selectRowIndexes:byExtendingSelection:", row_index);
                    return;
                }
                row_index += 1;
            }
        }
    }

    /// Register callback for selection events
    pub fn setOnSelectCallback(self: *NativeSidebar, callback: *const fn (item_id: []const u8) void) void {
        self.delegate.setOnSelectCallback(callback);
    }

    /// Set frame for the sidebar view
    pub fn setFrame(self: *NativeSidebar, x: f64, y: f64, width: f64, height: f64) void {
        const NSRect = extern struct {
            origin: extern struct { x: f64, y: f64 },
            size: extern struct { width: f64, height: f64 },
        };

        const frame = NSRect{
            .origin = .{ .x = x, .y = y },
            .size = .{ .width = width, .height = height },
        };

        _ = macos.msgSend1(self.scroll_view, "setFrame:", frame);
    }

    /// Set Auto Layout constraints (alternative to setFrame)
    pub fn setAutoresizingMask(self: *NativeSidebar, mask: c_ulong) void {
        _ = macos.msgSend1(self.scroll_view, "setAutoresizingMask:", mask);
    }
};
