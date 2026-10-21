const std = @import("std");
const testing = std.testing;
const graphics = @import("../src/graphics.zig");

test "standalone raster core rejects allocations above the caller's budget" {
    try testing.expectError(error.AllocationLimitExceeded, graphics.Canvas.initWithLimits(testing.allocator, 3, 2, .{ .max_pixels = 5 }));
    var canvas = try graphics.Canvas.initWithLimits(testing.allocator, 3, 2, .{ .max_pixels = 6 });
    defer canvas.deinit();
    try testing.expectEqual(@as(usize, 6), canvas.pixels.len);
    try testing.expectError(error.AllocationLimitExceeded, graphics.Canvas.init(testing.allocator, 65536, 65536));
}

test "borrowed RGBA input cannot alias the writable frame" {
    var canvas = try graphics.Canvas.init(testing.allocator, 2, 1);
    defer canvas.deinit();
    canvas.clear(graphics.Color.rgb(10, 20, 30));
    const borrowed = std.mem.sliceAsBytes(canvas.pixels);
    try testing.expectError(error.AliasedBitmap, canvas.drawBitmap(.{ .width = 2, .height = 1, .pixels = borrowed }, .{ .x = 0, .y = 0, .width = 1, .height = 1 }, .{ .x = 1, .y = 0 }));
    try testing.expectEqualSlices(u32, &.{ 0xFF0A141E, 0xFF0A141E }, canvas.pixels);
}

test "standalone shapes replace exact clipped pixels and preserve alpha" {
    var canvas = try graphics.Canvas.init(testing.allocator, 3, 3);
    defer canvas.deinit();
    canvas.clear(graphics.Color.rgba(0, 0, 0, 0));
    canvas.drawRect(.{ .x = -1, .y = -1, .width = 2, .height = 2 }, graphics.Color.rgba(255, 0, 0, 128));
    canvas.drawCircle(.{ .x = 2, .y = 2 }, 1, graphics.Color.rgb(0, 255, 0));
    canvas.drawLine(.{ .x = 0, .y = 0 }, .{ .x = 2, .y = 1 }, graphics.Color.rgb(0, 0, 255));
    try testing.expectEqualSlices(u32, &.{ 0xFF0000FF, 0xFF0000FF, 0, 0, 0, 0xFF0000FF, 0, 0xFF00FF00, 0xFF00FF00 }, canvas.pixels);
    canvas.drawRect(.{ .x = 0, .y = 0, .width = 1, .height = 1 }, graphics.Color.rgba(255, 0, 0, 128));
    try testing.expectEqual(@as(u32, 0x80FF0000), canvas.pixels[0]);
}

test "directed Bresenham ties stay exact for shallow, steep and reversed lines" {
    const cases = [_]struct { from: graphics.Point, to: graphics.Point, pixels: [9]u32 }{
        .{ .from = .{ .x = 0, .y = 0 }, .to = .{ .x = 2, .y = 1 }, .pixels = .{ 1, 1, 0, 0, 0, 1, 0, 0, 0 } },
        .{ .from = .{ .x = 2, .y = 1 }, .to = .{ .x = 0, .y = 0 }, .pixels = .{ 1, 0, 0, 0, 1, 1, 0, 0, 0 } },
        .{ .from = .{ .x = 0, .y = 0 }, .to = .{ .x = 1, .y = 2 }, .pixels = .{ 1, 0, 0, 1, 0, 0, 0, 1, 0 } },
        .{ .from = .{ .x = 1, .y = 2 }, .to = .{ .x = 0, .y = 0 }, .pixels = .{ 1, 0, 0, 0, 1, 0, 0, 1, 0 } },
        .{ .from = .{ .x = 2, .y = 0 }, .to = .{ .x = 0, .y = 1 }, .pixels = .{ 0, 1, 1, 1, 0, 0, 0, 0, 0 } },
        .{ .from = .{ .x = 0, .y = 2 }, .to = .{ .x = 1, .y = 0 }, .pixels = .{ 0, 1, 0, 1, 0, 0, 1, 0, 0 } },
    };
    var canvas = try graphics.Canvas.init(testing.allocator, 3, 3);
    defer canvas.deinit();
    for (cases) |case| {
        canvas.clear(graphics.Color.rgba(0, 0, 0, 0));
        canvas.drawLine(case.from, case.to, graphics.Color.rgba(0, 0, 1, 0));
        try testing.expectEqualSlices(u32, &case.pixels, canvas.pixels);
    }
}

