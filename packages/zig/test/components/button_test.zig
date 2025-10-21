const std = @import("std");
const components = @import("components");
const Button = components.Button;
const ComponentProps = components.ComponentProps;

var clicked = false;

fn handleClick() void {
    clicked = true;
}

test "button creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const button = try Button.init(allocator, "Click Me", props);
    defer button.deinit();

    try std.testing.expectEqualStrings("Click Me", button.text);
    try std.testing.expect(button.on_click == null);
}

test "button click handler" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const button = try Button.init(allocator, "Click Me", props);
    defer button.deinit();

    clicked = false;
    button.onClick(&handleClick);
    button.click();
    try std.testing.expect(clicked);
}

test "button setText" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const button = try Button.init(allocator, "Initial", props);
    defer button.deinit();

    button.setText("Updated");
    try std.testing.expectEqualStrings("Updated", button.text);
}
