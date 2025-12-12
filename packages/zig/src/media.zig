//! Media Playback Module for Craft Framework
//!
//! Cross-platform media playback and recording providing:
//! - Audio/video playback with controls
//! - Media metadata extraction
//! - Playlist management
//! - Recording capabilities
//! - Streaming support
//!
//! Platform implementations:
//! - iOS: AVFoundation (AVPlayer, AVAudioPlayer)
//! - Android: MediaPlayer, ExoPlayer
//! - macOS: AVFoundation
//! - Windows: Media Foundation
//! - Linux: GStreamer

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// Enums
// ============================================================================

pub const MediaType = enum {
    audio,
    video,
    stream,
    unknown,

    pub fn toString(self: MediaType) []const u8 {
        return switch (self) {
            .audio => "audio",
            .video => "video",
            .stream => "stream",
            .unknown => "unknown",
        };
    }
};

pub const PlaybackState = enum {
    idle,
    loading,
    ready,
    playing,
    paused,
    buffering,
    stopped,
    ended,
    failed,

    pub fn isActive(self: PlaybackState) bool {
        return self == .playing or self == .paused or self == .buffering;
    }

    pub fn canPlay(self: PlaybackState) bool {
        return self == .ready or self == .paused or self == .stopped;
    }

    pub fn toString(self: PlaybackState) []const u8 {
        return switch (self) {
            .idle => "idle",
            .loading => "loading",
            .ready => "ready",
            .playing => "playing",
            .paused => "paused",
            .buffering => "buffering",
            .stopped => "stopped",
            .ended => "ended",
            .failed => "failed",
        };
    }
};

pub const RepeatMode = enum {
    off,
    one,
    all,

    pub fn toString(self: RepeatMode) []const u8 {
        return switch (self) {
            .off => "off",
            .one => "one",
            .all => "all",
        };
    }
};

pub const AudioOutputRoute = enum {
    speaker,
    headphones,
    bluetooth,
    airplay,
    hdmi,
    usb,
    unknown,

    pub fn toString(self: AudioOutputRoute) []const u8 {
        return switch (self) {
            .speaker => "speaker",
            .headphones => "headphones",
            .bluetooth => "bluetooth",
            .airplay => "airplay",
            .hdmi => "hdmi",
            .usb => "usb",
            .unknown => "unknown",
        };
    }
};

pub const RecordingState = enum {
    idle,
    preparing,
    recording,
    paused,
    stopped,
    failed,

    pub fn isRecording(self: RecordingState) bool {
        return self == .recording;
    }

    pub fn toString(self: RecordingState) []const u8 {
        return switch (self) {
            .idle => "idle",
            .preparing => "preparing",
            .recording => "recording",
            .paused => "paused",
            .stopped => "stopped",
            .failed => "failed",
        };
    }
};

pub const AudioFormat = enum {
    mp3,
    aac,
    wav,
    flac,
    ogg,
    m4a,
    wma,
    opus,
    unknown,

    pub fn mimeType(self: AudioFormat) []const u8 {
        return switch (self) {
            .mp3 => "audio/mpeg",
            .aac => "audio/aac",
            .wav => "audio/wav",
            .flac => "audio/flac",
            .ogg => "audio/ogg",
            .m4a => "audio/mp4",
            .wma => "audio/x-ms-wma",
            .opus => "audio/opus",
            .unknown => "application/octet-stream",
        };
    }

    pub fn fileExtension(self: AudioFormat) []const u8 {
        return switch (self) {
            .mp3 => ".mp3",
            .aac => ".aac",
            .wav => ".wav",
            .flac => ".flac",
            .ogg => ".ogg",
            .m4a => ".m4a",
            .wma => ".wma",
            .opus => ".opus",
            .unknown => "",
        };
    }
};

pub const VideoFormat = enum {
    mp4,
    mov,
    avi,
    mkv,
    webm,
    wmv,
    flv,
    unknown,

    pub fn mimeType(self: VideoFormat) []const u8 {
        return switch (self) {
            .mp4 => "video/mp4",
            .mov => "video/quicktime",
            .avi => "video/x-msvideo",
            .mkv => "video/x-matroska",
            .webm => "video/webm",
            .wmv => "video/x-ms-wmv",
            .flv => "video/x-flv",
            .unknown => "application/octet-stream",
        };
    }

    pub fn fileExtension(self: VideoFormat) []const u8 {
        return switch (self) {
            .mp4 => ".mp4",
            .mov => ".mov",
            .avi => ".avi",
            .mkv => ".mkv",
            .webm => ".webm",
            .wmv => ".wmv",
            .flv => ".flv",
            .unknown => "",
        };
    }
};

pub const SeekMode = enum {
    exact,
    nearest_keyframe,
    fast,

    pub fn toString(self: SeekMode) []const u8 {
        return switch (self) {
            .exact => "exact",
            .nearest_keyframe => "nearest_keyframe",
            .fast => "fast",
        };
    }
};

// ============================================================================
// Data Structures
// ============================================================================

