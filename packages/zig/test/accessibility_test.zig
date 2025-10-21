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

// FocusManager tests
test "FocusManager - initialization" {
    const allocator = testing.allocator;
    var manager = accessibility.FocusManager.init(allocator);
    defer manager.deinit();

    try testing.expect(manager.focused_element == null);
    try testing.expect(manager.focus_order.items.len == 0);
}

test "FocusManager - add to focus order" {
    const allocator = testing.allocator;
    var manager = accessibility.FocusManager.init(allocator);
    defer manager.deinit();

    var element1 = accessibility.AccessibleElement{
        .role = .button,
        .label = "Button 1",
        .focusable = true,
    };

    var element2 = accessibility.AccessibleElement{
        .role = .button,
        .label = "Button 2",
        .focusable = true,
    };

    try manager.addToFocusOrder(&element1);
    try manager.addToFocusOrder(&element2);

    try testing.expect(manager.focus_order.items.len == 2);
}

test "FocusManager - skip disabled elements" {
    const allocator = testing.allocator;
    var manager = accessibility.FocusManager.init(allocator);
    defer manager.deinit();

    var disabled = accessibility.AccessibleElement{
        .role = .button,
        .label = "Disabled",
        .focusable = true,
        .disabled = true,
    };

    try manager.addToFocusOrder(&disabled);

    // Should not add disabled element
    try testing.expect(manager.focus_order.items.len == 0);
}

test "FocusManager - skip non-focusable elements" {
    const allocator = testing.allocator;
    var manager = accessibility.FocusManager.init(allocator);
    defer manager.deinit();

    var non_focusable = accessibility.AccessibleElement{
        .role = .section,
        .focusable = false,
    };

    try manager.addToFocusOrder(&non_focusable);

    try testing.expect(manager.focus_order.items.len == 0);
}

test "FocusManager - focus next" {
    const allocator = testing.allocator;
    var manager = accessibility.FocusManager.init(allocator);
    defer manager.deinit();

    var element1 = accessibility.AccessibleElement{
        .role = .button,
        .label = "First",
        .focusable = true,
    };

    var element2 = accessibility.AccessibleElement{
        .role = .button,
        .label = "Second",
        .focusable = true,
    };

    var element3 = accessibility.AccessibleElement{
        .role = .button,
        .label = "Third",
        .focusable = true,
    };

    try manager.addToFocusOrder(&element1);
    try manager.addToFocusOrder(&element2);
    try manager.addToFocusOrder(&element3);

    // Focus first element
    const first = manager.focusNext();
    try testing.expect(first != null);
    try testing.expectEqualStrings("First", first.?.label.?);

    // Focus second element
    const second = manager.focusNext();
    try testing.expect(second != null);
    try testing.expectEqualStrings("Second", second.?.label.?);

    // Focus third element
    const third = manager.focusNext();
    try testing.expect(third != null);
    try testing.expectEqualStrings("Third", third.?.label.?);

    // Wrap around to first
    const wrap = manager.focusNext();
    try testing.expect(wrap != null);
    try testing.expectEqualStrings("First", wrap.?.label.?);
}

test "FocusManager - focus previous" {
    const allocator = testing.allocator;
    var manager = accessibility.FocusManager.init(allocator);
    defer manager.deinit();

    var element1 = accessibility.AccessibleElement{
        .role = .button,
        .label = "First",
        .focusable = true,
    };

    var element2 = accessibility.AccessibleElement{
        .role = .button,
        .label = "Second",
        .focusable = true,
    };

    try manager.addToFocusOrder(&element1);
    try manager.addToFocusOrder(&element2);

    // Focus first element
    _ = manager.focusNext();

    // Go back - should wrap to second
    const prev = manager.focusPrevious();
    try testing.expect(prev != null);
    try testing.expectEqualStrings("Second", prev.?.label.?);
}

