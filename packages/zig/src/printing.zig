//! Cross-platform printing module for Craft
//! Provides print services, page setup, and print job management
//! for iOS, Android, macOS, Windows, and Linux.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Paper size standards
pub const PaperSize = enum {
    letter, // 8.5 x 11 inches (US)
    legal, // 8.5 x 14 inches (US)
    tabloid, // 11 x 17 inches
    a0,
    a1,
    a2,
    a3,
    a4, // 210 x 297 mm (International standard)
    a5,
    a6,
    b4,
    b5,
    executive,
    folio,
    envelope_10, // #10 envelope
    envelope_dl, // DL envelope
    custom,

    pub fn toString(self: PaperSize) []const u8 {
        return switch (self) {
            .letter => "Letter",
            .legal => "Legal",
            .tabloid => "Tabloid",
            .a0 => "A0",
            .a1 => "A1",
            .a2 => "A2",
            .a3 => "A3",
            .a4 => "A4",
            .a5 => "A5",
            .a6 => "A6",
            .b4 => "B4",
            .b5 => "B5",
            .executive => "Executive",
            .folio => "Folio",
            .envelope_10 => "Envelope #10",
            .envelope_dl => "Envelope DL",
            .custom => "Custom",
        };
    }

    /// Get dimensions in points (1 point = 1/72 inch)
    pub fn getDimensions(self: PaperSize) PageDimensions {
        return switch (self) {
            .letter => .{ .width = 612, .height = 792 },
            .legal => .{ .width = 612, .height = 1008 },
            .tabloid => .{ .width = 792, .height = 1224 },
            .a0 => .{ .width = 2384, .height = 3370 },
            .a1 => .{ .width = 1684, .height = 2384 },
            .a2 => .{ .width = 1191, .height = 1684 },
            .a3 => .{ .width = 842, .height = 1191 },
            .a4 => .{ .width = 595, .height = 842 },
            .a5 => .{ .width = 420, .height = 595 },
            .a6 => .{ .width = 298, .height = 420 },
            .b4 => .{ .width = 729, .height = 1032 },
            .b5 => .{ .width = 516, .height = 729 },
            .executive => .{ .width = 522, .height = 756 },
            .folio => .{ .width = 612, .height = 936 },
            .envelope_10 => .{ .width = 297, .height = 684 },
            .envelope_dl => .{ .width = 312, .height = 624 },
            .custom => .{ .width = 0, .height = 0 },
        };
    }

    /// Get dimensions in millimeters
    pub fn getDimensionsMM(self: PaperSize) struct { width: f32, height: f32 } {
        const dims = self.getDimensions();
        // 1 point = 0.352778 mm
        return .{
            .width = @as(f32, @floatFromInt(dims.width)) * 0.352778,
            .height = @as(f32, @floatFromInt(dims.height)) * 0.352778,
        };
    }
};

/// Page dimensions in points
pub const PageDimensions = struct {
    width: u32,
    height: u32,

    pub fn landscape(self: PageDimensions) PageDimensions {
        return .{
            .width = self.height,
            .height = self.width,
        };
    }

    pub fn toInches(self: PageDimensions) struct { width: f32, height: f32 } {
        return .{
            .width = @as(f32, @floatFromInt(self.width)) / 72.0,
            .height = @as(f32, @floatFromInt(self.height)) / 72.0,
        };
    }

    pub fn toMM(self: PageDimensions) struct { width: f32, height: f32 } {
        return .{
            .width = @as(f32, @floatFromInt(self.width)) * 0.352778,
            .height = @as(f32, @floatFromInt(self.height)) * 0.352778,
        };
    }
};

/// Page orientation
pub const PageOrientation = enum {
    portrait,
    landscape,

    pub fn toString(self: PageOrientation) []const u8 {
        return switch (self) {
            .portrait => "Portrait",
            .landscape => "Landscape",
        };
    }
};

/// Print quality settings
pub const PrintQuality = enum {
    draft,
    normal,
    high,
    photo,

    pub fn toString(self: PrintQuality) []const u8 {
        return switch (self) {
            .draft => "Draft",
            .normal => "Normal",
            .high => "High",
            .photo => "Photo",
        };
    }

    pub fn getDPI(self: PrintQuality) u32 {
        return switch (self) {
            .draft => 150,
            .normal => 300,
            .high => 600,
            .photo => 1200,
        };
    }
};

/// Color mode for printing
pub const ColorMode = enum {
    auto,
    color,
    grayscale,
    monochrome,

    pub fn toString(self: ColorMode) []const u8 {
        return switch (self) {
            .auto => "Automatic",
            .color => "Color",
            .grayscale => "Grayscale",
            .monochrome => "Black & White",
        };
    }
};

