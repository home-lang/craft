const std = @import("std");
const testing = std.testing;
const components = @import("../src/components.zig");

test "ComponentProps - default values" {
    const props = components.ComponentProps{};

    try testing.expectEqual(@as(i32, 0), props.x);
    try testing.expectEqual(@as(i32, 0), props.y);
    try testing.expectEqual(@as(u32, 100), props.width);
    try testing.expectEqual(@as(u32, 30), props.height);
    try testing.expect(props.enabled);
    try testing.expect(props.visible);
}

test "ComponentProps - custom values" {
    const props = components.ComponentProps{
        .x = 10,
        .y = 20,
        .width = 200,
        .height = 50,
        .enabled = false,
        .visible = false,
    };

    try testing.expectEqual(@as(i32, 10), props.x);
    try testing.expectEqual(@as(i32, 20), props.y);
    try testing.expectEqual(@as(u32, 200), props.width);
    try testing.expectEqual(@as(u32, 50), props.height);
    try testing.expect(!props.enabled);
    try testing.expect(!props.visible);
}

test "Style - default values" {
    const style = components.Style{};

    try testing.expectEqual(@as(?[4]u8, null), style.background_color);
    try testing.expectEqual(@as(?[4]u8, null), style.foreground_color);
    try testing.expectEqual(@as(?[4]u8, null), style.border_color);
    try testing.expectEqual(@as(u32, 0), style.border_width);
    try testing.expectEqual(@as(u32, 0), style.border_radius);
    try testing.expectEqual(@as(u32, 14), style.font_size);
    try testing.expectEqual(components.Style.FontWeight.regular, style.font_weight);
}

test "Style - with colors" {
    const style = components.Style{
        .background_color = .{ 255, 255, 255, 255 },
        .foreground_color = .{ 0, 0, 0, 255 },
        .border_color = .{ 128, 128, 128, 255 },
        .border_width = 2,
    };

    try testing.expectEqual(@as(u8, 255), style.background_color.?[0]);
    try testing.expectEqual(@as(u8, 0), style.foreground_color.?[0]);
    try testing.expectEqual(@as(u8, 128), style.border_color.?[0]);
    try testing.expectEqual(@as(u32, 2), style.border_width);
}

test "Style.FontWeight - all values" {
    try testing.expectEqual(components.Style.FontWeight.light, .light);
    try testing.expectEqual(components.Style.FontWeight.regular, .regular);
    try testing.expectEqual(components.Style.FontWeight.medium, .medium);
    try testing.expectEqual(components.Style.FontWeight.bold, .bold);
}

test "Style.Padding - default values" {
    const padding = components.Style.Padding{};

    try testing.expectEqual(@as(u32, 0), padding.top);
    try testing.expectEqual(@as(u32, 0), padding.right);
    try testing.expectEqual(@as(u32, 0), padding.bottom);
    try testing.expectEqual(@as(u32, 0), padding.left);
}

test "Style.Padding - custom values" {
    const padding = components.Style.Padding{
        .top = 10,
        .right = 20,
        .bottom = 10,
        .left = 20,
    };

    try testing.expectEqual(@as(u32, 10), padding.top);
    try testing.expectEqual(@as(u32, 20), padding.right);
    try testing.expectEqual(@as(u32, 10), padding.bottom);
    try testing.expectEqual(@as(u32, 20), padding.left);
}

test "Style.Margin - default values" {
    const margin = components.Style.Margin{};

    try testing.expectEqual(@as(u32, 0), margin.top);
    try testing.expectEqual(@as(u32, 0), margin.right);
    try testing.expectEqual(@as(u32, 0), margin.bottom);
    try testing.expectEqual(@as(u32, 0), margin.left);
}

test "Style.Margin - custom values" {
    const margin = components.Style.Margin{
        .top = 5,
        .right = 10,
        .bottom = 5,
        .left = 10,
    };

    try testing.expectEqual(@as(u32, 5), margin.top);
    try testing.expectEqual(@as(u32, 10), margin.right);
    try testing.expectEqual(@as(u32, 5), margin.bottom);
    try testing.expectEqual(@as(u32, 10), margin.left);
}

test "Button - initialization" {
    const allocator = testing.allocator;
    const props = components.ComponentProps{};
    var button = try components.Button.init(allocator, "Click Me", props);
    defer button.deinit();

    try testing.expectEqualStrings("Click Me", button.text);
}

test "TextInput - initialization" {
    const allocator = testing.allocator;
    const props = components.ComponentProps{};
    var textinput = try components.TextInput.init(allocator, props);
    defer textinput.deinit();

    try testing.expectEqualStrings("", textinput.value);
}

