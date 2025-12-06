const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");
const icons = @import("icons.zig");
const logging = @import("logging.zig");

const BridgeError = bridge_error.BridgeError;
const log = logging.menu;

/// Menu item type
pub const MenuItemType = enum {
    normal,
    separator,
    checkbox,
    radio,
};

/// Menu item structure for menu building
pub const MenuItem = struct {
    id: []const u8,
    label: []const u8,
    menu_type: MenuItemType = .normal,
    checked: bool = false,
    enabled: bool = true,
    action: ?[]const u8 = null,
    shortcut: ?[]const u8 = null,
    icon: ?[]const u8 = null, // Icon name from icons.zig
    submenu: ?[]MenuItem = null,
};

/// Bridge handler for application menu and dock menu
pub const MenuBridge = struct {
    allocator: std.mem.Allocator,
    app_menu: ?*anyopaque = null,
    dock_menu: ?*anyopaque = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    /// Handle menu-related messages from JavaScript
    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        self.handleMessageInternal(action, data) catch |err| {
            self.reportError(action, err);
        };
    }

    fn handleMessageInternal(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "setAppMenu")) {
            try self.setAppMenu(data);
        } else if (std.mem.eql(u8, action, "setDockMenu")) {
            try self.setDockMenu(data);
        } else if (std.mem.eql(u8, action, "addMenuItem")) {
            try self.addMenuItem(data);
        } else if (std.mem.eql(u8, action, "removeMenuItem")) {
            try self.removeMenuItem(data);
        } else if (std.mem.eql(u8, action, "enableMenuItem")) {
            try self.enableMenuItem(data);
        } else if (std.mem.eql(u8, action, "disableMenuItem")) {
            try self.disableMenuItem(data);
        } else if (std.mem.eql(u8, action, "checkMenuItem")) {
            try self.checkMenuItem(data);
        } else if (std.mem.eql(u8, action, "uncheckMenuItem")) {
            try self.uncheckMenuItem(data);
        } else if (std.mem.eql(u8, action, "setMenuItemLabel")) {
            try self.setMenuItemLabel(data);
        } else if (std.mem.eql(u8, action, "clearDockMenu")) {
            try self.clearDockMenu();
        } else {
            return BridgeError.UnknownAction;
        }
    }

    fn reportError(self: *Self, action: []const u8, err: anyerror) void {
        const bridge_err: BridgeError = switch (err) {
            BridgeError.MissingData => BridgeError.MissingData,
            BridgeError.InvalidJSON => BridgeError.InvalidJSON,
            else => BridgeError.NativeCallFailed,
        };
        bridge_error.sendErrorToJS(self.allocator, action, bridge_err);
    }

    /// Set the application menu bar
    /// JSON: {"menus": [{"label": "File", "items": [{"id": "new", "label": "New", "shortcut": "cmd+n"}]}]}
    fn setAppMenu(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        log.debug("setAppMenu", .{});

        // Get NSApplication
        const NSApplication = macos.getClass("NSApplication");
        const app = macos.msgSend0(NSApplication, "sharedApplication");

        // Create main menu bar
        const NSMenu = macos.getClass("NSMenu");
        const main_menu = macos.msgSend0(macos.msgSend0(NSMenu, "alloc"), "init");

        // Parse menu structure - look for each menu in "menus" array
        var pos: usize = 0;
        var menu_count: usize = 0;

        while (std.mem.indexOfPos(u8, data, pos, "\"label\":\"")) |label_idx| {
            const start = label_idx + 9;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                const menu_label = data[start..end];

                // Find items for this menu
                if (std.mem.indexOfPos(u8, data, end, "\"items\":")) |items_idx| {
                    // Find the end of items array
                    var bracket_count: i32 = 0;
                    var items_start: usize = items_idx + 8;
                    var items_end: usize = items_start;

                    // Skip whitespace
                    while (items_start < data.len and (data[items_start] == ' ' or data[items_start] == '\n')) : (items_start += 1) {}

                    if (items_start < data.len and data[items_start] == '[') {
                        bracket_count = 1;
                        items_end = items_start + 1;

                        while (items_end < data.len and bracket_count > 0) : (items_end += 1) {
                            if (data[items_end] == '[') bracket_count += 1;
                            if (data[items_end] == ']') bracket_count -= 1;
                        }

                        const items_data = data[items_start..items_end];

                        // Create menu with items
                        const menu = try self.createMenuWithItems(menu_label, items_data);
                        if (menu) |m| {
                            // Create menu item for menu bar
                            const menu_item = macos.msgSend0(macos.msgSend0(macos.getClass("NSMenuItem"), "alloc"), "init");

                            const label_cstr = try self.allocator.dupeZ(u8, menu_label);
                            defer self.allocator.free(label_cstr);
                            const NSString = macos.getClass("NSString");
                            const ns_label = macos.msgSend1(macos.msgSend0(NSString, "alloc"), "initWithUTF8String:", label_cstr.ptr);
                            _ = macos.msgSend1(menu_item, "setTitle:", ns_label);
                            _ = macos.msgSend1(m, "setTitle:", ns_label);

                            // Set submenu
                            _ = macos.msgSend1(menu_item, "setSubmenu:", m);

                            // Add to main menu
                            _ = macos.msgSend1(main_menu, "addItem:", menu_item);
                            menu_count += 1;
                        }

                        pos = items_end;
                    } else {
                        pos = end + 1;
                    }
                } else {
                    pos = end + 1;
                }
            } else break;
        }

        // Set as app main menu
        _ = macos.msgSend1(app, "setMainMenu:", main_menu);
        self.app_menu = main_menu;

        log.debug("Created app menu with {} menus", .{menu_count});
    }

    /// Create a menu with items from JSON
    fn createMenuWithItems(self: *Self, title: []const u8, items_data: []const u8) !?*anyopaque {
        if (builtin.os.tag != .macos) return null;

        const macos = @import("macos.zig");

        const NSMenu = macos.getClass("NSMenu");
        const menu = macos.msgSend0(macos.msgSend0(NSMenu, "alloc"), "init");

        // Set title
        const title_cstr = try self.allocator.dupeZ(u8, title);
        defer self.allocator.free(title_cstr);
        const NSString = macos.getClass("NSString");
        const ns_title = macos.msgSend1(macos.msgSend0(NSString, "alloc"), "initWithUTF8String:", title_cstr.ptr);
        _ = macos.msgSend1(menu, "setTitle:", ns_title);

        // Parse items
        var pos: usize = 0;
        while (pos < items_data.len) {
            // Check for separator
            if (std.mem.indexOfPos(u8, items_data, pos, "\"separator\":true")) |sep_idx| {
                if (sep_idx < pos + 50) {
                    const sep_item = macos.msgSend0(macos.getClass("NSMenuItem"), "separatorItem");
                    _ = macos.msgSend1(menu, "addItem:", sep_item);
                    pos = sep_idx + 16;
                    continue;
                }
            }

            // Look for item id
            if (std.mem.indexOfPos(u8, items_data, pos, "\"id\":\"")) |id_idx| {
                const id_start = id_idx + 6;
                if (std.mem.indexOfPos(u8, items_data, id_start, "\"")) |id_end| {
                    const item_id = items_data[id_start..id_end];

                    // Look for label
                    var item_label: []const u8 = item_id;
                    if (std.mem.indexOfPos(u8, items_data, id_end, "\"label\":\"")) |label_idx| {
                        if (label_idx < id_end + 100) {
                            const label_start = label_idx + 9;
                            if (std.mem.indexOfPos(u8, items_data, label_start, "\"")) |label_end| {
                                item_label = items_data[label_start..label_end];
                            }
                        }
                    }

                    // Look for shortcut
                    var shortcut: []const u8 = "";
                    if (std.mem.indexOfPos(u8, items_data, id_end, "\"shortcut\":\"")) |sc_idx| {
                        if (sc_idx < id_end + 150) {
                            const sc_start = sc_idx + 12;
                            if (std.mem.indexOfPos(u8, items_data, sc_start, "\"")) |sc_end| {
                                shortcut = items_data[sc_start..sc_end];
                            }
                        }
                    }

                    // Look for icon
                    var icon_name: ?[]const u8 = null;
                    if (std.mem.indexOfPos(u8, items_data, id_end, "\"icon\":\"")) |icon_idx| {
                        if (icon_idx < id_end + 200) {
                            const icon_start = icon_idx + 8;
                            if (std.mem.indexOfPos(u8, items_data, icon_start, "\"")) |icon_end| {
                                icon_name = items_data[icon_start..icon_end];
                            }
                        }
                    }

                    // Create menu item
                    const item = try self.createMenuItem(item_id, item_label, shortcut, icon_name);
                    if (item) |i| {
                        _ = macos.msgSend1(menu, "addItem:", i);
                    }

                    pos = id_end + 1;
                } else break;
            } else {
                pos += 1;
            }
        }

        return menu;
    }

    /// Create a single menu item with optional icon
    fn createMenuItem(self: *Self, id: []const u8, label: []const u8, shortcut: []const u8, icon_name: ?[]const u8) !?*anyopaque {
        if (builtin.os.tag != .macos) return null;

        const macos = @import("macos.zig");

        // Create label NSString
        const label_cstr = try self.allocator.dupeZ(u8, label);
        defer self.allocator.free(label_cstr);
        const NSString = macos.getClass("NSString");
        const ns_label = macos.msgSend1(macos.msgSend0(NSString, "alloc"), "initWithUTF8String:", label_cstr.ptr);

        // Parse shortcut
        var key_equiv: []const u8 = "";
        var modifier_mask: c_ulong = 0;

        if (shortcut.len > 0) {
            if (std.mem.indexOf(u8, shortcut, "cmd")) |_| {
                modifier_mask |= (1 << 20); // NSEventModifierFlagCommand
            }
            if (std.mem.indexOf(u8, shortcut, "ctrl")) |_| {
                modifier_mask |= (1 << 18); // NSEventModifierFlagControl
            }
            if (std.mem.indexOf(u8, shortcut, "alt") != null or std.mem.indexOf(u8, shortcut, "opt") != null) {
                modifier_mask |= (1 << 19); // NSEventModifierFlagOption
            }
            if (std.mem.indexOf(u8, shortcut, "shift")) |_| {
                modifier_mask |= (1 << 17); // NSEventModifierFlagShift
            }

            // Get the key (last part after +)
            if (std.mem.lastIndexOf(u8, shortcut, "+")) |plus_idx| {
                key_equiv = shortcut[plus_idx + 1 ..];
            } else {
                key_equiv = shortcut;
            }
        }

        // Create key equivalent string
        const key_cstr = if (key_equiv.len > 0) try self.allocator.dupeZ(u8, key_equiv) else try self.allocator.dupeZ(u8, "");
        defer self.allocator.free(key_cstr);
        const ns_key = macos.msgSend1(macos.msgSend0(NSString, "alloc"), "initWithUTF8String:", key_cstr.ptr);

        // Create menu item with action
        const NSMenuItem = macos.getClass("NSMenuItem");
        const item = macos.msgSend3(macos.msgSend0(NSMenuItem, "alloc"), "initWithTitle:action:keyEquivalent:", ns_label, macos.sel("craftMenuAction:"), ns_key);

        // Set modifier mask
        if (modifier_mask > 0) {
            _ = macos.msgSend1(item, "setKeyEquivalentModifierMask:", modifier_mask);
        }

        // Store item ID as represented object
        const id_cstr = try self.allocator.dupeZ(u8, id);
        defer self.allocator.free(id_cstr);
        const ns_id = macos.msgSend1(macos.msgSend0(NSString, "alloc"), "initWithUTF8String:", id_cstr.ptr);
        _ = macos.msgSend1(item, "setRepresentedObject:", ns_id);

        // Apply icon if specified
        if (icon_name) |name| {
            // Resolve through cross-platform icons module
            const resolved_name = if (icons.getIconByName(name)) |icon| blk: {
                const platform_icon = icons.getPlatformIcon(icon);
                if (platform_icon.kind == .sf_symbol and platform_icon.value.len > 0) {
                    break :blk platform_icon.value;
                }
                break :blk name;
            } else name;

            const NSImage = macos.getClass("NSImage");
            const icon_cstr = try self.allocator.dupeZ(u8, resolved_name);
            defer self.allocator.free(icon_cstr);
            const ns_icon_name = macos.msgSend1(macos.msgSend0(NSString, "alloc"), "initWithUTF8String:", icon_cstr.ptr);
            const image = macos.msgSend2(NSImage, "imageWithSystemSymbolName:accessibilityDescription:", ns_icon_name, @as(?*anyopaque, null));

            if (image != null) {
                _ = macos.msgSend1(item, "setImage:", image);
            }
        }

        return item;
    }

    /// Set the dock menu (right-click on dock icon)
    /// JSON: {"items": [{"id": "show", "label": "Show Window"}, {"separator": true}, {"id": "quit", "label": "Quit"}]}
    fn setDockMenu(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) return;

        log.debug("setDockMenu", .{});

        // Create dock menu
        const menu = try self.createMenuWithItems("Dock", data) orelse return;
        self.dock_menu = menu;
        global_dock_menu = menu;

        log.debug("Dock menu created", .{});
    }

    /// Add a single menu item to existing menu
    /// JSON: {"menuId": "file", "itemId": "save", "label": "Save", "shortcut": "cmd+s", "index": -1}
    /// If menuId is omitted, adds to app menu. index -1 means append at end.
    fn addMenuItem(self: *Self, data: []const u8) !void {
        try addMenuItemImpl(self, data);
    }

    /// Remove a menu item
    /// JSON: {"itemId": "save"} or {"menuId": "file", "itemId": "save"}
    fn removeMenuItem(self: *Self, data: []const u8) !void {
        removeMenuItemImpl(self, data);
    }

    /// Enable a menu item
    fn enableMenuItem(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) return;
        _ = self;

        var item_id: []const u8 = "";
        if (std.mem.indexOf(u8, data, "\"itemId\":\"")) |idx| {
            const start = idx + 10;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                item_id = data[start..end];
            }
        }

        log.debug("enableMenuItem: {s}", .{item_id});

        if (findMenuItemById(item_id)) |item| {
            const macos = @import("macos.zig");
            _ = macos.msgSend1(item, "setEnabled:", @as(c_int, 1));
        }
    }

    /// Disable a menu item
    fn disableMenuItem(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) return;
        _ = self;

        var item_id: []const u8 = "";
        if (std.mem.indexOf(u8, data, "\"itemId\":\"")) |idx| {
            const start = idx + 10;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                item_id = data[start..end];
            }
        }

        log.debug("disableMenuItem: {s}", .{item_id});

        if (findMenuItemById(item_id)) |item| {
            const macos = @import("macos.zig");
            _ = macos.msgSend1(item, "setEnabled:", @as(c_int, 0));
        }
    }

    /// Check (add checkmark to) a menu item
    fn checkMenuItem(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) return;
        _ = self;

        var item_id: []const u8 = "";
        if (std.mem.indexOf(u8, data, "\"itemId\":\"")) |idx| {
            const start = idx + 10;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                item_id = data[start..end];
            }
        }

        log.debug("checkMenuItem: {s}", .{item_id});

        if (findMenuItemById(item_id)) |item| {
            const macos = @import("macos.zig");
            _ = macos.msgSend1(item, "setState:", @as(c_long, 1));
        }
    }

    /// Uncheck a menu item
    fn uncheckMenuItem(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) return;
        _ = self;

        var item_id: []const u8 = "";
        if (std.mem.indexOf(u8, data, "\"itemId\":\"")) |idx| {
            const start = idx + 10;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                item_id = data[start..end];
            }
        }

        log.debug("uncheckMenuItem: {s}", .{item_id});

        if (findMenuItemById(item_id)) |item| {
            const macos = @import("macos.zig");
            _ = macos.msgSend1(item, "setState:", @as(c_long, 0));
        }
    }

    /// Update menu item label
    fn setMenuItemLabel(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) return;

        var item_id: []const u8 = "";
        var new_label: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"itemId\":\"")) |idx| {
            const start = idx + 10;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                item_id = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"label\":\"")) |idx| {
            const start = idx + 9;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                new_label = data[start..end];
            }
        }

        log.debug("setMenuItemLabel: {s} = {s}", .{ item_id, new_label });

        if (findMenuItemById(item_id)) |item| {
            const macos = @import("macos.zig");
            const label_cstr = try self.allocator.dupeZ(u8, new_label);
            defer self.allocator.free(label_cstr);
            const NSString = macos.getClass("NSString");
            const ns_label = macos.msgSend1(macos.msgSend0(NSString, "alloc"), "initWithUTF8String:", label_cstr.ptr);
            _ = macos.msgSend1(item, "setTitle:", ns_label);
        }
    }

    /// Clear the dock menu
    fn clearDockMenu(self: *Self) !void {
        if (builtin.os.tag != .macos) return;

        log.debug("clearDockMenu", .{});

        if (self.dock_menu) |menu| {
            const macos = @import("macos.zig");
            _ = macos.msgSend0(menu, "removeAllItems");
        }
        self.dock_menu = null;
        global_dock_menu = null;
    }

    /// Legacy createMenu for compatibility
    pub fn createMenu(self: *Self, menu_json: []const u8) !?*anyopaque {
        return try self.createMenuWithItems("Menu", menu_json);
    }

    pub fn deinit(self: *Self) void {
        _ = self;
        global_dock_menu = null;
    }
};

