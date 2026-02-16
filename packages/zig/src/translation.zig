const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

/// Cross-platform on-device translation module.
/// Provides unified API for Apple Translation framework, ML Kit, and offline translation engines.

// ============================================================================
// Platform Detection
// ============================================================================

pub const Platform = enum {
    ios,
    macos,
    android,
    linux,
    windows,
    unsupported,

    pub fn current() Platform {
        return switch (builtin.os.tag) {
            .ios => .ios,
            .macos => .macos,
            .linux => if (builtin.abi == .android) .android else .linux,
            .windows => .windows,
            else => .unsupported,
        };
    }

    pub fn supportsOnDeviceTranslation(self: Platform) bool {
        return switch (self) {
            .ios, .macos, .android => true,
            .linux, .windows, .unsupported => false,
        };
    }

    pub fn supportsNeuralTranslation(self: Platform) bool {
        return switch (self) {
            .ios, .macos => true,
            .android, .linux, .windows, .unsupported => false,
        };
    }
};

// ============================================================================
// Helper Functions
// ============================================================================

fn getCurrentTimestamp() i64 {
    if (builtin.os.tag == .macos or builtin.os.tag == .ios or
        builtin.os.tag == .linux or builtin.os.tag == .windows)
    {
        var ts: std.c.timespec = undefined;
        if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
            return ts.sec;
        }
        return 0;
    }
    return 0;
}

// ============================================================================
// Language Types
// ============================================================================

/// Supported language identifiers (BCP-47 codes)
pub const Language = enum {
    en, // English
    es, // Spanish
    fr, // French
    de, // German
    it, // Italian
    pt, // Portuguese
    ru, // Russian
    zh, // Chinese (Simplified)
    zh_tw, // Chinese (Traditional)
    ja, // Japanese
    ko, // Korean
    ar, // Arabic
    hi, // Hindi
    th, // Thai
    vi, // Vietnamese
    id, // Indonesian
    ms, // Malay
    tr, // Turkish
    pl, // Polish
    nl, // Dutch
    sv, // Swedish
    da, // Danish
    fi, // Finnish
    no, // Norwegian
    el, // Greek
    he, // Hebrew
    cs, // Czech
    hu, // Hungarian
    ro, // Romanian
    uk, // Ukrainian
    unknown,

    pub fn fromCode(code: []const u8) Language {
        const mappings = .{
            .{ "en", .en },
            .{ "es", .es },
            .{ "fr", .fr },
            .{ "de", .de },
            .{ "it", .it },
            .{ "pt", .pt },
            .{ "ru", .ru },
            .{ "zh", .zh },
            .{ "zh-TW", .zh_tw },
            .{ "zh-Hant", .zh_tw },
            .{ "ja", .ja },
            .{ "ko", .ko },
            .{ "ar", .ar },
            .{ "hi", .hi },
            .{ "th", .th },
            .{ "vi", .vi },
            .{ "id", .id },
            .{ "ms", .ms },
            .{ "tr", .tr },
            .{ "pl", .pl },
            .{ "nl", .nl },
            .{ "sv", .sv },
            .{ "da", .da },
            .{ "fi", .fi },
            .{ "no", .no },
            .{ "el", .el },
            .{ "he", .he },
            .{ "cs", .cs },
            .{ "hu", .hu },
            .{ "ro", .ro },
            .{ "uk", .uk },
        };

        inline for (mappings) |mapping| {
            if (std.mem.eql(u8, code, mapping[0])) {
                return mapping[1];
            }
        }
        return .unknown;
    }

    pub fn toCode(self: Language) []const u8 {
        return switch (self) {
            .en => "en",
            .es => "es",
            .fr => "fr",
            .de => "de",
            .it => "it",
            .pt => "pt",
            .ru => "ru",
            .zh => "zh",
            .zh_tw => "zh-TW",
            .ja => "ja",
            .ko => "ko",
            .ar => "ar",
            .hi => "hi",
            .th => "th",
            .vi => "vi",
            .id => "id",
            .ms => "ms",
            .tr => "tr",
            .pl => "pl",
            .nl => "nl",
            .sv => "sv",
            .da => "da",
            .fi => "fi",
            .no => "no",
            .el => "el",
            .he => "he",
            .cs => "cs",
            .hu => "hu",
            .ro => "ro",
            .uk => "uk",
            .unknown => "unknown",
        };
    }

    pub fn getDisplayName(self: Language) []const u8 {
        return switch (self) {
            .en => "English",
            .es => "Spanish",
            .fr => "French",
            .de => "German",
            .it => "Italian",
            .pt => "Portuguese",
            .ru => "Russian",
            .zh => "Chinese (Simplified)",
            .zh_tw => "Chinese (Traditional)",
            .ja => "Japanese",
            .ko => "Korean",
            .ar => "Arabic",
            .hi => "Hindi",
            .th => "Thai",
            .vi => "Vietnamese",
            .id => "Indonesian",
            .ms => "Malay",
            .tr => "Turkish",
            .pl => "Polish",
            .nl => "Dutch",
            .sv => "Swedish",
            .da => "Danish",
            .fi => "Finnish",
            .no => "Norwegian",
            .el => "Greek",
            .he => "Hebrew",
            .cs => "Czech",
            .hu => "Hungarian",
            .ro => "Romanian",
            .uk => "Ukrainian",
            .unknown => "Unknown",
        };
    }

    pub fn isRTL(self: Language) bool {
        return switch (self) {
            .ar, .he => true,
            else => false,
        };
    }
};

