//! Cross-platform screen capture module
//! Provides abstractions for ReplayKit (iOS), MediaProjection (Android), and ScreenCaptureKit (macOS)

const std = @import("std");

/// Screen capture platform
pub const CapturePlatform = enum {
    replay_kit, // iOS
    media_projection, // Android
    screen_capture_kit, // macOS 12.3+
    cg_window_list, // macOS legacy
    desktop_duplication, // Windows
    pipewire, // Linux

    pub fn toString(self: CapturePlatform) []const u8 {
        return switch (self) {
            .replay_kit => "ReplayKit",
            .media_projection => "MediaProjection",
            .screen_capture_kit => "ScreenCaptureKit",
            .cg_window_list => "CGWindowList",
            .desktop_duplication => "Desktop Duplication",
            .pipewire => "PipeWire",
        };
    }

    pub fn supportsAudio(self: CapturePlatform) bool {
        return switch (self) {
            .replay_kit, .media_projection, .screen_capture_kit, .pipewire => true,
            .cg_window_list, .desktop_duplication => false,
        };
    }

    pub fn supportsWindowCapture(self: CapturePlatform) bool {
        return switch (self) {
            .screen_capture_kit, .cg_window_list, .desktop_duplication, .pipewire => true,
            .replay_kit, .media_projection => false,
        };
    }
};

/// Capture type
pub const CaptureType = enum {
    screenshot,
    video_recording,
    live_broadcast,

    pub fn toString(self: CaptureType) []const u8 {
        return switch (self) {
            .screenshot => "Screenshot",
            .video_recording => "Video Recording",
            .live_broadcast => "Live Broadcast",
        };
    }
};

/// Capture source type
pub const CaptureSource = enum {
    screen,
    window,
    app,
    region,

    pub fn toString(self: CaptureSource) []const u8 {
        return switch (self) {
            .screen => "Screen",
            .window => "Window",
            .app => "Application",
            .region => "Region",
        };
    }
};

/// Image format for screenshots
pub const ImageFormat = enum {
    png,
    jpeg,
    heic,
    tiff,
    bmp,
    webp,

    pub fn toString(self: ImageFormat) []const u8 {
        return switch (self) {
            .png => "PNG",
            .jpeg => "JPEG",
            .heic => "HEIC",
            .tiff => "TIFF",
            .bmp => "BMP",
            .webp => "WebP",
        };
    }

    pub fn fileExtension(self: ImageFormat) []const u8 {
        return switch (self) {
            .png => ".png",
            .jpeg => ".jpg",
            .heic => ".heic",
            .tiff => ".tiff",
            .bmp => ".bmp",
            .webp => ".webp",
        };
    }

    pub fn mimeType(self: ImageFormat) []const u8 {
        return switch (self) {
            .png => "image/png",
            .jpeg => "image/jpeg",
            .heic => "image/heic",
            .tiff => "image/tiff",
            .bmp => "image/bmp",
            .webp => "image/webp",
        };
    }

    pub fn supportsTransparency(self: ImageFormat) bool {
        return self == .png or self == .tiff or self == .webp;
    }
};

/// Video codec
pub const VideoCodec = enum {
    h264,
    h265,
    vp8,
    vp9,
    av1,
    prores,

    pub fn toString(self: VideoCodec) []const u8 {
        return switch (self) {
            .h264 => "H.264",
            .h265 => "H.265/HEVC",
            .vp8 => "VP8",
            .vp9 => "VP9",
            .av1 => "AV1",
            .prores => "ProRes",
        };
    }

    pub fn isHardwareAccelerated(self: VideoCodec) bool {
        return switch (self) {
            .h264, .h265, .prores => true,
            .vp8, .vp9, .av1 => false,
        };
    }
};

/// Audio codec
pub const AudioCodec = enum {
    aac,
    opus,
    pcm,
    flac,
    mp3,

    pub fn toString(self: AudioCodec) []const u8 {
        return switch (self) {
            .aac => "AAC",
            .opus => "Opus",
            .pcm => "PCM",
            .flac => "FLAC",
            .mp3 => "MP3",
        };
    }

    pub fn isLossless(self: AudioCodec) bool {
        return self == .pcm or self == .flac;
    }
};

