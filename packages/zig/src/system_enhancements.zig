const std = @import("std");
const builtin = @import("builtin");

/// System-level enhancements for Zyte framework
/// Includes: keyboard shortcuts, system events, dock features, etc.

// ============================================================================
// 1. Dock Features (macOS)
// ============================================================================

const objc = if (builtin.os.tag == .macos) @cImport({
    @cInclude("objc/message.h");
    @cInclude("objc/runtime.h");
}) else struct {};

pub const DockFeatures = struct {
    /// Set dock badge (notification count)
    pub fn setBadge(text: []const u8) !void {
        if (builtin.os.tag != .macos) return;

        const NSApp = objc.objc_getClass("NSApplication");
        const app = msgSend0(NSApp, "sharedApplication");
        const dockTile = msgSend0(app, "dockTile");

        const NSString = objc.objc_getClass("NSString");
        const badgeStr = msgSend1(NSString, "stringWithUTF8String:", text.ptr);
        _ = msgSend1(dockTile, "setBadgeLabel:", badgeStr);
    }

    /// Clear dock badge
    pub fn clearBadge() !void {
        if (builtin.os.tag != .macos) return;

        const NSApp = objc.objc_getClass("NSApplication");
        const app = msgSend0(NSApp, "sharedApplication");
        const dockTile = msgSend0(app, "dockTile");

        const NSString = objc.objc_getClass("NSString");
        const emptyStr = msgSend1(NSString, "string");
        _ = msgSend1(dockTile, "setBadgeLabel:", emptyStr);
    }

    /// Set dock progress (0.0 to 1.0)
    pub fn setProgress(progress: f64) !void {
        if (builtin.os.tag != .macos) return;
        _ = progress; // TODO: Implement progress indicator
    }

    /// Bounce dock icon to get attention
    pub fn bounce(critical: bool) !void {
        if (builtin.os.tag != .macos) return;

        const NSApp = objc.objc_getClass("NSApplication");
        const app = msgSend0(NSApp, "sharedApplication");

        const requestType: c_long = if (critical) 0 else 1; // 0 = Critical, 1 = Informational
        _ = msgSend1(app, "requestUserAttention:", requestType);
    }
};

// ============================================================================
// 2. Window Positioning Helpers
// ============================================================================

pub const WindowPosition = struct {
    pub fn center(window: *anyopaque) !void {
        if (builtin.os.tag != .macos) return;

        const nsWindow: objc.id = @ptrFromInt(@intFromPtr(window));
        msgSendVoid0(nsWindow, "center");
    }

    pub fn positionNearTray(window: *anyopaque, statusItem: *anyopaque) !void {
        if (builtin.os.tag != .macos) return;

        const nsWindow: objc.id = @ptrFromInt(@intFromPtr(window));
        const nsStatusItem: objc.id = @ptrFromInt(@intFromPtr(statusItem));

        // Get status item button
        const button = msgSend0(nsStatusItem, "button");
        const buttonWindow = msgSend0(button, "window");

        // Get button frame
        const buttonFrame = msgSendFrame(buttonWindow, "frame");

        // Position window below button
        const windowFrame = msgSendFrame(nsWindow, "frame");

        const NSMakeRect = @import("std").mem.zeroInit(NSRect, .{});
        _ = NSMakeRect;

        const newX = buttonFrame.origin.x;
        const newY = buttonFrame.origin.y - windowFrame.size.height - 5; // 5px gap

        const origin = NSPoint{ .x = newX, .y = newY };
        msgSendVoid1(nsWindow, "setFrameTopLeftPoint:", origin);
    }
};

// ============================================================================
// 3. Window Vibrancy Effects (macOS)
// ============================================================================

pub const VibrancyEffect = enum {
    light,
    dark,
    titlebar,
    selection,
    menu,
    popover,
    sidebar,
    header_view,
    sheet,
    window_background,
    hud_window,
    fullscreen_ui,
    tooltip,
    content_background,
    under_window_background,
    under_page_background,
};

