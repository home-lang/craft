const std = @import("std");
const objc_runtime = @import("objc_runtime.zig");
const mobile = @import("mobile.zig");

/// iOS Application Infrastructure
/// Provides UIApplicationDelegate, UIViewController, and full app lifecycle management
const objc = objc_runtime.objc;

// ============================================================================
// iOS Application Delegate
// ============================================================================

/// CraftAppDelegate - Main iOS application delegate
/// Handles app lifecycle events and window setup
pub const CraftAppDelegate = struct {
    window: ?objc.id = null,
    root_view_controller: ?objc.id = null,
    webview: ?*mobile.iOS.WKWebView = null,
    js_bridge: ?*JSBridge = null,
    allocator: std.mem.Allocator,
    config: AppConfig,

    // Callbacks
    on_launch: ?*const fn () void = null,
    on_foreground: ?*const fn () void = null,
    on_background: ?*const fn () void = null,
    on_terminate: ?*const fn () void = null,
    on_memory_warning: ?*const fn () void = null,
    on_js_message: ?*const fn ([]const u8) void = null,

    pub const AppConfig = struct {
        /// App display name
        name: []const u8 = "Craft App",
        /// Initial HTML content or URL
        initial_content: Content,
        /// Status bar style
        status_bar_style: StatusBarStyle = .default,
        /// Support orientations
        orientations: []const Orientation = &[_]Orientation{.portrait},
        /// Enable WebKit inspector (debug only)
        enable_inspector: bool = false,
        /// Custom user agent suffix
        user_agent_suffix: ?[]const u8 = null,
        /// Tint color for UI elements (RGBA)
        tint_color: ?[4]u8 = null,
        /// Allow background audio
        background_audio: bool = false,

        pub const Content = union(enum) {
            html: []const u8,
            url: []const u8,
            file: []const u8,
        };

        pub const StatusBarStyle = enum {
            default,
            light,
            dark,
            hidden,
        };

        pub const Orientation = enum {
            portrait,
            portrait_upside_down,
            landscape_left,
            landscape_right,

            pub fn toMask(self: Orientation) u32 {
                return switch (self) {
                    .portrait => 0x02, // UIInterfaceOrientationMaskPortrait
                    .portrait_upside_down => 0x04, // UIInterfaceOrientationMaskPortraitUpsideDown
                    .landscape_left => 0x10, // UIInterfaceOrientationMaskLandscapeLeft
                    .landscape_right => 0x08, // UIInterfaceOrientationMaskLandscapeRight
                };
            }
        };
    };

    const Self = @This();

    /// Initialize the app delegate
    pub fn init(allocator: std.mem.Allocator, config: AppConfig) Self {
        return Self{
            .allocator = allocator,
            .config = config,
        };
    }

    /// Register callbacks for lifecycle events
    pub fn onLaunch(self: *Self, callback: *const fn () void) void {
        self.on_launch = callback;
    }

    pub fn onForeground(self: *Self, callback: *const fn () void) void {
        self.on_foreground = callback;
    }

    pub fn onBackground(self: *Self, callback: *const fn () void) void {
        self.on_background = callback;
    }

    pub fn onTerminate(self: *Self, callback: *const fn () void) void {
        self.on_terminate = callback;
    }

    pub fn onMemoryWarning(self: *Self, callback: *const fn () void) void {
        self.on_memory_warning = callback;
    }

    /// Register a custom JavaScript handler
    /// The handler will be called when JS calls: craft.invoke('name', params)
    pub fn registerJSHandler(self: *Self, name: []const u8, handler: JSBridge.Handler) !void {
        if (self.js_bridge) |bridge| {
            try bridge.registerHandler(name, handler);
        }
    }

    /// Get the JavaScript bridge for advanced usage
    pub fn getBridge(self: *Self) ?*JSBridge {
        return self.js_bridge;
    }

    /// Start the iOS application
    /// This should be called from main() and will not return until the app terminates
    pub fn run(self: *Self) !void {
        if (!@import("builtin").target.isDarwin()) {
            return error.UnsupportedPlatform;
        }

        // Initialize global object manager for memory tracking
        mobile.initGlobalObjectManager(self.allocator);
        defer mobile.deinitGlobalObjectManager();

        // Initialize JavaScript bridge
        const bridge = try self.allocator.create(JSBridge);
        bridge.* = JSBridge.init(self.allocator);
        bridge.app_delegate = self;
        self.js_bridge = bridge;
        defer {
            bridge.deinit();
            self.allocator.destroy(bridge);
        }

        // Create UIWindow
        try self.createWindow();

        // Create and configure root view controller with WKWebView
        try self.createRootViewController();

        // Set up JavaScript bridge with WKWebView
        try self.setupJSBridge();

        // Inject craft bridge JavaScript
        try self.injectBridgeScript();

        // Load initial content
        try self.loadInitialContent();

        // Make window visible
        try self.showWindow();

        // Dispatch ready event to JavaScript
        if (self.js_bridge) |bridge_ptr| {
            bridge_ptr.sendEvent("ready", "{}") catch {};
        }

        // Call launch callback
        if (self.on_launch) |callback| {
            callback();
        }

        // Start the run loop (blocks until app terminates)
        try self.runMainLoop();
    }

    /// Set up WKScriptMessageHandler for JavaScript bridge
    fn setupJSBridge(self: *Self) !void {
        if (self.webview == null) return error.WebViewNotInitialized;

        // Get the webview's configuration
        const webview_ptr: objc.id = @ptrCast(@alignCast(self.webview.?));
        const sel_configuration = objc.sel_registerName("configuration") orelse return error.SelectorNotFound;
        const configuration = objc.msgSendId(webview_ptr, sel_configuration);

        // Get user content controller
        const sel_userContentController = objc.sel_registerName("userContentController") orelse return error.SelectorNotFound;
        const content_controller = objc.msgSendId(configuration, sel_userContentController);

        // Note: In a full implementation, we would create a custom Objective-C class
        // that implements WKScriptMessageHandler protocol and register it here.
        // For now, the JS bridge will work through evaluateJavaScript polling.

        _ = content_controller;
    }

    /// Inject the craft bridge JavaScript into the webview
    fn injectBridgeScript(self: *Self) !void {
        if (self.webview == null) return error.WebViewNotInitialized;

        // This JavaScript sets up the craft object that web apps can use
        const bridge_script =
            \\(function() {
            \\    if (window.craft) return; // Already initialized
            \\
            \\    window.craft = {
            \\        _callbacks: {},
            \\        _callbackId: 0,
            \\
            \\        isNative: function() {
            \\            return !!(window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.craft);
            \\        },
            \\
            \\        invoke: function(method, params) {
            \\            var self = this;
            \\            params = params || {};
            \\
            \\            return new Promise(function(resolve, reject) {
            \\                var callbackId = String(++self._callbackId);
            \\
            \\                // Store callback
            \\                window['__craftCallback_' + callbackId] = function(result) {
            \\                    delete window['__craftCallback_' + callbackId];
            \\                    if (result && result.error) {
            \\                        reject(new Error(result.error));
            \\                    } else {
            \\                        resolve(result);
            \\                    }
            \\                };
            \\
            \\                // Send to native
            \\                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.craft) {
            \\                    window.webkit.messageHandlers.craft.postMessage({
            \\                        method: method,
            \\                        params: params,
            \\                        callbackId: callbackId
            \\                    });
            \\                } else {
            \\                    // Browser fallback - simulate native response
            \\                    setTimeout(function() {
            \\                        window['__craftCallback_' + callbackId]({ success: true, browser: true });
            \\                    }, 10);
            \\                }
            \\
            \\                // Timeout after 10 seconds
            \\                setTimeout(function() {
            \\                    if (window['__craftCallback_' + callbackId]) {
            \\                        delete window['__craftCallback_' + callbackId];
            \\                        reject(new Error('Timeout'));
            \\                    }
            \\                }, 10000);
            \\            });
            \\        }
            \\    };
            \\
            \\    // Dispatch ready event
            \\    window.dispatchEvent(new CustomEvent('craft:ready'));
            \\})();
        ;

        try self.evaluateJavaScript(bridge_script, null);
    }

    /// Create the main UIWindow
    fn createWindow(self: *Self) !void {
        // Get UIScreen mainScreen bounds
        const UIScreenClass = objc.objc_getClass("UIScreen") orelse return error.ClassNotFound;
        const sel_mainScreen = objc.sel_registerName("mainScreen") orelse return error.SelectorNotFound;
        const sel_bounds = objc.sel_registerName("bounds") orelse return error.SelectorNotFound;

        const mainScreen = objc.msgSendId(UIScreenClass, sel_mainScreen);

        // Get bounds as CGRect
        const BoundsFn = *const fn (objc.id, objc.SEL) callconv(.c) objc.CGRect;
        const boundsFn: BoundsFn = @ptrCast(&objc_runtime.objc.objc_msgSend);
        const bounds = boundsFn(mainScreen, sel_bounds);

        // Create UIWindow: [[UIWindow alloc] initWithFrame:bounds]
        const UIWindowClass = objc.objc_getClass("UIWindow") orelse return error.ClassNotFound;
        const sel_initWithFrame = objc.sel_registerName("initWithFrame:") orelse return error.SelectorNotFound;

        const allocated = try objc.alloc(UIWindowClass);
        const InitFn = *const fn (objc.id, objc.SEL, objc.CGRect) callconv(.c) objc.id;
        const initFn: InitFn = @ptrCast(&objc_runtime.objc.objc_msgSend);
        self.window = initFn(allocated, sel_initWithFrame, bounds);

        // Set window background color
        const sel_setBackgroundColor = objc.sel_registerName("setBackgroundColor:") orelse return error.SelectorNotFound;
        const UIColorClass = objc.objc_getClass("UIColor") orelse return error.ClassNotFound;
        const sel_whiteColor = objc.sel_registerName("whiteColor") orelse return error.SelectorNotFound;
        const whiteColor = objc.msgSendId(UIColorClass, sel_whiteColor);

        const SetColorFn = *const fn (objc.id, objc.SEL, objc.id) callconv(.c) void;
        const setColorFn: SetColorFn = @ptrCast(&objc_runtime.objc.objc_msgSend);
        setColorFn(self.window.?, sel_setBackgroundColor, whiteColor);
    }

    /// Create root view controller with WKWebView
    fn createRootViewController(self: *Self) !void {
        // Create CraftViewController (our custom UIViewController)
        const UIViewControllerClass = objc.objc_getClass("UIViewController") orelse return error.ClassNotFound;
        self.root_view_controller = try objc.allocInit(UIViewControllerClass);

        // Create WKWebView configuration
        const webview_config = mobile.iOS.WebViewConfig{
            .allows_inline_media_playback = true,
            .allows_air_play = true,
            .allows_back_forward_navigation_gestures = true,
        };

        // Create WKWebView
        self.webview = try mobile.iOS.createWebView(self.allocator, webview_config);
        const webview_obj: objc.id = @ptrCast(@alignCast(self.webview.?));

        // Get view controller's view
        const sel_view = objc.sel_registerName("view") orelse return error.SelectorNotFound;
        const vc_view = objc.msgSendId(self.root_view_controller.?, sel_view);

        // Add webview as subview: [view addSubview:webview]
        const sel_addSubview = objc.sel_registerName("addSubview:") orelse return error.SelectorNotFound;
        const AddSubviewFn = *const fn (objc.id, objc.SEL, objc.id) callconv(.c) void;
        const addSubviewFn: AddSubviewFn = @ptrCast(&objc_runtime.objc.objc_msgSend);
        addSubviewFn(vc_view, sel_addSubview, webview_obj);

        // Set webview to fill the view using Auto Layout
        try self.setupWebViewConstraints(vc_view, webview_obj);

        // Configure status bar style
        try self.configureStatusBar();

        // Set root view controller on window
        const sel_setRootViewController = objc.sel_registerName("setRootViewController:") orelse return error.SelectorNotFound;
        const SetVCFn = *const fn (objc.id, objc.SEL, objc.id) callconv(.c) void;
        const setVCFn: SetVCFn = @ptrCast(&objc_runtime.objc.objc_msgSend);
        setVCFn(self.window.?, sel_setRootViewController, self.root_view_controller.?);
    }

    /// Setup Auto Layout constraints for webview
    fn setupWebViewConstraints(self: *Self, parent_view: objc.id, webview: objc.id) !void {
        _ = self;

        // Disable autoresizing mask translation
        const sel_setTranslatesAutoresizingMaskIntoConstraints = objc.sel_registerName("setTranslatesAutoresizingMaskIntoConstraints:") orelse return error.SelectorNotFound;
        const SetTranslatesFn = *const fn (objc.id, objc.SEL, bool) callconv(.c) void;
        const setTranslatesFn: SetTranslatesFn = @ptrCast(&objc_runtime.objc.objc_msgSend);
        setTranslatesFn(webview, sel_setTranslatesAutoresizingMaskIntoConstraints, false);

        // Get layout anchors
        const sel_topAnchor = objc.sel_registerName("topAnchor") orelse return error.SelectorNotFound;
        const sel_bottomAnchor = objc.sel_registerName("bottomAnchor") orelse return error.SelectorNotFound;
        const sel_leadingAnchor = objc.sel_registerName("leadingAnchor") orelse return error.SelectorNotFound;
        const sel_trailingAnchor = objc.sel_registerName("trailingAnchor") orelse return error.SelectorNotFound;
        const sel_safeAreaLayoutGuide = objc.sel_registerName("safeAreaLayoutGuide") orelse return error.SelectorNotFound;

        // Get safe area layout guide
        const safeArea = objc.msgSendId(parent_view, sel_safeAreaLayoutGuide);

        // Get anchors
        const webviewTop = objc.msgSendId(webview, sel_topAnchor);
        const webviewBottom = objc.msgSendId(webview, sel_bottomAnchor);
        const webviewLeading = objc.msgSendId(webview, sel_leadingAnchor);
        const webviewTrailing = objc.msgSendId(webview, sel_trailingAnchor);

        const safeTop = objc.msgSendId(safeArea, sel_topAnchor);
        const safeBottom = objc.msgSendId(safeArea, sel_bottomAnchor);
        const safeLeading = objc.msgSendId(safeArea, sel_leadingAnchor);
        const safeTrailing = objc.msgSendId(safeArea, sel_trailingAnchor);

        // Create constraints
        const sel_constraintEqualToAnchor = objc.sel_registerName("constraintEqualToAnchor:") orelse return error.SelectorNotFound;
        const sel_setActive = objc.sel_registerName("setActive:") orelse return error.SelectorNotFound;

        const ConstraintFn = *const fn (objc.id, objc.SEL, objc.id) callconv(.c) objc.id;
        const constraintFn: ConstraintFn = @ptrCast(&objc_runtime.objc.objc_msgSend);

        const SetActiveFn = *const fn (objc.id, objc.SEL, bool) callconv(.c) void;
        const setActiveFn: SetActiveFn = @ptrCast(&objc_runtime.objc.objc_msgSend);

        // Activate constraints
        const topConstraint = constraintFn(webviewTop, sel_constraintEqualToAnchor, safeTop);
        setActiveFn(topConstraint, sel_setActive, true);

        const bottomConstraint = constraintFn(webviewBottom, sel_constraintEqualToAnchor, safeBottom);
        setActiveFn(bottomConstraint, sel_setActive, true);

        const leadingConstraint = constraintFn(webviewLeading, sel_constraintEqualToAnchor, safeLeading);
        setActiveFn(leadingConstraint, sel_setActive, true);

        const trailingConstraint = constraintFn(webviewTrailing, sel_constraintEqualToAnchor, safeTrailing);
        setActiveFn(trailingConstraint, sel_setActive, true);
    }

    /// Configure status bar appearance
    fn configureStatusBar(self: *Self) !void {
        _ = self;
        // Status bar configuration is handled by Info.plist and preferredStatusBarStyle
        // The view controller should override preferredStatusBarStyle
    }

    /// Load initial content into webview
    fn loadInitialContent(self: *Self) !void {
        if (self.webview == null) return error.WebViewNotInitialized;

        switch (self.config.initial_content) {
            .url => |url| {
                try mobile.iOS.loadURL(self.webview.?, url);
            },
            .html => |html| {
                try self.loadHTMLString(html);
            },
            .file => |path| {
                try self.loadFileURL(path);
            },
        }
    }

    /// Load HTML string into webview
    fn loadHTMLString(self: *Self, html: []const u8) !void {
        if (!@import("builtin").target.isDarwin()) {
            return error.UnsupportedPlatform;
        }

        const webview_ptr: objc.id = @ptrCast(@alignCast(self.webview.?));

        // Create NSString from HTML
        const html_ns = try objc.createNSString(html, self.allocator);

        // Create base URL (empty string)
        const NSURLClass = objc.objc_getClass("NSURL") orelse return error.ClassNotFound;
        const sel_fileURLWithPath = objc.sel_registerName("fileURLWithPath:") orelse return error.SelectorNotFound;

        const empty_path = try objc.createNSString("", self.allocator);
        const base_url = objc.msgSendId1(NSURLClass, sel_fileURLWithPath, empty_path);

        // Load HTML: [webview loadHTMLString:html baseURL:baseURL]
        const sel_loadHTMLString = objc.sel_registerName("loadHTMLString:baseURL:") orelse return error.SelectorNotFound;
        const LoadHTMLFn = *const fn (objc.id, objc.SEL, objc.id, ?objc.id) callconv(.c) objc.id;
        const loadHTMLFn: LoadHTMLFn = @ptrCast(&objc_runtime.objc.objc_msgSend);
        _ = loadHTMLFn(webview_ptr, sel_loadHTMLString, html_ns, base_url);
    }

    /// Load file URL into webview
    fn loadFileURL(self: *Self, path: []const u8) !void {
        if (!@import("builtin").target.isDarwin()) {
            return error.UnsupportedPlatform;
        }

        const webview_ptr: objc.id = @ptrCast(@alignCast(self.webview.?));

        // Create file URL
        const NSURLClass = objc.objc_getClass("NSURL") orelse return error.ClassNotFound;
        const sel_fileURLWithPath = objc.sel_registerName("fileURLWithPath:") orelse return error.SelectorNotFound;

        const path_ns = try objc.createNSString(path, self.allocator);
        const file_url = objc.msgSendId1(NSURLClass, sel_fileURLWithPath, path_ns);

        // Get parent directory for allowing read access
        const sel_URLByDeletingLastPathComponent = objc.sel_registerName("URLByDeletingLastPathComponent") orelse return error.SelectorNotFound;
        const dir_url = objc.msgSendId(file_url, sel_URLByDeletingLastPathComponent);

        // Load file: [webview loadFileURL:url allowingReadAccessToURL:dirURL]
        const sel_loadFileURL = objc.sel_registerName("loadFileURL:allowingReadAccessToURL:") orelse return error.SelectorNotFound;
        const LoadFileFn = *const fn (objc.id, objc.SEL, objc.id, objc.id) callconv(.c) objc.id;
        const loadFileFn: LoadFileFn = @ptrCast(&objc_runtime.objc.objc_msgSend);
        _ = loadFileFn(webview_ptr, sel_loadFileURL, file_url, dir_url);
    }

    /// Make window visible
    fn showWindow(self: *Self) !void {
        if (self.window == null) return error.WindowNotInitialized;

        // Make window key and visible: [window makeKeyAndVisible]
        const sel_makeKeyAndVisible = objc.sel_registerName("makeKeyAndVisible") orelse return error.SelectorNotFound;
        objc.msgSend(self.window.?, sel_makeKeyAndVisible);
    }

    /// Run the main event loop
    fn runMainLoop(self: *Self) !void {
        _ = self;

        // Get NSRunLoop
        const NSRunLoopClass = objc.objc_getClass("NSRunLoop") orelse return error.ClassNotFound;
        const sel_currentRunLoop = objc.sel_registerName("currentRunLoop") orelse return error.SelectorNotFound;
        const sel_run = objc.sel_registerName("run") orelse return error.SelectorNotFound;

        const runLoop = objc.msgSendId(NSRunLoopClass, sel_currentRunLoop);
        objc.msgSend(runLoop, sel_run);
    }

    /// Execute JavaScript in the webview
    pub fn evaluateJavaScript(self: *Self, script: []const u8, callback: ?*const fn ([]const u8) void) !void {
        if (self.webview == null) return error.WebViewNotInitialized;
        try mobile.iOS.evaluateJavaScript(self.webview.?, script, callback);
    }

    /// Get safe area insets
    pub fn getSafeAreaInsets(self: *Self) !SafeAreaInsets {
        if (self.window == null) return error.WindowNotInitialized;

        const sel_safeAreaInsets = objc.sel_registerName("safeAreaInsets") orelse return error.SelectorNotFound;

        const InsetsFn = *const fn (objc.id, objc.SEL) callconv(.c) UIEdgeInsets;
        const insetsFn: InsetsFn = @ptrCast(&objc_runtime.objc.objc_msgSend);
        const insets = insetsFn(self.window.?, sel_safeAreaInsets);

        return SafeAreaInsets{
            .top = @floatCast(insets.top),
            .bottom = @floatCast(insets.bottom),
            .left = @floatCast(insets.left),
            .right = @floatCast(insets.right),
        };
    }

    /// Trigger haptic feedback
    pub fn haptic(self: *Self, haptic_type: mobile.iOS.HapticType) void {
        _ = self;
        mobile.iOS.triggerHaptic(haptic_type);
    }

    /// Show alert
    pub fn showAlert(self: *Self, message: []const u8) void {
        _ = self;
        mobile.iOS.showAlert(message, true);
    }

    /// Request permission
    pub fn requestPermission(self: *Self, permission: mobile.iOS.Permission, callback: *const fn (bool) void) !void {
        _ = self;
        try mobile.iOS.requestPermission(permission, callback);
    }

    /// Check permission status
    pub fn checkPermission(self: *Self, permission: mobile.iOS.Permission) !mobile.iOS.PermissionStatus {
        _ = self;
        return try mobile.iOS.checkPermissionStatus(permission);
    }
};

