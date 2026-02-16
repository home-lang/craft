//! Continuity Module
//! Apple Continuity features: Continuity Camera, Universal Clipboard, Sidecar, AirDrop
//! Provides cross-platform abstractions for seamless device integration

const std = @import("std");
const builtin = @import("builtin");

/// Platform support for Continuity
pub const Platform = enum {
    macos,
    ios,
    ipados,
    unsupported,

    pub fn current() Platform {
        return switch (builtin.os.tag) {
            .macos => .macos,
            .ios => .ios,
            else => .unsupported,
        };
    }

    pub fn supportsUniversalClipboard(self: Platform) bool {
        return self == .macos or self == .ios or self == .ipados;
    }

    pub fn supportsContinuityCamera(self: Platform) bool {
        return self == .macos; // macOS receives camera from iOS
    }

    pub fn supportsSidecar(self: Platform) bool {
        return self == .macos or self == .ipados;
    }
};

/// Continuity feature type
pub const ContinuityFeature = enum {
    universal_clipboard,
    continuity_camera,
    sidecar,
    airdrop,
    instant_hotspot,
    auto_unlock,
    relay_calls,
    sms_relay,
    desk_view,
    markup,

    pub fn requiresBluetooth(self: ContinuityFeature) bool {
        return switch (self) {
            .instant_hotspot, .auto_unlock => true,
            else => false,
        };
    }

    pub fn requiresWifi(self: ContinuityFeature) bool {
        return switch (self) {
            .sidecar, .airdrop, .universal_clipboard => true,
            else => false,
        };
    }
};

/// Device type for continuity
pub const DeviceType = enum {
    iphone,
    ipad,
    mac,
    apple_watch,
    apple_tv,
    unknown,
};

/// Nearby device for continuity
pub const NearbyDevice = struct {
    id: []const u8,
    name: []const u8,
    device_type: DeviceType = .unknown,
    is_connected: bool = false,
    is_trusted: bool = false,
    signal_strength: ?i8 = null, // dBm
    last_seen: i64 = 0,
    supported_features: std.ArrayListUnmanaged(ContinuityFeature) = .empty,

    pub fn init(id: []const u8, name: []const u8) NearbyDevice {
        return .{
            .id = id,
            .name = name,
            .last_seen = getCurrentTimestamp(),
        };
    }

    pub fn withType(self: NearbyDevice, device_type: DeviceType) NearbyDevice {
        var copy = self;
        copy.device_type = device_type;
        return copy;
    }

    pub fn withSignalStrength(self: NearbyDevice, strength: i8) NearbyDevice {
        var copy = self;
        copy.signal_strength = strength;
        return copy;
    }

    pub fn asConnected(self: NearbyDevice) NearbyDevice {
        var copy = self;
        copy.is_connected = true;
        return copy;
    }

    pub fn asTrusted(self: NearbyDevice) NearbyDevice {
        var copy = self;
        copy.is_trusted = true;
        return copy;
    }

    pub fn supportsFeature(self: *const NearbyDevice, feature: ContinuityFeature) bool {
        for (self.supported_features.items) |f| {
            if (f == feature) return true;
        }
        return false;
    }
};

// ============================================================================
// Universal Clipboard
// ============================================================================

/// Clipboard content type
pub const ClipboardContentType = enum {
    text,
    rich_text,
    image,
    url,
    file,
    custom,
};

/// Universal clipboard item
pub const ClipboardItem = struct {
    content_type: ClipboardContentType,
    data: []const u8,
    source_device_id: ?[]const u8 = null,
    expiration: ?i64 = null,
    created_at: i64,

    pub fn init(content_type: ClipboardContentType, data: []const u8) ClipboardItem {
        return .{
            .content_type = content_type,
            .data = data,
            .created_at = getCurrentTimestamp(),
        };
    }

    pub fn text(data: []const u8) ClipboardItem {
        return init(.text, data);
    }

    pub fn url(data: []const u8) ClipboardItem {
        return init(.url, data);
    }

    pub fn image(data: []const u8) ClipboardItem {
        return init(.image, data);
    }

    pub fn withSource(self: ClipboardItem, device_id: []const u8) ClipboardItem {
        var copy = self;
        copy.source_device_id = device_id;
        return copy;
    }

    pub fn withExpiration(self: ClipboardItem, expiration: i64) ClipboardItem {
        var copy = self;
        copy.expiration = expiration;
        return copy;
    }

    pub fn isExpired(self: *const ClipboardItem) bool {
        if (self.expiration) |exp| {
            return getCurrentTimestamp() > exp;
        }
        return false;
    }
};