/// Video container format
pub const ContainerFormat = enum {
    mp4,
    mov,
    webm,
    mkv,
    avi,

    pub fn toString(self: ContainerFormat) []const u8 {
        return switch (self) {
            .mp4 => "MP4",
            .mov => "MOV",
            .webm => "WebM",
            .mkv => "MKV",
            .avi => "AVI",
        };
    }

    pub fn fileExtension(self: ContainerFormat) []const u8 {
        return switch (self) {
            .mp4 => ".mp4",
            .mov => ".mov",
            .webm => ".webm",
            .mkv => ".mkv",
            .avi => ".avi",
        };
    }

    pub fn mimeType(self: ContainerFormat) []const u8 {
        return switch (self) {
            .mp4 => "video/mp4",
            .mov => "video/quicktime",
            .webm => "video/webm",
            .mkv => "video/x-matroska",
            .avi => "video/x-msvideo",
        };
    }
};

/// Capture region (rectangle)
pub const CaptureRegion = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,

    pub fn init(x: i32, y: i32, width: u32, height: u32) CaptureRegion {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }

    pub fn fullScreen(width: u32, height: u32) CaptureRegion {
        return .{ .x = 0, .y = 0, .width = width, .height = height };
    }

    pub fn aspectRatio(self: CaptureRegion) f32 {
        if (self.height == 0) return 0;
        return @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(self.height));
    }

    pub fn area(self: CaptureRegion) u64 {
        return @as(u64, self.width) * @as(u64, self.height);
    }

    pub fn contains(self: CaptureRegion, px: i32, py: i32) bool {
        return px >= self.x and px < self.x + @as(i32, @intCast(self.width)) and
            py >= self.y and py < self.y + @as(i32, @intCast(self.height));
    }

    pub fn scale(self: CaptureRegion, factor: f32) CaptureRegion {
        return .{
            .x = @intFromFloat(@as(f32, @floatFromInt(self.x)) * factor),
            .y = @intFromFloat(@as(f32, @floatFromInt(self.y)) * factor),
            .width = @intFromFloat(@as(f32, @floatFromInt(self.width)) * factor),
            .height = @intFromFloat(@as(f32, @floatFromInt(self.height)) * factor),
        };
    }
};

/// Display/screen information
pub const DisplayInfo = struct {
    id: u32,
    name: ?[]const u8,
    width: u32,
    height: u32,
    scale_factor: f32,
    refresh_rate: f32,
    is_primary: bool,
    is_builtin: bool,

    pub fn init(id: u32, width: u32, height: u32) DisplayInfo {
        return .{
            .id = id,
            .name = null,
            .width = width,
            .height = height,
            .scale_factor = 1.0,
            .refresh_rate = 60.0,
            .is_primary = false,
            .is_builtin = false,
        };
    }

    pub fn withName(self: DisplayInfo, name: []const u8) DisplayInfo {
        var info = self;
        info.name = name;
        return info;
    }

    pub fn withScale(self: DisplayInfo, scale: f32) DisplayInfo {
        var info = self;
        info.scale_factor = @max(1.0, scale);
        return info;
    }

    pub fn primary(self: DisplayInfo) DisplayInfo {
        var info = self;
        info.is_primary = true;
        return info;
    }

    pub fn getPhysicalWidth(self: DisplayInfo) u32 {
        return @intFromFloat(@as(f32, @floatFromInt(self.width)) * self.scale_factor);
    }

    pub fn getPhysicalHeight(self: DisplayInfo) u32 {
        return @intFromFloat(@as(f32, @floatFromInt(self.height)) * self.scale_factor);
    }

    pub fn toRegion(self: DisplayInfo) CaptureRegion {
        return CaptureRegion.fullScreen(self.width, self.height);
    }
};