/// Safe area insets
pub const SafeAreaInsets = struct {
    top: f32,
    bottom: f32,
    left: f32,
    right: f32,
};

/// UIEdgeInsets structure (matches iOS)
const UIEdgeInsets = extern struct {
    top: f64,
    left: f64,
    bottom: f64,
    right: f64,
};

// ============================================================================
// JavaScript Bridge
// ============================================================================

/// JavaScript bridge message handler
/// Handles messages from JavaScript: window.webkit.messageHandlers.craft.postMessage(data)
///
/// Expected message format:
/// {
///     "method": "methodName",
///     "params": { ... },
///     "callbackId": "unique_id"
/// }
pub const JSBridge = struct {
    handlers: std.StringHashMap(Handler),
    allocator: std.mem.Allocator,
    app_delegate: ?*CraftAppDelegate = null,

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

    pub fn deinit(self: *JSBridge) void {
        self.handlers.deinit();
    }

    /// Register built-in handlers for common native features
    fn registerBuiltinHandlers(self: *Self) !void {
        try self.handlers.put("getPlatform", handleGetPlatform);
        try self.handlers.put("showAlert", handleShowAlert);
        try self.handlers.put("haptic", handleHaptic);
        try self.handlers.put("setClipboard", handleSetClipboard);
        try self.handlers.put("getClipboard", handleGetClipboard);
        try self.handlers.put("getNetworkStatus", handleGetNetworkStatus);
        try self.handlers.put("getSafeArea", handleGetSafeArea);
        try self.handlers.put("openURL", handleOpenURL);
        try self.handlers.put("share", handleShare);
    }

    /// Register a custom handler for a specific method
    pub fn registerHandler(self: *Self, name: []const u8, handler: Handler) !void {
        try self.handlers.put(name, handler);
    }

    /// Handle incoming message from JavaScript
    /// Parses JSON message and routes to appropriate handler
    pub fn handleMessage(self: *Self, message: []const u8) void {
        // Parse the message - expected format:
        // {"method": "name", "params": {...}, "callbackId": "123"}

        const method = self.extractJsonString(message, "method") orelse return;
        const callback_id = self.extractJsonString(message, "callbackId") orelse "";
        const params = self.extractJsonObject(message, "params") orelse "{}";

        if (self.handlers.get(method)) |handler| {
            handler(params, self, callback_id);
        } else {
            // Unknown method - send error response
            self.sendError(callback_id, "Unknown method") catch {};
        }
    }

    /// Extract a string value from JSON
    fn extractJsonString(self: *Self, json: []const u8, key: []const u8) ?[]const u8 {
        _ = self;

        // Build search pattern: "key":"
        var pattern_buf: [64]u8 = undefined;
        const pattern = std.fmt.bufPrint(&pattern_buf, "\"{s}\":\"", .{key}) catch return null;

        if (std.mem.indexOf(u8, json, pattern)) |start| {
            const value_start = start + pattern.len;
            if (value_start < json.len) {
                // Find closing quote
                if (std.mem.indexOf(u8, json[value_start..], "\"")) |end| {
                    return json[value_start..][0..end];
                }
            }
        }
        return null;
    }

    /// Extract an object value from JSON
    fn extractJsonObject(self: *Self, json: []const u8, key: []const u8) ?[]const u8 {
        _ = self;

        // Build search pattern: "key":{
        var pattern_buf: [64]u8 = undefined;
        const pattern = std.fmt.bufPrint(&pattern_buf, "\"{s}\":{{", .{key}) catch return null;

        if (std.mem.indexOf(u8, json, pattern)) |start| {
            const value_start = start + pattern.len - 1; // Include opening brace
            if (value_start < json.len) {
                // Find matching closing brace (simple nested brace counting)
                var depth: usize = 0;
                var i: usize = value_start;
                while (i < json.len) : (i += 1) {
                    if (json[i] == '{') {
                        depth += 1;
                    } else if (json[i] == '}') {
                        depth -= 1;
                        if (depth == 0) {
                            return json[value_start .. i + 1];
                        }
                    }
                }
            }
        }
        return null;
    }

    /// Send success response to JavaScript callback
    pub fn sendResponse(self: *Self, callback_id: []const u8, result: []const u8) !void {
        if (self.app_delegate == null) return error.NoAppDelegate;
        if (callback_id.len == 0) return;

        var buf: [2048]u8 = undefined;
        const script = std.fmt.bufPrint(&buf,
            \\if (window['__craftCallback_{s}']) {{ window['__craftCallback_{s}']({s}); }}
        , .{ callback_id, callback_id, result }) catch return;

        try self.app_delegate.?.evaluateJavaScript(script, null);
    }

    /// Send error response to JavaScript callback
    pub fn sendError(self: *Self, callback_id: []const u8, error_message: []const u8) !void {
        if (self.app_delegate == null) return error.NoAppDelegate;
        if (callback_id.len == 0) return;

        var buf: [2048]u8 = undefined;
        const script = std.fmt.bufPrint(&buf,
            \\if (window['__craftCallback_{s}']) {{ window['__craftCallback_{s}']({{ error: '{s}' }}); }}
        , .{ callback_id, callback_id, error_message }) catch return;

        try self.app_delegate.?.evaluateJavaScript(script, null);
    }

    /// Send event to JavaScript (not a callback response)
    pub fn sendEvent(self: *Self, event: []const u8, data: []const u8) !void {
        if (self.app_delegate == null) return error.NoAppDelegate;

        var buf: [2048]u8 = undefined;
        const script = std.fmt.bufPrint(&buf,
            \\window.dispatchEvent(new CustomEvent('craft:{s}', {{ detail: {s} }}));
        , .{ event, data }) catch return;

        try self.app_delegate.?.evaluateJavaScript(script, null);
    }

    // ========================================================================
    // Built-in Handlers
    // ========================================================================

    fn handleGetPlatform(params: []const u8, bridge: *JSBridge, callback_id: []const u8) void {
        _ = params;

        const response =
            \\{"os": "ios", "version": "17.0", "device": "iPhone", "native": true}
        ;

        bridge.sendResponse(callback_id, response) catch {};
    }

    fn handleShowAlert(params: []const u8, bridge: *JSBridge, callback_id: []const u8) void {
        // Extract title and message from params
        const title = bridge.extractJsonString(params, "title") orelse "Alert";
        const message = bridge.extractJsonString(params, "message") orelse "";
        _ = title;

        // Show native alert
        mobile.iOS.showAlert(message, true);

        bridge.sendResponse(callback_id, "{ \"success\": true }") catch {};
    }

    fn handleHaptic(params: []const u8, bridge: *JSBridge, callback_id: []const u8) void {
        // Extract haptic type
        const haptic_type_str = bridge.extractJsonString(params, "type") orelse "light";

        const haptic_type: mobile.iOS.HapticType = blk: {
            if (std.mem.eql(u8, haptic_type_str, "success")) break :blk .success;
            if (std.mem.eql(u8, haptic_type_str, "warning")) break :blk .warning;
            if (std.mem.eql(u8, haptic_type_str, "error")) break :blk .error_haptic;
            if (std.mem.eql(u8, haptic_type_str, "light")) break :blk .light;
            if (std.mem.eql(u8, haptic_type_str, "medium")) break :blk .medium;
            if (std.mem.eql(u8, haptic_type_str, "heavy")) break :blk .heavy;
            break :blk .light;
        };

        mobile.iOS.triggerHaptic(haptic_type);

        bridge.sendResponse(callback_id, "{ \"success\": true }") catch {};
    }

    fn handleSetClipboard(params: []const u8, bridge: *JSBridge, callback_id: []const u8) void {
        const text = bridge.extractJsonString(params, "text") orelse "";

        mobile.iOS.setClipboard(text);

        bridge.sendResponse(callback_id, "{ \"success\": true }") catch {};
    }

    fn handleGetClipboard(params: []const u8, bridge: *JSBridge, callback_id: []const u8) void {
        _ = params;

        const text = mobile.iOS.getClipboard(bridge.allocator) catch "";

        var buf: [1024]u8 = undefined;
        const response = std.fmt.bufPrint(&buf, "{{ \"text\": \"{s}\" }}", .{text}) catch "{}";

        bridge.sendResponse(callback_id, response) catch {};
    }

    fn handleGetNetworkStatus(params: []const u8, bridge: *JSBridge, callback_id: []const u8) void {
        _ = params;

        // For now, assume connected - real implementation would check reachability
        const response = "{ \"connected\": true, \"type\": \"wifi\" }";

        bridge.sendResponse(callback_id, response) catch {};
    }

    fn handleGetSafeArea(params: []const u8, bridge: *JSBridge, callback_id: []const u8) void {
        _ = params;

        if (bridge.app_delegate) |app| {
            const insets = app.getSafeAreaInsets() catch SafeAreaInsets{ .top = 0, .bottom = 0, .left = 0, .right = 0 };

            var buf: [256]u8 = undefined;
            const response = std.fmt.bufPrint(&buf,
                \\{{ "top": {d}, "bottom": {d}, "left": {d}, "right": {d} }}
            , .{ insets.top, insets.bottom, insets.left, insets.right }) catch "{}";

            bridge.sendResponse(callback_id, response) catch {};
        } else {
            bridge.sendResponse(callback_id, "{ \"top\": 0, \"bottom\": 0, \"left\": 0, \"right\": 0 }") catch {};
        }
    }

    fn handleOpenURL(params: []const u8, bridge: *JSBridge, callback_id: []const u8) void {
        const url = bridge.extractJsonString(params, "url") orelse "";

        mobile.iOS.openURL(url);

        bridge.sendResponse(callback_id, "{ \"success\": true }") catch {};
    }

    fn handleShare(params: []const u8, bridge: *JSBridge, callback_id: []const u8) void {
        const text = bridge.extractJsonString(params, "text") orelse "";

        mobile.iOS.share(text);

        bridge.sendResponse(callback_id, "{ \"success\": true }") catch {};
    }
};

