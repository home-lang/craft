const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// ListView Component - Scrollable list of items
pub const ListView = struct {
    component: Component,
    items: std.ArrayList(ListItem),
    selected_indices: std.ArrayList(usize),
    selection_mode: SelectionMode,
    on_item_click: ?*const fn (usize) void,
    on_item_double_click: ?*const fn (usize) void,
    on_selection_change: ?*const fn ([]const usize) void,
    scroll_position: usize,
    visible_count: usize,
    item_height: u32,
    show_dividers: bool,
    show_icons: bool,

    pub const ListItem = struct {
        id: []const u8,
        text: []const u8,
        secondary_text: ?[]const u8 = null,
        icon: ?[]const u8 = null,
        data: ?*anyopaque = null,
        disabled: bool = false,
        selected: bool = false,
    };

    pub const SelectionMode = enum {
        none,
        single,
        multiple,
    };

    pub const Config = struct {
        selection_mode: SelectionMode = .single,
        item_height: u32 = 48,
        visible_count: usize = 10,
        show_dividers: bool = true,
        show_icons: bool = true,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps, config: Config) !*ListView {
        const list_view = try allocator.create(ListView);
        list_view.* = ListView{
            .component = try Component.init(allocator, "listview", props),
            .items = .{},
            .selected_indices = .{},
            .selection_mode = config.selection_mode,
            .on_item_click = null,
            .on_item_double_click = null,
            .on_selection_change = null,
            .scroll_position = 0,
            .visible_count = config.visible_count,
            .item_height = config.item_height,
            .show_dividers = config.show_dividers,
            .show_icons = config.show_icons,
        };
        return list_view;
    }

    pub fn deinit(self: *ListView) void {
        self.items.deinit(self.component.allocator);
        self.selected_indices.deinit(self.component.allocator);
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    /// Add an item to the list
    pub fn addItem(self: *ListView, item: ListItem) !void {
        try self.items.append(self.component.allocator, item);
    }

    /// Add a simple text item
    pub fn addTextItem(self: *ListView, id: []const u8, text: []const u8) !void {
        try self.items.append(self.component.allocator, .{
            .id = id,
            .text = text,
        });
    }

    /// Insert an item at a specific index
    pub fn insertItem(self: *ListView, index: usize, item: ListItem) !void {
        if (index <= self.items.items.len) {
            try self.items.insert(self.component.allocator, index, item);
            // Update selected indices
            for (self.selected_indices.items) |*idx| {
                if (idx.* >= index) {
                    idx.* += 1;
                }
            }
        }
    }

    /// Remove an item by index
    pub fn removeItem(self: *ListView, index: usize) void {
        if (index < self.items.items.len) {
            _ = self.items.orderedRemove(index);
            // Update selected indices
            var i: usize = 0;
            while (i < self.selected_indices.items.len) {
                if (self.selected_indices.items[i] == index) {
                    _ = self.selected_indices.orderedRemove(i);
                } else {
                    if (self.selected_indices.items[i] > index) {
                        self.selected_indices.items[i] -= 1;
                    }
                    i += 1;
                }
            }
        }
    }

    /// Remove an item by ID
    pub fn removeItemById(self: *ListView, id: []const u8) void {
        for (self.items.items, 0..) |item, i| {
            if (std.mem.eql(u8, item.id, id)) {
                self.removeItem(i);
                return;
            }
        }
    }

    /// Clear all items
    pub fn clearItems(self: *ListView) void {
        self.items.clearRetainingCapacity();
        self.selected_indices.clearRetainingCapacity();
        self.scroll_position = 0;
    }

    /// Select an item by index
    pub fn selectItem(self: *ListView, index: usize) void {
        if (index >= self.items.items.len) return;
        if (self.items.items[index].disabled) return;
        if (self.selection_mode == .none) return;

        if (self.selection_mode == .single) {
            // Clear previous selection
            for (self.selected_indices.items) |idx| {
                if (idx < self.items.items.len) {
                    self.items.items[idx].selected = false;
                }
            }
            self.selected_indices.clearRetainingCapacity();
        }

        // Check if already selected
        for (self.selected_indices.items) |idx| {
            if (idx == index) return;
        }

        self.items.items[index].selected = true;
        self.selected_indices.append(self.component.allocator, index) catch return;

        self.notifySelectionChange();
    }

    /// Deselect an item by index
    pub fn deselectItem(self: *ListView, index: usize) void {
        if (index >= self.items.items.len) return;

        self.items.items[index].selected = false;

        for (self.selected_indices.items, 0..) |idx, i| {
            if (idx == index) {
                _ = self.selected_indices.orderedRemove(i);
                break;
            }
        }

        self.notifySelectionChange();
    }

    /// Toggle item selection
    pub fn toggleItemSelection(self: *ListView, index: usize) void {
        if (index >= self.items.items.len) return;

        if (self.items.items[index].selected) {
            self.deselectItem(index);
        } else {
            self.selectItem(index);
        }
    }

    /// Select all items (only in multiple selection mode)
    pub fn selectAll(self: *ListView) void {
        if (self.selection_mode != .multiple) return;

        self.selected_indices.clearRetainingCapacity();
        for (self.items.items, 0..) |*item, i| {
            if (!item.disabled) {
                item.selected = true;
                self.selected_indices.append(self.component.allocator, i) catch continue;
            }
        }

        self.notifySelectionChange();
    }

    /// Deselect all items
    pub fn deselectAll(self: *ListView) void {
        for (self.selected_indices.items) |idx| {
            if (idx < self.items.items.len) {
                self.items.items[idx].selected = false;
            }
        }
        self.selected_indices.clearRetainingCapacity();

        self.notifySelectionChange();
    }

    /// Get selected items
    pub fn getSelectedItems(self: *const ListView, allocator: std.mem.Allocator) ![]ListItem {
        var selected: std.ArrayList(ListItem) = .{};
        for (self.selected_indices.items) |idx| {
            if (idx < self.items.items.len) {
                try selected.append(allocator, self.items.items[idx]);
            }
        }
        return selected.toOwnedSlice(allocator);
    }

    /// Get selected indices
    pub fn getSelectedIndices(self: *const ListView) []const usize {
        return self.selected_indices.items;
    }

    /// Get item by index
    pub fn getItem(self: *const ListView, index: usize) ?ListItem {
        if (index < self.items.items.len) {
            return self.items.items[index];
        }
        return null;
    }

    /// Get item by ID
    pub fn getItemById(self: *const ListView, id: []const u8) ?ListItem {
        for (self.items.items) |item| {
            if (std.mem.eql(u8, item.id, id)) {
                return item;
            }
        }
        return null;
    }

    /// Get item count
    pub fn getItemCount(self: *const ListView) usize {
        return self.items.items.len;
    }

    /// Update an item's text
    pub fn setItemText(self: *ListView, index: usize, text: []const u8) void {
        if (index < self.items.items.len) {
            self.items.items[index].text = text;
        }
    }

    /// Update an item's secondary text
    pub fn setItemSecondaryText(self: *ListView, index: usize, text: ?[]const u8) void {
        if (index < self.items.items.len) {
            self.items.items[index].secondary_text = text;
        }
    }

    /// Set item disabled state
    pub fn setItemDisabled(self: *ListView, index: usize, disabled: bool) void {
        if (index < self.items.items.len) {
            self.items.items[index].disabled = disabled;
            if (disabled and self.items.items[index].selected) {
                self.deselectItem(index);
            }
        }
    }

    /// Set item icon
    pub fn setItemIcon(self: *ListView, index: usize, icon: ?[]const u8) void {
        if (index < self.items.items.len) {
            self.items.items[index].icon = icon;
        }
    }

    /// Scroll to a specific item
    pub fn scrollToItem(self: *ListView, index: usize) void {
        if (index < self.items.items.len) {
            if (index < self.scroll_position) {
                self.scroll_position = index;
            } else if (index >= self.scroll_position + self.visible_count) {
                self.scroll_position = index - self.visible_count + 1;
            }
        }
    }

    /// Scroll up by one item
    pub fn scrollUp(self: *ListView) void {
        if (self.scroll_position > 0) {
            self.scroll_position -= 1;
        }
    }

    /// Scroll down by one item
    pub fn scrollDown(self: *ListView) void {
        if (self.scroll_position + self.visible_count < self.items.items.len) {
            self.scroll_position += 1;
        }
    }

    /// Get visible items
    pub fn getVisibleItems(self: *const ListView) []const ListItem {
        const start = self.scroll_position;
        const end = @min(start + self.visible_count, self.items.items.len);
        return self.items.items[start..end];
    }

    /// Handle item click
    pub fn handleItemClick(self: *ListView, index: usize) void {
        if (index >= self.items.items.len) return;
        if (self.items.items[index].disabled) return;

        if (self.selection_mode == .single) {
            self.selectItem(index);
        } else if (self.selection_mode == .multiple) {
            self.toggleItemSelection(index);
        }

        if (self.on_item_click) |callback| {
            callback(index);
        }
    }

    /// Handle item double click
    pub fn handleItemDoubleClick(self: *ListView, index: usize) void {
        if (index >= self.items.items.len) return;
        if (self.items.items[index].disabled) return;

        if (self.on_item_double_click) |callback| {
            callback(index);
        }
    }

    /// Set callbacks
    pub fn onItemClick(self: *ListView, callback: *const fn (usize) void) void {
        self.on_item_click = callback;
    }

    pub fn onItemDoubleClick(self: *ListView, callback: *const fn (usize) void) void {
        self.on_item_double_click = callback;
    }

    pub fn onSelectionChange(self: *ListView, callback: *const fn ([]const usize) void) void {
        self.on_selection_change = callback;
    }

    fn notifySelectionChange(self: *ListView) void {
        if (self.on_selection_change) |callback| {
            callback(self.selected_indices.items);
        }
    }

    /// Set selection mode
    pub fn setSelectionMode(self: *ListView, mode: SelectionMode) void {
        self.selection_mode = mode;
        if (mode == .none or mode == .single) {
            // Keep only first selected item in single mode
            if (self.selected_indices.items.len > 1) {
                const first = self.selected_indices.items[0];
                for (self.selected_indices.items[1..]) |idx| {
                    if (idx < self.items.items.len) {
                        self.items.items[idx].selected = false;
                    }
                }
                self.selected_indices.clearRetainingCapacity();
                if (mode == .single) {
                    self.selected_indices.append(self.component.allocator, first) catch {};
                }
            }
            if (mode == .none) {
                self.deselectAll();
            }
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "listview creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var list_view = try ListView.init(allocator, props, .{});
    defer list_view.deinit();

    try std.testing.expectEqual(@as(usize, 0), list_view.getItemCount());
    try std.testing.expectEqual(ListView.SelectionMode.single, list_view.selection_mode);
}

test "listview add and remove items" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var list_view = try ListView.init(allocator, props, .{});
    defer list_view.deinit();

    try list_view.addTextItem("1", "Item 1");
    try list_view.addTextItem("2", "Item 2");
    try list_view.addTextItem("3", "Item 3");

    try std.testing.expectEqual(@as(usize, 3), list_view.getItemCount());

    list_view.removeItem(1);
    try std.testing.expectEqual(@as(usize, 2), list_view.getItemCount());

    const item = list_view.getItem(1);
    try std.testing.expect(item != null);
    try std.testing.expectEqualStrings("Item 3", item.?.text);
}

test "listview single selection" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var list_view = try ListView.init(allocator, props, .{ .selection_mode = .single });
    defer list_view.deinit();

    try list_view.addTextItem("1", "Item 1");
    try list_view.addTextItem("2", "Item 2");

    list_view.selectItem(0);
    try std.testing.expectEqual(@as(usize, 1), list_view.getSelectedIndices().len);

    list_view.selectItem(1);
    try std.testing.expectEqual(@as(usize, 1), list_view.getSelectedIndices().len);
    try std.testing.expectEqual(@as(usize, 1), list_view.getSelectedIndices()[0]);
}

test "listview multiple selection" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var list_view = try ListView.init(allocator, props, .{ .selection_mode = .multiple });
    defer list_view.deinit();

    try list_view.addTextItem("1", "Item 1");
    try list_view.addTextItem("2", "Item 2");
    try list_view.addTextItem("3", "Item 3");

    list_view.selectItem(0);
    list_view.selectItem(2);

    try std.testing.expectEqual(@as(usize, 2), list_view.getSelectedIndices().len);
}

