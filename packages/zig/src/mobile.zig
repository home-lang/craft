const std = @import("std");

/// Mobile Platform Support
/// Provides iOS and Android native integration

// Import Objective-C runtime for iOS
const objc = if (@import("builtin").target.isDarwin()) struct {
    pub extern "c" fn objc_getClass(name: [*:0]const u8) ?*anyopaque;
    pub extern "c" fn sel_registerName(name: [*:0]const u8) ?*anyopaque;
    pub extern "c" fn objc_msgSend() void;
    pub extern "c" fn objc_msgSend_stret() void;
    pub extern "c" fn class_getName(cls: ?*anyopaque) [*:0]const u8;
    pub extern "c" fn objc_allocateClassPair(superclass: ?*anyopaque, name: [*:0]const u8, extraBytes: usize) ?*anyopaque;
    pub extern "c" fn objc_registerClassPair(cls: ?*anyopaque) void;
    pub extern "c" fn class_addMethod(cls: ?*anyopaque, name: ?*anyopaque, imp: *const anyopaque, types: [*:0]const u8) bool;
    pub extern "c" fn object_getClass(obj: ?*anyopaque) ?*anyopaque;
    pub extern "c" fn class_createInstance(cls: ?*anyopaque, extraBytes: usize) ?*anyopaque;
    pub extern "c" fn objc_setAssociatedObject(obj: ?*anyopaque, key: ?*const anyopaque, value: ?*anyopaque, policy: c_uint) void;
    pub extern "c" fn objc_getAssociatedObject(obj: ?*anyopaque, key: ?*const anyopaque) ?*anyopaque;
    pub extern "c" fn objc_removeAssociatedObjects(obj: ?*anyopaque) void;
    pub extern "c" fn object_setClass(obj: ?*anyopaque, cls: ?*anyopaque) ?*anyopaque;

    // Associated object policies
    pub const OBJC_ASSOCIATION_ASSIGN: c_uint = 0;
    pub const OBJC_ASSOCIATION_RETAIN_NONATOMIC: c_uint = 1;
    pub const OBJC_ASSOCIATION_COPY_NONATOMIC: c_uint = 3;
    pub const OBJC_ASSOCIATION_RETAIN: c_uint = 769;
    pub const OBJC_ASSOCIATION_COPY: c_uint = 771;
} else struct {};

// JNI for Android
const jni = if (@import("builtin").target.os.tag == .linux) struct {
    pub const JNIEnv = opaque {};
    pub const jobject = ?*anyopaque;
    pub const jclass = ?*anyopaque;
    pub const jmethodID = ?*anyopaque;
    pub const jstring = ?*anyopaque;
    pub const jboolean = u8;
    pub const jint = i32;
    pub const jlong = i64;

    pub extern "c" fn (*JNIEnv).GetObjectClass(env: *JNIEnv, obj: jobject) jclass;
    pub extern "c" fn (*JNIEnv).GetMethodID(env: *JNIEnv, cls: jclass, name: [*:0]const u8, sig: [*:0]const u8) jmethodID;
    pub extern "c" fn (*JNIEnv).CallVoidMethod(env: *JNIEnv, obj: jobject, methodID: jmethodID, ...) void;
    pub extern "c" fn (*JNIEnv).CallObjectMethod(env: *JNIEnv, obj: jobject, methodID: jmethodID, ...) jobject;
    pub extern "c" fn (*JNIEnv).NewStringUTF(env: *JNIEnv, bytes: [*:0]const u8) jstring;
    pub extern "c" fn (*JNIEnv).GetStringUTFChars(env: *JNIEnv, string: jstring, isCopy: ?*jboolean) [*:0]const u8;
    pub extern "c" fn (*JNIEnv).ReleaseStringUTFChars(env: *JNIEnv, string: jstring, utf: [*:0]const u8) void;
} else struct {};

pub const Platform = enum {
    ios,
    android,
    unknown,

    pub fn current() Platform {
        const builtin = @import("builtin");
        return switch (builtin.target.os.tag) {
            .ios => .ios,
            .tvos => .ios,
            .watchos => .ios,
            .macos => .ios, // iOS simulator on macOS
            .linux => .android, // Assume Android when building on Linux for ARM
            else => .unknown,
        };
    }
};

