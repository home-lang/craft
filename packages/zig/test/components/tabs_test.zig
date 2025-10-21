const std = @import("std");
const components = @import("components");
const Tabs = components.Tabs;
const Component = components.Component;
const ComponentProps = components.ComponentProps;

var tab_changed_to: usize = 0;

fn handleTabChange(index: usize) void {
    tab_changed_to = index;
}

test "tabs creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tabs = try Tabs.init(allocator, props);
    defer tabs.deinit();

    try std.testing.expect(tabs.tabs.items.len == 0);
    try std.testing.expect(tabs.active_index == 0);
}

test "tabs add and remove" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tabs = try Tabs.init(allocator, props);
    defer tabs.deinit();

    const content1 = try allocator.create(Component);
    content1.* = try Component.init(allocator, "content1", props);

    const content2 = try allocator.create(Component);
    content2.* = try Component.init(allocator, "content2", props);

    try tabs.addTab("Tab 1", content1);
    try tabs.addTab("Tab 2", content2);

    try std.testing.expect(tabs.tabs.items.len == 2);
    try std.testing.expectEqualStrings("Tab 1", tabs.tabs.items[0].label);
    try std.testing.expectEqualStrings("Tab 2", tabs.tabs.items[1].label);

    tabs.removeTab(0);
    try std.testing.expect(tabs.tabs.items.len == 1);
    try std.testing.expectEqualStrings("Tab 2", tabs.tabs.items[0].label);
}

test "tabs set active" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tabs = try Tabs.init(allocator, props);
    defer tabs.deinit();

    const content1 = try allocator.create(Component);
    content1.* = try Component.init(allocator, "content1", props);

    const content2 = try allocator.create(Component);
    content2.* = try Component.init(allocator, "content2", props);

    try tabs.addTab("Tab 1", content1);
    try tabs.addTab("Tab 2", content2);

    tab_changed_to = 0;
    tabs.onTabChange(&handleTabChange);

    tabs.setActiveTab(1);
    try std.testing.expect(tabs.active_index == 1);
    try std.testing.expect(tab_changed_to == 1);
}

test "tabs disabled state" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tabs = try Tabs.init(allocator, props);
    defer tabs.deinit();

    const content = try allocator.create(Component);
    content.* = try Component.init(allocator, "content", props);

    try tabs.addTab("Tab 1", content);

    tabs.setTabDisabled(0, true);
    try std.testing.expect(tabs.tabs.items[0].disabled);

    // Should not change to disabled tab
    const old_index = tabs.active_index;
    tabs.setActiveTab(0);
    try std.testing.expect(tabs.active_index == old_index);
}

test "tabs get active" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tabs = try Tabs.init(allocator, props);
    defer tabs.deinit();

    const content = try allocator.create(Component);
    content.* = try Component.init(allocator, "content", props);

    try tabs.addTab("Active Tab", content);

    const active = tabs.getActiveTab();
    try std.testing.expect(active != null);
    try std.testing.expectEqualStrings("Active Tab", active.?.label);
}
