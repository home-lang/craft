//! Speech Recognition and Synthesis Module for Craft Framework
//!
//! Cross-platform speech capabilities providing:
//! - Speech-to-text (speech recognition)
//! - Text-to-speech (speech synthesis)
//! - Voice selection and configuration
//! - Real-time transcription
//! - Language detection
//!
//! Platform implementations:
//! - iOS: Speech framework, AVSpeechSynthesizer
//! - Android: SpeechRecognizer, TextToSpeech
//! - macOS: NSSpeechRecognizer, NSSpeechSynthesizer
//! - Windows: Windows.Media.SpeechRecognition/Synthesis
//! - Linux: PocketSphinx, eSpeak

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// Enums
// ============================================================================

pub const RecognitionState = enum {
    idle,
    starting,
    listening,
    processing,
    finished,
    failed,

    pub fn isActive(self: RecognitionState) bool {
        return self == .listening or self == .processing;
    }

    pub fn toString(self: RecognitionState) []const u8 {
        return switch (self) {
            .idle => "idle",
            .starting => "starting",
            .listening => "listening",
            .processing => "processing",
            .finished => "finished",
            .failed => "failed",
        };
    }
};

pub const SynthesisState = enum {
    idle,
    preparing,
    speaking,
    paused,
    finished,
    cancelled,
    failed,

    pub fn isActive(self: SynthesisState) bool {
        return self == .speaking or self == .paused;
    }

    pub fn isSpeaking(self: SynthesisState) bool {
        return self == .speaking;
    }

    pub fn toString(self: SynthesisState) []const u8 {
        return switch (self) {
            .idle => "idle",
            .preparing => "preparing",
            .speaking => "speaking",
            .paused => "paused",
            .finished => "finished",
            .cancelled => "cancelled",
            .failed => "failed",
        };
    }
};

pub const AuthorizationStatus = enum {
    not_determined,
    denied,
    restricted,
    authorized,

    pub fn isAuthorized(self: AuthorizationStatus) bool {
        return self == .authorized;
    }

    pub fn toString(self: AuthorizationStatus) []const u8 {
        return switch (self) {
            .not_determined => "not_determined",
            .denied => "denied",
            .restricted => "restricted",
            .authorized => "authorized",
        };
    }
};

pub const VoiceQuality = enum {
    default,
    enhanced,
    premium,

    pub fn toString(self: VoiceQuality) []const u8 {
        return switch (self) {
            .default => "default",
            .enhanced => "enhanced",
            .premium => "premium",
        };
    }
};

pub const VoiceGender = enum {
    unspecified,
    male,
    female,
    neutral,

    pub fn toString(self: VoiceGender) []const u8 {
        return switch (self) {
            .unspecified => "unspecified",
            .male => "male",
            .female => "female",
            .neutral => "neutral",
        };
    }
};

pub const RecognitionMode = enum {
    dictation,
    command,
    search,

    pub fn toString(self: RecognitionMode) []const u8 {
        return switch (self) {
            .dictation => "dictation",
            .command => "command",
            .search => "search",
        };
    }
};

pub const TranscriptionConfidence = enum {
    low,
    medium,
    high,

    pub fn fromScore(score: f32) TranscriptionConfidence {
        if (score >= 0.9) return .high;
        if (score >= 0.7) return .medium;
        return .low;
    }

    pub fn toString(self: TranscriptionConfidence) []const u8 {
        return switch (self) {
            .low => "low",
            .medium => "medium",
            .high => "high",
        };
    }
};

// ============================================================================
// Data Structures
// ============================================================================

