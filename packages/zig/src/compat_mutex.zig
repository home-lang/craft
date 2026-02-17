const std = @import("std");

/// Blocking mutex built on std.atomic.Mutex.
/// Provides lock()/unlock() semantics via spin-wait on tryLock().
/// In Zig 0.16, std.atomic.Mutex only provides tryLock() and unlock().
pub const Mutex = struct {
    inner: std.atomic.Mutex = .unlocked,

    pub fn lock(self: *Mutex) void {
        while (!self.inner.tryLock()) {
            std.atomic.spinLoopHint();
        }
    }

    pub fn unlock(self: *Mutex) void {
        self.inner.unlock();
    }

    pub fn tryLock(self: *Mutex) bool {
        return self.inner.tryLock();
    }
};

/// Condition variable replacement for std.Thread.Condition (removed in Zig 0.16).
/// Uses atomic flag + spin wait since std.Io.Condition requires an Io instance.
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
