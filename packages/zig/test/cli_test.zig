const std = @import("std");
const testing = std.testing;
const cli = @import("../src/cli.zig");

test "WindowOptions - default values" {
    const options = cli.WindowOptions{};

    try testing.expect(options.url == null);
    try testing.expect(options.html == null);
    try testing.expectEqualStrings("Craft App", options.title);
    try testing.expectEqual(@as(u32, 1200), options.width);
    try testing.expectEqual(@as(u32, 800), options.height);
    try testing.expect(options.x == null);
    try testing.expect(options.y == null);
    try testing.expect(!options.frameless);
    try testing.expect(!options.transparent);
    try testing.expect(!options.always_on_top);
    try testing.expect(options.resizable);
    try testing.expect(!options.fullscreen);
    try testing.expect(options.dev_tools);
    try testing.expect(options.dark_mode == null);
    try testing.expect(!options.hot_reload);
    try testing.expect(!options.system_tray);
}

test "WindowOptions - custom values" {
    const options = cli.WindowOptions{
        .url = "http://example.com",
        .html = "<h1>Test</h1>",
        .title = "Custom Title",
        .width = 800,
        .height = 600,
        .x = 100,
        .y = 50,
        .frameless = true,
        .transparent = true,
        .always_on_top = true,
        .resizable = false,
        .fullscreen = true,
        .dev_tools = false,
        .dark_mode = true,
        .hot_reload = true,
        .system_tray = true,
    };

    try testing.expectEqualStrings("http://example.com", options.url.?);
    try testing.expectEqualStrings("<h1>Test</h1>", options.html.?);
    try testing.expectEqualStrings("Custom Title", options.title);
    try testing.expectEqual(@as(u32, 800), options.width);
    try testing.expectEqual(@as(u32, 600), options.height);
    try testing.expectEqual(@as(i32, 100), options.x.?);
    try testing.expectEqual(@as(i32, 50), options.y.?);
    try testing.expect(options.frameless);
    try testing.expect(options.transparent);
    try testing.expect(options.always_on_top);
    try testing.expect(!options.resizable);
    try testing.expect(options.fullscreen);
    try testing.expect(!options.dev_tools);
    try testing.expectEqual(true, options.dark_mode.?);
    try testing.expect(options.hot_reload);
    try testing.expect(options.system_tray);
}

test "CliError - error types exist" {
    const err1: cli.CliError = error.InvalidArgument;
    const err2: cli.CliError = error.MissingValue;
    const err3: cli.CliError = error.InvalidNumber;

    try testing.expectError(error.InvalidArgument, err1);
    try testing.expectError(error.MissingValue, err2);
    try testing.expectError(error.InvalidNumber, err3);
}

test "WindowOptions - position coordinates" {
    const options = cli.WindowOptions{
        .x = -100,
        .y = 2000,
    };

    try testing.expectEqual(@as(i32, -100), options.x.?);
    try testing.expectEqual(@as(i32, 2000), options.y.?);
}

test "WindowOptions - minimum dimensions" {
    const options = cli.WindowOptions{
        .width = 1,
        .height = 1,
    };

    try testing.expectEqual(@as(u32, 1), options.width);
    try testing.expectEqual(@as(u32, 1), options.height);
}

test "WindowOptions - large dimensions" {
    const options = cli.WindowOptions{
        .width = 4096,
        .height = 2160,
    };

    try testing.expectEqual(@as(u32, 4096), options.width);
    try testing.expectEqual(@as(u32, 2160), options.height);
}

test "WindowOptions - dark_mode three states" {
    const options1 = cli.WindowOptions{ .dark_mode = true };
    const options2 = cli.WindowOptions{ .dark_mode = false };
    const options3 = cli.WindowOptions{ .dark_mode = null };

    try testing.expectEqual(true, options1.dark_mode.?);
    try testing.expectEqual(false, options2.dark_mode.?);
    try testing.expect(options3.dark_mode == null);
}

test "WindowOptions - url and html mutually exclusive usage" {
    const options1 = cli.WindowOptions{
        .url = "http://example.com",
        .html = null,
    };

    const options2 = cli.WindowOptions{
        .url = null,
        .html = "<h1>Test</h1>",
    };

    try testing.expectEqualStrings("http://example.com", options1.url.?);
    try testing.expect(options1.html == null);

    try testing.expect(options2.url == null);
    try testing.expectEqualStrings("<h1>Test</h1>", options2.html.?);
}

test "WindowOptions - boolean flags combinations" {
    const options = cli.WindowOptions{
        .frameless = true,
        .transparent = true,
        .always_on_top = true,
        .fullscreen = false,
    };

    try testing.expect(options.frameless);
    try testing.expect(options.transparent);
    try testing.expect(options.always_on_top);
    try testing.expect(!options.fullscreen);
}

test "WindowOptions - feature flags" {
    const options = cli.WindowOptions{
        .dev_tools = false,
        .hot_reload = true,
        .system_tray = true,
    };

    try testing.expect(!options.dev_tools);
    try testing.expect(options.hot_reload);
    try testing.expect(options.system_tray);
}

test "WindowOptions - title variations" {
    const options1 = cli.WindowOptions{ .title = "" };
    const options2 = cli.WindowOptions{ .title = "A" };
    const options3 = cli.WindowOptions{ .title = "Very Long Title With Many Words And Special Characters !@#$%^&*()" };

    try testing.expectEqualStrings("", options1.title);
    try testing.expectEqualStrings("A", options2.title);
    try testing.expect(options3.title.len > 50);
}

test "WindowOptions - coordinate extremes" {
    const options = cli.WindowOptions{
        .x = -32768,
        .y = 32767,
    };

    try testing.expectEqual(@as(i32, -32768), options.x.?);
    try testing.expectEqual(@as(i32, 32767), options.y.?);
}

test "WindowOptions - all boolean flags false" {
    const options = cli.WindowOptions{
        .frameless = false,
        .transparent = false,
        .always_on_top = false,
        .resizable = false,
        .fullscreen = false,
        .dev_tools = false,
        .hot_reload = false,
        .system_tray = false,
    };

    try testing.expect(!options.frameless);
    try testing.expect(!options.transparent);
    try testing.expect(!options.always_on_top);
    try testing.expect(!options.resizable);
    try testing.expect(!options.fullscreen);
    try testing.expect(!options.dev_tools);
    try testing.expect(!options.hot_reload);
    try testing.expect(!options.system_tray);
}

test "WindowOptions - all boolean flags true" {
    const options = cli.WindowOptions{
        .frameless = true,
        .transparent = true,
        .always_on_top = true,
        .resizable = true,
        .fullscreen = true,
        .dev_tools = true,
        .hot_reload = true,
        .system_tray = true,
    };

    try testing.expect(options.frameless);
    try testing.expect(options.transparent);
    try testing.expect(options.always_on_top);
    try testing.expect(options.resizable);
    try testing.expect(options.fullscreen);
    try testing.expect(options.dev_tools);
    try testing.expect(options.hot_reload);
    try testing.expect(options.system_tray);
}