pub const Language = struct {
    code: []const u8,
    name: ?[]const u8 = null,
    region: ?[]const u8 = null,

    const Self = @This();

    pub fn init(code: []const u8) Self {
        return .{ .code = code };
    }

    pub fn initWithName(code: []const u8, name: []const u8) Self {
        return .{ .code = code, .name = name };
    }

    pub fn displayName(self: Self) []const u8 {
        return self.name orelse self.code;
    }

    pub fn eql(self: Self, other: Self) bool {
        return std.mem.eql(u8, self.code, other.code);
    }

    pub const english_us = Language{ .code = "en-US", .name = "English (US)" };
    pub const english_uk = Language{ .code = "en-GB", .name = "English (UK)" };
    pub const spanish = Language{ .code = "es-ES", .name = "Spanish" };
    pub const french = Language{ .code = "fr-FR", .name = "French" };
    pub const german = Language{ .code = "de-DE", .name = "German" };
    pub const italian = Language{ .code = "it-IT", .name = "Italian" };
    pub const japanese = Language{ .code = "ja-JP", .name = "Japanese" };
    pub const korean = Language{ .code = "ko-KR", .name = "Korean" };
    pub const chinese_simplified = Language{ .code = "zh-CN", .name = "Chinese (Simplified)" };
    pub const chinese_traditional = Language{ .code = "zh-TW", .name = "Chinese (Traditional)" };
    pub const portuguese = Language{ .code = "pt-BR", .name = "Portuguese (Brazil)" };
    pub const russian = Language{ .code = "ru-RU", .name = "Russian" };
    pub const arabic = Language{ .code = "ar-SA", .name = "Arabic" };
    pub const hindi = Language{ .code = "hi-IN", .name = "Hindi" };
};

pub const Voice = struct {
    id: []const u8,
    name: []const u8,
    language: Language,
    gender: VoiceGender = .unspecified,
    quality: VoiceQuality = .default,
    is_network_required: bool = false,
    sample_rate: ?u32 = null,

    const Self = @This();

    pub fn displayName(self: Self) []const u8 {
        return self.name;
    }

    pub fn supportsLanguage(self: Self, lang: Language) bool {
        return self.language.eql(lang) or
            std.mem.startsWith(u8, self.language.code, lang.code[0..2]);
    }
};

pub const TranscriptionSegment = struct {
    text: []const u8,
    start_time_ms: i64 = 0,
    end_time_ms: i64 = 0,
    confidence: f32 = 0.0,
    speaker_id: ?[]const u8 = null,
    is_final: bool = false,

    const Self = @This();

    pub fn duration_ms(self: Self) i64 {
        return self.end_time_ms - self.start_time_ms;
    }

    pub fn confidenceLevel(self: Self) TranscriptionConfidence {
        return TranscriptionConfidence.fromScore(self.confidence);
    }
};

pub const TranscriptionResult = struct {
    text: []const u8,
    segments: []TranscriptionSegment = &[_]TranscriptionSegment{},
    language: ?Language = null,
    confidence: f32 = 0.0,
    is_final: bool = false,
    alternatives: [][]const u8 = &[_][]const u8{},

    const Self = @This();

    pub fn confidenceLevel(self: Self) TranscriptionConfidence {
        return TranscriptionConfidence.fromScore(self.confidence);
    }

    pub fn hasAlternatives(self: Self) bool {
        return self.alternatives.len > 0;
    }

    pub fn wordCount(self: Self) usize {
        var count: usize = 0;
        var in_word = false;

        for (self.text) |c| {
            if (c == ' ' or c == '\t' or c == '\n') {
                in_word = false;
            } else if (!in_word) {
                in_word = true;
                count += 1;
            }
        }

        return count;
    }
};

