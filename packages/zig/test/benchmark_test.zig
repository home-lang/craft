const std = @import("std");
const benchmark = @import("benchmark");
const testing = std.testing;

test "Benchmark - simple function" {
    const allocator = testing.allocator;
    const bench = try benchmark.Benchmark.init(allocator, "Simple Function", 1000);
    defer bench.deinit();

    const result = try bench.run(simpleAdd, .{ 5, 10 });

    try testing.expect(result.iterations == 1000);
    try testing.expect(result.total_time_ns > 0);
    // min_time_ns can be 0 for very fast functions, so we don't check it
    try testing.expect(result.max_time_ns >= result.min_time_ns);
    try testing.expect(result.ops_per_sec > 0);
}

fn simpleAdd(a: i32, b: i32) !i32 {
    return a + b;
}

test "Benchmark - memory allocation" {
    const allocator = testing.allocator;
    const result = try benchmark.benchmarkAllocation(allocator, 1024, 100);

    try testing.expect(result.iterations == 100);
    try testing.expect(result.total_time_ns > 0);
    try testing.expectEqualStrings("Memory Allocation", result.name);
}

test "Benchmark - HashMap operations" {
    const allocator = testing.allocator;
    const result = try benchmark.benchmarkHashMapOperations(allocator, 100);

    try testing.expect(result.iterations == 100);
    try testing.expect(result.total_time_ns > 0);
    try testing.expectEqualStrings("HashMap Operations", result.name);
}

test "Benchmark - ArrayList operations" {
    const allocator = testing.allocator;
    const result = try benchmark.benchmarkArrayListOperations(allocator, 100);

    try testing.expect(result.iterations == 100);
    try testing.expect(result.total_time_ns > 0);
    try testing.expectEqualStrings("ArrayList Operations", result.name);
}

test "MemoryTracker - track allocations" {
    const allocator = testing.allocator;
    const tracker = try benchmark.MemoryTracker.init(allocator);
    defer {
        tracker.deinit();
        allocator.destroy(tracker);
    }

    tracker.trackAllocation(1024);
    tracker.trackAllocation(2048);
    tracker.trackAllocation(512);

    try testing.expect(tracker.total_allocated == 3584);
    try testing.expect(tracker.current_allocated == 3584);
    try testing.expect(tracker.peak_allocated == 3584);
    try testing.expect(tracker.allocation_count == 3);
}

test "MemoryTracker - track frees" {
    const allocator = testing.allocator;
    const tracker = try benchmark.MemoryTracker.init(allocator);
    defer {
        tracker.deinit();
        allocator.destroy(tracker);
    }

    tracker.trackAllocation(1024);
    tracker.trackAllocation(2048);
    tracker.trackFree(1024);

    try testing.expect(tracker.total_allocated == 3072);
    try testing.expect(tracker.total_freed == 1024);
    try testing.expect(tracker.current_allocated == 2048);
    try testing.expect(tracker.peak_allocated == 3072);
}

test "MemoryTracker - reset" {
    const allocator = testing.allocator;
    const tracker = try benchmark.MemoryTracker.init(allocator);
    defer {
        tracker.deinit();
        allocator.destroy(tracker);
    }

    tracker.trackAllocation(1024);
    tracker.trackFree(512);
    tracker.reset();

    try testing.expect(tracker.total_allocated == 0);
    try testing.expect(tracker.total_freed == 0);
    try testing.expect(tracker.current_allocated == 0);
    try testing.expect(tracker.peak_allocated == 0);
}

test "MemoryTracker - report generation" {
    const allocator = testing.allocator;
    const tracker = try benchmark.MemoryTracker.init(allocator);
    defer {
        tracker.deinit();
        allocator.destroy(tracker);
    }

    tracker.trackAllocation(1024);
    tracker.trackAllocation(512);
    tracker.trackFree(256);

    const report = try tracker.getReport(allocator);
    defer allocator.free(report);

    try testing.expect(report.len > 0);
    try testing.expect(std.mem.indexOf(u8, report, "Memory Report:") != null);
}

