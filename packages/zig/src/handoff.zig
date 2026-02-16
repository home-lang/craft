//! Handoff and continuity support for Craft
//! Provides cross-platform abstractions for Apple Handoff, Universal Clipboard,
//! and cross-device activity continuation.

const std = @import("std");

/// Handoff provider types
pub const HandoffProvider = enum {
    apple_handoff,
    universal_clipboard,
    nearby_share,
    your_phone,
    kde_connect,
    custom,

    pub fn toString(self: HandoffProvider) []const u8 {
        return switch (self) {
            .apple_handoff => "Apple Handoff",
            .universal_clipboard => "Universal Clipboard",
            .nearby_share => "Nearby Share",
            .your_phone => "Your Phone",
            .kde_connect => "KDE Connect",
            .custom => "Custom",
        };
    }

    pub fn supportsActivityContinuation(self: HandoffProvider) bool {
        return switch (self) {
            .apple_handoff => true,
            else => false,
        };
    }

    pub fn supportsClipboard(self: HandoffProvider) bool {
        return switch (self) {
            .apple_handoff, .universal_clipboard, .kde_connect => true,
            .nearby_share, .your_phone, .custom => false,
        };
    }

    pub fn supportsFileTransfer(self: HandoffProvider) bool {
        return switch (self) {
            .nearby_share, .your_phone, .kde_connect => true,
            .apple_handoff, .universal_clipboard, .custom => false,
        };
    }
};

/// Handoff availability state
pub const AvailabilityState = enum {
    unavailable,
    checking,
    available,
    restricted,

    pub fn isAvailable(self: AvailabilityState) bool {
        return self == .available;
    }

    pub fn toString(self: AvailabilityState) []const u8 {
        return switch (self) {
            .unavailable => "Unavailable",
            .checking => "Checking",
            .available => "Available",
            .restricted => "Restricted",
        };
    }
};

/// Activity type identifier
pub const ActivityType = struct {
    type_id: []const u8,
    title: []const u8,
    is_eligible_for_handoff: bool,
    is_eligible_for_search: bool,
    is_eligible_for_prediction: bool,

    pub fn init(type_id: []const u8, title: []const u8) ActivityType {
        return .{
            .type_id = type_id,
            .title = title,
            .is_eligible_for_handoff = true,
            .is_eligible_for_search = false,
            .is_eligible_for_prediction = false,
        };
    }

    pub fn withSearchEligibility(self: ActivityType, eligible: bool) ActivityType {
        var activity = self;
        activity.is_eligible_for_search = eligible;
        return activity;
    }

    pub fn withPredictionEligibility(self: ActivityType, eligible: bool) ActivityType {
        var activity = self;
        activity.is_eligible_for_prediction = eligible;
        return activity;
    }

    pub fn withHandoffEligibility(self: ActivityType, eligible: bool) ActivityType {
        var activity = self;
        activity.is_eligible_for_handoff = eligible;
        return activity;
    }
};

/// User activity state
pub const ActivityState = enum {
    inactive,
    active,
    continuing,
    completed,
    cancelled,

    pub fn isActive(self: ActivityState) bool {
        return self == .active or self == .continuing;
    }

    pub fn isFinished(self: ActivityState) bool {
        return self == .completed or self == .cancelled;
    }

    pub fn toString(self: ActivityState) []const u8 {
        return switch (self) {
            .inactive => "Inactive",
            .active => "Active",
            .continuing => "Continuing",
            .completed => "Completed",
            .cancelled => "Cancelled",
        };
    }
};

/// User info key-value entry
pub const UserInfoEntry = struct {
    key: []const u8,
    value: []const u8,

    pub fn init(key: []const u8, value: []const u8) UserInfoEntry {
        return .{ .key = key, .value = value };
    }
};