test "FocusManager - focus specific element" {
    const allocator = testing.allocator;
    var manager = accessibility.FocusManager.init(allocator);
    defer manager.deinit();

    var element = accessibility.AccessibleElement{
        .role = .button,
        .label = "Target",
        .focusable = true,
    };

    try manager.addToFocusOrder(&element);
    manager.focus(&element);

    try testing.expect(manager.focused_element != null);
    try testing.expectEqualStrings("Target", manager.focused_element.?.label.?);
}

test "FocusManager - blur removes focus" {
    const allocator = testing.allocator;
    var manager = accessibility.FocusManager.init(allocator);
    defer manager.deinit();

    var element = accessibility.AccessibleElement{
        .role = .button,
        .focusable = true,
    };

    manager.focus(&element);
    try testing.expect(manager.focused_element != null);

    manager.blur();
    try testing.expect(manager.focused_element == null);
}

test "FocusManager - cannot focus disabled element" {
    const allocator = testing.allocator;
    var manager = accessibility.FocusManager.init(allocator);
    defer manager.deinit();

    var element = accessibility.AccessibleElement{
        .role = .button,
        .focusable = true,
        .disabled = true,
    };

    manager.focus(&element);
    try testing.expect(manager.focused_element == null);
}

test "FocusManager - empty focus order" {
    const allocator = testing.allocator;
    var manager = accessibility.FocusManager.init(allocator);
    defer manager.deinit();

    const next = manager.focusNext();
    try testing.expect(next == null);

    const prev = manager.focusPrevious();
    try testing.expect(prev == null);
}

// Accessibility validation tests
test "Accessibility - validate element with label" {
    const allocator = testing.allocator;
    var a11y = accessibility.Accessibility.init(allocator);
    defer a11y.deinit();

    const element = accessibility.AccessibleElement{
        .role = .button,
        .label = "Submit",
    };

    try testing.expect(a11y.validateElement(element));
}

test "Accessibility - validate element with description" {
    const allocator = testing.allocator;
    var a11y = accessibility.Accessibility.init(allocator);
    defer a11y.deinit();

    const element = accessibility.AccessibleElement{
        .role = .button,
        .description = "Submit the form",
    };

    try testing.expect(a11y.validateElement(element));
}

test "Accessibility - invalid element without label or description" {
    const allocator = testing.allocator;
    var a11y = accessibility.Accessibility.init(allocator);
    defer a11y.deinit();

    const element = accessibility.AccessibleElement{
        .role = .button,
    };

    try testing.expect(!a11y.validateElement(element));
}

test "Accessibility - presentation role doesn't need label" {
    const allocator = testing.allocator;
    var a11y = accessibility.Accessibility.init(allocator);
    defer a11y.deinit();

    const element = accessibility.AccessibleElement{
        .role = .presentation,
    };

    try testing.expect(a11y.validateElement(element));
}

test "Accessibility - interactive element must be focusable" {
    const allocator = testing.allocator;
    var a11y = accessibility.Accessibility.init(allocator);
    defer a11y.deinit();

    const invalid = accessibility.AccessibleElement{
        .role = .button,
        .label = "Click",
        .focusable = false,
    };

    try testing.expect(!a11y.validateElement(invalid));

    const valid = accessibility.AccessibleElement{
        .role = .button,
        .label = "Click",
        .focusable = true,
    };

    try testing.expect(a11y.validateElement(valid));
}

test "Accessibility - high contrast mode" {
    const allocator = testing.allocator;
    var a11y = accessibility.Accessibility.init(allocator);
    defer a11y.deinit();

    try testing.expect(!a11y.high_contrast);

    a11y.setHighContrast(true);
    try testing.expect(a11y.high_contrast);

    a11y.setHighContrast(false);
    try testing.expect(!a11y.high_contrast);
}

test "Accessibility - reduce motion mode" {
    const allocator = testing.allocator;
    var a11y = accessibility.Accessibility.init(allocator);
    defer a11y.deinit();

    try testing.expect(!a11y.reduce_motion);

    a11y.setReduceMotion(true);
    try testing.expect(a11y.reduce_motion);

    a11y.setReduceMotion(false);
    try testing.expect(!a11y.reduce_motion);
}

