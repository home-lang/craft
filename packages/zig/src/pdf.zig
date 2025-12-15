//! Cross-platform PDF generation and manipulation module for Craft
//! Provides PDF creation, reading, and manipulation capabilities
//! for iOS, Android, macOS, Windows, and Linux.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// PDF version
pub const PDFVersion = enum {
    v1_0,
    v1_1,
    v1_2,
    v1_3,
    v1_4, // Acrobat 5
    v1_5, // Acrobat 6
    v1_6, // Acrobat 7
    v1_7, // Acrobat 8+
    v2_0, // ISO 32000-2

    pub fn toString(self: PDFVersion) []const u8 {
        return switch (self) {
            .v1_0 => "1.0",
            .v1_1 => "1.1",
            .v1_2 => "1.2",
            .v1_3 => "1.3",
            .v1_4 => "1.4",
            .v1_5 => "1.5",
            .v1_6 => "1.6",
            .v1_7 => "1.7",
            .v2_0 => "2.0",
        };
    }

    pub fn header(self: PDFVersion) []const u8 {
        return switch (self) {
            .v1_0 => "%PDF-1.0",
            .v1_1 => "%PDF-1.1",
            .v1_2 => "%PDF-1.2",
            .v1_3 => "%PDF-1.3",
            .v1_4 => "%PDF-1.4",
            .v1_5 => "%PDF-1.5",
            .v1_6 => "%PDF-1.6",
            .v1_7 => "%PDF-1.7",
            .v2_0 => "%PDF-2.0",
        };
    }
};