/// Universal Clipboard Manager
pub const UniversalClipboard = struct {
    allocator: std.mem.Allocator,
    current_item: ?ClipboardItem = null,
    history: std.ArrayListUnmanaged(ClipboardItem),
    max_history: usize = 50,
    sync_enabled: bool = true,
    expiration_seconds: i64 = 120, // 2 minutes default

    pub fn init(allocator: std.mem.Allocator) UniversalClipboard {
        return .{
            .allocator = allocator,
            .history = .empty,
        };
    }

    pub fn deinit(self: *UniversalClipboard) void {
        self.history.deinit(self.allocator);
    }

    pub fn copy(self: *UniversalClipboard, item: ClipboardItem) !void {
        var item_with_expiration = item;
        if (item_with_expiration.expiration == null) {
            item_with_expiration.expiration = getCurrentTimestamp() + self.expiration_seconds;
        }

        self.current_item = item_with_expiration;

        if (self.history.items.len >= self.max_history) {
            _ = self.history.orderedRemove(0);
        }
        try self.history.append(self.allocator, item_with_expiration);
    }

    pub fn paste(self: *const UniversalClipboard) ?ClipboardItem {
        if (self.current_item) |item| {
            if (!item.isExpired()) {
                return item;
            }
        }
        return null;
    }

    pub fn clear(self: *UniversalClipboard) void {
        self.current_item = null;
    }

    pub fn getHistory(self: *const UniversalClipboard) []const ClipboardItem {
        return self.history.items;
    }

    pub fn clearHistory(self: *UniversalClipboard) void {
        self.history.clearAndFree(self.allocator);
    }

    pub fn setMaxHistory(self: *UniversalClipboard, max: usize) void {
        self.max_history = max;
    }

    pub fn setSyncEnabled(self: *UniversalClipboard, enabled: bool) void {
        self.sync_enabled = enabled;
    }

    pub fn setExpirationSeconds(self: *UniversalClipboard, seconds: i64) void {
        self.expiration_seconds = seconds;
    }

    pub fn historyCount(self: *const UniversalClipboard) usize {
        return self.history.items.len;
    }
};

// ============================================================================
// Continuity Camera
// ============================================================================

/// Camera mode for Continuity Camera
pub const CameraMode = enum {
    standard, // Normal webcam
    desk_view, // Overhead desk view
    portrait, // Portrait mode with blur
    studio_light, // Studio lighting effect
    center_stage, // Auto-framing
};

/// Camera quality
pub const CameraQuality = enum {
    low, // 480p
    medium, // 720p
    high, // 1080p
    ultra, // 4K

    pub fn resolution(self: CameraQuality) struct { width: u32, height: u32 } {
        return switch (self) {
            .low => .{ .width = 640, .height = 480 },
            .medium => .{ .width = 1280, .height = 720 },
            .high => .{ .width = 1920, .height = 1080 },
            .ultra => .{ .width = 3840, .height = 2160 },
        };
    }
};

/// Camera state
pub const CameraState = enum {
    disconnected,
    connecting,
    connected,
    streaming,
    paused,
    error_state,
};

/// Continuity Camera session
pub const CameraSession = struct {
    id: []const u8,
    device_id: []const u8,
    device_name: []const u8,
    state: CameraState = .disconnected,
    mode: CameraMode = .standard,
    quality: CameraQuality = .high,
    is_muted: bool = false,
    started_at: ?i64 = null,
    frame_count: u64 = 0,

    pub fn init(id: []const u8, device_id: []const u8, device_name: []const u8) CameraSession {
        return .{
            .id = id,
            .device_id = device_id,
            .device_name = device_name,
        };
    }

    pub fn connect(self: *CameraSession) void {
        self.state = .connecting;
    }

    pub fn onConnected(self: *CameraSession) void {
        self.state = .connected;
    }

    pub fn startStreaming(self: *CameraSession) void {
        self.state = .streaming;
        self.started_at = getCurrentTimestamp();
    }

    pub fn pause(self: *CameraSession) void {
        if (self.state == .streaming) {
            self.state = .paused;
        }
    }

    pub fn resume_streaming(self: *CameraSession) void {
        if (self.state == .paused) {
            self.state = .streaming;
        }
    }

    pub fn stop(self: *CameraSession) void {
        self.state = .disconnected;
        self.started_at = null;
    }

    pub fn setMode(self: *CameraSession, mode: CameraMode) void {
        self.mode = mode;
    }

    pub fn setQuality(self: *CameraSession, quality: CameraQuality) void {
        self.quality = quality;
    }

    pub fn mute(self: *CameraSession) void {
        self.is_muted = true;
    }

    pub fn unmute(self: *CameraSession) void {
        self.is_muted = false;
    }

    pub fn incrementFrameCount(self: *CameraSession) void {
        self.frame_count += 1;
    }

    pub fn isActive(self: *const CameraSession) bool {
        return self.state == .streaming;
    }

    pub fn duration(self: *const CameraSession) ?i64 {
        if (self.started_at) |start| {
            return getCurrentTimestamp() - start;
        }
        return null;
    }
};