pub const MediaMetadata = struct {
    title: ?[]const u8 = null,
    artist: ?[]const u8 = null,
    album: ?[]const u8 = null,
    album_artist: ?[]const u8 = null,
    composer: ?[]const u8 = null,
    genre: ?[]const u8 = null,
    year: ?u16 = null,
    track_number: ?u16 = null,
    track_total: ?u16 = null,
    disc_number: ?u16 = null,
    disc_total: ?u16 = null,
    duration_ms: ?i64 = null,
    artwork_url: ?[]const u8 = null,
    artwork_data: ?[]const u8 = null,

    const Self = @This();

    pub fn hasDuration(self: Self) bool {
        return self.duration_ms != null;
    }

    pub fn durationSeconds(self: Self) ?f64 {
        if (self.duration_ms) |ms| {
            return @as(f64, @floatFromInt(ms)) / 1000.0;
        }
        return null;
    }

    pub fn displayTitle(self: Self) []const u8 {
        return self.title orelse "Unknown Title";
    }

    pub fn displayArtist(self: Self) []const u8 {
        return self.artist orelse "Unknown Artist";
    }
};

pub const MediaSource = struct {
    url: []const u8,
    media_type: MediaType = .unknown,
    metadata: MediaMetadata = .{},
    headers: ?[]const Header = null,
    drm_config: ?DrmConfig = null,

    pub const Header = struct {
        name: []const u8,
        value: []const u8,
    };

    pub const DrmConfig = struct {
        scheme: DrmScheme,
        license_url: ?[]const u8 = null,
        headers: ?[]const Header = null,
    };

    pub const DrmScheme = enum {
        widevine,
        fairplay,
        playready,
        clearkey,
    };

    const Self = @This();

    pub fn fromUrl(url: []const u8) Self {
        return .{ .url = url };
    }

    pub fn fromUrlWithType(url: []const u8, media_type: MediaType) Self {
        return .{ .url = url, .media_type = media_type };
    }

    pub fn isLocal(self: Self) bool {
        return std.mem.startsWith(u8, self.url, "file://") or
            std.mem.startsWith(u8, self.url, "/");
    }

    pub fn isRemote(self: Self) bool {
        return std.mem.startsWith(u8, self.url, "http://") or
            std.mem.startsWith(u8, self.url, "https://");
    }

    pub fn isStream(self: Self) bool {
        return std.mem.endsWith(u8, self.url, ".m3u8") or
            std.mem.endsWith(u8, self.url, ".mpd") or
            self.media_type == .stream;
    }
};

pub const PlaybackPosition = struct {
    current_ms: i64 = 0,
    duration_ms: i64 = 0,
    buffered_ms: i64 = 0,

    const Self = @This();

    pub fn progress(self: Self) f32 {
        if (self.duration_ms <= 0) return 0.0;
        return @as(f32, @floatFromInt(self.current_ms)) / @as(f32, @floatFromInt(self.duration_ms));
    }

    pub fn bufferProgress(self: Self) f32 {
        if (self.duration_ms <= 0) return 0.0;
        return @as(f32, @floatFromInt(self.buffered_ms)) / @as(f32, @floatFromInt(self.duration_ms));
    }

    pub fn remainingMs(self: Self) i64 {
        if (self.duration_ms <= self.current_ms) return 0;
        return self.duration_ms - self.current_ms;
    }

    pub fn currentSeconds(self: Self) f64 {
        return @as(f64, @floatFromInt(self.current_ms)) / 1000.0;
    }

    pub fn durationSeconds(self: Self) f64 {
        return @as(f64, @floatFromInt(self.duration_ms)) / 1000.0;
    }

    pub fn formatTime(ms: i64, buffer: []u8) []const u8 {
        const ms_u: u64 = if (ms < 0) 0 else @intCast(ms);
        const total_seconds = ms_u / 1000;
        const hours = total_seconds / 3600;
        const minutes = (total_seconds / 60) % 60;
        const seconds = total_seconds % 60;

        if (hours > 0) {
            return std.fmt.bufPrint(buffer, "{d}:{d:0>2}:{d:0>2}", .{ hours, minutes, seconds }) catch "";
        } else {
            return std.fmt.bufPrint(buffer, "{d}:{d:0>2}", .{ minutes, seconds }) catch "";
        }
    }
};

pub const VideoSize = struct {
    width: u32,
    height: u32,

    const Self = @This();

    pub fn aspectRatio(self: Self) f32 {
        if (self.height == 0) return 0.0;
        return @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(self.height));
    }

    pub fn isPortrait(self: Self) bool {
        return self.height > self.width;
    }

    pub fn isLandscape(self: Self) bool {
        return self.width > self.height;
    }

    pub fn is16by9(self: Self) bool {
        const ratio = self.aspectRatio();
        return ratio > 1.7 and ratio < 1.8;
    }

    pub fn is4by3(self: Self) bool {
        const ratio = self.aspectRatio();
        return ratio > 1.3 and ratio < 1.4;
    }
};

