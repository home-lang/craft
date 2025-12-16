const std = @import("std");
const builtin = @import("builtin");

/// Audio Module
/// Provides cross-platform audio playback, system sounds, and haptic feedback.
/// Supports macOS (AVFoundation/AppKit), Linux (PulseAudio), Windows (WinMM).

// =============================================================================
// Audio Types
// =============================================================================

/// Audio format for playback
pub const AudioFormat = enum {
    wav,
    mp3,
    aac,
    ogg,
    flac,
    m4a,
    unknown,

    pub fn fromExtension(ext: []const u8) AudioFormat {
        if (std.mem.eql(u8, ext, "wav")) return .wav;
        if (std.mem.eql(u8, ext, "mp3")) return .mp3;
        if (std.mem.eql(u8, ext, "aac")) return .aac;
        if (std.mem.eql(u8, ext, "ogg")) return .ogg;
        if (std.mem.eql(u8, ext, "flac")) return .flac;
        if (std.mem.eql(u8, ext, "m4a")) return .m4a;
        return .unknown;
    }

    pub fn mimeType(self: AudioFormat) []const u8 {
        return switch (self) {
            .wav => "audio/wav",
            .mp3 => "audio/mpeg",
            .aac => "audio/aac",
            .ogg => "audio/ogg",
            .flac => "audio/flac",
            .m4a => "audio/mp4",
            .unknown => "application/octet-stream",
        };
    }
};

/// Audio playback state
pub const PlaybackState = enum {
    stopped,
    playing,
    paused,
    loading,
    error_state,
};

/// Audio error types
pub const AudioError = error{
    FileNotFound,
    UnsupportedFormat,
    PlaybackFailed,
    DeviceNotAvailable,
    InvalidVolume,
    SystemSoundNotFound,
    HapticNotSupported,
    AlreadyPlaying,
    NotPlaying,
    InitializationFailed,
};

// =============================================================================
// System Sounds
// =============================================================================

/// Pre-defined system sounds (macOS names, mapped to other platforms)
pub const SystemSound = enum {
    // Alert sounds
    basso,
    blow,
    bottle,
    frog,
    funk,
    glass,
    hero,
    morse,
    ping,
    pop,
    purr,
    sosumi,
    submarine,
    tink,

    // UI sounds
    click,
    beep,
    error_sound,
    warning,
    notification,
    success,
    failure,

    // Custom name (use name field)
    custom,

    /// Get the platform-specific sound name
    pub fn getPlatformName(self: SystemSound) []const u8 {
        return switch (builtin.os.tag) {
            .macos => self.getMacOSName(),
            .linux => self.getLinuxName(),
            .windows => self.getWindowsName(),
            else => "default",
        };
    }

    fn getMacOSName(self: SystemSound) []const u8 {
        return switch (self) {
            .basso => "Basso",
            .blow => "Blow",
            .bottle => "Bottle",
            .frog => "Frog",
            .funk => "Funk",
            .glass => "Glass",
            .hero => "Hero",
            .morse => "Morse",
            .ping => "Ping",
            .pop => "Pop",
            .purr => "Purr",
            .sosumi => "Sosumi",
            .submarine => "Submarine",
            .tink => "Tink",
            .click => "Tock",
            .beep => "Ping",
            .error_sound => "Basso",
            .warning => "Sosumi",
            .notification => "Glass",
            .success => "Hero",
            .failure => "Basso",
            .custom => "",
        };
    }

    fn getLinuxName(self: SystemSound) []const u8 {
        // XDG sound theme names
        return switch (self) {
            .basso, .error_sound, .failure => "dialog-error",
            .warning => "dialog-warning",
            .notification, .glass, .ping => "message-new-instant",
            .success, .hero => "complete",
            .click, .tink, .pop => "button-pressed",
            .beep => "bell",
            else => "bell",
        };
    }

    fn getWindowsName(self: SystemSound) []const u8 {
        // Windows system sound aliases
        return switch (self) {
            .basso, .error_sound, .failure => "SystemHand",
            .warning => "SystemExclamation",
            .notification, .glass => "SystemNotification",
            .beep, .ping => "SystemDefault",
            .success, .hero => "SystemAsterisk",
            .click, .tink, .pop => "SystemStart",
            else => "SystemDefault",
        };
    }
};

// =============================================================================
// Haptic Feedback
// =============================================================================

