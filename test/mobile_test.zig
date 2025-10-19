const std = @import("std");
const testing = std.testing;
const mobile = @import("../src/mobile.zig");

test "Platform detection" {
    try testing.expect(mobile.Platform.ios == .ios);
    try testing.expect(mobile.Platform.android == .android);
    try testing.expect(mobile.Platform.unknown == .unknown);
}

test "Platform - current() returns a platform" {
    const platform = mobile.Platform.current();
    try testing.expect(platform == .ios or platform == .android or platform == .unknown);
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
    try testing.expectEqual(mobile.iOS.HapticType.selection, .selection);
    try testing.expectEqual(mobile.iOS.HapticType.impact_light, .impact_light);
    try testing.expectEqual(mobile.iOS.HapticType.impact_medium, .impact_medium);
    try testing.expectEqual(mobile.iOS.HapticType.impact_heavy, .impact_heavy);
    try testing.expectEqual(mobile.iOS.HapticType.notification_success, .notification_success);
    try testing.expectEqual(mobile.iOS.HapticType.notification_warning, .notification_warning);
    try testing.expectEqual(mobile.iOS.HapticType.notification_error, .notification_error);
}

test "iOS - StatusBarStyle enum" {
    try testing.expectEqual(mobile.iOS.AppConfig.StatusBarStyle.default, .default);
    try testing.expectEqual(mobile.iOS.AppConfig.StatusBarStyle.light_content, .light_content);
    try testing.expectEqual(mobile.iOS.AppConfig.StatusBarStyle.dark_content, .dark_content);
}

test "iOS - Orientation enum" {
    try testing.expectEqual(mobile.iOS.AppConfig.Orientation.portrait, .portrait);
    try testing.expectEqual(mobile.iOS.AppConfig.Orientation.portrait_upside_down, .portrait_upside_down);
    try testing.expectEqual(mobile.iOS.AppConfig.Orientation.landscape_left, .landscape_left);
    try testing.expectEqual(mobile.iOS.AppConfig.Orientation.landscape_right, .landscape_right);
}

test "iOS - BackgroundMode enum" {
    try testing.expectEqual(mobile.iOS.AppConfig.BackgroundMode.audio, .audio);
    try testing.expectEqual(mobile.iOS.AppConfig.BackgroundMode.location, .location);
    try testing.expectEqual(mobile.iOS.AppConfig.BackgroundMode.voip, .voip);
    try testing.expectEqual(mobile.iOS.AppConfig.BackgroundMode.fetch, .fetch);
    try testing.expectEqual(mobile.iOS.AppConfig.BackgroundMode.remote_notification, .remote_notification);
    try testing.expectEqual(mobile.iOS.AppConfig.BackgroundMode.processing, .processing);
}

test "iOS - AppConfig creation" {
    const config = mobile.iOS.AppConfig{
        .bundle_id = "com.example.app",
        .display_name = "Test App",
        .version = "1.0.0",
        .build_number = "1",
        .supported_orientations = &[_]mobile.iOS.AppConfig.Orientation{.portrait},
        .status_bar_style = .light_content,
    };

    try testing.expectEqualStrings("com.example.app", config.bundle_id);
    try testing.expectEqualStrings("Test App", config.display_name);
    try testing.expectEqualStrings("1.0.0", config.version);
    try testing.expectEqualStrings("1", config.build_number);
    try testing.expectEqual(@as(usize, 1), config.supported_orientations.len);
    try testing.expectEqual(mobile.iOS.AppConfig.Orientation.portrait, config.supported_orientations[0]);
    try testing.expectEqual(mobile.iOS.AppConfig.StatusBarStyle.light_content, config.status_bar_style);
}

test "iOS - AppConfig with multiple orientations" {
    const config = mobile.iOS.AppConfig{
        .bundle_id = "com.example.app",
        .display_name = "Test App",
        .version = "1.0.0",
        .build_number = "1",
        .supported_orientations = &[_]mobile.iOS.AppConfig.Orientation{
            .portrait,
            .landscape_left,
            .landscape_right,
        },
        .status_bar_style = .default,
    };

    try testing.expectEqual(@as(usize, 3), config.supported_orientations.len);
    try testing.expectEqual(mobile.iOS.AppConfig.Orientation.portrait, config.supported_orientations[0]);
    try testing.expectEqual(mobile.iOS.AppConfig.Orientation.landscape_left, config.supported_orientations[1]);
    try testing.expectEqual(mobile.iOS.AppConfig.Orientation.landscape_right, config.supported_orientations[2]);
}