/// Page size in points (72 points = 1 inch)
pub const PageSize = struct {
    width: f32,
    height: f32,

    pub const letter: PageSize = .{ .width = 612, .height = 792 };
    pub const legal: PageSize = .{ .width = 612, .height = 1008 };
    pub const tabloid: PageSize = .{ .width = 792, .height = 1224 };
    pub const a0: PageSize = .{ .width = 2384, .height = 3370 };
    pub const a1: PageSize = .{ .width = 1684, .height = 2384 };
    pub const a2: PageSize = .{ .width = 1191, .height = 1684 };
    pub const a3: PageSize = .{ .width = 842, .height = 1191 };
    pub const a4: PageSize = .{ .width = 595, .height = 842 };
    pub const a5: PageSize = .{ .width = 420, .height = 595 };
    pub const a6: PageSize = .{ .width = 298, .height = 420 };
    pub const b4: PageSize = .{ .width = 729, .height = 1032 };
    pub const b5: PageSize = .{ .width = 516, .height = 729 };

    pub fn landscape(self: PageSize) PageSize {
        return .{ .width = self.height, .height = self.width };
    }

    pub fn toInches(self: PageSize) struct { width: f32, height: f32 } {
        return .{
            .width = self.width / 72.0,
            .height = self.height / 72.0,
        };
    }

    pub fn toMM(self: PageSize) struct { width: f32, height: f32 } {
        return .{
            .width = self.width * 0.352778,
            .height = self.height * 0.352778,
        };
    }

    pub fn custom(width_inches: f32, height_inches: f32) PageSize {
        return .{
            .width = width_inches * 72.0,
            .height = height_inches * 72.0,
        };
    }

    pub fn customMM(width_mm: f32, height_mm: f32) PageSize {
        return .{
            .width = width_mm / 0.352778,
            .height = height_mm / 0.352778,
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

/// Color space
pub const ColorSpace = enum {
    device_gray,
    device_rgb,
    device_cmyk,

    pub fn toString(self: ColorSpace) []const u8 {
        return switch (self) {
            .device_gray => "DeviceGray",
            .device_rgb => "DeviceRGB",
            .device_cmyk => "DeviceCMYK",
        };
    }

    pub fn componentCount(self: ColorSpace) u8 {
        return switch (self) {
            .device_gray => 1,
            .device_rgb => 3,
            .device_cmyk => 4,
        };
    }
};

/// PDF color representation
pub const PDFColor = struct {
    r: f32, // Red (0-1) or Cyan in CMYK
    g: f32, // Green (0-1) or Magenta in CMYK
    b: f32, // Blue (0-1) or Yellow in CMYK
    k: f32, // Black in CMYK (unused for RGB)
    space: ColorSpace,

    pub const black: PDFColor = .{ .r = 0, .g = 0, .b = 0, .k = 0, .space = .device_rgb };
    pub const white: PDFColor = .{ .r = 1, .g = 1, .b = 1, .k = 0, .space = .device_rgb };
    pub const red: PDFColor = .{ .r = 1, .g = 0, .b = 0, .k = 0, .space = .device_rgb };
    pub const green: PDFColor = .{ .r = 0, .g = 1, .b = 0, .k = 0, .space = .device_rgb };
    pub const blue: PDFColor = .{ .r = 0, .g = 0, .b = 1, .k = 0, .space = .device_rgb };

    pub fn rgb(r: f32, g: f32, b: f32) PDFColor {
        return .{
            .r = std.math.clamp(r, 0, 1),
            .g = std.math.clamp(g, 0, 1),
            .b = std.math.clamp(b, 0, 1),
            .k = 0,
            .space = .device_rgb,
        };
    }

    pub fn gray(value: f32) PDFColor {
        const v = std.math.clamp(value, 0, 1);
        return .{ .r = v, .g = v, .b = v, .k = 0, .space = .device_gray };
    }

    pub fn cmyk(c: f32, m: f32, y: f32, k: f32) PDFColor {
        return .{
            .r = std.math.clamp(c, 0, 1),
            .g = std.math.clamp(m, 0, 1),
            .b = std.math.clamp(y, 0, 1),
            .k = std.math.clamp(k, 0, 1),
            .space = .device_cmyk,
        };
    }

    pub fn fromHex(hex: u32) PDFColor {
        const r = @as(f32, @floatFromInt((hex >> 16) & 0xFF)) / 255.0;
        const g = @as(f32, @floatFromInt((hex >> 8) & 0xFF)) / 255.0;
        const b = @as(f32, @floatFromInt(hex & 0xFF)) / 255.0;
        return rgb(r, g, b);
    }

    pub fn toHex(self: PDFColor) u32 {
        const r: u32 = @intFromFloat(self.r * 255.0);
        const g: u32 = @intFromFloat(self.g * 255.0);
        const b_val: u32 = @intFromFloat(self.b * 255.0);
        return (r << 16) | (g << 8) | b_val;
    }
};

/// Font style
pub const FontStyle = enum {
    normal,
    bold,
    italic,
    bold_italic,

    pub fn toString(self: FontStyle) []const u8 {
        return switch (self) {
            .normal => "Normal",
            .bold => "Bold",
            .italic => "Italic",
            .bold_italic => "Bold Italic",
        };
    }

    pub fn isBold(self: FontStyle) bool {
        return self == .bold or self == .bold_italic;
    }

    pub fn isItalic(self: FontStyle) bool {
        return self == .italic or self == .bold_italic;
    }
};

/// Standard PDF fonts
pub const StandardFont = enum {
    helvetica,
    helvetica_bold,
    helvetica_oblique,
    helvetica_bold_oblique,
    times_roman,
    times_bold,
    times_italic,
    times_bold_italic,
    courier,
    courier_bold,
    courier_oblique,
    courier_bold_oblique,
    symbol,
    zapf_dingbats,

    pub fn name(self: StandardFont) []const u8 {
        return switch (self) {
            .helvetica => "Helvetica",
            .helvetica_bold => "Helvetica-Bold",
            .helvetica_oblique => "Helvetica-Oblique",
            .helvetica_bold_oblique => "Helvetica-BoldOblique",
            .times_roman => "Times-Roman",
            .times_bold => "Times-Bold",
            .times_italic => "Times-Italic",
            .times_bold_italic => "Times-BoldItalic",
            .courier => "Courier",
            .courier_bold => "Courier-Bold",
            .courier_oblique => "Courier-Oblique",
            .courier_bold_oblique => "Courier-BoldOblique",
            .symbol => "Symbol",
            .zapf_dingbats => "ZapfDingbats",
        };
    }

    pub fn isMonospace(self: StandardFont) bool {
        return switch (self) {
            .courier, .courier_bold, .courier_oblique, .courier_bold_oblique => true,
            else => false,
        };
    }

    pub fn isSerif(self: StandardFont) bool {
        return switch (self) {
            .times_roman, .times_bold, .times_italic, .times_bold_italic => true,
            else => false,
        };
    }
};

/// PDF font reference
pub const PDFFont = struct {
    id: u32,
    name: []const u8,
    standard_font: ?StandardFont,
    size: f32,
    style: FontStyle,

    pub fn standard(font: StandardFont, size: f32) PDFFont {
        return .{
            .id = 0,
            .name = font.name(),
            .standard_font = font,
            .size = size,
            .style = .normal,
        };
    }

    pub fn custom(id: u32, name_str: []const u8, size: f32, style: FontStyle) PDFFont {
        return .{
            .id = id,
            .name = name_str,
            .standard_font = null,
            .size = size,
            .style = style,
        };
    }
};

/// Text alignment
pub const TextAlign = enum {
    left,
    center,
    right,
    justify,

    pub fn toString(self: TextAlign) []const u8 {
        return switch (self) {
            .left => "Left",
            .center => "Center",
            .right => "Right",
            .justify => "Justify",
        };
    }
};

/// Line cap style
pub const LineCap = enum {
    butt,
    round,
    square,

    pub fn value(self: LineCap) u8 {
        return switch (self) {
            .butt => 0,
            .round => 1,
            .square => 2,
        };
    }
};

/// Line join style
pub const LineJoin = enum {
    miter,
    round,
    bevel,

    pub fn value(self: LineJoin) u8 {
        return switch (self) {
            .miter => 0,
            .round => 1,
            .bevel => 2,
        };
    }
};

/// Point in 2D space
pub const Point = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) Point {
        return .{ .x = x, .y = y };
    }

    pub fn add(self: Point, other: Point) Point {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    pub fn subtract(self: Point, other: Point) Point {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }

    pub fn scale(self: Point, factor: f32) Point {
        return .{ .x = self.x * factor, .y = self.y * factor };
    }
};

/// Rectangle
pub const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    pub fn init(x: f32, y: f32, width: f32, height: f32) Rect {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }

    pub fn origin(self: Rect) Point {
        return .{ .x = self.x, .y = self.y };
    }

    pub fn size(self: Rect) struct { width: f32, height: f32 } {
        return .{ .width = self.width, .height = self.height };
    }

    pub fn center(self: Rect) Point {
        return .{
            .x = self.x + self.width / 2,
            .y = self.y + self.height / 2,
        };
    }

    pub fn contains(self: Rect, point: Point) bool {
        return point.x >= self.x and
            point.x <= self.x + self.width and
            point.y >= self.y and
            point.y <= self.y + self.height;
    }

    pub fn intersects(self: Rect, other: Rect) bool {
        return !(other.x > self.x + self.width or
            other.x + other.width < self.x or
            other.y > self.y + self.height or
            other.y + other.height < self.y);
    }

    pub fn inset(self: Rect, dx: f32, dy: f32) Rect {
        return .{
            .x = self.x + dx,
            .y = self.y + dy,
            .width = @max(0, self.width - 2 * dx),
            .height = @max(0, self.height - 2 * dy),
        };
    }
};

/// Graphics state
pub const GraphicsState = struct {
    fill_color: PDFColor,
    stroke_color: PDFColor,
    line_width: f32,
    line_cap: LineCap,
    line_join: LineJoin,
    miter_limit: f32,
    font: ?PDFFont,
    transform: [6]f32, // Affine transformation matrix [a, b, c, d, e, f]

    pub fn init() GraphicsState {
        return .{
            .fill_color = PDFColor.black,
            .stroke_color = PDFColor.black,
            .line_width = 1.0,
            .line_cap = .butt,
            .line_join = .miter,
            .miter_limit = 10.0,
            .font = null,
            .transform = .{ 1, 0, 0, 1, 0, 0 }, // Identity matrix
        };
    }
};

/// PDF page
pub const PDFPage = struct {
    index: u32,
    size: PageSize,
    orientation: PageOrientation,
    content_stream: std.ArrayListUnmanaged(u8),
    state_stack: std.ArrayListUnmanaged(GraphicsState),
    current_state: GraphicsState,
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, size: PageSize, orientation: PageOrientation) Self {
        const effective_size = if (orientation == .landscape) size.landscape() else size;
        return .{
            .index = 0,
            .size = effective_size,
            .orientation = orientation,
            .content_stream = .{},
            .state_stack = .{},
            .current_state = GraphicsState.init(),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.content_stream.deinit(self.allocator);
        self.state_stack.deinit(self.allocator);
    }

    pub fn getSize(self: Self) PageSize {
        return self.size;
    }

    /// Save graphics state
    pub fn saveState(self: *Self) !void {
        try self.state_stack.append(self.allocator, self.current_state);
        try self.writeOperator("q");
    }

    /// Restore graphics state
    pub fn restoreState(self: *Self) !void {
        if (self.state_stack.items.len > 0) {
            self.current_state = self.state_stack.pop();
            try self.writeOperator("Q");
        }
    }

    /// Set fill color
    pub fn setFillColor(self: *Self, color: PDFColor) !void {
        self.current_state.fill_color = color;
        switch (color.space) {
            .device_gray => try self.writeFloat3Op(color.r, 0, 0, "g"),
            .device_rgb => try self.writeFloat3Op(color.r, color.g, color.b, "rg"),
            .device_cmyk => try self.writeFloat4Op(color.r, color.g, color.b, color.k, "k"),
        }
    }

    /// Set stroke color
    pub fn setStrokeColor(self: *Self, color: PDFColor) !void {
        self.current_state.stroke_color = color;
        switch (color.space) {
            .device_gray => try self.writeFloat3Op(color.r, 0, 0, "G"),
            .device_rgb => try self.writeFloat3Op(color.r, color.g, color.b, "RG"),
            .device_cmyk => try self.writeFloat4Op(color.r, color.g, color.b, color.k, "K"),
        }
    }

    /// Set line width
    pub fn setLineWidth(self: *Self, width: f32) !void {
        self.current_state.line_width = width;
        try self.writeFloatOp(width, "w");
    }

    /// Set line cap
    pub fn setLineCap(self: *Self, cap: LineCap) !void {
        self.current_state.line_cap = cap;
        try self.writeIntOp(cap.value(), "J");
    }

    /// Set line join
    pub fn setLineJoin(self: *Self, join: LineJoin) !void {
        self.current_state.line_join = join;
        try self.writeIntOp(join.value(), "j");
    }

    /// Move to point
    pub fn moveTo(self: *Self, x: f32, y: f32) !void {
        try self.writeFloat2Op(x, y, "m");
    }

    /// Line to point
    pub fn lineTo(self: *Self, x: f32, y: f32) !void {
        try self.writeFloat2Op(x, y, "l");
    }

    /// Bezier curve to point
    pub fn curveTo(self: *Self, x1: f32, y1: f32, x2: f32, y2: f32, x3: f32, y3: f32) !void {
        try self.writeFloat6Op(x1, y1, x2, y2, x3, y3, "c");
    }

    /// Close path
    pub fn closePath(self: *Self) !void {
        try self.writeOperator("h");
    }

    /// Stroke path
    pub fn stroke(self: *Self) !void {
        try self.writeOperator("S");
    }

    /// Fill path
    pub fn fill(self: *Self) !void {
        try self.writeOperator("f");
    }

    /// Fill and stroke path
    pub fn fillStroke(self: *Self) !void {
        try self.writeOperator("B");
    }

    /// Draw rectangle
    pub fn drawRect(self: *Self, rect: Rect) !void {
        try self.writeFloat4Op(rect.x, rect.y, rect.width, rect.height, "re");
    }

    /// Draw filled rectangle
    pub fn fillRect(self: *Self, rect: Rect, color: PDFColor) !void {
        try self.saveState();
        try self.setFillColor(color);
        try self.drawRect(rect);
        try self.fill();
        try self.restoreState();
    }

    /// Draw stroked rectangle
    pub fn strokeRect(self: *Self, rect: Rect, color: PDFColor, line_width: f32) !void {
        try self.saveState();
        try self.setStrokeColor(color);
        try self.setLineWidth(line_width);
        try self.drawRect(rect);
        try self.stroke();
        try self.restoreState();
    }

    /// Draw line
    pub fn drawLine(self: *Self, x1: f32, y1: f32, x2: f32, y2: f32) !void {
        try self.moveTo(x1, y1);
        try self.lineTo(x2, y2);
        try self.stroke();
    }

    /// Draw circle (approximated with bezier curves)
    pub fn drawCircle(self: *Self, cx: f32, cy: f32, radius: f32) !void {
        const k: f32 = 0.552284749831; // Magic number for circle approximation
        const r = radius;
        const kr = k * r;

        try self.moveTo(cx + r, cy);
        try self.curveTo(cx + r, cy + kr, cx + kr, cy + r, cx, cy + r);
        try self.curveTo(cx - kr, cy + r, cx - r, cy + kr, cx - r, cy);
        try self.curveTo(cx - r, cy - kr, cx - kr, cy - r, cx, cy - r);
        try self.curveTo(cx + kr, cy - r, cx + r, cy - kr, cx + r, cy);
        try self.closePath();
    }

    /// Set font
    pub fn setFont(self: *Self, font: PDFFont) !void {
        self.current_state.font = font;
        var buf: [64]u8 = undefined;
        const cmd = std.fmt.bufPrint(&buf, "/F{d} {d:.2} Tf", .{ font.id, font.size }) catch return error.BufferTooSmall;
        try self.content_stream.appendSlice(self.allocator, cmd);
        try self.content_stream.appendSlice(self.allocator, "\n");
    }

    /// Begin text block
    pub fn beginText(self: *Self) !void {
        try self.writeOperator("BT");
    }

    /// End text block
    pub fn endText(self: *Self) !void {
        try self.writeOperator("ET");
    }

    /// Set text position
    pub fn setTextPosition(self: *Self, x: f32, y: f32) !void {
        try self.writeFloat2Op(x, y, "Td");
    }

    /// Show text
    pub fn showText(self: *Self, text: []const u8) !void {
        try self.content_stream.appendSlice(self.allocator, "(");
        // Escape special characters
        for (text) |c| {
            switch (c) {
                '(', ')', '\\' => {
                    try self.content_stream.append(self.allocator, '\\');
                    try self.content_stream.append(self.allocator, c);
                },
                else => try self.content_stream.append(self.allocator, c),
            }
        }
        try self.content_stream.appendSlice(self.allocator, ") Tj\n");
    }

    /// Draw text at position
    pub fn drawText(self: *Self, text: []const u8, x: f32, y: f32) !void {
        try self.beginText();
        try self.setTextPosition(x, y);
        try self.showText(text);
        try self.endText();
    }

    /// Set text leading (line spacing)
    pub fn setTextLeading(self: *Self, leading: f32) !void {
        try self.writeFloatOp(leading, "TL");
    }

    /// Move to next line
    pub fn nextLine(self: *Self) !void {
        try self.writeOperator("T*");
    }

    // Internal helper functions

    fn writeOperator(self: *Self, op: []const u8) !void {
        try self.content_stream.appendSlice(self.allocator, op);
        try self.content_stream.appendSlice(self.allocator, "\n");
    }

    fn writeFloatOp(self: *Self, val: f32, op: []const u8) !void {
        var buf: [32]u8 = undefined;
        const formatted = std.fmt.bufPrint(&buf, "{d:.4} {s}\n", .{ val, op }) catch return error.BufferTooSmall;
        try self.content_stream.appendSlice(self.allocator, formatted);
    }

    fn writeIntOp(self: *Self, val: u8, op: []const u8) !void {
        var buf: [32]u8 = undefined;
        const formatted = std.fmt.bufPrint(&buf, "{d} {s}\n", .{ val, op }) catch return error.BufferTooSmall;
        try self.content_stream.appendSlice(self.allocator, formatted);
    }

    fn writeFloat2Op(self: *Self, a: f32, b: f32, op: []const u8) !void {
        var buf: [64]u8 = undefined;
        const formatted = std.fmt.bufPrint(&buf, "{d:.4} {d:.4} {s}\n", .{ a, b, op }) catch return error.BufferTooSmall;
        try self.content_stream.appendSlice(self.allocator, formatted);
    }

    fn writeFloat3Op(self: *Self, a: f32, b: f32, c: f32, op: []const u8) !void {
        var buf: [96]u8 = undefined;
        const formatted = std.fmt.bufPrint(&buf, "{d:.4} {d:.4} {d:.4} {s}\n", .{ a, b, c, op }) catch return error.BufferTooSmall;
        try self.content_stream.appendSlice(self.allocator, formatted);
    }

    fn writeFloat4Op(self: *Self, a: f32, b: f32, c: f32, d: f32, op: []const u8) !void {
        var buf: [128]u8 = undefined;
        const formatted = std.fmt.bufPrint(&buf, "{d:.4} {d:.4} {d:.4} {d:.4} {s}\n", .{ a, b, c, d, op }) catch return error.BufferTooSmall;
        try self.content_stream.appendSlice(self.allocator, formatted);
    }

    fn writeFloat6Op(self: *Self, a: f32, b: f32, c: f32, d: f32, e: f32, f_val: f32, op: []const u8) !void {
        var buf: [192]u8 = undefined;
        const formatted = std.fmt.bufPrint(&buf, "{d:.4} {d:.4} {d:.4} {d:.4} {d:.4} {d:.4} {s}\n", .{ a, b, c, d, e, f_val, op }) catch return error.BufferTooSmall;
        try self.content_stream.appendSlice(self.allocator, formatted);
    }

    pub fn getContentLength(self: Self) usize {
        return self.content_stream.items.len;
    }
};

/// PDF document metadata
pub const PDFMetadata = struct {
    title: ?[]const u8,
    author: ?[]const u8,
    subject: ?[]const u8,
    keywords: ?[]const u8,
    creator: ?[]const u8,
    producer: ?[]const u8,
    creation_date: ?i64,
    modification_date: ?i64,

    pub fn init() PDFMetadata {
        return .{
            .title = null,
            .author = null,
            .subject = null,
            .keywords = null,
            .creator = "Craft PDF Module",
            .producer = "Craft Framework",
            .creation_date = null,
            .modification_date = null,
        };
    }
};

/// PDF document
pub const PDFDocument = struct {
    allocator: Allocator,
    version: PDFVersion,
    metadata: PDFMetadata,
    pages: std.ArrayListUnmanaged(PDFPage),
    fonts: std.ArrayListUnmanaged(PDFFont),
    next_font_id: u32,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .version = .v1_7,
            .metadata = PDFMetadata.init(),
            .pages = .{},
            .fonts = .{},
            .next_font_id = 1,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.pages.items) |*page| {
            page.deinit();
        }
        self.pages.deinit(self.allocator);
        self.fonts.deinit(self.allocator);
    }

    /// Set PDF version
    pub fn setVersion(self: *Self, version: PDFVersion) void {
        self.version = version;
    }

    /// Set document title
    pub fn setTitle(self: *Self, title: []const u8) void {
        self.metadata.title = title;
    }

    /// Set document author
    pub fn setAuthor(self: *Self, author: []const u8) void {
        self.metadata.author = author;
    }

    /// Set document subject
    pub fn setSubject(self: *Self, subject: []const u8) void {
        self.metadata.subject = subject;
    }

    /// Set document keywords
    pub fn setKeywords(self: *Self, keywords: []const u8) void {
        self.metadata.keywords = keywords;
    }

    /// Add a new page
    pub fn addPage(self: *Self, size: PageSize, orientation: PageOrientation) !*PDFPage {
        var page = PDFPage.init(self.allocator, size, orientation);
        page.index = @intCast(self.pages.items.len);
        try self.pages.append(self.allocator, page);
        return &self.pages.items[self.pages.items.len - 1];
    }

    /// Add a standard page (letter, portrait)
    pub fn addStandardPage(self: *Self) !*PDFPage {
        return self.addPage(PageSize.letter, .portrait);
    }

    /// Get page count
    pub fn getPageCount(self: Self) usize {
        return self.pages.items.len;
    }

    /// Get page by index
    pub fn getPage(self: *Self, index: usize) ?*PDFPage {
        if (index < self.pages.items.len) {
            return &self.pages.items[index];
        }
        return null;
    }

    /// Add a standard font
    pub fn addStandardFont(self: *Self, font: StandardFont, size: f32) !PDFFont {
        const pdf_font = PDFFont{
            .id = self.next_font_id,
            .name = font.name(),
            .standard_font = font,
            .size = size,
            .style = .normal,
        };
        try self.fonts.append(self.allocator, pdf_font);
        self.next_font_id += 1;
        return pdf_font;
    }

    /// Get total content size across all pages
    pub fn getTotalContentSize(self: Self) usize {
        var total: usize = 0;
        for (self.pages.items) |page| {
            total += page.getContentLength();
        }
        return total;
    }
};