/// User activity for handoff
pub const UserActivity = struct {
    activity_type: ActivityType,
    state: ActivityState,
    title: []const u8,
    webpage_url: ?[]const u8,
    referrer_url: ?[]const u8,
    user_info_count: u32,
    needs_save: bool,
    supports_continuation_streams: bool,
    created_at: u64,

    pub fn init(activity_type: ActivityType) UserActivity {
        return .{
            .activity_type = activity_type,
            .state = .inactive,
            .title = activity_type.title,
            .webpage_url = null,
            .referrer_url = null,
            .user_info_count = 0,
            .needs_save = false,
            .supports_continuation_streams = false,
            .created_at = getCurrentTimestamp(),
        };
    }

    pub fn withTitle(self: UserActivity, title: []const u8) UserActivity {
        var activity = self;
        activity.title = title;
        return activity;
    }

    pub fn withWebpageUrl(self: UserActivity, url: []const u8) UserActivity {
        var activity = self;
        activity.webpage_url = url;
        return activity;
    }

    pub fn withReferrerUrl(self: UserActivity, url: []const u8) UserActivity {
        var activity = self;
        activity.referrer_url = url;
        return activity;
    }

    pub fn withContinuationStreams(self: UserActivity, enabled: bool) UserActivity {
        var activity = self;
        activity.supports_continuation_streams = enabled;
        return activity;
    }

    pub fn becomeActive(self: *UserActivity) void {
        self.state = .active;
    }

    pub fn resignActive(self: *UserActivity) void {
        self.state = .inactive;
    }

    pub fn markNeedsSave(self: *UserActivity) void {
        self.needs_save = true;
    }

    pub fn invalidate(self: *UserActivity) void {
        self.state = .cancelled;
    }

    pub fn complete(self: *UserActivity) void {
        self.state = .completed;
    }

    pub fn isActive(self: UserActivity) bool {
        return self.state.isActive();
    }

    pub fn hasWebpage(self: UserActivity) bool {
        return self.webpage_url != null;
    }
};

/// Device type for handoff
pub const DeviceType = enum {
    iphone,
    ipad,
    mac,
    apple_watch,
    apple_tv,
    android,
    windows,
    linux,
    unknown,

    pub fn toString(self: DeviceType) []const u8 {
        return switch (self) {
            .iphone => "iPhone",
            .ipad => "iPad",
            .mac => "Mac",
            .apple_watch => "Apple Watch",
            .apple_tv => "Apple TV",
            .android => "Android",
            .windows => "Windows",
            .linux => "Linux",
            .unknown => "Unknown",
        };
    }

    pub fn isAppleDevice(self: DeviceType) bool {
        return switch (self) {
            .iphone, .ipad, .mac, .apple_watch, .apple_tv => true,
            else => false,
        };
    }

    pub fn isMobile(self: DeviceType) bool {
        return self == .iphone or self == .android or self == .apple_watch;
    }

    pub fn isDesktop(self: DeviceType) bool {
        return self == .mac or self == .windows or self == .linux;
    }
};

/// Nearby device information
pub const NearbyDevice = struct {
    device_id: []const u8,
    name: []const u8,
    device_type: DeviceType,
    is_same_user: bool,
    signal_strength: i8,
    last_seen: u64,

    pub fn init(device_id: []const u8, name: []const u8, device_type: DeviceType) NearbyDevice {
        return .{
            .device_id = device_id,
            .name = name,
            .device_type = device_type,
            .is_same_user = false,
            .signal_strength = 0,
            .last_seen = getCurrentTimestamp(),
        };
    }

    pub fn withSameUser(self: NearbyDevice, same_user: bool) NearbyDevice {
        var device = self;
        device.is_same_user = same_user;
        return device;
    }

    pub fn withSignalStrength(self: NearbyDevice, rssi: i8) NearbyDevice {
        var device = self;
        device.signal_strength = rssi;
        return device;
    }

    pub fn signalQuality(self: NearbyDevice) SignalQuality {
        if (self.signal_strength >= -50) return .excellent;
        if (self.signal_strength >= -60) return .good;
        if (self.signal_strength >= -70) return .fair;
        return .poor;
    }

    pub fn supportsHandoff(self: NearbyDevice) bool {
        return self.device_type.isAppleDevice();
    }
};

/// Signal quality level
pub const SignalQuality = enum {
    excellent,
    good,
    fair,
    poor,

    pub fn toString(self: SignalQuality) []const u8 {
        return switch (self) {
            .excellent => "Excellent",
            .good => "Good",
            .fair => "Fair",
            .poor => "Poor",
        };
    }

    pub fn bars(self: SignalQuality) u8 {
        return switch (self) {
            .excellent => 4,
            .good => 3,
            .fair => 2,
            .poor => 1,
        };
    }
};