/// Window information
pub const WindowInfo = struct {
    id: u64,
    title: ?[]const u8,
    app_name: ?[]const u8,
    bundle_id: ?[]const u8,
    x: i32,
    y: i32,
    width: u32,
    height: u32,
    is_on_screen: bool,
    is_minimized: bool,
    layer: i32,

    pub fn init(id: u64) WindowInfo {
        return .{
            .id = id,
            .title = null,
            .app_name = null,
            .bundle_id = null,
            .x = 0,
            .y = 0,
            .width = 0,
            .height = 0,
            .is_on_screen = true,
            .is_minimized = false,
            .layer = 0,
        };
    }

    pub fn withTitle(self: WindowInfo, title: []const u8) WindowInfo {
        var info = self;
        info.title = title;
        return info;
    }

    pub fn withApp(self: WindowInfo, app_name: []const u8) WindowInfo {
        var info = self;
        info.app_name = app_name;
        return info;
    }

    pub fn withBounds(self: WindowInfo, x: i32, y: i32, width: u32, height: u32) WindowInfo {
        var info = self;
        info.x = x;
        info.y = y;
        info.width = width;
        info.height = height;
        return info;
    }

    pub fn toRegion(self: WindowInfo) CaptureRegion {
        return CaptureRegion.init(self.x, self.y, self.width, self.height);
    }

    pub fn isVisible(self: *const WindowInfo) bool {
        return self.is_on_screen and !self.is_minimized and self.width > 0 and self.height > 0;
    }
};

/// Screenshot settings
pub const ScreenshotSettings = struct {
    format: ImageFormat,
    quality: f32, // 0.0 - 1.0 for lossy formats
    scale: f32,
    include_cursor: bool,
    include_shadow: bool,
    region: ?CaptureRegion,

    pub fn defaults() ScreenshotSettings {
        return .{
            .format = .png,
            .quality = 0.9,
            .scale = 1.0,
            .include_cursor = false,
            .include_shadow = true,
            .region = null,
        };
    }

    pub fn withFormat(self: ScreenshotSettings, format: ImageFormat) ScreenshotSettings {
        var settings = self;
        settings.format = format;
        return settings;
    }

    pub fn withQuality(self: ScreenshotSettings, quality: f32) ScreenshotSettings {
        var settings = self;
        settings.quality = std.math.clamp(quality, 0.0, 1.0);
        return settings;
    }

    pub fn withScale(self: ScreenshotSettings, scale: f32) ScreenshotSettings {
        var settings = self;
        settings.scale = std.math.clamp(scale, 0.1, 4.0);
        return settings;
    }

    pub fn withCursor(self: ScreenshotSettings, include: bool) ScreenshotSettings {
        var settings = self;
        settings.include_cursor = include;
        return settings;
    }

    pub fn withRegion(self: ScreenshotSettings, region: CaptureRegion) ScreenshotSettings {
        var settings = self;
        settings.region = region;
        return settings;
    }
};

