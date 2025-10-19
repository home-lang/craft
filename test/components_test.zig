const std = @import("std");
const testing = std.testing;
const components = @import("../src/components.zig");

// Button Tests
test "Button - basic creation" {
    const allocator = testing.allocator;
    var button = try components.Button.init(allocator, "Click Me", null);
    defer button.deinit();

    try testing.expectEqualStrings("Click Me", button.label);
    try testing.expect(button.enabled);
}

test "Button - enabled/disabled" {
    const allocator = testing.allocator;
    var button = try components.Button.init(allocator, "Test", null);
    defer button.deinit();

    button.setEnabled(false);
    try testing.expect(!button.enabled);

    button.setEnabled(true);
    try testing.expect(button.enabled);
}

test "Button - set label" {
    const allocator = testing.allocator;
    var button = try components.Button.init(allocator, "Old", null);
    defer button.deinit();

    button.setLabel("New");
    try testing.expectEqualStrings("New", button.label);
}

// TextInput Tests
test "TextInput - creation" {
    const allocator = testing.allocator;
    var input = try components.TextInput.init(allocator, "Placeholder");
    defer input.deinit();

    try testing.expectEqualStrings("Placeholder", input.placeholder);
    try testing.expectEqualStrings("", input.text);
}

test "TextInput - set text" {
    const allocator = testing.allocator;
    var input = try components.TextInput.init(allocator, "Enter text");
    defer input.deinit();

    try input.setText("Hello World");
    try testing.expectEqualStrings("Hello World", input.text);
}

test "TextInput - clear" {
    const allocator = testing.allocator;
    var input = try components.TextInput.init(allocator, "Enter text");
    defer input.deinit();

    try input.setText("Some text");
    input.clear();
    try testing.expectEqualStrings("", input.text);
}

// Label Tests
test "Label - creation" {
    const allocator = testing.allocator;
    var label = try components.Label.init(allocator, "Test Label");
    defer label.deinit();

    try testing.expectEqualStrings("Test Label", label.text);
}

test "Label - set text" {
    const allocator = testing.allocator;
    var label = try components.Label.init(allocator, "Old");
    defer label.deinit();

    label.setText("New");
    try testing.expectEqualStrings("New", label.text);
}

// Checkbox Tests
test "Checkbox - creation" {
    const allocator = testing.allocator;
    var checkbox = try components.Checkbox.init(allocator, "Check me", null);
    defer checkbox.deinit();

    try testing.expectEqualStrings("Check me", checkbox.label);
    try testing.expect(!checkbox.checked);
}

test "Checkbox - toggle" {
    const allocator = testing.allocator;
    var checkbox = try components.Checkbox.init(allocator, "Test", null);
    defer checkbox.deinit();

    checkbox.toggle();
    try testing.expect(checkbox.checked);

    checkbox.toggle();
    try testing.expect(!checkbox.checked);
}

test "Checkbox - set checked" {
    const allocator = testing.allocator;
    var checkbox = try components.Checkbox.init(allocator, "Test", null);
    defer checkbox.deinit();

    checkbox.setChecked(true);
    try testing.expect(checkbox.checked);

    checkbox.setChecked(false);
    try testing.expect(!checkbox.checked);
}

// RadioButton Tests
test "RadioButton - creation" {
    const allocator = testing.allocator;
    var radio = try components.RadioButton.init(allocator, "Option 1", "group1", null);
    defer radio.deinit();

    try testing.expectEqualStrings("Option 1", radio.label);
    try testing.expectEqualStrings("group1", radio.group);
    try testing.expect(!radio.selected);
}

test "RadioButton - select" {
    const allocator = testing.allocator;
    var radio = try components.RadioButton.init(allocator, "Option", "group", null);
    defer radio.deinit();

    radio.select();
    try testing.expect(radio.selected);
}

// Slider Tests
test "Slider - creation with defaults" {
    const allocator = testing.allocator;
    var slider = try components.Slider.init(allocator, 0.0, 100.0, 50.0, null);
    defer slider.deinit();

    try testing.expectEqual(@as(f64, 0.0), slider.min);
    try testing.expectEqual(@as(f64, 100.0), slider.max);
    try testing.expectEqual(@as(f64, 50.0), slider.value);
}