/// Continuity Camera Manager
pub const ContinuityCameraManager = struct {
    allocator: std.mem.Allocator,
    sessions: std.ArrayListUnmanaged(CameraSession),
    available_devices: std.ArrayListUnmanaged(NearbyDevice),
    active_session_id: ?[]const u8 = null,
    session_counter: u64 = 0,
    default_mode: CameraMode = .standard,
    default_quality: CameraQuality = .high,

    pub fn init(allocator: std.mem.Allocator) ContinuityCameraManager {
        return .{
            .allocator = allocator,
            .sessions = .empty,
            .available_devices = .empty,
        };
    }

    pub fn deinit(self: *ContinuityCameraManager) void {
        self.sessions.deinit(self.allocator);
        self.available_devices.deinit(self.allocator);
    }

    pub fn scanForDevices(self: *ContinuityCameraManager) void {
        // In real implementation, this would scan for nearby iOS devices
        _ = self;
    }

    pub fn addAvailableDevice(self: *ContinuityCameraManager, device: NearbyDevice) !void {
        try self.available_devices.append(self.allocator, device);
    }

    pub fn getAvailableDevices(self: *const ContinuityCameraManager) []const NearbyDevice {
        return self.available_devices.items;
    }

    pub fn createSession(self: *ContinuityCameraManager, device_id: []const u8, device_name: []const u8) !*CameraSession {
        self.session_counter += 1;

        var id_buf: [32]u8 = undefined;
        const id = try std.fmt.bufPrint(&id_buf, "camera_{d}", .{self.session_counter});

        var session = CameraSession.init(id, device_id, device_name);
        session.mode = self.default_mode;
        session.quality = self.default_quality;

        try self.sessions.append(self.allocator, session);
        return &self.sessions.items[self.sessions.items.len - 1];
    }

    pub fn connectSession(self: *ContinuityCameraManager, session_id: []const u8) !void {
        const session = self.findSession(session_id) orelse return error.SessionNotFound;
        session.connect();
        session.onConnected();
    }

    pub fn startSession(self: *ContinuityCameraManager, session_id: []const u8) !void {
        const session = self.findSession(session_id) orelse return error.SessionNotFound;

        if (session.state != .connected and session.state != .paused) {
            return error.NotConnected;
        }

        session.startStreaming();
        self.active_session_id = session_id;
    }

    pub fn stopSession(self: *ContinuityCameraManager, session_id: []const u8) !void {
        const session = self.findSession(session_id) orelse return error.SessionNotFound;
        session.stop();

        if (self.active_session_id) |active_id| {
            if (std.mem.eql(u8, active_id, session_id)) {
                self.active_session_id = null;
            }
        }
    }

    pub fn findSession(self: *ContinuityCameraManager, session_id: []const u8) ?*CameraSession {
        for (self.sessions.items) |*session| {
            if (std.mem.eql(u8, session.id, session_id)) {
                return session;
            }
        }
        return null;
    }

    pub fn getActiveSession(self: *ContinuityCameraManager) ?*CameraSession {
        if (self.active_session_id) |id| {
            return self.findSession(id);
        }
        return null;
    }

    pub fn setDefaultMode(self: *ContinuityCameraManager, mode: CameraMode) void {
        self.default_mode = mode;
    }

    pub fn setDefaultQuality(self: *ContinuityCameraManager, quality: CameraQuality) void {
        self.default_quality = quality;
    }

    pub fn sessionCount(self: *const ContinuityCameraManager) usize {
        return self.sessions.items.len;
    }

    pub fn activeSessionCount(self: *const ContinuityCameraManager) usize {
        var count: usize = 0;
        for (self.sessions.items) |session| {
            if (session.isActive()) {
                count += 1;
            }
        }
        return count;
    }
};

