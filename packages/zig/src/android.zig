const std = @import("std");
const builtin = @import("builtin");
const mobile = @import("mobile.zig");

/// Android Native Integration
/// Provides a clean API for building Android apps with Craft
///
/// Usage:
///   var app = android.CraftActivity.init(allocator, .{
///       .name = "My App",
///       .package_name = "com.example.myapp",
///       .initial_content = .{ .html = html },
///   });
///   try app.run();

// ============================================================================
// JNI Types (for cross-compilation)
// ============================================================================

pub const jni = struct {
    pub const JNIEnv = *anyopaque;
    pub const jobject = *anyopaque;
    pub const jclass = *anyopaque;
    pub const jstring = *anyopaque;
    pub const jint = i32;
    pub const jlong = i64;
    pub const jboolean = u8;
    pub const jfloat = f32;
    pub const jdouble = f64;
};

// ============================================================================
// CraftActivity - Main Android Activity
// ============================================================================

/// CraftActivity - Android Activity with WebView
/// Similar to iOS CraftAppDelegate but for Android
pub const CraftActivity = struct {
    allocator: std.mem.Allocator,
    config: ActivityConfig,
    js_bridge: ?*JSBridge = null,
    webview: ?*mobile.Android.WebView = null,

    // JNI references
    jni_env: ?jni.JNIEnv = null,
    activity: ?jni.jobject = null,

    // Callbacks
    on_create: ?*const fn () void = null,
    on_resume: ?*const fn () void = null,
    on_pause: ?*const fn () void = null,
    on_destroy: ?*const fn () void = null,
    on_back_pressed: ?*const fn () bool = null,

    const Self = @This();

    pub const ActivityConfig = struct {
        name: []const u8 = "Craft App",
        package_name: []const u8 = "com.craft.app",
        initial_content: Content = .{ .html = default_html },
        theme: Theme = .light,
        orientation: Orientation = .portrait,
        fullscreen: bool = false,
        hardware_accelerated: bool = true,
        enable_javascript: bool = true,
        enable_dom_storage: bool = true,
        allow_file_access: bool = false,
        enable_inspector: bool = false,
    };

    pub const Content = union(enum) {
        html: []const u8,
        url: []const u8,
        asset: []const u8, // Load from assets folder
    };

    pub const Theme = enum {
        light,
        dark,
        system,
    };

    pub const Orientation = enum {
        portrait,
        landscape,
        sensor,
        unspecified,
    };

    pub fn init(allocator: std.mem.Allocator, config: ActivityConfig) Self {
        return Self{
            .allocator = allocator,
            .config = config,
        };
    }

    /// Set onCreate callback
    pub fn onCreate(self: *Self, callback: *const fn () void) void {
        self.on_create = callback;
    }

    /// Set onResume callback
    pub fn onResume(self: *Self, callback: *const fn () void) void {
        self.on_resume = callback;
    }

    /// Set onPause callback
    pub fn onPause(self: *Self, callback: *const fn () void) void {
        self.on_pause = callback;
    }

    /// Set onDestroy callback
    pub fn onDestroy(self: *Self, callback: *const fn () void) void {
        self.on_destroy = callback;
    }

    /// Set onBackPressed callback (return true to consume the event)
    pub fn onBackPressed(self: *Self, callback: *const fn () bool) void {
        self.on_back_pressed = callback;
    }

    /// Register a custom JavaScript handler
    pub fn registerJSHandler(self: *Self, name: []const u8, handler: JSBridge.Handler) !void {
        if (self.js_bridge) |bridge| {
            try bridge.registerHandler(name, handler);
        }
    }

    /// Get the JavaScript bridge
    pub fn getBridge(self: *Self) ?*JSBridge {
        return self.js_bridge;
    }

    /// Evaluate JavaScript in the WebView
    pub fn evaluateJavaScript(self: *Self, script: []const u8, callback: ?*const fn ([]const u8) void) !void {
        _ = self;
        _ = script;
        _ = callback;
        // Would call Android WebView.evaluateJavascript via JNI
    }

    /// Load HTML content
    pub fn loadHTML(self: *Self, html: []const u8) !void {
        _ = self;
        _ = html;
        // Would call WebView.loadDataWithBaseURL via JNI
    }

    /// Load URL
    pub fn loadURL(self: *Self, url: []const u8) !void {
        _ = self;
        _ = url;
        // Would call WebView.loadUrl via JNI
    }

    /// Run the activity (called from JNI onCreate)
    pub fn run(self: *Self) !void {
        // Initialize JavaScript bridge
        const bridge = try self.allocator.create(JSBridge);
        bridge.* = JSBridge.init(self.allocator);
        bridge.activity = self;
        self.js_bridge = bridge;

        // Load initial content
        switch (self.config.initial_content) {
            .html => |html| try self.loadHTML(html),
            .url => |url| try self.loadURL(url),
            .asset => |asset| {
                const url = try std.fmt.allocPrint(self.allocator, "file:///android_asset/{s}", .{asset});
                defer self.allocator.free(url);
                try self.loadURL(url);
            },
        }

        // Call onCreate callback
        if (self.on_create) |callback| {
            callback();
        }

        // Send ready event
        if (self.js_bridge) |bridge_ptr| {
            bridge_ptr.sendEvent("ready", "{}") catch {};
        }
    }

    pub fn deinit(self: *Self) void {
        if (self.js_bridge) |bridge| {
            bridge.deinit();
            self.allocator.destroy(bridge);
        }
    }
};

