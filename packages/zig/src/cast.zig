//! Media casting support for Craft
//! Provides cross-platform abstractions for Chromecast, AirPlay, DLNA, and Miracast.
//! Covers device discovery, media streaming, and screen mirroring.

const std = @import("std");

/// Cast protocol types
pub const CastProtocol = enum {
    chromecast,
    airplay,
    dlna,
    miracast,
    fire_tv,
    roku,
    webos,
    unknown,

    pub fn toString(self: CastProtocol) []const u8 {
        return switch (self) {
            .chromecast => "Chromecast",
            .airplay => "AirPlay",
            .dlna => "DLNA",
            .miracast => "Miracast",
            .fire_tv => "Fire TV",
            .roku => "Roku",
            .webos => "webOS",
            .unknown => "Unknown",
        };
    }

    pub fn supportsAudio(self: CastProtocol) bool {
        return self != .unknown;
    }

    pub fn supportsVideo(self: CastProtocol) bool {
        return self != .unknown;
    }

    pub fn supportsScreenMirroring(self: CastProtocol) bool {
        return switch (self) {
            .airplay, .miracast, .chromecast => true,
            else => false,
        };
    }

    pub fn supportsPhotos(self: CastProtocol) bool {
        return switch (self) {
            .chromecast, .airplay, .dlna => true,
            else => false,
        };
    }

    pub fn defaultPort(self: CastProtocol) u16 {
        return switch (self) {
            .chromecast => 8008,
            .airplay => 7000,
            .dlna => 1900,
            .miracast => 7236,
            .fire_tv => 8008,
            .roku => 8060,
            .webos => 3000,
            .unknown => 0,
        };
    }
};

/// Cast device type
pub const CastDeviceType = enum {
    speaker,
    display,
    tv,
    soundbar,
    group,
    dongle,
    unknown,

    pub fn toString(self: CastDeviceType) []const u8 {
        return switch (self) {
            .speaker => "Speaker",
            .display => "Display",
            .tv => "Smart TV",
            .soundbar => "Soundbar",
            .group => "Speaker Group",
            .dongle => "Streaming Dongle",
            .unknown => "Unknown",
        };
    }

    pub fn hasDisplay(self: CastDeviceType) bool {
        return switch (self) {
            .display, .tv, .dongle => true,
            else => false,
        };
    }

    pub fn hasAudio(self: CastDeviceType) bool {
        return self != .unknown;
    }
};

/// Cast device capabilities
pub const DeviceCapabilities = struct {
    supports_audio: bool,
    supports_video: bool,
    supports_photos: bool,
    supports_mirroring: bool,
    max_resolution: u32,
    supports_4k: bool,
    supports_hdr: bool,

    pub const audio_only = DeviceCapabilities{
        .supports_audio = true,
        .supports_video = false,
        .supports_photos = false,
        .supports_mirroring = false,
        .max_resolution = 0,
        .supports_4k = false,
        .supports_hdr = false,
    };

    pub const full_media = DeviceCapabilities{
        .supports_audio = true,
        .supports_video = true,
        .supports_photos = true,
        .supports_mirroring = true,
        .max_resolution = 3840,
        .supports_4k = true,
        .supports_hdr = true,
    };

    pub const standard_video = DeviceCapabilities{
        .supports_audio = true,
        .supports_video = true,
        .supports_photos = true,
        .supports_mirroring = false,
        .max_resolution = 1920,
        .supports_4k = false,
        .supports_hdr = false,
    };

    pub fn canPlayMedia(self: DeviceCapabilities) bool {
        return self.supports_audio or self.supports_video;
    }
};

/// Cast device connection state
pub const ConnectionState = enum {
    disconnected,
    connecting,
    connected,
    disconnecting,
    failed,

    pub fn isConnected(self: ConnectionState) bool {
        return self == .connected;
    }

    pub fn isTransitioning(self: ConnectionState) bool {
        return self == .connecting or self == .disconnecting;
    }

    pub fn toString(self: ConnectionState) []const u8 {
        return switch (self) {
            .disconnected => "Disconnected",
            .connecting => "Connecting",
            .connected => "Connected",
            .disconnecting => "Disconnecting",
            .failed => "Failed",
        };
    }
};

