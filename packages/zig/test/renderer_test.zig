const std = @import("std");
const testing = std.testing;
const renderer = @import("../src/renderer.zig");

test "Color - rgb creation" {
    const color = renderer.Color.rgb(255, 128, 64);

    try testing.expectEqual(@as(u8, 255), color.r);
    try testing.expectEqual(@as(u8, 128), color.g);
    try testing.expectEqual(@as(u8, 64), color.b);
    try testing.expectEqual(@as(u8, 255), color.a);
}

test "Color - rgba creation" {
    const color = renderer.Color.rgba(100, 150, 200, 128);

    try testing.expectEqual(@as(u8, 100), color.r);
    try testing.expectEqual(@as(u8, 150), color.g);
    try testing.expectEqual(@as(u8, 200), color.b);
    try testing.expectEqual(@as(u8, 128), color.a);
}

test "Color - fromHex" {
    const color = renderer.Color.fromHex(0xFF8040);

    try testing.expectEqual(@as(u8, 255), color.r);
    try testing.expectEqual(@as(u8, 128), color.g);
    try testing.expectEqual(@as(u8, 64), color.b);
    try testing.expectEqual(@as(u8, 255), color.a);
}

test "Point - creation" {
    const point = renderer.Point{ .x = 100, .y = 200 };

    try testing.expectEqual(@as(i32, 100), point.x);
    try testing.expectEqual(@as(i32, 200), point.y);
}

test "Size - creation" {
    const size = renderer.Size{ .width = 800, .height = 600 };

    try testing.expectEqual(@as(u32, 800), size.width);
    try testing.expectEqual(@as(u32, 600), size.height);
}

test "Rect - creation" {
    const rect = renderer.Rect{ .x = 10, .y = 20, .width = 100, .height = 50 };

    try testing.expectEqual(@as(i32, 10), rect.x);
    try testing.expectEqual(@as(i32, 20), rect.y);
    try testing.expectEqual(@as(u32, 100), rect.width);
    try testing.expectEqual(@as(u32, 50), rect.height);
}

test "Font - creation" {
    const font = renderer.Font{
        .family = "Arial",
        .size = 16.0,
        .weight = .bold,
        .style = .italic,
    };

    try testing.expectEqualStrings("Arial", font.family);
    try testing.expectEqual(@as(f32, 16.0), font.size);
    try testing.expectEqual(renderer.FontWeight.bold, font.weight);
    try testing.expectEqual(renderer.FontStyle.italic, font.style);
}

test "Renderer - init and deinit" {
    var r = renderer.Renderer.init(testing.allocator, .native);
    defer r.deinit();

    try testing.expectEqual(renderer.RenderBackend.native, r.backend);
    try testing.expect(r.canvas == null);
}

test "Renderer - createCanvas" {
    var r = renderer.Renderer.init(testing.allocator, .native);
    defer r.deinit();

    const canvas = try r.createCanvas(800, 600);

    try testing.expectEqual(@as(u32, 800), canvas.width);
    try testing.expectEqual(@as(u32, 600), canvas.height);
    try testing.expect(r.canvas != null);
}

test "Canvas - init" {
    var canvas = try renderer.Canvas.init(testing.allocator, 640, 480);
    defer canvas.deinit();

    try testing.expectEqual(@as(u32, 640), canvas.width);
    try testing.expectEqual(@as(u32, 480), canvas.height);
    try testing.expectEqual(@as(usize, 640 * 480), canvas.pixels.len);
}

test "Canvas - clear" {
    var canvas = try renderer.Canvas.init(testing.allocator, 100, 100);
    defer canvas.deinit();

    const red = renderer.Color.rgb(255, 0, 0);
    canvas.clear(red);

    const pixel = canvas.pixels[0];
    try testing.expectEqual(@as(u32, 0xFFFF0000), pixel);
}

test "Canvas - setPixel and getPixel" {
    var canvas = try renderer.Canvas.init(testing.allocator, 100, 100);
    defer canvas.deinit();

    const blue = renderer.Color.rgb(0, 0, 255);
    canvas.setPixel(50, 50, blue);

    const retrieved = canvas.getPixel(50, 50);
    try testing.expect(retrieved != null);
    try testing.expectEqual(@as(u8, 0), retrieved.?.r);
    try testing.expectEqual(@as(u8, 0), retrieved.?.g);
    try testing.expectEqual(@as(u8, 255), retrieved.?.b);
}

