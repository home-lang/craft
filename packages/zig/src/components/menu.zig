const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// Menu Component - Hierarchical menu with items and submenus
pub const Menu = struct {
    component: Component,
    items: std.ArrayList(MenuItem),
    on_item_select: ?*const fn ([]const u8) void,
    is_open: bool,
    parent_menu: ?*Menu,

    pub const MenuItem = struct {
        id: []const u8,
        label: []const u8,
        icon: ?[]const u8 = null,
        shortcut: ?[]const u8 = null,
        disabled: bool = false,
        checked: bool = false,
        checkable: bool = false,
        separator: bool = false,
        submenu: ?*Menu = null,
        on_click: ?*const fn () void = null,
    };

    pub const ItemType = enum {
        normal,
        checkbox,
        radio,
        separator,
        submenu,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*Menu {
        const menu = try allocator.create(Menu);
        menu.* = Menu{
            .component = try Component.init(allocator, "menu", props),
            .items = .{},
            .on_item_select = null,
            .is_open = false,
            .parent_menu = null,
        };
        return menu;
    }

    pub fn deinit(self: *Menu) void {
        for (self.items.items) |*item| {
            if (item.submenu) |submenu| {
                submenu.deinit();
            }
        }
        self.items.deinit(self.component.allocator);
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    /// Add a menu item
    pub fn addItem(self: *Menu, item: MenuItem) !void {
        try self.items.append(self.component.allocator, item);
    }

    /// Add a simple text item
    pub fn addTextItem(self: *Menu, id: []const u8, label: []const u8) !void {
        try self.items.append(self.component.allocator, .{
            .id = id,
            .label = label,
        });
    }

    /// Add an item with icon and shortcut
    pub fn addItemWithDetails(self: *Menu, id: []const u8, label: []const u8, icon: ?[]const u8, shortcut: ?[]const u8) !void {
        try self.items.append(self.component.allocator, .{
            .id = id,
            .label = label,
            .icon = icon,
            .shortcut = shortcut,
        });
    }

    /// Add a separator
    pub fn addSeparator(self: *Menu) !void {
        try self.items.append(self.component.allocator, .{
            .id = "",
            .label = "",
            .separator = true,
        });
    }

    /// Add a checkable item
    pub fn addCheckableItem(self: *Menu, id: []const u8, label: []const u8, checked: bool) !void {
        try self.items.append(self.component.allocator, .{
            .id = id,
            .label = label,
            .checkable = true,
            .checked = checked,
        });
    }

    /// Add a submenu
    pub fn addSubmenu(self: *Menu, id: []const u8, label: []const u8, submenu: *Menu) !void {
        submenu.parent_menu = self;
        try self.items.append(self.component.allocator, .{
            .id = id,
            .label = label,
            .submenu = submenu,
        });
    }

    /// Remove an item by index
    pub fn removeItem(self: *Menu, index: usize) void {
        if (index < self.items.items.len) {
            const item = self.items.orderedRemove(index);
            if (item.submenu) |submenu| {
                submenu.deinit();
            }
        }
    }

    /// Remove an item by ID
    pub fn removeItemById(self: *Menu, id: []const u8) void {
        for (self.items.items, 0..) |item, i| {
            if (std.mem.eql(u8, item.id, id)) {
                self.removeItem(i);
                return;
            }
        }
    }

    /// Clear all items
    pub fn clearItems(self: *Menu) void {
        for (self.items.items) |*item| {
            if (item.submenu) |submenu| {
                submenu.deinit();
            }
        }
        self.items.clearRetainingCapacity();
    }

    /// Get an item by index
    pub fn getItem(self: *const Menu, index: usize) ?MenuItem {
        if (index < self.items.items.len) {
            return self.items.items[index];
        }
        return null;
    }

    /// Get an item by ID
    pub fn getItemById(self: *const Menu, id: []const u8) ?MenuItem {
        for (self.items.items) |item| {
            if (std.mem.eql(u8, item.id, id)) {
                return item;
            }
        }
        return null;
    }

    /// Get item count
    pub fn getItemCount(self: *const Menu) usize {
        return self.items.items.len;
    }

    /// Set item disabled state
    pub fn setItemDisabled(self: *Menu, id: []const u8, disabled: bool) void {
        for (self.items.items) |*item| {
            if (std.mem.eql(u8, item.id, id)) {
                item.disabled = disabled;
                return;
            }
        }
    }

    /// Set item checked state (for checkable items)
    pub fn setItemChecked(self: *Menu, id: []const u8, checked: bool) void {
        for (self.items.items) |*item| {
            if (std.mem.eql(u8, item.id, id) and item.checkable) {
                item.checked = checked;
                return;
            }
        }
    }

    /// Toggle item checked state
    pub fn toggleItemChecked(self: *Menu, id: []const u8) void {
        for (self.items.items) |*item| {
            if (std.mem.eql(u8, item.id, id) and item.checkable) {
                item.checked = !item.checked;
                return;
            }
        }
    }

    /// Set item label
    pub fn setItemLabel(self: *Menu, id: []const u8, label: []const u8) void {
        for (self.items.items) |*item| {
            if (std.mem.eql(u8, item.id, id)) {
                item.label = label;
                return;
            }
        }
    }

    /// Set item icon
    pub fn setItemIcon(self: *Menu, id: []const u8, icon: ?[]const u8) void {
        for (self.items.items) |*item| {
            if (std.mem.eql(u8, item.id, id)) {
                item.icon = icon;
                return;
            }
        }
    }

    /// Set item shortcut
    pub fn setItemShortcut(self: *Menu, id: []const u8, shortcut: ?[]const u8) void {
        for (self.items.items) |*item| {
            if (std.mem.eql(u8, item.id, id)) {
                item.shortcut = shortcut;
                return;
            }
        }
    }

    /// Handle item click
    pub fn handleItemClick(self: *Menu, index: usize) void {
        if (index >= self.items.items.len) return;

        const item = &self.items.items[index];
        if (item.disabled or item.separator) return;

        if (item.checkable) {
            item.checked = !item.checked;
        }

        if (item.on_click) |callback| {
            callback();
        }

        if (self.on_item_select) |callback| {
            callback(item.id);
        }
    }

    /// Handle item click by ID
    pub fn handleItemClickById(self: *Menu, id: []const u8) void {
        for (self.items.items, 0..) |item, i| {
            if (std.mem.eql(u8, item.id, id)) {
                self.handleItemClick(i);
                return;
            }
        }
    }

    /// Open the menu
    pub fn open(self: *Menu) void {
        self.is_open = true;
    }

    /// Close the menu
    pub fn close(self: *Menu) void {
        self.is_open = false;
        // Close all submenus
        for (self.items.items) |*item| {
            if (item.submenu) |submenu| {
                submenu.close();
            }
        }
    }

    /// Toggle menu open state
    pub fn toggle(self: *Menu) void {
        if (self.is_open) {
            self.close();
        } else {
            self.open();
        }
    }

    /// Check if menu is open
    pub fn isOpen(self: *const Menu) bool {
        return self.is_open;
    }

    /// Set callback for item selection
    pub fn onItemSelect(self: *Menu, callback: *const fn ([]const u8) void) void {
        self.on_item_select = callback;
    }

    /// Set item click callback
    pub fn setItemCallback(self: *Menu, id: []const u8, callback: *const fn () void) void {
        for (self.items.items) |*item| {
            if (std.mem.eql(u8, item.id, id)) {
                item.on_click = callback;
                return;
            }
        }
    }

    /// Find an item recursively (including submenus)
    pub fn findItemRecursive(self: *const Menu, id: []const u8) ?MenuItem {
        for (self.items.items) |item| {
            if (std.mem.eql(u8, item.id, id)) {
                return item;
            }
            if (item.submenu) |submenu| {
                if (submenu.findItemRecursive(id)) |found| {
                    return found;
                }
            }
        }
        return null;
    }
};

/// MenuBar Component - Horizontal menu bar with dropdown menus
pub const MenuBar = struct {
    component: Component,
    menus: std.ArrayList(MenuEntry),
    active_menu_index: ?usize,
    on_menu_open: ?*const fn (usize) void,

    pub const MenuEntry = struct {
        label: []const u8,
        menu: *Menu,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*MenuBar {
        const menu_bar = try allocator.create(MenuBar);
        menu_bar.* = MenuBar{
            .component = try Component.init(allocator, "menubar", props),
            .menus = .{},
            .active_menu_index = null,
            .on_menu_open = null,
        };
        return menu_bar;
    }

    pub fn deinit(self: *MenuBar) void {
        for (self.menus.items) |entry| {
            entry.menu.deinit();
        }
        self.menus.deinit(self.component.allocator);
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    /// Add a menu to the menu bar
    pub fn addMenu(self: *MenuBar, label: []const u8, menu: *Menu) !void {
        try self.menus.append(self.component.allocator, .{
            .label = label,
            .menu = menu,
        });
    }

    /// Remove a menu by index
    pub fn removeMenu(self: *MenuBar, index: usize) void {
        if (index < self.menus.items.len) {
            var entry = self.menus.orderedRemove(index);
            entry.menu.deinit();
        }
    }

    /// Get menu count
    pub fn getMenuCount(self: *const MenuBar) usize {
        return self.menus.items.len;
    }

    /// Get menu by index
    pub fn getMenu(self: *const MenuBar, index: usize) ?*Menu {
        if (index < self.menus.items.len) {
            return self.menus.items[index].menu;
        }
        return null;
    }

    /// Open a menu by index
    pub fn openMenu(self: *MenuBar, index: usize) void {
        if (index >= self.menus.items.len) return;

        // Close currently active menu
        if (self.active_menu_index) |active| {
            if (active < self.menus.items.len) {
                self.menus.items[active].menu.close();
            }
        }

        self.menus.items[index].menu.open();
        self.active_menu_index = index;

        if (self.on_menu_open) |callback| {
            callback(index);
        }
    }

    /// Close all menus
    pub fn closeAllMenus(self: *MenuBar) void {
        for (self.menus.items) |entry| {
            entry.menu.close();
        }
        self.active_menu_index = null;
    }

    /// Toggle a menu
    pub fn toggleMenu(self: *MenuBar, index: usize) void {
        if (index >= self.menus.items.len) return;

        if (self.active_menu_index == index) {
            self.closeAllMenus();
        } else {
            self.openMenu(index);
        }
    }

    /// Set callback for menu open
    pub fn onMenuOpen(self: *MenuBar, callback: *const fn (usize) void) void {
        self.on_menu_open = callback;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "menu creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var menu = try Menu.init(allocator, props);
    defer menu.deinit();

    try std.testing.expectEqual(@as(usize, 0), menu.getItemCount());
    try std.testing.expect(!menu.isOpen());
}

test "menu add and remove items" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var menu = try Menu.init(allocator, props);
    defer menu.deinit();

    try menu.addTextItem("file", "File");
    try menu.addTextItem("edit", "Edit");
    try menu.addSeparator();
    try menu.addTextItem("help", "Help");

    try std.testing.expectEqual(@as(usize, 4), menu.getItemCount());

    menu.removeItemById("edit");
    try std.testing.expectEqual(@as(usize, 3), menu.getItemCount());
}

test "menu checkable items" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var menu = try Menu.init(allocator, props);
    defer menu.deinit();

    try menu.addCheckableItem("show-toolbar", "Show Toolbar", true);

    const item = menu.getItemById("show-toolbar");
    try std.testing.expect(item != null);
    try std.testing.expect(item.?.checked);
    try std.testing.expect(item.?.checkable);

    menu.toggleItemChecked("show-toolbar");
    const updated = menu.getItemById("show-toolbar");
    try std.testing.expect(!updated.?.checked);
}

test "menu submenu" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var menu = try Menu.init(allocator, props);
    defer menu.deinit();

    var submenu = try Menu.init(allocator, props);
    try submenu.addTextItem("sub1", "Submenu Item 1");
    try submenu.addTextItem("sub2", "Submenu Item 2");

    try menu.addSubmenu("view", "View", submenu);

    const item = menu.getItemById("view");
    try std.testing.expect(item != null);
    try std.testing.expect(item.?.submenu != null);
}

test "menu open and close" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var menu = try Menu.init(allocator, props);
    defer menu.deinit();

    try std.testing.expect(!menu.isOpen());

    menu.open();
    try std.testing.expect(menu.isOpen());

    menu.close();
    try std.testing.expect(!menu.isOpen());

    menu.toggle();
    try std.testing.expect(menu.isOpen());
}

test "menu find item recursive" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var menu = try Menu.init(allocator, props);
    defer menu.deinit();

    var submenu = try Menu.init(allocator, props);
    try submenu.addTextItem("nested-item", "Nested Item");

    try menu.addSubmenu("parent", "Parent", submenu);

    const found = menu.findItemRecursive("nested-item");
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("Nested Item", found.?.label);
}

test "menubar creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var menubar = try MenuBar.init(allocator, props);
    defer menubar.deinit();

    var file_menu = try Menu.init(allocator, props);
    try file_menu.addTextItem("new", "New");
    try file_menu.addTextItem("open", "Open");

    try menubar.addMenu("File", file_menu);

    try std.testing.expectEqual(@as(usize, 1), menubar.getMenuCount());
}

test "menubar open and close menus" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var menubar = try MenuBar.init(allocator, props);
    defer menubar.deinit();

    var file_menu = try Menu.init(allocator, props);
    var edit_menu = try Menu.init(allocator, props);

    try menubar.addMenu("File", file_menu);
    try menubar.addMenu("Edit", edit_menu);

    menubar.openMenu(0);
    try std.testing.expect(menubar.active_menu_index == 0);
    try std.testing.expect(file_menu.isOpen());

    menubar.openMenu(1);
    try std.testing.expect(menubar.active_menu_index == 1);
    try std.testing.expect(!file_menu.isOpen());
    try std.testing.expect(edit_menu.isOpen());

    menubar.closeAllMenus();
    try std.testing.expect(menubar.active_menu_index == null);
}
