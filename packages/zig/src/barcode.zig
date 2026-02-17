//! Cross-platform barcode scanning and generation module
//! Provides abstractions for AVFoundation/Vision (iOS/macOS) and ML Kit/ZXing (Android)

const std = @import("std");

/// Barcode symbology types
pub const BarcodeFormat = enum {
    // 1D Barcodes
    code_39,
    code_93,
    code_128,
    ean_8,
    ean_13,
    upc_a,
    upc_e,
    itf, // Interleaved 2 of 5
    codabar,
    pdf417,

    // 2D Barcodes
    qr_code,
    data_matrix,
    aztec,
    micro_qr,
    maxi_code,

    pub fn toString(self: BarcodeFormat) []const u8 {
        return switch (self) {
            .code_39 => "Code 39",
            .code_93 => "Code 93",
            .code_128 => "Code 128",
            .ean_8 => "EAN-8",
            .ean_13 => "EAN-13",
            .upc_a => "UPC-A",
            .upc_e => "UPC-E",
            .itf => "ITF",
            .codabar => "Codabar",
            .pdf417 => "PDF417",
            .qr_code => "QR Code",
            .data_matrix => "Data Matrix",
            .aztec => "Aztec",
            .micro_qr => "Micro QR",
            .maxi_code => "MaxiCode",
        };
    }

    pub fn is1D(self: BarcodeFormat) bool {
        return switch (self) {
            .code_39, .code_93, .code_128, .ean_8, .ean_13, .upc_a, .upc_e, .itf, .codabar => true,
            else => false,
        };
    }

    pub fn is2D(self: BarcodeFormat) bool {
        return !self.is1D();
    }

    pub fn maxDataLength(self: BarcodeFormat) usize {
        return switch (self) {
            .code_39 => 43,
            .code_93 => 48,
            .code_128 => 80,
            .ean_8 => 8,
            .ean_13 => 13,
            .upc_a => 12,
            .upc_e => 8,
            .itf => 14,
            .codabar => 16,
            .pdf417 => 1850,
            .qr_code => 4296,
            .data_matrix => 2335,
            .aztec => 3832,
            .micro_qr => 35,
            .maxi_code => 93,
        };
    }

    pub fn supportsAlphanumeric(self: BarcodeFormat) bool {
        return switch (self) {
            .code_39, .code_93, .code_128, .codabar, .pdf417, .qr_code, .data_matrix, .aztec => true,
            else => false,
        };
    }
};

/// QR Code error correction level
pub const QRErrorCorrection = enum {
    low, // ~7% recovery
    medium, // ~15% recovery
    quartile, // ~25% recovery
    high, // ~30% recovery

    pub fn toString(self: QRErrorCorrection) []const u8 {
        return switch (self) {
            .low => "L",
            .medium => "M",
            .quartile => "Q",
            .high => "H",
        };
    }

    pub fn recoveryPercentage(self: QRErrorCorrection) u8 {
        return switch (self) {
            .low => 7,
            .medium => 15,
            .quartile => 25,
            .high => 30,
        };
    }
};

/// Bounding rectangle for detected barcode
pub const BoundingRect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    pub fn init(x: f32, y: f32, width: f32, height: f32) BoundingRect {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }

    pub fn center(self: BoundingRect) struct { x: f32, y: f32 } {
        return .{
            .x = self.x + self.width / 2.0,
            .y = self.y + self.height / 2.0,
        };
    }

    pub fn area(self: BoundingRect) f32 {
        return self.width * self.height;
    }

    pub fn contains(self: BoundingRect, px: f32, py: f32) bool {
        return px >= self.x and px <= self.x + self.width and
            py >= self.y and py <= self.y + self.height;
    }

    pub fn intersects(self: BoundingRect, other: BoundingRect) bool {
        return !(self.x + self.width < other.x or
            other.x + other.width < self.x or
            self.y + self.height < other.y or
            other.y + other.height < self.y);
    }
};

