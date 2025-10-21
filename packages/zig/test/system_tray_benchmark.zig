const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");
const tray_module = @import("../src/tray.zig");
const SystemTray = tray_module.SystemTray;

// Benchmark SystemTray creation
test "Benchmark: SystemTray creation" {
    const allocator = testing.allocator;
    const iterations = 1000;

    var timer = try std.time.Timer.start();
    const start = timer.read();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        var tray = SystemTray.init(allocator, "Benchmark App");
        tray.deinit();
    }

    const end = timer.read();
    const total_ns = end - start;
    const avg_ns = total_ns / iterations;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(total_ns)) / 1_000_000_000.0);

    std.debug.print("\nSystemTray Creation Benchmark:\n", .{});
    std.debug.print("  Iterations:    {d}\n", .{iterations});
    std.debug.print("  Total Time:    {d:.2} ms\n", .{@as(f64, @floatFromInt(total_ns)) / 1_000_000.0});
    std.debug.print("  Average Time:  {d:.2} µs\n", .{@as(f64, @floatFromInt(avg_ns)) / 1_000.0});
    std.debug.print("  Ops/sec:       {d:.0}\n\n", .{ops_per_sec});

    // Sanity check: each operation should complete in reasonable time
    try testing.expect(avg_ns < 1_000_000); // < 1ms average
}

// Benchmark setTitle operation
test "Benchmark: SystemTray setTitle" {
    const allocator = testing.allocator;
    const iterations = 10000;

    var tray = SystemTray.init(allocator, "App");
    defer tray.deinit();

    var timer = try std.time.Timer.start();
    const start = timer.read();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        try tray.setTitle("Updated");
    }

    const end = timer.read();
    const total_ns = end - start;
    const avg_ns = total_ns / iterations;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(total_ns)) / 1_000_000_000.0);

    std.debug.print("\nSystemTray setTitle Benchmark:\n", .{});
    std.debug.print("  Iterations:    {d}\n", .{iterations});
    std.debug.print("  Total Time:    {d:.2} ms\n", .{@as(f64, @floatFromInt(total_ns)) / 1_000_000.0});
    std.debug.print("  Average Time:  {d:.2} µs\n", .{@as(f64, @floatFromInt(avg_ns)) / 1_000.0});
    std.debug.print("  Ops/sec:       {d:.0}\n\n", .{ops_per_sec});

    // setTitle should be very fast (just updating a field)
    try testing.expect(avg_ns < 10_000); // < 10µs average
}

// Benchmark setTooltip operation
test "Benchmark: SystemTray setTooltip" {
    const allocator = testing.allocator;
    const iterations = 10000;

    var tray = SystemTray.init(allocator, "App");
    defer tray.deinit();

    var timer = try std.time.Timer.start();
    const start = timer.read();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        try tray.setTooltip("Tooltip text");
    }

    const end = timer.read();
    const total_ns = end - start;
    const avg_ns = total_ns / iterations;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(total_ns)) / 1_000_000_000.0);

    std.debug.print("\nSystemTray setTooltip Benchmark:\n", .{});
    std.debug.print("  Iterations:    {d}\n", .{iterations});
    std.debug.print("  Total Time:    {d:.2} ms\n", .{@as(f64, @floatFromInt(total_ns)) / 1_000_000.0});
    std.debug.print("  Average Time:  {d:.2} µs\n", .{@as(f64, @floatFromInt(avg_ns)) / 1_000.0});
    std.debug.print("  Ops/sec:       {d:.0}\n\n", .{ops_per_sec});

    // setTooltip should be very fast
    try testing.expect(avg_ns < 10_000); // < 10µs average
}