pub const AudioSettings = struct {
    volume: f32 = 1.0,
    muted: bool = false,
    playback_speed: f32 = 1.0,
    pitch: f32 = 1.0,
    balance: f32 = 0.0,

    const Self = @This();

    pub fn effectiveVolume(self: Self) f32 {
        if (self.muted) return 0.0;
        return std.math.clamp(self.volume, 0.0, 1.0);
    }

    pub fn setVolume(self: *Self, vol: f32) void {
        self.volume = std.math.clamp(vol, 0.0, 1.0);
    }

    pub fn toggleMute(self: *Self) void {
        self.muted = !self.muted;
    }

    pub fn setPlaybackSpeed(self: *Self, speed: f32) void {
        self.playback_speed = std.math.clamp(speed, 0.25, 4.0);
    }
};

pub const RecordingSettings = struct {
    format: AudioFormat = .m4a,
    sample_rate: u32 = 44100,
    channels: u8 = 2,
    bit_rate: u32 = 128000,
    quality: RecordingQuality = .medium,

    pub const RecordingQuality = enum {
        low,
        medium,
        high,
        lossless,

        pub fn bitRate(self: RecordingQuality) u32 {
            return switch (self) {
                .low => 64000,
                .medium => 128000,
                .high => 256000,
                .lossless => 0,
            };
        }
    };
};

// ============================================================================
// Media Player
// ============================================================================

pub const MediaPlayer = struct {
    allocator: Allocator,
    state: PlaybackState = .idle,
    source: ?MediaSource = null,
    position: PlaybackPosition = .{},
    audio_settings: AudioSettings = .{},
    video_size: ?VideoSize = null,
    repeat_mode: RepeatMode = .off,
    shuffle_enabled: bool = false,
    output_route: AudioOutputRoute = .speaker,
    event_callback: ?*const fn (MediaEvent) void = null,
    error_message: ?[]const u8 = null,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn setEventCallback(self: *Self, callback: *const fn (MediaEvent) void) void {
        self.event_callback = callback;
    }

    pub fn load(self: *Self, source: MediaSource) !void {
        self.source = source;
        self.state = .loading;
        self.error_message = null;

        if (self.event_callback) |cb| {
            cb(.{ .loading_started = source.url });
        }
    }

    pub fn play(self: *Self) !void {
        if (self.source == null) return error.NoMediaLoaded;

        switch (self.state) {
            .ready, .paused, .stopped => {
                self.state = .playing;
                if (self.event_callback) |cb| {
                    cb(.playing);
                }
            },
            .playing => {},
            .loading, .buffering => return error.NotReady,
            else => return error.InvalidState,
        }
    }

    pub fn pause(self: *Self) void {
        if (self.state == .playing) {
            self.state = .paused;
            if (self.event_callback) |cb| {
                cb(.paused);
            }
        }
    }

    pub fn stop(self: *Self) void {
        if (self.state.isActive()) {
            self.state = .stopped;
            self.position.current_ms = 0;
            if (self.event_callback) |cb| {
                cb(.stopped);
            }
        }
    }

    pub fn seek(self: *Self, position_ms: i64, mode: SeekMode) !void {
        _ = mode;
        if (self.source == null) return error.NoMediaLoaded;

        const clamped = std.math.clamp(position_ms, 0, self.position.duration_ms);
        self.position.current_ms = clamped;

        if (self.event_callback) |cb| {
            cb(.{ .seeked = clamped });
        }
    }

    pub fn seekRelative(self: *Self, delta_ms: i64) !void {
        const new_pos = self.position.current_ms + delta_ms;
        try self.seek(new_pos, .fast);
    }

    pub fn skipForward(self: *Self, seconds: u32) !void {
        try self.seekRelative(@as(i64, seconds) * 1000);
    }

    pub fn skipBackward(self: *Self, seconds: u32) !void {
        try self.seekRelative(-@as(i64, seconds) * 1000);
    }

    pub fn setVolume(self: *Self, volume: f32) void {
        self.audio_settings.setVolume(volume);
        if (self.event_callback) |cb| {
            cb(.{ .volume_changed = self.audio_settings.effectiveVolume() });
        }
    }

    pub fn setMuted(self: *Self, muted: bool) void {
        self.audio_settings.muted = muted;
        if (self.event_callback) |cb| {
            cb(.{ .mute_changed = muted });
        }
    }

    pub fn toggleMute(self: *Self) void {
        self.setMuted(!self.audio_settings.muted);
    }

    pub fn setPlaybackSpeed(self: *Self, speed: f32) void {
        self.audio_settings.setPlaybackSpeed(speed);
        if (self.event_callback) |cb| {
            cb(.{ .speed_changed = speed });
        }
    }

    pub fn setRepeatMode(self: *Self, mode: RepeatMode) void {
        self.repeat_mode = mode;
    }

    pub fn toggleShuffle(self: *Self) void {
        self.shuffle_enabled = !self.shuffle_enabled;
    }

    pub fn getState(self: Self) PlaybackState {
        return self.state;
    }

    pub fn getPosition(self: Self) PlaybackPosition {
        return self.position;
    }

    pub fn getVolume(self: Self) f32 {
        return self.audio_settings.effectiveVolume();
    }

    pub fn isMuted(self: Self) bool {
        return self.audio_settings.muted;
    }

    pub fn isPlaying(self: Self) bool {
        return self.state == .playing;
    }

    pub fn isPaused(self: Self) bool {
        return self.state == .paused;
    }

    pub fn getMetadata(self: Self) ?MediaMetadata {
        if (self.source) |s| {
            return s.metadata;
        }
        return null;
    }

    pub fn getVideoSize(self: Self) ?VideoSize {
        return self.video_size;
    }

    fn simulateReady(self: *Self, duration_ms: i64) void {
        self.state = .ready;
        self.position.duration_ms = duration_ms;
        if (self.event_callback) |cb| {
            cb(.ready);
        }
    }

    fn simulateProgress(self: *Self, current_ms: i64, buffered_ms: i64) void {
        self.position.current_ms = current_ms;
        self.position.buffered_ms = buffered_ms;
        if (self.event_callback) |cb| {
            cb(.{ .progress = self.position });
        }
    }

    fn simulateEnded(self: *Self) void {
        self.state = .ended;
        if (self.event_callback) |cb| {
            cb(.ended);
        }
    }

    fn simulateError(self: *Self, message: []const u8) void {
        self.state = .failed;
        self.error_message = message;
        if (self.event_callback) |cb| {
            cb(.{ .error_occurred = message });
        }
    }
};

