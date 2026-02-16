//! Cross-platform smartwatch module for Craft
//! Provides Apple Watch and WearOS connectivity and communication
//! for iOS and Android platforms.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Watch platform type
pub const WatchPlatform = enum {
    apple_watch,
    wear_os,
    samsung_galaxy_watch,
    fitbit,
    garmin,
    unknown,

    pub fn toString(self: WatchPlatform) []const u8 {
        return switch (self) {
            .apple_watch => "Apple Watch",
            .wear_os => "Wear OS",
            .samsung_galaxy_watch => "Samsung Galaxy Watch",
            .fitbit => "Fitbit",
            .garmin => "Garmin",
            .unknown => "Unknown",
        };
    }

    pub fn supportsCompanionApp(self: WatchPlatform) bool {
        return switch (self) {
            .apple_watch, .wear_os, .samsung_galaxy_watch => true,
            .fitbit, .garmin, .unknown => false,
        };
    }
};

/// Watch connectivity state
pub const ConnectivityState = enum {
    not_paired,
    paired_not_installed,
    paired_inactive,
    paired_active,

    pub fn toString(self: ConnectivityState) []const u8 {
        return switch (self) {
            .not_paired => "Not Paired",
            .paired_not_installed => "App Not Installed",
            .paired_inactive => "Inactive",
            .paired_active => "Active",
        };
    }

    pub fn isPaired(self: ConnectivityState) bool {
        return self != .not_paired;
    }

    pub fn isReachable(self: ConnectivityState) bool {
        return self == .paired_active;
    }
};

/// Watch reachability
pub const ReachabilityState = enum {
    not_reachable,
    reachable,

    pub fn toString(self: ReachabilityState) []const u8 {
        return switch (self) {
            .not_reachable => "Not Reachable",
            .reachable => "Reachable",
        };
    }
};

/// Complication family (Apple Watch)
pub const ComplicationFamily = enum {
    modular_small,
    modular_large,
    utilitarian_small,
    utilitarian_small_flat,
    utilitarian_large,
    circular_small,
    extra_large,
    graphic_corner,
    graphic_bezel,
    graphic_circular,
    graphic_rectangular,
    graphic_extra_large,

    pub fn toString(self: ComplicationFamily) []const u8 {
        return switch (self) {
            .modular_small => "Modular Small",
            .modular_large => "Modular Large",
            .utilitarian_small => "Utilitarian Small",
            .utilitarian_small_flat => "Utilitarian Small Flat",
            .utilitarian_large => "Utilitarian Large",
            .circular_small => "Circular Small",
            .extra_large => "Extra Large",
            .graphic_corner => "Graphic Corner",
            .graphic_bezel => "Graphic Bezel",
            .graphic_circular => "Graphic Circular",
            .graphic_rectangular => "Graphic Rectangular",
            .graphic_extra_large => "Graphic Extra Large",
        };
    }

    pub fn maxTextLength(self: ComplicationFamily) u32 {
        return switch (self) {
            .modular_small, .utilitarian_small, .circular_small => 3,
            .utilitarian_small_flat => 10,
            .utilitarian_large, .modular_large => 20,
            .graphic_corner, .graphic_circular => 15,
            .graphic_bezel => 30,
            .graphic_rectangular, .graphic_extra_large, .extra_large => 50,
        };
    }
};

/// Tile template type (Wear OS)
pub const TileTemplate = enum {
    single_slot,
    multi_slot,
    list,
    progress,
    stat,

    pub fn toString(self: TileTemplate) []const u8 {
        return switch (self) {
            .single_slot => "Single Slot",
            .multi_slot => "Multi Slot",
            .list => "List",
            .progress => "Progress",
            .stat => "Stat",
        };
    }
};

/// Watch app state
pub const WatchAppState = enum {
    not_installed,
    installed,
    running_foreground,
    running_background,
    suspended,

    pub fn toString(self: WatchAppState) []const u8 {
        return switch (self) {
            .not_installed => "Not Installed",
            .installed => "Installed",
            .running_foreground => "Running (Foreground)",
            .running_background => "Running (Background)",
            .suspended => "Suspended",
        };
    }

    pub fn isRunning(self: WatchAppState) bool {
        return self == .running_foreground or self == .running_background;
    }

    pub fn isInstalled(self: WatchAppState) bool {
        return self != .not_installed;
    }
};