/// Duplex (two-sided) printing mode
pub const DuplexMode = enum {
    none, // Single-sided
    long_edge, // Flip on long edge (book binding)
    short_edge, // Flip on short edge (calendar binding)

    pub fn toString(self: DuplexMode) []const u8 {
        return switch (self) {
            .none => "Single-sided",
            .long_edge => "Two-sided (Long Edge)",
            .short_edge => "Two-sided (Short Edge)",
        };
    }

    pub fn isTwoSided(self: DuplexMode) bool {
        return self != .none;
    }
};

/// Page margins in points
pub const PageMargins = struct {
    top: u32,
    bottom: u32,
    left: u32,
    right: u32,

    pub const none: PageMargins = .{ .top = 0, .bottom = 0, .left = 0, .right = 0 };
    pub const normal: PageMargins = .{ .top = 72, .bottom = 72, .left = 72, .right = 72 }; // 1 inch
    pub const narrow: PageMargins = .{ .top = 36, .bottom = 36, .left = 36, .right = 36 }; // 0.5 inch
    pub const wide: PageMargins = .{ .top = 72, .bottom = 72, .left = 144, .right = 144 }; // 1 inch top/bottom, 2 inch sides

    pub fn getPrintableWidth(self: PageMargins, page_width: u32) u32 {
        const margin_sum = self.left + self.right;
        if (margin_sum >= page_width) return 0;
        return page_width - margin_sum;
    }

    pub fn getPrintableHeight(self: PageMargins, page_height: u32) u32 {
        const margin_sum = self.top + self.bottom;
        if (margin_sum >= page_height) return 0;
        return page_height - margin_sum;
    }
};

/// Print job status
pub const PrintJobStatus = enum {
    pending,
    queued,
    printing,
    paused,
    completed,
    cancelled,
    failed,

    pub fn toString(self: PrintJobStatus) []const u8 {
        return switch (self) {
            .pending => "Pending",
            .queued => "Queued",
            .printing => "Printing",
            .paused => "Paused",
            .completed => "Completed",
            .cancelled => "Cancelled",
            .failed => "Failed",
        };
    }

    pub fn isActive(self: PrintJobStatus) bool {
        return switch (self) {
            .pending, .queued, .printing, .paused => true,
            .completed, .cancelled, .failed => false,
        };
    }

    pub fn isTerminal(self: PrintJobStatus) bool {
        return switch (self) {
            .completed, .cancelled, .failed => true,
            .pending, .queued, .printing, .paused => false,
        };
    }
};

/// Printer status
pub const PrinterStatus = enum {
    idle,
    printing,
    paused,
    offline,
    error_state,
    paper_jam,
    paper_out,
    toner_low,
    toner_out,
    door_open,
    unknown,

    pub fn toString(self: PrinterStatus) []const u8 {
        return switch (self) {
            .idle => "Ready",
            .printing => "Printing",
            .paused => "Paused",
            .offline => "Offline",
            .error_state => "Error",
            .paper_jam => "Paper Jam",
            .paper_out => "Out of Paper",
            .toner_low => "Low Toner",
            .toner_out => "Out of Toner",
            .door_open => "Door Open",
            .unknown => "Unknown",
        };
    }

    pub fn isReady(self: PrinterStatus) bool {
        return self == .idle;
    }

    pub fn requiresAttention(self: PrinterStatus) bool {
        return switch (self) {
            .error_state, .paper_jam, .paper_out, .toner_out, .door_open => true,
            else => false,
        };
    }
};

/// Printer capabilities
pub const PrinterCapabilities = struct {
    supports_color: bool,
    supports_duplex: bool,
    supports_collation: bool,
    supports_stapling: bool,
    supports_hole_punch: bool,
    max_copies: u32,
    max_dpi: u32,
    supported_paper_sizes: []const PaperSize,
    supported_media_types: []const []const u8,

    pub fn init() PrinterCapabilities {
        return .{
            .supports_color = true,
            .supports_duplex = false,
            .supports_collation = true,
            .supports_stapling = false,
            .supports_hole_punch = false,
            .max_copies = 999,
            .max_dpi = 600,
            .supported_paper_sizes = &[_]PaperSize{ .letter, .a4 },
            .supported_media_types = &[_][]const u8{ "Plain", "Photo" },
        };
    }
};

/// Printer information
pub const PrinterInfo = struct {
    id: []const u8,
    name: []const u8,
    model: []const u8,
    location: ?[]const u8,
    is_default: bool,
    is_network: bool,
    status: PrinterStatus,
    capabilities: PrinterCapabilities,

    pub fn isAvailable(self: PrinterInfo) bool {
        return self.status == .idle or self.status == .printing;
    }
};