/// Corner points for barcode detection
pub const CornerPoints = struct {
    top_left: struct { x: f32, y: f32 },
    top_right: struct { x: f32, y: f32 },
    bottom_right: struct { x: f32, y: f32 },
    bottom_left: struct { x: f32, y: f32 },

    pub fn fromRect(rect: BoundingRect) CornerPoints {
        return .{
            .top_left = .{ .x = rect.x, .y = rect.y },
            .top_right = .{ .x = rect.x + rect.width, .y = rect.y },
            .bottom_right = .{ .x = rect.x + rect.width, .y = rect.y + rect.height },
            .bottom_left = .{ .x = rect.x, .y = rect.y + rect.height },
        };
    }

    pub fn toBoundingRect(self: CornerPoints) BoundingRect {
        const min_x = @min(@min(self.top_left.x, self.top_right.x), @min(self.bottom_left.x, self.bottom_right.x));
        const max_x = @max(@max(self.top_left.x, self.top_right.x), @max(self.bottom_left.x, self.bottom_right.x));
        const min_y = @min(@min(self.top_left.y, self.top_right.y), @min(self.bottom_left.y, self.bottom_right.y));
        const max_y = @max(@max(self.top_left.y, self.top_right.y), @max(self.bottom_left.y, self.bottom_right.y));
        return BoundingRect.init(min_x, min_y, max_x - min_x, max_y - min_y);
    }
};

