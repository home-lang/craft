const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// Toolbar Component - Horizontal bar with action buttons and controls
pub const Toolbar = struct {
    component: Component,
    items: std.ArrayList(ToolbarItem),
    orientation: Orientation,
    on_item_click: ?*const fn ([]const u8) void,
    show_labels: bool,
    show_tooltips: bool,
    icon_size: IconSize,

    pub const ToolbarItem = union(enum) {
        button: ButtonItem,
        toggle: ToggleItem,
        separator: void,
        spacer: void,
        flexible_spacer: void,
        dropdown: DropdownItem,
        custom: CustomItem,
    };

    pub const ButtonItem = struct {
        id: []const u8,
        icon: ?[]const u8 = null,
        label: ?[]const u8 = null,
        tooltip: ?[]const u8 = null,
        disabled: bool = false,
        on_click: ?*const fn () void = null,
    };

    pub const ToggleItem = struct {
        id: []const u8,
        icon: ?[]const u8 = null,
        icon_toggled: ?[]const u8 = null,
        label: ?[]const u8 = null,
        tooltip: ?[]const u8 = null,
        toggled: bool = false,
        disabled: bool = false,
        on_toggle: ?*const fn (bool) void = null,
    };

    pub const DropdownItem = struct {
        id: []const u8,
        icon: ?[]const u8 = null,
        label: ?[]const u8 = null,
        tooltip: ?[]const u8 = null,
        options: []const []const u8 = &.{},
        selected_index: usize = 0,
        disabled: bool = false,
        on_select: ?*const fn (usize) void = null,
    };

    pub const CustomItem = struct {
        id: []const u8,
        component: *Component,
    };

    pub const Orientation = enum {
        horizontal,
        vertical,
    };

    pub const IconSize = enum {
        small,
        medium,
        large,

        pub fn toPixels(self: IconSize) u32 {
            return switch (self) {
                .small => 16,
                .medium => 24,
                .large => 32,
            };
        }
    };

    pub const Config = struct {
        orientation: Orientation = .horizontal,
        show_labels: bool = false,
        show_tooltips: bool = true,
        icon_size: IconSize = .medium,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps, config: Config) !*Toolbar {
        const toolbar = try allocator.create(Toolbar);
        toolbar.* = Toolbar{
            .component = try Component.init(allocator, "toolbar", props),
            .items = .{},
            .orientation = config.orientation,
            .on_item_click = null,
            .show_labels = config.show_labels,
            .show_tooltips = config.show_tooltips,
            .icon_size = config.icon_size,
        };
        return toolbar;
    }

    pub fn deinit(self: *Toolbar) void {
        for (self.items.items) |*item| {
            switch (item.*) {
                .custom => |custom| {
                    custom.component.deinit();
                    self.component.allocator.destroy(custom.component);
                },
                else => {},
            }
        }
        self.items.deinit(self.component.allocator);
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    /// Add a button item
    pub fn addButton(self: *Toolbar, id: []const u8, icon: ?[]const u8, label: ?[]const u8) !void {
        try self.items.append(self.component.allocator, .{
            .button = .{
                .id = id,
                .icon = icon,
                .label = label,
            },
        });
    }

    /// Add a button with tooltip
    pub fn addButtonWithTooltip(self: *Toolbar, id: []const u8, icon: ?[]const u8, label: ?[]const u8, tooltip: []const u8) !void {
        try self.items.append(self.component.allocator, .{
            .button = .{
                .id = id,
                .icon = icon,
                .label = label,
                .tooltip = tooltip,
            },
        });
    }

    /// Add a toggle button
    pub fn addToggle(self: *Toolbar, id: []const u8, icon: ?[]const u8, label: ?[]const u8, toggled: bool) !void {
        try self.items.append(self.component.allocator, .{
            .toggle = .{
                .id = id,
                .icon = icon,
                .label = label,
                .toggled = toggled,
            },
        });
    }

    /// Add a separator
    pub fn addSeparator(self: *Toolbar) !void {
        try self.items.append(self.component.allocator, .separator);
    }

    /// Add a fixed spacer
    pub fn addSpacer(self: *Toolbar) !void {
        try self.items.append(self.component.allocator, .spacer);
    }

    /// Add a flexible spacer (expands to fill available space)
    pub fn addFlexibleSpacer(self: *Toolbar) !void {
        try self.items.append(self.component.allocator, .flexible_spacer);
    }

    /// Add a dropdown
    pub fn addDropdown(self: *Toolbar, id: []const u8, label: ?[]const u8, options: []const []const u8) !void {
        try self.items.append(self.component.allocator, .{
            .dropdown = .{
                .id = id,
                .label = label,
                .options = options,
            },
        });
    }

    /// Add a custom component
    pub fn addCustom(self: *Toolbar, id: []const u8, component: *Component) !void {
        try self.items.append(self.component.allocator, .{
            .custom = .{
                .id = id,
                .component = component,
            },
        });
    }

    /// Remove an item by index
    pub fn removeItem(self: *Toolbar, index: usize) void {
        if (index < self.items.items.len) {
            const item = self.items.orderedRemove(index);
            switch (item) {
                .custom => |custom| {
                    custom.component.deinit();
                    self.component.allocator.destroy(custom.component);
                },
                else => {},
            }
        }
    }

    /// Remove an item by ID
    pub fn removeItemById(self: *Toolbar, id: []const u8) void {
        for (self.items.items, 0..) |item, i| {
            const item_id = self.getItemId(item);
            if (item_id) |iid| {
                if (std.mem.eql(u8, iid, id)) {
                    self.removeItem(i);
                    return;
                }
            }
        }
    }

    /// Get item count
    pub fn getItemCount(self: *const Toolbar) usize {
        return self.items.items.len;
    }

    /// Set item disabled state
    pub fn setItemDisabled(self: *Toolbar, id: []const u8, disabled: bool) void {
        for (self.items.items) |*item| {
            switch (item.*) {
                .button => |*btn| {
                    if (std.mem.eql(u8, btn.id, id)) {
                        btn.disabled = disabled;
                        return;
                    }
                },
                .toggle => |*tog| {
                    if (std.mem.eql(u8, tog.id, id)) {
                        tog.disabled = disabled;
                        return;
                    }
                },
                .dropdown => |*dd| {
                    if (std.mem.eql(u8, dd.id, id)) {
                        dd.disabled = disabled;
                        return;
                    }
                },
                else => {},
            }
        }
    }

    /// Set toggle state
    pub fn setToggled(self: *Toolbar, id: []const u8, toggled: bool) void {
        for (self.items.items) |*item| {
            switch (item.*) {
                .toggle => |*tog| {
                    if (std.mem.eql(u8, tog.id, id)) {
                        tog.toggled = toggled;
                        return;
                    }
                },
                else => {},
            }
        }
    }

    /// Get toggle state
    pub fn isToggled(self: *const Toolbar, id: []const u8) bool {
        for (self.items.items) |item| {
            switch (item) {
                .toggle => |tog| {
                    if (std.mem.eql(u8, tog.id, id)) {
                        return tog.toggled;
                    }
                },
                else => {},
            }
        }
        return false;
    }

    /// Set dropdown selected index
    pub fn setDropdownSelection(self: *Toolbar, id: []const u8, index: usize) void {
        for (self.items.items) |*item| {
            switch (item.*) {
                .dropdown => |*dd| {
                    if (std.mem.eql(u8, dd.id, id)) {
                        if (index < dd.options.len) {
                            dd.selected_index = index;
                        }
                        return;
                    }
                },
                else => {},
            }
        }
    }

    /// Handle item click
    pub fn handleItemClick(self: *Toolbar, index: usize) void {
        if (index >= self.items.items.len) return;

        switch (self.items.items[index]) {
            .button => |btn| {
                if (btn.disabled) return;
                if (btn.on_click) |callback| {
                    callback();
                }
                if (self.on_item_click) |callback| {
                    callback(btn.id);
                }
            },
            .toggle => |*tog| {
                if (tog.disabled) return;
                tog.toggled = !tog.toggled;
                if (tog.on_toggle) |callback| {
                    callback(tog.toggled);
                }
                if (self.on_item_click) |callback| {
                    callback(tog.id);
                }
            },
            else => {},
        }
    }

    /// Handle item click by ID
    pub fn handleItemClickById(self: *Toolbar, id: []const u8) void {
        for (self.items.items, 0..) |item, i| {
            const item_id = self.getItemId(item);
            if (item_id) |iid| {
                if (std.mem.eql(u8, iid, id)) {
                    self.handleItemClick(i);
                    return;
                }
            }
        }
    }

    /// Set button click callback
    pub fn setButtonCallback(self: *Toolbar, id: []const u8, callback: *const fn () void) void {
        for (self.items.items) |*item| {
            switch (item.*) {
                .button => |*btn| {
                    if (std.mem.eql(u8, btn.id, id)) {
                        btn.on_click = callback;
                        return;
                    }
                },
                else => {},
            }
        }
    }

    /// Set toggle callback
    pub fn setToggleCallback(self: *Toolbar, id: []const u8, callback: *const fn (bool) void) void {
        for (self.items.items) |*item| {
            switch (item.*) {
                .toggle => |*tog| {
                    if (std.mem.eql(u8, tog.id, id)) {
                        tog.on_toggle = callback;
                        return;
                    }
                },
                else => {},
            }
        }
    }

    /// Set dropdown callback
    pub fn setDropdownCallback(self: *Toolbar, id: []const u8, callback: *const fn (usize) void) void {
        for (self.items.items) |*item| {
            switch (item.*) {
                .dropdown => |*dd| {
                    if (std.mem.eql(u8, dd.id, id)) {
                        dd.on_select = callback;
                        return;
                    }
                },
                else => {},
            }
        }
    }

    /// Set callback for any item click
    pub fn onItemClick(self: *Toolbar, callback: *const fn ([]const u8) void) void {
        self.on_item_click = callback;
    }

    /// Set orientation
    pub fn setOrientation(self: *Toolbar, orientation: Orientation) void {
        self.orientation = orientation;
    }

    /// Set show labels
    pub fn setShowLabels(self: *Toolbar, show: bool) void {
        self.show_labels = show;
    }

    /// Set show tooltips
    pub fn setShowTooltips(self: *Toolbar, show: bool) void {
        self.show_tooltips = show;
    }

    /// Set icon size
    pub fn setIconSize(self: *Toolbar, size: IconSize) void {
        self.icon_size = size;
    }

    fn getItemId(self: *const Toolbar, item: ToolbarItem) ?[]const u8 {
        _ = self;
        return switch (item) {
            .button => |btn| btn.id,
            .toggle => |tog| tog.id,
            .dropdown => |dd| dd.id,
            .custom => |custom| custom.id,
            else => null,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "toolbar creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var toolbar = try Toolbar.init(allocator, props, .{});
    defer toolbar.deinit();

    try std.testing.expectEqual(@as(usize, 0), toolbar.getItemCount());
    try std.testing.expectEqual(Toolbar.Orientation.horizontal, toolbar.orientation);
}

test "toolbar add items" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var toolbar = try Toolbar.init(allocator, props, .{});
    defer toolbar.deinit();

    try toolbar.addButton("new", "new-icon", "New");
    try toolbar.addButton("open", "open-icon", "Open");
    try toolbar.addSeparator();
    try toolbar.addToggle("bold", "bold-icon", "Bold", false);

    try std.testing.expectEqual(@as(usize, 4), toolbar.getItemCount());
}

test "toolbar toggle state" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var toolbar = try Toolbar.init(allocator, props, .{});
    defer toolbar.deinit();

    try toolbar.addToggle("bold", "bold-icon", "Bold", false);

    try std.testing.expect(!toolbar.isToggled("bold"));

    toolbar.setToggled("bold", true);
    try std.testing.expect(toolbar.isToggled("bold"));
}

test "toolbar disabled items" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var toolbar = try Toolbar.init(allocator, props, .{});
    defer toolbar.deinit();

    try toolbar.addButton("save", "save-icon", "Save");
    toolbar.setItemDisabled("save", true);

    // Item should be disabled, click should have no effect
    var clicked = false;
    _ = &clicked;
    // Note: Can't easily test callback wasn't called without more infrastructure
}