test "RGBA source-over is exact on translucent destinations and borrows synchronously" {
    var canvas = try graphics.Canvas.init(testing.allocator, 1, 1);
    defer canvas.deinit();
    canvas.clear(graphics.Color.rgba(0, 0, 255, 128));
    var pixels = [_]u8{ 255, 0, 0, 128 };
    try canvas.drawBitmap(.{ .width = 1, .height = 1, .pixels = &pixels }, .{ .x = 0, .y = 0, .width = 1, .height = 1 }, .{ .x = 0, .y = 0 });
    try testing.expectEqual(@as(u32, 0xC0AA0055), canvas.pixels[0]);
    @memset(&pixels, 0);
    try testing.expectEqual(@as(u32, 0xC0AA0055), canvas.pixels[0]);
}

test "unsupported text fails without changing the retained frame" {
    var canvas = try graphics.Canvas.init(testing.allocator, 1, 1);
    defer canvas.deinit();
    canvas.clear(graphics.Color.rgb(10, 20, 30));
    try testing.expectError(error.TextRenderingUnavailable, canvas.drawText("visible", .{ .x = 0, .y = 0 }, .{ .family = "system", .size = 14 }, graphics.Color.rgb(255, 0, 0)));
    try testing.expectEqual(@as(u32, 0xFF0A141E), canvas.pixels[0]);
}

fn createStandaloneCanvas(allocator: std.mem.Allocator) !void {
    var canvas = try graphics.Canvas.init(allocator, 2, 2);
    defer canvas.deinit();
    canvas.clear(graphics.Color.rgb(10, 20, 30));
}

test "standalone canvas releases allocations on every failure path" {
    try testing.checkAllAllocationFailures(testing.allocator, createStandaloneCanvas, .{});
}

test "transformed atlas sprites clip pixels and tint only the player mask" {
    var canvas = try graphics.Canvas.init(std.testing.allocator, 4, 2);
    defer canvas.deinit();
    canvas.clear(graphics.Color.rgba(0, 0, 0, 0));
    const atlas = [_]u8{ 255, 255, 255, 255, 0, 0, 255, 255 };
    const mask = [_]u8{ 255, 0 };
    try graphics.scene.drawSprite(&canvas, .{
        .bitmap = .{ .width = 2, .height = 1, .pixels = &atlas },
        .source = .{ .x = 0, .y = 0, .width = 2, .height = 1 },
        .transform = .{ .a = 2, .d = 2 },
        .tint = .{ .color = graphics.Color.rgb(255, 0, 0), .mask = &mask },
        .clip = .{ .x = 1, .y = 0, .width = 2, .height = 1 },
    }, .{});
    try std.testing.expectEqualSlices(u32, &.{ 0, 0xFFFF0000, 0xFF0000FF, 0, 0, 0, 0, 0 }, canvas.pixels);
}

test "textured terrain triangles cover a shared edge exactly once" {
    var canvas = try graphics.Canvas.init(testing.allocator, 2, 2);
    defer canvas.deinit();
    canvas.clear(graphics.Color.rgba(0, 0, 0, 0));
    const atlas = [_]u8{ 255, 255, 255, 128 };
    const bitmap = graphics.Bitmap{ .width = 1, .height = 1, .pixels = &atlas };
    try graphics.scene.drawTriangle(&canvas, .{ .bitmap = bitmap, .vertices = .{
        .{ .x = 0, .y = 0, .u = 0, .v = 0 },
        .{ .x = 2, .y = 0, .u = 1, .v = 0 },
        .{ .x = 0, .y = 2, .u = 0, .v = 1 },
    } }, .{});
    // The second triangle deliberately has the opposite winding.
    try graphics.scene.drawTriangle(&canvas, .{ .bitmap = bitmap, .vertices = .{
        .{ .x = 2, .y = 2, .u = 1, .v = 1 },
        .{ .x = 2, .y = 0, .u = 1, .v = 0 },
        .{ .x = 0, .y = 2, .u = 0, .v = 1 },
    } }, .{});
    try testing.expectEqualSlices(u32, &.{ 0x80FFFFFF, 0x80FFFFFF, 0x80FFFFFF, 0x80FFFFFF }, canvas.pixels);
}

