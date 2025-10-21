const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// Media Player Component
pub const MediaPlayer = struct {
    component: Component,
    source: []const u8,
    media_type: MediaType,
    playing: bool,
    current_time: f64,
    duration: f64,
    volume: f32,
    muted: bool,
    loop: bool,
    playback_rate: f32,
    on_play: ?*const fn () void,
    on_pause: ?*const fn () void,
    on_ended: ?*const fn () void,
    on_time_update: ?*const fn (f64) void,

    pub const MediaType = enum {
        audio,
        video,
    };

    pub fn init(allocator: std.mem.Allocator, source: []const u8, media_type: MediaType, props: ComponentProps) !*MediaPlayer {
        const player = try allocator.create(MediaPlayer);
        player.* = MediaPlayer{
            .component = try Component.init(allocator, "media_player", props),
            .source = source,
            .media_type = media_type,
            .playing = false,
            .current_time = 0.0,
            .duration = 0.0,
            .volume = 1.0,
            .muted = false,
            .loop = false,
            .playback_rate = 1.0,
            .on_play = null,
            .on_pause = null,
            .on_ended = null,
            .on_time_update = null,
        };
        return player;
    }

    pub fn deinit(self: *MediaPlayer) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn play(self: *MediaPlayer) void {
        self.playing = true;
        if (self.on_play) |callback| {
            callback();
        }
    }

    pub fn pause(self: *MediaPlayer) void {
        self.playing = false;
        if (self.on_pause) |callback| {
            callback();
        }
    }

    pub fn stop(self: *MediaPlayer) void {
        self.playing = false;
        self.current_time = 0.0;
    }

    pub fn togglePlayPause(self: *MediaPlayer) void {
        if (self.playing) {
            self.pause();
        } else {
            self.play();
        }
    }

    pub fn seek(self: *MediaPlayer, time: f64) void {
        self.current_time = std.math.clamp(time, 0.0, self.duration);
        if (self.on_time_update) |callback| {
            callback(self.current_time);
        }
    }

    pub fn seekForward(self: *MediaPlayer, seconds: f64) void {
        self.seek(self.current_time + seconds);
    }

    pub fn seekBackward(self: *MediaPlayer, seconds: f64) void {
        self.seek(self.current_time - seconds);
    }

    pub fn setVolume(self: *MediaPlayer, volume: f32) void {
        self.volume = std.math.clamp(volume, 0.0, 1.0);
    }

    pub fn increaseVolume(self: *MediaPlayer, amount: f32) void {
        self.setVolume(self.volume + amount);
    }

    pub fn decreaseVolume(self: *MediaPlayer, amount: f32) void {
        self.setVolume(self.volume - amount);
    }

    pub fn toggleMute(self: *MediaPlayer) void {
        self.muted = !self.muted;
    }

    pub fn setLoop(self: *MediaPlayer, loop: bool) void {
        self.loop = loop;
    }

    pub fn setPlaybackRate(self: *MediaPlayer, rate: f32) void {
        self.playback_rate = std.math.clamp(rate, 0.25, 4.0);
    }

    pub fn setSource(self: *MediaPlayer, source: []const u8) void {
        self.source = source;
        self.stop();
    }

    pub fn getProgress(self: *const MediaPlayer) f32 {
        if (self.duration == 0.0) return 0.0;
        return @as(f32, @floatCast(self.current_time / self.duration));
    }

    pub fn onPlay(self: *MediaPlayer, callback: *const fn () void) void {
        self.on_play = callback;
    }

    pub fn onPause(self: *MediaPlayer, callback: *const fn () void) void {
        self.on_pause = callback;
    }

    pub fn onEnded(self: *MediaPlayer, callback: *const fn () void) void {
        self.on_ended = callback;
    }

    pub fn onTimeUpdate(self: *MediaPlayer, callback: *const fn (f64) void) void {
        self.on_time_update = callback;
    }
};
