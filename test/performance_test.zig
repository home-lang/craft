const std = @import("std");
const testing = std.testing;
const performance = @import("../src/performance.zig");

// Cache tests
test "Cache - initialization" {
    const allocator = testing.allocator;
    var cache = performance.Cache.init(allocator, 1024);
    defer cache.deinit();

    try testing.expectEqual(@as(usize, 1024), cache.max_size);
    try testing.expectEqual(@as(usize, 0), cache.current_size);
}

test "Cache - put and get" {
    const allocator = testing.allocator;
    var cache = performance.Cache.init(allocator, 1024);
    defer cache.deinit();

    try cache.put("key1", "value1");

    const result = cache.get("key1");
    try testing.expect(result != null);
    try testing.expectEqualStrings("value1", result.?);
}

test "Cache - get non-existent key" {
    const allocator = testing.allocator;
    var cache = performance.Cache.init(allocator, 1024);
    defer cache.deinit();

    const result = cache.get("non-existent");
    try testing.expectEqual(@as(?[]const u8, null), result);
}

test "Cache - multiple entries" {
    const allocator = testing.allocator;
    var cache = performance.Cache.init(allocator, 1024);
    defer cache.deinit();

    try cache.put("key1", "value1");
    try cache.put("key2", "value2");
    try cache.put("key3", "value3");

    try testing.expectEqualStrings("value1", cache.get("key1").?);
    try testing.expectEqualStrings("value2", cache.get("key2").?);
    try testing.expectEqualStrings("value3", cache.get("key3").?);
}

test "Cache - overwrite existing key" {
    const allocator = testing.allocator;
    var cache = performance.Cache.init(allocator, 1024);
    defer cache.deinit();

    try cache.put("key1", "original");
    try cache.put("key1", "updated");

    try testing.expectEqualStrings("updated", cache.get("key1").?);
}

test "Cache - remove entry" {
    const allocator = testing.allocator;
    var cache = performance.Cache.init(allocator, 1024);
    defer cache.deinit();

    try cache.put("key1", "value1");
    cache.remove("key1");

    const result = cache.get("key1");
    try testing.expectEqual(@as(?[]const u8, null), result);
}

test "Cache - remove non-existent key" {
    const allocator = testing.allocator;
    var cache = performance.Cache.init(allocator, 1024);
    defer cache.deinit();

    cache.remove("non-existent");
}

test "Cache - clear all entries" {
    const allocator = testing.allocator;
    var cache = performance.Cache.init(allocator, 1024);
    defer cache.deinit();

    try cache.put("key1", "value1");
    try cache.put("key2", "value2");

    cache.clear();

    try testing.expectEqual(@as(?[]const u8, null), cache.get("key1"));
    try testing.expectEqual(@as(?[]const u8, null), cache.get("key2"));
    try testing.expectEqual(@as(usize, 0), cache.current_size);
}

test "Cache - LRU eviction" {
    const allocator = testing.allocator;
    var cache = performance.Cache.init(allocator, 20);
    defer cache.deinit();

    try cache.put("key1", "value1");
    std.time.sleep(1_000_000); // Sleep 1ms

    try cache.put("key2", "value2");
    std.time.sleep(1_000_000);

    try cache.put("key3", "value3456789012345"); // This should trigger eviction

    // key1 should be evicted as it's the oldest
    try testing.expectEqual(@as(?[]const u8, null), cache.get("key1"));
    try testing.expect(cache.get("key2") != null);
    try testing.expect(cache.get("key3") != null);
}

test "Cache - access count increments" {
    const allocator = testing.allocator;
    var cache = performance.Cache.init(allocator, 1024);
    defer cache.deinit();

    try cache.put("key1", "value1");

    _ = cache.get("key1");
    _ = cache.get("key1");
    _ = cache.get("key1");

    // Access count should have incremented
}

test "Cache - getHitRate with empty cache" {
    const allocator = testing.allocator;
    var cache = performance.Cache.init(allocator, 1024);
    defer cache.deinit();

    const rate = cache.getHitRate();
    try testing.expectEqual(@as(f64, 0.0), rate);
}

test "Cache - getHitRate with entries" {
    const allocator = testing.allocator;
    var cache = performance.Cache.init(allocator, 1024);
    defer cache.deinit();

    try cache.put("key1", "value1");
    _ = cache.get("key1");

    const rate = cache.getHitRate();
    try testing.expect(rate > 0.0);
}

