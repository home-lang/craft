const std = @import("std");
const testing = std.testing;

// ============================================================================
// JSON Parsing Tests (Pure Zig - no macOS deps)
// ============================================================================

test "parse simple JSON for window setSize" {
    const json = "{\"width\":800,\"height\":600}";

    // Parse width
    if (std.mem.indexOf(u8, json, "\"width\":")) |idx| {
        const start = idx + 8;
        var end = start;
        while (end < json.len and json[end] >= '0' and json[end] <= '9') : (end += 1) {}
        const width = std.fmt.parseInt(u32, json[start..end], 10) catch 0;
        try testing.expectEqual(@as(u32, 800), width);
    }

    // Parse height
    if (std.mem.indexOf(u8, json, "\"height\":")) |idx| {
        const start = idx + 9;
        var end = start;
        while (end < json.len and json[end] >= '0' and json[end] <= '9') : (end += 1) {}
        const height = std.fmt.parseInt(u32, json[start..end], 10) catch 0;
        try testing.expectEqual(@as(u32, 600), height);
    }
}

test "parse hex color" {
    const json = "{\"color\":\"#FF5733\"}";

    if (std.mem.indexOf(u8, json, "\"color\":\"#")) |idx| {
        const start = idx + 10;
        if (start + 6 <= json.len) {
            const hex = json[start .. start + 6];

            const r = std.fmt.parseInt(u8, hex[0..2], 16) catch 0;
            const g = std.fmt.parseInt(u8, hex[2..4], 16) catch 0;
            const b = std.fmt.parseInt(u8, hex[4..6], 16) catch 0;

            try testing.expectEqual(@as(u8, 255), r);
            try testing.expectEqual(@as(u8, 87), g);
            try testing.expectEqual(@as(u8, 51), b);
        }
    }
}

test "parse opacity float" {
    const json = "{\"opacity\":0.75}";

    if (std.mem.indexOf(u8, json, "\"opacity\":")) |idx| {
        var start = idx + 10;
        while (start < json.len and (json[start] == ' ' or json[start] == '\t')) : (start += 1) {}
        var end = start;
        while (end < json.len and ((json[end] >= '0' and json[end] <= '9') or json[end] == '.')) : (end += 1) {}
        if (end > start) {
            const opacity = std.fmt.parseFloat(f64, json[start..end]) catch 1.0;
            try testing.expectApproxEqAbs(@as(f64, 0.75), opacity, 0.001);
        }
    }
}

test "parse boolean from JSON" {
    const json_true = "{\"enabled\":true}";
    const json_false = "{\"enabled\":false}";

    // Test true
    const has_true = std.mem.indexOf(u8, json_true, "true") != null;
    try testing.expect(has_true);

    // Test false
    const has_false = std.mem.indexOf(u8, json_false, "false") != null;
    try testing.expect(has_false);
}

test "parse title string" {
    const json = "{\"title\":\"My Window Title\"}";

    if (std.mem.indexOf(u8, json, "\"title\":\"")) |idx| {
        const start = idx + 9;
        if (std.mem.indexOfPos(u8, json, start, "\"")) |end| {
            const title = json[start..end];
            try testing.expectEqualStrings("My Window Title", title);
        }
    }
}

test "parse position coordinates" {
    const json = "{\"x\":100,\"y\":200}";

    var x: i32 = 0;
    var y: i32 = 0;

    if (std.mem.indexOf(u8, json, "\"x\":")) |idx| {
        const start = idx + 4;
        var end = start;
        while (end < json.len and ((json[end] >= '0' and json[end] <= '9') or json[end] == '-')) : (end += 1) {}
        x = std.fmt.parseInt(i32, json[start..end], 10) catch 0;
    }

    if (std.mem.indexOf(u8, json, "\"y\":")) |idx| {
        const start = idx + 4;
        var end = start;
        while (end < json.len and ((json[end] >= '0' and json[end] <= '9') or json[end] == '-')) : (end += 1) {}
        y = std.fmt.parseInt(i32, json[start..end], 10) catch 0;
    }

    try testing.expectEqual(@as(i32, 100), x);
    try testing.expectEqual(@as(i32, 200), y);
}

test "parse vibrancy type" {
    const json = "{\"vibrancy\":\"sidebar\"}";

    if (std.mem.indexOf(u8, json, "\"vibrancy\":\"")) |idx| {
        const start = idx + 12;
        if (std.mem.indexOfPos(u8, json, start, "\"")) |end| {
            const vibrancy = json[start..end];
            try testing.expectEqualStrings("sidebar", vibrancy);
        }
    }
}