/// Clipboard content type
pub const ClipboardContentType = enum {
    text,
    url,
    image,
    file,
    html,
    rtf,

    pub fn toString(self: ClipboardContentType) []const u8 {
        return switch (self) {
            .text => "Plain Text",
            .url => "URL",
            .image => "Image",
            .file => "File",
            .html => "HTML",
            .rtf => "Rich Text",
        };
    }

    pub fn mimeType(self: ClipboardContentType) []const u8 {
        return switch (self) {
            .text => "text/plain",
            .url => "text/uri-list",
            .image => "image/*",
            .file => "application/octet-stream",
            .html => "text/html",
            .rtf => "text/rtf",
        };
    }
};

/// Clipboard item
pub const ClipboardItem = struct {
    content_type: ClipboardContentType,
    data_size: u64,
    source_device: ?[]const u8,
    timestamp: u64,
    expires_at: ?u64,

    pub fn init(content_type: ClipboardContentType, data_size: u64) ClipboardItem {
        return .{
            .content_type = content_type,
            .data_size = data_size,
            .source_device = null,
            .timestamp = getCurrentTimestamp(),
            .expires_at = null,
        };
    }

    pub fn withSourceDevice(self: ClipboardItem, device: []const u8) ClipboardItem {
        var item = self;
        item.source_device = device;
        return item;
    }

    pub fn withExpiration(self: ClipboardItem, expires_at: u64) ClipboardItem {
        var item = self;
        item.expires_at = expires_at;
        return item;
    }

    pub fn isFromRemote(self: ClipboardItem) bool {
        return self.source_device != null;
    }

    pub fn isExpired(self: ClipboardItem) bool {
        if (self.expires_at) |exp| {
            return getCurrentTimestamp() >= exp;
        }
        return false;
    }
};

/// Universal clipboard manager
pub const UniversalClipboard = struct {
    is_enabled: bool,
    has_content: bool,
    last_sync: u64,
    pending_items: u32,

    pub fn init() UniversalClipboard {
        return .{
            .is_enabled = false,
            .has_content = false,
            .last_sync = 0,
            .pending_items = 0,
        };
    }

    pub fn enable(self: *UniversalClipboard) void {
        self.is_enabled = true;
    }

    pub fn disable(self: *UniversalClipboard) void {
        self.is_enabled = false;
    }

    pub fn sync(self: *UniversalClipboard) void {
        self.last_sync = getCurrentTimestamp();
        self.pending_items = 0;
    }

    pub fn addPendingItem(self: *UniversalClipboard) void {
        self.pending_items += 1;
        self.has_content = true;
    }

    pub fn hasPendingItems(self: UniversalClipboard) bool {
        return self.pending_items > 0;
    }

    pub fn timeSinceLastSync(self: UniversalClipboard) u64 {
        if (self.last_sync == 0) return 0;
        const now = getCurrentTimestamp();
        if (now < self.last_sync) return 0;
        return now - self.last_sync;
    }
};

/// Transfer state
pub const TransferState = enum {
    idle,
    preparing,
    transferring,
    completed,
    failed,
    cancelled,

    pub fn isInProgress(self: TransferState) bool {
        return self == .preparing or self == .transferring;
    }

    pub fn isFinished(self: TransferState) bool {
        return self == .completed or self == .failed or self == .cancelled;
    }

    pub fn toString(self: TransferState) []const u8 {
        return switch (self) {
            .idle => "Idle",
            .preparing => "Preparing",
            .transferring => "Transferring",
            .completed => "Completed",
            .failed => "Failed",
            .cancelled => "Cancelled",
        };
    }
};

