//! Document Scanner - Camera-based document scanning
//!
//! Provides cross-platform abstraction for document scanning:
//! - iOS VisionKit (VNDocumentCameraViewController)
//! - Android ML Kit Document Scanner
//! - Desktop camera integration
//!
//! Features:
//! - Automatic edge detection
//! - Perspective correction
//! - Image enhancement
//! - Multi-page scanning
//! - OCR text extraction
//! - PDF export

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

/// Gets current timestamp in seconds
fn getCurrentTimestamp() i64 {
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
        return ts.sec;
    }
    return 0;
}

/// Scanner platform
pub const ScannerPlatform = enum {
    visionkit, // iOS VisionKit
    mlkit, // Android ML Kit
    windows_imaging, // Windows Imaging
    camera_generic, // Generic camera
    unknown,

    pub fn displayName(self: ScannerPlatform) []const u8 {
        return switch (self) {
            .visionkit => "VisionKit",
            .mlkit => "ML Kit",
            .windows_imaging => "Windows Imaging",
            .camera_generic => "Camera",
            .unknown => "Unknown",
        };
    }

    pub fn supportsAutoEdgeDetection(self: ScannerPlatform) bool {
        return switch (self) {
            .visionkit => true,
            .mlkit => true,
            .windows_imaging => true,
            .camera_generic => false,
            .unknown => false,
        };
    }

    pub fn supportsOCR(self: ScannerPlatform) bool {
        return switch (self) {
            .visionkit => true,
            .mlkit => true,
            .windows_imaging => true,
            .camera_generic => false,
            .unknown => false,
        };
    }
};

/// Document type being scanned
pub const DocumentType = enum {
    generic,
    receipt,
    business_card,
    id_card,
    passport,
    invoice,
    form,
    letter,
    book_page,
    whiteboard,
    photo,

    pub fn displayName(self: DocumentType) []const u8 {
        return switch (self) {
            .generic => "Document",
            .receipt => "Receipt",
            .business_card => "Business Card",
            .id_card => "ID Card",
            .passport => "Passport",
            .invoice => "Invoice",
            .form => "Form",
            .letter => "Letter",
            .book_page => "Book Page",
            .whiteboard => "Whiteboard",
            .photo => "Photo",
        };
    }

    pub fn suggestedAspectRatio(self: DocumentType) f32 {
        return switch (self) {
            .generic => 1.414, // A4 ratio
            .receipt => 0.4, // Long receipt
            .business_card => 1.75, // Standard card
            .id_card => 1.586, // Credit card ratio
            .passport => 1.42, // Passport ratio
            .invoice => 1.414, // A4
            .form => 1.414, // A4
            .letter => 1.294, // US Letter
            .book_page => 1.5,
            .whiteboard => 1.778, // 16:9
            .photo => 1.5, // 3:2
        };
    }
};

/// Image format for output
pub const ImageFormat = enum {
    jpeg,
    png,
    heic,
    pdf,
    tiff,

    pub fn fileExtension(self: ImageFormat) []const u8 {
        return switch (self) {
            .jpeg => ".jpg",
            .png => ".png",
            .heic => ".heic",
            .pdf => ".pdf",
            .tiff => ".tiff",
        };
    }

    pub fn mimeType(self: ImageFormat) []const u8 {
        return switch (self) {
            .jpeg => "image/jpeg",
            .png => "image/png",
            .heic => "image/heic",
            .pdf => "application/pdf",
            .tiff => "image/tiff",
        };
    }
};

/// Color mode for scanning
pub const ColorMode = enum {
    color,
    grayscale,
    black_white,
    auto,

    pub fn displayName(self: ColorMode) []const u8 {
        return switch (self) {
            .color => "Color",
            .grayscale => "Grayscale",
            .black_white => "Black & White",
            .auto => "Auto",
        };
    }
};

/// Quality preset for scanning
pub const QualityPreset = enum {
    low, // Fast, smaller file
    medium, // Balanced
    high, // Best quality
    maximum, // Highest resolution

    pub fn displayName(self: QualityPreset) []const u8 {
        return switch (self) {
            .low => "Low",
            .medium => "Medium",
            .high => "High",
            .maximum => "Maximum",
        };
    }

    pub fn jpegQuality(self: QualityPreset) u8 {
        return switch (self) {
            .low => 60,
            .medium => 75,
            .high => 90,
            .maximum => 100,
        };
    }

    pub fn maxResolution(self: QualityPreset) u32 {
        return switch (self) {
            .low => 1024,
            .medium => 2048,
            .high => 3072,
            .maximum => 4096,
        };
    }
};