/// Haptic feedback types (iOS/macOS)
pub const HapticType = enum {
    // Impact feedback
    impact_light,
    impact_medium,
    impact_heavy,
    impact_rigid,
    impact_soft,

    // Notification feedback
    notification_success,
    notification_warning,
    notification_error,

    // Selection feedback
    selection_changed,

    pub fn getIntensity(self: HapticType) f32 {
        return switch (self) {
            .impact_light, .impact_soft => 0.3,
            .impact_medium, .selection_changed => 0.5,
            .impact_heavy, .impact_rigid => 0.8,
            .notification_success => 0.6,
            .notification_warning => 0.7,
            .notification_error => 0.9,
        };
    }
};

// =============================================================================
// Audio Configuration
// =============================================================================

/// Configuration for audio playback
pub const AudioConfig = struct {
    volume: f32 = 1.0, // 0.0 to 1.0
    loop: bool = false,
    loop_count: u32 = 0, // 0 = infinite when loop is true
    fade_in_ms: u32 = 0,
    fade_out_ms: u32 = 0,
    playback_rate: f32 = 1.0, // 0.5 to 2.0 typical range
    pan: f32 = 0.0, // -1.0 (left) to 1.0 (right)
    start_time_ms: u64 = 0,
    end_time_ms: u64 = 0, // 0 = play to end

    pub fn validate(self: AudioConfig) AudioError!void {
        if (self.volume < 0.0 or self.volume > 1.0) return AudioError.InvalidVolume;
        if (self.pan < -1.0 or self.pan > 1.0) return AudioError.InvalidVolume;
        if (self.playback_rate < 0.1 or self.playback_rate > 4.0) return AudioError.InvalidVolume;
    }
};

// =============================================================================
// Audio Player
// =============================================================================

