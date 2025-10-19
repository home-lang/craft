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
