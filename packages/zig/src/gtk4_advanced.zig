const std = @import("std");
const builtin = @import("builtin");

/// Advanced GTK4 features for Linux
/// Provides access to modern GTK4 widgets and features
/// Requires GTK 4.0 or later
pub const GTK4Error = error{
    PlatformNotSupported,
    InitializationFailed,
    WidgetCreationFailed,
    InvalidConfiguration,
};

/// GTK4 Application
pub const GTK4Application = struct {
    app_id: []const u8,
    platform_handle: ?*anyopaque = null,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, app_id: []const u8) !Self {
        if (builtin.target.os.tag != .linux) {
            return GTK4Error.PlatformNotSupported;
        }

        return Self{
            .app_id = try allocator.dupe(u8, app_id),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.app_id);
    }

    /// Activate the application
    pub fn activate(self: *Self) !void {
        if (builtin.target.os.tag != .linux) {
            return GTK4Error.PlatformNotSupported;
        }

        std.debug.print("[GTK4] Activating application: {s}\n", .{self.app_id});
        // Platform implementation would go here
        _ = self;
    }
};

/// GTK4 Adaptive Layout (Libadwaita)
pub const AdaptiveLayout = struct {
    /// Breakpoint for responsive design
    pub const Breakpoint = struct {
        min_width: u32,
        max_width: u32,
        layout: Layout,

        pub const Layout = enum {
            mobile,
            tablet,
            desktop,
        };
    };

    breakpoints: []const Breakpoint,
    current_layout: Breakpoint.Layout,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        const default_breakpoints = [_]Breakpoint{
            .{ .min_width = 0, .max_width = 600, .layout = .mobile },
            .{ .min_width = 601, .max_width = 1024, .layout = .tablet },
            .{ .min_width = 1025, .max_width = 9999, .layout = .desktop },
        };

        return Self{
            .breakpoints = &default_breakpoints,
            .current_layout = .desktop,
            .allocator = allocator,
        };
    }

    pub fn updateLayout(self: *Self, width: u32) void {
        for (self.breakpoints) |bp| {
            if (width >= bp.min_width and width <= bp.max_width) {
                self.current_layout = bp.layout;
                break;
            }
        }
    }

    pub fn getCurrentLayout(self: Self) Breakpoint.Layout {
        return self.current_layout;
    }
};

/// GTK4 Toast notification
pub const Toast = struct {
    title: []const u8,
    message: ?[]const u8 = null,
    priority: Priority = .normal,
    timeout: u32 = 3000, // milliseconds
    action_name: ?[]const u8 = null,
    action_label: ?[]const u8 = null,
    allocator: std.mem.Allocator,

    pub const Priority = enum {
        low,
        normal,
        high,
    };

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, title: []const u8) !Self {
        return Self{
            .title = try allocator.dupe(u8, title),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.title);
        if (self.message) |msg| self.allocator.free(msg);
        if (self.action_name) |name| self.allocator.free(name);
        if (self.action_label) |label| self.allocator.free(label);
    }

    pub fn setMessage(self: *Self, message: []const u8) !void {
        if (self.message) |old| self.allocator.free(old);
        self.message = try self.allocator.dupe(u8, message);
    }

    pub fn setAction(self: *Self, name: []const u8, label: []const u8) !void {
        if (self.action_name) |old| self.allocator.free(old);
        if (self.action_label) |old| self.allocator.free(old);
        self.action_name = try self.allocator.dupe(u8, name);
        self.action_label = try self.allocator.dupe(u8, label);
    }

    pub fn show(self: *Self) !void {
        if (builtin.target.os.tag != .linux) {
            return GTK4Error.PlatformNotSupported;
        }

        std.debug.print("[GTK4] Showing toast: {s}\n", .{self.title});
        if (self.message) |msg| {
            std.debug.print("[GTK4]   Message: {s}\n", .{msg});
        }
        // Platform implementation would go here
        _ = self;
    }
};