// ============================================================================
// AirDrop
// ============================================================================

/// AirDrop visibility
pub const AirDropVisibility = enum {
    off,
    contacts_only,
    everyone,
};

/// AirDrop transfer state
pub const TransferState = enum {
    pending,
    waiting_acceptance,
    transferring,
    completed,
    rejected,
    failed,
    cancelled,
};

/// AirDrop item to transfer
pub const AirDropItem = struct {
    id: u64,
    name: []const u8,
    file_path: ?[]const u8 = null,
    data: ?[]const u8 = null,
    size_bytes: u64 = 0,
    mime_type: []const u8 = "application/octet-stream",

    pub fn init(id: u64, name: []const u8) AirDropItem {
        return .{
            .id = id,
            .name = name,
        };
    }

    pub fn withPath(self: AirDropItem, path: []const u8) AirDropItem {
        var copy = self;
        copy.file_path = path;
        return copy;
    }

    pub fn withData(self: AirDropItem, data: []const u8) AirDropItem {
        var copy = self;
        copy.data = data;
        copy.size_bytes = data.len;
        return copy;
    }

    pub fn withMimeType(self: AirDropItem, mime_type: []const u8) AirDropItem {
        var copy = self;
        copy.mime_type = mime_type;
        return copy;
    }

    pub fn withSize(self: AirDropItem, size: u64) AirDropItem {
        var copy = self;
        copy.size_bytes = size;
        return copy;
    }
};

/// AirDrop transfer
pub const AirDropTransfer = struct {
    id: []const u8,
    items: std.ArrayListUnmanaged(AirDropItem),
    target_device_id: ?[]const u8 = null,
    source_device_id: ?[]const u8 = null,
    state: TransferState = .pending,
    progress: f32 = 0.0,
    bytes_transferred: u64 = 0,
    total_bytes: u64 = 0,
    started_at: ?i64 = null,
    completed_at: ?i64 = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, id: []const u8) AirDropTransfer {
        return .{
            .allocator = allocator,
            .id = id,
            .items = .empty,
        };
    }

    pub fn deinit(self: *AirDropTransfer) void {
        self.items.deinit(self.allocator);
    }

    pub fn addItem(self: *AirDropTransfer, item: AirDropItem) !void {
        self.total_bytes += item.size_bytes;
        try self.items.append(self.allocator, item);
    }

    pub fn itemCount(self: *const AirDropTransfer) usize {
        return self.items.items.len;
    }

    pub fn start(self: *AirDropTransfer) void {
        self.state = .transferring;
        self.started_at = getCurrentTimestamp();
    }

    pub fn updateProgress(self: *AirDropTransfer, bytes: u64) void {
        self.bytes_transferred = bytes;
        if (self.total_bytes > 0) {
            self.progress = @as(f32, @floatFromInt(bytes)) / @as(f32, @floatFromInt(self.total_bytes));
        }
    }

    pub fn complete(self: *AirDropTransfer) void {
        self.state = .completed;
        self.progress = 1.0;
        self.bytes_transferred = self.total_bytes;
        self.completed_at = getCurrentTimestamp();
    }

    pub fn reject(self: *AirDropTransfer) void {
        self.state = .rejected;
    }

    pub fn cancel(self: *AirDropTransfer) void {
        self.state = .cancelled;
    }

    pub fn fail(self: *AirDropTransfer) void {
        self.state = .failed;
    }

    pub fn isComplete(self: *const AirDropTransfer) bool {
        return self.state == .completed;
    }

    pub fn duration(self: *const AirDropTransfer) ?i64 {
        if (self.started_at) |start_time| {
            const end_time = self.completed_at orelse getCurrentTimestamp();
            return end_time - start_time;
        }
        return null;
    }
};