// ============================================================================
// Playlist
// ============================================================================

pub const Playlist = struct {
    allocator: Allocator,
    name: []const u8,
    items: std.ArrayListUnmanaged(MediaSource) = .{},
    current_index: ?usize = null,
    shuffle_order: std.ArrayListUnmanaged(usize) = .{},
    is_shuffled: bool = false,

    const Self = @This();

    pub fn init(allocator: Allocator, name: []const u8) Self {
        return .{ .allocator = allocator, .name = name };
    }

    pub fn deinit(self: *Self) void {
        self.items.deinit(self.allocator);
        self.shuffle_order.deinit(self.allocator);
    }

    pub fn addItem(self: *Self, source: MediaSource) !void {
        try self.items.append(self.allocator, source);
    }

    pub fn addItems(self: *Self, sources: []const MediaSource) !void {
        try self.items.appendSlice(self.allocator, sources);
    }

    pub fn removeItem(self: *Self, index: usize) !void {
        if (index >= self.items.items.len) return error.IndexOutOfBounds;
        _ = self.items.orderedRemove(index);

        if (self.current_index) |ci| {
            if (index < ci) {
                self.current_index = ci - 1;
            } else if (index == ci) {
                self.current_index = null;
            }
        }
    }

    pub fn clear(self: *Self) void {
        self.items.clearRetainingCapacity();
        self.current_index = null;
        self.shuffle_order.clearRetainingCapacity();
    }

    pub fn moveItem(self: *Self, from: usize, to: usize) !void {
        if (from >= self.items.items.len or to >= self.items.items.len) {
            return error.IndexOutOfBounds;
        }

        const item = self.items.items[from];

        if (from < to) {
            var i = from;
            while (i < to) : (i += 1) {
                self.items.items[i] = self.items.items[i + 1];
            }
        } else {
            var i = from;
            while (i > to) : (i -= 1) {
                self.items.items[i] = self.items.items[i - 1];
            }
        }

        self.items.items[to] = item;
    }

    pub fn getCurrentItem(self: Self) ?MediaSource {
        if (self.current_index) |idx| {
            if (idx < self.items.items.len) {
                return self.items.items[idx];
            }
        }
        return null;
    }

    pub fn next(self: *Self) ?MediaSource {
        if (self.items.items.len == 0) return null;

        if (self.current_index) |idx| {
            if (idx + 1 < self.items.items.len) {
                self.current_index = idx + 1;
            } else {
                self.current_index = 0;
            }
        } else {
            self.current_index = 0;
        }

        return self.getCurrentItem();
    }

    pub fn previous(self: *Self) ?MediaSource {
        if (self.items.items.len == 0) return null;

        if (self.current_index) |idx| {
            if (idx > 0) {
                self.current_index = idx - 1;
            } else {
                self.current_index = self.items.items.len - 1;
            }
        } else {
            self.current_index = self.items.items.len - 1;
        }

        return self.getCurrentItem();
    }

    pub fn goTo(self: *Self, index: usize) ?MediaSource {
        if (index >= self.items.items.len) return null;
        self.current_index = index;
        return self.getCurrentItem();
    }

    pub fn count(self: Self) usize {
        return self.items.items.len;
    }

    pub fn isEmpty(self: Self) bool {
        return self.items.items.len == 0;
    }

    pub fn hasNext(self: Self) bool {
        if (self.current_index) |idx| {
            return idx + 1 < self.items.items.len;
        }
        return self.items.items.len > 0;
    }

    pub fn hasPrevious(self: Self) bool {
        if (self.current_index) |idx| {
            return idx > 0;
        }
        return self.items.items.len > 0;
    }

    pub fn getTotalDuration(self: Self) i64 {
        var total: i64 = 0;
        for (self.items.items) |item| {
            if (item.metadata.duration_ms) |d| {
                total += d;
            }
        }
        return total;
    }
};