/// PDF builder for fluent API
pub const PDFBuilder = struct {
    document: PDFDocument,
    current_page: ?*PDFPage,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .document = PDFDocument.init(allocator),
            .current_page = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.document.deinit();
    }

    pub fn title(self: *Self, title_str: []const u8) *Self {
        self.document.setTitle(title_str);
        return self;
    }

    pub fn author(self: *Self, author_str: []const u8) *Self {
        self.document.setAuthor(author_str);
        return self;
    }

    pub fn version(self: *Self, ver: PDFVersion) *Self {
        self.document.setVersion(ver);
        return self;
    }

    pub fn newPage(self: *Self, size: PageSize, orientation: PageOrientation) !*Self {
        self.current_page = try self.document.addPage(size, orientation);
        return self;
    }

    pub fn newStandardPage(self: *Self) !*Self {
        self.current_page = try self.document.addStandardPage();
        return self;
    }

    pub fn getCurrentPage(self: *Self) ?*PDFPage {
        return self.current_page;
    }

    pub fn build(self: *Self) PDFDocument {
        const doc = self.document;
        self.document = PDFDocument.init(self.document.allocator);
        self.current_page = null;
        return doc;
    }
};

/// Image format for embedding
pub const ImageFormat = enum {
    jpeg,
    png,
    gif,
    bmp,

    pub fn mimeType(self: ImageFormat) []const u8 {
        return switch (self) {
            .jpeg => "image/jpeg",
            .png => "image/png",
            .gif => "image/gif",
            .bmp => "image/bmp",
        };
    }

    pub fn extension(self: ImageFormat) []const u8 {
        return switch (self) {
            .jpeg => "jpg",
            .png => "png",
            .gif => "gif",
            .bmp => "bmp",
        };
    }
};