pub const WindowVibrancy = struct {
    /// Set window vibrancy effect (macOS translucent background)
    pub fn setVibrancy(window: *anyopaque, effect: VibrancyEffect) !void {
        if (builtin.os.tag != .macos) return error.PlatformNotSupported;

        const nsWindow: objc.id = @ptrFromInt(@intFromPtr(window));

        // Create NSVisualEffectView
        const NSVisualEffectView = objc.objc_getClass("NSVisualEffectView");
        const effectView = msgSend0(msgSend0(NSVisualEffectView, "alloc"), "init");

        // Set material based on effect type
        const material: c_long = switch (effect) {
            .light => 1, // NSVisualEffectMaterialLight
            .dark => 2, // NSVisualEffectMaterialDark
            .titlebar => 3, // NSVisualEffectMaterialTitlebar
            .selection => 4, // NSVisualEffectMaterialSelection
            .menu => 5, // NSVisualEffectMaterialMenu
            .popover => 6, // NSVisualEffectMaterialPopover
            .sidebar => 7, // NSVisualEffectMaterialSidebar
            .header_view => 10, // NSVisualEffectMaterialHeaderView
            .sheet => 11, // NSVisualEffectMaterialSheet
            .window_background => 12, // NSVisualEffectMaterialWindowBackground
            .hud_window => 13, // NSVisualEffectMaterialHUDWindow
            .fullscreen_ui => 14, // NSVisualEffectMaterialFullScreenUI
            .tooltip => 15, // NSVisualEffectMaterialToolTip
            .content_background => 16, // NSVisualEffectMaterialContentBackground
            .under_window_background => 17, // NSVisualEffectMaterialUnderWindowBackground
            .under_page_background => 18, // NSVisualEffectMaterialUnderPageBackground
        };

        _ = msgSend1(effectView, "setMaterial:", material);

        // Set blending mode
        const NSVisualEffectBlendingModeBehindWindow: c_long = 0;
        _ = msgSend1(effectView, "setBlendingMode:", NSVisualEffectBlendingModeBehindWindow);

        // Set state to active
        const NSVisualEffectStateActive: c_long = 1;
        _ = msgSend1(effectView, "setState:", NSVisualEffectStateActive);

        // Get window content view
        const contentView = msgSend0(nsWindow, "contentView");

        // Get content view bounds
        const bounds = msgSendFrame(contentView, "bounds");

        // Set effect view frame to match content view
        msgSendVoid1(effectView, "setFrame:", bounds);

        // Set autoresizing mask to follow window
        const NSViewWidthSizable: c_ulong = 2;
        const NSViewHeightSizable: c_ulong = 16;
        _ = msgSend1(effectView, "setAutoresizingMask:", NSViewWidthSizable | NSViewHeightSizable);

        // Add effect view as subview
        msgSendVoid1(contentView, "addSubview:positioned:relativeTo:", effectView);

        // Make window background transparent
        msgSendVoid1(nsWindow, "setOpaque:", @as(c_int, 0));
        const NSColor = objc.objc_getClass("NSColor");
        const clearColor = msgSend0(NSColor, "clearColor");
        _ = msgSend1(nsWindow, "setBackgroundColor:", clearColor);
    }

    /// Remove vibrancy effect
    pub fn removeVibrancy(window: *anyopaque) !void {
        if (builtin.os.tag != .macos) return error.PlatformNotSupported;

        const nsWindow: objc.id = @ptrFromInt(@intFromPtr(window));

        // Reset window to opaque
        msgSendVoid1(nsWindow, "setOpaque:", @as(c_int, 1));

        // Get content view and remove effect views
        const contentView = msgSend0(nsWindow, "contentView");
        const subviews = msgSend0(contentView, "subviews");
        const count = msgSend0(subviews, "count");

        var i: usize = 0;
        while (i < @as(usize, @intCast(count))) : (i += 1) {
            const subview = msgSend1(subviews, "objectAtIndex:", i);
            const className = msgSend0(msgSend0(subview, "class"), "description");
            const classNameStr = msgSend0(className, "UTF8String");

            // Check if it's an NSVisualEffectView
            if (std.mem.indexOf(u8, std.mem.span(@as([*:0]const u8, @ptrCast(classNameStr))), "NSVisualEffectView") != null) {
                msgSendVoid0(subview, "removeFromSuperview");
            }
        }
    }
};

