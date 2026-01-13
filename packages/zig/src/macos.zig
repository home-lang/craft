const std = @import("std");

// Objective-C runtime types and functions (manual declarations to avoid @cImport issues)
pub const objc = struct {
    pub const id = ?*anyopaque;
    pub const Class = ?*anyopaque;
    pub const SEL = ?*anyopaque;
    pub const IMP = ?*anyopaque;
    pub const BOOL = bool;
    pub const Method = ?*anyopaque;
    pub const Ivar = ?*anyopaque;
    pub const Protocol = ?*anyopaque;

    // Objective-C runtime functions
    pub extern "objc" fn objc_getClass(name: [*:0]const u8) Class;
    pub extern "objc" fn objc_allocateClassPair(superclass: Class, name: [*:0]const u8, extraBytes: usize) Class;
    pub extern "objc" fn objc_registerClassPair(cls: Class) void;
    pub extern "objc" fn sel_registerName(name: [*:0]const u8) SEL;
    pub extern "objc" fn class_addMethod(cls: Class, name: SEL, imp: IMP, types: [*:0]const u8) BOOL;
    pub extern "objc" fn class_addIvar(cls: Class, name: [*:0]const u8, size: usize, alignment: u8, types: [*:0]const u8) BOOL;
    pub extern "objc" fn object_getIvar(obj: id, ivar: Ivar) id;
    pub extern "objc" fn object_setIvar(obj: id, ivar: Ivar, value: id) void;
    pub extern "objc" fn class_getInstanceVariable(cls: Class, name: [*:0]const u8) Ivar;
    pub extern "objc" fn objc_msgSend() void; // Actual signature varies, cast as needed
    pub extern "objc" fn objc_msgSend_stret() void;
    pub extern "objc" fn object_getClass(obj: id) Class;
    pub extern "objc" fn class_getSuperclass(cls: Class) Class;
    pub extern "objc" fn class_getName(cls: Class) [*:0]const u8;
    pub extern "objc" fn method_getImplementation(m: Method) IMP;
    pub extern "objc" fn class_getInstanceMethod(cls: Class, sel: SEL) Method;
    pub extern "objc" fn class_getClassMethod(cls: Class, sel: SEL) Method;
    pub extern "objc" fn class_getMethodImplementation(cls: Class, sel: SEL) IMP;
    pub extern "objc" fn objc_setAssociatedObject(object: id, key: *const anyopaque, value: id, policy: usize) void;
    pub extern "objc" fn objc_getAssociatedObject(object: id, key: *const anyopaque) id;

    // Association policy constants
    pub const OBJC_ASSOCIATION_ASSIGN: usize = 0;
    pub const OBJC_ASSOCIATION_RETAIN_NONATOMIC: usize = 1;
    pub const OBJC_ASSOCIATION_COPY_NONATOMIC: usize = 3;
    pub const OBJC_ASSOCIATION_RETAIN: usize = 0x301;
    pub const OBJC_ASSOCIATION_COPY: usize = 0x303;
};

pub const NSRect = extern struct {
    origin: NSPoint,
    size: NSSize,
};

pub const NSPoint = extern struct {
    x: f64,
    y: f64,
};

pub const NSSize = extern struct {
    width: f64,
    height: f64,
};

// Window style options
pub const WindowStyle = struct {
    frameless: bool = false,
    transparent: bool = false,
    always_on_top: bool = false,
    resizable: bool = true,
    closable: bool = true,
    miniaturizable: bool = true,
    fullscreen: bool = false,
    x: ?i32 = null, // Window x position (null = center)
    y: ?i32 = null, // Window y position (null = center)
    dark_mode: ?bool = null, // null = system default, true = dark, false = light
    enable_hot_reload: bool = false, // Enable hot reload support
    hide_dock_icon: bool = false, // Hide dock icon (menubar-only mode)
    titlebar_hidden: bool = false, // Hide titlebar (content extends into titlebar area)
    system_tray: bool = false, // Show in system tray (menubar)
    system_tray_title: ?[]const u8 = null, // Initial title for system tray
};

// Helper functions for Objective-C runtime
pub fn getClass(name: [*:0]const u8) objc.Class {
    return objc.objc_getClass(name);
}

pub fn sel(name: [*:0]const u8) objc.SEL {
    return objc.sel_registerName(name);
}

// Simple message send wrappers
pub fn msgSend0(target: anytype, selector: [*:0]const u8) objc.id {
    const msg = @as(*const fn (@TypeOf(target), objc.SEL) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    return msg(target, sel(selector));
}

pub fn msgSend1(target: anytype, selector: [*:0]const u8, arg1: anytype) objc.id {
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, @TypeOf(arg1)) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    return msg(target, sel(selector), arg1);
}

pub fn msgSend2(target: anytype, selector: [*:0]const u8, arg1: anytype, arg2: anytype) objc.id {
    const Arg1Type = if (@TypeOf(arg1) == @TypeOf(null)) ?*anyopaque else @TypeOf(arg1);
    const Arg2Type = if (@TypeOf(arg2) == @TypeOf(null)) ?*anyopaque else @TypeOf(arg2);
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, Arg1Type, Arg2Type) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    const typed_arg1: Arg1Type = if (@TypeOf(arg1) == @TypeOf(null)) null else arg1;
    const typed_arg2: Arg2Type = if (@TypeOf(arg2) == @TypeOf(null)) null else arg2;
    return msg(target, sel(selector), typed_arg1, typed_arg2);
}

pub fn msgSend4(target: anytype, selector: [*:0]const u8, arg1: anytype, arg2: anytype, arg3: anytype, arg4: anytype) objc.id {
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, @TypeOf(arg1), @TypeOf(arg2), @TypeOf(arg3), @TypeOf(arg4)) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    return msg(target, sel(selector), arg1, arg2, arg3, arg4);
}

pub fn msgSendVoid0(target: anytype, selector: [*:0]const u8) void {
    const msg = @as(*const fn (@TypeOf(target), objc.SEL) callconv(.c) void, @ptrCast(&objc.objc_msgSend));
    msg(target, sel(selector));
}

fn msgSendVoid1(target: anytype, selector: [*:0]const u8, arg1: anytype) void {
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, @TypeOf(arg1)) callconv(.c) void, @ptrCast(&objc.objc_msgSend));
    msg(target, sel(selector), arg1);
}

fn msgSendVoid2(target: anytype, selector: [*:0]const u8, arg1: anytype, arg2: anytype) void {
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, @TypeOf(arg1), @TypeOf(arg2)) callconv(.c) void, @ptrCast(&objc.objc_msgSend));
    msg(target, sel(selector), arg1, arg2);
}

pub fn msgSend3(target: anytype, selector: [*:0]const u8, arg1: anytype, arg2: anytype, arg3: anytype) objc.id {
    const Arg1Type = if (@TypeOf(arg1) == @TypeOf(null)) ?*anyopaque else @TypeOf(arg1);
    const Arg2Type = if (@TypeOf(arg2) == @TypeOf(null)) ?*anyopaque else @TypeOf(arg2);
    const Arg3Type = if (@TypeOf(arg3) == @TypeOf(null)) ?*anyopaque else @TypeOf(arg3);
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, Arg1Type, Arg2Type, Arg3Type) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    const typed_arg1: Arg1Type = if (@TypeOf(arg1) == @TypeOf(null)) null else arg1;
    const typed_arg2: Arg2Type = if (@TypeOf(arg2) == @TypeOf(null)) null else arg2;
    const typed_arg3: Arg3Type = if (@TypeOf(arg3) == @TypeOf(null)) null else arg3;
    return msg(target, sel(selector), typed_arg1, typed_arg2, typed_arg3);
}

/// Message send that returns NSRect (for methods like -frame)
pub fn msgSendRect(target: anytype, selector: [*:0]const u8) NSRect {
    const msg = @as(*const fn (@TypeOf(target), objc.SEL) callconv(.c) NSRect, @ptrCast(&objc.objc_msgSend));
    return msg(target, sel(selector));
}

/// Message send that takes NSRect and returns NSRect (for methods like -contentRectForFrameRect:)
pub fn msgSendRect1Rect(target: anytype, selector: [*:0]const u8, rect: NSRect) NSRect {
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, NSRect) callconv(.c) NSRect, @ptrCast(&objc.objc_msgSend));
    return msg(target, sel(selector), rect);
}

/// Message send that returns CGFloat (f64)
pub fn msgSendFloat(target: anytype, selector: [*:0]const u8) f64 {
    const msg = @as(*const fn (@TypeOf(target), objc.SEL) callconv(.c) f64, @ptrCast(&objc.objc_msgSend));
    return msg(target, sel(selector));
}

/// Message send that returns bool
pub fn msgSendBool(target: anytype, selector: [*:0]const u8) bool {
    const msg = @as(*const fn (@TypeOf(target), objc.SEL) callconv(.c) bool, @ptrCast(&objc.objc_msgSend));
    return msg(target, sel(selector));
}

/// Message send that returns NSInteger (c_long)
fn msgSendNSInteger(target: anytype, selector: [*:0]const u8) c_long {
    const msg = @as(*const fn (@TypeOf(target), objc.SEL) callconv(.c) c_long, @ptrCast(&objc.objc_msgSend));
    return msg(target, sel(selector));
}

/// Message send with one bool argument
pub fn msgSend1Bool(target: anytype, selector: [*:0]const u8, arg1: bool) objc.id {
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, bool) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    return msg(target, sel(selector), arg1);
}

/// Message send with one f64 argument
pub fn msgSend1Double(target: anytype, selector: [*:0]const u8, arg1: f64) objc.id {
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, f64) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    return msg(target, sel(selector), arg1);
}

/// Message send that returns f64 with no arguments
pub fn msgSend0Double(target: anytype, selector: [*:0]const u8) f64 {
    const msg = @as(*const fn (@TypeOf(target), objc.SEL) callconv(.c) f64, @ptrCast(&objc.objc_msgSend));
    return msg(target, sel(selector));
}

/// Message send with one NSRect argument (void return)
pub fn msgSendVoid1Rect(target: anytype, selector: [*:0]const u8, rect: NSRect) void {
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, NSRect) callconv(.c) void, @ptrCast(&objc.objc_msgSend));
    msg(target, sel(selector), rect);
}

/// Message send with NSRect + 2 f64 arguments (for bezierPathWithRoundedRect:xRadius:yRadius:)
fn msgSendRect2Double(target: anytype, selector: [*:0]const u8, rect: NSRect, arg1: f64, arg2: f64) objc.id {
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, NSRect, f64, f64) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    return msg(target, sel(selector), rect, arg1, arg2);
}

/// Parse hex color string (e.g. "#ef4444" or "ef4444") and create NSColor
fn createColorFromHex(hex_str: []const u8) ?objc.id {
    // Skip leading # if present
    const hex = if (hex_str.len > 0 and hex_str[0] == '#') hex_str[1..] else hex_str;

    // Must be 6 characters (RRGGBB)
    if (hex.len != 6) return null;

    // Parse hex components
    const r = std.fmt.parseInt(u8, hex[0..2], 16) catch return null;
    const g = std.fmt.parseInt(u8, hex[2..4], 16) catch return null;
    const b = std.fmt.parseInt(u8, hex[4..6], 16) catch return null;

    // Convert to 0.0-1.0 range
    const rf: f64 = @as(f64, @floatFromInt(r)) / 255.0;
    const gf: f64 = @as(f64, @floatFromInt(g)) / 255.0;
    const bf: f64 = @as(f64, @floatFromInt(b)) / 255.0;

    // Create NSColor using colorWithRed:green:blue:alpha:
    const NSColor = getClass("NSColor");
    const color = msgSend4(NSColor, "colorWithRed:green:blue:alpha:", rf, gf, bf, @as(f64, 1.0));

    return color;
}

// Custom borderless window class that can become key window
var BorderlessWindowClass: objc.Class = null;

fn getBorderlessWindowClass() objc.Class {
    if (BorderlessWindowClass != null) return BorderlessWindowClass;

    const NSWindow = getClass("NSWindow");
    BorderlessWindowClass = objc.objc_allocateClassPair(NSWindow, "CraftBorderlessWindow", 0);

    if (BorderlessWindowClass == null) {
        std.debug.print("[Window] Failed to create CraftBorderlessWindow class\n", .{});
        return NSWindow;
    }

    // Override canBecomeKeyWindow to return YES
    const canBecomeKey = struct {
        fn impl(_: objc.id, _: objc.SEL) callconv(.c) bool {
            return true;
        }
    }.impl;
    _ = objc.class_addMethod(BorderlessWindowClass, sel("canBecomeKeyWindow"), @ptrCast(@constCast(&canBecomeKey)), "B@:");

    // Override canBecomeMainWindow to return YES
    const canBecomeMain = struct {
        fn impl(_: objc.id, _: objc.SEL) callconv(.c) bool {
            return true;
        }
    }.impl;
    _ = objc.class_addMethod(BorderlessWindowClass, sel("canBecomeMainWindow"), @ptrCast(@constCast(&canBecomeMain)), "B@:");

    objc.objc_registerClassPair(BorderlessWindowClass);
    std.debug.print("[Window] Created CraftBorderlessWindow class\n", .{});

    return BorderlessWindowClass;
}

pub fn createWindow(title: []const u8, width: u32, height: u32, html: []const u8) !objc.id {
    return createWindowWithStyle(title, width, height, html, null, .{});
}

pub fn createWindowWithHTML(title: []const u8, width: u32, height: u32, html: []const u8, style: WindowStyle) !objc.id {
    return createWindowWithStyle(title, width, height, html, null, style);
}

pub fn createWindowWithURL(title: []const u8, width: u32, height: u32, url: []const u8, style: WindowStyle) !objc.id {
    return createWindowWithStyle(title, width, height, null, url, style);
}

