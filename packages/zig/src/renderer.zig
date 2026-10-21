const std = @import("std");

/// Native Rendering Module
/// Provides alternative to WebView for pure native UI
pub const RenderBackend = enum {
    webview, // Default WebView rendering
    native, // Pure native rendering
    hybrid, // Mix of native and web
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return Color{ .r = r, .g = g, .b = b };
    }

    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
        return Color{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn fromHex(hex: u32) Color {
        return Color{
            .r = @intCast((hex >> 16) & 0xFF),
            .g = @intCast((hex >> 8) & 0xFF),
            .b = @intCast(hex & 0xFF),
            .a = 255,
        };
    }
};

pub const Point = struct {
    x: i32,
    y: i32,
};

pub const Size = struct {
    width: u32,
    height: u32,
};

pub const Rect = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,
};

/// Tightly packed, straight-alpha RGBA8 pixels. The caller retains ownership;
/// drawBitmap reads synchronously and does not retain this slice.
pub const Bitmap = struct {
    width: u32,
    height: u32,
    pixels: []const u8,
};

pub const BitmapError = error{ InvalidBitmap, InvalidSourceRect };

pub const Font = struct {
    family: []const u8,
    size: f32,
    weight: FontWeight = .normal,
    style: FontStyle = .normal,
};

pub const FontWeight = enum {
    thin,
    light,
    normal,
    medium,
    semibold,
    bold,
    black,
};

pub const FontStyle = enum {
    normal,
    italic,
    oblique,
};

pub const Renderer = struct {
    backend: RenderBackend,
    canvas: ?*Canvas,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, backend: RenderBackend) Renderer {
        return Renderer{
            .backend = backend,
            .canvas = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Renderer) void {
        if (self.canvas) |canvas| {
            canvas.deinit();
            self.allocator.destroy(canvas);
        }
    }

    pub fn createCanvas(self: *Renderer, width: u32, height: u32) !*Canvas {
        const canvas = try self.allocator.create(Canvas);
        // Without this errdefer, a failure inside `Canvas.init` below leaks
        // the outer allocation.
        errdefer self.allocator.destroy(canvas);
        canvas.* = try Canvas.init(self.allocator, width, height);
        self.canvas = canvas;
        return canvas;
    }
};

