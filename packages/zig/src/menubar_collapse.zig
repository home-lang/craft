const std = @import("std");
const builtin = @import("builtin");
const logging = @import("logging.zig");

const log = logging.menu;

/// Menu Bar Collapse/Hide System — with optional always-hidden section
///
///   Two permanent items + optional always-hidden separator:
///
///   1. btnExpandCollapse (rightmost, created in earlyInit): ‹/› — toggle button, ALWAYS visible
///   2. tray icon (created by tray.zig):                     ☕️ — the app's icon, ALWAYS visible
///   3. btnSeparate (created in init, after tray):           ·  — the width-changer, to LEFT of tray
///   4. btnAlwaysHidden (optional):                          ·  — always-hidden separator
///
///   On collapse:
///     btnSeparate.length = COLLAPSE_WIDTH — pushes everything to its LEFT off-screen
///     btnExpandCollapse shows › (it stays visible because it's to the RIGHT of separator)
///     ☕️ also stays visible (to the RIGHT of separator)
///
///   On expand:
///     btnSeparate.length = SEPARATOR_LENGTH (normal)
///     btnExpandCollapse shows ‹
///     If always-hidden enabled, btnAlwaysHidden stays expanded
///
///   Normal:            [always-hidden items] [·] [sometimes-hidden items] [·] [☕️] [‹]
///   Collapsed:                               [· expanded ............... ] [☕️] [›]
///   Expanded (always): [· expanded .........] [sometimes-hidden items] [·] [☕️] [‹]

// ============================================================================
// Objective-C runtime
// ============================================================================

const objc = if (builtin.target.os.tag == .macos) struct {
    pub const id = ?*anyopaque;
    pub const Class = ?*anyopaque;
    pub const SEL = ?*anyopaque;
    pub const IMP = ?*anyopaque;
    pub const BOOL = bool;

    pub extern "objc" fn objc_getClass(name: [*:0]const u8) Class;
    pub extern "objc" fn sel_registerName(name: [*:0]const u8) SEL;
    pub extern "objc" fn objc_msgSend() void;
    pub extern "objc" fn objc_allocateClassPair(superclass: Class, name: [*:0]const u8, extraBytes: usize) Class;
    pub extern "objc" fn objc_registerClassPair(cls: Class) void;
    pub extern "objc" fn class_addMethod(cls: Class, name: SEL, imp: IMP, types: [*:0]const u8) BOOL;
} else struct {
    pub const id = *anyopaque;
    pub const Class = *anyopaque;
    pub const SEL = *anyopaque;
};

// ============================================================================
// ObjC message sending helpers
// ============================================================================

fn getClass(name: [*:0]const u8) objc.id {
    if (builtin.target.os.tag != .macos) unreachable;
    return @ptrCast(@alignCast(objc.objc_getClass(name)));
}