/// Point in 2D space (normalized 0-1)
pub const Point = struct {
    x: f32 = 0,
    y: f32 = 0,

    pub fn init(x: f32, y: f32) Point {
        return .{ .x = x, .y = y };
    }

    pub fn distance(self: Point, other: Point) f32 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        return @sqrt(dx * dx + dy * dy);
    }
};

/// Quadrilateral representing detected document edges
pub const Quad = struct {
    top_left: Point = Point{},
    top_right: Point = Point{},
    bottom_left: Point = Point{},
    bottom_right: Point = Point{},

    pub fn init(tl: Point, tr: Point, bl: Point, br: Point) Quad {
        return .{
            .top_left = tl,
            .top_right = tr,
            .bottom_left = bl,
            .bottom_right = br,
        };
    }

    pub fn fullFrame() Quad {
        return .{
            .top_left = Point.init(0, 0),
            .top_right = Point.init(1, 0),
            .bottom_left = Point.init(0, 1),
            .bottom_right = Point.init(1, 1),
        };
    }

    pub fn isValid(self: *const Quad) bool {
        // Check that points form a valid quadrilateral
        const top_width = self.top_left.distance(self.top_right);
        const bottom_width = self.bottom_left.distance(self.bottom_right);
        const left_height = self.top_left.distance(self.bottom_left);
        const right_height = self.top_right.distance(self.bottom_right);

        return top_width > 0.1 and bottom_width > 0.1 and
            left_height > 0.1 and right_height > 0.1;
    }

    pub fn area(self: *const Quad) f32 {
        // Shoelace formula for quadrilateral area
        const x1 = self.top_left.x;
        const y1 = self.top_left.y;
        const x2 = self.top_right.x;
        const y2 = self.top_right.y;
        const x3 = self.bottom_right.x;
        const y3 = self.bottom_right.y;
        const x4 = self.bottom_left.x;
        const y4 = self.bottom_left.y;

        return @abs((x1 * y2 - x2 * y1) + (x2 * y3 - x3 * y2) +
            (x3 * y4 - x4 * y3) + (x4 * y1 - x1 * y4)) / 2.0;
    }

    pub fn aspectRatio(self: *const Quad) f32 {
        const top_width = self.top_left.distance(self.top_right);
        const left_height = self.top_left.distance(self.bottom_left);
        if (left_height == 0) return 1;
        return top_width / left_height;
    }
};

/// Scanner configuration
pub const ScannerConfig = struct {
    /// Document type hint
    document_type: DocumentType = .generic,

    /// Color mode
    color_mode: ColorMode = .auto,

    /// Quality preset
    quality: QualityPreset = .high,

    /// Output format
    output_format: ImageFormat = .jpeg,

    /// Enable auto edge detection
    auto_edge_detection: bool = true,

    /// Enable perspective correction
    perspective_correction: bool = true,

    /// Enable image enhancement
    image_enhancement: bool = true,

    /// Enable OCR
    ocr_enabled: bool = false,

    /// OCR language(s)
    ocr_languages: [4][8]u8 = [_][8]u8{[_]u8{0} ** 8} ** 4,
    ocr_language_lens: [4]usize = [_]usize{0} ** 4,
    ocr_language_count: usize = 0,

    /// Maximum pages (0 = unlimited)
    max_pages: u32 = 0,

    /// Show scanner UI
    show_ui: bool = true,

    pub fn init() ScannerConfig {
        return .{};
    }

    pub fn withDocumentType(self: ScannerConfig, doc_type: DocumentType) ScannerConfig {
        var result = self;
        result.document_type = doc_type;
        return result;
    }

    pub fn withColorMode(self: ScannerConfig, mode: ColorMode) ScannerConfig {
        var result = self;
        result.color_mode = mode;
        return result;
    }

    pub fn withQuality(self: ScannerConfig, quality: QualityPreset) ScannerConfig {
        var result = self;
        result.quality = quality;
        return result;
    }

    pub fn withFormat(self: ScannerConfig, format: ImageFormat) ScannerConfig {
        var result = self;
        result.output_format = format;
        return result;
    }

    pub fn withEdgeDetection(self: ScannerConfig, enabled: bool) ScannerConfig {
        var result = self;
        result.auto_edge_detection = enabled;
        return result;
    }

    pub fn withPerspectiveCorrection(self: ScannerConfig, enabled: bool) ScannerConfig {
        var result = self;
        result.perspective_correction = enabled;
        return result;
    }

    pub fn withEnhancement(self: ScannerConfig, enabled: bool) ScannerConfig {
        var result = self;
        result.image_enhancement = enabled;
        return result;
    }

    pub fn withOCR(self: ScannerConfig, enabled: bool) ScannerConfig {
        var result = self;
        result.ocr_enabled = enabled;
        return result;
    }

    pub fn addOCRLanguage(self: ScannerConfig, lang: []const u8) ScannerConfig {
        var result = self;
        if (result.ocr_language_count < 4) {
            const copy_len = @min(lang.len, 8);
            @memcpy(result.ocr_languages[result.ocr_language_count][0..copy_len], lang[0..copy_len]);
            result.ocr_language_lens[result.ocr_language_count] = copy_len;
            result.ocr_language_count += 1;
        }
        return result;
    }

    pub fn withMaxPages(self: ScannerConfig, max: u32) ScannerConfig {
        var result = self;
        result.max_pages = max;
        return result;
    }

    pub fn withUI(self: ScannerConfig, show: bool) ScannerConfig {
        var result = self;
        result.show_ui = show;
        return result;
    }
};

