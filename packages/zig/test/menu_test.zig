const std = @import("std");
const testing = std.testing;
const menu = @import("../src/menu.zig");

test "MenuItem - basic creation" {
    const item = menu.MenuItem{
        .title = "File",
        .key_equivalent = "f",
        .action = null,
        .submenu = null,
    };

    try testing.expectEqualStrings("File", item.title);
    try testing.expectEqualStrings("f", item.key_equivalent.?);
    try testing.expect(item.action == null);
    try testing.expect(item.submenu == null);
}

test "MenuItem - with action" {
    const testAction = struct {
        fn action() void {}
    }.action;

    const item = menu.MenuItem{
        .title = "Save",
        .key_equivalent = "s",
        .action = testAction,
        .submenu = null,
    };

    try testing.expectEqualStrings("Save", item.title);
    try testing.expect(item.action != null);
}

test "MenuItem - with submenu" {
    const submenu_items = [_]menu.MenuItem{
        .{ .title = "New", .key_equivalent = "n" },
        .{ .title = "Open", .key_equivalent = "o" },
    };

    const item = menu.MenuItem{
        .title = "File",
        .submenu = &submenu_items,
    };

    try testing.expectEqualStrings("File", item.title);
    try testing.expect(item.submenu != null);
    try testing.expectEqual(@as(usize, 2), item.submenu.?.len);
    try testing.expectEqualStrings("New", item.submenu.?[0].title);
    try testing.expectEqualStrings("Open", item.submenu.?[1].title);
}

test "Menu - init and deinit" {
    const items = [_]menu.MenuItem{
        .{ .title = "File" },
        .{ .title = "Edit" },
    };

    var m = menu.Menu.init(testing.allocator, &items);
    defer m.deinit();

    try testing.expectEqual(@as(usize, 2), m.items.len);
    try testing.expectEqualStrings("File", m.items[0].title);
    try testing.expectEqualStrings("Edit", m.items[1].title);
}

test "Menu - createStandardMenuBar" {
    var m = menu.createStandardMenuBar("TestApp");
    defer m.deinit();

    try testing.expect(m.items.len > 0);

    // Check File menu
    try testing.expectEqualStrings("File", m.items[0].title);
    try testing.expect(m.items[0].submenu != null);

    // Check Edit menu
    try testing.expectEqualStrings("Edit", m.items[1].title);
    try testing.expect(m.items[1].submenu != null);

    // Check View menu
    try testing.expectEqualStrings("View", m.items[2].title);
    try testing.expect(m.items[2].submenu != null);
}

test "Menu - standard menu has expected items" {
    var m = menu.createStandardMenuBar("TestApp");
    defer m.deinit();

    // Verify File submenu items
    const file_submenu = m.items[0].submenu.?;
    try testing.expectEqualStrings("New", file_submenu[0].title);
    try testing.expectEqualStrings("n", file_submenu[0].key_equivalent.?);
    try testing.expectEqualStrings("Open...", file_submenu[1].title);
    try testing.expectEqualStrings("o", file_submenu[1].key_equivalent.?);
    try testing.expectEqualStrings("Save", file_submenu[2].title);
    try testing.expectEqualStrings("s", file_submenu[2].key_equivalent.?);
    try testing.expectEqualStrings("Close", file_submenu[3].title);
    try testing.expectEqualStrings("w", file_submenu[3].key_equivalent.?);

    // Verify Edit submenu items
    const edit_submenu = m.items[1].submenu.?;
    try testing.expectEqualStrings("Undo", edit_submenu[0].title);
    try testing.expectEqualStrings("z", edit_submenu[0].key_equivalent.?);
    try testing.expectEqualStrings("Redo", edit_submenu[1].title);
    try testing.expectEqualStrings("Z", edit_submenu[1].key_equivalent.?);
    try testing.expectEqualStrings("Cut", edit_submenu[2].title);
    try testing.expectEqualStrings("x", edit_submenu[2].key_equivalent.?);
    try testing.expectEqualStrings("Copy", edit_submenu[3].title);
    try testing.expectEqualStrings("c", edit_submenu[3].key_equivalent.?);
    try testing.expectEqualStrings("Paste", edit_submenu[4].title);
    try testing.expectEqualStrings("v", edit_submenu[4].key_equivalent.?);

    // Verify View submenu items
    const view_submenu = m.items[2].submenu.?;
    try testing.expectEqualStrings("Reload", view_submenu[0].title);
    try testing.expectEqualStrings("r", view_submenu[0].key_equivalent.?);
    try testing.expectEqualStrings("Toggle DevTools", view_submenu[1].title);
    try testing.expectEqualStrings("i", view_submenu[1].key_equivalent.?);
}

test "MenuItem - default values" {
    const item = menu.MenuItem{
        .title = "Help",
    };

    try testing.expectEqualStrings("Help", item.title);
    try testing.expect(item.key_equivalent == null);
    try testing.expect(item.action == null);
    try testing.expect(item.submenu == null);
}