// ContrastChecker tests (WCAG 2.1)
test "ContrastChecker - calculate relative luminance" {
    // Black (#000000)
    const black_lum = accessibility.ContrastChecker.getRelativeLuminance(0, 0, 0);
    try testing.expect(black_lum == 0.0);

    // White (#FFFFFF)
    const white_lum = accessibility.ContrastChecker.getRelativeLuminance(255, 255, 255);
    try testing.expect(white_lum == 1.0);

    // Gray (#808080) should be around 0.216
    const gray_lum = accessibility.ContrastChecker.getRelativeLuminance(128, 128, 128);
    try testing.expect(gray_lum > 0.2 and gray_lum < 0.25);
}

test "ContrastChecker - black and white contrast ratio" {
    const ratio = accessibility.ContrastChecker.getContrastRatio(0, 0, 0, 255, 255, 255);

    // Black and white should have 21:1 ratio
    try testing.expect(ratio >= 20.9 and ratio <= 21.1);
}

test "ContrastChecker - same color contrast ratio" {
    const ratio = accessibility.ContrastChecker.getContrastRatio(100, 100, 100, 100, 100, 100);

    // Same color should have 1:1 ratio
    try testing.expect(ratio == 1.0);
}

test "ContrastChecker - WCAG AA normal text" {
    // Black on white passes AA (ratio 21:1 > 4.5:1)
    const high_ratio = accessibility.ContrastChecker.getContrastRatio(0, 0, 0, 255, 255, 255);
    try testing.expect(accessibility.ContrastChecker.meetsWCAG_AA(high_ratio, false));

    // Low contrast fails
    const low_ratio = 3.0;
    try testing.expect(!accessibility.ContrastChecker.meetsWCAG_AA(low_ratio, false));
}

test "ContrastChecker - WCAG AA large text" {
    // Large text requires 3:1 ratio
    const ratio = 3.5;
    try testing.expect(accessibility.ContrastChecker.meetsWCAG_AA(ratio, true));

    const low_ratio = 2.5;
    try testing.expect(!accessibility.ContrastChecker.meetsWCAG_AA(low_ratio, true));
}

test "ContrastChecker - WCAG AAA normal text" {
    // AAA requires 7:1 for normal text
    const high_ratio = accessibility.ContrastChecker.getContrastRatio(0, 0, 0, 255, 255, 255);
    try testing.expect(accessibility.ContrastChecker.meetsWCAG_AAA(high_ratio, false));

    const medium_ratio = 5.0;
    try testing.expect(!accessibility.ContrastChecker.meetsWCAG_AAA(medium_ratio, false));
}

test "ContrastChecker - WCAG AAA large text" {
    // AAA requires 4.5:1 for large text
    const ratio = 5.0;
    try testing.expect(accessibility.ContrastChecker.meetsWCAG_AAA(ratio, true));

    const low_ratio = 4.0;
    try testing.expect(!accessibility.ContrastChecker.meetsWCAG_AAA(low_ratio, true));
}

// Screen reader announcement tests
test "ScreenReaderAnnouncement - creation" {
    const announcement = accessibility.ScreenReaderAnnouncement{
        .message = "File uploaded successfully",
        .priority = .medium,
        .interrupt = false,
    };

    try testing.expectEqualStrings("File uploaded successfully", announcement.message);
    try testing.expectEqual(accessibility.AnnouncementPriority.medium, announcement.priority);
    try testing.expect(!announcement.interrupt);
}

test "ScreenReaderAnnouncement - all priority levels" {
    const low = accessibility.ScreenReaderAnnouncement{
        .message = "Low priority",
        .priority = .low,
    };
    try testing.expectEqual(accessibility.AnnouncementPriority.low, low.priority);

    const medium = accessibility.ScreenReaderAnnouncement{
        .message = "Medium priority",
        .priority = .medium,
    };
    try testing.expectEqual(accessibility.AnnouncementPriority.medium, medium.priority);

    const high = accessibility.ScreenReaderAnnouncement{
        .message = "High priority",
        .priority = .high,
    };
    try testing.expectEqual(accessibility.AnnouncementPriority.high, high.priority);

    const critical = accessibility.ScreenReaderAnnouncement{
        .message = "Critical priority",
        .priority = .critical,
    };
    try testing.expectEqual(accessibility.AnnouncementPriority.critical, critical.priority);
}