test "bitmap-font text produces glyph pixels and newline placement" {
    var canvas = try graphics.Canvas.init(testing.allocator, 3, 2);
    defer canvas.deinit();
    canvas.clear(graphics.Color.rgba(0, 0, 0, 0));
    const atlas = [_]u8{ 255, 255, 255, 255 };
    const glyphs = [_]graphics.scene.Glyph{
        .{ .codepoint = 'A', .source = .{ .x = 0, .y = 0, .width = 1, .height = 1 }, .advance = 1 },
        .{ .codepoint = 'B', .source = .{ .x = 0, .y = 0, .width = 1, .height = 1 }, .advance = 1 },
    };
    try graphics.scene.drawText(&canvas, .{
        .font = .{ .bitmap = .{ .width = 1, .height = 1, .pixels = &atlas }, .glyphs = &glyphs, .line_height = 1 },
        .text = "A\nB",
        .transform = .{ .tx = 1 },
        .tint = .{ .color = graphics.Color.rgb(0, 255, 0) },
    }, .{});
    try testing.expectEqualSlices(u32, &.{ 0, 0xFF00FF00, 0, 0, 0xFF00FF00, 0 }, canvas.pixels);
}

test "ordered frames reject a later invalid command before any pixel writes" {
    var canvas = try graphics.Canvas.init(testing.allocator, 1, 1);
    defer canvas.deinit();
    canvas.clear(graphics.Color.rgb(0, 0, 0));
    const red = [_]u8{ 255, 0, 0, 255 };
    const bitmap = graphics.Bitmap{ .width = 1, .height = 1, .pixels = &red };
    const commands = [_]graphics.scene.Command{
        .{ .sprite = .{ .bitmap = bitmap, .source = .{ .x = 0, .y = 0, .width = 1, .height = 1 } } },
        .{ .triangle = .{ .bitmap = bitmap, .vertices = .{
            .{ .x = 0, .y = 0, .u = 0, .v = 0 },
            .{ .x = 2, .y = 0, .u = 2, .v = 0 },
            .{ .x = 0, .y = 2, .u = 0, .v = 1 },
        } } },
    };
    try testing.expectError(error.InvalidUV, graphics.scene.drawFrame(&canvas, &commands, .{}));
    try testing.expectEqual(@as(u32, 0xFF000000), canvas.pixels[0]);
}

test "ordered frames composite repeatably without allocating frame storage" {
    var failing = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 1 });
    var canvas = try graphics.Canvas.init(failing.allocator(), 1, 1);
    defer canvas.deinit();
    const red = [_]u8{ 255, 0, 0, 255 };
    const blue = [_]u8{ 0, 0, 255, 128 };
    const region = graphics.Rect{ .x = 0, .y = 0, .width = 1, .height = 1 };
    const commands = [_]graphics.scene.Command{
        .{ .sprite = .{ .bitmap = .{ .width = 1, .height = 1, .pixels = &red }, .source = region } },
        .{ .sprite = .{ .bitmap = .{ .width = 1, .height = 1, .pixels = &blue }, .source = region } },
    };
    for (0..4) |_| {
        canvas.clear(graphics.Color.rgb(0, 0, 0));
        try graphics.scene.drawFrame(&canvas, &commands, .{});
        try testing.expectEqual(@as(u32, 0xFF7F0080), canvas.pixels[0]);
    }
    const unchanged = canvas.pixels[0];
    try testing.expectError(error.FrameLimitExceeded, graphics.scene.drawFrame(&canvas, &commands, .{ .max_commands = 1 }));
    try testing.expectError(error.FrameLimitExceeded, graphics.scene.drawFrame(&canvas, &commands, .{ .max_covered_pixels = 1 }));
    try testing.expectError(error.AssetLimitExceeded, graphics.scene.drawFrame(&canvas, &commands, .{ .max_asset_bytes = 7 }));
    try testing.expectEqual(unchanged, canvas.pixels[0]);
}