/// Scanned barcode result
pub const BarcodeResult = struct {
    format: BarcodeFormat,
    raw_value: []const u8,
    display_value: ?[]const u8,
    bounding_rect: BoundingRect,
    corner_points: ?CornerPoints,
    confidence: f32, // 0.0 - 1.0
    timestamp: u64,

    pub fn init(format: BarcodeFormat, value: []const u8) BarcodeResult {
        return .{
            .format = format,
            .raw_value = value,
            .display_value = null,
            .bounding_rect = BoundingRect.init(0, 0, 0, 0),
            .corner_points = null,
            .confidence = 1.0,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn withBounds(self: BarcodeResult, rect: BoundingRect) BarcodeResult {
        var result = self;
        result.bounding_rect = rect;
        result.corner_points = CornerPoints.fromRect(rect);
        return result;
    }

    pub fn withConfidence(self: BarcodeResult, confidence: f32) BarcodeResult {
        var result = self;
        result.confidence = std.math.clamp(confidence, 0.0, 1.0);
        return result;
    }

    pub fn isHighConfidence(self: BarcodeResult) bool {
        return self.confidence >= 0.9;
    }

    fn getCurrentTimestamp() u64 {
        var ts: std.c.timespec = undefined;
        if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
            return @intCast(@divTrunc(ts.sec * 1000 + @divTrunc(ts.nsec, 1_000_000), 1));
        }
        return 0;
    }
};

/// Barcode content type (for QR codes and 2D barcodes)
pub const BarcodeContentType = enum {
    text,
    url,
    email,
    phone,
    sms,
    geo,
    wifi,
    vcard,
    vevent,
    mecard,
    unknown,

    pub fn toString(self: BarcodeContentType) []const u8 {
        return switch (self) {
            .text => "Text",
            .url => "URL",
            .email => "Email",
            .phone => "Phone",
            .sms => "SMS",
            .geo => "Geographic",
            .wifi => "WiFi",
            .vcard => "vCard",
            .vevent => "Calendar Event",
            .mecard => "MeCard",
            .unknown => "Unknown",
        };
    }

    pub fn detect(value: []const u8) BarcodeContentType {
        if (value.len == 0) return .unknown;

        if (std.mem.startsWith(u8, value, "http://") or std.mem.startsWith(u8, value, "https://")) {
            return .url;
        }
        if (std.mem.startsWith(u8, value, "mailto:")) {
            return .email;
        }
        if (std.mem.startsWith(u8, value, "tel:")) {
            return .phone;
        }
        if (std.mem.startsWith(u8, value, "smsto:") or std.mem.startsWith(u8, value, "sms:")) {
            return .sms;
        }
        if (std.mem.startsWith(u8, value, "geo:")) {
            return .geo;
        }
        if (std.mem.startsWith(u8, value, "WIFI:")) {
            return .wifi;
        }
        if (std.mem.startsWith(u8, value, "BEGIN:VCARD")) {
            return .vcard;
        }
        if (std.mem.startsWith(u8, value, "BEGIN:VEVENT")) {
            return .vevent;
        }
        if (std.mem.startsWith(u8, value, "MECARD:")) {
            return .mecard;
        }
        return .text;
    }
};

/// WiFi configuration from QR code
pub const WiFiConfig = struct {
    ssid: []const u8,
    password: ?[]const u8,
    security_type: SecurityType,
    is_hidden: bool,

    pub const SecurityType = enum {
        none,
        wep,
        wpa,
        wpa2,
        wpa3,

        pub fn toString(self: SecurityType) []const u8 {
            return switch (self) {
                .none => "None",
                .wep => "WEP",
                .wpa => "WPA",
                .wpa2 => "WPA2",
                .wpa3 => "WPA3",
            };
        }
    };

    pub fn parse(value: []const u8) ?WiFiConfig {
        if (!std.mem.startsWith(u8, value, "WIFI:")) return null;

        var ssid: ?[]const u8 = null;
        var password: ?[]const u8 = null;
        var security = SecurityType.none;
        var hidden = false;

        var iter = std.mem.splitSequence(u8, value[5..], ";");
        while (iter.next()) |part| {
            if (std.mem.startsWith(u8, part, "S:")) {
                ssid = part[2..];
            } else if (std.mem.startsWith(u8, part, "P:")) {
                password = part[2..];
            } else if (std.mem.startsWith(u8, part, "T:")) {
                const t = part[2..];
                if (std.mem.eql(u8, t, "WEP")) security = .wep else if (std.mem.eql(u8, t, "WPA")) security = .wpa else if (std.mem.eql(u8, t, "WPA2")) security = .wpa2 else if (std.mem.eql(u8, t, "WPA3")) security = .wpa3;
            } else if (std.mem.startsWith(u8, part, "H:")) {
                hidden = std.mem.eql(u8, part[2..], "true");
            }
        }

        if (ssid) |s| {
            return .{
                .ssid = s,
                .password = password,
                .security_type = security,
                .is_hidden = hidden,
            };
        }
        return null;
    }

    pub fn encode(self: WiFiConfig) []const u8 {
        _ = self;
        // Would build WIFI: string
        return "WIFI:S:NetworkName;T:WPA;P:password;;";
    }
};

/// Contact info from vCard/MeCard
pub const ContactInfo = struct {
    name: ?[]const u8,
    phone: ?[]const u8,
    email: ?[]const u8,
    organization: ?[]const u8,
    address: ?[]const u8,
    url: ?[]const u8,

    pub fn init() ContactInfo {
        return .{
            .name = null,
            .phone = null,
            .email = null,
            .organization = null,
            .address = null,
            .url = null,
        };
    }

    pub fn withName(self: ContactInfo, name: []const u8) ContactInfo {
        var info = self;
        info.name = name;
        return info;
    }

    pub fn withPhone(self: ContactInfo, phone: []const u8) ContactInfo {
        var info = self;
        info.phone = phone;
        return info;
    }

    pub fn withEmail(self: ContactInfo, email: []const u8) ContactInfo {
        var info = self;
        info.email = email;
        return info;
    }
};

/// Geo location from QR code
pub const GeoLocation = struct {
    latitude: f64,
    longitude: f64,
    altitude: ?f64,
    query: ?[]const u8,

    pub fn parse(value: []const u8) ?GeoLocation {
        if (!std.mem.startsWith(u8, value, "geo:")) return null;

        const coords_str = value[4..];
        var parts = std.mem.splitScalar(u8, coords_str, ',');

        const lat_str = parts.next() orelse return null;
        const lon_str = parts.next() orelse return null;

        const lat = std.fmt.parseFloat(f64, lat_str) catch return null;
        const lon = std.fmt.parseFloat(f64, lon_str) catch return null;

        return .{
            .latitude = lat,
            .longitude = lon,
            .altitude = null,
            .query = null,
        };
    }

    pub fn encode(self: GeoLocation) []const u8 {
        _ = self;
        return "geo:0.0,0.0";
    }
};

/// Scanner configuration
pub const ScannerConfig = struct {
    formats: std.ArrayListUnmanaged(BarcodeFormat),
    is_torch_enabled: bool,
    is_vibration_enabled: bool,
    is_beep_enabled: bool,
    scan_interval_ms: u32,
    auto_focus: bool,
    restrict_to_region: ?BoundingRect,

    pub fn init(allocator: std.mem.Allocator) ScannerConfig {
        _ = allocator;
        return .{
            .formats = .{},
            .is_torch_enabled = false,
            .is_vibration_enabled = true,
            .is_beep_enabled = true,
            .scan_interval_ms = 500,
            .auto_focus = true,
            .restrict_to_region = null,
        };
    }

    pub fn deinit(self: *ScannerConfig, allocator: std.mem.Allocator) void {
        self.formats.deinit(allocator);
    }

    pub fn addFormat(self: *ScannerConfig, allocator: std.mem.Allocator, format: BarcodeFormat) !void {
        try self.formats.append(allocator, format);
    }

    pub fn addAllFormats(self: *ScannerConfig, allocator: std.mem.Allocator) !void {
        const all_formats = [_]BarcodeFormat{
            .code_39, .code_93,     .code_128, .ean_8,    .ean_13,
            .upc_a,   .upc_e,       .itf,      .codabar,  .pdf417,
            .qr_code, .data_matrix, .aztec,    .micro_qr, .maxi_code,
        };
        for (all_formats) |format| {
            try self.formats.append(allocator, format);
        }
    }

    pub fn withTorch(self: ScannerConfig, enabled: bool) ScannerConfig {
        var config = self;
        config.is_torch_enabled = enabled;
        return config;
    }

    pub fn withScanInterval(self: ScannerConfig, ms: u32) ScannerConfig {
        var config = self;
        config.scan_interval_ms = @max(100, ms);
        return config;
    }

    pub fn withRegion(self: ScannerConfig, rect: BoundingRect) ScannerConfig {
        var config = self;
        config.restrict_to_region = rect;
        return config;
    }

    pub fn supportsFormat(self: *const ScannerConfig, format: BarcodeFormat) bool {
        for (self.formats.items) |f| {
            if (f == format) return true;
        }
        return false;
    }
};

/// Scanner session state
pub const ScannerState = enum {
    idle,
    starting,
    scanning,
    paused,
    stopped,
    scanner_error,

    pub fn toString(self: ScannerState) []const u8 {
        return switch (self) {
            .idle => "Idle",
            .starting => "Starting",
            .scanning => "Scanning",
            .paused => "Paused",
            .stopped => "Stopped",
            .scanner_error => "Error",
        };
    }

    pub fn isActive(self: ScannerState) bool {
        return self == .scanning;
    }
};

/// Barcode scanner session
pub const BarcodeScanner = struct {
    allocator: std.mem.Allocator,
    config: ScannerConfig,
    state: ScannerState,
    results: std.ArrayListUnmanaged(BarcodeResult),
    last_scan_time: u64,
    scan_count: u32,

    pub fn init(allocator: std.mem.Allocator) BarcodeScanner {
        return .{
            .allocator = allocator,
            .config = ScannerConfig.init(allocator),
            .state = .idle,
            .results = .{},
            .last_scan_time = 0,
            .scan_count = 0,
        };
    }

    pub fn deinit(self: *BarcodeScanner) void {
        self.config.deinit(self.allocator);
        self.results.deinit(self.allocator);
    }

    pub fn start(self: *BarcodeScanner) !void {
        if (self.state == .scanning) return;
        self.state = .starting;
        // Platform-specific camera initialization would happen here
        self.state = .scanning;
    }

    pub fn stop(self: *BarcodeScanner) void {
        self.state = .stopped;
    }

    pub fn pause(self: *BarcodeScanner) void {
        if (self.state == .scanning) {
            self.state = .paused;
        }
    }

    pub fn resumeScanning(self: *BarcodeScanner) void {
        if (self.state == .paused) {
            self.state = .scanning;
        }
    }

    pub fn toggleTorch(self: *BarcodeScanner) void {
        self.config.is_torch_enabled = !self.config.is_torch_enabled;
    }

    pub fn onBarcodeDetected(self: *BarcodeScanner, result: BarcodeResult) !void {
        try self.results.append(self.allocator, result);
        var ts: std.c.timespec = undefined;
        if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
            self.last_scan_time = @intCast(@divTrunc(ts.sec * 1000 + @divTrunc(ts.nsec, 1_000_000), 1));
        }
        self.scan_count += 1;
    }

    pub fn clearResults(self: *BarcodeScanner) void {
        self.results.clearRetainingCapacity();
    }

    pub fn getLastResult(self: *const BarcodeScanner) ?BarcodeResult {
        if (self.results.items.len == 0) return null;
        return self.results.items[self.results.items.len - 1];
    }

    pub fn isScanning(self: *const BarcodeScanner) bool {
        return self.state.isActive();
    }
};