/// Cast device information
pub const CastDevice = struct {
    device_id: []const u8,
    name: []const u8,
    protocol: CastProtocol,
    device_type: CastDeviceType,
    ip_address: []const u8,
    port: u16,
    capabilities: DeviceCapabilities,
    connection_state: ConnectionState,
    volume: f32,
    is_muted: bool,

    pub fn init(device_id: []const u8, name: []const u8, protocol: CastProtocol) CastDevice {
        return .{
            .device_id = device_id,
            .name = name,
            .protocol = protocol,
            .device_type = .unknown,
            .ip_address = "",
            .port = protocol.defaultPort(),
            .capabilities = DeviceCapabilities.standard_video,
            .connection_state = .disconnected,
            .volume = 1.0,
            .is_muted = false,
        };
    }

    pub fn withDeviceType(self: CastDevice, device_type: CastDeviceType) CastDevice {
        var device = self;
        device.device_type = device_type;
        return device;
    }

    pub fn withAddress(self: CastDevice, ip: []const u8, port: u16) CastDevice {
        var device = self;
        device.ip_address = ip;
        device.port = port;
        return device;
    }

    pub fn withCapabilities(self: CastDevice, capabilities: DeviceCapabilities) CastDevice {
        var device = self;
        device.capabilities = capabilities;
        return device;
    }

    pub fn connect(self: *CastDevice) void {
        self.connection_state = .connecting;
    }

    pub fn onConnected(self: *CastDevice) void {
        self.connection_state = .connected;
    }

    pub fn onConnectionFailed(self: *CastDevice) void {
        self.connection_state = .failed;
    }

    pub fn disconnect(self: *CastDevice) void {
        self.connection_state = .disconnecting;
    }

    pub fn onDisconnected(self: *CastDevice) void {
        self.connection_state = .disconnected;
    }

    pub fn setVolume(self: *CastDevice, volume: f32) void {
        self.volume = @min(1.0, @max(0.0, volume));
    }

    pub fn setMuted(self: *CastDevice, muted: bool) void {
        self.is_muted = muted;
    }

    pub fn toggleMute(self: *CastDevice) void {
        self.is_muted = !self.is_muted;
    }

    pub fn isConnected(self: CastDevice) bool {
        return self.connection_state.isConnected();
    }

    pub fn effectiveVolume(self: CastDevice) f32 {
        if (self.is_muted) return 0;
        return self.volume;
    }
};

/// Media type for casting
pub const MediaType = enum {
    audio,
    video,
    photo,
    screen_mirror,
    live_stream,

    pub fn toString(self: MediaType) []const u8 {
        return switch (self) {
            .audio => "Audio",
            .video => "Video",
            .photo => "Photo",
            .screen_mirror => "Screen Mirror",
            .live_stream => "Live Stream",
        };
    }

    pub fn isStreaming(self: MediaType) bool {
        return self == .live_stream or self == .screen_mirror;
    }

    pub fn supportsSeeking(self: MediaType) bool {
        return self == .audio or self == .video;
    }
};

/// Playback state
pub const PlaybackState = enum {
    idle,
    loading,
    buffering,
    playing,
    paused,
    stopped,
    error_state,

    pub fn isActive(self: PlaybackState) bool {
        return self == .playing or self == .paused or self == .buffering;
    }

    pub fn isPlaying(self: PlaybackState) bool {
        return self == .playing;
    }

    pub fn canPlay(self: PlaybackState) bool {
        return self == .paused or self == .stopped;
    }

    pub fn canPause(self: PlaybackState) bool {
        return self == .playing;
    }

    pub fn toString(self: PlaybackState) []const u8 {
        return switch (self) {
            .idle => "Idle",
            .loading => "Loading",
            .buffering => "Buffering",
            .playing => "Playing",
            .paused => "Paused",
            .stopped => "Stopped",
            .error_state => "Error",
        };
    }
};

