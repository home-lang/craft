const std = @import("std");
const testing = std.testing;
const log_module = @import("../src/log.zig");

test "LogLevel - toString" {
    try testing.expectEqualStrings("DEBUG", log_module.LogLevel.Debug.toString());
    try testing.expectEqualStrings("INFO", log_module.LogLevel.Info.toString());
    try testing.expectEqualStrings("WARN", log_module.LogLevel.Warning.toString());
    try testing.expectEqualStrings("ERROR", log_module.LogLevel.Error.toString());
    try testing.expectEqualStrings("FATAL", log_module.LogLevel.Fatal.toString());
}

test "LogLevel - color codes" {
    try testing.expectEqualStrings("\x1B[36m", log_module.LogLevel.Debug.color());
    try testing.expectEqualStrings("\x1B[32m", log_module.LogLevel.Info.color());
    try testing.expectEqualStrings("\x1B[33m", log_module.LogLevel.Warning.color());
    try testing.expectEqualStrings("\x1B[31m", log_module.LogLevel.Error.color());
    try testing.expectEqualStrings("\x1B[35m", log_module.LogLevel.Fatal.color());
}

test "LogConfig - default values" {
    const config = log_module.LogConfig{};

    try testing.expectEqual(log_module.LogLevel.Info, config.min_level);
    try testing.expect(config.enable_colors);
    try testing.expect(config.enable_timestamps);
    try testing.expect(config.output_file == null);
}

test "LogConfig - custom values" {
    const config = log_module.LogConfig{
        .min_level = .Debug,
        .enable_colors = false,
        .enable_timestamps = false,
        .output_file = "/tmp/test.log",
    };

    try testing.expectEqual(log_module.LogLevel.Debug, config.min_level);
    try testing.expect(!config.enable_colors);
    try testing.expect(!config.enable_timestamps);
    try testing.expectEqualStrings("/tmp/test.log", config.output_file.?);
}

test "Log - init and deinit" {
    const config = log_module.LogConfig{
        .min_level = .Debug,
    };

    try log_module.init(config);
    defer log_module.deinit();

    try testing.expectEqual(log_module.LogLevel.Debug, log_module.getLevel());
}

test "Log - setLevel and getLevel" {
    try log_module.init(.{});
    defer log_module.deinit();

    log_module.setLevel(.Debug);
    try testing.expectEqual(log_module.LogLevel.Debug, log_module.getLevel());

    log_module.setLevel(.Warning);
    try testing.expectEqual(log_module.LogLevel.Warning, log_module.getLevel());

    log_module.setLevel(.Fatal);
    try testing.expectEqual(log_module.LogLevel.Fatal, log_module.getLevel());
}

test "Log - shouldLog with Info level" {
    try log_module.init(.{ .min_level = .Info });
    defer log_module.deinit();

    try testing.expect(!log_module.shouldLog(.Debug));
    try testing.expect(log_module.shouldLog(.Info));
    try testing.expect(log_module.shouldLog(.Warning));
    try testing.expect(log_module.shouldLog(.Error));
    try testing.expect(log_module.shouldLog(.Fatal));
}

test "Log - shouldLog with Debug level" {
    try log_module.init(.{ .min_level = .Debug });
    defer log_module.deinit();

    try testing.expect(log_module.shouldLog(.Debug));
    try testing.expect(log_module.shouldLog(.Info));
    try testing.expect(log_module.shouldLog(.Warning));
    try testing.expect(log_module.shouldLog(.Error));
    try testing.expect(log_module.shouldLog(.Fatal));
}

test "Log - shouldLog with Warning level" {
    try log_module.init(.{ .min_level = .Warning });
    defer log_module.deinit();

    try testing.expect(!log_module.shouldLog(.Debug));
    try testing.expect(!log_module.shouldLog(.Info));
    try testing.expect(log_module.shouldLog(.Warning));
    try testing.expect(log_module.shouldLog(.Error));
    try testing.expect(log_module.shouldLog(.Fatal));
}

test "Log - shouldLog with Error level" {
    try log_module.init(.{ .min_level = .Error });
    defer log_module.deinit();

    try testing.expect(!log_module.shouldLog(.Debug));
    try testing.expect(!log_module.shouldLog(.Info));
    try testing.expect(!log_module.shouldLog(.Warning));
    try testing.expect(log_module.shouldLog(.Error));
    try testing.expect(log_module.shouldLog(.Fatal));
}

test "Log - shouldLog with Fatal level" {
    try log_module.init(.{ .min_level = .Fatal });
    defer log_module.deinit();

    try testing.expect(!log_module.shouldLog(.Debug));
    try testing.expect(!log_module.shouldLog(.Info));
    try testing.expect(!log_module.shouldLog(.Warning));
    try testing.expect(!log_module.shouldLog(.Error));
    try testing.expect(log_module.shouldLog(.Fatal));
}

test "Log - convenience functions exist" {
    try log_module.init(.{ .min_level = .Fatal });
    defer log_module.deinit();

    // These should not panic, just test they exist
    log_module.debug("Debug test {d}", .{42});
    log_module.info("Info test {s}", .{"hello"});
    log_module.warn("Warning test", .{});
    log_module.err("Error test", .{});
    log_module.fatal("Fatal test", .{});

    try testing.expect(true);
}

test "Log - output to file" {
    const test_path = "/tmp/zyte_log_test.log";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const config = log_module.LogConfig{
        .min_level = .Info,
        .output_file = test_path,
    };

    try log_module.init(config);
    defer log_module.deinit();

    log_module.info("Test log message", .{});

    // Verify file was created
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(content);

    try testing.expect(content.len > 0);
    try testing.expect(std.mem.indexOf(u8, content, "Test log message") != null);
}

test "LogLevel - enum ordering" {
    try testing.expect(@intFromEnum(log_module.LogLevel.Debug) < @intFromEnum(log_module.LogLevel.Info));
    try testing.expect(@intFromEnum(log_module.LogLevel.Info) < @intFromEnum(log_module.LogLevel.Warning));
    try testing.expect(@intFromEnum(log_module.LogLevel.Warning) < @intFromEnum(log_module.LogLevel.Error));
    try testing.expect(@intFromEnum(log_module.LogLevel.Error) < @intFromEnum(log_module.LogLevel.Fatal));
}