/// PDF image reference
pub const PDFImage = struct {
    id: u32,
    width: u32,
    height: u32,
    format: ImageFormat,
    bits_per_component: u8,
    color_space: ColorSpace,

    pub fn aspectRatio(self: PDFImage) f32 {
        if (self.height == 0) return 0;
        return @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(self.height));
    }

    pub fn scaledSize(self: PDFImage, max_width: f32, max_height: f32) struct { width: f32, height: f32 } {
        const width_f = @as(f32, @floatFromInt(self.width));
        const height_f = @as(f32, @floatFromInt(self.height));

        const scale_w = max_width / width_f;
        const scale_h = max_height / height_f;
        const s = @min(scale_w, scale_h);

        return .{
            .width = width_f * s,
            .height = height_f * s,
        };
    }
};

/// Compression method
pub const CompressionMethod = enum {
    none,
    flate, // zlib/deflate
    lzw,
    jpeg,
    ccitt_fax, // For bi-level images

    pub fn filterName(self: CompressionMethod) ?[]const u8 {
        return switch (self) {
            .none => null,
            .flate => "FlateDecode",
            .lzw => "LZWDecode",
            .jpeg => "DCTDecode",
            .ccitt_fax => "CCITTFaxDecode",
        };
    }
};

/// Utility: Convert points to other units
pub fn pointsToInches(points: f32) f32 {
    return points / 72.0;
}

