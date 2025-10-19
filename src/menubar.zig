const std = @import("std");

/// Native Menubar Application Support
/// Provides system tray/menubar integration for macOS, Linux, and Windows

pub const MenubarApp = struct {
    title: []const u8,
    icon: ?[]const u8,
    tooltip: ?[]const u8,
    menu: ?*Menu,
    window: ?*Window,
    visible: bool,
    allocator: std.mem.Allocator,
    handle: ?*anyopaque,

    pub fn init(allocator: std.mem.Allocator, title: []const u8) !MenubarApp {
        return MenubarApp{
            .title = title,
            .icon = null,
            .tooltip = null,
            .menu = null,
            .window = null,
            .visible = true,
            .allocator = allocator,
            .handle = null,
        };
    }

    pub fn deinit(self: *MenubarApp) void {
        if (self.menu) |menu| {
            menu.deinit();
            self.allocator.destroy(menu);
        }
        _ = self;
    }

    pub fn setIcon(self: *MenubarApp, icon_path: []const u8) !void {
        self.icon = icon_path;
        // Platform-specific icon update
        const builtin = @import("builtin");
        switch (builtin.target.os.tag) {
            .macos => try updateMacOSIcon(self, icon_path),
            .linux => try updateLinuxIcon(self, icon_path),
            .windows => try updateWindowsIcon(self, icon_path),
            else => {},
        }
    }

    pub fn setTooltip(self: *MenubarApp, tooltip: []const u8) void {
        self.tooltip = tooltip;
    }

    pub fn setMenu(self: *MenubarApp, menu: *Menu) !void {
        self.menu = menu;
        // Platform-specific menu update
    }

    pub fn show(self: *MenubarApp) !void {
        self.visible = true;
        // Platform-specific show
    }

    pub fn hide(self: *MenubarApp) void {
        self.visible = false;
        // Platform-specific hide
    }

    pub fn setWindow(self: *MenubarApp, window: *Window) void {
        self.window = window;
    }

    pub fn showWindow(self: *MenubarApp) !void {
        if (self.window) |window| {
            window.show();
        }
    }

    pub fn hideWindow(self: *MenubarApp) void {
        if (self.window) |window| {
            window.hide();
        }
    }

    pub fn toggleWindow(self: *MenubarApp) !void {
        if (self.window) |window| {
            if (window.visible) {
                window.hide();
            } else {
                window.show();
            }
        }
    }

    fn updateMacOSIcon(self: *MenubarApp, icon_path: []const u8) !void {
        _ = self;
        _ = icon_path;
        // NSStatusBar implementation
    }

    fn updateLinuxIcon(self: *MenubarApp, icon_path: []const u8) !void {
        _ = self;
        _ = icon_path;
        // AppIndicator/StatusNotifier implementation
    }

    fn updateWindowsIcon(self: *MenubarApp, icon_path: []const u8) !void {
        _ = self;
        _ = icon_path;
        // System tray icon implementation
    }
};

pub const Menu = struct {
    items: std.ArrayList(MenuItem),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*Menu {
        const menu = try allocator.create(Menu);
        menu.* = Menu{
            .items = std.ArrayList(MenuItem).init(allocator),
            .allocator = allocator,
        };
        return menu;
    }

    pub fn deinit(self: *Menu) void {
        for (self.items.items) |*item| {
            item.deinit();
        }
        self.items.deinit();
    }

    pub fn addItem(self: *Menu, item: MenuItem) !void {
        try self.items.append(item);
    }

    pub fn addSeparator(self: *Menu) !void {
        try self.items.append(MenuItem{
            .label = "",
            .enabled = true,
            .checked = false,
            .icon = null,
            .shortcut = null,
            .submenu = null,
            .action = null,
            .separator = true,
            .allocator = self.allocator,
        });
    }

    pub fn removeItem(self: *Menu, index: usize) void {
        if (index < self.items.items.len) {
            var item = self.items.swapRemove(index);
            item.deinit();
        }
    }

    pub fn clear(self: *Menu) void {
        for (self.items.items) |*item| {
            item.deinit();
        }
        self.items.clearRetainingCapacity();
    }
};

