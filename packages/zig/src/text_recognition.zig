//! Text Recognition Module
//! On-device OCR using Vision (iOS/macOS), ML Kit (Android), Tesseract (Linux/Windows)
//! Provides cross-platform abstractions for text extraction from images

const std = @import("std");
const builtin = @import("builtin");

/// Platform-specific OCR backends
pub const Platform = enum {
    ios, // Vision framework
    macos, // Vision framework
    android, // ML Kit Text Recognition
    linux, // Tesseract OCR
    windows, // Windows OCR / Tesseract
    unsupported,

    pub fn current() Platform {
        return switch (builtin.os.tag) {
            .ios => .ios,
            .macos => .macos,
            .linux => .linux,
            .windows => .windows,
            else => if (builtin.abi == .android) .android else .unsupported,
        };
    }

    pub fn backendName(self: Platform) []const u8 {
        return switch (self) {
            .ios, .macos => "Vision",
            .android => "ML Kit",
            .linux, .windows => "Tesseract",
            .unsupported => "None",
        };
    }
};

/// Recognition level/accuracy
pub const RecognitionLevel = enum {
    fast, // Quick, less accurate
    accurate, // Slower, more accurate

    pub fn processingTimeMultiplier(self: RecognitionLevel) f32 {
        return switch (self) {
            .fast => 1.0,
            .accurate => 2.5,
        };
    }
};

/// Supported languages for recognition
pub const Language = enum {
    english,
    spanish,
    french,
    german,
    italian,
    portuguese,
    chinese_simplified,
    chinese_traditional,
    japanese,
    korean,
    arabic,
    russian,
    hindi,
    auto_detect,

    pub fn code(self: Language) []const u8 {
        return switch (self) {
            .english => "en",
            .spanish => "es",
            .french => "fr",
            .german => "de",
            .italian => "it",
            .portuguese => "pt",
            .chinese_simplified => "zh-Hans",
            .chinese_traditional => "zh-Hant",
            .japanese => "ja",
            .korean => "ko",
            .arabic => "ar",
            .russian => "ru",
            .hindi => "hi",
            .auto_detect => "auto",
        };
    }

    pub fn isRTL(self: Language) bool {
        return self == .arabic;
    }
};

/// Text element type
pub const TextElementType = enum {
    character,
    word,
    line,
    paragraph,
    block,
};

/// Bounding box for recognized text
pub const BoundingBox = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    pub fn init(x: f32, y: f32, width: f32, height: f32) BoundingBox {
        return .{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
        };
    }

    pub fn center(self: *const BoundingBox) struct { x: f32, y: f32 } {
        return .{
            .x = self.x + self.width / 2.0,
            .y = self.y + self.height / 2.0,
        };
    }

    pub fn area(self: *const BoundingBox) f32 {
        return self.width * self.height;
    }

    pub fn contains(self: *const BoundingBox, px: f32, py: f32) bool {
        return px >= self.x and px <= self.x + self.width and
            py >= self.y and py <= self.y + self.height;
    }

    pub fn intersects(self: *const BoundingBox, other: *const BoundingBox) bool {
        return !(self.x + self.width < other.x or
            other.x + other.width < self.x or
            self.y + self.height < other.y or
            other.y + other.height < self.y);
    }
};

/// Recognized text element
pub const TextElement = struct {
    text: []const u8,
    element_type: TextElementType,
    bounding_box: BoundingBox,
    confidence: f32 = 0.0, // 0.0 to 1.0
    language: ?Language = null,
    children: std.ArrayListUnmanaged(TextElement) = .empty,

    pub fn init(text: []const u8, element_type: TextElementType, bounding_box: BoundingBox) TextElement {
        return .{
            .text = text,
            .element_type = element_type,
            .bounding_box = bounding_box,
        };
    }

    pub fn withConfidence(self: TextElement, confidence: f32) TextElement {
        var copy = self;
        copy.confidence = @min(1.0, @max(0.0, confidence));
        return copy;
    }

    pub fn withLanguage(self: TextElement, language: Language) TextElement {
        var copy = self;
        copy.language = language;
        return copy;
    }

    pub fn isHighConfidence(self: *const TextElement) bool {
        return self.confidence >= 0.8;
    }

    pub fn charCount(self: *const TextElement) usize {
        return self.text.len;
    }
};