fn msgSend0(target: anytype, sel: [*:0]const u8) objc.id {
    if (builtin.target.os.tag != .macos) unreachable;
    const f = @as(*const fn (@TypeOf(target), objc.SEL) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    return f(target, objc.sel_registerName(sel));
}

fn msgSend1(target: anytype, sel: [*:0]const u8, a1: anytype) objc.id {
    if (builtin.target.os.tag != .macos) unreachable;
    const f = @as(*const fn (@TypeOf(target), objc.SEL, @TypeOf(a1)) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    return f(target, objc.sel_registerName(sel), a1);
}

fn msgSendVoid1(target: anytype, sel: [*:0]const u8, a1: anytype) void {
    if (builtin.target.os.tag != .macos) unreachable;
    const f = @as(*const fn (@TypeOf(target), objc.SEL, @TypeOf(a1)) callconv(.c) void, @ptrCast(&objc.objc_msgSend));
    f(target, objc.sel_registerName(sel), a1);
}

fn msgSendVoid2(target: anytype, sel: [*:0]const u8, a1: anytype, a2: anytype) void {
    if (builtin.target.os.tag != .macos) unreachable;
    const f = @as(*const fn (@TypeOf(target), objc.SEL, @TypeOf(a1), @TypeOf(a2)) callconv(.c) void, @ptrCast(&objc.objc_msgSend));
    f(target, objc.sel_registerName(sel), a1, a2);
}

fn msgSendVoid3(target: anytype, sel: [*:0]const u8, a1: anytype, a2: anytype, a3: anytype) void {
    if (builtin.target.os.tag != .macos) unreachable;
    const f = @as(*const fn (@TypeOf(target), objc.SEL, @TypeOf(a1), @TypeOf(a2), @TypeOf(a3)) callconv(.c) void, @ptrCast(&objc.objc_msgSend));
    f(target, objc.sel_registerName(sel), a1, a2, a3);
}

fn msgSendUsize(target: anytype, sel: [*:0]const u8) usize {
    if (builtin.target.os.tag != .macos) unreachable;
    const f = @as(*const fn (@TypeOf(target), objc.SEL) callconv(.c) usize, @ptrCast(&objc.objc_msgSend));
    return f(target, objc.sel_registerName(sel));
}

fn createNSString(str: []const u8) objc.id {
    const NSString = getClass("NSString");
    const alloc = msgSend0(NSString, "alloc");
    const allocator = std.heap.c_allocator;
    const z = allocator.dupeZ(u8, str) catch return null;
    defer allocator.free(z);
    return msgSend1(alloc, "initWithUTF8String:", z.ptr);
}

fn getSystemStatusBar() objc.id {
    return msgSend0(getClass("NSStatusBar"), "systemStatusBar");
}

// ============================================================================
// Global State
// ============================================================================

var early_initialized: bool = false;
var is_initialized: bool = false;
var is_collapsed: bool = false;

// The toggle button (rightmost) — shows ‹ or ›, ALWAYS visible, never changes width
// Matches Hidden's btnExpandCollapse
var expand_collapse_btn: objc.id = if (builtin.target.os.tag == .macos) null else null;

// The separator (created after tray, to LEFT of tray icon) — THIS expands to hide items
// Matches Hidden's btnSeparate
var separator_item: objc.id = if (builtin.target.os.tag == .macos) null else null;
var separator_constraint: objc.id = if (builtin.target.os.tag == .macos) null else null;

var saved_tray_menu: objc.id = if (builtin.target.os.tag == .macos) null else null;
var click_target: objc.id = if (builtin.target.os.tag == .macos) null else null;
var class_registered: bool = false;

// Always-hidden section — matches Hidden's btnAlwaysHidden
var always_hidden_item: objc.id = if (builtin.target.os.tag == .macos) null else null;
var always_hidden_constraint: objc.id = if (builtin.target.os.tag == .macos) null else null;
var always_hidden_enabled: bool = false;
var always_hidden_active: bool = false;

var separator_hidden: bool = false;

var auto_collapse_delay: u32 = 0;
var auto_collapse_timer_active: bool = false;
var last_expand_ns: ?u64 = null;

// Debounce: matches Hidden's isToggle with 0.3s cooldown
var toggle_debounce_active: bool = false;
var toggle_debounce_ns: ?u64 = null;
const DEBOUNCE_INTERVAL_NS: u64 = 300_000_000;

const LENGTH_VARIABLE: f64 = -1.0;
const SEPARATOR_LENGTH: f64 = 20.0; // matches Hidden's btnHiddenLength
const COLLAPSE_WIDTH: f64 = 10_000.0;

const CHEVRON_COLLAPSE = "\xE2\x80\xB9"; // ‹
const CHEVRON_EXPAND = "\xE2\x80\xBA"; // ›
const SEPARATOR_DOT = "\xC2\xB7"; // ·

// ============================================================================
// Public API
// ============================================================================

/// Called from tray.zig BEFORE the tray item is created.
/// Creates the expand/collapse toggle button (rightmost, always visible).
pub fn earlyInit() void {
    if (builtin.target.os.tag != .macos) return;
    if (early_initialized) return;

    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] earlyInit — creating toggle button (rightmost)...\n", .{});

    if (!class_registered) {
        const NSObject = getClass("NSObject");
        const className: [*:0]const u8 = "CraftMenubarCollapseTarget";
        var targetClass = objc.objc_getClass(className);

        if (targetClass == null) {
            targetClass = objc.objc_allocateClassPair(
                @ptrCast(@alignCast(NSObject)),
                className,
                0,
            );
            _ = objc.class_addMethod(
                @ptrCast(@alignCast(targetClass)),
                objc.sel_registerName("toggleClicked:"),
                @ptrCast(@constCast(&toggleClicked)),
                "v@:@",
            );
            objc.objc_registerClassPair(@ptrCast(@alignCast(targetClass)));
        }

        const cls_id: objc.id = @ptrCast(@alignCast(targetClass));
        click_target = msgSend0(msgSend0(cls_id, "alloc"), "init");
        _ = msgSend0(click_target, "retain");
        class_registered = true;
    }

    // Create the toggle button (rightmost, NEVER changes width)
    expand_collapse_btn = msgSend1(getSystemStatusBar(), "statusItemWithLength:", LENGTH_VARIABLE);
    _ = msgSend0(expand_collapse_btn, "retain");
    msgSendVoid1(expand_collapse_btn, "setAutosaveName:", createNSString("barista_expandcollapse"));

    const btn = msgSend0(expand_collapse_btn, "button");
    if (btn != null) {
        msgSendVoid1(btn, "setTitle:", createNSString(CHEVRON_COLLAPSE));
        msgSendVoid1(btn, "setTarget:", click_target);
        msgSendVoid1(btn, "setAction:", objc.sel_registerName("toggleClicked:"));
    }

    early_initialized = true;

    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] earlyInit done — toggle button created\n", .{});
}