/// Scanned page result
pub const ScannedPage = struct {
    /// Page index (0-based)
    page_index: u32 = 0,

    /// Detected document edges
    detected_quad: Quad = Quad.fullFrame(),

    /// Image dimensions
    width: u32 = 0,
    height: u32 = 0,

    /// File size in bytes
    file_size: u64 = 0,

    /// Image data path or reference
    image_path_buffer: [512]u8 = [_]u8{0} ** 512,
    image_path_len: usize = 0,

    /// OCR extracted text
    ocr_text_buffer: [8192]u8 = [_]u8{0} ** 8192,
    ocr_text_len: usize = 0,

    /// OCR confidence (0-1)
    ocr_confidence: f32 = 0,

    /// Scan timestamp
    scanned_at: i64 = 0,

    /// Whether page was auto-enhanced
    was_enhanced: bool = false,

    /// Whether perspective was corrected
    was_corrected: bool = false,

    pub fn init(page_index: u32) ScannedPage {
        return .{
            .page_index = page_index,
            .scanned_at = getCurrentTimestamp(),
        };
    }

    pub fn withDimensions(self: ScannedPage, width: u32, height: u32) ScannedPage {
        var result = self;
        result.width = width;
        result.height = height;
        return result;
    }

    pub fn withQuad(self: ScannedPage, quad: Quad) ScannedPage {
        var result = self;
        result.detected_quad = quad;
        return result;
    }

    pub fn withImagePath(self: ScannedPage, path: []const u8) ScannedPage {
        var result = self;
        const copy_len = @min(path.len, result.image_path_buffer.len);
        @memcpy(result.image_path_buffer[0..copy_len], path[0..copy_len]);
        result.image_path_len = copy_len;
        return result;
    }

    pub fn withOCRText(self: ScannedPage, text: []const u8, confidence: f32) ScannedPage {
        var result = self;
        const copy_len = @min(text.len, result.ocr_text_buffer.len);
        @memcpy(result.ocr_text_buffer[0..copy_len], text[0..copy_len]);
        result.ocr_text_len = copy_len;
        result.ocr_confidence = confidence;
        return result;
    }

    pub fn withFileSize(self: ScannedPage, size: u64) ScannedPage {
        var result = self;
        result.file_size = size;
        return result;
    }

    pub fn withEnhanced(self: ScannedPage, enhanced: bool) ScannedPage {
        var result = self;
        result.was_enhanced = enhanced;
        return result;
    }

    pub fn withCorrected(self: ScannedPage, corrected: bool) ScannedPage {
        var result = self;
        result.was_corrected = corrected;
        return result;
    }

    pub fn getImagePath(self: *const ScannedPage) []const u8 {
        return self.image_path_buffer[0..self.image_path_len];
    }

    pub fn getOCRText(self: *const ScannedPage) []const u8 {
        return self.ocr_text_buffer[0..self.ocr_text_len];
    }

    pub fn hasOCRText(self: *const ScannedPage) bool {
        return self.ocr_text_len > 0;
    }

    pub fn aspectRatio(self: *const ScannedPage) f32 {
        if (self.height == 0) return 1;
        return @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(self.height));
    }
};