test "listview select all and deselect all" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var list_view = try ListView.init(allocator, props, .{ .selection_mode = .multiple });
    defer list_view.deinit();

    try list_view.addTextItem("1", "Item 1");
    try list_view.addTextItem("2", "Item 2");
    try list_view.addTextItem("3", "Item 3");

    list_view.selectAll();
    try std.testing.expectEqual(@as(usize, 3), list_view.getSelectedIndices().len);

    list_view.deselectAll();
    try std.testing.expectEqual(@as(usize, 0), list_view.getSelectedIndices().len);
}

test "listview disabled items" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var list_view = try ListView.init(allocator, props, .{});
    defer list_view.deinit();

    try list_view.addTextItem("1", "Item 1");
    list_view.setItemDisabled(0, true);

    list_view.selectItem(0);
    try std.testing.expectEqual(@as(usize, 0), list_view.getSelectedIndices().len);
}

test "listview scroll" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var list_view = try ListView.init(allocator, props, .{ .visible_count = 3 });
    defer list_view.deinit();

    try list_view.addTextItem("1", "Item 1");
    try list_view.addTextItem("2", "Item 2");
    try list_view.addTextItem("3", "Item 3");
    try list_view.addTextItem("4", "Item 4");
    try list_view.addTextItem("5", "Item 5");

    try std.testing.expectEqual(@as(usize, 0), list_view.scroll_position);

    list_view.scrollToItem(4);
    try std.testing.expectEqual(@as(usize, 2), list_view.scroll_position);

    list_view.scrollUp();
    try std.testing.expectEqual(@as(usize, 1), list_view.scroll_position);
}

test "listview get item by id" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var list_view = try ListView.init(allocator, props, .{});
    defer list_view.deinit();

    try list_view.addTextItem("unique-id", "Item 1");

    const item = list_view.getItemById("unique-id");
    try std.testing.expect(item != null);
    try std.testing.expectEqualStrings("Item 1", item.?.text);

    const not_found = list_view.getItemById("not-exists");
    try std.testing.expect(not_found == null);
}