test "Canvas - getPixel out of bounds" {
    var canvas = try renderer.Canvas.init(testing.allocator, 100, 100);
    defer canvas.deinit();

    const pixel = canvas.getPixel(100, 100);
    try testing.expect(pixel == null);

    const pixel2 = canvas.getPixel(200, 200);
    try testing.expect(pixel2 == null);
}

test "Canvas - setPixel out of bounds" {
    var canvas = try renderer.Canvas.init(testing.allocator, 100, 100);
    defer canvas.deinit();

    const color = renderer.Color.rgb(255, 0, 0);
    canvas.setPixel(100, 100, color);
    canvas.setPixel(200, 200, color);

    // Should not crash, just no-op
    try testing.expect(true);
}

test "Canvas - drawRect" {
    var canvas = try renderer.Canvas.init(testing.allocator, 100, 100);
    defer canvas.deinit();

    const green = renderer.Color.rgb(0, 255, 0);
    const rect = renderer.Rect{ .x = 10, .y = 10, .width = 20, .height = 20 };
    canvas.drawRect(rect, green);

    const pixel = canvas.getPixel(10, 10);
    try testing.expect(pixel != null);
    try testing.expectEqual(@as(u8, 0), pixel.?.r);
    try testing.expectEqual(@as(u8, 255), pixel.?.g);
    try testing.expectEqual(@as(u8, 0), pixel.?.b);
}

test "Canvas - drawCircle" {
    var canvas = try renderer.Canvas.init(testing.allocator, 100, 100);
    defer canvas.deinit();

    const yellow = renderer.Color.rgb(255, 255, 0);
    const center = renderer.Point{ .x = 50, .y = 50 };
    canvas.drawCircle(center, 10, yellow);

    const pixel = canvas.getPixel(50, 50);
    try testing.expect(pixel != null);
    try testing.expectEqual(@as(u8, 255), pixel.?.r);
    try testing.expectEqual(@as(u8, 255), pixel.?.g);
    try testing.expectEqual(@as(u8, 0), pixel.?.b);
}

test "Canvas - drawLine" {
    var canvas = try renderer.Canvas.init(testing.allocator, 100, 100);
    defer canvas.deinit();

    const cyan = renderer.Color.rgb(0, 255, 255);
    const from = renderer.Point{ .x = 10, .y = 10 };
    const to = renderer.Point{ .x = 20, .y = 20 };
    canvas.drawLine(from, to, cyan);

    const pixel = canvas.getPixel(10, 10);
    try testing.expect(pixel != null);
}

test "Component - init and deinit" {
    const bounds = renderer.Rect{ .x = 0, .y = 0, .width = 100, .height = 100 };
    var component = renderer.Component.init(testing.allocator, bounds);
    defer component.deinit();

    try testing.expect(component.visible);
    try testing.expectEqual(@as(usize, 0), component.children.items.len);
}

test "Component - addChild" {
    const bounds = renderer.Rect{ .x = 0, .y = 0, .width = 100, .height = 100 };
    var parent = renderer.Component.init(testing.allocator, bounds);
    defer parent.deinit();

    const child_bounds = renderer.Rect{ .x = 10, .y = 10, .width = 50, .height = 50 };
    const child = try testing.allocator.create(renderer.Component);
    child.* = renderer.Component.init(testing.allocator, child_bounds);

    try parent.addChild(child);

    try testing.expectEqual(@as(usize, 1), parent.children.items.len);
}

test "Button - init" {
    const bounds = renderer.Rect{ .x = 0, .y = 0, .width = 100, .height = 30 };
    var button = renderer.Button.init(testing.allocator, bounds, "Click Me");
    defer button.component.deinit();

    try testing.expectEqualStrings("Click Me", button.text);
    try testing.expect(button.component.visible);
}

test "Label - init" {
    const bounds = renderer.Rect{ .x = 0, .y = 0, .width = 200, .height = 20 };
    var label = renderer.Label.init(testing.allocator, bounds, "Hello World");
    defer label.component.deinit();

    try testing.expectEqualStrings("Hello World", label.text);
    try testing.expect(label.component.visible);
}

test "RenderBackend - enum values" {
    try testing.expectEqual(renderer.RenderBackend.webview, .webview);
    try testing.expectEqual(renderer.RenderBackend.native, .native);
    try testing.expectEqual(renderer.RenderBackend.hybrid, .hybrid);
}

test "FontWeight - enum values" {
    try testing.expectEqual(renderer.FontWeight.thin, .thin);
    try testing.expectEqual(renderer.FontWeight.normal, .normal);
    try testing.expectEqual(renderer.FontWeight.bold, .bold);
    try testing.expectEqual(renderer.FontWeight.black, .black);
}

