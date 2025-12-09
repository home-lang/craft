const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

// Import modules to test
const api = @import("../src/api.zig");
const components = @import("../src/components.zig");
const gpu = @import("../src/gpu.zig");
const renderer = @import("../src/renderer.zig");
const memory = @import("../src/memory.zig");

/// Performance test configuration
const PerformanceConfig = struct {
    iterations: usize = 1000,
    warmup_iterations: usize = 100,
    report_percentiles: bool = true,
};

/// Performance metrics collector
const PerformanceMetrics = struct {
    timings: std.ArrayList(u64),
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) PerformanceMetrics {
        return .{
            .timings = std.ArrayList(u64).init(allocator),
            .allocator = allocator,
        };
    }

    fn deinit(self: *PerformanceMetrics) void {
        self.timings.deinit();
    }

    fn record(self: *PerformanceMetrics, duration_ns: u64) !void {
        try self.timings.append(duration_ns);
    }

    fn calculateStats(self: *PerformanceMetrics) Stats {
        if (self.timings.items.len == 0) return .{};

        var total: u64 = 0;
        var min_val: u64 = std.math.maxInt(u64);
        var max_val: u64 = 0;

        for (self.timings.items) |timing| {
            total += timing;
            if (timing < min_val) min_val = timing;
            if (timing > max_val) max_val = timing;
        }

        const count = self.timings.items.len;
        const mean = total / count;

        // Calculate median
        std.mem.sort(u64, self.timings.items, {}, comptime std.sort.asc(u64));
        const median = if (count % 2 == 0)
            (self.timings.items[count / 2 - 1] + self.timings.items[count / 2]) / 2
        else
            self.timings.items[count / 2];

        // Calculate percentiles
        const p95_idx = @min((count * 95) / 100, count - 1);
        const p99_idx = @min((count * 99) / 100, count - 1);

        return .{
            .mean = mean,
            .median = median,
            .min = min_val,
            .max = max_val,
            .p95 = self.timings.items[p95_idx],
            .p99 = self.timings.items[p99_idx],
            .count = count,
        };
    }

    const Stats = struct {
        mean: u64 = 0,
        median: u64 = 0,
        min: u64 = 0,
        max: u64 = 0,
        p95: u64 = 0,
        p99: u64 = 0,
        count: usize = 0,

        fn print(self: Stats, name: []const u8) void {
            std.debug.print("\n=== {s} Performance Stats ===\n", .{name});
            std.debug.print("Iterations: {d}\n", .{self.count});
            std.debug.print("Mean:       {d} ns ({d:.2} µs)\n", .{ self.mean, @as(f64, @floatFromInt(self.mean)) / 1_000.0 });
            std.debug.print("Median:     {d} ns ({d:.2} µs)\n", .{ self.median, @as(f64, @floatFromInt(self.median)) / 1_000.0 });
            std.debug.print("Min:        {d} ns ({d:.2} µs)\n", .{ self.min, @as(f64, @floatFromInt(self.min)) / 1_000.0 });
            std.debug.print("Max:        {d} ns ({d:.2} µs)\n", .{ self.max, @as(f64, @floatFromInt(self.max)) / 1_000.0 });
            std.debug.print("P95:        {d} ns ({d:.2} µs)\n", .{ self.p95, @as(f64, @floatFromInt(self.p95)) / 1_000.0 });
            std.debug.print("P99:        {d} ns ({d:.2} µs)\n", .{ self.p99, @as(f64, @floatFromInt(self.p99)) / 1_000.0 });
        }
    };
};

/// Timer utility for precise measurements
const Timer = struct {
    start_time: i128,

    fn start() Timer {
        return .{ .start_time = std.time.nanoTimestamp() };
    }

    fn elapsed(self: *const Timer) u64 {
        const end_time = std.time.nanoTimestamp();
        return @intCast(end_time - self.start_time);
    }
};

// =============================================================================
// Component Creation Performance Tests
// =============================================================================

test "Performance: Component creation and destruction" {
    const config = PerformanceConfig{ .iterations = 10000 };
    var metrics = PerformanceMetrics.init(testing.allocator);
    defer metrics.deinit();

    const props = components.ComponentProps{};

    // Warmup
    var i: usize = 0;
    while (i < config.warmup_iterations) : (i += 1) {
        var button = try components.Button.init(testing.allocator, "Test", props);
        button.deinit();
    }

    // Actual measurements
    i = 0;
    while (i < config.iterations) : (i += 1) {
        const timer = Timer.start();
        var button = try components.Button.init(testing.allocator, "Test", props);
        button.deinit();
        try metrics.record(timer.elapsed());
    }

    const stats = metrics.calculateStats();
    stats.print("Button Creation/Destruction");

    // Assert reasonable performance (< 100µs average)
    try testing.expect(stats.mean < 100_000);
}

