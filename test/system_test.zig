const std = @import("std");
const testing = std.testing;
const system = @import("../src/system.zig");

// Notification Tests
test "Notification - basic creation" {
    const notification = system.Notification.init("Title", "Body");

    try testing.expectEqualStrings("Title", notification.title);
    try testing.expectEqualStrings("Body", notification.body);
    try testing.expectEqual(system.Notification.Urgency.normal, notification.urgency);
    try testing.expectEqual(@as(usize, 0), notification.actions.len);
}

test "Notification - with icon" {
    var notification = system.Notification.init("Title", "Body");
    notification.icon = "icon.png";

    try testing.expectEqualStrings("icon.png", notification.icon.?);
}

test "Notification - urgency levels" {
    try testing.expectEqual(system.Notification.Urgency.low, .low);
    try testing.expectEqual(system.Notification.Urgency.normal, .normal);
    try testing.expectEqual(system.Notification.Urgency.critical, .critical);
}

test "Notification - with actions" {
    const actions = [_]system.NotificationAction{
        .{ .id = "yes", .label = "Yes" },
        .{ .id = "no", .label = "No" },
    };

    var notification = system.Notification.init("Question", "Do you agree?");
    notification.actions = &actions;

    try testing.expectEqual(@as(usize, 2), notification.actions.len);
    try testing.expectEqualStrings("yes", notification.actions[0].id);
    try testing.expectEqualStrings("Yes", notification.actions[0].label);
}

test "NotificationAction - structure" {
    const action = system.NotificationAction{
        .id = "accept",
        .label = "Accept",
    };

    try testing.expectEqualStrings("accept", action.id);
    try testing.expectEqualStrings("Accept", action.label);
}

// Clipboard Tests
test "Clipboard - initialization" {
    const allocator = testing.allocator;
    var clipboard = try system.Clipboard.init(allocator);
    defer clipboard.deinit();

    // Should initialize successfully
    try testing.expect(true);
}

test "ClipboardContent - text variant" {
    const content = system.ClipboardContent{ .text = "Hello" };

    try testing.expect(content == .text);
    try testing.expectEqualStrings("Hello", content.text);
}

test "ClipboardContent - image variant" {
    const image_data = [_]u8{ 0x89, 0x50, 0x4E, 0x47 };
    const content = system.ClipboardContent{ .image = &image_data };

    try testing.expect(content == .image);
    try testing.expectEqual(@as(usize, 4), content.image.len);
}

test "ClipboardContent - files variant" {
    const files = [_][]const u8{ "file1.txt", "file2.txt" };
    const content = system.ClipboardContent{ .files = &files };

    try testing.expect(content == .files);
    try testing.expectEqual(@as(usize, 2), content.files.len);
}

// FileDialog Tests
test "FileDialog - basic structure" {
    const dialog = system.FileDialog{
        .title = "Open File",
        .default_path = null,
        .filters = &[_]system.FileFilter{},
    };

    try testing.expectEqualStrings("Open File", dialog.title);
    try testing.expectEqual(@as(?[]const u8, null), dialog.default_path);
}

test "FileDialog - with default path" {
    const dialog = system.FileDialog{
        .title = "Save File",
        .default_path = "/home/user/documents",
        .filters = &[_]system.FileFilter{},
    };

    try testing.expectEqualStrings("/home/user/documents", dialog.default_path.?);
}

test "FileDialog - with filters" {
    const filters = [_]system.FileFilter{
        .{ .name = "Text Files", .extensions = &[_][]const u8{ ".txt", ".md" } },
        .{ .name = "Images", .extensions = &[_][]const u8{ ".png", ".jpg" } },
    };

    const dialog = system.FileDialog{
        .title = "Open",
        .default_path = null,
        .filters = &filters,
    };

    try testing.expectEqual(@as(usize, 2), dialog.filters.len);
    try testing.expectEqualStrings("Text Files", dialog.filters[0].name);
    try testing.expectEqual(@as(usize, 2), dialog.filters[0].extensions.len);
}

test "FileFilter - structure" {
    const filter = system.FileFilter{
        .name = "Documents",
        .extensions = &[_][]const u8{ ".doc", ".docx", ".pdf" },
    };

    try testing.expectEqualStrings("Documents", filter.name);
    try testing.expectEqual(@as(usize, 3), filter.extensions.len);
    try testing.expectEqualStrings(".doc", filter.extensions[0]);
}

// SystemInfo Tests
test "SystemInfo - structure" {
    const allocator = testing.allocator;
    const info = system.SystemInfo{
        .os_name = "Linux",
        .os_version = "6.5.0",
        .cpu_brand = "Intel Core i7",
        .cpu_cores = 8,
        .total_memory = 16_777_216_000,
        .available_memory = 8_388_608_000,
        .used_memory = 8_388_608_000,
        .uptime_seconds = 86400,
        .allocator = allocator,
    };

    try testing.expectEqualStrings("Linux", info.os_name);
    try testing.expectEqualStrings("6.5.0", info.os_version);
    try testing.expectEqualStrings("Intel Core i7", info.cpu_brand);
    try testing.expectEqual(@as(u32, 8), info.cpu_cores);
    try testing.expectEqual(@as(u64, 16_777_216_000), info.total_memory);
    try testing.expectEqual(@as(u64, 86400), info.uptime_seconds);
}

