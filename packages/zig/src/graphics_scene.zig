//! Borrowed, allocation-free CPU scene drawing. No window or GPU dependency.
const std = @import("std");
const graphics = @import("graphics.zig");

pub const DrawError = graphics.BitmapError || error{
    InvalidTransform,
    InvalidTriangle,
    InvalidUV,
    InvalidFont,
    InvalidText,
    MissingGlyph,
    InvalidTintMask,
    AliasedInput,
    AssetLimitExceeded,
    FrameLimitExceeded,
    InvalidAssetViewLimit,
    AssetViewLimitExceeded,
};

pub const max_supported_asset_views: usize = 1024;
const asset_table_slots = max_supported_asset_views * 2;

pub const Limits = struct {
    max_asset_bytes: usize = 64 * 1024 * 1024,
    max_covered_pixels: usize = 64 * 1024 * 1024,
    max_font_glyphs: usize = 4096,
    max_text_bytes: usize = 1024 * 1024,
    max_commands: usize = 65_536,
    max_asset_views: usize = max_supported_asset_views,
};

/// Maps local pixel-edge coordinates to frame coordinates:
/// x' = a*x + c*y + tx; y' = b*x + d*y + ty.
pub const Transform = struct {
    a: f64 = 1,
    b: f64 = 0,
    c: f64 = 0,
    d: f64 = 1,
    tx: f64 = 0,
    ty: f64 = 0,
};

/// An optional atlas-sized byte mask selects player-colored pixels. Coverage
/// blends between the original and channel-multiplied tint, including alpha.
pub const Tint = struct {
    color: graphics.Color = graphics.Color.rgba(255, 255, 255, 255),
    mask: ?[]const u8 = null,
};

pub const Sprite = struct {
    bitmap: graphics.Bitmap,
    source: graphics.Rect,
    transform: Transform = .{},
    tint: Tint = .{},
    clip: ?graphics.Rect = null,
};

const Position = struct { x: f64, y: f64 };
const Bounds = struct {
    left: u32,
    top: u32,
    right: u32,
    bottom: u32,

    fn pixels(self: Bounds) usize {
        return @as(usize, self.right - self.left) * (self.bottom - self.top);
    }
};

fn position(transform: Transform, x: f64, y: f64) Position {
    return .{ .x = transform.a * x + transform.c * y + transform.tx, .y = transform.b * x + transform.d * y + transform.ty };
}

fn inverse(transform: Transform) DrawError!Transform {
    inline for (@typeInfo(Transform).@"struct".field_names) |field| {
        if (!std.math.isFinite(@field(transform, field))) return error.InvalidTransform;
    }
    const determinant = transform.a * transform.d - transform.b * transform.c;
    if (!std.math.isFinite(determinant) or determinant == 0) return error.InvalidTransform;
    const result = Transform{
        .a = transform.d / determinant,
        .b = -transform.b / determinant,
        .c = -transform.c / determinant,
        .d = transform.a / determinant,
        .tx = (transform.c * transform.ty - transform.d * transform.tx) / determinant,
        .ty = (transform.b * transform.tx - transform.a * transform.ty) / determinant,
    };
    inline for (@typeInfo(Transform).@"struct".field_names) |field| {
        if (!std.math.isFinite(@field(result, field))) return error.InvalidTransform;
    }
    return result;
}

fn overlaps(canvas: *const graphics.Canvas, bytes: []const u8) bool {
    if (bytes.len == 0) return false;
    const source = @intFromPtr(bytes.ptr);
    const destination = @intFromPtr(canvas.pixels.ptr);
    return if (source >= destination)
        source - destination < canvas.pixels.len * @sizeOf(u32)
    else
        destination - source < bytes.len;
}

fn validateAsset(canvas: *const graphics.Canvas, bitmap: graphics.Bitmap, tint: Tint, limits: Limits) DrawError!void {
    if (bitmap.pixels.len > limits.max_asset_bytes) return error.AssetLimitExceeded;
    try canvas.validateBitmap(bitmap);
    if (tint.mask) |mask| {
        if (mask.len != bitmap.pixels.len / 4) return error.InvalidTintMask;
        if (overlaps(canvas, mask)) return error.AliasedInput;
        if (mask.len > limits.max_asset_bytes - bitmap.pixels.len) return error.AssetLimitExceeded;
    }
}

