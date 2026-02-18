const std = @import("std");
const builtin = @import("builtin");
const logging = @import("logging.zig");

const log = logging.menu;

/// Menu Bar Collapse/Hide System
///
/// Hides menu bar status items by creating a very wide (10000px) NSStatusItem
/// with an NSVisualEffectView (.menu material) as its content. Since the hider
/// is itself a status item (window level 25), it lives at the SAME level as
/// other status items and blends naturally with the menu bar — no floating
/// overlay, no visual mismatch.
///
/// On collapse:  create hider item (10000px) with visual effect background
/// On expand:    remove hider item entirely
///
/// The separator toggle (‹/›) stays persistent across collapse/expand cycles.

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

const CGRect = extern struct {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
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

fn msgSendVoid0(target: anytype, sel: [*:0]const u8) void {
    if (builtin.target.os.tag != .macos) unreachable;
    const f = @as(*const fn (@TypeOf(target), objc.SEL) callconv(.c) void, @ptrCast(&objc.objc_msgSend));
    f(target, objc.sel_registerName(sel));
}

fn msgSendVoid1(target: anytype, sel: [*:0]const u8, a1: anytype) void {
    if (builtin.target.os.tag != .macos) unreachable;
    const f = @as(*const fn (@TypeOf(target), objc.SEL, @TypeOf(a1)) callconv(.c) void, @ptrCast(&objc.objc_msgSend));
    f(target, objc.sel_registerName(sel), a1);
}

fn msgSendRect(target: anytype, sel: [*:0]const u8) CGRect {
    if (builtin.target.os.tag != .macos) unreachable;
    const f = @as(*const fn (@TypeOf(target), objc.SEL) callconv(.c) CGRect, @ptrCast(&objc.objc_msgSend));
    return f(target, objc.sel_registerName(sel));
}

fn msgSendF64(target: anytype, sel: [*:0]const u8) f64 {
    if (builtin.target.os.tag != .macos) unreachable;
    const f = @as(*const fn (@TypeOf(target), objc.SEL) callconv(.c) f64, @ptrCast(&objc.objc_msgSend));
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

var is_initialized: bool = false;
var is_collapsed: bool = false;

var separator_item: objc.id = if (builtin.target.os.tag == .macos) null else null;
var hider_item: objc.id = if (builtin.target.os.tag == .macos) null else null;
var separator_target: objc.id = if (builtin.target.os.tag == .macos) null else null;
var class_registered: bool = false;

var auto_collapse_delay: u32 = 0;
var auto_collapse_timer_active: bool = false;
var last_expand_ns: ?u64 = null;

// ============================================================================
// Public API
// ============================================================================

pub fn init() void {
    if (builtin.target.os.tag != .macos) return;
    if (is_initialized) return;

    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] Initializing...\n", .{});

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
                objc.sel_registerName("separatorClicked:"),
                @ptrCast(@constCast(&separatorClicked)),
                "v@:@",
            );
            objc.objc_registerClassPair(@ptrCast(@alignCast(targetClass)));
        }

        const cls_id: objc.id = @ptrCast(@alignCast(targetClass));
        separator_target = msgSend0(msgSend0(cls_id, "alloc"), "init");
        _ = msgSend0(separator_target, "retain");
        class_registered = true;
    }

    // Create the separator toggle button (‹/›)
    const NSVariableStatusItemLength: f64 = -1.0;
    separator_item = msgSend1(getSystemStatusBar(), "statusItemWithLength:", NSVariableStatusItemLength);
    _ = msgSend0(separator_item, "retain");
    msgSendVoid1(separator_item, "setAutosaveName:", createNSString("barista_expandcollapse"));

    const btn = msgSend0(separator_item, "button");
    if (btn != null) {
        msgSendVoid1(btn, "setTitle:", createNSString("\xE2\x80\xB9")); // ‹
        msgSendVoid1(btn, "setTarget:", separator_target);
        msgSendVoid1(btn, "setAction:", objc.sel_registerName("separatorClicked:"));
    }

    is_initialized = true;
    is_collapsed = false;

    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] Ready\n", .{});
}