test "Performance: Bulk component creation" {
    const config = PerformanceConfig{ .iterations = 100 };
    var metrics = PerformanceMetrics.init(testing.allocator);
    defer metrics.deinit();

    const props = components.ComponentProps{};
    const batch_size = 100;

    var i: usize = 0;
    while (i < config.iterations) : (i += 1) {
        var components_list = std.ArrayList(*components.Button).init(testing.allocator);
        defer {
            for (components_list.items) |comp| {
                comp.deinit();
            }
            components_list.deinit();
        }

        const timer = Timer.start();
        var j: usize = 0;
        while (j < batch_size) : (j += 1) {
            const button = try components.Button.init(testing.allocator, "Button", props);
            try components_list.append(button);
        }
        try metrics.record(timer.elapsed());
    }

    const stats = metrics.calculateStats();
    stats.print("Bulk Component Creation (100 components)");
}

test "Performance: Checkbox toggle operations" {
    const config = PerformanceConfig{ .iterations = 100000 };
    var metrics = PerformanceMetrics.init(testing.allocator);
    defer metrics.deinit();

    const props = components.ComponentProps{};
    var checkbox = try components.Checkbox.init(testing.allocator, props);
    defer checkbox.deinit();

    var i: usize = 0;
    while (i < config.iterations) : (i += 1) {
        const timer = Timer.start();
        checkbox.toggle();
        try metrics.record(timer.elapsed());
    }

    const stats = metrics.calculateStats();
    stats.print("Checkbox Toggle");

    // Toggle should be extremely fast (< 1µs)
    try testing.expect(stats.mean < 1_000);
}

test "Performance: Slider value updates" {
    const config = PerformanceConfig{ .iterations = 100000 };
    var metrics = PerformanceMetrics.init(testing.allocator);
    defer metrics.deinit();

    const props = components.ComponentProps{};
    var slider = try components.Slider.init(testing.allocator, 0.0, 100.0, props);
    defer slider.deinit();

    var i: usize = 0;
    while (i < config.iterations) : (i += 1) {
        const timer = Timer.start();
        slider.setValue(@as(f64, @floatFromInt(i % 100)));
        try metrics.record(timer.elapsed());
    }

    const stats = metrics.calculateStats();
    stats.print("Slider Value Update");

    // Value updates should be very fast (< 1µs)
    try testing.expect(stats.mean < 1_000);
}

// =============================================================================
// List/Collection Performance Tests
// =============================================================================

test "Performance: ListView item addition" {
    const config = PerformanceConfig{ .iterations = 1000 };
    var metrics = PerformanceMetrics.init(testing.allocator);
    defer metrics.deinit();

    const props = components.ComponentProps{};
    var list = try components.ListView.init(testing.allocator, props);
    defer list.deinit();

    var i: usize = 0;
    while (i < config.iterations) : (i += 1) {
        const timer = Timer.start();
        try list.addItem("Test Item");
        try metrics.record(timer.elapsed());
    }

    const stats = metrics.calculateStats();
    stats.print("ListView Item Addition");
}

test "Performance: Table row operations" {
    const config = PerformanceConfig{ .iterations = 1000 };
    var metrics = PerformanceMetrics.init(testing.allocator);
    defer metrics.deinit();

    var columns = [_]components.Table.Column{
        .{ .title = "Name", .width = 100 },
        .{ .title = "Age", .width = 50 },
        .{ .title = "Email", .width = 150 },
    };
    const props = components.ComponentProps{};
    var table = try components.Table.init(testing.allocator, &columns, props);
    defer table.deinit();

    const row_data = [_][]const u8{ "John Doe", "30", "john@example.com" };

    var i: usize = 0;
    while (i < config.iterations) : (i += 1) {
        const timer = Timer.start();
        try table.addRow(.{ .data = &row_data });
        try metrics.record(timer.elapsed());
    }

    const stats = metrics.calculateStats();
    stats.print("Table Row Addition");
}

// =============================================================================
// Memory Management Performance Tests
// =============================================================================