// ============================================================================
// Audio Recorder
// ============================================================================

pub const AudioRecorder = struct {
    allocator: Allocator,
    state: RecordingState = .idle,
    settings: RecordingSettings = .{},
    output_path: ?[]const u8 = null,
    duration_ms: i64 = 0,
    peak_level: f32 = 0.0,
    average_level: f32 = 0.0,
    event_callback: ?*const fn (RecordingEvent) void = null,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn setEventCallback(self: *Self, callback: *const fn (RecordingEvent) void) void {
        self.event_callback = callback;
    }

    pub fn prepare(self: *Self, output_path: []const u8, settings: RecordingSettings) !void {
        if (self.state == .recording) return error.AlreadyRecording;

        self.output_path = output_path;
        self.settings = settings;
        self.state = .preparing;
        self.duration_ms = 0;
    }

    pub fn start(self: *Self) !void {
        if (self.state != .preparing and self.state != .paused) {
            return error.NotPrepared;
        }

        self.state = .recording;
        if (self.event_callback) |cb| {
            cb(.recording_started);
        }
    }

    pub fn pause(self: *Self) void {
        if (self.state == .recording) {
            self.state = .paused;
            if (self.event_callback) |cb| {
                cb(.recording_paused);
            }
        }
    }

    pub fn resumeRecording(self: *Self) !void {
        if (self.state != .paused) return error.NotPaused;

        self.state = .recording;
        if (self.event_callback) |cb| {
            cb(.recording_resumed);
        }
    }

    pub fn stop(self: *Self) ![]const u8 {
        if (self.state != .recording and self.state != .paused) {
            return error.NotRecording;
        }

        self.state = .stopped;
        if (self.event_callback) |cb| {
            cb(.{ .recording_stopped = self.output_path orelse "" });
        }

        return self.output_path orelse error.NoOutputPath;
    }

    pub fn cancel(self: *Self) void {
        self.state = .idle;
        self.duration_ms = 0;
        self.output_path = null;
    }

    pub fn isRecording(self: Self) bool {
        return self.state == .recording;
    }

    pub fn isPaused(self: Self) bool {
        return self.state == .paused;
    }

    pub fn getDuration(self: Self) i64 {
        return self.duration_ms;
    }

    pub fn getAudioLevels(self: Self) struct { peak: f32, average: f32 } {
        return .{ .peak = self.peak_level, .average = self.average_level };
    }

    fn simulateProgress(self: *Self, duration_ms: i64, peak: f32, average: f32) void {
        self.duration_ms = duration_ms;
        self.peak_level = peak;
        self.average_level = average;

        if (self.event_callback) |cb| {
            cb(.{ .level_update = .{ .peak = peak, .average = average } });
        }
    }
};

// ============================================================================
// Events
// ============================================================================

pub const MediaEvent = union(enum) {
    loading_started: []const u8,
    ready: void,
    playing: void,
    paused: void,
    stopped: void,
    ended: void,
    buffering: f32,
    progress: PlaybackPosition,
    seeked: i64,
    volume_changed: f32,
    mute_changed: bool,
    speed_changed: f32,
    error_occurred: []const u8,
    audio_route_changed: AudioOutputRoute,
    metadata_updated: MediaMetadata,
};

pub const RecordingEvent = union(enum) {
    recording_started: void,
    recording_paused: void,
    recording_resumed: void,
    recording_stopped: []const u8,
    level_update: struct { peak: f32, average: f32 },
    error_occurred: []const u8,
};

// ============================================================================
// Utility Functions
// ============================================================================

pub fn formatDuration(ms: i64, buffer: []u8) []const u8 {
    return PlaybackPosition.formatTime(ms, buffer);
}

pub fn msToSeconds(ms: i64) f64 {
    return @as(f64, @floatFromInt(ms)) / 1000.0;
}

pub fn secondsToMs(seconds: f64) i64 {
    return @intFromFloat(seconds * 1000.0);
}

pub fn detectMediaType(url: []const u8) MediaType {
    const audio_exts = [_][]const u8{ ".mp3", ".aac", ".wav", ".flac", ".ogg", ".m4a", ".wma", ".opus" };
    const video_exts = [_][]const u8{ ".mp4", ".mov", ".avi", ".mkv", ".webm", ".wmv", ".flv" };
    const stream_exts = [_][]const u8{ ".m3u8", ".mpd" };

    for (audio_exts) |ext| {
        if (std.mem.endsWith(u8, url, ext)) return .audio;
    }

    for (video_exts) |ext| {
        if (std.mem.endsWith(u8, url, ext)) return .video;
    }

    for (stream_exts) |ext| {
        if (std.mem.endsWith(u8, url, ext)) return .stream;
    }

    return .unknown;
}

// ============================================================================
// Tests
// ============================================================================

test "MediaType toString" {
    try std.testing.expectEqualStrings("audio", MediaType.audio.toString());
    try std.testing.expectEqualStrings("video", MediaType.video.toString());
    try std.testing.expectEqualStrings("stream", MediaType.stream.toString());
}