/// Audio player for file playback
pub const AudioPlayer = struct {
    allocator: std.mem.Allocator,
    state: PlaybackState,
    config: AudioConfig,
    current_file: ?[]const u8,
    duration_ms: u64,
    position_ms: u64,
    native_handle: ?*anyopaque,

    // Callbacks
    on_play: ?*const fn () void,
    on_pause: ?*const fn () void,
    on_stop: ?*const fn () void,
    on_complete: ?*const fn () void,
    on_error: ?*const fn (AudioError) void,
    on_progress: ?*const fn (position_ms: u64, duration_ms: u64) void,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .state = .stopped,
            .config = .{},
            .current_file = null,
            .duration_ms = 0,
            .position_ms = 0,
            .native_handle = null,
            .on_play = null,
            .on_pause = null,
            .on_stop = null,
            .on_complete = null,
            .on_error = null,
            .on_progress = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.stop() catch {};
        if (self.current_file) |file| {
            self.allocator.free(file);
        }
    }

    /// Load an audio file for playback
    pub fn load(self: *Self, file_path: []const u8) AudioError!void {
        // Clean up previous file
        if (self.current_file) |file| {
            self.allocator.free(file);
        }

        // Store file path
        self.current_file = self.allocator.dupe(u8, file_path) catch return AudioError.InitializationFailed;
        self.state = .loading;

        // Platform-specific loading
        if (builtin.os.tag == .macos) {
            try self.loadMacOS(file_path);
        } else if (builtin.os.tag == .linux) {
            try self.loadLinux(file_path);
        } else if (builtin.os.tag == .windows) {
            try self.loadWindows(file_path);
        }

        self.state = .stopped;
    }

    /// Start playback
    pub fn play(self: *Self) AudioError!void {
        if (self.current_file == null) return AudioError.FileNotFound;
        if (self.state == .playing) return AudioError.AlreadyPlaying;

        try self.config.validate();

        if (builtin.os.tag == .macos) {
            try self.playMacOS();
        }

        self.state = .playing;
        if (self.on_play) |cb| cb();
    }

    /// Pause playback
    pub fn pause(self: *Self) AudioError!void {
        if (self.state != .playing) return AudioError.NotPlaying;

        if (builtin.os.tag == .macos) {
            self.pauseMacOS();
        }

        self.state = .paused;
        if (self.on_pause) |cb| cb();
    }

    /// Resume playback
    pub fn unpause(self: *Self) AudioError!void {
        if (self.state != .paused) return AudioError.NotPlaying;

        if (builtin.os.tag == .macos) {
            self.resumeMacOS();
        }

        self.state = .playing;
        if (self.on_play) |cb| cb();
    }

    /// Stop playback
    pub fn stop(self: *Self) AudioError!void {
        if (self.state == .stopped) return;

        if (builtin.os.tag == .macos) {
            self.stopMacOS();
        }

        self.state = .stopped;
        self.position_ms = 0;
        if (self.on_stop) |cb| cb();
    }

    /// Seek to position
    pub fn seek(self: *Self, position_ms: u64) AudioError!void {
        if (position_ms > self.duration_ms) return;

        self.position_ms = position_ms;

        if (builtin.os.tag == .macos) {
            self.seekMacOS(position_ms);
        }
    }

    /// Set volume (0.0 to 1.0)
    pub fn setVolume(self: *Self, volume: f32) AudioError!void {
        if (volume < 0.0 or volume > 1.0) return AudioError.InvalidVolume;
        self.config.volume = volume;

        if (builtin.os.tag == .macos) {
            self.setVolumeMacOS(volume);
        }
    }

    /// Get current volume
    pub fn getVolume(self: Self) f32 {
        return self.config.volume;
    }

    /// Set playback rate
    pub fn setPlaybackRate(self: *Self, rate: f32) AudioError!void {
        if (rate < 0.1 or rate > 4.0) return AudioError.InvalidVolume;
        self.config.playback_rate = rate;
    }

    /// Get playback progress (0.0 to 1.0)
    pub fn getProgress(self: Self) f32 {
        if (self.duration_ms == 0) return 0;
        return @as(f32, @floatFromInt(self.position_ms)) / @as(f32, @floatFromInt(self.duration_ms));
    }

    // Platform-specific implementations
    fn loadMacOS(self: *Self, file_path: []const u8) AudioError!void {
        const macos = @import("macos.zig");

        // Get AVAudioPlayer class
        const AVAudioPlayer = macos.getClass("AVAudioPlayer") orelse return AudioError.DeviceNotAvailable;

        // Create NSURL from file path
        const NSURLClass = macos.getClass("NSURL") orelse return AudioError.DeviceNotAvailable;
        const file_path_z = self.allocator.dupeZ(u8, file_path) catch return AudioError.InitializationFailed;
        defer self.allocator.free(file_path_z);

        const NSString = macos.getClass("NSString") orelse return AudioError.DeviceNotAvailable;
        const str_alloc = macos.msgSend0(NSString, "alloc");
        const ns_path = macos.msgSend1(str_alloc, "initWithUTF8String:", file_path_z.ptr);
        const file_url = macos.msgSend1(NSURLClass, "fileURLWithPath:", ns_path);

        if (file_url == null) return AudioError.FileNotFound;

        // Create AVAudioPlayer: [[AVAudioPlayer alloc] initWithContentsOfURL:error:]
        const player_alloc = macos.msgSend0(AVAudioPlayer, "alloc");
        const player = macos.msgSend2(player_alloc, "initWithContentsOfURL:error:", file_url, @as(?*anyopaque, null));

        if (player == null) return AudioError.UnsupportedFormat;

        // Prepare to play
        _ = macos.msgSend0(player, "prepareToPlay");

        // Get duration: [player duration] returns NSTimeInterval (double, seconds)
        const duration_sel = macos.sel("duration");
        const DurationFn = *const fn (?*anyopaque, ?*anyopaque) callconv(.c) f64;
        const duration_fn: DurationFn = @ptrCast(&macos.objc.objc_msgSend);
        const duration_seconds = duration_fn(player, duration_sel);
        self.duration_ms = @intFromFloat(duration_seconds * 1000.0);

        self.native_handle = player;
    }

    fn loadLinux(self: *Self, file_path: []const u8) AudioError!void {
        // On Linux, we use external commands for audio playback
        // Store the file path for later playback with paplay/aplay
        _ = self;
        _ = file_path;
        // File path is already stored in self.current_file
        // Actual playback will spawn a subprocess
    }

    fn loadWindows(self: *Self, file_path: []const u8) AudioError!void {
        // On Windows, we'll use MCI (Media Control Interface) commands
        // Store the file path for later playback
        _ = self;
        _ = file_path;
        // File path is already stored in self.current_file
    }

    fn playMacOS(self: *Self) AudioError!void {
        if (self.native_handle) |player| {
            const macos = @import("macos.zig");

            // Set volume
            const SetVolumeFn = *const fn (?*anyopaque, ?*anyopaque, f32) callconv(.c) void;
            const set_volume_fn: SetVolumeFn = @ptrCast(&macos.objc.objc_msgSend);
            set_volume_fn(player, macos.sel("setVolume:"), self.config.volume);

            // Set number of loops (-1 for infinite)
            if (self.config.loop) {
                const SetLoopsFn = *const fn (?*anyopaque, ?*anyopaque, c_long) callconv(.c) void;
                const set_loops_fn: SetLoopsFn = @ptrCast(&macos.objc.objc_msgSend);
                const loops: c_long = if (self.config.loop_count == 0) -1 else @intCast(self.config.loop_count);
                set_loops_fn(player, macos.sel("setNumberOfLoops:"), loops);
            }

            // Play
            _ = macos.msgSend0(player, "play");
        } else {
            return AudioError.FileNotFound;
        }
    }

    fn pauseMacOS(self: *Self) void {
        if (self.native_handle) |player| {
            const macos = @import("macos.zig");
            _ = macos.msgSend0(player, "pause");
        }
    }

    fn resumeMacOS(self: *Self) void {
        if (self.native_handle) |player| {
            const macos = @import("macos.zig");
            _ = macos.msgSend0(player, "play");
        }
    }

    fn stopMacOS(self: *Self) void {
        if (self.native_handle) |player| {
            const macos = @import("macos.zig");
            _ = macos.msgSend0(player, "stop");

            // Reset to beginning
            const SetTimeFn = *const fn (?*anyopaque, ?*anyopaque, f64) callconv(.c) void;
            const set_time_fn: SetTimeFn = @ptrCast(&macos.objc.objc_msgSend);
            set_time_fn(player, macos.sel("setCurrentTime:"), 0.0);
        }
    }

    fn seekMacOS(self: *Self, position_ms: u64) void {
        if (self.native_handle) |player| {
            const macos = @import("macos.zig");
            const time_seconds: f64 = @as(f64, @floatFromInt(position_ms)) / 1000.0;
            const SetTimeFn = *const fn (?*anyopaque, ?*anyopaque, f64) callconv(.c) void;
            const set_time_fn: SetTimeFn = @ptrCast(&macos.objc.objc_msgSend);
            set_time_fn(player, macos.sel("setCurrentTime:"), time_seconds);
        }
    }

    fn setVolumeMacOS(self: *Self, volume: f32) void {
        if (self.native_handle) |player| {
            const macos = @import("macos.zig");
            const SetVolumeFn = *const fn (?*anyopaque, ?*anyopaque, f32) callconv(.c) void;
            const set_volume_fn: SetVolumeFn = @ptrCast(&macos.objc.objc_msgSend);
            set_volume_fn(player, macos.sel("setVolume:"), volume);
        }
    }
};

