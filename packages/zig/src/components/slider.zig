const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// Slider Component - Range input control
pub const Slider = struct {
    component: Component,
    value: f64,
    min: f64,
    max: f64,
    step: f64,
    disabled: bool,
    orientation: Orientation,
    show_value: bool,
    show_ticks: bool,
    tick_marks: ?[]f64,
    labels: std.StringHashMap([]const u8),
    on_change: ?*const fn (f64) void,
    on_change_start: ?*const fn () void,
    on_change_end: ?*const fn () void,

    pub const Orientation = enum {
        horizontal,
        vertical,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*Slider {
        const slider = try allocator.create(Slider);
        slider.* = Slider{
            .component = try Component.init(allocator, "slider", props),
            .value = 0.0,
            .min = 0.0,
            .max = 100.0,
            .step = 1.0,
            .disabled = false,
            .orientation = .horizontal,
            .show_value = true,
            .show_ticks = false,
            .tick_marks = null,
            .labels = std.StringHashMap([]const u8).init(allocator),
            .on_change = null,
            .on_change_start = null,
            .on_change_end = null,
        };
        return slider;
    }

    pub fn deinit(self: *Slider) void {
        // Free all label keys
        var it = self.labels.keyIterator();
        while (it.next()) |key| {
            self.component.allocator.free(key.*);
        }
        self.labels.deinit();
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setValue(self: *Slider, value: f64) !void {
        if (self.disabled) return;

        // Validate range
        if (value < self.min or value > self.max) {
            return error.ValueOutOfRange;
        }

        // Snap to step
        const steps_from_min = @round((value - self.min) / self.step);
        const snapped_value = self.min + (steps_from_min * self.step);

        // Clamp to range
        const old_value = self.value;
        self.value = std.math.clamp(snapped_value, self.min, self.max);

        // Trigger callback if value changed
        if (old_value != self.value) {
            if (self.on_change) |callback| {
                callback(self.value);
            }
        }
    }

    pub fn increment(self: *Slider) !void {
        try self.setValue(self.value + self.step);
    }

    pub fn decrement(self: *Slider) !void {
        try self.setValue(self.value - self.step);
    }

    pub fn setRange(self: *Slider, min: f64, max: f64) !void {
        if (min >= max) {
            return error.InvalidRange;
        }

        self.min = min;
        self.max = max;

        // Adjust current value if out of new range
        if (self.value < min) {
            try self.setValue(min);
        } else if (self.value > max) {
            try self.setValue(max);
        }
    }

    pub fn setStep(self: *Slider, step: f64) !void {
        if (step <= 0) {
            return error.InvalidStep;
        }

        self.step = step;

        // Re-snap current value to new step
        try self.setValue(self.value);
    }

    pub fn setDisabled(self: *Slider, disabled: bool) void {
        self.disabled = disabled;
    }

    pub fn setOrientation(self: *Slider, orientation: Orientation) void {
        self.orientation = orientation;
    }

    pub fn setShowValue(self: *Slider, show: bool) void {
        self.show_value = show;
    }

    pub fn setShowTicks(self: *Slider, show: bool) void {
        self.show_ticks = show;
    }

    pub fn addLabel(self: *Slider, value: f64, label: []const u8) !void {
        const key = try std.fmt.allocPrint(self.component.allocator, "{d}", .{value});
        try self.labels.put(key, label);
    }

    pub fn getLabel(self: *const Slider, value: f64) ?[]const u8 {
        const key = std.fmt.allocPrint(self.component.allocator, "{d}", .{value}) catch return null;
        defer self.component.allocator.free(key);
        return self.labels.get(key);
    }

    pub fn getPercentage(self: *const Slider) f64 {
        if (self.max == self.min) return 0.0;
        return ((self.value - self.min) / (self.max - self.min)) * 100.0;
    }

    pub fn setPercentage(self: *Slider, percentage: f64) !void {
        const clamped = std.math.clamp(percentage, 0.0, 100.0);
        const value = self.min + ((clamped / 100.0) * (self.max - self.min));
        try self.setValue(value);
    }

    pub fn isAtMin(self: *const Slider) bool {
        return self.value == self.min;
    }

    pub fn isAtMax(self: *const Slider) bool {
        return self.value == self.max;
    }

    pub fn reset(self: *Slider) !void {
        try self.setValue(self.min);
    }

    pub fn startChange(self: *Slider) void {
        if (self.on_change_start) |callback| {
            callback();
        }
    }

    pub fn endChange(self: *Slider) void {
        if (self.on_change_end) |callback| {
            callback();
        }
    }

    pub fn onChange(self: *Slider, callback: *const fn (f64) void) void {
        self.on_change = callback;
    }

    pub fn onChangeStart(self: *Slider, callback: *const fn () void) void {
        self.on_change_start = callback;
    }

    pub fn onChangeEnd(self: *Slider, callback: *const fn () void) void {
        self.on_change_end = callback;
    }
};