/// Scan session result
pub const ScanResult = struct {
    /// Session ID
    session_id_buffer: [64]u8 = [_]u8{0} ** 64,
    session_id_len: usize = 0,

    /// Scanned pages
    pages: [32]ScannedPage = [_]ScannedPage{ScannedPage{}} ** 32,
    page_count: usize = 0,

    /// Total file size
    total_size: u64 = 0,

    /// Output format used
    output_format: ImageFormat = .jpeg,

    /// Document type detected
    detected_type: DocumentType = .generic,

    /// Combined PDF path (if PDF output)
    pdf_path_buffer: [512]u8 = [_]u8{0} ** 512,
    pdf_path_len: usize = 0,

    /// Combined OCR text from all pages
    combined_text_buffer: [16384]u8 = [_]u8{0} ** 16384,
    combined_text_len: usize = 0,

    /// Session start time
    started_at: i64 = 0,

    /// Session end time
    completed_at: i64 = 0,

    /// Whether session was cancelled
    was_cancelled: bool = false,

    pub fn init(session_id: []const u8) ScanResult {
        var result = ScanResult{
            .started_at = getCurrentTimestamp(),
        };
        const copy_len = @min(session_id.len, result.session_id_buffer.len);
        @memcpy(result.session_id_buffer[0..copy_len], session_id[0..copy_len]);
        result.session_id_len = copy_len;
        return result;
    }

    pub fn addPage(self: *ScanResult, page: ScannedPage) bool {
        if (self.page_count < 32) {
            self.pages[self.page_count] = page;
            self.page_count += 1;
            self.total_size += page.file_size;
            return true;
        }
        return false;
    }

    pub fn complete(self: *ScanResult) void {
        self.completed_at = getCurrentTimestamp();
    }

    pub fn cancel(self: *ScanResult) void {
        self.was_cancelled = true;
        self.completed_at = getCurrentTimestamp();
    }

    pub fn withPDFPath(self: *ScanResult, path: []const u8) void {
        const copy_len = @min(path.len, self.pdf_path_buffer.len);
        @memcpy(self.pdf_path_buffer[0..copy_len], path[0..copy_len]);
        self.pdf_path_len = copy_len;
    }

    pub fn withCombinedText(self: *ScanResult, text: []const u8) void {
        const copy_len = @min(text.len, self.combined_text_buffer.len);
        @memcpy(self.combined_text_buffer[0..copy_len], text[0..copy_len]);
        self.combined_text_len = copy_len;
    }

    pub fn getSessionId(self: *const ScanResult) []const u8 {
        return self.session_id_buffer[0..self.session_id_len];
    }

    pub fn getPDFPath(self: *const ScanResult) []const u8 {
        return self.pdf_path_buffer[0..self.pdf_path_len];
    }

    pub fn getCombinedText(self: *const ScanResult) []const u8 {
        return self.combined_text_buffer[0..self.combined_text_len];
    }

    pub fn getPage(self: *const ScanResult, index: usize) ?*const ScannedPage {
        if (index < self.page_count) {
            return &self.pages[index];
        }
        return null;
    }

    pub fn getDuration(self: *const ScanResult) i64 {
        if (self.completed_at == 0) {
            return getCurrentTimestamp() - self.started_at;
        }
        return self.completed_at - self.started_at;
    }

    pub fn isSuccessful(self: *const ScanResult) bool {
        return !self.was_cancelled and self.page_count > 0;
    }
};

/// Scanner state
pub const ScannerState = enum {
    idle,
    initializing,
    ready,
    scanning,
    processing,
    completed,
    cancelled,
    failed,

    pub fn displayName(self: ScannerState) []const u8 {
        return switch (self) {
            .idle => "Idle",
            .initializing => "Initializing",
            .ready => "Ready",
            .scanning => "Scanning",
            .processing => "Processing",
            .completed => "Completed",
            .cancelled => "Cancelled",
            .failed => "Failed",
        };
    }

    pub fn isActive(self: ScannerState) bool {
        return self == .scanning or self == .processing;
    }
};