test "toolbar remove item" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var toolbar = try Toolbar.init(allocator, props, .{});
    defer toolbar.deinit();

    try toolbar.addButton("item1", null, "Item 1");
    try toolbar.addButton("item2", null, "Item 2");
    try toolbar.addButton("item3", null, "Item 3");

    try std.testing.expectEqual(@as(usize, 3), toolbar.getItemCount());

    toolbar.removeItemById("item2");
    try std.testing.expectEqual(@as(usize, 2), toolbar.getItemCount());
}

test "toolbar spacers" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var toolbar = try Toolbar.init(allocator, props, .{});
    defer toolbar.deinit();

    try toolbar.addButton("left", null, "Left");
    try toolbar.addFlexibleSpacer();
    try toolbar.addButton("right", null, "Right");

    try std.testing.expectEqual(@as(usize, 3), toolbar.getItemCount());
}

test "toolbar icon size" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var toolbar = try Toolbar.init(allocator, props, .{ .icon_size = .large });
    defer toolbar.deinit();

    try std.testing.expectEqual(Toolbar.IconSize.large, toolbar.icon_size);
    try std.testing.expectEqual(@as(u32, 32), toolbar.icon_size.toPixels());

    toolbar.setIconSize(.small);
    try std.testing.expectEqual(@as(u32, 16), toolbar.icon_size.toPixels());
}