/// AirDrop Manager
pub const AirDropManager = struct {
    allocator: std.mem.Allocator,
    visibility: AirDropVisibility = .contacts_only,
    transfers: std.ArrayListUnmanaged(AirDropTransfer),
    nearby_devices: std.ArrayListUnmanaged(NearbyDevice),
    transfer_counter: u64 = 0,
    is_enabled: bool = true,

    pub fn init(allocator: std.mem.Allocator) AirDropManager {
        return .{
            .allocator = allocator,
            .transfers = .empty,
            .nearby_devices = .empty,
        };
    }

    pub fn deinit(self: *AirDropManager) void {
        for (self.transfers.items) |*transfer| {
            transfer.deinit();
        }
        self.transfers.deinit(self.allocator);
        self.nearby_devices.deinit(self.allocator);
    }

    pub fn setVisibility(self: *AirDropManager, visibility: AirDropVisibility) void {
        self.visibility = visibility;
    }

    pub fn setEnabled(self: *AirDropManager, enabled: bool) void {
        self.is_enabled = enabled;
    }

    pub fn addNearbyDevice(self: *AirDropManager, device: NearbyDevice) !void {
        try self.nearby_devices.append(self.allocator, device);
    }

    pub fn getNearbyDevices(self: *const AirDropManager) []const NearbyDevice {
        return self.nearby_devices.items;
    }

    pub fn createTransfer(self: *AirDropManager) !*AirDropTransfer {
        self.transfer_counter += 1;

        var id_buf: [32]u8 = undefined;
        const id = try std.fmt.bufPrint(&id_buf, "transfer_{d}", .{self.transfer_counter});

        const transfer = AirDropTransfer.init(self.allocator, id);
        try self.transfers.append(self.allocator, transfer);

        return &self.transfers.items[self.transfers.items.len - 1];
    }

    pub fn sendToDevice(self: *AirDropManager, transfer_id: []const u8, device_id: []const u8) !void {
        const transfer = self.findTransfer(transfer_id) orelse return error.TransferNotFound;

        if (!self.is_enabled) {
            return error.AirDropDisabled;
        }

        transfer.target_device_id = device_id;
        transfer.state = .waiting_acceptance;
    }

    pub fn acceptTransfer(self: *AirDropManager, transfer_id: []const u8) !void {
        const transfer = self.findTransfer(transfer_id) orelse return error.TransferNotFound;

        if (transfer.state != .waiting_acceptance) {
            return error.InvalidState;
        }

        transfer.start();
    }

    pub fn findTransfer(self: *AirDropManager, transfer_id: []const u8) ?*AirDropTransfer {
        for (self.transfers.items) |*transfer| {
            if (std.mem.eql(u8, transfer.id, transfer_id)) {
                return transfer;
            }
        }
        return null;
    }

    pub fn transferCount(self: *const AirDropManager) usize {
        return self.transfers.items.len;
    }

    pub fn activeTransferCount(self: *const AirDropManager) usize {
        var count: usize = 0;
        for (self.transfers.items) |transfer| {
            if (transfer.state == .transferring) {
                count += 1;
            }
        }
        return count;
    }

    pub fn completedTransferCount(self: *const AirDropManager) usize {
        var count: usize = 0;
        for (self.transfers.items) |transfer| {
            if (transfer.state == .completed) {
                count += 1;
            }
        }
        return count;
    }
};

// ============================================================================
// Continuity Controller
// ============================================================================

