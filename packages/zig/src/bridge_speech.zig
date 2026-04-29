const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Text-to-speech bridge.
///
/// macOS implementation uses `AVSpeechSynthesizer` (the modern,
/// system-wide speech synthesizer that respects the user's
/// configured voice + rate). Linux/Windows TTS implementations land
/// later — those return `not-supported` reasons in the response.
///
/// Speech synthesis happens off the main thread on macOS, so this
/// bridge is fire-and-forget for `speak`. The `stop` action interrupts
/// any in-flight utterance immediately.
pub const SpeechBridge = struct {
    allocator: std.mem.Allocator,
    synthesizer: ?@import("macos.zig").objc.id = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        if (self.synthesizer) |s| {
            const macos = @import("macos.zig");
            _ = macos.msgSend0(s, "release");
        }
    }

    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "speak")) {
            try self.speak(data);
        } else if (std.mem.eql(u8, action, "stop")) {
            try self.stop();
        } else if (std.mem.eql(u8, action, "pause")) {
            try self.pause();
        } else if (std.mem.eql(u8, action, "resume")) {
            try self.resumeSpeaking();
        } else if (std.mem.eql(u8, action, "isSpeaking")) {
            try self.isSpeaking();
        } else if (std.mem.eql(u8, action, "getVoices")) {
            try self.getVoices();
        } else {
            return BridgeError.UnknownAction;
        }
    }

    fn speak(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "speak", "{\"ok\":false,\"reason\":\"not supported on this OS\"}");
            return;
        }

        // Payload: `{text, voice?, rate?, pitch?, volume?}`
        const ParseShape = struct {
            text: []const u8 = "",
            voice: []const u8 = "",
            rate: ?f64 = null,
            pitch: ?f64 = null,
            volume: ?f64 = null,
        };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        if (parsed.value.text.len == 0) return BridgeError.MissingData;

        const macos = @import("macos.zig");

        // Build the utterance: -[AVSpeechUtterance speechUtteranceWithString:]
        const AVSpeechUtterance = macos.getClass("AVSpeechUtterance");
        if (@intFromPtr(AVSpeechUtterance) == 0) {
            bridge_error.sendResultToJS(self.allocator, "speak", "{\"ok\":false,\"reason\":\"AVFoundation not loaded\"}");
            return;
        }
        const text_ns = macos.createNSString(parsed.value.text);
        const utterance = macos.msgSend1(AVSpeechUtterance, "speechUtteranceWithString:", text_ns);

        if (parsed.value.voice.len > 0) {
            const AVSpeechSynthesisVoice = macos.getClass("AVSpeechSynthesisVoice");
            const voice_id_ns = macos.createNSString(parsed.value.voice);
            // -[AVSpeechSynthesisVoice voiceWithIdentifier:] — apps pass
            // either an identifier (`com.apple.voice.compact.en-US.Samantha`)
            // or a language code (`en-US`); the latter resolves to the
            // user's preferred voice for that language.
            const voice = macos.msgSend1(AVSpeechSynthesisVoice, "voiceWithIdentifier:", voice_id_ns);
            const final_voice = if (@intFromPtr(voice) != 0)
                voice
            else blk: {
                // Fall back to language-code lookup if identifier didn't resolve.
                const v = macos.msgSend1(AVSpeechSynthesisVoice, "voiceWithLanguage:", voice_id_ns);
                break :blk v;
            };
            if (@intFromPtr(final_voice) != 0) {
                _ = macos.msgSend1(utterance, "setVoice:", final_voice);
            }
        }
        if (parsed.value.rate) |r| {
            // AVSpeechUtteranceMinimumSpeechRate / Maximum / Default —
            // the natural range is 0..1 with 0.5 ≈ default. Apps that
            // pass values outside this range get clamped silently by
            // AppKit, so no defensive coercion needed here.
            _ = macos.msgSend1Double(utterance, "setRate:", r);
        }
        if (parsed.value.pitch) |p| {
            _ = macos.msgSend1Double(utterance, "setPitchMultiplier:", p);
        }
        if (parsed.value.volume) |v| {
            _ = macos.msgSend1Double(utterance, "setVolume:", v);
        }

        // Lazily allocate the synthesizer so multi-call apps share one.
        if (self.synthesizer == null) {
            const AVSpeechSynthesizer = macos.getClass("AVSpeechSynthesizer");
            const synth = macos.msgSend0(macos.msgSend0(AVSpeechSynthesizer, "alloc"), "init");
            self.synthesizer = synth;
        }
        _ = macos.msgSend1(self.synthesizer.?, "speakUtterance:", utterance);

        bridge_error.sendResultToJS(self.allocator, "speak", "{\"ok\":true}");
    }

    fn stop(self: *Self) !void {
        if (builtin.os.tag != .macos or self.synthesizer == null) {
            bridge_error.sendResultToJS(self.allocator, "stop", "{\"ok\":true}");
            return;
        }
        const macos = @import("macos.zig");
        // AVSpeechBoundaryImmediate = 0
        _ = macos.msgSend1(self.synthesizer.?, "stopSpeakingAtBoundary:", @as(c_long, 0));
        bridge_error.sendResultToJS(self.allocator, "stop", "{\"ok\":true}");
    }

    fn pause(self: *Self) !void {
        if (builtin.os.tag != .macos or self.synthesizer == null) {
            bridge_error.sendResultToJS(self.allocator, "pause", "{\"ok\":true}");
            return;
        }
        const macos = @import("macos.zig");
        _ = macos.msgSend1(self.synthesizer.?, "pauseSpeakingAtBoundary:", @as(c_long, 0));
        bridge_error.sendResultToJS(self.allocator, "pause", "{\"ok\":true}");
    }

    fn resumeSpeaking(self: *Self) !void {
        if (builtin.os.tag != .macos or self.synthesizer == null) {
            bridge_error.sendResultToJS(self.allocator, "resume", "{\"ok\":true}");
            return;
        }
        const macos = @import("macos.zig");
        _ = macos.msgSend0(self.synthesizer.?, "continueSpeaking");
        bridge_error.sendResultToJS(self.allocator, "resume", "{\"ok\":true}");
    }

    fn isSpeaking(self: *Self) !void {
        if (builtin.os.tag != .macos or self.synthesizer == null) {
            bridge_error.sendResultToJS(self.allocator, "isSpeaking", "{\"value\":false}");
            return;
        }
        const macos = @import("macos.zig");
        const speaking = macos.msgSendBool(self.synthesizer.?, "isSpeaking");
        const json = if (speaking) "{\"value\":true}" else "{\"value\":false}";
        bridge_error.sendResultToJS(self.allocator, "isSpeaking", json);
    }

    /// Return the list of installed voices: `[{id, name, language, quality}]`.
    /// `quality` is "default" or "enhanced" (the user's premium voices).
    fn getVoices(self: *Self) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "getVoices", "{\"voices\":[]}");
            return;
        }
        const macos = @import("macos.zig");
        const AVSpeechSynthesisVoice = macos.getClass("AVSpeechSynthesisVoice");
        const voices = macos.msgSend0(AVSpeechSynthesisVoice, "speechVoices");
        if (@intFromPtr(voices) == 0) {
            bridge_error.sendResultToJS(self.allocator, "getVoices", "{\"voices\":[]}");
            return;
        }

        const getCount = @as(
            *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) c_ulong,
            @ptrCast(&macos.objc.objc_msgSend),
        );
        const count = getCount(voices, macos.sel("count"));

        var buf: std.ArrayListUnmanaged(u8) = .empty;
        defer buf.deinit(self.allocator);
        try buf.appendSlice(self.allocator, "{\"voices\":[");

        var i: c_ulong = 0;
        while (i < count) : (i += 1) {
            if (i > 0) try buf.append(self.allocator, ',');
            const voice = macos.msgSend1(voices, "objectAtIndex:", i);
            try appendVoice(self.allocator, &buf, voice);
        }
        try buf.appendSlice(self.allocator, "]}");
        const owned = try buf.toOwnedSlice(self.allocator);
        defer self.allocator.free(owned);
        bridge_error.sendResultToJS(self.allocator, "getVoices", owned);
    }
};

