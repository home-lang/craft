const std = @import("std");

pub const scene = @import("graphics_scene.zig");

/// Window-independent CPU raster core. Pixel words use 0xAARRGGBB; bitmaps
/// borrow tightly packed straight-alpha RGBA8 bytes for synchronous drawing.
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
/// drawBitmap reads synchronously and does not retain this slice. Input must
/// not overlap the writable canvas; overlapping buffers fail before drawing.
pub const Bitmap = struct {
    width: u32,
    height: u32,
    pixels: []const u8,
};

pub const BitmapError = error{ InvalidBitmap, InvalidSourceRect, AliasedBitmap };

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

pub const Canvas = struct {
    width: u32,
    height: u32,
    pixels: []u32,
    allocator: std.mem.Allocator,

    pub const Limits = struct {
        /// Default pixel storage is at most 64 MiB. A host may explicitly
        /// choose a different budget before allocating its offscreen frame.
        max_pixels: usize = 16 * 1024 * 1024,
    };

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Canvas {
        return initWithLimits(allocator, width, height, .{});
    }

    pub fn initWithLimits(allocator: std.mem.Allocator, width: u32, height: u32, limits: Limits) !Canvas {
        if (width == 0 or height == 0 or width > std.math.maxInt(i32) or height > std.math.maxInt(i32))
            return error.InvalidDimensions;
        const count = try std.math.mul(usize, width, height);
        if (count > limits.max_pixels) return error.AllocationLimitExceeded;
        _ = try std.math.mul(usize, count, @sizeOf(u32));
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
        try self.validateBitmap(bitmap);
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

    /// Validate borrowed RGBA8 storage without retaining or changing it.
    pub fn validateBitmap(self: *const Canvas, bitmap: Bitmap) BitmapError!void {
        if (bitmap.width == 0 or bitmap.height == 0) return error.InvalidBitmap;
        const count = std.math.mul(usize, bitmap.width, bitmap.height) catch return error.InvalidBitmap;
        const bytes = std.math.mul(usize, count, 4) catch return error.InvalidBitmap;
        if (bitmap.pixels.len != bytes) return error.InvalidBitmap;
        const source_start = @intFromPtr(bitmap.pixels.ptr);
        const destination_start = @intFromPtr(self.pixels.ptr);
        const overlaps = if (source_start >= destination_start)
            source_start - destination_start < self.pixels.len * @sizeOf(u32)
        else
            destination_start - source_start < bitmap.pixels.len;
        if (overlaps) return error.AliasedBitmap;
    }

    /// Straight-alpha source-over for one clipped pixel.
    pub fn blendPixel(self: *Canvas, x: u32, y: u32, color: Color) void {
        if (x >= self.width or y >= self.height) return;
        const index = @as(usize, y) * self.width + x;
        self.pixels[index] = compositeRgba(.{ color.r, color.g, color.b, color.a }, self.pixels[index]);
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

    /// Replace covered pixels, matching clear/setPixel. Bitmap drawing uses source-over.
    pub fn drawRect(self: *Canvas, rect: Rect, color: Color) void {
        const pixel = (@as(u32, color.a) << 24) | (@as(u32, color.r) << 16) | (@as(u32, color.g) << 8) | color.b;
        const left = @max(0, @as(i64, rect.x));
        const top = @max(0, @as(i64, rect.y));
        const right = @min(@as(i64, self.width), @as(i64, rect.x) + rect.width);
        const bottom = @min(@as(i64, self.height), @as(i64, rect.y) + rect.height);
        var y: i64 = top;
        while (y < bottom) : (y += 1) {
            const row: usize = @as(usize, @intCast(y)) * self.width;
            var x: i64 = left;
            while (x < right) : (x += 1) {
                self.pixels[row + @as(usize, @intCast(x))] = pixel;
            }
        }
    }

    pub fn drawCircle(self: *Canvas, center: Point, radius: u32, color: Color) void {
        const pixel = (@as(u32, color.a) << 24) | (@as(u32, color.r) << 16) | (@as(u32, color.g) << 8) | color.b;
        const r: i64 = radius;
        const left = @max(0, @as(i64, center.x) - r);
        const top = @max(0, @as(i64, center.y) - r);
        const right = @min(@as(i64, self.width), @as(i64, center.x) + r + 1);
        const bottom = @min(@as(i64, self.height), @as(i64, center.y) + r + 1);
        const squared_radius = @as(i128, radius) * radius;
        var y: i64 = top;
        while (y < bottom) : (y += 1) {
            const dy: i128 = y - center.y;
            const row: usize = @as(usize, @intCast(y)) * self.width;
            var x: i64 = left;
            while (x < right) : (x += 1) {
                const dx: i128 = x - center.x;
                if (dx * dx + dy * dy <= squared_radius)
                    self.pixels[row + @as(usize, @intCast(x))] = pixel;
            }
        }
    }

    /// The same directed Bresenham pixels as before, evaluated only across the
    /// visible major axis. Offscreen endpoints cannot cause billions of steps.
    pub fn drawLine(self: *Canvas, from: Point, to: Point, color: Color) void {
        if (self.width == 0 or self.height == 0) return;
        const pixel = (@as(u32, color.a) << 24) | (@as(u32, color.r) << 16) | (@as(u32, color.g) << 8) | color.b;
        const dx: i128 = @abs(@as(i64, to.x) - from.x);
        const dy: i128 = @abs(@as(i64, to.y) - from.y);
        const sx: i128 = if (from.x < to.x) 1 else -1;
        const sy: i128 = if (from.y < to.y) 1 else -1;
        if (dx == 0 and dy == 0) {
            if (from.x >= 0 and from.y >= 0)
                self.setPixel(@intCast(from.x), @intCast(from.y), color);
            return;
        }
        if (dx >= dy) {
            const first: i64 = @max(0, @min(from.x, to.x));
            const last: i64 = @min(@as(i64, self.width) - 1, @max(from.x, to.x));
            var x = first;
            while (x <= last) : (x += 1) {
                const step: i128 = @abs(x - from.x);
                const y = @as(i128, from.y) + sy * @divTrunc(step * dy + @divTrunc(dx - 1, 2), dx);
                if (y >= 0 and y < self.height)
                    self.pixels[@as(usize, @intCast(y)) * self.width + @as(usize, @intCast(x))] = pixel;
            }
        } else {
            const first: i64 = @max(0, @min(from.y, to.y));
            const last: i64 = @min(@as(i64, self.height) - 1, @max(from.y, to.y));
            var y = first;
            while (y <= last) : (y += 1) {
                const step: i128 = @abs(y - from.y);
                const x = @as(i128, from.x) + sx * @divTrunc(step * dx + @divTrunc(dy - 1, 2), dy);
                if (x >= 0 and x < self.width)
                    self.pixels[@as(usize, @intCast(y)) * self.width + @as(usize, @intCast(x))] = pixel;
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

        const pixel = self.pixels[@as(usize, y) * self.width + x];
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
        self.pixels[@as(usize, y) * self.width + x] = pixel;
    }
};
