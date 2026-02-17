const std = @import("std");
const logging = @import("logging.zig");

const log = logging.scoped("Menubar");

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
            .items = .{},
            .allocator = allocator,
        };
        return menu;
    }

    pub fn deinit(self: *Menu) void {
        for (self.items.items) |*item| {
            item.deinit();
        }
        self.items.deinit(self.allocator);
    }

    pub fn addItem(self: *Menu, item: MenuItem) !void {
        try self.items.append(self.allocator, item);
    }

    pub fn addSeparator(self: *Menu) !void {
        try self.items.append(self.allocator, MenuItem{
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
    icon_path: ?[]const u8 = null,
    tooltip_text: ?[]const u8 = null,
    app_menu: ?*Menu = null,
    app_window: ?*Window = null,
    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, title: []const u8) MenubarBuilder {
        return MenubarBuilder{
            .title = title,
            .allocator = allocator,
        };
    }

    pub fn icon(self: MenubarBuilder, icon_path: []const u8) MenubarBuilder {
        var builder = self;
        builder.icon_path = icon_path;
        return builder;
    }

    pub fn tooltip(self: MenubarBuilder, text: []const u8) MenubarBuilder {
        var builder = self;
        builder.tooltip_text = text;
        return builder;
    }

    pub fn menu(self: MenubarBuilder, app_menu: *Menu) MenubarBuilder {
        var builder = self;
        builder.app_menu = app_menu;
        return builder;
    }

    pub fn window(self: MenubarBuilder, win: *Window) MenubarBuilder {
        var builder = self;
        builder.app_window = win;
        return builder;
    }

    pub fn build(self: MenubarBuilder) !MenubarApp {
        var app = try MenubarApp.init(self.allocator, self.title);

        if (self.icon_path) |icon_path| {
            try app.setIcon(icon_path);
        }

        if (self.tooltip_text) |text| {
            app.setTooltip(text);
        }

        if (self.app_menu) |app_menu| {
            try app.setMenu(app_menu);
        }

        if (self.app_window) |win| {
            app.setWindow(win);
        }

        return app;
    }
};

/// Platform-specific implementations
/// macOS NSStatusBar Integration
pub const MacOS = struct {
    const c = @cImport({
        @cInclude("objc/runtime.h");
        @cInclude("objc/message.h");
    });

    /// Opaque handle to NSStatusItem
    pub const StatusItem = struct {
        ns_status_item: ?*anyopaque,
        menu_handle: ?*anyopaque,
        allocator: std.mem.Allocator,
        click_callback: ?ClickHandler,
        title: []const u8,
        icon_path: ?[]const u8,
        tooltip: ?[]const u8,

        pub fn init(allocator: std.mem.Allocator, title: []const u8) !*StatusItem {
            const item = try allocator.create(StatusItem);
            item.* = StatusItem{
                .ns_status_item = null,
                .menu_handle = null,
                .allocator = allocator,
                .click_callback = null,
                .title = title,
                .icon_path = null,
                .tooltip = null,
            };

            // In a real implementation, we would call:
            // NSStatusBar* statusBar = [NSStatusBar systemStatusBar];
            // item.ns_status_item = [statusBar statusItemWithLength:NSVariableStatusItemLength];
            log.debug("macOS StatusItem created: {s}", .{title});

            return item;
        }

        pub fn deinit(self: *StatusItem) void {
            // In a real implementation:
            // [[NSStatusBar systemStatusBar] removeStatusItem:self.ns_status_item];
            log.debug("macOS StatusItem destroyed", .{});
            self.allocator.destroy(self);
        }

        pub fn setIcon(self: *StatusItem, icon_path: []const u8) !void {
            self.icon_path = icon_path;
            // In a real implementation:
            // NSImage* image = [[NSImage alloc] initWithContentsOfFile:@(icon_path)];
            // [self.ns_status_item.button setImage:image];
            log.debug("macOS StatusItem icon set: {s}", .{icon_path});
        }

        pub fn setTitle(self: *StatusItem, title: []const u8) void {
            // In a real implementation:
            // [self.ns_status_item.button setTitle:@(title)];
            _ = self;
            log.debug("macOS StatusItem title set: {s}", .{title});
        }

        pub fn setTooltip(self: *StatusItem, tooltip: []const u8) void {
            self.tooltip = tooltip;
            // In a real implementation:
            // [self.ns_status_item.button setToolTip:@(tooltip)];
            log.debug("macOS StatusItem tooltip set: {s}", .{tooltip});
        }

        pub fn setMenu(self: *StatusItem, menu: *Menu) !void {
            // Build NSMenu from our Menu struct
            const ns_menu = try buildNSMenu(self.allocator, menu);
            self.menu_handle = ns_menu;
            // In a real implementation:
            // self.ns_status_item.menu = ns_menu;
            log.debug("macOS StatusItem menu set with {} items", .{menu.items.items.len});
        }

        pub fn setClickCallback(self: *StatusItem, callback: ClickHandler) void {
            self.click_callback = callback;
            // In a real implementation, we would set up the target/action
        }

        pub fn show(self: *StatusItem) void {
            // In a real implementation:
            // [self.ns_status_item setVisible:YES];
            _ = self;
            log.debug("macOS StatusItem shown", .{});
        }

        pub fn hide(self: *StatusItem) void {
            // In a real implementation:
            // [self.ns_status_item setVisible:NO];
            _ = self;
            log.debug("macOS StatusItem hidden", .{});
        }

        fn buildNSMenu(allocator: std.mem.Allocator, menu: *Menu) !?*anyopaque {
            _ = allocator;
            // In a real implementation:
            // NSMenu* nsMenu = [[NSMenu alloc] init];
            // for each item in menu.items:
            //   NSMenuItem* nsItem = [[NSMenuItem alloc] initWithTitle:... action:@selector(menuAction:) keyEquivalent:@""];
            //   [nsMenu addItem:nsItem];
            _ = menu;
            return null;
        }
    };

    /// Send a notification using NSUserNotificationCenter
    pub fn sendNotification(title: []const u8, message: []const u8, icon_path: ?[]const u8) !void {
        // In a real implementation:
        // NSUserNotification* notification = [[NSUserNotification alloc] init];
        // notification.title = @(title);
        // notification.informativeText = @(message);
        // if (icon_path) notification.contentImage = [[NSImage alloc] initWithContentsOfFile:@(icon_path)];
        // [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
        _ = icon_path;
        log.debug("macOS notification: {s} - {s}", .{ title, message });
    }

    /// Get the system status bar
    pub fn getSystemStatusBar() ?*anyopaque {
        // In a real implementation:
        // return [NSStatusBar systemStatusBar];
        return null;
    }
};

/// Linux AppIndicator Integration
/// Uses libappindicator3 or StatusNotifierItem (SNI) protocol
pub const Linux = struct {
    /// Status for the indicator
    pub const IndicatorStatus = enum(c_int) {
        passive = 0,
        active = 1,
        attention = 2,
    };

    /// Category for the indicator
    pub const IndicatorCategory = enum(c_int) {
        application_status = 0,
        communications = 1,
        system_services = 2,
        hardware = 3,
        other = 4,
    };

    /// AppIndicator handle
    pub const Indicator = struct {
        app_indicator: ?*anyopaque,
        gtk_menu: ?*anyopaque,
        allocator: std.mem.Allocator,
        id: []const u8,
        icon_name: []const u8,
        icon_theme_path: ?[]const u8,
        title: ?[]const u8,
        status: IndicatorStatus,
        category: IndicatorCategory,
        click_callback: ?ClickHandler,

        pub fn init(allocator: std.mem.Allocator, id: []const u8, icon_name: []const u8, category: IndicatorCategory) !*Indicator {
            const indicator = try allocator.create(Indicator);
            indicator.* = Indicator{
                .app_indicator = null,
                .gtk_menu = null,
                .allocator = allocator,
                .id = id,
                .icon_name = icon_name,
                .icon_theme_path = null,
                .title = null,
                .status = .passive,
                .category = category,
                .click_callback = null,
            };

            // In a real implementation:
            // AppIndicator* app = app_indicator_new(id, icon_name, category);
            // indicator.app_indicator = app;
            log.debug("Linux AppIndicator created: {s}", .{id});

            return indicator;
        }

        pub fn deinit(self: *Indicator) void {
            // In a real implementation:
            // g_object_unref(self.app_indicator);
            // if (self.gtk_menu) g_object_unref(self.gtk_menu);
            log.debug("Linux AppIndicator destroyed: {s}", .{self.id});
            self.allocator.destroy(self);
        }

        pub fn setStatus(self: *Indicator, status: IndicatorStatus) void {
            self.status = status;
            // In a real implementation:
            // app_indicator_set_status(self.app_indicator, status);
            log.debug("Linux AppIndicator status set: {}", .{@intFromEnum(status)});
        }

        pub fn setIcon(self: *Indicator, icon_name: []const u8) void {
            _ = self;
            // In a real implementation:
            // app_indicator_set_icon(self.app_indicator, icon_name);
            log.debug("Linux AppIndicator icon set: {s}", .{icon_name});
        }

        pub fn setIconThemePath(self: *Indicator, path: []const u8) void {
            self.icon_theme_path = path;
            // In a real implementation:
            // app_indicator_set_icon_theme_path(self.app_indicator, path);
            log.debug("Linux AppIndicator icon theme path set: {s}", .{path});
        }

        pub fn setTitle(self: *Indicator, title: []const u8) void {
            self.title = title;
            // In a real implementation:
            // app_indicator_set_title(self.app_indicator, title);
            log.debug("Linux AppIndicator title set: {s}", .{title});
        }

        pub fn setAttentionIcon(self: *Indicator, icon_name: []const u8) void {
            _ = self;
            // In a real implementation:
            // app_indicator_set_attention_icon(self.app_indicator, icon_name);
            log.debug("Linux AppIndicator attention icon set: {s}", .{icon_name});
        }

        pub fn setMenu(self: *Indicator, menu: *Menu) !void {
            // Build GtkMenu from our Menu struct
            const gtk_menu = try buildGtkMenu(self.allocator, menu);
            self.gtk_menu = gtk_menu;
            // In a real implementation:
            // app_indicator_set_menu(self.app_indicator, GTK_MENU(gtk_menu));
            log.debug("Linux AppIndicator menu set with {} items", .{menu.items.items.len});
        }

        pub fn setSecondaryActivateTarget(self: *Indicator, callback: ClickHandler) void {
            self.click_callback = callback;
            // In a real implementation:
            // g_signal_connect(self.app_indicator, "secondary-activate", G_CALLBACK(...), self);
        }

        fn buildGtkMenu(allocator: std.mem.Allocator, menu: *Menu) !?*anyopaque {
            _ = allocator;
            // In a real implementation using GTK:
            // GtkWidget* gtk_menu = gtk_menu_new();
            // for each item in menu.items:
            //   GtkWidget* gtk_item = gtk_menu_item_new_with_label(item.label);
            //   g_signal_connect(gtk_item, "activate", G_CALLBACK(on_menu_item_activate), item);
            //   gtk_menu_shell_append(GTK_MENU_SHELL(gtk_menu), gtk_item);
            // gtk_widget_show_all(gtk_menu);
            _ = menu;
            return null;
        }
    };

    /// Send a notification using libnotify
    pub fn sendNotification(title: []const u8, message: []const u8, icon: ?[]const u8) !void {
        // In a real implementation:
        // notify_init("app");
        // NotifyNotification* n = notify_notification_new(title, message, icon);
        // notify_notification_show(n, NULL);
        // g_object_unref(n);
        _ = icon;
        log.debug("Linux notification: {s} - {s}", .{ title, message });
    }

    /// Initialize GTK (required before using AppIndicator)
    pub fn initGtk() void {
        // In a real implementation:
        // gtk_init(NULL, NULL);
        log.debug("GTK initialized", .{});
    }

    /// Run GTK main loop
    pub fn runMainLoop() void {
        // In a real implementation:
        // gtk_main();
        log.debug("GTK main loop started", .{});
    }

    /// Quit GTK main loop
    pub fn quitMainLoop() void {
        // In a real implementation:
        // gtk_main_quit();
        log.debug("GTK main loop quit", .{});
    }
};

/// Windows System Tray Integration
/// Uses Shell_NotifyIcon API for system tray icons
pub const Windows = struct {
    /// Notification icon flags
    pub const NotifyIconFlags = packed struct(u32) {
        message: bool = false,
        icon: bool = false,
        tip: bool = false,
        state: bool = false,
        info: bool = false,
        guid: bool = false,
        realtime: bool = false,
        showtip: bool = false,
        _padding: u24 = 0,
    };

    /// Balloon icon types
    pub const BalloonIconType = enum(u32) {
        none = 0,
        info = 1,
        warning = 2,
        @"error" = 3,
        user = 4,
    };

    /// System tray icon handle
    pub const TrayIcon = struct {
        hwnd: ?*anyopaque,
        icon_id: u32,
        callback_message: u32,
        icon_handle: ?*anyopaque,
        allocator: std.mem.Allocator,
        tooltip: [128]u8,
        tooltip_len: usize,
        visible: bool,
        menu: ?*Menu,
        click_callback: ?ClickHandler,

        pub fn init(allocator: std.mem.Allocator, hwnd: ?*anyopaque, icon_id: u32) !*TrayIcon {
            const tray = try allocator.create(TrayIcon);
            tray.* = TrayIcon{
                .hwnd = hwnd,
                .icon_id = icon_id,
                .callback_message = 0x8000 + icon_id, // WM_APP + icon_id
                .icon_handle = null,
                .allocator = allocator,
                .tooltip = [_]u8{0} ** 128,
                .tooltip_len = 0,
                .visible = false,
                .menu = null,
                .click_callback = null,
            };

            // In a real implementation:
            // NOTIFYICONDATA nid = {0};
            // nid.cbSize = sizeof(NOTIFYICONDATA);
            // nid.hWnd = hwnd;
            // nid.uID = icon_id;
            // nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
            // nid.uCallbackMessage = callback_message;
            // Shell_NotifyIcon(NIM_ADD, &nid);
            log.debug("Windows TrayIcon created with ID: {}", .{icon_id});

            return tray;
        }

        pub fn deinit(self: *TrayIcon) void {
            if (self.visible) {
                self.remove();
            }
            log.debug("Windows TrayIcon destroyed", .{});
            self.allocator.destroy(self);
        }

        pub fn add(self: *TrayIcon) !void {
            // In a real implementation:
            // NOTIFYICONDATA nid = {0};
            // nid.cbSize = sizeof(NOTIFYICONDATA);
            // nid.hWnd = self.hwnd;
            // nid.uID = self.icon_id;
            // nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
            // nid.uCallbackMessage = self.callback_message;
            // nid.hIcon = self.icon_handle;
            // memcpy(nid.szTip, self.tooltip, self.tooltip_len);
            // Shell_NotifyIcon(NIM_ADD, &nid);
            self.visible = true;
            log.debug("Windows TrayIcon added to system tray", .{});
        }

        pub fn remove(self: *TrayIcon) void {
            // In a real implementation:
            // NOTIFYICONDATA nid = {0};
            // nid.cbSize = sizeof(NOTIFYICONDATA);
            // nid.hWnd = self.hwnd;
            // nid.uID = self.icon_id;
            // Shell_NotifyIcon(NIM_DELETE, &nid);
            self.visible = false;
            log.debug("Windows TrayIcon removed from system tray", .{});
        }

        pub fn setIcon(self: *TrayIcon, icon_handle: ?*anyopaque) !void {
            self.icon_handle = icon_handle;
            if (self.visible) {
                // In a real implementation:
                // NOTIFYICONDATA nid = {0};
                // nid.cbSize = sizeof(NOTIFYICONDATA);
                // nid.hWnd = self.hwnd;
                // nid.uID = self.icon_id;
                // nid.uFlags = NIF_ICON;
                // nid.hIcon = icon_handle;
                // Shell_NotifyIcon(NIM_MODIFY, &nid);
            }
            log.debug("Windows TrayIcon icon updated", .{});
        }

        pub fn setIconFromPath(self: *TrayIcon, icon_path: []const u8) !void {
            // In a real implementation:
            // HICON hIcon = (HICON)LoadImage(NULL, icon_path, IMAGE_ICON, 0, 0, LR_LOADFROMFILE);
            // self.setIcon(hIcon);
            _ = self;
            log.debug("Windows TrayIcon icon loaded from: {s}", .{icon_path});
        }

        pub fn setTooltip(self: *TrayIcon, tooltip: []const u8) void {
            const len = @min(tooltip.len, 127);
            @memcpy(self.tooltip[0..len], tooltip[0..len]);
            self.tooltip[len] = 0;
            self.tooltip_len = len;

            if (self.visible) {
                // In a real implementation:
                // NOTIFYICONDATA nid = {0};
                // nid.cbSize = sizeof(NOTIFYICONDATA);
                // nid.hWnd = self.hwnd;
                // nid.uID = self.icon_id;
                // nid.uFlags = NIF_TIP;
                // memcpy(nid.szTip, tooltip, len);
                // Shell_NotifyIcon(NIM_MODIFY, &nid);
            }
            log.debug("Windows TrayIcon tooltip set: {s}", .{tooltip});
        }

        pub fn showBalloon(self: *TrayIcon, title: []const u8, message: []const u8, icon_type: BalloonIconType, timeout_ms: u32) void {
            _ = timeout_ms;
            _ = self;
            // In a real implementation:
            // NOTIFYICONDATA nid = {0};
            // nid.cbSize = sizeof(NOTIFYICONDATA);
            // nid.hWnd = self.hwnd;
            // nid.uID = self.icon_id;
            // nid.uFlags = NIF_INFO;
            // nid.dwInfoFlags = icon_type;
            // nid.uTimeout = timeout_ms;
            // memcpy(nid.szInfoTitle, title, min(title.len, 63));
            // memcpy(nid.szInfo, message, min(message.len, 255));
            // Shell_NotifyIcon(NIM_MODIFY, &nid);
            log.debug("Windows balloon notification: [{s}] {s} - {s}", .{ @tagName(icon_type), title, message });
        }

        pub fn hideBalloon(self: *TrayIcon) void {
            _ = self;
            // In a real implementation:
            // NOTIFYICONDATA nid = {0};
            // nid.cbSize = sizeof(NOTIFYICONDATA);
            // nid.hWnd = self.hwnd;
            // nid.uID = self.icon_id;
            // nid.uFlags = NIF_INFO;
            // nid.szInfo[0] = 0;
            // Shell_NotifyIcon(NIM_MODIFY, &nid);
            log.debug("Windows balloon notification hidden", .{});
        }

        pub fn setMenu(self: *TrayIcon, menu: *Menu) void {
            self.menu = menu;
            log.debug("Windows TrayIcon menu set with {} items", .{menu.items.items.len});
        }

        pub fn showContextMenu(self: *TrayIcon, x: i32, y: i32) void {
            if (self.menu == null) return;
            // In a real implementation:
            // HMENU hMenu = buildWindowsMenu(self.menu);
            // SetForegroundWindow(self.hwnd);
            // TrackPopupMenu(hMenu, TPM_BOTTOMALIGN | TPM_LEFTALIGN, x, y, 0, self.hwnd, NULL);
            // PostMessage(self.hwnd, WM_NULL, 0, 0);
            // DestroyMenu(hMenu);
            log.debug("Windows context menu shown at ({}, {})", .{ x, y });
        }

        pub fn setClickCallback(self: *TrayIcon, callback: ClickHandler) void {
            self.click_callback = callback;
        }

        /// Process window message for tray icon events
        pub fn processMessage(self: *TrayIcon, message: u32, lparam: usize) void {
            if (message != self.callback_message) return;

            const click_type: ClickAction = switch (lparam) {
                0x0201 => .left_click, // WM_LBUTTONDOWN
                0x0203 => .double_click, // WM_LBUTTONDBLCLK
                0x0204 => .right_click, // WM_RBUTTONDOWN
                0x0207 => .middle_click, // WM_MBUTTONDOWN
                else => return,
            };

            if (self.click_callback) |callback| {
                callback(click_type);
            }
        }
    };

    /// Load an icon from a resource or file
    pub fn loadIcon(path: []const u8) ?*anyopaque {
        // In a real implementation:
        // return LoadImage(NULL, path, IMAGE_ICON, 0, 0, LR_LOADFROMFILE);
        _ = path;
        return null;
    }

    /// Send a Windows notification toast (Windows 10+)
    pub fn sendToastNotification(title: []const u8, message: []const u8, app_id: []const u8) !void {
        // In a real implementation using WinRT:
        // ToastNotificationManager::CreateToastNotifier(app_id)->Show(toast);
        _ = app_id;
        log.debug("Windows toast notification: {s} - {s}", .{ title, message });
    }

    /// Build Windows HMENU from our Menu struct
    fn buildWindowsMenu(menu: *Menu) ?*anyopaque {
        // In a real implementation:
        // HMENU hMenu = CreatePopupMenu();
        // for each item in menu.items:
        //   if (item.separator) AppendMenu(hMenu, MF_SEPARATOR, 0, NULL);
        //   else AppendMenu(hMenu, MF_STRING, item_id, item.label);
        // return hMenu;
        _ = menu;
        return null;
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
            .apps = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MenubarManager) void {
        for (self.apps.items) |app| {
            app.deinit();
            self.allocator.destroy(app);
        }
        self.apps.deinit(self.allocator);
    }

    pub fn addApp(self: *MenubarManager, app: *MenubarApp) !void {
        try self.apps.append(self.allocator, app);
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
        log.debug("Show window", .{});
    }

    fn quit() void {
        log.debug("Quit", .{});
    }
};

// ============================================================================
// Tests
// ============================================================================

test "menubar app creation" {
    const allocator = std.testing.allocator;
    var app = try MenubarApp.init(allocator, "Test App");
    defer app.deinit();

    try std.testing.expectEqualStrings("Test App", app.title);
    try std.testing.expect(app.visible);
    try std.testing.expect(app.menu == null);
}

test "menu creation and items" {
    const allocator = std.testing.allocator;
    var menu = try Menu.init(allocator);
    defer {
        menu.deinit();
        allocator.destroy(menu);
    }

    try menu.addItem(MenuItem.init(allocator, "Item 1", null));
    try menu.addItem(MenuItem.init(allocator, "Item 2", null));
    try menu.addSeparator();
    try menu.addItem(MenuItem.init(allocator, "Item 3", null));

    try std.testing.expectEqual(@as(usize, 4), menu.items.items.len);

    // Check separator
    try std.testing.expect(menu.items.items[2].separator);
}

test "menu item properties" {
    const allocator = std.testing.allocator;
    var item = MenuItem.init(allocator, "Test Item", null);
    defer item.deinit();

    try std.testing.expectEqualStrings("Test Item", item.label);
    try std.testing.expect(item.enabled);
    try std.testing.expect(!item.checked);
    try std.testing.expect(!item.separator);

    item.setEnabled(false);
    try std.testing.expect(!item.enabled);

    item.setChecked(true);
    try std.testing.expect(item.checked);

    item.setIcon("icon.png");
    try std.testing.expectEqualStrings("icon.png", item.icon.?);
}

test "menu item shortcut" {
    const allocator = std.testing.allocator;
    var item = MenuItem.init(allocator, "Copy", null);
    defer item.deinit();

    item.setShortcut(.{
        .key = "C",
        .modifiers = .{ .ctrl = true },
    });

    try std.testing.expect(item.shortcut != null);
    try std.testing.expectEqualStrings("C", item.shortcut.?.key);
    try std.testing.expect(item.shortcut.?.modifiers.ctrl);
    try std.testing.expect(!item.shortcut.?.modifiers.shift);
}

test "menubar builder" {
    const allocator = std.testing.allocator;

    var menu = try Menu.init(allocator);
    try menu.addItem(MenuItem.init(allocator, "Quit", null));

    var app = try MenubarBuilder.new(allocator, "Builder App")
        .icon("app_icon.png")
        .tooltip("Tooltip text")
        .menu(menu)
        .build();
    defer app.deinit();

    try std.testing.expectEqualStrings("Builder App", app.title);
    try std.testing.expectEqualStrings("app_icon.png", app.icon.?);
    try std.testing.expectEqualStrings("Tooltip text", app.tooltip.?);
    try std.testing.expect(app.menu != null);
}

test "window operations" {
    var window = Window.init(800, 600);

    try std.testing.expectEqual(@as(u32, 800), window.width);
    try std.testing.expectEqual(@as(u32, 600), window.height);
    try std.testing.expect(!window.visible);

    window.show();
    try std.testing.expect(window.visible);

    window.hide();
    try std.testing.expect(!window.visible);

    window.setPosition(100, 200);
    try std.testing.expectEqual(@as(i32, 100), window.x);
    try std.testing.expectEqual(@as(i32, 200), window.y);

    window.setSize(1024, 768);
    try std.testing.expectEqual(@as(u32, 1024), window.width);
    try std.testing.expectEqual(@as(u32, 768), window.height);
}

test "menubar notification" {
    var notification = MenubarNotification.init("Test Title", "Test Message");

    try std.testing.expectEqualStrings("Test Title", notification.title);
    try std.testing.expectEqualStrings("Test Message", notification.message);
    try std.testing.expect(notification.sound);
    try std.testing.expectEqual(@as(u64, 3000), notification.duration_ms);
}

test "macOS status item creation" {
    const allocator = std.testing.allocator;
    var item = try MacOS.StatusItem.init(allocator, "Test App");
    defer item.deinit();

    try std.testing.expectEqualStrings("Test App", item.title);
    try std.testing.expect(item.icon_path == null);
    try std.testing.expect(item.tooltip == null);

    try item.setIcon("icon.png");
    try std.testing.expectEqualStrings("icon.png", item.icon_path.?);

    item.setTooltip("Test tooltip");
    try std.testing.expectEqualStrings("Test tooltip", item.tooltip.?);
}

test "linux indicator creation" {
    const allocator = std.testing.allocator;
    var indicator = try Linux.Indicator.init(allocator, "test-app", "test-icon", .application_status);
    defer indicator.deinit();

    try std.testing.expectEqualStrings("test-app", indicator.id);
    try std.testing.expectEqualStrings("test-icon", indicator.icon_name);
    try std.testing.expectEqual(Linux.IndicatorStatus.passive, indicator.status);
    try std.testing.expectEqual(Linux.IndicatorCategory.application_status, indicator.category);

    indicator.setStatus(.active);
    try std.testing.expectEqual(Linux.IndicatorStatus.active, indicator.status);

    indicator.setTitle("Test Title");
    try std.testing.expectEqualStrings("Test Title", indicator.title.?);
}

test "windows tray icon creation" {
    const allocator = std.testing.allocator;
    var tray = try Windows.TrayIcon.init(allocator, null, 1);
    defer tray.deinit();

    try std.testing.expectEqual(@as(u32, 1), tray.icon_id);
    try std.testing.expect(!tray.visible);
    try std.testing.expectEqual(@as(usize, 0), tray.tooltip_len);

    try tray.add();
    try std.testing.expect(tray.visible);

    tray.setTooltip("Test Tooltip");
    try std.testing.expectEqual(@as(usize, 12), tray.tooltip_len);
    try std.testing.expectEqualStrings("Test Tooltip", tray.tooltip[0..12]);

    tray.remove();
    try std.testing.expect(!tray.visible);
}

test "windows balloon icon types" {
    try std.testing.expectEqual(@as(u32, 0), @intFromEnum(Windows.BalloonIconType.none));
    try std.testing.expectEqual(@as(u32, 1), @intFromEnum(Windows.BalloonIconType.info));
    try std.testing.expectEqual(@as(u32, 2), @intFromEnum(Windows.BalloonIconType.warning));
    try std.testing.expectEqual(@as(u32, 3), @intFromEnum(Windows.BalloonIconType.@"error"));
    try std.testing.expectEqual(@as(u32, 4), @intFromEnum(Windows.BalloonIconType.user));
}

test "click action types" {
    const left = ClickAction.left_click;
    const right = ClickAction.right_click;
    const double = ClickAction.double_click;
    const middle = ClickAction.middle_click;

    try std.testing.expect(left != right);
    try std.testing.expect(double != middle);
}

test "menubar manager" {
    const allocator = std.testing.allocator;
    var manager = MenubarManager.init(allocator);
    defer manager.deinit();

    try std.testing.expectEqual(@as(usize, 0), manager.apps.items.len);
    try std.testing.expect(manager.getApp(0) == null);
}

test "submenu support" {
    const allocator = std.testing.allocator;
    var parent_menu = try Menu.init(allocator);
    defer {
        parent_menu.deinit();
        allocator.destroy(parent_menu);
    }

    var submenu = try Menu.init(allocator);
    try submenu.addItem(MenuItem.init(allocator, "Sub Item 1", null));
    try submenu.addItem(MenuItem.init(allocator, "Sub Item 2", null));

    var parent_item = MenuItem.init(allocator, "Parent", null);
    parent_item.setSubmenu(submenu);

    try parent_menu.addItem(parent_item);

    try std.testing.expect(parent_menu.items.items[0].submenu != null);
    try std.testing.expectEqual(@as(usize, 2), parent_menu.items.items[0].submenu.?.items.items.len);
}