/// Global dock menu for delegate callback
var global_dock_menu: ?*anyopaque = null;

/// Get dock menu for applicationDockMenu: delegate
pub fn getDockMenu() ?*anyopaque {
    return global_dock_menu;
}

/// Implementation of addMenuItem (platform-specific)
fn addMenuItemImpl(self: *MenuBridge, data: []const u8) !void {
    if (builtin.os.tag == .macos) {
        const macos = @import("macos.zig");

        // Parse menuId (target menu)
        var menu_id: []const u8 = "";
        if (std.mem.indexOf(u8, data, "\"menuId\":\"")) |idx| {
            const start = idx + 10;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                menu_id = data[start..end];
            }
        }

        // Parse item details
        var item_id: []const u8 = "";
        var item_label: []const u8 = "";
        var shortcut: []const u8 = "";
        var index: i32 = -1;

        if (std.mem.indexOf(u8, data, "\"itemId\":\"")) |idx| {
            const start = idx + 10;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                item_id = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"label\":\"")) |idx| {
            const start = idx + 9;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                item_label = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"shortcut\":\"")) |idx| {
            const start = idx + 12;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                shortcut = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"index\":")) |idx| {
            const start = idx + 8;
            var end = start;
            while (end < data.len and (data[end] == '-' or (data[end] >= '0' and data[end] <= '9'))) : (end += 1) {}
            if (end > start) {
                index = std.fmt.parseInt(i32, data[start..end], 10) catch -1;
            }
        }

        // Parse icon
        var icon_name: ?[]const u8 = null;
        if (std.mem.indexOf(u8, data, "\"icon\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                icon_name = data[start..end];
            }
        }

        // Check for separator
        const is_separator = std.mem.indexOf(u8, data, "\"separator\":true") != null;

        log.debug("addMenuItem: menu={s}, id={s}, label={s}", .{ menu_id, item_id, item_label });

        // Find target menu
        var target_menu: ?*anyopaque = null;

        if (menu_id.len > 0) {
            const app = macos.msgSend0(macos.getClass("NSApplication"), "sharedApplication");
            const main_menu = macos.msgSend0(app, "mainMenu");
            if (main_menu) |menu| {
                target_menu = findSubmenuByTitle(menu, menu_id);
            }
        } else if (self.app_menu) |menu| {
            target_menu = menu;
        }

        if (target_menu == null) {
            log.warn("Target menu not found: {s}", .{menu_id});
            return;
        }

        // Create menu item
        var new_item: ?*anyopaque = null;
        if (is_separator) {
            new_item = macos.msgSend0(macos.getClass("NSMenuItem"), "separatorItem");
        } else {
            new_item = try self.createMenuItem(item_id, item_label, shortcut, icon_name);
        }

        if (new_item) |item| {
            if (index < 0) {
                _ = macos.msgSend1(target_menu.?, "addItem:", item);
            } else {
                _ = macos.msgSend2(target_menu.?, "insertItem:atIndex:", item, @as(c_long, index));
            }
            log.debug("Added menu item: {s}", .{item_id});
        }
    } else {
        // Linux/Windows: Menu APIs not yet implemented
        _ = &self;
        _ = &data;
    }
}

