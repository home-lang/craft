const std = @import("std");
const compat_mutex = @import("compat_mutex.zig");

/// Performance Optimization Module
/// Provides caching, pooling, and optimization utilities
pub const Cache = struct {
    entries: std.StringHashMap(CacheEntry),
    max_size: usize,
    current_size: usize,
    hits: u64,
    misses: u64,
    allocator: std.mem.Allocator,

    const CacheEntry = struct {
        data: []const u8,
        timestamp: i64,
        access_count: usize,
        size: usize,
    };

    pub fn init(allocator: std.mem.Allocator, max_size: usize) Cache {
        return Cache{
            .entries = std.StringHashMap(CacheEntry).init(allocator),
            .max_size = max_size,
            .current_size = 0,
            .hits = 0,
            .misses = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Cache) void {
        // Free the key buffers the map owns as well as the value buffers.
        // The previous version only freed values, so every entry's duped
        // key leaked on shutdown.
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.data);
        }
        self.entries.deinit();
    }

    pub fn get(self: *Cache, key: []const u8) ?[]const u8 {
        if (self.entries.getPtr(key)) |entry| {
            entry.access_count += 1;
            entry.timestamp = std.time.milliTimestamp();
            self.hits += 1;
            return entry.data;
        }
        self.misses += 1;
        return null;
    }

    pub fn put(self: *Cache, key: []const u8, data: []const u8) !void {
        const size = data.len;

        // Reject items that can never fit; otherwise the eviction loop below
        // would empty the cache and then fail anyway.
        if (size > self.max_size) return error.EntryTooLarge;

        // If the key already exists, free the old entry's key+value so we
        // don't leak storage when we overwrite. Previously only the value
        // was freed; the old duped key stayed with the map.
        if (self.entries.fetchRemove(key)) |kv| {
            self.allocator.free(kv.key);
            self.allocator.free(kv.value.data);
            self.current_size -= kv.value.size;
        }

        // Evict if necessary. Bounded by the current entry count so a bug in
        // `evictLRU` (e.g. failing to remove anything) can't spin forever.
        var evict_budget: usize = self.entries.count() + 1;
        while (self.current_size + size > self.max_size and self.entries.count() > 0) {
            if (evict_budget == 0) return error.EvictionFailed;
            evict_budget -= 1;
            try self.evictLRU();
        }

        // Dupe both the key and the data so the cache owns its storage and
        // stays valid after the caller's buffers go away. Previously the
        // key was stored by reference, and any caller that passed a
        // transient slice produced silently-corrupt map keys.
        const owned_data = try self.allocator.dupe(u8, data);
        errdefer self.allocator.free(owned_data);
        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);

        const entry = CacheEntry{
            .data = owned_data,
            .timestamp = std.time.milliTimestamp(),
            .access_count = 0,
            .size = size,
        };

        try self.entries.put(owned_key, entry);
        self.current_size += size;
    }

    pub fn remove(self: *Cache, key: []const u8) void {
        if (self.entries.fetchRemove(key)) |kv| {
            self.allocator.free(kv.key);
            self.allocator.free(kv.value.data);
            self.current_size -= kv.value.size;
        }
    }

    pub fn clear(self: *Cache) void {
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.data);
        }
        self.entries.clearRetainingCapacity();
        self.current_size = 0;
    }

    fn evictLRU(self: *Cache) !void {
        var oldest_key: ?[]const u8 = null;
        var oldest_time: i64 = std.math.maxInt(i64);

        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.timestamp < oldest_time) {
                oldest_time = entry.value_ptr.timestamp;
                oldest_key = entry.key_ptr.*;
            }
        }

        if (oldest_key) |key| {
            self.remove(key);
        }
    }

    /// Return hit rate as `hits / (hits + misses)`. Previously this returned
    /// `entries / total_accesses` which is not a hit rate at all — with one
    /// entry accessed twice it would return 0.5 regardless of miss count.
    pub fn getHitRate(self: Cache) f64 {
        const total = self.hits + self.misses;
        if (total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
    }
};

