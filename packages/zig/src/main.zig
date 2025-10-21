const std = @import("std");
const builtin = @import("builtin");
const macos = if (builtin.os.tag == .macos) @import("macos.zig") else struct {};
const SystemTray = @import("tray.zig").SystemTray;
const BridgeAPI = @import("bridge_api.zig").BridgeAPI;
const Notifications = @import("notifications.zig").Notifications;
const Menu = @import("menu.zig").Menu;

// Re-export components
pub const components = @import("components.zig");
pub const Component = components.Component;
pub const ComponentProps = components.ComponentProps;
pub const Button = components.Button;
pub const TextInput = components.TextInput;
pub const Chart = components.Chart;
pub const MediaPlayer = components.MediaPlayer;
pub const CodeEditor = components.CodeEditor;
pub const Tabs = components.Tabs;
pub const Modal = components.Modal;
pub const ProgressBar = components.ProgressBar;
pub const Dropdown = components.Dropdown;
pub const Toast = components.Toast;
pub const ToastManager = components.ToastManager;
pub const TreeView = components.TreeView;
pub const DatePicker = components.DatePicker;
pub const DataGrid = components.DataGrid;
pub const Tooltip = components.Tooltip;
pub const Slider = components.Slider;
pub const Autocomplete = components.Autocomplete;
pub const ColorPicker = components.ColorPicker;

// Re-export platform types
pub const WindowStyle = if (builtin.os.tag == .macos) macos.WindowStyle else struct {
    frameless: bool = false,
    transparent: bool = false,
    always_on_top: bool = false,
    resizable: bool = true,
    closable: bool = true,
    miniaturizable: bool = true,
    fullscreen: bool = false,
    x: ?i32 = null,
    y: ?i32 = null,
    dark_mode: ?bool = null,
    enable_hot_reload: bool = false,
};

pub const Window = struct {
    title: []const u8,
    width: u32,
    height: u32,
    html: []const u8,
    native_handle: ?*anyopaque = null,

    const Self = @This();

    pub fn init(title: []const u8, width: u32, height: u32, html: []const u8) Self {
        return .{
            .title = title,
            .width = width,
            .height = height,
            .html = html,
        };
    }

    pub fn show(self: *Self) !void {
        switch (builtin.os.tag) {
            .macos => try self.showMacOS(),
            .linux => try self.showLinux(),
            .windows => try self.showWindows(),
            else => return error.UnsupportedPlatform,
        }
    }

    fn showMacOS(self: *Self) !void {
        if (builtin.os.tag == .macos) {
            const window = try macos.createWindow(self.title, self.width, self.height, self.html);
            self.native_handle = @ptrCast(window);
        } else {
            return error.UnsupportedPlatform;
        }
    }

    fn showLinux(self: *Self) !void {
        const linux = @import("linux.zig");
        const window = try linux.createWindow(self.title, self.width, self.height, self.html);
        self.native_handle = window;
    }

    fn showWindows(self: *Self) !void {
        const windows = @import("windows.zig");
        const window = try windows.createWindow(self.title, self.width, self.height, self.html);
        self.native_handle = window;
    }

    pub fn setHtml(self: *Self, html: []const u8) void {
        self.html = html;
    }

    pub fn eval(self: *Self, js: []const u8) !void {
        _ = self;
        _ = js;
        return error.NotImplemented;
    }

    pub fn deinit(self: *Self) void {
        if (self.native_handle) |handle| {
            // Platform-specific cleanup
            _ = handle;
        }
    }
};