/// Page range specification
pub const PageRange = struct {
    start: u32,
    end: u32,

    pub fn single(page: u32) PageRange {
        return .{ .start = page, .end = page };
    }

    pub fn all() PageRange {
        return .{ .start = 0, .end = std.math.maxInt(u32) };
    }

    pub fn count(self: PageRange) u32 {
        if (self.end < self.start) return 0;
        return self.end - self.start + 1;
    }

    pub fn contains(self: PageRange, page: u32) bool {
        return page >= self.start and page <= self.end;
    }

    pub fn format(self: PageRange, buffer: []u8) []const u8 {
        if (self.start == self.end) {
            return std.fmt.bufPrint(buffer, "{d}", .{self.start}) catch "?";
        } else if (self.end == std.math.maxInt(u32)) {
            return std.fmt.bufPrint(buffer, "{d}-", .{self.start}) catch "?";
        } else {
            return std.fmt.bufPrint(buffer, "{d}-{d}", .{ self.start, self.end }) catch "?";
        }
    }
};

/// Print settings
pub const PrintSettings = struct {
    paper_size: PaperSize,
    orientation: PageOrientation,
    quality: PrintQuality,
    color_mode: ColorMode,
    duplex: DuplexMode,
    margins: PageMargins,
    copies: u32,
    collate: bool,
    page_ranges: ?[]const PageRange,
    scale_to_fit: bool,
    scale_percent: u32, // 100 = 100%
    header: ?[]const u8,
    footer: ?[]const u8,

    const Self = @This();

    pub fn init() Self {
        return .{
            .paper_size = .letter,
            .orientation = .portrait,
            .quality = .normal,
            .color_mode = .auto,
            .duplex = .none,
            .margins = PageMargins.normal,
            .copies = 1,
            .collate = true,
            .page_ranges = null,
            .scale_to_fit = false,
            .scale_percent = 100,
            .header = null,
            .footer = null,
        };
    }

    pub fn getEffectiveDimensions(self: Self) PageDimensions {
        var dims = self.paper_size.getDimensions();
        if (self.orientation == .landscape) {
            dims = dims.landscape();
        }
        return dims;
    }

    pub fn getPrintableArea(self: Self) struct { width: u32, height: u32 } {
        const dims = self.getEffectiveDimensions();
        return .{
            .width = self.margins.getPrintableWidth(dims.width),
            .height = self.margins.getPrintableHeight(dims.height),
        };
    }
};

/// Print job information
pub const PrintJob = struct {
    id: u64,
    name: []const u8,
    printer_id: []const u8,
    status: PrintJobStatus,
    total_pages: u32,
    printed_pages: u32,
    copies: u32,
    created_at: i64,
    started_at: ?i64,
    completed_at: ?i64,
    error_message: ?[]const u8,
    settings: PrintSettings,

    const Self = @This();

    pub fn getProgress(self: Self) f32 {
        if (self.total_pages == 0) return 0;
        const total = self.total_pages * self.copies;
        return @as(f32, @floatFromInt(self.printed_pages)) / @as(f32, @floatFromInt(total));
    }

    pub fn getProgressPercent(self: Self) u8 {
        return @intFromFloat(self.getProgress() * 100);
    }

    pub fn isComplete(self: Self) bool {
        return self.status.isTerminal();
    }

    pub fn getRemainingPages(self: Self) u32 {
        const total = self.total_pages * self.copies;
        if (self.printed_pages >= total) return 0;
        return total - self.printed_pages;
    }
};

/// Print event types
pub const PrintEventType = enum {
    job_created,
    job_started,
    job_progress,
    job_completed,
    job_cancelled,
    job_failed,
    printer_status_changed,
    printer_added,
    printer_removed,
};