/// Continuation stream for data transfer
pub const ContinuationStream = struct {
    stream_id: []const u8,
    state: TransferState,
    bytes_transferred: u64,
    total_bytes: u64,
    started_at: u64,

    pub fn init(stream_id: []const u8) ContinuationStream {
        return .{
            .stream_id = stream_id,
            .state = .idle,
            .bytes_transferred = 0,
            .total_bytes = 0,
            .started_at = 0,
        };
    }

    pub fn start(self: *ContinuationStream, total: u64) void {
        self.state = .transferring;
        self.total_bytes = total;
        self.started_at = getCurrentTimestamp();
    }

    pub fn updateProgress(self: *ContinuationStream, bytes: u64) void {
        self.bytes_transferred = bytes;
        if (self.bytes_transferred >= self.total_bytes and self.total_bytes > 0) {
            self.state = .completed;
        }
    }

    pub fn cancel(self: *ContinuationStream) void {
        self.state = .cancelled;
    }

    pub fn fail(self: *ContinuationStream) void {
        self.state = .failed;
    }

    pub fn progressPercent(self: ContinuationStream) f32 {
        if (self.total_bytes == 0) return 0;
        return @as(f32, @floatFromInt(self.bytes_transferred)) / @as(f32, @floatFromInt(self.total_bytes)) * 100.0;
    }

    pub fn isComplete(self: ContinuationStream) bool {
        return self.state == .completed;
    }
};

/// Handoff controller
pub const HandoffController = struct {
    provider: HandoffProvider,
    availability: AvailabilityState,
    current_activity: ?UserActivity,
    nearby_device_count: u32,
    clipboard: UniversalClipboard,

    pub fn init(provider: HandoffProvider) HandoffController {
        return .{
            .provider = provider,
            .availability = .unavailable,
            .current_activity = null,
            .nearby_device_count = 0,
            .clipboard = UniversalClipboard.init(),
        };
    }

    pub fn checkAvailability(self: *HandoffController) void {
        self.availability = .checking;
    }

    pub fn setAvailable(self: *HandoffController) void {
        self.availability = .available;
    }

    pub fn setUnavailable(self: *HandoffController) void {
        self.availability = .unavailable;
    }

    pub fn startActivity(self: *HandoffController, activity: UserActivity) void {
        var act = activity;
        act.becomeActive();
        self.current_activity = act;
    }

    pub fn stopActivity(self: *HandoffController) void {
        if (self.current_activity) |*activity| {
            activity.resignActive();
        }
        self.current_activity = null;
    }

    pub fn updateNearbyDevices(self: *HandoffController, count: u32) void {
        self.nearby_device_count = count;
    }

    pub fn hasActiveActivity(self: HandoffController) bool {
        if (self.current_activity) |activity| {
            return activity.isActive();
        }
        return false;
    }

    pub fn isAvailable(self: HandoffController) bool {
        return self.availability.isAvailable();
    }

    pub fn hasNearbyDevices(self: HandoffController) bool {
        return self.nearby_device_count > 0;
    }
};

/// Get current timestamp in milliseconds
fn getCurrentTimestamp() u64 {
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
        const ms = @divTrunc(ts.nsec, 1_000_000);
        return @intCast(@as(i128, ts.sec) * 1000 + ms);
    }
    return 0;
}

/// Check if handoff is supported on current platform
pub fn isHandoffSupported() bool {
    return false; // Would use runtime detection
}

/// Get current device type
pub fn currentDeviceType() DeviceType {
    return .unknown; // Would use runtime detection
}

// ============================================================================
// Tests
// ============================================================================

test "HandoffProvider properties" {
    try std.testing.expect(HandoffProvider.apple_handoff.supportsActivityContinuation());
    try std.testing.expect(!HandoffProvider.nearby_share.supportsActivityContinuation());
    try std.testing.expect(HandoffProvider.apple_handoff.supportsClipboard());
    try std.testing.expect(HandoffProvider.nearby_share.supportsFileTransfer());
}

test "HandoffProvider toString" {
    try std.testing.expectEqualStrings("Apple Handoff", HandoffProvider.apple_handoff.toString());
    try std.testing.expectEqualStrings("Nearby Share", HandoffProvider.nearby_share.toString());
}

test "AvailabilityState properties" {
    try std.testing.expect(AvailabilityState.available.isAvailable());
    try std.testing.expect(!AvailabilityState.unavailable.isAvailable());
    try std.testing.expect(!AvailabilityState.checking.isAvailable());
}

test "ActivityType creation" {
    const activity = ActivityType.init("com.app.edit", "Editing Document")
        .withSearchEligibility(true)
        .withPredictionEligibility(true);

    try std.testing.expectEqualStrings("com.app.edit", activity.type_id);
    try std.testing.expect(activity.is_eligible_for_handoff);
    try std.testing.expect(activity.is_eligible_for_search);
    try std.testing.expect(activity.is_eligible_for_prediction);
}