/// Message priority
pub const MessagePriority = enum {
    low,
    normal,
    high,

    pub fn toString(self: MessagePriority) []const u8 {
        return switch (self) {
            .low => "Low",
            .normal => "Normal",
            .high => "High",
        };
    }
};

/// Transfer type
pub const TransferType = enum {
    message, // Real-time message
    user_info, // Background user info transfer
    application_context, // Latest state dictionary
    file, // File transfer
    complication_data, // Complication update

    pub fn toString(self: TransferType) []const u8 {
        return switch (self) {
            .message => "Message",
            .user_info => "User Info",
            .application_context => "Application Context",
            .file => "File",
            .complication_data => "Complication Data",
        };
    }

    pub fn isRealtime(self: TransferType) bool {
        return self == .message;
    }

    pub fn requiresReachability(self: TransferType) bool {
        return self == .message;
    }
};

/// Transfer status
pub const TransferStatus = enum {
    pending,
    transferring,
    completed,
    failed,
    cancelled,

    pub fn toString(self: TransferStatus) []const u8 {
        return switch (self) {
            .pending => "Pending",
            .transferring => "Transferring",
            .completed => "Completed",
            .failed => "Failed",
            .cancelled => "Cancelled",
        };
    }

    pub fn isComplete(self: TransferStatus) bool {
        return self == .completed or self == .failed or self == .cancelled;
    }

    pub fn isInProgress(self: TransferStatus) bool {
        return self == .pending or self == .transferring;
    }
};

/// Watch message
pub const WatchMessage = struct {
    id: u64,
    transfer_type: TransferType,
    priority: MessagePriority,
    payload_size: usize,
    reply_expected: bool,
    timestamp: i64,
    status: TransferStatus,
    error_message: ?[]const u8,

    const Self = @This();

    pub fn create(id: u64, transfer_type: TransferType) Self {
        return .{
            .id = id,
            .transfer_type = transfer_type,
            .priority = .normal,
            .payload_size = 0,
            .reply_expected = false,
            .timestamp = getCurrentTimestamp(),
            .status = .pending,
            .error_message = null,
        };
    }

    pub fn withPriority(self: Self, priority: MessagePriority) Self {
        var msg = self;
        msg.priority = priority;
        return msg;
    }

    pub fn expectingReply(self: Self) Self {
        var msg = self;
        msg.reply_expected = true;
        return msg;
    }

    pub fn isComplete(self: Self) bool {
        return self.status.isComplete();
    }
};

/// File transfer info
pub const FileTransfer = struct {
    id: u64,
    file_name: []const u8,
    file_size: u64,
    bytes_transferred: u64,
    status: TransferStatus,
    metadata: ?[]const u8,
    timestamp: i64,

    const Self = @This();

    pub fn getProgress(self: Self) f32 {
        if (self.file_size == 0) return 0;
        return @as(f32, @floatFromInt(self.bytes_transferred)) / @as(f32, @floatFromInt(self.file_size));
    }

    pub fn getProgressPercent(self: Self) u8 {
        return @intFromFloat(self.getProgress() * 100);
    }

    pub fn getRemainingBytes(self: Self) u64 {
        if (self.bytes_transferred >= self.file_size) return 0;
        return self.file_size - self.bytes_transferred;
    }

    pub fn isComplete(self: Self) bool {
        return self.status.isComplete();
    }
};

/// Watch information
pub const WatchInfo = struct {
    name: []const u8,
    model: []const u8,
    platform: WatchPlatform,
    os_version: []const u8,
    app_version: ?[]const u8,
    serial_number: ?[]const u8,
    battery_level: ?u8,
    is_charging: bool,

    pub fn hasBatteryInfo(self: WatchInfo) bool {
        return self.battery_level != null;
    }

    pub fn isBatteryLow(self: WatchInfo) bool {
        if (self.battery_level) |level| {
            return level <= 20;
        }
        return false;
    }
};

