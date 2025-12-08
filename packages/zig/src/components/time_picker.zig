const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// TimePicker Component - Time selection control
pub const TimePicker = struct {
    component: Component,
    hour: u8,
    minute: u8,
    second: u8,
    format: TimeFormat,
    show_seconds: bool,
    min_time: ?Time,
    max_time: ?Time,
    on_time_change: ?*const fn (u8, u8, u8) void,
    is_open: bool,
    step_minutes: u8,

    pub const Time = struct {
        hour: u8,
        minute: u8,
        second: u8 = 0,

        pub fn toMinutes(self: Time) u32 {
            return @as(u32, self.hour) * 60 + @as(u32, self.minute);
        }

        pub fn toSeconds(self: Time) u32 {
            return self.toMinutes() * 60 + @as(u32, self.second);
        }

        pub fn compare(self: Time, other: Time) i32 {
            const self_secs = self.toSeconds();
            const other_secs = other.toSeconds();
            if (self_secs < other_secs) return -1;
            if (self_secs > other_secs) return 1;
            return 0;
        }

        pub fn eql(self: Time, other: Time) bool {
            return self.hour == other.hour and
                self.minute == other.minute and
                self.second == other.second;
        }
    };

    pub const TimeFormat = enum {
        h24, // 24-hour format (00:00 - 23:59)
        h12, // 12-hour format with AM/PM

        pub fn maxHour(self: TimeFormat) u8 {
            return switch (self) {
                .h24 => 23,
                .h12 => 12,
            };
        }

        pub fn minHour(self: TimeFormat) u8 {
            return switch (self) {
                .h24 => 0,
                .h12 => 1,
            };
        }
    };

    pub const Period = enum {
        am,
        pm,
    };

    pub const Config = struct {
        initial_hour: u8 = 0,
        initial_minute: u8 = 0,
        initial_second: u8 = 0,
        format: TimeFormat = .h24,
        show_seconds: bool = false,
        step_minutes: u8 = 1,
        min_time: ?Time = null,
        max_time: ?Time = null,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps, config: Config) !*TimePicker {
        const picker = try allocator.create(TimePicker);
        picker.* = TimePicker{
            .component = try Component.init(allocator, "timepicker", props),
            .hour = config.initial_hour,
            .minute = config.initial_minute,
            .second = config.initial_second,
            .format = config.format,
            .show_seconds = config.show_seconds,
            .min_time = config.min_time,
            .max_time = config.max_time,
            .on_time_change = null,
            .is_open = false,
            .step_minutes = if (config.step_minutes == 0) 1 else config.step_minutes,
        };
        return picker;
    }

    pub fn deinit(self: *TimePicker) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    /// Set the time
    pub fn setTime(self: *TimePicker, hour: u8, minute: u8, second: u8) void {
        const new_time = Time{ .hour = hour, .minute = minute, .second = second };

        // Validate against constraints
        if (!self.isTimeValid(new_time)) return;

        const old_hour = self.hour;
        const old_minute = self.minute;
        const old_second = self.second;

        self.hour = hour;
        self.minute = minute;
        self.second = second;

        if (old_hour != hour or old_minute != minute or old_second != second) {
            if (self.on_time_change) |callback| {
                callback(self.hour, self.minute, self.second);
            }
        }
    }

    /// Set hour only
    pub fn setHour(self: *TimePicker, hour: u8) void {
        self.setTime(hour, self.minute, self.second);
    }

    /// Set minute only
    pub fn setMinute(self: *TimePicker, minute: u8) void {
        self.setTime(self.hour, minute, self.second);
    }

    /// Set second only
    pub fn setSecond(self: *TimePicker, second: u8) void {
        self.setTime(self.hour, self.minute, second);
    }

    /// Get current time as struct
    pub fn getTime(self: *const TimePicker) Time {
        return Time{
            .hour = self.hour,
            .minute = self.minute,
            .second = self.second,
        };
    }

    /// Get hour in 12-hour format
    pub fn getHour12(self: *const TimePicker) u8 {
        if (self.hour == 0) return 12;
        if (self.hour > 12) return self.hour - 12;
        return self.hour;
    }

    /// Get AM/PM period
    pub fn getPeriod(self: *const TimePicker) Period {
        return if (self.hour < 12) .am else .pm;
    }

    /// Set AM/PM period (only affects 12-hour format display, internally always 24h)
    pub fn setPeriod(self: *TimePicker, period: Period) void {
        const current_period = self.getPeriod();
        if (current_period == period) return;

        var new_hour = self.hour;
        if (period == .am and self.hour >= 12) {
            new_hour = self.hour - 12;
        } else if (period == .pm and self.hour < 12) {
            new_hour = self.hour + 12;
        }
        self.setHour(new_hour);
    }

    /// Increment hour
    pub fn incrementHour(self: *TimePicker) void {
        var new_hour = self.hour + 1;
        if (new_hour > 23) new_hour = 0;
        self.setHour(new_hour);
    }

    /// Decrement hour
    pub fn decrementHour(self: *TimePicker) void {
        var new_hour: u8 = undefined;
        if (self.hour == 0) {
            new_hour = 23;
        } else {
            new_hour = self.hour - 1;
        }
        self.setHour(new_hour);
    }

    /// Increment minute
    pub fn incrementMinute(self: *TimePicker) void {
        var new_minute = self.minute + self.step_minutes;
        if (new_minute > 59) {
            new_minute = 0;
            self.incrementHour();
        }
        self.setMinute(new_minute);
    }

    /// Decrement minute
    pub fn decrementMinute(self: *TimePicker) void {
        if (self.minute < self.step_minutes) {
            self.decrementHour();
            self.setMinute(60 - self.step_minutes + self.minute);
        } else {
            self.setMinute(self.minute - self.step_minutes);
        }
    }

    /// Increment second
    pub fn incrementSecond(self: *TimePicker) void {
        var new_second = self.second + 1;
        if (new_second > 59) {
            new_second = 0;
            self.incrementMinute();
        }
        self.setSecond(new_second);
    }

    /// Decrement second
    pub fn decrementSecond(self: *TimePicker) void {
        if (self.second == 0) {
            self.decrementMinute();
            self.setSecond(59);
        } else {
            self.setSecond(self.second - 1);
        }
    }

    /// Set time format
    pub fn setFormat(self: *TimePicker, format: TimeFormat) void {
        self.format = format;
    }

    /// Set whether to show seconds
    pub fn setShowSeconds(self: *TimePicker, show: bool) void {
        self.show_seconds = show;
    }

    /// Set minimum allowed time
    pub fn setMinTime(self: *TimePicker, min: ?Time) void {
        self.min_time = min;
    }

    /// Set maximum allowed time
    pub fn setMaxTime(self: *TimePicker, max: ?Time) void {
        self.max_time = max;
    }

    /// Set minute step increment
    pub fn setStepMinutes(self: *TimePicker, step: u8) void {
        self.step_minutes = if (step == 0) 1 else step;
    }

    /// Check if a time is valid within constraints
    pub fn isTimeValid(self: *const TimePicker, time: Time) bool {
        // Basic validation
        if (time.hour > 23) return false;
        if (time.minute > 59) return false;
        if (time.second > 59) return false;

        // Check min constraint
        if (self.min_time) |min| {
            if (time.compare(min) < 0) return false;
        }

        // Check max constraint
        if (self.max_time) |max| {
            if (time.compare(max) > 0) return false;
        }

        return true;
    }

    /// Open the picker dropdown/popup
    pub fn open(self: *TimePicker) void {
        self.is_open = true;
    }

    /// Close the picker dropdown/popup
    pub fn close(self: *TimePicker) void {
        self.is_open = false;
    }

    /// Toggle picker open state
    pub fn toggle(self: *TimePicker) void {
        self.is_open = !self.is_open;
    }

    /// Check if picker is open
    pub fn isOpen(self: *const TimePicker) bool {
        return self.is_open;
    }

    /// Set callback for time changes
    pub fn onTimeChange(self: *TimePicker, callback: *const fn (u8, u8, u8) void) void {
        self.on_time_change = callback;
    }

    /// Format time as string (caller must free)
    pub fn formatTime(self: *const TimePicker, allocator: std.mem.Allocator) ![]u8 {
        if (self.format == .h12) {
            const hour12 = self.getHour12();
            const period_str: []const u8 = if (self.getPeriod() == .am) "AM" else "PM";

            if (self.show_seconds) {
                return try std.fmt.allocPrint(allocator, "{d:0>2}:{d:0>2}:{d:0>2} {s}", .{
                    hour12,
                    self.minute,
                    self.second,
                    period_str,
                });
            } else {
                return try std.fmt.allocPrint(allocator, "{d:0>2}:{d:0>2} {s}", .{
                    hour12,
                    self.minute,
                    period_str,
                });
            }
        } else {
            if (self.show_seconds) {
                return try std.fmt.allocPrint(allocator, "{d:0>2}:{d:0>2}:{d:0>2}", .{
                    self.hour,
                    self.minute,
                    self.second,
                });
            } else {
                return try std.fmt.allocPrint(allocator, "{d:0>2}:{d:0>2}", .{
                    self.hour,
                    self.minute,
                });
            }
        }
    }

    /// Set time to current system time
    pub fn setToNow(self: *TimePicker) void {
        const timestamp = std.time.timestamp();
        const epoch_seconds: u64 = @intCast(timestamp);
        const day_seconds = @mod(epoch_seconds, 86400);
        const hour: u8 = @intCast(day_seconds / 3600);
        const minute: u8 = @intCast((day_seconds % 3600) / 60);
        const second: u8 = @intCast(day_seconds % 60);
        self.setTime(hour, minute, second);
    }

    /// Clear to initial state (midnight)
    pub fn clear(self: *TimePicker) void {
        self.setTime(0, 0, 0);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "timepicker creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var picker = try TimePicker.init(allocator, props, .{});
    defer picker.deinit();

    try std.testing.expectEqual(@as(u8, 0), picker.hour);
    try std.testing.expectEqual(@as(u8, 0), picker.minute);
    try std.testing.expectEqual(@as(u8, 0), picker.second);
    try std.testing.expectEqual(TimePicker.TimeFormat.h24, picker.format);
}

test "timepicker set time" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var picker = try TimePicker.init(allocator, props, .{});
    defer picker.deinit();

    picker.setTime(14, 30, 45);

    try std.testing.expectEqual(@as(u8, 14), picker.hour);
    try std.testing.expectEqual(@as(u8, 30), picker.minute);
    try std.testing.expectEqual(@as(u8, 45), picker.second);
}

