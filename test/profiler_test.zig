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