/// Media metadata
pub const MediaMetadata = struct {
    title: []const u8,
    subtitle: ?[]const u8,
    artist: ?[]const u8,
    album: ?[]const u8,
    artwork_url: ?[]const u8,
    duration_ms: u64,
    media_type: MediaType,

    pub fn init(title: []const u8, media_type: MediaType) MediaMetadata {
        return .{
            .title = title,
            .subtitle = null,
            .artist = null,
            .album = null,
            .artwork_url = null,
            .duration_ms = 0,
            .media_type = media_type,
        };
    }

    pub fn withSubtitle(self: MediaMetadata, subtitle: []const u8) MediaMetadata {
        var meta = self;
        meta.subtitle = subtitle;
        return meta;
    }

    pub fn withArtist(self: MediaMetadata, artist: []const u8) MediaMetadata {
        var meta = self;
        meta.artist = artist;
        return meta;
    }

    pub fn withAlbum(self: MediaMetadata, album: []const u8) MediaMetadata {
        var meta = self;
        meta.album = album;
        return meta;
    }

    pub fn withArtwork(self: MediaMetadata, url: []const u8) MediaMetadata {
        var meta = self;
        meta.artwork_url = url;
        return meta;
    }

    pub fn withDuration(self: MediaMetadata, duration_ms: u64) MediaMetadata {
        var meta = self;
        meta.duration_ms = duration_ms;
        return meta;
    }

    pub fn hasDuration(self: MediaMetadata) bool {
        return self.duration_ms > 0;
    }

    pub fn durationSeconds(self: MediaMetadata) f64 {
        return @as(f64, @floatFromInt(self.duration_ms)) / 1000.0;
    }
};

/// Cast session representing active media streaming
pub const CastSession = struct {
    session_id: []const u8,
    device: CastDevice,
    metadata: ?MediaMetadata,
    playback_state: PlaybackState,
    position_ms: u64,
    playback_rate: f32,
    started_at: u64,

    pub fn init(session_id: []const u8, device: CastDevice) CastSession {
        return .{
            .session_id = session_id,
            .device = device,
            .metadata = null,
            .playback_state = .idle,
            .position_ms = 0,
            .playback_rate = 1.0,
            .started_at = getCurrentTimestamp(),
        };
    }

    pub fn loadMedia(self: *CastSession, metadata: MediaMetadata) void {
        self.metadata = metadata;
        self.playback_state = .loading;
        self.position_ms = 0;
    }

    pub fn play(self: *CastSession) void {
        if (self.playback_state.canPlay() or self.playback_state == .loading) {
            self.playback_state = .playing;
        }
    }

    pub fn pause(self: *CastSession) void {
        if (self.playback_state.canPause()) {
            self.playback_state = .paused;
        }
    }

    pub fn stop(self: *CastSession) void {
        self.playback_state = .stopped;
        self.position_ms = 0;
    }

    pub fn seek(self: *CastSession, position_ms: u64) void {
        if (self.metadata) |meta| {
            if (meta.media_type.supportsSeeking()) {
                self.position_ms = @min(position_ms, meta.duration_ms);
            }
        }
    }

    pub fn setPlaybackRate(self: *CastSession, rate: f32) void {
        self.playback_rate = @min(2.0, @max(0.5, rate));
    }

    pub fn progressPercent(self: CastSession) f32 {
        if (self.metadata) |meta| {
            if (meta.duration_ms == 0) return 0;
            return @as(f32, @floatFromInt(self.position_ms)) / @as(f32, @floatFromInt(meta.duration_ms)) * 100.0;
        }
        return 0;
    }

    pub fn remainingMs(self: CastSession) u64 {
        if (self.metadata) |meta| {
            if (self.position_ms >= meta.duration_ms) return 0;
            return meta.duration_ms - self.position_ms;
        }
        return 0;
    }

    pub fn isPlaying(self: CastSession) bool {
        return self.playback_state.isPlaying();
    }

    pub fn hasMedia(self: CastSession) bool {
        return self.metadata != null;
    }
};

/// Queue item for media queue
pub const QueueItem = struct {
    item_id: u32,
    metadata: MediaMetadata,
    autoplay: bool,
    preload_time_ms: u64,

    pub fn init(item_id: u32, metadata: MediaMetadata) QueueItem {
        return .{
            .item_id = item_id,
            .metadata = metadata,
            .autoplay = true,
            .preload_time_ms = 20000, // 20 seconds
        };
    }

    pub fn withAutoplay(self: QueueItem, autoplay: bool) QueueItem {
        var item = self;
        item.autoplay = autoplay;
        return item;
    }

    pub fn withPreloadTime(self: QueueItem, preload_ms: u64) QueueItem {
        var item = self;
        item.preload_time_ms = preload_ms;
        return item;
    }
};