test "iOS - WebViewConfig defaults" {
    const config = mobile.iOS.WebViewConfig{};

    try testing.expect(config.allows_inline_media_playback);
    try testing.expect(config.allows_air_play);
    try testing.expect(config.allows_picture_in_picture);
    try testing.expectEqual(mobile.iOS.WebViewConfig.MediaTypes.none, config.media_types_requiring_user_action);
    try testing.expectEqual(mobile.iOS.WebViewConfig.DataDetectorTypes.all, config.data_detector_types);
    try testing.expect(!config.suppresses_incremental_rendering);
    try testing.expect(config.allows_back_forward_navigation_gestures);
    try testing.expectEqual(mobile.iOS.WebViewConfig.SelectionGranularity.dynamic, config.selection_granularity);
}

test "iOS - WebViewConfig custom settings" {
    const config = mobile.iOS.WebViewConfig{
        .allows_inline_media_playback = false,
        .media_types_requiring_user_action = .all,
        .selection_granularity = .character,
    };

    try testing.expect(!config.allows_inline_media_playback);
    try testing.expectEqual(mobile.iOS.WebViewConfig.MediaTypes.all, config.media_types_requiring_user_action);
    try testing.expectEqual(mobile.iOS.WebViewConfig.SelectionGranularity.character, config.selection_granularity);
}

// Android Tests
test "Android - Orientation enum" {
    try testing.expectEqual(mobile.Android.AppConfig.Orientation.portrait, .portrait);
    try testing.expectEqual(mobile.Android.AppConfig.Orientation.landscape, .landscape);
    try testing.expectEqual(mobile.Android.AppConfig.Orientation.sensor, .sensor);
    try testing.expectEqual(mobile.Android.AppConfig.Orientation.user, .user);
    try testing.expectEqual(mobile.Android.AppConfig.Orientation.behind, .behind);
    try testing.expectEqual(mobile.Android.AppConfig.Orientation.nosensor, .nosensor);
    try testing.expectEqual(mobile.Android.AppConfig.Orientation.unspecified, .unspecified);
}

test "Android - AppConfig with defaults" {
    const config = mobile.Android.AppConfig{
        .package_name = "com.example.app",
        .app_name = "Test App",
        .version_name = "1.0.0",
        .version_code = 1,
        .supported_orientations = &[_]mobile.Android.AppConfig.Orientation{.portrait},
    };

    try testing.expectEqualStrings("com.example.app", config.package_name);
    try testing.expectEqualStrings("Test App", config.app_name);
    try testing.expectEqualStrings("1.0.0", config.version_name);
    try testing.expectEqual(@as(u32, 1), config.version_code);
    try testing.expectEqual(@as(u32, 21), config.min_sdk_version);
    try testing.expectEqual(@as(u32, 34), config.target_sdk_version);
    try testing.expect(config.hardware_acceleration);
    try testing.expect(!config.large_heap);
    try testing.expect(!config.uses_cleartext_traffic);
}

test "Android - AppConfig with custom SDK versions" {
    const config = mobile.Android.AppConfig{
        .package_name = "com.example.app",
        .app_name = "Test App",
        .version_name = "1.0.0",
        .version_code = 1,
        .min_sdk_version = 26,
        .target_sdk_version = 33,
        .supported_orientations = &[_]mobile.Android.AppConfig.Orientation{.portrait},
        .large_heap = true,
    };

    try testing.expectEqual(@as(u32, 26), config.min_sdk_version);
    try testing.expectEqual(@as(u32, 33), config.target_sdk_version);
    try testing.expect(config.large_heap);
}

