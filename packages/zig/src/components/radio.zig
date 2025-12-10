const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// RadioButton Component - A single radio button option
pub const RadioButton = struct {
    component: Component,
    label: []const u8,
    value: []const u8,
    selected: bool,
    group: ?*RadioGroup,

    pub fn init(allocator: std.mem.Allocator, label: []const u8, value: []const u8, props: ComponentProps) !*RadioButton {
        const radio = try allocator.create(RadioButton);
        radio.* = RadioButton{
            .component = try Component.init(allocator, "radio", props),
            .label = label,
            .value = value,
            .selected = false,
            .group = null,
        };
        return radio;
    }

    pub fn deinit(self: *RadioButton) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    /// Select this radio button
    pub fn select(self: *RadioButton) void {
        if (self.group) |group| {
            group.selectButton(self);
        } else {
            self.selected = true;
        }
    }

    /// Check if selected
    pub fn isSelected(self: *const RadioButton) bool {
        return self.selected;
    }

    /// Get the value
    pub fn getValue(self: *const RadioButton) []const u8 {
        return self.value;
    }

    /// Get the label
    pub fn getLabel(self: *const RadioButton) []const u8 {
        return self.label;
    }

    /// Set label
    pub fn setLabel(self: *RadioButton, label: []const u8) void {
        self.label = label;
    }

    /// Enable or disable
    pub fn setEnabled(self: *RadioButton, enabled: bool) void {
        self.component.props.enabled = enabled;
    }

    /// Check if enabled
    pub fn isEnabled(self: *const RadioButton) bool {
        return self.component.props.enabled;
    }
};

/// RadioGroup - Manages a group of mutually exclusive radio buttons
pub const RadioGroup = struct {
    component: Component,
    name: []const u8,
    buttons: std.ArrayList(*RadioButton),
    selected_value: ?[]const u8,
    on_change: ?*const fn ([]const u8) void,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, props: ComponentProps) !*RadioGroup {
        const group = try allocator.create(RadioGroup);
        group.* = RadioGroup{
            .component = try Component.init(allocator, "radio-group", props),
            .name = name,
            .buttons = .{},
            .selected_value = null,
            .on_change = null,
            .allocator = allocator,
        };
        return group;
    }

    pub fn deinit(self: *RadioGroup) void {
        // Deinit all buttons in the group
        for (self.buttons.items) |button| {
            button.deinit();
        }
        self.buttons.deinit(self.allocator);
        self.component.deinit();
        self.allocator.destroy(self);
    }

    /// Add a radio button to the group
    pub fn addButton(self: *RadioGroup, button: *RadioButton) !void {
        button.group = self;
        try self.buttons.append(self.allocator, button);
    }

    /// Create and add a new radio button
    pub fn addOption(self: *RadioGroup, label: []const u8, value: []const u8) !*RadioButton {
        const button = try RadioButton.init(self.allocator, label, value, .{});
        try self.addButton(button);
        return button;
    }

    /// Select a button (internal use)
    fn selectButton(self: *RadioGroup, selected: *RadioButton) void {
        // Deselect all buttons
        for (self.buttons.items) |button| {
            button.selected = false;
        }
        // Select the specified button
        selected.selected = true;
        self.selected_value = selected.value;

        if (self.on_change) |callback| {
            callback(selected.value);
        }
    }

    /// Select by value
    pub fn selectValue(self: *RadioGroup, value: []const u8) void {
        for (self.buttons.items) |button| {
            if (std.mem.eql(u8, button.value, value)) {
                self.selectButton(button);
                return;
            }
        }
    }

    /// Get the selected value
    pub fn getSelectedValue(self: *const RadioGroup) ?[]const u8 {
        return self.selected_value;
    }

    /// Set change callback
    pub fn onChange(self: *RadioGroup, callback: *const fn ([]const u8) void) void {
        self.on_change = callback;
    }

    /// Get number of options
    pub fn count(self: *const RadioGroup) usize {
        return self.buttons.items.len;
    }

    /// Clear selection
    pub fn clearSelection(self: *RadioGroup) void {
        for (self.buttons.items) |button| {
            button.selected = false;
        }
        self.selected_value = null;
    }
};

test "radio button creation" {
    const allocator = std.testing.allocator;
    const radio = try RadioButton.init(allocator, "Option A", "a", .{});
    defer radio.deinit();

    try std.testing.expectEqualStrings("Option A", radio.label);
    try std.testing.expectEqualStrings("a", radio.value);
    try std.testing.expect(!radio.isSelected());
}

test "radio group creation" {
    const allocator = std.testing.allocator;
    const group = try RadioGroup.init(allocator, "options", .{});
    defer group.deinit();

    _ = try group.addOption("Option A", "a");
    _ = try group.addOption("Option B", "b");
    _ = try group.addOption("Option C", "c");

    try std.testing.expect(group.count() == 3);
    try std.testing.expect(group.getSelectedValue() == null);
}

test "radio group selection" {
    const allocator = std.testing.allocator;
    const group = try RadioGroup.init(allocator, "options", .{});
    defer group.deinit();

    const btn_a = try group.addOption("Option A", "a");
    _ = try group.addOption("Option B", "b");

    // Select first option
    btn_a.select();

    try std.testing.expect(btn_a.isSelected());
    try std.testing.expectEqualStrings("a", group.getSelectedValue().?);
}

test "radio group mutual exclusion" {
    const allocator = std.testing.allocator;
    const group = try RadioGroup.init(allocator, "options", .{});
    defer group.deinit();

    const btn_a = try group.addOption("Option A", "a");
    const btn_b = try group.addOption("Option B", "b");

    btn_a.select();
    try std.testing.expect(btn_a.isSelected());
    try std.testing.expect(!btn_b.isSelected());

    btn_b.select();
    try std.testing.expect(!btn_a.isSelected());
    try std.testing.expect(btn_b.isSelected());
}

test "radio group select by value" {
    const allocator = std.testing.allocator;
    const group = try RadioGroup.init(allocator, "options", .{});
    defer group.deinit();

    _ = try group.addOption("Option A", "a");
    const btn_b = try group.addOption("Option B", "b");

    group.selectValue("b");

    try std.testing.expect(btn_b.isSelected());
    try std.testing.expectEqualStrings("b", group.getSelectedValue().?);
}