/// Barcode generation options
pub const GeneratorOptions = struct {
    format: BarcodeFormat,
    width: u32,
    height: u32,
    margin: u32,
    foreground_color: u32, // ARGB
    background_color: u32, // ARGB
    error_correction: QRErrorCorrection,

    pub fn defaults(format: BarcodeFormat) GeneratorOptions {
        const size: u32 = if (format.is2D()) 256 else 300;
        const h: u32 = if (format.is2D()) 256 else 100;
        return .{
            .format = format,
            .width = size,
            .height = h,
            .margin = 4,
            .foreground_color = 0xFF000000, // Black
            .background_color = 0xFFFFFFFF, // White
            .error_correction = .medium,
        };
    }

    pub fn withSize(self: GeneratorOptions, width: u32, height: u32) GeneratorOptions {
        var opts = self;
        opts.width = width;
        opts.height = height;
        return opts;
    }

    pub fn withMargin(self: GeneratorOptions, margin: u32) GeneratorOptions {
        var opts = self;
        opts.margin = margin;
        return opts;
    }

    pub fn withColors(self: GeneratorOptions, foreground: u32, background: u32) GeneratorOptions {
        var opts = self;
        opts.foreground_color = foreground;
        opts.background_color = background;
        return opts;
    }

    pub fn withErrorCorrection(self: GeneratorOptions, level: QRErrorCorrection) GeneratorOptions {
        var opts = self;
        opts.error_correction = level;
        return opts;
    }
};

