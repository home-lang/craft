const std = @import("std");
const testing = std.testing;
const profiler = @import("../src/profiler.zig");

test "Profiler - init and deinit" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    try testing.expect(prof.enabled);
    try testing.expectEqual(@as(usize, 0), prof.entries.items.len);
    try testing.expectEqual(@as(usize, 0), prof.active_profiles.count());
}

test "Profiler - start and end timing" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    try prof.start("test_operation");
    std.time.sleep(1 * std.time.ns_per_ms); // Sleep 1ms
    try prof.end("test_operation");

    try testing.expectEqual(@as(usize, 1), prof.entries.items.len);
    try testing.expectEqualStrings("test_operation", prof.entries.items[0].name);
    try testing.expect(prof.entries.items[0].duration_ms >= 1.0);
}

test "Profiler - multiple operations" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    try prof.start("op1");
    std.time.sleep(1 * std.time.ns_per_ms);
    try prof.end("op1");

    try prof.start("op2");
    std.time.sleep(2 * std.time.ns_per_ms);
    try prof.end("op2");

    try prof.start("op3");
    try prof.end("op3");

    try testing.expectEqual(@as(usize, 3), prof.entries.items.len);
    try testing.expect(prof.entries.items[1].duration_ms >= prof.entries.items[0].duration_ms);
}

test "Profiler - disabled profiler" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    prof.enabled = false;

    try prof.start("disabled_op");
    try prof.end("disabled_op");

    try testing.expectEqual(@as(usize, 0), prof.entries.items.len);
}

test "Profiler - end without start" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    try prof.end("nonexistent");

    try testing.expectEqual(@as(usize, 0), prof.entries.items.len);
}

test "Profiler - clear entries" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    try prof.start("op1");
    try prof.end("op1");
    try prof.start("op2");
    try prof.end("op2");

    try testing.expectEqual(@as(usize, 2), prof.entries.items.len);

    prof.clear();

    try testing.expectEqual(@as(usize, 0), prof.entries.items.len);
}

test "Profiler - getReport" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    try prof.start("test_op");
    std.time.sleep(1 * std.time.ns_per_ms);
    try prof.end("test_op");

    const report = try prof.getReport();
    defer prof.allocator.free(report);

    try testing.expect(report.len > 0);
    try testing.expect(std.mem.indexOf(u8, report, "Performance Profile Report") != null);
    try testing.expect(std.mem.indexOf(u8, report, "test_op") != null);
}

test "Profiler - getReport empty" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    const report = try prof.getReport();
    defer prof.allocator.free(report);

    try testing.expect(std.mem.indexOf(u8, report, "No profiling data collected") != null);
}

test "Profiler - getHTMLDashboard" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    try prof.start("html_test");
    try prof.end("html_test");

    const html = try prof.getHTMLDashboard();
    defer prof.allocator.free(html);

    try testing.expect(html.len > 0);
    try testing.expect(std.mem.indexOf(u8, html, "<!DOCTYPE html>") != null);
    try testing.expect(std.mem.indexOf(u8, html, "Zyte Performance Dashboard") != null);
    try testing.expect(std.mem.indexOf(u8, html, "html_test") != null);
}

test "Profiler - measure function" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    const testFunc = struct {
        fn run(x: i32) i32 {
            std.time.sleep(1 * std.time.ns_per_ms);
            return x * 2;
        }
    }.run;

    const result = try prof.measure("measure_test", testFunc, .{5});

    try testing.expectEqual(@as(i32, 10), result);
    try testing.expectEqual(@as(usize, 1), prof.entries.items.len);
    try testing.expectEqualStrings("measure_test", prof.entries.items[0].name);
}

test "ProfileEntry - structure" {
    const entry = profiler.ProfileEntry{
        .name = "test",
        .start_time = 1000,
        .end_time = 1100,
        .duration_ms = 100.0,
        .memory_before = 1024,
        .memory_after = 2048,
    };

    try testing.expectEqualStrings("test", entry.name);
    try testing.expectEqual(@as(i64, 1000), entry.start_time);
    try testing.expectEqual(@as(i64, 1100), entry.end_time);
    try testing.expectEqual(@as(f64, 100.0), entry.duration_ms);
    try testing.expectEqual(@as(usize, 1024), entry.memory_before);
    try testing.expectEqual(@as(usize, 2048), entry.memory_after);
}

// Edge cases and thorough tests

test "Profiler - nested operations" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    try prof.start("outer");
    try prof.start("inner");
    std.time.sleep(1 * std.time.ns_per_ms);
    try prof.end("inner");
    try prof.end("outer");

    try testing.expectEqual(@as(usize, 2), prof.entries.items.len);
    try testing.expect(prof.entries.items[1].duration_ms >= prof.entries.items[0].duration_ms);
}

test "Profiler - same operation multiple times" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    for (0..5) |_| {
        try prof.start("repeated");
        std.time.sleep(1 * std.time.ns_per_ms);
        try prof.end("repeated");
    }

    try testing.expectEqual(@as(usize, 5), prof.entries.items.len);
    for (prof.entries.items) |entry| {
        try testing.expectEqualStrings("repeated", entry.name);
    }
}