/// Repeat mode for queue
pub const RepeatMode = enum {
    off,
    one,
    all,
    shuffle,

    pub fn toString(self: RepeatMode) []const u8 {
        return switch (self) {
            .off => "Off",
            .one => "Repeat One",
            .all => "Repeat All",
            .shuffle => "Shuffle",
        };
    }

    pub fn next(self: RepeatMode) RepeatMode {
        return switch (self) {
            .off => .one,
            .one => .all,
            .all => .shuffle,
            .shuffle => .off,
        };
    }
};

/// Media queue for sequential playback
pub const MediaQueue = struct {
    item_count: u32,
    current_index: u32,
    repeat_mode: RepeatMode,
    shuffle_enabled: bool,

    pub fn init() MediaQueue {
        return .{
            .item_count = 0,
            .current_index = 0,
            .repeat_mode = .off,
            .shuffle_enabled = false,
        };
    }

    pub fn setItemCount(self: *MediaQueue, count: u32) void {
        self.item_count = count;
        if (self.current_index >= count and count > 0) {
            self.current_index = count - 1;
        }
    }

    pub fn nextItem(self: *MediaQueue) bool {
        if (self.item_count == 0) return false;

        if (self.current_index < self.item_count - 1) {
            self.current_index += 1;
            return true;
        } else if (self.repeat_mode == .all) {
            self.current_index = 0;
            return true;
        }
        return false;
    }

    pub fn previousItem(self: *MediaQueue) bool {
        if (self.item_count == 0) return false;

        if (self.current_index > 0) {
            self.current_index -= 1;
            return true;
        } else if (self.repeat_mode == .all) {
            self.current_index = self.item_count - 1;
            return true;
        }
        return false;
    }

    pub fn jumpTo(self: *MediaQueue, index: u32) bool {
        if (index < self.item_count) {
            self.current_index = index;
            return true;
        }
        return false;
    }

    pub fn setRepeatMode(self: *MediaQueue, mode: RepeatMode) void {
        self.repeat_mode = mode;
        self.shuffle_enabled = (mode == .shuffle);
    }

    pub fn toggleShuffle(self: *MediaQueue) void {
        self.shuffle_enabled = !self.shuffle_enabled;
    }

    pub fn hasNext(self: MediaQueue) bool {
        return self.current_index < self.item_count - 1 or self.repeat_mode == .all;
    }

    pub fn hasPrevious(self: MediaQueue) bool {
        return self.current_index > 0 or self.repeat_mode == .all;
    }

    pub fn isEmpty(self: MediaQueue) bool {
        return self.item_count == 0;
    }
};

/// Discovery state
pub const DiscoveryState = enum {
    idle,
    scanning,
    found_devices,
    stopped,
    error_state,

    pub fn isScanning(self: DiscoveryState) bool {
        return self == .scanning;
    }

    pub fn toString(self: DiscoveryState) []const u8 {
        return switch (self) {
            .idle => "Idle",
            .scanning => "Scanning",
            .found_devices => "Found Devices",
            .stopped => "Stopped",
            .error_state => "Error",
        };
    }
};