test "PlaybackState isActive" {
    try std.testing.expect(PlaybackState.playing.isActive());
    try std.testing.expect(PlaybackState.paused.isActive());
    try std.testing.expect(PlaybackState.buffering.isActive());
    try std.testing.expect(!PlaybackState.idle.isActive());
    try std.testing.expect(!PlaybackState.stopped.isActive());
}

test "PlaybackState canPlay" {
    try std.testing.expect(PlaybackState.ready.canPlay());
    try std.testing.expect(PlaybackState.paused.canPlay());
    try std.testing.expect(PlaybackState.stopped.canPlay());
    try std.testing.expect(!PlaybackState.playing.canPlay());
    try std.testing.expect(!PlaybackState.idle.canPlay());
}

test "AudioFormat mimeType and extension" {
    try std.testing.expectEqualStrings("audio/mpeg", AudioFormat.mp3.mimeType());
    try std.testing.expectEqualStrings(".mp3", AudioFormat.mp3.fileExtension());
    try std.testing.expectEqualStrings("audio/aac", AudioFormat.aac.mimeType());
}

test "VideoFormat mimeType and extension" {
    try std.testing.expectEqualStrings("video/mp4", VideoFormat.mp4.mimeType());
    try std.testing.expectEqualStrings(".mp4", VideoFormat.mp4.fileExtension());
    try std.testing.expectEqualStrings("video/webm", VideoFormat.webm.mimeType());
}

test "MediaMetadata displayTitle and displayArtist" {
    const meta1 = MediaMetadata{ .title = "Test Song", .artist = "Test Artist" };
    try std.testing.expectEqualStrings("Test Song", meta1.displayTitle());
    try std.testing.expectEqualStrings("Test Artist", meta1.displayArtist());

    const meta2 = MediaMetadata{};
    try std.testing.expectEqualStrings("Unknown Title", meta2.displayTitle());
    try std.testing.expectEqualStrings("Unknown Artist", meta2.displayArtist());
}

test "MediaMetadata durationSeconds" {
    const meta = MediaMetadata{ .duration_ms = 180000 };
    try std.testing.expectEqual(@as(?f64, 180.0), meta.durationSeconds());

    const meta2 = MediaMetadata{};
    try std.testing.expect(meta2.durationSeconds() == null);
}

test "MediaSource fromUrl" {
    const source = MediaSource.fromUrl("https://example.com/song.mp3");
    try std.testing.expectEqualStrings("https://example.com/song.mp3", source.url);
    try std.testing.expectEqual(MediaType.unknown, source.media_type);
}

test "MediaSource isLocal and isRemote" {
    const remote = MediaSource.fromUrl("https://example.com/song.mp3");
    try std.testing.expect(remote.isRemote());
    try std.testing.expect(!remote.isLocal());

    const local1 = MediaSource.fromUrl("file:///path/to/song.mp3");
    try std.testing.expect(local1.isLocal());
    try std.testing.expect(!local1.isRemote());

    const local2 = MediaSource.fromUrl("/path/to/song.mp3");
    try std.testing.expect(local2.isLocal());
}

test "MediaSource isStream" {
    const hls = MediaSource.fromUrl("https://example.com/stream.m3u8");
    try std.testing.expect(hls.isStream());

    const dash = MediaSource.fromUrl("https://example.com/manifest.mpd");
    try std.testing.expect(dash.isStream());

    const mp3 = MediaSource.fromUrl("https://example.com/song.mp3");
    try std.testing.expect(!mp3.isStream());
}

test "PlaybackPosition progress" {
    const pos = PlaybackPosition{
        .current_ms = 30000,
        .duration_ms = 120000,
        .buffered_ms = 60000,
    };

    try std.testing.expectEqual(@as(f32, 0.25), pos.progress());
    try std.testing.expectEqual(@as(f32, 0.5), pos.bufferProgress());
    try std.testing.expectEqual(@as(i64, 90000), pos.remainingMs());
}

test "PlaybackPosition formatTime" {
    var buffer: [16]u8 = undefined;

    try std.testing.expectEqualStrings("1:30", PlaybackPosition.formatTime(90000, &buffer));
    try std.testing.expectEqualStrings("1:05:30", PlaybackPosition.formatTime(3930000, &buffer));
    try std.testing.expectEqualStrings("0:00", PlaybackPosition.formatTime(0, &buffer));
}

test "VideoSize aspectRatio" {
    const hd = VideoSize{ .width = 1920, .height = 1080 };
    const ratio = hd.aspectRatio();
    try std.testing.expect(ratio > 1.7 and ratio < 1.8);
    try std.testing.expect(hd.isLandscape());
    try std.testing.expect(!hd.isPortrait());
    try std.testing.expect(hd.is16by9());
}

test "VideoSize 4:3" {
    const sd = VideoSize{ .width = 640, .height = 480 };
    try std.testing.expect(sd.is4by3());
    try std.testing.expect(!sd.is16by9());
}

