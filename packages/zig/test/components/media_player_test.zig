const std = @import("std");
const components = @import("components");
const MediaPlayer = components.MediaPlayer;
const ComponentProps = components.ComponentProps;

var play_called = false;
var pause_called = false;
var last_time: f64 = 0.0;

fn handlePlay() void {
    play_called = true;
}

fn handlePause() void {
    pause_called = true;
}

fn handleTimeUpdate(time: f64) void {
    last_time = time;
}

test "media player creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const player = try MediaPlayer.init(allocator, "test.mp4", .video, props);
    defer player.deinit();

    try std.testing.expectEqualStrings("test.mp4", player.source);
    try std.testing.expect(player.media_type == .video);
    try std.testing.expect(!player.playing);
    try std.testing.expect(player.volume == 1.0);
}

test "media player play pause" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const player = try MediaPlayer.init(allocator, "test.mp3", .audio, props);
    defer player.deinit();

    play_called = false;
    pause_called = false;

    player.onPlay(&handlePlay);
    player.onPause(&handlePause);

    player.play();
    try std.testing.expect(player.playing);
    try std.testing.expect(play_called);

    player.pause();
    try std.testing.expect(!player.playing);
    try std.testing.expect(pause_called);
}

test "media player toggle play pause" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const player = try MediaPlayer.init(allocator, "test.mp4", .video, props);
    defer player.deinit();

    try std.testing.expect(!player.playing);
    player.togglePlayPause();
    try std.testing.expect(player.playing);
    player.togglePlayPause();
    try std.testing.expect(!player.playing);
}

test "media player volume control" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const player = try MediaPlayer.init(allocator, "test.mp3", .audio, props);
    defer player.deinit();

    player.setVolume(0.5);
    try std.testing.expect(player.volume == 0.5);

    player.increaseVolume(0.3);
    try std.testing.expect(player.volume == 0.8);

    player.decreaseVolume(0.3);
    try std.testing.expect(player.volume == 0.5);

    // Test clamping
    player.setVolume(2.0);
    try std.testing.expect(player.volume == 1.0);

    player.setVolume(-0.5);
    try std.testing.expect(player.volume == 0.0);
}

test "media player mute" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const player = try MediaPlayer.init(allocator, "test.mp3", .audio, props);
    defer player.deinit();

    try std.testing.expect(!player.muted);
    player.toggleMute();
    try std.testing.expect(player.muted);
    player.toggleMute();
    try std.testing.expect(!player.muted);
}

test "media player seek" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const player = try MediaPlayer.init(allocator, "test.mp4", .video, props);
    defer player.deinit();

    player.duration = 100.0;
    last_time = 0.0;

    player.onTimeUpdate(&handleTimeUpdate);

    player.seek(50.0);
    try std.testing.expect(player.current_time == 50.0);
    try std.testing.expect(last_time == 50.0);

    player.seekForward(10.0);
    try std.testing.expect(player.current_time == 60.0);

    player.seekBackward(20.0);
    try std.testing.expect(player.current_time == 40.0);

    // Test clamping
    player.seek(150.0);
    try std.testing.expect(player.current_time == 100.0);

    player.seek(-10.0);
    try std.testing.expect(player.current_time == 0.0);
}

test "media player progress" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const player = try MediaPlayer.init(allocator, "test.mp4", .video, props);
    defer player.deinit();

    player.duration = 100.0;
    player.current_time = 25.0;

    const progress = player.getProgress();
    try std.testing.expect(progress == 0.25);
}

test "media player playback rate" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const player = try MediaPlayer.init(allocator, "test.mp4", .video, props);
    defer player.deinit();

    player.setPlaybackRate(2.0);
    try std.testing.expect(player.playback_rate == 2.0);

    // Test clamping
    player.setPlaybackRate(10.0);
    try std.testing.expect(player.playback_rate == 4.0);

    player.setPlaybackRate(0.1);
    try std.testing.expect(player.playback_rate == 0.25);
}

test "media player loop" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const player = try MediaPlayer.init(allocator, "test.mp3", .audio, props);
    defer player.deinit();

    try std.testing.expect(!player.loop);
    player.setLoop(true);
    try std.testing.expect(player.loop);
}

test "media player set source" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const player = try MediaPlayer.init(allocator, "test1.mp4", .video, props);
    defer player.deinit();

    player.play();
    player.current_time = 50.0;

    player.setSource("test2.mp4");
    try std.testing.expectEqualStrings("test2.mp4", player.source);
    try std.testing.expect(!player.playing);
    try std.testing.expect(player.current_time == 0.0);
}