/// Implementation of removeMenuItem (platform-specific)
fn removeMenuItemImpl(self: *MenuBridge, data: []const u8) void {
    _ = &self;
    if (builtin.os.tag == .macos) {
        const macos = @import("macos.zig");

        // Parse itemId to remove
        var item_id: []const u8 = "";
        if (std.mem.indexOf(u8, data, "\"itemId\":\"")) |idx| {
            const start = idx + 10;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                item_id = data[start..end];
            }
        }

        if (item_id.len == 0) {
            log.warn("removeMenuItem: no itemId provided", .{});
            return;
        }

        log.debug("removeMenuItem: {s}", .{item_id});

        // Find and remove the item
        if (findMenuItemById(item_id)) |item| {
            const parent_menu = macos.msgSend0(item, "menu");
            if (parent_menu) |menu| {
                _ = macos.msgSend1(menu, "removeItem:", item);
                log.debug("Removed menu item: {s}", .{item_id});
            }
        } else {
            log.warn("Menu item not found: {s}", .{item_id});
        }
    } else {
        // Linux/Windows: Menu APIs not yet implemented
        _ = &data;
    }
}

/// Find submenu by title (case-insensitive search)
fn findSubmenuByTitle(menu: *anyopaque, title: []const u8) ?*anyopaque {
    if (builtin.os.tag != .macos) return null;

    const macos = @import("macos.zig");

    const count_ptr = macos.msgSend0(menu, "numberOfItems");
    const count = @as(usize, @intFromPtr(count_ptr));

    var i: usize = 0;
    while (i < count) : (i += 1) {
        const item = macos.msgSend1(menu, "itemAtIndex:", @as(c_long, @intCast(i)));
        if (item == null) continue;

        // Check if this item has a submenu
        const submenu = macos.msgSend0(item, "submenu");
        if (submenu) |sub| {
            // Get submenu title
            const ns_title = macos.msgSend0(sub, "title");
            if (ns_title != null) {
                const cstr = macos.msgSend0(ns_title, "UTF8String");
                if (cstr != null) {
                    const title_str = std.mem.span(@as([*:0]const u8, @ptrCast(cstr)));
                    if (std.ascii.eqlIgnoreCase(title_str, title)) {
                        return sub;
                    }
                }
            }

            // Also check item title (menu bar items)
            const item_title = macos.msgSend0(item, "title");
            if (item_title != null) {
                const item_cstr = macos.msgSend0(item_title, "UTF8String");
                if (item_cstr != null) {
                    const item_str = std.mem.span(@as([*:0]const u8, @ptrCast(item_cstr)));
                    if (std.ascii.eqlIgnoreCase(item_str, title)) {
                        return sub;
                    }
                }
            }

            // Recursively search nested submenus
            if (findSubmenuByTitle(sub, title)) |found| {
                return found;
            }
        }
    }

    return null;
}