/// Video recording settings
pub const RecordingSettings = struct {
    video_codec: VideoCodec,
    audio_codec: AudioCodec,
    container: ContainerFormat,
    frame_rate: f32,
    bitrate: u32, // kbps
    audio_bitrate: u32, // kbps
    width: ?u32,
    height: ?u32,
    capture_audio: bool,
    capture_microphone: bool,
    show_cursor: bool,
    highlight_clicks: bool,

    pub fn defaults() RecordingSettings {
        return .{
            .video_codec = .h264,
            .audio_codec = .aac,
            .container = .mp4,
            .frame_rate = 30.0,
            .bitrate = 8000,
            .audio_bitrate = 128,
            .width = null,
            .height = null,
            .capture_audio = true,
            .capture_microphone = false,
            .show_cursor = true,
            .highlight_clicks = false,
        };
    }

    pub fn highQuality() RecordingSettings {
        return .{
            .video_codec = .h265,
            .audio_codec = .aac,
            .container = .mp4,
            .frame_rate = 60.0,
            .bitrate = 20000,
            .audio_bitrate = 256,
            .width = null,
            .height = null,
            .capture_audio = true,
            .capture_microphone = false,
            .show_cursor = true,
            .highlight_clicks = false,
        };
    }

    pub fn withResolution(self: RecordingSettings, width: u32, height: u32) RecordingSettings {
        var settings = self;
        settings.width = width;
        settings.height = height;
        return settings;
    }

    pub fn withFrameRate(self: RecordingSettings, fps: f32) RecordingSettings {
        var settings = self;
        settings.frame_rate = std.math.clamp(fps, 1.0, 120.0);
        return settings;
    }

    pub fn withBitrate(self: RecordingSettings, kbps: u32) RecordingSettings {
        var settings = self;
        settings.bitrate = kbps;
        return settings;
    }

    pub fn withMicrophone(self: RecordingSettings, enabled: bool) RecordingSettings {
        var settings = self;
        settings.capture_microphone = enabled;
        return settings;
    }

    pub fn estimatedFileSizePerMinute(self: *const RecordingSettings) u64 {
        // Rough estimate: (video_bitrate + audio_bitrate) * 60 / 8 = bytes per minute
        const total_bitrate = self.bitrate + self.audio_bitrate;
        return @as(u64, total_bitrate) * 60 * 1000 / 8;
    }
};

/// Recording state
pub const RecordingState = enum {
    idle,
    starting,
    recording,
    paused,
    stopping,
    stopped,
    recording_error,

    pub fn toString(self: RecordingState) []const u8 {
        return switch (self) {
            .idle => "Idle",
            .starting => "Starting",
            .recording => "Recording",
            .paused => "Paused",
            .stopping => "Stopping",
            .stopped => "Stopped",
            .recording_error => "Error",
        };
    }

    pub fn isActive(self: RecordingState) bool {
        return self == .recording or self == .paused;
    }

    pub fn canStart(self: RecordingState) bool {
        return self == .idle or self == .stopped;
    }
};

/// Screenshot result
pub const ScreenshotResult = struct {
    data: []u8,
    width: u32,
    height: u32,
    format: ImageFormat,
    timestamp: u64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32, format: ImageFormat) !ScreenshotResult {
        // Estimate size based on format
        const size = width * height * 4; // RGBA
        const data = try allocator.alloc(u8, size);
        return .{
            .data = data,
            .width = width,
            .height = height,
            .format = format,
            .timestamp = getCurrentTimestamp(),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ScreenshotResult) void {
        self.allocator.free(self.data);
    }

    pub fn sizeBytes(self: *const ScreenshotResult) usize {
        return self.data.len;
    }

    fn getCurrentTimestamp() u64 {
        const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
        return @intCast(ts.sec * 1000 + @divTrunc(ts.nsec, 1_000_000));
    }
};

/// Recording session
pub const RecordingSession = struct {
    id: u64,
    state: RecordingState,
    settings: RecordingSettings,
    output_path: ?[]const u8,
    start_time: u64,
    duration_ms: u64,
    frames_captured: u64,
    bytes_written: u64,

    pub fn init(id: u64, settings: RecordingSettings) RecordingSession {
        return .{
            .id = id,
            .state = .idle,
            .settings = settings,
            .output_path = null,
            .start_time = 0,
            .duration_ms = 0,
            .frames_captured = 0,
            .bytes_written = 0,
        };
    }

    pub fn start(self: *RecordingSession, output_path: []const u8) !void {
        if (!self.state.canStart()) return error.InvalidState;
        self.state = .starting;
        self.output_path = output_path;
        self.start_time = getCurrentTimestamp();
        self.state = .recording;
    }

    pub fn pause(self: *RecordingSession) void {
        if (self.state == .recording) {
            self.state = .paused;
        }
    }

    pub fn resume_recording(self: *RecordingSession) void {
        if (self.state == .paused) {
            self.state = .recording;
        }
    }

    pub fn stop(self: *RecordingSession) void {
        if (self.state.isActive()) {
            self.state = .stopping;
            self.duration_ms = getCurrentTimestamp() - self.start_time;
            self.state = .stopped;
        }
    }

    pub fn updateStats(self: *RecordingSession, frames: u64, bytes: u64) void {
        self.frames_captured = frames;
        self.bytes_written = bytes;
        if (self.state == .recording) {
            self.duration_ms = getCurrentTimestamp() - self.start_time;
        }
    }

    pub fn getDurationSeconds(self: *const RecordingSession) f64 {
        return @as(f64, @floatFromInt(self.duration_ms)) / 1000.0;
    }

    pub fn getAverageFrameRate(self: *const RecordingSession) f32 {
        if (self.duration_ms == 0) return 0;
        return @as(f32, @floatFromInt(self.frames_captured)) / (@as(f32, @floatFromInt(self.duration_ms)) / 1000.0);
    }

    fn getCurrentTimestamp() u64 {
        const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
        return @intCast(ts.sec * 1000 + @divTrunc(ts.nsec, 1_000_000));
    }
};

