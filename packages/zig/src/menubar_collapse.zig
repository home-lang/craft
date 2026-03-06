const std = @import("std");
const builtin = @import("builtin");
const logging = @import("logging.zig");

const log = logging.menu;

/// Menu Bar Collapse/Hide System — single visible chevron, dynamic expand indicator
///
///   Position 1 (rightmost, created in earlyInit): ‹ — the chevron/separator
///   Position 2 (created by tray.zig):             ☕️ — the app's tray icon (untouched)
///
///   On collapse:
///     1. The ‹ item expands to 10000px, pushing ☕️ and other items off-screen
///        (its button goes off-screen too — that's unavoidable)
///     2. A NEW temporary › item is created — it becomes the new rightmost item,
///        so it appears to the RIGHT of the expanded item and stays visible
///
///   On expand:
///     1. The temporary › item is removed
///     2. The original item shrinks back, ‹ reappears
///
///   Normal:    [other apps] [☕️] [‹]
///   Collapsed:                   [›]  (← temporary item, original ‹ is expanded behind it)

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

// The permanent ‹ item — expands to push items off-screen
var chevron_item: objc.id = if (builtin.target.os.tag == .macos) null else null;
var item_constraint: objc.id = if (builtin.target.os.tag == .macos) null else null;

// Temporary › item — created when collapsed, removed when expanded
var expand_indicator: objc.id = if (builtin.target.os.tag == .macos) null else null;

var saved_tray_menu: objc.id = if (builtin.target.os.tag == .macos) null else null;
var click_target: objc.id = if (builtin.target.os.tag == .macos) null else null;
var class_registered: bool = false;

var auto_collapse_delay: u32 = 0;
var auto_collapse_timer_active: bool = false;
var last_expand_ns: ?u64 = null;

const LENGTH_VARIABLE: f64 = -1.0;
const COLLAPSE_WIDTH: f64 = 10_000.0;

const CHEVRON_COLLAPSE = "\xE2\x80\xB9"; // ‹ (items visible, click to hide)
const CHEVRON_EXPAND = "\xE2\x80\xBA"; // › (items hidden, click to show)

// ============================================================================
// Public API
// ============================================================================

/// Called from tray.zig BEFORE the tray item is created.
pub fn earlyInit() void {
    if (builtin.target.os.tag != .macos) return;
    if (early_initialized) return;

    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] earlyInit — creating chevron (pos1)...\n", .{});

    // Register ObjC click handler class
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

    // === Create the chevron/separator item (position 1, rightmost) ===
    chevron_item = msgSend1(getSystemStatusBar(), "statusItemWithLength:", LENGTH_VARIABLE);
    _ = msgSend0(chevron_item, "retain");

    const btn = msgSend0(chevron_item, "button");
    if (btn != null) {
        msgSendVoid1(btn, "setTitle:", createNSString(CHEVRON_COLLAPSE)); // ‹
        msgSendVoid1(btn, "setTarget:", click_target);
        msgSendVoid1(btn, "setAction:", objc.sel_registerName("toggleClicked:"));
    }

    // Find and cache the width constraint for expansion
    findConstraintForItem(chevron_item);

    early_initialized = true;

    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] earlyInit done (constraint={s})\n", .{if (item_constraint != null) "found" else "NOT found"});
}

/// Called after tray is created.
pub fn init() void {
    if (builtin.target.os.tag != .macos) return;
    if (is_initialized) return;
    if (!early_initialized) earlyInit();

    // Save the tray's context menu for right-click on the chevron
    const macos = @import("macos.zig");
    if (macos.getGlobalTrayHandle()) |tray_handle| {
        const statusItem: objc.id = @ptrFromInt(@intFromPtr(tray_handle));
        const menu = msgSend0(statusItem, "menu");
        if (menu != null) {
            saved_tray_menu = menu;
            _ = msgSend0(saved_tray_menu, "retain");
        }
    }

    is_initialized = true;
    is_collapsed = false;

    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] Ready\n", .{});
}

