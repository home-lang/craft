const std = @import("std");
const components = @import("components");
const ProgressBar = components.ProgressBar;
const ComponentProps = components.ComponentProps;

var progress_completed = false;

fn handleComplete() void {
    progress_completed = true;
}

test "progress bar creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const progress = try ProgressBar.init(allocator, props);
    defer progress.deinit();

    try std.testing.expect(progress.value == 0.0);
    try std.testing.expect(progress.max == 100.0);
    try std.testing.expect(!progress.indeterminate);
    try std.testing.expect(progress.show_percentage);
    try std.testing.expect(progress.color == .primary);
}

test "progress bar set value" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const progress = try ProgressBar.init(allocator, props);
    defer progress.deinit();

    progress.setValue(50.0);
    try std.testing.expect(progress.value == 50.0);

    // Should clamp to max
    progress.setValue(150.0);
    try std.testing.expect(progress.value == 100.0);

    // Should clamp to 0
    progress.setValue(-10.0);
    try std.testing.expect(progress.value == 0.0);
}

test "progress bar increment and decrement" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const progress = try ProgressBar.init(allocator, props);
    defer progress.deinit();

    progress.increment(30.0);
    try std.testing.expect(progress.value == 30.0);

    progress.increment(40.0);
    try std.testing.expect(progress.value == 70.0);

    progress.decrement(20.0);
    try std.testing.expect(progress.value == 50.0);
}

test "progress bar percentage" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const progress = try ProgressBar.init(allocator, props);
    defer progress.deinit();

    progress.setValue(25.0);
    try std.testing.expect(progress.getPercentage() == 25.0);

    progress.setValue(75.0);
    try std.testing.expect(progress.getPercentage() == 75.0);

    progress.setValue(100.0);
    try std.testing.expect(progress.getPercentage() == 100.0);
}

test "progress bar completion callback" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const progress = try ProgressBar.init(allocator, props);
    defer progress.deinit();

    progress_completed = false;
    progress.onComplete(&handleComplete);

    progress.setValue(99.0);
    try std.testing.expect(!progress_completed);

    progress.setValue(100.0);
    try std.testing.expect(progress_completed);
}

test "progress bar is complete" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const progress = try ProgressBar.init(allocator, props);
    defer progress.deinit();

    try std.testing.expect(!progress.isComplete());

    progress.setValue(100.0);
    try std.testing.expect(progress.isComplete());

    progress.setValue(50.0);
    try std.testing.expect(!progress.isComplete());
}

test "progress bar reset" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const progress = try ProgressBar.init(allocator, props);
    defer progress.deinit();

    progress.setValue(75.0);
    try std.testing.expect(progress.value == 75.0);

    progress.reset();
    try std.testing.expect(progress.value == 0.0);
}

test "progress bar color and indeterminate" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const progress = try ProgressBar.init(allocator, props);
    defer progress.deinit();

    progress.setColor(.success);
    try std.testing.expect(progress.color == .success);

    progress.setIndeterminate(true);
    try std.testing.expect(progress.indeterminate);
}

test "progress bar label" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const progress = try ProgressBar.init(allocator, props);
    defer progress.deinit();

    try std.testing.expect(progress.label == null);

    progress.setLabel("Loading...");
    try std.testing.expectEqualStrings("Loading...", progress.label.?);
}