test "Cache - size tracking" {
    const allocator = testing.allocator;
    var cache = performance.Cache.init(allocator, 1024);
    defer cache.deinit();

    try cache.put("key1", "hello");
    try testing.expectEqual(@as(usize, 5), cache.current_size);

    try cache.put("key2", "world");
    try testing.expectEqual(@as(usize, 10), cache.current_size);

    cache.remove("key1");
    try testing.expectEqual(@as(usize, 5), cache.current_size);
}

// ObjectPool tests
fn createTestObject(allocator: std.mem.Allocator) !*anyopaque {
    const ptr = try allocator.create(i32);
    ptr.* = 42;
    return @ptrCast(ptr);
}

fn destroyTestObject(ptr: *anyopaque, allocator: std.mem.Allocator) void {
    const typed_ptr: *i32 = @ptrCast(@alignCast(ptr));
    allocator.destroy(typed_ptr);
}

fn resetTestObject(ptr: *anyopaque) void {
    const typed_ptr: *i32 = @ptrCast(@alignCast(ptr));
    typed_ptr.* = 0;
}

test "ObjectPool - initialization" {
    const allocator = testing.allocator;
    var pool = performance.ObjectPool.init(allocator, 10, createTestObject, destroyTestObject, resetTestObject);
    defer pool.deinit();

    try testing.expectEqual(@as(usize, 10), pool.max_size);
}

test "ObjectPool - acquire object" {
    const allocator = testing.allocator;
    var pool = performance.ObjectPool.init(allocator, 10, createTestObject, destroyTestObject, resetTestObject);
    defer pool.deinit();

    const obj = try pool.acquire();
    try testing.expect(obj != undefined);
}

test "ObjectPool - acquire and release" {
    const allocator = testing.allocator;
    var pool = performance.ObjectPool.init(allocator, 10, createTestObject, destroyTestObject, resetTestObject);
    defer pool.deinit();

    const obj = try pool.acquire();
    try testing.expectEqual(@as(usize, 1), pool.inUseCount());

    try pool.release(obj);
    try testing.expectEqual(@as(usize, 0), pool.inUseCount());
    try testing.expectEqual(@as(usize, 1), pool.availableCount());
}

test "ObjectPool - reuse released object" {
    const allocator = testing.allocator;
    var pool = performance.ObjectPool.init(allocator, 10, createTestObject, destroyTestObject, resetTestObject);
    defer pool.deinit();

    const obj1 = try pool.acquire();
    try pool.release(obj1);

    const obj2 = try pool.acquire();
    try testing.expectEqual(obj1, obj2);
}

test "ObjectPool - exhaust pool" {
    const allocator = testing.allocator;
    var pool = performance.ObjectPool.init(allocator, 2, createTestObject, destroyTestObject, null);
    defer pool.deinit();

    _ = try pool.acquire();
    _ = try pool.acquire();

    const result = pool.acquire();
    try testing.expectError(error.PoolExhausted, result);
}

test "ObjectPool - availableCount" {
    const allocator = testing.allocator;
    var pool = performance.ObjectPool.init(allocator, 10, createTestObject, destroyTestObject, null);
    defer pool.deinit();

    try testing.expectEqual(@as(usize, 0), pool.availableCount());

    const obj = try pool.acquire();
    try pool.release(obj);

    try testing.expectEqual(@as(usize, 1), pool.availableCount());
}

test "ObjectPool - inUseCount" {
    const allocator = testing.allocator;
    var pool = performance.ObjectPool.init(allocator, 10, createTestObject, destroyTestObject, null);
    defer pool.deinit();

    try testing.expectEqual(@as(usize, 0), pool.inUseCount());

    _ = try pool.acquire();
    try testing.expectEqual(@as(usize, 1), pool.inUseCount());

    _ = try pool.acquire();
    try testing.expectEqual(@as(usize, 2), pool.inUseCount());
}

// LazyLoader tests
var lazy_loaded = false;

fn lazyLoadFn() !void {
    lazy_loaded = true;
}

test "LazyLoader - initialization" {
    var loader = performance.LazyLoader.init(lazyLoadFn);

    try testing.expect(!loader.loaded);
}

test "LazyLoader - load once" {
    lazy_loaded = false;
    var loader = performance.LazyLoader.init(lazyLoadFn);

    try loader.load();

    try testing.expect(loader.isLoaded());
    try testing.expect(lazy_loaded);
}

test "LazyLoader - load multiple times only executes once" {
    lazy_loaded = false;
    var loader = performance.LazyLoader.init(lazyLoadFn);

    try loader.load();
    try loader.load();
    try loader.load();

    try testing.expect(loader.isLoaded());
}