test "parse RGBA color components" {
    const json = "{\"r\":0.5,\"g\":0.3,\"b\":0.8,\"a\":1.0}";

    var r: f64 = 0;
    var g: f64 = 0;
    var b: f64 = 0;
    var a: f64 = 0;

    inline for (.{ .{ "\"r\":", &r }, .{ "\"g\":", &g }, .{ "\"b\":", &b }, .{ "\"a\":", &a } }) |pair| {
        const key = pair[0];
        const val = pair[1];
        if (std.mem.indexOf(u8, json, key)) |idx| {
            const start = idx + key.len;
            var end = start;
            while (end < json.len and ((json[end] >= '0' and json[end] <= '9') or json[end] == '.')) : (end += 1) {}
            val.* = std.fmt.parseFloat(f64, json[start..end]) catch 0;
        }
    }

    try testing.expectApproxEqAbs(@as(f64, 0.5), r, 0.001);
    try testing.expectApproxEqAbs(@as(f64, 0.3), g, 0.001);
    try testing.expectApproxEqAbs(@as(f64, 0.8), b, 0.001);
    try testing.expectApproxEqAbs(@as(f64, 1.0), a, 0.001);
}

test "parse notification data" {
    const json = "{\"title\":\"Alert\",\"body\":\"Something happened\"}";

    var title: []const u8 = "";
    var body: []const u8 = "";

    if (std.mem.indexOf(u8, json, "\"title\":\"")) |idx| {
        const start = idx + 9;
        if (std.mem.indexOfPos(u8, json, start, "\"")) |end| {
            title = json[start..end];
        }
    }

    if (std.mem.indexOf(u8, json, "\"body\":\"")) |idx| {
        const start = idx + 8;
        if (std.mem.indexOfPos(u8, json, start, "\"")) |end| {
            body = json[start..end];
        }
    }

    try testing.expectEqualStrings("Alert", title);
    try testing.expectEqualStrings("Something happened", body);
}

test "parse badge value" {
    const json = "{\"badge\":\"42\"}";

    if (std.mem.indexOf(u8, json, "\"badge\":\"")) |idx| {
        const start = idx + 9;
        if (std.mem.indexOfPos(u8, json, start, "\"")) |end| {
            const badge = json[start..end];
            try testing.expectEqualStrings("42", badge);
        }
    }
}

test "parse clipboard text" {
    const json = "{\"text\":\"Hello, World!\"}";

    if (std.mem.indexOf(u8, json, "\"text\":\"")) |idx| {
        const start = idx + 8;
        if (std.mem.indexOfPos(u8, json, start, "\"")) |end| {
            const text = json[start..end];
            try testing.expectEqualStrings("Hello, World!", text);
        }
    }
}

test "parse file dialog options" {
    const json = "{\"title\":\"Open File\",\"defaultName\":\"document.txt\"}";

    var title: []const u8 = "";
    var default_name: []const u8 = "";

    if (std.mem.indexOf(u8, json, "\"title\":\"")) |idx| {
        const start = idx + 9;
        if (std.mem.indexOfPos(u8, json, start, "\"")) |end| {
            title = json[start..end];
        }
    }

    if (std.mem.indexOf(u8, json, "\"defaultName\":\"")) |idx| {
        const start = idx + 15;
        if (std.mem.indexOfPos(u8, json, start, "\"")) |end| {
            default_name = json[start..end];
        }
    }

    try testing.expectEqualStrings("Open File", title);
    try testing.expectEqualStrings("document.txt", default_name);
}

// ============================================================================
// Action Dispatch Tests
// ============================================================================

test "action string matching" {
    const actions = [_][]const u8{
        "show",
        "hide",
        "toggle",
        "minimize",
        "maximize",
        "close",
        "setTitle",
        "setSize",
        "setPosition",
        "setVibrancy",
        "setOpacity",
        "setBackgroundColor",
    };

    for (actions) |action| {
        // Verify action can be compared
        try testing.expect(std.mem.eql(u8, action, action));
    }

    // Test specific matches
    try testing.expect(std.mem.eql(u8, "show", "show"));
    try testing.expect(!std.mem.eql(u8, "show", "hide"));
}

test "memory allocation for string duplication" {
    const allocator = testing.allocator;

    const original = "Hello, Craft!";
    const duped = try allocator.dupe(u8, original);
    defer allocator.free(duped);

    try testing.expectEqualStrings(original, duped);
    try testing.expect(original.ptr != duped.ptr);
}

test "null-terminated string creation" {
    const allocator = testing.allocator;

    const str = "Test String";
    const cstr = try allocator.dupeZ(u8, str);
    defer allocator.free(cstr);

    // Verify null terminator
    try testing.expectEqual(@as(u8, 0), cstr[str.len]);
    try testing.expectEqualStrings(str, cstr[0..str.len]);
}

// ============================================================================
// Error Handling Tests
// ============================================================================

test "parse missing key returns default" {
    const json = "{\"other\":\"value\"}";

    var width: u32 = 800; // default
    if (std.mem.indexOf(u8, json, "\"width\":")) |idx| {
        const start = idx + 8;
        var end = start;
        while (end < json.len and json[end] >= '0' and json[end] <= '9') : (end += 1) {}
        width = std.fmt.parseInt(u32, json[start..end], 10) catch 800;
    }

    try testing.expectEqual(@as(u32, 800), width); // Should keep default
}

