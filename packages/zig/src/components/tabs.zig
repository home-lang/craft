const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// Tabs Component - Tabbed interface
pub const Tabs = struct {
    component: Component,
    tabs: std.ArrayList(Tab),
    active_index: usize,
    on_tab_change: ?*const fn (usize) void,

    pub const Tab = struct {
        label: []const u8,
        content: *Component,
        disabled: bool = false,
        closable: bool = false,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*Tabs {
        const tabs = try allocator.create(Tabs);
        tabs.* = Tabs{
            .component = try Component.init(allocator, "tabs", props),
            .tabs = .{},
            .active_index = 0,
            .on_tab_change = null,
        };
        return tabs;
    }

    pub fn deinit(self: *Tabs) void {
        for (self.tabs.items) |*tab| {
            tab.content.deinit();
            self.component.allocator.destroy(tab.content);
        }
        self.tabs.deinit(self.component.allocator);
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn addTab(self: *Tabs, label: []const u8, content: *Component) !void {
        try self.tabs.append(self.component.allocator, .{
            .label = label,
            .content = content,
        });
    }

    pub fn removeTab(self: *Tabs, index: usize) void {
        if (index < self.tabs.items.len) {
            var tab = self.tabs.swapRemove(index);
            tab.content.deinit();
            self.component.allocator.destroy(tab.content);

            if (self.active_index >= self.tabs.items.len and self.tabs.items.len > 0) {
                self.active_index = self.tabs.items.len - 1;
            }
        }
    }

    pub fn setActiveTab(self: *Tabs, index: usize) void {
        if (index < self.tabs.items.len and !self.tabs.items[index].disabled) {
            self.active_index = index;
            if (self.on_tab_change) |callback| {
                callback(index);
            }
        }
    }

    pub fn getActiveTab(self: *const Tabs) ?Tab {
        if (self.active_index < self.tabs.items.len) {
            return self.tabs.items[self.active_index];
        }
        return null;
    }

    pub fn onTabChange(self: *Tabs, callback: *const fn (usize) void) void {
        self.on_tab_change = callback;
    }

    pub fn setTabDisabled(self: *Tabs, index: usize, disabled: bool) void {
        if (index < self.tabs.items.len) {
            self.tabs.items[index].disabled = disabled;
        }
    }

    pub fn setTabClosable(self: *Tabs, index: usize, closable: bool) void {
        if (index < self.tabs.items.len) {
            self.tabs.items[index].closable = closable;
        }
    }
};