/// Cast controller for managing discovery and sessions
pub const CastController = struct {
    discovery_state: DiscoveryState,
    device_count: u32,
    current_session: ?CastSession,
    supported_protocols: u8, // bitmask

    pub fn init() CastController {
        return .{
            .discovery_state = .idle,
            .device_count = 0,
            .current_session = null,
            .supported_protocols = 0xFF, // all protocols
        };
    }

    pub fn startDiscovery(self: *CastController) void {
        self.discovery_state = .scanning;
    }

    pub fn stopDiscovery(self: *CastController) void {
        self.discovery_state = .stopped;
    }

    pub fn onDevicesFound(self: *CastController, count: u32) void {
        self.device_count = count;
        if (count > 0) {
            self.discovery_state = .found_devices;
        }
    }

    pub fn startSession(self: *CastController, session: CastSession) void {
        self.current_session = session;
    }

    pub fn endSession(self: *CastController) void {
        self.current_session = null;
    }

    pub fn hasActiveSession(self: CastController) bool {
        return self.current_session != null;
    }

    pub fn isDiscovering(self: CastController) bool {
        return self.discovery_state.isScanning();
    }

    pub fn hasDevices(self: CastController) bool {
        return self.device_count > 0;
    }

    pub fn setProtocolEnabled(self: *CastController, protocol: CastProtocol, enabled: bool) void {
        const bit = @as(u8, 1) << @intFromEnum(protocol);
        if (enabled) {
            self.supported_protocols |= bit;
        } else {
            self.supported_protocols &= ~bit;
        }
    }

    pub fn isProtocolEnabled(self: CastController, protocol: CastProtocol) bool {
        const bit = @as(u8, 1) << @intFromEnum(protocol);
        return (self.supported_protocols & bit) != 0;
    }
};

/// Get current timestamp in milliseconds
fn getCurrentTimestamp() u64 {
    const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
    const ms = @divTrunc(ts.nsec, 1_000_000);
    return @intCast(@as(i128, ts.sec) * 1000 + ms);
}

/// Check if casting is supported
pub fn isCastingSupported() bool {
    return true; // Most platforms support some form of casting
}

// ============================================================================
// Tests
// ============================================================================

test "CastProtocol properties" {
    try std.testing.expect(CastProtocol.chromecast.supportsAudio());
    try std.testing.expect(CastProtocol.chromecast.supportsVideo());
    try std.testing.expect(CastProtocol.airplay.supportsScreenMirroring());
    try std.testing.expect(!CastProtocol.roku.supportsScreenMirroring());
    try std.testing.expect(CastProtocol.dlna.supportsPhotos());
}

test "CastProtocol ports" {
    try std.testing.expectEqual(@as(u16, 8008), CastProtocol.chromecast.defaultPort());
    try std.testing.expectEqual(@as(u16, 7000), CastProtocol.airplay.defaultPort());
    try std.testing.expectEqual(@as(u16, 1900), CastProtocol.dlna.defaultPort());
}

test "CastProtocol toString" {
    try std.testing.expectEqualStrings("Chromecast", CastProtocol.chromecast.toString());
    try std.testing.expectEqualStrings("AirPlay", CastProtocol.airplay.toString());
}

test "CastDeviceType properties" {
    try std.testing.expect(CastDeviceType.tv.hasDisplay());
    try std.testing.expect(CastDeviceType.display.hasDisplay());
    try std.testing.expect(!CastDeviceType.speaker.hasDisplay());
    try std.testing.expect(CastDeviceType.soundbar.hasAudio());
}

test "DeviceCapabilities presets" {
    const audio = DeviceCapabilities.audio_only;
    try std.testing.expect(audio.supports_audio);
    try std.testing.expect(!audio.supports_video);
    try std.testing.expect(!audio.supports_mirroring);

    const full = DeviceCapabilities.full_media;
    try std.testing.expect(full.supports_4k);
    try std.testing.expect(full.supports_hdr);
    try std.testing.expect(full.canPlayMedia());
}

test "ConnectionState properties" {
    try std.testing.expect(ConnectionState.connected.isConnected());
    try std.testing.expect(!ConnectionState.disconnected.isConnected());
    try std.testing.expect(ConnectionState.connecting.isTransitioning());
    try std.testing.expect(ConnectionState.disconnecting.isTransitioning());
}

test "CastDevice creation" {
    const device = CastDevice.init("dev123", "Living Room TV", .chromecast)
        .withDeviceType(.tv)
        .withAddress("192.168.1.100", 8008);

    try std.testing.expectEqualStrings("dev123", device.device_id);
    try std.testing.expectEqualStrings("Living Room TV", device.name);
    try std.testing.expectEqual(CastProtocol.chromecast, device.protocol);
    try std.testing.expectEqualStrings("192.168.1.100", device.ip_address);
}