// ============================================================================
// JavaScript Bridge for Android
// ============================================================================

/// JavaScript bridge for Android WebView
/// Handles messages from JavaScript via @JavascriptInterface
pub const JSBridge = struct {
    handlers: std.StringHashMap(Handler),
    allocator: std.mem.Allocator,
    activity: ?*CraftActivity = null,

    pub const Handler = *const fn (params: []const u8, bridge: *JSBridge, callback_id: []const u8) void;

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) JSBridge {
        var bridge = JSBridge{
            .handlers = std.StringHashMap(Handler).init(allocator),
            .allocator = allocator,
        };

        // Register built-in handlers
        bridge.registerBuiltinHandlers() catch {};

        return bridge;
    }

    pub fn deinit(self: *Self) void {
        self.handlers.deinit();
    }

    fn registerBuiltinHandlers(self: *Self) !void {
        try self.handlers.put("getPlatform", handleGetPlatform);
        try self.handlers.put("showToast", handleShowToast);
        try self.handlers.put("vibrate", handleVibrate);
        try self.handlers.put("setClipboard", handleSetClipboard);
        try self.handlers.put("getClipboard", handleGetClipboard);
        try self.handlers.put("share", handleShare);
        try self.handlers.put("openURL", handleOpenURL);
        try self.handlers.put("getNetworkStatus", handleGetNetworkStatus);
        try self.handlers.put("showAlert", handleShowAlert);
    }

    pub fn registerHandler(self: *Self, name: []const u8, handler: Handler) !void {
        try self.handlers.put(name, handler);
    }

    /// Handle message from JavaScript (called via JNI)
    pub fn handleMessage(self: *Self, message: []const u8) void {
        const method = self.extractJsonString(message, "method") orelse return;
        const callback_id = self.extractJsonString(message, "callbackId") orelse "";
        const params = self.extractJsonObject(message, "params") orelse "{}";

        if (self.handlers.get(method)) |handler| {
            handler(params, self, callback_id);
        } else {
            self.sendError(callback_id, "Unknown method") catch {};
        }
    }

    fn extractJsonString(self: *Self, json: []const u8, key: []const u8) ?[]const u8 {
        _ = self;
        var pattern_buf: [64]u8 = undefined;
        const pattern = std.fmt.bufPrint(&pattern_buf, "\"{s}\":\"", .{key}) catch return null;

        if (std.mem.indexOf(u8, json, pattern)) |start| {
            const value_start = start + pattern.len;
            if (value_start < json.len) {
                if (std.mem.indexOf(u8, json[value_start..], "\"")) |end| {
                    return json[value_start..][0..end];
                }
            }
        }
        return null;
    }

    fn extractJsonObject(self: *Self, json: []const u8, key: []const u8) ?[]const u8 {
        _ = self;
        var pattern_buf: [64]u8 = undefined;
        const pattern = std.fmt.bufPrint(&pattern_buf, "\"{s}\":{{", .{key}) catch return null;

        if (std.mem.indexOf(u8, json, pattern)) |start| {
            const value_start = start + pattern.len - 1;
            if (value_start < json.len) {
                var depth: usize = 0;
                var i: usize = value_start;
                while (i < json.len) : (i += 1) {
                    if (json[i] == '{') depth += 1 else if (json[i] == '}') {
                        depth -= 1;
                        if (depth == 0) return json[value_start .. i + 1];
                    }
                }
            }
        }
        return null;
    }

    pub fn sendResponse(self: *Self, callback_id: []const u8, result: []const u8) !void {
        if (self.activity == null) return error.NoActivity;
        if (callback_id.len == 0) return;

        var buf: [2048]u8 = undefined;
        const script = std.fmt.bufPrint(&buf,
            \\if (window['__craftCallback_{s}']) {{ window['__craftCallback_{s}']({s}); }}
        , .{ callback_id, callback_id, result }) catch return;

        try self.activity.?.evaluateJavaScript(script, null);
    }

    pub fn sendError(self: *Self, callback_id: []const u8, error_message: []const u8) !void {
        if (self.activity == null) return error.NoActivity;
        if (callback_id.len == 0) return;

        var buf: [2048]u8 = undefined;
        const script = std.fmt.bufPrint(&buf,
            \\if (window['__craftCallback_{s}']) {{ window['__craftCallback_{s}']({{ error: '{s}' }}); }}
        , .{ callback_id, callback_id, error_message }) catch return;

        try self.activity.?.evaluateJavaScript(script, null);
    }

    pub fn sendEvent(self: *Self, event: []const u8, data: []const u8) !void {
        if (self.activity == null) return error.NoActivity;

        var buf: [2048]u8 = undefined;
        const script = std.fmt.bufPrint(&buf,
            \\window.dispatchEvent(new CustomEvent('craft:{s}', {{ detail: {s} }}));
        , .{ event, data }) catch return;

        try self.activity.?.evaluateJavaScript(script, null);
    }

    // Built-in handlers
    fn handleGetPlatform(params: []const u8, bridge: *JSBridge, callback_id: []const u8) void {
        _ = params;
        const response =
            \\{"os": "android", "version": "14", "device": "Android", "native": true}
        ;
        bridge.sendResponse(callback_id, response) catch {};
    }

    fn handleShowToast(params: []const u8, bridge: *JSBridge, callback_id: []const u8) void {
        const message = bridge.extractJsonString(params, "message") orelse "Toast";
        _ = message;
        // Would call Toast.makeText via JNI
        bridge.sendResponse(callback_id, "{ \"success\": true }") catch {};
    }

    fn handleVibrate(params: []const u8, bridge: *JSBridge, callback_id: []const u8) void {
        _ = params;
        // Would call Vibrator.vibrate via JNI
        bridge.sendResponse(callback_id, "{ \"success\": true }") catch {};
    }

    fn handleSetClipboard(params: []const u8, bridge: *JSBridge, callback_id: []const u8) void {
        const text = bridge.extractJsonString(params, "text") orelse "";
        _ = text;
        // Would call ClipboardManager.setPrimaryClip via JNI
        bridge.sendResponse(callback_id, "{ \"success\": true }") catch {};
    }

    fn handleGetClipboard(params: []const u8, bridge: *JSBridge, callback_id: []const u8) void {
        _ = params;
        // Would call ClipboardManager.getPrimaryClip via JNI
        bridge.sendResponse(callback_id, "{ \"text\": \"\" }") catch {};
    }

    fn handleShare(params: []const u8, bridge: *JSBridge, callback_id: []const u8) void {
        const text = bridge.extractJsonString(params, "text") orelse "";
        _ = text;
        // Would start Intent.ACTION_SEND via JNI
        bridge.sendResponse(callback_id, "{ \"success\": true }") catch {};
    }

    fn handleOpenURL(params: []const u8, bridge: *JSBridge, callback_id: []const u8) void {
        const url = bridge.extractJsonString(params, "url") orelse "";
        _ = url;
        // Would start Intent.ACTION_VIEW via JNI
        bridge.sendResponse(callback_id, "{ \"success\": true }") catch {};
    }

    fn handleGetNetworkStatus(params: []const u8, bridge: *JSBridge, callback_id: []const u8) void {
        _ = params;
        // Would check ConnectivityManager via JNI
        bridge.sendResponse(callback_id, "{ \"connected\": true, \"type\": \"wifi\" }") catch {};
    }

    fn handleShowAlert(params: []const u8, bridge: *JSBridge, callback_id: []const u8) void {
        const title = bridge.extractJsonString(params, "title") orelse "Alert";
        const message = bridge.extractJsonString(params, "message") orelse "";
        _ = title;
        _ = message;
        // Would show AlertDialog via JNI
        bridge.sendResponse(callback_id, "{ \"success\": true }") catch {};
    }
};