// =============================================================================
// System Sound Player
// =============================================================================

/// Plays system sounds and UI feedback sounds
pub const SystemSoundPlayer = struct {
    allocator: std.mem.Allocator,
    enabled: bool,
    volume: f32,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .enabled = true,
            .volume = 1.0,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Play a predefined system sound
    pub fn play(self: *Self, sound: SystemSound) AudioError!void {
        if (!self.enabled) return;

        const sound_name = sound.getPlatformName();
        try self.playByName(sound_name);
    }

    /// Play a system sound by name
    pub fn playByName(self: *Self, name: []const u8) AudioError!void {
        if (!self.enabled) return;

        switch (builtin.os.tag) {
            .macos => try self.playMacOSSound(name),
            .linux => try self.playLinuxSound(name),
            .windows => try self.playWindowsSound(name),
            else => return AudioError.DeviceNotAvailable,
        }
    }

    /// Play alert/beep sound
    pub fn beep(self: *Self) AudioError!void {
        try self.play(.beep);
    }

    /// Play notification sound
    pub fn notification(self: *Self) AudioError!void {
        try self.play(.notification);
    }

    /// Play error sound
    pub fn playError(self: *Self) AudioError!void {
        try self.play(.error_sound);
    }

    /// Play success sound
    pub fn success(self: *Self) AudioError!void {
        try self.play(.success);
    }

    /// Enable/disable sounds
    pub fn setEnabled(self: *Self, enabled: bool) void {
        self.enabled = enabled;
    }

    /// Set volume for system sounds
    pub fn setVolume(self: *Self, volume: f32) AudioError!void {
        if (volume < 0.0 or volume > 1.0) return AudioError.InvalidVolume;
        self.volume = volume;
    }

    // Platform implementations
    fn playMacOSSound(self: *Self, name: []const u8) AudioError!void {
        _ = self;

        // Use NSSound to play system sound
        const macos = @import("macos.zig");

        // Get NSSound class
        const NSSound = macos.getClass("NSSound");
        if (NSSound == null) return AudioError.DeviceNotAvailable;

        // Create NSString for sound name
        const name_cstr = std.heap.c_allocator.dupeZ(u8, name) catch return AudioError.InitializationFailed;
        defer std.heap.c_allocator.free(name_cstr);

        const NSString = macos.getClass("NSString");
        const str_alloc = macos.msgSend0(NSString, "alloc");
        const ns_name = macos.msgSend1(str_alloc, "initWithUTF8String:", name_cstr.ptr);

        // Try to get system sound by name
        const sound = macos.msgSend1(NSSound, "soundNamed:", ns_name);
        if (sound != null) {
            _ = macos.msgSend0(sound, "play");
        } else {
            return AudioError.SystemSoundNotFound;
        }
    }

    fn playLinuxSound(self: *Self, name: []const u8) AudioError!void {
        _ = self;

        // Use canberra-gtk-play for freedesktop sound theme
        // This is the standard way to play event sounds on Linux
        const name_z = std.heap.c_allocator.dupeZ(u8, name) catch return AudioError.InitializationFailed;
        defer std.heap.c_allocator.free(name_z);

        // Try canberra-gtk-play first (most compatible)
        var canberra_child = std.process.Child.init(
            &[_][]const u8{ "canberra-gtk-play", "-i", name_z },
            std.heap.c_allocator,
        );
        canberra_child.spawn() catch {
            // Fall back to paplay with a system sound file
            var paplay_child = std.process.Child.init(
                &[_][]const u8{ "paplay", "/usr/share/sounds/freedesktop/stereo/bell.oga" },
                std.heap.c_allocator,
            );
            paplay_child.spawn() catch return AudioError.DeviceNotAvailable;
            return;
        };
    }

    fn playWindowsSound(self: *Self, name: []const u8) AudioError!void {
        _ = self;

        // Windows sound playback using PlaySound
        // We'll use the system sound registry names
        if (builtin.os.tag != .windows) return AudioError.DeviceNotAvailable;

        const windows = struct {
            extern "winmm" fn PlaySoundA(
                pszSound: [*:0]const u8,
                hmod: ?*anyopaque,
                fdwSound: u32,
            ) callconv(.winapi) i32;
        };

        const SND_ALIAS: u32 = 0x00010000;
        const SND_ASYNC: u32 = 0x0001;
        const SND_NODEFAULT: u32 = 0x0002;

        const name_z = std.heap.c_allocator.dupeZ(u8, name) catch return AudioError.InitializationFailed;
        defer std.heap.c_allocator.free(name_z);

        const result = windows.PlaySoundA(name_z.ptr, null, SND_ALIAS | SND_ASYNC | SND_NODEFAULT);
        if (result == 0) {
            // Try playing as a system default
            _ = windows.PlaySoundA("SystemDefault", null, SND_ALIAS | SND_ASYNC);
        }
    }
};