/// Screen capture permission status
pub const PermissionStatus = enum {
    not_determined,
    authorized,
    denied,
    restricted,

    pub fn toString(self: PermissionStatus) []const u8 {
        return switch (self) {
            .not_determined => "Not Determined",
            .authorized => "Authorized",
            .denied => "Denied",
            .restricted => "Restricted",
        };
    }

    pub fn isGranted(self: PermissionStatus) bool {
        return self == .authorized;
    }
};

/// Screen capture manager
pub const ScreenCaptureManager = struct {
    allocator: std.mem.Allocator,
    displays: std.ArrayListUnmanaged(DisplayInfo),
    windows: std.ArrayListUnmanaged(WindowInfo),
    active_session: ?RecordingSession,
    permission_status: PermissionStatus,
    next_session_id: u64,

    pub fn init(allocator: std.mem.Allocator) ScreenCaptureManager {
        return .{
            .allocator = allocator,
            .displays = .{},
            .windows = .{},
            .active_session = null,
            .permission_status = .not_determined,
            .next_session_id = 1,
        };
    }

    pub fn deinit(self: *ScreenCaptureManager) void {
        self.displays.deinit(self.allocator);
        self.windows.deinit(self.allocator);
    }

    pub fn refreshDisplays(self: *ScreenCaptureManager) !void {
        self.displays.clearRetainingCapacity();
        // Platform-specific display enumeration would happen here
        // For now, add a mock primary display
        try self.displays.append(self.allocator, DisplayInfo.init(1, 1920, 1080).primary());
    }

    pub fn refreshWindows(self: *ScreenCaptureManager) !void {
        self.windows.clearRetainingCapacity();
        // Platform-specific window enumeration would happen here
    }

    pub fn takeScreenshot(self: *ScreenCaptureManager, settings: ScreenshotSettings) !ScreenshotResult {
        if (!self.permission_status.isGranted()) return error.PermissionDenied;

        const width: u32 = if (settings.region) |r| r.width else 1920;
        const height: u32 = if (settings.region) |r| r.height else 1080;

        return ScreenshotResult.init(self.allocator, width, height, settings.format);
    }

    pub fn startRecording(self: *ScreenCaptureManager, settings: RecordingSettings, output_path: []const u8) !*RecordingSession {
        if (!self.permission_status.isGranted()) return error.PermissionDenied;
        if (self.active_session != null) return error.RecordingInProgress;

        const id = self.next_session_id;
        self.next_session_id += 1;

        self.active_session = RecordingSession.init(id, settings);
        try self.active_session.?.start(output_path);

        return &self.active_session.?;
    }

    pub fn stopRecording(self: *ScreenCaptureManager) ?RecordingSession {
        if (self.active_session) |*session| {
            session.stop();
            const result = session.*;
            self.active_session = null;
            return result;
        }
        return null;
    }

    pub fn isRecording(self: *const ScreenCaptureManager) bool {
        if (self.active_session) |session| {
            return session.state.isActive();
        }
        return false;
    }

    pub fn requestPermission(self: *ScreenCaptureManager) void {
        // Platform-specific permission request would happen here
        self.permission_status = .authorized;
    }

    pub fn displayCount(self: *const ScreenCaptureManager) usize {
        return self.displays.items.len;
    }

    pub fn windowCount(self: *const ScreenCaptureManager) usize {
        return self.windows.items.len;
    }

    pub fn getPrimaryDisplay(self: *const ScreenCaptureManager) ?DisplayInfo {
        for (self.displays.items) |display| {
            if (display.is_primary) return display;
        }
        if (self.displays.items.len > 0) {
            return self.displays.items[0];
        }
        return null;
    }
};