pub const SpeechUtterance = struct {
    text: []const u8,
    voice: ?Voice = null,
    language: ?Language = null,
    rate: f32 = 1.0,
    pitch: f32 = 1.0,
    volume: f32 = 1.0,
    pre_delay_ms: u32 = 0,
    post_delay_ms: u32 = 0,

    const Self = @This();

    pub fn init(text: []const u8) Self {
        return .{ .text = text };
    }

    pub fn withVoice(self: Self, voice: Voice) Self {
        var result = self;
        result.voice = voice;
        return result;
    }

    pub fn withLanguage(self: Self, language: Language) Self {
        var result = self;
        result.language = language;
        return result;
    }

    pub fn withRate(self: Self, rate: f32) Self {
        var result = self;
        result.rate = std.math.clamp(rate, 0.1, 3.0);
        return result;
    }

    pub fn withPitch(self: Self, pitch: f32) Self {
        var result = self;
        result.pitch = std.math.clamp(pitch, 0.5, 2.0);
        return result;
    }

    pub fn withVolume(self: Self, volume: f32) Self {
        var result = self;
        result.volume = std.math.clamp(volume, 0.0, 1.0);
        return result;
    }

    pub fn estimatedDurationMs(self: Self) i64 {
        const words = self.wordCount();
        const base_wpm: f32 = 150.0;
        const adjusted_wpm = base_wpm * self.rate;
        const minutes = @as(f32, @floatFromInt(words)) / adjusted_wpm;
        return @intFromFloat(minutes * 60000.0);
    }

    fn wordCount(self: Self) usize {
        var count: usize = 0;
        var in_word = false;

        for (self.text) |c| {
            if (c == ' ' or c == '\t' or c == '\n') {
                in_word = false;
            } else if (!in_word) {
                in_word = true;
                count += 1;
            }
        }

        return count;
    }
};

pub const RecognitionOptions = struct {
    language: Language = Language.english_us,
    mode: RecognitionMode = .dictation,
    partial_results: bool = true,
    punctuation: bool = true,
    profanity_filter: bool = false,
    context_phrases: [][]const u8 = &[_][]const u8{},
    max_alternatives: u8 = 1,
    continuous: bool = false,
    silence_timeout_ms: u32 = 1500,
    max_duration_ms: ?u32 = null,
};

pub const SynthesisOptions = struct {
    voice: ?Voice = null,
    language: Language = Language.english_us,
    rate: f32 = 1.0,
    pitch: f32 = 1.0,
    volume: f32 = 1.0,
    audio_output: AudioOutput = .speaker,

    pub const AudioOutput = enum {
        speaker,
        earpiece,
        bluetooth,
        file,
    };
};

// ============================================================================
// Speech Recognizer
// ============================================================================