test "timepicker 12-hour format" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var picker = try TimePicker.init(allocator, props, .{ .format = .h12 });
    defer picker.deinit();

    picker.setTime(14, 30, 0);
    try std.testing.expectEqual(@as(u8, 2), picker.getHour12());
    try std.testing.expectEqual(TimePicker.Period.pm, picker.getPeriod());

    picker.setTime(9, 15, 0);
    try std.testing.expectEqual(@as(u8, 9), picker.getHour12());
    try std.testing.expectEqual(TimePicker.Period.am, picker.getPeriod());

    // Midnight
    picker.setTime(0, 0, 0);
    try std.testing.expectEqual(@as(u8, 12), picker.getHour12());
    try std.testing.expectEqual(TimePicker.Period.am, picker.getPeriod());
}

test "timepicker increment/decrement hour" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var picker = try TimePicker.init(allocator, props, .{});
    defer picker.deinit();

    picker.setTime(23, 0, 0);
    picker.incrementHour();
    try std.testing.expectEqual(@as(u8, 0), picker.hour);

    picker.decrementHour();
    try std.testing.expectEqual(@as(u8, 23), picker.hour);
}

test "timepicker increment/decrement minute" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var picker = try TimePicker.init(allocator, props, .{ .step_minutes = 15 });
    defer picker.deinit();

    picker.setTime(10, 0, 0);
    picker.incrementMinute();
    try std.testing.expectEqual(@as(u8, 15), picker.minute);

    picker.incrementMinute();
    try std.testing.expectEqual(@as(u8, 30), picker.minute);
}