/// Print event
pub const PrintEvent = struct {
    event_type: PrintEventType,
    job_id: ?u64,
    printer_id: ?[]const u8,
    message: ?[]const u8,
    timestamp: i64,

    pub fn create(event_type: PrintEventType) PrintEvent {
        return .{
            .event_type = event_type,
            .job_id = null,
            .printer_id = null,
            .message = null,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn forJob(event_type: PrintEventType, job_id: u64) PrintEvent {
        return .{
            .event_type = event_type,
            .job_id = job_id,
            .printer_id = null,
            .message = null,
            .timestamp = getCurrentTimestamp(),
        };
    }
};

/// Print callback type
pub const PrintCallback = *const fn (event: PrintEvent) void;

/// Print manager for handling print operations
pub const PrintManager = struct {
    allocator: Allocator,
    printers: std.ArrayListUnmanaged(PrinterInfo),
    jobs: std.ArrayListUnmanaged(PrintJob),
    callbacks: std.ArrayListUnmanaged(PrintCallback),
    next_job_id: u64,
    default_printer_id: ?[]const u8,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .printers = .{},
            .jobs = .{},
            .callbacks = .{},
            .next_job_id = 1,
            .default_printer_id = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.printers.deinit(self.allocator);
        self.jobs.deinit(self.allocator);
        self.callbacks.deinit(self.allocator);
    }

    /// Add a callback for print events
    pub fn addCallback(self: *Self, callback: PrintCallback) !void {
        try self.callbacks.append(self.allocator, callback);
    }

    /// Remove a callback
    pub fn removeCallback(self: *Self, callback: PrintCallback) bool {
        for (self.callbacks.items, 0..) |cb, i| {
            if (cb == callback) {
                _ = self.callbacks.orderedRemove(i);
                return true;
            }
        }
        return false;
    }

    /// Register a printer
    pub fn registerPrinter(self: *Self, printer: PrinterInfo) !void {
        try self.printers.append(self.allocator, printer);
        if (printer.is_default) {
            self.default_printer_id = printer.id;
        }
        self.notifyCallbacks(PrintEvent{
            .event_type = .printer_added,
            .job_id = null,
            .printer_id = printer.id,
            .message = null,
            .timestamp = getCurrentTimestamp(),
        });
    }

    /// Get all available printers
    pub fn getPrinters(self: Self) []const PrinterInfo {
        return self.printers.items;
    }

    /// Get printer by ID
    pub fn getPrinter(self: Self, printer_id: []const u8) ?PrinterInfo {
        for (self.printers.items) |printer| {
            if (std.mem.eql(u8, printer.id, printer_id)) {
                return printer;
            }
        }
        return null;
    }

    /// Get default printer
    pub fn getDefaultPrinter(self: Self) ?PrinterInfo {
        if (self.default_printer_id) |id| {
            return self.getPrinter(id);
        }
        // Return first available printer
        for (self.printers.items) |printer| {
            if (printer.isAvailable()) {
                return printer;
            }
        }
        return null;
    }

    /// Create a print job
    pub fn createJob(self: *Self, name: []const u8, printer_id: []const u8, settings: PrintSettings, total_pages: u32) !PrintJob {
        const job = PrintJob{
            .id = self.next_job_id,
            .name = name,
            .printer_id = printer_id,
            .status = .pending,
            .total_pages = total_pages,
            .printed_pages = 0,
            .copies = settings.copies,
            .created_at = getCurrentTimestamp(),
            .started_at = null,
            .completed_at = null,
            .error_message = null,
            .settings = settings,
        };

        try self.jobs.append(self.allocator, job);
        self.next_job_id += 1;

        self.notifyCallbacks(PrintEvent.forJob(.job_created, job.id));

        return job;
    }

    /// Get job by ID
    pub fn getJob(self: Self, job_id: u64) ?PrintJob {
        for (self.jobs.items) |job| {
            if (job.id == job_id) {
                return job;
            }
        }
        return null;
    }

    /// Get all jobs
    pub fn getJobs(self: Self) []const PrintJob {
        return self.jobs.items;
    }

    /// Get active jobs
    pub fn getActiveJobs(self: Self, buffer: []PrintJob) []PrintJob {
        var count: usize = 0;
        for (self.jobs.items) |job| {
            if (job.status.isActive() and count < buffer.len) {
                buffer[count] = job;
                count += 1;
            }
        }
        return buffer[0..count];
    }

    /// Start a print job
    pub fn startJob(self: *Self, job_id: u64) bool {
        for (self.jobs.items) |*job| {
            if (job.id == job_id and job.status == .pending) {
                job.status = .queued;
                job.started_at = getCurrentTimestamp();
                self.notifyCallbacks(PrintEvent.forJob(.job_started, job_id));
                return true;
            }
        }
        return false;
    }

    /// Update job progress
    pub fn updateJobProgress(self: *Self, job_id: u64, printed_pages: u32) bool {
        for (self.jobs.items) |*job| {
            if (job.id == job_id) {
                job.printed_pages = printed_pages;
                if (job.status == .queued) {
                    job.status = .printing;
                }
                self.notifyCallbacks(PrintEvent.forJob(.job_progress, job_id));
                return true;
            }
        }
        return false;
    }

    /// Complete a print job
    pub fn completeJob(self: *Self, job_id: u64) bool {
        for (self.jobs.items) |*job| {
            if (job.id == job_id) {
                job.status = .completed;
                job.completed_at = getCurrentTimestamp();
                self.notifyCallbacks(PrintEvent.forJob(.job_completed, job_id));
                return true;
            }
        }
        return false;
    }

    /// Cancel a print job
    pub fn cancelJob(self: *Self, job_id: u64) bool {
        for (self.jobs.items) |*job| {
            if (job.id == job_id and job.status.isActive()) {
                job.status = .cancelled;
                job.completed_at = getCurrentTimestamp();
                self.notifyCallbacks(PrintEvent.forJob(.job_cancelled, job_id));
                return true;
            }
        }
        return false;
    }

    /// Fail a print job
    pub fn failJob(self: *Self, job_id: u64, error_message: []const u8) bool {
        for (self.jobs.items) |*job| {
            if (job.id == job_id) {
                job.status = .failed;
                job.completed_at = getCurrentTimestamp();
                job.error_message = error_message;
                self.notifyCallbacks(PrintEvent.forJob(.job_failed, job_id));
                return true;
            }
        }
        return false;
    }

    fn notifyCallbacks(self: *Self, event: PrintEvent) void {
        for (self.callbacks.items) |callback| {
            callback(event);
        }
    }
};

/// Print formatter for simple text documents
pub const TextPrintFormatter = struct {
    allocator: Allocator,
    lines: std.ArrayListUnmanaged([]const u8),
    font_size: u32,
    line_spacing: f32,
    settings: PrintSettings,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .lines = .{},
            .font_size = 12,
            .line_spacing = 1.5,
            .settings = PrintSettings.init(),
        };
    }

    pub fn deinit(self: *Self) void {
        self.lines.deinit(self.allocator);
    }

    pub fn addLine(self: *Self, line: []const u8) !void {
        try self.lines.append(self.allocator, line);
    }

    pub fn setFontSize(self: *Self, size: u32) void {
        self.font_size = size;
    }

    pub fn setLineSpacing(self: *Self, spacing: f32) void {
        self.line_spacing = spacing;
    }

    pub fn getLineCount(self: Self) usize {
        return self.lines.items.len;
    }

    /// Calculate number of pages needed
    pub fn calculatePageCount(self: Self) u32 {
        const printable = self.settings.getPrintableArea();
        const line_height: u32 = @intFromFloat(@as(f32, @floatFromInt(self.font_size)) * self.line_spacing);
        if (line_height == 0) return 1;

        const lines_per_page = printable.height / line_height;
        if (lines_per_page == 0) return 1;

        const total_lines: u32 = @intCast(self.lines.items.len);
        return (total_lines + lines_per_page - 1) / lines_per_page;
    }

    /// Get lines for a specific page (1-indexed)
    pub fn getLinesForPage(self: Self, page: u32, buffer: [][]const u8) [][]const u8 {
        const printable = self.settings.getPrintableArea();
        const line_height: u32 = @intFromFloat(@as(f32, @floatFromInt(self.font_size)) * self.line_spacing);
        if (line_height == 0) return buffer[0..0];

        const lines_per_page = printable.height / line_height;
        if (lines_per_page == 0) return buffer[0..0];

        const start_line = (page - 1) * lines_per_page;
        const end_line = @min(start_line + lines_per_page, @as(u32, @intCast(self.lines.items.len)));

        var count: usize = 0;
        var i = start_line;
        while (i < end_line and count < buffer.len) : (i += 1) {
            buffer[count] = self.lines.items[i];
            count += 1;
        }

        return buffer[0..count];
    }
};