test "sprites reject invalid transforms, UV bounds, masks, aliases and asset budgets before writes" {
    var canvas = try graphics.Canvas.init(testing.allocator, 2, 1);
    defer canvas.deinit();
    const atlas = [_]u8{ 255, 0, 0, 255 };
    const sprite = graphics.scene.Sprite{ .bitmap = .{ .width = 1, .height = 1, .pixels = &atlas }, .source = .{ .x = 0, .y = 0, .width = 1, .height = 1 } };
    var invalid = sprite;
    invalid.transform.a = std.math.nan(f64);
    try testing.expectError(error.InvalidTransform, graphics.scene.drawSprite(&canvas, invalid, .{}));
    invalid.transform = .{ .a = 0 };
    try testing.expectError(error.InvalidTransform, graphics.scene.drawSprite(&canvas, invalid, .{}));
    invalid = sprite;
    invalid.source.width = 2;
    try testing.expectError(error.InvalidSourceRect, graphics.scene.drawSprite(&canvas, invalid, .{}));
    invalid = sprite;
    invalid.tint.mask = &.{};
    try testing.expectError(error.InvalidTintMask, graphics.scene.drawSprite(&canvas, invalid, .{}));
    invalid.tint.mask = std.mem.sliceAsBytes(canvas.pixels)[0..1];
    try testing.expectError(error.AliasedInput, graphics.scene.drawSprite(&canvas, invalid, .{}));
    invalid = sprite;
    invalid.bitmap.pixels = std.mem.sliceAsBytes(canvas.pixels)[0..4];
    try testing.expectError(error.AliasedBitmap, graphics.scene.drawSprite(&canvas, invalid, .{}));
    try testing.expectError(error.AssetLimitExceeded, graphics.scene.drawSprite(&canvas, sprite, .{ .max_asset_bytes = 3 }));
    try testing.expectEqualSlices(u32, &.{ 0xFFFFFFFF, 0xFFFFFFFF }, canvas.pixels);
}

test "sprite mirroring and rotation preserve atlas sampling" {
    var canvas = try graphics.Canvas.init(testing.allocator, 2, 2);
    defer canvas.deinit();
    canvas.clear(graphics.Color.rgba(0, 0, 0, 0));
    const atlas = [_]u8{ 255, 0, 0, 255, 0, 0, 255, 255 };
    var sprite = graphics.scene.Sprite{ .bitmap = .{ .width = 2, .height = 1, .pixels = &atlas }, .source = .{ .x = 0, .y = 0, .width = 2, .height = 1 }, .transform = .{ .a = -1, .tx = 2 } };
    try graphics.scene.drawSprite(&canvas, sprite, .{});
    try testing.expectEqualSlices(u32, &.{ 0xFF0000FF, 0xFFFF0000, 0, 0 }, canvas.pixels);
    canvas.clear(graphics.Color.rgba(0, 0, 0, 0));
    sprite.transform = .{ .a = 0, .b = 1, .c = -1, .d = 0, .tx = 1 };
    try graphics.scene.drawSprite(&canvas, sprite, .{});
    try testing.expectEqualSlices(u32, &.{ 0xFFFF0000, 0, 0xFF0000FF, 0 }, canvas.pixels);
}

test "invalid bitmap fonts, UTF-8 and missing glyphs never leave partial text" {
    var canvas = try graphics.Canvas.init(testing.allocator, 2, 1);
    defer canvas.deinit();
    const atlas = [_]u8{ 255, 255, 255, 255 };
    const glyphs = [_]graphics.scene.Glyph{.{ .codepoint = 'A', .source = .{ .x = 0, .y = 0, .width = 1, .height = 1 }, .advance = 1 }};
    const text = graphics.scene.Text{ .font = .{ .bitmap = .{ .width = 1, .height = 1, .pixels = &atlas }, .glyphs = &glyphs, .line_height = 1 }, .text = "AA" };
    var invalid = text;
    invalid.text = "A\xff";
    try testing.expectError(error.InvalidText, graphics.scene.drawText(&canvas, invalid, .{}));
    invalid.text = "AZ";
    try testing.expectError(error.MissingGlyph, graphics.scene.drawText(&canvas, invalid, .{}));
    invalid = text;
    invalid.font.line_height = 0;
    try testing.expectError(error.InvalidFont, graphics.scene.drawText(&canvas, invalid, .{}));
    invalid = text;
    const duplicate = [_]graphics.scene.Glyph{ glyphs[0], glyphs[0] };
    invalid.font.glyphs = &duplicate;
    try testing.expectError(error.InvalidFont, graphics.scene.drawText(&canvas, invalid, .{}));
    var bad_glyphs = glyphs;
    bad_glyphs[0].source.width = 2;
    invalid.font.glyphs = &bad_glyphs;
    try testing.expectError(error.InvalidFont, graphics.scene.drawText(&canvas, invalid, .{}));
    try testing.expectError(error.AssetLimitExceeded, graphics.scene.drawText(&canvas, text, .{ .max_font_glyphs = 0 }));
    try testing.expectError(error.FrameLimitExceeded, graphics.scene.drawText(&canvas, text, .{ .max_text_bytes = 1 }));
    try testing.expectEqualSlices(u32, &.{ 0xFFFFFFFF, 0xFFFFFFFF }, canvas.pixels);
}

