const std = @import("std");
const builtin = @import("builtin");

// Only compile on Linux
pub const LinuxTray = if (builtin.os.tag == .linux) LinuxTrayImpl else struct {
    pub fn init(_: std.mem.Allocator, _: []const u8) !LinuxTray {
        return error.UnsupportedPlatform;
    }
    pub fn deinit(_: *LinuxTray) void {}
    pub fn setLabel(_: *LinuxTray, _: []const u8) !void {}
    pub fn setTooltip(_: *LinuxTray, _: []const u8) !void {}
};

const LinuxTrayImpl = if (builtin.os.tag == .linux) struct {
    // libappindicator3 types
    const AppIndicator = opaque {};
    const GtkMenu = opaque {};
    const GtkMenuItem = opaque {};
    const GtkWidget = opaque {};

    const AppIndicatorCategory = enum(c_int) {
        application = 0,
        communications = 1,
        system = 2,
        hardware = 3,
        other = 4,
    };

    const AppIndicatorStatus = enum(c_int) {
        passive = 0,
        active = 1,
        attention = 2,
    };

    // Function pointers (dynamically loaded)
    var libappindicator: ?*anyopaque = null;
    var libgtk: ?*anyopaque = null;
    var initialized = false;

    // AppIndicator function pointers
    var app_indicator_new: ?*const fn (
        id: [*:0]const u8,
        icon_name: [*:0]const u8,
        category: AppIndicatorCategory,
    ) callconv(.C) ?*AppIndicator = null;

    var app_indicator_set_status: ?*const fn (
        indicator: *AppIndicator,
        status: AppIndicatorStatus,
    ) callconv(.C) void = null;

    var app_indicator_set_menu: ?*const fn (
        indicator: *AppIndicator,
        menu: *GtkMenu,
    ) callconv(.C) void = null;

    var app_indicator_set_label: ?*const fn (
        indicator: *AppIndicator,
        label: [*:0]const u8,
        guide: [*:0]const u8,
    ) callconv(.C) void = null;

    var app_indicator_set_icon: ?*const fn (
        indicator: *AppIndicator,
        icon_name: [*:0]const u8,
    ) callconv(.C) void = null;

    // GTK function pointers
    var gtk_init: ?*const fn (argc: ?*c_int, argv: ?*[*][*:0]u8) callconv(.C) void = null;
    var gtk_menu_new: ?*const fn () callconv(.C) ?*GtkMenu = null;
    var gtk_menu_item_new_with_label: ?*const fn (label: [*:0]const u8) callconv(.C) ?*GtkMenuItem = null;
    var gtk_menu_shell_append: ?*const fn (shell: *GtkMenu, child: *GtkWidget) callconv(.C) void = null;
    var gtk_widget_show_all: ?*const fn (widget: *GtkWidget) callconv(.C) void = null;

    indicator: *AppIndicator,
    menu: *GtkMenu,
    allocator: std.mem.Allocator,

    fn loadLibraries() !void {
        if (initialized) return;

        // Try to load libappindicator3
        libappindicator = std.c.dlopen(
            "libappindicator3.so.1",
            std.c.RTLD.LAZY,
        ) orelse {
            // Try without version number
            libappindicator = std.c.dlopen(
                "libappindicator3.so",
                std.c.RTLD.LAZY,
            ) orelse return error.AppIndicatorNotFound;
        };

        // Try to load libgtk-3
        libgtk = std.c.dlopen(
            "libgtk-3.so.0",
            std.c.RTLD.LAZY,
        ) orelse {
            // Try without version number
            libgtk = std.c.dlopen(
                "libgtk-3.so",
                std.c.RTLD.LAZY,
            ) orelse return error.GtkNotFound;
        };

        // Load AppIndicator function pointers
        app_indicator_new = @ptrCast(@alignCast(std.c.dlsym(
            libappindicator,
            "app_indicator_new",
        ) orelse return error.SymbolNotFound));

        app_indicator_set_status = @ptrCast(@alignCast(std.c.dlsym(
            libappindicator,
            "app_indicator_set_status",
        ) orelse return error.SymbolNotFound));

        app_indicator_set_menu = @ptrCast(@alignCast(std.c.dlsym(
            libappindicator,
            "app_indicator_set_menu",
        ) orelse return error.SymbolNotFound));

        app_indicator_set_label = @ptrCast(@alignCast(std.c.dlsym(
            libappindicator,
            "app_indicator_set_label",
        ) orelse return error.SymbolNotFound));

        app_indicator_set_icon = @ptrCast(@alignCast(std.c.dlsym(
            libappindicator,
            "app_indicator_set_icon",
        ) orelse return error.SymbolNotFound));

        // Load GTK function pointers
        gtk_init = @ptrCast(@alignCast(std.c.dlsym(
            libgtk,
            "gtk_init",
        ) orelse return error.SymbolNotFound));

        gtk_menu_new = @ptrCast(@alignCast(std.c.dlsym(
            libgtk,
            "gtk_menu_new",
        ) orelse return error.SymbolNotFound));

        gtk_menu_item_new_with_label = @ptrCast(@alignCast(std.c.dlsym(
            libgtk,
            "gtk_menu_item_new_with_label",
        ) orelse return error.SymbolNotFound));

        gtk_menu_shell_append = @ptrCast(@alignCast(std.c.dlsym(
            libgtk,
            "gtk_menu_shell_append",
        ) orelse return error.SymbolNotFound));

        gtk_widget_show_all = @ptrCast(@alignCast(std.c.dlsym(
            libgtk,
            "gtk_widget_show_all",
        ) orelse return error.SymbolNotFound));

        // Initialize GTK
        gtk_init.?(null, null);

        initialized = true;
    }

    pub fn init(allocator: std.mem.Allocator, title: []const u8) !LinuxTrayImpl {
        try loadLibraries();

        // Create null-terminated strings
        const id = try allocator.dupeZ(u8, "zyte-app");
        defer allocator.free(id);

        const icon_name = try allocator.dupeZ(u8, "application-default-icon");
        defer allocator.free(icon_name);

        // Create indicator
        const indicator = app_indicator_new.?(
            id.ptr,
            icon_name.ptr,
            .application,
        ) orelse return error.FailedToCreateIndicator;

        // Create a basic menu (required by libappindicator)
        const menu = try createDefaultMenu(allocator);

        // Set menu
        app_indicator_set_menu.?(indicator, menu);

        // Create tray instance
        var tray = LinuxTrayImpl{
            .indicator = indicator,
            .menu = menu,
            .allocator = allocator,
        };

        // Set label
        try tray.setLabel(title);

        // Set status to active
        app_indicator_set_status.?(indicator, .active);

        return tray;
    }

    pub fn deinit(self: *LinuxTrayImpl) void {
        // Set to passive before cleanup
        app_indicator_set_status.?(self.indicator, .passive);
        // AppIndicator is managed by GTK, no manual cleanup needed
    }

    pub fn setLabel(self: *LinuxTrayImpl, label: []const u8) !void {
        const label_z = try self.allocator.dupeZ(u8, label);
        defer self.allocator.free(label_z);

        app_indicator_set_label.?(
            self.indicator,
            label_z.ptr,
            label_z.ptr, // guide (same as label)
        );
    }

    pub fn setTooltip(self: *LinuxTrayImpl, tooltip: []const u8) !void {
        // libappindicator doesn't have separate tooltip support
        // Tooltip is derived from label, so set the label instead
        try self.setLabel(tooltip);
    }

    pub fn setIcon(self: *LinuxTrayImpl, icon_path: []const u8) !void {
        const icon_z = try self.allocator.dupeZ(u8, icon_path);
        defer self.allocator.free(icon_z);

        app_indicator_set_icon.?(self.indicator, icon_z.ptr);
    }

    fn createDefaultMenu(allocator: std.mem.Allocator) !*GtkMenu {
        const menu = gtk_menu_new.?() orelse return error.FailedToCreateMenu;

        // Add a "Quit" menu item as a placeholder
        const quit_label = try allocator.dupeZ(u8, "Quit");
        defer allocator.free(quit_label);

        const menu_item = gtk_menu_item_new_with_label.?(quit_label.ptr) orelse {
            return error.FailedToCreateMenuItem;
        };

        gtk_menu_shell_append.?(menu, @ptrCast(menu_item));
        gtk_widget_show_all.?(@ptrCast(menu));

        return menu;
    }

    pub fn unloadLibraries() void {
        if (libappindicator) |lib| {
            std.c.dlclose(lib);
            libappindicator = null;
        }
        if (libgtk) |lib| {
            std.c.dlclose(lib);
            libgtk = null;
        }
        initialized = false;
    }
} else struct {};