pub const MenuItem = struct {
    label: []const u8,
    enabled: bool,
    checked: bool,
    icon: ?[]const u8,
    shortcut: ?Shortcut,
    submenu: ?*Menu,
    action: ?*const fn () void,
    separator: bool,
    allocator: std.mem.Allocator,

    pub const Shortcut = struct {
        key: []const u8,
        modifiers: Modifiers,

        pub const Modifiers = packed struct {
            ctrl: bool = false,
            alt: bool = false,
            shift: bool = false,
            meta: bool = false,
        };
    };

    pub fn init(allocator: std.mem.Allocator, label: []const u8, action: ?*const fn () void) MenuItem {
        return MenuItem{
            .label = label,
            .enabled = true,
            .checked = false,
            .icon = null,
            .shortcut = null,
            .submenu = null,
            .action = action,
            .separator = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MenuItem) void {
        if (self.submenu) |submenu| {
            submenu.deinit();
            self.allocator.destroy(submenu);
        }
    }

    pub fn setIcon(self: *MenuItem, icon: []const u8) void {
        self.icon = icon;
    }

    pub fn setShortcut(self: *MenuItem, shortcut: Shortcut) void {
        self.shortcut = shortcut;
    }

    pub fn setSubmenu(self: *MenuItem, submenu: *Menu) void {
        self.submenu = submenu;
    }

    pub fn setEnabled(self: *MenuItem, enabled: bool) void {
        self.enabled = enabled;
    }

    pub fn setChecked(self: *MenuItem, checked: bool) void {
        self.checked = checked;
    }

    pub fn trigger(self: *MenuItem) void {
        if (self.action) |action| {
            action();
        }
    }
};

pub const Window = struct {
    width: u32,
    height: u32,
    x: i32,
    y: i32,
    visible: bool,
    handle: ?*anyopaque,

    pub fn init(width: u32, height: u32) Window {
        return Window{
            .width = width,
            .height = height,
            .x = 0,
            .y = 0,
            .visible = false,
            .handle = null,
        };
    }

    pub fn show(self: *Window) void {
        self.visible = true;
        // Platform-specific show
    }

    pub fn hide(self: *Window) void {
        self.visible = false;
        // Platform-specific hide
    }

    pub fn setPosition(self: *Window, x: i32, y: i32) void {
        self.x = x;
        self.y = y;
    }

    pub fn setSize(self: *Window, width: u32, height: u32) void {
        self.width = width;
        self.height = height;
    }
};

/// Menubar App Builder
pub const MenubarBuilder = struct {
    title: []const u8,
    icon: ?[]const u8 = null,
    tooltip: ?[]const u8 = null,
    menu: ?*Menu = null,
    window: ?*Window = null,
    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, title: []const u8) MenubarBuilder {
        return MenubarBuilder{
            .title = title,
            .allocator = allocator,
        };
    }

    pub fn icon(self: MenubarBuilder, icon_path: []const u8) MenubarBuilder {
        var builder = self;
        builder.icon = icon_path;
        return builder;
    }

    pub fn tooltip(self: MenubarBuilder, text: []const u8) MenubarBuilder {
        var builder = self;
        builder.tooltip = text;
        return builder;
    }

    pub fn menu(self: MenubarBuilder, app_menu: *Menu) MenubarBuilder {
        var builder = self;
        builder.menu = app_menu;
        return builder;
    }

    pub fn window(self: MenubarBuilder, win: *Window) MenubarBuilder {
        var builder = self;
        builder.window = win;
        return builder;
    }

    pub fn build(self: MenubarBuilder) !MenubarApp {
        var app = try MenubarApp.init(self.allocator, self.title);

        if (self.icon) |icon_path| {
            try app.setIcon(icon_path);
        }

        if (self.tooltip) |text| {
            app.setTooltip(text);
        }

        if (self.menu) |app_menu| {
            try app.setMenu(app_menu);
        }

        if (self.window) |win| {
            app.setWindow(win);
        }

        return app;
    }
};

/// Platform-specific implementations

/// macOS NSStatusBar Integration
pub const MacOS = struct {
    pub const StatusItem = opaque {};

    pub fn createStatusItem(title: []const u8) !*StatusItem {
        _ = title;
        // NSStatusBar.systemStatusBar().statusItemWithLength:(NSStatusItemLength)
        return undefined;
    }

    pub fn setIcon(item: *StatusItem, icon_path: []const u8) !void {
        _ = item;
        _ = icon_path;
        // [statusItem.button setImage:[NSImage imageWithContentsOfFile:]]
    }

    pub fn setMenu(item: *StatusItem, menu: *Menu) !void {
        _ = item;
        _ = menu;
        // statusItem.menu = nsMenu
    }

    pub fn setTitle(item: *StatusItem, title: []const u8) void {
        _ = item;
        _ = title;
        // [statusItem.button setTitle:]
    }
};