/// Memory Management for Native Objects
pub const NativeObjectManager = struct {
    allocator: std.mem.Allocator,
    tracked_objects: std.AutoHashMap(usize, ObjectInfo),
    total_allocations: usize,
    total_deallocations: usize,
    peak_object_count: usize,

    const ObjectInfo = struct {
        ptr: *anyopaque,
        size: usize,
        type_name: []const u8,
        allocation_time: i64,
    };

    pub fn init(allocator: std.mem.Allocator) NativeObjectManager {
        return .{
            .allocator = allocator,
            .tracked_objects = std.AutoHashMap(usize, ObjectInfo).init(allocator),
            .total_allocations = 0,
            .total_deallocations = 0,
            .peak_object_count = 0,
        };
    }

    pub fn deinit(self: *NativeObjectManager) void {
        // Clean up any remaining tracked objects
        var it = self.tracked_objects.iterator();
        while (it.next()) |entry| {
            self.releaseObject(entry.key_ptr.*) catch {};
        }
        self.tracked_objects.deinit();
    }

    pub fn trackObject(self: *NativeObjectManager, ptr: *anyopaque, size: usize, type_name: []const u8) !void {
        const addr = @intFromPtr(ptr);
        const info = ObjectInfo{
            .ptr = ptr,
            .size = size,
            .type_name = type_name,
            .allocation_time = std.time.timestamp(),
        };

        try self.tracked_objects.put(addr, info);
        self.total_allocations += 1;

        const current_count = self.tracked_objects.count();
        if (current_count > self.peak_object_count) {
            self.peak_object_count = current_count;
        }
    }

    pub fn releaseObject(self: *NativeObjectManager, addr: usize) !void {
        if (self.tracked_objects.fetchRemove(addr)) |entry| {
            self.total_deallocations += 1;

            // Platform-specific cleanup
            const platform = Platform.current();
            switch (platform) {
                .ios => {
                    if (@import("builtin").target.isDarwin()) {
                        // Remove associated objects before releasing
                        objc.objc_removeAssociatedObjects(entry.value.ptr);
                    }
                },
                .android => {
                    // JNI cleanup would go here
                },
                .unknown => {},
            }
        }
    }

    pub fn getObjectInfo(self: *NativeObjectManager, addr: usize) ?ObjectInfo {
        return self.tracked_objects.get(addr);
    }

    pub fn getStats(self: *NativeObjectManager) struct {
        total_allocations: usize,
        total_deallocations: usize,
        current_objects: usize,
        peak_objects: usize,
    } {
        return .{
            .total_allocations = self.total_allocations,
            .total_deallocations = self.total_deallocations,
            .current_objects = self.tracked_objects.count(),
            .peak_objects = self.peak_object_count,
        };
    }

    pub fn printLeaks(self: *NativeObjectManager) void {
        var it = self.tracked_objects.iterator();
        var leak_count: usize = 0;

        std.debug.print("Memory Leak Report:\n", .{});
        while (it.next()) |entry| {
            const age = std.time.timestamp() - entry.value.*.allocation_time;
            std.debug.print("  Leaked {s} at 0x{x} (size: {d} bytes, age: {d}s)\n", .{
                entry.value.*.type_name,
                entry.key_ptr.*,
                entry.value.*.size,
                age,
            });
            leak_count += 1;
        }

        if (leak_count == 0) {
            std.debug.print("  No leaks detected!\n", .{});
        } else {
            std.debug.print("  Total leaks: {d}\n", .{leak_count});
        }
    }
};

/// Global native object manager (should be initialized on app startup)
var global_object_manager: ?NativeObjectManager = null;

pub fn initGlobalObjectManager(allocator: std.mem.Allocator) void {
    global_object_manager = NativeObjectManager.init(allocator);
}

pub fn deinitGlobalObjectManager() void {
    if (global_object_manager) |*manager| {
        manager.deinit();
        global_object_manager = null;
    }
}

pub fn getGlobalObjectManager() ?*NativeObjectManager {
    if (global_object_manager) |*manager| {
        return manager;
    }
    return null;
}