fn bounds(canvas: *const graphics.Canvas, points: []const Position, clip: ?graphics.Rect) DrawError!Bounds {
    var left: f64 = @floatFromInt(canvas.width);
    var top: f64 = @floatFromInt(canvas.height);
    var right: f64 = 0;
    var bottom: f64 = 0;
    for (points) |point| {
        if (!std.math.isFinite(point.x) or !std.math.isFinite(point.y)) return error.InvalidTransform;
        left = @min(left, point.x);
        top = @min(top, point.y);
        right = @max(right, point.x);
        bottom = @max(bottom, point.y);
    }
    var clip_left: f64 = 0;
    var clip_top: f64 = 0;
    var clip_right: f64 = @floatFromInt(canvas.width);
    var clip_bottom: f64 = @floatFromInt(canvas.height);
    if (clip) |region| {
        clip_left = @max(clip_left, @as(f64, @floatFromInt(region.x)));
        clip_top = @max(clip_top, @as(f64, @floatFromInt(region.y)));
        clip_right = @min(clip_right, @as(f64, @floatFromInt(@as(i64, region.x) + region.width)));
        clip_bottom = @min(clip_bottom, @as(f64, @floatFromInt(@as(i64, region.y) + region.height)));
    }
    // Clamp in floating point before casting even extreme offscreen geometry.
    left = @max(0, @min(@as(f64, @floatFromInt(canvas.width)), @max(@floor(left), clip_left)));
    top = @max(0, @min(@as(f64, @floatFromInt(canvas.height)), @max(@floor(top), clip_top)));
    right = @max(left, @min(@as(f64, @floatFromInt(canvas.width)), @min(@ceil(right), clip_right)));
    bottom = @max(top, @min(@as(f64, @floatFromInt(canvas.height)), @min(@ceil(bottom), clip_bottom)));
    return .{ .left = @intFromFloat(left), .top = @intFromFloat(top), .right = @intFromFloat(right), .bottom = @intFromFloat(bottom) };
}

fn sample(bitmap: graphics.Bitmap, x: u32, y: u32, tint: Tint) graphics.Color {
    const index = @as(usize, y) * bitmap.width + x;
    const pixel = bitmap.pixels[index * 4 ..][0..4];
    const coverage: u32 = if (tint.mask) |mask| mask[index] else 255;
    var channels: [4]u8 = undefined;
    const color = [4]u8{ tint.color.r, tint.color.g, tint.color.b, tint.color.a };
    for (pixel, color, &channels) |original, multiplier, *output| {
        const multiplied = (@as(u32, original) * multiplier + 127) / 255;
        output.* = @intCast((@as(u32, original) * (255 - coverage) + multiplied * coverage + 127) / 255);
    }
    return graphics.Color.rgba(channels[0], channels[1], channels[2], channels[3]);
}

const PreparedSprite = struct { inverse: Transform, bounds: Bounds };

fn prepareSprite(canvas: *const graphics.Canvas, sprite: Sprite, limits: Limits) DrawError!PreparedSprite {
    try validateAsset(canvas, sprite.bitmap, sprite.tint, limits);
    if (sprite.source.x < 0 or sprite.source.y < 0 or
        @as(i64, sprite.source.x) + sprite.source.width > sprite.bitmap.width or
        @as(i64, sprite.source.y) + sprite.source.height > sprite.bitmap.height) return error.InvalidSourceRect;
    const inverted = try inverse(sprite.transform);
    const width: f64 = @floatFromInt(sprite.source.width);
    const height: f64 = @floatFromInt(sprite.source.height);
    const area = try bounds(canvas, &.{ position(sprite.transform, 0, 0), position(sprite.transform, width, 0), position(sprite.transform, 0, height), position(sprite.transform, width, height) }, sprite.clip);
    if (area.pixels() > limits.max_covered_pixels) return error.FrameLimitExceeded;
    // Finite inverse coefficients alone do not ensure finite evaluation:
    // multiplication can overflow and opposite infinities can produce NaN.
    // Bound every multiply/add over the whole clipped sampling rectangle
    // before any sprite, text or frame write can occur.
    for ([_]u32{ area.left, area.right }) |x| {
        for ([_]u32{ area.top, area.bottom }) |y| {
            const px: f64 = @floatFromInt(x);
            const py: f64 = @floatFromInt(y);
            const ax = inverted.a * px;
            const cy = inverted.c * py;
            const bx = inverted.b * px;
            const dy = inverted.d * py;
            if (!std.math.isFinite(ax) or !std.math.isFinite(cy) or !std.math.isFinite(bx) or !std.math.isFinite(dy) or
                !std.math.isFinite(ax + cy) or !std.math.isFinite(bx + dy) or
                !std.math.isFinite(ax + cy + inverted.tx) or !std.math.isFinite(bx + dy + inverted.ty)) return error.InvalidTransform;
        }
    }
    return .{ .inverse = inverted, .bounds = area };
}