pub fn inchesToPoints(inches: f32) f32 {
    return inches * 72.0;
}

pub fn pointsToMM(points: f32) f32 {
    return points * 0.352778;
}

pub fn mmToPoints(mm: f32) f32 {
    return mm / 0.352778;
}

// ============================================================================
// Tests
// ============================================================================

test "PDFVersion toString" {
    try std.testing.expectEqualStrings("1.7", PDFVersion.v1_7.toString());
    try std.testing.expectEqualStrings("2.0", PDFVersion.v2_0.toString());
}

test "PDFVersion header" {
    try std.testing.expectEqualStrings("%PDF-1.7", PDFVersion.v1_7.header());
    try std.testing.expectEqualStrings("%PDF-1.4", PDFVersion.v1_4.header());
}

test "PageSize constants" {
    try std.testing.expectApproxEqAbs(@as(f32, 612), PageSize.letter.width, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 792), PageSize.letter.height, 0.1);

    try std.testing.expectApproxEqAbs(@as(f32, 595), PageSize.a4.width, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 842), PageSize.a4.height, 0.1);
}

test "PageSize landscape" {
    const portrait = PageSize.a4;
    const landscape = portrait.landscape();

    try std.testing.expectApproxEqAbs(portrait.width, landscape.height, 0.1);
    try std.testing.expectApproxEqAbs(portrait.height, landscape.width, 0.1);
}