// =============================================================================
// Haptic Engine
// =============================================================================

/// Provides haptic/tactile feedback
pub const HapticEngine = struct {
    allocator: std.mem.Allocator,
    enabled: bool,
    intensity_multiplier: f32,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .enabled = true,
            .intensity_multiplier = 1.0,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Check if haptic feedback is available
    pub fn isAvailable() bool {
        return switch (builtin.os.tag) {
            .macos, .ios => true, // NSHapticFeedbackManager / UIImpactFeedbackGenerator
            else => false,
        };
    }

    /// Trigger haptic feedback
    pub fn trigger(self: *Self, haptic_type: HapticType) AudioError!void {
        if (!self.enabled) return;
        if (!isAvailable()) return AudioError.HapticNotSupported;

        const intensity = haptic_type.getIntensity() * self.intensity_multiplier;

        switch (builtin.os.tag) {
            .macos => try self.triggerMacOS(haptic_type, intensity),
            .ios => try self.triggerIOS(haptic_type, intensity),
            else => return AudioError.HapticNotSupported,
        }
    }

    /// Trigger impact feedback
    pub fn impact(self: *Self, style: enum { light, medium, heavy }) AudioError!void {
        const haptic_type: HapticType = switch (style) {
            .light => .impact_light,
            .medium => .impact_medium,
            .heavy => .impact_heavy,
        };
        try self.trigger(haptic_type);
    }

    /// Trigger notification feedback
    pub fn notificationFeedback(self: *Self, feedback_type: enum { success, warning, error_feedback }) AudioError!void {
        const haptic_type: HapticType = switch (feedback_type) {
            .success => .notification_success,
            .warning => .notification_warning,
            .error_feedback => .notification_error,
        };
        try self.trigger(haptic_type);
    }

    /// Trigger selection changed feedback
    pub fn selectionChanged(self: *Self) AudioError!void {
        try self.trigger(.selection_changed);
    }

    /// Enable/disable haptics
    pub fn setEnabled(self: *Self, enabled: bool) void {
        self.enabled = enabled;
    }

    /// Set intensity multiplier (0.0 to 2.0)
    pub fn setIntensity(self: *Self, multiplier: f32) AudioError!void {
        if (multiplier < 0.0 or multiplier > 2.0) return AudioError.InvalidVolume;
        self.intensity_multiplier = multiplier;
    }

    fn triggerMacOS(self: *Self, haptic_type: HapticType, intensity: f32) AudioError!void {
        _ = self;
        _ = intensity;

        const macos = @import("macos.zig");

        // NSHapticFeedbackManager
        const NSHapticFeedbackManager = macos.getClass("NSHapticFeedbackManager");
        if (NSHapticFeedbackManager == null) return AudioError.HapticNotSupported;

        const manager = macos.msgSend0(NSHapticFeedbackManager, "defaultPerformer");
        if (manager == null) return AudioError.HapticNotSupported;

        // Map haptic type to NSHapticFeedbackPattern
        const pattern: c_long = switch (haptic_type) {
            .impact_light, .impact_soft, .selection_changed => 1, // NSHapticFeedbackPatternGeneric
            .impact_medium => 2, // NSHapticFeedbackPatternAlignment
            .impact_heavy, .impact_rigid => 3, // NSHapticFeedbackPatternLevelChange
            .notification_success, .notification_warning, .notification_error => 1,
        };

        // performFeedbackPattern:performanceTime:
        _ = macos.msgSend2(manager, "performFeedbackPattern:performanceTime:", pattern, @as(c_long, 0));
    }

    fn triggerIOS(self: *Self, haptic_type: HapticType, intensity: f32) AudioError!void {
        _ = self;
        _ = intensity;

        // iOS haptic feedback using UIKit feedback generators
        const macos = @import("macos.zig");

        switch (haptic_type) {
            .impact_light, .impact_medium, .impact_heavy, .impact_rigid, .impact_soft => {
                // UIImpactFeedbackGenerator
                const UIImpactFeedbackGenerator = macos.getClass("UIImpactFeedbackGenerator") orelse
                    return AudioError.HapticNotSupported;

                // Map to UIImpactFeedbackStyle
                const style: c_long = switch (haptic_type) {
                    .impact_light => 0, // UIImpactFeedbackStyleLight
                    .impact_medium => 1, // UIImpactFeedbackStyleMedium
                    .impact_heavy => 2, // UIImpactFeedbackStyleHeavy
                    .impact_soft => 3, // UIImpactFeedbackStyleSoft (iOS 13+)
                    .impact_rigid => 4, // UIImpactFeedbackStyleRigid (iOS 13+)
                    else => 1,
                };

                // Create and trigger: [[UIImpactFeedbackGenerator alloc] initWithStyle:style]
                const gen_alloc = macos.msgSend0(UIImpactFeedbackGenerator, "alloc");
                const InitStyleFn = *const fn (?*anyopaque, ?*anyopaque, c_long) callconv(.c) ?*anyopaque;
                const init_fn: InitStyleFn = @ptrCast(&macos.objc.objc_msgSend);
                const generator = init_fn(gen_alloc, macos.sel("initWithStyle:"), style);

                if (generator != null) {
                    _ = macos.msgSend0(generator, "impactOccurred");
                }
            },
            .notification_success, .notification_warning, .notification_error => {
                // UINotificationFeedbackGenerator
                const UINotificationFeedbackGenerator = macos.getClass("UINotificationFeedbackGenerator") orelse
                    return AudioError.HapticNotSupported;

                // Map to UINotificationFeedbackType
                const notif_type: c_long = switch (haptic_type) {
                    .notification_success => 0, // UINotificationFeedbackTypeSuccess
                    .notification_warning => 1, // UINotificationFeedbackTypeWarning
                    .notification_error => 2, // UINotificationFeedbackTypeError
                    else => 0,
                };

                // Create and trigger
                const gen_alloc = macos.msgSend0(UINotificationFeedbackGenerator, "alloc");
                const generator = macos.msgSend0(gen_alloc, "init");

                if (generator != null) {
                    const NotifFn = *const fn (?*anyopaque, ?*anyopaque, c_long) callconv(.c) void;
                    const notif_fn: NotifFn = @ptrCast(&macos.objc.objc_msgSend);
                    notif_fn(generator, macos.sel("notificationOccurred:"), notif_type);
                }
            },
            .selection_changed => {
                // UISelectionFeedbackGenerator
                const UISelectionFeedbackGenerator = macos.getClass("UISelectionFeedbackGenerator") orelse
                    return AudioError.HapticNotSupported;

                const gen_alloc = macos.msgSend0(UISelectionFeedbackGenerator, "alloc");
                const generator = macos.msgSend0(gen_alloc, "init");

                if (generator != null) {
                    _ = macos.msgSend0(generator, "selectionChanged");
                }
            },
        }
    }
};

