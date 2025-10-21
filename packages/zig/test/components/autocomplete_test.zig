const std = @import("std");
const components = @import("components");
const Autocomplete = components.Autocomplete;
const Suggestion = Autocomplete.Suggestion;
const ComponentProps = components.ComponentProps;

var selected_suggestion: ?*const Suggestion = null;
var input_value: []const u8 = "";
var dropdown_opened = false;
var dropdown_closed = false;

fn handleSelect(suggestion: *const Suggestion) void {
    selected_suggestion = suggestion;
}

fn handleInput(value: []const u8) void {
    input_value = value;
}

fn handleOpen() void {
    dropdown_opened = true;
}

fn handleClose() void {
    dropdown_closed = true;
}

test "autocomplete creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const autocomplete = try Autocomplete.init(allocator, props);
    defer autocomplete.deinit();

    try std.testing.expect(autocomplete.suggestions.items.len == 0);
    try std.testing.expect(!autocomplete.open);
    try std.testing.expect(!autocomplete.disabled);
    try std.testing.expect(autocomplete.min_chars == 1);
}

test "autocomplete add suggestions" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const autocomplete = try Autocomplete.init(allocator, props);
    defer autocomplete.deinit();

    try autocomplete.addSuggestion("Apple", "apple");
    try autocomplete.addSuggestion("Banana", "banana");

    try std.testing.expect(autocomplete.suggestions.items.len == 2);
    try std.testing.expectEqualStrings("Apple", autocomplete.suggestions.items[0].label);
}

test "autocomplete filtering - contains" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const autocomplete = try Autocomplete.init(allocator, props);
    defer autocomplete.deinit();

    try autocomplete.addSuggestion("Apple", "apple");
    try autocomplete.addSuggestion("Banana", "banana");
    try autocomplete.addSuggestion("Orange", "orange");
    try autocomplete.addSuggestion("Pineapple", "pineapple");

    autocomplete.setMatchMode(.contains);
    try autocomplete.setInput("app");

    try std.testing.expect(autocomplete.getFilteredCount() == 2); // Apple, Pineapple
}

test "autocomplete filtering - starts with" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const autocomplete = try Autocomplete.init(allocator, props);
    defer autocomplete.deinit();

    try autocomplete.addSuggestion("Apple", "apple");
    try autocomplete.addSuggestion("Apricot", "apricot");
    try autocomplete.addSuggestion("Banana", "banana");

    autocomplete.setMatchMode(.starts_with);
    try autocomplete.setInput("ap");

    try std.testing.expect(autocomplete.getFilteredCount() == 2); // Apple, Apricot
}

test "autocomplete case sensitivity" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const autocomplete = try Autocomplete.init(allocator, props);
    defer autocomplete.deinit();

    try autocomplete.addSuggestion("Apple", "apple");

    // Case insensitive (default)
    try autocomplete.setInput("APP");
    try std.testing.expect(autocomplete.getFilteredCount() == 1);

    // Case sensitive
    autocomplete.setCaseSensitive(true);
    try autocomplete.setInput("APP");
    try std.testing.expect(autocomplete.getFilteredCount() == 0);
}

test "autocomplete min chars" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const autocomplete = try Autocomplete.init(allocator, props);
    defer autocomplete.deinit();

    try autocomplete.addSuggestion("Apple", "apple");

    autocomplete.setMinChars(3);
    try autocomplete.setInput("ap");
    try std.testing.expect(!autocomplete.open); // Should not open

    try autocomplete.setInput("app");
    try std.testing.expect(autocomplete.open); // Should open now
}

test "autocomplete max suggestions" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const autocomplete = try Autocomplete.init(allocator, props);
    defer autocomplete.deinit();

    var i: usize = 0;
    while (i < 20) : (i += 1) {
        try autocomplete.addSuggestion("Item", "item");
    }

    autocomplete.setMaxSuggestions(5);
    try autocomplete.setInput("i");

    try std.testing.expect(autocomplete.getFilteredCount() == 5);
}

test "autocomplete selection" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const autocomplete = try Autocomplete.init(allocator, props);
    defer autocomplete.deinit();

    try autocomplete.addSuggestion("Apple", "apple");
    try autocomplete.addSuggestion("Banana", "banana");

    selected_suggestion = null;
    autocomplete.onSelect(&handleSelect);

    try autocomplete.setInput("a");
    autocomplete.selectSuggestion(0);

    try std.testing.expect(selected_suggestion != null);
    try std.testing.expectEqualStrings("apple", autocomplete.input_value);
}

test "autocomplete navigation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const autocomplete = try Autocomplete.init(allocator, props);
    defer autocomplete.deinit();

    try autocomplete.addSuggestion("Apple", "apple");
    try autocomplete.addSuggestion("Banana", "banana");
    try autocomplete.addSuggestion("Cherry", "cherry");

    try autocomplete.setInput("a");

    try std.testing.expect(autocomplete.selected_index == null);

    autocomplete.selectNext();
    try std.testing.expect(autocomplete.selected_index.? == 0);

    autocomplete.selectNext();
    try std.testing.expect(autocomplete.selected_index.? == 1);

    autocomplete.selectPrevious();
    try std.testing.expect(autocomplete.selected_index.? == 0);
}

test "autocomplete open and close" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const autocomplete = try Autocomplete.init(allocator, props);
    defer autocomplete.deinit();

    dropdown_opened = false;
    dropdown_closed = false;
    autocomplete.onOpen(&handleOpen);
    autocomplete.onClose(&handleClose);

    try autocomplete.addSuggestion("Apple", "apple");
    try autocomplete.setInput("a");

    try std.testing.expect(autocomplete.open);
    try std.testing.expect(dropdown_opened);

    autocomplete.closeDropdown();
    try std.testing.expect(!autocomplete.open);
    try std.testing.expect(dropdown_closed);
}

test "autocomplete clear" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const autocomplete = try Autocomplete.init(allocator, props);
    defer autocomplete.deinit();

    try autocomplete.addSuggestion("Apple", "apple");
    try autocomplete.setInput("app");

    autocomplete.clear();
    try std.testing.expectEqualStrings("", autocomplete.input_value);
    try std.testing.expect(!autocomplete.open);
}

test "autocomplete disabled" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const autocomplete = try Autocomplete.init(allocator, props);
    defer autocomplete.deinit();

    autocomplete.setDisabled(true);
    try autocomplete.setInput("test");

    try std.testing.expectEqualStrings("", autocomplete.input_value);
}

test "autocomplete with description" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const autocomplete = try Autocomplete.init(allocator, props);
    defer autocomplete.deinit();

    try autocomplete.addSuggestionWithDetails("Apple", "apple", "A red fruit", "🍎");

    try std.testing.expect(autocomplete.suggestions.items[0].description != null);
    try std.testing.expectEqualStrings("A red fruit", autocomplete.suggestions.items[0].description.?);
}

test "autocomplete fuzzy matching" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const autocomplete = try Autocomplete.init(allocator, props);
    defer autocomplete.deinit();

    try autocomplete.addSuggestion("JavaScript", "javascript");
    try autocomplete.addSuggestion("TypeScript", "typescript");

    autocomplete.setMatchMode(.fuzzy);
    try autocomplete.setInput("jsc");

    try std.testing.expect(autocomplete.getFilteredCount() >= 1);
}