test "BenchmarkSuite - add results" {
    const allocator = testing.allocator;
    const suite = try benchmark.BenchmarkSuite.init(allocator, "Test Suite");
    defer suite.deinit();

    const result1 = benchmark.BenchmarkResult{
        .name = "Test 1",
        .iterations = 100,
        .total_time_ns = 1000000,
        .min_time_ns = 9000,
        .max_time_ns = 11000,
        .mean_time_ns = 10000,
        .median_time_ns = 10000,
        .std_dev_ns = 500.0,
        .ops_per_sec = 100000.0,
        .memory_allocated = 1024,
        .memory_peak = 2048,
    };

    const result2 = benchmark.BenchmarkResult{
        .name = "Test 2",
        .iterations = 200,
        .total_time_ns = 2000000,
        .min_time_ns = 9500,
        .max_time_ns = 10500,
        .mean_time_ns = 10000,
        .median_time_ns = 10000,
        .std_dev_ns = 300.0,
        .ops_per_sec = 100000.0,
        .memory_allocated = 2048,
        .memory_peak = 4096,
    };

    try suite.addResult(result1);
    try suite.addResult(result2);

    try testing.expect(suite.results.items.len == 2);
    try testing.expectEqualStrings("Test 1", suite.results.items[0].name);
    try testing.expectEqualStrings("Test 2", suite.results.items[1].name);
}

test "BenchmarkSuite - generate report" {
    const allocator = testing.allocator;
    const suite = try benchmark.BenchmarkSuite.init(allocator, "Performance Suite");
    defer suite.deinit();

    const result = benchmark.BenchmarkResult{
        .name = "Sample Benchmark",
        .iterations = 1000,
        .total_time_ns = 10000000,
        .min_time_ns = 9000,
        .max_time_ns = 11000,
        .mean_time_ns = 10000,
        .median_time_ns = 10000,
        .std_dev_ns = 500.0,
        .ops_per_sec = 100000.0,
        .memory_allocated = 4096,
        .memory_peak = 8192,
    };

    try suite.addResult(result);

    const report = try suite.generateReport(allocator);
    defer allocator.free(report);

    try testing.expect(report.len > 0);
    try testing.expect(std.mem.indexOf(u8, report, "Performance Suite") != null);
    try testing.expect(std.mem.indexOf(u8, report, "Sample Benchmark") != null);
}

test "BenchmarkSuite - generate JSON" {
    const allocator = testing.allocator;
    const suite = try benchmark.BenchmarkSuite.init(allocator, "JSON Suite");
    defer suite.deinit();

    const result = benchmark.BenchmarkResult{
        .name = "JSON Test",
        .iterations = 500,
        .total_time_ns = 5000000,
        .min_time_ns = 9000,
        .max_time_ns = 11000,
        .mean_time_ns = 10000,
        .median_time_ns = 10000,
        .std_dev_ns = 400.0,
        .ops_per_sec = 100000.0,
        .memory_allocated = 2048,
        .memory_peak = 4096,
    };

    try suite.addResult(result);

    const json = try suite.generateJSON(allocator);
    defer allocator.free(json);

    try testing.expect(json.len > 0);
    try testing.expect(std.mem.indexOf(u8, json, "\"suite\":\"JSON Suite\"") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"name\":\"JSON Test\"") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"iterations\":500") != null);
}

test "BenchmarkResult - format" {
    const allocator = testing.allocator;

    const result = benchmark.BenchmarkResult{
        .name = "Format Test",
        .iterations = 1000,
        .total_time_ns = 10000000,
        .min_time_ns = 9000,
        .max_time_ns = 11000,
        .mean_time_ns = 10000,
        .median_time_ns = 10000,
        .std_dev_ns = 500.0,
        .ops_per_sec = 100000.0,
        .memory_allocated = 1024,
        .memory_peak = 2048,
    };

    const formatted = try result.format(allocator);
    defer allocator.free(formatted);

    try testing.expect(formatted.len > 0);
    try testing.expect(std.mem.indexOf(u8, formatted, "Format Test") != null);
    try testing.expect(std.mem.indexOf(u8, formatted, "Iterations:") != null);
    try testing.expect(std.mem.indexOf(u8, formatted, "Memory Alloc:") != null);
}

test "Benchmark - statistical calculations" {
    const allocator = testing.allocator;
    const bench = try benchmark.Benchmark.init(allocator, "Stats Test", 100);
    defer bench.deinit();

    const result = try bench.run(simpleAdd, .{ 1, 2 });

    // Verify statistical measures are calculated
    try testing.expect(result.mean_time_ns > 0);
    try testing.expect(result.median_time_ns > 0);
    try testing.expect(result.std_dev_ns >= 0);
    try testing.expect(result.min_time_ns <= result.mean_time_ns);
    try testing.expect(result.max_time_ns >= result.mean_time_ns);
}

test "Benchmark - warmup iterations" {
    const allocator = testing.allocator;
    const bench = try benchmark.Benchmark.init(allocator, "Warmup Test", 1000);
    defer bench.deinit();

    // With 1000 iterations, warmup should be 100 (min(1000/10, 100))
    try testing.expect(bench.warmup_iterations == 100);

    const result = try bench.run(simpleAdd, .{ 3, 4 });
    // Only actual iterations should be counted
    try testing.expect(result.iterations == 1000);
}
