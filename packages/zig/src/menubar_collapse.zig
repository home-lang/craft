//! Tucking menu bar items away, in the manner of Hidden Bar.
//!
//! macOS gives no API for hiding another app's menu bar item, so the trick is
//! to take up the room instead: a status item that grows very wide shoves the
//! items to its left off the front of the bar.
//!
//!   ·    the marker: the boundary the user arranges icons around
//!   ⋯    invisible links that widen alongside it, resting at no width at all
//!   ☕️   the app's own tray icon
//!
//!   expanded:  [items to hide] [·][⋯][⋯][⋯] [☕️]
//!   collapsed: [·······················] [☕️]
//!
//! The user decides what gets hidden by cmd-dragging icons to the left of `·`.
//! Collapsed, the chain covers the space it just cleared, so clicking anywhere
//! in the emptied stretch brings the icons back. That is deliberately the only
//! affordance: a separate always-visible toggle button would be one more item
//! in a bar the user is trying to empty, and — being just another status item —
//! could itself end up left of the boundary and vanish with everything else.
//! An optional second marker adds a group that stays tucked away even while the
//! rest is expanded.
//!
//! Three things about the growing are easy to get wrong, and each of them looks
//! like the feature doing nothing at all:
//!
//!   - Past some width the system ignores a `setLength:` rather than trimming
//!     it to what it will allow. The ports of this trick ask for a flat
//!     10,000pt, which is over that width everywhere, so nothing ever moves.
//!   - That width is not documented and is not a fixed fraction of the display:
//!     1262pt was accepted on a 2560pt bar with one item widening and refused
//!     on the same bar with two. So no single item can be relied on to cross
//!     the whole bar, and the distance is shared across a chain of them —
//!     every link widening shoves what is left of the chain further left, so
//!     the pushes add up. `settleCollapse` then checks what actually happened
//!     and narrows the slices until the bar really moved.
//!   - The width has to be set before the button's title, or AppKit lays the
//!     button out against the old width and the growth is lost.

const std = @import("std");
const builtin = @import("builtin");
const logging = @import("logging.zig");

const log = logging.menu;

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
    pub extern "objc" fn objc_msgSend_stret() void;
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

const CGPoint = extern struct { x: f64, y: f64 };
const CGSize = extern struct { width: f64, height: f64 };
const CGRect = extern struct { origin: CGPoint, size: CGSize };