/// Utility functions
pub fn pointsToInches(points: u32) f32 {
    return @as(f32, @floatFromInt(points)) / 72.0;
}

pub fn inchesToPoints(inches: f32) u32 {
    return @intFromFloat(inches * 72.0);
}

pub fn pointsToMM(points: u32) f32 {
    return @as(f32, @floatFromInt(points)) * 0.352778;
}

pub fn mmToPoints(mm: f32) u32 {
    return @intFromFloat(mm / 0.352778);
}

/// Parse page range string like "1-5,7,9-12"
pub fn parsePageRanges(input: []const u8, buffer: []PageRange) []PageRange {
    var count: usize = 0;
    var start: usize = 0;
    var i: usize = 0;

    while (i <= input.len and count < buffer.len) : (i += 1) {
        if (i == input.len or input[i] == ',') {
            if (i > start) {
                if (parsePageRange(input[start..i])) |range| {
                    buffer[count] = range;
                    count += 1;
                }
            }
            start = i + 1;
        }
    }

    return buffer[0..count];
}

fn parsePageRange(input: []const u8) ?PageRange {
    // Find the dash
    var dash_pos: ?usize = null;
    for (input, 0..) |c, i| {
        if (c == '-') {
            dash_pos = i;
            break;
        }
    }

    if (dash_pos) |pos| {
        const start_str = std.mem.trim(u8, input[0..pos], " ");
        const end_str = std.mem.trim(u8, input[pos + 1 ..], " ");

        const start = std.fmt.parseInt(u32, start_str, 10) catch return null;
        const end = if (end_str.len == 0)
            std.math.maxInt(u32)
        else
            std.fmt.parseInt(u32, end_str, 10) catch return null;

        return .{ .start = start, .end = end };
    } else {
        const page = std.fmt.parseInt(u32, std.mem.trim(u8, input, " "), 10) catch return null;
        return PageRange.single(page);
    }
}

