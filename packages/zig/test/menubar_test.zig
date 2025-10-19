const std = @import("std");
const testing = std.testing;
const menubar = @import("../src/menubar.zig");

test "MenubarApp - basic initialization" {
    const allocator = testing.allocator;
    var app = try menubar.MenubarApp.init(allocator, "Test App");
    defer app.deinit();

    try testing.expectEqualStrings("Test App", app.title);
    try testing.expectEqual(@as(?[]const u8, null), app.icon);
    try testing.expectEqual(@as(?[]const u8, null), app.tooltip);
    try testing.expect(app.visible);
}

test "MenubarApp - set icon" {
    const allocator = testing.allocator;
    var app = try menubar.MenubarApp.init(allocator, "Test App");
    defer app.deinit();

    try app.setIcon("icon.png");

    try testing.expectEqualStrings("icon.png", app.icon.?);
}

test "MenubarApp - set tooltip" {
    const allocator = testing.allocator;
    var app = try menubar.MenubarApp.init(allocator, "Test App");
    defer app.deinit();

    app.setTooltip("This is a tooltip");

    try testing.expectEqualStrings("This is a tooltip", app.tooltip.?);
}

test "MenubarApp - visibility control" {
    const allocator = testing.allocator;
    var app = try menubar.MenubarApp.init(allocator, "Test App");
    defer app.deinit();

    try testing.expect(app.visible);

    app.hide();
    try testing.expect(!app.visible);

    try app.show();
    try testing.expect(app.visible);
}

test "Menu - initialization and cleanup" {
    const allocator = testing.allocator;
    var menu = try menubar.Menu.init(allocator);
    defer allocator.destroy(menu);
    defer menu.deinit();

    try testing.expectEqual(@as(usize, 0), menu.items.items.len);
}

test "Menu - add item" {
    const allocator = testing.allocator;
    var menu = try menubar.Menu.init(allocator);
    defer allocator.destroy(menu);
    defer menu.deinit();

    const item = menubar.MenuItem.init(allocator, "Test Item", null);
    try menu.addItem(item);

    try testing.expectEqual(@as(usize, 1), menu.items.items.len);
    try testing.expectEqualStrings("Test Item", menu.items.items[0].label);
}

test "Menu - add multiple items" {
    const allocator = testing.allocator;
    var menu = try menubar.Menu.init(allocator);
    defer allocator.destroy(menu);
    defer menu.deinit();

    const item1 = menubar.MenuItem.init(allocator, "Item 1", null);
    const item2 = menubar.MenuItem.init(allocator, "Item 2", null);
    const item3 = menubar.MenuItem.init(allocator, "Item 3", null);

    try menu.addItem(item1);
    try menu.addItem(item2);
    try menu.addItem(item3);

    try testing.expectEqual(@as(usize, 3), menu.items.items.len);
    try testing.expectEqualStrings("Item 1", menu.items.items[0].label);
    try testing.expectEqualStrings("Item 2", menu.items.items[1].label);
    try testing.expectEqualStrings("Item 3", menu.items.items[2].label);
}

test "Menu - add separator" {
    const allocator = testing.allocator;
    var menu = try menubar.Menu.init(allocator);
    defer allocator.destroy(menu);
    defer menu.deinit();

    const item1 = menubar.MenuItem.init(allocator, "Item 1", null);
    try menu.addItem(item1);
    try menu.addSeparator();
    const item2 = menubar.MenuItem.init(allocator, "Item 2", null);
    try menu.addItem(item2);

    try testing.expectEqual(@as(usize, 3), menu.items.items.len);
    try testing.expect(!menu.items.items[0].separator);
    try testing.expect(menu.items.items[1].separator);
    try testing.expect(!menu.items.items[2].separator);
}

test "Menu - remove item" {
    const allocator = testing.allocator;
    var menu = try menubar.Menu.init(allocator);
    defer allocator.destroy(menu);
    defer menu.deinit();

    const item1 = menubar.MenuItem.init(allocator, "Item 1", null);
    const item2 = menubar.MenuItem.init(allocator, "Item 2", null);
    try menu.addItem(item1);
    try menu.addItem(item2);

    try testing.expectEqual(@as(usize, 2), menu.items.items.len);

    menu.removeItem(0);

    try testing.expectEqual(@as(usize, 1), menu.items.items.len);
}