test "PageSize custom" {
    const custom = PageSize.custom(8.5, 11.0);
    try std.testing.expectApproxEqAbs(@as(f32, 612), custom.width, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 792), custom.height, 0.1);
}

test "ColorSpace componentCount" {
    try std.testing.expectEqual(@as(u8, 1), ColorSpace.device_gray.componentCount());
    try std.testing.expectEqual(@as(u8, 3), ColorSpace.device_rgb.componentCount());
    try std.testing.expectEqual(@as(u8, 4), ColorSpace.device_cmyk.componentCount());
}

test "PDFColor rgb" {
    const color = PDFColor.rgb(0.5, 0.25, 0.75);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), color.r, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), color.g, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), color.b, 0.01);
    try std.testing.expectEqual(ColorSpace.device_rgb, color.space);
}

test "PDFColor fromHex" {
    const color = PDFColor.fromHex(0xFF8000);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), color.r, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), color.g, 0.02);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), color.b, 0.01);
}

test "PDFColor toHex" {
    const color = PDFColor.rgb(1.0, 0.5, 0.0);
    const hex = color.toHex();
    try std.testing.expect(hex > 0xFF0000);
}

test "PDFColor gray" {
    const color = PDFColor.gray(0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), color.r, 0.01);
    try std.testing.expectEqual(ColorSpace.device_gray, color.space);
}