test "timepicker time constraints" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var picker = try TimePicker.init(allocator, props, .{
        .min_time = .{ .hour = 9, .minute = 0 },
        .max_time = .{ .hour = 17, .minute = 0 },
    });
    defer picker.deinit();

    // Valid time
    try std.testing.expect(picker.isTimeValid(.{ .hour = 12, .minute = 0, .second = 0 }));

    // Too early
    try std.testing.expect(!picker.isTimeValid(.{ .hour = 8, .minute = 0, .second = 0 }));

    // Too late
    try std.testing.expect(!picker.isTimeValid(.{ .hour = 18, .minute = 0, .second = 0 }));
}

test "timepicker format time string" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var picker = try TimePicker.init(allocator, props, .{});
    defer picker.deinit();

    picker.setTime(9, 5, 30);

    const formatted = try picker.formatTime(allocator);
    defer allocator.free(formatted);
    try std.testing.expectEqualStrings("09:05", formatted);

    picker.show_seconds = true;
    const formatted_secs = try picker.formatTime(allocator);
    defer allocator.free(formatted_secs);
    try std.testing.expectEqualStrings("09:05:30", formatted_secs);
}

test "timepicker 12h format string" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var picker = try TimePicker.init(allocator, props, .{ .format = .h12 });
    defer picker.deinit();

    picker.setTime(14, 30, 0);
    const formatted = try picker.formatTime(allocator);
    defer allocator.free(formatted);
    try std.testing.expectEqualStrings("02:30 PM", formatted);
}

test "timepicker period toggle" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var picker = try TimePicker.init(allocator, props, .{});
    defer picker.deinit();

    picker.setTime(10, 30, 0); // 10:30 AM
    try std.testing.expectEqual(TimePicker.Period.am, picker.getPeriod());

    picker.setPeriod(.pm);
    try std.testing.expectEqual(@as(u8, 22), picker.hour);
    try std.testing.expectEqual(TimePicker.Period.pm, picker.getPeriod());
}

test "time struct operations" {
    const time1 = TimePicker.Time{ .hour = 10, .minute = 30, .second = 0 };
    const time2 = TimePicker.Time{ .hour = 14, .minute = 0, .second = 0 };
    const time3 = TimePicker.Time{ .hour = 10, .minute = 30, .second = 0 };

    try std.testing.expectEqual(@as(i32, -1), time1.compare(time2));
    try std.testing.expectEqual(@as(i32, 1), time2.compare(time1));
    try std.testing.expectEqual(@as(i32, 0), time1.compare(time3));
    try std.testing.expect(time1.eql(time3));
    try std.testing.expect(!time1.eql(time2));
}
