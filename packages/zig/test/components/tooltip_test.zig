const std = @import("std");
const components = @import("components");
const Tooltip = components.Tooltip;
const Component = components.Component;
const ComponentProps = components.ComponentProps;

var tooltip_shown = false;
var tooltip_hidden = false;

fn handleShow() void {
    tooltip_shown = true;
}

fn handleHide() void {
    tooltip_hidden = true;
}

test "tooltip creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tooltip = try Tooltip.init(allocator, "Help text", props);
    defer tooltip.deinit();

    try std.testing.expectEqualStrings("Help text", tooltip.text);
    try std.testing.expect(!tooltip.visible);
    try std.testing.expect(tooltip.position == .top);
    try std.testing.expect(tooltip.delay_ms == 500);
}

test "tooltip show and hide" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tooltip = try Tooltip.init(allocator, "Info", props);
    defer tooltip.deinit();

    tooltip_shown = false;
    tooltip_hidden = false;
    tooltip.onShow(&handleShow);
    tooltip.onHide(&handleHide);

    tooltip.show();
    try std.testing.expect(tooltip.visible);
    try std.testing.expect(tooltip_shown);

    tooltip.hide();
    try std.testing.expect(!tooltip.visible);
    try std.testing.expect(tooltip_hidden);
}

test "tooltip toggle" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tooltip = try Tooltip.init(allocator, "Toggle me", props);
    defer tooltip.deinit();

    try std.testing.expect(!tooltip.visible);

    tooltip.toggle();
    try std.testing.expect(tooltip.visible);

    tooltip.toggle();
    try std.testing.expect(!tooltip.visible);
}

test "tooltip position" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tooltip = try Tooltip.init(allocator, "Text", props);
    defer tooltip.deinit();

    tooltip.setPosition(.bottom);
    try std.testing.expect(tooltip.position == .bottom);

    tooltip.setPosition(.left);
    try std.testing.expect(tooltip.position == .left);
}

test "tooltip theme" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tooltip = try Tooltip.init(allocator, "Text", props);
    defer tooltip.deinit();

    tooltip.setTheme(.light);
    try std.testing.expect(tooltip.theme == .light);

    tooltip.setTheme(.warning);
    try std.testing.expect(tooltip.theme == .warning);
}

test "tooltip text update" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tooltip = try Tooltip.init(allocator, "Initial", props);
    defer tooltip.deinit();

    tooltip.setText("Updated");
    try std.testing.expectEqualStrings("Updated", tooltip.text);
}

test "tooltip delay" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tooltip = try Tooltip.init(allocator, "Text", props);
    defer tooltip.deinit();

    tooltip.setDelay(1000);
    try std.testing.expect(tooltip.delay_ms == 1000);
}

test "tooltip offset" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tooltip = try Tooltip.init(allocator, "Text", props);
    defer tooltip.deinit();

    tooltip.setOffset(10, 20);
    try std.testing.expect(tooltip.offset_x == 10);
    try std.testing.expect(tooltip.offset_y == 20);
}

test "tooltip max width" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tooltip = try Tooltip.init(allocator, "Text", props);
    defer tooltip.deinit();

    tooltip.setMaxWidth(500);
    try std.testing.expect(tooltip.max_width.? == 500);

    tooltip.setMaxWidth(null);
    try std.testing.expect(tooltip.max_width == null);
}

test "tooltip arrow visibility" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tooltip = try Tooltip.init(allocator, "Text", props);
    defer tooltip.deinit();

    try std.testing.expect(tooltip.show_arrow);

    tooltip.setShowArrow(false);
    try std.testing.expect(!tooltip.show_arrow);
}

test "tooltip target" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tooltip = try Tooltip.init(allocator, "Text", props);
    defer tooltip.deinit();

    const target = try allocator.create(Component);
    target.* = try Component.init(allocator, "button", props);
    defer {
        target.deinit();
        allocator.destroy(target);
    }

    tooltip.setTarget(target);
    try std.testing.expect(tooltip.target == target);
}

test "tooltip visible duration" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tooltip = try Tooltip.init(allocator, "Text", props);
    defer tooltip.deinit();

    try std.testing.expect(tooltip.getVisibleDuration() == null);

    tooltip.show();
    const duration = tooltip.getVisibleDuration();
    try std.testing.expect(duration != null);
}