test "Android - WebViewConfig defaults" {
    const config = mobile.Android.WebViewConfig{};

    try testing.expect(config.javascript_enabled);
    try testing.expect(config.dom_storage_enabled);
    try testing.expect(config.database_enabled);
    try testing.expect(!config.media_playback_requires_user_gesture);
    try testing.expect(!config.allow_file_access);
    try testing.expect(!config.allow_content_access);
    try testing.expectEqual(mobile.Android.WebViewConfig.MixedContentMode.never_allow, config.mixed_content_mode);
    try testing.expectEqual(mobile.Android.WebViewConfig.CacheMode.default, config.cache_mode);
}

test "Android - WebViewConfig custom settings" {
    const config = mobile.Android.WebViewConfig{
        .javascript_enabled = false,
        .allow_file_access = true,
        .mixed_content_mode = .always_allow,
        .cache_mode = .no_cache,
    };

    try testing.expect(!config.javascript_enabled);
    try testing.expect(config.allow_file_access);
    try testing.expectEqual(mobile.Android.WebViewConfig.MixedContentMode.always_allow, config.mixed_content_mode);
    try testing.expectEqual(mobile.Android.WebViewConfig.CacheMode.no_cache, config.cache_mode);
}

test "Android - Permission enum" {
    try testing.expectEqual(mobile.Android.Permission.camera, .camera);
    try testing.expectEqual(mobile.Android.Permission.microphone, .microphone);
    try testing.expectEqual(mobile.Android.Permission.location_fine, .location_fine);
    try testing.expectEqual(mobile.Android.Permission.location_coarse, .location_coarse);
    try testing.expectEqual(mobile.Android.Permission.read_external_storage, .read_external_storage);
    try testing.expectEqual(mobile.Android.Permission.write_external_storage, .write_external_storage);
    try testing.expectEqual(mobile.Android.Permission.read_contacts, .read_contacts);
    try testing.expectEqual(mobile.Android.Permission.write_contacts, .write_contacts);
    try testing.expectEqual(mobile.Android.Permission.record_audio, .record_audio);
}

test "Android - ToastDuration enum" {
    try testing.expectEqual(mobile.Android.ToastDuration.short, .short);
    try testing.expectEqual(mobile.Android.ToastDuration.long, .long);
}

test "MobileWindow - MobileConfig creation" {
    const config = mobile.MobileWindow.MobileConfig{
        .title = "Test App",
        .initial_url = "http://localhost:3000",
        .user_agent = "TestAgent/1.0",
        .enable_inspector = true,
        .orientation_lock = .portrait,
        .safe_area_insets = true,
    };

    try testing.expectEqualStrings("Test App", config.title);
    try testing.expectEqualStrings("http://localhost:3000", config.initial_url);
    try testing.expectEqualStrings("TestAgent/1.0", config.user_agent.?);
    try testing.expect(config.enable_inspector);
    try testing.expectEqual(mobile.MobileWindow.MobileConfig.Orientation.portrait, config.orientation_lock.?);
    try testing.expect(config.safe_area_insets);
}

test "MobileWindow - MobileConfig Orientation enum" {
    try testing.expectEqual(mobile.MobileWindow.MobileConfig.Orientation.portrait, .portrait);
    try testing.expectEqual(mobile.MobileWindow.MobileConfig.Orientation.landscape, .landscape);
    try testing.expectEqual(mobile.MobileWindow.MobileConfig.Orientation.any, .any);
}

test "DeviceInfo - SafeAreaInsets" {
    const insets = mobile.DeviceInfo.SafeAreaInsets{
        .top = 44.0,
        .bottom = 34.0,
        .left = 0.0,
        .right = 0.0,
    };

    try testing.expectEqual(@as(f32, 44.0), insets.top);
    try testing.expectEqual(@as(f32, 34.0), insets.bottom);
    try testing.expectEqual(@as(f32, 0.0), insets.left);
    try testing.expectEqual(@as(f32, 0.0), insets.right);
}

test "DeviceInfo - get() returns valid info" {
    const info = try mobile.DeviceInfo.get(testing.allocator);

    try testing.expect(info.platform == .ios or info.platform == .android or info.platform == .unknown);
    try testing.expect(info.os_version.len > 0);
    try testing.expect(info.device_model.len > 0);
    try testing.expect(info.screen_width > 0);
    try testing.expect(info.screen_height > 0);
    try testing.expect(info.scale_factor > 0.0);
}

