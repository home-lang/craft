const std = @import("std");
const builtin = @import("builtin");
const logging = @import("logging.zig");

const log = logging.menu;

/// Menu Bar Collapse/Hide System
///
/// Implements the "Hidden Bar" technique for collapsing macOS menu bar items.
///
/// A visible "separator" item (toggle button showing ‹ or ›) is created at init.
/// To collapse: a new 10 000-px-wide status item is created via statusItemWithLength:
///   — this pushes everything to its left off the screen edge.
/// To expand: the wide item is removed via removeStatusItem:
///   — items spring back into view.
///
/// Note: setLength: does NOT trigger a status bar re-layout, so we must
/// destroy and re-create the hider item each time.

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

// Objective-C message sending helpers
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

/// The visible separator/toggle item (shows ‹ or ›)
var separator_item: if (builtin.target.os.tag == .macos) objc.id else ?*anyopaque = if (builtin.target.os.tag == .macos) null else null;
/// The wide hider item — only exists while collapsed
var hider_item: if (builtin.target.os.tag == .macos) objc.id else ?*anyopaque = if (builtin.target.os.tag == .macos) null else null;
/// Target object for separator click action
var separator_target: if (builtin.target.os.tag == .macos) objc.id else ?*anyopaque = if (builtin.target.os.tag == .macos) null else null;
/// Whether the target class has been registered
var class_registered: bool = false;

/// Auto-collapse delay in seconds (0 = disabled)
var auto_collapse_delay: u32 = 0;
var auto_collapse_timer_active: bool = false;
var last_expand_instant: ?std.time.Instant = null;

/// Width of the hider item when collapsed.
const HIDER_WIDTH: f64 = 10000.0;

// ============================================================================
// Public API
// ============================================================================

/// Initialize the menu bar collapse system.
/// Creates only the separator NSStatusItem.
pub fn init() void {
    if (builtin.target.os.tag != .macos) return;
    if (is_initialized) return;

    std.debug.print("[Menubar] Initializing...\n", .{});

    const statusBar = getSystemStatusBar();
    if (statusBar == null) {
        std.debug.print("[Menubar] ERROR: systemStatusBar is null\n", .{});
        return;
    }

    // Register the click handler ObjC class (once globally)
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

    // Create the separator item (visible toggle button)
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

    is_initialized = true;
    is_collapsed = false;

    std.debug.print("[Menubar] Initialized. separator={*}\n", .{@as(?*anyopaque, separator_item)});
}

/// Collapse: create a fresh 10000-px-wide status item to push items off-screen.
pub fn collapse() void {
    if (builtin.target.os.tag != .macos) return;
    if (!is_initialized) {
        init();
        if (!is_initialized) return;
    }
    if (is_collapsed) return;

    std.debug.print("[Menubar] Collapsing...\n", .{});

    // Remove any leftover hider
    destroyHider();

    // Create a brand-new status item with the full 10000px width.
    // statusItemWithLength: triggers a proper layout (unlike setLength:).
    const statusBar = getSystemStatusBar();
    hider_item = msgSend1(statusBar, "statusItemWithLength:", HIDER_WIDTH);
    if (hider_item == null) {
        std.debug.print("[Menubar] ERROR: failed to create hider\n", .{});
        return;
    }
    _ = msgSend0(hider_item, "retain");

    // Give the button some content so macOS allocates the full width
    const btn = msgSend0(hider_item, "button");
    if (btn != null) {
        msgSendVoid1(btn, "setTitle:", createNSString(" "));
    }

    // Update separator icon → ›
    updateSeparatorIcon("\xE2\x80\xBA");

    is_collapsed = true;
    auto_collapse_timer_active = false;

    std.debug.print("[Menubar] Collapsed. hider={*}\n", .{@as(?*anyopaque, hider_item)});
    notifyJS();
}

/// Expand: destroy the hider item so menu bar icons reappear.
pub fn expand() void {
    if (builtin.target.os.tag != .macos) return;
    if (!is_initialized) {
        init();
        if (!is_initialized) return;
    }
    if (!is_collapsed) return;

    std.debug.print("[Menubar] Expanding...\n", .{});

    destroyHider();

    // Update separator icon → ‹
    updateSeparatorIcon("\xE2\x80\xB9");

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

    std.debug.print("[Menubar] Toggle (is_collapsed={})\n", .{is_collapsed});
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
// Internal helpers
// ============================================================================

/// Remove the hider from the status bar and release it.
fn destroyHider() void {
    if (hider_item == null) return;
    const statusBar = getSystemStatusBar();
    msgSendVoid1(statusBar, "removeStatusItem:", hider_item);
    _ = msgSend0(hider_item, "release");
    hider_item = null;
    std.debug.print("[Menubar] Hider destroyed\n", .{});
}

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

/// ObjC callback — separator button clicked.
fn separatorClicked(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    std.debug.print("[Menubar] Separator clicked\n", .{});
    toggle();
}