/// Nearest-neighbor atlas drawing at pixel centers, in invocation order.
/// All validation precedes writes. No input pointer is retained or allocated.
pub fn drawSprite(canvas: *graphics.Canvas, sprite: Sprite, limits: Limits) DrawError!void {
    const prepared = try prepareSprite(canvas, sprite, limits);
    var y = prepared.bounds.top;
    while (y < prepared.bounds.bottom) : (y += 1) {
        var x = prepared.bounds.left;
        while (x < prepared.bounds.right) : (x += 1) {
            const local = position(prepared.inverse, @as(f64, @floatFromInt(x)) + 0.5, @as(f64, @floatFromInt(y)) + 0.5);
            if (local.x < 0 or local.y < 0 or local.x >= @as(f64, @floatFromInt(sprite.source.width)) or local.y >= @as(f64, @floatFromInt(sprite.source.height))) continue;
            const sx = @as(u32, @intCast(sprite.source.x)) + @as(u32, @intFromFloat(@floor(local.x)));
            const sy = @as(u32, @intCast(sprite.source.y)) + @as(u32, @intFromFloat(@floor(local.y)));
            canvas.blendPixel(x, y, sample(sprite.bitmap, sx, sy, sprite.tint));
        }
    }
}

pub const Vertex = struct { x: f64, y: f64, u: f64, v: f64 };
pub const Triangle = struct {
    bitmap: graphics.Bitmap,
    vertices: [3]Vertex,
    tint: Tint = .{},
    clip: ?graphics.Rect = null,
};

fn edge(from: Vertex, to: Vertex, x: f64, y: f64) f64 {
    // Evaluate a shared geometric edge identically in both triangles, then
    // apply its direction. Independent AB/BA arithmetic can round both sides
    // negative at fractional coordinates, leaving a crack (or double fill).
    const reversed = from.x > to.x or (from.x == to.x and from.y > to.y);
    const first = if (reversed) to else from;
    const last = if (reversed) from else to;
    const value = (last.x - first.x) * (y - first.y) - (last.y - first.y) * (x - first.x);
    return if (reversed) -value else value;
}

fn includesEdge(from: Vertex, to: Vertex) bool {
    const dx = to.x - from.x;
    const dy = to.y - from.y;
    return dy < 0 or (dy == 0 and dx > 0);
}

const PreparedTriangle = struct { vertices: [3]Vertex, area: f64, bounds: Bounds };

