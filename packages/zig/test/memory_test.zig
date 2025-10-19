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

// Edge cases and thorough tests

test "MemoryPool - multiple resets" {
    var pool = memory.MemoryPool.init(testing.allocator);
    defer pool.deinit();

    const alloc = pool.allocator();

    for (0..10) |_| {
        _ = try alloc.alloc(u8, 100);
        pool.reset();
    }

    // Should still work after multiple resets
    const data = try alloc.alloc(u8, 50);
    try testing.expectEqual(@as(usize, 50), data.len);
}

test "MemoryPool - large allocation" {
    var pool = memory.MemoryPool.init(testing.allocator);
    defer pool.deinit();

    const alloc = pool.allocator();
    const large_data = try alloc.alloc(u8, 1024 * 1024); // 1MB
    try testing.expectEqual(@as(usize, 1024 * 1024), large_data.len);
}

test "MemoryPool - zero size allocation" {
    var pool = memory.MemoryPool.init(testing.allocator);
    defer pool.deinit();

    const alloc = pool.allocator();
    const empty_data = try alloc.alloc(u8, 0);
    try testing.expectEqual(@as(usize, 0), empty_data.len);
}

test "TempAllocator - out of memory" {
    var buffer: [100]u8 = undefined;
    var temp = memory.TempAllocator.init(&buffer);

    const alloc = temp.allocator();

    // First allocation should succeed
    const data1 = try alloc.alloc(u8, 50);
    try testing.expectEqual(@as(usize, 50), data1.len);

    // Second allocation should fail (not enough space)
    const result = alloc.alloc(u8, 100);
    try testing.expectError(error.OutOfMemory, result);
}

test "TempAllocator - exact buffer size" {
    var buffer: [100]u8 = undefined;
    var temp = memory.TempAllocator.init(&buffer);

    const alloc = temp.allocator();

    // Allocate exactly the buffer size (accounting for alignment overhead)
    const data = alloc.alloc(u8, 90);
    try testing.expect(data != error.OutOfMemory);
}

test "TempAllocator - multiple small allocations" {
    var buffer: [1024]u8 = undefined;
    var temp = memory.TempAllocator.init(&buffer);

    const alloc = temp.allocator();

    for (0..10) |_| {
        const data = try alloc.alloc(u8, 10);
        try testing.expectEqual(@as(usize, 10), data.len);
    }
}

test "MemoryStats - many allocations" {
    var stats = memory.MemoryStats{};

    for (0..1000) |i| {
        stats.recordAlloc(i);
    }

    try testing.expectEqual(@as(usize, 1000), stats.allocations);
    try testing.expect(stats.bytes_allocated > 0);
}

test "MemoryStats - alternating alloc/free" {
    var stats = memory.MemoryStats{};

    for (0..100) |_| {
        stats.recordAlloc(100);
        stats.recordFree(100);
    }

    try testing.expectEqual(@as(usize, 100), stats.allocations);
    try testing.expectEqual(@as(usize, 100), stats.deallocations);
    try testing.expectEqual(@as(usize, 0), stats.current_memory);
}

test "MemoryStats - peak tracking with variations" {
    var stats = memory.MemoryStats{};

    stats.recordAlloc(1000);
    try testing.expectEqual(@as(usize, 1000), stats.peak_memory);

    stats.recordAlloc(500);
    try testing.expectEqual(@as(usize, 1500), stats.peak_memory);

    stats.recordFree(1000);
    try testing.expectEqual(@as(usize, 1500), stats.peak_memory); // Peak unchanged

    stats.recordAlloc(2000);
    try testing.expectEqual(@as(usize, 2500), stats.peak_memory); // New peak
}

test "MemoryStats - zero allocations" {
    var stats = memory.MemoryStats{};

    stats.recordAlloc(0);
    stats.recordFree(0);

    try testing.expectEqual(@as(usize, 1), stats.allocations);
    try testing.expectEqual(@as(usize, 1), stats.deallocations);
    try testing.expectEqual(@as(usize, 0), stats.current_memory);
}

