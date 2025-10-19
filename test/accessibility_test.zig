const std = @import("std");
const testing = std.testing;
const accessibility = @import("../src/accessibility.zig");

// Role enum tests
test "Role - document structure roles" {
    try testing.expectEqual(accessibility.Role.document, .document);
    try testing.expectEqual(accessibility.Role.article, .article);
    try testing.expectEqual(accessibility.Role.section, .section);
    try testing.expectEqual(accessibility.Role.navigation, .navigation);
    try testing.expectEqual(accessibility.Role.main, .main);
    try testing.expectEqual(accessibility.Role.complementary, .complementary);
    try testing.expectEqual(accessibility.Role.banner, .banner);
    try testing.expectEqual(accessibility.Role.contentinfo, .contentinfo);
    try testing.expectEqual(accessibility.Role.region, .region);
}

test "Role - landmark roles" {
    try testing.expectEqual(accessibility.Role.search, .search);
    try testing.expectEqual(accessibility.Role.form, .form);
    try testing.expectEqual(accessibility.Role.application, .application);
}

test "Role - widget roles" {
    try testing.expectEqual(accessibility.Role.button, .button);
    try testing.expectEqual(accessibility.Role.checkbox, .checkbox);
    try testing.expectEqual(accessibility.Role.radio, .radio);
    try testing.expectEqual(accessibility.Role.textbox, .textbox);
    try testing.expectEqual(accessibility.Role.combobox, .combobox);
    try testing.expectEqual(accessibility.Role.listbox, .listbox);
    try testing.expectEqual(accessibility.Role.menu, .menu);
    try testing.expectEqual(accessibility.Role.menubar, .menubar);
    try testing.expectEqual(accessibility.Role.menuitem, .menuitem);
    try testing.expectEqual(accessibility.Role.slider, .slider);
    try testing.expectEqual(accessibility.Role.spinbutton, .spinbutton);
    try testing.expectEqual(accessibility.Role.progressbar, .progressbar);
}

test "Role - tab roles" {
    try testing.expectEqual(accessibility.Role.tab, .tab);
    try testing.expectEqual(accessibility.Role.tabpanel, .tabpanel);
    try testing.expectEqual(accessibility.Role.tablist, .tablist);
}

test "Role - tree roles" {
    try testing.expectEqual(accessibility.Role.tree, .tree);
    try testing.expectEqual(accessibility.Role.treeitem, .treeitem);
}

test "Role - dialog roles" {
    try testing.expectEqual(accessibility.Role.dialog, .dialog);
    try testing.expectEqual(accessibility.Role.alertdialog, .alertdialog);
    try testing.expectEqual(accessibility.Role.alert, .alert);
    try testing.expectEqual(accessibility.Role.status, .status);
}

test "Role - list roles" {
    try testing.expectEqual(accessibility.Role.list, .list);
    try testing.expectEqual(accessibility.Role.listitem, .listitem);
}

test "Role - table roles" {
    try testing.expectEqual(accessibility.Role.table, .table);
    try testing.expectEqual(accessibility.Role.row, .row);
    try testing.expectEqual(accessibility.Role.cell, .cell);
    try testing.expectEqual(accessibility.Role.columnheader, .columnheader);
    try testing.expectEqual(accessibility.Role.rowheader, .rowheader);
    try testing.expectEqual(accessibility.Role.grid, .grid);
    try testing.expectEqual(accessibility.Role.gridcell, .gridcell);
}

test "Role - media roles" {
    try testing.expectEqual(accessibility.Role.img, .img);
    try testing.expectEqual(accessibility.Role.figure, .figure);
    try testing.expectEqual(accessibility.Role.math, .math);
}

test "Role - other roles" {
    try testing.expectEqual(accessibility.Role.separator, .separator);
    try testing.expectEqual(accessibility.Role.none, .none);
    try testing.expectEqual(accessibility.Role.presentation, .presentation);
}

// AccessibleElement tests
test "AccessibleElement - minimal button" {
    const element = accessibility.AccessibleElement{
        .role = .button,
    };

    try testing.expectEqual(accessibility.Role.button, element.role);
    try testing.expectEqual(@as(?[]const u8, null), element.label);
    try testing.expect(!element.focusable);
    try testing.expect(!element.disabled);
}

test "AccessibleElement - labeled button" {
    const element = accessibility.AccessibleElement{
        .role = .button,
        .label = "Click Me",
        .focusable = true,
    };

    try testing.expectEqualStrings("Click Me", element.label.?);
    try testing.expect(element.focusable);
}

test "AccessibleElement - disabled button" {
    const element = accessibility.AccessibleElement{
        .role = .button,
        .label = "Disabled",
        .disabled = true,
    };

    try testing.expect(element.disabled);
}