pub fn createWindowWithStyle(title: []const u8, width: u32, height: u32, html: ?[]const u8, url: ?[]const u8, style: WindowStyle) !objc.id {
    // Get classes
    const NSApplication = getClass("NSApplication");
    const NSWindow = getClass("NSWindow");
    const NSString = getClass("NSString");
    const NSURL = getClass("NSURL");
    const NSURLRequest = getClass("NSURLRequest");
    const WKWebView = getClass("WKWebView");
    const WKPreferences = getClass("WKPreferences");
    const WKWebViewConfiguration = getClass("WKWebViewConfiguration");
    const WKUserContentController = getClass("WKUserContentController");

    // Note: Activation policy is set in initApp(), NOT here!
    // We must not call setActivationPolicy after finishLaunching has been called
    // (which happens in initApp before window creation)

    // Get shared application (just to check, not to modify)
    const app = msgSend0(NSApplication, "sharedApplication");
    _ = app; // We get it but don't modify activation policy here anymore

    // Create window frame
    const frame = NSRect{
        .origin = .{
            .x = if (style.x) |x| @as(f64, @floatFromInt(x)) else 100,
            .y = if (style.y) |y| @as(f64, @floatFromInt(y)) else 100,
        },
        .size = .{ .width = @as(f64, @floatFromInt(width)), .height = @as(f64, @floatFromInt(height)) },
    };

    // Build style mask based on options
    var styleMask: c_ulong = 1; // NSTitledWindowMask
    if (!style.frameless) {
        if (style.closable) styleMask |= 2; // NSClosableWindowMask
        if (style.miniaturizable) styleMask |= 4; // NSMiniaturizableWindowMask
        if (style.resizable) styleMask |= 8; // NSResizableWindowMask

        // Add full-size content view for hidden titlebar
        if (style.titlebar_hidden) {
            std.debug.print("[TitlebarHidden] ✓ titlebar_hidden flag is TRUE - adding NSWindowStyleMaskFullSizeContentView\n", .{});
            styleMask |= 32768; // NSWindowStyleMaskFullSizeContentView
            std.debug.print("[TitlebarHidden] ✓ styleMask before window creation: {d}\n", .{styleMask});
        } else {
            std.debug.print("[TitlebarHidden] ✗ titlebar_hidden flag is FALSE\n", .{});
        }
    } else {
        // Borderless window - use NSWindowStyleMaskBorderless (0)
        // Combined with NSWindowStyleMaskNonactivatingPanel behavior workaround
        styleMask = 0;
    }

    const backing: c_ulong = 2; // NSBackingStoreBuffered
    const defer_flag: bool = false;

    // For borderless windows, use custom class that can become key window
    const WindowClass = if (style.frameless) getBorderlessWindowClass() else NSWindow;

    // Allocate and initialize window
    const window_alloc = msgSend0(WindowClass, "alloc");
    const window = msgSend4(window_alloc, "initWithContentRect:styleMask:backing:defer:", frame, styleMask, backing, defer_flag);

    // Create title NSString
    const title_cstr = try std.heap.c_allocator.dupeZ(u8, title);
    defer std.heap.c_allocator.free(title_cstr);
    const title_str_alloc = msgSend0(NSString, "alloc");
    const title_str = msgSend1(title_str_alloc, "initWithUTF8String:", title_cstr.ptr);

    // Set window title
    _ = msgSend1(window, "setTitle:", title_str);

    // Configure transparency
    if (style.transparent) {
        _ = msgSend1(window, "setOpaque:", false);
        _ = msgSend1(window, "setBackgroundColor:", msgSend0(getClass("NSColor"), "clearColor"));
    }

    // For frameless/borderless windows, ensure they can receive mouse events
    if (style.frameless) {
        // Accept mouse moved events
        _ = msgSend1(window, "setAcceptsMouseMovedEvents:", true);
        // Make sure the window can become key (receive keyboard/mouse input)
        _ = msgSend1(window, "setMovableByWindowBackground:", false);
    }

    // Configure always on top
    if (style.always_on_top) {
        const NSFloatingWindowLevel: c_int = 3;
        _ = msgSend1(window, "setLevel:", NSFloatingWindowLevel);
    }

    // Configure titlebar transparency for full-size content view
    if (style.titlebar_hidden) {
        _ = msgSend1(window, "setTitlebarAppearsTransparent:", @as(c_int, 1)); // YES

        // CRITICAL: Hide the title text (NSWindowTitleHidden = 1)
        _ = msgSend1(window, "setTitleVisibility:", @as(c_int, 1)); // NSWindowTitleHidden

        // CRITICAL: Remove the titlebar separator line (NSWindowTitlebarSeparatorStyleNone = 2)
        // This makes the titlebar truly invisible - required for macOS Tahoe/Settings look
        _ = msgSend1(window, "setTitlebarSeparatorStyle:", @as(c_long, 2)); // NSWindowTitlebarSeparatorStyleNone

        // CRITICAL: Position traffic lights in the sidebar (Tahoe/Settings style)
        // Close button (red) - NSWindowCloseButton = 0
        const closeButton = msgSend1(window, "standardWindowButton:", @as(c_ulong, 0));
        if (closeButton != null) {
            _ = msgSend2(closeButton, "setFrameOrigin:", @as(f64, 20.0), @as(f64, @as(f64, @floatFromInt(height)) - 28.0));
        }

        // Minimize button (yellow) - NSWindowMiniaturizeButton = 1
        const miniButton = msgSend1(window, "standardWindowButton:", @as(c_ulong, 1));
        if (miniButton != null) {
            _ = msgSend2(miniButton, "setFrameOrigin:", @as(f64, 40.0), @as(f64, @as(f64, @floatFromInt(height)) - 28.0));
        }

        // Zoom button (green) - NSWindowZoomButton = 2
        const zoomButton = msgSend1(window, "standardWindowButton:", @as(c_ulong, 2));
        if (zoomButton != null) {
            _ = msgSend2(zoomButton, "setFrameOrigin:", @as(f64, 60.0), @as(f64, @as(f64, @floatFromInt(height)) - 28.0));
        }

        std.debug.print("[TitlebarHidden] ✓ COMPLETE: Titlebar hidden, traffic lights positioned in sidebar\n", .{});
    }

    // CRITICAL: Configure toolbar style for Liquid Glass
    // NSWindowToolbarStyleUnified = 1 - Creates unified toolbar that works with glass materials
    _ = msgSend1(window, "setToolbarStyle:", @as(c_long, 1));
    std.debug.print("[LiquidGlass] ✓ Set unified toolbar style for Liquid Glass compatibility\n", .{});

    // CRITICAL: Configure window for vibrancy - allow NSVisualEffectView to show through
    _ = msgSend1(window, "setOpaque:", @as(c_int, 0)); // NO - window is not opaque
    const clearColor = msgSend0(getClass("NSColor"), "clearColor");
    _ = msgSend1(window, "setBackgroundColor:", clearColor);
    std.debug.print("[LiquidGlass] ✓ Window configured for vibrancy (non-opaque, clear background)\n", .{});

    // Create WebView configuration with DevTools enabled
    const config_alloc = msgSend0(WKWebViewConfiguration, "alloc");
    const config = msgSend0(config_alloc, "init");

    const prefs_alloc = msgSend0(WKPreferences, "alloc");
    const prefs = msgSend0(prefs_alloc, "init");

    // Enable JavaScript explicitly (should be enabled by default, but let's be explicit)
    msgSendVoid1(prefs, "setJavaScriptEnabled:", true);

    // Enable developer extras (DevTools)
    const key_str = createNSString("developerExtrasEnabled");
    const value_obj = msgSend1(msgSend0(getClass("NSNumber"), "alloc"), "initWithBool:", true);
    msgSendVoid2(prefs, "setValue:forKey:", value_obj, key_str);

    // Enable camera and microphone access for getUserMedia()
    // javaScriptCanAccessClipboard is needed for some media-related APIs
    const clipboard_key = createNSString("javaScriptCanAccessClipboard");
    const clipboard_value = msgSend1(msgSend0(getClass("NSNumber"), "alloc"), "initWithBool:", true);
    msgSendVoid2(prefs, "setValue:forKey:", clipboard_value, clipboard_key);

    _ = msgSend1(config, "setPreferences:", prefs);

    // Note: allowsInlineMediaPlayback and mediaTypesRequiringUserActionForPlayback
    // are iOS-only properties and not available on macOS WKWebViewConfiguration

    // Set up user content controller for JavaScript bridge
    const userContentController = msgSend0(msgSend0(WKUserContentController, "alloc"), "init");

    // CRITICAL: For URL loading, we MUST use WKUserScript to inject the bridge
    // For HTML loading, we inject directly into the HTML string (more reliable for loadHTMLString)
    if (url != null) {
        // Inject bridge scripts via WKUserScript for URL loading
        const WKUserScript = getClass("WKUserScript");
        const bridge_js = getCraftBridgeScript();
        const native_ui_js = getNativeUIScript();

        // Create bridge script
        const bridge_js_str = createNSString(bridge_js);
        const bridge_script = msgSend3(msgSend0(WKUserScript, "alloc"), "initWithSource:injectionTime:forMainFrameOnly:", bridge_js_str, @as(c_long, 0), // WKUserScriptInjectionTimeAtDocumentStart = 0
            @as(c_int, 1) // YES - main frame only
        );
        _ = msgSend1(userContentController, "addUserScript:", bridge_script);

        // Create native UI script
        const native_ui_js_str = createNSString(native_ui_js);
        const native_ui_script = msgSend3(msgSend0(WKUserScript, "alloc"), "initWithSource:injectionTime:forMainFrameOnly:", native_ui_js_str, @as(c_long, 0), // WKUserScriptInjectionTimeAtDocumentStart = 0
            @as(c_int, 1) // YES - main frame only
        );
        _ = msgSend1(userContentController, "addUserScript:", native_ui_script);

        std.debug.print("[Bridge] Injected bridge scripts via WKUserScript for URL loading\n", .{});
    }
    // NOTE: For HTML loading, we inject the bridge script directly into the HTML instead of using WKUserScript
    // because WKUserScript doesn't reliably inject when using loadHTMLString with null baseURL

    // Set up the script message handler NOW (not later)
    setupScriptMessageHandler(userContentController) catch |err| {
        std.debug.print("[Bridge] Failed to setup message handler: {}\n", .{err});
    };

    _ = msgSend1(config, "setUserContentController:", userContentController);

    // Create WKWebView with configuration
    const webview_alloc = msgSend0(WKWebView, "alloc");
    const webview = msgSend2(webview_alloc, "initWithFrame:configuration:", frame, config);

    // Set up UI delegate for camera/microphone permission handling
    setupUIDelegate(webview) catch |err| {
        std.debug.print("[Media] Failed to setup UI delegate: {}\n", .{err});
    };

    // Load content - either URL or HTML
    if (url) |u| {
        // Load URL directly (no iframe!)
        const url_cstr = try std.heap.c_allocator.dupeZ(u8, u);
        defer std.heap.c_allocator.free(url_cstr);
        const url_str_alloc = msgSend0(NSString, "alloc");
        const url_str = msgSend1(url_str_alloc, "initWithUTF8String:", url_cstr.ptr);

        const nsurl = msgSend1(NSURL, "URLWithString:", url_str);
        const request = msgSend1(NSURLRequest, "requestWithURL:", nsurl);
        _ = msgSend1(webview, "loadRequest:", request);
    } else if (html) |h| {
        // CRITICAL FIX: WKUserScript doesn't reliably inject with loadHTMLString when baseURL is null
        // So we inject the bridge script directly into the HTML before loading
        const bridge_js = getCraftBridgeScript();
        const native_ui_js = getNativeUIScript();

        // Find </head> tag and inject script before it
        var modified_html = try std.ArrayList(u8).initCapacity(std.heap.c_allocator, h.len + bridge_js.len + native_ui_js.len + 40);
        defer modified_html.deinit(std.heap.c_allocator);

        if (std.mem.indexOf(u8, h, "</head>")) |head_pos| {
            // Inject before </head>
            try modified_html.appendSlice(std.heap.c_allocator, h[0..head_pos]);
            try modified_html.appendSlice(std.heap.c_allocator, "<script type=\"text/javascript\">");
            try modified_html.appendSlice(std.heap.c_allocator, bridge_js);
            try modified_html.appendSlice(std.heap.c_allocator, "</script>");
            try modified_html.appendSlice(std.heap.c_allocator, "<script type=\"text/javascript\">");
            try modified_html.appendSlice(std.heap.c_allocator, native_ui_js);
            try modified_html.appendSlice(std.heap.c_allocator, "</script>");
            try modified_html.appendSlice(std.heap.c_allocator, h[head_pos..]);
        } else {
            // No </head> found, just prepend to the HTML
            try modified_html.appendSlice(std.heap.c_allocator, "<script>");
            try modified_html.appendSlice(std.heap.c_allocator, bridge_js);
            try modified_html.appendSlice(std.heap.c_allocator, "</script>");
            try modified_html.appendSlice(std.heap.c_allocator, "<script>");
            try modified_html.appendSlice(std.heap.c_allocator, native_ui_js);
            try modified_html.appendSlice(std.heap.c_allocator, "</script>");
            try modified_html.appendSlice(std.heap.c_allocator, h);
        }

        const final_html = try modified_html.toOwnedSlice(std.heap.c_allocator);
        defer std.heap.c_allocator.free(final_html);

        std.debug.print("[HTML] Injected bridge script ({d} bytes) and native UI script ({d} bytes)\n", .{ bridge_js.len, native_ui_js.len });

        // Load the modified HTML with a proper baseURL
        // This is important - without a baseURL, body scripts may not execute!
        const html_cstr = try std.heap.c_allocator.dupeZ(u8, final_html);
        defer std.heap.c_allocator.free(html_cstr);
        const html_str_alloc = msgSend0(NSString, "alloc");
        const html_str = msgSend1(html_str_alloc, "initWithUTF8String:", html_cstr.ptr);

        // Create a baseURL - use http://localhost to avoid security restrictions
        // about:blank has restrictions on evaluateJavaScript from native code
        const base_url_string = createNSString("http://localhost/");
        const base_url = msgSend1(NSURL, "URLWithString:", base_url_string);

        _ = msgSend2(webview, "loadHTMLString:baseURL:", html_str, base_url);
    }

    // CRITICAL FIX: Get the proper content rect BEFORE setting webview as content view
    // The window's frame includes the titlebar area, but the content view should only
    // fill the content area. We need to calculate the proper content rect.

    // Get the window's content rect (the area below the titlebar)
    const windowFrame: NSRect = msgSendRect(window, "frame");
    const contentRect: NSRect = msgSendRect1Rect(window, "contentRectForFrameRect:", windowFrame);

    std.debug.print("[WebView] Window frame: {d}x{d}, Content rect: {d}x{d}\n", .{
        windowFrame.size.width,
        windowFrame.size.height,
        contentRect.size.width,
        contentRect.size.height,
    });

    // Create the proper frame for the WebView - it should fill the content area
    // The origin should be (0, 0) relative to the content view
    const webviewFrame = NSRect{
        .origin = .{ .x = 0, .y = 0 },
        .size = contentRect.size,
    };

    // Set the WebView's frame to the content area size
    msgSendVoid1Rect(webview, "setFrame:", webviewFrame);
    std.debug.print("[WebView] Set WebView frame to: {d}x{d}\n", .{ webviewFrame.size.width, webviewFrame.size.height });

    // Now set webview as content view
    _ = msgSend1(window, "setContentView:", webview);

    // Also set autoresizing mask to resize with window
    // NSViewWidthSizable = 2, NSViewHeightSizable = 16
    msgSendVoid1(webview, "setAutoresizingMask:", @as(c_ulong, 2 | 16));

    // Store webview and window references globally
    if (webview) |wv| {
        setGlobalWebView(wv);
        // Also set references for tray menu actions
        const tray_menu = @import("tray_menu.zig");
        tray_menu.setGlobalWebView(wv);
        if (window) |win| {
            tray_menu.setGlobalWindow(win);
        }
    }

    // Setup bridge handlers (need allocator and handles)
    // We'll use a global allocator for now
    const allocator = std.heap.c_allocator;
    setupBridgeHandlers(allocator, null, window) catch |err| {
        std.debug.print("[Bridge] Failed to setup bridge handlers: {}\n", .{err});
    };

    // Apply dark mode if specified
    if (style.dark_mode) |is_dark| {
        setAppearance(window, is_dark);
    }

    // Center window if no custom position specified
    if (style.x == null or style.y == null) {
        msgSendVoid0(window, "center");
    }

    // Enter fullscreen if requested
    if (style.fullscreen) {
        msgSendVoid0(window, "toggleFullScreen:");
    }

    // DON'T show window here - it will be shown in runApp() after system tray is created
    // This is critical: makeKeyAndOrderFront activates the app, which must happen AFTER
    // the system tray is created for the menubar item to appear
    // _ = msgSend1(window, "makeKeyAndOrderFront:", @as(?*anyopaque, null));

    return window;
}

// ============================================================================
// Native Sidebar Support (NSSplitViewController + NSVisualEffectView)
// ============================================================================

/// Sidebar item for native NSOutlineView
pub const SidebarItem = struct {
    id: []const u8,
    label: []const u8,
    icon: ?[]const u8 = null, // SF Symbol name
    badge: ?[]const u8 = null,
    tint_color: ?[]const u8 = null, // Hex color for tags
    children: ?[]const SidebarItem = null,
    is_section_header: bool = false,
};

// Global storage for sidebar data source class
var sidebarDataSourceClass: objc.Class = null;

/// Setup a simple data source for the sidebar outline view
/// Returns an Objective-C object that implements NSOutlineViewDataSource and NSOutlineViewDelegate
fn setupSidebarDataSource() !objc.id {
    const NSObject = getClass("NSObject");
    const className = "CraftSidebarDataSource";

    // Check if class already exists
    if (sidebarDataSourceClass == null) {
        sidebarDataSourceClass = objc.objc_getClass(className);
    }

    if (sidebarDataSourceClass == null) {
        std.debug.print("[NativeSidebar] Creating data source class...\n", .{});

        // Create the class
        sidebarDataSourceClass = objc.objc_allocateClassPair(NSObject, className, 0);
        if (sidebarDataSourceClass == null) {
            return error.ClassCreationFailed;
        }

        // Add NSOutlineViewDataSource methods
        // outlineView:numberOfChildrenOfItem:
        _ = objc.class_addMethod(
            sidebarDataSourceClass,
            sel("outlineView:numberOfChildrenOfItem:"),
            @ptrCast(@constCast(&sidebarNumberOfChildren)),
            "l@:@@",
        );

        // outlineView:child:ofItem:
        _ = objc.class_addMethod(
            sidebarDataSourceClass,
            sel("outlineView:child:ofItem:"),
            @ptrCast(@constCast(&sidebarChildOfItem)),
            "@@:@l@",
        );

        // outlineView:isItemExpandable:
        _ = objc.class_addMethod(
            sidebarDataSourceClass,
            sel("outlineView:isItemExpandable:"),
            @ptrCast(@constCast(&sidebarIsItemExpandable)),
            "B@:@@",
        );

        // NSOutlineViewDelegate method for view-based outline
        // outlineView:viewForTableColumn:item:
        _ = objc.class_addMethod(
            sidebarDataSourceClass,
            sel("outlineView:viewForTableColumn:item:"),
            @ptrCast(@constCast(&sidebarViewForItem)),
            "@@:@@@",
        );

        // outlineView:isGroupItem:
        _ = objc.class_addMethod(
            sidebarDataSourceClass,
            sel("outlineView:isGroupItem:"),
            @ptrCast(@constCast(&sidebarIsGroupItem)),
            "B@:@@",
        );

        // outlineViewSelectionDidChange: - Handle selection events
        _ = objc.class_addMethod(
            sidebarDataSourceClass,
            sel("outlineViewSelectionDidChange:"),
            @ptrCast(@constCast(&sidebarSelectionDidChange)),
            "v@:@",
        );

        // outlineView:shouldSelectItem: - Prevent selection of section headers
        _ = objc.class_addMethod(
            sidebarDataSourceClass,
            sel("outlineView:shouldSelectItem:"),
            @ptrCast(@constCast(&sidebarShouldSelectItem)),
            "B@:@@",
        );

        // outlineView:rowViewForItem: - Return custom row view for Finder-style selection
        _ = objc.class_addMethod(
            sidebarDataSourceClass,
            sel("outlineView:rowViewForItem:"),
            @ptrCast(@constCast(&sidebarRowViewForItem)),
            "@@:@@",
        );

        objc.objc_registerClassPair(sidebarDataSourceClass);
        std.debug.print("[NativeSidebar] Data source class registered\n", .{});
    }

    // Create instance
    const instance = msgSend0(msgSend0(sidebarDataSourceClass, "alloc"), "init");
    std.debug.print("[NativeSidebar] Data source instance created\n", .{});

    return instance;
}

// Dynamic sidebar data structures
const DynamicSidebarItem = struct {
    id: []const u8,
    label: []const u8,
    icon: []const u8,
    badge: ?[]const u8 = null,
    tint_color: ?[]const u8 = null,
};

const DynamicSidebarSection = struct {
    id: []const u8,
    title: []const u8,
    items: []DynamicSidebarItem,
    collapsed: bool = false,
};

// Global dynamic sidebar data (parsed from JSON config)
var dynamic_sections: ?[]DynamicSidebarSection = null;
var sidebar_allocator: ?std.mem.Allocator = null;

// Global WebView reference for sending sidebar events
var sidebar_webview: objc.id = null;

// Default demo sections (used when no config provided)
const default_sections = [_]DynamicSidebarSection{
    .{
        .id = "favorites",
        .title = "Favorites",
        .items = @constCast(&[_]DynamicSidebarItem{
            .{ .id = "home", .label = "Home", .icon = "house.fill" },
            .{ .id = "documents", .label = "Documents", .icon = "folder.fill" },
            .{ .id = "downloads", .label = "Downloads", .icon = "arrow.down.circle.fill" },
        }),
    },
    .{
        .id = "icloud",
        .title = "iCloud",
        .items = @constCast(&[_]DynamicSidebarItem{
            .{ .id = "icloud-drive", .label = "iCloud Drive", .icon = "externaldrive.fill.badge.icloud" },
            .{ .id = "shared", .label = "Shared", .icon = "person.2.fill" },
        }),
    },
    .{
        .id = "tags",
        .title = "Tags",
        .items = @constCast(&[_]DynamicSidebarItem{
            .{ .id = "tag-red", .label = "Red", .icon = "circle.fill", .tint_color = "#ef4444" },
            .{ .id = "tag-blue", .label = "Blue", .icon = "circle.fill", .tint_color = "#3b82f6" },
            .{ .id = "tag-green", .label = "Green", .icon = "circle.fill", .tint_color = "#22c55e" },
        }),
    },
};

/// Get the current sidebar sections (dynamic or default)
fn getSidebarSections() []const DynamicSidebarSection {
    if (dynamic_sections) |sections| {
        return sections;
    }
    return &default_sections;
}

/// Parse JSON sidebar configuration
fn parseSidebarConfig(json: []const u8) !void {
    std.debug.print("[NativeSidebar] Parsing sidebar config ({d} bytes)\n", .{json.len});

    // Use a simple allocator for parsing
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    sidebar_allocator = arena.allocator();
    const allocator = sidebar_allocator.?;

    // Parse JSON using std.json
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, json, .{}) catch |err| {
        std.debug.print("[NativeSidebar] JSON parse error: {}\n", .{err});
        return err;
    };
    const root = parsed.value;

    // Extract sections array
    const sections_json = root.object.get("sections") orelse {
        std.debug.print("[NativeSidebar] No 'sections' field in config\n", .{});
        return;
    };

    const sections_array = sections_json.array;
    var sections = try allocator.alloc(DynamicSidebarSection, sections_array.items.len);

    for (sections_array.items, 0..) |section_val, i| {
        const section_obj = section_val.object;

        // Get section fields
        const id = if (section_obj.get("id")) |v| v.string else "section";
        const title = if (section_obj.get("title")) |v| v.string else "Section";
        const collapsed = if (section_obj.get("collapsed")) |v| v.bool else false;

        // Parse items
        const items_json = section_obj.get("items") orelse continue;
        const items_array = items_json.array;
        var items = try allocator.alloc(DynamicSidebarItem, items_array.items.len);

        for (items_array.items, 0..) |item_val, j| {
            const item_obj = item_val.object;

            items[j] = .{
                .id = if (item_obj.get("id")) |v| v.string else "item",
                .label = if (item_obj.get("label")) |v| v.string else "Item",
                .icon = if (item_obj.get("icon")) |v| v.string else "doc",
                .badge = if (item_obj.get("badge")) |v| switch (v) {
                    .string => |s| s,
                    .integer => |n| std.fmt.allocPrint(allocator, "{d}", .{n}) catch null,
                    else => null,
                } else null,
                .tint_color = if (item_obj.get("tintColor")) |v| v.string else null,
            };
        }

        sections[i] = .{
            .id = id,
            .title = title,
            .items = items,
            .collapsed = collapsed,
        };
    }

    dynamic_sections = sections;
    std.debug.print("[NativeSidebar] Parsed {d} sections from config\n", .{sections.len});
}

