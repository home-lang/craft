//! Cross-platform Picture-in-Picture module
//! Provides abstractions for AVKit PiP (iOS/macOS) and Android PiP mode

const std = @import("std");

/// PiP platform
pub const PiPPlatform = enum {
    avkit, // iOS 9+, macOS 10.15+
    android_pip, // Android 8.0+
    web_pip, // Document PiP API
    windows_compact_overlay, // Windows 10+

    pub fn toString(self: PiPPlatform) []const u8 {
        return switch (self) {
            .avkit => "AVKit PiP",
            .android_pip => "Android PiP",
            .web_pip => "Web PiP",
            .windows_compact_overlay => "Compact Overlay",
        };
    }

    pub fn supportsCustomControls(self: PiPPlatform) bool {
        return switch (self) {
            .avkit, .android_pip => true,
            .web_pip, .windows_compact_overlay => false,
        };
    }

    pub fn supportsAutomatic(self: PiPPlatform) bool {
        return switch (self) {
            .avkit, .android_pip => true,
            .web_pip, .windows_compact_overlay => false,
        };
    }
};

/// PiP state
pub const PiPState = enum {
    inactive,
    activating,
    active,
    deactivating,
    suspended,

    pub fn toString(self: PiPState) []const u8 {
        return switch (self) {
            .inactive => "Inactive",
            .activating => "Activating",
            .active => "Active",
            .deactivating => "Deactivating",
            .suspended => "Suspended",
        };
    }

    pub fn isActive(self: PiPState) bool {
        return self == .active or self == .suspended;
    }

    pub fn canActivate(self: PiPState) bool {
        return self == .inactive;
    }

    pub fn canDeactivate(self: PiPState) bool {
        return self == .active or self == .suspended;
    }
};

/// PiP window position
pub const PiPPosition = enum {
    top_left,
    top_right,
    bottom_left,
    bottom_right,
    custom,

    pub fn toString(self: PiPPosition) []const u8 {
        return switch (self) {
            .top_left => "Top Left",
            .top_right => "Top Right",
            .bottom_left => "Bottom Left",
            .bottom_right => "Bottom Right",
            .custom => "Custom",
        };
    }

    pub fn defaultOffset(self: PiPPosition, screen_width: u32, screen_height: u32, pip_width: u32, pip_height: u32) struct { x: i32, y: i32 } {
        const margin: i32 = 20;
        return switch (self) {
            .top_left => .{ .x = margin, .y = margin },
            .top_right => .{ .x = @as(i32, @intCast(screen_width)) - @as(i32, @intCast(pip_width)) - margin, .y = margin },
            .bottom_left => .{ .x = margin, .y = @as(i32, @intCast(screen_height)) - @as(i32, @intCast(pip_height)) - margin },
            .bottom_right => .{ .x = @as(i32, @intCast(screen_width)) - @as(i32, @intCast(pip_width)) - margin, .y = @as(i32, @intCast(screen_height)) - @as(i32, @intCast(pip_height)) - margin },
            .custom => .{ .x = 0, .y = 0 },
        };
    }
};