test "Menu - clear" {
    const allocator = testing.allocator;
    var menu = try menubar.Menu.init(allocator);
    defer allocator.destroy(menu);
    defer menu.deinit();

    const item1 = menubar.MenuItem.init(allocator, "Item 1", null);
    const item2 = menubar.MenuItem.init(allocator, "Item 2", null);
    try menu.addItem(item1);
    try menu.addItem(item2);

    try testing.expectEqual(@as(usize, 2), menu.items.items.len);

    menu.clear();

    try testing.expectEqual(@as(usize, 0), menu.items.items.len);
}

test "MenuItem - basic creation" {
    const allocator = testing.allocator;
    const item = menubar.MenuItem.init(allocator, "Test Item", null);

    try testing.expectEqualStrings("Test Item", item.label);
    try testing.expect(item.enabled);
    try testing.expect(!item.checked);
    try testing.expectEqual(@as(?[]const u8, null), item.icon);
    try testing.expectEqual(@as(?menubar.MenuItem.Shortcut, null), item.shortcut);
    try testing.expect(!item.separator);
}

test "MenuItem - with icon" {
    const allocator = testing.allocator;
    var item = menubar.MenuItem.init(allocator, "Test Item", null);
    item.setIcon("icon.png");

    try testing.expectEqualStrings("icon.png", item.icon.?);
}

test "MenuItem - enabled/disabled" {
    const allocator = testing.allocator;
    var item = menubar.MenuItem.init(allocator, "Test Item", null);

    try testing.expect(item.enabled);

    item.setEnabled(false);
    try testing.expect(!item.enabled);

    item.setEnabled(true);
    try testing.expect(item.enabled);
}

test "MenuItem - checked state" {
    const allocator = testing.allocator;
    var item = menubar.MenuItem.init(allocator, "Test Item", null);

    try testing.expect(!item.checked);

    item.setChecked(true);
    try testing.expect(item.checked);

    item.setChecked(false);
    try testing.expect(!item.checked);
}

test "MenuItem - Shortcut creation" {
    const shortcut = menubar.MenuItem.Shortcut{
        .key = "S",
        .modifiers = .{ .ctrl = true, .shift = false },
    };

    try testing.expectEqualStrings("S", shortcut.key);
    try testing.expect(shortcut.modifiers.ctrl);
    try testing.expect(!shortcut.modifiers.shift);
    try testing.expect(!shortcut.modifiers.alt);
    try testing.expect(!shortcut.modifiers.meta);
}

test "MenuItem - set shortcut" {
    const allocator = testing.allocator;
    var item = menubar.MenuItem.init(allocator, "Save", null);

    const shortcut = menubar.MenuItem.Shortcut{
        .key = "S",
        .modifiers = .{ .ctrl = true },
    };

    item.setShortcut(shortcut);

    try testing.expectEqualStrings("S", item.shortcut.?.key);
    try testing.expect(item.shortcut.?.modifiers.ctrl);
}

test "MenuItem - with submenu" {
    const allocator = testing.allocator;
    var item = menubar.MenuItem.init(allocator, "File", null);
    defer item.deinit();

    var submenu = try menubar.Menu.init(allocator);
    const subitem = menubar.MenuItem.init(allocator, "Open", null);
    try submenu.addItem(subitem);

    item.setSubmenu(submenu);

    try testing.expectEqual(@as(usize, 1), item.submenu.?.items.items.len);
}

test "Window - initialization" {
    const window = menubar.Window.init(400, 300);

    try testing.expectEqual(@as(u32, 400), window.width);
    try testing.expectEqual(@as(u32, 300), window.height);
    try testing.expectEqual(@as(i32, 0), window.x);
    try testing.expectEqual(@as(i32, 0), window.y);
    try testing.expect(!window.visible);
}

test "Window - visibility" {
    var window = menubar.Window.init(400, 300);

    try testing.expect(!window.visible);

    window.show();
    try testing.expect(window.visible);

    window.hide();
    try testing.expect(!window.visible);
}

test "Window - position" {
    var window = menubar.Window.init(400, 300);

    window.setPosition(100, 200);

    try testing.expectEqual(@as(i32, 100), window.x);
    try testing.expectEqual(@as(i32, 200), window.y);
}

test "Window - size" {
    var window = menubar.Window.init(400, 300);

    window.setSize(800, 600);

    try testing.expectEqual(@as(u32, 800), window.width);
    try testing.expectEqual(@as(u32, 600), window.height);
}