// NSOutlineViewDataSource: numberOfChildrenOfItem
fn sidebarNumberOfChildren(
    _: objc.id,
    _: objc.SEL,
    _: objc.id, // outlineView
    item: objc.id,
) callconv(.c) c_long {
    const sections = getSidebarSections();

    // If item is nil, return number of sections
    if (item == null) {
        return @intCast(sections.len);
    }

    // Check if it's a section (NSNumber with section index)
    const isSection = msgSend1(item, "respondsToSelector:", sel("isSection"));
    if (@intFromPtr(isSection) != 0) {
        // It's a section wrapper, get the children count
        const idx_obj = msgSend0(item, "sectionIndex");
        const idx: usize = @intCast(@intFromPtr(idx_obj));
        if (idx < sections.len) {
            return @intCast(sections[idx].items.len);
        }
    }

    // Regular items have no children
    return 0;
}

// NSOutlineViewDataSource: child:ofItem
fn sidebarChildOfItem(
    _: objc.id,
    _: objc.SEL,
    _: objc.id, // outlineView
    index: c_long,
    item: objc.id,
) callconv(.c) objc.id {
    const sections = getSidebarSections();
    const idx: usize = @intCast(index);

    // If item is nil, return section wrapper
    if (item == null) {
        if (idx >= sections.len) return null;
        return createSectionWrapper(idx);
    }

    // Check if it's a section
    const isSection = msgSend1(item, "respondsToSelector:", sel("isSection"));
    if (@intFromPtr(isSection) != 0) {
        const section_idx_obj = msgSend0(item, "sectionIndex");
        const section_idx: usize = @intCast(@intFromPtr(section_idx_obj));
        if (section_idx < sections.len) {
            const section = &sections[section_idx];
            if (idx < section.items.len) {
                return createItemWrapper(section_idx, idx);
            }
        }
    }

    return null;
}

// NSOutlineViewDataSource: isItemExpandable
fn sidebarIsItemExpandable(
    _: objc.id,
    _: objc.SEL,
    _: objc.id, // outlineView
    item: objc.id,
) callconv(.c) bool {
    if (item == null) return false;

    // Sections are expandable
    const isSection = msgSend1(item, "respondsToSelector:", sel("isSection"));
    return @intFromPtr(isSection) != 0;
}

// NSOutlineViewDelegate: isGroupItem (for section headers)
fn sidebarIsGroupItem(
    _: objc.id,
    _: objc.SEL,
    _: objc.id, // outlineView
    item: objc.id,
) callconv(.c) bool {
    if (item == null) return false;

    // Sections are group items
    const isSection = msgSend1(item, "respondsToSelector:", sel("isSection"));
    return @intFromPtr(isSection) != 0;
}

// NSOutlineViewDelegate: selectionDidChange - Handle selection events
fn sidebarSelectionDidChange(
    _: objc.id,
    _: objc.SEL,
    notification: objc.id,
) callconv(.c) void {
    // Get the outline view from the notification
    const outlineView = msgSend0(notification, "object");
    if (outlineView == null) return;

    // Get selected row (returns NSInteger, can be -1 if no selection)
    const rowIndex = msgSendNSInteger(outlineView, "selectedRow");

    // -1 means no selection (NSNotFound or deselected)
    if (rowIndex < 0) return;

    // Get the item at the selected row
    const item = msgSend1(outlineView, "itemAtRow:", rowIndex);
    if (item == null) return;

    // Check if it's a section (we don't send events for sections)
    const isSection = msgSend1(item, "respondsToSelector:", sel("isSection"));
    if (@intFromPtr(isSection) != 0) return;

    // Get item indices
    const isItem = msgSend1(item, "respondsToSelector:", sel("itemIndex"));
    if (@intFromPtr(isItem) == 0) return;

    const section_idx_obj = msgSend0(item, "sectionIndex");
    const item_idx_obj = msgSend0(item, "itemIndex");
    const section_idx: usize = @intCast(@intFromPtr(section_idx_obj));
    const item_idx: usize = @intCast(@intFromPtr(item_idx_obj));

    const sections = getSidebarSections();
    if (section_idx >= sections.len) return;

    const section = &sections[section_idx];
    if (item_idx >= section.items.len) return;

    const child = &section.items[item_idx];

    std.debug.print("[NativeSidebar] Selection changed: section={s}, item={s}\n", .{ section.id, child.id });

    // Send event to WebView if available
    if (sidebar_webview != null) {
        // Create JavaScript to dispatch sidebar selection event
        var js_buf: [1024]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buf,
            \\if (window.craft && window.craft._sidebarSelectHandler) {{
            \\  window.craft._sidebarSelectHandler({{
            \\    itemId: "{s}",
            \\    sectionId: "{s}",
            \\    item: {{ id: "{s}", label: "{s}", icon: "{s}" }}
            \\  }});
            \\}}
        , .{ child.id, section.id, child.id, child.label, child.icon }) catch return;

        const js_str = createNSString(js);
        _ = msgSend2(sidebar_webview, "evaluateJavaScript:completionHandler:", js_str, @as(?*anyopaque, null));
    }
}

// NSOutlineViewDelegate: shouldSelectItem - Prevent section headers from being selected
fn sidebarShouldSelectItem(
    _: objc.id,
    _: objc.SEL,
    _: objc.id, // outlineView
    item: objc.id,
) callconv(.c) bool {
    if (item == null) return false;

    // Section headers (group items) should not be selectable
    const isSection = msgSend1(item, "respondsToSelector:", sel("isSection"));
    if (@intFromPtr(isSection) != 0) {
        return false; // Don't allow selection of section headers
    }

    return true; // Allow selection of regular items
}