// ============================================================================
// Android Native Features
// ============================================================================

pub const AndroidFeatures = struct {
    /// Show a Toast message
    pub fn showToast(message: []const u8, long_duration: bool) void {
        _ = message;
        _ = long_duration;
        // JNI call to Toast.makeText().show()
    }

    /// Vibrate the device
    pub fn vibrate(duration_ms: i64) void {
        _ = duration_ms;
        // JNI call to Vibrator.vibrate()
    }

    /// Request a permission
    pub fn requestPermission(permission: []const u8) void {
        _ = permission;
        // JNI call to ActivityCompat.requestPermissions()
    }

    /// Check if permission is granted
    pub fn hasPermission(permission: []const u8) bool {
        _ = permission;
        // JNI call to ContextCompat.checkSelfPermission()
        return false;
    }

    /// Open URL in browser
    pub fn openURL(url: []const u8) void {
        _ = url;
        // JNI call to startActivity with ACTION_VIEW intent
    }

    /// Share text/content
    pub fn share(text: []const u8) void {
        _ = text;
        // JNI call to startActivity with ACTION_SEND intent
    }

    /// Copy text to clipboard
    pub fn setClipboard(text: []const u8) void {
        _ = text;
        // JNI call to ClipboardManager.setPrimaryClip()
    }

    /// Get text from clipboard
    pub fn getClipboard(allocator: std.mem.Allocator) ![]const u8 {
        _ = allocator;
        // JNI call to ClipboardManager.getPrimaryClip()
        return "";
    }

    /// Check network connectivity
    pub fn isNetworkConnected() bool {
        // JNI call to ConnectivityManager.getActiveNetworkInfo()
        return true;
    }

    /// Get device info
    pub fn getDeviceInfo() DeviceInfo {
        return .{
            .manufacturer = "Unknown",
            .model = "Android Device",
            .os_version = "14",
            .sdk_version = 34,
        };
    }

    pub const DeviceInfo = struct {
        manufacturer: []const u8,
        model: []const u8,
        os_version: []const u8,
        sdk_version: i32,
    };
};

