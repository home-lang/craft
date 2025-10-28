const std = @import("std");

/// Craft API Version - Follows Semantic Versioning
pub const Version = struct {
    major: u32 = 1,
    minor: u32 = 0,
    patch: u32 = 0,

    pub fn toString(self: Version, allocator: std.mem.Allocator) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "{d}.{d}.{d}", .{ self.major, self.minor, self.patch });
    }

    pub fn isCompatible(self: Version, other: Version) bool {
        // Major version must match for compatibility
        // Minor version must be >= for forward compatibility
        return self.major == other.major and self.minor >= other.minor;
    }
};

pub const current_version = Version{
    .major = 0,
    .minor = 0,
    .patch = 1,
};

/// Stable Window API
pub const Window = struct {
    handle: *anyopaque,
    title: []const u8,
    width: u32,
    height: u32,
    x: i32,
    y: i32,

    /// Create a new window
    pub fn create(options: WindowOptions) !Window {
        return switch (@import("builtin").target.os.tag) {
            .macos => @import("macos.zig").Window.create(options),
            .linux => @import("linux.zig").Window.create(options),
            .windows => @import("windows.zig").Window.create(options),
            else => error.UnsupportedPlatform,
        };
    }

    /// Show the window
    pub fn show(self: *Window) void {
        switch (@import("builtin").target.os.tag) {
            .macos => @import("macos.zig").Window.show(self),
            .linux => @import("linux.zig").Window.show(self),
            .windows => @import("windows.zig").Window.show(self),
            else => {},
        }
    }

    /// Hide the window
    pub fn hide(self: *Window) void {
        switch (@import("builtin").target.os.tag) {
            .macos => @import("macos.zig").Window.hide(self),
            .linux => @import("linux.zig").Window.hide(self),
            .windows => @import("windows.zig").Window.hide(self),
            else => {},
        }
    }

    /// Close the window
    pub fn close(self: *Window) void {
        switch (@import("builtin").target.os.tag) {
            .macos => @import("macos.zig").Window.close(self),
            .linux => @import("linux.zig").Window.close(self),
            .windows => @import("windows.zig").Window.close(self),
            else => {},
        }
    }

    /// Set window size
    pub fn setSize(self: *Window, width: u32, height: u32) void {
        self.width = width;
        self.height = height;
        switch (@import("builtin").target.os.tag) {
            .macos => @import("macos.zig").Window.setSize(self, width, height),
            .linux => @import("linux.zig").Window.setSize(self, width, height),
            .windows => @import("windows.zig").Window.setSize(self, width, height),
            else => {},
        }
    }

    /// Set window position
    pub fn setPosition(self: *Window, x: i32, y: i32) void {
        self.x = x;
        self.y = y;
        switch (@import("builtin").target.os.tag) {
            .macos => @import("macos.zig").Window.setPosition(self, x, y),
            .linux => @import("linux.zig").Window.setPosition(self, x, y),
            .windows => @import("windows.zig").Window.setPosition(self, x, y),
            else => {},
        }
    }

    /// Set window title
    pub fn setTitle(self: *Window, title: []const u8) void {
        self.title = title;
        switch (@import("builtin").target.os.tag) {
            .macos => @import("macos.zig").Window.setTitle(self, title),
            .linux => @import("linux.zig").Window.setTitle(self, title),
            .windows => @import("windows.zig").Window.setTitle(self, title),
            else => {},
        }
    }
};

/// Window creation options
pub const WindowOptions = struct {
    title: []const u8 = "Craft App",
    width: u32 = 1200,
    height: u32 = 800,
    x: ?i32 = null,
    y: ?i32 = null,
    resizable: bool = true,
    frameless: bool = false,
    transparent: bool = false,
    always_on_top: bool = false,
    fullscreen: bool = false,
    dark_mode: ?bool = null,
    dev_tools: bool = true,
};

