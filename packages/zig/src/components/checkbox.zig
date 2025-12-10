const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// Checkbox Component - A toggleable checkbox input
pub const Checkbox = struct {
    component: Component,
    label: []const u8,
    checked: bool,
    indeterminate: bool,
    on_change: ?*const fn (bool) void,

    pub fn init(allocator: std.mem.Allocator, label: []const u8, props: ComponentProps) !*Checkbox {
        const checkbox = try allocator.create(Checkbox);
        checkbox.* = Checkbox{
            .component = try Component.init(allocator, "checkbox", props),
            .label = label,
            .checked = false,
            .indeterminate = false,
            .on_change = null,
        };
        return checkbox;
    }

    pub fn deinit(self: *Checkbox) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    /// Set the change callback
    pub fn onChange(self: *Checkbox, callback: *const fn (bool) void) void {
        self.on_change = callback;
    }

    /// Toggle the checkbox state
    pub fn toggle(self: *Checkbox) void {
        self.indeterminate = false;
        self.checked = !self.checked;
        if (self.on_change) |callback| {
            callback(self.checked);
        }
    }

    /// Set checked state
    pub fn setChecked(self: *Checkbox, checked: bool) void {
        self.indeterminate = false;
        if (self.checked != checked) {
            self.checked = checked;
            if (self.on_change) |callback| {
                callback(self.checked);
            }
        }
    }

    /// Get checked state
    pub fn isChecked(self: *const Checkbox) bool {
        return self.checked;
    }

    /// Set indeterminate state (partially checked)
    pub fn setIndeterminate(self: *Checkbox, indeterminate: bool) void {
        self.indeterminate = indeterminate;
    }

    /// Check if in indeterminate state
    pub fn isIndeterminate(self: *const Checkbox) bool {
        return self.indeterminate;
    }

    /// Set the label text
    pub fn setLabel(self: *Checkbox, label: []const u8) void {
        self.label = label;
    }

    /// Get the label text
    pub fn getLabel(self: *const Checkbox) []const u8 {
        return self.label;
    }

    /// Enable or disable the checkbox
    pub fn setEnabled(self: *Checkbox, enabled: bool) void {
        self.component.props.enabled = enabled;
    }

    /// Check if enabled
    pub fn isEnabled(self: *const Checkbox) bool {
        return self.component.props.enabled;
    }
};

test "checkbox creation" {
    const allocator = std.testing.allocator;
    const checkbox = try Checkbox.init(allocator, "Accept terms", .{});
    defer checkbox.deinit();

    try std.testing.expectEqualStrings("Accept terms", checkbox.label);
    try std.testing.expect(!checkbox.checked);
    try std.testing.expect(!checkbox.indeterminate);
}

test "checkbox toggle" {
    const allocator = std.testing.allocator;
    const checkbox = try Checkbox.init(allocator, "Option", .{});
    defer checkbox.deinit();

    try std.testing.expect(!checkbox.isChecked());

    checkbox.toggle();
    try std.testing.expect(checkbox.isChecked());

    checkbox.toggle();
    try std.testing.expect(!checkbox.isChecked());
}

test "checkbox set checked" {
    const allocator = std.testing.allocator;
    const checkbox = try Checkbox.init(allocator, "Option", .{});
    defer checkbox.deinit();

    checkbox.setChecked(true);
    try std.testing.expect(checkbox.isChecked());

    checkbox.setChecked(false);
    try std.testing.expect(!checkbox.isChecked());
}

test "checkbox indeterminate" {
    const allocator = std.testing.allocator;
    const checkbox = try Checkbox.init(allocator, "Select all", .{});
    defer checkbox.deinit();

    checkbox.setIndeterminate(true);
    try std.testing.expect(checkbox.isIndeterminate());

    // Toggle clears indeterminate
    checkbox.toggle();
    try std.testing.expect(!checkbox.isIndeterminate());
}