test "ScreenReaderAnnouncement - interrupt flag" {
    const interrupting = accessibility.ScreenReaderAnnouncement{
        .message = "Error occurred!",
        .priority = .critical,
        .interrupt = true,
    };

    try testing.expect(interrupting.interrupt);
}

// SemanticHTML tests
test "SemanticHTML - button mapping" {
    const html = accessibility.SemanticHTML.roleToHTML(.button);
    try testing.expectEqualStrings("button", html);
}

test "SemanticHTML - input mappings" {
    try testing.expectEqualStrings("input[type=checkbox]", accessibility.SemanticHTML.roleToHTML(.checkbox));
    try testing.expectEqualStrings("input[type=radio]", accessibility.SemanticHTML.roleToHTML(.radio));
    try testing.expectEqualStrings("input[type=text]", accessibility.SemanticHTML.roleToHTML(.textbox));
}

test "SemanticHTML - structural elements" {
    try testing.expectEqualStrings("nav", accessibility.SemanticHTML.roleToHTML(.navigation));
    try testing.expectEqualStrings("main", accessibility.SemanticHTML.roleToHTML(.main));
    try testing.expectEqualStrings("article", accessibility.SemanticHTML.roleToHTML(.article));
    try testing.expectEqualStrings("section", accessibility.SemanticHTML.roleToHTML(.section));
    try testing.expectEqualStrings("header", accessibility.SemanticHTML.roleToHTML(.banner));
    try testing.expectEqualStrings("footer", accessibility.SemanticHTML.roleToHTML(.contentinfo));
    try testing.expectEqualStrings("aside", accessibility.SemanticHTML.roleToHTML(.complementary));
}

test "SemanticHTML - list elements" {
    try testing.expectEqualStrings("ul/ol", accessibility.SemanticHTML.roleToHTML(.list));
    try testing.expectEqualStrings("li", accessibility.SemanticHTML.roleToHTML(.listitem));
}

test "SemanticHTML - table elements" {
    try testing.expectEqualStrings("table", accessibility.SemanticHTML.roleToHTML(.table));
    try testing.expectEqualStrings("tr", accessibility.SemanticHTML.roleToHTML(.row));
    try testing.expectEqualStrings("td", accessibility.SemanticHTML.roleToHTML(.cell));
    try testing.expectEqualStrings("th", accessibility.SemanticHTML.roleToHTML(.columnheader));
}

test "SemanticHTML - media elements" {
    try testing.expectEqualStrings("img", accessibility.SemanticHTML.roleToHTML(.img));
    try testing.expectEqualStrings("figure", accessibility.SemanticHTML.roleToHTML(.figure));
}

test "SemanticHTML - fallback to div" {
    try testing.expectEqualStrings("div", accessibility.SemanticHTML.roleToHTML(.region));
    try testing.expectEqualStrings("div", accessibility.SemanticHTML.roleToHTML(.application));
}

// Keyboard navigation tests
test "KeyboardNav - NavKey enum" {
    try testing.expectEqual(accessibility.KeyboardNav.NavKey.tab, .tab);
    try testing.expectEqual(accessibility.KeyboardNav.NavKey.shift_tab, .shift_tab);
    try testing.expectEqual(accessibility.KeyboardNav.NavKey.arrow_up, .arrow_up);
    try testing.expectEqual(accessibility.KeyboardNav.NavKey.arrow_down, .arrow_down);
    try testing.expectEqual(accessibility.KeyboardNav.NavKey.arrow_left, .arrow_left);
    try testing.expectEqual(accessibility.KeyboardNav.NavKey.arrow_right, .arrow_right);
    try testing.expectEqual(accessibility.KeyboardNav.NavKey.home, .home);
    try testing.expectEqual(accessibility.KeyboardNav.NavKey.end, .end);
    try testing.expectEqual(accessibility.KeyboardNav.NavKey.enter, .enter);
    try testing.expectEqual(accessibility.KeyboardNav.NavKey.space, .space);
    try testing.expectEqual(accessibility.KeyboardNav.NavKey.escape, .escape);
}