/// Continuity event type
pub const ContinuityEvent = struct {
    event_type: EventType,
    device_id: ?[]const u8 = null,
    feature: ?ContinuityFeature = null,
    timestamp: i64,
    data: ?[]const u8 = null,

    pub const EventType = enum {
        device_discovered,
        device_lost,
        device_connected,
        device_disconnected,
        clipboard_changed,
        camera_started,
        camera_stopped,
        transfer_started,
        transfer_completed,
        transfer_failed,
    };

    pub fn init(event_type: EventType) ContinuityEvent {
        return .{
            .event_type = event_type,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn withDevice(self: ContinuityEvent, device_id: []const u8) ContinuityEvent {
        var copy = self;
        copy.device_id = device_id;
        return copy;
    }

    pub fn withFeature(self: ContinuityEvent, feature: ContinuityFeature) ContinuityEvent {
        var copy = self;
        copy.feature = feature;
        return copy;
    }
};

/// Main Continuity Controller
pub const ContinuityController = struct {
    allocator: std.mem.Allocator,
    clipboard: UniversalClipboard,
    camera_manager: ContinuityCameraManager,
    airdrop_manager: AirDropManager,
    event_history: std.ArrayListUnmanaged(ContinuityEvent),
    event_callback: ?*const fn (ContinuityEvent) void = null,
    enabled_features: std.ArrayListUnmanaged(ContinuityFeature),

    pub fn init(allocator: std.mem.Allocator) ContinuityController {
        return .{
            .allocator = allocator,
            .clipboard = UniversalClipboard.init(allocator),
            .camera_manager = ContinuityCameraManager.init(allocator),
            .airdrop_manager = AirDropManager.init(allocator),
            .event_history = .empty,
            .enabled_features = .empty,
        };
    }

    pub fn deinit(self: *ContinuityController) void {
        self.clipboard.deinit();
        self.camera_manager.deinit();
        self.airdrop_manager.deinit();
        self.event_history.deinit(self.allocator);
        self.enabled_features.deinit(self.allocator);
    }

    pub fn enableFeature(self: *ContinuityController, feature: ContinuityFeature) !void {
        for (self.enabled_features.items) |f| {
            if (f == feature) return; // Already enabled
        }
        try self.enabled_features.append(self.allocator, feature);
    }

    pub fn disableFeature(self: *ContinuityController, feature: ContinuityFeature) void {
        var i: usize = 0;
        while (i < self.enabled_features.items.len) {
            if (self.enabled_features.items[i] == feature) {
                _ = self.enabled_features.orderedRemove(i);
                return;
            }
            i += 1;
        }
    }

    pub fn isFeatureEnabled(self: *const ContinuityController, feature: ContinuityFeature) bool {
        for (self.enabled_features.items) |f| {
            if (f == feature) return true;
        }
        return false;
    }

    pub fn copyToClipboard(self: *ContinuityController, item: ClipboardItem) !void {
        try self.clipboard.copy(item);

        const event = ContinuityEvent.init(.clipboard_changed)
            .withFeature(.universal_clipboard);
        try self.event_history.append(self.allocator, event);

        if (self.event_callback) |callback| {
            callback(event);
        }
    }

    pub fn pasteFromClipboard(self: *const ContinuityController) ?ClipboardItem {
        return self.clipboard.paste();
    }

    pub fn setEventCallback(self: *ContinuityController, callback: *const fn (ContinuityEvent) void) void {
        self.event_callback = callback;
    }

    pub fn getEventHistory(self: *const ContinuityController) []const ContinuityEvent {
        return self.event_history.items;
    }

    pub fn clearEventHistory(self: *ContinuityController) void {
        self.event_history.clearAndFree(self.allocator);
    }

    pub fn enabledFeatureCount(self: *const ContinuityController) usize {
        return self.enabled_features.items.len;
    }
};

/// Helper to get current timestamp
fn getCurrentTimestamp() i64 {
    if (builtin.os.tag == .macos or builtin.os.tag == .ios or
        builtin.os.tag == .tvos or builtin.os.tag == .watchos)
    {
        var ts: std.c.timespec = undefined;
        if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
            return ts.sec;
        }
        return 0;
    } else if (builtin.os.tag == .windows) {
        return std.time.timestamp();
    } else if (builtin.os.tag == .linux) {
        var ts: std.c.timespec = undefined;
        if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
            return ts.sec;
        }
        return 0;
    } else {
        return 0;
    }
}

// ============================================================================
// Tests
// ============================================================================

test "Platform detection" {
    const platform = Platform.current();
    try std.testing.expect(platform == .macos or platform != .macos);
}

test "Platform feature support" {
    try std.testing.expect(Platform.macos.supportsUniversalClipboard());
    try std.testing.expect(Platform.ios.supportsUniversalClipboard());
    try std.testing.expect(Platform.macos.supportsContinuityCamera());
    try std.testing.expect(!Platform.ios.supportsContinuityCamera());
}

test "ContinuityFeature requirements" {
    try std.testing.expect(ContinuityFeature.instant_hotspot.requiresBluetooth());
    try std.testing.expect(ContinuityFeature.auto_unlock.requiresBluetooth());
    try std.testing.expect(!ContinuityFeature.airdrop.requiresBluetooth());

    try std.testing.expect(ContinuityFeature.sidecar.requiresWifi());
    try std.testing.expect(ContinuityFeature.airdrop.requiresWifi());
}

test "NearbyDevice init and builder" {
    const device = NearbyDevice.init("device1", "iPhone")
        .withType(.iphone)
        .withSignalStrength(-50)
        .asConnected()
        .asTrusted();

    try std.testing.expectEqualStrings("device1", device.id);
    try std.testing.expectEqualStrings("iPhone", device.name);
    try std.testing.expectEqual(DeviceType.iphone, device.device_type);
    try std.testing.expectEqual(@as(?i8, -50), device.signal_strength);
    try std.testing.expect(device.is_connected);
    try std.testing.expect(device.is_trusted);
}