/// Get current timestamp in milliseconds
fn getCurrentTimestamp() i64 {
    const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
    return @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000);
}

// ============================================================================
// Tests
// ============================================================================

test "PaperSize toString" {
    try std.testing.expectEqualStrings("Letter", PaperSize.letter.toString());
    try std.testing.expectEqualStrings("A4", PaperSize.a4.toString());
    try std.testing.expectEqualStrings("Legal", PaperSize.legal.toString());
}

test "PaperSize getDimensions" {
    const letter = PaperSize.letter.getDimensions();
    try std.testing.expectEqual(@as(u32, 612), letter.width);
    try std.testing.expectEqual(@as(u32, 792), letter.height);

    const a4 = PaperSize.a4.getDimensions();
    try std.testing.expectEqual(@as(u32, 595), a4.width);
    try std.testing.expectEqual(@as(u32, 842), a4.height);
}

test "PageDimensions landscape" {
    const portrait = PaperSize.letter.getDimensions();
    const landscape = portrait.landscape();

    try std.testing.expectEqual(portrait.height, landscape.width);
    try std.testing.expectEqual(portrait.width, landscape.height);
}

test "PageDimensions toInches" {
    const dims = PageDimensions{ .width = 612, .height = 792 };
    const inches = dims.toInches();

    try std.testing.expectApproxEqAbs(@as(f32, 8.5), inches.width, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 11.0), inches.height, 0.01);
}

test "PageOrientation toString" {
    try std.testing.expectEqualStrings("Portrait", PageOrientation.portrait.toString());
    try std.testing.expectEqualStrings("Landscape", PageOrientation.landscape.toString());
}

test "PrintQuality getDPI" {
    try std.testing.expectEqual(@as(u32, 150), PrintQuality.draft.getDPI());
    try std.testing.expectEqual(@as(u32, 300), PrintQuality.normal.getDPI());
    try std.testing.expectEqual(@as(u32, 600), PrintQuality.high.getDPI());
    try std.testing.expectEqual(@as(u32, 1200), PrintQuality.photo.getDPI());
}

test "ColorMode toString" {
    try std.testing.expectEqualStrings("Automatic", ColorMode.auto.toString());
    try std.testing.expectEqualStrings("Grayscale", ColorMode.grayscale.toString());
}

test "DuplexMode states" {
    try std.testing.expect(!DuplexMode.none.isTwoSided());
    try std.testing.expect(DuplexMode.long_edge.isTwoSided());
    try std.testing.expect(DuplexMode.short_edge.isTwoSided());
}

test "PageMargins getPrintableWidth" {
    const margins = PageMargins{ .top = 72, .bottom = 72, .left = 72, .right = 72 };
    const printable_width = margins.getPrintableWidth(612);
    try std.testing.expectEqual(@as(u32, 468), printable_width); // 612 - 144
}

test "PageMargins getPrintableHeight" {
    const margins = PageMargins.normal;
    const printable_height = margins.getPrintableHeight(792);
    try std.testing.expectEqual(@as(u32, 648), printable_height); // 792 - 144
}

test "PrintJobStatus states" {
    try std.testing.expect(PrintJobStatus.pending.isActive());
    try std.testing.expect(PrintJobStatus.printing.isActive());
    try std.testing.expect(!PrintJobStatus.completed.isActive());
    try std.testing.expect(!PrintJobStatus.cancelled.isActive());

    try std.testing.expect(PrintJobStatus.completed.isTerminal());
    try std.testing.expect(PrintJobStatus.failed.isTerminal());
    try std.testing.expect(!PrintJobStatus.printing.isTerminal());
}

test "PrinterStatus states" {
    try std.testing.expect(PrinterStatus.idle.isReady());
    try std.testing.expect(!PrinterStatus.offline.isReady());

    try std.testing.expect(PrinterStatus.paper_jam.requiresAttention());
    try std.testing.expect(PrinterStatus.paper_out.requiresAttention());
    try std.testing.expect(!PrinterStatus.idle.requiresAttention());
}

test "PageRange single" {
    const range = PageRange.single(5);
    try std.testing.expectEqual(@as(u32, 5), range.start);
    try std.testing.expectEqual(@as(u32, 5), range.end);
    try std.testing.expectEqual(@as(u32, 1), range.count());
}

test "PageRange contains" {
    const range = PageRange{ .start = 3, .end = 7 };
    try std.testing.expect(range.contains(3));
    try std.testing.expect(range.contains(5));
    try std.testing.expect(range.contains(7));
    try std.testing.expect(!range.contains(2));
    try std.testing.expect(!range.contains(8));
}

