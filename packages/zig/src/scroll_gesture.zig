//! Trackpad scroll phases → swipe events, as a pure state machine.
//!
//! A WKWebView's `wheel` stream carries no phase information, so web code has
//! to guess where a gesture starts and ends. The usual guess — end it after a
//! short idle gap — cannot distinguish a finger still on the trackpad from the
//! momentum macOS keeps delivering for over a second afterwards. A web-side
//! swipe therefore settles at the end of momentum instead of at finger-up,
//! which reads as roughly a second of lag on every swipe.
//!
//! The host holds the real NSEvent and its `phase` / `momentumPhase`, so it can
//! forward the truth. This module is that translation with no Objective-C in
//! it; `macos.zig` owns the event monitor that feeds it and the bridge call
//! that ships the result to `window.craft.gestures`.

const std = @import("std");

/// `NSEventPhase` is a bitmask, not an enum.
pub const NSEventPhaseBegan: c_ulong = 1 << 0;
pub const NSEventPhaseChanged: c_ulong = 1 << 2;
pub const NSEventPhaseEnded: c_ulong = 1 << 3;
pub const NSEventPhaseCancelled: c_ulong = 1 << 4;
pub const NSEventMaskScrollWheel: c_ulong = 1 << 22;

/// Below this much travel a swipe and a scroll are indistinguishable, so we
/// wait rather than guess. Matches the 8px axis lock the web fallback uses.
pub const AXIS_LOCK_POINTS: f64 = 8.0;

pub const State = struct {
    /// A gesture is live between an emitted `begin` and its `end`.
    active: bool = false,
    /// Set at Began, cleared once the axis is decided.
    deciding: bool = false,
    /// Decided to be a vertical scroll — stay out of its way for the rest of
    /// the gesture.
    ignored: bool = false,
    accum_x: f64 = 0,
    accum_y: f64 = 0,
    /// Points per second, from the most recent pair of samples.
    velocity_x: f64 = 0,
    last_at: f64 = 0,
};

pub const Phase = enum { begin, change, end };

pub const Emit = struct {
    phase: Phase,
    delta_x: f64 = 0,
    delta_y: f64 = 0,
    velocity_x: f64 = 0,
};

/// Up to two emits come out of one NSEvent: the event that satisfies the axis
/// lock produces both the `begin` and the `change` carrying the travel that
/// decided it.
pub const Emits = struct {
    items: [2]Emit = undefined,
    len: usize = 0,

    fn push(self: *Emits, emit: Emit) void {
        self.items[self.len] = emit;
        self.len += 1;
    }

    pub fn slice(self: *const Emits) []const Emit {
        return self.items[0..self.len];
    }
};

/// Advance the state machine by one scroll event.
pub fn step(
    state: *State,
    phase: c_ulong,
    momentum_phase: c_ulong,
    delta_x: f64,
    delta_y: f64,
    timestamp: f64,
) Emits {
    var out = Emits{};

    // Momentum is the coast after the fingers lift. Forwarding it would
    // reintroduce exactly the bug this module exists to fix, so it is dropped.
    if (momentum_phase != 0) return out;

    if (phase & NSEventPhaseBegan != 0) {
        state.* = .{ .deciding = true, .last_at = timestamp };
        return out;
    }

    if (phase & NSEventPhaseChanged != 0) {
        if (state.ignored) return out;

        if (state.deciding) {
            state.accum_x += delta_x;
            state.accum_y += delta_y;
            if (@max(@abs(state.accum_x), @abs(state.accum_y)) < AXIS_LOCK_POINTS) return out;

            // Decided once and honoured for the rest of the gesture.
            // Re-deciding mid-drag is what makes a carousel feel slippery.
            if (@abs(state.accum_x) <= @abs(state.accum_y)) {
                state.ignored = true;
                state.deciding = false;
                return out;
            }

            state.deciding = false;
            state.active = true;
            state.last_at = timestamp;
            out.push(.{ .phase = .begin });
            // Replay the travel that decided the axis, so the first frame of
            // the swipe does not silently drop those 8 points.
            out.push(.{ .phase = .change, .delta_x = state.accum_x, .delta_y = state.accum_y });
            return out;
        }

        if (!state.active) return out;

        const elapsed = timestamp - state.last_at;
        if (elapsed > 0) state.velocity_x = delta_x / elapsed;
        state.last_at = timestamp;
        out.push(.{
            .phase = .change,
            .delta_x = delta_x,
            .delta_y = delta_y,
            .velocity_x = state.velocity_x,
        });
        return out;
    }

    if (phase & (NSEventPhaseEnded | NSEventPhaseCancelled) != 0) {
        const was_active = state.active;
        const velocity = state.velocity_x;
        state.* = .{};
        if (was_active) out.push(.{ .phase = .end, .velocity_x = velocity });
        return out;
    }

    return out;
}