test "Label - initialization" {
    const allocator = testing.allocator;
    const props = components.ComponentProps{};
    var label = try components.Label.init(allocator, "Label Text", props);
    defer label.deinit();

    try testing.expectEqualStrings("Label Text", label.text);
}

test "Checkbox - initialization" {
    const allocator = testing.allocator;
    const props = components.ComponentProps{};
    var checkbox = try components.Checkbox.init(allocator, "Test Checkbox", props);
    defer checkbox.deinit();

    try testing.expect(!checkbox.checked);
}

test "Checkbox - toggle" {
    const allocator = testing.allocator;
    const props = components.ComponentProps{};
    var checkbox = try components.Checkbox.init(allocator, "Test Checkbox", props);
    defer checkbox.deinit();

    try testing.expect(!checkbox.checked);
    checkbox.toggle();
    try testing.expect(checkbox.checked);
    checkbox.toggle();
    try testing.expect(!checkbox.checked);
}

test "Slider - initialization" {
    const allocator = testing.allocator;
    const props = components.ComponentProps{};
    var slider = try components.Slider.init(allocator, props);
    defer slider.deinit();

    // Default values: min=0, max=100, value=0
    try testing.expectEqual(@as(f64, 0.0), slider.min);
    try testing.expectEqual(@as(f64, 100.0), slider.max);
    try testing.expectEqual(@as(f64, 0.0), slider.value);
}

test "Slider - setValue" {
    const allocator = testing.allocator;
    const props = components.ComponentProps{};
    var slider = try components.Slider.init(allocator, props);
    defer slider.deinit();

    try slider.setValue(50.0);
    try testing.expectEqual(@as(f64, 50.0), slider.value);
}

test "ProgressBar - initialization" {
    const allocator = testing.allocator;
    const props = components.ComponentProps{};
    var progress = try components.ProgressBar.init(allocator, props);
    defer progress.deinit();

    try testing.expectEqual(@as(f32, 0.0), progress.value);
    try testing.expectEqual(@as(f32, 100.0), progress.max);
}

test "ProgressBar - setValue" {
    const allocator = testing.allocator;
    const props = components.ComponentProps{};
    var progress = try components.ProgressBar.init(allocator, props);
    defer progress.deinit();

    progress.setValue(75.0);
    try testing.expectEqual(@as(f32, 75.0), progress.value);
}

test "ListView - initialization" {
    const allocator = testing.allocator;
    const props = components.ComponentProps{};
    const config = components.ListView.Config{};
    var list = try components.ListView.init(allocator, props, config);
    defer list.deinit();

    try testing.expectEqual(@as(usize, 0), list.items.items.len);
}

test "ListView - add item" {
    const allocator = testing.allocator;
    const props = components.ComponentProps{};
    const config = components.ListView.Config{};
    var list = try components.ListView.init(allocator, props, config);
    defer list.deinit();

    try list.addItem(.{ .text = "Item 1" });
    try testing.expectEqual(@as(usize, 1), list.items.items.len);
}

// Note: Table, TabView, ScrollView, ImageView tests removed as components not exported

test "RadioButton - initialization" {
    const allocator = testing.allocator;
    const props = components.ComponentProps{};
    var radio = try components.RadioButton.init(allocator, "Option 1", "option1", props);
    defer radio.deinit();

    try testing.expectEqualStrings("Option 1", radio.label);
    try testing.expectEqualStrings("option1", radio.value);
    try testing.expect(!radio.selected);
}

test "ColorPicker - initialization" {
    const allocator = testing.allocator;
    const props = components.ComponentProps{};
    var picker = try components.ColorPicker.init(allocator, props);
    defer picker.deinit();

    try testing.expectEqual(@as(u8, 255), picker.color[0]);
    try testing.expectEqual(@as(u8, 255), picker.color[1]);
    try testing.expectEqual(@as(u8, 255), picker.color[2]);
    try testing.expectEqual(@as(u8, 255), picker.color[3]);
}

test "Toolbar - initialization" {
    const allocator = testing.allocator;
    const props = components.ComponentProps{};
    var toolbar = try components.Toolbar.init(allocator, props);
    defer toolbar.deinit();

    try testing.expectEqual(@as(usize, 0), toolbar.items.items.len);
}

test "StatusBar - initialization" {
    const allocator = testing.allocator;
    const props = components.ComponentProps{};
    var statusbar = try components.StatusBar.init(allocator, props);
    defer statusbar.deinit();

    try testing.expectEqualStrings("", statusbar.text);
}