test "PageRange format" {
    var buffer: [32]u8 = undefined;

    const single = PageRange.single(5);
    try std.testing.expectEqualStrings("5", single.format(&buffer));

    const range = PageRange{ .start = 1, .end = 10 };
    try std.testing.expectEqualStrings("1-10", range.format(&buffer));
}

test "PrintSettings init" {
    const settings = PrintSettings.init();
    try std.testing.expectEqual(PaperSize.letter, settings.paper_size);
    try std.testing.expectEqual(PageOrientation.portrait, settings.orientation);
    try std.testing.expectEqual(PrintQuality.normal, settings.quality);
    try std.testing.expectEqual(@as(u32, 1), settings.copies);
}

test "PrintSettings getEffectiveDimensions" {
    var settings = PrintSettings.init();
    settings.paper_size = .a4;

    const portrait = settings.getEffectiveDimensions();
    try std.testing.expectEqual(@as(u32, 595), portrait.width);
    try std.testing.expectEqual(@as(u32, 842), portrait.height);

    settings.orientation = .landscape;
    const landscape = settings.getEffectiveDimensions();
    try std.testing.expectEqual(@as(u32, 842), landscape.width);
    try std.testing.expectEqual(@as(u32, 595), landscape.height);
}

test "PrintSettings getPrintableArea" {
    var settings = PrintSettings.init();
    settings.margins = PageMargins.normal;

    const area = settings.getPrintableArea();
    try std.testing.expect(area.width > 0);
    try std.testing.expect(area.height > 0);
}

test "PrintJob getProgress" {
    const job = PrintJob{
        .id = 1,
        .name = "Test Job",
        .printer_id = "printer1",
        .status = .printing,
        .total_pages = 10,
        .printed_pages = 5,
        .copies = 1,
        .created_at = 0,
        .started_at = 0,
        .completed_at = null,
        .error_message = null,
        .settings = PrintSettings.init(),
    };

    try std.testing.expectApproxEqAbs(@as(f32, 0.5), job.getProgress(), 0.01);
    try std.testing.expectEqual(@as(u8, 50), job.getProgressPercent());
}

test "PrintJob getRemainingPages" {
    var job = PrintJob{
        .id = 1,
        .name = "Test Job",
        .printer_id = "printer1",
        .status = .printing,
        .total_pages = 10,
        .printed_pages = 3,
        .copies = 2,
        .created_at = 0,
        .started_at = 0,
        .completed_at = null,
        .error_message = null,
        .settings = PrintSettings.init(),
    };

    // Total pages = 10 * 2 copies = 20, printed = 3, remaining = 17
    try std.testing.expectEqual(@as(u32, 17), job.getRemainingPages());

    job.printed_pages = 20;
    try std.testing.expectEqual(@as(u32, 0), job.getRemainingPages());
}

test "PrintManager initialization" {
    const allocator = std.testing.allocator;
    var manager = PrintManager.init(allocator);
    defer manager.deinit();

    try std.testing.expectEqual(@as(usize, 0), manager.printers.items.len);
    try std.testing.expectEqual(@as(usize, 0), manager.jobs.items.len);
}

test "PrintManager registerPrinter" {
    const allocator = std.testing.allocator;
    var manager = PrintManager.init(allocator);
    defer manager.deinit();

    const printer = PrinterInfo{
        .id = "printer1",
        .name = "Test Printer",
        .model = "HP LaserJet",
        .location = "Office",
        .is_default = true,
        .is_network = true,
        .status = .idle,
        .capabilities = PrinterCapabilities.init(),
    };

    try manager.registerPrinter(printer);
    try std.testing.expectEqual(@as(usize, 1), manager.printers.items.len);

    const default = manager.getDefaultPrinter();
    try std.testing.expect(default != null);
    try std.testing.expectEqualStrings("printer1", default.?.id);
}

test "PrintManager createJob" {
    const allocator = std.testing.allocator;
    var manager = PrintManager.init(allocator);
    defer manager.deinit();

    const settings = PrintSettings.init();
    const job = try manager.createJob("Test Document", "printer1", settings, 5);

    try std.testing.expectEqual(@as(u64, 1), job.id);
    try std.testing.expectEqualStrings("Test Document", job.name);
    try std.testing.expectEqual(PrintJobStatus.pending, job.status);
    try std.testing.expectEqual(@as(u32, 5), job.total_pages);
}

test "PrintManager job lifecycle" {
    const allocator = std.testing.allocator;
    var manager = PrintManager.init(allocator);
    defer manager.deinit();

    const settings = PrintSettings.init();
    const job = try manager.createJob("Test", "printer1", settings, 3);

    try std.testing.expect(manager.startJob(job.id));

    const started_job = manager.getJob(job.id);
    try std.testing.expect(started_job != null);
    try std.testing.expectEqual(PrintJobStatus.queued, started_job.?.status);

    try std.testing.expect(manager.updateJobProgress(job.id, 2));
    try std.testing.expect(manager.completeJob(job.id));

    const completed_job = manager.getJob(job.id);
    try std.testing.expectEqual(PrintJobStatus.completed, completed_job.?.status);
}