test "ActivityState properties" {
    try std.testing.expect(ActivityState.active.isActive());
    try std.testing.expect(ActivityState.continuing.isActive());
    try std.testing.expect(!ActivityState.inactive.isActive());
    try std.testing.expect(ActivityState.completed.isFinished());
    try std.testing.expect(ActivityState.cancelled.isFinished());
}

test "UserActivity creation" {
    const activity_type = ActivityType.init("com.app.browse", "Browsing");
    const activity = UserActivity.init(activity_type)
        .withTitle("Reading Article")
        .withWebpageUrl("https://example.com/article");

    try std.testing.expectEqualStrings("Reading Article", activity.title);
    try std.testing.expect(activity.hasWebpage());
    try std.testing.expectEqual(ActivityState.inactive, activity.state);
}

test "UserActivity lifecycle" {
    const activity_type = ActivityType.init("com.app.test", "Test");
    var activity = UserActivity.init(activity_type);

    try std.testing.expect(!activity.isActive());

    activity.becomeActive();
    try std.testing.expect(activity.isActive());

    activity.resignActive();
    try std.testing.expect(!activity.isActive());

    activity.invalidate();
    try std.testing.expectEqual(ActivityState.cancelled, activity.state);
}

test "UserActivity needsSave" {
    const activity_type = ActivityType.init("com.app.test", "Test");
    var activity = UserActivity.init(activity_type);

    try std.testing.expect(!activity.needs_save);

    activity.markNeedsSave();
    try std.testing.expect(activity.needs_save);
}

test "DeviceType properties" {
    try std.testing.expect(DeviceType.iphone.isAppleDevice());
    try std.testing.expect(DeviceType.mac.isAppleDevice());
    try std.testing.expect(!DeviceType.android.isAppleDevice());
    try std.testing.expect(DeviceType.iphone.isMobile());
    try std.testing.expect(DeviceType.mac.isDesktop());
}

test "DeviceType toString" {
    try std.testing.expectEqualStrings("iPhone", DeviceType.iphone.toString());
    try std.testing.expectEqualStrings("Mac", DeviceType.mac.toString());
    try std.testing.expectEqualStrings("Android", DeviceType.android.toString());
}

test "NearbyDevice creation" {
    const device = NearbyDevice.init("device123", "John's iPhone", .iphone)
        .withSameUser(true)
        .withSignalStrength(-45);

    try std.testing.expectEqualStrings("device123", device.device_id);
    try std.testing.expectEqualStrings("John's iPhone", device.name);
    try std.testing.expect(device.is_same_user);
    try std.testing.expect(device.supportsHandoff());
}

test "NearbyDevice signal quality" {
    const excellent = NearbyDevice.init("d1", "D1", .iphone).withSignalStrength(-45);
    try std.testing.expectEqual(SignalQuality.excellent, excellent.signalQuality());

    const good = NearbyDevice.init("d2", "D2", .iphone).withSignalStrength(-55);
    try std.testing.expectEqual(SignalQuality.good, good.signalQuality());

    const fair = NearbyDevice.init("d3", "D3", .iphone).withSignalStrength(-65);
    try std.testing.expectEqual(SignalQuality.fair, fair.signalQuality());

    const poor = NearbyDevice.init("d4", "D4", .iphone).withSignalStrength(-80);
    try std.testing.expectEqual(SignalQuality.poor, poor.signalQuality());
}

test "SignalQuality bars" {
    try std.testing.expectEqual(@as(u8, 4), SignalQuality.excellent.bars());
    try std.testing.expectEqual(@as(u8, 3), SignalQuality.good.bars());
    try std.testing.expectEqual(@as(u8, 2), SignalQuality.fair.bars());
    try std.testing.expectEqual(@as(u8, 1), SignalQuality.poor.bars());
}

test "ClipboardContentType properties" {
    try std.testing.expectEqualStrings("Plain Text", ClipboardContentType.text.toString());
    try std.testing.expectEqualStrings("text/plain", ClipboardContentType.text.mimeType());
    try std.testing.expectEqualStrings("text/html", ClipboardContentType.html.mimeType());
}