/// Stable Application API
pub const App = struct {
    allocator: std.mem.Allocator,
    windows: std.ArrayList(Window),
    running: bool = false,

    pub fn init(allocator: std.mem.Allocator) App {
        return .{
            .allocator = allocator,
            .windows = std.ArrayList(Window).init(allocator),
        };
    }

    pub fn deinit(self: *App) void {
        self.windows.deinit();
    }

    /// Create a window with URL
    pub fn createWindow(self: *App, title: []const u8, width: u32, height: u32, url: []const u8, options: WindowOptions) !*Window {
        var opts = options;
        opts.title = title;
        opts.width = width;
        opts.height = height;

        const window = try Window.create(opts);
        try self.windows.append(window);

        // Load URL in window
        switch (@import("builtin").target.os.tag) {
            .macos => try @import("macos.zig").Window.loadURL(&self.windows.items[self.windows.items.len - 1], url),
            .linux => try @import("linux.zig").Window.loadURL(&self.windows.items[self.windows.items.len - 1], url),
            .windows => try @import("windows.zig").Window.loadURL(&self.windows.items[self.windows.items.len - 1], url),
            else => return error.UnsupportedPlatform,
        }

        return &self.windows.items[self.windows.items.len - 1];
    }

    /// Run the application event loop
    pub fn run(self: *App) !void {
        self.running = true;
        switch (@import("builtin").target.os.tag) {
            .macos => try @import("macos.zig").App.run(),
            .linux => try @import("linux.zig").App.run(),
            .windows => try @import("windows.zig").App.run(),
            else => return error.UnsupportedPlatform,
        }
    }

    /// Quit the application
    pub fn quit(self: *App) void {
        self.running = false;
        switch (@import("builtin").target.os.tag) {
            .macos => @import("macos.zig").App.quit(),
            .linux => @import("linux.zig").App.quit(),
            .windows => @import("windows.zig").App.quit(),
            else => {},
        }
    }
};

/// Platform information
pub const Platform = struct {
    pub fn name() []const u8 {
        return switch (@import("builtin").target.os.tag) {
            .macos => "macOS",
            .linux => "Linux",
            .windows => "Windows",
            else => "Unknown",
        };
    }

    pub fn isSupported() bool {
        return switch (@import("builtin").target.os.tag) {
            .macos, .linux, .windows => true,
            else => false,
        };
    }

    pub fn version() Version {
        return current_version;
    }
};

/// Feature flags - allows checking for platform-specific features
pub const Features = struct {
    pub fn hasWebView() bool {
        return switch (@import("builtin").target.os.tag) {
            .macos => true,
            .linux => true, // With WebKit2GTK
            .windows => true, // With WebView2
            else => false,
        };
    }

    pub fn hasSystemTray() bool {
        return switch (@import("builtin").target.os.tag) {
            .macos => true,
            .linux => true,
            .windows => true,
            else => false,
        };
    }

    pub fn hasNotifications() bool {
        return switch (@import("builtin").target.os.tag) {
            .macos => true,
            .linux => true,
            .windows => true,
            else => false,
        };
    }

    pub fn hasHotReload() bool {
        return true; // Available on all platforms
    }

    pub fn hasDevTools() bool {
        return switch (@import("builtin").target.os.tag) {
            .macos => true,
            .linux => true,
            .windows => true,
            else => false,
        };
    }
};

/// Error types
pub const Error = error{
    UnsupportedPlatform,
    WindowCreationFailed,
    WebViewCreationFailed,
    InvalidURL,
    InitializationFailed,
    FeatureNotAvailable,
};

/// Result type for better error handling
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        ok: T,
        err: E,

        pub fn isOk(self: @This()) bool {
            return self == .ok;
        }

        pub fn isErr(self: @This()) bool {
            return self == .err;
        }

        pub fn unwrap(self: @This()) T {
            return switch (self) {
                .ok => |val| val,
                .err => @panic("Called unwrap on error value"),
            };
        }

        pub fn unwrapOr(self: @This(), default: T) T {
            return switch (self) {
                .ok => |val| val,
                .err => default,
            };
        }

        pub fn expect(self: @This(), msg: []const u8) T {
            return switch (self) {
                .ok => |val| val,
                .err => |e| {
                    std.debug.print("Expected ok value: {s}. Got error: {}\n", .{ msg, e });
                    @panic("expect() failed");
                },
            };
        }
    };
}