/// Generated barcode image
pub const BarcodeImage = struct {
    width: u32,
    height: u32,
    format: BarcodeFormat,
    data: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32, format: BarcodeFormat) !BarcodeImage {
        const size = width * height * 4; // RGBA
        const data = try allocator.alloc(u8, size);
        @memset(data, 255); // White background
        return .{
            .width = width,
            .height = height,
            .format = format,
            .data = data,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BarcodeImage) void {
        self.allocator.free(self.data);
    }

    pub fn setPixel(self: *BarcodeImage, x: u32, y: u32, color: u32) void {
        if (x >= self.width or y >= self.height) return;
        const idx = (y * self.width + x) * 4;
        self.data[idx] = @truncate((color >> 16) & 0xFF); // R
        self.data[idx + 1] = @truncate((color >> 8) & 0xFF); // G
        self.data[idx + 2] = @truncate(color & 0xFF); // B
        self.data[idx + 3] = @truncate((color >> 24) & 0xFF); // A
    }

    pub fn getPixel(self: *const BarcodeImage, x: u32, y: u32) u32 {
        if (x >= self.width or y >= self.height) return 0;
        const idx = (y * self.width + x) * 4;
        return (@as(u32, self.data[idx + 3]) << 24) |
            (@as(u32, self.data[idx]) << 16) |
            (@as(u32, self.data[idx + 1]) << 8) |
            @as(u32, self.data[idx + 2]);
    }

    pub fn dataSize(self: *const BarcodeImage) usize {
        return self.data.len;
    }
};