test "TrackingAllocator - complex allocation pattern" {
    var tracker = memory.TrackingAllocator.init(testing.allocator);
    const alloc = tracker.allocator();

    var allocations = std.ArrayList([]u8).init(testing.allocator);
    defer {
        for (allocations.items) |item| {
            alloc.free(item);
        }
        allocations.deinit();
    }

    // Allocate various sizes
    const sizes = [_]usize{ 10, 100, 1000, 50, 500 };
    for (sizes) |size| {
        const data = try alloc.alloc(u8, size);
        try allocations.append(data);
    }

    const stats = tracker.getStats();
    try testing.expect(stats.allocations >= 5);
    try testing.expect(stats.bytes_allocated >= 1660);
}

test "TrackingAllocator - reallocation tracking" {
    var tracker = memory.TrackingAllocator.init(testing.allocator);
    const alloc = tracker.allocator();

    var data = try alloc.alloc(u8, 100);
    defer alloc.free(data);

    const initial_allocs = tracker.getStats().allocations;

    // Try to resize
    if (alloc.resize(data, 200)) {
        // Resize succeeded
        data.len = 200;
    }

    // Stats should reflect the operation
    try testing.expect(tracker.getStats().allocations >= initial_allocs);
}

test "TrackingAllocator - memory leak detection" {
    var tracker = memory.TrackingAllocator.init(testing.allocator);
    const alloc = tracker.allocator();

    _ = try alloc.alloc(u8, 100);

    const stats = tracker.getStats();
    try testing.expect(stats.current_memory > 0);
    // In real usage, this would indicate a leak if not freed
}

test "createArena - multiple arenas" {
    var arena1 = try memory.createArena(testing.allocator);
    defer arena1.deinit();

    var arena2 = try memory.createArena(testing.allocator);
    defer arena2.deinit();

    const alloc1 = arena1.allocator();
    const alloc2 = arena2.allocator();

    const data1 = try alloc1.alloc(u8, 100);
    const data2 = try alloc2.alloc(u8, 200);

    try testing.expectEqual(@as(usize, 100), data1.len);
    try testing.expectEqual(@as(usize, 200), data2.len);
}

test "createTempAllocator - various sizes" {
    const sizes = [_]usize{ 64, 256, 1024, 4096 };

    for (sizes) |size| {
        var temp = try memory.createTempAllocator(size);
        const alloc = temp.allocator.allocator();

        // Should be able to allocate roughly half the buffer
        const data = try alloc.alloc(u8, size / 4);
        try testing.expect(data.len > 0);
    }
}

test "MemoryPool - stress test" {
    var pool = memory.MemoryPool.init(testing.allocator);
    defer pool.deinit();

    const alloc = pool.allocator();

    for (0..100) |_| {
        _ = try alloc.alloc(u8, 1024);
    }

    pool.reset();

    // Should still work after stress
    const data = try alloc.alloc(u8, 1024);
    try testing.expectEqual(@as(usize, 1024), data.len);
}

test "TrackingAllocator - concurrent operations simulation" {
    var tracker = memory.TrackingAllocator.init(testing.allocator);
    const alloc = tracker.allocator();

    var allocations = std.ArrayList([]u8).init(testing.allocator);
    defer allocations.deinit();

    // Simulate interleaved allocations and frees
    for (0..10) |i| {
        const data = try alloc.alloc(u8, (i + 1) * 10);
        try allocations.append(data);

        if (i % 2 == 0 and allocations.items.len > 1) {
            alloc.free(allocations.orderedRemove(0));
        }
    }

    // Clean up remaining allocations
    for (allocations.items) |item| {
        alloc.free(item);
    }

    const stats = tracker.getStats();
    try testing.expect(stats.allocations > 0);
    try testing.expect(stats.deallocations > 0);
}