fn prepareTriangle(canvas: *const graphics.Canvas, triangle: Triangle, limits: Limits) DrawError!PreparedTriangle {
    try validateAsset(canvas, triangle.bitmap, triangle.tint, limits);
    var vertices = triangle.vertices;
    for (vertices) |vertex| {
        if (!std.math.isFinite(vertex.x) or !std.math.isFinite(vertex.y)) return error.InvalidTriangle;
        if (!std.math.isFinite(vertex.u) or !std.math.isFinite(vertex.v) or vertex.u < 0 or vertex.u > 1 or vertex.v < 0 or vertex.v > 1) return error.InvalidUV;
    }
    var area = edge(vertices[0], vertices[1], vertices[2].x, vertices[2].y);
    if (!std.math.isFinite(area) or area == 0) return error.InvalidTriangle;
    if (area < 0) {
        std.mem.swap(Vertex, &vertices[1], &vertices[2]);
        area = -area;
    }
    const region = try bounds(canvas, &.{ .{ .x = vertices[0].x, .y = vertices[0].y }, .{ .x = vertices[1].x, .y = vertices[1].y }, .{ .x = vertices[2].x, .y = vertices[2].y } }, triangle.clip);
    if (region.pixels() > limits.max_covered_pixels) return error.FrameLimitExceeded;
    // Reject numerically unrepresentable edge evaluation before any writes.
    for (0..3) |index| {
        const from = vertices[index];
        const to = vertices[(index + 1) % 3];
        for ([_]u32{ region.left, region.right }) |x| {
            for ([_]u32{ region.top, region.bottom }) |y| {
                if (!std.math.isFinite(edge(from, to, @floatFromInt(x), @floatFromInt(y)))) return error.InvalidTriangle;
            }
        }
    }
    return .{ .vertices = vertices, .area = area, .bounds = region };
}

/// Affine UV interpolation with normalized [0,1] coordinates and nearest
/// sampling. The top-left edge rule prevents shared-edge double compositing.
pub fn drawTriangle(canvas: *graphics.Canvas, triangle: Triangle, limits: Limits) DrawError!void {
    const prepared = try prepareTriangle(canvas, triangle, limits);
    const vertices = prepared.vertices;
    var y = prepared.bounds.top;
    while (y < prepared.bounds.bottom) : (y += 1) {
        var x = prepared.bounds.left;
        while (x < prepared.bounds.right) : (x += 1) {
            const px = @as(f64, @floatFromInt(x)) + 0.5;
            const py = @as(f64, @floatFromInt(y)) + 0.5;
            const weights = [3]f64{ edge(vertices[1], vertices[2], px, py), edge(vertices[2], vertices[0], px, py), edge(vertices[0], vertices[1], px, py) };
            var covered = true;
            for (weights, 0..) |weight, index| {
                if (weight < 0 or (weight == 0 and !includesEdge(vertices[(index + 1) % 3], vertices[(index + 2) % 3]))) covered = false;
            }
            if (!covered) continue;
            var u: f64 = 0;
            var v: f64 = 0;
            for (weights, vertices) |weight, vertex| {
                u += (weight / prepared.area) * vertex.u;
                v += (weight / prepared.area) * vertex.v;
            }
            const sx: u32 = @intFromFloat(@floor(@min(@as(f64, @floatFromInt(triangle.bitmap.width - 1)), @max(0, u * @as(f64, @floatFromInt(triangle.bitmap.width))))));
            const sy: u32 = @intFromFloat(@floor(@min(@as(f64, @floatFromInt(triangle.bitmap.height - 1)), @max(0, v * @as(f64, @floatFromInt(triangle.bitmap.height))))));
            canvas.blendPixel(x, y, sample(triangle.bitmap, sx, sy, triangle.tint));
        }
    }
}

/// Sorted Unicode scalar glyphs. Bearings and advance are in untransformed
/// pixel units; the text origin is the glyph's top-left pen, not a baseline.
pub const Glyph = struct {
    codepoint: u21,
    source: graphics.Rect,
    bearing: graphics.Point = .{ .x = 0, .y = 0 },
    advance: u32,
};
pub const BitmapFont = struct {
    bitmap: graphics.Bitmap,
    glyphs: []const Glyph,
    line_height: u32,
};
pub const Text = struct {
    font: BitmapFont,
    text: []const u8,
    transform: Transform = .{},
    tint: Tint = .{},
    clip: ?graphics.Rect = null,
};

fn findGlyph(font: BitmapFont, codepoint: u21) ?Glyph {
    var first: usize = 0;
    var last = font.glyphs.len;
    while (first < last) {
        const middle = first + (last - first) / 2;
        const candidate = font.glyphs[middle];
        if (candidate.codepoint == codepoint) return candidate;
        if (candidate.codepoint < codepoint) first = middle + 1 else last = middle;
    }
    return null;
}