/// Called after tray is created. Creates the separator (the width-changer).
pub fn init() void {
    if (builtin.target.os.tag != .macos) return;
    if (is_initialized) return;
    if (!early_initialized) earlyInit();

    const macos = @import("macos.zig");
    if (macos.getGlobalTrayHandle()) |tray_handle| {
        const statusItem: objc.id = @ptrFromInt(@intFromPtr(tray_handle));
        const menu = msgSend0(statusItem, "menu");
        if (menu != null) {
            saved_tray_menu = menu;
            _ = msgSend0(saved_tray_menu, "retain");
        }
    }

    // Create the separator (to LEFT of tray icon — THIS does the width expansion)
    separator_item = msgSend1(getSystemStatusBar(), "statusItemWithLength:", SEPARATOR_LENGTH);
    _ = msgSend0(separator_item, "retain");
    msgSendVoid1(separator_item, "setAutosaveName:", createNSString("barista_separate"));

    const sep_btn = msgSend0(separator_item, "button");
    if (sep_btn != null) {
        if (separator_hidden) {
            msgSendVoid1(sep_btn, "setTitle:", createNSString(""));
        } else {
            msgSendVoid1(sep_btn, "setTitle:", createNSString(SEPARATOR_DOT));
        }
        msgSendVoid1(sep_btn, "setTarget:", click_target);
        msgSendVoid1(sep_btn, "setAction:", objc.sel_registerName("toggleClicked:"));
    }

    // Right-click on separator shows context menu (like Hidden)
    if (saved_tray_menu != null) {
        msgSendVoid1(separator_item, "setMenu:", saved_tray_menu);
    }

    findConstraintForItem(separator_item, &separator_constraint);

    is_initialized = true;
    is_collapsed = false;

    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] Ready — separator created (constraint={s})\n", .{if (separator_constraint != null) "found" else "NOT found"});
}