/// PiP aspect ratio
pub const AspectRatio = struct {
    width: u32,
    height: u32,

    pub const ratio_16_9 = AspectRatio{ .width = 16, .height = 9 };
    pub const ratio_4_3 = AspectRatio{ .width = 4, .height = 3 };
    pub const ratio_1_1 = AspectRatio{ .width = 1, .height = 1 };
    pub const ratio_9_16 = AspectRatio{ .width = 9, .height = 16 };
    pub const ratio_21_9 = AspectRatio{ .width = 21, .height = 9 };

    pub fn init(width: u32, height: u32) AspectRatio {
        return .{ .width = width, .height = height };
    }

    pub fn fromDimensions(width: u32, height: u32) AspectRatio {
        const gcd_val = gcd(width, height);
        return .{
            .width = width / gcd_val,
            .height = height / gcd_val,
        };
    }

    fn gcd(a: u32, b: u32) u32 {
        var x = a;
        var y = b;
        while (y != 0) {
            const temp = y;
            y = x % y;
            x = temp;
        }
        return x;
    }

    pub fn toFloat(self: AspectRatio) f32 {
        if (self.height == 0) return 0;
        return @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(self.height));
    }

    pub fn calculateHeight(self: AspectRatio, width: u32) u32 {
        if (self.width == 0) return 0;
        return width * self.height / self.width;
    }

    pub fn calculateWidth(self: AspectRatio, height: u32) u32 {
        if (self.height == 0) return 0;
        return height * self.width / self.height;
    }

    pub fn isLandscape(self: AspectRatio) bool {
        return self.width > self.height;
    }

    pub fn isPortrait(self: AspectRatio) bool {
        return self.height > self.width;
    }

    pub fn isSquare(self: AspectRatio) bool {
        return self.width == self.height;
    }
};

/// PiP window bounds
pub const PiPBounds = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,

    pub fn init(x: i32, y: i32, width: u32, height: u32) PiPBounds {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }

    pub fn withSize(width: u32, height: u32) PiPBounds {
        return .{ .x = 0, .y = 0, .width = width, .height = height };
    }

    pub fn aspectRatio(self: PiPBounds) AspectRatio {
        return AspectRatio.fromDimensions(self.width, self.height);
    }

    pub fn center(self: PiPBounds) struct { x: i32, y: i32 } {
        return .{
            .x = self.x + @as(i32, @intCast(self.width / 2)),
            .y = self.y + @as(i32, @intCast(self.height / 2)),
        };
    }

    pub fn scale(self: PiPBounds, factor: f32) PiPBounds {
        return .{
            .x = self.x,
            .y = self.y,
            .width = @intFromFloat(@as(f32, @floatFromInt(self.width)) * factor),
            .height = @intFromFloat(@as(f32, @floatFromInt(self.height)) * factor),
        };
    }

    pub fn moveTo(self: PiPBounds, x: i32, y: i32) PiPBounds {
        var bounds = self;
        bounds.x = x;
        bounds.y = y;
        return bounds;
    }

    pub fn area(self: PiPBounds) u64 {
        return @as(u64, self.width) * @as(u64, self.height);
    }
};

/// PiP playback control type
pub const PlaybackControl = enum {
    play_pause,
    skip_forward,
    skip_backward,
    next_track,
    previous_track,
    close,
    restore,
    custom,

    pub fn toString(self: PlaybackControl) []const u8 {
        return switch (self) {
            .play_pause => "Play/Pause",
            .skip_forward => "Skip Forward",
            .skip_backward => "Skip Backward",
            .next_track => "Next Track",
            .previous_track => "Previous Track",
            .close => "Close",
            .restore => "Restore",
            .custom => "Custom",
        };
    }

    pub fn sfSymbol(self: PlaybackControl) []const u8 {
        return switch (self) {
            .play_pause => "playpause.fill",
            .skip_forward => "goforward.15",
            .skip_backward => "gobackward.15",
            .next_track => "forward.end.fill",
            .previous_track => "backward.end.fill",
            .close => "xmark",
            .restore => "arrow.up.left.and.arrow.down.right",
            .custom => "ellipsis",
        };
    }
};

/// Content type for PiP
pub const ContentType = enum {
    video,
    live_stream,
    video_call,
    screen_share,
    camera,

    pub fn toString(self: ContentType) []const u8 {
        return switch (self) {
            .video => "Video",
            .live_stream => "Live Stream",
            .video_call => "Video Call",
            .screen_share => "Screen Share",
            .camera => "Camera",
        };
    }

    pub fn supportsSeek(self: ContentType) bool {
        return self == .video;
    }

    pub fn isLive(self: ContentType) bool {
        return self == .live_stream or self == .video_call or self == .screen_share;
    }
};

