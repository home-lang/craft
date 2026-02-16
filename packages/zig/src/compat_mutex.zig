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
