const std = @import("std");
const testing = std.testing;
const memory = @import("../src/memory.zig");

test "MemoryPool - init and deinit" {
    var pool = memory.MemoryPool.init(testing.allocator);
    defer pool.deinit();

    try testing.expect(true);
}

test "MemoryPool - allocator" {
    var pool = memory.MemoryPool.init(testing.allocator);
    defer pool.deinit();

    const alloc = pool.allocator();
    const data = try alloc.alloc(u8, 100);
    try testing.expectEqual(@as(usize, 100), data.len);
}

test "MemoryPool - reset retains capacity" {
    var pool = memory.MemoryPool.init(testing.allocator);
    defer pool.deinit();

    const alloc = pool.allocator();
    _ = try alloc.alloc(u8, 100);

    pool.reset();

    const data2 = try alloc.alloc(u8, 50);
    try testing.expectEqual(@as(usize, 50), data2.len);
}

test "MemoryPool - resetFree" {
    var pool = memory.MemoryPool.init(testing.allocator);
    defer pool.deinit();

    const alloc = pool.allocator();
    _ = try alloc.alloc(u8, 100);

    pool.resetFree();

    const data2 = try alloc.alloc(u8, 50);
    try testing.expectEqual(@as(usize, 50), data2.len);
}

test "TempAllocator - init and allocator" {
    var buffer: [1024]u8 = undefined;
    var temp = memory.TempAllocator.init(&buffer);

    const alloc = temp.allocator();
    const data = try alloc.alloc(u8, 100);
    try testing.expectEqual(@as(usize, 100), data.len);
}

test "TempAllocator - reset" {
    var buffer: [1024]u8 = undefined;
    var temp = memory.TempAllocator.init(&buffer);

    const alloc = temp.allocator();
    _ = try alloc.alloc(u8, 100);

    temp.reset();

    const data2 = try alloc.alloc(u8, 200);
    try testing.expectEqual(@as(usize, 200), data2.len);
}

test "TempAllocator - multiple allocations" {
    var buffer: [1024]u8 = undefined;
    var temp = memory.TempAllocator.init(&buffer);

    const alloc = temp.allocator();
    const data1 = try alloc.alloc(u8, 100);
    const data2 = try alloc.alloc(u8, 200);
    const data3 = try alloc.alloc(u8, 50);

    try testing.expectEqual(@as(usize, 100), data1.len);
    try testing.expectEqual(@as(usize, 200), data2.len);
    try testing.expectEqual(@as(usize, 50), data3.len);
}

test "MemoryStats - initialization" {
    const stats = memory.MemoryStats{};

    try testing.expectEqual(@as(usize, 0), stats.allocations);
    try testing.expectEqual(@as(usize, 0), stats.deallocations);
    try testing.expectEqual(@as(usize, 0), stats.bytes_allocated);
    try testing.expectEqual(@as(usize, 0), stats.bytes_freed);
    try testing.expectEqual(@as(usize, 0), stats.peak_memory);
    try testing.expectEqual(@as(usize, 0), stats.current_memory);
}

test "MemoryStats - recordAlloc" {
    var stats = memory.MemoryStats{};

    stats.recordAlloc(100);

    try testing.expectEqual(@as(usize, 1), stats.allocations);
    try testing.expectEqual(@as(usize, 100), stats.bytes_allocated);
    try testing.expectEqual(@as(usize, 100), stats.current_memory);
    try testing.expectEqual(@as(usize, 100), stats.peak_memory);
}

test "MemoryStats - recordAlloc multiple times" {
    var stats = memory.MemoryStats{};

    stats.recordAlloc(100);
    stats.recordAlloc(200);
    stats.recordAlloc(50);

    try testing.expectEqual(@as(usize, 3), stats.allocations);
    try testing.expectEqual(@as(usize, 350), stats.bytes_allocated);
    try testing.expectEqual(@as(usize, 350), stats.current_memory);
    try testing.expectEqual(@as(usize, 350), stats.peak_memory);
}