test "Slider - set value" {
    const allocator = testing.allocator;
    var slider = try components.Slider.init(allocator, 0.0, 100.0, 0.0, null);
    defer slider.deinit();

    slider.setValue(75.0);
    try testing.expectEqual(@as(f64, 75.0), slider.value);
}

test "Slider - value clamping" {
    const allocator = testing.allocator;
    var slider = try components.Slider.init(allocator, 0.0, 100.0, 0.0, null);
    defer slider.deinit();

    slider.setValue(150.0); // Over max
    try testing.expectEqual(@as(f64, 100.0), slider.value);

    slider.setValue(-10.0); // Under min
    try testing.expectEqual(@as(f64, 0.0), slider.value);
}

// ProgressBar Tests
test "ProgressBar - creation" {
    const allocator = testing.allocator;
    var progress = try components.ProgressBar.init(allocator);
    defer progress.deinit();

    try testing.expectEqual(@as(f64, 0.0), progress.value);
    try testing.expectEqual(@as(f64, 100.0), progress.max);
}

test "ProgressBar - set value" {
    const allocator = testing.allocator;
    var progress = try components.ProgressBar.init(allocator);
    defer progress.deinit();

    progress.setValue(50.0);
    try testing.expectEqual(@as(f64, 50.0), progress.value);
}

test "ProgressBar - percentage" {
    const allocator = testing.allocator;
    var progress = try components.ProgressBar.init(allocator);
    defer progress.deinit();

    progress.setValue(50.0);
    try testing.expectEqual(@as(f64, 50.0), progress.percentage());
}

// ColorPicker Tests
test "ColorPicker - creation with default" {
    const allocator = testing.allocator;
    const default_color = components.ColorPicker.Color{ .r = 255, .g = 0, .b = 0, .a = 255 };
    var picker = try components.ColorPicker.init(allocator, default_color, null);
    defer picker.deinit();

    try testing.expectEqual(@as(u8, 255), picker.selected_color.r);
    try testing.expectEqual(@as(u8, 0), picker.selected_color.g);
    try testing.expectEqual(@as(u8, 0), picker.selected_color.b);
}

test "ColorPicker - set color" {
    const allocator = testing.allocator;
    const default_color = components.ColorPicker.Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
    var picker = try components.ColorPicker.init(allocator, default_color, null);
    defer picker.deinit();

    const new_color = components.ColorPicker.Color{ .r = 100, .g = 150, .b = 200, .a = 255 };
    picker.setColor(new_color);

    try testing.expectEqual(@as(u8, 100), picker.selected_color.r);
    try testing.expectEqual(@as(u8, 150), picker.selected_color.g);
    try testing.expectEqual(@as(u8, 200), picker.selected_color.b);
}

// DatePicker Tests
test "DatePicker - creation" {
    const allocator = testing.allocator;
    var picker = try components.DatePicker.init(allocator, null);
    defer picker.deinit();

    try testing.expectEqual(@as(?i32, null), picker.selected_year);
}

test "DatePicker - set date" {
    const allocator = testing.allocator;
    var picker = try components.DatePicker.init(allocator, null);
    defer picker.deinit();

    picker.setDate(2024, 12, 25);

    try testing.expectEqual(@as(?i32, 2024), picker.selected_year);
    try testing.expectEqual(@as(?u8, 12), picker.selected_month);
    try testing.expectEqual(@as(?u8, 25), picker.selected_day);
}

// TimePicker Tests
test "TimePicker - creation" {
    const allocator = testing.allocator;
    var picker = try components.TimePicker.init(allocator, null);
    defer picker.deinit();

    try testing.expectEqual(@as(?u8, null), picker.selected_hour);
}

test "TimePicker - set time" {
    const allocator = testing.allocator;
    var picker = try components.TimePicker.init(allocator, null);
    defer picker.deinit();

    picker.setTime(14, 30, 45);

    try testing.expectEqual(@as(?u8, 14), picker.selected_hour);
    try testing.expectEqual(@as(?u8, 30), picker.selected_minute);
    try testing.expectEqual(@as(?u8, 45), picker.selected_second);
}

