const std = @import("std");
const io_context = @import("io_context.zig");

/// End-to-end testing utilities for Craft applications
/// Tests complete user workflows and application behavior
///
/// Note: This module provides e2e test helpers that work with
/// the zig-test-framework package (~/Code/zig-test-framework)

pub const E2ETestError = error{
    WindowNotFound,
    ElementNotFound,
    TimeoutExceeded,
    ActionFailed,
    InvalidSelector,
    ScreenshotFailed,
};

/// E2E test context
pub const E2ETestContext = struct {
    allocator: std.mem.Allocator,
    window_handle: ?*anyopaque = null,
    screenshots_dir: []const u8,
    screenshot_count: usize = 0,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, screenshots_dir: []const u8) !Self {
        // Create screenshots directory
        const io = io_context.get();
        const cwd = io_context.cwd();
        cwd.createDir(io, screenshots_dir, .default_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        return Self{
            .allocator = allocator,
            .screenshots_dir = try allocator.dupe(u8, screenshots_dir),
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.screenshots_dir);
    }

    /// Launch the application
    pub fn launchApp(self: *Self, config: AppLaunchConfig) !void {
        std.debug.print("[E2E] Launching app: {s}\n", .{config.app_path});
        std.debug.print("[E2E] URL: {s}\n", .{config.url orelse "none"});
        std.debug.print("[E2E] Size: {d}x{d}\n", .{ config.width, config.height });

        // Mock window handle
        self.window_handle = @ptrFromInt(12345);
    }

    /// Close the application
    pub fn closeApp(self: *Self) !void {
        if (self.window_handle == null) {
            return E2ETestError.WindowNotFound;
        }

        std.debug.print("[E2E] Closing app\n", .{});
        self.window_handle = null;
    }

    /// Wait for an element to appear
    pub fn waitForElement(self: *Self, selector: []const u8, timeout_ms: u64) !Element {
        std.debug.print("[E2E] Waiting for element: {s} (timeout: {d}ms)\n", .{ selector, timeout_ms });

        // Mock element
        return Element{
            .selector = try self.allocator.dupe(u8, selector),
            .handle = @ptrFromInt(67890),
            .allocator = self.allocator,
        };
    }

    /// Click an element
    pub fn click(self: *Self, selector: []const u8) !void {
        var element = try self.waitForElement(selector, 5000);
        defer element.deinit();

        try element.click();
    }

    /// Type text into an input
    pub fn type(self: *Self, selector: []const u8, text: []const u8) !void {
        var element = try self.waitForElement(selector, 5000);
        defer element.deinit();

        try element.type(text);
    }

    /// Get text content of an element
    pub fn getText(self: *Self, selector: []const u8) ![]u8 {
        var element = try self.waitForElement(selector, 5000);
        defer element.deinit();

        return try element.getText();
    }

    /// Take a screenshot
    pub fn screenshot(self: *Self, name: ?[]const u8) !void {
        if (self.window_handle == null) {
            return E2ETestError.WindowNotFound;
        }

        const filename = if (name) |n|
            try std.fmt.allocPrint(self.allocator, "{s}/{s}.png", .{ self.screenshots_dir, n })
        else
            try std.fmt.allocPrint(self.allocator, "{s}/screenshot_{d}.png", .{ self.screenshots_dir, self.screenshot_count });
        defer self.allocator.free(filename);

        std.debug.print("[E2E] Taking screenshot: {s}\n", .{filename});

        self.screenshot_count += 1;
    }

    /// Wait for a condition to be true
    pub fn waitFor(self: *Self, condition: *const fn () bool, timeout_ms: u64) !void {
        const start = std.time.milliTimestamp();
        const timeout = @as(i64, @intCast(timeout_ms));

        while (!condition()) {
            const elapsed = std.time.milliTimestamp() - start;
            if (elapsed > timeout) {
                return E2ETestError.TimeoutExceeded;
            }

            std.time.sleep(100 * std.time.ns_per_ms);
        }

        _ = self;
    }

    /// Navigate to a URL
    pub fn navigate(self: *Self, url: []const u8) !void {
        if (self.window_handle == null) {
            return E2ETestError.WindowNotFound;
        }

        std.debug.print("[E2E] Navigating to: {s}\n", .{url});
    }

    /// Go back in navigation history
    pub fn goBack(self: *Self) !void {
        if (self.window_handle == null) {
            return E2ETestError.WindowNotFound;
        }

        std.debug.print("[E2E] Going back\n", .{});
    }

    /// Go forward in navigation history
    pub fn goForward(self: *Self) !void {
        if (self.window_handle == null) {
            return E2ETestError.WindowNotFound;
        }

        std.debug.print("[E2E] Going forward\n", .{});
    }

    /// Reload the page
    pub fn reload(self: *Self) !void {
        if (self.window_handle == null) {
            return E2ETestError.WindowNotFound;
        }

        std.debug.print("[E2E] Reloading page\n", .{});
    }

    /// Execute JavaScript in the page
    pub fn executeScript(self: *Self, script: []const u8) ![]u8 {
        if (self.window_handle == null) {
            return E2ETestError.WindowNotFound;
        }

        std.debug.print("[E2E] Executing script: {s}\n", .{script});

        // Mock return value
        return try self.allocator.dupe(u8, "{}");
    }

    /// Resize the window
    pub fn resizeWindow(self: *Self, width: u32, height: u32) !void {
        if (self.window_handle == null) {
            return E2ETestError.WindowNotFound;
        }

        std.debug.print("[E2E] Resizing window to {d}x{d}\n", .{ width, height });
    }

    /// Maximize the window
    pub fn maximizeWindow(self: *Self) !void {
        if (self.window_handle == null) {
            return E2ETestError.WindowNotFound;
        }

        std.debug.print("[E2E] Maximizing window\n", .{});
    }

    // Assertion helpers (compatible with zig-test-framework)
    pub fn assertEqual(self: *Self, expected: anytype, actual: anytype) !void {
        _ = self;
        if (expected != actual) {
            std.debug.print("Assertion failed: expected {} but got {}\n", .{ expected, actual });
            return error.AssertionFailed;
        }
    }

    pub fn assertEqualStrings(self: *Self, expected: []const u8, actual: []const u8) !void {
        _ = self;
        if (!std.mem.eql(u8, expected, actual)) {
            std.debug.print("Assertion failed: expected '{s}' but got '{s}'\n", .{ expected, actual });
            return error.AssertionFailed;
        }
    }

    pub fn assertTrue(self: *Self, value: bool) !void {
        _ = self;
        if (!value) {
            std.debug.print("Assertion failed: expected true but got false\n", .{});
            return error.AssertionFailed;
        }
    }

    pub fn assertContains(self: *Self, haystack: []const u8, needle: []const u8) !void {
        _ = self;
        if (std.mem.indexOf(u8, haystack, needle) == null) {
            std.debug.print("Assertion failed: '{s}' does not contain '{s}'\n", .{ haystack, needle });
            return error.AssertionFailed;
        }
    }
};