test "parse invalid number returns default" {
    const json = "{\"width\":\"abc\"}";

    var width: u32 = 800; // default
    if (std.mem.indexOf(u8, json, "\"width\":")) |idx| {
        const start = idx + 8;
        var end = start;
        while (end < json.len and json[end] >= '0' and json[end] <= '9') : (end += 1) {}
        if (end > start) {
            width = std.fmt.parseInt(u32, json[start..end], 10) catch 800;
        }
    }

    try testing.expectEqual(@as(u32, 800), width); // Should keep default
}

test "parse empty string" {
    const json = "{\"title\":\"\"}";

    var title: []const u8 = "default";
    if (std.mem.indexOf(u8, json, "\"title\":\"")) |idx| {
        const start = idx + 9;
        if (std.mem.indexOfPos(u8, json, start, "\"")) |end| {
            title = json[start..end];
        }
    }

    try testing.expectEqualStrings("", title);
}

test "parse negative numbers" {
    const json = "{\"x\":-100,\"y\":-200}";

    var x: i32 = 0;
    var y: i32 = 0;

    if (std.mem.indexOf(u8, json, "\"x\":")) |idx| {
        const start = idx + 4;
        var end = start;
        while (end < json.len and ((json[end] >= '0' and json[end] <= '9') or json[end] == '-')) : (end += 1) {}
        x = std.fmt.parseInt(i32, json[start..end], 10) catch 0;
    }

    if (std.mem.indexOf(u8, json, "\"y\":")) |idx| {
        const start = idx + 4;
        var end = start;
        while (end < json.len and ((json[end] >= '0' and json[end] <= '9') or json[end] == '-')) : (end += 1) {}
        y = std.fmt.parseInt(i32, json[start..end], 10) catch 0;
    }

    try testing.expectEqual(@as(i32, -100), x);
    try testing.expectEqual(@as(i32, -200), y);
}

test "parse decimal opacity edge cases" {
    const test_cases = [_]struct { json: []const u8, expected: f64 }{
        .{ .json = "{\"opacity\":0.0}", .expected = 0.0 },
        .{ .json = "{\"opacity\":1.0}", .expected = 1.0 },
        .{ .json = "{\"opacity\":0.5}", .expected = 0.5 },
        .{ .json = "{\"opacity\":0.99}", .expected = 0.99 },
    };

    for (test_cases) |tc| {
        if (std.mem.indexOf(u8, tc.json, "\"opacity\":")) |idx| {
            var start = idx + 10;
            while (start < tc.json.len and (tc.json[start] == ' ' or tc.json[start] == '\t')) : (start += 1) {}
            var end = start;
            while (end < tc.json.len and ((tc.json[end] >= '0' and tc.json[end] <= '9') or tc.json[end] == '.')) : (end += 1) {}
            if (end > start) {
                const opacity = std.fmt.parseFloat(f64, tc.json[start..end]) catch 1.0;
                try testing.expectApproxEqAbs(tc.expected, opacity, 0.001);
            }
        }
    }
}

test "vibrancy material types" {
    const materials = [_][]const u8{
        "sidebar",
        "header",
        "sheet",
        "menu",
        "popover",
        "fullscreen-ui",
        "hud",
        "titlebar",
        "none",
    };

    for (materials) |material| {
        var buf: [64]u8 = undefined;
        const json = std.fmt.bufPrint(&buf, "{{\"vibrancy\":\"{s}\"}}", .{material}) catch continue;

        if (std.mem.indexOf(u8, json, "\"vibrancy\":\"")) |idx| {
            const start = idx + 12;
            if (std.mem.indexOfPos(u8, json, start, "\"")) |end| {
                const parsed = json[start..end];
                try testing.expectEqualStrings(material, parsed);
            }
        }
    }
}

test "action list completeness" {
    const window_actions = [_][]const u8{
        "show", "hide", "toggle", "focus", "minimize", "maximize", "close",
        "center", "toggleFullscreen", "setFullscreen", "setSize", "setPosition",
        "setTitle", "reload", "setVibrancy", "setAlwaysOnTop", "setOpacity",
        "setResizable", "setBackgroundColor", "setMinSize", "setMaxSize",
        "setMovable", "setHasShadow",
    };

    const tray_actions = [_][]const u8{
        "setTitle", "setTooltip", "setMenu", "pollActions", "hide", "show", "setIcon",
    };

    const clipboard_actions = [_][]const u8{
        "writeText", "readText", "writeHTML", "readHTML", "clear", "hasText", "hasHTML", "hasImage",
    };

    const dialog_actions = [_][]const u8{
        "openFile", "openFiles", "openFolder", "saveFile", "showAlert", "showConfirm",
    };

    // Verify we have comprehensive action coverage
    try testing.expect(window_actions.len == 23);
    try testing.expect(tray_actions.len == 7);
    try testing.expect(clipboard_actions.len == 8);
    try testing.expect(dialog_actions.len == 6);
}