test "CastDevice connection" {
    var device = CastDevice.init("dev456", "Speaker", .airplay);

    try std.testing.expect(!device.isConnected());

    device.connect();
    try std.testing.expectEqual(ConnectionState.connecting, device.connection_state);

    device.onConnected();
    try std.testing.expect(device.isConnected());

    device.disconnect();
    device.onDisconnected();
    try std.testing.expect(!device.isConnected());
}

test "CastDevice volume" {
    var device = CastDevice.init("dev789", "TV", .chromecast);

    device.setVolume(0.5);
    try std.testing.expect(device.volume > 0.49 and device.volume < 0.51);
    try std.testing.expect(device.effectiveVolume() > 0.49);

    device.setMuted(true);
    try std.testing.expect(device.effectiveVolume() == 0);

    device.toggleMute();
    try std.testing.expect(!device.is_muted);
}

test "CastDevice volume clamping" {
    var device = CastDevice.init("dev", "D", .chromecast);

    device.setVolume(1.5);
    try std.testing.expect(device.volume <= 1.0);

    device.setVolume(-0.5);
    try std.testing.expect(device.volume >= 0.0);
}

test "MediaType properties" {
    try std.testing.expect(MediaType.live_stream.isStreaming());
    try std.testing.expect(MediaType.screen_mirror.isStreaming());
    try std.testing.expect(!MediaType.video.isStreaming());
    try std.testing.expect(MediaType.audio.supportsSeeking());
    try std.testing.expect(!MediaType.live_stream.supportsSeeking());
}

test "PlaybackState properties" {
    try std.testing.expect(PlaybackState.playing.isActive());
    try std.testing.expect(PlaybackState.paused.isActive());
    try std.testing.expect(!PlaybackState.idle.isActive());
    try std.testing.expect(PlaybackState.paused.canPlay());
    try std.testing.expect(PlaybackState.playing.canPause());
}

test "MediaMetadata creation" {
    const meta = MediaMetadata.init("Song Title", .audio)
        .withArtist("Artist Name")
        .withAlbum("Album Name")
        .withDuration(180000);

    try std.testing.expectEqualStrings("Song Title", meta.title);
    try std.testing.expectEqualStrings("Artist Name", meta.artist.?);
    try std.testing.expect(meta.hasDuration());
    try std.testing.expect(meta.durationSeconds() > 179.9);
}

test "CastSession creation" {
    const device = CastDevice.init("dev", "Device", .chromecast);
    const session = CastSession.init("session123", device);

    try std.testing.expectEqualStrings("session123", session.session_id);
    try std.testing.expectEqual(PlaybackState.idle, session.playback_state);
    try std.testing.expect(!session.hasMedia());
}

test "CastSession media loading" {
    const device = CastDevice.init("dev", "Device", .chromecast);
    var session = CastSession.init("sess", device);

    const meta = MediaMetadata.init("Video", .video).withDuration(60000);
    session.loadMedia(meta);

    try std.testing.expect(session.hasMedia());
    try std.testing.expectEqual(PlaybackState.loading, session.playback_state);
}

test "CastSession playback" {
    const device = CastDevice.init("dev", "Device", .chromecast);
    var session = CastSession.init("sess", device);
    const meta = MediaMetadata.init("Video", .video).withDuration(60000);
    session.loadMedia(meta);

    session.play();
    try std.testing.expect(session.isPlaying());

    session.pause();
    try std.testing.expectEqual(PlaybackState.paused, session.playback_state);

    session.play();
    session.stop();
    try std.testing.expectEqual(PlaybackState.stopped, session.playback_state);
}

test "CastSession seeking" {
    const device = CastDevice.init("dev", "Device", .chromecast);
    var session = CastSession.init("sess", device);
    const meta = MediaMetadata.init("Video", .video).withDuration(60000);
    session.loadMedia(meta);

    session.seek(30000);
    try std.testing.expectEqual(@as(u64, 30000), session.position_ms);
    try std.testing.expect(session.progressPercent() > 49.9);
    try std.testing.expectEqual(@as(u64, 30000), session.remainingMs());
}

test "CastSession playback rate" {
    const device = CastDevice.init("dev", "Device", .chromecast);
    var session = CastSession.init("sess", device);

    session.setPlaybackRate(1.5);
    try std.testing.expect(session.playback_rate > 1.49);

    session.setPlaybackRate(3.0);
    try std.testing.expect(session.playback_rate <= 2.0);

    session.setPlaybackRate(0.1);
    try std.testing.expect(session.playback_rate >= 0.5);
}