/// GTK4 Carousel widget
pub const Carousel = struct {
    items: std.ArrayList(*anyopaque),
    current_index: usize = 0,
    interactive: bool = true,
    spacing: u32 = 0,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .items = std.ArrayList(*anyopaque).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.items.deinit();
    }

    pub fn addItem(self: *Self, item: *anyopaque) !void {
        try self.items.append(item);
    }

    pub fn removeItem(self: *Self, index: usize) void {
        _ = self.items.orderedRemove(index);
        if (self.current_index >= self.items.items.len and self.items.items.len > 0) {
            self.current_index = self.items.items.len - 1;
        }
    }

    pub fn scrollTo(self: *Self, index: usize) void {
        if (index < self.items.items.len) {
            self.current_index = index;
            std.debug.print("[GTK4] Carousel scrolled to index {d}\n", .{index});
        }
    }

    pub fn next(self: *Self) void {
        if (self.current_index < self.items.items.len - 1) {
            self.current_index += 1;
            std.debug.print("[GTK4] Carousel next: {d}\n", .{self.current_index});
        }
    }

    pub fn previous(self: *Self) void {
        if (self.current_index > 0) {
            self.current_index -= 1;
            std.debug.print("[GTK4] Carousel previous: {d}\n", .{self.current_index});
        }
    }
};

/// GTK4 Banner widget
pub const Banner = struct {
    title: []const u8,
    button_label: ?[]const u8 = null,
    revealed: bool = false,
    use_markup: bool = false,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, title: []const u8) !Self {
        return Self{
            .title = try allocator.dupe(u8, title),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.title);
        if (self.button_label) |label| self.allocator.free(label);
    }

    pub fn setButton(self: *Self, label: []const u8) !void {
        if (self.button_label) |old| self.allocator.free(old);
        self.button_label = try self.allocator.dupe(u8, label);
    }

    pub fn reveal(self: *Self) void {
        self.revealed = true;
        std.debug.print("[GTK4] Banner revealed: {s}\n", .{self.title});
    }

    pub fn hide(self: *Self) void {
        self.revealed = false;
        std.debug.print("[GTK4] Banner hidden\n", .{});
    }
};

/// GTK4 Status Page (for empty states)
pub const StatusPage = struct {
    icon_name: ?[]const u8 = null,
    title: []const u8,
    description: ?[]const u8 = null,
    child_widget: ?*anyopaque = null,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, title: []const u8) !Self {
        return Self{
            .title = try allocator.dupe(u8, title),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.title);
        if (self.icon_name) |icon| self.allocator.free(icon);
        if (self.description) |desc| self.allocator.free(desc);
    }

    pub fn setIcon(self: *Self, icon_name: []const u8) !void {
        if (self.icon_name) |old| self.allocator.free(old);
        self.icon_name = try self.allocator.dupe(u8, icon_name);
    }

    pub fn setDescription(self: *Self, description: []const u8) !void {
        if (self.description) |old| self.allocator.free(old);
        self.description = try self.allocator.dupe(u8, description);
    }
};

/// GTK4 Preferences Window
pub const PreferencesWindow = struct {
    title: []const u8,
    search_enabled: bool = true,
    pages: std.ArrayList(PreferencesPage),
    allocator: std.mem.Allocator,

    pub const PreferencesPage = struct {
        name: []const u8,
        title: []const u8,
        icon_name: ?[]const u8 = null,
        groups: std.ArrayList(PreferencesGroup),
    };

    pub const PreferencesGroup = struct {
        title: ?[]const u8 = null,
        description: ?[]const u8 = null,
        rows: std.ArrayList(PreferencesRow),
    };

    pub const PreferencesRow = struct {
        title: []const u8,
        subtitle: ?[]const u8 = null,
        icon_name: ?[]const u8 = null,
        activatable: bool = true,
    };

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, title: []const u8) !Self {
        return Self{
            .title = try allocator.dupe(u8, title),
            .pages = std.ArrayList(PreferencesPage).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.title);
        for (self.pages.items) |*page| {
            self.allocator.free(page.name);
            self.allocator.free(page.title);
            if (page.icon_name) |icon| self.allocator.free(icon);
            for (page.groups.items) |*group| {
                if (group.title) |t| self.allocator.free(t);
                if (group.description) |d| self.allocator.free(d);
                for (group.rows.items) |*row| {
                    self.allocator.free(row.title);
                    if (row.subtitle) |s| self.allocator.free(s);
                    if (row.icon_name) |i| self.allocator.free(i);
                }
                group.rows.deinit();
            }
            page.groups.deinit();
        }
        self.pages.deinit();
    }

    pub fn addPage(self: *Self, name: []const u8, title: []const u8, icon_name: ?[]const u8) !void {
        const page = PreferencesPage{
            .name = try self.allocator.dupe(u8, name),
            .title = try self.allocator.dupe(u8, title),
            .icon_name = if (icon_name) |icon| try self.allocator.dupe(u8, icon) else null,
            .groups = std.ArrayList(PreferencesGroup).init(self.allocator),
        };
        try self.pages.append(page);
    }
};