/// iOS Native Integration
pub const iOS = struct {
    pub const UIViewController = opaque {};
    pub const UIView = opaque {};
    pub const WKWebView = opaque {};
    pub const NSString = opaque {};

    /// iOS App Configuration
    pub const AppConfig = struct {
        bundle_id: []const u8,
        display_name: []const u8,
        version: []const u8,
        build_number: []const u8,
        supported_orientations: []const Orientation,
        requires_fullscreen: bool = false,
        status_bar_style: StatusBarStyle = .default,
        background_modes: []const BackgroundMode = &[_]BackgroundMode{},

        pub const Orientation = enum {
            portrait,
            portrait_upside_down,
            landscape_left,
            landscape_right,
        };

        pub const StatusBarStyle = enum {
            default,
            light_content,
            dark_content,
        };

        pub const BackgroundMode = enum {
            audio,
            location,
            voip,
            fetch,
            remote_notification,
            processing,
        };
    };

    /// WKWebView Configuration
    pub const WebViewConfig = struct {
        allows_inline_media_playback: bool = true,
        allows_air_play: bool = true,
        allows_picture_in_picture: bool = true,
        media_types_requiring_user_action: MediaTypes = .none,
        data_detector_types: DataDetectorTypes = .all,
        suppresses_incremental_rendering: bool = false,
        allows_back_forward_navigation_gestures: bool = true,
        selection_granularity: SelectionGranularity = .dynamic,

        pub const MediaTypes = enum {
            none,
            audio,
            video,
            all,
        };

        pub const DataDetectorTypes = enum {
            none,
            phone_number,
            link,
            address,
            calendar_event,
            all,
        };

        pub const SelectionGranularity = enum {
            dynamic,
            character,
        };
    };

    /// Create iOS WebView
    pub fn createWebView(allocator: std.mem.Allocator, config: WebViewConfig) !*WKWebView {
        if (!@import("builtin").target.isDarwin()) {
            return error.UnsupportedPlatform;
        }

        // Get WKWebView class
        const WKWebViewClass = objc.objc_getClass("WKWebView") orelse return error.ClassNotFound;

        // Create configuration
        const WKWebViewConfigurationClass = objc.objc_getClass("WKWebViewConfiguration") orelse return error.ClassNotFound;
        const sel_alloc = objc.sel_registerName("alloc") orelse return error.SelectorNotFound;
        const sel_init = objc.sel_registerName("init") orelse return error.SelectorNotFound;

        // Create configuration instance
        const configObj = objc.class_createInstance(WKWebViewConfigurationClass, 0) orelse return error.AllocationFailed;

        // Configure webview settings based on config
        if (config.allows_inline_media_playback) {
            const sel_setAllowsInlineMediaPlayback = objc.sel_registerName("setAllowsInlineMediaPlayback:") orelse return error.SelectorNotFound;
            // Call method (simplified - would need proper msgSend wrapper)
            _ = sel_setAllowsInlineMediaPlayback;
        }

        // Create WKWebView instance with frame
        const webview = objc.class_createInstance(WKWebViewClass, 0) orelse return error.AllocationFailed;

        // Track the webview in memory manager
        if (getGlobalObjectManager()) |manager| {
            try manager.trackObject(webview, @sizeOf(@TypeOf(webview)), "WKWebView");
        }

        // Associate allocator with webview for cleanup
        const allocator_ptr = try allocator.create(std.mem.Allocator);
        allocator_ptr.* = allocator;
        objc.objc_setAssociatedObject(webview, @ptrCast(&allocator_key), allocator_ptr, objc.OBJC_ASSOCIATION_RETAIN);

        return @ptrCast(@alignCast(webview));
    }

    // Key for associated allocator
    var allocator_key: u8 = 0;

    /// Cleanup/dealloc WebView
    pub fn destroyWebView(webview: *WKWebView) void {
        if (!@import("builtin").target.isDarwin()) {
            return;
        }

        const webview_ptr: *anyopaque = @ptrCast(@alignCast(webview));
        const addr = @intFromPtr(webview_ptr);

        // Get associated allocator and clean up
        const allocator_ptr = objc.objc_getAssociatedObject(webview_ptr, @ptrCast(&allocator_key));
        if (allocator_ptr) |alloc_ptr| {
            const allocator: *std.mem.Allocator = @ptrCast(@alignCast(alloc_ptr));
            allocator.destroy(allocator);
        }

        // Remove from memory tracking
        if (getGlobalObjectManager()) |manager| {
            manager.releaseObject(addr) catch {};
        }

        // Remove all associated objects
        objc.objc_removeAssociatedObjects(webview_ptr);

        // Call dealloc if needed (platform handles retain/release)
        const sel_release = objc.sel_registerName("release") orelse return;
        _ = sel_release;
    }

    /// Load URL in WebView
    pub fn loadURL(webview: *WKWebView, url: []const u8) !void {
        if (!@import("builtin").target.isDarwin()) {
            return error.UnsupportedPlatform;
        }

        // Get NSURL class
        const NSURLClass = objc.objc_getClass("NSURL") orelse return error.ClassNotFound;
        const NSStringClass = objc.objc_getClass("NSString") orelse return error.ClassNotFound;
        const NSURLRequestClass = objc.objc_getClass("NSURLRequest") orelse return error.ClassNotFound;

        // Create NSString from URL
        const sel_stringWithUTF8String = objc.sel_registerName("stringWithUTF8String:") orelse return error.SelectorNotFound;
        const sel_URLWithString = objc.sel_registerName("URLWithString:") orelse return error.SelectorNotFound;
        const sel_requestWithURL = objc.sel_registerName("requestWithURL:") orelse return error.SelectorNotFound;
        const sel_loadRequest = objc.sel_registerName("loadRequest:") orelse return error.SelectorNotFound;

        // Note: This is a simplified version. Full implementation would use proper msgSend wrappers
        // to handle different architectures and return types correctly.

        _ = webview;
        _ = url;
        _ = NSURLClass;
        _ = NSStringClass;
        _ = NSURLRequestClass;
        _ = sel_stringWithUTF8String;
        _ = sel_URLWithString;
        _ = sel_requestWithURL;
        _ = sel_loadRequest;
    }

    /// Execute JavaScript
    pub fn evaluateJavaScript(webview: *WKWebView, script: []const u8, callback: ?*const fn ([]const u8) void) !void {
        if (!@import("builtin").target.isDarwin()) {
            return error.UnsupportedPlatform;
        }

        const sel_evaluateJavaScript = objc.sel_registerName("evaluateJavaScript:completionHandler:") orelse return error.SelectorNotFound;
        const NSStringClass = objc.objc_getClass("NSString") orelse return error.ClassNotFound;
        const sel_stringWithUTF8String = objc.sel_registerName("stringWithUTF8String:") orelse return error.SelectorNotFound;

        // Note: Full implementation would properly wrap the callback and handle the completion handler
        _ = webview;
        _ = script;
        _ = callback;
        _ = sel_evaluateJavaScript;
        _ = NSStringClass;
        _ = sel_stringWithUTF8String;
    }

    /// Handle Deep Links
    pub fn handleDeepLink(url: []const u8) !void {
        _ = url;
        // Parse and handle custom URL scheme
    }

    /// Request Permissions
    pub const Permission = enum {
        camera,
        microphone,
        location,
        photos,
        notifications,
        contacts,
        calendar,
        reminders,
    };

    pub fn requestPermission(permission: Permission, callback: *const fn (bool) void) !void {
        if (!@import("builtin").target.isDarwin()) {
            return error.UnsupportedPlatform;
        }

        // Different permission types require different iOS APIs
        switch (permission) {
            .camera, .microphone => {
                const AVCaptureDeviceClass = objc.objc_getClass("AVCaptureDevice") orelse return error.ClassNotFound;
                const sel_requestAccessForMediaType = objc.sel_registerName("requestAccessForMediaType:completionHandler:") orelse return error.SelectorNotFound;

                // Note: Full implementation would properly wrap the completion handler
                _ = AVCaptureDeviceClass;
                _ = sel_requestAccessForMediaType;
                _ = callback;
            },
            .location => {
                const CLLocationManagerClass = objc.objc_getClass("CLLocationManager") orelse return error.ClassNotFound;
                const sel_requestWhenInUseAuthorization = objc.sel_registerName("requestWhenInUseAuthorization") orelse return error.SelectorNotFound;

                _ = CLLocationManagerClass;
                _ = sel_requestWhenInUseAuthorization;
                _ = callback;
            },
            .photos => {
                const PHPhotoLibraryClass = objc.objc_getClass("PHPhotoLibrary") orelse return error.ClassNotFound;
                const sel_requestAuthorization = objc.sel_registerName("requestAuthorization:") orelse return error.SelectorNotFound;

                _ = PHPhotoLibraryClass;
                _ = sel_requestAuthorization;
                _ = callback;
            },
            .notifications => {
                const UNUserNotificationCenterClass = objc.objc_getClass("UNUserNotificationCenter") orelse return error.ClassNotFound;
                const sel_currentNotificationCenter = objc.sel_registerName("currentNotificationCenter") orelse return error.SelectorNotFound;
                const sel_requestAuthorizationWithOptions = objc.sel_registerName("requestAuthorizationWithOptions:completionHandler:") orelse return error.SelectorNotFound;

                _ = UNUserNotificationCenterClass;
                _ = sel_currentNotificationCenter;
                _ = sel_requestAuthorizationWithOptions;
                _ = callback;
            },
            .contacts, .calendar, .reminders => {
                const CNContactStoreClass = objc.objc_getClass("CNContactStore") orelse return error.ClassNotFound;
                const sel_requestAccessForEntityType = objc.sel_registerName("requestAccessForEntityType:completionHandler:") orelse return error.SelectorNotFound;

                _ = CNContactStoreClass;
                _ = sel_requestAccessForEntityType;
                _ = callback;
            },
        }
    }

    /// Haptic Feedback
    pub const HapticType = enum {
        selection,
        impact_light,
        impact_medium,
        impact_heavy,
        notification_success,
        notification_warning,
        notification_error,
    };

    pub fn triggerHaptic(haptic_type: HapticType) void {
        if (!@import("builtin").target.isDarwin()) {
            return;
        }

        switch (haptic_type) {
            .selection => {
                const UISelectionFeedbackGeneratorClass = objc.objc_getClass("UISelectionFeedbackGenerator") orelse return;
                const sel_alloc = objc.sel_registerName("alloc") orelse return;
                const sel_init = objc.sel_registerName("init") orelse return;
                const sel_selectionChanged = objc.sel_registerName("selectionChanged") orelse return;

                // Create generator and trigger
                _ = UISelectionFeedbackGeneratorClass;
                _ = sel_alloc;
                _ = sel_init;
                _ = sel_selectionChanged;
            },
            .impact_light, .impact_medium, .impact_heavy => {
                const UIImpactFeedbackGeneratorClass = objc.objc_getClass("UIImpactFeedbackGenerator") orelse return;
                const sel_alloc = objc.sel_registerName("alloc") orelse return;
                const sel_initWithStyle = objc.sel_registerName("initWithStyle:") orelse return;
                const sel_impactOccurred = objc.sel_registerName("impactOccurred") orelse return;

                // Determine impact style
                const style: i64 = switch (haptic_type) {
                    .impact_light => 0, // UIImpactFeedbackStyleLight
                    .impact_medium => 1, // UIImpactFeedbackStyleMedium
                    .impact_heavy => 2, // UIImpactFeedbackStyleHeavy
                    else => 1,
                };

                _ = UIImpactFeedbackGeneratorClass;
                _ = sel_alloc;
                _ = sel_initWithStyle;
                _ = sel_impactOccurred;
                _ = style;
            },
            .notification_success, .notification_warning, .notification_error => {
                const UINotificationFeedbackGeneratorClass = objc.objc_getClass("UINotificationFeedbackGenerator") orelse return;
                const sel_alloc = objc.sel_registerName("alloc") orelse return;
                const sel_init = objc.sel_registerName("init") orelse return;
                const sel_notificationOccurred = objc.sel_registerName("notificationOccurred:") orelse return;

                // Determine notification type
                const feedbackType: i64 = switch (haptic_type) {
                    .notification_success => 0, // UINotificationFeedbackTypeSuccess
                    .notification_warning => 1, // UINotificationFeedbackTypeWarning
                    .notification_error => 2, // UINotificationFeedbackTypeError
                    else => 0,
                };

                _ = UINotificationFeedbackGeneratorClass;
                _ = sel_alloc;
                _ = sel_init;
                _ = sel_notificationOccurred;
                _ = feedbackType;
            },
        }
    }
};