test "PrintManager cancelJob" {
    const allocator = std.testing.allocator;
    var manager = PrintManager.init(allocator);
    defer manager.deinit();

    const settings = PrintSettings.init();
    const job = try manager.createJob("Test", "printer1", settings, 3);

    try std.testing.expect(manager.startJob(job.id));
    try std.testing.expect(manager.cancelJob(job.id));

    const cancelled_job = manager.getJob(job.id);
    try std.testing.expectEqual(PrintJobStatus.cancelled, cancelled_job.?.status);
}

test "TextPrintFormatter basic" {
    const allocator = std.testing.allocator;
    var formatter = TextPrintFormatter.init(allocator);
    defer formatter.deinit();

    try formatter.addLine("Line 1");
    try formatter.addLine("Line 2");
    try formatter.addLine("Line 3");

    try std.testing.expectEqual(@as(usize, 3), formatter.getLineCount());
}

test "TextPrintFormatter calculatePageCount" {
    const allocator = std.testing.allocator;
    var formatter = TextPrintFormatter.init(allocator);
    defer formatter.deinit();

    formatter.font_size = 12;
    formatter.line_spacing = 1.5;

    // Add 100 lines
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        try formatter.addLine("Test line");
    }

    const pages = formatter.calculatePageCount();
    try std.testing.expect(pages > 1);
}

test "pointsToInches" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), pointsToInches(72), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 8.5), pointsToInches(612), 0.01);
}

test "inchesToPoints" {
    try std.testing.expectEqual(@as(u32, 72), inchesToPoints(1.0));
    try std.testing.expectEqual(@as(u32, 612), inchesToPoints(8.5));
}

test "pointsToMM" {
    // 72 points = 1 inch = 25.4mm
    try std.testing.expectApproxEqAbs(@as(f32, 25.4), pointsToMM(72), 0.1);
}

test "mmToPoints" {
    // 25.4mm = 1 inch = 72 points (allow for rounding)
    const result = mmToPoints(25.4);
    try std.testing.expect(result >= 71 and result <= 72);
}

test "parsePageRanges" {
    var buffer: [10]PageRange = undefined;

    const ranges = parsePageRanges("1-5,7,9-12", &buffer);
    try std.testing.expectEqual(@as(usize, 3), ranges.len);

    try std.testing.expectEqual(@as(u32, 1), ranges[0].start);
    try std.testing.expectEqual(@as(u32, 5), ranges[0].end);

    try std.testing.expectEqual(@as(u32, 7), ranges[1].start);
    try std.testing.expectEqual(@as(u32, 7), ranges[1].end);

    try std.testing.expectEqual(@as(u32, 9), ranges[2].start);
    try std.testing.expectEqual(@as(u32, 12), ranges[2].end);
}

test "parsePageRanges open ended" {
    var buffer: [10]PageRange = undefined;

    const ranges = parsePageRanges("5-", &buffer);
    try std.testing.expectEqual(@as(usize, 1), ranges.len);
    try std.testing.expectEqual(@as(u32, 5), ranges[0].start);
    try std.testing.expectEqual(std.math.maxInt(u32), ranges[0].end);
}

test "PrinterInfo isAvailable" {
    const printer = PrinterInfo{
        .id = "test",
        .name = "Test",
        .model = "Model",
        .location = null,
        .is_default = false,
        .is_network = false,
        .status = .idle,
        .capabilities = PrinterCapabilities.init(),
    };

    try std.testing.expect(printer.isAvailable());

    const offline_printer = PrinterInfo{
        .id = "test2",
        .name = "Test 2",
        .model = "Model",
        .location = null,
        .is_default = false,
        .is_network = false,
        .status = .offline,
        .capabilities = PrinterCapabilities.init(),
    };

    try std.testing.expect(!offline_printer.isAvailable());
}

test "PrinterCapabilities init" {
    const caps = PrinterCapabilities.init();
    try std.testing.expect(caps.supports_color);
    try std.testing.expect(!caps.supports_duplex);
    try std.testing.expectEqual(@as(u32, 999), caps.max_copies);
}

test "PrintEvent create" {
    const event = PrintEvent.create(.job_created);
    try std.testing.expectEqual(PrintEventType.job_created, event.event_type);
    try std.testing.expect(event.job_id == null);
}

test "PrintEvent forJob" {
    const event = PrintEvent.forJob(.job_started, 42);
    try std.testing.expectEqual(PrintEventType.job_started, event.event_type);
    try std.testing.expectEqual(@as(u64, 42), event.job_id.?);
}