/// PiP controller configuration
pub const PiPConfig = struct {
    preferred_aspect_ratio: AspectRatio,
    min_size: PiPBounds,
    max_size: PiPBounds,
    initial_position: PiPPosition,
    allows_resizing: bool,
    allows_repositioning: bool,
    auto_enter_on_background: bool,
    requires_linear_playback: bool,
    controls_enabled: bool,
    seamless_resize: bool,

    pub fn defaults() PiPConfig {
        return .{
            .preferred_aspect_ratio = AspectRatio.ratio_16_9,
            .min_size = PiPBounds.withSize(150, 84),
            .max_size = PiPBounds.withSize(500, 281),
            .initial_position = .bottom_right,
            .allows_resizing = true,
            .allows_repositioning = true,
            .auto_enter_on_background = true,
            .requires_linear_playback = false,
            .controls_enabled = true,
            .seamless_resize = true,
        };
    }

    pub fn forVideoCall() PiPConfig {
        return .{
            .preferred_aspect_ratio = AspectRatio.ratio_4_3,
            .min_size = PiPBounds.withSize(100, 75),
            .max_size = PiPBounds.withSize(300, 225),
            .initial_position = .top_right,
            .allows_resizing = true,
            .allows_repositioning = true,
            .auto_enter_on_background = true,
            .requires_linear_playback = true,
            .controls_enabled = false,
            .seamless_resize = true,
        };
    }

    pub fn withAspectRatio(self: PiPConfig, ratio: AspectRatio) PiPConfig {
        var config = self;
        config.preferred_aspect_ratio = ratio;
        return config;
    }

    pub fn withPosition(self: PiPConfig, position: PiPPosition) PiPConfig {
        var config = self;
        config.initial_position = position;
        return config;
    }

    pub fn withAutoEnter(self: PiPConfig, enabled: bool) PiPConfig {
        var config = self;
        config.auto_enter_on_background = enabled;
        return config;
    }

    pub fn withControls(self: PiPConfig, enabled: bool) PiPConfig {
        var config = self;
        config.controls_enabled = enabled;
        return config;
    }
};

/// PiP event types
pub const PiPEvent = enum {
    will_start,
    did_start,
    will_stop,
    did_stop,
    failed_to_start,
    restore_user_interface,
    size_changed,
    position_changed,
    playback_state_changed,

    pub fn toString(self: PiPEvent) []const u8 {
        return switch (self) {
            .will_start => "Will Start",
            .did_start => "Did Start",
            .will_stop => "Will Stop",
            .did_stop => "Did Stop",
            .failed_to_start => "Failed to Start",
            .restore_user_interface => "Restore UI",
            .size_changed => "Size Changed",
            .position_changed => "Position Changed",
            .playback_state_changed => "Playback Changed",
        };
    }

    pub fn isLifecycle(self: PiPEvent) bool {
        return switch (self) {
            .will_start, .did_start, .will_stop, .did_stop, .failed_to_start => true,
            else => false,
        };
    }
};

/// Playback state
pub const PlaybackState = enum {
    idle,
    playing,
    paused,
    buffering,
    ended,

    pub fn toString(self: PlaybackState) []const u8 {
        return switch (self) {
            .idle => "Idle",
            .playing => "Playing",
            .paused => "Paused",
            .buffering => "Buffering",
            .ended => "Ended",
        };
    }

    pub fn isPlaying(self: PlaybackState) bool {
        return self == .playing;
    }
};