// ============================================================================
// 4. System Event Listeners
// ============================================================================

pub const SystemEvents = struct {
    sleep_callback: ?*const fn () void = null,
    wake_callback: ?*const fn () void = null,
    screen_lock_callback: ?*const fn () void = null,

    pub fn init() SystemEvents {
        return .{};
    }

    pub fn onSleep(self: *SystemEvents, callback: *const fn () void) void {
        self.sleep_callback = callback;
        if (builtin.os.tag == .macos) {
            macOSRegisterSleepWake(self);
        }
    }

    pub fn onWake(self: *SystemEvents, callback: *const fn () void) void {
        self.wake_callback = callback;
    }

    pub fn onScreenLock(self: *SystemEvents, callback: *const fn () void) void {
        self.screen_lock_callback = callback;
    }

    fn macOSRegisterSleepWake(self: *SystemEvents) void {
        _ = self;
        // TODO: Register for NSWorkspaceWillSleepNotification
        // and NSWorkspaceDidWakeNotification
    }
};

// ============================================================================
// 4. Global Keyboard Shortcuts (macOS Carbon)
// ============================================================================

pub const HotkeyManager = struct {
    hotkeys: std.ArrayList(Hotkey),
    allocator: std.mem.Allocator,

    pub const Hotkey = struct {
        id: u32,
        key_code: u32,
        modifiers: u32,
        callback: *const fn () void,
    };

    pub fn init(allocator: std.mem.Allocator) HotkeyManager {
        return .{
            .hotkeys = std.ArrayList(Hotkey).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *HotkeyManager) void {
        // Unregister all hotkeys
        for (self.hotkeys.items) |hotkey| {
            _ = hotkey;
            // TODO: UnregisterEventHotKey on macOS
        }
        self.hotkeys.deinit();
    }

    /// Register a global hotkey
    /// key_code: Virtual key code (e.g., 35 for 'P')
    /// modifiers: cmdKey (256), shiftKey (512), optionKey (2048), controlKey (4096)
    pub fn register(self: *HotkeyManager, key_code: u32, modifiers: u32, callback: *const fn () void) !void {
        const id = @as(u32, @intCast(self.hotkeys.items.len + 1));

        try self.hotkeys.append(.{
            .id = id,
            .key_code = key_code,
            .modifiers = modifiers,
            .callback = callback,
        });

        if (builtin.os.tag == .macos) {
            // TODO: RegisterEventHotKey using Carbon
            // For now, just store the hotkey
        }
    }

    /// Parse shortcut string like "Cmd+Shift+P" to key code and modifiers
    pub fn parseShortcut(shortcut: []const u8) struct { key_code: u32, modifiers: u32 } {
        var modifiers: u32 = 0;
        var key_code: u32 = 0;

        // Simple parser (could be enhanced)
        if (std.mem.indexOf(u8, shortcut, "Cmd") != null) modifiers |= 256;
        if (std.mem.indexOf(u8, shortcut, "Shift") != null) modifiers |= 512;
        if (std.mem.indexOf(u8, shortcut, "Option") != null or std.mem.indexOf(u8, shortcut, "Alt") != null) modifiers |= 2048;
        if (std.mem.indexOf(u8, shortcut, "Ctrl") != null or std.mem.indexOf(u8, shortcut, "Control") != null) modifiers |= 4096;

        // Extract last character as key
        if (shortcut.len > 0) {
            const last_char = shortcut[shortcut.len - 1];
            key_code = @as(u32, last_char);
        }

        return .{ .key_code = key_code, .modifiers = modifiers };
    }
};

// ============================================================================
// 5. Local Storage Helper
// ============================================================================

pub const LocalStorage = struct {
    file_path: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, app_name: []const u8) !LocalStorage {
        // Create path: ~/Library/Application Support/<app_name>/storage.json (macOS)
        const home = std.posix.getenv("HOME") orelse return error.NoHomeDir;

        const path = try std.fmt.allocPrint(
            allocator,
            "{s}/Library/Application Support/{s}/storage.json",
            .{ home, app_name },
        );

        // Ensure directory exists
        const dir_path = std.fs.path.dirname(path) orelse return error.InvalidPath;
        try std.fs.cwd().makePath(dir_path);

        return .{
            .file_path = path,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LocalStorage) void {
        self.allocator.free(self.file_path);
    }

    pub fn set(self: *LocalStorage, key: []const u8, value: []const u8) !void {
        // Load existing data
        var data = try self.loadAll();
        defer self.allocator.free(data);

        // TODO: Parse JSON, update key, write back
        _ = key;
        _ = value;
    }

    pub fn get(self: *LocalStorage, key: []const u8) !?[]const u8 {
        _ = key;
        // TODO: Load and parse JSON, return value for key
        return null;
    }

    fn loadAll(self: *LocalStorage) ![]const u8 {
        const file = std.fs.cwd().openFile(self.file_path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                return try self.allocator.dupe(u8, "{}");
            }
            return err;
        };
        defer file.close();

        return try file.readToEndAlloc(self.allocator, 1024 * 1024); // Max 1MB
    }
};