// =============================================================================

test "vertical scroll never claims a swipe" {
    var state = State{};
    try std.testing.expectEqual(@as(usize, 0), step(&state, NSEventPhaseBegan, 0, 0, 0, 0).len);
    // Well past the axis lock, but all of it vertical.
    try std.testing.expectEqual(@as(usize, 0), step(&state, NSEventPhaseChanged, 0, 1, 40, 0.01).len);
    try std.testing.expect(state.ignored);
    // Once ignored the gesture stays ignored, even if it later turns sideways.
    try std.testing.expectEqual(@as(usize, 0), step(&state, NSEventPhaseChanged, 0, 90, 0, 0.02).len);
    try std.testing.expectEqual(@as(usize, 0), step(&state, NSEventPhaseEnded, 0, 0, 0, 0.03).len);
}

test "horizontal swipe emits begin then change, replaying the axis-lock travel" {
    var state = State{};
    _ = step(&state, NSEventPhaseBegan, 0, 0, 0, 0);

    // Under the lock: nothing emitted yet, but the travel accumulates.
    try std.testing.expectEqual(@as(usize, 0), step(&state, NSEventPhaseChanged, 0, 5, 1, 0.01).len);

    const claimed = step(&state, NSEventPhaseChanged, 0, 5, 1, 0.02);
    try std.testing.expectEqual(@as(usize, 2), claimed.len);
    try std.testing.expectEqual(Phase.begin, claimed.items[0].phase);
    try std.testing.expectEqual(Phase.change, claimed.items[1].phase);
    // Both events' worth of travel, not just the one that crossed the lock.
    try std.testing.expectEqual(@as(f64, 10), claimed.items[1].delta_x);
}

test "momentum is dropped so the swipe settles at finger-up" {
    var state = State{};
    _ = step(&state, NSEventPhaseBegan, 0, 0, 0, 0);
    _ = step(&state, NSEventPhaseChanged, 0, 20, 0, 0.01);
    try std.testing.expect(state.active);

    const ended = step(&state, NSEventPhaseEnded, 0, 0, 0, 0.02);
    try std.testing.expectEqual(@as(usize, 1), ended.len);
    try std.testing.expectEqual(Phase.end, ended.items[0].phase);

    // The momentum tail arrives after the end and must produce nothing.
    var tail = step(&state, 0, NSEventPhaseBegan, 18, 0, 0.03);
    try std.testing.expectEqual(@as(usize, 0), tail.len);
    tail = step(&state, 0, NSEventPhaseChanged, 9, 0, 0.05);
    try std.testing.expectEqual(@as(usize, 0), tail.len);
}

test "velocity is points per second from the last sample pair" {
    var state = State{};
    _ = step(&state, NSEventPhaseBegan, 0, 0, 0, 0);
    _ = step(&state, NSEventPhaseChanged, 0, 20, 0, 0.10);
    // 12 points over 0.01s -> 1200 pt/s.
    _ = step(&state, NSEventPhaseChanged, 0, 12, 0, 0.11);

    const ended = step(&state, NSEventPhaseEnded, 0, 0, 0, 0.12);
    try std.testing.expectApproxEqAbs(@as(f64, 1200), ended.items[0].velocity_x, 0.001);
}

test "a cancelled gesture still ends, and an unclaimed one stays silent" {
    var state = State{};
    _ = step(&state, NSEventPhaseBegan, 0, 0, 0, 0);
    _ = step(&state, NSEventPhaseChanged, 0, 20, 0, 0.01);
    try std.testing.expectEqual(@as(usize, 1), step(&state, NSEventPhaseCancelled, 0, 0, 0, 0.02).len);

    // A gesture that never crossed the axis lock emits no `end`: there was no
    // `begin` to balance it, and a stray `end` would settle a swipe that the
    // consumer never started.
    var quiet = State{};
    _ = step(&quiet, NSEventPhaseBegan, 0, 0, 0, 0);
    _ = step(&quiet, NSEventPhaseChanged, 0, 2, 0, 0.01);
    try std.testing.expectEqual(@as(usize, 0), step(&quiet, NSEventPhaseEnded, 0, 0, 0, 0.02).len);
}

test "a new gesture starts clean after the previous one ended" {
    var state = State{};
    _ = step(&state, NSEventPhaseBegan, 0, 0, 0, 0);
    _ = step(&state, NSEventPhaseChanged, 0, 20, 0, 0.01);
    _ = step(&state, NSEventPhaseEnded, 0, 0, 0, 0.02);

    // Stale accumulators would let a second gesture claim below the axis lock.
    _ = step(&state, NSEventPhaseBegan, 0, 0, 0, 1.00);
    try std.testing.expectEqual(@as(usize, 0), step(&state, NSEventPhaseChanged, 0, 3, 0, 1.01).len);
}
