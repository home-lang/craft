/// Compatibility module for Zig 0.16
///
/// Provides replacements for APIs removed in Zig 0.16:
/// - std.time.timestamp() -> compat.timestamp()
/// - std.time.milliTimestamp() -> compat.milliTimestamp()
/// - std.time.Instant -> compat.Instant
/// - std.time.Timer -> compat.Timer
/// - std.Thread.Condition -> compat.Condition
/// - std.Thread.Mutex -> compat.Mutex
const std = @import("std");
const builtin = @import("builtin");
const native_os = builtin.os.tag;

const c = @cImport({
    @cInclude("time.h");
});

/// Returns seconds since Unix epoch (replacement for std.time.timestamp)
pub fn timestamp() i64 {
    if (comptime native_os == .windows) {
        return @as(i64, @intCast(windowsTimestamp()));
    }
    var ts: c.struct_timespec = undefined;
    _ = c.clock_gettime(c.CLOCK_REALTIME, &ts);
    return @as(i64, @intCast(ts.tv_sec));
}

/// Returns milliseconds since Unix epoch (replacement for std.time.milliTimestamp)
pub fn milliTimestamp() i64 {
    if (comptime native_os == .windows) {
        return @as(i64, @intCast(windowsTimestamp())) * 1000;
    }
    var ts: c.struct_timespec = undefined;
    _ = c.clock_gettime(c.CLOCK_REALTIME, &ts);
    return @as(i64, @intCast(ts.tv_sec)) * 1000 + @divTrunc(@as(i64, @intCast(ts.tv_nsec)), 1_000_000);
}

/// Returns nanoseconds (monotonic) for duration measurement
pub fn nanoTimestamp() i128 {
    if (comptime native_os == .windows) {
        return @as(i128, @intCast(windowsTimestamp())) * 1_000_000_000;
    }
    var ts: c.struct_timespec = undefined;
    _ = c.clock_gettime(c.CLOCK_MONOTONIC, &ts);
    return @as(i128, ts.tv_sec) * 1_000_000_000 + ts.tv_nsec;
}

fn windowsTimestamp() u64 {
    // Windows FILETIME epoch is Jan 1, 1601; Unix epoch is Jan 1, 1970
    // Difference is 11644473600 seconds
    const windows_c = @cImport({
        @cInclude("windows.h");
    });
    var ft: windows_c.FILETIME = undefined;
    windows_c.GetSystemTimeAsFileTime(&ft);
    const ticks = @as(u64, ft.dwHighDateTime) << 32 | ft.dwLowDateTime;
    return (ticks / 10_000_000) - 11_644_473_600;
}

/// Monotonic time point for measuring durations (replacement for std.time.Instant)
pub const Instant = struct {
    ns: i128,

    pub fn now() error{}!Instant {
        return .{ .ns = nanoTimestamp() };
    }

    pub fn since(self: Instant, earlier: Instant) u64 {
        const diff = self.ns - earlier.ns;
        if (diff < 0) return 0;
        return @as(u64, @intCast(diff));
    }
};

/// Simple timer for benchmarking (replacement for std.time.Timer)
pub const Timer = struct {
    start_ns: i128,

    pub fn start() error{}!Timer {
        return .{ .start_ns = nanoTimestamp() };
    }

    pub fn read(self: Timer) u64 {
        const now = nanoTimestamp();
        const diff = now - self.start_ns;
        if (diff < 0) return 0;
        return @as(u64, @intCast(diff));
    }

    pub fn lap(self: *Timer) u64 {
        const now = nanoTimestamp();
        const diff = now - self.start_ns;
        self.start_ns = now;
        if (diff < 0) return 0;
        return @as(u64, @intCast(diff));
    }

    pub fn reset(self: *Timer) void {
        self.start_ns = nanoTimestamp();
    }
};

/// Simple mutex using atomic operations (replacement for std.Thread.Mutex)
pub const Mutex = struct {
    state: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),

    pub fn lock(self: *Mutex) void {
        while (self.state.cmpxchgWeak(0, 1, .acquire, .monotonic) != null) {
            std.atomic.spinLoopHint();
        }
    }

    pub fn unlock(self: *Mutex) void {
        self.state.store(0, .release);
    }

    pub fn tryLock(self: *Mutex) bool {
        return self.state.cmpxchgWeak(0, 1, .acquire, .monotonic) == null;
    }
};

/// Simple condition-like signaling (replacement for std.Thread.Condition)
/// Uses atomic flag + spin wait since std.Io.Condition requires Io instance
pub const Condition = struct {
    flag: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),

    pub fn wait(self: *Condition, mutex: *Mutex) void {
        mutex.unlock();
        while (self.flag.load(.acquire) == 0) {
            std.atomic.spinLoopHint();
        }
        self.flag.store(0, .release);
        mutex.lock();
    }

    pub fn signal(self: *Condition) void {
        self.flag.store(1, .release);
    }

    pub fn broadcast(self: *Condition) void {
        self.flag.store(1, .release);
    }
};
