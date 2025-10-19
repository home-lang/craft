const std = @import("std");
const testing = std.testing;
const mobile = @import("../src/mobile.zig");

test "Platform detection" {
    try testing.expect(mobile.Platform.ios == .ios);
    try testing.expect(mobile.Platform.android == .android);
    try testing.expect(mobile.Platform.unknown == .unknown);
}

test "Orientation enum" {
    try testing.expectEqual(mobile.Orientation.portrait, .portrait);
    try testing.expectEqual(mobile.Orientation.portrait_upside_down, .portrait_upside_down);
    try testing.expectEqual(mobile.Orientation.landscape_left, .landscape_left);
    try testing.expectEqual(mobile.Orientation.landscape_right, .landscape_right);
}

// iOS Tests
test "iOS - Permission enum" {
    try testing.expectEqual(mobile.iOS.Permission.camera, .camera);
    try testing.expectEqual(mobile.iOS.Permission.location, .location);
    try testing.expectEqual(mobile.iOS.Permission.notifications, .notifications);
    try testing.expectEqual(mobile.iOS.Permission.photos, .photos);
    try testing.expectEqual(mobile.iOS.Permission.contacts, .contacts);
    try testing.expectEqual(mobile.iOS.Permission.microphone, .microphone);
}

test "iOS - HapticType enum" {
    try testing.expectEqual(mobile.iOS.HapticType.light, .light);
    try testing.expectEqual(mobile.iOS.HapticType.medium, .medium);
    try testing.expectEqual(mobile.iOS.HapticType.heavy, .heavy);
    try testing.expectEqual(mobile.iOS.HapticType.selection, .selection);
    try testing.expectEqual(mobile.iOS.HapticType.success, .success);
    try testing.expectEqual(mobile.iOS.HapticType.warning, .warning);
    try testing.expectEqual(mobile.iOS.HapticType.@"error", .@"error");
}

test "iOS - StatusBarStyle enum" {
    try testing.expectEqual(mobile.iOS.StatusBarStyle.default, .default);
    try testing.expectEqual(mobile.iOS.StatusBarStyle.light, .light);
    try testing.expectEqual(mobile.iOS.StatusBarStyle.dark, .dark);
}

test "iOS - AppConfig creation" {
    const config = mobile.iOS.AppConfig{
        .bundle_id = "com.example.app",
        .display_name = "Test App",
        .supported_orientations = &[_]mobile.Orientation{.portrait},
        .status_bar_style = .light,
    };

    try testing.expectEqualStrings("com.example.app", config.bundle_id);
    try testing.expectEqualStrings("Test App", config.display_name);
    try testing.expectEqual(@as(usize, 1), config.supported_orientations.len);
    try testing.expectEqual(mobile.Orientation.portrait, config.supported_orientations[0]);
    try testing.expectEqual(mobile.iOS.StatusBarStyle.light, config.status_bar_style);
}

test "iOS - AppConfig with multiple orientations" {
    const config = mobile.iOS.AppConfig{
        .bundle_id = "com.example.app",
        .display_name = "Test App",
        .supported_orientations = &[_]mobile.Orientation{
            .portrait,
            .landscape_left,
            .landscape_right,
        },
        .status_bar_style = .default,
    };

    try testing.expectEqual(@as(usize, 3), config.supported_orientations.len);
    try testing.expectEqual(mobile.Orientation.portrait, config.supported_orientations[0]);
    try testing.expectEqual(mobile.Orientation.landscape_left, config.supported_orientations[1]);
    try testing.expectEqual(mobile.Orientation.landscape_right, config.supported_orientations[2]);
}

test "iOS - WebViewConfig defaults" {
    const config = mobile.iOS.WebViewConfig{
        .url = "http://localhost:3000",
        .enable_javascript = true,
        .enable_devtools = false,
    };

    try testing.expectEqualStrings("http://localhost:3000", config.url);
    try testing.expect(config.enable_javascript);
    try testing.expect(!config.enable_devtools);
}

test "iOS - WebViewConfig with all features enabled" {
    const config = mobile.iOS.WebViewConfig{
        .url = "http://localhost:3000",
        .enable_javascript = true,
        .enable_devtools = true,
    };

    try testing.expect(config.enable_javascript);
    try testing.expect(config.enable_devtools);
}

// Android Tests
test "Android - AppConfig with defaults" {
    const config = mobile.Android.AppConfig{
        .package_name = "com.example.app",
        .min_sdk_version = 21,
        .target_sdk_version = 34,
    };

    try testing.expectEqualStrings("com.example.app", config.package_name);
    try testing.expectEqual(@as(u32, 21), config.min_sdk_version);
    try testing.expectEqual(@as(u32, 34), config.target_sdk_version);
}

test "Android - AppConfig with custom SDK versions" {
    const config = mobile.Android.AppConfig{
        .package_name = "com.example.app",
        .min_sdk_version = 26,
        .target_sdk_version = 33,
    };

    try testing.expectEqual(@as(u32, 26), config.min_sdk_version);
    try testing.expectEqual(@as(u32, 33), config.target_sdk_version);
}