/// Android Native Integration
pub const Android = struct {
    pub const Activity = opaque {};
    pub const WebView = opaque {};
    pub const Context = opaque {};

    /// Android App Configuration
    pub const AppConfig = struct {
        package_name: []const u8,
        app_name: []const u8,
        version_name: []const u8,
        version_code: u32,
        min_sdk_version: u32 = 21,
        target_sdk_version: u32 = 34,
        supported_orientations: []const Orientation,
        hardware_acceleration: bool = true,
        large_heap: bool = false,
        uses_cleartext_traffic: bool = false,

        pub const Orientation = enum {
            portrait,
            landscape,
            sensor,
            user,
            behind,
            nosensor,
            unspecified,
        };
    };

    /// WebView Configuration
    pub const WebViewConfig = struct {
        javascript_enabled: bool = true,
        dom_storage_enabled: bool = true,
        database_enabled: bool = true,
        media_playback_requires_user_gesture: bool = false,
        allow_file_access: bool = false,
        allow_content_access: bool = false,
        mixed_content_mode: MixedContentMode = .never_allow,
        cache_mode: CacheMode = .default,

        pub const MixedContentMode = enum {
            always_allow,
            never_allow,
            compatibility_mode,
        };

        pub const CacheMode = enum {
            default,
            cache_else_network,
            no_cache,
            cache_only,
        };
    };

    /// JNI Environment (global reference, must be set by Java/Kotlin code)
    var jni_env: ?*jni.JNIEnv = null;

    pub fn setJNIEnv(env: *jni.JNIEnv) void {
        jni_env = env;
    }

    /// Create Android WebView
    pub fn createWebView(allocator: std.mem.Allocator, context: *Context, config: WebViewConfig) !*WebView {
        const builtin = @import("builtin");
        if (builtin.target.os.tag != .linux) {
            return error.UnsupportedPlatform;
        }

        const env = jni_env orelse return error.JNINotInitialized;

        // Get WebView class
        const webview_class_name = "android/webkit/WebView";
        const webview_class = try getJNIClass(env, webview_class_name);

        // Get WebView constructor
        const constructor_id = try getJNIMethod(env, webview_class, "<init>", "(Landroid/content/Context;)V");

        // Create WebView instance
        const webview_obj = jni.CallObjectMethod(env, context, constructor_id);
        if (webview_obj == null) {
            return error.WebViewCreationFailed;
        }

        // Configure WebView settings
        const settings_method = try getJNIMethod(env, webview_class, "getSettings", "()Landroid/webkit/WebSettings;");
        const settings = jni.CallObjectMethod(env, webview_obj, settings_method);

        if (settings != null) {
            const settings_class_name = "android/webkit/WebSettings";
            const settings_class = try getJNIClass(env, settings_class_name);

            // Enable JavaScript
            if (config.javascript_enabled) {
                const set_js_enabled = try getJNIMethod(env, settings_class, "setJavaScriptEnabled", "(Z)V");
                jni.CallVoidMethod(env, settings, set_js_enabled, @as(jni.jboolean, 1));
            }

            // Enable DOM storage
            if (config.dom_storage_enabled) {
                const set_dom_storage = try getJNIMethod(env, settings_class, "setDomStorageEnabled", "(Z)V");
                jni.CallVoidMethod(env, settings, set_dom_storage, @as(jni.jboolean, 1));
            }

            // Enable database
            if (config.database_enabled) {
                const set_database = try getJNIMethod(env, settings_class, "setDatabaseEnabled", "(Z)V");
                jni.CallVoidMethod(env, settings, set_database, @as(jni.jboolean, 1));
            }
        }

        _ = allocator; // Will be used for cleanup tracking
        return @ptrCast(@alignCast(webview_obj));
    }

    /// Load URL in WebView
    pub fn loadURL(webview: *WebView, url: []const u8) !void {
        const builtin = @import("builtin");
        if (builtin.target.os.tag != .linux) {
            return error.UnsupportedPlatform;
        }

        const env = jni_env orelse return error.JNINotInitialized;

        // Get WebView class
        const webview_obj: jni.jobject = @ptrCast(@alignCast(webview));
        const webview_class = jni.GetObjectClass(env, webview_obj);

        // Get loadUrl method
        const load_url_method = try getJNIMethod(env, webview_class, "loadUrl", "(Ljava/lang/String;)V");

        // Convert URL to Java string
        const url_jstring = jni.NewStringUTF(env, @ptrCast(url.ptr));

        // Call loadUrl
        jni.CallVoidMethod(env, webview_obj, load_url_method, url_jstring);
    }

    /// Execute JavaScript
    pub fn evaluateJavaScript(webview: *WebView, script: []const u8, callback: ?*const fn ([]const u8) void) !void {
        const builtin = @import("builtin");
        if (builtin.target.os.tag != .linux) {
            return error.UnsupportedPlatform;
        }

        const env = jni_env orelse return error.JNINotInitialized;

        // Get WebView class
        const webview_obj: jni.jobject = @ptrCast(@alignCast(webview));
        const webview_class = jni.GetObjectClass(env, webview_obj);

        // Get evaluateJavascript method
        const eval_js_method = try getJNIMethod(env, webview_class, "evaluateJavascript", "(Ljava/lang/String;Landroid/webkit/ValueCallback;)V");

        // Convert script to Java string
        const script_jstring = jni.NewStringUTF(env, @ptrCast(script.ptr));

        // Call evaluateJavascript (callback would need to be wrapped in Java ValueCallback)
        _ = callback; // TODO: Wrap callback in ValueCallback interface
        jni.CallVoidMethod(env, webview_obj, eval_js_method, script_jstring, null);
    }

    /// Helper function to get JNI class
    fn getJNIClass(env: *jni.JNIEnv, class_name: [:0]const u8) !jni.jclass {
        const find_class_method = @field(env, "FindClass");
        const cls = find_class_method(env, class_name.ptr);
        if (cls == null) {
            return error.ClassNotFound;
        }
        return cls;
    }

    /// Helper function to get JNI method
    fn getJNIMethod(env: *jni.JNIEnv, cls: jni.jclass, method_name: [:0]const u8, signature: [:0]const u8) !jni.jmethodID {
        const get_method_id = @field(env, "GetMethodID");
        const method_id = get_method_id(env, cls, method_name.ptr, signature.ptr);
        if (method_id == null) {
            return error.MethodNotFound;
        }
        return method_id;
    }

    /// Handle Deep Links
    pub fn handleDeepLink(intent_data: []const u8) !void {
        _ = intent_data;
        // Parse and handle Android Intent data
    }

    /// Request Permissions
    pub const Permission = enum {
        camera,
        microphone,
        location_fine,
        location_coarse,
        read_external_storage,
        write_external_storage,
        read_contacts,
        write_contacts,
        record_audio,
    };

    pub fn requestPermission(activity: *Activity, permission: Permission, callback: *const fn (bool) void) !void {
        const builtin = @import("builtin");
        if (builtin.target.os.tag != .linux) {
            return error.UnsupportedPlatform;
        }

        const env = jni_env orelse return error.JNINotInitialized;

        // Get ActivityCompat class
        const activity_compat_class = try getJNIClass(env, "androidx/core/app/ActivityCompat");

        // Convert permission to Android permission string
        const permission_str = switch (permission) {
            .camera => "android.permission.CAMERA",
            .microphone => "android.permission.RECORD_AUDIO",
            .location_fine => "android.permission.ACCESS_FINE_LOCATION",
            .location_coarse => "android.permission.ACCESS_COARSE_LOCATION",
            .read_external_storage => "android.permission.READ_EXTERNAL_STORAGE",
            .write_external_storage => "android.permission.WRITE_EXTERNAL_STORAGE",
            .read_contacts => "android.permission.READ_CONTACTS",
            .write_contacts => "android.permission.WRITE_CONTACTS",
            .record_audio => "android.permission.RECORD_AUDIO",
        };

        // Get requestPermissions method
        const request_permissions_method = try getJNIMethod(
            env,
            activity_compat_class,
            "requestPermissions",
            "(Landroid/app/Activity;[Ljava/lang/String;I)V",
        );

        // Create string array with single permission
        const permission_jstring = jni.NewStringUTF(env, @ptrCast(permission_str));

        // Call requestPermissions
        _ = callback; // TODO: Store callback to be invoked in onRequestPermissionsResult
        const activity_obj: jni.jobject = @ptrCast(@alignCast(activity));
        jni.CallVoidMethod(env, activity_obj, request_permissions_method, permission_jstring, @as(jni.jint, 1001));
    }

    /// Vibration
    pub fn vibrate(context: *Context, duration_ms: u64) void {
        const builtin = @import("builtin");
        if (builtin.target.os.tag != .linux) {
            return;
        }

        const env = jni_env orelse return;

        // Get Vibrator service
        const context_obj: jni.jobject = @ptrCast(@alignCast(context));
        const context_class = jni.GetObjectClass(env, context_obj);

        const get_system_service_method = getJNIMethod(env, context_class, "getSystemService", "(Ljava/lang/String;)Ljava/lang/Object;") catch return;

        // Get VIBRATOR_SERVICE constant
        const vibrator_service_str = jni.NewStringUTF(env, "vibrator");
        const vibrator_obj = jni.CallObjectMethod(env, context_obj, get_system_service_method, vibrator_service_str);

        if (vibrator_obj != null) {
            const vibrator_class = jni.GetObjectClass(env, vibrator_obj);

            // For Android 26+, use VibrationEffect
            const vibrate_method = getJNIMethod(env, vibrator_class, "vibrate", "(J)V") catch return;
            jni.CallVoidMethod(env, vibrator_obj, vibrate_method, @as(jni.jlong, @intCast(duration_ms)));
        }
    }

    /// Toast Notification
    pub fn showToast(context: *Context, message: []const u8, duration: ToastDuration) void {
        const builtin = @import("builtin");
        if (builtin.target.os.tag != .linux) {
            return;
        }

        const env = jni_env orelse return;

        // Get Toast class
        const toast_class = getJNIClass(env, "android/widget/Toast") catch return;

        // Get makeText method
        const make_text_method = getJNIMethod(
            env,
            toast_class,
            "makeText",
            "(Landroid/content/Context;Ljava/lang/CharSequence;I)Landroid/widget/Toast;",
        ) catch return;

        // Convert message to Java string
        const message_jstring = jni.NewStringUTF(env, @ptrCast(message.ptr));

        // Convert duration
        const duration_int: jni.jint = switch (duration) {
            .short => 0, // Toast.LENGTH_SHORT
            .long => 1, // Toast.LENGTH_LONG
        };

        // Create toast
        const context_obj: jni.jobject = @ptrCast(@alignCast(context));
        const toast_obj = jni.CallObjectMethod(env, context_obj, make_text_method, context_obj, message_jstring, duration_int);

        if (toast_obj != null) {
            // Show toast
            const toast_obj_class = jni.GetObjectClass(env, toast_obj);
            const show_method = getJNIMethod(env, toast_obj_class, "show", "()V") catch return;
            jni.CallVoidMethod(env, toast_obj, show_method);
        }
    }

    pub const ToastDuration = enum {
        short,
        long,
    };
};

