const std = @import("std");
const components = @import("components");
const ColorPicker = components.ColorPicker;
const Color = ColorPicker.Color;
const HSL = ColorPicker.HSL;
const ComponentProps = components.ComponentProps;

var changed_color: ?Color = null;

fn handleChange(color: Color) void {
    changed_color = color;
}

test "color picker creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const picker = try ColorPicker.init(allocator, props);
    defer picker.deinit();

    try std.testing.expect(picker.color.r == 0);
    try std.testing.expect(picker.color.g == 0);
    try std.testing.expect(picker.color.b == 0);
    try std.testing.expect(picker.presets.items.len == 8); // Default presets
}

test "color from RGB" {
    const color = Color.fromRGB(255, 128, 64);

    try std.testing.expect(color.r == 255);
    try std.testing.expect(color.g == 128);
    try std.testing.expect(color.b == 64);
    try std.testing.expect(color.a == 255);
}

test "color from hex" {
    const color = try Color.fromHex("FF8040");

    try std.testing.expect(color.r == 255);
    try std.testing.expect(color.g == 128);
    try std.testing.expect(color.b == 64);

    const color_alpha = try Color.fromHex("FF8040C0");
    try std.testing.expect(color_alpha.a == 192);
}

test "color to hex" {
    const allocator = std.testing.allocator;
    const color = Color.fromRGB(255, 128, 64);

    const hex = try color.toHex(allocator, false);
    defer allocator.free(hex);

    try std.testing.expectEqualStrings("FF8040", hex);
}

test "color to hex with alpha" {
    const allocator = std.testing.allocator;
    const color = Color.fromRGBA(255, 128, 64, 192);

    const hex = try color.toHex(allocator, true);
    defer allocator.free(hex);

    try std.testing.expectEqualStrings("FF8040C0", hex);
}

test "color picker set color" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const picker = try ColorPicker.init(allocator, props);
    defer picker.deinit();

    changed_color = null;
    picker.onChange(&handleChange);

    const color = Color.fromRGB(255, 0, 0);
    picker.setColor(color);

    try std.testing.expect(picker.color.r == 255);
    try std.testing.expect(changed_color != null);
}

test "color picker set from hex" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const picker = try ColorPicker.init(allocator, props);
    defer picker.deinit();

    try picker.setColorFromHex("00FF00");

    try std.testing.expect(picker.color.r == 0);
    try std.testing.expect(picker.color.g == 255);
    try std.testing.expect(picker.color.b == 0);
}

test "color picker set from RGB" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const picker = try ColorPicker.init(allocator, props);
    defer picker.deinit();

    picker.setColorFromRGB(0, 0, 255);

    try std.testing.expect(picker.color.r == 0);
    try std.testing.expect(picker.color.g == 0);
    try std.testing.expect(picker.color.b == 255);
}

test "color to HSL conversion" {
    const color = Color.fromRGB(255, 0, 0); // Pure red
    const hsl = color.toHSL();

    try std.testing.expect(@abs(hsl.h - 0.0) < 1.0); // Hue ~0
    try std.testing.expect(@abs(hsl.s - 1.0) < 0.01); // Saturation ~1
    try std.testing.expect(@abs(hsl.l - 0.5) < 0.01); // Lightness ~0.5
}

test "HSL to RGB conversion" {
    const hsl = HSL{ .h = 0, .s = 1.0, .l = 0.5 }; // Pure red
    const color = hsl.toRGB();

    try std.testing.expect(color.r == 255);
    try std.testing.expect(color.g == 0);
    try std.testing.expect(color.b == 0);
}

test "color picker formats" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const picker = try ColorPicker.init(allocator, props);
    defer picker.deinit();

    picker.setColorFromRGB(255, 128, 64);

    // Hex format
    picker.setFormat(.hex);
    const hex_str = try picker.getColorString(allocator);
    defer allocator.free(hex_str);
    try std.testing.expectEqualStrings("FF8040", hex_str);

    // RGB format
    picker.setFormat(.rgb);
    const rgb_str = try picker.getColorString(allocator);
    defer allocator.free(rgb_str);
    try std.testing.expectEqualStrings("rgb(255,128,64)", rgb_str);
}

test "color picker presets" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const picker = try ColorPicker.init(allocator, props);
    defer picker.deinit();

    const initial_count = picker.presets.items.len;

    try picker.addPreset(Color.fromRGB(100, 100, 100));
    try std.testing.expect(picker.presets.items.len == initial_count + 1);

    picker.clearPresets();
    try std.testing.expect(picker.presets.items.len == 0);
}

test "color picker disabled state" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const picker = try ColorPicker.init(allocator, props);
    defer picker.deinit();

    picker.setDisabled(true);
    picker.setColor(Color.fromRGB(255, 0, 0));

    // Color should not change when disabled
    try std.testing.expect(picker.color.r == 0);
}

test "color equals" {
    const color1 = Color.fromRGB(255, 128, 64);
    const color2 = Color.fromRGB(255, 128, 64);
    const color3 = Color.fromRGB(255, 128, 65);

    try std.testing.expect(color1.equals(color2));
    try std.testing.expect(!color1.equals(color3));
}

test "color picker alpha channel" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const picker = try ColorPicker.init(allocator, props);
    defer picker.deinit();

    picker.setShowAlpha(true);
    picker.setColorFromRGBA(255, 128, 64, 128);

    try std.testing.expect(picker.color.a == 128);
}