test "Android - WebViewConfig creation" {
    const config = mobile.Android.WebViewConfig{
        .url = "http://localhost:3000",
        .enable_javascript = true,
        .enable_devtools = true,
        .enable_file_access = false,
    };

    try testing.expectEqualStrings("http://localhost:3000", config.url);
    try testing.expect(config.enable_javascript);
    try testing.expect(config.enable_devtools);
    try testing.expect(!config.enable_file_access);
}

test "Android - Permission enum" {
    try testing.expectEqual(mobile.Android.Permission.camera, .camera);
    try testing.expectEqual(mobile.Android.Permission.location, .location);
    try testing.expectEqual(mobile.Android.Permission.storage, .storage);
    try testing.expectEqual(mobile.Android.Permission.microphone, .microphone);
    try testing.expectEqual(mobile.Android.Permission.contacts, .contacts);
}

test "Android - VibrationPattern creation" {
    const pattern = mobile.Android.VibrationPattern{
        .durations_ms = &[_]u64{ 100, 200, 100, 200 },
        .repeat = false,
    };

    try testing.expectEqual(@as(usize, 4), pattern.durations_ms.len);
    try testing.expectEqual(@as(u64, 100), pattern.durations_ms[0]);
    try testing.expectEqual(@as(u64, 200), pattern.durations_ms[1]);
    try testing.expect(!pattern.repeat);
}

test "Android - VibrationPattern with repeat" {
    const pattern = mobile.Android.VibrationPattern{
        .durations_ms = &[_]u64{ 100, 200 },
        .repeat = true,
    };

    try testing.expect(pattern.repeat);
}

test "MobileApp - basic creation" {
    const app = mobile.MobileApp{
        .platform = .ios,
        .bundle_id = "com.example.app",
        .version = "1.0.0",
    };

    try testing.expectEqual(mobile.Platform.ios, app.platform);
    try testing.expectEqualStrings("com.example.app", app.bundle_id);
    try testing.expectEqualStrings("1.0.0", app.version);
}

test "MobileApp - Android configuration" {
    const app = mobile.MobileApp{
        .platform = .android,
        .bundle_id = "com.example.app",
        .version = "2.0.0",
    };

    try testing.expectEqual(mobile.Platform.android, app.platform);
    try testing.expectEqualStrings("2.0.0", app.version);
}

test "DeviceInfo - complete structure" {
    const info = mobile.DeviceInfo{
        .platform = .ios,
        .os_version = "17.0",
        .device_model = "iPhone 15 Pro",
        .screen_width = 1179,
        .screen_height = 2556,
        .scale_factor = 3.0,
    };

    try testing.expectEqual(mobile.Platform.ios, info.platform);
    try testing.expectEqualStrings("17.0", info.os_version);
    try testing.expectEqualStrings("iPhone 15 Pro", info.device_model);
    try testing.expectEqual(@as(u32, 1179), info.screen_width);
    try testing.expectEqual(@as(u32, 2556), info.screen_height);
    try testing.expectEqual(@as(f32, 3.0), info.scale_factor);
}

test "DeviceInfo - Android device" {
    const info = mobile.DeviceInfo{
        .platform = .android,
        .os_version = "14",
        .device_model = "Pixel 8 Pro",
        .screen_width = 1344,
        .screen_height = 2992,
        .scale_factor = 3.5,
    };

    try testing.expectEqual(mobile.Platform.android, info.platform);
    try testing.expectEqualStrings("14", info.os_version);
    try testing.expectEqualStrings("Pixel 8 Pro", info.device_model);
}

test "Lifecycle events" {
    try testing.expectEqual(mobile.LifecycleEvent.app_launched, .app_launched);
    try testing.expectEqual(mobile.LifecycleEvent.app_terminated, .app_terminated);
    try testing.expectEqual(mobile.LifecycleEvent.app_background, .app_background);
    try testing.expectEqual(mobile.LifecycleEvent.app_foreground, .app_foreground);
    try testing.expectEqual(mobile.LifecycleEvent.memory_warning, .memory_warning);
}

test "Bridge - message structure" {
    const msg = mobile.Bridge.Message{
        .method = "test",
        .data = "hello",
    };

    try testing.expectEqualStrings("test", msg.method);
    try testing.expectEqualStrings("hello", msg.data);
}

test "Notification - iOS configuration" {
    const notification = mobile.Notification{
        .title = "Test Notification",
        .body = "This is a test",
        .badge_count = 5,
        .sound = "default",
    };

    try testing.expectEqualStrings("Test Notification", notification.title);
    try testing.expectEqualStrings("This is a test", notification.body);
    try testing.expectEqual(@as(?u32, 5), notification.badge_count);
    try testing.expectEqualStrings("default", notification.sound.?);
}

test "Notification - without badge" {
    const notification = mobile.Notification{
        .title = "Simple",
        .body = "Message",
        .badge_count = null,
        .sound = null,
    };

    try testing.expectEqual(@as(?u32, null), notification.badge_count);
    try testing.expectEqual(@as(?[]const u8, null), notification.sound);
}
