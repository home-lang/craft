const std = @import("std");
const components = @import("components");
const TextInput = components.TextInput;
const ComponentProps = components.ComponentProps;

var last_value: []const u8 = "";

fn handleChange(value: []const u8) void {
    last_value = value;
}

test "text input creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const input = try TextInput.init(allocator, props);
    defer input.deinit();

    try std.testing.expectEqualStrings("", input.value);
    try std.testing.expect(!input.password);
}

test "text input setValue" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const input = try TextInput.init(allocator, props);
    defer input.deinit();

    last_value = "";
    input.onChange(&handleChange);
    input.setValue("test value");

    try std.testing.expectEqualStrings("test value", input.value);
    try std.testing.expectEqualStrings("test value", last_value);
}

test "text input max length" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const input = try TextInput.init(allocator, props);
    defer input.deinit();

    input.setMaxLength(5);
    input.setValue("123456789");

    // Should not set value longer than max_length
    try std.testing.expectEqualStrings("", input.value);

    input.setValue("12345");
    try std.testing.expectEqualStrings("12345", input.value);
}

test "text input password mode" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const input = try TextInput.init(allocator, props);
    defer input.deinit();

    try std.testing.expect(!input.password);
    input.setPassword(true);
    try std.testing.expect(input.password);
}

test "text input placeholder" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const input = try TextInput.init(allocator, props);
    defer input.deinit();

    try std.testing.expect(input.placeholder == null);
    input.setPlaceholder("Enter text...");
    try std.testing.expectEqualStrings("Enter text...", input.placeholder.?);
}