/// Find menu item by ID (searches app menu and dock menu)
fn findMenuItemById(item_id: []const u8) ?*anyopaque {
    if (builtin.os.tag != .macos) return null;

    const macos = @import("macos.zig");

    // Search app main menu
    const app = macos.msgSend0(macos.getClass("NSApplication"), "sharedApplication");
    const main_menu = macos.msgSend0(app, "mainMenu");

    if (main_menu) |menu| {
        if (searchMenuForItem(menu, item_id)) |found| {
            return found;
        }
    }

    // Search dock menu
    if (global_dock_menu) |dock_menu| {
        if (searchMenuForItem(dock_menu, item_id)) |found| {
            return found;
        }
    }

    return null;
}

/// Recursively search menu for item with ID
fn searchMenuForItem(menu: *anyopaque, item_id: []const u8) ?*anyopaque {
    if (builtin.os.tag != .macos) return null;

    const macos = @import("macos.zig");

    const count_ptr = macos.msgSend0(menu, "numberOfItems");
    const count = @as(usize, @intFromPtr(count_ptr));

    var i: usize = 0;
    while (i < count) : (i += 1) {
        const item = macos.msgSend1(menu, "itemAtIndex:", @as(c_long, @intCast(i)));
        if (item == null) continue;

        // Check represented object for ID
        const rep_obj = macos.msgSend0(item, "representedObject");
        if (rep_obj != null) {
            const cstr = macos.msgSend0(rep_obj, "UTF8String");
            if (cstr != null) {
                const id_str = std.mem.span(@as([*:0]const u8, @ptrCast(cstr)));
                if (std.mem.eql(u8, id_str, item_id)) {
                    return item;
                }
            }
        }

        // Check submenu recursively
        const submenu = macos.msgSend0(item, "submenu");
        if (submenu) |sub| {
            if (searchMenuForItem(sub, item_id)) |found| {
                return found;
            }
        }
    }

    return null;
}

/// Handle menu item click - called from app delegate
pub fn handleMenuItemClick(item_id: []const u8) void {
    if (builtin.os.tag != .macos) return;

    const macos = @import("macos.zig");

    log.debug("Menu item clicked: {s}", .{item_id});

    var buf: [512]u8 = undefined;
    const js = std.fmt.bufPrint(&buf,
        \\if(window.__craftMenuCallback)window.__craftMenuCallback('{s}');
    , .{item_id}) catch return;

    macos.tryEvalJS(js) catch |err| {
        log.err("Failed to trigger callback: {}", .{err});
    };
}