test "PDFColor cmyk" {
    const color = PDFColor.cmyk(1, 0, 0.5, 0.25);
    try std.testing.expectEqual(ColorSpace.device_cmyk, color.space);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), color.k, 0.01);
}

test "FontStyle properties" {
    try std.testing.expect(FontStyle.bold.isBold());
    try std.testing.expect(!FontStyle.bold.isItalic());
    try std.testing.expect(FontStyle.bold_italic.isBold());
    try std.testing.expect(FontStyle.bold_italic.isItalic());
}

test "StandardFont properties" {
    try std.testing.expect(StandardFont.courier.isMonospace());
    try std.testing.expect(!StandardFont.helvetica.isMonospace());
    try std.testing.expect(StandardFont.times_roman.isSerif());
    try std.testing.expect(!StandardFont.helvetica.isSerif());
}

test "StandardFont name" {
    try std.testing.expectEqualStrings("Helvetica", StandardFont.helvetica.name());
    try std.testing.expectEqualStrings("Times-Roman", StandardFont.times_roman.name());
    try std.testing.expectEqualStrings("Courier-Bold", StandardFont.courier_bold.name());
}

test "PDFFont standard" {
    const font = PDFFont.standard(.helvetica, 12.0);
    try std.testing.expectEqualStrings("Helvetica", font.name);
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), font.size, 0.01);
}

test "TextAlign toString" {
    try std.testing.expectEqualStrings("Left", TextAlign.left.toString());
    try std.testing.expectEqualStrings("Justify", TextAlign.justify.toString());
}

test "LineCap values" {
    try std.testing.expectEqual(@as(u8, 0), LineCap.butt.value());
    try std.testing.expectEqual(@as(u8, 1), LineCap.round.value());
    try std.testing.expectEqual(@as(u8, 2), LineCap.square.value());
}

test "LineJoin values" {
    try std.testing.expectEqual(@as(u8, 0), LineJoin.miter.value());
    try std.testing.expectEqual(@as(u8, 1), LineJoin.round.value());
    try std.testing.expectEqual(@as(u8, 2), LineJoin.bevel.value());
}

test "Point operations" {
    const p1 = Point.init(10, 20);
    const p2 = Point.init(5, 10);

    const sum = p1.add(p2);
    try std.testing.expectApproxEqAbs(@as(f32, 15), sum.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 30), sum.y, 0.01);

    const diff = p1.subtract(p2);
    try std.testing.expectApproxEqAbs(@as(f32, 5), diff.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 10), diff.y, 0.01);

    const scaled = p1.scale(2);
    try std.testing.expectApproxEqAbs(@as(f32, 20), scaled.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 40), scaled.y, 0.01);
}

test "Rect contains" {
    const rect = Rect.init(0, 0, 100, 100);

    try std.testing.expect(rect.contains(Point.init(50, 50)));
    try std.testing.expect(rect.contains(Point.init(0, 0)));
    try std.testing.expect(rect.contains(Point.init(100, 100)));
    try std.testing.expect(!rect.contains(Point.init(101, 50)));
    try std.testing.expect(!rect.contains(Point.init(-1, 50)));
}

test "Rect intersects" {
    const rect1 = Rect.init(0, 0, 100, 100);
    const rect2 = Rect.init(50, 50, 100, 100);
    const rect3 = Rect.init(200, 200, 100, 100);

    try std.testing.expect(rect1.intersects(rect2));
    try std.testing.expect(!rect1.intersects(rect3));
}

test "Rect center" {
    const rect = Rect.init(0, 0, 100, 100);
    const c = rect.center();

    try std.testing.expectApproxEqAbs(@as(f32, 50), c.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 50), c.y, 0.01);
}