test "ClipboardItem creation" {
    const item = ClipboardItem.init(.text, 256)
        .withSourceDevice("MacBook");

    try std.testing.expectEqual(ClipboardContentType.text, item.content_type);
    try std.testing.expectEqual(@as(u64, 256), item.data_size);
    try std.testing.expect(item.isFromRemote());
    try std.testing.expect(!item.isExpired());
}

test "ClipboardItem local" {
    const item = ClipboardItem.init(.url, 64);
    try std.testing.expect(!item.isFromRemote());
}

test "UniversalClipboard init" {
    const clipboard = UniversalClipboard.init();
    try std.testing.expect(!clipboard.is_enabled);
    try std.testing.expect(!clipboard.has_content);
    try std.testing.expect(!clipboard.hasPendingItems());
}

test "UniversalClipboard operations" {
    var clipboard = UniversalClipboard.init();

    clipboard.enable();
    try std.testing.expect(clipboard.is_enabled);

    clipboard.addPendingItem();
    try std.testing.expect(clipboard.hasPendingItems());
    try std.testing.expect(clipboard.has_content);

    clipboard.sync();
    try std.testing.expect(!clipboard.hasPendingItems());
    try std.testing.expect(clipboard.last_sync > 0);
}

test "TransferState properties" {
    try std.testing.expect(TransferState.preparing.isInProgress());
    try std.testing.expect(TransferState.transferring.isInProgress());
    try std.testing.expect(!TransferState.idle.isInProgress());
    try std.testing.expect(TransferState.completed.isFinished());
    try std.testing.expect(TransferState.failed.isFinished());
}

test "ContinuationStream creation" {
    const stream = ContinuationStream.init("stream001");
    try std.testing.expectEqualStrings("stream001", stream.stream_id);
    try std.testing.expectEqual(TransferState.idle, stream.state);
    try std.testing.expect(!stream.isComplete());
}

test "ContinuationStream progress" {
    var stream = ContinuationStream.init("stream002");

    stream.start(1000);
    try std.testing.expectEqual(TransferState.transferring, stream.state);
    try std.testing.expectEqual(@as(u64, 1000), stream.total_bytes);

    stream.updateProgress(500);
    try std.testing.expect(stream.progressPercent() > 49.9);

    stream.updateProgress(1000);
    try std.testing.expect(stream.isComplete());
}

test "ContinuationStream cancel" {
    var stream = ContinuationStream.init("stream003");
    stream.start(100);
    stream.cancel();
    try std.testing.expectEqual(TransferState.cancelled, stream.state);
}

test "HandoffController init" {
    const controller = HandoffController.init(.apple_handoff);
    try std.testing.expectEqual(HandoffProvider.apple_handoff, controller.provider);
    try std.testing.expectEqual(AvailabilityState.unavailable, controller.availability);
    try std.testing.expect(!controller.hasActiveActivity());
}

test "HandoffController availability" {
    var controller = HandoffController.init(.apple_handoff);

    controller.checkAvailability();
    try std.testing.expectEqual(AvailabilityState.checking, controller.availability);

    controller.setAvailable();
    try std.testing.expect(controller.isAvailable());

    controller.setUnavailable();
    try std.testing.expect(!controller.isAvailable());
}

test "HandoffController activity" {
    var controller = HandoffController.init(.apple_handoff);
    const activity_type = ActivityType.init("com.app.test", "Test");
    const activity = UserActivity.init(activity_type);

    controller.startActivity(activity);
    try std.testing.expect(controller.hasActiveActivity());

    controller.stopActivity();
    try std.testing.expect(!controller.hasActiveActivity());
}

test "HandoffController nearby devices" {
    var controller = HandoffController.init(.apple_handoff);
    try std.testing.expect(!controller.hasNearbyDevices());

    controller.updateNearbyDevices(3);
    try std.testing.expect(controller.hasNearbyDevices());
    try std.testing.expectEqual(@as(u32, 3), controller.nearby_device_count);
}

test "isHandoffSupported" {
    try std.testing.expect(!isHandoffSupported());
}

test "currentDeviceType" {
    const device = currentDeviceType();
    try std.testing.expectEqual(DeviceType.unknown, device);
}
