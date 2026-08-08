/// Compatibility module for Zig 0.16
///
/// Provides replacements for APIs removed in Zig 0.16:
/// - std.time.timestamp() -> compat.timestamp()
/// - std.time.milliTimestamp() -> compat.milliTimestamp()
/// - std.time.Instant -> compat.Instant
/// - std.time.Timer -> compat.Timer
/// - std.Thread.Condition -> compat.Condition
/// - std.Thread.Mutex -> compat.Mutex
/// - std.crypto.random.bytes -> compat.randomBytes
const std = @import("std");
const builtin = @import("builtin");
const native_os = builtin.os.tag;

/// Fill a buffer with cryptographically secure random bytes.
///
/// Replaces `std.crypto.random.bytes`, which this Zig no longer provides. That
/// was not a cosmetic break: it is referenced from keychain, crypto and
/// api_crypto, so `zig test` on anything reaching them failed to compile and
/// took the whole suite with it.
///
/// Goes straight to the platform CSPRNG rather than seeding a userspace PRNG.
/// These bytes become encryption keys and tokens, and a generator seeded from a
/// clock is the classic way to make that look fine and not be.
pub fn randomBytes(buffer: []u8) void {
    if (buffer.len == 0) return;

    if (comptime native_os == .windows) {
        const advapi = struct {
            extern "advapi32" fn SystemFunction036(RandomBuffer: [*]u8, RandomBufferLength: u32) callconv(.c) u8;
        };
        // RtlGenRandom. Documented as never failing for a valid buffer, but the
        // result is checked rather than assumed — silently returning zeroed
        // "random" bytes is the worst possible failure for a key.
        if (advapi.SystemFunction036(buffer.ptr, @intCast(buffer.len)) == 0)
            @panic("compat.randomBytes: RtlGenRandom failed");
        return;
    }

    // arc4random_buf is present on macOS, iOS and the BSDs, and on glibc and
    // musl Linux. It cannot fail and never blocks after early boot, which is
    // why it is preferred over reading /dev/urandom.
    const libc = struct {
        extern "c" fn arc4random_buf(buf: [*]u8, nbytes: usize) callconv(.c) void;
    };
    libc.arc4random_buf(buffer.ptr, buffer.len);
}

/// Returns seconds since Unix epoch (replacement for std.time.timestamp).
/// Returns 0 if the system clock can't be read, so callers never observe the
/// undefined bytes that the previous implementation would propagate when
/// `clock_gettime` failed.
pub fn timestamp() i64 {
    if (comptime native_os == .windows) {
        return @as(i64, @intCast(windowsTimestamp()));
    }
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.REALTIME, &ts) != 0) return 0;
    return @as(i64, @intCast(ts.sec));
}

/// Returns milliseconds since Unix epoch (replacement for std.time.milliTimestamp)
pub fn milliTimestamp() i64 {
    if (comptime native_os == .windows) {
        return @as(i64, @intCast(windowsTimestamp())) * 1000;
    }
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.REALTIME, &ts) != 0) return 0;
    return @as(i64, @intCast(ts.sec)) * 1000 + @divTrunc(@as(i64, @intCast(ts.nsec)), 1_000_000);
}

/// Returns nanoseconds (monotonic) for duration measurement
pub fn nanoTimestamp() i128 {
    if (comptime native_os == .windows) {
        return @as(i128, @intCast(windowsTimestamp())) * 1_000_000_000;
    }
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.MONOTONIC, &ts) != 0) return 0;
    return @as(i128, ts.sec) * 1_000_000_000 + ts.nsec;
}

fn windowsTimestamp() u64 {
    // Windows FILETIME epoch is Jan 1, 1601; Unix epoch is Jan 1, 1970
    // Difference is 11644473600 seconds
    const windows = std.os.windows;
    const ticks: u64 = @intCast(windows.ntdll.RtlGetSystemTimePrecise());
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