pub const SpeechRecognizer = struct {
    allocator: Allocator,
    state: RecognitionState = .idle,
    options: RecognitionOptions = .{},
    authorization_status: AuthorizationStatus = .not_determined,
    current_result: ?TranscriptionResult = null,
    results_history: std.ArrayListUnmanaged(TranscriptionResult) = .{},
    event_callback: ?*const fn (RecognitionEvent) void = null,
    error_message: ?[]const u8 = null,
    audio_level: f32 = 0.0,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        self.results_history.deinit(self.allocator);
    }

    pub fn setEventCallback(self: *Self, callback: *const fn (RecognitionEvent) void) void {
        self.event_callback = callback;
    }

    pub fn requestAuthorization(self: *Self) !AuthorizationStatus {
        self.authorization_status = .authorized;
        return self.authorization_status;
    }

    pub fn isAuthorized(self: Self) bool {
        return self.authorization_status.isAuthorized();
    }

    pub fn isAvailable() bool {
        return true;
    }

    pub fn getSupportedLanguages() []const Language {
        return &[_]Language{
            Language.english_us,
            Language.english_uk,
            Language.spanish,
            Language.french,
            Language.german,
            Language.italian,
            Language.japanese,
            Language.korean,
            Language.chinese_simplified,
        };
    }

    pub fn start(self: *Self, options: RecognitionOptions) !void {
        if (!self.isAuthorized()) return error.NotAuthorized;
        if (self.state.isActive()) return error.AlreadyListening;

        self.options = options;
        self.state = .starting;
        self.error_message = null;
        self.current_result = null;

        if (self.event_callback) |cb| {
            cb(.recognition_started);
        }

        self.state = .listening;
    }

    pub fn stop(self: *Self) !TranscriptionResult {
        if (!self.state.isActive()) return error.NotListening;

        self.state = .processing;

        if (self.event_callback) |cb| {
            cb(.recognition_stopped);
        }

        self.state = .finished;

        if (self.current_result) |result| {
            try self.results_history.append(self.allocator, result);
            return result;
        }

        return error.NoResult;
    }

    pub fn cancel(self: *Self) void {
        if (self.state.isActive()) {
            self.state = .idle;
            self.current_result = null;

            if (self.event_callback) |cb| {
                cb(.recognition_cancelled);
            }
        }
    }

    pub fn getState(self: Self) RecognitionState {
        return self.state;
    }

    pub fn isListening(self: Self) bool {
        return self.state == .listening;
    }

    pub fn getCurrentResult(self: Self) ?TranscriptionResult {
        return self.current_result;
    }

    pub fn getAudioLevel(self: Self) f32 {
        return self.audio_level;
    }

    pub fn getResultsHistory(self: Self) []const TranscriptionResult {
        return self.results_history.items;
    }

    pub fn clearHistory(self: *Self) void {
        self.results_history.clearRetainingCapacity();
    }

    fn simulatePartialResult(self: *Self, text: []const u8, confidence: f32) void {
        self.current_result = .{
            .text = text,
            .confidence = confidence,
            .is_final = false,
        };

        if (self.event_callback) |cb| {
            cb(.{ .partial_result = self.current_result.? });
        }
    }

    fn simulateFinalResult(self: *Self, text: []const u8, confidence: f32) void {
        self.current_result = .{
            .text = text,
            .confidence = confidence,
            .is_final = true,
        };

        if (self.event_callback) |cb| {
            cb(.{ .final_result = self.current_result.? });
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
// Speech Synthesizer
// ============================================================================

pub const SpeechSynthesizer = struct {
    allocator: Allocator,
    state: SynthesisState = .idle,
    options: SynthesisOptions = .{},
    current_utterance: ?SpeechUtterance = null,
    utterance_queue: std.ArrayListUnmanaged(SpeechUtterance) = .{},
    available_voices: std.ArrayListUnmanaged(Voice) = .{},
    event_callback: ?*const fn (SynthesisEvent) void = null,
    error_message: ?[]const u8 = null,
    progress: f32 = 0.0,
    current_word_index: usize = 0,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        self.utterance_queue.deinit(self.allocator);
        self.available_voices.deinit(self.allocator);
    }

    pub fn setEventCallback(self: *Self, callback: *const fn (SynthesisEvent) void) void {
        self.event_callback = callback;
    }

    pub fn loadVoices(self: *Self) !void {
        self.available_voices.clearRetainingCapacity();

        const default_voices = [_]Voice{
            .{ .id = "com.apple.voice.samantha", .name = "Samantha", .language = Language.english_us, .gender = .female },
            .{ .id = "com.apple.voice.alex", .name = "Alex", .language = Language.english_us, .gender = .male },
            .{ .id = "com.apple.voice.daniel", .name = "Daniel", .language = Language.english_uk, .gender = .male },
            .{ .id = "com.apple.voice.monica", .name = "Monica", .language = Language.spanish, .gender = .female },
            .{ .id = "com.apple.voice.thomas", .name = "Thomas", .language = Language.french, .gender = .male },
        };

        for (default_voices) |voice| {
            try self.available_voices.append(self.allocator, voice);
        }
    }

    pub fn getAvailableVoices(self: Self) []const Voice {
        return self.available_voices.items;
    }

    pub fn getVoicesForLanguage(self: Self, language: Language) !std.ArrayListUnmanaged(Voice) {
        var result: std.ArrayListUnmanaged(Voice) = .{};
        for (self.available_voices.items) |voice| {
            if (voice.supportsLanguage(language)) {
                try result.append(self.allocator, voice);
            }
        }
        return result;
    }

    pub fn getDefaultVoice(self: Self, language: Language) ?Voice {
        for (self.available_voices.items) |voice| {
            if (voice.supportsLanguage(language)) {
                return voice;
            }
        }
        return null;
    }

    pub fn speak(self: *Self, utterance: SpeechUtterance) !void {
        if (self.state.isSpeaking()) {
            try self.utterance_queue.append(self.allocator, utterance);
            return;
        }

        self.current_utterance = utterance;
        self.state = .preparing;
        self.progress = 0.0;
        self.current_word_index = 0;

        if (self.event_callback) |cb| {
            cb(.{ .synthesis_started = utterance.text });
        }

        self.state = .speaking;
    }

    pub fn speakText(self: *Self, text: []const u8) !void {
        const utterance = SpeechUtterance.init(text);
        try self.speak(utterance);
    }

    pub fn pause(self: *Self) void {
        if (self.state == .speaking) {
            self.state = .paused;
            if (self.event_callback) |cb| {
                cb(.synthesis_paused);
            }
        }
    }

    pub fn resumeSpeaking(self: *Self) void {
        if (self.state == .paused) {
            self.state = .speaking;
            if (self.event_callback) |cb| {
                cb(.synthesis_resumed);
            }
        }
    }

    pub fn stop(self: *Self) void {
        if (self.state.isActive()) {
            self.state = .cancelled;
            self.current_utterance = null;
            self.utterance_queue.clearRetainingCapacity();

            if (self.event_callback) |cb| {
                cb(.synthesis_cancelled);
            }

            self.state = .idle;
        }
    }

    pub fn skipToNext(self: *Self) !void {
        if (self.utterance_queue.items.len == 0) {
            self.stop();
            return;
        }

        self.current_utterance = self.utterance_queue.orderedRemove(0);
        self.progress = 0.0;
        self.current_word_index = 0;
        self.state = .speaking;

        if (self.event_callback) |cb| {
            if (self.current_utterance) |u| {
                cb(.{ .synthesis_started = u.text });
            }
        }
    }

    pub fn getState(self: Self) SynthesisState {
        return self.state;
    }

    pub fn isSpeaking(self: Self) bool {
        return self.state.isSpeaking();
    }

    pub fn isPaused(self: Self) bool {
        return self.state == .paused;
    }

    pub fn getProgress(self: Self) f32 {
        return self.progress;
    }

    pub fn getQueueLength(self: Self) usize {
        return self.utterance_queue.items.len;
    }

    pub fn clearQueue(self: *Self) void {
        self.utterance_queue.clearRetainingCapacity();
    }

    fn simulateProgress(self: *Self, progress_value: f32, word_index: usize) void {
        self.progress = progress_value;
        self.current_word_index = word_index;

        if (self.event_callback) |cb| {
            cb(.{ .word_spoken = word_index });
        }
    }

    fn simulateFinished(self: *Self) void {
        self.state = .finished;
        self.progress = 1.0;

        if (self.event_callback) |cb| {
            cb(.synthesis_finished);
        }

        if (self.utterance_queue.items.len > 0) {
            self.skipToNext() catch {};
        } else {
            self.state = .idle;
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
// Events
// ============================================================================

pub const RecognitionEvent = union(enum) {
    recognition_started: void,
    recognition_stopped: void,
    recognition_cancelled: void,
    partial_result: TranscriptionResult,
    final_result: TranscriptionResult,
    audio_level_changed: f32,
    silence_detected: void,
    error_occurred: []const u8,
};

pub const SynthesisEvent = union(enum) {
    synthesis_started: []const u8,
    synthesis_paused: void,
    synthesis_resumed: void,
    synthesis_cancelled: void,
    synthesis_finished: void,
    word_spoken: usize,
    progress_updated: f32,
    error_occurred: []const u8,
};

// ============================================================================
// Utility Functions
// ============================================================================

pub fn normalizeText(allocator: Allocator, text: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    var prev_space = true;
    for (text) |c| {
        const is_space = c == ' ' or c == '\t' or c == '\n' or c == '\r';
        if (is_space) {
            if (!prev_space) {
                try result.append(' ');
            }
            prev_space = true;
        } else {
            try result.append(c);
            prev_space = false;
        }
    }

    if (result.items.len > 0 and result.items[result.items.len - 1] == ' ') {
        _ = result.pop();
    }

    return result.toOwnedSlice();
}

pub fn countWords(text: []const u8) usize {
    var count: usize = 0;
    var in_word = false;

    for (text) |c| {
        if (c == ' ' or c == '\t' or c == '\n') {
            in_word = false;
        } else if (!in_word) {
            in_word = true;
            count += 1;
        }
    }

    return count;
}

pub fn estimateSpeechDuration(text: []const u8, words_per_minute: f32) i64 {
    const words = countWords(text);
    const minutes = @as(f32, @floatFromInt(words)) / words_per_minute;
    return @intFromFloat(minutes * 60000.0);
}

pub fn languageFromLocale(locale: []const u8) ?Language {
    const languages = [_]Language{
        Language.english_us,
        Language.english_uk,
        Language.spanish,
        Language.french,
        Language.german,
        Language.italian,
        Language.japanese,
        Language.korean,
        Language.chinese_simplified,
        Language.chinese_traditional,
        Language.portuguese,
        Language.russian,
        Language.arabic,
        Language.hindi,
    };

    for (languages) |lang| {
        if (std.mem.eql(u8, lang.code, locale)) {
            return lang;
        }
    }

    for (languages) |lang| {
        if (locale.len >= 2 and std.mem.eql(u8, lang.code[0..2], locale[0..2])) {
            return lang;
        }
    }

    return null;
}

// ============================================================================
// Tests
// ============================================================================

test "RecognitionState isActive" {
    try std.testing.expect(RecognitionState.listening.isActive());
    try std.testing.expect(RecognitionState.processing.isActive());
    try std.testing.expect(!RecognitionState.idle.isActive());
    try std.testing.expect(!RecognitionState.finished.isActive());
}

test "SynthesisState isActive and isSpeaking" {
    try std.testing.expect(SynthesisState.speaking.isActive());
    try std.testing.expect(SynthesisState.paused.isActive());
    try std.testing.expect(!SynthesisState.idle.isActive());

    try std.testing.expect(SynthesisState.speaking.isSpeaking());
    try std.testing.expect(!SynthesisState.paused.isSpeaking());
}

test "AuthorizationStatus isAuthorized" {
    try std.testing.expect(AuthorizationStatus.authorized.isAuthorized());
    try std.testing.expect(!AuthorizationStatus.denied.isAuthorized());
    try std.testing.expect(!AuthorizationStatus.not_determined.isAuthorized());
}

test "TranscriptionConfidence fromScore" {
    try std.testing.expectEqual(TranscriptionConfidence.high, TranscriptionConfidence.fromScore(0.95));
    try std.testing.expectEqual(TranscriptionConfidence.medium, TranscriptionConfidence.fromScore(0.8));
    try std.testing.expectEqual(TranscriptionConfidence.low, TranscriptionConfidence.fromScore(0.5));
}

test "Language equality" {
    const lang1 = Language.english_us;
    const lang2 = Language.english_us;
    const lang3 = Language.spanish;

    try std.testing.expect(lang1.eql(lang2));
    try std.testing.expect(!lang1.eql(lang3));
}

test "Language displayName" {
    const lang1 = Language.english_us;
    try std.testing.expectEqualStrings("English (US)", lang1.displayName());

    const lang2 = Language.init("xx-XX");
    try std.testing.expectEqualStrings("xx-XX", lang2.displayName());
}

test "Voice supportsLanguage" {
    const voice = Voice{
        .id = "test",
        .name = "Test Voice",
        .language = Language.english_us,
    };

    try std.testing.expect(voice.supportsLanguage(Language.english_us));
    try std.testing.expect(voice.supportsLanguage(Language.english_uk));
    try std.testing.expect(!voice.supportsLanguage(Language.spanish));
}

test "TranscriptionSegment duration" {
    const segment = TranscriptionSegment{
        .text = "hello",
        .start_time_ms = 1000,
        .end_time_ms = 2500,
        .confidence = 0.85,
    };

    try std.testing.expectEqual(@as(i64, 1500), segment.duration_ms());
    try std.testing.expectEqual(TranscriptionConfidence.medium, segment.confidenceLevel());
}

test "TranscriptionResult wordCount" {
    const result = TranscriptionResult{
        .text = "Hello world this is a test",
        .confidence = 0.9,
    };

    try std.testing.expectEqual(@as(usize, 6), result.wordCount());
    try std.testing.expectEqual(TranscriptionConfidence.high, result.confidenceLevel());
}

test "SpeechUtterance init" {
    const utterance = SpeechUtterance.init("Hello world");
    try std.testing.expectEqualStrings("Hello world", utterance.text);
    try std.testing.expectEqual(@as(f32, 1.0), utterance.rate);
    try std.testing.expectEqual(@as(f32, 1.0), utterance.pitch);
}

test "SpeechUtterance builder pattern" {
    const utterance = SpeechUtterance.init("Hello")
        .withRate(1.5)
        .withPitch(0.8)
        .withVolume(0.9);

    try std.testing.expectEqual(@as(f32, 1.5), utterance.rate);
    try std.testing.expectEqual(@as(f32, 0.8), utterance.pitch);
    try std.testing.expectEqual(@as(f32, 0.9), utterance.volume);
}

test "SpeechUtterance rate clamping" {
    const utterance1 = SpeechUtterance.init("Test").withRate(5.0);
    try std.testing.expectEqual(@as(f32, 3.0), utterance1.rate);

    const utterance2 = SpeechUtterance.init("Test").withRate(0.01);
    try std.testing.expectEqual(@as(f32, 0.1), utterance2.rate);
}

test "SpeechUtterance estimatedDuration" {
    const utterance = SpeechUtterance.init("one two three four five six seven eight nine ten");
    const duration = utterance.estimatedDurationMs();
    try std.testing.expect(duration > 0);
}

test "SpeechRecognizer initialization" {
    var recognizer = SpeechRecognizer.init(std.testing.allocator);
    defer recognizer.deinit();

    try std.testing.expectEqual(RecognitionState.idle, recognizer.getState());
    try std.testing.expect(!recognizer.isListening());
}

test "SpeechRecognizer authorization" {
    var recognizer = SpeechRecognizer.init(std.testing.allocator);
    defer recognizer.deinit();

    try std.testing.expect(!recognizer.isAuthorized());

    const status = try recognizer.requestAuthorization();
    try std.testing.expectEqual(AuthorizationStatus.authorized, status);
    try std.testing.expect(recognizer.isAuthorized());
}

test "SpeechRecognizer start requires authorization" {
    var recognizer = SpeechRecognizer.init(std.testing.allocator);
    defer recognizer.deinit();

    const result = recognizer.start(.{});
    try std.testing.expectError(error.NotAuthorized, result);
}

test "SpeechRecognizer start and cancel" {
    var recognizer = SpeechRecognizer.init(std.testing.allocator);
    defer recognizer.deinit();

    _ = try recognizer.requestAuthorization();
    try recognizer.start(.{});

    try std.testing.expect(recognizer.isListening());

    recognizer.cancel();
    try std.testing.expectEqual(RecognitionState.idle, recognizer.getState());
}

test "SpeechRecognizer getSupportedLanguages" {
    const languages = SpeechRecognizer.getSupportedLanguages();
    try std.testing.expect(languages.len > 0);
}

test "SpeechSynthesizer initialization" {
    var synthesizer = SpeechSynthesizer.init(std.testing.allocator);
    defer synthesizer.deinit();

    try std.testing.expectEqual(SynthesisState.idle, synthesizer.getState());
    try std.testing.expect(!synthesizer.isSpeaking());
}

test "SpeechSynthesizer loadVoices" {
    var synthesizer = SpeechSynthesizer.init(std.testing.allocator);
    defer synthesizer.deinit();

    try synthesizer.loadVoices();
    try std.testing.expect(synthesizer.getAvailableVoices().len > 0);
}

test "SpeechSynthesizer speak" {
    var synthesizer = SpeechSynthesizer.init(std.testing.allocator);
    defer synthesizer.deinit();

    try synthesizer.speakText("Hello world");
    try std.testing.expect(synthesizer.isSpeaking());
}

test "SpeechSynthesizer pause and resume" {
    var synthesizer = SpeechSynthesizer.init(std.testing.allocator);
    defer synthesizer.deinit();

    try synthesizer.speakText("Hello world");

    synthesizer.pause();
    try std.testing.expect(synthesizer.isPaused());

    synthesizer.resumeSpeaking();
    try std.testing.expect(synthesizer.isSpeaking());
}

test "SpeechSynthesizer stop" {
    var synthesizer = SpeechSynthesizer.init(std.testing.allocator);
    defer synthesizer.deinit();

    try synthesizer.speakText("Hello world");
    synthesizer.stop();

    try std.testing.expectEqual(SynthesisState.idle, synthesizer.getState());
}

test "SpeechSynthesizer queue" {
    var synthesizer = SpeechSynthesizer.init(std.testing.allocator);
    defer synthesizer.deinit();

    try synthesizer.speakText("First utterance");
    try synthesizer.speakText("Second utterance");
    try synthesizer.speakText("Third utterance");

    try std.testing.expectEqual(@as(usize, 2), synthesizer.getQueueLength());

    synthesizer.clearQueue();
    try std.testing.expectEqual(@as(usize, 0), synthesizer.getQueueLength());
}

test "SpeechSynthesizer getDefaultVoice" {
    var synthesizer = SpeechSynthesizer.init(std.testing.allocator);
    defer synthesizer.deinit();

    try synthesizer.loadVoices();

    const voice = synthesizer.getDefaultVoice(Language.english_us);
    try std.testing.expect(voice != null);
}

test "countWords" {
    try std.testing.expectEqual(@as(usize, 5), countWords("Hello world this is test"));
    try std.testing.expectEqual(@as(usize, 0), countWords(""));
    try std.testing.expectEqual(@as(usize, 1), countWords("hello"));
    try std.testing.expectEqual(@as(usize, 3), countWords("  multiple   spaces  here  "));
}

test "estimateSpeechDuration" {
    const duration = estimateSpeechDuration("one two three four five six seven eight nine ten", 150.0);
    try std.testing.expect(duration > 0);
}

test "languageFromLocale" {
    const lang1 = languageFromLocale("en-US");
    try std.testing.expect(lang1 != null);
    try std.testing.expectEqualStrings("en-US", lang1.?.code);

    const lang2 = languageFromLocale("es-ES");
    try std.testing.expect(lang2 != null);

    const lang3 = languageFromLocale("en");
    try std.testing.expect(lang3 != null);

    const lang4 = languageFromLocale("xx-YY");
    try std.testing.expect(lang4 == null);
}

test "VoiceQuality toString" {
    try std.testing.expectEqualStrings("default", VoiceQuality.default.toString());
    try std.testing.expectEqualStrings("enhanced", VoiceQuality.enhanced.toString());
    try std.testing.expectEqualStrings("premium", VoiceQuality.premium.toString());
}

test "VoiceGender toString" {
    try std.testing.expectEqualStrings("male", VoiceGender.male.toString());
    try std.testing.expectEqualStrings("female", VoiceGender.female.toString());
    try std.testing.expectEqualStrings("neutral", VoiceGender.neutral.toString());
}

test "RecognitionMode toString" {
    try std.testing.expectEqualStrings("dictation", RecognitionMode.dictation.toString());
    try std.testing.expectEqualStrings("command", RecognitionMode.command.toString());
    try std.testing.expectEqualStrings("search", RecognitionMode.search.toString());
}

test "RecognitionOptions defaults" {
    const options = RecognitionOptions{};
    try std.testing.expect(options.partial_results);
    try std.testing.expect(options.punctuation);
    try std.testing.expect(!options.profanity_filter);
}

test "SynthesisOptions defaults" {
    const options = SynthesisOptions{};
    try std.testing.expectEqual(@as(f32, 1.0), options.rate);
    try std.testing.expectEqual(@as(f32, 1.0), options.pitch);
    try std.testing.expectEqual(@as(f32, 1.0), options.volume);
}