test "MenubarBuilder - basic build" {
    const allocator = testing.allocator;
    const builder = menubar.MenubarBuilder.new(allocator, "My App");

    try testing.expectEqualStrings("My App", builder.title);
    try testing.expectEqual(@as(?[]const u8, null), builder.icon_path);
    try testing.expectEqual(@as(?[]const u8, null), builder.tooltip_text);
}

test "MenubarBuilder - with icon" {
    const allocator = testing.allocator;
    const builder = menubar.MenubarBuilder.new(allocator, "My App")
        .icon("app-icon.png");

    try testing.expectEqualStrings("app-icon.png", builder.icon_path.?);
}

test "MenubarBuilder - with tooltip" {
    const allocator = testing.allocator;
    const builder = menubar.MenubarBuilder.new(allocator, "My App")
        .tooltip("My Application");

    try testing.expectEqualStrings("My Application", builder.tooltip_text.?);
}

test "MenubarBuilder - complete build" {
    const allocator = testing.allocator;

    var menu = try menubar.Menu.init(allocator);
    const item = menubar.MenuItem.init(allocator, "Quit", null);
    try menu.addItem(item);

    var window = menubar.Window.init(400, 300);

    var app = try menubar.MenubarBuilder.new(allocator, "My App")
        .icon("icon.png")
        .tooltip("My Application")
        .menu(menu)
        .window(&window)
        .build();
    defer app.deinit();

    try testing.expectEqualStrings("My App", app.title);
    try testing.expectEqualStrings("icon.png", app.icon.?);
    try testing.expectEqualStrings("My Application", app.tooltip.?);
}

test "MenubarNotification - basic creation" {
    const notification = menubar.MenubarNotification.init("Title", "Message");

    try testing.expectEqualStrings("Title", notification.title);
    try testing.expectEqualStrings("Message", notification.message);
    try testing.expectEqual(@as(?[]const u8, null), notification.icon);
    try testing.expect(notification.sound);
    try testing.expectEqual(@as(u64, 3000), notification.duration_ms);
}

test "ClickAction enum" {
    try testing.expectEqual(menubar.ClickAction.left_click, .left_click);
    try testing.expectEqual(menubar.ClickAction.right_click, .right_click);
    try testing.expectEqual(menubar.ClickAction.double_click, .double_click);
    try testing.expectEqual(menubar.ClickAction.middle_click, .middle_click);
}

test "MenubarManager - initialization" {
    const allocator = testing.allocator;
    var manager = menubar.MenubarManager.init(allocator);
    defer manager.deinit();

    try testing.expectEqual(@as(usize, 0), manager.apps.items.len);
}

test "MenubarManager - add app" {
    const allocator = testing.allocator;
    var manager = menubar.MenubarManager.init(allocator);
    defer manager.deinit();

    const app = try allocator.create(menubar.MenubarApp);
    app.* = try menubar.MenubarApp.init(allocator, "App 1");

    try manager.addApp(app);

    try testing.expectEqual(@as(usize, 1), manager.apps.items.len);
}

test "MenubarManager - get app" {
    const allocator = testing.allocator;
    var manager = menubar.MenubarManager.init(allocator);
    defer manager.deinit();

    const app1 = try allocator.create(menubar.MenubarApp);
    app1.* = try menubar.MenubarApp.init(allocator, "App 1");
    try manager.addApp(app1);

    const app2 = try allocator.create(menubar.MenubarApp);
    app2.* = try menubar.MenubarApp.init(allocator, "App 2");
    try manager.addApp(app2);

    const retrieved = manager.getApp(0);
    try testing.expect(retrieved != null);
    try testing.expectEqualStrings("App 1", retrieved.?.title);

    const out_of_bounds = manager.getApp(10);
    try testing.expectEqual(@as(?*menubar.MenubarApp, null), out_of_bounds);
}

test "Modifiers - all combinations" {
    const mods1 = menubar.MenuItem.Shortcut.Modifiers{
        .ctrl = true,
        .alt = false,
        .shift = false,
        .meta = false,
    };
    try testing.expect(mods1.ctrl);
    try testing.expect(!mods1.alt);

    const mods2 = menubar.MenuItem.Shortcut.Modifiers{
        .ctrl = true,
        .shift = true,
    };
    try testing.expect(mods2.ctrl);
    try testing.expect(mods2.shift);
    try testing.expect(!mods2.alt);
    try testing.expect(!mods2.meta);

    const mods3 = menubar.MenuItem.Shortcut.Modifiers{
        .meta = true,
    };
    try testing.expect(mods3.meta);
}