pub const App = struct {
    allocator: std.mem.Allocator,
    windows: std.ArrayList(*Window),
    system_tray: ?*SystemTray = null,
    bridge: ?*BridgeAPI = null,
    notifications: ?*Notifications = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .windows = .{},
            .bridge = null,
            .notifications = null,
        };
    }

    /// Initialize platform-specific features (must be called before creating system tray on macOS)
    pub fn initPlatform(self: *Self) void {
        _ = self;
        switch (builtin.os.tag) {
            .macos => {
                if (builtin.os.tag == .macos) {
                    // Use regular init for now - will be configured based on system tray
                    macos.initAppWithoutLaunching();
                }
            },
            else => {},
        }
    }

    /// Initialize platform for system tray apps
    pub fn initPlatformForTray(self: *Self) void {
        _ = self;
        switch (builtin.os.tag) {
            .macos => {
                if (builtin.os.tag == .macos) {
                    macos.initAppForTray();
                }
            },
            else => {},
        }
    }

    pub fn createSystemTray(self: *Self, title: []const u8) !*SystemTray {
        const sys_tray = try self.allocator.create(SystemTray);
        sys_tray.* = SystemTray.init(self.allocator, title);
        try sys_tray.show();
        self.system_tray = sys_tray;
        return sys_tray;
    }

    pub fn createWindow(self: *Self, title: []const u8, width: u32, height: u32, html: []const u8) !*Window {
        const window = try self.allocator.create(Window);
        window.* = Window.init(title, width, height, html);
        try self.windows.append(self.allocator, window);
        return window;
    }

    pub fn createWindowWithURL(self: *Self, title: []const u8, width: u32, height: u32, url: []const u8, style: WindowStyle) !*Window {
        if (builtin.os.tag == .macos) {
            const native_window = try macos.createWindowWithURL(title, width, height, url, style);
            const window = try self.allocator.create(Window);
            window.* = Window.init(title, width, height, "");
            window.native_handle = @ptrCast(native_window);
            try self.windows.append(self.allocator, window);
            return window;
        } else {
            return error.UnsupportedPlatform;
        }
    }

    /// Show all windows without activating the app (for menubar apps)
    pub fn showWindows(self: *Self) void {
        switch (builtin.os.tag) {
            .macos => {
                if (builtin.os.tag == .macos) {
                    macos.showAllWindows();
                }
            },
            else => {
                for (self.windows.items) |window| {
                    window.show() catch {};
                }
            },
        }
    }

    pub fn run(self: *Self) !void {
        // Allow no windows if we have a system tray (menubar-only mode)
        if (self.windows.items.len == 0 and self.system_tray == null) {
            return error.NoWindows;
        }

        // DON'T show windows yet on macOS - they'll be shown after tray is created
        // On other platforms, show them now
        switch (builtin.os.tag) {
            .macos => {
                // Windows will be shown in runMacOS() after platform is ready
            },
            else => {
                for (self.windows.items) |window| {
                    try window.show();
                }
            },
        }

        // Platform-specific event loop
        switch (builtin.os.tag) {
            .macos => try self.runMacOS(),
            .linux => try self.runLinux(),
            .windows => try self.runWindows(),
            else => return error.UnsupportedPlatform,
        }
    }

    fn runMacOS(self: *Self) !void {
        if (builtin.os.tag == .macos) {
            // Show windows if we don't have a system tray
            // If we have a system tray, windows were already shown in the correct order
            // (after tray creation) by the caller
            if (self.system_tray == null) {
                macos.showAllWindows();
            }

            // Now run the event loop (which activates the app)
            macos.runApp();
        }
    }

    fn runLinux(self: *Self) !void {
        _ = self;
        const linux = @import("linux.zig");
        try linux.App.run();
    }

    fn runWindows(self: *Self) !void {
        _ = self;
        const windows = @import("windows.zig");
        try windows.App.run();
    }

    /// Initialize bridge API for JavaScript communication
    pub fn initBridge(self: *Self) !void {
        if (self.bridge == null) {
            const bridge = try self.allocator.create(BridgeAPI);
            bridge.* = BridgeAPI.init(self.allocator);
            self.bridge = bridge;
        }
    }

    /// Initialize notifications system
    pub fn initNotifications(self: *Self) !void {
        if (self.notifications == null) {
            const notif = try self.allocator.create(Notifications);
            notif.* = Notifications.init(self.allocator);
            self.notifications = notif;
        }
    }

    /// Send a notification
    pub fn notify(self: *Self, options: Notifications.NotificationOptions) !void {
        if (self.notifications == null) {
            try self.initNotifications();
        }
        if (self.notifications) |notif| {
            try notif.send(options);
        }
    }

    pub fn deinit(self: *Self) void {
        // Cleanup bridge
        if (self.bridge) |bridge| {
            bridge.deinit();
            self.allocator.destroy(bridge);
        }

        // Cleanup notifications
        if (self.notifications) |notif| {
            notif.deinit();
            self.allocator.destroy(notif);
        }

        // Cleanup system tray
        if (self.system_tray) |sys_tray| {
            sys_tray.deinit();
            self.allocator.destroy(sys_tray);
        }

        for (self.windows.items) |window| {
            window.deinit();
            self.allocator.destroy(window);
        }
        self.windows.deinit(self.allocator);
    }
};

test "create window" {
    const allocator = std.testing.allocator;
    var app = App.init(allocator);
    defer app.deinit();

    const window = try app.createWindow("Test Window", 800, 600, "<h1>Hello, World!</h1>");
    try std.testing.expectEqualStrings("Test Window", window.title);
    try std.testing.expect(window.width == 800);
    try std.testing.expect(window.height == 600);
}

test "set html" {
    const allocator = std.testing.allocator;
    var app = App.init(allocator);
    defer app.deinit();

    const window = try app.createWindow("Test", 800, 600, "<h1>Initial</h1>");
    window.setHtml("<h1>Updated</h1>");
    try std.testing.expectEqualStrings("<h1>Updated</h1>", window.html);
}