/// PiP controller
pub const PiPController = struct {
    allocator: std.mem.Allocator,
    state: PiPState,
    config: PiPConfig,
    content_type: ContentType,
    current_bounds: PiPBounds,
    playback_state: PlaybackState,
    current_time: f64, // seconds
    duration: f64, // seconds
    is_muted: bool,
    volume: f32, // 0.0 - 1.0

    pub fn init(allocator: std.mem.Allocator, config: PiPConfig) PiPController {
        return .{
            .allocator = allocator,
            .state = .inactive,
            .config = config,
            .content_type = .video,
            .current_bounds = config.min_size,
            .playback_state = .idle,
            .current_time = 0,
            .duration = 0,
            .is_muted = false,
            .volume = 1.0,
        };
    }

    pub fn deinit(self: *PiPController) void {
        _ = self;
        // Cleanup resources if needed
    }

    pub fn start(self: *PiPController) !void {
        if (!self.state.canActivate()) return error.InvalidState;
        self.state = .activating;
        // Platform-specific PiP activation would happen here
        self.state = .active;
    }

    pub fn stop(self: *PiPController) !void {
        if (!self.state.canDeactivate()) return error.InvalidState;
        self.state = .deactivating;
        // Platform-specific PiP deactivation would happen here
        self.state = .inactive;
    }

    pub fn suspend_pip(self: *PiPController) void {
        if (self.state == .active) {
            self.state = .suspended;
        }
    }

    pub fn resume_pip(self: *PiPController) void {
        if (self.state == .suspended) {
            self.state = .active;
        }
    }

    pub fn play(self: *PiPController) void {
        self.playback_state = .playing;
    }

    pub fn pause(self: *PiPController) void {
        self.playback_state = .paused;
    }

    pub fn togglePlayPause(self: *PiPController) void {
        if (self.playback_state.isPlaying()) {
            self.pause();
        } else {
            self.play();
        }
    }

    pub fn seek(self: *PiPController, time: f64) void {
        if (self.content_type.supportsSeek()) {
            self.current_time = std.math.clamp(time, 0, self.duration);
        }
    }

    pub fn skipForward(self: *PiPController, seconds: f64) void {
        self.seek(self.current_time + seconds);
    }

    pub fn skipBackward(self: *PiPController, seconds: f64) void {
        self.seek(self.current_time - seconds);
    }

    pub fn setVolume(self: *PiPController, vol: f32) void {
        self.volume = std.math.clamp(vol, 0.0, 1.0);
    }

    pub fn mute(self: *PiPController) void {
        self.is_muted = true;
    }

    pub fn unmute(self: *PiPController) void {
        self.is_muted = false;
    }

    pub fn toggleMute(self: *PiPController) void {
        self.is_muted = !self.is_muted;
    }

    pub fn resize(self: *PiPController, width: u32, height: u32) void {
        if (!self.config.allows_resizing) return;

        const min_w = self.config.min_size.width;
        const max_w = self.config.max_size.width;
        const min_h = self.config.min_size.height;
        const max_h = self.config.max_size.height;

        self.current_bounds.width = std.math.clamp(width, min_w, max_w);
        self.current_bounds.height = std.math.clamp(height, min_h, max_h);
    }

    pub fn moveTo(self: *PiPController, x: i32, y: i32) void {
        if (!self.config.allows_repositioning) return;
        self.current_bounds = self.current_bounds.moveTo(x, y);
    }

    pub fn setContentType(self: *PiPController, content_type: ContentType) void {
        self.content_type = content_type;
    }

    pub fn setDuration(self: *PiPController, dur: f64) void {
        self.duration = @max(0, dur);
    }

    pub fn getProgress(self: *const PiPController) f32 {
        if (self.duration == 0) return 0;
        return @floatCast(self.current_time / self.duration);
    }

    pub fn isActive(self: *const PiPController) bool {
        return self.state.isActive();
    }

    pub fn isPossible(_: *const PiPController) bool {
        // Would check platform support and permissions
        return true;
    }
};

/// PiP permission status
pub const PermissionStatus = enum {
    not_determined,
    authorized,
    denied,

    pub fn toString(self: PermissionStatus) []const u8 {
        return switch (self) {
            .not_determined => "Not Determined",
            .authorized => "Authorized",
            .denied => "Denied",
        };
    }

    pub fn isGranted(self: PermissionStatus) bool {
        return self == .authorized;
    }
};