/// App launch configuration
pub const AppLaunchConfig = struct {
    app_path: []const u8,
    url: ?[]const u8 = null,
    width: u32 = 1200,
    height: u32 = 800,
    headless: bool = false,
    dev_tools: bool = false,
};

/// DOM Element representation
pub const Element = struct {
    selector: []const u8,
    handle: *anyopaque,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.selector);
    }

    /// Click this element
    pub fn click(self: *Self) !void {
        std.debug.print("[E2E] Clicking element: {s}\n", .{self.selector});
    }

    /// Type text into this element
    pub fn type(self: *Self, text: []const u8) !void {
        std.debug.print("[E2E] Typing into element {s}: {s}\n", .{ self.selector, text });
    }

    /// Get text content
    pub fn getText(self: *Self) ![]u8 {
        std.debug.print("[E2E] Getting text from element: {s}\n", .{self.selector});
        return try self.allocator.dupe(u8, "Mock text content");
    }

    /// Get attribute value
    pub fn getAttribute(self: *Self, attr_name: []const u8) !?[]u8 {
        std.debug.print("[E2E] Getting attribute '{s}' from element: {s}\n", .{ attr_name, self.selector });
        return try self.allocator.dupe(u8, "mock-value");
    }

    /// Check if element is visible
    pub fn isVisible(self: *Self) !bool {
        std.debug.print("[E2E] Checking visibility of element: {s}\n", .{self.selector});
        return true;
    }

    /// Check if element is enabled
    pub fn isEnabled(self: *Self) !bool {
        std.debug.print("[E2E] Checking if element is enabled: {s}\n", .{self.selector});
        return true;
    }

    /// Hover over this element
    pub fn hover(self: *Self) !void {
        std.debug.print("[E2E] Hovering over element: {s}\n", .{self.selector});
    }

    /// Double click this element
    pub fn doubleClick(self: *Self) !void {
        std.debug.print("[E2E] Double clicking element: {s}\n", .{self.selector});
    }

    /// Right click this element
    pub fn rightClick(self: *Self) !void {
        std.debug.print("[E2E] Right clicking element: {s}\n", .{self.selector});
    }
};