/// Barcode generator
pub const BarcodeGenerator = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) BarcodeGenerator {
        return .{ .allocator = allocator };
    }

    pub fn generate(self: *BarcodeGenerator, data: []const u8, options: GeneratorOptions) !BarcodeImage {
        // Validate data length
        if (data.len > options.format.maxDataLength()) {
            return error.DataTooLong;
        }

        var image = try BarcodeImage.init(self.allocator, options.width, options.height, options.format);

        // Fill background
        for (0..options.height) |y| {
            for (0..options.width) |x| {
                image.setPixel(@intCast(x), @intCast(y), options.background_color);
            }
        }

        // Generate pattern (simplified - real implementation would encode properly)
        if (options.format.is2D()) {
            try self.generate2DPattern(&image, data, options);
        } else {
            try self.generate1DPattern(&image, data, options);
        }

        return image;
    }

    fn generate1DPattern(self: *BarcodeGenerator, image: *BarcodeImage, data: []const u8, options: GeneratorOptions) !void {
        _ = self;
        const bar_width = (options.width - options.margin * 2) / @as(u32, @intCast(data.len * 11 + 35));
        const bar_height = options.height - options.margin * 2;

        var x = options.margin;
        for (data) |byte| {
            // Simple pattern based on data
            const pattern = byte % 4;
            for (0..@as(usize, pattern + 1)) |_| {
                for (0..bar_height) |y| {
                    image.setPixel(x, @intCast(options.margin + y), options.foreground_color);
                }
                x += bar_width;
            }
            x += bar_width; // Gap
        }
    }

    fn generate2DPattern(self: *BarcodeGenerator, image: *BarcodeImage, data: []const u8, options: GeneratorOptions) !void {
        _ = self;
        const module_size = @min(
            (options.width - options.margin * 2) / 21,
            (options.height - options.margin * 2) / 21,
        );

        // Draw finder patterns (simplified QR code)
        const patterns = [_]struct { x: u32, y: u32 }{
            .{ .x = options.margin, .y = options.margin },
            .{ .x = options.width - options.margin - module_size * 7, .y = options.margin },
            .{ .x = options.margin, .y = options.height - options.margin - module_size * 7 },
        };

        for (patterns) |p| {
            // Outer square
            for (0..7) |dy| {
                for (0..7) |dx| {
                    const is_border = dy == 0 or dy == 6 or dx == 0 or dx == 6;
                    const is_center = dx >= 2 and dx <= 4 and dy >= 2 and dy <= 4;
                    if (is_border or is_center) {
                        for (0..module_size) |my| {
                            for (0..module_size) |mx| {
                                image.setPixel(
                                    @intCast(p.x + @as(u32, @intCast(dx)) * module_size + mx),
                                    @intCast(p.y + @as(u32, @intCast(dy)) * module_size + my),
                                    options.foreground_color,
                                );
                            }
                        }
                    }
                }
            }
        }

        // Add some data modules (simplified)
        var hash: u32 = 0;
        for (data) |byte| {
            hash = hash *% 31 +% byte;
        }

        const data_start_x = options.margin + module_size * 9;
        const data_start_y = options.margin + module_size * 9;

        for (0..5) |row| {
            for (0..5) |col| {
                if (((hash >> @intCast(row * 5 + col)) & 1) == 1) {
                    for (0..module_size) |my| {
                        for (0..module_size) |mx| {
                            image.setPixel(
                                @intCast(data_start_x + @as(u32, @intCast(col)) * module_size + mx),
                                @intCast(data_start_y + @as(u32, @intCast(row)) * module_size + my),
                                options.foreground_color,
                            );
                        }
                    }
                }
            }
        }
    }

    pub fn generateQR(self: *BarcodeGenerator, data: []const u8) !BarcodeImage {
        return self.generate(data, GeneratorOptions.defaults(.qr_code));
    }

    pub fn generateEAN13(self: *BarcodeGenerator, data: []const u8) !BarcodeImage {
        if (data.len != 13) return error.InvalidDataLength;
        return self.generate(data, GeneratorOptions.defaults(.ean_13));
    }
};

/// Validate barcode checksum
pub fn validateChecksum(format: BarcodeFormat, data: []const u8) bool {
    return switch (format) {
        .ean_13 => validateEAN13(data),
        .ean_8 => validateEAN8(data),
        .upc_a => validateUPCA(data),
        else => true, // No checksum validation for other formats
    };
}

fn validateEAN13(data: []const u8) bool {
    if (data.len != 13) return false;

    var sum: u32 = 0;
    for (data[0..12], 0..) |c, i| {
        if (c < '0' or c > '9') return false;
        const digit = c - '0';
        sum += if (i % 2 == 0) digit else digit * 3;
    }

    const check = (10 - (sum % 10)) % 10;
    return data[12] == '0' + @as(u8, @intCast(check));
}

fn validateEAN8(data: []const u8) bool {
    if (data.len != 8) return false;

    var sum: u32 = 0;
    for (data[0..7], 0..) |c, i| {
        if (c < '0' or c > '9') return false;
        const digit = c - '0';
        sum += if (i % 2 == 0) digit * 3 else digit;
    }

    const check = (10 - (sum % 10)) % 10;
    return data[7] == '0' + @as(u8, @intCast(check));
}

fn validateUPCA(data: []const u8) bool {
    if (data.len != 12) return false;

    var sum: u32 = 0;
    for (data[0..11], 0..) |c, i| {
        if (c < '0' or c > '9') return false;
        const digit = c - '0';
        sum += if (i % 2 == 0) digit * 3 else digit;
    }

    const check = (10 - (sum % 10)) % 10;
    return data[11] == '0' + @as(u8, @intCast(check));
}

/// Check if barcode scanning is available
pub fn isScanningAvailable() bool {
    return true; // Stub for platform check
}

/// Check if barcode generation is available
pub fn isGenerationAvailable() bool {
    return true;
}

// ============================================================================
// Tests
// ============================================================================