test "MemoryStats - recordFree" {
    var stats = memory.MemoryStats{};

    stats.recordAlloc(100);
    stats.recordFree(50);

    try testing.expectEqual(@as(usize, 1), stats.deallocations);
    try testing.expectEqual(@as(usize, 50), stats.bytes_freed);
    try testing.expectEqual(@as(usize, 50), stats.current_memory);
}

test "MemoryStats - peak memory tracking" {
    var stats = memory.MemoryStats{};

    stats.recordAlloc(100);
    try testing.expectEqual(@as(usize, 100), stats.peak_memory);

    stats.recordAlloc(200);
    try testing.expectEqual(@as(usize, 300), stats.peak_memory);

    stats.recordFree(150);
    try testing.expectEqual(@as(usize, 300), stats.peak_memory); // Peak should remain
    try testing.expectEqual(@as(usize, 150), stats.current_memory);
}

test "MemoryStats - print does not crash" {
    var stats = memory.MemoryStats{};
    stats.recordAlloc(100);
    stats.recordFree(50);

    stats.print();

    try testing.expect(true);
}

test "TrackingAllocator - init" {
    var tracker = memory.TrackingAllocator.init(testing.allocator);
    const stats = tracker.getStats();

    try testing.expectEqual(@as(usize, 0), stats.allocations);
    try testing.expectEqual(@as(usize, 0), stats.deallocations);
}

test "TrackingAllocator - allocator and tracking" {
    var tracker = memory.TrackingAllocator.init(testing.allocator);
    const alloc = tracker.allocator();

    const data = try alloc.alloc(u8, 100);
    defer alloc.free(data);

    const stats = tracker.getStats();
    try testing.expect(stats.allocations > 0);
    try testing.expect(stats.bytes_allocated >= 100);
}

test "TrackingAllocator - track multiple allocations" {
    var tracker = memory.TrackingAllocator.init(testing.allocator);
    const alloc = tracker.allocator();

    const data1 = try alloc.alloc(u8, 100);
    const data2 = try alloc.alloc(u8, 200);
    const data3 = try alloc.alloc(u8, 50);

    defer alloc.free(data1);
    defer alloc.free(data2);
    defer alloc.free(data3);

    const stats = tracker.getStats();
    try testing.expect(stats.allocations >= 3);
    try testing.expect(stats.bytes_allocated >= 350);
}

test "TrackingAllocator - track deallocations" {
    var tracker = memory.TrackingAllocator.init(testing.allocator);
    const alloc = tracker.allocator();

    const data = try alloc.alloc(u8, 100);
    alloc.free(data);

    const stats = tracker.getStats();
    try testing.expect(stats.deallocations > 0);
    try testing.expect(stats.bytes_freed >= 100);
}

test "TrackingAllocator - printStats does not crash" {
    var tracker = memory.TrackingAllocator.init(testing.allocator);
    const alloc = tracker.allocator();

    const data = try alloc.alloc(u8, 100);
    defer alloc.free(data);

    tracker.printStats();

    try testing.expect(true);
}

test "createArena - helper function" {
    var pool = try memory.createArena(testing.allocator);
    defer pool.deinit();

    const alloc = pool.allocator();
    const data = try alloc.alloc(u8, 100);
    try testing.expectEqual(@as(usize, 100), data.len);
}

test "createTempAllocator - helper function" {
    var temp = try memory.createTempAllocator(1024);

    const alloc = temp.allocator.allocator();
    const data = try alloc.alloc(u8, 100);
    try testing.expectEqual(@as(usize, 100), data.len);
}

test "MemoryStats - free more than allocated" {
    var stats = memory.MemoryStats{};

    stats.recordAlloc(100);
    stats.recordFree(150);

    try testing.expectEqual(@as(usize, 0), stats.current_memory);
}