pub const Canvas = struct {
    width: u32,
    height: u32,
    pixels: []u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Canvas {
        if (width == 0 or height == 0 or width > std.math.maxInt(i32) or height > std.math.maxInt(i32))
            return error.InvalidDimensions;
        const count = try std.math.mul(usize, width, height);
        const pixels = try allocator.alloc(u32, count);
        @memset(pixels, 0xFFFFFFFF); // White background

        return Canvas{
            .width = width,
            .height = height,
            .pixels = pixels,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Canvas) void {
        self.allocator.free(self.pixels);
    }

    pub fn clear(self: *Canvas, color: Color) void {
        const pixel = (@as(u32, color.a) << 24) | (@as(u32, color.r) << 16) | (@as(u32, color.g) << 8) | color.b;
        @memset(self.pixels, pixel);
    }

    /// Composite an atlas rectangle at its unscaled destination. Source
    /// bounds are validated before any pixel changes; destination clipping
    /// never changes which source pixel corresponds to a destination pixel.
    pub fn drawBitmap(self: *Canvas, bitmap: Bitmap, source: Rect, destination: Point) BitmapError!void {
        if (bitmap.width == 0 or bitmap.height == 0) return error.InvalidBitmap;
        const count = std.math.mul(usize, bitmap.width, bitmap.height) catch return error.InvalidBitmap;
        const bytes = std.math.mul(usize, count, 4) catch return error.InvalidBitmap;
        if (bitmap.pixels.len != bytes) return error.InvalidBitmap;
        if (source.x < 0 or source.y < 0 or
            @as(i64, source.x) + source.width > bitmap.width or
            @as(i64, source.y) + source.height > bitmap.height)
            return error.InvalidSourceRect;

        const left = @max(0, @as(i64, destination.x));
        const top = @max(0, @as(i64, destination.y));
        const right = @min(@as(i64, self.width), @as(i64, destination.x) + source.width);
        const bottom = @min(@as(i64, self.height), @as(i64, destination.y) + source.height);
        var y: i64 = top;
        while (y < bottom) : (y += 1) {
            var x: i64 = left;
            while (x < right) : (x += 1) {
                const sx: usize = @intCast(@as(i64, source.x) + x - destination.x);
                const sy: usize = @intCast(@as(i64, source.y) + y - destination.y);
                const at = (sy * bitmap.width + sx) * 4;
                const index = @as(usize, @intCast(y)) * self.width + @as(usize, @intCast(x));
                self.pixels[index] = compositeRgba(bitmap.pixels[at..][0..4].*, self.pixels[index]);
            }
        }
    }

    fn compositeRgba(source: [4]u8, destination: u32) u32 {
        const alpha: u32 = source[3];
        if (alpha == 0) return destination;
        if (alpha == 255)
            return 0xFF000000 | (@as(u32, source[0]) << 16) | (@as(u32, source[1]) << 8) | source[2];
        const destination_alpha = destination >> 24;
        const inverse = 255 - alpha;
        const combined = alpha * 255 + destination_alpha * inverse;
        var result: u32 = ((combined + 127) / 255) << 24;
        for ([_]u5{ 16, 8, 0 }, 0..) |shift, channel| {
            const old = (destination >> shift) & 0xFF;
            const value = (@as(u32, source[channel]) * alpha * 255 + old * destination_alpha * inverse + combined / 2) / combined;
            result |= value << shift;
        }
        return result;
    }

    pub fn drawRect(self: *Canvas, rect: Rect, color: Color) void {
        const pixel = (@as(u32, color.a) << 24) | (@as(u32, color.r) << 16) | (@as(u32, color.g) << 8) | color.b;

        var y: i32 = rect.y;
        while (y < rect.y + @as(i32, @intCast(rect.height))) : (y += 1) {
            if (y < 0 or y >= @as(i32, @intCast(self.height))) continue;

            var x: i32 = rect.x;
            while (x < rect.x + @as(i32, @intCast(rect.width))) : (x += 1) {
                if (x < 0 or x >= @as(i32, @intCast(self.width))) continue;

                const index = @as(usize, @intCast(y)) * self.width + @as(usize, @intCast(x));
                self.pixels[index] = pixel;
            }
        }
    }

    pub fn drawCircle(self: *Canvas, center: Point, radius: u32, color: Color) void {
        const pixel = (@as(u32, color.a) << 24) | (@as(u32, color.r) << 16) | (@as(u32, color.g) << 8) | color.b;
        const r_sq = @as(i32, @intCast(radius * radius));

        var y: i32 = center.y - @as(i32, @intCast(radius));
        while (y <= center.y + @as(i32, @intCast(radius))) : (y += 1) {
            if (y < 0 or y >= @as(i32, @intCast(self.height))) continue;

            var x: i32 = center.x - @as(i32, @intCast(radius));
            while (x <= center.x + @as(i32, @intCast(radius))) : (x += 1) {
                if (x < 0 or x >= @as(i32, @intCast(self.width))) continue;

                const dx = x - center.x;
                const dy = y - center.y;
                if (dx * dx + dy * dy <= r_sq) {
                    const index = @as(usize, @intCast(y)) * self.width + @as(usize, @intCast(x));
                    self.pixels[index] = pixel;
                }
            }
        }
    }

    pub fn drawLine(self: *Canvas, from: Point, to: Point, color: Color) void {
        const pixel = (@as(u32, color.a) << 24) | (@as(u32, color.r) << 16) | (@as(u32, color.g) << 8) | color.b;

        var x0 = from.x;
        var y0 = from.y;
        const x1 = to.x;
        const y1 = to.y;

        // Use i32 for dx, dy to support signed arithmetic in Bresenham's algorithm
        const dx: i32 = @intCast(@abs(x1 - x0));
        const dy: i32 = @intCast(@abs(y1 - y0));
        const sx: i32 = if (x0 < x1) 1 else -1;
        const sy: i32 = if (y0 < y1) 1 else -1;
        var err: i32 = dx - dy;

        while (true) {
            if (x0 >= 0 and x0 < @as(i32, @intCast(self.width)) and y0 >= 0 and y0 < @as(i32, @intCast(self.height))) {
                const index = @as(usize, @intCast(y0)) * self.width + @as(usize, @intCast(x0));
                self.pixels[index] = pixel;
            }

            if (x0 == x1 and y0 == y1) break;

            const e2 = 2 * err;
            if (e2 > -dy) {
                err -= dy;
                x0 += sx;
            }
            if (e2 < dx) {
                err += dx;
                y0 += sy;
            }
        }
    }

    pub fn drawText(self: *Canvas, text: []const u8, pos: Point, font: Font, color: Color) error{TextRenderingUnavailable}!void {
        _ = self;
        _ = text;
        _ = pos;
        _ = font;
        _ = color;
        return error.TextRenderingUnavailable;
    }

    pub fn getPixel(self: Canvas, x: u32, y: u32) ?Color {
        if (x >= self.width or y >= self.height) return null;

        const pixel = self.pixels[y * self.width + x];
        return Color{
            .a = @intCast((pixel >> 24) & 0xFF),
            .r = @intCast((pixel >> 16) & 0xFF),
            .g = @intCast((pixel >> 8) & 0xFF),
            .b = @intCast(pixel & 0xFF),
        };
    }

    pub fn setPixel(self: *Canvas, x: u32, y: u32, color: Color) void {
        if (x >= self.width or y >= self.height) return;

        const pixel = (@as(u32, color.a) << 24) | (@as(u32, color.r) << 16) | (@as(u32, color.g) << 8) | color.b;
        self.pixels[y * self.width + x] = pixel;
    }
};

/// UI Component system for native rendering
pub const Component = struct {
    bounds: Rect,
    visible: bool,
    children: std.ArrayList(*Component),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, bounds: Rect) Component {
        return Component{
            .bounds = bounds,
            .visible = true,
            .children = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Component) void {
        for (self.children.items) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }
        self.children.deinit(self.allocator);
    }

    pub fn addChild(self: *Component, child: *Component) !void {
        try self.children.append(self.allocator, child);
    }

    pub fn render(self: *Component, canvas: *Canvas) void {
        if (!self.visible) return;

        // Render self
        canvas.drawRect(self.bounds, Color.rgb(200, 200, 200));

        // Render children
        for (self.children.items) |child| {
            child.render(canvas);
        }
    }
};