/// Session state for watch communication
pub const SessionState = struct {
    connectivity: ConnectivityState,
    reachability: ReachabilityState,
    watch_app_state: WatchAppState,
    is_companion_app_installed: bool,
    outstanding_transfers: u32,
    last_message_timestamp: ?i64,
    last_error: ?[]const u8,

    pub fn init() SessionState {
        return .{
            .connectivity = .not_paired,
            .reachability = .not_reachable,
            .watch_app_state = .not_installed,
            .is_companion_app_installed = false,
            .outstanding_transfers = 0,
            .last_message_timestamp = null,
            .last_error = null,
        };
    }

    pub fn canSendMessage(self: SessionState) bool {
        return self.connectivity == .paired_active and
            self.reachability == .reachable;
    }

    pub fn canTransferUserInfo(self: SessionState) bool {
        return self.connectivity.isPaired() and self.is_companion_app_installed;
    }

    pub fn canUpdateContext(self: SessionState) bool {
        return self.connectivity.isPaired() and self.is_companion_app_installed;
    }
};

/// Watch event types
pub const WatchEventType = enum {
    session_activated,
    session_deactivated,
    reachability_changed,
    connectivity_changed,
    watch_state_changed,
    message_received,
    message_sent,
    message_failed,
    file_transfer_started,
    file_transfer_progress,
    file_transfer_completed,
    file_transfer_failed,
    user_info_received,
    context_updated,
    complication_requested,
    watch_error,
};

