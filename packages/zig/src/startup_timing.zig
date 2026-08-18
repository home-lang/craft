//! Where the milliseconds before first paint actually go.
//!
//! "The app feels slow to launch" is not a bug report you can act on, and
//! timing craft from the outside folds the whole process into one number that
//! hides which half is ours. `--benchmark` already answers "how fast can a
//! window appear", but it exits before any page loads, so the expensive part —
//! WebKit coming up and the page arriving — is invisible to it.
//!
//! This records named marks along the startup path against one monotonic clock
//! and prints the gaps. It is a fixed-size array of integers written on a path
//! that already does Objective-C message sends, so leaving it compiled in costs
//! nothing measurable; nothing prints unless `--timing` is passed.
//!
//! The ordering it exposes is the point. Everything between "webview created"
//! and "load started" is setup the network is waiting on, so a mark that drifts
//! later is a regression you can see rather than infer.

const std = @import("std");
// craft's own monotonic clock: this Zig has no std.time.nanoTimestamp, and
// compat is what the rest of the codebase already times against.
const compat = @import("compat.zig");

/// Marks in the order they occur. Adding one is a new enum member plus a
/// `mark()` call; nothing else needs to change.
pub const Phase = enum {
    process_start,
    args_parsed,
    platform_init,
    window_created,
    webview_config_built,
    webview_created,
    load_started,
    window_shown,
    runloop_entered,

    pub fn label(self: Phase) []const u8 {
        return switch (self) {
            .process_start => "process start",
            .args_parsed => "args parsed",
            .platform_init => "platform init (NSApp)",
            .window_created => "window created",
            .webview_config_built => "webview config built",
            .webview_created => "webview created",
            .load_started => "load started",
            .window_shown => "window shown",
            .runloop_entered => "run loop entered",
        };
    }
};

const info = @typeInfo(Phase).@"enum";
const count = info.field_names.len;

var origin_ns: i128 = 0;
var stamps: [count]?i128 = @splat(null);
var enabled: bool = false;

/// Turn recording on. Called once, as early as possible, before any mark.
pub fn start() void {
    enabled = true;
    origin_ns = compat.nanoTimestamp();
    stamps = @splat(null);
    stamps[@backingInt(Phase.process_start)] = origin_ns;
}

/// Record a phase. A no-op unless `start()` ran, so call sites need no guard.
///
/// First write wins: a window created per monitor, or a retry after a failed
/// load, must not overwrite the timeline of the first one — the interesting
/// question is always when a phase *first* happened.
pub fn mark(phase: Phase) void {
    if (!enabled) return;
    const index = @backingInt(phase);
    if (stamps[index] != null) return;
    stamps[index] = compat.nanoTimestamp();
}

/// Milliseconds from process start to a phase, or null if it never happened.
pub fn millisSince(phase: Phase) ?f64 {
    const at = stamps[@backingInt(phase)] orelse return null;
    return @as(f64, @floatFromInt(at - origin_ns)) / 1_000_000.0;
}

/// Print the timeline: elapsed since start, and the gap from the previous mark.
///
/// The gap column is what a reader acts on — a total tells you the app is slow,
/// a gap tells you which call to move.
pub fn report() void {
    if (!enabled) return;

    std.debug.print("\n  craft startup\n", .{});
    var previous: ?f64 = null;
    inline for (0..count) |index| {
        const phase: Phase = @fromBackingInt(@intCast(info.field_values[index]));
        if (millisSince(phase)) |elapsed| {
            // Phases that never ran are skipped rather than shown as zero: a
            // menubar-only app has no window, and a fabricated 0.0 there would
            // read as "instant" instead of "did not happen".
            const gap = if (previous) |p| elapsed - p else 0;
            std.debug.print("    {s: <24} {d: >7.1}ms  (+{d:.1}ms)\n", .{ phase.label(), elapsed, gap });
            previous = elapsed;
        }
    }
    std.debug.print("\n", .{});
}

/// True when `--timing` was passed, for callers that want to skip other work.
pub fn isEnabled() bool {
    return enabled;
}

// -- tests -------------------------------------------------------------------

const testing = std.testing;

test "marks are silent until started" {
    enabled = false;
    stamps = @splat(null);
    mark(.window_created);
    try testing.expect(millisSince(.window_created) == null);
}

test "records phases in order once started" {
    start();
    defer enabled = false;
    mark(.window_created);
    mark(.load_started);

    const window = millisSince(.window_created).?;
    const load = millisSince(.load_started).?;
    try testing.expect(load >= window);
    try testing.expect(millisSince(.process_start).? == 0);
}

test "a phase that never happened stays null" {
    start();
    defer enabled = false;
    mark(.window_created);
    try testing.expect(millisSince(.runloop_entered) == null);
}

test "first write wins so a second window cannot rewrite the timeline" {
    start();
    defer enabled = false;
    mark(.window_created);
    const first = millisSince(.window_created).?;

    // Spin until the clock has definitely advanced, so a second mark that did
    // overwrite would produce a different value. Sleeping would be clearer,
    // but this Zig has no std.Thread.sleep.
    const spin_until = compat.nanoTimestamp() + std.time.ns_per_ms;
    while (compat.nanoTimestamp() < spin_until) {}

    mark(.window_created);
    try testing.expectEqual(first, millisSince(.window_created).?);
}

test "start resets a previous run" {
    start();
    mark(.window_created);
    start();
    defer enabled = false;
    try testing.expect(millisSince(.window_created) == null);
}