// =============================================================================
// Audio Manager (Unified Interface)
// =============================================================================

/// Unified audio manager combining all audio functionality
pub const AudioManager = struct {
    allocator: std.mem.Allocator,
    player: AudioPlayer,
    system_sounds: SystemSoundPlayer,
    haptics: HapticEngine,
    master_volume: f32,
    muted: bool,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .player = AudioPlayer.init(allocator),
            .system_sounds = SystemSoundPlayer.init(allocator),
            .haptics = HapticEngine.init(allocator),
            .master_volume = 1.0,
            .muted = false,
        };
    }

    pub fn deinit(self: *Self) void {
        self.player.deinit();
        self.system_sounds.deinit();
        self.haptics.deinit();
    }

    /// Set master volume (affects all audio)
    pub fn setMasterVolume(self: *Self, volume: f32) AudioError!void {
        if (volume < 0.0 or volume > 1.0) return AudioError.InvalidVolume;
        self.master_volume = volume;
        try self.player.setVolume(volume * self.player.config.volume);
    }

    /// Mute all audio
    pub fn mute(self: *Self) void {
        self.muted = true;
        self.system_sounds.setEnabled(false);
    }

    /// Unmute all audio
    pub fn unmute(self: *Self) void {
        self.muted = false;
        self.system_sounds.setEnabled(true);
    }

    /// Toggle mute state
    pub fn toggleMute(self: *Self) void {
        if (self.muted) {
            self.unmute();
        } else {
            self.mute();
        }
    }

    /// Play a UI click sound with haptic
    pub fn playClick(self: *Self) void {
        self.system_sounds.play(.click) catch {};
        self.haptics.trigger(.selection_changed) catch {};
    }

    /// Play success feedback (sound + haptic)
    pub fn playSuccess(self: *Self) void {
        self.system_sounds.success() catch {};
        self.haptics.notificationFeedback(.success) catch {};
    }

    /// Play error feedback (sound + haptic)
    pub fn playErrorFeedback(self: *Self) void {
        self.system_sounds.playError() catch {};
        self.haptics.notificationFeedback(.error_feedback) catch {};
    }

    /// Play warning feedback (sound + haptic)
    pub fn playWarning(self: *Self) void {
        self.system_sounds.play(.warning) catch {};
        self.haptics.notificationFeedback(.warning) catch {};
    }
};