test "AudioSettings effectiveVolume" {
    var settings = AudioSettings{ .volume = 0.8 };
    try std.testing.expectEqual(@as(f32, 0.8), settings.effectiveVolume());

    settings.muted = true;
    try std.testing.expectEqual(@as(f32, 0.0), settings.effectiveVolume());
}

test "AudioSettings setVolume clamps" {
    var settings = AudioSettings{};

    settings.setVolume(1.5);
    try std.testing.expectEqual(@as(f32, 1.0), settings.volume);

    settings.setVolume(-0.5);
    try std.testing.expectEqual(@as(f32, 0.0), settings.volume);
}

test "AudioSettings setPlaybackSpeed clamps" {
    var settings = AudioSettings{};

    settings.setPlaybackSpeed(5.0);
    try std.testing.expectEqual(@as(f32, 4.0), settings.playback_speed);

    settings.setPlaybackSpeed(0.1);
    try std.testing.expectEqual(@as(f32, 0.25), settings.playback_speed);
}

test "RecordingSettings quality bitRate" {
    try std.testing.expectEqual(@as(u32, 64000), RecordingSettings.RecordingQuality.low.bitRate());
    try std.testing.expectEqual(@as(u32, 128000), RecordingSettings.RecordingQuality.medium.bitRate());
    try std.testing.expectEqual(@as(u32, 256000), RecordingSettings.RecordingQuality.high.bitRate());
}

test "MediaPlayer initialization" {
    var player = MediaPlayer.init(std.testing.allocator);
    defer player.deinit();

    try std.testing.expectEqual(PlaybackState.idle, player.getState());
    try std.testing.expect(!player.isPlaying());
    try std.testing.expect(!player.isPaused());
}

test "MediaPlayer load" {
    var player = MediaPlayer.init(std.testing.allocator);
    defer player.deinit();

    const source = MediaSource.fromUrl("https://example.com/song.mp3");
    try player.load(source);

    try std.testing.expectEqual(PlaybackState.loading, player.getState());
}

test "MediaPlayer play requires source" {
    var player = MediaPlayer.init(std.testing.allocator);
    defer player.deinit();

    const result = player.play();
    try std.testing.expectError(error.NoMediaLoaded, result);
}

test "MediaPlayer play/pause/stop" {
    var player = MediaPlayer.init(std.testing.allocator);
    defer player.deinit();

    const source = MediaSource.fromUrl("https://example.com/song.mp3");
    try player.load(source);
    player.simulateReady(180000);

    try player.play();
    try std.testing.expect(player.isPlaying());

    player.pause();
    try std.testing.expect(player.isPaused());

    player.stop();
    try std.testing.expectEqual(PlaybackState.stopped, player.getState());
}

test "MediaPlayer volume control" {
    var player = MediaPlayer.init(std.testing.allocator);
    defer player.deinit();

    player.setVolume(0.5);
    try std.testing.expectEqual(@as(f32, 0.5), player.getVolume());

    player.setMuted(true);
    try std.testing.expect(player.isMuted());
    try std.testing.expectEqual(@as(f32, 0.0), player.getVolume());

    player.toggleMute();
    try std.testing.expect(!player.isMuted());
}

test "MediaPlayer seek" {
    var player = MediaPlayer.init(std.testing.allocator);
    defer player.deinit();

    const source = MediaSource.fromUrl("https://example.com/song.mp3");
    try player.load(source);
    player.simulateReady(180000);

    try player.seek(60000, .exact);
    try std.testing.expectEqual(@as(i64, 60000), player.getPosition().current_ms);

    try player.skipForward(10);
    try std.testing.expectEqual(@as(i64, 70000), player.getPosition().current_ms);

    try player.skipBackward(5);
    try std.testing.expectEqual(@as(i64, 65000), player.getPosition().current_ms);
}

test "Playlist initialization" {
    var playlist = Playlist.init(std.testing.allocator, "My Playlist");
    defer playlist.deinit();

    try std.testing.expect(playlist.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), playlist.count());
}

test "Playlist addItem" {
    var playlist = Playlist.init(std.testing.allocator, "My Playlist");
    defer playlist.deinit();

    try playlist.addItem(MediaSource.fromUrl("song1.mp3"));
    try playlist.addItem(MediaSource.fromUrl("song2.mp3"));

    try std.testing.expectEqual(@as(usize, 2), playlist.count());
    try std.testing.expect(!playlist.isEmpty());
}

test "Playlist navigation" {
    var playlist = Playlist.init(std.testing.allocator, "My Playlist");
    defer playlist.deinit();

    try playlist.addItem(MediaSource.fromUrl("song1.mp3"));
    try playlist.addItem(MediaSource.fromUrl("song2.mp3"));
    try playlist.addItem(MediaSource.fromUrl("song3.mp3"));

    const first = playlist.next();
    try std.testing.expect(first != null);
    try std.testing.expectEqualStrings("song1.mp3", first.?.url);

    const second = playlist.next();
    try std.testing.expectEqualStrings("song2.mp3", second.?.url);

    const prev = playlist.previous();
    try std.testing.expectEqualStrings("song1.mp3", prev.?.url);
}