test "LazyLoader - isLoaded before loading" {
    var loader = performance.LazyLoader.init(lazyLoadFn);

    try testing.expect(!loader.isLoaded());
}

// Debouncer tests
var debouncer_call_count: usize = 0;

fn debouncerCallback() void {
    debouncer_call_count += 1;
}

test "Debouncer - initialization" {
    var debouncer = performance.Debouncer.init(100, debouncerCallback);

    try testing.expectEqual(@as(u64, 100), debouncer.delay_ms);
    try testing.expectEqual(@as(i64, 0), debouncer.last_call);
}

test "Debouncer - call updates last_call" {
    var debouncer = performance.Debouncer.init(100, debouncerCallback);

    debouncer.call();

    try testing.expect(debouncer.last_call > 0);
}

test "Debouncer - shouldExecute after delay" {
    var debouncer = performance.Debouncer.init(1, debouncerCallback);

    debouncer.call();
    std.time.sleep(2_000_000); // Sleep 2ms

    try testing.expect(debouncer.shouldExecute());
}

test "Debouncer - shouldExecute before delay" {
    var debouncer = performance.Debouncer.init(1000, debouncerCallback);

    debouncer.call();

    try testing.expect(!debouncer.shouldExecute());
}

// Throttler tests
var throttler_call_count: usize = 0;

fn throttlerCallback() void {
    throttler_call_count += 1;
}

test "Throttler - initialization" {
    var throttler = performance.Throttler.init(100, throttlerCallback);

    try testing.expectEqual(@as(u64, 100), throttler.interval_ms);
    try testing.expectEqual(@as(i64, 0), throttler.last_execution);
}

test "Throttler - call executes on first call" {
    throttler_call_count = 0;
    var throttler = performance.Throttler.init(100, throttlerCallback);

    throttler.call();

    try testing.expectEqual(@as(usize, 1), throttler_call_count);
}

test "Throttler - call throttles rapid calls" {
    throttler_call_count = 0;
    var throttler = performance.Throttler.init(100, throttlerCallback);

    throttler.call();
    throttler.call();
    throttler.call();

    try testing.expectEqual(@as(usize, 1), throttler_call_count);
}

test "Throttler - call executes after interval" {
    throttler_call_count = 0;
    var throttler = performance.Throttler.init(1, throttlerCallback);

    throttler.call();
    std.time.sleep(2_000_000); // Sleep 2ms
    throttler.call();

    try testing.expectEqual(@as(usize, 2), throttler_call_count);
}

// BatchProcessor tests
var batch_processed_items: []const *anyopaque = &[_]*anyopaque{};

fn batchProcessFn(items: []const *anyopaque) void {
    batch_processed_items = items;
}

test "BatchProcessor - initialization" {
    const allocator = testing.allocator;
    var processor = performance.BatchProcessor.init(allocator, 10, batchProcessFn);
    defer processor.deinit();

    try testing.expectEqual(@as(usize, 10), processor.batch_size);
}

test "BatchProcessor - add item" {
    const allocator = testing.allocator;
    var processor = performance.BatchProcessor.init(allocator, 10, batchProcessFn);
    defer processor.deinit();

    var item: i32 = 42;
    try processor.add(@ptrCast(&item));

    try testing.expectEqual(@as(usize, 1), processor.items.items.len);
}

test "BatchProcessor - auto flush on batch size" {
    const allocator = testing.allocator;
    var processor = performance.BatchProcessor.init(allocator, 2, batchProcessFn);
    defer processor.deinit();

    var item1: i32 = 1;
    var item2: i32 = 2;

    try processor.add(@ptrCast(&item1));
    try processor.add(@ptrCast(&item2));

    try testing.expectEqual(@as(usize, 0), processor.items.items.len);
    try testing.expectEqual(@as(usize, 2), batch_processed_items.len);
}

test "BatchProcessor - manual flush" {
    const allocator = testing.allocator;
    batch_processed_items = &[_]*anyopaque{};
    var processor = performance.BatchProcessor.init(allocator, 10, batchProcessFn);
    defer processor.deinit();

    var item: i32 = 42;
    try processor.add(@ptrCast(&item));

    processor.flush();

    try testing.expectEqual(@as(usize, 1), batch_processed_items.len);
    try testing.expectEqual(@as(usize, 0), processor.items.items.len);
}

test "BatchProcessor - flush empty" {
    const allocator = testing.allocator;
    batch_processed_items = &[_]*anyopaque{};
    var processor = performance.BatchProcessor.init(allocator, 10, batchProcessFn);
    defer processor.deinit();

    processor.flush();

    try testing.expectEqual(@as(usize, 0), batch_processed_items.len);
}