test "terrain UV interpolation samples the actual two-by-two atlas" {
    var canvas = try graphics.Canvas.init(testing.allocator, 2, 2);
    defer canvas.deinit();
    const atlas = [_]u8{ 255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255 };
    const bitmap = graphics.Bitmap{ .width = 2, .height = 2, .pixels = &atlas };
    try graphics.scene.drawTriangle(&canvas, .{ .bitmap = bitmap, .vertices = .{
        .{ .x = 0, .y = 0, .u = 0, .v = 0 }, .{ .x = 2, .y = 0, .u = 1, .v = 0 }, .{ .x = 0, .y = 2, .u = 0, .v = 1 },
    } }, .{});
    try graphics.scene.drawTriangle(&canvas, .{ .bitmap = bitmap, .vertices = .{
        .{ .x = 2, .y = 0, .u = 1, .v = 0 }, .{ .x = 2, .y = 2, .u = 1, .v = 1 }, .{ .x = 0, .y = 2, .u = 0, .v = 1 },
    } }, .{});
    try testing.expectEqualSlices(u32, &.{ 0xFFFF0000, 0xFF00FF00, 0xFF0000FF, 0xFFFFFFFF }, canvas.pixels);
}

test "triangle validation rejects nonfinite and degenerate inputs while extreme geometry stays clipped" {
    var canvas = try graphics.Canvas.init(testing.allocator, 2, 2);
    defer canvas.deinit();
    const atlas = [_]u8{ 255, 0, 0, 255 };
    const triangle = graphics.scene.Triangle{ .bitmap = .{ .width = 1, .height = 1, .pixels = &atlas }, .vertices = .{
        .{ .x = -1_000_000_000, .y = -1_000_000_000, .u = 0, .v = 0 },
        .{ .x = 1_000_000_000, .y = -1_000_000_000, .u = 1, .v = 0 },
        .{ .x = 0, .y = 1_000_000_000, .u = 0.5, .v = 1 },
    } };
    var invalid = triangle;
    invalid.vertices[0].u = std.math.nan(f64);
    try testing.expectError(error.InvalidUV, graphics.scene.drawTriangle(&canvas, invalid, .{}));
    invalid = triangle;
    invalid.vertices[1] = invalid.vertices[0];
    try testing.expectError(error.InvalidTriangle, graphics.scene.drawTriangle(&canvas, invalid, .{}));
    invalid = triangle;
    invalid.vertices[0].x = std.math.inf(f64);
    try testing.expectError(error.InvalidTriangle, graphics.scene.drawTriangle(&canvas, invalid, .{}));
    try testing.expectEqualSlices(u32, &.{ 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF }, canvas.pixels);
    try graphics.scene.drawTriangle(&canvas, triangle, .{ .max_covered_pixels = 4 });
    try testing.expectEqualSlices(u32, &.{ 0xFFFF0000, 0xFFFF0000, 0xFFFF0000, 0xFFFF0000 }, canvas.pixels);
}

test "atlas subregions index the player mask in full-atlas coordinates" {
    var canvas = try graphics.Canvas.init(testing.allocator, 1, 1);
    defer canvas.deinit();
    const atlas = [_]u8{ 255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255 };
    const mask = [_]u8{ 0, 0, 0, 255 };
    try graphics.scene.drawSprite(&canvas, .{
        .bitmap = .{ .width = 2, .height = 2, .pixels = &atlas },
        .source = .{ .x = 1, .y = 1, .width = 1, .height = 1 },
        .tint = .{ .color = graphics.Color.rgb(0, 255, 0), .mask = &mask },
    }, .{});
    try testing.expectEqual(@as(u32, 0xFF00FF00), canvas.pixels[0]);
}

