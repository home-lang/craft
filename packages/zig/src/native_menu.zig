const std = @import("std");

/// Native menu system for application menus, context menus, and accelerators
/// Cross-platform menu abstraction
pub const MenuError = error{
    InvalidMenuItem,
    MenuNotFound,
    InvalidAccelerator,
};

/// Menu item type
pub const MenuItemType = enum {
    Normal,
    Separator,
    Submenu,
    Checkbox,
    Radio,
};

/// Menu item
pub const MenuItem = struct {
    id: []const u8,
    label: []const u8,
    type: MenuItemType = .Normal,
    enabled: bool = true,
    checked: bool = false,
    accelerator: ?[]const u8 = null,
    submenu: ?*Menu = null,
    callback: ?*const fn () void = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, id: []const u8, label: []const u8) !MenuItem {
        return MenuItem{
            .id = try allocator.dupe(u8, id),
            .label = try allocator.dupe(u8, label),
            .type = .Normal,
            .enabled = true,
            .checked = false,
            .accelerator = null,
            .submenu = null,
            .callback = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MenuItem) void {
        self.allocator.free(self.id);
        self.allocator.free(self.label);
        if (self.accelerator) |acc| {
            self.allocator.free(acc);
        }
        if (self.submenu) |submenu| {
            submenu.deinit();
            self.allocator.destroy(submenu);
        }
    }

    pub fn setAccelerator(self: *MenuItem, accelerator: []const u8) !void {
        if (self.accelerator) |old| {
            self.allocator.free(old);
        }
        self.accelerator = try self.allocator.dupe(u8, accelerator);
    }

    pub fn setSubmenu(self: *MenuItem, submenu: *Menu) void {
        self.submenu = submenu;
        self.type = .Submenu;
    }
};

/// Menu structure
pub const Menu = struct {
    title: []const u8,
    items: std.ArrayList(MenuItem),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, title: []const u8) !Menu {
        return Menu{
            .title = try allocator.dupe(u8, title),
            .items = std.ArrayList(MenuItem).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.items.items) |*item| {
            item.deinit();
        }
        self.items.deinit();
        self.allocator.free(self.title);
    }

    pub fn addItem(self: *Self, item: MenuItem) !void {
        try self.items.append(item);
    }

    pub fn addSeparator(self: *Self) !void {
        var separator = MenuItem{
            .id = try self.allocator.dupe(u8, "separator"),
            .label = try self.allocator.dupe(u8, ""),
            .type = .Separator,
            .enabled = false,
            .checked = false,
            .accelerator = null,
            .submenu = null,
            .callback = null,
            .allocator = self.allocator,
        };
        try self.items.append(separator);
    }

    pub fn findItem(self: *Self, id: []const u8) ?*MenuItem {
        for (self.items.items) |*item| {
            if (std.mem.eql(u8, item.id, id)) {
                return item;
            }
        }
        return null;
    }

    pub fn removeItem(self: *Self, id: []const u8) !void {
        for (self.items.items, 0..) |*item, i| {
            if (std.mem.eql(u8, item.id, id)) {
                var removed = self.items.orderedRemove(i);
                removed.deinit();
                return;
            }
        }
        return MenuError.MenuNotFound;
    }
};

