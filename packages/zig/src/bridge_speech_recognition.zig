const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Speech-to-text via `SFSpeechRecognizer`.
///
/// The full flow needs `AVAudioEngine` to capture mic input,
/// `SFSpeechAudioBufferRecognitionRequest` to feed the audio into
/// the recognizer, and a delegate that emits partial + final
/// transcripts. The pieces aren't trivial; what's here is the
/// stable JS surface so apps can write against it now.
///
/// Apps that want speech today can hook the Web Speech API
/// (`webkitSpeechRecognition` in Safari / Chrome) — same shape, just
/// browser-only.
pub const SpeechRecognitionBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(a: std.mem.Allocator) Self {
        return .{ .allocator = a };
    }

    pub fn deinit(_: *Self) void {}

    pub fn handleMessage(self: *Self, action: []const u8, _: []const u8) !void {
        if (std.mem.eql(u8, action, "isAvailable")) {
            bridge_error.sendResultToJS(self.allocator, "isAvailable", "{\"value\":false}");
        } else if (std.mem.eql(u8, action, "start")) {
            bridge_error.sendResultToJS(self.allocator, "start", "{\"started\":false,\"reason\":\"SFSpeechRecognizer wiring pending\"}");
        } else if (std.mem.eql(u8, action, "stop")) {
            bridge_error.sendResultToJS(self.allocator, "stop", "{\"ok\":true}");
        } else return BridgeError.UnknownAction;
    }
};
