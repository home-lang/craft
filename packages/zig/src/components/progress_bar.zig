const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// ProgressBar Component
pub const ProgressBar = struct {
    component: Component,
    value: f32,
    max: f32,
    indeterminate: bool,
    label: ?[]const u8,
    show_percentage: bool,
    color: ProgressColor,
    on_complete: ?*const fn () void,

    pub const ProgressColor = enum {
        primary,
        success,
        warning,
        danger,
        info,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*ProgressBar {
        const progress = try allocator.create(ProgressBar);
        progress.* = ProgressBar{
            .component = try Component.init(allocator, "progress_bar", props),
            .value = 0.0,
            .max = 100.0,
            .indeterminate = false,
            .label = null,
            .show_percentage = true,
            .color = .primary,
            .on_complete = null,
        };
        return progress;
    }

    pub fn deinit(self: *ProgressBar) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setValue(self: *ProgressBar, value: f32) void {
        const old_value = self.value;
        self.value = std.math.clamp(value, 0.0, self.max);

        // Trigger completion callback
        if (old_value < self.max and self.value >= self.max) {
            if (self.on_complete) |callback| {
                callback();
            }
        }
    }

    pub fn increment(self: *ProgressBar, amount: f32) void {
        self.setValue(self.value + amount);
    }

    pub fn decrement(self: *ProgressBar, amount: f32) void {
        self.setValue(self.value - amount);
    }

    pub fn setIndeterminate(self: *ProgressBar, indeterminate: bool) void {
        self.indeterminate = indeterminate;
    }

    pub fn setColor(self: *ProgressBar, color: ProgressColor) void {
        self.color = color;
    }

    pub fn setLabel(self: *ProgressBar, label: []const u8) void {
        self.label = label;
    }

    pub fn getPercentage(self: *const ProgressBar) f32 {
        if (self.max == 0.0) return 0.0;
        return (self.value / self.max) * 100.0;
    }

    pub fn isComplete(self: *const ProgressBar) bool {
        return self.value >= self.max;
    }

    pub fn reset(self: *ProgressBar) void {
        self.value = 0.0;
    }

    pub fn onComplete(self: *ProgressBar, callback: *const fn () void) void {
        self.on_complete = callback;
    }
};