test "QueueItem creation" {
    const meta = MediaMetadata.init("Track", .audio);
    const item = QueueItem.init(1, meta)
        .withAutoplay(false)
        .withPreloadTime(10000);

    try std.testing.expectEqual(@as(u32, 1), item.item_id);
    try std.testing.expect(!item.autoplay);
    try std.testing.expectEqual(@as(u64, 10000), item.preload_time_ms);
}

test "RepeatMode cycle" {
    try std.testing.expectEqual(RepeatMode.one, RepeatMode.off.next());
    try std.testing.expectEqual(RepeatMode.all, RepeatMode.one.next());
    try std.testing.expectEqual(RepeatMode.shuffle, RepeatMode.all.next());
    try std.testing.expectEqual(RepeatMode.off, RepeatMode.shuffle.next());
}

test "MediaQueue navigation" {
    var queue = MediaQueue.init();
    queue.setItemCount(5);

    try std.testing.expect(queue.nextItem());
    try std.testing.expectEqual(@as(u32, 1), queue.current_index);

    try std.testing.expect(queue.previousItem());
    try std.testing.expectEqual(@as(u32, 0), queue.current_index);

    try std.testing.expect(!queue.previousItem()); // Can't go before 0

    try std.testing.expect(queue.jumpTo(3));
    try std.testing.expectEqual(@as(u32, 3), queue.current_index);
}

test "MediaQueue repeat all" {
    var queue = MediaQueue.init();
    queue.setItemCount(3);
    queue.setRepeatMode(.all);

    queue.current_index = 2;
    try std.testing.expect(queue.nextItem());
    try std.testing.expectEqual(@as(u32, 0), queue.current_index);

    try std.testing.expect(queue.previousItem());
    try std.testing.expectEqual(@as(u32, 2), queue.current_index);
}

test "MediaQueue hasNext/hasPrevious" {
    var queue = MediaQueue.init();
    queue.setItemCount(3);

    try std.testing.expect(queue.hasNext());
    try std.testing.expect(!queue.hasPrevious());

    queue.current_index = 2;
    try std.testing.expect(!queue.hasNext());
    try std.testing.expect(queue.hasPrevious());

    queue.setRepeatMode(.all);
    try std.testing.expect(queue.hasNext());
    try std.testing.expect(queue.hasPrevious());
}

test "DiscoveryState properties" {
    try std.testing.expect(DiscoveryState.scanning.isScanning());
    try std.testing.expect(!DiscoveryState.idle.isScanning());
}

test "CastController discovery" {
    var controller = CastController.init();

    try std.testing.expect(!controller.isDiscovering());

    controller.startDiscovery();
    try std.testing.expect(controller.isDiscovering());

    controller.onDevicesFound(3);
    try std.testing.expect(controller.hasDevices());
    try std.testing.expectEqual(@as(u32, 3), controller.device_count);

    controller.stopDiscovery();
    try std.testing.expect(!controller.isDiscovering());
}

test "CastController session" {
    var controller = CastController.init();
    const device = CastDevice.init("dev", "Device", .chromecast);
    const session = CastSession.init("sess", device);

    try std.testing.expect(!controller.hasActiveSession());

    controller.startSession(session);
    try std.testing.expect(controller.hasActiveSession());

    controller.endSession();
    try std.testing.expect(!controller.hasActiveSession());
}

test "CastController protocols" {
    var controller = CastController.init();

    try std.testing.expect(controller.isProtocolEnabled(.chromecast));
    try std.testing.expect(controller.isProtocolEnabled(.airplay));

    controller.setProtocolEnabled(.chromecast, false);
    try std.testing.expect(!controller.isProtocolEnabled(.chromecast));
    try std.testing.expect(controller.isProtocolEnabled(.airplay));

    controller.setProtocolEnabled(.chromecast, true);
    try std.testing.expect(controller.isProtocolEnabled(.chromecast));
}

test "isCastingSupported" {
    try std.testing.expect(isCastingSupported());
}