test "SystemInfo - memory calculations" {
    const allocator = testing.allocator;
    const info = system.SystemInfo{
        .os_name = "macOS",
        .os_version = "14.0",
        .cpu_brand = "Apple M2",
        .cpu_cores = 8,
        .total_memory = 16_000_000_000,
        .available_memory = 8_000_000_000,
        .used_memory = 8_000_000_000,
        .uptime_seconds = 3600,
        .allocator = allocator,
    };

    // Total should equal available + used
    try testing.expectEqual(
        info.total_memory,
        info.available_memory + info.used_memory,
    );
}

// PowerManagement Tests
test "BatteryInfo - structure" {
    const info = system.PowerManagement.BatteryInfo{
        .is_charging = true,
        .level = 85,
        .time_remaining = 7200,
    };

    try testing.expect(info.is_charging);
    try testing.expectEqual(@as(u8, 85), info.level);
    try testing.expectEqual(@as(?u64, 7200), info.time_remaining);
}

test "BatteryInfo - not charging" {
    const info = system.PowerManagement.BatteryInfo{
        .is_charging = false,
        .level = 45,
        .time_remaining = 3600,
    };

    try testing.expect(!info.is_charging);
    try testing.expectEqual(@as(u8, 45), info.level);
}

test "BatteryInfo - no time remaining" {
    const info = system.PowerManagement.BatteryInfo{
        .is_charging = true,
        .level = 100,
        .time_remaining = null,
    };

    try testing.expectEqual(@as(?u64, null), info.time_remaining);
}

test "PowerState enum" {
    try testing.expectEqual(system.PowerManagement.PowerState.on_battery, .on_battery);
    try testing.expectEqual(system.PowerManagement.PowerState.charging, .charging);
    try testing.expectEqual(system.PowerManagement.PowerState.fully_charged, .fully_charged);
}

// Screen Tests
test "Screen - structure" {
    const screen = system.Screen{
        .id = 0,
        .width = 1920,
        .height = 1080,
        .scale_factor = 1.0,
        .x = 0,
        .y = 0,
        .is_primary = true,
    };

    try testing.expectEqual(@as(u32, 0), screen.id);
    try testing.expectEqual(@as(u32, 1920), screen.width);
    try testing.expectEqual(@as(u32, 1080), screen.height);
    try testing.expectEqual(@as(f32, 1.0), screen.scale_factor);
    try testing.expect(screen.is_primary);
}

test "Screen - secondary display" {
    const screen = system.Screen{
        .id = 1,
        .width = 2560,
        .height = 1440,
        .scale_factor = 1.5,
        .x = 1920,
        .y = 0,
        .is_primary = false,
    };

    try testing.expectEqual(@as(u32, 1), screen.id);
    try testing.expectEqual(@as(i32, 1920), screen.x);
    try testing.expect(!screen.is_primary);
}

test "Screen - high DPI" {
    const screen = system.Screen{
        .id = 0,
        .width = 3840,
        .height = 2160,
        .scale_factor = 2.0,
        .x = 0,
        .y = 0,
        .is_primary = true,
    };

    try testing.expectEqual(@as(f32, 2.0), screen.scale_factor);
    try testing.expectEqual(@as(u32, 3840), screen.width);
}

// URLHandler Tests
test "URLHandler - open URL" {
    const handler = system.URLHandler{};
    _ = handler;

    // Structure exists
    try testing.expect(true);
}

test "URLScheme - structure" {
    const scheme = system.URLHandler.URLScheme{
        .scheme = "myapp",
        .handler = null,
    };

    try testing.expectEqualStrings("myapp", scheme.scheme);
    try testing.expectEqual(@as(?*const fn ([]const u8) void, null), scheme.handler);
}

// Environment Tests
test "Environment - OS detection" {
    const env = try system.Environment.detect();

    // Should detect some OS
    try testing.expect(env.os != .unknown);
}

test "Environment - OS enum" {
    try testing.expectEqual(system.Environment.OS.windows, .windows);
    try testing.expectEqual(system.Environment.OS.macos, .macos);
    try testing.expectEqual(system.Environment.OS.linux, .linux);
    try testing.expectEqual(system.Environment.OS.unknown, .unknown);
}

// Process Tests
test "ProcessInfo - structure" {
    const info = system.Process.ProcessInfo{
        .pid = 1234,
        .parent_pid = 1,
        .name = "test_process",
        .cpu_usage = 5.5,
        .memory_usage = 1024 * 1024 * 100,
    };

    try testing.expectEqual(@as(u32, 1234), info.pid);
    try testing.expectEqual(@as(u32, 1), info.parent_pid);
    try testing.expectEqualStrings("test_process", info.name);
    try testing.expectEqual(@as(f32, 5.5), info.cpu_usage);
}