// ============================================================================
// 6. Performance Monitoring
// ============================================================================

pub const PerformanceMonitor = struct {
    start_time: i64,
    allocator: std.mem.Allocator,

    pub const Stats = struct {
        memory_used: u64,
        memory_total: u64,
        cpu_percent: f64,
        uptime_seconds: i64,
    };

    pub fn init(allocator: std.mem.Allocator) PerformanceMonitor {
        return .{
            .start_time = std.time.timestamp(),
            .allocator = allocator,
        };
    }

    pub fn getStats(self: *PerformanceMonitor) !Stats {
        const uptime = std.time.timestamp() - self.start_time;

        // Get memory info
        var memory_used: u64 = 0;
        var memory_total: u64 = 0;

        if (builtin.os.tag == .macos) {
            // TODO: Use task_info() to get memory usage
            memory_used = 45_000_000; // Placeholder
            memory_total = 64_000_000;
        }

        return .{
            .memory_used = memory_used,
            .memory_total = memory_total,
            .cpu_percent = 0.0, // TODO: Calculate CPU usage
            .uptime_seconds = uptime,
        };
    }
};

// ============================================================================
// Helper functions for Objective-C messaging
// ============================================================================

fn msgSend0(target: anytype, selector: [*:0]const u8) objc.id {
    if (builtin.os.tag != .macos) unreachable;
    const msg = @as(*const fn (@TypeOf(target), objc.SEL) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    return msg(target, objc.sel_registerName(selector));
}

fn msgSend1(target: anytype, selector: [*:0]const u8, arg1: anytype) objc.id {
    if (builtin.os.tag != .macos) unreachable;
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, @TypeOf(arg1)) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    return msg(target, objc.sel_registerName(selector), arg1);
}

fn msgSendVoid0(target: anytype, selector: [*:0]const u8) void {
    if (builtin.os.tag != .macos) unreachable;
    const msg = @as(*const fn (@TypeOf(target), objc.SEL) callconv(.c) void, @ptrCast(&objc.objc_msgSend));
    msg(target, objc.sel_registerName(selector));
}

fn msgSendVoid1(target: anytype, selector: [*:0]const u8, arg1: anytype) void {
    if (builtin.os.tag != .macos) unreachable;
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, @TypeOf(arg1)) callconv(.c) void, @ptrCast(&objc.objc_msgSend));
    msg(target, objc.sel_registerName(selector), arg1);
}

fn msgSendFrame(target: anytype, selector: [*:0]const u8) NSRect {
    if (builtin.os.tag != .macos) unreachable;
    const msg = @as(*const fn (@TypeOf(target), objc.SEL) callconv(.c) NSRect, @ptrCast(&objc.objc_msgSend));
    return msg(target, objc.sel_registerName(selector));
}

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