/// Application menu bar
pub const MenuBar = struct {
    menus: std.ArrayList(Menu),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) MenuBar {
        return MenuBar{
            .menus = std.ArrayList(Menu).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.menus.items) |*menu| {
            menu.deinit();
        }
        self.menus.deinit();
    }

    pub fn addMenu(self: *Self, menu: Menu) !void {
        try self.menus.append(menu);
    }

    pub fn findMenu(self: *Self, title: []const u8) ?*Menu {
        for (self.menus.items) |*menu| {
            if (std.mem.eql(u8, menu.title, title)) {
                return menu;
            }
        }
        return null;
    }

    /// Build standard application menu (File, Edit, View, Window, Help)
    pub fn buildStandardMenu(allocator: std.mem.Allocator, app_name: []const u8) !MenuBar {
        var menu_bar = MenuBar.init(allocator);

        // File Menu
        var file_menu = try Menu.init(allocator, "File");
        try file_menu.addItem(try MenuItem.init(allocator, "file.new", "New"));
        try file_menu.addItem(try MenuItem.init(allocator, "file.open", "Open..."));
        try file_menu.addSeparator();
        try file_menu.addItem(try MenuItem.init(allocator, "file.save", "Save"));
        try file_menu.addItem(try MenuItem.init(allocator, "file.save_as", "Save As..."));
        try file_menu.addSeparator();
        try file_menu.addItem(try MenuItem.init(allocator, "file.close", "Close Window"));

        // Set accelerators
        if (file_menu.findItem("file.new")) |item| {
            try item.setAccelerator("Cmd+N");
        }
        if (file_menu.findItem("file.open")) |item| {
            try item.setAccelerator("Cmd+O");
        }
        if (file_menu.findItem("file.save")) |item| {
            try item.setAccelerator("Cmd+S");
        }

        try menu_bar.addMenu(file_menu);

        // Edit Menu
        var edit_menu = try Menu.init(allocator, "Edit");
        try edit_menu.addItem(try MenuItem.init(allocator, "edit.undo", "Undo"));
        try edit_menu.addItem(try MenuItem.init(allocator, "edit.redo", "Redo"));
        try edit_menu.addSeparator();
        try edit_menu.addItem(try MenuItem.init(allocator, "edit.cut", "Cut"));
        try edit_menu.addItem(try MenuItem.init(allocator, "edit.copy", "Copy"));
        try edit_menu.addItem(try MenuItem.init(allocator, "edit.paste", "Paste"));

        if (edit_menu.findItem("edit.undo")) |item| {
            try item.setAccelerator("Cmd+Z");
        }
        if (edit_menu.findItem("edit.redo")) |item| {
            try item.setAccelerator("Cmd+Shift+Z");
        }
        if (edit_menu.findItem("edit.cut")) |item| {
            try item.setAccelerator("Cmd+X");
        }
        if (edit_menu.findItem("edit.copy")) |item| {
            try item.setAccelerator("Cmd+C");
        }
        if (edit_menu.findItem("edit.paste")) |item| {
            try item.setAccelerator("Cmd+V");
        }

        try menu_bar.addMenu(edit_menu);

        // View Menu
        var view_menu = try Menu.init(allocator, "View");
        try view_menu.addItem(try MenuItem.init(allocator, "view.reload", "Reload"));
        try view_menu.addItem(try MenuItem.init(allocator, "view.fullscreen", "Toggle Full Screen"));
        try view_menu.addSeparator();
        try view_menu.addItem(try MenuItem.init(allocator, "view.devtools", "Developer Tools"));

        if (view_menu.findItem("view.reload")) |item| {
            try item.setAccelerator("Cmd+R");
        }
        if (view_menu.findItem("view.fullscreen")) |item| {
            try item.setAccelerator("Cmd+Ctrl+F");
        }
        if (view_menu.findItem("view.devtools")) |item| {
            try item.setAccelerator("Cmd+Alt+I");
        }

        try menu_bar.addMenu(view_menu);

        // Window Menu
        var window_menu = try Menu.init(allocator, "Window");
        try window_menu.addItem(try MenuItem.init(allocator, "window.minimize", "Minimize"));
        try window_menu.addItem(try MenuItem.init(allocator, "window.zoom", "Zoom"));
        try window_menu.addSeparator();
        try window_menu.addItem(try MenuItem.init(allocator, "window.front", "Bring All to Front"));

        if (window_menu.findItem("window.minimize")) |item| {
            try item.setAccelerator("Cmd+M");
        }

        try menu_bar.addMenu(window_menu);

        // Help Menu
        var help_menu = try Menu.init(allocator, "Help");
        const label = try std.fmt.allocPrint(allocator, "{s} Help", .{app_name});
        defer allocator.free(label);
        try help_menu.addItem(try MenuItem.init(allocator, "help.docs", label));

        try menu_bar.addMenu(help_menu);

        return menu_bar;
    }
};

/// Context menu
pub const ContextMenu = struct {
    menu: Menu,
    x: i32,
    y: i32,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, x: i32, y: i32) !ContextMenu {
        return ContextMenu{
            .menu = try Menu.init(allocator, "Context"),
            .x = x,
            .y = y,
        };
    }

    pub fn deinit(self: *Self) void {
        self.menu.deinit();
    }

    pub fn show(self: *Self) void {
        std.debug.print("Showing context menu at ({d}, {d})\n", .{ self.x, self.y });
        // Platform-specific implementation
    }
};

// Tests
test "menu creation" {
    const allocator = std.testing.allocator;

    var menu = try Menu.init(allocator, "File");
    defer menu.deinit();

    var item = try MenuItem.init(allocator, "file.open", "Open...");
    try menu.addItem(item);

    try std.testing.expect(menu.items.items.len == 1);
}

test "menu bar with standard menus" {
    const allocator = std.testing.allocator;

    var menu_bar = try MenuBar.buildStandardMenu(allocator, "Test App");
    defer menu_bar.deinit();

    try std.testing.expect(menu_bar.menus.items.len == 5); // File, Edit, View, Window, Help

    const file_menu = menu_bar.findMenu("File");
    try std.testing.expect(file_menu != null);
}

test "menu item accelerator" {
    const allocator = std.testing.allocator;

    var item = try MenuItem.init(allocator, "test", "Test Item");
    defer item.deinit();

    try item.setAccelerator("Cmd+T");
    try std.testing.expect(item.accelerator != null);
    try std.testing.expectEqualStrings("Cmd+T", item.accelerator.?);
}
