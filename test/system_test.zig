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

fn dummyCallback() void {}

test "Notification - with actions" {
    const actions = [_]system.Notification.NotificationAction{
        .{ .id = "yes", .label = "Yes", .callback = dummyCallback },
        .{ .id = "no", .label = "No", .callback = dummyCallback },
    };

    var notification = system.Notification.init("Question", "Do you agree?");
    notification.actions = &actions;

    try testing.expectEqual(@as(usize, 2), notification.actions.len);
    try testing.expectEqualStrings("yes", notification.actions[0].id);
    try testing.expectEqualStrings("Yes", notification.actions[0].label);
}

test "NotificationAction - structure" {
    const action = system.Notification.NotificationAction{
        .id = "accept",
        .label = "Accept",
        .callback = dummyCallback,
    };

    try testing.expectEqualStrings("accept", action.id);
    try testing.expectEqualStrings("Accept", action.label);
}

// NotificationManager Tests
test "NotificationManager - init and deinit" {
    const allocator = testing.allocator;
    var manager = system.NotificationManager.init(allocator);
    defer manager.deinit();

    try testing.expectEqual(@as(usize, 0), manager.notifications.items.len);
}

// Clipboard Tests
test "Clipboard - init" {
    const allocator = testing.allocator;
    const clipboard = system.Clipboard.init(allocator);

    try testing.expect(clipboard.allocator.ptr == allocator.ptr);
}

test "Clipboard - getText returns optional" {
    const allocator = testing.allocator;
    const clipboard = system.Clipboard.init(allocator);
    const text = try clipboard.getText();

    try testing.expect(text == null or text.?.len >= 0);
}

test "Clipboard - setText does not crash" {
    const allocator = testing.allocator;
    const clipboard = system.Clipboard.init(allocator);
    try clipboard.setText("Hello World");

    try testing.expect(true);
}

// FileDialog Tests
test "FileDialog - openFile options" {
    const filters = [_]system.FileDialog.FileFilter{};
    const options = system.FileDialog{
        .title = "Open File",
        .default_path = "/home/user",
        .filters = &filters,
        .multi_select = false,
    };

    try testing.expectEqualStrings("Open File", options.title);
    try testing.expectEqualStrings("/home/user", options.default_path.?);
    try testing.expect(!options.multi_select);
}

test "FileDialog - saveFile options" {
    const filters = [_]system.FileDialog.FileFilter{};
    const options = system.FileDialog{
        .title = "Save File",
        .filters = &filters,
    };

    try testing.expectEqualStrings("Save File", options.title);
    try testing.expectEqual(@as(?[]const u8, null), options.default_path);
}

test "FileDialog - with filters" {
    const filters = [_]system.FileDialog.FileFilter{
        .{ .name = "Images", .extensions = &[_][]const u8{ "png", "jpg", "gif" } },
        .{ .name = "Documents", .extensions = &[_][]const u8{ "pdf", "doc", "txt" } },
    };

    const options = system.FileDialog{
        .title = "Open",
        .filters = &filters,
    };

    try testing.expectEqual(@as(usize, 2), options.filters.len);
    try testing.expectEqualStrings("Images", options.filters[0].name);
    try testing.expectEqual(@as(usize, 3), options.filters[0].extensions.len);
}

test "FileFilter - structure" {
    const filter = system.FileDialog.FileFilter{
        .name = "Text Files",
        .extensions = &[_][]const u8{ "txt", "md" },
    };

    try testing.expectEqualStrings("Text Files", filter.name);
    try testing.expectEqual(@as(usize, 2), filter.extensions.len);
    try testing.expectEqualStrings("txt", filter.extensions[0]);
    try testing.expectEqualStrings("md", filter.extensions[1]);
}

// SystemInfo Tests
test "SystemInfo - getOSName" {
    const os_name = system.SystemInfo.getOSName();
    try testing.expect(os_name.len > 0);
    try testing.expect(
        std.mem.eql(u8, os_name, "macOS") or
            std.mem.eql(u8, os_name, "Linux") or
            std.mem.eql(u8, os_name, "Windows") or
            std.mem.eql(u8, os_name, "iOS") or
            std.mem.eql(u8, os_name, "Android") or
            std.mem.eql(u8, os_name, "Unknown"),
    );
}

test "SystemInfo - getOSVersion" {
    const allocator = testing.allocator;
    const version = try system.SystemInfo.getOSVersion(allocator);

    try testing.expect(version.len > 0);
}

test "SystemInfo - getHomeDirectory" {
    const allocator = testing.allocator;
    const home = try system.SystemInfo.getHomeDirectory(allocator);

    try testing.expect(home.len > 0);
}