/// Language pair for translation
pub const LanguagePair = struct {
    source: Language,
    target: Language,

    pub fn init(source: Language, target: Language) LanguagePair {
        return .{ .source = source, .target = target };
    }

    pub fn reversed(self: LanguagePair) LanguagePair {
        return .{ .source = self.target, .target = self.source };
    }

    pub fn isValid(self: LanguagePair) bool {
        return self.source != .unknown and self.target != .unknown and self.source != self.target;
    }

    pub fn getDisplayString(self: LanguagePair) struct { src: []const u8, tgt: []const u8 } {
        return .{
            .src = self.source.getDisplayName(),
            .tgt = self.target.getDisplayName(),
        };
    }
};

// ============================================================================
// Translation Status
// ============================================================================

/// Translation operation status
pub const TranslationStatus = enum {
    success,
    language_not_supported,
    model_not_downloaded,
    download_in_progress,
    download_failed,
    translation_failed,
    input_too_long,
    network_required,
    service_unavailable,
    cancelled,
    unknown_error,

    pub fn isSuccess(self: TranslationStatus) bool {
        return self == .success;
    }

    pub fn isRetryable(self: TranslationStatus) bool {
        return switch (self) {
            .download_failed, .translation_failed, .service_unavailable => true,
            else => false,
        };
    }

    pub fn getDescription(self: TranslationStatus) []const u8 {
        return switch (self) {
            .success => "Translation successful",
            .language_not_supported => "Language pair not supported",
            .model_not_downloaded => "Translation model not downloaded",
            .download_in_progress => "Model download in progress",
            .download_failed => "Model download failed",
            .translation_failed => "Translation failed",
            .input_too_long => "Input text too long",
            .network_required => "Network connection required",
            .service_unavailable => "Translation service unavailable",
            .cancelled => "Translation cancelled",
            .unknown_error => "An unknown error occurred",
        };
    }
};

// ============================================================================
// Translation Model
// ============================================================================

/// Translation model information
pub const TranslationModel = struct {
    language_pair: LanguagePair,
    model_size_bytes: u64,
    is_downloaded: bool,
    download_progress: f32,
    version: u32,
    supports_offline: bool,
    quality_tier: QualityTier,

    pub const QualityTier = enum {
        standard,
        enhanced,
        premium,

        pub fn getDisplayName(self: QualityTier) []const u8 {
            return switch (self) {
                .standard => "Standard",
                .enhanced => "Enhanced",
                .premium => "Premium",
            };
        }
    };

    pub fn init(language_pair: LanguagePair) TranslationModel {
        return .{
            .language_pair = language_pair,
            .model_size_bytes = 50 * 1024 * 1024, // 50MB default
            .is_downloaded = false,
            .download_progress = 0.0,
            .version = 1,
            .supports_offline = true,
            .quality_tier = .standard,
        };
    }

    pub fn withSize(self: TranslationModel, size_bytes: u64) TranslationModel {
        var result = self;
        result.model_size_bytes = size_bytes;
        return result;
    }

    pub fn withDownloaded(self: TranslationModel, downloaded: bool) TranslationModel {
        var result = self;
        result.is_downloaded = downloaded;
        result.download_progress = if (downloaded) 1.0 else 0.0;
        return result;
    }

    pub fn withQuality(self: TranslationModel, tier: QualityTier) TranslationModel {
        var result = self;
        result.quality_tier = tier;
        return result;
    }

    pub fn getModelSizeMB(self: TranslationModel) f32 {
        return @as(f32, @floatFromInt(self.model_size_bytes)) / (1024 * 1024);
    }

    pub fn isReady(self: TranslationModel) bool {
        return self.is_downloaded and self.language_pair.isValid();
    }
};

// ============================================================================
// Translation Request
// ============================================================================

/// Translation request configuration
pub const TranslationRequest = struct {
    text: [4096]u8,
    text_len: usize,
    language_pair: LanguagePair,
    preserve_formatting: bool,
    detect_source_language: bool,
    request_id: [64]u8,
    request_id_len: usize,
    created_at: i64,
    max_length: u32,

    pub fn init(language_pair: LanguagePair) TranslationRequest {
        return .{
            .text = [_]u8{0} ** 4096,
            .text_len = 0,
            .language_pair = language_pair,
            .preserve_formatting = true,
            .detect_source_language = false,
            .request_id = [_]u8{0} ** 64,
            .request_id_len = 0,
            .created_at = getCurrentTimestamp(),
            .max_length = 4096,
        };
    }

    pub fn withText(self: TranslationRequest, text: []const u8) TranslationRequest {
        var result = self;
        const copy_len = @min(text.len, 4096);
        @memcpy(result.text[0..copy_len], text[0..copy_len]);
        result.text_len = copy_len;
        return result;
    }

    pub fn withPreserveFormatting(self: TranslationRequest, preserve: bool) TranslationRequest {
        var result = self;
        result.preserve_formatting = preserve;
        return result;
    }

    pub fn withAutoDetect(self: TranslationRequest, detect: bool) TranslationRequest {
        var result = self;
        result.detect_source_language = detect;
        return result;
    }

    pub fn withRequestId(self: TranslationRequest, request_id: []const u8) TranslationRequest {
        var result = self;
        const copy_len = @min(request_id.len, 64);
        @memcpy(result.request_id[0..copy_len], request_id[0..copy_len]);
        result.request_id_len = copy_len;
        return result;
    }

    pub fn getTextSlice(self: *const TranslationRequest) []const u8 {
        return self.text[0..self.text_len];
    }

    pub fn getRequestIdSlice(self: *const TranslationRequest) []const u8 {
        return self.request_id[0..self.request_id_len];
    }

    pub fn isValid(self: *const TranslationRequest) bool {
        return self.text_len > 0 and
            self.text_len <= self.max_length and
            (self.detect_source_language or self.language_pair.source != .unknown) and
            self.language_pair.target != .unknown;
    }
};