fn appendVoice(allocator: std.mem.Allocator, buf: *std.ArrayListUnmanaged(u8), voice: @import("macos.zig").objc.id) !void {
    const macos = @import("macos.zig");
    try buf.append(allocator, '{');
    try writeNSStringField(allocator, buf, "id", macos.msgSend0(voice, "identifier"), true);
    try writeNSStringField(allocator, buf, "name", macos.msgSend0(voice, "name"), false);
    try writeNSStringField(allocator, buf, "language", macos.msgSend0(voice, "language"), false);
    // `-quality` returns AVSpeechSynthesisVoiceQuality enum (default=1, enhanced=2).
    const Fn = *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) c_long;
    const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
    const quality = f(voice, macos.sel("quality"));
    try buf.appendSlice(allocator, ",\"quality\":\"");
    try buf.appendSlice(allocator, if (quality == 2) "enhanced" else "default");
    try buf.appendSlice(allocator, "\"}");
}

fn writeNSStringField(
    allocator: std.mem.Allocator,
    buf: *std.ArrayListUnmanaged(u8),
    key: []const u8,
    ns_string: @import("macos.zig").objc.id,
    first: bool,
) !void {
    if (!first) try buf.append(allocator, ',');
    try buf.append(allocator, '"');
    try buf.appendSlice(allocator, key);
    try buf.appendSlice(allocator, "\":\"");
    if (@intFromPtr(ns_string) != 0) {
        const macos = @import("macos.zig");
        const utf8 = macos.msgSend0(ns_string, "UTF8String");
        if (@intFromPtr(utf8) != 0) {
            const slice = std.mem.span(@as([*:0]const u8, @ptrCast(utf8)));
            for (slice) |b| {
                switch (b) {
                    '"' => try buf.appendSlice(allocator, "\\\""),
                    '\\' => try buf.appendSlice(allocator, "\\\\"),
                    else => try buf.append(allocator, b),
                }
            }
        }
    }
    try buf.append(allocator, '"');
}