// =============================================================================
// Audio Presets
// =============================================================================

/// Pre-configured audio settings for common use cases
pub const AudioPresets = struct {
    /// Settings for background music
    pub fn backgroundMusic() AudioConfig {
        return .{
            .volume = 0.3,
            .loop = true,
            .fade_in_ms = 1000,
            .fade_out_ms = 1000,
        };
    }

    /// Settings for sound effects
    pub fn soundEffect() AudioConfig {
        return .{
            .volume = 1.0,
            .loop = false,
        };
    }

    /// Settings for UI sounds
    pub fn uiSound() AudioConfig {
        return .{
            .volume = 0.5,
            .loop = false,
        };
    }

    /// Settings for notifications
    pub fn notificationSound() AudioConfig {
        return .{
            .volume = 0.7,
            .loop = false,
        };
    }

    /// Settings for ambient/atmosphere
    pub fn ambient() AudioConfig {
        return .{
            .volume = 0.2,
            .loop = true,
            .fade_in_ms = 3000,
            .fade_out_ms = 3000,
        };
    }

    /// Settings for voice/speech
    pub fn voice() AudioConfig {
        return .{
            .volume = 1.0,
            .loop = false,
            .playback_rate = 1.0,
        };
    }
};

// =============================================================================
// Tests
// =============================================================================

