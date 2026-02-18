const std = @import("std");
const builtin = @import("builtin");
const logging = @import("logging.zig");

const log = logging.menu;

/// Menu Bar Collapse/Hide System
///
/// Two NSStatusItems are created at init:
///   1. A "separator" (toggle button showing ‹ or ›) — always visible.
///   2. A "hider" — 10 000 px wide, starts hidden (visible=NO).
///
/// To collapse: hider.visible = YES  → pushes everything left off-screen.
/// To expand:   hider.visible = NO   → items reappear.

// Objective-C runtime types
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

fn getClass(name: [*:0]const u8) if (builtin.target.os.tag == .macos) objc.id else *anyopaque {
    if (builtin.target.os.tag != .macos) unreachable;
    const class_ptr = objc.objc_getClass(name);
    return @ptrCast(@alignCast(class_ptr));
}

fn msgSend0(target: anytype, selector: [*:0]const u8) if (builtin.target.os.tag == .macos) objc.id else *anyopaque {
    if (builtin.target.os.tag != .macos) unreachable;
    const msg = @as(*const fn (@TypeOf(target), objc.SEL) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    return msg(target, objc.sel_registerName(selector));
}

fn msgSend1(target: anytype, selector: [*:0]const u8, arg1: anytype) if (builtin.target.os.tag == .macos) objc.id else *anyopaque {
    if (builtin.target.os.tag != .macos) unreachable;
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, @TypeOf(arg1)) callconv(.c) objc.id, @ptrCast(&objc.objc_msgSend));
    return msg(target, objc.sel_registerName(selector), arg1);
}

fn msgSendVoid1(target: anytype, selector: [*:0]const u8, arg1: anytype) void {
    if (builtin.target.os.tag != .macos) unreachable;
    const msg = @as(*const fn (@TypeOf(target), objc.SEL, @TypeOf(arg1)) callconv(.c) void, @ptrCast(&objc.objc_msgSend));
    msg(target, objc.sel_registerName(selector), arg1);
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
    const NSStatusBar = getClass("NSStatusBar");
    return msgSend0(NSStatusBar, "systemStatusBar");
}

// ============================================================================
// Global State
// ============================================================================

var is_initialized: bool = false;
var is_collapsed: bool = false;

var separator_item: if (builtin.target.os.tag == .macos) objc.id else ?*anyopaque = if (builtin.target.os.tag == .macos) null else null;
var hider_item: if (builtin.target.os.tag == .macos) objc.id else ?*anyopaque = if (builtin.target.os.tag == .macos) null else null;
var separator_target: if (builtin.target.os.tag == .macos) objc.id else ?*anyopaque = if (builtin.target.os.tag == .macos) null else null;
var class_registered: bool = false;

var auto_collapse_delay: u32 = 0;
var auto_collapse_timer_active: bool = false;
var last_expand_instant: ?std.time.Instant = null;

const HIDER_WIDTH: f64 = 10000.0;

// ============================================================================
// Public API
// ============================================================================