// Spinner Tests
test "Spinner - creation" {
    const allocator = testing.allocator;
    var spinner = try components.Spinner.init(allocator);
    defer spinner.deinit();

    try testing.expect(!spinner.spinning);
}

test "Spinner - start/stop" {
    const allocator = testing.allocator;
    var spinner = try components.Spinner.init(allocator);
    defer spinner.deinit();

    spinner.start();
    try testing.expect(spinner.spinning);

    spinner.stop();
    try testing.expect(!spinner.spinning);
}

// ImageView Tests
test "ImageView - creation" {
    const allocator = testing.allocator;
    var image = try components.ImageView.init(allocator, "test.png");
    defer image.deinit();

    try testing.expectEqualStrings("test.png", image.source);
}

test "ImageView - set source" {
    const allocator = testing.allocator;
    var image = try components.ImageView.init(allocator, "old.png");
    defer image.deinit();

    image.setSource("new.png");
    try testing.expectEqualStrings("new.png", image.source);
}

// TreeView Tests
test "TreeView - creation" {
    const allocator = testing.allocator;
    var tree = try components.TreeView.init(allocator);
    defer tree.deinit();

    try testing.expectEqual(@as(?*components.TreeView.TreeNode, null), tree.root);
}

test "TreeView - create and set root node" {
    const allocator = testing.allocator;
    var tree = try components.TreeView.init(allocator);
    defer tree.deinit();

    const root = try tree.createNode("Root");
    try tree.setRoot(root);

    try testing.expectEqualStrings("Root", tree.root.?.label);
}

test "TreeNode - add child" {
    const allocator = testing.allocator;
    var tree = try components.TreeView.init(allocator);
    defer tree.deinit();

    const root = try tree.createNode("Root");
    const child = try tree.createNode("Child");

    try root.addChild(child);

    try testing.expectEqual(@as(usize, 1), root.children.items.len);
    try testing.expectEqualStrings("Child", root.children.items[0].label);
}

test "TreeNode - expand/collapse" {
    const allocator = testing.allocator;
    var tree = try components.TreeView.init(allocator);
    defer tree.deinit();

    var node = try tree.createNode("Node");

    try testing.expect(!node.expanded);

    node.expand();
    try testing.expect(node.expanded);

    node.collapse();
    try testing.expect(!node.expanded);
}

// Accordion Tests
test "Accordion - creation" {
    const allocator = testing.allocator;
    var accordion = try components.Accordion.init(allocator);
    defer accordion.deinit();

    try testing.expectEqual(@as(usize, 0), accordion.panels.items.len);
}

test "Accordion - add panel" {
    const allocator = testing.allocator;
    var accordion = try components.Accordion.init(allocator);
    defer accordion.deinit();

    try accordion.addPanel("Panel 1", "Content 1");

    try testing.expectEqual(@as(usize, 1), accordion.panels.items.len);
    try testing.expectEqualStrings("Panel 1", accordion.panels.items[0].title);
}

test "Accordion - expand panel" {
    const allocator = testing.allocator;
    var accordion = try components.Accordion.init(allocator);
    defer accordion.deinit();

    try accordion.addPanel("Panel 1", "Content 1");
    accordion.expandPanel(0);

    try testing.expect(accordion.panels.items[0].expanded);
}

// Card Tests
test "Card - creation" {
    const allocator = testing.allocator;
    var card = try components.Card.init(allocator, "Title", "Content");
    defer card.deinit();

    try testing.expectEqualStrings("Title", card.title);
    try testing.expectEqualStrings("Content", card.content);
}

// Badge Tests
test "Badge - creation" {
    const allocator = testing.allocator;
    var badge = try components.Badge.init(allocator, "5");
    defer badge.deinit();

    try testing.expectEqualStrings("5", badge.text);
}

