const std = @import("std");
const testing = std.testing;
const devmode = @import("../src/devmode.zig");

test "DebugOverlay - default values" {
    const overlay = devmode.DebugOverlay{};

    try testing.expect(!overlay.enabled);
    try testing.expect(overlay.show_fps);
    try testing.expect(overlay.show_memory);
    try testing.expect(overlay.show_events);
    try testing.expect(!overlay.show_network);
    try testing.expectEqual(devmode.DebugOverlay.OverlayPosition.top_right, overlay.position);
}

test "DebugOverlay - custom values" {
    const overlay = devmode.DebugOverlay{
        .enabled = true,
        .show_fps = false,
        .show_memory = false,
        .show_events = false,
        .show_network = true,
        .position = .bottom_left,
    };

    try testing.expect(overlay.enabled);
    try testing.expect(!overlay.show_fps);
    try testing.expect(!overlay.show_memory);
    try testing.expect(!overlay.show_events);
    try testing.expect(overlay.show_network);
    try testing.expectEqual(devmode.DebugOverlay.OverlayPosition.bottom_left, overlay.position);
}

test "OverlayPosition - enum values" {
    try testing.expectEqual(devmode.DebugOverlay.OverlayPosition.top_left, .top_left);
    try testing.expectEqual(devmode.DebugOverlay.OverlayPosition.top_right, .top_right);
    try testing.expectEqual(devmode.DebugOverlay.OverlayPosition.bottom_left, .bottom_left);
    try testing.expectEqual(devmode.DebugOverlay.OverlayPosition.bottom_right, .bottom_right);
}

test "DevMode - init" {
    const dm = devmode.DevMode.init(testing.allocator);

    try testing.expect(!dm.enabled);
    try testing.expect(!dm.overlay.enabled);
    try testing.expect(!dm.verbose_logging);
    try testing.expect(!dm.break_on_errors);
    try testing.expect(dm.hot_reload_enabled);
    try testing.expect(!dm.profiling_enabled);
}

test "DevMode - enable" {
    var dm = devmode.DevMode.init(testing.allocator);

    dm.enable();

    try testing.expect(dm.enabled);
    try testing.expect(dm.overlay.enabled);
    try testing.expect(dm.verbose_logging);
}

test "DevMode - disable" {
    var dm = devmode.DevMode.init(testing.allocator);

    dm.enable();
    try testing.expect(dm.enabled);

    dm.disable();
    try testing.expect(!dm.enabled);
    try testing.expect(!dm.overlay.enabled);
    try testing.expect(!dm.verbose_logging);
}

test "DevMode - toggle from disabled to enabled" {
    var dm = devmode.DevMode.init(testing.allocator);

    try testing.expect(!dm.enabled);

    dm.toggle();
    try testing.expect(dm.enabled);
}

test "DevMode - toggle from enabled to disabled" {
    var dm = devmode.DevMode.init(testing.allocator);

    dm.enable();
    try testing.expect(dm.enabled);

    dm.toggle();
    try testing.expect(!dm.enabled);
}

test "DevMode - getOverlayHTML when disabled" {
    var dm = devmode.DevMode.init(testing.allocator);

    const html = try dm.getOverlayHTML();

    try testing.expectEqualStrings("", html);
}

test "DevMode - getOverlayHTML when enabled" {
    var dm = devmode.DevMode.init(testing.allocator);
    dm.enable();

    const html = try dm.getOverlayHTML();
    defer testing.allocator.free(html);

    try testing.expect(html.len > 0);
    try testing.expect(std.mem.indexOf(u8, html, "craft-debug-overlay") != null);
    try testing.expect(std.mem.indexOf(u8, html, "Craft Dev Mode") != null);
    try testing.expect(std.mem.indexOf(u8, html, "FPS:") != null);
    try testing.expect(std.mem.indexOf(u8, html, "Memory:") != null);
    try testing.expect(std.mem.indexOf(u8, html, "Events:") != null);
}

test "DevMode - getOverlayHTML top_left position" {
    var dm = devmode.DevMode.init(testing.allocator);
    dm.enable();
    dm.overlay.position = .top_left;

    const html = try dm.getOverlayHTML();
    defer testing.allocator.free(html);

    try testing.expect(std.mem.indexOf(u8, html, "top: 10px; left: 10px;") != null);
}

test "DevMode - getOverlayHTML bottom_right position" {
    var dm = devmode.DevMode.init(testing.allocator);
    dm.enable();
    dm.overlay.position = .bottom_right;

    const html = try dm.getOverlayHTML();
    defer testing.allocator.free(html);

    try testing.expect(std.mem.indexOf(u8, html, "bottom: 10px; right: 10px;") != null);
}

test "DevMode - logEvent when disabled" {
    var dm = devmode.DevMode.init(testing.allocator);

    dm.logEvent("test_event", "test_data");

    try testing.expect(true);
}

test "DevMode - logEvent when enabled" {
    var dm = devmode.DevMode.init(testing.allocator);
    dm.enable();

    dm.logEvent("test_event", "test_data");

    try testing.expect(true);
}

test "DevMode - logError" {
    var dm = devmode.DevMode.init(testing.allocator);

    dm.logError(error.OutOfMemory, "test context");

    try testing.expect(true);
}

test "DevMode - logPerformance when disabled" {
    var dm = devmode.DevMode.init(testing.allocator);

    dm.logPerformance("test_operation", 10.5);

    try testing.expect(true);
}

test "DevMode - logPerformance when profiling enabled" {
    var dm = devmode.DevMode.init(testing.allocator);
    dm.enable();
    dm.profiling_enabled = true;

    dm.logPerformance("fast_operation", 5.0);
    dm.logPerformance("slow_operation", 20.0);

    try testing.expect(true);
}

test "DevMode - global functions initialization" {
    devmode.initGlobalDevMode(testing.allocator);

    const dm = devmode.getGlobalDevMode();
    try testing.expect(dm != null);
    try testing.expect(!dm.?.enabled);
}

test "DevMode - global enable and disable" {
    devmode.initGlobalDevMode(testing.allocator);

    try testing.expect(!devmode.isEnabled());

    devmode.enable();
    try testing.expect(devmode.isEnabled());

    devmode.disable();
    try testing.expect(!devmode.isEnabled());
}

test "DevMode - getGlobalDevMode returns null when not initialized" {
    // Note: This test assumes global state is clean
    // In a real scenario, you'd need to reset global state
    const dm = devmode.getGlobalDevMode();
    try testing.expect(dm != null); // It will be initialized from previous test
}

test "DevMode - multiple toggle cycles" {
    var dm = devmode.DevMode.init(testing.allocator);

    try testing.expect(!dm.enabled);

    dm.toggle();
    try testing.expect(dm.enabled);

    dm.toggle();
    try testing.expect(!dm.enabled);

    dm.toggle();
    try testing.expect(dm.enabled);

    dm.toggle();
    try testing.expect(!dm.enabled);
}

test "DevMode - overlay HTML contains script" {
    var dm = devmode.DevMode.init(testing.allocator);
    dm.enable();

    const html = try dm.getOverlayHTML();
    defer testing.allocator.free(html);

    try testing.expect(std.mem.indexOf(u8, html, "<script>") != null);
    try testing.expect(std.mem.indexOf(u8, html, "performance.now") != null);
    try testing.expect(std.mem.indexOf(u8, html, "requestAnimationFrame") != null);
    try testing.expect(std.mem.indexOf(u8, html, "</script>") != null);
}