/// Watch event
pub const WatchEvent = struct {
    event_type: WatchEventType,
    message_id: ?u64,
    transfer_id: ?u64,
    error_message: ?[]const u8,
    timestamp: i64,

    pub fn create(event_type: WatchEventType) WatchEvent {
        return .{
            .event_type = event_type,
            .message_id = null,
            .transfer_id = null,
            .error_message = null,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn forMessage(event_type: WatchEventType, message_id: u64) WatchEvent {
        return .{
            .event_type = event_type,
            .message_id = message_id,
            .transfer_id = null,
            .error_message = null,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn forTransfer(event_type: WatchEventType, transfer_id: u64) WatchEvent {
        return .{
            .event_type = event_type,
            .message_id = null,
            .transfer_id = transfer_id,
            .error_message = null,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn withError(event_type: WatchEventType, error_msg: []const u8) WatchEvent {
        return .{
            .event_type = event_type,
            .message_id = null,
            .transfer_id = null,
            .error_message = error_msg,
            .timestamp = getCurrentTimestamp(),
        };
    }
};

/// Callback type for watch events
pub const WatchCallback = *const fn (event: WatchEvent) void;

/// Complication data
pub const ComplicationData = struct {
    family: ComplicationFamily,
    text_primary: ?[]const u8,
    text_secondary: ?[]const u8,
    value: ?f32,
    value_min: f32,
    value_max: f32,
    image_name: ?[]const u8,
    tint_color: ?u32,

    pub fn init(family: ComplicationFamily) ComplicationData {
        return .{
            .family = family,
            .text_primary = null,
            .text_secondary = null,
            .value = null,
            .value_min = 0,
            .value_max = 1,
            .image_name = null,
            .tint_color = null,
        };
    }

    pub fn withText(self: ComplicationData, primary: []const u8) ComplicationData {
        var data = self;
        data.text_primary = primary;
        return data;
    }

    pub fn withSecondaryText(self: ComplicationData, secondary: []const u8) ComplicationData {
        var data = self;
        data.text_secondary = secondary;
        return data;
    }

    pub fn withValue(self: ComplicationData, value: f32, min: f32, max: f32) ComplicationData {
        var data = self;
        data.value = value;
        data.value_min = min;
        data.value_max = max;
        return data;
    }

    pub fn withImage(self: ComplicationData, image_name: []const u8) ComplicationData {
        var data = self;
        data.image_name = image_name;
        return data;
    }

    pub fn getNormalizedValue(self: ComplicationData) ?f32 {
        if (self.value) |v| {
            const range = self.value_max - self.value_min;
            if (range == 0) return 0;
            return (v - self.value_min) / range;
        }
        return null;
    }
};

/// Tile data (Wear OS)
pub const TileData = struct {
    template: TileTemplate,
    title: ?[]const u8,
    subtitle: ?[]const u8,
    body: ?[]const u8,
    progress_value: ?f32,
    icon_resource: ?[]const u8,
    action_id: ?[]const u8,
    refresh_interval_ms: u64,

    pub fn init(template: TileTemplate) TileData {
        return .{
            .template = template,
            .title = null,
            .subtitle = null,
            .body = null,
            .progress_value = null,
            .icon_resource = null,
            .action_id = null,
            .refresh_interval_ms = 60000, // 1 minute default
        };
    }

    pub fn withTitle(self: TileData, title: []const u8) TileData {
        var data = self;
        data.title = title;
        return data;
    }

    pub fn withSubtitle(self: TileData, subtitle: []const u8) TileData {
        var data = self;
        data.subtitle = subtitle;
        return data;
    }

    pub fn withProgress(self: TileData, value: f32) TileData {
        var data = self;
        data.progress_value = std.math.clamp(value, 0, 1);
        return data;
    }

    pub fn withAction(self: TileData, action_id: []const u8) TileData {
        var data = self;
        data.action_id = action_id;
        return data;
    }
};

/// Watch session manager
pub const WatchSession = struct {
    allocator: Allocator,
    state: SessionState,
    watch_info: ?WatchInfo,
    messages: std.ArrayListUnmanaged(WatchMessage),
    file_transfers: std.ArrayListUnmanaged(FileTransfer),
    callbacks: std.ArrayListUnmanaged(WatchCallback),
    next_message_id: u64,
    next_transfer_id: u64,
    is_activated: bool,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .state = SessionState.init(),
            .watch_info = null,
            .messages = .{},
            .file_transfers = .{},
            .callbacks = .{},
            .next_message_id = 1,
            .next_transfer_id = 1,
            .is_activated = false,
        };
    }

    pub fn deinit(self: *Self) void {
        self.messages.deinit(self.allocator);
        self.file_transfers.deinit(self.allocator);
        self.callbacks.deinit(self.allocator);
    }

    /// Activate the session
    pub fn activate(self: *Self) void {
        self.is_activated = true;
        self.notifyCallbacks(WatchEvent.create(.session_activated));
    }

    /// Deactivate the session
    pub fn deactivate(self: *Self) void {
        self.is_activated = false;
        self.notifyCallbacks(WatchEvent.create(.session_deactivated));
    }

    /// Check if session is activated
    pub fn isActivated(self: Self) bool {
        return self.is_activated;
    }

    /// Add event callback
    pub fn addCallback(self: *Self, callback: WatchCallback) !void {
        try self.callbacks.append(self.allocator, callback);
    }

    /// Remove event callback
    pub fn removeCallback(self: *Self, callback: WatchCallback) bool {
        for (self.callbacks.items, 0..) |cb, i| {
            if (cb == callback) {
                _ = self.callbacks.orderedRemove(i);
                return true;
            }
        }
        return false;
    }

    /// Update connectivity state
    pub fn updateConnectivity(self: *Self, connectivity: ConnectivityState) void {
        self.state.connectivity = connectivity;
        self.notifyCallbacks(WatchEvent.create(.connectivity_changed));
    }

    /// Update reachability state
    pub fn updateReachability(self: *Self, reachability: ReachabilityState) void {
        self.state.reachability = reachability;
        self.notifyCallbacks(WatchEvent.create(.reachability_changed));
    }

    /// Update watch app state
    pub fn updateWatchAppState(self: *Self, app_state: WatchAppState) void {
        self.state.watch_app_state = app_state;
        self.notifyCallbacks(WatchEvent.create(.watch_state_changed));
    }

    /// Set watch info
    pub fn setWatchInfo(self: *Self, info: WatchInfo) void {
        self.watch_info = info;
    }

    /// Get current state
    pub fn getState(self: Self) SessionState {
        return self.state;
    }

    /// Check if can send message
    pub fn canSendMessage(self: Self) bool {
        return self.is_activated and self.state.canSendMessage();
    }

    /// Send a message
    pub fn sendMessage(self: *Self, transfer_type: TransferType, priority: MessagePriority) !WatchMessage {
        if (!self.canSendMessage() and transfer_type.requiresReachability()) {
            return error.NotReachable;
        }

        var msg = WatchMessage.create(self.next_message_id, transfer_type);
        msg.priority = priority;
        msg.status = .transferring;

        try self.messages.append(self.allocator, msg);
        self.next_message_id += 1;
        self.state.outstanding_transfers += 1;

        self.notifyCallbacks(WatchEvent.forMessage(.message_sent, msg.id));

        return msg;
    }

    /// Get message by ID
    pub fn getMessage(self: Self, message_id: u64) ?WatchMessage {
        for (self.messages.items) |msg| {
            if (msg.id == message_id) {
                return msg;
            }
        }
        return null;
    }

    /// Complete a message
    pub fn completeMessage(self: *Self, message_id: u64, success: bool) bool {
        for (self.messages.items) |*msg| {
            if (msg.id == message_id and !msg.status.isComplete()) {
                msg.status = if (success) .completed else .failed;
                if (self.state.outstanding_transfers > 0) {
                    self.state.outstanding_transfers -= 1;
                }
                const event_type: WatchEventType = if (success) .message_sent else .message_failed;
                self.notifyCallbacks(WatchEvent.forMessage(event_type, message_id));
                return true;
            }
        }
        return false;
    }

    /// Start file transfer
    pub fn startFileTransfer(self: *Self, file_name: []const u8, file_size: u64) !FileTransfer {
        if (!self.state.canTransferUserInfo()) {
            return error.NotPaired;
        }

        const transfer = FileTransfer{
            .id = self.next_transfer_id,
            .file_name = file_name,
            .file_size = file_size,
            .bytes_transferred = 0,
            .status = .pending,
            .metadata = null,
            .timestamp = getCurrentTimestamp(),
        };

        try self.file_transfers.append(self.allocator, transfer);
        self.next_transfer_id += 1;

        self.notifyCallbacks(WatchEvent.forTransfer(.file_transfer_started, transfer.id));

        return transfer;
    }

    /// Update file transfer progress
    pub fn updateTransferProgress(self: *Self, transfer_id: u64, bytes_transferred: u64) bool {
        for (self.file_transfers.items) |*transfer| {
            if (transfer.id == transfer_id) {
                transfer.bytes_transferred = bytes_transferred;
                transfer.status = .transferring;
                self.notifyCallbacks(WatchEvent.forTransfer(.file_transfer_progress, transfer_id));
                return true;
            }
        }
        return false;
    }

    /// Complete file transfer
    pub fn completeTransfer(self: *Self, transfer_id: u64, success: bool) bool {
        for (self.file_transfers.items) |*transfer| {
            if (transfer.id == transfer_id) {
                transfer.status = if (success) .completed else .failed;
                const event_type: WatchEventType = if (success) .file_transfer_completed else .file_transfer_failed;
                self.notifyCallbacks(WatchEvent.forTransfer(event_type, transfer_id));
                return true;
            }
        }
        return false;
    }

    /// Get file transfer by ID
    pub fn getTransfer(self: Self, transfer_id: u64) ?FileTransfer {
        for (self.file_transfers.items) |transfer| {
            if (transfer.id == transfer_id) {
                return transfer;
            }
        }
        return null;
    }

    /// Get pending transfers count
    pub fn getPendingTransfersCount(self: Self) usize {
        var count: usize = 0;
        for (self.file_transfers.items) |transfer| {
            if (transfer.status.isInProgress()) {
                count += 1;
            }
        }
        return count;
    }

    fn notifyCallbacks(self: *Self, event: WatchEvent) void {
        for (self.callbacks.items) |callback| {
            callback(event);
        }
    }
};

/// Complication manager for Apple Watch
pub const ComplicationManager = struct {
    allocator: Allocator,
    active_complications: std.ArrayListUnmanaged(ComplicationData),
    supported_families: []const ComplicationFamily,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .active_complications = .{},
            .supported_families = &[_]ComplicationFamily{
                .modular_small,
                .modular_large,
                .circular_small,
                .graphic_circular,
                .graphic_rectangular,
            },
        };
    }

    pub fn deinit(self: *Self) void {
        self.active_complications.deinit(self.allocator);
    }

    /// Check if family is supported
    pub fn isSupported(self: Self, family: ComplicationFamily) bool {
        for (self.supported_families) |f| {
            if (f == family) return true;
        }
        return false;
    }

    /// Update complication
    pub fn updateComplication(self: *Self, data: ComplicationData) !void {
        // Check if we already have this family
        for (self.active_complications.items, 0..) |_, i| {
            if (self.active_complications.items[i].family == data.family) {
                self.active_complications.items[i] = data;
                return;
            }
        }
        // Add new complication
        try self.active_complications.append(self.allocator, data);
    }

    /// Get complication for family
    pub fn getComplication(self: Self, family: ComplicationFamily) ?ComplicationData {
        for (self.active_complications.items) |comp| {
            if (comp.family == family) {
                return comp;
            }
        }
        return null;
    }

    /// Get active complication count
    pub fn getActiveCount(self: Self) usize {
        return self.active_complications.items.len;
    }
};

/// Tile manager for Wear OS
pub const TileManager = struct {
    allocator: Allocator,
    tiles: std.ArrayListUnmanaged(TileData),
    max_tiles: u32,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .tiles = .{},
            .max_tiles = 5,
        };
    }

    pub fn deinit(self: *Self) void {
        self.tiles.deinit(self.allocator);
    }

    /// Add a tile
    pub fn addTile(self: *Self, tile: TileData) !void {
        if (self.tiles.items.len >= self.max_tiles) {
            return error.MaxTilesReached;
        }
        try self.tiles.append(self.allocator, tile);
    }

    /// Get tile count
    pub fn getTileCount(self: Self) usize {
        return self.tiles.items.len;
    }

    /// Get tile by index
    pub fn getTile(self: Self, index: usize) ?TileData {
        if (index < self.tiles.items.len) {
            return self.tiles.items[index];
        }
        return null;
    }

    /// Remove tile by index
    pub fn removeTile(self: *Self, index: usize) bool {
        if (index < self.tiles.items.len) {
            _ = self.tiles.orderedRemove(index);
            return true;
        }
        return false;
    }
};