// ============================================================================
// Quick Start Helper
// ============================================================================

/// Quick start an Android app with HTML content
pub fn quickStart(allocator: std.mem.Allocator, html: []const u8) !void {
    var app = CraftActivity.init(allocator, .{
        .name = "Craft App",
        .initial_content = .{ .html = html },
    });
    defer app.deinit();
    try app.run();
}

// ============================================================================
// Default HTML
// ============================================================================

const default_html =
    \\<!DOCTYPE html>
    \\<html>
    \\<head>
    \\    <meta charset="UTF-8">
    \\    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    \\    <title>Craft App</title>
    \\    <style>
    \\        * { box-sizing: border-box; margin: 0; padding: 0; }
    \\        body {
    \\            font-family: 'Roboto', sans-serif;
    \\            display: flex;
    \\            align-items: center;
    \\            justify-content: center;
    \\            min-height: 100vh;
    \\            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    \\            color: white;
    \\            text-align: center;
    \\            padding: 20px;
    \\        }
    \\        h1 { font-size: 2rem; margin-bottom: 1rem; }
    \\        p { opacity: 0.9; font-size: 1.1rem; }
    \\    </style>
    \\</head>
    \\<body>
    \\    <div>
    \\        <h1>Welcome to Craft</h1>
    \\        <p>Your Android app is ready!</p>
    \\    </div>
    \\</body>
    \\</html>
;

// ============================================================================
// Tests
// ============================================================================

test "CraftActivity initialization" {
    const allocator = std.testing.allocator;

    const config = CraftActivity.ActivityConfig{
        .name = "Test App",
        .package_name = "com.test.app",
        .initial_content = .{ .html = "<h1>Hello</h1>" },
    };

    const app = CraftActivity.init(allocator, config);
    _ = app;
}

test "JSBridge initialization" {
    const allocator = std.testing.allocator;

    var bridge = JSBridge.init(allocator);
    defer bridge.deinit();

    const handler = struct {
        fn handle(_: []const u8, _: *JSBridge, _: []const u8) void {}
    }.handle;

    try bridge.registerHandler("test", handler);
}