test "NavContext - enum values" {
    try testing.expectEqual(accessibility.NavContext.menu, .menu);
    try testing.expectEqual(accessibility.NavContext.list, .list);
    try testing.expectEqual(accessibility.NavContext.grid, .grid);
    try testing.expectEqual(accessibility.NavContext.tabs, .tabs);
}

// Complex integration tests
test "Integration - complete form accessibility" {
    const allocator = testing.allocator;
    var manager = accessibility.FocusManager.init(allocator);
    defer manager.deinit();

    var username = accessibility.AccessibleElement{
        .role = .textbox,
        .label = "Username",
        .description = "Enter your username",
        .focusable = true,
        .required = true,
    };

    var password = accessibility.AccessibleElement{
        .role = .textbox,
        .label = "Password",
        .description = "Enter your password",
        .focusable = true,
        .required = true,
    };

    var remember = accessibility.AccessibleElement{
        .role = .checkbox,
        .label = "Remember me",
        .focusable = true,
        .checked = false,
    };

    var submit = accessibility.AccessibleElement{
        .role = .button,
        .label = "Sign In",
        .focusable = true,
    };

    try manager.addToFocusOrder(&username);
    try manager.addToFocusOrder(&password);
    try manager.addToFocusOrder(&remember);
    try manager.addToFocusOrder(&submit);

    try testing.expect(manager.focus_order.items.len == 4);

    // Tab through form
    const first = manager.focusNext();
    try testing.expectEqualStrings("Username", first.?.label.?);

    const second = manager.focusNext();
    try testing.expectEqualStrings("Password", second.?.label.?);

    const third = manager.focusNext();
    try testing.expectEqualStrings("Remember me", third.?.label.?);

    const fourth = manager.focusNext();
    try testing.expectEqualStrings("Sign In", fourth.?.label.?);
}

test "Integration - menu with disabled items" {
    const allocator = testing.allocator;
    var manager = accessibility.FocusManager.init(allocator);
    defer manager.deinit();

    var item1 = accessibility.AccessibleElement{
        .role = .menuitem,
        .label = "New",
        .focusable = true,
    };

    var item2 = accessibility.AccessibleElement{
        .role = .menuitem,
        .label = "Save",
        .focusable = true,
        .disabled = true,
    };

    var item3 = accessibility.AccessibleElement{
        .role = .menuitem,
        .label = "Close",
        .focusable = true,
    };

    try manager.addToFocusOrder(&item1);
    try manager.addToFocusOrder(&item2); // Should not be added (disabled)
    try manager.addToFocusOrder(&item3);

    try testing.expect(manager.focus_order.items.len == 2);
}

test "Integration - accessible color combinations" {
    // Test common UI color combinations

    // Primary button - white text on blue (#0066CC)
    const blue_white = accessibility.ContrastChecker.getContrastRatio(255, 255, 255, 0, 102, 204);
    try testing.expect(accessibility.ContrastChecker.meetsWCAG_AA(blue_white, false));
    try testing.expect(accessibility.ContrastChecker.meetsWCAG_AAA(blue_white, false));

    // Error text - red (#CC0000) on white
    const red_white = accessibility.ContrastChecker.getContrastRatio(204, 0, 0, 255, 255, 255);
    try testing.expect(accessibility.ContrastChecker.meetsWCAG_AA(red_white, false));

    // Success text - green (#00AA00) on white
    const green_white = accessibility.ContrastChecker.getContrastRatio(0, 170, 0, 255, 255, 255);
    try testing.expect(accessibility.ContrastChecker.meetsWCAG_AA(green_white, false));
}