/// Get current timestamp in milliseconds
fn getCurrentTimestamp() i64 {
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
        return @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000);
    }
    return 0;
}

// ============================================================================
// Tests
// ============================================================================

test "WatchPlatform toString" {
    try std.testing.expectEqualStrings("Apple Watch", WatchPlatform.apple_watch.toString());
    try std.testing.expectEqualStrings("Wear OS", WatchPlatform.wear_os.toString());
}

test "WatchPlatform supportsCompanionApp" {
    try std.testing.expect(WatchPlatform.apple_watch.supportsCompanionApp());
    try std.testing.expect(WatchPlatform.wear_os.supportsCompanionApp());
    try std.testing.expect(!WatchPlatform.garmin.supportsCompanionApp());
}

test "ConnectivityState properties" {
    try std.testing.expect(!ConnectivityState.not_paired.isPaired());
    try std.testing.expect(ConnectivityState.paired_active.isPaired());
    try std.testing.expect(ConnectivityState.paired_active.isReachable());
    try std.testing.expect(!ConnectivityState.paired_inactive.isReachable());
}

test "ComplicationFamily maxTextLength" {
    try std.testing.expectEqual(@as(u32, 3), ComplicationFamily.modular_small.maxTextLength());
    try std.testing.expectEqual(@as(u32, 20), ComplicationFamily.modular_large.maxTextLength());
    try std.testing.expectEqual(@as(u32, 50), ComplicationFamily.graphic_rectangular.maxTextLength());
}