// Benchmark callback registration
test "Benchmark: SystemTray setClickCallback" {
    const allocator = testing.allocator;
    const iterations = 100000;

    var tray = SystemTray.init(allocator, "App");
    defer tray.deinit();

    const TestCallback = struct {
        fn callback() void {}
    };

    var timer = try std.time.Timer.start();
    const start = timer.read();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        tray.setClickCallback(&TestCallback.callback);
    }

    const end = timer.read();
    const total_ns = end - start;
    const avg_ns = total_ns / iterations;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(total_ns)) / 1_000_000_000.0);

    std.debug.print("\nSystemTray setClickCallback Benchmark:\n", .{});
    std.debug.print("  Iterations:    {d}\n", .{iterations});
    std.debug.print("  Total Time:    {d:.2} ms\n", .{@as(f64, @floatFromInt(total_ns)) / 1_000_000.0});
    std.debug.print("  Average Time:  {d:.2} ns\n", .{avg_ns});
    std.debug.print("  Ops/sec:       {d:.0}\n\n", .{ops_per_sec});

    // Callback registration is just pointer assignment, should be extremely fast
    try testing.expect(avg_ns < 1_000); // < 1µs average
}

// Benchmark callback triggering
test "Benchmark: SystemTray triggerClick" {
    const allocator = testing.allocator;
    const iterations = 100000;

    var tray = SystemTray.init(allocator, "App");
    defer tray.deinit();

    const TestCallback = struct {
        var counter: usize = 0;
        fn callback() void {
            counter += 1;
        }
    };

    tray.setClickCallback(&TestCallback.callback);
    TestCallback.counter = 0;

    var timer = try std.time.Timer.start();
    const start = timer.read();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        tray.triggerClick();
    }

    const end = timer.read();
    const total_ns = end - start;
    const avg_ns = total_ns / iterations;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(total_ns)) / 1_000_000_000.0);

    std.debug.print("\nSystemTray triggerClick Benchmark:\n", .{});
    std.debug.print("  Iterations:    {d}\n", .{iterations});
    std.debug.print("  Total Time:    {d:.2} ms\n", .{@as(f64, @floatFromInt(total_ns)) / 1_000_000.0});
    std.debug.print("  Average Time:  {d:.2} ns\n", .{avg_ns});
    std.debug.print("  Ops/sec:       {d:.0}\n\n", .{ops_per_sec});

    // Verify all callbacks were executed
    try testing.expectEqual(iterations, TestCallback.counter);

    // Callback triggering should be very fast
    try testing.expect(avg_ns < 5_000); // < 5µs average
}

// Benchmark menu attachment
test "Benchmark: SystemTray setMenu" {
    const allocator = testing.allocator;
    const iterations = 10000;

    var tray = SystemTray.init(allocator, "App");
    defer tray.deinit();

    var fake_menu: u8 = 0;
    const menu_ptr: *anyopaque = @ptrCast(&fake_menu);

    var timer = try std.time.Timer.start();
    const start = timer.read();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        try tray.setMenu(menu_ptr);
    }

    const end = timer.read();
    const total_ns = end - start;
    const avg_ns = total_ns / iterations;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(total_ns)) / 1_000_000_000.0);

    std.debug.print("\nSystemTray setMenu Benchmark:\n", .{});
    std.debug.print("  Iterations:    {d}\n", .{iterations});
    std.debug.print("  Total Time:    {d:.2} ms\n", .{@as(f64, @floatFromInt(total_ns)) / 1_000_000.0});
    std.debug.print("  Average Time:  {d:.2} µs\n", .{@as(f64, @floatFromInt(avg_ns)) / 1_000.0});
    std.debug.print("  Ops/sec:       {d:.0}\n\n", .{ops_per_sec});

    // Menu attachment should be fast
    try testing.expect(avg_ns < 50_000); // < 50µs average
}

// Benchmark hide/show toggle
test "Benchmark: SystemTray hide operation" {
    const allocator = testing.allocator;
    const iterations = 10000;

    var tray = SystemTray.init(allocator, "App");
    defer tray.deinit();

    var timer = try std.time.Timer.start();
    const start = timer.read();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        tray.hide();
    }

    const end = timer.read();
    const total_ns = end - start;
    const avg_ns = total_ns / iterations;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(total_ns)) / 1_000_000_000.0);

    std.debug.print("\nSystemTray hide Benchmark:\n", .{});
    std.debug.print("  Iterations:    {d}\n", .{iterations});
    std.debug.print("  Total Time:    {d:.2} ms\n", .{@as(f64, @floatFromInt(total_ns)) / 1_000_000.0});
    std.debug.print("  Average Time:  {d:.2} µs\n", .{@as(f64, @floatFromInt(avg_ns)) / 1_000.0});
    std.debug.print("  Ops/sec:       {d:.0}\n\n", .{ops_per_sec});

    // hide() is mostly a flag update, should be very fast
    try testing.expect(avg_ns < 10_000); // < 10µs average
}

