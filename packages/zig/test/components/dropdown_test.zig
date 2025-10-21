const std = @import("std");
const components = @import("components");
const Dropdown = components.Dropdown;
const ComponentProps = components.ComponentProps;

var dropdown_opened = false;
var dropdown_closed = false;
var selected_index: usize = 0;

fn handleOpen() void {
    dropdown_opened = true;
}

fn handleClose() void {
    dropdown_closed = true;
}

fn handleSelect(index: usize) void {
    selected_index = index;
}

test "dropdown creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const dropdown = try Dropdown.init(allocator, props);
    defer dropdown.deinit();

    try std.testing.expect(dropdown.options.items.len == 0);
    try std.testing.expect(dropdown.selected_index == null);
    try std.testing.expect(!dropdown.open);
    try std.testing.expect(!dropdown.disabled);
}

test "dropdown add and remove options" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const dropdown = try Dropdown.init(allocator, props);
    defer dropdown.deinit();

    try dropdown.addOption("Option 1", "value1");
    try dropdown.addOption("Option 2", "value2");

    try std.testing.expect(dropdown.options.items.len == 2);
    try std.testing.expectEqualStrings("Option 1", dropdown.options.items[0].label);
    try std.testing.expectEqualStrings("value1", dropdown.options.items[0].value);

    dropdown.removeOption(0);
    try std.testing.expect(dropdown.options.items.len == 1);
    try std.testing.expectEqualStrings("Option 2", dropdown.options.items[0].label);
}

test "dropdown select option" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const dropdown = try Dropdown.init(allocator, props);
    defer dropdown.deinit();

    try dropdown.addOption("Option 1", "value1");
    try dropdown.addOption("Option 2", "value2");

    selected_index = 0;
    dropdown.onSelect(&handleSelect);

    dropdown.selectOption(1);
    try std.testing.expect(dropdown.selected_index.? == 1);
    try std.testing.expect(selected_index == 1);

    const selected = dropdown.getSelectedOption();
    try std.testing.expect(selected != null);
    try std.testing.expectEqualStrings("Option 2", selected.?.label);

    const value = dropdown.getSelectedValue();
    try std.testing.expectEqualStrings("value2", value.?);
}

test "dropdown open and close" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const dropdown = try Dropdown.init(allocator, props);
    defer dropdown.deinit();

    dropdown_opened = false;
    dropdown_closed = false;
    dropdown.onOpen(&handleOpen);
    dropdown.onClose(&handleClose);

    dropdown.openDropdown();
    try std.testing.expect(dropdown.open);
    try std.testing.expect(dropdown_opened);

    dropdown.close();
    try std.testing.expect(!dropdown.open);
    try std.testing.expect(dropdown_closed);
}

test "dropdown toggle" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const dropdown = try Dropdown.init(allocator, props);
    defer dropdown.deinit();

    try std.testing.expect(!dropdown.open);

    dropdown.toggle();
    try std.testing.expect(dropdown.open);

    dropdown.toggle();
    try std.testing.expect(!dropdown.open);
}

test "dropdown disabled state" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const dropdown = try Dropdown.init(allocator, props);
    defer dropdown.deinit();

    try dropdown.addOption("Option 1", "value1");

    dropdown.setDisabled(true);
    try std.testing.expect(dropdown.disabled);

    // Should not open when disabled
    dropdown.toggle();
    try std.testing.expect(!dropdown.open);

    // Should not select when disabled
    dropdown.selectOption(0);
    try std.testing.expect(dropdown.selected_index == null);
}

test "dropdown option disabled state" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const dropdown = try Dropdown.init(allocator, props);
    defer dropdown.deinit();

    try dropdown.addOption("Option 1", "value1");

    dropdown.setOptionDisabled(0, true);
    try std.testing.expect(dropdown.options.items[0].disabled);

    // Should not select disabled option
    dropdown.selectOption(0);
    try std.testing.expect(dropdown.selected_index == null);
}

test "dropdown clear selection" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const dropdown = try Dropdown.init(allocator, props);
    defer dropdown.deinit();

    try dropdown.addOption("Option 1", "value1");
    dropdown.selectOption(0);
    try std.testing.expect(dropdown.selected_index != null);

    dropdown.clearSelection();
    try std.testing.expect(dropdown.selected_index == null);
}

test "dropdown with icon" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const dropdown = try Dropdown.init(allocator, props);
    defer dropdown.deinit();

    try dropdown.addOptionWithIcon("Home", "home", "🏠");
    try std.testing.expectEqualStrings("🏠", dropdown.options.items[0].icon.?);
}

test "dropdown placeholder" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const dropdown = try Dropdown.init(allocator, props);
    defer dropdown.deinit();

    dropdown.setPlaceholder("Select an option...");
    try std.testing.expectEqualStrings("Select an option...", dropdown.placeholder.?);
}
