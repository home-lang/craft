const std = @import("std");
const testing = std.testing;
const config = @import("../src/config.zig");
const c_fs = @cImport({
    @cInclude("unistd.h");
    @cInclude("stdio.h");
});

test "WindowConfig - default values" {
    const window = config.WindowConfig{};

    try testing.expectEqualStrings("Craft App", window.title);
    try testing.expectEqual(@as(u32, 1200), window.width);
    try testing.expectEqual(@as(u32, 800), window.height);
    try testing.expect(window.x == null);
    try testing.expect(window.y == null);
    try testing.expect(window.resizable);
    try testing.expect(!window.frameless);
    try testing.expect(!window.transparent);
    try testing.expect(!window.always_on_top);
    try testing.expect(!window.fullscreen);
    try testing.expect(window.dark_mode == null);
}

test "WindowConfig - custom values" {
    const window = config.WindowConfig{
        .title = "Custom App",
        .width = 800,
        .height = 600,
        .x = 100,
        .y = 50,
        .resizable = false,
        .frameless = true,
        .transparent = true,
        .always_on_top = true,
        .fullscreen = true,
        .dark_mode = true,
    };

    try testing.expectEqualStrings("Custom App", window.title);
    try testing.expectEqual(@as(u32, 800), window.width);
    try testing.expectEqual(@as(u32, 600), window.height);
    try testing.expectEqual(@as(i32, 100), window.x.?);
    try testing.expectEqual(@as(i32, 50), window.y.?);
    try testing.expect(!window.resizable);
    try testing.expect(window.frameless);
    try testing.expect(window.transparent);
    try testing.expect(window.always_on_top);
    try testing.expect(window.fullscreen);
    try testing.expectEqual(true, window.dark_mode.?);
}

test "WebViewConfig - default values" {
    const webview = config.WebViewConfig{};

    try testing.expect(webview.dev_tools);
    try testing.expect(webview.user_agent == null);
}

test "WebViewConfig - custom values" {
    const webview = config.WebViewConfig{
        .dev_tools = false,
        .user_agent = "Custom UserAgent/1.0",
    };

    try testing.expect(!webview.dev_tools);
    try testing.expectEqualStrings("Custom UserAgent/1.0", webview.user_agent.?);
}

test "AppConfig - default values" {
    const app = config.AppConfig{};

    try testing.expect(!app.hot_reload);
    try testing.expect(!app.system_tray);
    try testing.expectEqualStrings("info", app.log_level);
    try testing.expect(app.log_file == null);
}

test "AppConfig - custom values" {
    const app = config.AppConfig{
        .hot_reload = true,
        .system_tray = true,
        .log_level = "debug",
        .log_file = "/var/log/app.log",
    };

    try testing.expect(app.hot_reload);
    try testing.expect(app.system_tray);
    try testing.expectEqualStrings("debug", app.log_level);
    try testing.expectEqualStrings("/var/log/app.log", app.log_file.?);
}

test "Config - default initialization" {
    const cfg = config.Config{};

    try testing.expectEqualStrings("Craft App", cfg.window.title);
    try testing.expect(cfg.webview.dev_tools);
    try testing.expect(!cfg.app.hot_reload);
}

test "Config - parseToml window section" {
    const toml_content =
        \\[window]
        \\title = "Test App"
        \\width = 1024
        \\height = 768
        \\x = 100
        \\y = 200
        \\resizable = false
        \\frameless = true
    ;

    const cfg = try config.Config.parseToml(testing.allocator, toml_content);

    try testing.expectEqualStrings("Test App", cfg.window.title);
    try testing.expectEqual(@as(u32, 1024), cfg.window.width);
    try testing.expectEqual(@as(u32, 768), cfg.window.height);
    try testing.expectEqual(@as(i32, 100), cfg.window.x.?);
    try testing.expectEqual(@as(i32, 200), cfg.window.y.?);
    try testing.expect(!cfg.window.resizable);
    try testing.expect(cfg.window.frameless);
}

test "Config - parseToml webview section" {
    const toml_content =
        \\[webview]
        \\dev_tools = false
        \\user_agent = "TestAgent/1.0"
    ;

    const cfg = try config.Config.parseToml(testing.allocator, toml_content);

    try testing.expect(!cfg.webview.dev_tools);
    try testing.expectEqualStrings("TestAgent/1.0", cfg.webview.user_agent.?);
}

test "Config - parseToml app section" {
    const toml_content =
        \\[app]
        \\hot_reload = true
        \\system_tray = true
        \\log_level = "debug"
        \\log_file = "/tmp/test.log"
    ;

    const cfg = try config.Config.parseToml(testing.allocator, toml_content);

    try testing.expect(cfg.app.hot_reload);
    try testing.expect(cfg.app.system_tray);
    try testing.expectEqualStrings("debug", cfg.app.log_level);
    try testing.expectEqualStrings("/tmp/test.log", cfg.app.log_file.?);
}

test "Config - parseToml with comments" {
    const toml_content =
        \\# This is a comment
        \\[window]
        \\# Another comment
        \\width = 800
        \\height = 600
    ;

    const cfg = try config.Config.parseToml(testing.allocator, toml_content);

    try testing.expectEqual(@as(u32, 800), cfg.window.width);
    try testing.expectEqual(@as(u32, 600), cfg.window.height);
}

test "Config - parseToml with empty lines" {
    const toml_content =
        \\
        \\[window]
        \\
        \\width = 640
        \\
        \\height = 480
        \\
    ;

    const cfg = try config.Config.parseToml(testing.allocator, toml_content);

    try testing.expectEqual(@as(u32, 640), cfg.window.width);
    try testing.expectEqual(@as(u32, 480), cfg.window.height);
}

test "Config - parseToml dark_mode true" {
    const toml_content =
        \\[window]
        \\dark_mode = true
    ;

    const cfg = try config.Config.parseToml(testing.allocator, toml_content);
    try testing.expectEqual(true, cfg.window.dark_mode.?);
}

test "Config - parseToml dark_mode false" {
    const toml_content =
        \\[window]
        \\dark_mode = false
    ;

    const cfg = try config.Config.parseToml(testing.allocator, toml_content);
    try testing.expectEqual(false, cfg.window.dark_mode.?);
}

test "Config - saveToFile and loadFromFile" {
    const test_path = "/tmp/craft_test_config.toml";
    defer _ = c_fs.remove(test_path);

    const original = config.Config{
        .window = .{
            .title = "Test Save",
            .width = 1000,
            .height = 750,
        },
        .app = .{
            .hot_reload = true,
            .log_level = "debug",
        },
    };

    try original.saveToFile(test_path);

    const loaded = try config.Config.loadFromFile(testing.allocator, test_path);

    try testing.expectEqual(original.window.width, loaded.window.width);
    try testing.expectEqual(original.window.height, loaded.window.height);
    try testing.expectEqual(original.app.hot_reload, loaded.app.hot_reload);
}