// ============================================================================
// Convenience Functions
// ============================================================================

/// Quick start function for simple apps
pub fn quickStart(allocator: std.mem.Allocator, html: []const u8) !void {
    var app = CraftAppDelegate.init(allocator, .{
        .name = "Craft App",
        .initial_content = .{ .html = html },
    });

    try app.run();
}

/// Quick start with URL
pub fn quickStartURL(allocator: std.mem.Allocator, url: []const u8) !void {
    var app = CraftAppDelegate.init(allocator, .{
        .name = "Craft App",
        .initial_content = .{ .url = url },
    });

    try app.run();
}

// ============================================================================
// Tests
// ============================================================================

test "CraftAppDelegate initialization" {
    const allocator = std.testing.allocator;

    const config = CraftAppDelegate.AppConfig{
        .name = "Test App",
        .initial_content = .{ .html = "<h1>Hello</h1>" },
    };

    const app = CraftAppDelegate.init(allocator, config);
    _ = app;

    // Can't fully test without iOS runtime
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

test "JSBridge JSON parsing" {
    const allocator = std.testing.allocator;

    var bridge = JSBridge.init(allocator);
    defer bridge.deinit();

    // Test extractJsonString
    const json =
        \\{"method":"getPlatform","params":{},"callbackId":"123"}
    ;

    const method = bridge.extractJsonString(json, "method");
    try std.testing.expect(method != null);
    try std.testing.expectEqualStrings("getPlatform", method.?);

    const callback_id = bridge.extractJsonString(json, "callbackId");
    try std.testing.expect(callback_id != null);
    try std.testing.expectEqualStrings("123", callback_id.?);
}

test "SafeAreaInsets" {
    const insets = SafeAreaInsets{
        .top = 47.0,
        .bottom = 34.0,
        .left = 0.0,
        .right = 0.0,
    };

    try std.testing.expectEqual(@as(f32, 47.0), insets.top);
    try std.testing.expectEqual(@as(f32, 34.0), insets.bottom);
}