/// Check if PiP is supported
pub fn isPiPSupported() bool {
    return true; // Stub for platform check
}

/// Get current PiP platform
pub fn currentPlatform() PiPPlatform {
    return .avkit; // Would detect at runtime
}

/// Get minimum supported OS version
pub fn minimumOSVersion() []const u8 {
    return "iOS 9.0 / macOS 10.15 / Android 8.0";
}

// ============================================================================
// Tests
// ============================================================================

test "PiPPlatform properties" {
    try std.testing.expectEqualStrings("AVKit PiP", PiPPlatform.avkit.toString());
    try std.testing.expect(PiPPlatform.avkit.supportsCustomControls());
    try std.testing.expect(PiPPlatform.avkit.supportsAutomatic());
}

test "PiPState properties" {
    try std.testing.expectEqualStrings("Active", PiPState.active.toString());
    try std.testing.expect(PiPState.active.isActive());
    try std.testing.expect(PiPState.inactive.canActivate());
    try std.testing.expect(PiPState.active.canDeactivate());
}

test "PiPPosition defaultOffset" {
    const offset = PiPPosition.bottom_right.defaultOffset(1920, 1080, 300, 200);
    // x = 1920 - 300 - 20 = 1600, y = 1080 - 200 - 20 = 860
    try std.testing.expectEqual(@as(i32, 1600), offset.x);
    try std.testing.expectEqual(@as(i32, 860), offset.y);
}

test "AspectRatio presets" {
    try std.testing.expect(AspectRatio.ratio_16_9.toFloat() > 1.77);
    try std.testing.expect(AspectRatio.ratio_16_9.isLandscape());
    try std.testing.expect(AspectRatio.ratio_9_16.isPortrait());
    try std.testing.expect(AspectRatio.ratio_1_1.isSquare());
}

test "AspectRatio fromDimensions" {
    const ratio = AspectRatio.fromDimensions(1920, 1080);
    try std.testing.expectEqual(@as(u32, 16), ratio.width);
    try std.testing.expectEqual(@as(u32, 9), ratio.height);
}

test "AspectRatio calculations" {
    const ratio = AspectRatio.ratio_16_9;
    try std.testing.expectEqual(@as(u32, 225), ratio.calculateHeight(400));
    try std.testing.expectEqual(@as(u32, 320), ratio.calculateWidth(180));
}

test "PiPBounds operations" {
    const bounds = PiPBounds.init(100, 200, 300, 200);
    const center = bounds.center();
    try std.testing.expectEqual(@as(i32, 250), center.x);
    try std.testing.expectEqual(@as(i32, 300), center.y);
}

test "PiPBounds scale" {
    const bounds = PiPBounds.withSize(200, 100);
    const scaled = bounds.scale(1.5);
    try std.testing.expectEqual(@as(u32, 300), scaled.width);
    try std.testing.expectEqual(@as(u32, 150), scaled.height);
}

test "PiPBounds moveTo" {
    const bounds = PiPBounds.init(0, 0, 100, 100);
    const moved = bounds.moveTo(50, 60);
    try std.testing.expectEqual(@as(i32, 50), moved.x);
    try std.testing.expectEqual(@as(i32, 60), moved.y);
}

test "PlaybackControl symbols" {
    try std.testing.expectEqualStrings("playpause.fill", PlaybackControl.play_pause.sfSymbol());
    try std.testing.expectEqualStrings("Play/Pause", PlaybackControl.play_pause.toString());
}

test "ContentType properties" {
    try std.testing.expect(ContentType.video.supportsSeek());
    try std.testing.expect(!ContentType.live_stream.supportsSeek());
    try std.testing.expect(ContentType.live_stream.isLive());
}