// Chip Tests
test "Chip - creation" {
    const allocator = testing.allocator;
    var chip = try components.Chip.init(allocator, "Tag", null);
    defer chip.deinit();

    try testing.expectEqualStrings("Tag", chip.label);
}

test "Chip - removable" {
    const allocator = testing.allocator;
    var chip = try components.Chip.init(allocator, "Tag", null);
    defer chip.deinit();

    try testing.expect(!chip.removed);
    chip.remove();
    try testing.expect(chip.removed);
}

// Avatar Tests
test "Avatar - creation with initials" {
    const allocator = testing.allocator;
    var avatar = try components.Avatar.init(allocator, null, "JD");
    defer avatar.deinit();

    try testing.expectEqual(@as(?[]const u8, null), avatar.image_url);
    try testing.expectEqualStrings("JD", avatar.initials.?);
}

test "Avatar - creation with image" {
    const allocator = testing.allocator;
    var avatar = try components.Avatar.init(allocator, "avatar.png", null);
    defer avatar.deinit();

    try testing.expectEqualStrings("avatar.png", avatar.image_url.?);
}

// Stepper Tests
test "Stepper - creation" {
    const allocator = testing.allocator;
    var stepper = try components.Stepper.init(allocator);
    defer stepper.deinit();

    try testing.expectEqual(@as(usize, 0), stepper.current_step);
}

test "Stepper - add step" {
    const allocator = testing.allocator;
    var stepper = try components.Stepper.init(allocator);
    defer stepper.deinit();

    try stepper.addStep("Step 1", "Description 1");

    try testing.expectEqual(@as(usize, 1), stepper.steps.items.len);
    try testing.expectEqualStrings("Step 1", stepper.steps.items[0].title);
}

test "Stepper - navigation" {
    const allocator = testing.allocator;
    var stepper = try components.Stepper.init(allocator);
    defer stepper.deinit();

    try stepper.addStep("Step 1", "Description 1");
    try stepper.addStep("Step 2", "Description 2");
    try stepper.addStep("Step 3", "Description 3");

    try testing.expectEqual(@as(usize, 0), stepper.current_step);

    stepper.next();
    try testing.expectEqual(@as(usize, 1), stepper.current_step);

    stepper.next();
    try testing.expectEqual(@as(usize, 2), stepper.current_step);

    stepper.previous();
    try testing.expectEqual(@as(usize, 1), stepper.current_step);
}

test "Stepper - go to step" {
    const allocator = testing.allocator;
    var stepper = try components.Stepper.init(allocator);
    defer stepper.deinit();

    try stepper.addStep("Step 1", "Description 1");
    try stepper.addStep("Step 2", "Description 2");
    try stepper.addStep("Step 3", "Description 3");

    stepper.goToStep(2);
    try testing.expectEqual(@as(usize, 2), stepper.current_step);
}

// Rating Tests
test "Rating - creation" {
    const allocator = testing.allocator;
    var rating = try components.Rating.init(allocator, 5, null);
    defer rating.deinit();

    try testing.expectEqual(@as(u8, 5), rating.max_rating);
    try testing.expectEqual(@as(f32, 0.0), rating.current_rating);
}

test "Rating - set rating" {
    const allocator = testing.allocator;
    var rating = try components.Rating.init(allocator, 5, null);
    defer rating.deinit();

    rating.setRating(4.5);
    try testing.expectEqual(@as(f32, 4.5), rating.current_rating);
}

test "Rating - rating bounds" {
    const allocator = testing.allocator;
    var rating = try components.Rating.init(allocator, 5, null);
    defer rating.deinit();

    rating.setRating(10.0); // Over max
    try testing.expectEqual(@as(f32, 5.0), rating.current_rating);

    rating.setRating(-1.0); // Below min
    try testing.expectEqual(@as(f32, 0.0), rating.current_rating);
}

// ListView Tests
test "ListView - creation" {
    const allocator = testing.allocator;
    var list = try components.ListView.init(allocator);
    defer list.deinit();

    try testing.expectEqual(@as(usize, 0), list.items.items.len);
}