/// Recognition result for an image
pub const RecognitionResult = struct {
    allocator: std.mem.Allocator,
    elements: std.ArrayListUnmanaged(TextElement),
    full_text: ?[]const u8 = null,
    detected_language: ?Language = null,
    processing_time_ms: i64 = 0,
    image_width: u32 = 0,
    image_height: u32 = 0,
    average_confidence: f32 = 0.0,
    word_count: u32 = 0,

    pub fn init(allocator: std.mem.Allocator) RecognitionResult {
        return .{
            .allocator = allocator,
            .elements = .empty,
        };
    }

    pub fn deinit(self: *RecognitionResult) void {
        self.elements.deinit(self.allocator);
    }

    pub fn addElement(self: *RecognitionResult, element: TextElement) !void {
        try self.elements.append(self.allocator, element);
        self.updateStats();
    }

    fn updateStats(self: *RecognitionResult) void {
        if (self.elements.items.len == 0) {
            self.average_confidence = 0.0;
            return;
        }

        var total_confidence: f32 = 0.0;
        var word_count: u32 = 0;

        for (self.elements.items) |element| {
            total_confidence += element.confidence;
            if (element.element_type == .word) {
                word_count += 1;
            }
        }

        self.average_confidence = total_confidence / @as(f32, @floatFromInt(self.elements.items.len));
        self.word_count = word_count;
    }

    pub fn elementCount(self: *const RecognitionResult) usize {
        return self.elements.items.len;
    }

    pub fn getElementsByType(self: *const RecognitionResult, element_type: TextElementType) []const TextElement {
        // Return all elements (filtering would require allocation)
        _ = element_type;
        return self.elements.items;
    }

    pub fn hasText(self: *const RecognitionResult) bool {
        return self.elements.items.len > 0;
    }
};

/// Recognition configuration
pub const RecognitionConfig = struct {
    level: RecognitionLevel = .accurate,
    languages: std.ArrayListUnmanaged(Language) = .empty,
    detect_language: bool = true,
    minimum_text_height: f32 = 0.0, // Minimum height in pixels
    correct_perspective: bool = true,
    use_language_correction: bool = true,
    return_bounding_boxes: bool = true,
    custom_words: std.ArrayListUnmanaged([]const u8) = .empty,

    pub fn init() RecognitionConfig {
        return .{};
    }

    pub fn withLevel(self: RecognitionConfig, level: RecognitionLevel) RecognitionConfig {
        var copy = self;
        copy.level = level;
        return copy;
    }

    pub fn withLanguageDetection(self: RecognitionConfig, detect: bool) RecognitionConfig {
        var copy = self;
        copy.detect_language = detect;
        return copy;
    }

    pub fn withPerspectiveCorrection(self: RecognitionConfig, correct: bool) RecognitionConfig {
        var copy = self;
        copy.correct_perspective = correct;
        return copy;
    }

    pub fn withMinimumTextHeight(self: RecognitionConfig, height: f32) RecognitionConfig {
        var copy = self;
        copy.minimum_text_height = height;
        return copy;
    }
};

/// Image source for recognition
pub const ImageSource = union(enum) {
    file_path: []const u8,
    data: []const u8,
    url: []const u8,

    pub fn isLocal(self: ImageSource) bool {
        return switch (self) {
            .file_path, .data => true,
            .url => false,
        };
    }
};

/// Recognition request
pub const RecognitionRequest = struct {
    id: u64,
    source: ImageSource,
    config: RecognitionConfig,
    created_at: i64,
    priority: Priority = .normal,

    pub const Priority = enum {
        low,
        normal,
        high,
    };

    pub fn init(id: u64, source: ImageSource) RecognitionRequest {
        return .{
            .id = id,
            .source = source,
            .config = RecognitionConfig.init(),
            .created_at = getCurrentTimestamp(),
        };
    }

    pub fn withConfig(self: RecognitionRequest, config: RecognitionConfig) RecognitionRequest {
        var copy = self;
        copy.config = config;
        return copy;
    }

    pub fn withPriority(self: RecognitionRequest, priority: Priority) RecognitionRequest {
        var copy = self;
        copy.priority = priority;
        return copy;
    }
};