pub fn collapse() void {
    if (builtin.target.os.tag != .macos) return;
    if (!is_initialized) {
        init();
        if (!is_initialized) return;
    }
    if (is_collapsed) return;
    if (separator_item == null) return;

    // Expand separator to push everything to its LEFT off-screen.
    // Toggle button + tray icon (to the RIGHT) stay visible.
    msgSendVoid1(separator_item, "setLength:", COLLAPSE_WIDTH);
    if (separator_constraint != null) {
        msgSendVoid1(separator_constraint, "setActive:", @as(c_int, 1));
    }

    // Show › on the toggle button
    if (expand_collapse_btn != null) {
        const btn = msgSend0(expand_collapse_btn, "button");
        if (btn != null) {
            msgSendVoid1(btn, "setTitle:", createNSString(CHEVRON_EXPAND));
        }
    }

    is_collapsed = true;
    auto_collapse_timer_active = false;

    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] Collapsed — separator expanded, button shows ›\n", .{});
    notifyJS();
}

pub fn expand() void {
    if (builtin.target.os.tag != .macos) return;
    if (!is_initialized) {
        init();
        if (!is_initialized) return;
    }
    if (!is_collapsed) return;
    if (separator_item == null) return;

    // Shrink separator back to normal
    msgSendVoid1(separator_item, "setLength:", SEPARATOR_LENGTH);
    if (separator_constraint != null) {
        msgSendVoid1(separator_constraint, "setActive:", @as(c_int, 0));
    }

    // Keep always-hidden items off-screen
    if (always_hidden_enabled and always_hidden_item != null and !always_hidden_active) {
        activateAlwaysHidden();
    }

    // Show ‹ on the toggle button
    if (expand_collapse_btn != null) {
        const btn = msgSend0(expand_collapse_btn, "button");
        if (btn != null) {
            msgSendVoid1(btn, "setTitle:", createNSString(CHEVRON_COLLAPSE));
        }
    }

    // Restore separator text
    if (separator_item != null) {
        const sep_btn = msgSend0(separator_item, "button");
        if (sep_btn != null) {
            if (separator_hidden) {
                msgSendVoid1(sep_btn, "setTitle:", createNSString(""));
            } else {
                msgSendVoid1(sep_btn, "setTitle:", createNSString(SEPARATOR_DOT));
            }
        }
    }

    is_collapsed = false;
    last_expand_ns = nanoTimestamp();
    if (auto_collapse_delay > 0) {
        auto_collapse_timer_active = true;
    }

    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] Expanded — separator shrunk, button shows ‹\n", .{});
    notifyJS();
}

pub fn toggle() void {
    if (builtin.target.os.tag != .macos) return;
    if (!is_initialized) {
        init();
        if (!is_initialized) return;
    }
    if (is_collapsed) expand() else collapse();
}

pub fn cleanup() void {
    if (always_hidden_active) deactivateAlwaysHidden();
    always_hidden_enabled = false;
    if (is_collapsed) expand();
}

pub fn isCollapsed() bool {
    return is_collapsed;
}

pub fn isInitialized() bool {
    return is_initialized;
}

pub fn setAutoCollapse(delay_seconds: u32) void {
    auto_collapse_delay = delay_seconds;
    if (delay_seconds > 0 and !is_collapsed) {
        auto_collapse_timer_active = true;
        last_expand_ns = nanoTimestamp();
    } else {
        auto_collapse_timer_active = false;
    }
}

pub fn checkAutoCollapse() void {
    if (toggle_debounce_active) {
        if (toggle_debounce_ns) |start| {
            if (nanoTimestamp()) |now| {
                if (now - start >= DEBOUNCE_INTERVAL_NS) {
                    toggle_debounce_active = false;
                }
            }
        }
    }

    if (!auto_collapse_timer_active or auto_collapse_delay == 0 or is_collapsed) {
        if (is_collapsed) auto_collapse_timer_active = false;
        return;
    }
    const start = last_expand_ns orelse return;
    const now = nanoTimestamp() orelse return;
    const elapsed_ns = now - start;
    const delay_ns: u64 = @as(u64, auto_collapse_delay) * std.time.ns_per_s;
    if (elapsed_ns >= delay_ns) {
        collapse();
    }
}