/// Button component
pub const Button = struct {
    component: Component,
    text: []const u8,
    background: Color,
    foreground: Color,
    font: Font,

    pub fn init(allocator: std.mem.Allocator, bounds: Rect, text: []const u8) Button {
        return Button{
            .component = Component.init(allocator, bounds),
            .text = text,
            .background = Color.rgb(100, 100, 200),
            .foreground = Color.rgb(255, 255, 255),
            .font = Font{
                .family = "system",
                .size = 14.0,
            },
        };
    }

    pub fn render(self: *Button, canvas: *Canvas) !void {
        canvas.drawRect(self.component.bounds, self.background);
        try canvas.drawText(self.text, .{ .x = self.component.bounds.x, .y = self.component.bounds.y }, self.font, self.foreground);
    }
};

/// Label component
pub const Label = struct {
    component: Component,
    text: []const u8,
    color: Color,
    font: Font,

    pub fn init(allocator: std.mem.Allocator, bounds: Rect, text: []const u8) Label {
        return Label{
            .component = Component.init(allocator, bounds),
            .text = text,
            .color = Color.rgb(0, 0, 0),
            .font = Font{
                .family = "system",
                .size = 14.0,
            },
        };
    }

    pub fn render(self: *Label, canvas: *Canvas) !void {
        try canvas.drawText(self.text, Point{ .x = self.component.bounds.x, .y = self.component.bounds.y }, self.font, self.color);
    }
};