test "LifecycleEvent - enum values" {
    try testing.expectEqual(mobile.LifecycleEvent.did_finish_launching, .did_finish_launching);
    try testing.expectEqual(mobile.LifecycleEvent.will_enter_foreground, .will_enter_foreground);
    try testing.expectEqual(mobile.LifecycleEvent.did_become_active, .did_become_active);
    try testing.expectEqual(mobile.LifecycleEvent.will_resign_active, .will_resign_active);
    try testing.expectEqual(mobile.LifecycleEvent.did_enter_background, .did_enter_background);
    try testing.expectEqual(mobile.LifecycleEvent.will_terminate, .will_terminate);
    try testing.expectEqual(mobile.LifecycleEvent.memory_warning, .memory_warning);
}

test "LifecycleManager - init and deinit" {
    var manager = mobile.LifecycleManager.init(testing.allocator);
    defer manager.deinit();

    try testing.expectEqual(@as(usize, 0), manager.callbacks.items.len);
}

test "LifecycleManager - add callback" {
    var manager = mobile.LifecycleManager.init(testing.allocator);
    defer manager.deinit();

    const callback = struct {
        fn cb(event: mobile.LifecycleEvent) void {
            _ = event;
        }
    }.cb;

    try manager.addCallback(callback);
    try testing.expectEqual(@as(usize, 1), manager.callbacks.items.len);
}

test "LifecycleManager - trigger event" {
    var manager = mobile.LifecycleManager.init(testing.allocator);
    defer manager.deinit();

    var triggered = false;
    const callback = struct {
        var flag: *bool = undefined;
        fn cb(event: mobile.LifecycleEvent) void {
            _ = event;
            flag.* = true;
        }
    };
    callback.flag = &triggered;

    try manager.addCallback(callback.cb);
    manager.triggerEvent(.did_finish_launching);

    try testing.expect(triggered);
}

test "Storage - init" {
    const storage = mobile.Storage.init(testing.allocator);
    try testing.expect(storage.platform == .ios or storage.platform == .android or storage.platform == .unknown);
}

test "Storage - directory getters return strings" {
    const storage = mobile.Storage.init(testing.allocator);

    const docs_dir = try storage.getDocumentsDirectory();
    const cache_dir = try storage.getCacheDirectory();
    const temp_dir = try storage.getTemporaryDirectory();

    try testing.expect(docs_dir.len >= 0);
    try testing.expect(cache_dir.len >= 0);
    try testing.expect(temp_dir.len >= 0);
}

test "NetworkStatus - enum values" {
    try testing.expectEqual(mobile.NetworkStatus.unknown, .unknown);
    try testing.expectEqual(mobile.NetworkStatus.not_reachable, .not_reachable);
    try testing.expectEqual(mobile.NetworkStatus.reachable_via_wifi, .reachable_via_wifi);
    try testing.expectEqual(mobile.NetworkStatus.reachable_via_cellular, .reachable_via_cellular);
}

test "NetworkMonitor - init and deinit" {
    var monitor = mobile.NetworkMonitor.init(testing.allocator);
    defer monitor.deinit();

    try testing.expectEqual(mobile.NetworkStatus.unknown, monitor.status);
    try testing.expectEqual(@as(usize, 0), monitor.callbacks.items.len);
}

test "NetworkMonitor - getCurrentStatus" {
    var monitor = mobile.NetworkMonitor.init(testing.allocator);
    defer monitor.deinit();

    const status = monitor.getCurrentStatus();
    try testing.expect(status == .unknown or status == .not_reachable or status == .reachable_via_wifi or status == .reachable_via_cellular);
}

test "NetworkMonitor - onStatusChange callback" {
    var monitor = mobile.NetworkMonitor.init(testing.allocator);
    defer monitor.deinit();

    const callback = struct {
        fn cb(status: mobile.NetworkStatus) void {
            _ = status;
        }
    }.cb;

    try monitor.onStatusChange(callback);
    try testing.expectEqual(@as(usize, 1), monitor.callbacks.items.len);
}
