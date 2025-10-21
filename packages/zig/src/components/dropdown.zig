const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// Dropdown/Select Component
pub const Dropdown = struct {
    component: Component,
    options: std.ArrayList(Option),
    selected_index: ?usize,
    open: bool,
    searchable: bool,
    disabled: bool,
    placeholder: ?[]const u8,
    on_select: ?*const fn (usize) void,
    on_open: ?*const fn () void,
    on_close: ?*const fn () void,

    pub const Option = struct {
        label: []const u8,
        value: []const u8,
        disabled: bool = false,
        icon: ?[]const u8 = null,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*Dropdown {
        const dropdown = try allocator.create(Dropdown);
        dropdown.* = Dropdown{
            .component = try Component.init(allocator, "dropdown", props),
            .options = .{},
            .selected_index = null,
            .open = false,
            .searchable = false,
            .disabled = false,
            .placeholder = null,
            .on_select = null,
            .on_open = null,
            .on_close = null,
        };
        return dropdown;
    }

    pub fn deinit(self: *Dropdown) void {
        self.options.deinit(self.component.allocator);
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn addOption(self: *Dropdown, label: []const u8, value: []const u8) !void {
        try self.options.append(self.component.allocator, .{
            .label = label,
            .value = value,
        });
    }

    pub fn addOptionWithIcon(self: *Dropdown, label: []const u8, value: []const u8, icon: []const u8) !void {
        try self.options.append(self.component.allocator, .{
            .label = label,
            .value = value,
            .icon = icon,
        });
    }

    pub fn removeOption(self: *Dropdown, index: usize) void {
        if (index < self.options.items.len) {
            _ = self.options.swapRemove(index);

            // Adjust selected index if necessary
            if (self.selected_index) |selected| {
                if (selected == index) {
                    self.selected_index = null;
                } else if (selected > index) {
                    self.selected_index = selected - 1;
                }
            }
        }
    }

    pub fn selectOption(self: *Dropdown, index: usize) void {
        if (self.disabled) return;

        if (index < self.options.items.len and !self.options.items[index].disabled) {
            self.selected_index = index;
            self.open = false;

            if (self.on_select) |callback| {
                callback(index);
            }
            if (self.on_close) |callback| {
                callback();
            }
        }
    }

    pub fn clearSelection(self: *Dropdown) void {
        self.selected_index = null;
    }

    pub fn getSelectedOption(self: *const Dropdown) ?Option {
        if (self.selected_index) |index| {
            if (index < self.options.items.len) {
                return self.options.items[index];
            }
        }
        return null;
    }

    pub fn getSelectedValue(self: *const Dropdown) ?[]const u8 {
        if (self.getSelectedOption()) |option| {
            return option.value;
        }
        return null;
    }

    pub fn toggle(self: *Dropdown) void {
        if (self.disabled) return;

        if (self.open) {
            self.close();
        } else {
            self.openDropdown();
        }
    }

    pub fn openDropdown(self: *Dropdown) void {
        if (self.disabled) return;

        self.open = true;
        if (self.on_open) |callback| {
            callback();
        }
    }

    pub fn close(self: *Dropdown) void {
        self.open = false;
        if (self.on_close) |callback| {
            callback();
        }
    }

    pub fn setDisabled(self: *Dropdown, disabled: bool) void {
        self.disabled = disabled;
        if (disabled) {
            self.open = false;
        }
    }

    pub fn setOptionDisabled(self: *Dropdown, index: usize, disabled: bool) void {
        if (index < self.options.items.len) {
            self.options.items[index].disabled = disabled;
        }
    }

    pub fn setSearchable(self: *Dropdown, searchable: bool) void {
        self.searchable = searchable;
    }

    pub fn setPlaceholder(self: *Dropdown, placeholder: []const u8) void {
        self.placeholder = placeholder;
    }

    pub fn onSelect(self: *Dropdown, callback: *const fn (usize) void) void {
        self.on_select = callback;
    }

    pub fn onOpen(self: *Dropdown, callback: *const fn () void) void {
        self.on_open = callback;
    }

    pub fn onClose(self: *Dropdown, callback: *const fn () void) void {
        self.on_close = callback;
    }
};