// Memory footprint test
test "Benchmark: SystemTray memory footprint" {
    const allocator = testing.allocator;

    const size_of_tray = @sizeOf(SystemTray);

    std.debug.print("\nSystemTray Memory Footprint:\n", .{});
    std.debug.print("  Struct Size:   {d} bytes\n", .{size_of_tray});
    std.debug.print("  Alignment:     {d} bytes\n\n", .{@alignOf(SystemTray)});

    // Create a tray to verify no hidden allocations
    var tray = SystemTray.init(allocator, "App");
    defer tray.deinit();

    // SystemTray should be reasonably small
    try testing.expect(size_of_tray < 256); // Should be less than 256 bytes
}

// Benchmark creating multiple tray instances
test "Benchmark: Multiple SystemTray instances" {
    const allocator = testing.allocator;
    const num_trays = 10;
    const iterations = 100;

    var timer = try std.time.Timer.start();
    const start = timer.read();

    var round: usize = 0;
    while (round < iterations) : (round += 1) {
        var trays: [num_trays]SystemTray = undefined;

        // Create all trays
        var i: usize = 0;
        while (i < num_trays) : (i += 1) {
            trays[i] = SystemTray.init(allocator, "App");
        }

        // Update all trays
        i = 0;
        while (i < num_trays) : (i += 1) {
            try trays[i].setTitle("Updated");
        }

        // Cleanup all trays
        i = 0;
        while (i < num_trays) : (i += 1) {
            trays[i].deinit();
        }
    }

    const end = timer.read();
    const total_ns = end - start;
    const avg_ns = total_ns / iterations;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(total_ns)) / 1_000_000_000.0);

    std.debug.print("\nMultiple SystemTray Instances Benchmark ({d} instances):\n", .{num_trays});
    std.debug.print("  Iterations:    {d}\n", .{iterations});
    std.debug.print("  Total Time:    {d:.2} ms\n", .{@as(f64, @floatFromInt(total_ns)) / 1_000_000.0});
    std.debug.print("  Average Time:  {d:.2} ms\n", .{@as(f64, @floatFromInt(avg_ns)) / 1_000_000.0});
    std.debug.print("  Ops/sec:       {d:.0}\n\n", .{ops_per_sec});

    // Each round should complete in reasonable time
    try testing.expect(avg_ns < 10_000_000); // < 10ms per round
}

// Stress test with rapid updates
test "Benchmark: SystemTray rapid updates stress test" {
    const allocator = testing.allocator;
    const iterations = 1000;

    var tray = SystemTray.init(allocator, "App");
    defer tray.deinit();

    const titles = [_][]const u8{
        "Title 1",
        "Title 2",
        "Title 3",
        "🚀 Emoji",
        "Long title text that might exceed normal limits",
    };

    var timer = try std.time.Timer.start();
    const start = timer.read();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const title = titles[i % titles.len];
        try tray.setTitle(title);
        try tray.setTooltip(title);
    }

    const end = timer.read();
    const total_ns = end - start;
    const avg_ns = total_ns / iterations;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(total_ns)) / 1_000_000_000.0);

    std.debug.print("\nSystemTray Rapid Updates Stress Test:\n", .{});
    std.debug.print("  Iterations:    {d}\n", .{iterations});
    std.debug.print("  Total Time:    {d:.2} ms\n", .{@as(f64, @floatFromInt(total_ns)) / 1_000_000.0});
    std.debug.print("  Average Time:  {d:.2} µs\n", .{@as(f64, @floatFromInt(avg_ns)) / 1_000.0});
    std.debug.print("  Ops/sec:       {d:.0}\n\n", .{ops_per_sec});

    // Should handle rapid updates efficiently
    try testing.expect(avg_ns < 100_000); // < 100µs average
}