/// Linux AppIndicator Integration
pub const Linux = struct {
    pub const Indicator = opaque {};

    pub fn createIndicator(id: []const u8, icon_path: []const u8) !*Indicator {
        _ = id;
        _ = icon_path;
        // app_indicator_new()
        return undefined;
    }

    pub fn setStatus(indicator: *Indicator, active: bool) void {
        _ = indicator;
        _ = active;
        // app_indicator_set_status()
    }

    pub fn setMenu(indicator: *Indicator, menu: *Menu) !void {
        _ = indicator;
        _ = menu;
        // app_indicator_set_menu()
    }

    pub fn setIcon(indicator: *Indicator, icon_path: []const u8) void {
        _ = indicator;
        _ = icon_path;
        // app_indicator_set_icon()
    }
};

/// Windows System Tray Integration
pub const Windows = struct {
    pub const TrayIcon = opaque {};

    pub fn createTrayIcon(hwnd: *anyopaque, icon_path: []const u8) !*TrayIcon {
        _ = hwnd;
        _ = icon_path;
        // Shell_NotifyIcon(NIM_ADD, &nid)
        return undefined;
    }

    pub fn setIcon(icon: *TrayIcon, icon_path: []const u8) !void {
        _ = icon;
        _ = icon_path;
        // Shell_NotifyIcon(NIM_MODIFY, &nid)
    }

    pub fn setTooltip(icon: *TrayIcon, tooltip: []const u8) void {
        _ = icon;
        _ = tooltip;
        // Set szTip in NOTIFYICONDATA
    }

    pub fn showBalloon(icon: *TrayIcon, title: []const u8, message: []const u8) void {
        _ = icon;
        _ = title;
        _ = message;
        // Shell_NotifyIcon(NIM_MODIFY, &nid) with NIF_INFO
    }
};

/// Menubar Notification System
pub const MenubarNotification = struct {
    title: []const u8,
    message: []const u8,
    icon: ?[]const u8,
    sound: bool,
    duration_ms: u64,

    pub fn init(title: []const u8, message: []const u8) MenubarNotification {
        return MenubarNotification{
            .title = title,
            .message = message,
            .icon = null,
            .sound = true,
            .duration_ms = 3000,
        };
    }

    pub fn show(self: MenubarNotification) !void {
        const builtin = @import("builtin");
        switch (builtin.target.os.tag) {
            .macos => try showMacOSNotification(self),
            .linux => try showLinuxNotification(self),
            .windows => try showWindowsNotification(self),
            else => {},
        }
    }

    fn showMacOSNotification(notification: MenubarNotification) !void {
        _ = notification;
        // NSUserNotificationCenter
    }

    fn showLinuxNotification(notification: MenubarNotification) !void {
        _ = notification;
        // libnotify
    }

    fn showWindowsNotification(notification: MenubarNotification) !void {
        _ = notification;
        // Shell_NotifyIcon with balloon
    }
};

/// Click Actions
pub const ClickAction = enum {
    left_click,
    right_click,
    double_click,
    middle_click,
};

pub const ClickHandler = *const fn (ClickAction) void;

/// Menubar App Manager
pub const MenubarManager = struct {
    apps: std.ArrayList(*MenubarApp),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MenubarManager {
        return MenubarManager{
            .apps = std.ArrayList(*MenubarApp).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MenubarManager) void {
        for (self.apps.items) |app| {
            app.deinit();
            self.allocator.destroy(app);
        }
        self.apps.deinit();
    }

    pub fn addApp(self: *MenubarManager, app: *MenubarApp) !void {
        try self.apps.append(app);
    }

    pub fn removeApp(self: *MenubarManager, app: *MenubarApp) void {
        for (self.apps.items, 0..) |a, i| {
            if (a == app) {
                _ = self.apps.swapRemove(i);
                app.deinit();
                self.allocator.destroy(app);
                break;
            }
        }
    }

    pub fn getApp(self: *MenubarManager, index: usize) ?*MenubarApp {
        if (index < self.apps.items.len) {
            return self.apps.items[index];
        }
        return null;
    }
};

/// Example Usage
pub const Example = struct {
    pub fn createBasicMenubarApp(allocator: std.mem.Allocator) !MenubarApp {
        // Create menu
        var menu = try Menu.init(allocator);

        const show_item = MenuItem.init(allocator, "Show Window", showWindow);
        try menu.addItem(show_item);

        try menu.addSeparator();

        const quit_item = MenuItem.init(allocator, "Quit", quit);
        try menu.addItem(quit_item);

        // Create menubar app
        const app = try MenubarBuilder.new(allocator, "My App")
            .icon("icon.png")
            .tooltip("My Menubar App")
            .menu(menu)
            .build();

        return app;
    }

    fn showWindow() void {
        std.debug.print("Show window\n", .{});
    }

    fn quit() void {
        std.debug.print("Quit\n", .{});
    }
};