test "ListView - add item" {
    const allocator = testing.allocator;
    var list = try components.ListView.init(allocator);
    defer list.deinit();

    try list.addItem("Item 1");
    try list.addItem("Item 2");

    try testing.expectEqual(@as(usize, 2), list.items.items.len);
    try testing.expectEqualStrings("Item 1", list.items.items[0]);
}

test "ListView - remove item" {
    const allocator = testing.allocator;
    var list = try components.ListView.init(allocator);
    defer list.deinit();

    try list.addItem("Item 1");
    try list.addItem("Item 2");
    list.removeItem(0);

    try testing.expectEqual(@as(usize, 1), list.items.items.len);
}

// Table Tests
test "Table - creation" {
    const allocator = testing.allocator;
    var table = try components.Table.init(allocator);
    defer table.deinit();

    try testing.expectEqual(@as(usize, 0), table.columns.items.len);
    try testing.expectEqual(@as(usize, 0), table.rows.items.len);
}

test "Table - add column" {
    const allocator = testing.allocator;
    var table = try components.Table.init(allocator);
    defer table.deinit();

    try table.addColumn("Name");
    try table.addColumn("Age");

    try testing.expectEqual(@as(usize, 2), table.columns.items.len);
    try testing.expectEqualStrings("Name", table.columns.items[0].header);
}

test "Table - add row" {
    const allocator = testing.allocator;
    var table = try components.Table.init(allocator);
    defer table.deinit();

    try table.addColumn("Name");
    try table.addColumn("Age");

    const row_data = [_][]const u8{ "John", "30" };
    try table.addRow(&row_data);

    try testing.expectEqual(@as(usize, 1), table.rows.items.len);
}

// TabView Tests
test "TabView - creation" {
    const allocator = testing.allocator;
    var tabs = try components.TabView.init(allocator);
    defer tabs.deinit();

    try testing.expectEqual(@as(usize, 0), tabs.tabs.items.len);
    try testing.expectEqual(@as(usize, 0), tabs.active_tab);
}

test "TabView - add tab" {
    const allocator = testing.allocator;
    var tabs = try components.TabView.init(allocator);
    defer tabs.deinit();

    try tabs.addTab("Tab 1", "Content 1");
    try tabs.addTab("Tab 2", "Content 2");

    try testing.expectEqual(@as(usize, 2), tabs.tabs.items.len);
    try testing.expectEqualStrings("Tab 1", tabs.tabs.items[0].title);
}

test "TabView - select tab" {
    const allocator = testing.allocator;
    var tabs = try components.TabView.init(allocator);
    defer tabs.deinit();

    try tabs.addTab("Tab 1", "Content 1");
    try tabs.addTab("Tab 2", "Content 2");

    tabs.selectTab(1);
    try testing.expectEqual(@as(usize, 1), tabs.active_tab);
}

// ScrollView Tests
test "ScrollView - creation" {
    const allocator = testing.allocator;
    var scroll = try components.ScrollView.init(allocator);
    defer scroll.deinit();

    try testing.expectEqual(@as(i32, 0), scroll.scroll_x);
    try testing.expectEqual(@as(i32, 0), scroll.scroll_y);
}

test "ScrollView - scroll to" {
    const allocator = testing.allocator;
    var scroll = try components.ScrollView.init(allocator);
    defer scroll.deinit();

    scroll.scrollTo(100, 200);

    try testing.expectEqual(@as(i32, 100), scroll.scroll_x);
    try testing.expectEqual(@as(i32, 200), scroll.scroll_y);
}

// SplitView Tests
test "SplitView - creation" {
    const allocator = testing.allocator;
    var split = try components.SplitView.init(allocator, .horizontal);
    defer split.deinit();

    try testing.expectEqual(components.SplitView.Orientation.horizontal, split.orientation);
    try testing.expectEqual(@as(f32, 0.5), split.split_ratio);
}

test "SplitView - set split ratio" {
    const allocator = testing.allocator;
    var split = try components.SplitView.init(allocator, .vertical);
    defer split.deinit();

    split.setSplitRatio(0.3);
    try testing.expectEqual(@as(f32, 0.3), split.split_ratio);
}
