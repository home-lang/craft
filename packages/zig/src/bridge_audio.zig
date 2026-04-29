const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Audio playback + recording bridge.
///
/// Playback uses `NSSound`. Apps can either:
///   - hand a system sound name ("Funk", "Glass", "Hero" — see
///     `/System/Library/Sounds/`) — fastest, no allocations
///   - or a path to a file we play once via `[NSSound initWithContentsOfFile:]`
///
/// Recording uses `AVAudioRecorder` with a default M4A AAC profile.
/// More elaborate audio I/O (multi-track, real-time DSP) wants
/// AVAudioEngine, which is out of scope for this module.
pub const AudioBridge = struct {
    allocator: std.mem.Allocator,
    current_sound: ?@import("macos.zig").objc.id = null,
    current_recorder: ?@import("macos.zig").objc.id = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        if (builtin.os.tag != .macos) return;
        const macos = @import("macos.zig");
        if (self.current_sound) |s| _ = macos.msgSend0(s, "release");
        if (self.current_recorder) |r| _ = macos.msgSend0(r, "release");
    }

    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "play")) try self.play(data)
        else if (std.mem.eql(u8, action, "stop")) try self.stop()
        else if (std.mem.eql(u8, action, "playSystemSound")) try self.playSystemSound(data)
        else if (std.mem.eql(u8, action, "startRecording")) try self.startRecording(data)
        else if (std.mem.eql(u8, action, "stopRecording")) try self.stopRecording()
        else if (std.mem.eql(u8, action, "isPlaying")) try self.isPlaying()
        else if (std.mem.eql(u8, action, "isRecording")) try self.isRecording()
        else return BridgeError.UnknownAction;
    }

    fn play(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "play", "{\"ok\":false}");
            return;
        }
        const ParseShape = struct { path: []const u8 = "", volume: f64 = 1.0, loops: bool = false };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        if (parsed.value.path.len == 0) return BridgeError.MissingData;

        const macos = @import("macos.zig");
        const NSSound = macos.getClass("NSSound");
        const path_ns = macos.createNSString(parsed.value.path);
        // -initWithContentsOfFile:byReference: — byReference=YES doesn't
        // copy the data which is what we want for short SFX.
        const Fn = *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id, c_int) callconv(.c) macos.objc.id;
        const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
        const sound = f(macos.msgSend0(NSSound, "alloc"), macos.sel("initWithContentsOfFile:byReference:"), path_ns, 1);
        if (@intFromPtr(sound) == 0) {
            bridge_error.sendResultToJS(self.allocator, "play", "{\"ok\":false,\"reason\":\"file not found or unsupported format\"}");
            return;
        }

        // Stop the previous sound first; NSSound only plays one instance
        // at a time per object, but we hold the reference so it doesn't
        // get released mid-playback.
        if (self.current_sound) |old| {
            _ = macos.msgSend0(old, "stop");
            _ = macos.msgSend0(old, "release");
        }

        _ = macos.msgSend1Double(sound, "setVolume:", parsed.value.volume);
        _ = macos.msgSend1(sound, "setLoops:", @as(c_int, if (parsed.value.loops) 1 else 0));
        _ = macos.msgSend0(sound, "play");
        self.current_sound = sound;

        bridge_error.sendResultToJS(self.allocator, "play", "{\"ok\":true}");
    }

    fn playSystemSound(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "playSystemSound", "{\"ok\":false}");
            return;
        }
        const ParseShape = struct { name: []const u8 = "" };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        if (parsed.value.name.len == 0) return BridgeError.MissingData;

        const macos = @import("macos.zig");
        const NSSound = macos.getClass("NSSound");
        const name_ns = macos.createNSString(parsed.value.name);
        const sound = macos.msgSend1(NSSound, "soundNamed:", name_ns);
        if (@intFromPtr(sound) == 0) {
            bridge_error.sendResultToJS(self.allocator, "playSystemSound", "{\"ok\":false,\"reason\":\"unknown sound\"}");
            return;
        }
        _ = macos.msgSend0(sound, "play");
        bridge_error.sendResultToJS(self.allocator, "playSystemSound", "{\"ok\":true}");
    }

    fn stop(self: *Self) !void {
        if (builtin.os.tag != .macos) return;
        if (self.current_sound) |s| {
            const macos = @import("macos.zig");
            _ = macos.msgSend0(s, "stop");
            _ = macos.msgSend0(s, "release");
            self.current_sound = null;
        }
        bridge_error.sendResultToJS(self.allocator, "stop", "{\"ok\":true}");
    }

    fn isPlaying(self: *Self) !void {
        if (self.current_sound == null) {
            bridge_error.sendResultToJS(self.allocator, "isPlaying", "{\"value\":false}");
            return;
        }
        const macos = @import("macos.zig");
        const playing = macos.msgSendBool(self.current_sound.?, "isPlaying");
        const json = if (playing) "{\"value\":true}" else "{\"value\":false}";
        bridge_error.sendResultToJS(self.allocator, "isPlaying", json);
    }

    fn startRecording(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "startRecording", "{\"ok\":false}");
            return;
        }
        const ParseShape = struct { path: []const u8 = "", maxDurationSec: ?f64 = null };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        if (parsed.value.path.len == 0) return BridgeError.MissingData;

        const macos = @import("macos.zig");
        const AVAudioRecorder = macos.getClass("AVAudioRecorder");
        if (@intFromPtr(AVAudioRecorder) == 0) {
            bridge_error.sendResultToJS(self.allocator, "startRecording", "{\"ok\":false,\"reason\":\"AVFoundation unavailable\"}");
            return;
        }

        const NSURL = macos.getClass("NSURL");
        const path_ns = macos.createNSString(parsed.value.path);
        const url = macos.msgSend1(NSURL, "fileURLWithPath:", path_ns);

        // Settings dictionary: AAC at 44.1kHz, 2 channels. Default
        // bitrate (~128kbps). Apps wanting different formats (e.g.
        // 16-bit linear PCM for analysis) can pass their own settings
        // — we expose a simple opinionated default here.
        const NSMutableDictionary = macos.getClass("NSMutableDictionary");
        const settings = macos.msgSend0(NSMutableDictionary, "dictionary");

        const NSNumber = macos.getClass("NSNumber");
        // kAudioFormatMPEG4AAC = 'aac ' = 0x61616320
        const fmt_num = macos.msgSend1(NSNumber, "numberWithUnsignedInt:", @as(c_uint, 0x61616320));
        _ = macos.msgSend2(settings, "setObject:forKey:", fmt_num, macos.createNSString("AVFormatIDKey"));
        const sr_num = macos.msgSend1Double(NSNumber, "numberWithDouble:", 44100.0);
        _ = macos.msgSend2(settings, "setObject:forKey:", sr_num, macos.createNSString("AVSampleRateKey"));
        const ch_num = macos.msgSend1(NSNumber, "numberWithInt:", @as(c_int, 2));
        _ = macos.msgSend2(settings, "setObject:forKey:", ch_num, macos.createNSString("AVNumberOfChannelsKey"));

        // -[AVAudioRecorder initWithURL:settings:error:] takes an
        // NSError**; we pass null which is documented as legal.
        const Fn = *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id, macos.objc.id, ?*anyopaque) callconv(.c) macos.objc.id;
        const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
        const recorder = f(macos.msgSend0(AVAudioRecorder, "alloc"), macos.sel("initWithURL:settings:error:"), url, settings, null);
        if (@intFromPtr(recorder) == 0) {
            bridge_error.sendResultToJS(self.allocator, "startRecording", "{\"ok\":false,\"reason\":\"recorder init failed\"}");
            return;
        }

        if (self.current_recorder) |old| {
            _ = macos.msgSend0(old, "stop");
            _ = macos.msgSend0(old, "release");
        }

        if (parsed.value.maxDurationSec) |dur| {
            const RecordFn = *const fn (macos.objc.id, macos.objc.SEL, f64) callconv(.c) bool;
            const rf: RecordFn = @ptrCast(&macos.objc.objc_msgSend);
            _ = rf(recorder, macos.sel("recordForDuration:"), dur);
        } else {
            _ = macos.msgSend0(recorder, "record");
        }
        self.current_recorder = recorder;

        bridge_error.sendResultToJS(self.allocator, "startRecording", "{\"ok\":true}");
    }

    fn stopRecording(self: *Self) !void {
        if (self.current_recorder == null) {
            bridge_error.sendResultToJS(self.allocator, "stopRecording", "{\"ok\":true}");
            return;
        }
        const macos = @import("macos.zig");
        _ = macos.msgSend0(self.current_recorder.?, "stop");
        _ = macos.msgSend0(self.current_recorder.?, "release");
        self.current_recorder = null;
        bridge_error.sendResultToJS(self.allocator, "stopRecording", "{\"ok\":true}");
    }

    fn isRecording(self: *Self) !void {
        if (self.current_recorder == null) {
            bridge_error.sendResultToJS(self.allocator, "isRecording", "{\"value\":false}");
            return;
        }
        const macos = @import("macos.zig");
        const recording = macos.msgSendBool(self.current_recorder.?, "isRecording");
        const json = if (recording) "{\"value\":true}" else "{\"value\":false}";
        bridge_error.sendResultToJS(self.allocator, "isRecording", json);
    }
};