test "ClipboardItem factories" {
    const text_item = ClipboardItem.text("Hello");
    try std.testing.expectEqual(ClipboardContentType.text, text_item.content_type);
    try std.testing.expectEqualStrings("Hello", text_item.data);

    const url_item = ClipboardItem.url("https://example.com");
    try std.testing.expectEqual(ClipboardContentType.url, url_item.content_type);
}

test "ClipboardItem builder" {
    const item = ClipboardItem.text("test")
        .withSource("device1")
        .withExpiration(9999999999);

    try std.testing.expectEqualStrings("device1", item.source_device_id.?);
    try std.testing.expect(!item.isExpired());
}

test "UniversalClipboard copy and paste" {
    var clipboard = UniversalClipboard.init(std.testing.allocator);
    defer clipboard.deinit();

    const item = ClipboardItem.text("test data");
    try clipboard.copy(item);

    const pasted = clipboard.paste();
    try std.testing.expect(pasted != null);
    try std.testing.expectEqualStrings("test data", pasted.?.data);
}

test "UniversalClipboard history" {
    var clipboard = UniversalClipboard.init(std.testing.allocator);
    defer clipboard.deinit();

    try clipboard.copy(ClipboardItem.text("first"));
    try clipboard.copy(ClipboardItem.text("second"));

    try std.testing.expectEqual(@as(usize, 2), clipboard.historyCount());
}

test "UniversalClipboard clear" {
    var clipboard = UniversalClipboard.init(std.testing.allocator);
    defer clipboard.deinit();

    try clipboard.copy(ClipboardItem.text("test"));
    clipboard.clear();

    try std.testing.expect(clipboard.paste() == null);
}

test "CameraQuality resolution" {
    const low = CameraQuality.low.resolution();
    try std.testing.expectEqual(@as(u32, 640), low.width);
    try std.testing.expectEqual(@as(u32, 480), low.height);

    const ultra = CameraQuality.ultra.resolution();
    try std.testing.expectEqual(@as(u32, 3840), ultra.width);
}

test "CameraSession lifecycle" {
    var session = CameraSession.init("session1", "device1", "iPhone");

    try std.testing.expectEqual(CameraState.disconnected, session.state);

    session.connect();
    try std.testing.expectEqual(CameraState.connecting, session.state);

    session.onConnected();
    try std.testing.expectEqual(CameraState.connected, session.state);

    session.startStreaming();
    try std.testing.expectEqual(CameraState.streaming, session.state);
    try std.testing.expect(session.isActive());

    session.pause();
    try std.testing.expectEqual(CameraState.paused, session.state);

    session.resume_streaming();
    try std.testing.expectEqual(CameraState.streaming, session.state);

    session.stop();
    try std.testing.expectEqual(CameraState.disconnected, session.state);
}

test "CameraSession mute" {
    var session = CameraSession.init("session1", "device1", "iPhone");

    try std.testing.expect(!session.is_muted);
    session.mute();
    try std.testing.expect(session.is_muted);
    session.unmute();
    try std.testing.expect(!session.is_muted);
}

test "ContinuityCameraManager createSession" {
    var manager = ContinuityCameraManager.init(std.testing.allocator);
    defer manager.deinit();

    _ = try manager.createSession("device1", "iPhone");
    try std.testing.expectEqual(@as(usize, 1), manager.sessionCount());
}

test "ContinuityCameraManager startSession" {
    var manager = ContinuityCameraManager.init(std.testing.allocator);
    defer manager.deinit();

    const session = try manager.createSession("device1", "iPhone");
    try manager.connectSession(session.id);
    try manager.startSession(session.id);

    try std.testing.expectEqual(CameraState.streaming, session.state);
    try std.testing.expect(manager.active_session_id != null);
}

test "AirDropItem builder" {
    const item = AirDropItem.init(1, "photo.jpg")
        .withPath("/path/to/photo.jpg")
        .withMimeType("image/jpeg")
        .withSize(1024);

    try std.testing.expectEqualStrings("photo.jpg", item.name);
    try std.testing.expectEqualStrings("/path/to/photo.jpg", item.file_path.?);
    try std.testing.expectEqualStrings("image/jpeg", item.mime_type);
    try std.testing.expectEqual(@as(u64, 1024), item.size_bytes);
}