/// Builder Pattern for WindowOptions
pub const WindowBuilder = struct {
    title: []const u8,
    width: u32,
    height: u32,
    url: []const u8,
    x: ?i32 = null,
    y: ?i32 = null,
    is_resizable: bool = true,
    is_frameless: bool = false,
    is_transparent: bool = false,
    always_on_top: bool = false,
    is_fullscreen: bool = false,
    dark_mode: ?bool = null,
    dev_tools: bool = true,
    min_width: ?u32 = null,
    min_height: ?u32 = null,
    max_width: ?u32 = null,
    max_height: ?u32 = null,

    pub fn new(title: []const u8, url: []const u8) WindowBuilder {
        return WindowBuilder{
            .title = title,
            .width = 1200,
            .height = 800,
            .url = url,
        };
    }

    pub fn size(self: WindowBuilder, width: u32, height: u32) WindowBuilder {
        var builder = self;
        builder.width = width;
        builder.height = height;
        return builder;
    }

    pub fn position(self: WindowBuilder, x: i32, y: i32) WindowBuilder {
        var builder = self;
        builder.x = x;
        builder.y = y;
        return builder;
    }

    pub fn minSize(self: WindowBuilder, width: u32, height: u32) WindowBuilder {
        var builder = self;
        builder.min_width = width;
        builder.min_height = height;
        return builder;
    }

    pub fn maxSize(self: WindowBuilder, width: u32, height: u32) WindowBuilder {
        var builder = self;
        builder.max_width = width;
        builder.max_height = height;
        return builder;
    }

    pub fn resizable(self: WindowBuilder, value: bool) WindowBuilder {
        var builder = self;
        builder.is_resizable = value;
        return builder;
    }

    pub fn frameless(self: WindowBuilder, value: bool) WindowBuilder {
        var builder = self;
        builder.is_frameless = value;
        return builder;
    }

    pub fn transparent(self: WindowBuilder, value: bool) WindowBuilder {
        var builder = self;
        builder.is_transparent = value;
        return builder;
    }

    pub fn alwaysOnTop(self: WindowBuilder, value: bool) WindowBuilder {
        var builder = self;
        builder.always_on_top = value;
        return builder;
    }

    pub fn fullscreen(self: WindowBuilder, value: bool) WindowBuilder {
        var builder = self;
        builder.is_fullscreen = value;
        return builder;
    }

    pub fn darkMode(self: WindowBuilder, value: bool) WindowBuilder {
        var builder = self;
        builder.dark_mode = value;
        return builder;
    }

    pub fn devTools(self: WindowBuilder, value: bool) WindowBuilder {
        var builder = self;
        builder.dev_tools = value;
        return builder;
    }

    pub fn build(self: WindowBuilder) Result(Window, Error) {
        // Validate dimensions
        if (self.min_width != null and self.width < self.min_width.?) {
            return .{ .err = Error.WindowCreationFailed };
        }
        if (self.min_height != null and self.height < self.min_height.?) {
            return .{ .err = Error.WindowCreationFailed };
        }

        // Create window (platform-specific implementation would go here)
        const opts = WindowOptions{
            .title = self.title,
            .width = self.width,
            .height = self.height,
            .x = self.x,
            .y = self.y,
            .resizable = self.resizable,
            .frameless = self.frameless,
            .transparent = self.transparent,
            .always_on_top = self.always_on_top,
            .fullscreen = self.fullscreen,
            .dark_mode = self.dark_mode,
            .dev_tools = self.dev_tools,
        };

        const window = Window.create(opts) catch {
            return .{ .err = Error.WindowCreationFailed };
        };

        return .{ .ok = window };
    }
};