test "WatchAppState properties" {
    try std.testing.expect(!WatchAppState.not_installed.isInstalled());
    try std.testing.expect(WatchAppState.installed.isInstalled());
    try std.testing.expect(WatchAppState.running_foreground.isRunning());
    try std.testing.expect(!WatchAppState.suspended.isRunning());
}

test "TransferType properties" {
    try std.testing.expect(TransferType.message.isRealtime());
    try std.testing.expect(!TransferType.user_info.isRealtime());
    try std.testing.expect(TransferType.message.requiresReachability());
    try std.testing.expect(!TransferType.application_context.requiresReachability());
}

test "TransferStatus properties" {
    try std.testing.expect(!TransferStatus.pending.isComplete());
    try std.testing.expect(TransferStatus.completed.isComplete());
    try std.testing.expect(TransferStatus.failed.isComplete());
    try std.testing.expect(TransferStatus.pending.isInProgress());
    try std.testing.expect(!TransferStatus.completed.isInProgress());
}

test "WatchMessage create" {
    const msg = WatchMessage.create(1, .message);
    try std.testing.expectEqual(@as(u64, 1), msg.id);
    try std.testing.expectEqual(TransferType.message, msg.transfer_type);
    try std.testing.expectEqual(MessagePriority.normal, msg.priority);
    try std.testing.expectEqual(TransferStatus.pending, msg.status);
}