/// Check if screen capture is available
pub fn isScreenCaptureAvailable() bool {
    return true; // Stub for platform check
}

/// Get the current capture platform
pub fn currentPlatform() CapturePlatform {
    return .screen_capture_kit; // Would detect at runtime
}

// ============================================================================
// Tests
// ============================================================================

test "CapturePlatform properties" {
    try std.testing.expectEqualStrings("ReplayKit", CapturePlatform.replay_kit.toString());
    try std.testing.expect(CapturePlatform.replay_kit.supportsAudio());
    try std.testing.expect(!CapturePlatform.replay_kit.supportsWindowCapture());
    try std.testing.expect(CapturePlatform.screen_capture_kit.supportsWindowCapture());
}

test "CaptureType toString" {
    try std.testing.expectEqualStrings("Screenshot", CaptureType.screenshot.toString());
}

test "CaptureSource toString" {
    try std.testing.expectEqualStrings("Window", CaptureSource.window.toString());
}

test "ImageFormat properties" {
    try std.testing.expectEqualStrings(".png", ImageFormat.png.fileExtension());
    try std.testing.expectEqualStrings("image/png", ImageFormat.png.mimeType());
    try std.testing.expect(ImageFormat.png.supportsTransparency());
    try std.testing.expect(!ImageFormat.jpeg.supportsTransparency());
}

test "VideoCodec properties" {
    try std.testing.expectEqualStrings("H.264", VideoCodec.h264.toString());
    try std.testing.expect(VideoCodec.h264.isHardwareAccelerated());
    try std.testing.expect(!VideoCodec.vp9.isHardwareAccelerated());
}

test "AudioCodec properties" {
    try std.testing.expectEqualStrings("AAC", AudioCodec.aac.toString());
    try std.testing.expect(!AudioCodec.aac.isLossless());
    try std.testing.expect(AudioCodec.flac.isLossless());
}

test "ContainerFormat properties" {
    try std.testing.expectEqualStrings(".mp4", ContainerFormat.mp4.fileExtension());
    try std.testing.expectEqualStrings("video/mp4", ContainerFormat.mp4.mimeType());
}

test "CaptureRegion operations" {
    const region = CaptureRegion.init(100, 200, 800, 600);
    try std.testing.expectEqual(@as(u64, 480000), region.area());
    try std.testing.expect(region.contains(150, 250));
    try std.testing.expect(!region.contains(50, 50));
}

test "CaptureRegion aspectRatio" {
    const region = CaptureRegion.init(0, 0, 1920, 1080);
    const ratio = region.aspectRatio();
    try std.testing.expect(ratio > 1.77 and ratio < 1.78);
}

test "CaptureRegion scale" {
    const region = CaptureRegion.init(0, 0, 100, 100);
    const scaled = region.scale(2.0);
    try std.testing.expectEqual(@as(u32, 200), scaled.width);
    try std.testing.expectEqual(@as(u32, 200), scaled.height);
}

test "DisplayInfo builder" {
    const display = DisplayInfo.init(1, 1920, 1080)
        .withName("Main Display")
        .withScale(2.0)
        .primary();
    try std.testing.expectEqualStrings("Main Display", display.name.?);
    try std.testing.expect(display.is_primary);
    try std.testing.expectEqual(@as(u32, 3840), display.getPhysicalWidth());
}

test "DisplayInfo toRegion" {
    const display = DisplayInfo.init(1, 1920, 1080);
    const region = display.toRegion();
    try std.testing.expectEqual(@as(u32, 1920), region.width);
}

