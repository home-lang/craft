const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// DatePicker Component
pub const DatePicker = struct {
    component: Component,
    selected_date: ?Date,
    min_date: ?Date,
    max_date: ?Date,
    disabled_dates: std.ArrayList(Date),
    open: bool,
    disabled: bool,
    format: DateFormat,
    first_day_of_week: u8, // 0 = Sunday, 1 = Monday, etc.
    show_time: bool,
    on_select: ?*const fn (Date) void,
    on_open: ?*const fn () void,
    on_close: ?*const fn () void,

    pub const Date = struct {
        year: u16,
        month: u8, // 1-12
        day: u8, // 1-31
        hour: u8 = 0, // 0-23
        minute: u8 = 0, // 0-59

        pub fn equals(self: Date, other: Date) bool {
            return self.year == other.year and
                self.month == other.month and
                self.day == other.day and
                self.hour == other.hour and
                self.minute == other.minute;
        }

        pub fn isBefore(self: Date, other: Date) bool {
            if (self.year != other.year) return self.year < other.year;
            if (self.month != other.month) return self.month < other.month;
            if (self.day != other.day) return self.day < other.day;
            if (self.hour != other.hour) return self.hour < other.hour;
            return self.minute < other.minute;
        }

        pub fn isAfter(self: Date, other: Date) bool {
            return !self.isBefore(other) and !self.equals(other);
        }

        pub fn isSameDay(self: Date, other: Date) bool {
            return self.year == other.year and
                self.month == other.month and
                self.day == other.day;
        }

        pub fn isValid(self: Date) bool {
            if (self.month < 1 or self.month > 12) return false;
            if (self.day < 1 or self.day > 31) return false;
            if (self.hour > 23) return false;
            if (self.minute > 59) return false;

            const days_in_month = getDaysInMonth(self.year, self.month);
            return self.day <= days_in_month;
        }

        pub fn getDaysInMonth(year: u16, month: u8) u8 {
            return switch (month) {
                1, 3, 5, 7, 8, 10, 12 => 31,
                4, 6, 9, 11 => 30,
                2 => if (isLeapYear(year)) 29 else 28,
                else => 0,
            };
        }

        pub fn isLeapYear(year: u16) bool {
            return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
        }
    };

    pub const DateFormat = enum {
        iso_8601, // YYYY-MM-DD
        us, // MM/DD/YYYY
        european, // DD/MM/YYYY
        long, // Month DD, YYYY
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*DatePicker {
        const picker = try allocator.create(DatePicker);
        picker.* = DatePicker{
            .component = try Component.init(allocator, "date_picker", props),
            .selected_date = null,
            .min_date = null,
            .max_date = null,
            .disabled_dates = .{},
            .open = false,
            .disabled = false,
            .format = .iso_8601,
            .first_day_of_week = 0, // Sunday
            .show_time = false,
            .on_select = null,
            .on_open = null,
            .on_close = null,
        };
        return picker;
    }

    pub fn deinit(self: *DatePicker) void {
        self.disabled_dates.deinit(self.component.allocator);
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn selectDate(self: *DatePicker, date: Date) !void {
        if (self.disabled) return;

        // Validate date
        if (!date.isValid()) {
            return error.InvalidDate;
        }

        // Check min/max bounds
        if (self.min_date) |min| {
            if (date.isBefore(min)) {
                return error.DateBeforeMinimum;
            }
        }

        if (self.max_date) |max| {
            if (date.isAfter(max)) {
                return error.DateAfterMaximum;
            }
        }

        // Check if date is disabled
        for (self.disabled_dates.items) |disabled_date| {
            if (date.isSameDay(disabled_date)) {
                return error.DateDisabled;
            }
        }

        self.selected_date = date;
        self.open = false;

        if (self.on_select) |callback| {
            callback(date);
        }
        if (self.on_close) |callback| {
            callback();
        }
    }

    pub fn clearDate(self: *DatePicker) void {
        self.selected_date = null;
    }

    pub fn setMinDate(self: *DatePicker, date: Date) void {
        self.min_date = date;
    }

    pub fn setMaxDate(self: *DatePicker, date: Date) void {
        self.max_date = date;
    }

    pub fn addDisabledDate(self: *DatePicker, date: Date) !void {
        try self.disabled_dates.append(self.component.allocator, date);
    }

    pub fn clearDisabledDates(self: *DatePicker) void {
        self.disabled_dates.clearRetainingCapacity();
    }

    pub fn openPicker(self: *DatePicker) void {
        if (self.disabled) return;

        self.open = true;
        if (self.on_open) |callback| {
            callback();
        }
    }

    pub fn closePicker(self: *DatePicker) void {
        self.open = false;
        if (self.on_close) |callback| {
            callback();
        }
    }

    pub fn toggle(self: *DatePicker) void {
        if (self.open) {
            self.closePicker();
        } else {
            self.openPicker();
        }
    }

    pub fn setDisabled(self: *DatePicker, disabled: bool) void {
        self.disabled = disabled;
        if (disabled) {
            self.open = false;
        }
    }

    pub fn setFormat(self: *DatePicker, format: DateFormat) void {
        self.format = format;
    }

    pub fn setFirstDayOfWeek(self: *DatePicker, day: u8) void {
        if (day <= 6) {
            self.first_day_of_week = day;
        }
    }

    pub fn setShowTime(self: *DatePicker, show_time: bool) void {
        self.show_time = show_time;
    }

    pub fn isDateDisabled(self: *const DatePicker, date: Date) bool {
        // Check min/max bounds
        if (self.min_date) |min| {
            if (date.isBefore(min)) return true;
        }

        if (self.max_date) |max| {
            if (date.isAfter(max)) return true;
        }

        // Check disabled dates
        for (self.disabled_dates.items) |disabled_date| {
            if (date.isSameDay(disabled_date)) return true;
        }

        return false;
    }

    pub fn onSelect(self: *DatePicker, callback: *const fn (Date) void) void {
        self.on_select = callback;
    }

    pub fn onOpen(self: *DatePicker, callback: *const fn () void) void {
        self.on_open = callback;
    }

    pub fn onClose(self: *DatePicker, callback: *const fn () void) void {
        self.on_close = callback;
    }
};