test "PiPConfig defaults" {
    const config = PiPConfig.defaults();
    try std.testing.expectEqual(PiPPosition.bottom_right, config.initial_position);
    try std.testing.expect(config.auto_enter_on_background);
}

test "PiPConfig forVideoCall" {
    const config = PiPConfig.forVideoCall();
    try std.testing.expectEqual(PiPPosition.top_right, config.initial_position);
    try std.testing.expect(!config.controls_enabled);
}

test "PiPConfig builder" {
    const config = PiPConfig.defaults()
        .withPosition(.top_left)
        .withAutoEnter(false)
        .withControls(false);
    try std.testing.expectEqual(PiPPosition.top_left, config.initial_position);
    try std.testing.expect(!config.auto_enter_on_background);
}

test "PiPEvent properties" {
    try std.testing.expectEqualStrings("Did Start", PiPEvent.did_start.toString());
    try std.testing.expect(PiPEvent.will_start.isLifecycle());
    try std.testing.expect(!PiPEvent.size_changed.isLifecycle());
}

test "PlaybackState properties" {
    try std.testing.expectEqualStrings("Playing", PlaybackState.playing.toString());
    try std.testing.expect(PlaybackState.playing.isPlaying());
    try std.testing.expect(!PlaybackState.paused.isPlaying());
}

test "PiPController init" {
    var controller = PiPController.init(std.testing.allocator, PiPConfig.defaults());
    defer controller.deinit();

    try std.testing.expectEqual(PiPState.inactive, controller.state);
    try std.testing.expect(!controller.isActive());
}

test "PiPController lifecycle" {
    var controller = PiPController.init(std.testing.allocator, PiPConfig.defaults());
    defer controller.deinit();

    try controller.start();
    try std.testing.expect(controller.isActive());

    try controller.stop();
    try std.testing.expect(!controller.isActive());
}

test "PiPController playback" {
    var controller = PiPController.init(std.testing.allocator, PiPConfig.defaults());
    defer controller.deinit();

    controller.setDuration(300);
    controller.play();
    try std.testing.expectEqual(PlaybackState.playing, controller.playback_state);

    controller.togglePlayPause();
    try std.testing.expectEqual(PlaybackState.paused, controller.playback_state);
}

test "PiPController seek" {
    var controller = PiPController.init(std.testing.allocator, PiPConfig.defaults());
    defer controller.deinit();

    controller.setDuration(300);
    controller.seek(150);
    try std.testing.expectEqual(@as(f64, 150), controller.current_time);

    controller.skipForward(30);
    try std.testing.expectEqual(@as(f64, 180), controller.current_time);
}

test "PiPController volume" {
    var controller = PiPController.init(std.testing.allocator, PiPConfig.defaults());
    defer controller.deinit();

    controller.setVolume(0.5);
    try std.testing.expectEqual(@as(f32, 0.5), controller.volume);

    controller.mute();
    try std.testing.expect(controller.is_muted);

    controller.toggleMute();
    try std.testing.expect(!controller.is_muted);
}

test "PiPController resize" {
    var controller = PiPController.init(std.testing.allocator, PiPConfig.defaults());
    defer controller.deinit();

    controller.resize(250, 150);
    try std.testing.expectEqual(@as(u32, 250), controller.current_bounds.width);
}

test "PiPController progress" {
    var controller = PiPController.init(std.testing.allocator, PiPConfig.defaults());
    defer controller.deinit();

    controller.setDuration(100);
    controller.seek(50);
    const progress = controller.getProgress();
    try std.testing.expectEqual(@as(f32, 0.5), progress);
}

test "PermissionStatus properties" {
    try std.testing.expect(PermissionStatus.authorized.isGranted());
    try std.testing.expect(!PermissionStatus.denied.isGranted());
}

test "isPiPSupported" {
    try std.testing.expect(isPiPSupported());
}

test "currentPlatform" {
    try std.testing.expectEqual(PiPPlatform.avkit, currentPlatform());
}
