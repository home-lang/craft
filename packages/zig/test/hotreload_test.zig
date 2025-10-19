const std = @import("std");
const testing = std.testing;
const hotreload = @import("../src/hotreload.zig");

test "HotReloadConfig - default values" {
    const config = hotreload.HotReloadConfig{};

    try testing.expect(config.enabled);
    try testing.expectEqual(@as(usize, 0), config.watch_paths.len);
    try testing.expectEqual(@as(usize, 3), config.ignore_patterns.len);
    try testing.expectEqual(@as(u64, 300), config.debounce_ms);
    try testing.expect(config.auto_reload);
    try testing.expect(config.reload_on_save);
}

test "HotReloadConfig - custom values" {
    const paths = [_][]const u8{ "src", "public" };
    const patterns = [_][]const u8{".tmp"};

    const config = hotreload.HotReloadConfig{
        .enabled = false,
        .watch_paths = &paths,
        .ignore_patterns = &patterns,
        .debounce_ms = 500,
        .auto_reload = false,
        .reload_on_save = false,
    };

    try testing.expect(!config.enabled);
    try testing.expectEqual(@as(usize, 2), config.watch_paths.len);
    try testing.expectEqual(@as(usize, 1), config.ignore_patterns.len);
    try testing.expectEqual(@as(u64, 500), config.debounce_ms);
    try testing.expect(!config.auto_reload);
    try testing.expect(!config.reload_on_save);
}

test "FileWatcher - init and deinit" {
    const config = hotreload.HotReloadConfig{};

    var watcher = try hotreload.FileWatcher.init(testing.allocator, config);
    defer watcher.deinit();

    try testing.expectEqual(@as(usize, 0), watcher.watched_paths.count());
}

test "FileWatcher - shouldIgnore" {
    const config = hotreload.HotReloadConfig{};

    var watcher = try hotreload.FileWatcher.init(testing.allocator, config);
    defer watcher.deinit();

    try testing.expect(watcher.shouldIgnore("path/to/.git/file"));
    try testing.expect(watcher.shouldIgnore("project/node_modules/package"));
    try testing.expect(watcher.shouldIgnore("folder/.DS_Store"));
    try testing.expect(!watcher.shouldIgnore("src/main.zig"));
}

test "FileWatcher - debounce behavior" {
    const config = hotreload.HotReloadConfig{
        .debounce_ms = 1000,
    };

    var watcher = try hotreload.FileWatcher.init(testing.allocator, config);
    defer watcher.deinit();

    try testing.expectEqual(@as(u64, 1000), watcher.debounce_ms);
    try testing.expectEqual(@as(i64, 0), watcher.last_reload);
}

test "HotReload - init with disabled config" {
    const config = hotreload.HotReloadConfig{
        .enabled = false,
    };

    var hr = try hotreload.HotReload.init(testing.allocator, config);
    defer hr.deinit();

    try testing.expect(!hr.config.enabled);
    try testing.expect(hr.watcher == null);
    try testing.expect(!hr.running);
}

test "HotReload - init with enabled config but no paths" {
    const config = hotreload.HotReloadConfig{
        .enabled = true,
    };

    var hr = try hotreload.HotReload.init(testing.allocator, config);
    defer hr.deinit();

    try testing.expect(hr.config.enabled);
    try testing.expect(hr.watcher == null);
}

test "HotReload - setCallback" {
    var called = false;
    const testCallback = struct {
        fn callback() void {
            called = true;
        }
    }.callback;

    const config = hotreload.HotReloadConfig{};

    var hr = try hotreload.HotReload.init(testing.allocator, config);
    defer hr.deinit();

    hr.setCallback(testCallback);

    try testing.expect(hr.callback != null);
}

test "HotReload - start and stop" {
    const config = hotreload.HotReloadConfig{};

    var hr = try hotreload.HotReload.init(testing.allocator, config);
    defer hr.deinit();

    try testing.expect(!hr.running);

    hr.start();
    try testing.expect(hr.running);

    hr.stop();
    try testing.expect(!hr.running);
}

test "HotReload - poll when not running" {
    const config = hotreload.HotReloadConfig{};

    var hr = try hotreload.HotReload.init(testing.allocator, config);
    defer hr.deinit();

    try hr.poll();

    try testing.expect(true);
}

test "HotReload - poll when no watcher" {
    const config = hotreload.HotReloadConfig{};

    var hr = try hotreload.HotReload.init(testing.allocator, config);
    defer hr.deinit();

    hr.start();
    try hr.poll();

    try testing.expect(true);
}

test "client_script - exists and contains expected content" {
    try testing.expect(hotreload.client_script.len > 0);
    try testing.expect(std.mem.indexOf(u8, hotreload.client_script, "<script>") != null);
    try testing.expect(std.mem.indexOf(u8, hotreload.client_script, "WebSocket") != null);
    try testing.expect(std.mem.indexOf(u8, hotreload.client_script, "_zyte_reload") != null);
    try testing.expect(std.mem.indexOf(u8, hotreload.client_script, "location.reload") != null);
    try testing.expect(std.mem.indexOf(u8, hotreload.client_script, "</script>") != null);
}

test "HotReloadConfig - ignore_patterns default" {
    const config = hotreload.HotReloadConfig{};

    try testing.expectEqualStrings(".git", config.ignore_patterns[0]);
    try testing.expectEqualStrings("node_modules", config.ignore_patterns[1]);
    try testing.expectEqualStrings(".DS_Store", config.ignore_patterns[2]);
}

test "FileWatcher - multiple ignore patterns" {
    const patterns = [_][]const u8{ ".tmp", ".cache", "build" };
    const config = hotreload.HotReloadConfig{
        .ignore_patterns = &patterns,
    };

    var watcher = try hotreload.FileWatcher.init(testing.allocator, config);
    defer watcher.deinit();

    try testing.expect(watcher.shouldIgnore("file.tmp"));
    try testing.expect(watcher.shouldIgnore("data.cache"));
    try testing.expect(watcher.shouldIgnore("build/output"));
    try testing.expect(!watcher.shouldIgnore("src/main.zig"));
}