/// OCR result for a text region
pub const OCRRegion = struct {
    /// Bounding box (normalized coordinates)
    bounds: Quad = Quad.fullFrame(),

    /// Recognized text
    text_buffer: [1024]u8 = [_]u8{0} ** 1024,
    text_len: usize = 0,

    /// Confidence score (0-1)
    confidence: f32 = 0,

    /// Detected language
    language_buffer: [8]u8 = [_]u8{0} ** 8,
    language_len: usize = 0,

    pub fn init(text: []const u8, confidence: f32) OCRRegion {
        var result = OCRRegion{
            .confidence = confidence,
        };
        const copy_len = @min(text.len, result.text_buffer.len);
        @memcpy(result.text_buffer[0..copy_len], text[0..copy_len]);
        result.text_len = copy_len;
        return result;
    }

    pub fn withBounds(self: OCRRegion, bounds: Quad) OCRRegion {
        var result = self;
        result.bounds = bounds;
        return result;
    }

    pub fn withLanguage(self: OCRRegion, lang: []const u8) OCRRegion {
        var result = self;
        const copy_len = @min(lang.len, result.language_buffer.len);
        @memcpy(result.language_buffer[0..copy_len], lang[0..copy_len]);
        result.language_len = copy_len;
        return result;
    }

    pub fn getText(self: *const OCRRegion) []const u8 {
        return self.text_buffer[0..self.text_len];
    }

    pub fn getLanguage(self: *const OCRRegion) []const u8 {
        return self.language_buffer[0..self.language_len];
    }
};

/// Image enhancement options
pub const EnhancementOptions = struct {
    /// Adjust brightness (-1 to 1)
    brightness: f32 = 0,

    /// Adjust contrast (-1 to 1)
    contrast: f32 = 0,

    /// Adjust sharpness (-1 to 1)
    sharpness: f32 = 0,

    /// Remove shadows
    remove_shadows: bool = false,

    /// Auto white balance
    auto_white_balance: bool = true,

    /// Denoise
    denoise: bool = false,

    /// Deskew (auto-rotate)
    deskew: bool = true,

    pub fn init() EnhancementOptions {
        return .{};
    }

    pub fn withBrightness(self: EnhancementOptions, value: f32) EnhancementOptions {
        var result = self;
        result.brightness = std.math.clamp(value, -1.0, 1.0);
        return result;
    }

    pub fn withContrast(self: EnhancementOptions, value: f32) EnhancementOptions {
        var result = self;
        result.contrast = std.math.clamp(value, -1.0, 1.0);
        return result;
    }

    pub fn withSharpness(self: EnhancementOptions, value: f32) EnhancementOptions {
        var result = self;
        result.sharpness = std.math.clamp(value, -1.0, 1.0);
        return result;
    }

    pub fn withShadowRemoval(self: EnhancementOptions, enabled: bool) EnhancementOptions {
        var result = self;
        result.remove_shadows = enabled;
        return result;
    }

    pub fn withAutoWhiteBalance(self: EnhancementOptions, enabled: bool) EnhancementOptions {
        var result = self;
        result.auto_white_balance = enabled;
        return result;
    }

    pub fn withDenoise(self: EnhancementOptions, enabled: bool) EnhancementOptions {
        var result = self;
        result.denoise = enabled;
        return result;
    }

    pub fn withDeskew(self: EnhancementOptions, enabled: bool) EnhancementOptions {
        var result = self;
        result.deskew = enabled;
        return result;
    }
};

