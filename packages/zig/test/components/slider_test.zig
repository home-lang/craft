const std = @import("std");
const components = @import("components");
const Slider = components.Slider;
const ComponentProps = components.ComponentProps;

var slider_value: f64 = 0;
var change_started = false;
var change_ended = false;

fn handleChange(value: f64) void {
    slider_value = value;
}

fn handleChangeStart() void {
    change_started = true;
}

fn handleChangeEnd() void {
    change_ended = true;
}

test "slider creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const slider = try Slider.init(allocator, props);
    defer slider.deinit();

    try std.testing.expect(slider.value == 0.0);
    try std.testing.expect(slider.min == 0.0);
    try std.testing.expect(slider.max == 100.0);
    try std.testing.expect(slider.step == 1.0);
    try std.testing.expect(!slider.disabled);
}

test "slider set value" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const slider = try Slider.init(allocator, props);
    defer slider.deinit();

    slider_value = 0;
    slider.onChange(&handleChange);

    try slider.setValue(50.0);
    try std.testing.expect(slider.value == 50.0);
    try std.testing.expect(slider_value == 50.0);
}

test "slider value clamping" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const slider = try Slider.init(allocator, props);
    defer slider.deinit();

    try std.testing.expectError(error.ValueOutOfRange, slider.setValue(150.0));
    try std.testing.expectError(error.ValueOutOfRange, slider.setValue(-10.0));
}

test "slider step snapping" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const slider = try Slider.init(allocator, props);
    defer slider.deinit();

    try slider.setStep(10.0);
    try slider.setValue(47.0);

    // Should snap to nearest step (50.0)
    try std.testing.expect(slider.value == 50.0);
}

test "slider increment and decrement" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const slider = try Slider.init(allocator, props);
    defer slider.deinit();

    try slider.setValue(50.0);

    try slider.increment();
    try std.testing.expect(slider.value == 51.0);

    try slider.decrement();
    try std.testing.expect(slider.value == 50.0);
}

test "slider range" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const slider = try Slider.init(allocator, props);
    defer slider.deinit();

    try slider.setRange(10.0, 90.0);
    try std.testing.expect(slider.min == 10.0);
    try std.testing.expect(slider.max == 90.0);

    // Value should adjust to new range
    try std.testing.expect(slider.value == 10.0);

    try std.testing.expectError(error.InvalidRange, slider.setRange(100.0, 50.0));
}

test "slider percentage" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const slider = try Slider.init(allocator, props);
    defer slider.deinit();

    try slider.setValue(50.0);
    try std.testing.expect(slider.getPercentage() == 50.0);

    try slider.setPercentage(75.0);
    try std.testing.expect(slider.value == 75.0);
}

test "slider at min and max" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const slider = try Slider.init(allocator, props);
    defer slider.deinit();

    try std.testing.expect(slider.isAtMin());
    try std.testing.expect(!slider.isAtMax());

    try slider.setValue(100.0);
    try std.testing.expect(!slider.isAtMin());
    try std.testing.expect(slider.isAtMax());
}

test "slider reset" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const slider = try Slider.init(allocator, props);
    defer slider.deinit();

    try slider.setValue(75.0);
    try slider.reset();
    try std.testing.expect(slider.value == 0.0);
}

test "slider disabled state" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const slider = try Slider.init(allocator, props);
    defer slider.deinit();

    slider.setDisabled(true);
    try slider.setValue(50.0);

    // Value should not change when disabled
    try std.testing.expect(slider.value == 0.0);
}

test "slider orientation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const slider = try Slider.init(allocator, props);
    defer slider.deinit();

    try std.testing.expect(slider.orientation == .horizontal);

    slider.setOrientation(.vertical);
    try std.testing.expect(slider.orientation == .vertical);
}

test "slider visibility options" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const slider = try Slider.init(allocator, props);
    defer slider.deinit();

    try std.testing.expect(slider.show_value);
    try std.testing.expect(!slider.show_ticks);

    slider.setShowValue(false);
    slider.setShowTicks(true);

    try std.testing.expect(!slider.show_value);
    try std.testing.expect(slider.show_ticks);
}

test "slider labels" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const slider = try Slider.init(allocator, props);
    defer slider.deinit();

    try slider.addLabel(0.0, "Min");
    try slider.addLabel(50.0, "Mid");
    try slider.addLabel(100.0, "Max");

    const label = slider.getLabel(50.0);
    try std.testing.expect(label != null);
    try std.testing.expectEqualStrings("Mid", label.?);
}

test "slider change callbacks" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const slider = try Slider.init(allocator, props);
    defer slider.deinit();

    change_started = false;
    change_ended = false;

    slider.onChangeStart(&handleChangeStart);
    slider.onChangeEnd(&handleChangeEnd);

    slider.startChange();
    try std.testing.expect(change_started);

    slider.endChange();
    try std.testing.expect(change_ended);
}