// ============================================================================
// Always-Hidden Section
// ============================================================================

pub fn enableAlwaysHidden() void {
    if (builtin.target.os.tag != .macos) return;
    if (always_hidden_enabled) return;
    if (!is_initialized) {
        init();
        if (!is_initialized) return;
    }

    always_hidden_item = msgSend1(getSystemStatusBar(), "statusItemWithLength:", SEPARATOR_LENGTH);
    _ = msgSend0(always_hidden_item, "retain");
    msgSendVoid1(always_hidden_item, "setAutosaveName:", createNSString("barista_always_hidden"));

    const btn = msgSend0(always_hidden_item, "button");
    if (btn != null) {
        if (separator_hidden) {
            msgSendVoid1(btn, "setTitle:", createNSString(""));
        } else {
            msgSendVoid1(btn, "setTitle:", createNSString(SEPARATOR_DOT));
        }
        msgSendVoid1(btn, "setTarget:", click_target);
        msgSendVoid1(btn, "setAction:", objc.sel_registerName("toggleClicked:"));
    }

    findConstraintForItem(always_hidden_item, &always_hidden_constraint);
    always_hidden_enabled = true;

    if (!is_collapsed) {
        activateAlwaysHidden();
    }

    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] Always-hidden section enabled\n", .{});
    notifyJS();
}

pub fn disableAlwaysHidden() void {
    if (builtin.target.os.tag != .macos) return;
    if (!always_hidden_enabled) return;

    if (always_hidden_active) deactivateAlwaysHidden();

    if (always_hidden_item != null) {
        msgSendVoid1(getSystemStatusBar(), "removeStatusItem:", always_hidden_item);
        _ = msgSend0(always_hidden_item, "release");
        always_hidden_item = null;
    }
    if (always_hidden_constraint != null) {
        _ = msgSend0(always_hidden_constraint, "release");
        always_hidden_constraint = null;
    }

    always_hidden_enabled = false;

    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] Always-hidden section disabled\n", .{});
    notifyJS();
}

pub fn isAlwaysHiddenEnabled() bool {
    return always_hidden_enabled;
}

// ============================================================================
// Separator Visibility
// ============================================================================

pub fn setSeparatorHidden(hidden: bool) void {
    if (builtin.target.os.tag != .macos) return;
    separator_hidden = hidden;

    if (separator_item != null and !is_collapsed) {
        const sep_btn = msgSend0(separator_item, "button");
        if (sep_btn != null) {
            if (hidden) {
                msgSendVoid1(sep_btn, "setTitle:", createNSString(""));
            } else {
                msgSendVoid1(sep_btn, "setTitle:", createNSString(SEPARATOR_DOT));
            }
        }
    }

    if (always_hidden_item != null and always_hidden_enabled) {
        const ah_btn = msgSend0(always_hidden_item, "button");
        if (ah_btn != null) {
            if (hidden) {
                msgSendVoid1(ah_btn, "setTitle:", createNSString(""));
            } else {
                msgSendVoid1(ah_btn, "setTitle:", createNSString(SEPARATOR_DOT));
            }
        }
    }
}

pub fn isSeparatorHidden() bool {
    return separator_hidden;
}

// ============================================================================
// Internal helpers
// ============================================================================

fn activateAlwaysHidden() void {
    if (always_hidden_item == null) return;
    msgSendVoid1(always_hidden_item, "setLength:", COLLAPSE_WIDTH);
    if (always_hidden_constraint != null) {
        msgSendVoid1(always_hidden_constraint, "setActive:", @as(c_int, 1));
    }
    always_hidden_active = true;
}