test "WatchMessage fluent API" {
    const msg = WatchMessage.create(1, .message)
        .withPriority(.high)
        .expectingReply();

    try std.testing.expectEqual(MessagePriority.high, msg.priority);
    try std.testing.expect(msg.reply_expected);
}

test "FileTransfer progress" {
    const transfer = FileTransfer{
        .id = 1,
        .file_name = "test.dat",
        .file_size = 1000,
        .bytes_transferred = 500,
        .status = .transferring,
        .metadata = null,
        .timestamp = 0,
    };

    try std.testing.expectApproxEqAbs(@as(f32, 0.5), transfer.getProgress(), 0.01);
    try std.testing.expectEqual(@as(u8, 50), transfer.getProgressPercent());
    try std.testing.expectEqual(@as(u64, 500), transfer.getRemainingBytes());
}

test "WatchInfo battery" {
    const info = WatchInfo{
        .name = "My Watch",
        .model = "Series 9",
        .platform = .apple_watch,
        .os_version = "10.0",
        .app_version = "1.0",
        .serial_number = null,
        .battery_level = 15,
        .is_charging = false,
    };

    try std.testing.expect(info.hasBatteryInfo());
    try std.testing.expect(info.isBatteryLow());
}

test "SessionState init" {
    const state = SessionState.init();
    try std.testing.expectEqual(ConnectivityState.not_paired, state.connectivity);
    try std.testing.expectEqual(ReachabilityState.not_reachable, state.reachability);
    try std.testing.expect(!state.canSendMessage());
}

test "SessionState canSendMessage" {
    var state = SessionState.init();
    state.connectivity = .paired_active;
    state.reachability = .reachable;

    try std.testing.expect(state.canSendMessage());
}

test "WatchEvent create" {
    const event = WatchEvent.create(.session_activated);
    try std.testing.expectEqual(WatchEventType.session_activated, event.event_type);
    try std.testing.expect(event.message_id == null);
}

test "WatchEvent forMessage" {
    const event = WatchEvent.forMessage(.message_sent, 42);
    try std.testing.expectEqual(WatchEventType.message_sent, event.event_type);
    try std.testing.expectEqual(@as(u64, 42), event.message_id.?);
}

test "ComplicationData init" {
    const data = ComplicationData.init(.graphic_circular);
    try std.testing.expectEqual(ComplicationFamily.graphic_circular, data.family);
    try std.testing.expect(data.text_primary == null);
}

test "ComplicationData fluent API" {
    const data = ComplicationData.init(.modular_large)
        .withText("75%")
        .withSecondaryText("Battery")
        .withValue(0.75, 0, 1);

    try std.testing.expectEqualStrings("75%", data.text_primary.?);
    try std.testing.expectEqualStrings("Battery", data.text_secondary.?);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), data.value.?, 0.01);
}

test "ComplicationData getNormalizedValue" {
    const data = ComplicationData.init(.graphic_circular)
        .withValue(50, 0, 100);

    const normalized = data.getNormalizedValue();
    try std.testing.expect(normalized != null);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), normalized.?, 0.01);
}

test "TileData init" {
    const tile = TileData.init(.progress);
    try std.testing.expectEqual(TileTemplate.progress, tile.template);
    try std.testing.expectEqual(@as(u64, 60000), tile.refresh_interval_ms);
}