test "Performance: Memory pool allocation and deallocation" {
    const config = PerformanceConfig{ .iterations = 10000 };
    var metrics = PerformanceMetrics.init(testing.allocator);
    defer metrics.deinit();

    var pool = memory.MemoryPool.init(testing.allocator);
    defer pool.deinit();

    var i: usize = 0;
    while (i < config.iterations) : (i += 1) {
        const timer = Timer.start();
        const ptr = try pool.alloc(1024);
        pool.free(ptr);
        try metrics.record(timer.elapsed());
    }

    const stats = metrics.calculateStats();
    stats.print("Memory Pool Alloc/Free");
}

test "Performance: Arena allocator bulk operations" {
    const config = PerformanceConfig{ .iterations = 1000 };
    var metrics = PerformanceMetrics.init(testing.allocator);
    defer metrics.deinit();

    var i: usize = 0;
    while (i < config.iterations) : (i += 1) {
        var arena = std.heap.ArenaAllocator.init(testing.allocator);
        defer arena.deinit();

        const timer = Timer.start();
        var j: usize = 0;
        while (j < 100) : (j += 1) {
            _ = try arena.allocator().alloc(u8, 1024);
        }
        try metrics.record(timer.elapsed());
    }

    const stats = metrics.calculateStats();
    stats.print("Arena Bulk Allocation (100 x 1KB)");
}

// =============================================================================
// GPU Performance Tests
// =============================================================================

test "Performance: GPU vertex buffer creation" {
    const config = PerformanceConfig{ .iterations = 1000 };
    var metrics = PerformanceMetrics.init(testing.allocator);
    defer metrics.deinit();

    const vertex_count = 1000;

    var i: usize = 0;
    while (i < config.iterations) : (i += 1) {
        const vertices = try testing.allocator.alloc(gpu.Vertex, vertex_count);
        defer testing.allocator.free(vertices);

        const timer = Timer.start();
        for (vertices, 0..) |*vertex, idx| {
            vertex.* = .{
                .position = .{ @floatFromInt(idx), @floatFromInt(idx), 0.0 },
                .normal = .{ 0.0, 0.0, 1.0 },
                .uv = .{ 0.5, 0.5 },
                .color = .{ 1.0, 1.0, 1.0, 1.0 },
            };
        }
        try metrics.record(timer.elapsed());
    }

    const stats = metrics.calculateStats();
    stats.print("GPU Vertex Buffer Creation (1000 vertices)");
}

test "Performance: Mesh initialization" {
    const config = PerformanceConfig{ .iterations = 1000 };
    var metrics = PerformanceMetrics.init(testing.allocator);
    defer metrics.deinit();

    var vertices = [_]gpu.Vertex{
        .{ .position = .{ 0.0, 1.0, 0.0 }, .normal = .{ 0.0, 0.0, 1.0 }, .uv = .{ 0.5, 1.0 }, .color = .{ 1.0, 0.0, 0.0, 1.0 } },
        .{ .position = .{ -1.0, -1.0, 0.0 }, .normal = .{ 0.0, 0.0, 1.0 }, .uv = .{ 0.0, 0.0 }, .color = .{ 0.0, 1.0, 0.0, 1.0 } },
        .{ .position = .{ 1.0, -1.0, 0.0 }, .normal = .{ 0.0, 0.0, 1.0 }, .uv = .{ 1.0, 0.0 }, .color = .{ 0.0, 0.0, 1.0, 1.0 } },
    };
    var indices = [_]u32{ 0, 1, 2 };

    var i: usize = 0;
    while (i < config.iterations) : (i += 1) {
        const timer = Timer.start();
        var mesh = try gpu.Mesh.init(testing.allocator, &vertices, &indices);
        mesh.deinit();
        try metrics.record(timer.elapsed());
    }

    const stats = metrics.calculateStats();
    stats.print("Mesh Init/Deinit");
}

// =============================================================================
// Rendering Performance Tests
// =============================================================================

test "Performance: Render command queueing" {
    const config = PerformanceConfig{ .iterations = 10000 };
    var metrics = PerformanceMetrics.init(testing.allocator);
    defer metrics.deinit();

    var pipeline = try renderer.RenderPipeline.init(testing.allocator);
    defer pipeline.deinit();

    var i: usize = 0;
    while (i < config.iterations) : (i += 1) {
        const timer = Timer.start();
        try pipeline.queueCommand(.{ .clear = .{ .color = .{ 0.0, 0.0, 0.0, 1.0 } } });
        try pipeline.queueCommand(.{ .draw = .{ .vertex_count = 3, .instance_count = 1 } });
        try metrics.record(timer.elapsed());
    }

    const stats = metrics.calculateStats();
    stats.print("Render Command Queueing");
}

