const std = @import("std");

/// Blocking mutex that works across Zig versions.
/// Uses std.Thread.Mutex if available, otherwise falls back to std.atomic.Mutex.
pub const Mutex = struct {
    inner: InnerMutex = inner_init,

    const has_thread_mutex = @hasDecl(std.Thread, "Mutex");

    const InnerMutex = if (has_thread_mutex) std.Thread.Mutex else std.atomic.Mutex;

    const inner_init: InnerMutex = if (has_thread_mutex) .{} else .unlocked;

    pub fn lock(self: *Mutex) void {
        if (has_thread_mutex) {
            self.inner.lock();
        } else {
            while (!self.inner.tryLock()) {
                std.atomic.spinLoopHint();
            }
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