/// Cross-Platform Mobile Window
pub const MobileWindow = struct {
    platform: Platform,
    handle: *anyopaque,
    config: MobileConfig,
    allocator: std.mem.Allocator,

    pub const MobileConfig = struct {
        title: []const u8,
        initial_url: []const u8,
        user_agent: ?[]const u8 = null,
        enable_inspector: bool = false,
        orientation_lock: ?Orientation = null,
        safe_area_insets: bool = true,

        pub const Orientation = enum {
            portrait,
            landscape,
            any,
        };
    };

    pub fn init(allocator: std.mem.Allocator, config: MobileConfig) !MobileWindow {
        const platform = Platform.current();

        return MobileWindow{
            .platform = platform,
            .handle = undefined,
            .config = config,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MobileWindow) void {
        _ = self;
        // Platform-specific cleanup
    }

    pub fn loadURL(self: *MobileWindow, url: []const u8) !void {
        switch (self.platform) {
            .ios => {
                const webview: *iOS.WKWebView = @ptrCast(@alignCast(self.handle));
                try iOS.loadURL(webview, url);
            },
            .android => {
                const webview: *Android.WebView = @ptrCast(@alignCast(self.handle));
                try Android.loadURL(webview, url);
            },
            .unknown => return error.UnsupportedPlatform,
        }
    }

    pub fn evaluateJavaScript(self: *MobileWindow, script: []const u8) !void {
        switch (self.platform) {
            .ios => {
                const webview: *iOS.WKWebView = @ptrCast(@alignCast(self.handle));
                try iOS.evaluateJavaScript(webview, script, null);
            },
            .android => {
                const webview: *Android.WebView = @ptrCast(@alignCast(self.handle));
                try Android.evaluateJavaScript(webview, script, null);
            },
            .unknown => return error.UnsupportedPlatform,
        }
    }

    pub fn setOrientation(self: *MobileWindow, orientation: MobileConfig.Orientation) !void {
        _ = self;
        _ = orientation;
        // Platform-specific orientation lock
    }

    pub fn vibrate(self: *MobileWindow, duration_ms: u64) void {
        _ = self;
        _ = duration_ms;
        // Platform-specific vibration
    }

    pub fn showToast(self: *MobileWindow, message: []const u8) void {
        _ = self;
        _ = message;
        // Platform-specific toast
    }
};

/// Mobile Device Information
pub const DeviceInfo = struct {
    platform: Platform,
    os_version: []const u8,
    device_model: []const u8,
    screen_width: u32,
    screen_height: u32,
    scale_factor: f32,
    is_tablet: bool,
    safe_area_insets: SafeAreaInsets,

    pub const SafeAreaInsets = struct {
        top: f32,
        bottom: f32,
        left: f32,
        right: f32,
    };

    pub fn get(allocator: std.mem.Allocator) !DeviceInfo {
        _ = allocator;
        // Would query device info from platform APIs
        return DeviceInfo{
            .platform = Platform.current(),
            .os_version = "0.0.0",
            .device_model = "Unknown",
            .screen_width = 375,
            .screen_height = 667,
            .scale_factor = 2.0,
            .is_tablet = false,
            .safe_area_insets = .{
                .top = 0,
                .bottom = 0,
                .left = 0,
                .right = 0,
            },
        };
    }
};

/// Mobile Lifecycle Events
pub const LifecycleEvent = enum {
    did_finish_launching,
    will_enter_foreground,
    did_become_active,
    will_resign_active,
    did_enter_background,
    will_terminate,
    memory_warning,
};

pub const LifecycleCallback = *const fn (LifecycleEvent) void;

pub const LifecycleManager = struct {
    callbacks: std.ArrayList(LifecycleCallback),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) LifecycleManager {
        return LifecycleManager{
            .callbacks = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LifecycleManager) void {
        self.callbacks.deinit(self.allocator);
    }

    pub fn addCallback(self: *LifecycleManager, callback: LifecycleCallback) !void {
        try self.callbacks.append(self.allocator, callback);
    }

    pub fn triggerEvent(self: *LifecycleManager, event: LifecycleEvent) void {
        for (self.callbacks.items) |callback| {
            callback(event);
        }
    }
};

/// Mobile Storage
pub const Storage = struct {
    platform: Platform,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Storage {
        return Storage{
            .platform = Platform.current(),
            .allocator = allocator,
        };
    }

    pub fn getDocumentsDirectory(self: Storage) ![]const u8 {
        _ = self;
        // Platform-specific documents directory path
        return "";
    }

    pub fn getCacheDirectory(self: Storage) ![]const u8 {
        _ = self;
        // Platform-specific cache directory path
        return "";
    }

    pub fn getTemporaryDirectory(self: Storage) ![]const u8 {
        _ = self;
        // Platform-specific temp directory path
        return "";
    }
};

/// Mobile Networking
pub const NetworkStatus = enum {
    unknown,
    not_reachable,
    reachable_via_wifi,
    reachable_via_cellular,
};

pub const NetworkMonitor = struct {
    status: NetworkStatus,
    callbacks: std.ArrayList(*const fn (NetworkStatus) void),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) NetworkMonitor {
        return NetworkMonitor{
            .status = .unknown,
            .callbacks = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *NetworkMonitor) void {
        self.callbacks.deinit(self.allocator);
    }

    pub fn startMonitoring(self: *NetworkMonitor) !void {
        _ = self;
        // Start platform-specific network monitoring
    }

    pub fn stopMonitoring(self: *NetworkMonitor) void {
        _ = self;
        // Stop network monitoring
    }

    pub fn onStatusChange(self: *NetworkMonitor, callback: *const fn (NetworkStatus) void) !void {
        try self.callbacks.append(self.allocator, callback);
    }

    pub fn getCurrentStatus(self: NetworkMonitor) NetworkStatus {
        return self.status;
    }
};
