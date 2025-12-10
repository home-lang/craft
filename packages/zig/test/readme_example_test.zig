const std = @import("std");

// Direct imports to test README examples
const Button = @import("../src/components/button.zig").Button;
const Slider = @import("../src/components/slider.zig").Slider;
const main = @import("../src/main.zig");

// Test that the README component example compiles
test "README component example" {
    const allocator = std.testing.allocator;

    // Create a button component (README example)
    const button = try Button.init(allocator, .{});
    defer button.deinit();

    button.setLabel("Click Me!");
    button.setVariant(.primary);
    // button.onClick(handleClick); // Can't test callbacks easily

    // Create a slider (README example)
    const slider = try Slider.init(allocator, .{});
    defer slider.deinit();

    try slider.setRange(0, 100);
    try slider.setValue(50);
    // slider.onChange(handleSliderChange); // Can't test callbacks easily

    // Verify values
    try std.testing.expectEqualStrings("Click Me!", button.getLabel());
    try std.testing.expectEqual(Button.Variant.primary, button.getVariant());
    try std.testing.expectEqual(@as(f64, 50.0), slider.value);
}

test "README basic window API" {
    // Just verify the types exist and can be accessed
    _ = main.App;
    _ = main.ios;
    _ = main.mobile;
    _ = main.api;
}