test "BarcodeFormat properties" {
    try std.testing.expectEqualStrings("QR Code", BarcodeFormat.qr_code.toString());
    try std.testing.expect(BarcodeFormat.qr_code.is2D());
    try std.testing.expect(BarcodeFormat.ean_13.is1D());
}

test "BarcodeFormat maxDataLength" {
    try std.testing.expectEqual(@as(usize, 4296), BarcodeFormat.qr_code.maxDataLength());
    try std.testing.expectEqual(@as(usize, 13), BarcodeFormat.ean_13.maxDataLength());
}

test "BarcodeFormat supportsAlphanumeric" {
    try std.testing.expect(BarcodeFormat.qr_code.supportsAlphanumeric());
    try std.testing.expect(!BarcodeFormat.ean_13.supportsAlphanumeric());
}

test "QRErrorCorrection properties" {
    try std.testing.expectEqualStrings("H", QRErrorCorrection.high.toString());
    try std.testing.expectEqual(@as(u8, 30), QRErrorCorrection.high.recoveryPercentage());
}

test "BoundingRect operations" {
    const rect = BoundingRect.init(10, 20, 100, 50);
    const center = rect.center();
    try std.testing.expectEqual(@as(f32, 60), center.x);
    try std.testing.expectEqual(@as(f32, 45), center.y);
    try std.testing.expectEqual(@as(f32, 5000), rect.area());
}

test "BoundingRect contains" {
    const rect = BoundingRect.init(0, 0, 100, 100);
    try std.testing.expect(rect.contains(50, 50));
    try std.testing.expect(!rect.contains(150, 50));
}

test "BoundingRect intersects" {
    const r1 = BoundingRect.init(0, 0, 100, 100);
    const r2 = BoundingRect.init(50, 50, 100, 100);
    const r3 = BoundingRect.init(200, 200, 50, 50);
    try std.testing.expect(r1.intersects(r2));
    try std.testing.expect(!r1.intersects(r3));
}

test "CornerPoints conversion" {
    const rect = BoundingRect.init(10, 20, 100, 50);
    const corners = CornerPoints.fromRect(rect);
    try std.testing.expectEqual(@as(f32, 10), corners.top_left.x);
    try std.testing.expectEqual(@as(f32, 110), corners.top_right.x);

    const back = corners.toBoundingRect();
    try std.testing.expectEqual(@as(f32, 10), back.x);
    try std.testing.expectEqual(@as(f32, 100), back.width);
}

test "BarcodeResult builder" {
    const result = BarcodeResult.init(.qr_code, "test")
        .withBounds(BoundingRect.init(0, 0, 100, 100))
        .withConfidence(0.95);
    try std.testing.expectEqual(BarcodeFormat.qr_code, result.format);
    try std.testing.expect(result.isHighConfidence());
}

test "BarcodeContentType detect" {
    try std.testing.expectEqual(BarcodeContentType.url, BarcodeContentType.detect("https://example.com"));
    try std.testing.expectEqual(BarcodeContentType.email, BarcodeContentType.detect("mailto:test@test.com"));
    try std.testing.expectEqual(BarcodeContentType.phone, BarcodeContentType.detect("tel:+1234567890"));
    try std.testing.expectEqual(BarcodeContentType.wifi, BarcodeContentType.detect("WIFI:S:MyNetwork;;"));
    try std.testing.expectEqual(BarcodeContentType.text, BarcodeContentType.detect("Hello World"));
}

test "WiFiConfig parse" {
    const config = WiFiConfig.parse("WIFI:S:MyNetwork;T:WPA2;P:secret123;;").?;
    try std.testing.expectEqualStrings("MyNetwork", config.ssid);
    try std.testing.expectEqualStrings("secret123", config.password.?);
    try std.testing.expectEqual(WiFiConfig.SecurityType.wpa2, config.security_type);
}

test "ContactInfo builder" {
    const contact = ContactInfo.init()
        .withName("John Doe")
        .withPhone("+1234567890")
        .withEmail("john@example.com");
    try std.testing.expectEqualStrings("John Doe", contact.name.?);
    try std.testing.expectEqualStrings("+1234567890", contact.phone.?);
}

test "GeoLocation parse" {
    const geo = GeoLocation.parse("geo:37.7749,-122.4194").?;
    try std.testing.expect(geo.latitude > 37.77 and geo.latitude < 37.78);
    try std.testing.expect(geo.longitude > -122.42 and geo.longitude < -122.41);
}