pub fn init() void {
    if (builtin.target.os.tag != .macos) return;
    if (is_initialized) return;

    std.debug.print("[Menubar] Initializing...\n", .{});

    const statusBar = getSystemStatusBar();

    // Register ObjC click handler class (once)
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
            const sel = objc.sel_registerName("separatorClicked:");
            const imp: objc.IMP = @ptrCast(@constCast(&separatorClicked));
            _ = objc.class_addMethod(@ptrCast(@alignCast(targetClass)), sel, imp, "v@:@");
            objc.objc_registerClassPair(@ptrCast(@alignCast(targetClass)));
        }

        const cls_id: objc.id = @ptrCast(@alignCast(targetClass));
        separator_target = msgSend0(msgSend0(cls_id, "alloc"), "init");
        _ = msgSend0(separator_target, "retain");
        class_registered = true;
    }

    // 1) Create the SEPARATOR (toggle button, always visible)
    const NSVariableStatusItemLength: f64 = -1.0;
    separator_item = msgSend1(statusBar, "statusItemWithLength:", NSVariableStatusItemLength);
    _ = msgSend0(separator_item, "retain");
    msgSendVoid1(separator_item, "setAutosaveName:", createNSString("barista_expandcollapse"));

    const sep_button = msgSend0(separator_item, "button");
    if (sep_button != null) {
        msgSendVoid1(sep_button, "setTitle:", createNSString("\xE2\x80\xB9")); // ‹
        msgSendVoid1(sep_button, "setTarget:", separator_target);
        msgSendVoid1(sep_button, "setAction:", objc.sel_registerName("separatorClicked:"));
    }

    std.debug.print("[Menubar] Separator created: {*}\n", .{@as(?*anyopaque, separator_item)});

    // 2) Create the HIDER (10000px wide, starts HIDDEN via visible=NO)
    //    Created after separator → positioned to the LEFT of separator.
    //    Must have button content for macOS to allocate space when visible.
    hider_item = msgSend1(statusBar, "statusItemWithLength:", HIDER_WIDTH);
    _ = msgSend0(hider_item, "retain");
    msgSendVoid1(hider_item, "setAutosaveName:", createNSString("barista_separate"));

    const hider_button = msgSend0(hider_item, "button");
    if (hider_button != null) {
        msgSendVoid1(hider_button, "setTitle:", createNSString(" "));
    }

    // Start hidden — items are visible (expanded state)
    msgSendVoid1(hider_item, "setVisible:", @as(bool, false));

    std.debug.print("[Menubar] Hider created (hidden): {*}\n", .{@as(?*anyopaque, hider_item)});

    is_initialized = true;
    is_collapsed = false;

    std.debug.print("[Menubar] Ready\n", .{});
}

/// Collapse: show the 10000px hider → pushes items off-screen.
pub fn collapse() void {
    if (builtin.target.os.tag != .macos) return;
    if (!is_initialized) {
        init();
        if (!is_initialized) return;
    }
    if (is_collapsed) return;

    std.debug.print("[Menubar] Collapsing — showing hider...\n", .{});

    // Make the wide hider visible → status bar re-layouts, pushing items left
    msgSendVoid1(hider_item, "setVisible:", @as(bool, true));

    updateSeparatorIcon("\xE2\x80\xBA"); // ›

    is_collapsed = true;
    auto_collapse_timer_active = false;

    std.debug.print("[Menubar] Collapsed\n", .{});
    notifyJS();
}

/// Expand: hide the hider → items reappear.
pub fn expand() void {
    if (builtin.target.os.tag != .macos) return;
    if (!is_initialized) {
        init();
        if (!is_initialized) return;
    }
    if (!is_collapsed) return;

    std.debug.print("[Menubar] Expanding — hiding hider...\n", .{});

    msgSendVoid1(hider_item, "setVisible:", @as(bool, false));

    updateSeparatorIcon("\xE2\x80\xB9"); // ‹

    is_collapsed = false;

    last_expand_instant = std.time.Instant.now() catch null;
    if (auto_collapse_delay > 0) {
        auto_collapse_timer_active = true;
    }

    std.debug.print("[Menubar] Expanded\n", .{});
    notifyJS();
}

/// Toggle collapsed/expanded. Auto-initializes.
pub fn toggle() void {
    if (builtin.target.os.tag != .macos) return;

    if (!is_initialized) {
        std.debug.print("[Menubar] Auto-init on toggle\n", .{});
        init();
        if (!is_initialized) return;
    }

    std.debug.print("[Menubar] Toggle (collapsed={})\n", .{is_collapsed});
    if (is_collapsed) expand() else collapse();
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
        last_expand_instant = std.time.Instant.now() catch null;
    } else {
        auto_collapse_timer_active = false;
    }
}

pub fn checkAutoCollapse() void {
    if (!auto_collapse_timer_active or auto_collapse_delay == 0 or is_collapsed) {
        if (is_collapsed) auto_collapse_timer_active = false;
        return;
    }

    const start = last_expand_instant orelse return;
    const now = std.time.Instant.now() catch return;
    const elapsed_ns = now.since(start);
    const delay_ns: u64 = @as(u64, auto_collapse_delay) * std.time.ns_per_s;

    if (elapsed_ns >= delay_ns) {
        collapse();
    }
}

// ============================================================================
// Internal
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
    std.debug.print("[Menubar] Separator clicked\n", .{});
    toggle();
}