test "Playlist goTo" {
    var playlist = Playlist.init(std.testing.allocator, "My Playlist");
    defer playlist.deinit();

    try playlist.addItem(MediaSource.fromUrl("song1.mp3"));
    try playlist.addItem(MediaSource.fromUrl("song2.mp3"));
    try playlist.addItem(MediaSource.fromUrl("song3.mp3"));

    const item = playlist.goTo(2);
    try std.testing.expect(item != null);
    try std.testing.expectEqualStrings("song3.mp3", item.?.url);

    const invalid = playlist.goTo(10);
    try std.testing.expect(invalid == null);
}

test "Playlist removeItem" {
    var playlist = Playlist.init(std.testing.allocator, "My Playlist");
    defer playlist.deinit();

    try playlist.addItem(MediaSource.fromUrl("song1.mp3"));
    try playlist.addItem(MediaSource.fromUrl("song2.mp3"));

    try playlist.removeItem(0);
    try std.testing.expectEqual(@as(usize, 1), playlist.count());
}

test "Playlist hasNext and hasPrevious" {
    var playlist = Playlist.init(std.testing.allocator, "My Playlist");
    defer playlist.deinit();

    try playlist.addItem(MediaSource.fromUrl("song1.mp3"));
    try playlist.addItem(MediaSource.fromUrl("song2.mp3"));

    _ = playlist.goTo(0);
    try std.testing.expect(playlist.hasNext());
    try std.testing.expect(!playlist.hasPrevious());

    _ = playlist.goTo(1);
    try std.testing.expect(!playlist.hasNext());
    try std.testing.expect(playlist.hasPrevious());
}

test "AudioRecorder initialization" {
    var recorder = AudioRecorder.init(std.testing.allocator);
    defer recorder.deinit();

    try std.testing.expectEqual(RecordingState.idle, recorder.state);
    try std.testing.expect(!recorder.isRecording());
}

test "AudioRecorder prepare and start" {
    var recorder = AudioRecorder.init(std.testing.allocator);
    defer recorder.deinit();

    try recorder.prepare("/tmp/recording.m4a", .{});
    try std.testing.expectEqual(RecordingState.preparing, recorder.state);

    try recorder.start();
    try std.testing.expect(recorder.isRecording());
}

test "AudioRecorder pause and resume" {
    var recorder = AudioRecorder.init(std.testing.allocator);
    defer recorder.deinit();

    try recorder.prepare("/tmp/recording.m4a", .{});
    try recorder.start();

    recorder.pause();
    try std.testing.expect(recorder.isPaused());

    try recorder.resumeRecording();
    try std.testing.expect(recorder.isRecording());
}

test "AudioRecorder stop" {
    var recorder = AudioRecorder.init(std.testing.allocator);
    defer recorder.deinit();

    try recorder.prepare("/tmp/recording.m4a", .{});
    try recorder.start();

    const path = try recorder.stop();
    try std.testing.expectEqualStrings("/tmp/recording.m4a", path);
    try std.testing.expectEqual(RecordingState.stopped, recorder.state);
}

test "detectMediaType" {
    try std.testing.expectEqual(MediaType.audio, detectMediaType("song.mp3"));
    try std.testing.expectEqual(MediaType.audio, detectMediaType("track.flac"));
    try std.testing.expectEqual(MediaType.video, detectMediaType("movie.mp4"));
    try std.testing.expectEqual(MediaType.video, detectMediaType("clip.webm"));
    try std.testing.expectEqual(MediaType.stream, detectMediaType("live.m3u8"));
    try std.testing.expectEqual(MediaType.unknown, detectMediaType("file.txt"));
}

test "msToSeconds and secondsToMs" {
    try std.testing.expectEqual(@as(f64, 1.5), msToSeconds(1500));
    try std.testing.expectEqual(@as(i64, 1500), secondsToMs(1.5));
}

test "RepeatMode toString" {
    try std.testing.expectEqualStrings("off", RepeatMode.off.toString());
    try std.testing.expectEqualStrings("one", RepeatMode.one.toString());
    try std.testing.expectEqualStrings("all", RepeatMode.all.toString());
}

test "RecordingState isRecording" {
    try std.testing.expect(RecordingState.recording.isRecording());
    try std.testing.expect(!RecordingState.paused.isRecording());
    try std.testing.expect(!RecordingState.idle.isRecording());
}

test "AudioOutputRoute toString" {
    try std.testing.expectEqualStrings("speaker", AudioOutputRoute.speaker.toString());
    try std.testing.expectEqualStrings("bluetooth", AudioOutputRoute.bluetooth.toString());
}

test "Playlist getTotalDuration" {
    var playlist = Playlist.init(std.testing.allocator, "Test");
    defer playlist.deinit();

    var source1 = MediaSource.fromUrl("song1.mp3");
    source1.metadata.duration_ms = 180000;

    var source2 = MediaSource.fromUrl("song2.mp3");
    source2.metadata.duration_ms = 240000;

    try playlist.addItem(source1);
    try playlist.addItem(source2);

    try std.testing.expectEqual(@as(i64, 420000), playlist.getTotalDuration());
}