test "ScannerConfig operations" {
    var config = ScannerConfig.init(std.testing.allocator);
    defer config.deinit(std.testing.allocator);

    try config.addFormat(std.testing.allocator, .qr_code);
    try config.addFormat(std.testing.allocator, .ean_13);

    try std.testing.expect(config.supportsFormat(.qr_code));
    try std.testing.expect(!config.supportsFormat(.aztec));
}

test "ScannerConfig builder" {
    var config = ScannerConfig.init(std.testing.allocator);
    defer config.deinit(std.testing.allocator);

    const modified = config.withTorch(true).withScanInterval(1000);
    try std.testing.expect(modified.is_torch_enabled);
    try std.testing.expectEqual(@as(u32, 1000), modified.scan_interval_ms);
}

test "ScannerState properties" {
    try std.testing.expectEqualStrings("Scanning", ScannerState.scanning.toString());
    try std.testing.expect(ScannerState.scanning.isActive());
    try std.testing.expect(!ScannerState.paused.isActive());
}

test "BarcodeScanner lifecycle" {
    var scanner = BarcodeScanner.init(std.testing.allocator);
    defer scanner.deinit();

    try scanner.start();
    try std.testing.expect(scanner.isScanning());

    scanner.pause();
    try std.testing.expectEqual(ScannerState.paused, scanner.state);

    scanner.resumeScanning();
    try std.testing.expect(scanner.isScanning());

    scanner.stop();
    try std.testing.expectEqual(ScannerState.stopped, scanner.state);
}

test "BarcodeScanner results" {
    var scanner = BarcodeScanner.init(std.testing.allocator);
    defer scanner.deinit();

    try scanner.onBarcodeDetected(BarcodeResult.init(.qr_code, "test1"));
    try scanner.onBarcodeDetected(BarcodeResult.init(.ean_13, "1234567890123"));

    try std.testing.expectEqual(@as(u32, 2), scanner.scan_count);

    const last = scanner.getLastResult().?;
    try std.testing.expectEqual(BarcodeFormat.ean_13, last.format);
}

test "GeneratorOptions defaults" {
    const qr_opts = GeneratorOptions.defaults(.qr_code);
    try std.testing.expectEqual(@as(u32, 256), qr_opts.width);
    try std.testing.expectEqual(@as(u32, 256), qr_opts.height);

    const ean_opts = GeneratorOptions.defaults(.ean_13);
    try std.testing.expectEqual(@as(u32, 300), ean_opts.width);
    try std.testing.expectEqual(@as(u32, 100), ean_opts.height);
}

test "GeneratorOptions builder" {
    const opts = GeneratorOptions.defaults(.qr_code)
        .withSize(512, 512)
        .withMargin(8)
        .withErrorCorrection(.high);
    try std.testing.expectEqual(@as(u32, 512), opts.width);
    try std.testing.expectEqual(@as(u32, 8), opts.margin);
    try std.testing.expectEqual(QRErrorCorrection.high, opts.error_correction);
}

test "BarcodeImage operations" {
    var image = try BarcodeImage.init(std.testing.allocator, 10, 10, .qr_code);
    defer image.deinit();

    image.setPixel(5, 5, 0xFF000000);
    const pixel = image.getPixel(5, 5);
    try std.testing.expectEqual(@as(u32, 0xFF000000), pixel);
    try std.testing.expectEqual(@as(usize, 400), image.dataSize());
}

test "BarcodeGenerator generate" {
    var gen = BarcodeGenerator.init(std.testing.allocator);
    var image = try gen.generateQR("Hello World");
    defer image.deinit();

    try std.testing.expectEqual(@as(u32, 256), image.width);
    try std.testing.expectEqual(BarcodeFormat.qr_code, image.format);
}

test "validateChecksum EAN13" {
    try std.testing.expect(validateChecksum(.ean_13, "5901234123457"));
    try std.testing.expect(!validateChecksum(.ean_13, "5901234123456"));
}

test "validateChecksum EAN8" {
    try std.testing.expect(validateChecksum(.ean_8, "96385074"));
    try std.testing.expect(!validateChecksum(.ean_8, "96385075"));
}

test "isScanningAvailable" {
    try std.testing.expect(isScanningAvailable());
}

test "isGenerationAvailable" {
    try std.testing.expect(isGenerationAvailable());
}
