const std = @import("std");
const components = @import("components");
const Button = components.Button;

var clicked = false;

fn handleClick() void {
    clicked = true;
}

test "button creation" {
    const allocator = std.testing.allocator;
    const button = try Button.init(allocator, .{ .label = "Click Me" });
    defer button.deinit();

    try std.testing.expectEqualStrings("Click Me", button.text);
    try std.testing.expect(button.on_click == null);
}

test "button click handler" {
    const allocator = std.testing.allocator;
    const button = try Button.init(allocator, .{ .label = "Click Me" });
    defer button.deinit();

    clicked = false;
    button.onClick(&handleClick);
    button.click();
    try std.testing.expect(clicked);
}

test "button setText" {
    const allocator = std.testing.allocator;
    const button = try Button.init(allocator, .{ .label = "Initial" });
    defer button.deinit();

    button.setText("Updated");
    try std.testing.expectEqualStrings("Updated", button.text);
}

test "button setLabel and setVariant (README API)" {
    const allocator = std.testing.allocator;
    const button = try Button.init(allocator, .{});
    defer button.deinit();

    button.setLabel("Click Me!");
    button.setVariant(.primary);

    try std.testing.expectEqualStrings("Click Me!", button.getLabel());
    try std.testing.expectEqual(Button.Variant.primary, button.getVariant());
}