test "Profiler - very short duration" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    try prof.start("instant");
    try prof.end("instant");

    try testing.expectEqual(@as(usize, 1), prof.entries.items.len);
    try testing.expect(prof.entries.items[0].duration_ms >= 0.0);
}

test "Profiler - long operation name" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    const long_name = "very_long_operation_name_that_exceeds_normal_expectations_for_testing_purposes";
    try prof.start(long_name);
    try prof.end(long_name);

    try testing.expectEqual(@as(usize, 1), prof.entries.items.len);
    try testing.expectEqualStrings(long_name, prof.entries.items[0].name);
}

test "Profiler - empty operation name" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    try prof.start("");
    try prof.end("");

    try testing.expectEqual(@as(usize, 1), prof.entries.items.len);
    try testing.expectEqualStrings("", prof.entries.items[0].name);
}

test "Profiler - special characters in name" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    const special_name = "op::test-fn_v2.0 [main]";
    try prof.start(special_name);
    try prof.end(special_name);

    try testing.expectEqual(@as(usize, 1), prof.entries.items.len);
    try testing.expectEqualStrings(special_name, prof.entries.items[0].name);
}

test "Profiler - multiple end calls for same operation" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    try prof.start("op");
    try prof.end("op");

    // Second end should be a no-op since operation not started
    try prof.end("op");

    try testing.expectEqual(@as(usize, 1), prof.entries.items.len);
}

test "Profiler - interleaved operations" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    try prof.start("op1");
    try prof.start("op2");
    try prof.end("op1");
    try prof.end("op2");

    try testing.expectEqual(@as(usize, 2), prof.entries.items.len);
}

test "Profiler - clear after multiple operations" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    for (0..10) |i| {
        var buf: [20]u8 = undefined;
        const name = try std.fmt.bufPrint(&buf, "op{d}", .{i});
        try prof.start(name);
        try prof.end(name);
    }

    try testing.expectEqual(@as(usize, 10), prof.entries.items.len);
    prof.clear();
    try testing.expectEqual(@as(usize, 0), prof.entries.items.len);

    // Should be able to profile after clear
    try prof.start("after_clear");
    try prof.end("after_clear");
    try testing.expectEqual(@as(usize, 1), prof.entries.items.len);
}

test "Profiler - report with many entries" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    for (0..100) |i| {
        var buf: [20]u8 = undefined;
        const name = try std.fmt.bufPrint(&buf, "op{d}", .{i});
        try prof.start(name);
        if (i % 2 == 0) {
            std.time.sleep(2 * std.time.ns_per_ms);
        }
        try prof.end(name);
    }

    const report = try prof.getReport();
    defer prof.allocator.free(report);

    try testing.expect(report.len > 0);
    try testing.expect(std.mem.indexOf(u8, report, "Total entries: 100") != null);
}

test "Profiler - measure with error" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    const failFunc = struct {
        fn run() error{TestError}!i32 {
            return error.TestError;
        }
    }.run;

    const result = prof.measure("error_test", failFunc, .{});
    try testing.expectError(error.TestError, result);

    // Entry should still be recorded
    try testing.expectEqual(@as(usize, 1), prof.entries.items.len);
}

test "Profiler - HTML dashboard with zero entries" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    const html = try prof.getHTMLDashboard();
    defer prof.allocator.free(html);

    try testing.expect(std.mem.indexOf(u8, html, "Total entries: 0") != null);
    try testing.expect(std.mem.indexOf(u8, html, "Total time: 0.00ms") != null);
}

test "Profiler - enable/disable functionality" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    prof.enabled = true;
    try prof.start("enabled_op");
    try prof.end("enabled_op");
    try testing.expectEqual(@as(usize, 1), prof.entries.items.len);

    prof.enabled = false;
    try prof.start("disabled_op");
    try prof.end("disabled_op");
    try testing.expectEqual(@as(usize, 1), prof.entries.items.len); // Still 1, not 2
}

test "ProfileEntry - zero duration" {
    const entry = profiler.ProfileEntry{
        .name = "instant",
        .start_time = 1000,
        .end_time = 1000,
        .duration_ms = 0.0,
        .memory_before = 0,
        .memory_after = 0,
    };

    try testing.expectEqual(@as(f64, 0.0), entry.duration_ms);
}

test "ProfileEntry - large memory values" {
    const entry = profiler.ProfileEntry{
        .name = "large_mem",
        .start_time = 0,
        .end_time = 1,
        .duration_ms = 1.0,
        .memory_before = 1024 * 1024 * 1024, // 1GB
        .memory_after = 2 * 1024 * 1024 * 1024, // 2GB
    };

    try testing.expectEqual(@as(usize, 1024 * 1024 * 1024), entry.memory_before);
    try testing.expectEqual(@as(usize, 2 * 1024 * 1024 * 1024), entry.memory_after);
}

test "Profiler - measure function with multiple arguments" {
    var prof = profiler.Profiler.init(testing.allocator);
    defer prof.deinit();

    const multiArgFunc = struct {
        fn run(a: i32, b: i32, c: i32) i32 {
            return a + b + c;
        }
    }.run;

    const result = try prof.measure("multi_arg", multiArgFunc, .{ 10, 20, 30 });

    try testing.expectEqual(@as(i32, 60), result);
    try testing.expectEqual(@as(usize, 1), prof.entries.items.len);
}
