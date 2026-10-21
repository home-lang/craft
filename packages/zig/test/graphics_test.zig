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