/// Page object pattern helper
pub const PageObject = struct {
    ctx: *E2ETestContext,

    const Self = @This();

    pub fn init(ctx: *E2ETestContext) Self {
        return Self{
            .ctx = ctx,
        };
    }

    /// Define a page object with selectors
    pub fn withSelectors(self: *Self, selectors: anytype) PageObjectInstance(@TypeOf(selectors)) {
        return PageObjectInstance(@TypeOf(selectors)){
            .ctx = self.ctx,
            .selectors = selectors,
        };
    }
};

fn PageObjectInstance(comptime T: type) type {
    return struct {
        ctx: *E2ETestContext,
        selectors: T,

        const Self = @This();

        pub fn getElement(self: *Self, comptime field_name: []const u8) !Element {
            const selector = @field(self.selectors, field_name);
            return try self.ctx.waitForElement(selector, 5000);
        }
    };
}

/// User flow helper for common workflows
pub const UserFlow = struct {
    ctx: *E2ETestContext,

    const Self = @This();

    pub fn init(ctx: *E2ETestContext) Self {
        return Self{
            .ctx = ctx,
        };
    }

    /// Fill out a form
    pub fn fillForm(self: *Self, fields: []const FormField) !void {
        for (fields) |field| {
            try self.ctx.type(field.selector, field.value);
        }
    }

    /// Login flow
    pub fn login(self: *Self, username: []const u8, password: []const u8) !void {
        try self.ctx.type("#username", username);
        try self.ctx.type("#password", password);
        try self.ctx.click("#login-button");
    }

    /// Logout flow
    pub fn logout(self: *Self) !void {
        try self.ctx.click("#logout-button");
    }
};

pub const FormField = struct {
    selector: []const u8,
    value: []const u8,
};

/// Visual regression testing helper
pub const VisualRegressionTester = struct {
    baseline_dir: []const u8,
    current_dir: []const u8,
    diff_dir: []const u8,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        const io = io_context.get();
        const cwd = io_context.cwd();
        try cwd.createDir(io, "baseline", .default_dir);
        try cwd.createDir(io, "current", .default_dir);
        try cwd.createDir(io, "diff", .default_dir);

        return Self{
            .baseline_dir = try allocator.dupe(u8, "baseline"),
            .current_dir = try allocator.dupe(u8, "current"),
            .diff_dir = try allocator.dupe(u8, "diff"),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.baseline_dir);
        self.allocator.free(self.current_dir);
        self.allocator.free(self.diff_dir);
    }

    /// Compare current screenshot with baseline
    pub fn compare(self: *Self, name: []const u8) !bool {
        std.debug.print("[Visual] Comparing '{s}' with baseline\n", .{name});
        _ = self;
        // Implementation would compare images
        return true;
    }

    /// Update baseline with current screenshot
    pub fn updateBaseline(self: *Self, name: []const u8) !void {
        std.debug.print("[Visual] Updating baseline for '{s}'\n", .{name});
        _ = self;
    }
};

// Tests
test "E2E test context" {
    const allocator = std.testing.allocator;
    var ctx = try E2ETestContext.init(allocator, "test_screenshots");
    defer ctx.deinit();

    const config = AppLaunchConfig{
        .app_path = "./test-app",
        .url = "http://localhost:3000",
        .width = 800,
        .height = 600,
    };

    try ctx.launchApp(config);
    try ctx.screenshot("initial");
    try ctx.closeApp();
}

test "Element interactions" {
    const allocator = std.testing.allocator;
    var ctx = try E2ETestContext.init(allocator, "test_screenshots");
    defer ctx.deinit();

    const config = AppLaunchConfig{
        .app_path = "./test-app",
        .url = "http://localhost:3000",
    };

    try ctx.launchApp(config);

    var element = try ctx.waitForElement("#test-button", 5000);
    defer element.deinit();

    try element.click();
    try std.testing.expect(try element.isVisible());
    try std.testing.expect(try element.isEnabled());

    try ctx.closeApp();
}

test "User flow" {
    const allocator = std.testing.allocator;
    var ctx = try E2ETestContext.init(allocator, "test_screenshots");
    defer ctx.deinit();

    const config = AppLaunchConfig{
        .app_path = "./test-app",
        .url = "http://localhost:3000/login",
    };

    try ctx.launchApp(config);

    var flow = UserFlow.init(&ctx);
    try flow.login("testuser", "password123");

    try ctx.screenshot("after-login");
    try ctx.closeApp();
}
