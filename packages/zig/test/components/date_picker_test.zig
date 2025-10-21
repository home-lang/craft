const std = @import("std");
const components = @import("components");
const DatePicker = components.DatePicker;
const Date = DatePicker.Date;
const ComponentProps = components.ComponentProps;

var selected_date: ?Date = null;
var picker_opened = false;
var picker_closed = false;

fn handleSelect(date: Date) void {
    selected_date = date;
}

fn handleOpen() void {
    picker_opened = true;
}

fn handleClose() void {
    picker_closed = true;
}

test "date picker creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const picker = try DatePicker.init(allocator, props);
    defer picker.deinit();

    try std.testing.expect(picker.selected_date == null);
    try std.testing.expect(!picker.open);
    try std.testing.expect(!picker.disabled);
    try std.testing.expect(picker.format == .iso_8601);
}

test "date validation" {
    const valid_date = Date{ .year = 2024, .month = 3, .day = 15 };
    try std.testing.expect(valid_date.isValid());

    const invalid_month = Date{ .year = 2024, .month = 13, .day = 1 };
    try std.testing.expect(!invalid_month.isValid());

    const invalid_day = Date{ .year = 2024, .month = 2, .day = 30 };
    try std.testing.expect(!invalid_day.isValid());

    const leap_year = Date{ .year = 2024, .month = 2, .day = 29 };
    try std.testing.expect(leap_year.isValid());

    const non_leap_year = Date{ .year = 2023, .month = 2, .day = 29 };
    try std.testing.expect(!non_leap_year.isValid());
}

test "date comparison" {
    const date1 = Date{ .year = 2024, .month = 3, .day = 15 };
    const date2 = Date{ .year = 2024, .month = 3, .day = 20 };
    const date3 = Date{ .year = 2024, .month = 3, .day = 15 };

    try std.testing.expect(date1.isBefore(date2));
    try std.testing.expect(date2.isAfter(date1));
    try std.testing.expect(date1.equals(date3));
    try std.testing.expect(date1.isSameDay(date3));
}

test "leap year calculation" {
    try std.testing.expect(Date.isLeapYear(2024));
    try std.testing.expect(Date.isLeapYear(2000));
    try std.testing.expect(!Date.isLeapYear(2023));
    try std.testing.expect(!Date.isLeapYear(1900));
}

test "days in month" {
    try std.testing.expect(Date.getDaysInMonth(2024, 1) == 31);
    try std.testing.expect(Date.getDaysInMonth(2024, 2) == 29); // leap year
    try std.testing.expect(Date.getDaysInMonth(2023, 2) == 28); // non-leap year
    try std.testing.expect(Date.getDaysInMonth(2024, 4) == 30);
}

test "date picker select date" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const picker = try DatePicker.init(allocator, props);
    defer picker.deinit();

    selected_date = null;
    picker.onSelect(&handleSelect);

    const date = Date{ .year = 2024, .month = 3, .day = 15 };
    try picker.selectDate(date);

    try std.testing.expect(picker.selected_date != null);
    try std.testing.expect(picker.selected_date.?.equals(date));
    try std.testing.expect(selected_date != null);
}

test "date picker invalid date" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const picker = try DatePicker.init(allocator, props);
    defer picker.deinit();

    const invalid_date = Date{ .year = 2024, .month = 13, .day = 1 };
    try std.testing.expectError(error.InvalidDate, picker.selectDate(invalid_date));
}

test "date picker min and max dates" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const picker = try DatePicker.init(allocator, props);
    defer picker.deinit();

    const min_date = Date{ .year = 2024, .month = 1, .day = 1 };
    const max_date = Date{ .year = 2024, .month = 12, .day = 31 };

    picker.setMinDate(min_date);
    picker.setMaxDate(max_date);

    const before_min = Date{ .year = 2023, .month = 12, .day = 31 };
    try std.testing.expectError(error.DateBeforeMinimum, picker.selectDate(before_min));

    const after_max = Date{ .year = 2025, .month = 1, .day = 1 };
    try std.testing.expectError(error.DateAfterMaximum, picker.selectDate(after_max));

    const valid_date = Date{ .year = 2024, .month = 6, .day = 15 };
    try picker.selectDate(valid_date);
    try std.testing.expect(picker.selected_date.?.equals(valid_date));
}

test "date picker disabled dates" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const picker = try DatePicker.init(allocator, props);
    defer picker.deinit();

    const disabled_date = Date{ .year = 2024, .month = 3, .day = 15 };
    try picker.addDisabledDate(disabled_date);

    try std.testing.expect(picker.isDateDisabled(disabled_date));
    try std.testing.expectError(error.DateDisabled, picker.selectDate(disabled_date));

    picker.clearDisabledDates();
    try std.testing.expect(!picker.isDateDisabled(disabled_date));
}

test "date picker open and close" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const picker = try DatePicker.init(allocator, props);
    defer picker.deinit();

    picker_opened = false;
    picker_closed = false;
    picker.onOpen(&handleOpen);
    picker.onClose(&handleClose);

    picker.openPicker();
    try std.testing.expect(picker.open);
    try std.testing.expect(picker_opened);

    picker.closePicker();
    try std.testing.expect(!picker.open);
    try std.testing.expect(picker_closed);
}

test "date picker toggle" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const picker = try DatePicker.init(allocator, props);
    defer picker.deinit();

    try std.testing.expect(!picker.open);

    picker.toggle();
    try std.testing.expect(picker.open);

    picker.toggle();
    try std.testing.expect(!picker.open);
}

test "date picker disabled state" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const picker = try DatePicker.init(allocator, props);
    defer picker.deinit();

    picker.setDisabled(true);
    try std.testing.expect(picker.disabled);

    // Should not open when disabled
    picker.toggle();
    try std.testing.expect(!picker.open);
}

test "date picker clear date" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const picker = try DatePicker.init(allocator, props);
    defer picker.deinit();

    const date = Date{ .year = 2024, .month = 3, .day = 15 };
    try picker.selectDate(date);
    try std.testing.expect(picker.selected_date != null);

    picker.clearDate();
    try std.testing.expect(picker.selected_date == null);
}

test "date picker format and settings" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const picker = try DatePicker.init(allocator, props);
    defer picker.deinit();

    picker.setFormat(.european);
    try std.testing.expect(picker.format == .european);

    picker.setFirstDayOfWeek(1); // Monday
    try std.testing.expect(picker.first_day_of_week == 1);

    picker.setShowTime(true);
    try std.testing.expect(picker.show_time);
}