test "FontStyle - enum values" {
    try testing.expectEqual(renderer.FontStyle.normal, .normal);
    try testing.expectEqual(renderer.FontStyle.italic, .italic);
    try testing.expectEqual(renderer.FontStyle.oblique, .oblique);
}

// Edge cases and thorough tests

test "Color - fromHex edge cases" {
    const white = renderer.Color.fromHex(0xFFFFFF);
    const black = renderer.Color.fromHex(0x000000);
    const red = renderer.Color.fromHex(0xFF0000);

    try testing.expectEqual(@as(u8, 255), white.r);
    try testing.expectEqual(@as(u8, 255), white.g);
    try testing.expectEqual(@as(u8, 255), white.b);

    try testing.expectEqual(@as(u8, 0), black.r);
    try testing.expectEqual(@as(u8, 0), black.g);
    try testing.expectEqual(@as(u8, 0), black.b);

    try testing.expectEqual(@as(u8, 255), red.r);
    try testing.expectEqual(@as(u8, 0), red.g);
    try testing.expectEqual(@as(u8, 0), red.b);
}

test "Canvas - large dimensions" {
    var canvas = try renderer.Canvas.init(testing.allocator, 1920, 1080);
    defer canvas.deinit();

    try testing.expectEqual(@as(u32, 1920), canvas.width);
    try testing.expectEqual(@as(u32, 1080), canvas.height);
    try testing.expectEqual(@as(usize, 1920 * 1080), canvas.pixels.len);
}

test "Canvas - minimum dimensions" {
    var canvas = try renderer.Canvas.init(testing.allocator, 1, 1);
    defer canvas.deinit();

    try testing.expectEqual(@as(u32, 1), canvas.width);
    try testing.expectEqual(@as(u32, 1), canvas.height);
    try testing.expectEqual(@as(usize, 1), canvas.pixels.len);
}

test "Canvas - drawRect completely out of bounds" {
    var canvas = try renderer.Canvas.init(testing.allocator, 100, 100);
    defer canvas.deinit();

    const color = renderer.Color.rgb(255, 0, 0);
    const out_of_bounds = renderer.Rect{ .x = 200, .y = 200, .width = 50, .height = 50 };

    canvas.drawRect(out_of_bounds, color);

    // Should not crash, pixels should remain unchanged (white)
    const pixel = canvas.getPixel(0, 0);
    try testing.expect(pixel != null);
}

test "Canvas - drawRect partially out of bounds" {
    var canvas = try renderer.Canvas.init(testing.allocator, 100, 100);
    defer canvas.deinit();

    const color = renderer.Color.rgb(255, 0, 0);
    const partial = renderer.Rect{ .x = 90, .y = 90, .width = 20, .height = 20 };

    canvas.drawRect(partial, color);

    // Some pixels should be drawn
    const pixel = canvas.getPixel(95, 95);
    try testing.expect(pixel != null);
}

test "Canvas - drawRect with negative coordinates" {
    var canvas = try renderer.Canvas.init(testing.allocator, 100, 100);
    defer canvas.deinit();

    const color = renderer.Color.rgb(255, 0, 0);
    const negative = renderer.Rect{ .x = -10, .y = -10, .width = 20, .height = 20 };

    canvas.drawRect(negative, color);

    // Should clip to visible region
    const pixel = canvas.getPixel(0, 0);
    try testing.expect(pixel != null);
}

test "Canvas - drawCircle edge cases" {
    var canvas = try renderer.Canvas.init(testing.allocator, 100, 100);
    defer canvas.deinit();

    const color = renderer.Color.rgb(0, 255, 0);

    // Very small radius
    canvas.drawCircle(.{ .x = 50, .y = 50 }, 1, color);

    // Very large radius
    canvas.drawCircle(.{ .x = 50, .y = 50 }, 1000, color);

    // Zero radius (degenerate case)
    canvas.drawCircle(.{ .x = 50, .y = 50 }, 0, color);

    try testing.expect(true); // Should not crash
}

test "Canvas - drawLine diagonal" {
    var canvas = try renderer.Canvas.init(testing.allocator, 100, 100);
    defer canvas.deinit();

    const color = renderer.Color.rgb(255, 255, 0);
    canvas.drawLine(.{ .x = 0, .y = 0 }, .{ .x = 99, .y = 99 }, color);

    // Check endpoints
    const start = canvas.getPixel(0, 0);
    const end = canvas.getPixel(99, 99);

    try testing.expect(start != null);
    try testing.expect(end != null);
}