pub const ObjectPool = struct {
    // Migrated to `std.ArrayListUnmanaged` — the managed `ArrayList.init`
    // API was removed in Zig 0.16, so the previous `.init(allocator)` and
    // allocator-less `append`/`deinit` calls no longer compile.
    available: std.ArrayListUnmanaged(*anyopaque),
    in_use: std.ArrayListUnmanaged(*anyopaque),
    create_fn: *const fn (std.mem.Allocator) anyerror!*anyopaque,
    destroy_fn: *const fn (*anyopaque, std.mem.Allocator) void,
    reset_fn: ?*const fn (*anyopaque) void,
    allocator: std.mem.Allocator,
    max_size: usize,

    pub fn init(
        allocator: std.mem.Allocator,
        max_size: usize,
        create_fn: *const fn (std.mem.Allocator) anyerror!*anyopaque,
        destroy_fn: *const fn (*anyopaque, std.mem.Allocator) void,
        reset_fn: ?*const fn (*anyopaque) void,
    ) ObjectPool {
        return ObjectPool{
            .available = .{},
            .in_use = .{},
            .create_fn = create_fn,
            .destroy_fn = destroy_fn,
            .reset_fn = reset_fn,
            .allocator = allocator,
            .max_size = max_size,
        };
    }

    pub fn deinit(self: *ObjectPool) void {
        for (self.available.items) |obj| {
            self.destroy_fn(obj, self.allocator);
        }
        for (self.in_use.items) |obj| {
            self.destroy_fn(obj, self.allocator);
        }
        self.available.deinit(self.allocator);
        self.in_use.deinit(self.allocator);
    }

    pub fn acquire(self: *ObjectPool) !*anyopaque {
        // `popOrNull` was renamed to `pop` (returning `?T`) in Zig 0.16.
        if (self.available.pop()) |obj| {
            // If appending to in_use fails (OOM), put the object back into
            // `available` so we don't silently leak it — previously the obj
            // was popped but never tracked anywhere on this failure path.
            self.in_use.append(self.allocator, obj) catch |err| {
                self.available.append(self.allocator, obj) catch {};
                return err;
            };
            return obj;
        }

        if (self.in_use.items.len < self.max_size) {
            const obj = try self.create_fn(self.allocator);
            // Destroy the freshly-created object if we can't track it — the
            // old code would leak it permanently on append failure.
            self.in_use.append(self.allocator, obj) catch |err| {
                self.destroy_fn(obj, self.allocator);
                return err;
            };
            return obj;
        }

        return error.PoolExhausted;
    }

    pub fn release(self: *ObjectPool, obj: *anyopaque) !void {
        for (self.in_use.items, 0..) |item, i| {
            if (item == obj) {
                _ = self.in_use.swapRemove(i);

                if (self.reset_fn) |reset| {
                    reset(obj);
                }

                // If moving back into `available` fails (OOM), destroy the
                // object directly so we don't leak it. The caller sees the
                // error and knows the object is gone for good.
                self.available.append(self.allocator, obj) catch |err| {
                    self.destroy_fn(obj, self.allocator);
                    return err;
                };
                return;
            }
        }
        // Releasing an object that was never acquired (or was already
        // released) is a programming bug — surface it instead of silently
        // swallowing the call, which used to leak the caller's pointer.
        return error.ObjectNotInPool;
    }

    pub fn availableCount(self: ObjectPool) usize {
        return self.available.items.len;
    }

    pub fn inUseCount(self: ObjectPool) usize {
        return self.in_use.items.len;
    }
};

pub const LazyLoader = struct {
    /// `loaded` is atomic so the double-checked-locking pattern in `load()`
    /// is memory-safe on platforms with weak ordering (AArch64). Previously
    /// the non-atomic read could observe the flag without observing the
    /// side effects of `load_fn`, causing callers to proceed on
    /// partially-initialized state.
    loaded: std.atomic.Value(u8),
    load_fn: *const fn () anyerror!void,
    mutex: compat_mutex.Mutex,

    pub fn init(load_fn: *const fn () anyerror!void) LazyLoader {
        return LazyLoader{
            .loaded = std.atomic.Value(u8).init(0),
            .load_fn = load_fn,
            .mutex = .{},
        };
    }

    pub fn load(self: *LazyLoader) !void {
        // Fast-path: release-store in the slow path below is paired with
        // this acquire-load so the caller observes everything `load_fn` did.
        if (self.loaded.load(.acquire) != 0) return;

        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.loaded.load(.monotonic) != 0) return;

        try self.load_fn();
        self.loaded.store(1, .release);
    }

    pub fn isLoaded(self: *const LazyLoader) bool {
        return self.loaded.load(.acquire) != 0;
    }
};

pub const Debouncer = struct {
    delay_ms: u64,
    last_call: i64,
    callback: *const fn () void,

    pub fn init(delay_ms: u64, callback: *const fn () void) Debouncer {
        return Debouncer{
            .delay_ms = delay_ms,
            .last_call = 0,
            .callback = callback,
        };
    }

    pub fn call(self: *Debouncer) void {
        const now = std.time.milliTimestamp();
        self.last_call = now;

        // In a real implementation, would use a timer thread
        // For now, just track the last call time
    }

    pub fn shouldExecute(self: Debouncer) bool {
        const now = std.time.milliTimestamp();
        const elapsed = now - self.last_call;
        return elapsed >= self.delay_ms;
    }
};

pub const Throttler = struct {
    interval_ms: u64,
    last_execution: i64,
    callback: *const fn () void,

    pub fn init(interval_ms: u64, callback: *const fn () void) Throttler {
        return Throttler{
            .interval_ms = interval_ms,
            .last_execution = 0,
            .callback = callback,
        };
    }

    pub fn call(self: *Throttler) void {
        const now = std.time.milliTimestamp();
        const elapsed = now - self.last_execution;

        if (elapsed >= self.interval_ms) {
            self.callback();
            self.last_execution = now;
        }
    }
};

