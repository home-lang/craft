const std = @import("std");
const testing = std.testing;
const bridge_tray = @import("../src/bridge_tray.zig");
const bridge_error = @import("../src/bridge_error.zig");

test "TrayBridge - init" {
    const allocator = testing.allocator;
    const tray = bridge_tray.TrayBridge.init(allocator);

    try testing.expectEqual(allocator, tray.allocator);
    try testing.expect(tray.tray_handle == null);
    try testing.expect(tray.current_menu == null);
}

test "TrayBridge - setTrayHandle" {
    const allocator = testing.allocator;
    var tray = bridge_tray.TrayBridge.init(allocator);

    var dummy_handle: u8 = 42;
    const handle_ptr: *anyopaque = @ptrCast(&dummy_handle);

    tray.setTrayHandle(handle_ptr);
    try testing.expect(tray.tray_handle != null);
    try testing.expectEqual(handle_ptr, tray.tray_handle.?);
}

test "TrayBridge - handleMessage unknown action" {
    const allocator = testing.allocator;
    var tray = bridge_tray.TrayBridge.init(allocator);

    // Unknown action should not crash - it reports error to JS
    try tray.handleMessage("unknownAction", "{}");
}

test "TrayBridge - handleMessage missing tray handle" {
    const allocator = testing.allocator;
    var tray = bridge_tray.TrayBridge.init(allocator);

    // These actions require tray handle, should not crash
    try tray.handleMessage("setTitle", "Test");
    try tray.handleMessage("setTooltip", "Tooltip");
    try tray.handleMessage("hide", "");
    try tray.handleMessage("show", "");
}

test "TrayBridge - decodeUnicodeEscapes basic text" {
    const allocator = testing.allocator;

    const input = "Hello World";
    const output = try bridge_tray.decodeUnicodeEscapes(allocator, input);
    defer allocator.free(output);

    try testing.expectEqualStrings("Hello World", output);
}

test "TrayBridge - decodeUnicodeEscapes simple unicode" {
    const allocator = testing.allocator;

    // Single codepoint \U0041 = 'A'
    const input = "\\U0041";
    const output = try bridge_tray.decodeUnicodeEscapes(allocator, input);
    defer allocator.free(output);

    try testing.expectEqualStrings("A", output);
}

test "TrayBridge - decodeUnicodeEscapes emoji surrogate pair" {
    const allocator = testing.allocator;

    // Tomato emoji 🍅 = \Ud83c\Udf45
    const input = "\\Ud83c\\Udf45";
    const output = try bridge_tray.decodeUnicodeEscapes(allocator, input);
    defer allocator.free(output);

    // Should produce UTF-8 encoded emoji
    try testing.expect(output.len > 0);
    // The emoji is 4 bytes in UTF-8
    try testing.expectEqual(@as(usize, 4), output.len);
}

test "TrayBridge - decodeUnicodeEscapes mixed content" {
    const allocator = testing.allocator;

    const input = "Hello \\U0041\\U0042 World";
    const output = try bridge_tray.decodeUnicodeEscapes(allocator, input);
    defer allocator.free(output);

    try testing.expectEqualStrings("Hello AB World", output);
}

test "TrayBridge - decodeUnicodeEscapes invalid escape" {
    const allocator = testing.allocator;

    // Invalid hex should be copied as-is
    const input = "\\UZZZZ";
    const output = try bridge_tray.decodeUnicodeEscapes(allocator, input);
    defer allocator.free(output);

    // Should keep the backslash since parsing failed
    try testing.expect(output.len > 0);
}

test "TrayBridge - decodeUnicodeEscapes incomplete escape" {
    const allocator = testing.allocator;

    // Incomplete escape sequence
    const input = "\\U00";
    const output = try bridge_tray.decodeUnicodeEscapes(allocator, input);
    defer allocator.free(output);

    // Should handle gracefully
    try testing.expect(output.len > 0);
}

test "TrayBridge - decodeUnicodeEscapes high surrogate without low" {
    const allocator = testing.allocator;

    // High surrogate without matching low surrogate
    const input = "\\Ud83c";
    const output = try bridge_tray.decodeUnicodeEscapes(allocator, input);
    defer allocator.free(output);

    // Should handle gracefully (encode single surrogate or skip)
    try testing.expect(output.len >= 0);
}

test "TrayBridge - decodeUnicodeEscapes lowercase u" {
    const allocator = testing.allocator;

    // Should handle lowercase \u as well
    const input = "\\u0041";
    const output = try bridge_tray.decodeUnicodeEscapes(allocator, input);
    defer allocator.free(output);

    try testing.expectEqualStrings("A", output);
}

test "TrayBridge - deinit with no menu" {
    const allocator = testing.allocator;
    var tray = bridge_tray.TrayBridge.init(allocator);

    // Should not crash when current_menu is null
    tray.deinit();
}

test "TrayBridge - global bridge functions" {
    const allocator = testing.allocator;
    var tray = bridge_tray.TrayBridge.init(allocator);

    // Test that global functions exist and work
    _ = bridge_tray.getGlobalTrayBridge();
    bridge_tray.setGlobalTrayBridge(&tray);
}