test "Performance: Batch render operations" {
    const config = PerformanceConfig{ .iterations = 100 };
    var metrics = PerformanceMetrics.init(testing.allocator);
    defer metrics.deinit();

    var pipeline = try renderer.RenderPipeline.init(testing.allocator);
    defer pipeline.deinit();

    const batch_size = 1000;

    var i: usize = 0;
    while (i < config.iterations) : (i += 1) {
        const timer = Timer.start();
        var j: usize = 0;
        while (j < batch_size) : (j += 1) {
            try pipeline.queueCommand(.{ .draw = .{ .vertex_count = 6, .instance_count = 1 } });
        }
        try metrics.record(timer.elapsed());
    }

    const stats = metrics.calculateStats();
    stats.print("Batch Render Commands (1000 commands)");
}

// =============================================================================
// IPC Performance Tests
// =============================================================================

test "Performance: IPC message creation" {
    const config = PerformanceConfig{ .iterations = 100000 };
    var metrics = PerformanceMetrics.init(testing.allocator);
    defer metrics.deinit();

    var i: usize = 0;
    while (i < config.iterations) : (i += 1) {
        const timer = Timer.start();
        const payload = api.IPCMessage.Payload{ .string = "test data" };
        const msg = api.IPCMessage.request(@intCast(i), payload);
        _ = msg;
        try metrics.record(timer.elapsed());
    }

    const stats = metrics.calculateStats();
    stats.print("IPC Message Creation");

    // Message creation should be very fast (< 500ns)
    try testing.expect(stats.mean < 500);
}

// =============================================================================
// Stress Tests
// =============================================================================

test "Stress: Rapid component lifecycle" {
    const iterations = 50000;
    var i: usize = 0;
    const props = components.ComponentProps{};

    const timer = Timer.start();
    while (i < iterations) : (i += 1) {
        var button = try components.Button.init(testing.allocator, "Stress", props);
        button.deinit();
    }
    const duration = timer.elapsed();

    std.debug.print("\nStress Test: {d} component lifecycles in {d:.2} ms\n", .{ iterations, @as(f64, @floatFromInt(duration)) / 1_000_000.0 });
    std.debug.print("Throughput: {d:.0} ops/sec\n", .{@as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(duration)) / 1_000_000_000.0)});

    // Should complete in reasonable time (< 5 seconds)
    try testing.expect(duration < 5_000_000_000);
}

test "Stress: Memory allocation patterns" {
    const iterations = 10000;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    var allocations = std.ArrayList([]u8).init(testing.allocator);
    defer allocations.deinit();

    const timer = Timer.start();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const size = 1024 + (i % 1024);
        const mem = try allocator.alloc(u8, size);
        try allocations.append(mem);
    }
    const duration = timer.elapsed();

    std.debug.print("\nStress Test: {d} allocations in {d:.2} ms\n", .{ iterations, @as(f64, @floatFromInt(duration)) / 1_000_000.0 });
    std.debug.print("Average allocation size: 1.5 KB\n", .{});
    std.debug.print("Total allocated: {d} MB\n", .{(iterations * 1536) / (1024 * 1024)});
}

// =============================================================================
// Concurrency Simulation Tests
// =============================================================================

test "Performance: Simulated concurrent component operations" {
    const config = PerformanceConfig{ .iterations = 1000 };
    var metrics = PerformanceMetrics.init(testing.allocator);
    defer metrics.deinit();

    const props = components.ComponentProps{};
    const component_count = 10;

    var i: usize = 0;
    while (i < config.iterations) : (i += 1) {
        var components_list = std.ArrayList(*components.Button).init(testing.allocator);
        defer {
            for (components_list.items) |comp| {
                comp.deinit();
            }
            components_list.deinit();
        }

        const timer = Timer.start();

        // Simulate concurrent operations
        var j: usize = 0;
        while (j < component_count) : (j += 1) {
            const button = try components.Button.init(testing.allocator, "Concurrent", props);
            try components_list.append(button);
            button.setText("Updated");
        }

        try metrics.record(timer.elapsed());
    }

    const stats = metrics.calculateStats();
    stats.print("Simulated Concurrent Operations (10 components)");
}