/// Typed Event System
pub const EventType = enum {
    window_close,
    window_resize,
    window_move,
    window_focus,
    window_blur,
    key_down,
    key_up,
    mouse_down,
    mouse_up,
    mouse_move,
    scroll,
    custom,
};

pub const Event = union(EventType) {
    window_close: void,
    window_resize: ResizeEvent,
    window_move: MoveEvent,
    window_focus: void,
    window_blur: void,
    key_down: KeyEvent,
    key_up: KeyEvent,
    mouse_down: MouseEvent,
    mouse_up: MouseEvent,
    mouse_move: MouseEvent,
    scroll: ScrollEvent,
    custom: CustomEvent,
};

pub const ResizeEvent = struct {
    width: u32,
    height: u32,
};

pub const MoveEvent = struct {
    x: i32,
    y: i32,
};

pub const KeyEvent = struct {
    code: []const u8,
    key: []const u8,
    alt: bool,
    ctrl: bool,
    shift: bool,
    meta: bool,
};

pub const MouseEvent = struct {
    x: i32,
    y: i32,
    button: u8,
    alt: bool,
    ctrl: bool,
    shift: bool,
    meta: bool,
};

pub const ScrollEvent = struct {
    delta_x: f32,
    delta_y: f32,
};

pub const CustomEvent = struct {
    name: []const u8,
    data: []const u8,
};

pub const EventHandler = *const fn (Event) void;

/// Structured IPC Messages
pub const IPCMessage = struct {
    id: u64,
    type: MessageType,
    payload: Payload,

    pub const MessageType = enum {
        request,
        response,
        notification,
        error_msg,
    };

    pub const Payload = union(enum) {
        string: []const u8,
        number: f64,
        boolean: bool,
        object: std.StringHashMap([]const u8),
        array: []const []const u8,
        null_value: void,
    };

    pub fn request(id: u64, payload: Payload) IPCMessage {
        return IPCMessage{
            .id = id,
            .type = .request,
            .payload = payload,
        };
    }

    pub fn response(id: u64, payload: Payload) IPCMessage {
        return IPCMessage{
            .id = id,
            .type = .response,
            .payload = payload,
        };
    }

    pub fn notification(payload: Payload) IPCMessage {
        return IPCMessage{
            .id = 0,
            .type = .notification,
            .payload = payload,
        };
    }

    pub fn err(id: u64, message: []const u8) IPCMessage {
        return IPCMessage{
            .id = id,
            .type = .error_msg,
            .payload = .{ .string = message },
        };
    }
};

/// Async/Await Support
pub const Promise = struct {
    value: ?[]const u8,
    error_value: ?Error,
    resolved: bool,
    rejected: bool,
    then_callback: ?*const fn ([]const u8) void,
    catch_callback: ?*const fn (Error) void,

    pub fn init() Promise {
        return Promise{
            .value = null,
            .error_value = null,
            .resolved = false,
            .rejected = false,
            .then_callback = null,
            .catch_callback = null,
        };
    }

    pub fn resolve(self: *Promise, value: []const u8) void {
        self.value = value;
        self.resolved = true;
        if (self.then_callback) |callback| {
            callback(value);
        }
    }

    pub fn reject(self: *Promise, err: Error) void {
        self.error_value = err;
        self.rejected = true;
        if (self.catch_callback) |callback| {
            callback(err);
        }
    }

    pub fn then(self: *Promise, callback: *const fn ([]const u8) void) *Promise {
        self.then_callback = callback;
        if (self.resolved and self.value != null) {
            callback(self.value.?);
        }
        return self;
    }

    pub fn catch_(self: *Promise, callback: *const fn (Error) void) *Promise {
        self.catch_callback = callback;
        if (self.rejected and self.error_value != null) {
            callback(self.error_value.?);
        }
        return self;
    }
};