test "AccessibleElement - checkbox states" {
    const checked_element = accessibility.AccessibleElement{
        .role = .checkbox,
        .label = "Accept Terms",
        .checked = true,
    };

    try testing.expectEqual(true, checked_element.checked.?);

    const unchecked_element = accessibility.AccessibleElement{
        .role = .checkbox,
        .label = "Opt-in",
        .checked = false,
    };

    try testing.expectEqual(false, unchecked_element.checked.?);
}

test "AccessibleElement - expandable element" {
    const collapsed = accessibility.AccessibleElement{
        .role = .menuitem,
        .label = "More Options",
        .expanded = false,
    };

    try testing.expectEqual(false, collapsed.expanded.?);

    const expanded = accessibility.AccessibleElement{
        .role = .menuitem,
        .label = "More Options",
        .expanded = true,
    };

    try testing.expectEqual(true, expanded.expanded.?);
}

test "AccessibleElement - toggle button" {
    const unpressed = accessibility.AccessibleElement{
        .role = .button,
        .label = "Mute",
        .pressed = false,
    };

    try testing.expectEqual(false, unpressed.pressed.?);

    const pressed = accessibility.AccessibleElement{
        .role = .button,
        .label = "Mute",
        .pressed = true,
    };

    try testing.expectEqual(true, pressed.pressed.?);
}

test "AccessibleElement - selected state" {
    const selected = accessibility.AccessibleElement{
        .role = .tab,
        .label = "Home",
        .selected = true,
    };

    try testing.expectEqual(true, selected.selected.?);
}

test "AccessibleElement - heading with level" {
    const h1 = accessibility.AccessibleElement{
        .role = .document,
        .label = "Main Heading",
        .level = 1,
    };

    try testing.expectEqual(@as(u32, 1), h1.level.?);

    const h3 = accessibility.AccessibleElement{
        .role = .document,
        .label = "Sub Heading",
        .level = 3,
    };

    try testing.expectEqual(@as(u32, 3), h3.level.?);
}

test "AccessibleElement - required field" {
    const element = accessibility.AccessibleElement{
        .role = .textbox,
        .label = "Email",
        .required = true,
    };

    try testing.expect(element.required);
}

test "AccessibleElement - readonly field" {
    const element = accessibility.AccessibleElement{
        .role = .textbox,
        .label = "Username",
        .readonly = true,
    };

    try testing.expect(element.readonly);
}

test "AccessibleElement - with description" {
    const element = accessibility.AccessibleElement{
        .role = .button,
        .label = "Submit",
        .description = "Submit the form to continue",
    };

    try testing.expectEqualStrings("Submit the form to continue", element.description.?);
}

test "AccessibleElement - with value" {
    const element = accessibility.AccessibleElement{
        .role = .slider,
        .label = "Volume",
        .value = "75",
    };

    try testing.expectEqualStrings("75", element.value.?);
}

// Orientation tests
test "Orientation enum" {
    try testing.expectEqual(accessibility.Orientation.horizontal, .horizontal);
    try testing.expectEqual(accessibility.Orientation.vertical, .vertical);
}

test "AccessibleElement - horizontal orientation" {
    const element = accessibility.AccessibleElement{
        .role = .slider,
        .orientation = .horizontal,
    };

    try testing.expectEqual(accessibility.Orientation.horizontal, element.orientation);
}

test "AccessibleElement - vertical orientation" {
    const element = accessibility.AccessibleElement{
        .role = .slider,
        .orientation = .vertical,
    };

    try testing.expectEqual(accessibility.Orientation.vertical, element.orientation);
}

// LiveRegion tests
test "LiveRegion enum" {
    try testing.expectEqual(accessibility.LiveRegion.off, .off);
}

test "AccessibleElement - live region off" {
    const element = accessibility.AccessibleElement{
        .role = .status,
        .live = .off,
    };

    try testing.expectEqual(accessibility.LiveRegion.off, element.live);
}

test "AccessibleElement - atomic update" {
    const element = accessibility.AccessibleElement{
        .role = .status,
        .atomic = true,
    };

    try testing.expect(element.atomic);
}

test "AccessibleElement - busy state" {
    const element = accessibility.AccessibleElement{
        .role = .region,
        .busy = true,
    };

    try testing.expect(element.busy);
}

// Complex element tests
test "AccessibleElement - form with all properties" {
    const element = accessibility.AccessibleElement{
        .role = .textbox,
        .label = "Email Address",
        .description = "Enter your email to receive updates",
        .value = "user@example.com",
        .focusable = true,
        .disabled = false,
        .required = true,
        .readonly = false,
        .orientation = .horizontal,
    };

    try testing.expectEqual(accessibility.Role.textbox, element.role);
    try testing.expectEqualStrings("Email Address", element.label.?);
    try testing.expectEqualStrings("Enter your email to receive updates", element.description.?);
    try testing.expectEqualStrings("user@example.com", element.value.?);
    try testing.expect(element.focusable);
    try testing.expect(!element.disabled);
    try testing.expect(element.required);
    try testing.expect(!element.readonly);
}