/// `-frame` and friends return a 32-byte struct, which both macOS ABIs hand
/// back through a caller-provided pointer. On x86_64 that is a different entry
/// point; arm64 routes every return shape through `objc_msgSend`.
fn msgSendRect(target: anytype, sel: [*:0]const u8) CGRect {
    if (builtin.target.os.tag != .macos) unreachable;
    const entry = if (comptime builtin.target.cpu.arch == .x86_64)
        &objc.objc_msgSend_stret
    else
        &objc.objc_msgSend;
    const f = @as(*const fn (@TypeOf(target), objc.SEL) callconv(.c) CGRect, @ptrCast(entry));
    return f(target, objc.sel_registerName(sel));
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
    const z = @import("memory.zig").dupeZ(allocator, u8, str) catch return null;
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

// The widening chain. `markers[0]` is the `·` the user sees and drags icons to
// the left of; the rest are helpers that only exist because one item cannot get
// wide enough on its own. See `collapse` for why there is more than one.
var markers: [MARKER_COUNT]objc.id = @splat(if (builtin.target.os.tag == .macos) null else null);

/// The `·` marker: the boundary the user arranges icons around.
fn separatorItem() objc.id {
    return markers[0];
}

var saved_tray_menu: objc.id = if (builtin.target.os.tag == .macos) null else null;
var click_target: objc.id = if (builtin.target.os.tag == .macos) null else null;
var class_registered: bool = false;

// Always-hidden section — matches Hidden's btnAlwaysHidden
var always_hidden_item: objc.id = if (builtin.target.os.tag == .macos) null else null;
var always_hidden_enabled: bool = false;
var always_hidden_active: bool = false;

var separator_hidden: bool = false;

/// Where the leftmost link stood before the widening, and how far it has to
/// travel. `settleCollapse` compares against these to see whether the system
/// took the widths it was handed.
var collapse_origin: f64 = 0;
var collapse_travel: f64 = 0;
var collapse_limit: f64 = 0;
var collapse_settled: bool = true;
var settle_attempts: u8 = 0;

var auto_collapse_delay: u32 = 0;
var auto_collapse_timer_active: bool = false;
var last_expand_ns: ?u64 = null;

// Debounce: matches Hidden's isToggle with 0.3s cooldown
var toggle_debounce_active: bool = false;
var toggle_debounce_ns: ?u64 = null;
const DEBOUNCE_INTERVAL_NS: u64 = 300_000_000;

const SEPARATOR_LENGTH: f64 = 20.0; // matches Hidden's btnHiddenLength

/// How many items the widening is spread across.
///
/// A chain never has to travel further than the width of the display. Four
/// links means the job is still possible once `settleCollapse` has backed the
/// per-link width down to a quarter of the display, which is well below any
/// refusal seen in practice.
const MARKER_COUNT = 4;

/// Positions are remembered per name, so these have to stay stable across
/// releases or everyone's arrangement resets.
const autosaveNames = [MARKER_COUNT][]const u8{ "craft_menubar_marker", "craft_menubar_link_1", "craft_menubar_link_2", "craft_menubar_link_3" };

/// How much narrower to go on each retry, and how many retries to allow before
/// settling for whatever was achieved.
const LIMIT_BACKOFF: f64 = 0.75;
const MAX_SETTLE_ATTEMPTS: u8 = 6;

const SEPARATOR_DOT = "\xC2\xB7"; // ·

/// NSEvent types and masks. A status button reports left clicks only unless it
/// is told otherwise, so a right click would never reach `toggleClicked:`.
const NSEventTypeLeftMouseUp: usize = 2;
const NSEventTypeRightMouseDown: usize = 3;
const NSEventTypeRightMouseUp: usize = 4;
const NSEventMaskLeftMouseUp: c_ulong = 1 << 2;
const NSEventMaskRightMouseUp: c_ulong = 1 << 4;
const NSEventModifierFlagControl: usize = 1 << 18;

// ============================================================================
// Public API
// ============================================================================

/// Called from tray.zig before the tray item is created, to register the click
/// target the markers share.
pub fn earlyInit() void {
    if (builtin.target.os.tag != .macos) return;
    if (early_initialized) return;

    if (comptime builtin.mode == .debug)
        std.debug.print("[Menubar] earlyInit — registering click target...\n", .{});

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

    early_initialized = true;

    if (comptime builtin.mode == .debug)
        std.debug.print("[Menubar] earlyInit done\n", .{});
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

    // The system drops each new status item to the left of the ones already
    // there, so the chain is built back to front — helpers first, `·` last —
    // which lands the `·` leftmost of ours on a first run, with the helpers
    // tucked between it and the tray icon. Only on a first run, though: a
    // position is remembered per autosave name, so once the user drags things
    // around the order is theirs. `travelToClearBar` does not assume it.
    var i: usize = MARKER_COUNT;
    while (i > 0) {
        i -= 1;
        markers[i] = msgSend1(getSystemStatusBar(), "statusItemWithLength:", restingWidth(i));
        _ = msgSend0(markers[i], "retain");
        msgSendVoid1(markers[i], "setAutosaveName:", createNSString(autosaveNames[i]));
        if (i == 0) drawMarker(markers[i], false);
        routeClicks(msgSend0(markers[i], "button"));
        suppressHighlight(markers[i]);
    }

    is_initialized = true;
    is_collapsed = false;

    if (comptime builtin.mode == .debug)
        std.debug.print("[Menubar] Ready — separator created\n", .{});
}

pub fn collapse() void {
    if (builtin.target.os.tag != .macos) return;
    if (!is_initialized) {
        init();
        if (!is_initialized) return;
    }
    if (is_collapsed) return;
    if (separatorItem() == null) return;

    // Carry the chain off the front of the bar; everything to its left travels
    // with it. No single item can stretch that far — past some width the system
    // ignores the request rather than trimming it down — so the distance is
    // shared out, each link taking a slice and the rest passing down the chain.
    //
    // That refusal width is not documented and is not a fixed fraction of the
    // display: 1262pt was accepted on a 2560pt bar with one link widening and
    // refused on the same bar with two. So the first attempt is a guess and
    // `settleCollapse` checks, on the next turn of the run loop, whether the
    // bar actually moved — retrying with narrower slices until it does.
    collapse_origin = leftmostMarkerX();
    collapse_travel = collapse_origin + SEPARATOR_LENGTH;
    collapse_limit = screenWidth() / 2 - SEPARATOR_LENGTH;
    collapse_settled = false;
    settle_attempts = 0;
    applyWidening(collapse_limit);

    is_collapsed = true;
    auto_collapse_timer_active = false;

    if (comptime builtin.mode == .debug)
        std.debug.print("[Menubar] Collapsed\n", .{});
    notifyJS();
}

pub fn expand() void {
    if (builtin.target.os.tag != .macos) return;
    if (!is_initialized) {
        init();
        if (!is_initialized) return;
    }
    if (!is_collapsed) return;
    if (separatorItem() == null) return;

    // Shrink the chain back, which brings the hidden items along with it.
    collapse_settled = true;
    for (markers, 0..) |marker, index| {
        setMarkerWidth(marker, restingWidth(index));
    }

    // Keep always-hidden items off-screen
    if (always_hidden_enabled and always_hidden_item != null and !always_hidden_active) {
        activateAlwaysHidden();
    }

    is_collapsed = false;
    last_expand_ns = nanoTimestamp();
    if (auto_collapse_delay > 0) {
        auto_collapse_timer_active = true;
    }

    if (comptime builtin.mode == .debug)
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
    settleCollapse();

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

    drawMarker(always_hidden_item, false);
    routeClicks(msgSend0(always_hidden_item, "button"));

    always_hidden_enabled = true;

    if (!is_collapsed) {
        activateAlwaysHidden();
    }

    if (comptime builtin.mode == .debug)
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

    always_hidden_enabled = false;

    if (comptime builtin.mode == .debug)
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

    drawMarker(separatorItem(), is_collapsed);
    if (always_hidden_enabled) drawMarker(always_hidden_item, always_hidden_active);
}

pub fn isSeparatorHidden() bool {
    return separator_hidden;
}

// ============================================================================
// Internal helpers
// ============================================================================

/// Send both mouse buttons through the item's action instead of letting AppKit
/// swallow the right click. Pair this with holding the menu rather than calling
/// `setMenu:` — an item with a menu attached opens it on either button and never
/// runs its action, so left click could not toggle.
fn routeClicks(button: objc.id) void {
    if (button == null) return;
    msgSendVoid1(button, "setTarget:", click_target);
    msgSendVoid1(button, "setAction:", objc.sel_registerName("toggleClicked:"));
    msgSendVoid1(button, "sendActionOn:", NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp);
}

/// The `·` a marker draws. A widened marker spans most of the menu bar, so its
/// title would either float in the middle of the bar or sit off-screen entirely
/// — either way it is noise, and the marker is drawn blank while widened.
fn drawMarker(item: objc.id, widened: bool) void {
    if (item == null) return;
    const button = msgSend0(item, "button");
    if (button == null) return;

    const visible = !widened and !separator_hidden;
    msgSendVoid1(button, "setTitle:", createNSString(if (visible) SEPARATOR_DOT else ""));
}

/// Widen a marker as far as the system will let it, pushing the items to its
/// left off the end of the menu bar — or restore it to its normal width.
///
/// macOS caps how wide a status item may become, and a `setLength:` past that
/// cap is not clamped to the maximum: the item degenerates to nothing and the
/// bar lays out as if the marker were not there at all. Ports of the original
/// Hidden Bar trick ask for a flat 10,000pt, which lands past the cap on every
/// display this was measured on and so hides nothing.
///
/// Set a marker's width, and draw its `·` only at its resting size — a widened
/// marker spans most of the bar, so a dot centred in it would float somewhere
/// out in the empty space.
///
/// The width goes on before the title: a status button sizes itself to its own
/// content, so touching the title first makes AppKit lay the button out against
/// the width it had before, and the change is lost.
fn setMarkerWidth(item: objc.id, width: f64) void {
    if (item == null) return;
    msgSendVoid1(item, "setLength:", width);
    if (item == separatorItem()) drawMarker(item, width > SEPARATOR_LENGTH);
}

/// Hand each link a slice of the remaining distance, none wider than `limit`.
/// Links with nothing left to carry drop to their resting width, which also
/// undoes anything left over from an earlier, wider attempt.
fn applyWidening(limit: f64) void {
    var remaining = collapse_travel;
    for (markers, 0..) |marker, index| {
        const share = @max(@min(remaining, limit), 0);
        setMarkerWidth(marker, @max(share, restingWidth(index)));
        remaining -= share;
    }
}

/// Check whether the widening took, and narrow the slices if it did not.
///
/// The system resizes status item windows asynchronously, so this has to run a
/// turn of the run loop after the widths were set — never straight after them,
/// where the frames still read as they did before.
fn settleCollapse() void {
    if (collapse_settled or !is_collapsed) return;

    const moved = collapse_origin - leftmostMarkerX();
    if (moved >= collapse_travel - SEPARATOR_LENGTH) {
        collapse_settled = true;
        if (comptime builtin.mode == .debug)
            std.debug.print("[Menubar] Settled — moved {d}pt of {d}pt\n", .{ moved, collapse_travel });
        return;
    }

    settle_attempts += 1;
    if (settle_attempts >= MAX_SETTLE_ATTEMPTS) {
        collapse_settled = true;
        log.debug("menu bar collapse fell short: moved {d}pt of {d}pt", .{ moved, collapse_travel });
        return;
    }

    // Never go below what the chain needs to cover the distance between them.
    const floor = collapse_travel / @as(f64, MARKER_COUNT);
    collapse_limit = @max(collapse_limit * LIMIT_BACKOFF, floor);
    applyWidening(collapse_limit);
}

fn leftmostMarkerX() f64 {
    var leftmost: f64 = screenWidth();
    for (markers) |marker| {
        const x = markerOriginX(marker) orelse continue;
        if (x < leftmost) leftmost = x;
    }
    return leftmost;
}

/// What a link is worth when it is not carrying anything: a visible divider for
/// the `·`, and nothing at all for the helpers, so the user sees one marker in
/// the bar rather than three.
fn restingWidth(index: usize) f64 {
    return if (index == 0) SEPARATOR_LENGTH else 0;
}

/// The x of the marker's own status window. Read before widening: the system
/// resizes status item windows asynchronously, so a frame read straight after a
/// `setLength:` still reports the old geometry.
fn markerOriginX(item: objc.id) ?f64 {
    if (item == null) return null;
    const button = msgSend0(item, "button");
    if (button == null) return null;
    const window = msgSend0(button, "window");
    if (window == null) return null;
    return msgSendRect(window, "frame").origin.x;
}

fn screenWidth() f64 {
    const screen = msgSend0(getClass("NSScreen"), "mainScreen");
    if (screen == null) return 0;
    return msgSendRect(screen, "frame").size.width;
}

/// A status button flashes a highlight behind itself while pressed. Across a
/// widened marker that is a slab of colour over half the menu bar, so the
/// markers opt out of it and stay invisible whether or not they are being
/// clicked.
fn suppressHighlight(item: objc.id) void {
    if (item == null) return;
    const button = msgSend0(item, "button");
    if (button == null) return;
    const cell = msgSend0(button, "cell");
    if (cell == null) return;
    msgSendVoid1(cell, "setHighlightsBy:", @as(c_ulong, 0));
}

fn activateAlwaysHidden() void {
    setMarkerWidth(always_hidden_item, screenWidth() / 2 - SEPARATOR_LENGTH);
    if (always_hidden_item != null) always_hidden_active = true;
}

fn deactivateAlwaysHidden() void {
    setMarkerWidth(always_hidden_item, SEPARATOR_LENGTH);
    if (always_hidden_item != null) always_hidden_active = false;
}

fn nanoTimestamp() ?u64 {
    // Direct libc call — Zig 0.17 stripped `std.time.nanoTimestamp` and the
    // replacement `Io.Clock.now` requires plumbing an `Io` through this code
    // path, which isn't worth it for a debounce timer. CLOCK_MONOTONIC stays
    // monotonic across NTP adjustments which is what we need for diffing
    // intervals.
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.MONOTONIC, &ts) != 0) return null;
    const sec_ns = @as(u64, @intCast(ts.sec)) * std.time.ns_per_s;
    return sec_ns + @as(u64, @intCast(ts.nsec));
}

/// Whether the click that triggered the action asked for the menu rather than a
/// toggle. Control held during a left click is the long-standing macOS synonym
/// for a right click.
fn wantsMenu(event: objc.id) bool {
    if (event == null) return false;

    const event_type = msgSendUsize(event, "type");
    if (event_type == NSEventTypeRightMouseDown or event_type == NSEventTypeRightMouseUp) return true;

    const modifiers = msgSendUsize(event, "modifierFlags");
    return event_type == NSEventTypeLeftMouseUp and (modifiers & NSEventModifierFlagControl) != 0;
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
    if (comptime builtin.mode == .debug)
        std.debug.print("[Menubar] Toggle clicked\n", .{});

    const NSApp = msgSend0(getClass("NSApplication"), "sharedApplication");
    const event = msgSend0(NSApp, "currentEvent");
    if (wantsMenu(event)) {
        if (sender != null) showTrayMenu(sender);
        return;
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