fn deactivateAlwaysHidden() void {
    if (always_hidden_item == null) return;
    msgSendVoid1(always_hidden_item, "setLength:", SEPARATOR_LENGTH);
    if (always_hidden_constraint != null) {
        msgSendVoid1(always_hidden_constraint, "setActive:", @as(c_int, 0));
    }
    always_hidden_active = false;
}

fn nanoTimestamp() ?u64 {
    const c = @cImport(@cInclude("time.h"));
    var ts: c.struct_timespec = undefined;
    if (c.clock_gettime(c.CLOCK_MONOTONIC, &ts) != 0) return null;
    return @as(u64, @intCast(ts.tv_sec)) * 1_000_000_000 + @as(u64, @intCast(ts.tv_nsec));
}

fn findConstraintForItem(item: objc.id, out_constraint: *objc.id) void {
    if (item == null) return;

    const button = msgSend0(item, "button");
    if (button == null) return;

    const superview = msgSend0(button, "superview");
    const window = msgSend0(button, "window");
    if (window == null) return;

    const contentView = msgSend0(window, "contentView");
    if (contentView == null) return;

    const constraints = msgSend0(contentView, "constraints");
    if (constraints == null) return;

    const count: usize = @intFromPtr(msgSend0(constraints, "count"));

    var i: usize = 0;
    while (i < count) : (i += 1) {
        const constraint = msgSend1(constraints, "objectAtIndex:", i);
        const secondItem = msgSend0(constraint, "secondItem");
        if (secondItem == superview and superview != null) {
            out_constraint.* = constraint;
            _ = msgSend0(out_constraint.*, "retain");
            return;
        }
    }

    i = 0;
    while (i < count) : (i += 1) {
        const constraint = msgSend1(constraints, "objectAtIndex:", i);
        const firstItem = msgSend0(constraint, "firstItem");
        if (firstItem == superview and superview != null) {
            out_constraint.* = constraint;
            _ = msgSend0(out_constraint.*, "retain");
            return;
        }
    }
}

fn showTrayMenu(view: objc.id) void {
    if (saved_tray_menu == null) return;
    const NSApp = msgSend0(getClass("NSApplication"), "sharedApplication");
    const event = msgSend0(NSApp, "currentEvent");
    if (event == null) return;
    msgSendVoid3(getClass("NSMenu"), "popUpContextMenu:withEvent:forView:", saved_tray_menu, event, view);
}

fn notifyJS() void {
    const macos = @import("macos.zig");
    var buf: [320]u8 = undefined;
    const js = std.fmt.bufPrint(&buf, "window.dispatchEvent(new CustomEvent('craft:menubar:stateChange',{{detail:{{collapsed:{s},alwaysHiddenEnabled:{s},separatorHidden:{s}}}}}));", .{
        if (is_collapsed) "true" else "false",
        if (always_hidden_enabled) "true" else "false",
        if (separator_hidden) "true" else "false",
    }) catch return;
    macos.tryEvalJS(js) catch |err| {
        std.log.debug("JS eval failed for menubar collapse state callback: {}", .{err});
    };
}

fn toggleClicked(_: objc.id, _: objc.SEL, sender: objc.id) callconv(.c) void {
    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] Toggle clicked\n", .{});

    const NSApp = msgSend0(getClass("NSApplication"), "sharedApplication");
    const event = msgSend0(NSApp, "currentEvent");
    if (event != null) {
        const eventType = msgSendUsize(event, "type");
        if (eventType == 3 or eventType == 4) {
            if (sender != null) {
                showTrayMenu(sender);
            }
            return;
        }
    }

    // Debounce rapid clicks (matches Hidden's isToggle)
    if (toggle_debounce_active) {
        if (toggle_debounce_ns) |start| {
            if (nanoTimestamp()) |now| {
                if (now - start < DEBOUNCE_INTERVAL_NS) return;
            }
        }
    }
    toggle_debounce_active = true;
    toggle_debounce_ns = nanoTimestamp();

    toggle();
}