// ============================================================================
// Translation Result
// ============================================================================

/// Translation result
pub const TranslationResult = struct {
    status: TranslationStatus,
    translated_text: [8192]u8,
    translated_text_len: usize,
    detected_source_language: Language,
    language_pair: LanguagePair,
    confidence: f32,
    processing_time_ms: u32,
    timestamp: i64,
    request_id: [64]u8,
    request_id_len: usize,

    pub fn init(status: TranslationStatus, language_pair: LanguagePair) TranslationResult {
        return .{
            .status = status,
            .translated_text = [_]u8{0} ** 8192,
            .translated_text_len = 0,
            .detected_source_language = language_pair.source,
            .language_pair = language_pair,
            .confidence = 0.0,
            .processing_time_ms = 0,
            .timestamp = getCurrentTimestamp(),
            .request_id = [_]u8{0} ** 64,
            .request_id_len = 0,
        };
    }

    pub fn withTranslatedText(self: TranslationResult, text: []const u8) TranslationResult {
        var result = self;
        const copy_len = @min(text.len, 8192);
        @memcpy(result.translated_text[0..copy_len], text[0..copy_len]);
        result.translated_text_len = copy_len;
        return result;
    }

    pub fn withDetectedLanguage(self: TranslationResult, lang: Language) TranslationResult {
        var result = self;
        result.detected_source_language = lang;
        return result;
    }

    pub fn withConfidence(self: TranslationResult, confidence: f32) TranslationResult {
        var result = self;
        result.confidence = confidence;
        return result;
    }

    pub fn withProcessingTime(self: TranslationResult, time_ms: u32) TranslationResult {
        var result = self;
        result.processing_time_ms = time_ms;
        return result;
    }

    pub fn withRequestId(self: TranslationResult, request_id: []const u8) TranslationResult {
        var result = self;
        const copy_len = @min(request_id.len, 64);
        @memcpy(result.request_id[0..copy_len], request_id[0..copy_len]);
        result.request_id_len = copy_len;
        return result;
    }

    pub fn getTranslatedTextSlice(self: *const TranslationResult) []const u8 {
        return self.translated_text[0..self.translated_text_len];
    }

    pub fn getRequestIdSlice(self: *const TranslationResult) []const u8 {
        return self.request_id[0..self.request_id_len];
    }

    pub fn isSuccess(self: *const TranslationResult) bool {
        return self.status.isSuccess();
    }

    pub fn hasHighConfidence(self: *const TranslationResult) bool {
        return self.confidence >= 0.8;
    }
};

// ============================================================================
// Language Detection Result
// ============================================================================