pub fn collapse() void {
    if (builtin.target.os.tag != .macos) return;
    if (!is_initialized) {
        init();
        if (!is_initialized) return;
    }
    if (is_collapsed) return;
    if (chevron_item == null) return;

    // 1. Expand the ‹ item to 10000px — pushes everything to its LEFT off-screen
    //    (the ‹ button goes off-screen too, that's expected)
    msgSendVoid1(chevron_item, "setLength:", COLLAPSE_WIDTH);

    if (item_constraint != null) {
        msgSendVoid1(item_constraint, "setActive:", @as(c_int, 1));
    }

    // 2. Create a NEW temporary › item — it becomes the new rightmost item,
    //    appearing to the RIGHT of the expanded item, so it stays visible
    expand_indicator = msgSend1(getSystemStatusBar(), "statusItemWithLength:", LENGTH_VARIABLE);
    _ = msgSend0(expand_indicator, "retain");

    const ind_btn = msgSend0(expand_indicator, "button");
    if (ind_btn != null) {
        msgSendVoid1(ind_btn, "setTitle:", createNSString(CHEVRON_EXPAND)); // ›
        msgSendVoid1(ind_btn, "setTarget:", click_target);
        msgSendVoid1(ind_btn, "setAction:", objc.sel_registerName("toggleClicked:"));
    }

    is_collapsed = true;
    auto_collapse_timer_active = false;

    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] Collapsed — ‹ expanded, › indicator created\n", .{});
    notifyJS();
}

pub fn expand() void {
    if (builtin.target.os.tag != .macos) return;
    if (!is_initialized) {
        init();
        if (!is_initialized) return;
    }
    if (!is_collapsed) return;
    if (chevron_item == null) return;

    // 1. Remove the temporary › indicator
    if (expand_indicator != null) {
        msgSendVoid1(getSystemStatusBar(), "removeStatusItem:", expand_indicator);
        _ = msgSend0(expand_indicator, "release");
        expand_indicator = null;
    }

    // 2. Shrink the original ‹ item back
    msgSendVoid1(chevron_item, "setLength:", LENGTH_VARIABLE);

    if (item_constraint != null) {
        msgSendVoid1(item_constraint, "setActive:", @as(c_int, 0));
    }

    is_collapsed = false;

    last_expand_ns = nanoTimestamp();
    if (auto_collapse_delay > 0) {
        auto_collapse_timer_active = true;
    }

    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] Expanded — › indicator removed, ‹ restored\n", .{});
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

fn nanoTimestamp() ?u64 {
    const c = @cImport(@cInclude("time.h"));
    var ts: c.struct_timespec = undefined;
    if (c.clock_gettime(c.CLOCK_MONOTONIC, &ts) != 0) return null;
    return @as(u64, @intCast(ts.tv_sec)) * 1_000_000_000 + @as(u64, @intCast(ts.tv_nsec));
}

// ============================================================================
// Internal helpers
// ============================================================================

fn findConstraintForItem(item: objc.id) void {
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

    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] Constraints: {} on contentView\n", .{count});

    var i: usize = 0;
    while (i < count) : (i += 1) {
        const constraint = msgSend1(constraints, "objectAtIndex:", i);
        const secondItem = msgSend0(constraint, "secondItem");

        if (secondItem == superview and superview != null) {
            item_constraint = constraint;
            _ = msgSend0(item_constraint, "retain");
            if (comptime builtin.mode == .Debug)
                std.debug.print("[Menubar] Constraint MATCH idx={}\n", .{i});
            return;
        }
    }

    i = 0;
    while (i < count) : (i += 1) {
        const constraint = msgSend1(constraints, "objectAtIndex:", i);
        const firstItem = msgSend0(constraint, "firstItem");

        if (firstItem == superview and superview != null) {
            item_constraint = constraint;
            _ = msgSend0(item_constraint, "retain");
            if (comptime builtin.mode == .Debug)
                std.debug.print("[Menubar] Constraint MATCH (fallback) idx={}\n", .{i});
            return;
        }
    }

    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] WARNING: No constraint found\n", .{});
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
    var buf: [160]u8 = undefined;
    const js = std.fmt.bufPrint(&buf, "window.dispatchEvent(new CustomEvent('craft:menubar:stateChange',{{detail:{{collapsed:{s}}}}}));", .{
        if (is_collapsed) "true" else "false",
    }) catch return;
    macos.tryEvalJS(js) catch {};
}

fn toggleClicked(_: objc.id, _: objc.SEL, sender: objc.id) callconv(.c) void {
    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] Chevron clicked\n", .{});

    const NSApp = msgSend0(getClass("NSApplication"), "sharedApplication");
    const event = msgSend0(NSApp, "currentEvent");
    if (event != null) {
        const eventType = msgSendUsize(event, "type");
        // Right-click → show context menu
        if (eventType == 3 or eventType == 4) {
            if (sender != null) {
                showTrayMenu(sender);
            }
            return;
        }
    }

    toggle();
}