// NSOutlineViewDelegate: viewForTableColumn:item
fn sidebarViewForItem(
    _: objc.id,
    _: objc.SEL,
    outlineView: objc.id,
    _: objc.id, // tableColumn
    item: objc.id,
) callconv(.c) objc.id {
    const NSTableCellView = getClass("NSTableCellView");
    const NSTextField = getClass("NSTextField");
    const NSImageView = getClass("NSImageView");
    const NSImage = getClass("NSImage");

    // Determine if this is a section or item
    const isSection = msgSend1(item, "respondsToSelector:", sel("isSection"));
    const isSectionItem = @intFromPtr(isSection) != 0;

    // Get the appropriate identifier
    const identifier = if (isSectionItem) createNSString("HeaderCell") else createNSString("DataCell");

    // Try to reuse a cell
    var cellView = msgSend2(outlineView, "makeViewWithIdentifier:owner:", identifier, @as(?*anyopaque, null));

    if (cellView == null) {
        // Create new cell view
        const frame = NSRect{
            .origin = .{ .x = 0, .y = 0 },
            .size = .{ .width = 200, .height = 24 },
        };

        const cellAlloc = msgSend0(NSTableCellView, "alloc");
        cellView = msgSend1Rect(cellAlloc, "initWithFrame:", frame);
        _ = msgSend1(cellView, "setIdentifier:", identifier);

        // Create text field
        const textField = msgSend0(msgSend0(NSTextField, "alloc"), "init");
        _ = msgSend1(textField, "setBezeled:", @as(c_int, 0));
        _ = msgSend1(textField, "setDrawsBackground:", @as(c_int, 0));
        _ = msgSend1(textField, "setEditable:", @as(c_int, 0));
        _ = msgSend1(textField, "setSelectable:", @as(c_int, 0));

        if (isSectionItem) {
            // Section header style
            const font = msgSend1(getClass("NSFont"), "boldSystemFontOfSize:", @as(f64, 11.0));
            _ = msgSend1(textField, "setFont:", font);
        } else {
            // Regular item style
            const font = msgSend1(getClass("NSFont"), "systemFontOfSize:", @as(f64, 13.0));
            _ = msgSend1(textField, "setFont:", font);
        }

        _ = msgSend1(cellView, "setTextField:", textField);
        _ = msgSend1(cellView, "addSubview:", textField);

        // Create image view for icons (only for non-section items)
        if (!isSectionItem) {
            const imageView = msgSend0(msgSend0(NSImageView, "alloc"), "init");
            _ = msgSend1(cellView, "setImageView:", imageView);
            _ = msgSend1(cellView, "addSubview:", imageView);
        }

        // Set autoresizing
        msgSendVoid1(textField, "setAutoresizingMask:", @as(c_ulong, 2)); // Width flexible
    }

    // Get the text field and set the text
    const textField = msgSend0(cellView, "textField");
    const sections = getSidebarSections();

    if (isSectionItem) {
        const section_idx_obj = msgSend0(item, "sectionIndex");
        const section_idx: usize = @intCast(@intFromPtr(section_idx_obj));
        if (section_idx < sections.len) {
            const section = &sections[section_idx];
            _ = msgSend1(textField, "setStringValue:", createNSString(section.title));
        }
    } else {
        const isItem = msgSend1(item, "respondsToSelector:", sel("itemIndex"));
        if (@intFromPtr(isItem) != 0) {
            const section_idx_obj = msgSend0(item, "sectionIndex");
            const item_idx_obj = msgSend0(item, "itemIndex");
            const section_idx: usize = @intCast(@intFromPtr(section_idx_obj));
            const item_idx: usize = @intCast(@intFromPtr(item_idx_obj));

            if (section_idx < sections.len) {
                const section = &sections[section_idx];
                if (item_idx < section.items.len) {
                    const child = &section.items[item_idx];
                    _ = msgSend1(textField, "setStringValue:", createNSString(child.label));

                    // Set the icon using SF Symbols
                    const imageView = msgSend0(cellView, "imageView");
                    if (imageView != null) {
                        const symbolName = createNSString(child.icon);
                        const image = msgSend2(NSImage, "imageWithSystemSymbolName:accessibilityDescription:", symbolName, @as(?*anyopaque, null));
                        if (image != null) {
                            _ = msgSend1(imageView, "setImage:", image);

                            // Apply tint color if specified
                            if (child.tint_color) |tint_hex| {
                                if (createColorFromHex(tint_hex)) |tintColor| {
                                    _ = msgSend1(imageView, "setContentTintColor:", tintColor);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    return cellView;
}

// Custom row view class for Finder-style selection
var sidebarRowViewClass: objc.Class = null;

fn getSidebarRowViewClass() objc.Class {
    if (sidebarRowViewClass != null) return sidebarRowViewClass;

    const NSTableRowView = getClass("NSTableRowView");
    sidebarRowViewClass = objc.objc_allocateClassPair(NSTableRowView, "CraftSidebarRowView", 0);

    if (sidebarRowViewClass == null) {
        std.debug.print("[NativeSidebar] Failed to create CraftSidebarRowView class\n", .{});
        return NSTableRowView;
    }

    // Override drawSelectionInRect: to draw custom selection
    _ = objc.class_addMethod(
        sidebarRowViewClass,
        sel("drawSelectionInRect:"),
        @ptrCast(@constCast(&rowViewDrawSelection)),
        "v@:{CGRect=dddd}",
    );

    // Override isEmphasized to return NO for subtle selection
    _ = objc.class_addMethod(
        sidebarRowViewClass,
        sel("isEmphasized"),
        @ptrCast(@constCast(&rowViewIsEmphasized)),
        "B@:",
    );

    objc.objc_registerClassPair(sidebarRowViewClass);
    std.debug.print("[NativeSidebar] Custom row view class registered\n", .{});

    return sidebarRowViewClass;
}

// Custom drawing for selection - Finder-style subtle gray pill
fn rowViewDrawSelection(
    self: objc.id,
    _: objc.SEL,
    dirtyRect: NSRect,
) callconv(.c) void {
    _ = dirtyRect;

    // Only draw if selected
    const isSelected = msgSendBool(self, "isSelected");
    if (!isSelected) return;

    // Get the bounds
    const bounds = msgSendRect(self, "bounds");

    // Create a slightly inset rounded rect for the selection
    const inset: f64 = 4.0;
    const selectionRect = NSRect{
        .origin = .{ .x = inset, .y = 1.0 },
        .size = .{ .width = bounds.size.width - (inset * 2), .height = bounds.size.height - 2.0 },
    };

    // Create NSBezierPath for rounded rect
    const NSBezierPath = getClass("NSBezierPath");
    const cornerRadius: f64 = 6.0;
    const path = msgSendRect2Double(NSBezierPath, "bezierPathWithRoundedRect:xRadius:yRadius:", selectionRect, cornerRadius, cornerRadius);

    // Set the fill color - subtle gray like Finder
    // Light mode: rgba(0, 0, 0, 0.06), Dark mode: rgba(255, 255, 255, 0.10)
    const NSColor = getClass("NSColor");

    // Use a color that works for both light and dark mode
    // This creates a subtle selection similar to Finder
    const fillColor = msgSend2(NSColor, "colorWithWhite:alpha:", @as(f64, 0.5), @as(f64, 0.12));

    _ = msgSend0(fillColor, "setFill");
    _ = msgSend0(path, "fill");
}

// Return NO for isEmphasized to get the subtle (non-key window) selection style
fn rowViewIsEmphasized(
    _: objc.id,
    _: objc.SEL,
) callconv(.c) bool {
    return false;
}

// NSOutlineViewDelegate: rowViewForItem - Return custom row view
fn sidebarRowViewForItem(
    _: objc.id,
    _: objc.SEL,
    _: objc.id, // outlineView
    _: objc.id, // item
) callconv(.c) objc.id {
    const rowViewClass = getSidebarRowViewClass();
    const rowView = msgSend0(msgSend0(rowViewClass, "alloc"), "init");
    return rowView;
}

// Global class for section wrappers
var sidebarSectionWrapperClass: objc.Class = null;
var sidebarItemWrapperClass: objc.Class = null;

// Create a wrapper object for a section
fn createSectionWrapper(section_idx: usize) objc.id {
    if (sidebarSectionWrapperClass == null) {
        const NSObject = getClass("NSObject");
        sidebarSectionWrapperClass = objc.objc_allocateClassPair(NSObject, "CraftSidebarSectionWrapper", 0);

        // Add isSection method that returns YES
        _ = objc.class_addMethod(
            sidebarSectionWrapperClass,
            sel("isSection"),
            @ptrCast(@constCast(&wrapperIsSection)),
            "B@:",
        );

        // Add sectionIndex method
        _ = objc.class_addMethod(
            sidebarSectionWrapperClass,
            sel("sectionIndex"),
            @ptrCast(@constCast(&wrapperSectionIndex)),
            "L@:",
        );

        // Add ivar to store section index
        _ = objc.class_addIvar(sidebarSectionWrapperClass, "_sectionIdx", @sizeOf(usize), @alignOf(usize), "L");

        objc.objc_registerClassPair(sidebarSectionWrapperClass);
    }

    const instance = msgSend0(msgSend0(sidebarSectionWrapperClass, "alloc"), "init");

    // Store the section index using associated objects (simpler than ivar)
    const key = @as(*const anyopaque, @ptrCast(&sidebarSectionWrapperClass));
    const NSNumber = getClass("NSNumber");
    const idx_num = msgSend1(NSNumber, "numberWithUnsignedLong:", @as(c_ulong, section_idx));
    objc.objc_setAssociatedObject(instance, key, idx_num, objc.OBJC_ASSOCIATION_RETAIN);

    return instance;
}

// Create a wrapper object for an item
fn createItemWrapper(section_idx: usize, item_idx: usize) objc.id {
    if (sidebarItemWrapperClass == null) {
        const NSObject = getClass("NSObject");
        sidebarItemWrapperClass = objc.objc_allocateClassPair(NSObject, "CraftSidebarItemWrapper", 0);

        // Add itemIndex method
        _ = objc.class_addMethod(
            sidebarItemWrapperClass,
            sel("itemIndex"),
            @ptrCast(@constCast(&wrapperItemIndex)),
            "L@:",
        );

        // Add sectionIndex method
        _ = objc.class_addMethod(
            sidebarItemWrapperClass,
            sel("sectionIndex"),
            @ptrCast(@constCast(&wrapperItemSectionIndex)),
            "L@:",
        );

        objc.objc_registerClassPair(sidebarItemWrapperClass);
    }

    const instance = msgSend0(msgSend0(sidebarItemWrapperClass, "alloc"), "init");

    // Store indices using associated objects
    const section_key = @as(*const anyopaque, @ptrCast(&sidebarItemWrapperClass));
    const item_key = @as(*const anyopaque, @ptrFromInt(@intFromPtr(section_key) + 1));

    const NSNumber = getClass("NSNumber");
    const section_num = msgSend1(NSNumber, "numberWithUnsignedLong:", @as(c_ulong, section_idx));
    const item_num = msgSend1(NSNumber, "numberWithUnsignedLong:", @as(c_ulong, item_idx));

    objc.objc_setAssociatedObject(instance, section_key, section_num, objc.OBJC_ASSOCIATION_RETAIN);
    objc.objc_setAssociatedObject(instance, item_key, item_num, objc.OBJC_ASSOCIATION_RETAIN);

    return instance;
}

// Wrapper methods
fn wrapperIsSection(_: objc.id, _: objc.SEL) callconv(.c) bool {
    return true;
}

fn wrapperSectionIndex(self: objc.id, _: objc.SEL) callconv(.c) c_ulong {
    const key = @as(*const anyopaque, @ptrCast(&sidebarSectionWrapperClass));
    const num = objc.objc_getAssociatedObject(self, key);
    if (num == null) return 0;
    const val = msgSend0(num, "unsignedLongValue");
    return @intCast(@intFromPtr(val));
}

fn wrapperItemIndex(self: objc.id, _: objc.SEL) callconv(.c) c_ulong {
    const section_key = @as(*const anyopaque, @ptrCast(&sidebarItemWrapperClass));
    const item_key = @as(*const anyopaque, @ptrFromInt(@intFromPtr(section_key) + 1));
    const num = objc.objc_getAssociatedObject(self, item_key);
    if (num == null) return 0;
    const val = msgSend0(num, "unsignedLongValue");
    return @intCast(@intFromPtr(val));
}

fn wrapperItemSectionIndex(self: objc.id, _: objc.SEL) callconv(.c) c_ulong {
    const section_key = @as(*const anyopaque, @ptrCast(&sidebarItemWrapperClass));
    const num = objc.objc_getAssociatedObject(self, section_key);
    if (num == null) return 0;
    const val = msgSend0(num, "unsignedLongValue");
    return @intCast(@intFromPtr(val));
}

/// Create a window with a native macOS sidebar (Finder-style)
/// This uses NSSplitViewController, NSVisualEffectView, and NSOutlineView
pub fn createWindowWithSidebar(
    title: []const u8,
    width: u32,
    height: u32,
    html: []const u8,
    sidebar_width: u32,
    sidebar_config_json: ?[]const u8,
    style: WindowStyle,
) !objc.id {
    // Parse sidebar config if provided
    if (sidebar_config_json) |json| {
        parseSidebarConfig(json) catch |err| {
            std.debug.print("[NativeSidebar] Failed to parse sidebar config: {}\n", .{err});
        };
    }
    const NSApplication = getClass("NSApplication");
    const NSWindow = getClass("NSWindow");
    const NSString = getClass("NSString");
    const NSSplitViewController = getClass("NSSplitViewController");
    const NSSplitViewItem = getClass("NSSplitViewItem");
    const NSViewController = getClass("NSViewController");
    const NSVisualEffectView = getClass("NSVisualEffectView");
    const NSScrollView = getClass("NSScrollView");
    const NSOutlineView = getClass("NSOutlineView");
    const NSTableColumn = getClass("NSTableColumn");
    const WKWebView = getClass("WKWebView");
    const WKWebViewConfiguration = getClass("WKWebViewConfiguration");
    const WKPreferences = getClass("WKPreferences");
    const WKUserContentController = getClass("WKUserContentController");

    _ = NSApplication;
    std.debug.print("[NativeSidebar] Creating window with native macOS sidebar...\n", .{});

    // Create window frame
    const frame = NSRect{
        .origin = .{
            .x = if (style.x) |x| @as(f64, @floatFromInt(x)) else 200,
            .y = if (style.y) |y| @as(f64, @floatFromInt(y)) else 200,
        },
        .size = .{ .width = @as(f64, @floatFromInt(width)), .height = @as(f64, @floatFromInt(height)) },
    };

    // Style mask with full-size content view for proper toolbar integration
    var styleMask: c_ulong = 1 | 2 | 4 | 8; // Titled, Closable, Miniaturizable, Resizable
    styleMask |= 32768; // NSWindowStyleMaskFullSizeContentView

    const backing: c_ulong = 2;
    const defer_flag: bool = false;

    // Create window
    const window_alloc = msgSend0(NSWindow, "alloc");
    const window = msgSend4(window_alloc, "initWithContentRect:styleMask:backing:defer:", frame, styleMask, backing, defer_flag);

    // Set window title
    const title_cstr = try std.heap.c_allocator.dupeZ(u8, title);
    defer std.heap.c_allocator.free(title_cstr);
    const title_str = msgSend1(msgSend0(NSString, "alloc"), "initWithUTF8String:", title_cstr.ptr);
    _ = msgSend1(window, "setTitle:", title_str);

    // Configure for native sidebar appearance
    _ = msgSend1(window, "setTitlebarAppearsTransparent:", @as(c_int, 1));
    _ = msgSend1(window, "setTitleVisibility:", @as(c_int, 1)); // NSWindowTitleHidden = 1

    // Create NSToolbar - this is REQUIRED for traffic lights to appear in sidebar
    const NSToolbar = getClass("NSToolbar");
    const toolbar_id = createNSString("MainToolbar");
    const toolbar_alloc = msgSend0(NSToolbar, "alloc");
    const toolbar = msgSend1(toolbar_alloc, "initWithIdentifier:", toolbar_id);
    _ = msgSend1(toolbar, "setShowsBaselineSeparator:", @as(c_int, 0));
    _ = msgSend1(window, "setToolbar:", toolbar);
    _ = msgSend1(window, "setToolbarStyle:", @as(c_long, 3)); // NSWindowToolbarStyleUnifiedCompact = 3

    std.debug.print("[NativeSidebar] Window created with toolbar for traffic lights\n", .{});

    // ========================================
    // Create NSSplitViewController
    // ========================================
    const splitVC_alloc = msgSend0(NSSplitViewController, "alloc");
    const splitVC = msgSend0(splitVC_alloc, "init");

    // ========================================
    // Create Sidebar View Controller
    // ========================================

    // Create NSVisualEffectView for sidebar vibrancy
    const sidebarFrame = NSRect{
        .origin = .{ .x = 0, .y = 0 },
        .size = .{ .width = @as(f64, @floatFromInt(sidebar_width)), .height = @as(f64, @floatFromInt(height)) },
    };

    const visualEffect_alloc = msgSend0(NSVisualEffectView, "alloc");
    const visualEffectView = msgSend1Rect(visualEffect_alloc, "initWithFrame:", sidebarFrame);

    // Set material to sidebar (NSVisualEffectMaterialSidebar = 7)
    _ = msgSend1(visualEffectView, "setMaterial:", @as(c_long, 7));
    // Set blending mode to behind window (NSVisualEffectBlendingModeBehindWindow = 0)
    _ = msgSend1(visualEffectView, "setBlendingMode:", @as(c_long, 0));
    // Set state to follow window (NSVisualEffectStateFollowsWindowActiveState = 0)
    _ = msgSend1(visualEffectView, "setState:", @as(c_long, 0));

    std.debug.print("[NativeSidebar] Created NSVisualEffectView with sidebar material\n", .{});

    // Create NSScrollView for the outline view
    const scrollView_alloc = msgSend0(NSScrollView, "alloc");
    const scrollView = msgSend1Rect(scrollView_alloc, "initWithFrame:", sidebarFrame);
    _ = msgSend1(scrollView, "setHasVerticalScroller:", @as(c_int, 1));
    _ = msgSend1(scrollView, "setHasHorizontalScroller:", @as(c_int, 0));
    _ = msgSend1(scrollView, "setAutohidesScrollers:", @as(c_int, 1));
    _ = msgSend1(scrollView, "setBorderType:", @as(c_long, 0)); // NSNoBorder = 0
    _ = msgSend1(scrollView, "setDrawsBackground:", @as(c_int, 0)); // Transparent for vibrancy

    // Create NSOutlineView with source list style
    const outlineView_alloc = msgSend0(NSOutlineView, "alloc");
    const outlineView = msgSend1Rect(outlineView_alloc, "initWithFrame:", sidebarFrame);

    // Configure source list style (NSTableViewStyleSourceList)
    _ = msgSend1(outlineView, "setStyle:", @as(c_long, 1)); // NSTableViewStyleSourceList = 1
    _ = msgSend1(outlineView, "setSelectionHighlightStyle:", @as(c_long, 1)); // NSTableViewSelectionHighlightStyleSourceList = 1
    _ = msgSend1(outlineView, "setRowSizeStyle:", @as(c_long, 2)); // NSTableViewRowSizeStyleDefault = 2
    _ = msgSend1(outlineView, "setFloatsGroupRows:", @as(c_int, 1));
    _ = msgSend1(outlineView, "setIndentationPerLevel:", @as(f64, 13.0));
    _ = msgSend1(outlineView, "setHeaderView:", @as(?*anyopaque, null)); // No header

    // Create table column
    const columnId = createNSString("SidebarColumn");
    const column_alloc = msgSend0(NSTableColumn, "alloc");
    const column = msgSend1(column_alloc, "initWithIdentifier:", columnId);
    _ = msgSend1(column, "setWidth:", @as(f64, @floatFromInt(sidebar_width - 20)));
    _ = msgSend1(outlineView, "addTableColumn:", column);
    _ = msgSend1(outlineView, "setOutlineTableColumn:", column);

    std.debug.print("[NativeSidebar] Created NSOutlineView with source list style\n", .{});

    // Setup data source and delegate for the outline view
    const dataSource = try setupSidebarDataSource();
    _ = msgSend1(outlineView, "setDataSource:", dataSource);
    _ = msgSend1(outlineView, "setDelegate:", dataSource);

    // Reload data and expand all sections
    _ = msgSend0(outlineView, "reloadData");

    // Expand all root items (sections)
    const numSections = msgSend0(outlineView, "numberOfRows");
    const numSectionsInt: c_long = @intCast(@intFromPtr(numSections));
    std.debug.print("[NativeSidebar] Number of rows after reload: {d}\n", .{numSectionsInt});

    // Expand root items
    var i: c_long = 0;
    while (i < numSectionsInt) : (i += 1) {
        const item = msgSend1(outlineView, "itemAtRow:", i);
        if (item != null) {
            _ = msgSend1(outlineView, "expandItem:", item);
        }
    }

    std.debug.print("[NativeSidebar] Data source configured with demo items\n", .{});

    // Set outline view as document view of scroll view
    _ = msgSend1(scrollView, "setDocumentView:", outlineView);

    // Add scroll view to visual effect view
    _ = msgSend1(visualEffectView, "addSubview:", scrollView);
    // Set autoresizing mask for scroll view
    msgSendVoid1(scrollView, "setAutoresizingMask:", @as(c_ulong, 2 | 16)); // Width + Height

    // Create sidebar view controller
    const sidebarVC_alloc = msgSend0(NSViewController, "alloc");
    const sidebarVC = msgSend0(sidebarVC_alloc, "init");
    _ = msgSend1(sidebarVC, "setView:", visualEffectView);

    // Create sidebar split view item
    const sidebarItem = msgSend1(NSSplitViewItem, "sidebarWithViewController:", sidebarVC);
    _ = msgSend1(sidebarItem, "setCanCollapse:", @as(c_int, 1));
    _ = msgSend1(sidebarItem, "setMinimumThickness:", @as(f64, 180.0));
    _ = msgSend1(sidebarItem, "setMaximumThickness:", @as(f64, 320.0));

    // Add sidebar to split view controller
    _ = msgSend1(splitVC, "addSplitViewItem:", sidebarItem);

    std.debug.print("[NativeSidebar] Sidebar view controller configured\n", .{});

    // ========================================
    // Create Content (WebView) View Controller
    // ========================================

    const contentFrame = NSRect{
        .origin = .{ .x = 0, .y = 0 },
        .size = .{ .width = @as(f64, @floatFromInt(width - sidebar_width)), .height = @as(f64, @floatFromInt(height)) },
    };

    // Create WebView configuration
    const config_alloc = msgSend0(WKWebViewConfiguration, "alloc");
    const config = msgSend0(config_alloc, "init");

    const prefs_alloc = msgSend0(WKPreferences, "alloc");
    const prefs = msgSend0(prefs_alloc, "init");
    msgSendVoid1(prefs, "setJavaScriptEnabled:", true);

    // Enable developer extras
    const key_str = createNSString("developerExtrasEnabled");
    const value_obj = msgSend1(msgSend0(getClass("NSNumber"), "alloc"), "initWithBool:", true);
    msgSendVoid2(prefs, "setValue:forKey:", value_obj, key_str);
    _ = msgSend1(config, "setPreferences:", prefs);

    // Set up user content controller
    const userContentController = msgSend0(msgSend0(WKUserContentController, "alloc"), "init");
    setupScriptMessageHandler(userContentController) catch |err| {
        std.debug.print("[Bridge] Failed to setup message handler: {}\n", .{err});
    };
    _ = msgSend1(config, "setUserContentController:", userContentController);

    // Create WKWebView
    const webview_alloc = msgSend0(WKWebView, "alloc");
    const webview = msgSend2(webview_alloc, "initWithFrame:configuration:", contentFrame, config);

    // Setup UI delegate
    setupUIDelegate(webview) catch |err| {
        std.debug.print("[Media] Failed to setup UI delegate: {}\n", .{err});
    };

    // Load HTML content with bridge injection
    const bridge_js = getCraftBridgeScript();
    const native_ui_js = getNativeUIScript();

    var modified_html = try std.ArrayList(u8).initCapacity(std.heap.c_allocator, html.len + bridge_js.len + native_ui_js.len + 100);
    defer modified_html.deinit(std.heap.c_allocator);

    if (std.mem.indexOf(u8, html, "</head>")) |head_pos| {
        try modified_html.appendSlice(std.heap.c_allocator, html[0..head_pos]);
        try modified_html.appendSlice(std.heap.c_allocator, "<script>");
        try modified_html.appendSlice(std.heap.c_allocator, bridge_js);
        try modified_html.appendSlice(std.heap.c_allocator, "</script><script>");
        try modified_html.appendSlice(std.heap.c_allocator, native_ui_js);
        try modified_html.appendSlice(std.heap.c_allocator, "</script>");
        try modified_html.appendSlice(std.heap.c_allocator, html[head_pos..]);
    } else {
        try modified_html.appendSlice(std.heap.c_allocator, "<script>");
        try modified_html.appendSlice(std.heap.c_allocator, bridge_js);
        try modified_html.appendSlice(std.heap.c_allocator, "</script><script>");
        try modified_html.appendSlice(std.heap.c_allocator, native_ui_js);
        try modified_html.appendSlice(std.heap.c_allocator, "</script>");
        try modified_html.appendSlice(std.heap.c_allocator, html);
    }

    const final_html = try modified_html.toOwnedSlice(std.heap.c_allocator);
    defer std.heap.c_allocator.free(final_html);

    const html_cstr = try std.heap.c_allocator.dupeZ(u8, final_html);
    defer std.heap.c_allocator.free(html_cstr);
    const html_str = msgSend1(msgSend0(NSString, "alloc"), "initWithUTF8String:", html_cstr.ptr);
    const base_url_string = createNSString("http://localhost/");
    const base_url = msgSend1(getClass("NSURL"), "URLWithString:", base_url_string);
    _ = msgSend2(webview, "loadHTMLString:baseURL:", html_str, base_url);

    std.debug.print("[NativeSidebar] WebView created and HTML loaded\n", .{});

    // Store WebView reference for sidebar events
    sidebar_webview = webview;

    // Create content view controller
    const contentVC_alloc = msgSend0(NSViewController, "alloc");
    const contentVC = msgSend0(contentVC_alloc, "init");
    _ = msgSend1(contentVC, "setView:", webview);

    // Create content split view item
    const contentItem = msgSend1(NSSplitViewItem, "contentListWithViewController:", contentVC);
    _ = msgSend1(splitVC, "addSplitViewItem:", contentItem);

    std.debug.print("[NativeSidebar] Content view controller configured\n", .{});

    // ========================================
    // Set split view controller as window's content
    // ========================================

    _ = msgSend1(window, "setContentViewController:", splitVC);

    // Apply dark mode if specified
    if (style.dark_mode) |is_dark| {
        setAppearance(window, is_dark);
    }

    // Center window
    if (style.x == null or style.y == null) {
        msgSendVoid0(window, "center");
    }

    // Store references
    if (webview) |wv| {
        setGlobalWebView(wv);
        const tray_menu = @import("tray_menu.zig");
        tray_menu.setGlobalWebView(wv);
        if (window) |win| {
            tray_menu.setGlobalWindow(win);
        }
    }

    // Setup bridge handlers
    setupBridgeHandlers(std.heap.c_allocator, null, window) catch |err| {
        std.debug.print("[Bridge] Failed to setup bridge handlers: {}\n", .{err});
    };

    std.debug.print("[NativeSidebar] ✓ Window with native sidebar created successfully\n", .{});

    return window;
}

// Helper to send message with NSRect parameter
fn msgSend1Rect(target: anytype, selector: [*:0]const u8, rect: NSRect) objc.id {
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, NSRect) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    return msg(target, sel(selector), rect);
}

// Helper to create NSString
pub fn createNSString(str: []const u8) objc.id {
    const NSString = getClass("NSString");
    const str_alloc = msgSend0(NSString, "alloc");
    const cstr = std.heap.c_allocator.dupeZ(u8, str) catch unreachable;
    defer std.heap.c_allocator.free(cstr);
    return msgSend1(str_alloc, "initWithUTF8String:", cstr.ptr);
}

// Clipboard functions
pub fn setClipboard(text: []const u8) !void {
    const NSPasteboard = getClass("NSPasteboard");
    const NSString = getClass("NSString");

    const pasteboard = msgSend0(NSPasteboard, "generalPasteboard");
    msgSendVoid0(pasteboard, "clearContents");

    const text_cstr = try std.heap.c_allocator.dupeZ(u8, text);
    defer std.heap.c_allocator.free(text_cstr);
    const text_str_alloc = msgSend0(NSString, "alloc");
    const text_str = msgSend1(text_str_alloc, "initWithUTF8String:", text_cstr.ptr);

    _ = msgSend1(pasteboard, "setString:forType:", text_str);
}

pub fn getClipboard(allocator: std.mem.Allocator) ![]const u8 {
    const NSPasteboard = getClass("NSPasteboard");
    const pasteboard = msgSend0(NSPasteboard, "generalPasteboard");
    const str = msgSend0(pasteboard, "stringForType:");

    if (str == null) return error.NoClipboardContent;

    const cstr: [*:0]const u8 = @ptrCast(msgSend0(str, "UTF8String"));
    return allocator.dupe(u8, std.mem.span(cstr));
}

// Native dialog support
pub fn showOpenDialog(title: []const u8, allow_multiple: bool) !?[]const u8 {
    const NSOpenPanel = getClass("NSOpenPanel");
    const panel = msgSend0(NSOpenPanel, "openPanel");

    // Set title
    const title_cstr = try std.heap.c_allocator.dupeZ(u8, title);
    defer std.heap.c_allocator.free(title_cstr);
    const title_str_alloc = msgSend0(getClass("NSString"), "alloc");
    const title_str = msgSend1(title_str_alloc, "initWithUTF8String:", title_cstr.ptr);
    _ = msgSend1(panel, "setTitle:", title_str);

    // Set options
    _ = msgSend1(panel, "setCanChooseFiles:", true);
    _ = msgSend1(panel, "setCanChooseDirectories:", false);
    _ = msgSend1(panel, "setAllowsMultipleSelection:", allow_multiple);

    // Run modal
    const result = msgSend0(panel, "runModal");
    const NSModalResponseOK: c_long = 1;

    if (@as(c_long, @intCast(@intFromPtr(result))) != NSModalResponseOK) {
        return null;
    }

    // Get selected URL
    const urls = msgSend0(panel, "URLs");
    const count = @as(usize, @intCast(@intFromPtr(msgSend0(urls, "count"))));

    if (count == 0) return null;

    const url = msgSend1(urls, "objectAtIndex:", @as(c_ulong, 0));
    const path = msgSend0(url, "path");
    const cstr: [*:0]const u8 = @ptrCast(msgSend0(path, "UTF8String"));

    return std.heap.c_allocator.dupe(u8, std.mem.span(cstr));
}

pub fn showSaveDialog(title: []const u8, default_name: ?[]const u8) !?[]const u8 {
    const NSSavePanel = getClass("NSSavePanel");
    const panel = msgSend0(NSSavePanel, "savePanel");

    // Set title
    const title_cstr = try std.heap.c_allocator.dupeZ(u8, title);
    defer std.heap.c_allocator.free(title_cstr);
    const title_str_alloc = msgSend0(getClass("NSString"), "alloc");
    const title_str = msgSend1(title_str_alloc, "initWithUTF8String:", title_cstr.ptr);
    _ = msgSend1(panel, "setTitle:", title_str);

    // Set default name if provided
    if (default_name) |name| {
        const name_cstr = try std.heap.c_allocator.dupeZ(u8, name);
        defer std.heap.c_allocator.free(name_cstr);
        const name_str_alloc = msgSend0(getClass("NSString"), "alloc");
        const name_str = msgSend1(name_str_alloc, "initWithUTF8String:", name_cstr.ptr);
        _ = msgSend1(panel, "setNameFieldStringValue:", name_str);
    }

    // Run modal
    const result = msgSend0(panel, "runModal");
    const NSModalResponseOK: c_long = 1;

    if (@as(c_long, @intCast(@intFromPtr(result))) != NSModalResponseOK) {
        return null;
    }

    // Get selected URL
    const url = msgSend0(panel, "URL");
    const path = msgSend0(url, "path");
    const cstr: [*:0]const u8 = @ptrCast(msgSend0(path, "UTF8String"));

    return std.heap.c_allocator.dupe(u8, std.mem.span(cstr));
}

// Window control functions
pub fn minimizeWindow(window_handle: anytype) void {
    const window: objc.id = if (@TypeOf(window_handle) == objc.id) window_handle else @ptrFromInt(@intFromPtr(window_handle));
    msgSendVoid0(window, "miniaturize:");
}

pub fn maximizeWindow(window: objc.id) void {
    msgSendVoid0(window, "zoom:");
}

pub fn toggleFullscreen(window: objc.id) void {
    msgSendVoid0(window, "toggleFullScreen:");
}

pub fn closeWindow(window_handle: anytype) void {
    const window: objc.id = if (@TypeOf(window_handle) == objc.id) window_handle else @ptrFromInt(@intFromPtr(window_handle));
    msgSendVoid0(window, "close");
}

pub fn hideWindow(window_handle: anytype) void {
    const window: objc.id = if (@TypeOf(window_handle) == objc.id) window_handle else @ptrFromInt(@intFromPtr(window_handle));
    msgSendVoid0(window, "orderOut:");
}

pub fn showWindow(window_handle: anytype) void {
    const window: objc.id = if (@TypeOf(window_handle) == objc.id) window_handle else @ptrFromInt(@intFromPtr(window_handle));
    _ = msgSend1(window, "makeKeyAndOrderFront:", @as(?*anyopaque, null));
}

pub fn toggleWindow(window_handle: anytype) void {
    const window: objc.id = if (@TypeOf(window_handle) == objc.id) window_handle else @ptrFromInt(@intFromPtr(window_handle));
    const is_visible = msgSend0(window, "isVisible");
    const visible_int = @as(c_int, @intCast(@intFromPtr(is_visible)));

    if (visible_int != 0) {
        hideWindow(window);
    } else {
        showWindow(window);
    }
}

pub fn setWindowPosition(window: objc.id, x: i32, y: i32) void {
    const point = NSPoint{ .x = @as(f64, @floatFromInt(x)), .y = @as(f64, @floatFromInt(y)) };
    msgSendVoid1(window, "setFrameTopLeftPoint:", point);
}

pub fn setWindowSize(window: objc.id, width: u32, height: u32) void {
    var frame = msgSendRect(window, "frame");
    frame.size.width = @as(f64, @floatFromInt(width));
    frame.size.height = @as(f64, @floatFromInt(height));
    msgSendVoid2(window, "setFrame:display:", frame, true);
}

// Notification support
pub fn showNotification(title: []const u8, message: []const u8) !void {
    const NSUserNotification = getClass("NSUserNotification");
    const NSUserNotificationCenter = getClass("NSUserNotificationCenter");

    const notification = msgSend0(msgSend0(NSUserNotification, "alloc"), "init");

    // Set title
    const title_cstr = try std.heap.c_allocator.dupeZ(u8, title);
    defer std.heap.c_allocator.free(title_cstr);
    const title_str_alloc = msgSend0(getClass("NSString"), "alloc");
    const title_str = msgSend1(title_str_alloc, "initWithUTF8String:", title_cstr.ptr);
    _ = msgSend1(notification, "setTitle:", title_str);

    // Set message
    const msg_cstr = try std.heap.c_allocator.dupeZ(u8, message);
    defer std.heap.c_allocator.free(msg_cstr);
    const msg_str_alloc = msgSend0(getClass("NSString"), "alloc");
    const msg_str = msgSend1(msg_str_alloc, "initWithUTF8String:", msg_cstr.ptr);
    _ = msgSend1(notification, "setInformativeText:", msg_str);

    // Deliver notification
    const center = msgSend0(NSUserNotificationCenter, "defaultUserNotificationCenter");
    msgSendVoid1(center, "deliverNotification:", notification);
}

// Hot reload - reload URL in webview
pub fn reloadWindow(webview: objc.id) void {
    msgSendVoid0(webview, "reload:");
}

pub fn reloadWindowIgnoringCache(webview: objc.id) void {
    msgSendVoid0(webview, "reloadFromOrigin:");
}

// System tray integration
pub const SystemTray = struct {
    status_item: objc.id,

    pub fn create(title: []const u8) !SystemTray {
        const NSStatusBar = getClass("NSStatusBar");
        const status_bar = msgSend0(NSStatusBar, "systemStatusBar");

        const status_item = msgSend1(status_bar, "statusItemWithLength:", -1.0);

        // Set title
        const title_cstr = try std.heap.c_allocator.dupeZ(u8, title);
        defer std.heap.c_allocator.free(title_cstr);
        const title_str_alloc = msgSend0(getClass("NSString"), "alloc");
        const title_str = msgSend1(title_str_alloc, "initWithUTF8String:", title_cstr.ptr);

        const button = msgSend0(status_item, "button");
        _ = msgSend1(button, "setTitle:", title_str);

        return .{ .status_item = status_item };
    }

    pub fn setTitle(self: SystemTray, title: []const u8) !void {
        const title_cstr = try std.heap.c_allocator.dupeZ(u8, title);
        defer std.heap.c_allocator.free(title_cstr);
        const title_str_alloc = msgSend0(getClass("NSString"), "alloc");
        const title_str = msgSend1(title_str_alloc, "initWithUTF8String:", title_cstr.ptr);

        const button = msgSend0(self.status_item, "button");
        _ = msgSend1(button, "setTitle:", title_str);
    }

    pub fn remove(self: SystemTray) void {
        const NSStatusBar = getClass("NSStatusBar");
        const status_bar = msgSend0(NSStatusBar, "systemStatusBar");
        msgSendVoid1(status_bar, "removeStatusItem:", self.status_item);
    }
};

// Keyboard shortcuts/hotkeys
pub fn registerGlobalHotkey(key_code: u16, modifiers: u32) void {
    // This would require NSEvent monitoring
    // For now, we'll provide the structure
    _ = key_code;
    _ = modifiers;
}

// Multi-monitor awareness
pub const Monitor = struct {
    frame: NSRect,
    visible_frame: NSRect,
    name: []const u8,
};

pub fn getAllMonitors(allocator: std.mem.Allocator) ![]Monitor {
    const NSScreen = getClass("NSScreen");
    const screens = msgSend0(NSScreen, "screens");
    const count_obj = msgSend0(screens, "count");
    const count = @as(usize, @intCast(@as(i64, @bitCast(count_obj))));

    var monitors = try allocator.alloc(Monitor, count);

    for (0..count) |i| {
        const screen = msgSend1(screens, "objectAtIndex:", i);
        const frame = msgSend0(screen, "frame");
        const visible_frame = msgSend0(screen, "visibleFrame");

        monitors[i] = .{
            .frame = @as(NSRect, @bitCast(frame)),
            .visible_frame = @as(NSRect, @bitCast(visible_frame)),
            .name = "", // Would need to get from screen description
        };
    }

    return monitors;
}

pub fn getMainMonitor() Monitor {
    const NSScreen = getClass("NSScreen");
    const main_screen = msgSend0(NSScreen, "mainScreen");
    const frame = msgSend0(main_screen, "frame");
    const visible_frame = msgSend0(main_screen, "visibleFrame");

    return .{
        .frame = @as(NSRect, @bitCast(frame)),
        .visible_frame = @as(NSRect, @bitCast(visible_frame)),
        .name = "Main",
    };
}

// Screenshot/capture
pub fn captureWindow(window: objc.id, file_path: []const u8) !void {
    const window_id = msgSend0(window, "windowNumber");
    const CGWindowListCreateImage = @as(*const fn (NSRect, u32, u32, u32) callconv(.c) ?*anyopaque, @ptrFromInt(0)); // Placeholder
    _ = CGWindowListCreateImage;
    _ = window_id;
    _ = file_path;
    // Would need Core Graphics bindings for full implementation
}

pub fn captureScreen(file_path: []const u8) !void {
    _ = file_path;
    // Would need Core Graphics bindings
}

// Print support
pub fn printWindow(webview: objc.id) void {
    // Create print operation
    const print_op = msgSend0(webview, "printOperationWithPrintInfo:");
    msgSendVoid0(print_op, "runOperation");
}

pub fn showPrintDialog(webview: objc.id) void {
    const NSPrintInfo = getClass("NSPrintInfo");
    const print_info = msgSend0(NSPrintInfo, "sharedPrintInfo");

    const print_op_class = getClass("NSPrintOperation");
    const print_op = msgSend2(print_op_class, "printOperationWithView:printInfo:", webview, print_info);
    _ = msgSend1(print_op, "runOperationModalForWindow:delegate:didRunSelector:contextInfo:", @as(?*anyopaque, null));
}

// Download management
pub const Download = struct {
    url: []const u8,
    destination: []const u8,
    progress: f64 = 0.0,
};

pub fn startDownload(url: []const u8, destination: []const u8) !Download {
    return .{
        .url = url,
        .destination = destination,
        .progress = 0.0,
    };
}

// Theme support (dark/light mode)
pub fn setAppearance(window: objc.id, dark_mode: bool) void {
    const NSAppearance = getClass("NSAppearance");
    const appearance_name = if (dark_mode) "NSAppearanceNameDarkAqua" else "NSAppearanceNameAqua";

    const name_cstr: [*:0]const u8 = appearance_name;
    const appearance = msgSend1(NSAppearance, "appearanceNamed:", name_cstr);
    _ = msgSend1(window, "setAppearance:", appearance);
}

pub fn getSystemAppearance() bool {
    const NSApp = getClass("NSApplication");
    const app = msgSend0(NSApp, "sharedApplication");
    const appearance = msgSend0(app, "effectiveAppearance");
    const name = msgSend0(appearance, "name");

    // Check if dark mode
    const dark_name_cstr: [*:0]const u8 = "NSAppearanceNameDarkAqua";
    const dark_str_alloc = msgSend0(getClass("NSString"), "alloc");
    const dark_str = msgSend1(dark_str_alloc, "initWithUTF8String:", dark_name_cstr);

    const is_equal = msgSend1(name, "isEqualToString:", dark_str);
    return @as(i64, @bitCast(is_equal)) != 0;
}

// Performance monitoring
pub const PerformanceMetrics = struct {
    memory_usage_mb: f64,
    cpu_usage_percent: f64,
    fps: f64,
};

pub fn getPerformanceMetrics() PerformanceMetrics {
    // Would need to integrate with task_info and mach APIs
    return .{
        .memory_usage_mb = 0.0,
        .cpu_usage_percent = 0.0,
        .fps = 60.0,
    };
}

// Window events
pub const WindowEventType = enum {
    close,
    resize,
    move,
    focus,
    blur,
    minimize,
    maximize,
};

pub const WindowEvent = struct {
    event_type: WindowEventType,
    window: objc.id,
    data: ?*anyopaque = null,
};

// Window event callback (simplified - would need delegate in real implementation)
pub const WindowEventCallback = *const fn (WindowEvent) void;

// Store webview reference for access by window
var global_webview: ?objc.id = null;

pub fn setGlobalWebView(webview: objc.id) void {
    global_webview = webview;
}

pub fn getGlobalWebView() ?objc.id {
    return global_webview;
}

// ============================================================================
// JavaScript Bridge Injection
// ============================================================================

/// Generate the complete Craft JavaScript bridge to inject into WebViews
fn getCraftBridgeScript() []const u8 {
    return 
    \\ // Craft JavaScript Bridge - Auto-injected
    \\ (function() {
    \\   console.log('[Craft] Initializing JavaScript bridge...');
    \\
    \\   // Define the bridge API immediately (so it's available for use)
    \\   window.craft = window.craft || {};
    \\   window.__craftBridgePending = window.__craftBridgePending || {};
    \\   window.__craftBridgeResult = function(action, payload) {
    \\     try {
    \\       const pendingMap = window.__craftBridgePending || {};
    \\       const queue = pendingMap[action];
    \\       if (queue && queue.length > 0) {
    \\         const entry = queue.shift();
    \\         if (entry && typeof entry.resolve === 'function') {
    \\           entry.resolve(payload || {});
    \\         }
    \\       }
    \\     } catch (e) {
    \\       console.error('[Craft] Bridge result handler error:', e);
    \\     }
    \\   };
    \\   window.__craftBridgeError = function(error) {
    \\     try {
    \\       console.error('[Craft] Bridge error from native:', error);
    \\       const pendingMap = window.__craftBridgePending || {};
    \\       Object.keys(pendingMap).forEach((key) => {
    \\         const queue = pendingMap[key];
    \\         if (Array.isArray(queue)) {
    \\           while (queue.length > 0) {
    \\             const entry = queue.shift();
    \\             if (entry && typeof entry.reject === 'function') {
    \\               entry.reject(error);
    \\             }
    \\           }
    \\         }
    \\       });
    \\       window.__craftBridgePending = {};
    \\     } catch (e) {
    \\       console.error('[Craft] Bridge error handler failure:', e);
    \\     }
    \\   };
    \\
    \\   // ===== TRAY API =====
    \\   window.craft.tray = {
    \\     async setTitle(title) {
    \\       if (typeof title !== 'string') throw new TypeError('Title must be a string');
    \\       if (title.length > 20) {
    \\         console.warn('Tray title truncated to 20 characters');
    \\         title = title.substring(0, 20);
    \\       }
    \\       return new Promise((resolve, reject) => {
    \\         try {
    \\           window.webkit.messageHandlers.craft.postMessage({
    \\             type: 'tray', action: 'setTitle', data: title
    \\           });
    \\           resolve();
    \\         } catch (error) {
    \\           reject(new Error(`Failed to set tray title: ${error.message}`));
    \\         }
    \\       });
    \\     },
    \\     async setTooltip(tooltip) {
    \\       if (typeof tooltip !== 'string') throw new TypeError('Tooltip must be a string');
    \\       return new Promise((resolve, reject) => {
    \\         try {
    \\           window.webkit.messageHandlers.craft.postMessage({
    \\             type: 'tray', action: 'setTooltip', data: tooltip
    \\           });
    \\           resolve();
    \\         } catch (error) {
    \\           reject(new Error(`Failed to set tray tooltip: ${error.message}`));
    \\         }
    \\       });
    \\     },
    \\     async setMenu(items) {
    \\       if (!Array.isArray(items)) throw new TypeError('Menu items must be an array');
    \\       return new Promise((resolve, reject) => {
    \\         try {
    \\           window.webkit.messageHandlers.craft.postMessage({
    \\             type: 'tray', action: 'setMenu', data: JSON.stringify(items)
    \\           });
    \\           resolve();
    \\         } catch (error) {
    \\           reject(new Error(`Failed to set tray menu: ${error.message}`));
    \\         }
    \\       });
    \\     },
    \\     onClick(callback) {
    \\       if (typeof callback !== 'function') throw new TypeError('Callback must be a function');
    \\       const handler = (event) => {
    \\         callback({
    \\           button: event.detail?.button || 'left',
    \\           timestamp: event.detail?.timestamp || Date.now(),
    \\           modifiers: event.detail?.modifiers || {}
    \\         });
    \\       };
    \\       if (!window.__craft_tray_handlers) window.__craft_tray_handlers = [];
    \\       window.__craft_tray_handlers.push(handler);
    \\       window.addEventListener('craft:tray:click', handler);
    \\       return () => {
    \\         const index = window.__craft_tray_handlers.indexOf(handler);
    \\         if (index > -1) window.__craft_tray_handlers.splice(index, 1);
    \\         window.removeEventListener('craft:tray:click', handler);
    \\       };
    \\     },
    \\     onClickToggleWindow() {
    \\       return this.onClick(() => { window.craft.window.toggle(); });
    \\     }
    \\   };
    \\
    \\   // ===== WINDOW API =====
    \\   window.craft.window = {
    \\     async show() {
    \\       return new Promise((resolve, reject) => {
    \\         try {
    \\           window.webkit.messageHandlers.craft.postMessage({
    \\             type: 'window', action: 'show'
    \\           });
    \\           resolve();
    \\         } catch (error) {
    \\           reject(new Error(`Failed to show window: ${error.message}`));
    \\         }
    \\       });
    \\     },
    \\     async hide() {
    \\       return new Promise((resolve, reject) => {
    \\         try {
    \\           window.webkit.messageHandlers.craft.postMessage({
    \\             type: 'window', action: 'hide'
    \\           });
    \\           resolve();
    \\         } catch (error) {
    \\           reject(new Error(`Failed to hide window: ${error.message}`));
    \\         }
    \\       });
    \\     },
    \\     async toggle() {
    \\       return new Promise((resolve, reject) => {
    \\         try {
    \\           window.webkit.messageHandlers.craft.postMessage({
    \\             type: 'window', action: 'toggle'
    \\           });
    \\           resolve();
    \\         } catch (error) {
    \\           reject(new Error(`Failed to toggle window: ${error.message}`));
    \\         }
    \\       });
    \\     },
    \\     async minimize() {
    \\       return new Promise((resolve, reject) => {
    \\         try {
    \\           window.webkit.messageHandlers.craft.postMessage({
    \\             type: 'window', action: 'minimize'
    \\           });
    \\           resolve();
    \\         } catch (error) {
    \\           reject(new Error(`Failed to minimize window: ${error.message}`));
    \\         }
    \\       });
    \\     },
    \\     async close() {
    \\       return new Promise((resolve, reject) => {
    \\         try {
    \\           window.webkit.messageHandlers.craft.postMessage({
    \\             type: 'window', action: 'close'
    \\           });
    \\           resolve();
    \\         } catch (error) {
    \\           reject(new Error(`Failed to close window: ${error.message}`));
    \\         }
    \\       });
    \\     }
    \\   };
    \\
    \\   // ===== APP API =====
    \\   window.craft.app = {
    \\     async hideDockIcon() {
    \\       return new Promise((resolve, reject) => {
    \\         try {
    \\           window.webkit.messageHandlers.craft.postMessage({
    \\             type: 'app', action: 'hideDockIcon'
    \\           });
    \\           resolve();
    \\         } catch (error) {
    \\           reject(new Error(`Failed to hide dock icon: ${error.message}`));
    \\         }
    \\       });
    \\     },
    \\     async showDockIcon() {
    \\       return new Promise((resolve, reject) => {
    \\         try {
    \\           window.webkit.messageHandlers.craft.postMessage({
    \\             type: 'app', action: 'showDockIcon'
    \\           });
    \\           resolve();
    \\         } catch (error) {
    \\           reject(new Error(`Failed to show dock icon: ${error.message}`));
    \\         }
    \\       });
    \\     },
    \\     async quit() {
    \\       return new Promise((resolve, reject) => {
    \\         try {
    \\           window.webkit.messageHandlers.craft.postMessage({
    \\             type: 'app', action: 'quit'
    \\           });
    \\           resolve();
    \\         } catch (error) {
    \\           reject(new Error(`Failed to quit: ${error.message}`));
    \\         }
    \\       });
    \\     }
    \\   };
    \\
    \\   // Fire the ready event and manually trigger any event listeners
    \\   // Since loadHTMLString doesn't reliably execute body scripts, we need a workaround
    \\   function fireReady() {
    \\     console.log('[Craft] JavaScript bridge ready - firing craft:ready event');
    \\     window.dispatchEvent(new CustomEvent('craft:ready'));
    \\
    \\     // WORKAROUND: If body scripts don't load, manually check for initialization functions
    \\     // Look for a global init function that may have been defined
    \\     if (typeof window.initializeCraftApp === 'function') {
    \\       window.initializeCraftApp();
    \\     }
    \\   }
    \\
    \\   // Try multiple strategies to ensure scripts execute
    \\   if (document.readyState === 'loading') {
    \\     document.addEventListener('DOMContentLoaded', fireReady);
    \\   } else if (document.readyState === 'interactive') {
    \\     // DOM parsed but resources loading
    \\     setTimeout(fireReady, 100);
    \\   } else {
    \\     // Already complete
    \\     fireReady();
    \\   }
    \\
    \\   // ===== POLLING FOR MENU ACTIONS =====
    \\   // evaluateJavaScript doesn't work from menu callbacks, so we poll
    \\   window.__craftDeliverAction = function(action) {
    \\     if (action && action.length > 0) {
    \\       console.log('[Craft] Polled menu action:', action);
    \\       window.dispatchEvent(new CustomEvent('craft:tray:menuAction', {
    \\         detail: { action: action }
    \\       }));
    \\     }
    \\   };
    \\
    \\   setInterval(function() {
    \\     try {
    \\       window.webkit.messageHandlers.craft.postMessage({
    \\         type: 'tray',
    \\         action: 'pollActions',
    \\         data: ''
    \\       });
    \\     } catch (e) {
    \\       // Ignore polling errors
    \\     }
    \\   }, 100);
    \\ })();
    ;
}

fn getNativeUIScript() []const u8 {
    return @embedFile("js/craft-native-ui.js");
}

/// Storage for bridge handlers (global state)
var global_tray_bridge: ?*@import("bridge_tray.zig").TrayBridge = null;
var global_window_bridge: ?*@import("bridge_window.zig").WindowBridge = null;
var global_app_bridge: ?*@import("bridge_app.zig").AppBridge = null;
var global_dialog_bridge: ?*@import("bridge_dialog.zig").DialogBridge = null;
var global_native_ui_bridge: ?*@import("bridge_native_ui.zig").NativeUIBridge = null;
var global_notification_bridge: ?*@import("bridge_notification.zig").NotificationBridge = null;
var global_shortcuts_bridge: ?*@import("bridge_shortcuts.zig").ShortcutsBridge = null;
var global_menu_bridge: ?*@import("bridge_menu.zig").MenuBridge = null;
var global_updater_bridge: ?*@import("bridge_updater.zig").UpdaterBridge = null;
var global_touchbar_bridge: ?*@import("bridge_touchbar.zig").TouchBarBridge = null;
var global_fs_bridge: ?*@import("bridge_fs.zig").FSBridge = null;
var global_shell_bridge: ?*@import("bridge_shell.zig").ShellBridge = null;
var global_system_bridge: ?*@import("bridge_system.zig").SystemBridge = null;
var global_power_bridge: ?*@import("bridge_power.zig").PowerBridge = null;
var global_network_bridge: ?*@import("bridge_network.zig").NetworkBridge = null;
var global_bluetooth_bridge: ?*@import("bridge_bluetooth.zig").BluetoothBridge = null;
var global_tray_handle_for_bridge: ?*anyopaque = null;
var global_clipboard_bridge: ?*@import("bridge_clipboard.zig").ClipboardBridge = null;

pub fn setGlobalTrayHandle(handle: *anyopaque) void {
    global_tray_handle_for_bridge = handle;

    // Update bridge if it exists
    if (global_tray_bridge) |bridge| {
        bridge.setTrayHandle(handle);
    }
}

pub fn setupBridgeHandlers(allocator: std.mem.Allocator, tray_handle: ?*anyopaque, window_handle: ?*anyopaque) !void {
    const TrayBridge = @import("bridge_tray.zig").TrayBridge;
    const WindowBridge = @import("bridge_window.zig").WindowBridge;
    const AppBridge = @import("bridge_app.zig").AppBridge;

    // Initialize bridges
    if (global_tray_bridge == null) {
        global_tray_bridge = try allocator.create(TrayBridge);
        global_tray_bridge.?.* = TrayBridge.init(allocator);
    }

    if (global_window_bridge == null) {
        global_window_bridge = try allocator.create(WindowBridge);
        global_window_bridge.?.* = WindowBridge.init(allocator);
    }

    if (global_app_bridge == null) {
        global_app_bridge = try allocator.create(AppBridge);
        global_app_bridge.?.* = AppBridge.init(allocator);
    }

    if (global_native_ui_bridge == null) {
        global_native_ui_bridge = try allocator.create(@import("bridge_native_ui.zig").NativeUIBridge);
        global_native_ui_bridge.?.* = @import("bridge_native_ui.zig").NativeUIBridge.init(allocator);
    }

    if (global_notification_bridge == null) {
        const NotificationBridge = @import("bridge_notification.zig").NotificationBridge;
        global_notification_bridge = try allocator.create(NotificationBridge);
        global_notification_bridge.?.* = NotificationBridge.init(allocator);
    }

    if (global_shortcuts_bridge == null) {
        const ShortcutsBridge = @import("bridge_shortcuts.zig").ShortcutsBridge;
        global_shortcuts_bridge = try allocator.create(ShortcutsBridge);
        global_shortcuts_bridge.?.* = ShortcutsBridge.init(allocator);
    }

    if (global_menu_bridge == null) {
        const MenuBridge = @import("bridge_menu.zig").MenuBridge;
        global_menu_bridge = try allocator.create(MenuBridge);
        global_menu_bridge.?.* = MenuBridge.init(allocator);
    }

    if (global_updater_bridge == null) {
        const UpdaterBridge = @import("bridge_updater.zig").UpdaterBridge;
        global_updater_bridge = try allocator.create(UpdaterBridge);
        global_updater_bridge.?.* = UpdaterBridge.init(allocator);
    }

    if (global_touchbar_bridge == null) {
        const TouchBarBridge = @import("bridge_touchbar.zig").TouchBarBridge;
        global_touchbar_bridge = try allocator.create(TouchBarBridge);
        global_touchbar_bridge.?.* = TouchBarBridge.init(allocator);
    }

    if (global_fs_bridge == null) {
        const FSBridge = @import("bridge_fs.zig").FSBridge;
        global_fs_bridge = try allocator.create(FSBridge);
        global_fs_bridge.?.* = FSBridge.init(allocator);
    }

    if (global_shell_bridge == null) {
        const ShellBridge = @import("bridge_shell.zig").ShellBridge;
        global_shell_bridge = try allocator.create(ShellBridge);
        global_shell_bridge.?.* = ShellBridge.init(allocator);
    }

    if (global_dialog_bridge == null) {
        const DialogBridge = @import("bridge_dialog.zig").DialogBridge;
        global_dialog_bridge = try allocator.create(DialogBridge);
        global_dialog_bridge.?.* = DialogBridge.init(allocator);
    }

    if (global_clipboard_bridge == null) {
        const ClipboardBridge = @import("bridge_clipboard.zig").ClipboardBridge;
        global_clipboard_bridge = try allocator.create(ClipboardBridge);
        global_clipboard_bridge.?.* = ClipboardBridge.init(allocator);
    }

    // Set handles - use parameter or global
    const tray_h = tray_handle orelse global_tray_handle_for_bridge;
    std.debug.print("[Bridge] setupBridgeHandlers: tray_handle param={*}, global={*}, resolved={*}\n", .{ @as(?*anyopaque, tray_handle), global_tray_handle_for_bridge, tray_h });
    if (tray_h) |handle| {
        std.debug.print("[Bridge] Setting tray handle on bridge: {*}\n", .{handle});
        global_tray_bridge.?.setTrayHandle(handle);
    } else {
        std.debug.print("[Bridge] WARNING: No tray handle available!\n", .{});
    }

    if (window_handle) |handle| {
        global_window_bridge.?.setWindowHandle(handle);
        // Also set window reference for native UI bridge
        if (global_native_ui_bridge) |bridge| {
            const window_id: objc.id = @ptrCast(@alignCast(handle));
            bridge.setWindow(window_id);
        }
    }
}

/// Try to evaluate JavaScript (may fail silently)
pub fn tryEvalJS(js_code: []const u8) !void {
    const tray_menu = @import("tray_menu.zig");
    if (tray_menu.getGlobalWebView()) |webview| {
        const webview_id: objc.id = @ptrFromInt(@intFromPtr(webview));
        const js_str = createNSString(js_code);
        _ = msgSend2(webview_id, "evaluateJavaScript:completionHandler:", js_str, null);
        std.debug.print("[Bridge] Executed JS: {s}\n", .{js_code});
    } else {
        return error.NoWebView;
    }
}

/// Handle incoming messages from JavaScript bridge
/// Convert a JSON Value to string
fn jsonValueToString(allocator: std.mem.Allocator, value: std.json.Value) ![]const u8 {
    var buf: std.ArrayListUnmanaged(u8) = .{};
    errdefer buf.deinit(allocator);

    switch (value) {
        .null => try buf.appendSlice(allocator, "null"),
        .bool => |b| try buf.appendSlice(allocator, if (b) "true" else "false"),
        .integer => |i| {
            var num_buf: [32]u8 = undefined;
            const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{i}) catch return error.OutOfMemory;
            try buf.appendSlice(allocator, num_str);
        },
        .float => |f| {
            var num_buf: [64]u8 = undefined;
            const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{f}) catch return error.OutOfMemory;
            try buf.appendSlice(allocator, num_str);
        },
        .number_string => |s| try buf.appendSlice(allocator, s),
        .string => |s| {
            try buf.append(allocator, '"');
            for (s) |char| {
                switch (char) {
                    '"' => try buf.appendSlice(allocator, "\\\""),
                    '\\' => try buf.appendSlice(allocator, "\\\\"),
                    '\n' => try buf.appendSlice(allocator, "\\n"),
                    '\r' => try buf.appendSlice(allocator, "\\r"),
                    '\t' => try buf.appendSlice(allocator, "\\t"),
                    else => try buf.append(allocator, char),
                }
            }
            try buf.append(allocator, '"');
        },
        .array => |arr| {
            try buf.append(allocator, '[');
            for (arr.items, 0..) |item, i| {
                if (i > 0) try buf.append(allocator, ',');
                const item_str = try jsonValueToString(allocator, item);
                defer allocator.free(item_str);
                try buf.appendSlice(allocator, item_str);
            }
            try buf.append(allocator, ']');
        },
        .object => |obj| {
            try buf.append(allocator, '{');
            var it = obj.iterator();
            var first = true;
            while (it.next()) |entry| {
                if (!first) try buf.append(allocator, ',');
                first = false;
                try buf.append(allocator, '"');
                try buf.appendSlice(allocator, entry.key_ptr.*);
                try buf.appendSlice(allocator, "\":");
                const val_str = try jsonValueToString(allocator, entry.value_ptr.*);
                defer allocator.free(val_str);
                try buf.appendSlice(allocator, val_str);
            }
            try buf.append(allocator, '}');
        },
    }

    return allocator.dupe(u8, buf.items);
}

/// Handle properly formatted JSON messages
pub fn handleBridgeMessageJSON(json_str: []const u8) !void {
    // Skip logging pollActions to reduce noise
    if (std.mem.indexOf(u8, json_str, "pollActions") == null) {
        std.debug.print("[Bridge] Received JSON message: {s}\n", .{json_str});
    }

    // Parse JSON to extract type, action, and data
    const allocator = std.heap.c_allocator;
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_str, .{}) catch |err| {
        std.debug.print("[Bridge] JSON parse error: {any}\n", .{err});
        return err;
    };
    defer parsed.deinit();

    const root = parsed.value.object;

    // Extract type and action
    const msg_type_val = root.get("type") orelse {
        std.debug.print("[Bridge] Missing 'type' field in JSON\n", .{});
        return error.MissingType;
    };
    const action_val = root.get("action") orelse {
        std.debug.print("[Bridge] Missing 'action' field in JSON\n", .{});
        return error.MissingAction;
    };

    const msg_type = msg_type_val.string;
    const action = action_val.string;

    // Extract data if present - could be string, object, array, or missing
    var data_json_str: []const u8 = "";
    var data_needs_free: bool = false;
    if (root.get("data")) |data_val| {
        switch (data_val) {
            // If data is already a string, use it directly (common case for JSON data)
            .string => |s| {
                data_json_str = s;
                data_needs_free = false;
            },
            // For other types, convert to JSON string
            else => {
                data_json_str = try jsonValueToString(allocator, data_val);
                data_needs_free = true;
            },
        }
    }
    defer if (data_needs_free and data_json_str.len > 0) allocator.free(data_json_str);

    // Route to appropriate bridge
    if (std.mem.eql(u8, msg_type, "tray")) {
        if (global_tray_bridge) |bridge| {
            try bridge.handleMessage(action, data_json_str);
        }
    } else if (std.mem.eql(u8, msg_type, "window")) {
        if (global_window_bridge) |bridge| {
            try bridge.handleMessage(action);
        }
    } else if (std.mem.eql(u8, msg_type, "app")) {
        if (global_app_bridge) |bridge| {
            try bridge.handleMessage(action);
        }
    } else if (std.mem.eql(u8, msg_type, "nativeUI")) {
        if (global_native_ui_bridge) |bridge| {
            try bridge.handleMessage(action, data_json_str);
        }
    } else if (std.mem.eql(u8, msg_type, "notification")) {
        if (global_notification_bridge) |bridge| {
            try bridge.handleMessage(action, data_json_str);
        }
    } else if (std.mem.eql(u8, msg_type, "shortcuts")) {
        if (global_shortcuts_bridge) |bridge| {
            try bridge.handleMessage(action, data_json_str);
        }
    } else if (std.mem.eql(u8, msg_type, "menu")) {
        if (global_menu_bridge) |bridge| {
            try bridge.handleMessage(action, data_json_str);
        }
    } else if (std.mem.eql(u8, msg_type, "updater")) {
        if (global_updater_bridge) |bridge| {
            try bridge.handleMessage(action, data_json_str);
        }
    } else if (std.mem.eql(u8, msg_type, "touchbar")) {
        if (global_touchbar_bridge) |bridge| {
            try bridge.handleMessage(action, data_json_str);
        }
    } else if (std.mem.eql(u8, msg_type, "fs")) {
        if (global_fs_bridge) |bridge| {
            try bridge.handleMessage(action, data_json_str);
        }
    } else if (std.mem.eql(u8, msg_type, "shell")) {
        if (global_shell_bridge) |bridge| {
            try bridge.handleMessage(action, data_json_str);
        }
    } else if (std.mem.eql(u8, msg_type, "dialog")) {
        if (global_dialog_bridge) |bridge| {
            const data_opt: ?[]const u8 = if (data_json_str.len > 0) data_json_str else null;
            try bridge.handleMessageWithData(action, data_opt);
        }
    } else if (std.mem.eql(u8, msg_type, "clipboard")) {
        if (global_clipboard_bridge) |bridge| {
            // ClipboardBridge expects optional raw JSON slice for data
            const data_opt: ?[]const u8 = if (data_json_str.len > 0) data_json_str else null;
            try bridge.handleMessageWithData(action, data_opt);
        }
    } else if (std.mem.eql(u8, msg_type, "debug")) {
        // Handle debug messages
        if (root.get("message")) |msg_val| {
            std.debug.print("[JS Debug] {s}\n", .{msg_val.string});
        } else if (root.get("msg")) |msg_val| {
            std.debug.print("[JS Debug] {s}\n", .{msg_val.string});
        }
    } else {
        std.debug.print("Unknown message type: {s}\n", .{msg_type});
    }
}

pub fn handleBridgeMessage(message_json: []const u8) !void {
    // Parse NSDictionary description format (fallback for old code paths)
    // Expected format: { action = "setTitle"; data = "text"; type = "tray"; }
    // Or JSON format: {"type":"tray","action":"setTitle","data":"text"}

    // Skip logging pollActions to reduce noise
    if (std.mem.indexOf(u8, message_json, "pollActions") == null) {
        std.debug.print("[Bridge] Received message: {s}\n", .{message_json});
    }

    var type_start: usize = 0;
    var type_end: usize = 0;
    var action_start: usize = 0;
    var action_end: usize = 0;
    var data_start: usize = 0;
    var data_end: usize = 0;

    // Parse NSDictionary format: key = value; or key = "value";
    // Find type (unquoted)
    if (std.mem.indexOf(u8, message_json, "type")) |pos| {
        // Skip past "type" and find =
        if (std.mem.indexOfPos(u8, message_json, pos + 4, "=")) |eq_pos| {
            // Skip whitespace after =
            var start = eq_pos + 1;
            while (start < message_json.len and (message_json[start] == ' ' or message_json[start] == '\t')) : (start += 1) {}

            // Check if quoted
            if (start < message_json.len and message_json[start] == '"') {
                type_start = start + 1;
                if (std.mem.indexOfPos(u8, message_json, type_start, "\"")) |end| {
                    type_end = end;
                }
            } else {
                // Unquoted - find next ; or space or newline
                type_start = start;
                if (std.mem.indexOfPos(u8, message_json, start, ";")) |end| {
                    type_end = end;
                }
            }
        }
    }

    // Find action (unquoted)
    if (std.mem.indexOf(u8, message_json, "action")) |pos| {
        if (std.mem.indexOfPos(u8, message_json, pos + 6, "=")) |eq_pos| {
            var start = eq_pos + 1;
            while (start < message_json.len and (message_json[start] == ' ' or message_json[start] == '\t')) : (start += 1) {}

            if (start < message_json.len and message_json[start] == '"') {
                action_start = start + 1;
                if (std.mem.indexOfPos(u8, message_json, action_start, "\"")) |end| {
                    action_end = end;
                }
            } else {
                action_start = start;
                if (std.mem.indexOfPos(u8, message_json, start, ";")) |end| {
                    action_end = end;
                }
            }
        }
    }

    // Find data (usually quoted, may contain escaped quotes)
    if (std.mem.indexOf(u8, message_json, "data")) |pos| {
        if (std.mem.indexOfPos(u8, message_json, pos + 4, "=")) |eq_pos| {
            var start = eq_pos + 1;
            while (start < message_json.len and (message_json[start] == ' ' or message_json[start] == '\t')) : (start += 1) {}

            if (start < message_json.len and message_json[start] == '"') {
                data_start = start + 1;
                // Find closing quote, but skip escaped quotes (\")
                var i = data_start;
                while (i < message_json.len) : (i += 1) {
                    if (message_json[i] == '\\' and i + 1 < message_json.len) {
                        // Skip escaped character
                        i += 1;
                        continue;
                    }
                    if (message_json[i] == '"') {
                        data_end = i;
                        break;
                    }
                }
            } else {
                data_start = start;
                if (std.mem.indexOfPos(u8, message_json, start, ";")) |end| {
                    data_end = end;
                }
            }
        }
    }

    if (type_end == 0 or action_end == 0) {
        std.debug.print("[Bridge] Invalid message format (missing type or action)\n", .{});
        return;
    }

    const msg_type = message_json[type_start..type_end];
    const action = message_json[action_start..action_end];
    const data = if (data_end > 0) message_json[data_start..data_end] else "";

    // Route to appropriate bridge
    if (std.mem.eql(u8, msg_type, "tray")) {
        if (global_tray_bridge) |bridge| {
            try bridge.handleMessage(action, data);
        }
    } else if (std.mem.eql(u8, msg_type, "window")) {
        if (global_window_bridge) |bridge| {
            try bridge.handleMessage(action);
        }
    } else if (std.mem.eql(u8, msg_type, "app")) {
        if (global_app_bridge) |bridge| {
            try bridge.handleMessage(action);
        }
    } else if (std.mem.eql(u8, msg_type, "nativeUI")) {
        if (global_native_ui_bridge) |bridge| {
            try bridge.handleMessage(action, data);
        }
    } else if (std.mem.eql(u8, msg_type, "notification")) {
        if (global_notification_bridge) |bridge| {
            try bridge.handleMessage(action, data);
        }
    } else if (std.mem.eql(u8, msg_type, "shortcuts")) {
        if (global_shortcuts_bridge) |bridge| {
            try bridge.handleMessage(action, data);
        }
    } else if (std.mem.eql(u8, msg_type, "menu")) {
        if (global_menu_bridge) |bridge| {
            try bridge.handleMessage(action, data);
        }
    } else if (std.mem.eql(u8, msg_type, "updater")) {
        if (global_updater_bridge) |bridge| {
            try bridge.handleMessage(action, data);
        }
    } else if (std.mem.eql(u8, msg_type, "touchbar")) {
        if (global_touchbar_bridge) |bridge| {
            try bridge.handleMessage(action, data);
        }
    } else if (std.mem.eql(u8, msg_type, "fs")) {
        if (global_fs_bridge) |bridge| {
            try bridge.handleMessage(action, data);
        }
    } else if (std.mem.eql(u8, msg_type, "shell")) {
        if (global_shell_bridge) |bridge| {
            try bridge.handleMessage(action, data);
        }
    } else if (std.mem.eql(u8, msg_type, "debug")) {
        // Handle debug messages - look for "message" or "msg" field
        if (std.mem.indexOf(u8, message_json, "message")) |msg_pos| {
            if (std.mem.indexOfPos(u8, message_json, msg_pos + 7, "=")) |eq_pos| {
                var start = eq_pos + 1;
                while (start < message_json.len and (message_json[start] == ' ' or message_json[start] == '\t')) : (start += 1) {}
                if (start < message_json.len and message_json[start] == '"') {
                    const msg_start = start + 1;
                    if (std.mem.indexOfPos(u8, message_json, msg_start, "\"")) |msg_end| {
                        const debug_msg = message_json[msg_start..msg_end];
                        std.debug.print("[JS Debug] {s}\n", .{debug_msg});
                    }
                }
            }
        } else if (std.mem.indexOf(u8, message_json, "msg")) |msg_pos| {
            if (std.mem.indexOfPos(u8, message_json, msg_pos + 3, "=")) |eq_pos| {
                var start = eq_pos + 1;
                while (start < message_json.len and (message_json[start] == ' ' or message_json[start] == '\t')) : (start += 1) {}
                if (start < message_json.len and message_json[start] == '"') {
                    const msg_start = start + 1;
                    if (std.mem.indexOfPos(u8, message_json, msg_start, "\"")) |msg_end| {
                        const debug_msg = message_json[msg_start..msg_end];
                        std.debug.print("[JS Debug] {s}\n", .{debug_msg});
                    }
                }
            }
        }
    } else {
        std.debug.print("Unknown message type: {s}\n", .{msg_type});
    }
}

/// Callback for WKScriptMessageHandler
export fn didReceiveScriptMessage(self: objc.id, _: objc.SEL, userContentController: objc.id, message: objc.id) void {
    _ = self;
    _ = userContentController;

    // Get the message body (should be a dictionary/object from JavaScript)
    const body = msgSend0(message, "body");

    // Try to convert to JSON properly using NSJSONSerialization
    const NSJSONSerialization = getClass("NSJSONSerialization");
    const options: c_ulong = 0; // NSJSONWritingPrettyPrinted = 1, 0 for compact

    // Create JSON data from dictionary
    const json_data = msgSend3(NSJSONSerialization, "dataWithJSONObject:options:error:", body, options, null);

    if (json_data == null) {
        // Fallback to description format if JSON serialization fails
        std.debug.print("[Bridge] Failed to serialize to JSON, using description format\n", .{});
        const description = msgSend0(body, "description");
        const cstr = @as([*:0]const u8, @ptrCast(msgSend0(description, "UTF8String")));
        const desc_str = std.mem.span(cstr);
        handleBridgeMessage(desc_str) catch |err| {
            std.debug.print("[Bridge] Error handling message: {}\n", .{err});
        };
        return;
    }

    // Convert NSData to NSString
    const NSString = getClass("NSString");
    const json_string = msgSend2(NSString, "alloc", null, null);
    const NSUTF8StringEncoding: c_ulong = 4;
    const initialized_string = msgSend2(json_string, "initWithData:encoding:", json_data, NSUTF8StringEncoding);

    if (initialized_string == null) {
        std.debug.print("[Bridge] Failed to convert JSON data to string\n", .{});
        return;
    }

    // Get C string from NSString
    const cstr = @as([*:0]const u8, @ptrCast(msgSend0(initialized_string, "UTF8String")));
    const json_str = std.mem.span(cstr);

    // Now handle the properly formatted JSON
    handleBridgeMessageJSON(json_str) catch |err| {
        std.debug.print("[Bridge] Error handling JSON message: {}\n", .{err});
    };

    // Release the NSString
    msgSendVoid0(initialized_string, "release");
}

/// Create and register the script message handler with WKUserContentController
pub fn setupScriptMessageHandler(userContentController: objc.id) !void {
    std.debug.print("[Bridge] Setting up WKScriptMessageHandler...\n", .{});

    // Create a custom class at runtime that implements WKScriptMessageHandler
    const superclass = getClass("NSObject");
    const className = "CraftScriptMessageHandler";

    // Try to get existing class first (in case we're called multiple times)
    var handlerClass = objc.objc_getClass(className);

    if (handlerClass == null) {
        // Allocate a new class pair
        handlerClass = objc.objc_allocateClassPair(@ptrCast(superclass), className, 0);

        if (handlerClass == null) {
            std.debug.print("[Bridge] Failed to allocate class pair\n", .{});
            return error.ClassAllocationFailed;
        }

        // Add the method: userContentController:didReceiveScriptMessage:
        const method_sel = objc.sel_registerName("userContentController:didReceiveScriptMessage:");
        const method_imp: objc.IMP = @ptrCast(@constCast(&didReceiveScriptMessage));
        const method_types: [*c]const u8 = "v@:@@";
        const method_added = objc.class_addMethod(
            @ptrCast(@alignCast(handlerClass)),
            method_sel,
            method_imp,
            method_types,
        );

        if (!method_added) {
            std.debug.print("[Bridge] Failed to add method\n", .{});
        }

        // Register the class
        objc.objc_registerClassPair(@ptrCast(handlerClass));
        std.debug.print("[Bridge] Registered CraftScriptMessageHandler class\n", .{});
    }

    // Create an instance of our handler
    const handler_class_id: objc.id = @ptrCast(@alignCast(handlerClass));
    const handler = msgSend0(msgSend0(handler_class_id, "alloc"), "init");

    // Add the handler to the user content controller
    const handler_name = createNSString("craft");
    msgSendVoid2(userContentController, "addScriptMessageHandler:name:", handler, handler_name);

    std.debug.print("[Bridge] Script message handler registered successfully\n", .{});
}

// ============================================================================
// WKUIDelegate for Camera/Microphone Permissions
// ============================================================================

/// Media capture permission callback - automatically grants camera/microphone access
/// This is called by WebKit when a webpage requests getUserMedia()
fn handleMediaCapturePermission(
    self: objc.id,
    _sel: objc.SEL,
    webView: objc.id,
    origin: objc.id,
    frame: objc.id,
    mediaType: c_long,
    decisionHandler: objc.id,
) callconv(.c) void {
    _ = self;
    _ = _sel;
    _ = webView;
    _ = origin;
    _ = frame;

    // WKMediaCaptureType:
    // 0 = WKMediaCaptureTypeCamera
    // 1 = WKMediaCaptureTypeMicrophone
    // 2 = WKMediaCaptureTypeCameraAndMicrophone
    const media_type_str = switch (mediaType) {
        0 => "camera",
        1 => "microphone",
        2 => "camera+microphone",
        else => "unknown",
    };
    std.debug.print("[Media] Permission requested for: {s}\n", .{media_type_str});

    // Grant permission by calling decisionHandler with WKPermissionDecisionGrant (1)
    // WKPermissionDecision:
    // 0 = WKPermissionDecisionDeny
    // 1 = WKPermissionDecisionGrant
    // 2 = WKPermissionDecisionPrompt
    const invoke_sel = sel("invokeWithTarget:");

    // The decisionHandler is a block that takes WKPermissionDecision
    // We need to call it with 1 (grant) to allow media access
    // Create an NSInvocation to call the block properly
    const NSNumber = getClass("NSNumber");
    const grant_decision = msgSend1(NSNumber, "numberWithInt:", @as(c_int, 1)); // WKPermissionDecisionGrant

    // Blocks in Objective-C can be invoked directly with objc_msgSend
    // The block signature is void(^)(WKPermissionDecision)
    const block_invoke = @as(
        *const fn (objc.id, c_long) callconv(.c) void,
        @ptrCast(@alignCast(decisionHandler)),
    );
    _ = block_invoke;
    _ = invoke_sel;
    _ = grant_decision;

    // Alternative: Use the block directly
    // Blocks have a specific layout: isa, flags, reserved, invoke, descriptor
    // The invoke function is at offset 16 (after isa, flags, reserved)
    if (decisionHandler) |handler| {
        const BlockLayout = extern struct {
            isa: ?*anyopaque,
            flags: c_int,
            reserved: c_int,
            invoke: *const fn (*anyopaque, c_long) callconv(.c) void,
        };
        const block: *BlockLayout = @ptrCast(@alignCast(handler));
        // Call the block with WKPermissionDecisionGrant (1)
        block.invoke(handler, 1);
        std.debug.print("[Media] Permission granted for {s}\n", .{media_type_str});
    }
}

/// Set up WKUIDelegate to handle media capture permission requests
pub fn setupUIDelegate(webview: objc.id) !void {
    std.debug.print("[Media] Setting up WKUIDelegate for media permissions...\n", .{});

    // Create a custom class at runtime that implements WKUIDelegate
    const superclass = getClass("NSObject");
    const className = "CraftUIDelegate";

    // Try to get existing class first (in case we're called multiple times)
    var delegateClass = objc.objc_getClass(className);

    if (delegateClass == null) {
        // Allocate a new class pair
        delegateClass = objc.objc_allocateClassPair(@ptrCast(superclass), className, 0);

        if (delegateClass == null) {
            std.debug.print("[Media] Failed to allocate UI delegate class pair\n", .{});
            return error.ClassAllocationFailed;
        }

        // Add the method: webView:requestMediaCapturePermissionForOrigin:initiatedByFrame:type:decisionHandler:
        // This is the macOS 12+ API for handling getUserMedia() permission requests
        const method_sel = objc.sel_registerName("webView:requestMediaCapturePermissionForOrigin:initiatedByFrame:type:decisionHandler:");
        const method_imp: objc.IMP = @ptrCast(@constCast(&handleMediaCapturePermission));
        // Method signature: void return, self, _cmd, webView, origin, frame, type (long), decisionHandler (block)
        // v = void, @ = object, : = selector, @ = object, @ = object, @ = object, q = long long, @? = block
        const method_types: [*c]const u8 = "v@:@@@q@?";
        const method_added = objc.class_addMethod(
            @ptrCast(@alignCast(delegateClass)),
            method_sel,
            method_imp,
            method_types,
        );

        if (!method_added) {
            std.debug.print("[Media] Failed to add media permission method\n", .{});
        } else {
            std.debug.print("[Media] Added webView:requestMediaCapturePermissionForOrigin:... method\n", .{});
        }

        // Register the class
        objc.objc_registerClassPair(@ptrCast(delegateClass));
        std.debug.print("[Media] Registered CraftUIDelegate class\n", .{});
    }

    // Create an instance of our delegate
    const delegate_class_id: objc.id = @ptrCast(@alignCast(delegateClass));
    const delegate = msgSend0(msgSend0(delegate_class_id, "alloc"), "init");

    // Set the UI delegate on the webview
    msgSendVoid1(webview, "setUIDelegate:", delegate);

    std.debug.print("[Media] UI delegate set successfully - camera/microphone permissions enabled\n", .{});
}

// ============================================================================
// v0.5.0 Features
// ============================================================================

// WebSocket support for real-time communication
pub const WebSocket = struct {
    url: []const u8,
    connected: bool = false,
    allocator: std.mem.Allocator,

    pub fn connect(allocator: std.mem.Allocator, url: []const u8) !WebSocket {
        return .{
            .url = try allocator.dupe(u8, url),
            .connected = false,
            .allocator = allocator,
        };
    }

    pub fn send(self: *WebSocket, message: []const u8) !void {
        _ = self;
        _ = message;
        // Would integrate with NSURLSession WebSocket task
    }

    pub fn receive(self: *WebSocket) ![]const u8 {
        _ = self;
        // Would receive from NSURLSession WebSocket task
        return "";
    }

    pub fn close(self: *WebSocket) void {
        if (self.connected) {
            self.connected = false;
        }
    }

    pub fn deinit(self: *WebSocket) void {
        self.allocator.free(self.url);
    }
};

// Custom protocol handler (craft://)
pub const ProtocolHandler = struct {
    scheme: []const u8,
    callback: *const fn ([]const u8) void,

    pub fn register(scheme: []const u8, callback: *const fn ([]const u8) void) !ProtocolHandler {
        // Would register with WKURLSchemeHandler
        return .{
            .scheme = scheme,
            .callback = callback,
        };
    }

    pub fn handle(self: ProtocolHandler, url: []const u8) void {
        self.callback(url);
    }
};

pub fn registerCustomProtocol(webview: objc.id, scheme: []const u8) !void {
    _ = webview;
    _ = scheme;
    // Would use WKWebViewConfiguration.setURLSchemeHandler
}

// Drag and drop file support
pub const DragDropEvent = struct {
    files: [][]const u8,
    x: f64,
    y: f64,
};

pub const DragDropCallback = *const fn (DragDropEvent) void;

pub fn enableDragDrop(window: objc.id, callback: DragDropCallback) void {
    _ = window;
    _ = callback;
    // Would register for NSDragOperation and implement NSDraggingDestination protocol
}

pub fn getDraggedFiles(drag_info: objc.id, allocator: std.mem.Allocator) ![][]const u8 {
    _ = drag_info;
    _ = allocator;
    // Would extract files from NSPasteboard
    return &[_][]const u8{};
}

// Context menu API
pub const MenuItem = struct {
    title: []const u8,
    action: *const fn () void,
    enabled: bool = true,
    separator: bool = false,
};

pub const ContextMenu = struct {
    items: []MenuItem,
    native_menu: objc.id,

    pub fn create(allocator: std.mem.Allocator, items: []const MenuItem) !ContextMenu {
        const NSMenu = getClass("NSMenu");
        const menu = msgSend0(msgSend0(NSMenu, "alloc"), "init");

        const items_copy = try allocator.alloc(MenuItem, items.len);
        @memcpy(items_copy, items);

        return .{
            .items = items_copy,
            .native_menu = menu,
        };
    }

    pub fn show(self: ContextMenu, window: objc.id, x: f64, y: f64) void {
        const point = NSPoint{ .x = x, .y = y };
        _ = msgSend2(self.native_menu, "popUpMenuPositioningItem:atLocation:inView:", @as(?*anyopaque, null), point, window);
    }

    pub fn deinit(self: ContextMenu, allocator: std.mem.Allocator) void {
        allocator.free(self.items);
    }
};

// Auto-updater
pub const UpdateInfo = struct {
    version: []const u8,
    download_url: []const u8,
    release_notes: []const u8,
    required: bool = false,
};

pub const Updater = struct {
    current_version: []const u8,
    update_url: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, version: []const u8, update_url: []const u8) !Updater {
        return .{
            .current_version = try allocator.dupe(u8, version),
            .update_url = try allocator.dupe(u8, update_url),
            .allocator = allocator,
        };
    }

    pub fn checkForUpdates(self: *Updater) !?UpdateInfo {
        _ = self;
        // Would fetch update manifest from update_url
        return null;
    }

    pub fn downloadUpdate(self: *Updater, info: UpdateInfo) !void {
        _ = self;
        _ = info;
        // Would download update package
    }

    pub fn installUpdate(self: *Updater) !void {
        _ = self;
        // Would install downloaded update and restart app
    }

    pub fn deinit(self: *Updater) void {
        self.allocator.free(self.current_version);
        self.allocator.free(self.update_url);
    }
};

// Crash reporting
pub const CrashReport = struct {
    timestamp: i64,
    exception: []const u8,
    stack_trace: []const u8,
    app_version: []const u8,
};

pub const CrashReporter = struct {
    endpoint: []const u8,
    app_version: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, endpoint: []const u8, app_version: []const u8) !CrashReporter {
        return .{
            .endpoint = try allocator.dupe(u8, endpoint),
            .app_version = try allocator.dupe(u8, app_version),
            .allocator = allocator,
        };
    }

    pub fn reportCrash(self: *CrashReporter, report: CrashReport) !void {
        _ = self;
        _ = report;
        // Would send crash report to endpoint
    }

    pub fn enableAutomaticReporting(self: *CrashReporter) void {
        _ = self;
        // Would set up NSException handler
    }

    pub fn deinit(self: *CrashReporter) void {
        self.allocator.free(self.endpoint);
        self.allocator.free(self.app_version);
    }
};

// Enhanced keyboard shortcut API
pub const KeyModifier = packed struct {
    command: bool = false,
    shift: bool = false,
    option: bool = false,
    control: bool = false,
};

pub const KeyCode = enum(u16) {
    a = 0,
    s = 1,
    d = 2,
    f = 3,
    h = 4,
    g = 5,
    z = 6,
    x = 7,
    c = 8,
    v = 9,
    b = 11,
    q = 12,
    w = 13,
    e = 14,
    r = 15,
    y = 16,
    t = 17,
    n = 45,
    m = 46,
    space = 49,
    return_key = 36,
    escape = 53,
    delete = 51,
    tab = 48,
    f1 = 122,
    f2 = 120,
    f3 = 99,
    f4 = 118,
    f5 = 96,
    f6 = 97,
    f7 = 98,
    f8 = 100,
    f9 = 101,
    f10 = 109,
    f11 = 103,
    f12 = 111,
    _,
};

pub const Shortcut = struct {
    key: KeyCode,
    modifiers: KeyModifier,
    action: *const fn () void,
    global: bool = false,
};

pub fn registerShortcut(shortcut: Shortcut) !void {
    _ = shortcut;
    // Would use NSEvent.addLocalMonitorForEventsMatchingMask or
    // Carbon/Cocoa global hotkey registration
}

pub fn unregisterShortcut(shortcut: Shortcut) void {
    _ = shortcut;
    // Would remove event monitor or unregister hotkey
}

// Window snapshots/thumbnails
pub const WindowSnapshot = struct {
    data: []u8,
    width: u32,
    height: u32,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *WindowSnapshot) void {
        self.allocator.free(self.data);
    }
};

pub fn captureWindowSnapshot(window: objc.id, allocator: std.mem.Allocator, scale: f64) !WindowSnapshot {
    _ = window;
    _ = scale;
    // Would use CGWindowListCreateImage to capture window
    const data = try allocator.alloc(u8, 0);
    return .{
        .data = data,
        .width = 0,
        .height = 0,
        .allocator = allocator,
    };
}

pub fn captureWindowThumbnail(window: objc.id, allocator: std.mem.Allocator, max_width: u32, max_height: u32) !WindowSnapshot {
    _ = window;
    _ = max_width;
    _ = max_height;
    // Would capture and scale down
    const data = try allocator.alloc(u8, 0);
    return .{
        .data = data,
        .width = 0,
        .height = 0,
        .allocator = allocator,
    };
}

pub fn saveSnapshot(snapshot: WindowSnapshot, file_path: []const u8) !void {
    _ = snapshot;
    _ = file_path;
    // Would save to PNG/JPEG file
}

// Screen recording
pub const RecordingOptions = struct {
    fps: u32 = 30,
    audio: bool = false,
    cursor: bool = true,
};

pub const ScreenRecorder = struct {
    recording: bool = false,
    output_path: []const u8,
    options: RecordingOptions,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, output_path: []const u8, options: RecordingOptions) !ScreenRecorder {
        return .{
            .recording = false,
            .output_path = try allocator.dupe(u8, output_path),
            .options = options,
            .allocator = allocator,
        };
    }

    pub fn startRecording(self: *ScreenRecorder) !void {
        if (self.recording) return error.AlreadyRecording;
        self.recording = true;
        // Would use AVFoundation to start screen recording
    }

    pub fn stopRecording(self: *ScreenRecorder) !void {
        if (!self.recording) return error.NotRecording;
        self.recording = false;
        // Would stop AVFoundation recording and save file
    }

    pub fn pauseRecording(self: *ScreenRecorder) !void {
        if (!self.recording) return error.NotRecording;
        // Would pause recording
    }

    pub fn resumeRecording(self: *ScreenRecorder) !void {
        if (!self.recording) return error.NotRecording;
        // Would resume recording
    }

    pub fn deinit(self: *ScreenRecorder) void {
        if (self.recording) {
            _ = self.stopRecording() catch {};
        }
        self.allocator.free(self.output_path);
    }
};