fn glyphSprite(text: Text, glyph: Glyph, pen: Position) Sprite {
    const offset = position(text.transform, pen.x + @as(f64, @floatFromInt(glyph.bearing.x)), pen.y + @as(f64, @floatFromInt(glyph.bearing.y)));
    var transform = text.transform;
    transform.tx = offset.x;
    transform.ty = offset.y;
    return .{ .bitmap = text.font.bitmap, .source = glyph.source, .transform = transform, .tint = text.tint, .clip = text.clip };
}

fn prepareText(canvas: *const graphics.Canvas, text: Text, limits: Limits) DrawError!usize {
    if (text.text.len > limits.max_text_bytes) return error.FrameLimitExceeded;
    if (text.font.glyphs.len > limits.max_font_glyphs) return error.AssetLimitExceeded;
    if (overlaps(canvas, text.text) or overlaps(canvas, std.mem.sliceAsBytes(text.font.glyphs))) return error.AliasedInput;
    try validateAsset(canvas, text.font.bitmap, text.tint, limits);
    const glyph_bytes = std.math.mul(usize, text.font.glyphs.len, @sizeOf(Glyph)) catch return error.AssetLimitExceeded;
    const asset_bytes = std.math.add(usize, text.font.bitmap.pixels.len, if (text.tint.mask) |mask| mask.len else 0) catch return error.AssetLimitExceeded;
    if (glyph_bytes > limits.max_asset_bytes - asset_bytes) return error.AssetLimitExceeded;
    if (text.font.line_height == 0 or text.font.glyphs.len == 0) return error.InvalidFont;
    var previous: ?u21 = null;
    for (text.font.glyphs) |glyph| {
        if (!std.unicode.utf8ValidCodepoint(glyph.codepoint) or (previous != null and glyph.codepoint <= previous.?)) return error.InvalidFont;
        if (glyph.source.x < 0 or glyph.source.y < 0 or
            @as(i64, glyph.source.x) + glyph.source.width > text.font.bitmap.width or
            @as(i64, glyph.source.y) + glyph.source.height > text.font.bitmap.height) return error.InvalidFont;
        previous = glyph.codepoint;
    }
    _ = try inverse(text.transform);
    const view = std.unicode.Utf8View.init(text.text) catch return error.InvalidText;
    var iterator = view.iterator();
    var pen = Position{ .x = 0, .y = 0 };
    var covered: usize = 0;
    while (iterator.nextCodepoint()) |codepoint| {
        if (codepoint == '\n') {
            pen.x = 0;
            pen.y += @floatFromInt(text.font.line_height);
            continue;
        }
        const glyph = findGlyph(text.font, codepoint) orelse return error.MissingGlyph;
        const prepared = try prepareSprite(canvas, glyphSprite(text, glyph, pen), limits);
        covered = std.math.add(usize, covered, prepared.bounds.pixels()) catch return error.FrameLimitExceeded;
        if (covered > limits.max_covered_pixels) return error.FrameLimitExceeded;
        pen.x += @floatFromInt(glyph.advance);
    }
    return covered;
}

/// Explicit bitmap-font text, including UTF-8 and newlines. Missing glyphs,
/// malformed fonts and invalid text fail before any glyph changes the frame.
/// Family/system fonts remain unavailable through Canvas.drawText.
pub fn drawText(canvas: *graphics.Canvas, text: Text, limits: Limits) DrawError!void {
    _ = try prepareText(canvas, text, limits);
    var iterator = (std.unicode.Utf8View.init(text.text) catch unreachable).iterator();
    var pen = Position{ .x = 0, .y = 0 };
    while (iterator.nextCodepoint()) |codepoint| {
        if (codepoint == '\n') {
            pen.x = 0;
            pen.y += @floatFromInt(text.font.line_height);
            continue;
        }
        const glyph = findGlyph(text.font, codepoint).?;
        try drawSprite(canvas, glyphSprite(text, glyph, pen), limits);
        pen.x += @floatFromInt(glyph.advance);
    }
}

pub const Command = union(enum) { sprite: Sprite, triangle: Triangle, text: Text };

const AssetRole = enum(u8) { atlas, mask, glyphs };
const AssetView = struct {
    address: usize = 0,
    length: usize = 0,
    role: AssetRole = .atlas,
};