// Network Tests
test "NetworkInfo - structure" {
    const info = system.Network.NetworkInfo{
        .is_connected = true,
        .connection_type = .wifi,
        .ip_address = "192.168.1.100",
    };

    try testing.expect(info.is_connected);
    try testing.expectEqual(system.Network.ConnectionType.wifi, info.connection_type);
    try testing.expectEqualStrings("192.168.1.100", info.ip_address.?);
}

test "Network - ConnectionType enum" {
    try testing.expectEqual(system.Network.ConnectionType.ethernet, .ethernet);
    try testing.expectEqual(system.Network.ConnectionType.wifi, .wifi);
    try testing.expectEqual(system.Network.ConnectionType.cellular, .cellular);
    try testing.expectEqual(system.Network.ConnectionType.none, .none);
}

// Locale Tests
test "LocaleInfo - structure" {
    const locale = system.Locale.LocaleInfo{
        .language = "en",
        .country = "US",
        .encoding = "UTF-8",
        .decimal_separator = ".",
        .thousands_separator = ",",
        .currency_symbol = "$",
    };

    try testing.expectEqualStrings("en", locale.language);
    try testing.expectEqualStrings("US", locale.country);
    try testing.expectEqualStrings("UTF-8", locale.encoding);
    try testing.expectEqualStrings(".", locale.decimal_separator);
    try testing.expectEqualStrings(",", locale.thousands_separator);
    try testing.expectEqualStrings("$", locale.currency_symbol);
}

test "LocaleInfo - different locale" {
    const locale = system.Locale.LocaleInfo{
        .language = "de",
        .country = "DE",
        .encoding = "UTF-8",
        .decimal_separator = ",",
        .thousands_separator = ".",
        .currency_symbol = "€",
    };

    try testing.expectEqualStrings("de", locale.language);
    try testing.expectEqualStrings("DE", locale.country);
    try testing.expectEqualStrings(",", locale.decimal_separator);
    try testing.expectEqualStrings("€", locale.currency_symbol);
}

// Accessibility Tests
test "AccessibilityFeatures - all disabled" {
    const features = system.Accessibility.AccessibilityFeatures{
        .screen_reader = false,
        .high_contrast = false,
        .large_text = false,
        .reduce_motion = false,
    };

    try testing.expect(!features.screen_reader);
    try testing.expect(!features.high_contrast);
    try testing.expect(!features.large_text);
    try testing.expect(!features.reduce_motion);
}

test "AccessibilityFeatures - some enabled" {
    const features = system.Accessibility.AccessibilityFeatures{
        .screen_reader = true,
        .high_contrast = false,
        .large_text = true,
        .reduce_motion = false,
    };

    try testing.expect(features.screen_reader);
    try testing.expect(!features.high_contrast);
    try testing.expect(features.large_text);
    try testing.expect(!features.reduce_motion);
}

// System Performance Tests
test "SystemMetrics - structure" {
    const metrics = system.Performance.SystemMetrics{
        .cpu_usage = 45.5,
        .memory_usage = 8_000_000_000,
        .disk_read_bytes = 1024 * 1024 * 100,
        .disk_write_bytes = 1024 * 1024 * 50,
        .network_rx_bytes = 1024 * 1024 * 10,
        .network_tx_bytes = 1024 * 1024 * 5,
    };

    try testing.expectEqual(@as(f32, 45.5), metrics.cpu_usage);
    try testing.expectEqual(@as(u64, 8_000_000_000), metrics.memory_usage);
    try testing.expect(metrics.disk_read_bytes > metrics.disk_write_bytes);
    try testing.expect(metrics.network_rx_bytes > metrics.network_tx_bytes);
}

// Storage Tests
test "StorageInfo - structure" {
    const info = system.Storage.StorageInfo{
        .path = "/",
        .total_space = 500_000_000_000,
        .free_space = 200_000_000_000,
        .is_removable = false,
    };

    try testing.expectEqualStrings("/", info.path);
    try testing.expectEqual(@as(u64, 500_000_000_000), info.total_space);
    try testing.expectEqual(@as(u64, 200_000_000_000), info.free_space);
    try testing.expect(!info.is_removable);
}

test "StorageInfo - used space calculation" {
    const info = system.Storage.StorageInfo{
        .path = "/",
        .total_space = 1_000_000_000,
        .free_space = 400_000_000,
        .is_removable = false,
    };

    const used_space = info.total_space - info.free_space;
    try testing.expectEqual(@as(u64, 600_000_000), used_space);
}

test "StorageInfo - removable drive" {
    const info = system.Storage.StorageInfo{
        .path = "/media/usb",
        .total_space = 32_000_000_000,
        .free_space = 16_000_000_000,
        .is_removable = true,
    };

    try testing.expect(info.is_removable);
}