// Memoizer tests
test "Memoizer - initialization" {
    const allocator = testing.allocator;
    var memoizer = performance.Memoizer.init(allocator);
    defer memoizer.deinit();
}

test "Memoizer - put and get" {
    const allocator = testing.allocator;
    var memoizer = performance.Memoizer.init(allocator);
    defer memoizer.deinit();

    try memoizer.put("key1", "value1");

    const result = memoizer.get("key1");
    try testing.expect(result != null);
    try testing.expectEqualStrings("value1", result.?);
}

test "Memoizer - get non-existent key" {
    const allocator = testing.allocator;
    var memoizer = performance.Memoizer.init(allocator);
    defer memoizer.deinit();

    const result = memoizer.get("non-existent");
    try testing.expectEqual(@as(?[]const u8, null), result);
}

test "Memoizer - multiple entries" {
    const allocator = testing.allocator;
    var memoizer = performance.Memoizer.init(allocator);
    defer memoizer.deinit();

    try memoizer.put("key1", "value1");
    try memoizer.put("key2", "value2");
    try memoizer.put("key3", "value3");

    try testing.expectEqualStrings("value1", memoizer.get("key1").?);
    try testing.expectEqualStrings("value2", memoizer.get("key2").?);
    try testing.expectEqualStrings("value3", memoizer.get("key3").?);
}

test "Memoizer - clear" {
    const allocator = testing.allocator;
    var memoizer = performance.Memoizer.init(allocator);
    defer memoizer.deinit();

    try memoizer.put("key1", "value1");
    try memoizer.put("key2", "value2");

    memoizer.clear();

    try testing.expectEqual(@as(?[]const u8, null), memoizer.get("key1"));
    try testing.expectEqual(@as(?[]const u8, null), memoizer.get("key2"));
}

// WorkQueue tests
var work_executed = false;

fn workFunction(ctx: *anyopaque) void {
    _ = ctx;
    work_executed = true;
}

test "WorkQueue - initialization" {
    const allocator = testing.allocator;
    var queue = try performance.WorkQueue.init(allocator, 2);
    defer queue.deinit();

    try testing.expect(queue.running);
    try testing.expectEqual(@as(usize, 2), queue.workers.items.len);
}

test "WorkQueue - submit task" {
    const allocator = testing.allocator;
    var queue = try performance.WorkQueue.init(allocator, 1);
    defer queue.deinit();

    work_executed = false;
    var ctx: i32 = 42;

    try queue.submit(workFunction, @ptrCast(&ctx));

    std.time.sleep(10_000_000); // Give worker time to execute
}

// ResourcePreloader tests
test "ResourcePreloader - initialization" {
    const allocator = testing.allocator;
    var preloader = performance.ResourcePreloader.init(allocator);
    defer preloader.deinit();
}

test "ResourcePreloader - preload resource" {
    const allocator = testing.allocator;
    var preloader = performance.ResourcePreloader.init(allocator);
    defer preloader.deinit();

    try preloader.preload("/path/to/resource");

    const result = preloader.get("/path/to/resource");
    try testing.expect(result != null);
}

test "ResourcePreloader - get non-preloaded resource" {
    const allocator = testing.allocator;
    var preloader = performance.ResourcePreloader.init(allocator);
    defer preloader.deinit();

    const result = preloader.get("/non/existent/resource");
    try testing.expectEqual(@as(?[]const u8, null), result);
}

test "ResourcePreloader - isLoading" {
    const allocator = testing.allocator;
    var preloader = performance.ResourcePreloader.init(allocator);
    defer preloader.deinit();

    try preloader.preload("/path/to/resource");

    // After preload completes, should not be loading
    try testing.expect(!preloader.isLoading("/path/to/resource"));
}

test "ResourcePreloader - preload already loaded" {
    const allocator = testing.allocator;
    var preloader = performance.ResourcePreloader.init(allocator);
    defer preloader.deinit();

    try preloader.preload("/path/to/resource");
    try preloader.preload("/path/to/resource");

    const result = preloader.get("/path/to/resource");
    try testing.expect(result != null);
}

test "ResourcePreloader - multiple resources" {
    const allocator = testing.allocator;
    var preloader = performance.ResourcePreloader.init(allocator);
    defer preloader.deinit();

    try preloader.preload("/resource1");
    try preloader.preload("/resource2");
    try preloader.preload("/resource3");

    try testing.expect(preloader.get("/resource1") != null);
    try testing.expect(preloader.get("/resource2") != null);
    try testing.expect(preloader.get("/resource3") != null);
}