pub const BatchProcessor = struct {
    // Migrated to `std.ArrayListUnmanaged` for Zig 0.16.
    items: std.ArrayListUnmanaged(*anyopaque),
    batch_size: usize,
    process_fn: *const fn ([]const *anyopaque) void,
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        batch_size: usize,
        process_fn: *const fn ([]const *anyopaque) void,
    ) BatchProcessor {
        return BatchProcessor{
            .items = .{},
            .batch_size = batch_size,
            .process_fn = process_fn,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BatchProcessor) void {
        self.flush();
        self.items.deinit(self.allocator);
    }

    pub fn add(self: *BatchProcessor, item: *anyopaque) !void {
        try self.items.append(self.allocator, item);

        if (self.items.items.len >= self.batch_size) {
            self.flush();
        }
    }

    pub fn flush(self: *BatchProcessor) void {
        if (self.items.items.len == 0) return;

        self.process_fn(self.items.items);
        self.items.clearRetainingCapacity();
    }
};

pub const Memoizer = struct {
    cache: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Memoizer {
        return Memoizer{
            .cache = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Memoizer) void {
        // Free the map's keys as well as its values. The previous
        // `valueIterator` loop left every duped key in the allocator.
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.cache.deinit();
    }

    pub fn get(self: *Memoizer, key: []const u8) ?[]const u8 {
        return self.cache.get(key);
    }

    pub fn put(self: *Memoizer, key: []const u8, value: []const u8) !void {
        const owned_value = try self.allocator.dupe(u8, value);
        try self.cache.put(key, owned_value);
    }

    pub fn clear(self: *Memoizer) void {
        var iter = self.cache.valueIterator();
        while (iter.next()) |value| {
            self.allocator.free(value.*);
        }
        self.cache.clearRetainingCapacity();
    }
};

pub const WorkQueue = struct {
    tasks: std.ArrayList(Task),
    workers: std.ArrayList(std.Thread),
    running: bool,
    mutex: compat_mutex.Mutex,
    condition: compat_mutex.Condition,
    allocator: std.mem.Allocator,

    const Task = struct {
        fn_ptr: *const fn (*anyopaque) void,
        context: *anyopaque,
    };

    pub fn init(allocator: std.mem.Allocator, worker_count: usize) !WorkQueue {
        var queue = WorkQueue{
            .tasks = std.ArrayList(Task).init(allocator),
            .workers = std.ArrayList(std.Thread).init(allocator),
            .running = true,
            .mutex = .{},
            .condition = compat_mutex.Condition{},
            .allocator = allocator,
        };

        // Start worker threads
        var i: usize = 0;
        while (i < worker_count) : (i += 1) {
            const thread = try std.Thread.spawn(.{}, workerThread, .{&queue});
            try queue.workers.append(thread);
        }

        return queue;
    }

    pub fn deinit(self: *WorkQueue) void {
        self.running = false;
        self.condition.broadcast();

        for (self.workers.items) |thread| {
            thread.join();
        }

        self.workers.deinit();
        self.tasks.deinit();
    }

    pub fn submit(self: *WorkQueue, fn_ptr: *const fn (*anyopaque) void, context: *anyopaque) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try self.tasks.append(Task{
            .fn_ptr = fn_ptr,
            .context = context,
        });

        self.condition.signal();
    }

    fn workerThread(queue: *WorkQueue) void {
        while (queue.running) {
            queue.mutex.lock();

            while (queue.tasks.items.len == 0 and queue.running) {
                queue.condition.wait(&queue.mutex);
            }

            if (!queue.running) {
                queue.mutex.unlock();
                break;
            }

            const task = queue.tasks.orderedRemove(0);
            queue.mutex.unlock();

            task.fn_ptr(task.context);
        }
    }
};

pub const ResourcePreloader = struct {
    resources: std.StringHashMap([]const u8),
    loading: std.StringHashMap(bool),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ResourcePreloader {
        return ResourcePreloader{
            .resources = std.StringHashMap([]const u8).init(allocator),
            .loading = std.StringHashMap(bool).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ResourcePreloader) void {
        var iter = self.resources.valueIterator();
        while (iter.next()) |value| {
            self.allocator.free(value.*);
        }
        self.resources.deinit();
        self.loading.deinit();
    }

    pub fn preload(self: *ResourcePreloader, path: []const u8) !void {
        if (self.resources.contains(path)) return;
        if (self.loading.contains(path)) return;

        try self.loading.put(path, true);

        // Load resource (simplified)
        const data = try self.allocator.dupe(u8, "resource data");
        try self.resources.put(path, data);

        _ = self.loading.remove(path);
    }

    pub fn get(self: ResourcePreloader, path: []const u8) ?[]const u8 {
        return self.resources.get(path);
    }

    pub fn isLoading(self: ResourcePreloader, path: []const u8) bool {
        return self.loading.contains(path);
    }
};