/// Collapse: create a wide status item with a visual effect view that covers
/// other items. Since it's a status item (level 25), it blends with the menu bar.
pub fn collapse() void {
    if (builtin.target.os.tag != .macos) return;
    if (!is_initialized) {
        init();
        if (!is_initialized) return;
    }
    if (is_collapsed) return;

    // Remove any existing hider
    if (hider_item != null) {
        _ = msgSend1(getSystemStatusBar(), "removeStatusItem:", hider_item);
        hider_item = null;
    }

    // Create a very wide status item — it will overlap other items at the same level
    const hider_length: f64 = 10000.0;
    hider_item = msgSend1(getSystemStatusBar(), "statusItemWithLength:", hider_length);
    if (hider_item == null) {
        if (comptime builtin.mode == .Debug)
            std.debug.print("[Menubar] Failed to create hider item\n", .{});
        return;
    }
    _ = msgSend0(hider_item, "retain");
    msgSendVoid1(hider_item, "setAutosaveName:", createNSString("barista_hider"));

    // Get the button and set up a visual effect view as its content
    const button = msgSend0(hider_item, "button");
    if (button != null) {
        // Clear default title
        msgSendVoid1(button, "setTitle:", createNSString(""));

        // Get the menu bar thickness for the view height
        const thickness = msgSendF64(getSystemStatusBar(), "thickness");

        // Create NSVisualEffectView matching the menu bar
        const NSVisualEffectView = getClass("NSVisualEffectView");
        const effect_view = msgSend1(
            msgSend0(NSVisualEffectView, "alloc"),
            "initWithFrame:",
            CGRect{ .x = 0, .y = 0, .width = hider_length, .height = thickness },
        );

        // material = .menu (5), state = .active (1), blendingMode = .behindWindow (0)
        msgSendVoid1(effect_view, "setMaterial:", @as(c_long, 5));
        msgSendVoid1(effect_view, "setState:", @as(c_long, 1));
        msgSendVoid1(effect_view, "setBlendingMode:", @as(c_long, 0));

        // Add the visual effect view as a subview of the button
        msgSendVoid1(button, "addSubview:", effect_view);

        // Also set the button's layer to clip content
        msgSendVoid1(button, "setWantsLayer:", @as(objc.BOOL, true));
    }

    updateSeparatorIcon("\xE2\x80\xBA"); // ›
    is_collapsed = true;
    auto_collapse_timer_active = false;

    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] Collapsed\n", .{});
    notifyJS();
}

/// Expand: remove the hider status item entirely.
pub fn expand() void {
    if (builtin.target.os.tag != .macos) return;
    if (!is_initialized) {
        init();
        if (!is_initialized) return;
    }
    if (!is_collapsed) return;

    if (hider_item != null) {
        _ = msgSend1(getSystemStatusBar(), "removeStatusItem:", hider_item);
        msgSendVoid0(hider_item, "release");
        hider_item = null;
    }

    updateSeparatorIcon("\xE2\x80\xB9"); // ‹
    is_collapsed = false;

    last_expand_ns = nanoTimestamp();
    if (auto_collapse_delay > 0) {
        auto_collapse_timer_active = true;
    }

    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] Expanded\n", .{});
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

fn updateSeparatorIcon(icon: []const u8) void {
    if (separator_item == null) return;
    const button = msgSend0(separator_item, "button");
    if (button != null) {
        msgSendVoid1(button, "setTitle:", createNSString(icon));
    }
}

fn notifyJS() void {
    const macos = @import("macos.zig");
    var buf: [160]u8 = undefined;
    const js = std.fmt.bufPrint(&buf, "window.dispatchEvent(new CustomEvent('craft:menubar:stateChange',{{detail:{{collapsed:{s}}}}}));", .{
        if (is_collapsed) "true" else "false",
    }) catch return;
    macos.tryEvalJS(js) catch {};
}

fn separatorClicked(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    if (comptime builtin.mode == .Debug)
        std.debug.print("[Menubar] Separator clicked\n", .{});
    toggle();
}