test "WindowInfo builder" {
    const window = WindowInfo.init(123)
        .withTitle("Test Window")
        .withApp("TestApp")
        .withBounds(100, 100, 800, 600);
    try std.testing.expectEqualStrings("Test Window", window.title.?);
    try std.testing.expect(window.isVisible());
}

test "WindowInfo visibility" {
    var window = WindowInfo.init(1);
    window.is_minimized = true;
    try std.testing.expect(!window.isVisible());
}

test "ScreenshotSettings builder" {
    const settings = ScreenshotSettings.defaults()
        .withFormat(.jpeg)
        .withQuality(0.8)
        .withCursor(true);
    try std.testing.expectEqual(ImageFormat.jpeg, settings.format);
    try std.testing.expectEqual(@as(f32, 0.8), settings.quality);
    try std.testing.expect(settings.include_cursor);
}

test "RecordingSettings defaults" {
    const settings = RecordingSettings.defaults();
    try std.testing.expectEqual(VideoCodec.h264, settings.video_codec);
    try std.testing.expectEqual(@as(f32, 30.0), settings.frame_rate);
}

test "RecordingSettings highQuality" {
    const settings = RecordingSettings.highQuality();
    try std.testing.expectEqual(VideoCodec.h265, settings.video_codec);
    try std.testing.expectEqual(@as(f32, 60.0), settings.frame_rate);
}

test "RecordingSettings estimatedFileSize" {
    const settings = RecordingSettings.defaults();
    const size = settings.estimatedFileSizePerMinute();
    try std.testing.expect(size > 0);
}

test "RecordingState properties" {
    try std.testing.expectEqualStrings("Recording", RecordingState.recording.toString());
    try std.testing.expect(RecordingState.recording.isActive());
    try std.testing.expect(RecordingState.idle.canStart());
    try std.testing.expect(!RecordingState.recording.canStart());
}

test "RecordingSession lifecycle" {
    var session = RecordingSession.init(1, RecordingSettings.defaults());
    try std.testing.expectEqual(RecordingState.idle, session.state);

    try session.start("/tmp/test.mp4");
    try std.testing.expectEqual(RecordingState.recording, session.state);

    session.pause();
    try std.testing.expectEqual(RecordingState.paused, session.state);

    session.resume_recording();
    try std.testing.expectEqual(RecordingState.recording, session.state);

    session.stop();
    try std.testing.expectEqual(RecordingState.stopped, session.state);
}

test "RecordingSession stats" {
    var session = RecordingSession.init(1, RecordingSettings.defaults());
    session.updateStats(300, 10000000);
    try std.testing.expectEqual(@as(u64, 300), session.frames_captured);
}

test "PermissionStatus properties" {
    try std.testing.expectEqualStrings("Authorized", PermissionStatus.authorized.toString());
    try std.testing.expect(PermissionStatus.authorized.isGranted());
    try std.testing.expect(!PermissionStatus.denied.isGranted());
}

test "ScreenCaptureManager init" {
    var manager = ScreenCaptureManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectEqual(@as(usize, 0), manager.displayCount());
    try std.testing.expect(!manager.isRecording());
}

test "ScreenCaptureManager refreshDisplays" {
    var manager = ScreenCaptureManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.refreshDisplays();
    try std.testing.expectEqual(@as(usize, 1), manager.displayCount());

    const primary = manager.getPrimaryDisplay();
    try std.testing.expect(primary != null);
}

test "ScreenCaptureManager permission" {
    var manager = ScreenCaptureManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectEqual(PermissionStatus.not_determined, manager.permission_status);
    manager.requestPermission();
    try std.testing.expectEqual(PermissionStatus.authorized, manager.permission_status);
}

test "isScreenCaptureAvailable" {
    try std.testing.expect(isScreenCaptureAvailable());
}

test "currentPlatform" {
    try std.testing.expectEqual(CapturePlatform.screen_capture_kit, currentPlatform());
}