test "SystemInfo - getCPUCount" {
    const cpu_count = system.SystemInfo.getCPUCount();
    try testing.expect(cpu_count > 0);
}

test "SystemInfo - getTotalMemory" {
    const total_memory = system.SystemInfo.getTotalMemory();
    try testing.expect(total_memory > 0);
}

test "SystemInfo - getFreeMemory" {
    const free_memory = system.SystemInfo.getFreeMemory();
    try testing.expect(free_memory >= 0);
}

// PowerManagement Tests
test "PowerManagement.BatteryState - enum values" {
    try testing.expectEqual(system.PowerManagement.BatteryState.unknown, .unknown);
    try testing.expectEqual(system.PowerManagement.BatteryState.unplugged, .unplugged);
    try testing.expectEqual(system.PowerManagement.BatteryState.charging, .charging);
    try testing.expectEqual(system.PowerManagement.BatteryState.full, .full);
}

test "PowerManagement.BatteryInfo - structure" {
    const info = system.PowerManagement.BatteryInfo{
        .state = .charging,
        .level = 0.75,
        .time_remaining = 3600,
    };

    try testing.expectEqual(system.PowerManagement.BatteryState.charging, info.state);
    try testing.expectEqual(@as(f32, 0.75), info.level);
    try testing.expectEqual(@as(?u64, 3600), info.time_remaining);
}

test "PowerManagement.BatteryInfo - unplugged" {
    const info = system.PowerManagement.BatteryInfo{
        .state = .unplugged,
        .level = 0.5,
        .time_remaining = 1800,
    };

    try testing.expectEqual(system.PowerManagement.BatteryState.unplugged, info.state);
    try testing.expectEqual(@as(f32, 0.5), info.level);
}

test "PowerManagement.BatteryInfo - full" {
    const info = system.PowerManagement.BatteryInfo{
        .state = .full,
        .level = 1.0,
        .time_remaining = null,
    };

    try testing.expectEqual(system.PowerManagement.BatteryState.full, info.state);
    try testing.expectEqual(@as(f32, 1.0), info.level);
    try testing.expectEqual(@as(?u64, null), info.time_remaining);
}

test "PowerManagement - getBatteryInfo" {
    const info = try system.PowerManagement.getBatteryInfo();

    try testing.expect(info.level >= 0.0 and info.level <= 1.0);
}

// Screen Tests
test "Screen - structure" {
    const screen = system.Screen{
        .width = 1920,
        .height = 1080,
        .scale_factor = 2.0,
        .x = 0,
        .y = 0,
        .is_primary = true,
    };

    try testing.expectEqual(@as(u32, 1920), screen.width);
    try testing.expectEqual(@as(u32, 1080), screen.height);
    try testing.expectEqual(@as(f32, 2.0), screen.scale_factor);
    try testing.expectEqual(@as(i32, 0), screen.x);
    try testing.expectEqual(@as(i32, 0), screen.y);
    try testing.expect(screen.is_primary);
}

test "Screen - secondary display" {
    const screen = system.Screen{
        .width = 2560,
        .height = 1440,
        .scale_factor = 1.0,
        .x = 1920,
        .y = 0,
        .is_primary = false,
    };

    try testing.expectEqual(@as(u32, 2560), screen.width);
    try testing.expectEqual(@as(u32, 1440), screen.height);
    try testing.expect(!screen.is_primary);
    try testing.expectEqual(@as(i32, 1920), screen.x);
}

test "Screen - getPrimaryScreen" {
    const screen = try system.Screen.getPrimaryScreen();

    try testing.expect(screen.width > 0);
    try testing.expect(screen.height > 0);
    try testing.expect(screen.scale_factor > 0.0);
    try testing.expect(screen.is_primary);
}

test "Notification.Urgency - all values" {
    try testing.expectEqual(system.Notification.Urgency.low, .low);
    try testing.expectEqual(system.Notification.Urgency.normal, .normal);
    try testing.expectEqual(system.Notification.Urgency.critical, .critical);
}

test "Notification.NotificationSound - all values" {
    try testing.expectEqual(system.Notification.NotificationSound.default, .default);
    try testing.expectEqual(system.Notification.NotificationSound.custom, .custom);
    try testing.expectEqual(system.Notification.NotificationSound.none, .none);
}

test "FileDialog - show_hidden option" {
    const options = system.FileDialog{
        .title = "Open",
        .show_hidden = true,
    };

    try testing.expect(options.show_hidden);
}

test "FileDialog - create_directories option" {
    const options = system.FileDialog{
        .title = "Save",
        .create_directories = true,
    };

    try testing.expect(options.create_directories);
}