test "Rect inset" {
    const rect = Rect.init(0, 0, 100, 100);
    const inset_rect = rect.inset(10, 10);

    try std.testing.expectApproxEqAbs(@as(f32, 10), inset_rect.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 10), inset_rect.y, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 80), inset_rect.width, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 80), inset_rect.height, 0.01);
}

test "GraphicsState init" {
    const state = GraphicsState.init();
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), state.line_width, 0.01);
    try std.testing.expectEqual(LineCap.butt, state.line_cap);
    try std.testing.expectEqual(LineJoin.miter, state.line_join);
}

test "PDFPage init and deinit" {
    const allocator = std.testing.allocator;
    var page = PDFPage.init(allocator, PageSize.a4, .portrait);
    defer page.deinit();

    const size = page.getSize();
    try std.testing.expectApproxEqAbs(@as(f32, 595), size.width, 0.1);
}

test "PDFPage landscape" {
    const allocator = std.testing.allocator;
    var page = PDFPage.init(allocator, PageSize.a4, .landscape);
    defer page.deinit();

    const size = page.getSize();
    try std.testing.expectApproxEqAbs(@as(f32, 842), size.width, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 595), size.height, 0.1);
}

test "PDFPage operations" {
    const allocator = std.testing.allocator;
    var page = PDFPage.init(allocator, PageSize.letter, .portrait);
    defer page.deinit();

    try page.moveTo(100, 100);
    try page.lineTo(200, 200);
    try page.stroke();

    try std.testing.expect(page.getContentLength() > 0);
}

test "PDFDocument init and deinit" {
    const allocator = std.testing.allocator;
    var doc = PDFDocument.init(allocator);
    defer doc.deinit();

    try std.testing.expectEqual(PDFVersion.v1_7, doc.version);
    try std.testing.expectEqual(@as(usize, 0), doc.getPageCount());
}

test "PDFDocument addPage" {
    const allocator = std.testing.allocator;
    var doc = PDFDocument.init(allocator);
    defer doc.deinit();

    _ = try doc.addPage(PageSize.letter, .portrait);
    _ = try doc.addPage(PageSize.a4, .landscape);

    try std.testing.expectEqual(@as(usize, 2), doc.getPageCount());
}

test "PDFDocument metadata" {
    const allocator = std.testing.allocator;
    var doc = PDFDocument.init(allocator);
    defer doc.deinit();

    doc.setTitle("Test Document");
    doc.setAuthor("Test Author");

    try std.testing.expectEqualStrings("Test Document", doc.metadata.title.?);
    try std.testing.expectEqualStrings("Test Author", doc.metadata.author.?);
}

test "PDFDocument addStandardFont" {
    const allocator = std.testing.allocator;
    var doc = PDFDocument.init(allocator);
    defer doc.deinit();

    const font = try doc.addStandardFont(.helvetica, 12);
    try std.testing.expectEqual(@as(u32, 1), font.id);
    try std.testing.expectEqualStrings("Helvetica", font.name);
}

test "PDFBuilder fluent API" {
    const allocator = std.testing.allocator;
    var builder = PDFBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.title("My PDF").author("Author Name").version(.v1_7);
    _ = try builder.newStandardPage();

    try std.testing.expect(builder.getCurrentPage() != null);
    try std.testing.expectEqualStrings("My PDF", builder.document.metadata.title.?);
}

test "PDFMetadata init" {
    const meta = PDFMetadata.init();
    try std.testing.expect(meta.title == null);
    try std.testing.expectEqualStrings("Craft PDF Module", meta.creator.?);
    try std.testing.expectEqualStrings("Craft Framework", meta.producer.?);
}

test "ImageFormat properties" {
    try std.testing.expectEqualStrings("image/jpeg", ImageFormat.jpeg.mimeType());
    try std.testing.expectEqualStrings("jpg", ImageFormat.jpeg.extension());
    try std.testing.expectEqualStrings("png", ImageFormat.png.extension());
}

test "PDFImage aspectRatio" {
    const image = PDFImage{
        .id = 1,
        .width = 800,
        .height = 600,
        .format = .jpeg,
        .bits_per_component = 8,
        .color_space = .device_rgb,
    };

    try std.testing.expectApproxEqAbs(@as(f32, 1.333), image.aspectRatio(), 0.01);
}

test "PDFImage scaledSize" {
    const image = PDFImage{
        .id = 1,
        .width = 800,
        .height = 600,
        .format = .jpeg,
        .bits_per_component = 8,
        .color_space = .device_rgb,
    };

    const scaled = image.scaledSize(400, 300);
    try std.testing.expectApproxEqAbs(@as(f32, 400), scaled.width, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 300), scaled.height, 0.01);
}

test "CompressionMethod filterName" {
    try std.testing.expect(CompressionMethod.none.filterName() == null);
    try std.testing.expectEqualStrings("FlateDecode", CompressionMethod.flate.filterName().?);
    try std.testing.expectEqualStrings("DCTDecode", CompressionMethod.jpeg.filterName().?);
}

test "Unit conversion functions" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), pointsToInches(72), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 72), inchesToPoints(1.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 25.4), pointsToMM(72), 0.1);
}