pub fn recordWindow(window: objc.id, output_path: []const u8, options: RecordingOptions) !ScreenRecorder {
    _ = window;
    const allocator = std.heap.c_allocator;
    return ScreenRecorder.init(allocator, output_path, options);
}

pub fn recordScreen(output_path: []const u8, options: RecordingOptions) !ScreenRecorder {
    const allocator = std.heap.c_allocator;
    return ScreenRecorder.init(allocator, output_path, options);
}

// ============================================================================
// v0.6.0 Features - Cross-Platform & Enterprise
// ============================================================================

// Plugin system
pub const Plugin = struct {
    name: []const u8,
    version: []const u8,
    path: []const u8,
    enabled: bool = true,
    handle: ?*anyopaque = null,
    allocator: std.mem.Allocator,

    pub fn load(allocator: std.mem.Allocator, path: []const u8) !Plugin {
        // Would use dlopen() to load dynamic library
        return .{
            .name = try allocator.dupe(u8, "plugin"),
            .version = try allocator.dupe(u8, "1.0.0"),
            .path = try allocator.dupe(u8, path),
            .enabled = true,
            .handle = null,
            .allocator = allocator,
        };
    }

    pub fn call(self: *Plugin, function_name: []const u8, args: []const u8) ![]const u8 {
        _ = self;
        _ = function_name;
        _ = args;
        // Would use dlsym() to get function and call it
        return "";
    }

    pub fn unload(self: *Plugin) void {
        if (self.handle) |_| {
            // Would use dlclose()
        }
        self.enabled = false;
    }

    pub fn deinit(self: *Plugin) void {
        self.unload();
        self.allocator.free(self.name);
        self.allocator.free(self.version);
        self.allocator.free(self.path);
    }
};