/// Language detection result
pub const LanguageDetectionResult = struct {
    detected_language: Language,
    confidence: f32,
    alternatives: [5]LanguageCandidate,
    alternatives_count: usize,
    timestamp: i64,

    pub const LanguageCandidate = struct {
        language: Language,
        confidence: f32,
    };

    pub fn init(detected: Language, confidence: f32) LanguageDetectionResult {
        return .{
            .detected_language = detected,
            .confidence = confidence,
            .alternatives = [_]LanguageCandidate{.{ .language = .unknown, .confidence = 0.0 }} ** 5,
            .alternatives_count = 0,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn addAlternative(self: *LanguageDetectionResult, language: Language, confidence: f32) void {
        if (self.alternatives_count < 5) {
            self.alternatives[self.alternatives_count] = .{
                .language = language,
                .confidence = confidence,
            };
            self.alternatives_count += 1;
        }
    }

    pub fn getAlternatives(self: *const LanguageDetectionResult) []const LanguageCandidate {
        return self.alternatives[0..self.alternatives_count];
    }

    pub fn isConfident(self: *const LanguageDetectionResult) bool {
        return self.confidence >= 0.7;
    }
};

// ============================================================================
// Download Progress
// ============================================================================

/// Model download progress
pub const DownloadProgress = struct {
    language_pair: LanguagePair,
    bytes_downloaded: u64,
    total_bytes: u64,
    progress: f32,
    is_complete: bool,
    is_failed: bool,
    error_message: [256]u8,
    error_message_len: usize,
    started_at: i64,
    completed_at: i64,

    pub fn init(language_pair: LanguagePair, total_bytes: u64) DownloadProgress {
        return .{
            .language_pair = language_pair,
            .bytes_downloaded = 0,
            .total_bytes = total_bytes,
            .progress = 0.0,
            .is_complete = false,
            .is_failed = false,
            .error_message = [_]u8{0} ** 256,
            .error_message_len = 0,
            .started_at = getCurrentTimestamp(),
            .completed_at = 0,
        };
    }

    pub fn updateProgress(self: *DownloadProgress, bytes_downloaded: u64) void {
        self.bytes_downloaded = bytes_downloaded;
        if (self.total_bytes > 0) {
            self.progress = @as(f32, @floatFromInt(bytes_downloaded)) /
                @as(f32, @floatFromInt(self.total_bytes));
        }
        if (bytes_downloaded >= self.total_bytes) {
            self.is_complete = true;
            self.completed_at = getCurrentTimestamp();
        }
    }

    pub fn markFailed(self: *DownloadProgress, error_message: []const u8) void {
        self.is_failed = true;
        const copy_len = @min(error_message.len, 256);
        @memcpy(self.error_message[0..copy_len], error_message[0..copy_len]);
        self.error_message_len = copy_len;
        self.completed_at = getCurrentTimestamp();
    }

    pub fn getErrorMessageSlice(self: *const DownloadProgress) []const u8 {
        return self.error_message[0..self.error_message_len];
    }

    pub fn getProgressPercent(self: *const DownloadProgress) u8 {
        return @as(u8, @intFromFloat(self.progress * 100));
    }

    pub fn getElapsedSeconds(self: *const DownloadProgress) i64 {
        const end_time = if (self.completed_at > 0) self.completed_at else getCurrentTimestamp();
        return end_time - self.started_at;
    }
};

// ============================================================================
// Translation Event
// ============================================================================

/// Translation events
pub const TranslationEvent = struct {
    event_type: EventType,
    language_pair: LanguagePair,
    timestamp: i64,
    message: [256]u8,
    message_len: usize,

    pub const EventType = enum {
        translation_started,
        translation_completed,
        translation_failed,
        model_download_started,
        model_download_progress,
        model_download_completed,
        model_download_failed,
        language_detected,
        service_available,
        service_unavailable,
    };

    pub fn init(event_type: EventType, language_pair: LanguagePair) TranslationEvent {
        return .{
            .event_type = event_type,
            .language_pair = language_pair,
            .timestamp = getCurrentTimestamp(),
            .message = [_]u8{0} ** 256,
            .message_len = 0,
        };
    }

    pub fn withMessage(self: TranslationEvent, message: []const u8) TranslationEvent {
        var result = self;
        const copy_len = @min(message.len, 256);
        @memcpy(result.message[0..copy_len], message[0..copy_len]);
        result.message_len = copy_len;
        return result;
    }

    pub fn getMessageSlice(self: *const TranslationEvent) []const u8 {
        return self.message[0..self.message_len];
    }
};

// ============================================================================
// Translation Engine
// ============================================================================

/// Translation engine type
pub const TranslationEngine = enum {
    apple_translation, // iOS/macOS Translation framework
    ml_kit, // Google ML Kit
    libretranslate, // Open source
    argos_translate, // Open source offline
    custom, // Custom implementation

    pub fn isAvailable(self: TranslationEngine) bool {
        const platform = Platform.current();
        return switch (self) {
            .apple_translation => platform == .ios or platform == .macos,
            .ml_kit => platform == .android,
            .libretranslate => true,
            .argos_translate => true,
            .custom => true,
        };
    }

    pub fn supportsOffline(self: TranslationEngine) bool {
        return switch (self) {
            .apple_translation, .ml_kit, .argos_translate => true,
            .libretranslate, .custom => false,
        };
    }

    pub fn getDisplayName(self: TranslationEngine) []const u8 {
        return switch (self) {
            .apple_translation => "Apple Translation",
            .ml_kit => "ML Kit",
            .libretranslate => "LibreTranslate",
            .argos_translate => "Argos Translate",
            .custom => "Custom",
        };
    }
};

// ============================================================================
// Offline Translation Service
// ============================================================================

/// On-device offline translation service
pub const OfflineTranslationService = struct {
    engine: TranslationEngine,
    downloaded_models: std.ArrayListUnmanaged(TranslationModel),
    active_downloads: std.ArrayListUnmanaged(DownloadProgress),
    is_initialized: bool,

    pub fn init(engine: TranslationEngine) OfflineTranslationService {
        return .{
            .engine = engine,
            .downloaded_models = .empty,
            .active_downloads = .empty,
            .is_initialized = true,
        };
    }

    pub fn deinit(self: *OfflineTranslationService, allocator: Allocator) void {
        self.downloaded_models.deinit(allocator);
        self.active_downloads.deinit(allocator);
        self.is_initialized = false;
    }

    pub fn isModelDownloaded(self: *const OfflineTranslationService, language_pair: LanguagePair) bool {
        for (self.downloaded_models.items) |model| {
            if (model.language_pair.source == language_pair.source and
                model.language_pair.target == language_pair.target and
                model.is_downloaded)
            {
                return true;
            }
        }
        return false;
    }

    pub fn downloadModel(self: *OfflineTranslationService, language_pair: LanguagePair, allocator: Allocator) DownloadProgress {
        // Check if already downloaded
        if (self.isModelDownloaded(language_pair)) {
            var progress = DownloadProgress.init(language_pair, 0);
            progress.is_complete = true;
            progress.progress = 1.0;
            return progress;
        }

        // Check if download already in progress
        for (self.active_downloads.items) |download| {
            if (download.language_pair.source == language_pair.source and
                download.language_pair.target == language_pair.target and
                !download.is_complete and !download.is_failed)
            {
                return download;
            }
        }

        // Simulate starting a new download
        const model_size: u64 = 50 * 1024 * 1024; // 50MB
        const progress = DownloadProgress.init(language_pair, model_size);
        self.active_downloads.append(allocator, progress) catch {};

        return progress;
    }

    pub fn addDownloadedModel(self: *OfflineTranslationService, model: TranslationModel, allocator: Allocator) void {
        self.downloaded_models.append(allocator, model) catch {};
    }

    pub fn getDownloadedModels(self: *const OfflineTranslationService) []const TranslationModel {
        return self.downloaded_models.items;
    }

    pub fn translate(self: *OfflineTranslationService, request: TranslationRequest) TranslationResult {
        if (!request.isValid()) {
            return TranslationResult.init(.translation_failed, request.language_pair);
        }

        if (!self.isModelDownloaded(request.language_pair)) {
            return TranslationResult.init(.model_not_downloaded, request.language_pair);
        }

        // Simulate translation
        const source_text = request.getTextSlice();
        var translated: [8192]u8 = [_]u8{0} ** 8192;
        const prefix = "[Translated] ";
        const prefix_len = prefix.len;
        @memcpy(translated[0..prefix_len], prefix);

        const text_copy_len = @min(source_text.len, 8192 - prefix_len);
        @memcpy(translated[prefix_len .. prefix_len + text_copy_len], source_text[0..text_copy_len]);

        return TranslationResult.init(.success, request.language_pair)
            .withTranslatedText(translated[0 .. prefix_len + text_copy_len])
            .withConfidence(0.95)
            .withProcessingTime(50);
    }

    pub fn deleteModel(self: *OfflineTranslationService, language_pair: LanguagePair, allocator: Allocator) bool {
        var i: usize = 0;
        while (i < self.downloaded_models.items.len) {
            const model = self.downloaded_models.items[i];
            if (model.language_pair.source == language_pair.source and
                model.language_pair.target == language_pair.target)
            {
                _ = self.downloaded_models.orderedRemove(i);
                _ = allocator;
                return true;
            }
            i += 1;
        }
        return false;
    }

    pub fn getTotalStorageUsed(self: *const OfflineTranslationService) u64 {
        var total: u64 = 0;
        for (self.downloaded_models.items) |model| {
            if (model.is_downloaded) {
                total += model.model_size_bytes;
            }
        }
        return total;
    }
};

// ============================================================================
// Language Detector
// ============================================================================

/// Language detection service
pub const LanguageDetector = struct {
    min_confidence: f32,
    max_text_length: u32,
    detection_count: u64,

    pub fn init() LanguageDetector {
        return .{
            .min_confidence = 0.5,
            .max_text_length = 1000,
            .detection_count = 0,
        };
    }

    pub fn withMinConfidence(self: LanguageDetector, min_confidence: f32) LanguageDetector {
        var result = self;
        result.min_confidence = min_confidence;
        return result;
    }

    pub fn detect(self: *LanguageDetector, text: []const u8) LanguageDetectionResult {
        self.detection_count += 1;

        if (text.len == 0) {
            return LanguageDetectionResult.init(.unknown, 0.0);
        }

        // Simple heuristic-based detection (simulation)
        // Check for common language patterns
        var detected = Language.en;
        var confidence: f32 = 0.8;

        // Check for CJK characters
        for (text) |byte| {
            if (byte > 127) {
                // Non-ASCII - could be various languages
                detected = .zh;
                confidence = 0.6;
                break;
            }
        }

        // Check for common English words
        if (std.mem.indexOf(u8, text, "the") != null or
            std.mem.indexOf(u8, text, "and") != null or
            std.mem.indexOf(u8, text, "is") != null)
        {
            detected = .en;
            confidence = 0.9;
        }

        var result = LanguageDetectionResult.init(detected, confidence);

        // Add some alternatives
        if (detected == .en) {
            result.addAlternative(.de, 0.1);
            result.addAlternative(.fr, 0.05);
        }

        return result;
    }

    pub fn getDetectionCount(self: *const LanguageDetector) u64 {
        return self.detection_count;
    }
};

// ============================================================================
// Translation Controller
// ============================================================================

/// Main controller for translation operations
pub const TranslationController = struct {
    engine: TranslationEngine,
    offline_service: OfflineTranslationService,
    language_detector: LanguageDetector,
    event_history: std.ArrayListUnmanaged(TranslationEvent),
    translation_history: std.ArrayListUnmanaged(TranslationResult),
    event_callback: ?*const fn (TranslationEvent) void,
    is_initialized: bool,
    supported_pairs: std.ArrayListUnmanaged(LanguagePair),

    pub fn init(engine: TranslationEngine) TranslationController {
        return .{
            .engine = engine,
            .offline_service = OfflineTranslationService.init(engine),
            .language_detector = LanguageDetector.init(),
            .event_history = .empty,
            .translation_history = .empty,
            .event_callback = null,
            .is_initialized = true,
            .supported_pairs = .empty,
        };
    }

    pub fn deinit(self: *TranslationController, allocator: Allocator) void {
        self.offline_service.deinit(allocator);
        self.event_history.deinit(allocator);
        self.translation_history.deinit(allocator);
        self.supported_pairs.deinit(allocator);
        self.is_initialized = false;
    }

    pub fn setEventCallback(self: *TranslationController, callback: *const fn (TranslationEvent) void) void {
        self.event_callback = callback;
    }

    fn emitEvent(self: *TranslationController, event: TranslationEvent, allocator: Allocator) void {
        self.event_history.append(allocator, event) catch {};
        if (self.event_callback) |callback| {
            callback(event);
        }
    }

    fn recordResult(self: *TranslationController, result: TranslationResult, allocator: Allocator) void {
        self.translation_history.append(allocator, result) catch {};
    }

    pub fn translate(self: *TranslationController, request: TranslationRequest, allocator: Allocator) TranslationResult {
        var actual_request = request;

        // Auto-detect source language if requested
        if (request.detect_source_language) {
            const detection = self.language_detector.detect(request.getTextSlice());
            if (detection.isConfident()) {
                actual_request.language_pair.source = detection.detected_language;

                self.emitEvent(
                    TranslationEvent.init(.language_detected, actual_request.language_pair)
                        .withMessage(detection.detected_language.getDisplayName()),
                    allocator,
                );
            }
        }

        self.emitEvent(
            TranslationEvent.init(.translation_started, actual_request.language_pair),
            allocator,
        );

        const result = self.offline_service.translate(actual_request);

        const event_type: TranslationEvent.EventType = if (result.status.isSuccess())
            .translation_completed
        else
            .translation_failed;

        self.emitEvent(
            TranslationEvent.init(event_type, actual_request.language_pair)
                .withMessage(result.status.getDescription()),
            allocator,
        );

        self.recordResult(result, allocator);
        return result;
    }

    pub fn downloadModel(self: *TranslationController, language_pair: LanguagePair, allocator: Allocator) DownloadProgress {
        self.emitEvent(
            TranslationEvent.init(.model_download_started, language_pair),
            allocator,
        );

        return self.offline_service.downloadModel(language_pair, allocator);
    }

    pub fn addModel(self: *TranslationController, model: TranslationModel, allocator: Allocator) void {
        self.offline_service.addDownloadedModel(model, allocator);

        if (model.is_downloaded) {
            self.emitEvent(
                TranslationEvent.init(.model_download_completed, model.language_pair),
                allocator,
            );
        }
    }

    pub fn detectLanguage(self: *TranslationController, text: []const u8, allocator: Allocator) LanguageDetectionResult {
        const result = self.language_detector.detect(text);

        self.emitEvent(
            TranslationEvent.init(.language_detected, LanguagePair.init(result.detected_language, .unknown))
                .withMessage(result.detected_language.getDisplayName()),
            allocator,
        );

        return result;
    }

    pub fn isLanguagePairSupported(self: *TranslationController, language_pair: LanguagePair) bool {
        // Check if we have a downloaded model
        if (self.offline_service.isModelDownloaded(language_pair)) {
            return true;
        }

        // Check supported pairs list
        for (self.supported_pairs.items) |pair| {
            if (pair.source == language_pair.source and pair.target == language_pair.target) {
                return true;
            }
        }

        return false;
    }

    pub fn addSupportedPair(self: *TranslationController, language_pair: LanguagePair, allocator: Allocator) void {
        self.supported_pairs.append(allocator, language_pair) catch {};
    }

    pub fn getDownloadedModels(self: *const TranslationController) []const TranslationModel {
        return self.offline_service.getDownloadedModels();
    }

    pub fn getEventHistory(self: *const TranslationController) []const TranslationEvent {
        return self.event_history.items;
    }

    pub fn getTranslationHistory(self: *const TranslationController) []const TranslationResult {
        return self.translation_history.items;
    }

    pub fn clearHistory(self: *TranslationController, allocator: Allocator) void {
        self.event_history.clearAndFree(allocator);
        self.translation_history.clearAndFree(allocator);
    }

    pub fn getStatistics(self: *const TranslationController) Statistics {
        var stats = Statistics{
            .total_translations = 0,
            .successful_translations = 0,
            .failed_translations = 0,
            .total_detections = self.language_detector.getDetectionCount(),
            .downloaded_models = self.offline_service.downloaded_models.items.len,
            .storage_used_bytes = self.offline_service.getTotalStorageUsed(),
        };

        for (self.translation_history.items) |result| {
            stats.total_translations += 1;
            if (result.status.isSuccess()) {
                stats.successful_translations += 1;
            } else {
                stats.failed_translations += 1;
            }
        }

        return stats;
    }

    pub const Statistics = struct {
        total_translations: u64,
        successful_translations: u64,
        failed_translations: u64,
        total_detections: u64,
        downloaded_models: usize,
        storage_used_bytes: u64,

        pub fn getSuccessRate(self: Statistics) f32 {
            if (self.total_translations == 0) return 0.0;
            return @as(f32, @floatFromInt(self.successful_translations)) /
                @as(f32, @floatFromInt(self.total_translations));
        }

        pub fn getStorageUsedMB(self: Statistics) f32 {
            return @as(f32, @floatFromInt(self.storage_used_bytes)) / (1024 * 1024);
        }
    };
};

// ============================================================================
// Tests
// ============================================================================

test "Platform detection" {
    const platform = Platform.current();
    try std.testing.expect(platform != .unsupported or builtin.os.tag == .freestanding);
}

test "Platform translation support" {
    try std.testing.expect(Platform.ios.supportsOnDeviceTranslation());
    try std.testing.expect(Platform.android.supportsOnDeviceTranslation());
    try std.testing.expect(!Platform.linux.supportsOnDeviceTranslation());
}

test "Language from code" {
    try std.testing.expectEqual(Language.en, Language.fromCode("en"));
    try std.testing.expectEqual(Language.es, Language.fromCode("es"));
    try std.testing.expectEqual(Language.zh_tw, Language.fromCode("zh-TW"));
    try std.testing.expectEqual(Language.unknown, Language.fromCode("invalid"));
}

test "Language to code" {
    try std.testing.expectEqualStrings("en", Language.en.toCode());
    try std.testing.expectEqualStrings("zh-TW", Language.zh_tw.toCode());
}

test "Language display name" {
    try std.testing.expectEqualStrings("English", Language.en.getDisplayName());
    try std.testing.expectEqualStrings("Japanese", Language.ja.getDisplayName());
}

test "Language RTL detection" {
    try std.testing.expect(Language.ar.isRTL());
    try std.testing.expect(Language.he.isRTL());
    try std.testing.expect(!Language.en.isRTL());
}

test "LanguagePair creation" {
    const pair = LanguagePair.init(.en, .es);
    try std.testing.expectEqual(Language.en, pair.source);
    try std.testing.expectEqual(Language.es, pair.target);
}

test "LanguagePair reversed" {
    const pair = LanguagePair.init(.en, .es);
    const reversed = pair.reversed();
    try std.testing.expectEqual(Language.es, reversed.source);
    try std.testing.expectEqual(Language.en, reversed.target);
}

test "LanguagePair validity" {
    try std.testing.expect(LanguagePair.init(.en, .es).isValid());
    try std.testing.expect(!LanguagePair.init(.en, .en).isValid());
    try std.testing.expect(!LanguagePair.init(.unknown, .es).isValid());
}

test "TranslationStatus properties" {
    try std.testing.expect(TranslationStatus.success.isSuccess());
    try std.testing.expect(!TranslationStatus.translation_failed.isSuccess());
    try std.testing.expect(TranslationStatus.download_failed.isRetryable());
    try std.testing.expect(!TranslationStatus.language_not_supported.isRetryable());
}

test "TranslationModel creation" {
    const pair = LanguagePair.init(.en, .es);
    const model = TranslationModel.init(pair);
    try std.testing.expect(!model.is_downloaded);
    try std.testing.expect(!model.isReady());
}

test "TranslationModel builder" {
    const pair = LanguagePair.init(.en, .fr);
    const model = TranslationModel.init(pair)
        .withSize(100 * 1024 * 1024)
        .withDownloaded(true)
        .withQuality(.enhanced);

    try std.testing.expect(model.is_downloaded);
    try std.testing.expect(model.isReady());
    try std.testing.expectEqual(TranslationModel.QualityTier.enhanced, model.quality_tier);
}

test "TranslationModel size MB" {
    const pair = LanguagePair.init(.en, .de);
    const model = TranslationModel.init(pair)
        .withSize(50 * 1024 * 1024);
    try std.testing.expectEqual(@as(f32, 50.0), model.getModelSizeMB());
}

test "TranslationRequest creation" {
    const pair = LanguagePair.init(.en, .es);
    const request = TranslationRequest.init(pair);
    try std.testing.expect(!request.isValid()); // No text
}

test "TranslationRequest with text" {
    const pair = LanguagePair.init(.en, .es);
    const request = TranslationRequest.init(pair)
        .withText("Hello, world!");
    try std.testing.expect(request.isValid());
    try std.testing.expectEqualStrings("Hello, world!", request.getTextSlice());
}

test "TranslationRequest with options" {
    const pair = LanguagePair.init(.en, .fr);
    const request = TranslationRequest.init(pair)
        .withText("Test")
        .withPreserveFormatting(false)
        .withAutoDetect(true)
        .withRequestId("req-123");

    try std.testing.expect(!request.preserve_formatting);
    try std.testing.expect(request.detect_source_language);
    try std.testing.expectEqualStrings("req-123", request.getRequestIdSlice());
}

test "TranslationResult creation" {
    const pair = LanguagePair.init(.en, .es);
    const result = TranslationResult.init(.success, pair);
    try std.testing.expect(result.isSuccess());
}

test "TranslationResult with translation" {
    const pair = LanguagePair.init(.en, .es);
    const result = TranslationResult.init(.success, pair)
        .withTranslatedText("Hola, mundo!")
        .withConfidence(0.95)
        .withProcessingTime(100);

    try std.testing.expectEqualStrings("Hola, mundo!", result.getTranslatedTextSlice());
    try std.testing.expect(result.hasHighConfidence());
}

test "LanguageDetectionResult creation" {
    const result = LanguageDetectionResult.init(.en, 0.9);
    try std.testing.expectEqual(Language.en, result.detected_language);
    try std.testing.expect(result.isConfident());
}

test "LanguageDetectionResult alternatives" {
    var result = LanguageDetectionResult.init(.en, 0.8);
    result.addAlternative(.de, 0.1);
    result.addAlternative(.fr, 0.05);

    try std.testing.expectEqual(@as(usize, 2), result.alternatives_count);
    try std.testing.expectEqual(Language.de, result.getAlternatives()[0].language);
}

test "DownloadProgress creation" {
    const pair = LanguagePair.init(.en, .es);
    const progress = DownloadProgress.init(pair, 50 * 1024 * 1024);
    try std.testing.expectEqual(@as(u8, 0), progress.getProgressPercent());
    try std.testing.expect(!progress.is_complete);
}

test "DownloadProgress update" {
    const pair = LanguagePair.init(.en, .fr);
    var progress = DownloadProgress.init(pair, 100);
    progress.updateProgress(50);
    try std.testing.expectEqual(@as(u8, 50), progress.getProgressPercent());

    progress.updateProgress(100);
    try std.testing.expect(progress.is_complete);
}

test "DownloadProgress failure" {
    const pair = LanguagePair.init(.en, .de);
    var progress = DownloadProgress.init(pair, 100);
    progress.markFailed("Network error");
    try std.testing.expect(progress.is_failed);
    try std.testing.expectEqualStrings("Network error", progress.getErrorMessageSlice());
}

test "TranslationEvent creation" {
    const pair = LanguagePair.init(.en, .es);
    const event = TranslationEvent.init(.translation_started, pair);
    try std.testing.expectEqual(TranslationEvent.EventType.translation_started, event.event_type);
}

test "TranslationEvent with message" {
    const pair = LanguagePair.init(.en, .fr);
    const event = TranslationEvent.init(.translation_completed, pair)
        .withMessage("Translation successful");
    try std.testing.expectEqualStrings("Translation successful", event.getMessageSlice());
}

test "TranslationEngine availability" {
    const apple = TranslationEngine.apple_translation;
    try std.testing.expectEqualStrings("Apple Translation", apple.getDisplayName());
    try std.testing.expect(apple.supportsOffline());
}

test "OfflineTranslationService creation" {
    const allocator = std.testing.allocator;
    var service = OfflineTranslationService.init(.apple_translation);
    defer service.deinit(allocator);

    try std.testing.expect(service.is_initialized);
    try std.testing.expectEqual(@as(u64, 0), service.getTotalStorageUsed());
}

test "OfflineTranslationService model management" {
    const allocator = std.testing.allocator;
    var service = OfflineTranslationService.init(.ml_kit);
    defer service.deinit(allocator);

    const pair = LanguagePair.init(.en, .es);
    try std.testing.expect(!service.isModelDownloaded(pair));

    const model = TranslationModel.init(pair)
        .withDownloaded(true)
        .withSize(50 * 1024 * 1024);
    service.addDownloadedModel(model, allocator);

    try std.testing.expect(service.isModelDownloaded(pair));
    try std.testing.expectEqual(@as(u64, 50 * 1024 * 1024), service.getTotalStorageUsed());
}

test "OfflineTranslationService translation" {
    const allocator = std.testing.allocator;
    var service = OfflineTranslationService.init(.argos_translate);
    defer service.deinit(allocator);

    const pair = LanguagePair.init(.en, .es);
    const model = TranslationModel.init(pair).withDownloaded(true);
    service.addDownloadedModel(model, allocator);

    const request = TranslationRequest.init(pair)
        .withText("Hello");
    const result = service.translate(request);

    try std.testing.expect(result.isSuccess());
}

test "LanguageDetector basic" {
    var detector = LanguageDetector.init();
    const result = detector.detect("Hello, how are you?");
    try std.testing.expectEqual(Language.en, result.detected_language);
    try std.testing.expect(result.isConfident());
}

test "LanguageDetector empty text" {
    var detector = LanguageDetector.init();
    const result = detector.detect("");
    try std.testing.expectEqual(Language.unknown, result.detected_language);
}

test "LanguageDetector count" {
    var detector = LanguageDetector.init();
    _ = detector.detect("Test 1");
    _ = detector.detect("Test 2");
    try std.testing.expectEqual(@as(u64, 2), detector.getDetectionCount());
}

test "TranslationController initialization" {
    const allocator = std.testing.allocator;
    var controller = TranslationController.init(.apple_translation);
    defer controller.deinit(allocator);

    try std.testing.expect(controller.is_initialized);
}

test "TranslationController translation" {
    const allocator = std.testing.allocator;
    var controller = TranslationController.init(.ml_kit);
    defer controller.deinit(allocator);

    const pair = LanguagePair.init(.en, .es);
    const model = TranslationModel.init(pair).withDownloaded(true);
    controller.addModel(model, allocator);

    const request = TranslationRequest.init(pair)
        .withText("Hello");
    const result = controller.translate(request, allocator);

    try std.testing.expect(result.isSuccess());
    try std.testing.expect(controller.getTranslationHistory().len > 0);
}

test "TranslationController language detection" {
    const allocator = std.testing.allocator;
    var controller = TranslationController.init(.libretranslate);
    defer controller.deinit(allocator);

    const result = controller.detectLanguage("Hello world", allocator);
    try std.testing.expectEqual(Language.en, result.detected_language);
}

test "TranslationController auto-detect" {
    const allocator = std.testing.allocator;
    var controller = TranslationController.init(.argos_translate);
    defer controller.deinit(allocator);

    // Add model for detected pair
    const pair = LanguagePair.init(.en, .es);
    const model = TranslationModel.init(pair).withDownloaded(true);
    controller.addModel(model, allocator);

    const request = TranslationRequest.init(LanguagePair.init(.unknown, .es))
        .withText("Hello world")
        .withAutoDetect(true);

    const result = controller.translate(request, allocator);
    // May or may not succeed depending on auto-detection
    _ = result;
}

test "TranslationController statistics" {
    const allocator = std.testing.allocator;
    var controller = TranslationController.init(.custom);
    defer controller.deinit(allocator);

    const stats = controller.getStatistics();
    try std.testing.expectEqual(@as(u64, 0), stats.total_translations);
    try std.testing.expectEqual(@as(f32, 0.0), stats.getSuccessRate());
}

test "TranslationController event callback" {
    const allocator = std.testing.allocator;
    var controller = TranslationController.init(.apple_translation);
    defer controller.deinit(allocator);

    const S = struct {
        fn callback(_: TranslationEvent) void {
            // Event received
        }
    };

    controller.setEventCallback(S.callback);
    try std.testing.expect(controller.event_callback != null);
}

test "TranslationController supported pairs" {
    const allocator = std.testing.allocator;
    var controller = TranslationController.init(.ml_kit);
    defer controller.deinit(allocator);

    const pair = LanguagePair.init(.en, .ja);
    try std.testing.expect(!controller.isLanguagePairSupported(pair));

    controller.addSupportedPair(pair, allocator);
    try std.testing.expect(controller.isLanguagePairSupported(pair));
}

test "TranslationController clear history" {
    const allocator = std.testing.allocator;
    var controller = TranslationController.init(.libretranslate);
    defer controller.deinit(allocator);

    const pair = LanguagePair.init(.en, .es);
    const model = TranslationModel.init(pair).withDownloaded(true);
    controller.addModel(model, allocator);

    const request = TranslationRequest.init(pair).withText("Test");
    _ = controller.translate(request, allocator);

    try std.testing.expect(controller.getTranslationHistory().len > 0);

    controller.clearHistory(allocator);
    try std.testing.expectEqual(@as(usize, 0), controller.getTranslationHistory().len);
}

test "Statistics calculations" {
    const stats = TranslationController.Statistics{
        .total_translations = 10,
        .successful_translations = 8,
        .failed_translations = 2,
        .total_detections = 5,
        .downloaded_models = 3,
        .storage_used_bytes = 150 * 1024 * 1024,
    };

    try std.testing.expectEqual(@as(f32, 0.8), stats.getSuccessRate());
    try std.testing.expectEqual(@as(f32, 150.0), stats.getStorageUsedMB());
}