test "AudioFormat from extension" {
    try std.testing.expectEqual(AudioFormat.wav, AudioFormat.fromExtension("wav"));
    try std.testing.expectEqual(AudioFormat.mp3, AudioFormat.fromExtension("mp3"));
    try std.testing.expectEqual(AudioFormat.aac, AudioFormat.fromExtension("aac"));
    try std.testing.expectEqual(AudioFormat.unknown, AudioFormat.fromExtension("xyz"));
}

test "AudioFormat mime types" {
    try std.testing.expectEqualStrings("audio/wav", AudioFormat.wav.mimeType());
    try std.testing.expectEqualStrings("audio/mpeg", AudioFormat.mp3.mimeType());
}

test "AudioConfig validation" {
    const valid_config = AudioConfig{
        .volume = 0.5,
        .pan = 0.0,
        .playback_rate = 1.0,
    };
    try valid_config.validate();

    const invalid_volume = AudioConfig{ .volume = 2.0 };
    try std.testing.expectError(AudioError.InvalidVolume, invalid_volume.validate());

    const invalid_pan = AudioConfig{ .pan = 2.0 };
    try std.testing.expectError(AudioError.InvalidVolume, invalid_pan.validate());
}

test "SystemSound platform names" {
    const glass = SystemSound.glass;
    _ = glass.getPlatformName();

    const error_sound = SystemSound.error_sound;
    _ = error_sound.getPlatformName();
}

test "HapticType intensity" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), HapticType.impact_light.getIntensity(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), HapticType.impact_medium.getIntensity(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), HapticType.impact_heavy.getIntensity(), 0.001);
}

test "AudioPlayer initialization" {
    const allocator = std.testing.allocator;
    var player = AudioPlayer.init(allocator);
    defer player.deinit();

    try std.testing.expect(player.state == .stopped);
    try std.testing.expect(player.current_file == null);
    try std.testing.expect(player.config.volume == 1.0);
}

test "AudioPlayer volume" {
    const allocator = std.testing.allocator;
    var player = AudioPlayer.init(allocator);
    defer player.deinit();

    try player.setVolume(0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), player.getVolume(), 0.001);

    try std.testing.expectError(AudioError.InvalidVolume, player.setVolume(1.5));
}

test "SystemSoundPlayer initialization" {
    const allocator = std.testing.allocator;
    var sounds = SystemSoundPlayer.init(allocator);
    defer sounds.deinit();

    try std.testing.expect(sounds.enabled);
    try std.testing.expect(sounds.volume == 1.0);
}

test "HapticEngine availability" {
    const available = HapticEngine.isAvailable();
    // On macOS should be true, on other platforms may be false
    _ = available;
}

test "AudioManager initialization" {
    const allocator = std.testing.allocator;
    var manager = AudioManager.init(allocator);
    defer manager.deinit();

    try std.testing.expect(manager.master_volume == 1.0);
    try std.testing.expect(!manager.muted);
}

test "AudioManager mute/unmute" {
    const allocator = std.testing.allocator;
    var manager = AudioManager.init(allocator);
    defer manager.deinit();

    manager.mute();
    try std.testing.expect(manager.muted);

    manager.unmute();
    try std.testing.expect(!manager.muted);

    manager.toggleMute();
    try std.testing.expect(manager.muted);
}

test "AudioPresets" {
    const bg = AudioPresets.backgroundMusic();
    try std.testing.expect(bg.loop);
    try std.testing.expect(bg.volume < 1.0);

    const sfx = AudioPresets.soundEffect();
    try std.testing.expect(!sfx.loop);
    try std.testing.expect(sfx.volume == 1.0);

    const ambient = AudioPresets.ambient();
    try std.testing.expect(ambient.loop);
    try std.testing.expect(ambient.fade_in_ms > 0);
}