/// Document scanner controller
pub const DocumentScannerController = struct {
    allocator: Allocator,
    platform: ScannerPlatform,
    state: ScannerState,
    config: ScannerConfig,
    current_result: ?ScanResult,
    scan_count: u32,

    pub fn init(allocator: Allocator) DocumentScannerController {
        const platform = detectPlatform();
        return .{
            .allocator = allocator,
            .platform = platform,
            .state = .idle,
            .config = ScannerConfig.init(),
            .current_result = null,
            .scan_count = 0,
        };
    }

    pub fn deinit(self: *DocumentScannerController) void {
        _ = self;
        // Clean up any resources
    }

    fn detectPlatform() ScannerPlatform {
        return switch (builtin.os.tag) {
            .ios => .visionkit,
            .macos => .visionkit,
            .linux => if (builtin.abi == .android) .mlkit else .camera_generic,
            .windows => .windows_imaging,
            else => .unknown,
        };
    }

    pub fn configure(self: *DocumentScannerController, config: ScannerConfig) void {
        self.config = config;
    }

    pub fn startScan(self: *DocumentScannerController) ![]const u8 {
        if (self.state.isActive()) {
            return error.ScanInProgress;
        }

        self.state = .initializing;
        self.scan_count += 1;

        // Generate session ID
        var session_id_buf: [64]u8 = undefined;
        const session_id = std.fmt.bufPrint(&session_id_buf, "scan-{d}", .{self.scan_count}) catch "scan-0";

        self.current_result = ScanResult.init(session_id);
        self.current_result.?.output_format = self.config.output_format;

        self.state = .ready;

        return self.current_result.?.getSessionId();
    }

    pub fn capturePage(self: *DocumentScannerController) !*ScannedPage {
        if (self.state != .ready and self.state != .scanning) {
            return error.NotReady;
        }

        self.state = .scanning;

        if (self.current_result) |*result| {
            const page_index = result.page_count;

            // Check max pages
            if (self.config.max_pages > 0 and page_index >= self.config.max_pages) {
                return error.MaxPagesReached;
            }

            var page = ScannedPage.init(@intCast(page_index));
            page = page.withEnhanced(self.config.image_enhancement);
            page = page.withCorrected(self.config.perspective_correction);

            if (result.addPage(page)) {
                self.state = .ready;
                return &result.pages[result.page_count - 1];
            }
        }

        return error.ScanFailed;
    }

    pub fn completeScan(self: *DocumentScannerController) !*const ScanResult {
        if (self.current_result) |*result| {
            self.state = .processing;

            // Combine OCR text if enabled
            if (self.config.ocr_enabled) {
                var combined_buf: [16384]u8 = undefined;
                var combined_len: usize = 0;

                for (0..result.page_count) |i| {
                    const page = &result.pages[i];
                    if (page.hasOCRText()) {
                        const text = page.getOCRText();
                        const copy_len = @min(text.len, combined_buf.len - combined_len);
                        if (copy_len > 0) {
                            @memcpy(combined_buf[combined_len .. combined_len + copy_len], text[0..copy_len]);
                            combined_len += copy_len;
                            if (combined_len < combined_buf.len - 1) {
                                combined_buf[combined_len] = '\n';
                                combined_len += 1;
                            }
                        }
                    }
                }

                if (combined_len > 0) {
                    result.withCombinedText(combined_buf[0..combined_len]);
                }
            }

            result.complete();
            self.state = .completed;

            return result;
        }

        return error.NoScanInProgress;
    }

    pub fn cancelScan(self: *DocumentScannerController) void {
        if (self.current_result) |*result| {
            result.cancel();
        }
        self.state = .cancelled;
    }

    pub fn getState(self: *DocumentScannerController) ScannerState {
        return self.state;
    }

    pub fn getCurrentResult(self: *DocumentScannerController) ?*const ScanResult {
        if (self.current_result) |*result| {
            return result;
        }
        return null;
    }

    pub fn reset(self: *DocumentScannerController) void {
        self.state = .idle;
        self.current_result = null;
    }

    pub fn supportsOCR(self: *DocumentScannerController) bool {
        return self.platform.supportsOCR();
    }

    pub fn supportsAutoEdgeDetection(self: *DocumentScannerController) bool {
        return self.platform.supportsAutoEdgeDetection();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "ScannerPlatform display names and capabilities" {
    try std.testing.expectEqualStrings("VisionKit", ScannerPlatform.visionkit.displayName());
    try std.testing.expectEqualStrings("ML Kit", ScannerPlatform.mlkit.displayName());
    try std.testing.expect(ScannerPlatform.visionkit.supportsAutoEdgeDetection());
    try std.testing.expect(ScannerPlatform.visionkit.supportsOCR());
    try std.testing.expect(!ScannerPlatform.camera_generic.supportsOCR());
}

test "DocumentType display names and aspect ratios" {
    try std.testing.expectEqualStrings("Receipt", DocumentType.receipt.displayName());
    try std.testing.expectEqualStrings("Business Card", DocumentType.business_card.displayName());
    try std.testing.expect(DocumentType.id_card.suggestedAspectRatio() == 1.586);
}

test "ImageFormat extensions and MIME types" {
    try std.testing.expectEqualStrings(".jpg", ImageFormat.jpeg.fileExtension());
    try std.testing.expectEqualStrings(".pdf", ImageFormat.pdf.fileExtension());
    try std.testing.expectEqualStrings("image/jpeg", ImageFormat.jpeg.mimeType());
    try std.testing.expectEqualStrings("application/pdf", ImageFormat.pdf.mimeType());
}

test "ColorMode display names" {
    try std.testing.expectEqualStrings("Grayscale", ColorMode.grayscale.displayName());
    try std.testing.expectEqualStrings("Black & White", ColorMode.black_white.displayName());
}

test "QualityPreset values" {
    try std.testing.expect(QualityPreset.low.jpegQuality() == 60);
    try std.testing.expect(QualityPreset.maximum.jpegQuality() == 100);
    try std.testing.expect(QualityPreset.high.maxResolution() == 3072);
}

test "Point distance calculation" {
    const p1 = Point.init(0, 0);
    const p2 = Point.init(3, 4);

    try std.testing.expect(p1.distance(p2) == 5.0);
}

test "Quad initialization and validation" {
    const quad = Quad.init(
        Point.init(0.1, 0.1),
        Point.init(0.9, 0.1),
        Point.init(0.1, 0.9),
        Point.init(0.9, 0.9),
    );

    try std.testing.expect(quad.isValid());
    try std.testing.expect(quad.area() > 0);
}

test "Quad fullFrame" {
    const quad = Quad.fullFrame();

    try std.testing.expect(quad.top_left.x == 0);
    try std.testing.expect(quad.bottom_right.x == 1);
    try std.testing.expect(quad.isValid());
}

test "Quad aspect ratio" {
    const square = Quad.init(
        Point.init(0, 0),
        Point.init(1, 0),
        Point.init(0, 1),
        Point.init(1, 1),
    );

    try std.testing.expect(square.aspectRatio() == 1.0);
}

test "ScannerConfig initialization and fluent API" {
    const config = ScannerConfig.init()
        .withDocumentType(.receipt)
        .withColorMode(.grayscale)
        .withQuality(.high)
        .withFormat(.pdf)
        .withEdgeDetection(true)
        .withOCR(true)
        .addOCRLanguage("en")
        .addOCRLanguage("de")
        .withMaxPages(10);

    try std.testing.expect(config.document_type == .receipt);
    try std.testing.expect(config.color_mode == .grayscale);
    try std.testing.expect(config.quality == .high);
    try std.testing.expect(config.output_format == .pdf);
    try std.testing.expect(config.ocr_enabled);
    try std.testing.expect(config.ocr_language_count == 2);
    try std.testing.expect(config.max_pages == 10);
}

test "ScannedPage initialization and fluent API" {
    const page = ScannedPage.init(0)
        .withDimensions(2048, 2800)
        .withImagePath("/tmp/scan-001.jpg")
        .withOCRText("Sample text", 0.95)
        .withFileSize(1024 * 500)
        .withEnhanced(true)
        .withCorrected(true);

    try std.testing.expect(page.page_index == 0);
    try std.testing.expect(page.width == 2048);
    try std.testing.expect(page.height == 2800);
    try std.testing.expectEqualStrings("/tmp/scan-001.jpg", page.getImagePath());
    try std.testing.expectEqualStrings("Sample text", page.getOCRText());
    try std.testing.expect(page.ocr_confidence == 0.95);
    try std.testing.expect(page.was_enhanced);
    try std.testing.expect(page.was_corrected);
}

test "ScannedPage aspect ratio" {
    const page = ScannedPage.init(0)
        .withDimensions(1000, 1414);

    const ratio = page.aspectRatio();
    try std.testing.expect(ratio > 0.7 and ratio < 0.71);
}

test "ScanResult initialization and page management" {
    var result = ScanResult.init("session-001");

    try std.testing.expectEqualStrings("session-001", result.getSessionId());
    try std.testing.expect(result.page_count == 0);

    const page1 = ScannedPage.init(0).withFileSize(1000);
    const page2 = ScannedPage.init(1).withFileSize(2000);

    try std.testing.expect(result.addPage(page1));
    try std.testing.expect(result.addPage(page2));
    try std.testing.expect(result.page_count == 2);
    try std.testing.expect(result.total_size == 3000);
}

test "ScanResult completion" {
    var result = ScanResult.init("session-001");
    _ = result.addPage(ScannedPage.init(0));

    result.complete();

    try std.testing.expect(result.completed_at > 0);
    try std.testing.expect(result.isSuccessful());
}

test "ScanResult cancellation" {
    var result = ScanResult.init("session-001");
    _ = result.addPage(ScannedPage.init(0));

    result.cancel();

    try std.testing.expect(result.was_cancelled);
    try std.testing.expect(!result.isSuccessful());
}

test "ScanResult page access" {
    var result = ScanResult.init("session-001");
    _ = result.addPage(ScannedPage.init(0).withDimensions(100, 200));

    const page = result.getPage(0);
    try std.testing.expect(page != null);
    try std.testing.expect(page.?.width == 100);

    const missing = result.getPage(10);
    try std.testing.expect(missing == null);
}

test "ScannerState display names and isActive" {
    try std.testing.expectEqualStrings("Scanning", ScannerState.scanning.displayName());
    try std.testing.expect(ScannerState.scanning.isActive());
    try std.testing.expect(ScannerState.processing.isActive());
    try std.testing.expect(!ScannerState.idle.isActive());
}

test "OCRRegion initialization and fluent API" {
    const region = OCRRegion.init("Hello World", 0.98)
        .withBounds(Quad.fullFrame())
        .withLanguage("en");

    try std.testing.expectEqualStrings("Hello World", region.getText());
    try std.testing.expect(region.confidence == 0.98);
    try std.testing.expectEqualStrings("en", region.getLanguage());
}

test "EnhancementOptions initialization and fluent API" {
    const options = EnhancementOptions.init()
        .withBrightness(0.2)
        .withContrast(0.1)
        .withSharpness(0.3)
        .withShadowRemoval(true)
        .withDenoise(true)
        .withDeskew(true);

    try std.testing.expect(options.brightness == 0.2);
    try std.testing.expect(options.contrast == 0.1);
    try std.testing.expect(options.sharpness == 0.3);
    try std.testing.expect(options.remove_shadows);
    try std.testing.expect(options.denoise);
    try std.testing.expect(options.deskew);
}

test "EnhancementOptions clamping" {
    const options = EnhancementOptions.init()
        .withBrightness(2.0) // Should be clamped to 1.0
        .withContrast(-2.0); // Should be clamped to -1.0

    try std.testing.expect(options.brightness == 1.0);
    try std.testing.expect(options.contrast == -1.0);
}

test "DocumentScannerController initialization" {
    var controller = DocumentScannerController.init(std.testing.allocator);
    defer controller.deinit();

    try std.testing.expect(controller.state == .idle);
    try std.testing.expect(controller.scan_count == 0);
}

test "DocumentScannerController configuration" {
    var controller = DocumentScannerController.init(std.testing.allocator);
    defer controller.deinit();

    controller.configure(ScannerConfig.init()
        .withDocumentType(.receipt)
        .withOCR(true));

    try std.testing.expect(controller.config.document_type == .receipt);
    try std.testing.expect(controller.config.ocr_enabled);
}

test "DocumentScannerController scan workflow" {
    var controller = DocumentScannerController.init(std.testing.allocator);
    defer controller.deinit();

    // Start scan
    const session_id = try controller.startScan();
    try std.testing.expect(session_id.len > 0);
    try std.testing.expect(controller.state == .ready);

    // Capture page
    const page = try controller.capturePage();
    try std.testing.expect(page.page_index == 0);

    // Complete scan
    const result = try controller.completeScan();
    try std.testing.expect(result.page_count == 1);
    try std.testing.expect(controller.state == .completed);
}

test "DocumentScannerController cancel" {
    var controller = DocumentScannerController.init(std.testing.allocator);
    defer controller.deinit();

    _ = try controller.startScan();
    controller.cancelScan();

    try std.testing.expect(controller.state == .cancelled);
    const result = controller.getCurrentResult();
    try std.testing.expect(result != null);
    try std.testing.expect(result.?.was_cancelled);
}

test "DocumentScannerController reset" {
    var controller = DocumentScannerController.init(std.testing.allocator);
    defer controller.deinit();

    _ = try controller.startScan();
    controller.reset();

    try std.testing.expect(controller.state == .idle);
    try std.testing.expect(controller.getCurrentResult() == null);
}

test "DocumentScannerController not ready error" {
    var controller = DocumentScannerController.init(std.testing.allocator);
    defer controller.deinit();

    // Try to capture without starting a scan
    const result = controller.capturePage();
    try std.testing.expectError(error.NotReady, result);
}

test "DocumentScannerController max pages" {
    var controller = DocumentScannerController.init(std.testing.allocator);
    defer controller.deinit();

    controller.configure(ScannerConfig.init().withMaxPages(1));

    _ = try controller.startScan();
    _ = try controller.capturePage();

    // Try to capture beyond max
    const result = controller.capturePage();
    try std.testing.expectError(error.MaxPagesReached, result);
}

test "DocumentScannerController platform capabilities" {
    var controller = DocumentScannerController.init(std.testing.allocator);
    defer controller.deinit();

    // These depend on the platform but should not crash
    _ = controller.supportsOCR();
    _ = controller.supportsAutoEdgeDetection();
}