/// GTK4 View Switcher (for navigation)
pub const ViewSwitcher = struct {
    policy: Policy = .auto,
    stack: ?*anyopaque = null,

    pub const Policy = enum {
        auto,
        narrow,
        wide,
    };

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn setStack(self: *Self, stack: *anyopaque) void {
        self.stack = stack;
    }

    pub fn setPolicy(self: *Self, policy: Policy) void {
        self.policy = policy;
        std.debug.print("[GTK4] ViewSwitcher policy set to: {s}\n", .{@tagName(policy)});
    }
};

/// GTK4 Clamp widget (for responsive layouts)
pub const Clamp = struct {
    maximum_size: u32 = 600,
    tightening_threshold: u32 = 400,
    child: ?*anyopaque = null,

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn setMaximumSize(self: *Self, size: u32) void {
        self.maximum_size = size;
    }

    pub fn setTighteningThreshold(self: *Self, threshold: u32) void {
        self.tightening_threshold = threshold;
    }

    pub fn setChild(self: *Self, child: *anyopaque) void {
        self.child = child;
    }
};

/// GTK4 Split Button
pub const SplitButton = struct {
    label: []const u8,
    icon_name: ?[]const u8 = null,
    menu_model: ?*anyopaque = null,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, label: []const u8) !Self {
        return Self{
            .label = try allocator.dupe(u8, label),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.label);
        if (self.icon_name) |icon| self.allocator.free(icon);
    }

    pub fn setIcon(self: *Self, icon_name: []const u8) !void {
        if (self.icon_name) |old| self.allocator.free(old);
        self.icon_name = try self.allocator.dupe(u8, icon_name);
    }

    pub fn setMenu(self: *Self, menu: *anyopaque) void {
        self.menu_model = menu;
    }
};

// Tests
test "GTK4 adaptive layout" {
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var layout = AdaptiveLayout.init(allocator);

    layout.updateLayout(500); // Mobile
    try std.testing.expectEqual(AdaptiveLayout.Breakpoint.Layout.mobile, layout.getCurrentLayout());

    layout.updateLayout(800); // Tablet
    try std.testing.expectEqual(AdaptiveLayout.Breakpoint.Layout.tablet, layout.getCurrentLayout());

    layout.updateLayout(1200); // Desktop
    try std.testing.expectEqual(AdaptiveLayout.Breakpoint.Layout.desktop, layout.getCurrentLayout());
}

test "GTK4 carousel" {
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var carousel = Carousel.init(allocator);
    defer carousel.deinit();

    const item1: *anyopaque = @ptrFromInt(1);
    const item2: *anyopaque = @ptrFromInt(2);

    try carousel.addItem(item1);
    try carousel.addItem(item2);

    try std.testing.expectEqual(@as(usize, 2), carousel.items.items.len);

    carousel.next();
    try std.testing.expectEqual(@as(usize, 1), carousel.current_index);

    carousel.previous();
    try std.testing.expectEqual(@as(usize, 0), carousel.current_index);
}

test "GTK4 toast" {
    if (builtin.target.os.tag != .linux) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var toast = try Toast.init(allocator, "Test Toast");
    defer toast.deinit();

    try toast.setMessage("This is a test message");
    try toast.setAction("undo", "Undo");

    try std.testing.expectEqualStrings("Test Toast", toast.title);
}