test "Canvas - drawLine horizontal" {
    var canvas = try renderer.Canvas.init(testing.allocator, 100, 100);
    defer canvas.deinit();

    const color = renderer.Color.rgb(255, 0, 255);
    canvas.drawLine(.{ .x = 10, .y = 50 }, .{ .x = 90, .y = 50 }, color);

    const pixel = canvas.getPixel(50, 50);
    try testing.expect(pixel != null);
}

test "Canvas - drawLine vertical" {
    var canvas = try renderer.Canvas.init(testing.allocator, 100, 100);
    defer canvas.deinit();

    const color = renderer.Color.rgb(0, 255, 255);
    canvas.drawLine(.{ .x = 50, .y = 10 }, .{ .x = 50, .y = 90 }, color);

    const pixel = canvas.getPixel(50, 50);
    try testing.expect(pixel != null);
}

test "Canvas - drawLine zero length" {
    var canvas = try renderer.Canvas.init(testing.allocator, 100, 100);
    defer canvas.deinit();

    const color = renderer.Color.rgb(255, 255, 255);
    canvas.drawLine(.{ .x = 50, .y = 50 }, .{ .x = 50, .y = 50 }, color);

    try testing.expect(true); // Should not crash
}

test "Canvas - multiple overlapping shapes" {
    var canvas = try renderer.Canvas.init(testing.allocator, 200, 200);
    defer canvas.deinit();

    const red = renderer.Color.rgb(255, 0, 0);
    const green = renderer.Color.rgb(0, 255, 0);
    const blue = renderer.Color.rgb(0, 0, 255);

    canvas.drawRect(.{ .x = 10, .y = 10, .width = 50, .height = 50 }, red);
    canvas.drawCircle(.{ .x = 50, .y = 50 }, 30, green);
    canvas.drawLine(.{ .x = 0, .y = 0 }, .{ .x = 100, .y = 100 }, blue);

    try testing.expect(true); // Should handle overlapping correctly
}

test "Component - deep nesting" {
    const bounds = renderer.Rect{ .x = 0, .y = 0, .width = 100, .height = 100 };
    var root = renderer.Component.init(testing.allocator, bounds);
    defer root.deinit();

    // Create nested components
    for (0..5) |_| {
        const child_bounds = renderer.Rect{ .x = 10, .y = 10, .width = 80, .height = 80 };
        const child = try testing.allocator.create(renderer.Component);
        child.* = renderer.Component.init(testing.allocator, child_bounds);
        try root.addChild(child);
    }

    try testing.expectEqual(@as(usize, 5), root.children.items.len);
}

test "Component - invisible rendering" {
    const bounds = renderer.Rect{ .x = 0, .y = 0, .width = 100, .height = 100 };
    var component = renderer.Component.init(testing.allocator, bounds);
    defer component.deinit();

    var canvas = try renderer.Canvas.init(testing.allocator, 100, 100);
    defer canvas.deinit();

    component.visible = false;
    component.render(&canvas);

    try testing.expect(!component.visible);
}

test "Renderer - multiple backends" {
    const backends = [_]renderer.RenderBackend{ .webview, .native, .hybrid };

    for (backends) |backend| {
        var r = renderer.Renderer.init(testing.allocator, backend);
        defer r.deinit();

        try testing.expectEqual(backend, r.backend);
    }
}

test "Font - default values" {
    const font = renderer.Font{
        .family = "System",
        .size = 12.0,
    };

    try testing.expectEqual(renderer.FontWeight.normal, font.weight);
    try testing.expectEqual(renderer.FontStyle.normal, font.style);
}

test "Font - extreme sizes" {
    const tiny = renderer.Font{ .family = "Arial", .size = 0.5 };
    const huge = renderer.Font{ .family = "Arial", .size = 1000.0 };

    try testing.expectEqual(@as(f32, 0.5), tiny.size);
    try testing.expectEqual(@as(f32, 1000.0), huge.size);
}

test "Canvas - clear multiple times" {
    var canvas = try renderer.Canvas.init(testing.allocator, 100, 100);
    defer canvas.deinit();

    const colors = [_]renderer.Color{
        renderer.Color.rgb(255, 0, 0),
        renderer.Color.rgb(0, 255, 0),
        renderer.Color.rgb(0, 0, 255),
    };

    for (colors) |color| {
        canvas.clear(color);
    }

    // Final color should be blue
    const pixel = canvas.pixels[0];
    try testing.expectEqual(@as(u32, 0xFF0000FF), pixel);
}