test "bitmap text handles Unicode and enforces aggregate frame text budgets" {
    var canvas = try graphics.Canvas.init(testing.allocator, 1, 1);
    defer canvas.deinit();
    const atlas = [_]u8{ 255, 255, 255, 255 };
    const glyphs = [_]graphics.scene.Glyph{.{ .codepoint = 0x03BB, .source = .{ .x = 0, .y = 0, .width = 1, .height = 1 }, .advance = 1 }};
    const text = graphics.scene.Text{ .font = .{ .bitmap = .{ .width = 1, .height = 1, .pixels = &atlas }, .glyphs = &glyphs, .line_height = 1 }, .text = "\xce\xbb", .tint = .{ .color = graphics.Color.rgb(255, 0, 0) } };
    try graphics.scene.drawText(&canvas, text, .{});
    try testing.expectEqual(@as(u32, 0xFFFF0000), canvas.pixels[0]);
    const commands = [_]graphics.scene.Command{ .{ .text = text }, .{ .text = text } };
    try testing.expectError(error.FrameLimitExceeded, graphics.scene.drawFrame(&canvas, &commands, .{ .max_text_bytes = 3 }));
    try testing.expectEqual(@as(u32, 0xFFFF0000), canvas.pixels[0]);
}

test "finite inverse coefficients cannot leave partial pixels or trap on NaN evaluation" {
    var canvas = try graphics.Canvas.init(testing.allocator, 4, 4);
    defer canvas.deinit();
    canvas.clear(graphics.Color.rgb(0, 0, 0));
    const atlas: [64]u8 = @splat(255);
    const sprite = graphics.scene.Sprite{
        .bitmap = .{ .width = 4, .height = 4, .pixels = &atlas },
        .source = .{ .x = 0, .y = 0, .width = 4, .height = 4 },
        .transform = .{ .a = 1e-308, .c = 1 },
    };
    try testing.expectError(error.InvalidTransform, graphics.scene.drawSprite(&canvas, sprite, .{}));
    const commands = [_]graphics.scene.Command{.{ .sprite = sprite }};
    try testing.expectError(error.InvalidTransform, graphics.scene.drawFrame(&canvas, &commands, .{}));
    const glyphs = [_]graphics.scene.Glyph{.{ .codepoint = 'A', .source = sprite.source, .advance = 4 }};
    const text = graphics.scene.Text{ .font = .{ .bitmap = sprite.bitmap, .glyphs = &glyphs, .line_height = 4 }, .text = "A", .transform = sprite.transform };
    try testing.expectError(error.InvalidTransform, graphics.scene.drawText(&canvas, text, .{}));
    for (canvas.pixels) |pixel| try testing.expectEqual(@as(u32, 0xFF000000), pixel);
}

test "fractional shared edges remain watertight in either winding and command order" {
    var canvas = try graphics.Canvas.init(testing.allocator, 1, 1);
    defer canvas.deinit();
    const atlas = [_]u8{ 255, 255, 255, 128 };
    const bitmap = graphics.Bitmap{ .width = 1, .height = 1, .pixels = &atlas };
    const a = graphics.scene.Vertex{ .x = 0.1, .y = 0.2, .u = 0, .v = 0 };
    const b = graphics.scene.Vertex{ .x = 1.3, .y = 1.1, .u = 1, .v = 0 };
    for ([_]bool{ false, true }) |reverse| {
        for ([_]bool{ false, true }) |swap_order| {
            var triangles = [_]graphics.scene.Triangle{
                .{ .bitmap = bitmap, .vertices = .{ a, b, .{ .x = 0, .y = 2, .u = 0, .v = 1 } } },
                .{ .bitmap = bitmap, .vertices = .{ b, a, .{ .x = 2, .y = 0, .u = 1, .v = 1 } } },
            };
            if (reverse) for (&triangles) |*triangle| std.mem.swap(graphics.scene.Vertex, &triangle.vertices[1], &triangle.vertices[2]);
            const first: usize = if (swap_order) 1 else 0;
            const last = 1 - first;
            canvas.clear(graphics.Color.rgba(0, 0, 0, 0));
            try graphics.scene.drawTriangle(&canvas, triangles[first], .{});
            try graphics.scene.drawTriangle(&canvas, triangles[last], .{});
            try testing.expectEqual(@as(u32, 0x80FFFFFF), canvas.pixels[0]);
            const commands = [_]graphics.scene.Command{ .{ .triangle = triangles[first] }, .{ .triangle = triangles[last] } };
            canvas.clear(graphics.Color.rgba(0, 0, 0, 0));
            try graphics.scene.drawFrame(&canvas, &commands, .{});
            try testing.expectEqual(@as(u32, 0x80FFFFFF), canvas.pixels[0]);
        }
    }
}