pub const PluginManager = struct {
    plugins: std.ArrayList(Plugin),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) PluginManager {
        return .{
            .plugins = std.ArrayList(Plugin).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn loadPlugin(self: *PluginManager, path: []const u8) !void {
        const plugin = try Plugin.load(self.allocator, path);
        try self.plugins.append(plugin);
    }

    pub fn getPlugin(self: *PluginManager, name: []const u8) ?*Plugin {
        for (self.plugins.items) |*plugin| {
            if (std.mem.eql(u8, plugin.name, name)) {
                return plugin;
            }
        }
        return null;
    }

    pub fn deinit(self: *PluginManager) void {
        for (self.plugins.items) |*plugin| {
            plugin.deinit();
        }
        self.plugins.deinit();
    }
};

// Native modules
pub const NativeModule = struct {
    name: []const u8,
    exports: std.StringHashMap(*const fn () void),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !NativeModule {
        return .{
            .name = try allocator.dupe(u8, name),
            .exports = std.StringHashMap(*const fn () void).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn registerFunction(self: *NativeModule, name: []const u8, func: *const fn () void) !void {
        try self.exports.put(name, func);
    }

    pub fn call(self: *NativeModule, name: []const u8) !void {
        if (self.exports.get(name)) |func| {
            func();
        } else {
            return error.FunctionNotFound;
        }
    }

    pub fn deinit(self: *NativeModule) void {
        self.allocator.free(self.name);
        self.exports.deinit();
    }
};

// Sandbox environment
pub const SandboxPermissions = struct {
    network: bool = false,
    file_system_read: bool = false,
    file_system_write: bool = false,
    clipboard: bool = false,
    notifications: bool = false,
    camera: bool = false,
    microphone: bool = false,
};

pub const Sandbox = struct {
    permissions: SandboxPermissions,
    enabled: bool = true,

    pub fn create(permissions: SandboxPermissions) Sandbox {
        return .{
            .permissions = permissions,
            .enabled = true,
        };
    }

    pub fn checkPermission(self: Sandbox, permission: []const u8) bool {
        if (!self.enabled) return true;

        if (std.mem.eql(u8, permission, "network")) return self.permissions.network;
        if (std.mem.eql(u8, permission, "file_read")) return self.permissions.file_system_read;
        if (std.mem.eql(u8, permission, "file_write")) return self.permissions.file_system_write;
        if (std.mem.eql(u8, permission, "clipboard")) return self.permissions.clipboard;
        if (std.mem.eql(u8, permission, "notifications")) return self.permissions.notifications;
        if (std.mem.eql(u8, permission, "camera")) return self.permissions.camera;
        if (std.mem.eql(u8, permission, "microphone")) return self.permissions.microphone;

        return false;
    }

    pub fn requestPermission(self: *Sandbox, permission: []const u8) !void {
        _ = self;
        _ = permission;
        // Would show native permission dialog
    }
};

// IPC (Inter-Process Communication) improvements
pub const IpcMessage = struct {
    channel: []const u8,
    data: []const u8,
    reply_channel: ?[]const u8 = null,
};

pub const IpcHandler = *const fn (IpcMessage) void;

pub const Ipc = struct {
    handlers: std.StringHashMap(IpcHandler),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Ipc {
        return .{
            .handlers = std.StringHashMap(IpcHandler).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn on(self: *Ipc, channel: []const u8, handler: IpcHandler) !void {
        try self.handlers.put(channel, handler);
    }

    pub fn send(self: *Ipc, channel: []const u8, data: []const u8) !void {
        if (self.handlers.get(channel)) |handler| {
            const msg = IpcMessage{
                .channel = channel,
                .data = data,
            };
            handler(msg);
        }
    }

    pub fn invoke(self: *Ipc, channel: []const u8, data: []const u8) ![]const u8 {
        _ = self;
        _ = channel;
        _ = data;
        // Would send and wait for reply
        return "";
    }

    pub fn deinit(self: *Ipc) void {
        self.handlers.deinit();
    }
};

// Accessibility support
pub const AccessibilityRole = enum {
    button,
    link,
    heading,
    text,
    image,
    list,
    list_item,
    table,
    menu,
    dialog,
};

pub const AccessibilityElement = struct {
    role: AccessibilityRole,
    label: []const u8,
    value: []const u8,
    enabled: bool = true,
};

pub fn setAccessibilityLabel(element: objc.id, label: []const u8) !void {
    _ = element;
    _ = label;
    // Would use NSAccessibility protocol
}

pub fn enableVoiceOver(window: objc.id) void {
    _ = window;
    // Would enable VoiceOver support
}

pub fn setAccessibilityRole(element: objc.id, role: AccessibilityRole) !void {
    _ = element;
    _ = role;
    // Would use setAccessibilityRole:
}

// Internationalization (i18n)
pub const Locale = struct {
    language: []const u8,
    region: []const u8,
    direction: enum { ltr, rtl } = .ltr,
};

pub const I18n = struct {
    current_locale: Locale,
    translations: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, locale: Locale) I18n {
        return .{
            .current_locale = locale,
            .translations = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn translate(self: *I18n, key: []const u8) []const u8 {
        return self.translations.get(key) orelse key;
    }

    pub fn loadTranslations(self: *I18n, file_path: []const u8) !void {
        _ = self;
        _ = file_path;
        // Would load JSON/TOML translation file
    }

    pub fn setLocale(self: *I18n, locale: Locale) void {
        self.current_locale = locale;
    }

    pub fn deinit(self: *I18n) void {
        self.translations.deinit();
    }
};

pub fn getSystemLocale() Locale {
    // Would use NSLocale
    return .{
        .language = "en",
        .region = "US",
        .direction = .ltr,
    };
}

// Code signing
pub const CodeSignature = struct {
    certificate_path: []const u8,
    identity: []const u8,
    entitlements_path: ?[]const u8 = null,
};

pub fn signApplication(app_path: []const u8, signature: CodeSignature) !void {
    _ = app_path;
    _ = signature;
    // Would use codesign tool on macOS
    // codesign --sign "Developer ID" --entitlements entitlements.plist app.app
}

pub fn verifySignature(app_path: []const u8) !bool {
    _ = app_path;
    // Would use codesign --verify
    return false;
}

pub fn notarizeApplication(app_path: []const u8, apple_id: []const u8, password: []const u8) !void {
    _ = app_path;
    _ = apple_id;
    _ = password;
    // Would use xcrun notarytool
}

// Installer generation
pub const InstallerOptions = struct {
    app_name: []const u8,
    app_version: []const u8,
    app_icon: ?[]const u8 = null,
    license_file: ?[]const u8 = null,
    background_image: ?[]const u8 = null,
    install_location: []const u8 = "/Applications",
};

pub const Installer = struct {
    options: InstallerOptions,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, options: InstallerOptions) Installer {
        return .{
            .options = options,
            .allocator = allocator,
        };
    }

    pub fn generateDmg(self: *Installer, app_path: []const u8, output_path: []const u8) !void {
        _ = self;
        _ = app_path;
        _ = output_path;
        // Would use hdiutil to create DMG on macOS
    }

    pub fn generatePkg(self: *Installer, app_path: []const u8, output_path: []const u8) !void {
        _ = self;
        _ = app_path;
        _ = output_path;
        // Would use pkgbuild/productbuild on macOS
    }

    pub fn generateMsi(self: *Installer, app_path: []const u8, output_path: []const u8) !void {
        _ = self;
        _ = app_path;
        _ = output_path;
        // Would use WiX Toolset on Windows
    }

    pub fn generateDeb(self: *Installer, app_path: []const u8, output_path: []const u8) !void {
        _ = self;
        _ = app_path;
        _ = output_path;
        // Would use dpkg-deb on Linux
    }

    pub fn generateRpm(self: *Installer, app_path: []const u8, output_path: []const u8) !void {
        _ = self;
        _ = app_path;
        _ = output_path;
        // Would use rpmbuild on Linux
    }

    pub fn generateAppImage(self: *Installer, app_path: []const u8, output_path: []const u8) !void {
        _ = self;
        _ = app_path;
        _ = output_path;
        // Would use appimagetool on Linux
    }
};

/// Initialize the NSApplication for regular apps (with Dock icon)
pub fn initApp() void {
    const NSApplication = getClass("NSApplication");
    const app = msgSend0(NSApplication, "sharedApplication");

    const NSApplicationActivationPolicyRegular: c_long = 0;
    _ = msgSend1(app, "setActivationPolicy:", NSApplicationActivationPolicyRegular);
}

/// Initialize without finishing launch - for apps that will set policy later
pub fn initAppWithoutLaunching() void {
    const NSApplication = getClass("NSApplication");
    const app = msgSend0(NSApplication, "sharedApplication");
    _ = app; // Just ensure app exists
}

/// Create a minimal application menu with standard shortcuts (CMD+H, CMD+Q, etc.)
pub fn createApplicationMenu() void {
    const NSApplication = getClass("NSApplication");
    const NSMenu = getClass("NSMenu");
    const NSMenuItem = getClass("NSMenuItem");
    const NSString = getClass("NSString");

    const app = msgSend0(NSApplication, "sharedApplication");

    // Create main menu bar
    const main_menu = msgSend0(msgSend0(NSMenu, "alloc"), "init");

    // Create app menu (first menu in menu bar)
    const app_menu_item = msgSend0(msgSend0(NSMenuItem, "alloc"), "init");
    const app_menu = msgSend0(msgSend0(NSMenu, "alloc"), "init");

    // Add "Hide" item with CMD+H
    const hide_title = msgSend1(NSString, "stringWithUTF8String:", "Hide");
    const hide_item = msgSend0(msgSend0(NSMenuItem, "alloc"), "init");
    msgSendVoid1(hide_item, "setTitle:", hide_title);
    const h_key = msgSend1(NSString, "stringWithUTF8String:", "h");
    msgSendVoid1(hide_item, "setKeyEquivalent:", h_key);
    const hide_sel = sel("hide:");
    msgSendVoid1(hide_item, "setAction:", hide_sel);
    msgSendVoid1(app_menu, "addItem:", hide_item);

    // Add separator
    const sep1 = msgSend0(NSMenuItem, "separatorItem");
    msgSendVoid1(app_menu, "addItem:", sep1);

    // Add "Quit" item with CMD+Q
    const quit_title = msgSend1(NSString, "stringWithUTF8String:", "Quit");
    const quit_item = msgSend0(msgSend0(NSMenuItem, "alloc"), "init");
    msgSendVoid1(quit_item, "setTitle:", quit_title);
    const q_key = msgSend1(NSString, "stringWithUTF8String:", "q");
    msgSendVoid1(quit_item, "setKeyEquivalent:", q_key);
    const quit_sel = sel("terminate:");
    msgSendVoid1(quit_item, "setAction:", quit_sel);
    msgSendVoid1(app_menu, "addItem:", quit_item);

    // Set submenu
    msgSendVoid1(app_menu_item, "setSubmenu:", app_menu);
    msgSendVoid1(main_menu, "addItem:", app_menu_item);

    // Set as main menu
    msgSendVoid1(app, "setMainMenu:", main_menu);
}

/// Initialize for menubar/system tray apps (NO Dock icon)
pub fn initAppForTray() void {
    const NSApplication = getClass("NSApplication");
    const app = msgSend0(NSApplication, "sharedApplication");

    // Use Accessory policy for menubar-only apps
    const NSApplicationActivationPolicyAccessory: c_long = 1;
    _ = msgSend1(app, "setActivationPolicy:", NSApplicationActivationPolicyAccessory);

    // MUST call finishLaunching BEFORE creating status bar items!
    // This is the key - the working test does it in this order
    msgSendVoid0(app, "finishLaunching");

    // Create application menu for standard shortcuts (CMD+H, CMD+Q, etc.)
    createApplicationMenu();
}

/// Show all windows (call this AFTER creating system tray, BEFORE runApp)
pub fn showAllWindows() void {
    // Get all windows
    const NSApplication = getClass("NSApplication");
    const app = msgSend0(NSApplication, "sharedApplication");
    const windows = msgSend0(app, "windows");

    // Show each window WITHOUT making it key (don't activate yet)
    const count_obj = msgSend0(windows, "count");
    const count: c_ulong = @intCast(@intFromPtr(count_obj));
    var i: c_ulong = 0;
    while (i < count) : (i += 1) {
        const window = msgSend1(windows, "objectAtIndex:", i);
        // Use orderFront instead of makeKeyAndOrderFront - this shows the window
        // without activating the app
        _ = msgSend1(window, "orderFront:", @as(?*anyopaque, null));
    }
}

pub fn runApp() void {
    const NSApplication = getClass("NSApplication");
    const app = msgSend0(NSApplication, "sharedApplication");

    // DON'T activate - let the app activate naturally
    // The working test (test-minimal-tray.zig) doesn't call activate and it works!
    // Calling activate might interfere with the status bar item visibility

    // Run event loop
    msgSendVoid0(app, "run");
}