const FrameAssets = struct {
    slots: [asset_table_slots]AssetView = @splat(.{}),
    count: usize = 0,
    bytes: usize = 0,

    fn add(self: *FrameAssets, role: AssetRole, bytes: []const u8, limits: Limits) DrawError!void {
        if (bytes.len == 0) return;
        const address = @intFromPtr(bytes.ptr);
        const length = bytes.len;
        // Hash explicit scalar fields, never struct padding. Slot placement
        // cannot change equality, charging or the supported unique-view count.
        var hash = std.hash.Wyhash.init(@backingInt(role));
        hash.update(std.mem.asBytes(&address));
        hash.update(std.mem.asBytes(&length));
        var index = @as(usize, @truncate(hash.final())) & (asset_table_slots - 1);
        for (0..asset_table_slots) |_| {
            const slot = &self.slots[index];
            if (slot.address == 0) {
                if (self.count >= limits.max_asset_views) return error.AssetViewLimitExceeded;
                const total = std.math.add(usize, self.bytes, length) catch return error.AssetLimitExceeded;
                if (total > limits.max_asset_bytes) return error.AssetLimitExceeded;
                slot.* = .{ .address = address, .length = length, .role = role };
                self.count += 1;
                self.bytes = total;
                return;
            }
            if (slot.address == address and slot.length == length and slot.role == role) return;
            index = (index + 1) & (asset_table_slots - 1);
        }
        // Keep even an unexpected full-table probe deterministic and bounded.
        return error.AssetViewLimitExceeded;
    }

    fn bitmap(self: *FrameAssets, image: graphics.Bitmap, tint: Tint, limits: Limits) DrawError!void {
        try self.add(.atlas, image.pixels, limits);
        if (tint.mask) |mask| try self.add(.mask, mask, limits);
    }
};

/// A borrowed frame executes commands in slice order. Preflight covers every
/// command before writing, with aggregate unique typed-view bytes, text bytes,
/// clipped pixel-work and command-count budgets. The fixed metadata table is
/// frame-local, has no allocator and retains no source pointers after return.
pub fn drawFrame(canvas: *graphics.Canvas, commands: []const Command, limits: Limits) DrawError!void {
    if (limits.max_asset_views > max_supported_asset_views) return error.InvalidAssetViewLimit;
    if (commands.len > limits.max_commands) return error.FrameLimitExceeded;
    if (overlaps(canvas, std.mem.sliceAsBytes(commands))) return error.AliasedInput;
    var assets = FrameAssets{};
    var work: usize = 0;
    var text_bytes: usize = 0;
    for (commands) |command| {
        const pixels = switch (command) {
            .sprite => |sprite| blk: {
                const prepared = try prepareSprite(canvas, sprite, limits);
                try assets.bitmap(sprite.bitmap, sprite.tint, limits);
                break :blk prepared.bounds.pixels();
            },
            .triangle => |triangle| blk: {
                const prepared = try prepareTriangle(canvas, triangle, limits);
                try assets.bitmap(triangle.bitmap, triangle.tint, limits);
                break :blk prepared.bounds.pixels();
            },
            .text => |text| blk: {
                const prepared = try prepareText(canvas, text, limits);
                text_bytes = std.math.add(usize, text_bytes, text.text.len) catch return error.FrameLimitExceeded;
                if (text_bytes > limits.max_text_bytes) return error.FrameLimitExceeded;
                const glyph_bytes = std.math.mul(usize, text.font.glyphs.len, @sizeOf(Glyph)) catch return error.AssetLimitExceeded;
                try assets.bitmap(text.font.bitmap, text.tint, limits);
                try assets.add(.glyphs, std.mem.sliceAsBytes(text.font.glyphs)[0..glyph_bytes], limits);
                break :blk prepared;
            },
        };
        work = std.math.add(usize, work, pixels) catch return error.FrameLimitExceeded;
        if (work > limits.max_covered_pixels) return error.FrameLimitExceeded;
    }
    for (commands) |command| switch (command) {
        .sprite => |sprite| try drawSprite(canvas, sprite, limits),
        .triangle => |triangle| try drawTriangle(canvas, triangle, limits),
        .text => |text| try drawText(canvas, text, limits),
    };
}