test "AirDropTransfer lifecycle" {
    var transfer = AirDropTransfer.init(std.testing.allocator, "transfer1");
    defer transfer.deinit();

    try transfer.addItem(AirDropItem.init(1, "file1.txt").withSize(100));
    try transfer.addItem(AirDropItem.init(2, "file2.txt").withSize(200));

    try std.testing.expectEqual(@as(usize, 2), transfer.itemCount());
    try std.testing.expectEqual(@as(u64, 300), transfer.total_bytes);

    transfer.start();
    try std.testing.expectEqual(TransferState.transferring, transfer.state);

    transfer.updateProgress(150);
    try std.testing.expectEqual(@as(u64, 150), transfer.bytes_transferred);
    try std.testing.expectEqual(@as(f32, 0.5), transfer.progress);

    transfer.complete();
    try std.testing.expect(transfer.isComplete());
    try std.testing.expectEqual(@as(f32, 1.0), transfer.progress);
}

test "AirDropTransfer reject and cancel" {
    var transfer = AirDropTransfer.init(std.testing.allocator, "transfer1");
    defer transfer.deinit();

    transfer.state = .waiting_acceptance;
    transfer.reject();
    try std.testing.expectEqual(TransferState.rejected, transfer.state);

    transfer.state = .transferring;
    transfer.cancel();
    try std.testing.expectEqual(TransferState.cancelled, transfer.state);
}

test "AirDropManager createTransfer" {
    var manager = AirDropManager.init(std.testing.allocator);
    defer manager.deinit();

    _ = try manager.createTransfer();
    try std.testing.expectEqual(@as(usize, 1), manager.transferCount());
}

test "AirDropManager visibility" {
    var manager = AirDropManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectEqual(AirDropVisibility.contacts_only, manager.visibility);

    manager.setVisibility(.everyone);
    try std.testing.expectEqual(AirDropVisibility.everyone, manager.visibility);
}

test "ContinuityEvent builder" {
    const event = ContinuityEvent.init(.device_discovered)
        .withDevice("device1")
        .withFeature(.airdrop);

    try std.testing.expectEqual(ContinuityEvent.EventType.device_discovered, event.event_type);
    try std.testing.expectEqualStrings("device1", event.device_id.?);
    try std.testing.expectEqual(ContinuityFeature.airdrop, event.feature.?);
}

test "ContinuityController init and deinit" {
    var controller = ContinuityController.init(std.testing.allocator);
    defer controller.deinit();

    try std.testing.expectEqual(@as(usize, 0), controller.enabledFeatureCount());
}

test "ContinuityController enableFeature" {
    var controller = ContinuityController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.enableFeature(.universal_clipboard);
    try controller.enableFeature(.airdrop);

    try std.testing.expectEqual(@as(usize, 2), controller.enabledFeatureCount());
    try std.testing.expect(controller.isFeatureEnabled(.universal_clipboard));
    try std.testing.expect(controller.isFeatureEnabled(.airdrop));
}

test "ContinuityController disableFeature" {
    var controller = ContinuityController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.enableFeature(.universal_clipboard);
    try controller.enableFeature(.airdrop);

    controller.disableFeature(.universal_clipboard);

    try std.testing.expectEqual(@as(usize, 1), controller.enabledFeatureCount());
    try std.testing.expect(!controller.isFeatureEnabled(.universal_clipboard));
    try std.testing.expect(controller.isFeatureEnabled(.airdrop));
}

test "ContinuityController clipboard operations" {
    var controller = ContinuityController.init(std.testing.allocator);
    defer controller.deinit();

    const item = ClipboardItem.text("test clipboard");
    try controller.copyToClipboard(item);

    const pasted = controller.pasteFromClipboard();
    try std.testing.expect(pasted != null);
    try std.testing.expectEqualStrings("test clipboard", pasted.?.data);
}

test "ContinuityController event history" {
    var controller = ContinuityController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.copyToClipboard(ClipboardItem.text("test"));

    const history = controller.getEventHistory();
    try std.testing.expect(history.len > 0);
    try std.testing.expectEqual(ContinuityEvent.EventType.clipboard_changed, history[0].event_type);
}

test "DeviceType values" {
    try std.testing.expect(DeviceType.iphone != DeviceType.mac);
    try std.testing.expect(DeviceType.ipad != DeviceType.apple_watch);
}

test "CameraMode values" {
    try std.testing.expect(CameraMode.standard != CameraMode.desk_view);
    try std.testing.expect(CameraMode.portrait != CameraMode.center_stage);
}