test "TileData fluent API" {
    const tile = TileData.init(.stat)
        .withTitle("Steps")
        .withSubtitle("Today")
        .withProgress(0.65);

    try std.testing.expectEqualStrings("Steps", tile.title.?);
    try std.testing.expectEqualStrings("Today", tile.subtitle.?);
    try std.testing.expectApproxEqAbs(@as(f32, 0.65), tile.progress_value.?, 0.01);
}

test "WatchSession init and deinit" {
    const allocator = std.testing.allocator;
    var session = WatchSession.init(allocator);
    defer session.deinit();

    try std.testing.expect(!session.isActivated());
    try std.testing.expect(!session.canSendMessage());
}

test "WatchSession activate" {
    const allocator = std.testing.allocator;
    var session = WatchSession.init(allocator);
    defer session.deinit();

    session.activate();
    try std.testing.expect(session.isActivated());

    session.deactivate();
    try std.testing.expect(!session.isActivated());
}

test "WatchSession updateConnectivity" {
    const allocator = std.testing.allocator;
    var session = WatchSession.init(allocator);
    defer session.deinit();

    session.updateConnectivity(.paired_active);
    try std.testing.expectEqual(ConnectivityState.paired_active, session.getState().connectivity);
}

test "WatchSession sendMessage" {
    const allocator = std.testing.allocator;
    var session = WatchSession.init(allocator);
    defer session.deinit();

    session.activate();
    session.updateConnectivity(.paired_active);
    session.updateReachability(.reachable);

    const msg = try session.sendMessage(.message, .normal);
    try std.testing.expectEqual(@as(u64, 1), msg.id);
    try std.testing.expectEqual(@as(u32, 1), session.getState().outstanding_transfers);
}

test "WatchSession completeMessage" {
    const allocator = std.testing.allocator;
    var session = WatchSession.init(allocator);
    defer session.deinit();

    session.activate();
    session.updateConnectivity(.paired_active);
    session.updateReachability(.reachable);

    const msg = try session.sendMessage(.message, .normal);
    try std.testing.expect(session.completeMessage(msg.id, true));
    try std.testing.expectEqual(@as(u32, 0), session.getState().outstanding_transfers);
}

test "ComplicationManager init and deinit" {
    const allocator = std.testing.allocator;
    var manager = ComplicationManager.init(allocator);
    defer manager.deinit();

    try std.testing.expect(manager.isSupported(.modular_small));
    try std.testing.expectEqual(@as(usize, 0), manager.getActiveCount());
}

test "ComplicationManager updateComplication" {
    const allocator = std.testing.allocator;
    var manager = ComplicationManager.init(allocator);
    defer manager.deinit();

    const data = ComplicationData.init(.graphic_circular).withText("Test");
    try manager.updateComplication(data);

    try std.testing.expectEqual(@as(usize, 1), manager.getActiveCount());

    const retrieved = manager.getComplication(.graphic_circular);
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualStrings("Test", retrieved.?.text_primary.?);
}

test "TileManager init and deinit" {
    const allocator = std.testing.allocator;
    var manager = TileManager.init(allocator);
    defer manager.deinit();

    try std.testing.expectEqual(@as(usize, 0), manager.getTileCount());
}

test "TileManager addTile" {
    const allocator = std.testing.allocator;
    var manager = TileManager.init(allocator);
    defer manager.deinit();

    const tile = TileData.init(.stat).withTitle("Test");
    try manager.addTile(tile);

    try std.testing.expectEqual(@as(usize, 1), manager.getTileCount());

    const retrieved = manager.getTile(0);
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualStrings("Test", retrieved.?.title.?);
}

test "TileManager removeTile" {
    const allocator = std.testing.allocator;
    var manager = TileManager.init(allocator);
    defer manager.deinit();

    try manager.addTile(TileData.init(.stat));
    try std.testing.expect(manager.removeTile(0));
    try std.testing.expectEqual(@as(usize, 0), manager.getTileCount());
}

test "MessagePriority toString" {
    try std.testing.expectEqualStrings("Low", MessagePriority.low.toString());
    try std.testing.expectEqualStrings("High", MessagePriority.high.toString());
}

test "TileTemplate toString" {
    try std.testing.expectEqualStrings("Single Slot", TileTemplate.single_slot.toString());
    try std.testing.expectEqualStrings("Progress", TileTemplate.progress.toString());
}