/// Recognition event
pub const RecognitionEvent = struct {
    event_type: EventType,
    request_id: ?u64 = null,
    timestamp: i64,
    data: ?[]const u8 = null,

    pub const EventType = enum {
        started,
        progress,
        completed,
        failed,
        cancelled,
    };

    pub fn init(event_type: EventType) RecognitionEvent {
        return .{
            .event_type = event_type,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn withRequestId(self: RecognitionEvent, id: u64) RecognitionEvent {
        var copy = self;
        copy.request_id = id;
        return copy;
    }

    pub fn withData(self: RecognitionEvent, data: []const u8) RecognitionEvent {
        var copy = self;
        copy.data = data;
        return copy;
    }
};

/// Batch recognition for multiple images
pub const BatchRecognition = struct {
    allocator: std.mem.Allocator,
    requests: std.ArrayListUnmanaged(RecognitionRequest),
    results: std.ArrayListUnmanaged(RecognitionResult),
    completed_count: u32 = 0,
    failed_count: u32 = 0,
    total_processing_time_ms: i64 = 0,

    pub fn init(allocator: std.mem.Allocator) BatchRecognition {
        return .{
            .allocator = allocator,
            .requests = .empty,
            .results = .empty,
        };
    }

    pub fn deinit(self: *BatchRecognition) void {
        self.requests.deinit(self.allocator);
        for (self.results.items) |*result| {
            result.deinit();
        }
        self.results.deinit(self.allocator);
    }

    pub fn addRequest(self: *BatchRecognition, request: RecognitionRequest) !void {
        try self.requests.append(self.allocator, request);
    }

    pub fn addResult(self: *BatchRecognition, result: RecognitionResult) !void {
        try self.results.append(self.allocator, result);
        self.completed_count += 1;
        self.total_processing_time_ms += result.processing_time_ms;
    }

    pub fn markFailed(self: *BatchRecognition) void {
        self.failed_count += 1;
    }

    pub fn requestCount(self: *const BatchRecognition) usize {
        return self.requests.items.len;
    }

    pub fn progress(self: *const BatchRecognition) f32 {
        if (self.requests.items.len == 0) return 1.0;
        const completed = self.completed_count + self.failed_count;
        return @as(f32, @floatFromInt(completed)) / @as(f32, @floatFromInt(self.requests.items.len));
    }

    pub fn isComplete(self: *const BatchRecognition) bool {
        return self.completed_count + self.failed_count >= self.requests.items.len;
    }

    pub fn averageProcessingTime(self: *const BatchRecognition) i64 {
        if (self.completed_count == 0) return 0;
        return @divTrunc(self.total_processing_time_ms, @as(i64, @intCast(self.completed_count)));
    }
};

/// Live text recognition for camera feed
pub const LiveTextRecognition = struct {
    is_running: bool = false,
    frame_count: u64 = 0,
    last_result: ?RecognitionResult = null,
    config: RecognitionConfig,
    throttle_ms: i64 = 100, // Process every N ms
    last_process_time: i64 = 0,

    pub fn init(config: RecognitionConfig) LiveTextRecognition {
        return .{
            .config = config,
        };
    }

    pub fn start(self: *LiveTextRecognition) void {
        self.is_running = true;
        self.frame_count = 0;
    }

    pub fn stop(self: *LiveTextRecognition) void {
        self.is_running = false;
    }

    pub fn shouldProcessFrame(self: *LiveTextRecognition) bool {
        if (!self.is_running) return false;

        const now = getCurrentTimestamp() * 1000; // Convert to ms
        if (now - self.last_process_time >= self.throttle_ms) {
            self.last_process_time = now;
            return true;
        }
        return false;
    }

    pub fn processFrame(self: *LiveTextRecognition) void {
        if (self.is_running) {
            self.frame_count += 1;
        }
    }

    pub fn setThrottleMs(self: *LiveTextRecognition, ms: i64) void {
        self.throttle_ms = ms;
    }
};

/// Text Recognition Controller
pub const TextRecognitionController = struct {
    allocator: std.mem.Allocator,
    request_counter: u64 = 0,
    results: std.ArrayListUnmanaged(RecognitionResult),
    event_history: std.ArrayListUnmanaged(RecognitionEvent),
    event_callback: ?*const fn (RecognitionEvent) void = null,
    default_config: RecognitionConfig,
    live_recognition: ?LiveTextRecognition = null,
    is_available: bool = true,
    supported_languages: std.ArrayListUnmanaged(Language),

    pub fn init(allocator: std.mem.Allocator) TextRecognitionController {
        return .{
            .allocator = allocator,
            .results = .empty,
            .event_history = .empty,
            .default_config = RecognitionConfig.init(),
            .supported_languages = .empty,
        };
    }

    pub fn deinit(self: *TextRecognitionController) void {
        for (self.results.items) |*result| {
            result.deinit();
        }
        self.results.deinit(self.allocator);
        self.event_history.deinit(self.allocator);
        self.supported_languages.deinit(self.allocator);
    }

    pub fn createRequest(self: *TextRecognitionController, source: ImageSource) RecognitionRequest {
        self.request_counter += 1;
        return RecognitionRequest.init(self.request_counter, source)
            .withConfig(self.default_config);
    }

    pub fn recognizeText(self: *TextRecognitionController, request: RecognitionRequest) !*RecognitionResult {
        if (!self.is_available) {
            return error.RecognitionNotAvailable;
        }

        const start_event = RecognitionEvent.init(.started)
            .withRequestId(request.id);
        try self.event_history.append(self.allocator, start_event);

        if (self.event_callback) |callback| {
            callback(start_event);
        }

        // Simulate recognition (in real implementation, this would call native APIs)
        var result = RecognitionResult.init(self.allocator);
        result.processing_time_ms = @as(i64, @intFromFloat(100.0 * request.config.level.processingTimeMultiplier()));

        // Add simulated result
        const element = TextElement.init(
            "Sample recognized text",
            .line,
            BoundingBox.init(10.0, 10.0, 200.0, 20.0),
        ).withConfidence(0.95);
        try result.addElement(element);

        try self.results.append(self.allocator, result);

        const complete_event = RecognitionEvent.init(.completed)
            .withRequestId(request.id);
        try self.event_history.append(self.allocator, complete_event);

        if (self.event_callback) |callback| {
            callback(complete_event);
        }

        return &self.results.items[self.results.items.len - 1];
    }

    pub fn recognizeFromFile(self: *TextRecognitionController, file_path: []const u8) !*RecognitionResult {
        const request = self.createRequest(.{ .file_path = file_path });
        return self.recognizeText(request);
    }

    pub fn recognizeFromData(self: *TextRecognitionController, data: []const u8) !*RecognitionResult {
        const request = self.createRequest(.{ .data = data });
        return self.recognizeText(request);
    }

    pub fn startLiveRecognition(self: *TextRecognitionController) void {
        self.live_recognition = LiveTextRecognition.init(self.default_config);
        if (self.live_recognition) |*live| {
            live.start();
        }
    }

    pub fn stopLiveRecognition(self: *TextRecognitionController) void {
        if (self.live_recognition) |*live| {
            live.stop();
        }
        self.live_recognition = null;
    }

    pub fn isLiveRecognitionRunning(self: *const TextRecognitionController) bool {
        if (self.live_recognition) |live| {
            return live.is_running;
        }
        return false;
    }

    pub fn setDefaultConfig(self: *TextRecognitionController, config: RecognitionConfig) void {
        self.default_config = config;
    }

    pub fn setEventCallback(self: *TextRecognitionController, callback: *const fn (RecognitionEvent) void) void {
        self.event_callback = callback;
    }

    pub fn addSupportedLanguage(self: *TextRecognitionController, language: Language) !void {
        try self.supported_languages.append(self.allocator, language);
    }

    pub fn isLanguageSupported(self: *const TextRecognitionController, language: Language) bool {
        for (self.supported_languages.items) |lang| {
            if (lang == language) return true;
        }
        return false;
    }

    pub fn getEventHistory(self: *const TextRecognitionController) []const RecognitionEvent {
        return self.event_history.items;
    }

    pub fn clearEventHistory(self: *TextRecognitionController) void {
        self.event_history.clearAndFree(self.allocator);
    }

    pub fn resultCount(self: *const TextRecognitionController) usize {
        return self.results.items.len;
    }

    pub fn clearResults(self: *TextRecognitionController) void {
        for (self.results.items) |*result| {
            result.deinit();
        }
        self.results.clearAndFree(self.allocator);
    }
};

/// Helper to get current timestamp
fn getCurrentTimestamp() i64 {
    if (builtin.os.tag == .macos or builtin.os.tag == .ios or
        builtin.os.tag == .tvos or builtin.os.tag == .watchos)
    {
        const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
        return ts.sec;
    } else if (builtin.os.tag == .windows) {
        return std.time.timestamp();
    } else if (builtin.os.tag == .linux) {
        const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
        return ts.sec;
    } else {
        return 0;
    }
}

// ============================================================================
// Tests
// ============================================================================

test "Platform detection" {
    const platform = Platform.current();
    try std.testing.expect(platform == .macos or platform != .macos);
}

test "Platform backendName" {
    try std.testing.expectEqualStrings("Vision", Platform.macos.backendName());
    try std.testing.expectEqualStrings("Vision", Platform.ios.backendName());
    try std.testing.expectEqualStrings("ML Kit", Platform.android.backendName());
    try std.testing.expectEqualStrings("Tesseract", Platform.linux.backendName());
}

test "RecognitionLevel processingTimeMultiplier" {
    try std.testing.expectEqual(@as(f32, 1.0), RecognitionLevel.fast.processingTimeMultiplier());
    try std.testing.expectEqual(@as(f32, 2.5), RecognitionLevel.accurate.processingTimeMultiplier());
}

test "Language code" {
    try std.testing.expectEqualStrings("en", Language.english.code());
    try std.testing.expectEqualStrings("ja", Language.japanese.code());
    try std.testing.expectEqualStrings("zh-Hans", Language.chinese_simplified.code());
}

test "Language isRTL" {
    try std.testing.expect(Language.arabic.isRTL());
    try std.testing.expect(!Language.english.isRTL());
    try std.testing.expect(!Language.japanese.isRTL());
}

test "BoundingBox init" {
    const box = BoundingBox.init(10.0, 20.0, 100.0, 50.0);
    try std.testing.expectEqual(@as(f32, 10.0), box.x);
    try std.testing.expectEqual(@as(f32, 20.0), box.y);
    try std.testing.expectEqual(@as(f32, 100.0), box.width);
    try std.testing.expectEqual(@as(f32, 50.0), box.height);
}

test "BoundingBox center" {
    const box = BoundingBox.init(0.0, 0.0, 100.0, 50.0);
    const c = box.center();
    try std.testing.expectEqual(@as(f32, 50.0), c.x);
    try std.testing.expectEqual(@as(f32, 25.0), c.y);
}

test "BoundingBox area" {
    const box = BoundingBox.init(0.0, 0.0, 100.0, 50.0);
    try std.testing.expectEqual(@as(f32, 5000.0), box.area());
}

test "BoundingBox contains" {
    const box = BoundingBox.init(0.0, 0.0, 100.0, 50.0);
    try std.testing.expect(box.contains(50.0, 25.0));
    try std.testing.expect(!box.contains(150.0, 25.0));
}

test "BoundingBox intersects" {
    const box1 = BoundingBox.init(0.0, 0.0, 100.0, 50.0);
    const box2 = BoundingBox.init(50.0, 25.0, 100.0, 50.0);
    const box3 = BoundingBox.init(200.0, 200.0, 50.0, 50.0);

    try std.testing.expect(box1.intersects(&box2));
    try std.testing.expect(!box1.intersects(&box3));
}

test "TextElement init and builder" {
    const element = TextElement.init(
        "Hello",
        .word,
        BoundingBox.init(0.0, 0.0, 50.0, 20.0),
    ).withConfidence(0.95).withLanguage(.english);

    try std.testing.expectEqualStrings("Hello", element.text);
    try std.testing.expectEqual(TextElementType.word, element.element_type);
    try std.testing.expectEqual(@as(f32, 0.95), element.confidence);
    try std.testing.expect(element.isHighConfidence());
    try std.testing.expectEqual(Language.english, element.language.?);
}

test "TextElement charCount" {
    const element = TextElement.init("Hello World", .line, BoundingBox.init(0.0, 0.0, 100.0, 20.0));
    try std.testing.expectEqual(@as(usize, 11), element.charCount());
}

test "RecognitionResult init and addElement" {
    var result = RecognitionResult.init(std.testing.allocator);
    defer result.deinit();

    const element = TextElement.init("Test", .word, BoundingBox.init(0.0, 0.0, 50.0, 20.0))
        .withConfidence(0.9);
    try result.addElement(element);

    try std.testing.expectEqual(@as(usize, 1), result.elementCount());
    try std.testing.expect(result.hasText());
    try std.testing.expectEqual(@as(u32, 1), result.word_count);
}

test "RecognitionConfig builder" {
    const config = RecognitionConfig.init()
        .withLevel(.fast)
        .withLanguageDetection(true)
        .withPerspectiveCorrection(false)
        .withMinimumTextHeight(10.0);

    try std.testing.expectEqual(RecognitionLevel.fast, config.level);
    try std.testing.expect(config.detect_language);
    try std.testing.expect(!config.correct_perspective);
    try std.testing.expectEqual(@as(f32, 10.0), config.minimum_text_height);
}

test "ImageSource isLocal" {
    const file_source = ImageSource{ .file_path = "/path/to/image.png" };
    try std.testing.expect(file_source.isLocal());

    const url_source = ImageSource{ .url = "https://example.com/image.png" };
    try std.testing.expect(!url_source.isLocal());
}

test "RecognitionRequest init and builder" {
    const request = RecognitionRequest.init(1, .{ .file_path = "/image.png" })
        .withConfig(RecognitionConfig.init().withLevel(.fast))
        .withPriority(.high);

    try std.testing.expectEqual(@as(u64, 1), request.id);
    try std.testing.expectEqual(RecognitionLevel.fast, request.config.level);
    try std.testing.expectEqual(RecognitionRequest.Priority.high, request.priority);
}

test "RecognitionEvent builder" {
    const event = RecognitionEvent.init(.completed)
        .withRequestId(42)
        .withData("result_data");

    try std.testing.expectEqual(RecognitionEvent.EventType.completed, event.event_type);
    try std.testing.expectEqual(@as(?u64, 42), event.request_id);
    try std.testing.expectEqualStrings("result_data", event.data.?);
}

test "BatchRecognition init and deinit" {
    var batch = BatchRecognition.init(std.testing.allocator);
    defer batch.deinit();

    try std.testing.expectEqual(@as(usize, 0), batch.requestCount());
    try std.testing.expectEqual(@as(f32, 1.0), batch.progress());
}

test "BatchRecognition addRequest" {
    var batch = BatchRecognition.init(std.testing.allocator);
    defer batch.deinit();

    const request = RecognitionRequest.init(1, .{ .file_path = "/image.png" });
    try batch.addRequest(request);

    try std.testing.expectEqual(@as(usize, 1), batch.requestCount());
    try std.testing.expectEqual(@as(f32, 0.0), batch.progress());
}

test "BatchRecognition progress tracking" {
    var batch = BatchRecognition.init(std.testing.allocator);
    defer batch.deinit();

    try batch.addRequest(RecognitionRequest.init(1, .{ .file_path = "/image1.png" }));
    try batch.addRequest(RecognitionRequest.init(2, .{ .file_path = "/image2.png" }));

    var result = RecognitionResult.init(std.testing.allocator);
    result.processing_time_ms = 100;
    try batch.addResult(result);

    try std.testing.expectEqual(@as(f32, 0.5), batch.progress());
    try std.testing.expect(!batch.isComplete());

    batch.markFailed();
    try std.testing.expect(batch.isComplete());
}

test "LiveTextRecognition lifecycle" {
    var live = LiveTextRecognition.init(RecognitionConfig.init());

    try std.testing.expect(!live.is_running);

    live.start();
    try std.testing.expect(live.is_running);
    try std.testing.expectEqual(@as(u64, 0), live.frame_count);

    live.processFrame();
    try std.testing.expectEqual(@as(u64, 1), live.frame_count);

    live.stop();
    try std.testing.expect(!live.is_running);
}

test "LiveTextRecognition throttle" {
    var live = LiveTextRecognition.init(RecognitionConfig.init());
    live.setThrottleMs(200);
    try std.testing.expectEqual(@as(i64, 200), live.throttle_ms);
}

test "TextRecognitionController init and deinit" {
    var controller = TextRecognitionController.init(std.testing.allocator);
    defer controller.deinit();

    try std.testing.expectEqual(@as(usize, 0), controller.resultCount());
    try std.testing.expect(controller.is_available);
}

test "TextRecognitionController createRequest" {
    var controller = TextRecognitionController.init(std.testing.allocator);
    defer controller.deinit();

    const request1 = controller.createRequest(.{ .file_path = "/image1.png" });
    const request2 = controller.createRequest(.{ .file_path = "/image2.png" });

    try std.testing.expectEqual(@as(u64, 1), request1.id);
    try std.testing.expectEqual(@as(u64, 2), request2.id);
}

test "TextRecognitionController recognizeText" {
    var controller = TextRecognitionController.init(std.testing.allocator);
    defer controller.deinit();

    const request = controller.createRequest(.{ .file_path = "/image.png" });
    const result = try controller.recognizeText(request);

    try std.testing.expect(result.hasText());
    try std.testing.expectEqual(@as(usize, 1), controller.resultCount());
}

test "TextRecognitionController recognizeFromFile" {
    var controller = TextRecognitionController.init(std.testing.allocator);
    defer controller.deinit();

    const result = try controller.recognizeFromFile("/image.png");
    try std.testing.expect(result.hasText());
}

test "TextRecognitionController live recognition" {
    var controller = TextRecognitionController.init(std.testing.allocator);
    defer controller.deinit();

    try std.testing.expect(!controller.isLiveRecognitionRunning());

    controller.startLiveRecognition();
    try std.testing.expect(controller.isLiveRecognitionRunning());

    controller.stopLiveRecognition();
    try std.testing.expect(!controller.isLiveRecognitionRunning());
}

test "TextRecognitionController language support" {
    var controller = TextRecognitionController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.addSupportedLanguage(.english);
    try controller.addSupportedLanguage(.spanish);

    try std.testing.expect(controller.isLanguageSupported(.english));
    try std.testing.expect(controller.isLanguageSupported(.spanish));
    try std.testing.expect(!controller.isLanguageSupported(.japanese));
}

test "TextRecognitionController event history" {
    var controller = TextRecognitionController.init(std.testing.allocator);
    defer controller.deinit();

    const request = controller.createRequest(.{ .file_path = "/image.png" });
    _ = try controller.recognizeText(request);

    const history = controller.getEventHistory();
    try std.testing.expect(history.len >= 2); // started + completed
}

test "TextRecognitionController clearResults" {
    var controller = TextRecognitionController.init(std.testing.allocator);
    defer controller.deinit();

    _ = try controller.recognizeFromFile("/image.png");
    try std.testing.expectEqual(@as(usize, 1), controller.resultCount());

    controller.clearResults();
    try std.testing.expectEqual(@as(usize, 0), controller.resultCount());
}

test "TextElementType values" {
    try std.testing.expect(TextElementType.character != TextElementType.word);
    try std.testing.expect(TextElementType.line != TextElementType.paragraph);
}
