const std = @import("std");
const components = @import("components");
const Toast = components.Toast;
const ToastManager = components.ToastManager;
const ComponentProps = components.ComponentProps;

var toast_shown = false;
var toast_dismissed = false;

fn handleShow() void {
    toast_shown = true;
}

fn handleDismiss() void {
    toast_dismissed = true;
}

test "toast creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const toast = try Toast.init(allocator, "Test message", props);
    defer toast.deinit();

    try std.testing.expectEqualStrings("Test message", toast.message);
    try std.testing.expect(!toast.visible);
    try std.testing.expect(toast.type == .info);
    try std.testing.expect(toast.duration == 5000);
    try std.testing.expect(toast.closable);
    try std.testing.expect(toast.auto_dismiss);
}

test "toast show and dismiss" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const toast = try Toast.init(allocator, "Test message", props);
    defer toast.deinit();

    toast_shown = false;
    toast_dismissed = false;
    toast.onShow(&handleShow);
    toast.onDismiss(&handleDismiss);

    toast.show();
    try std.testing.expect(toast.visible);
    try std.testing.expect(toast_shown);
    try std.testing.expect(toast.show_time != null);

    toast.dismiss();
    try std.testing.expect(!toast.visible);
    try std.testing.expect(toast_dismissed);
    try std.testing.expect(toast.show_time == null);
}

test "toast toggle" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const toast = try Toast.init(allocator, "Test message", props);
    defer toast.deinit();

    try std.testing.expect(!toast.visible);

    toast.toggle();
    try std.testing.expect(toast.visible);

    toast.toggle();
    try std.testing.expect(!toast.visible);
}

test "toast type and position" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const toast = try Toast.init(allocator, "Test message", props);
    defer toast.deinit();

    toast.setType(.err);
    try std.testing.expect(toast.type == .err);

    toast.setPosition(.bottom_left);
    try std.testing.expect(toast.position == .bottom_left);
}

test "toast title and message" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const toast = try Toast.init(allocator, "Test message", props);
    defer toast.deinit();

    toast.setTitle("Test Title");
    try std.testing.expectEqualStrings("Test Title", toast.title.?);

    toast.setMessage("New message");
    try std.testing.expectEqualStrings("New message", toast.message);
}

test "toast duration and auto dismiss" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const toast = try Toast.init(allocator, "Test message", props);
    defer toast.deinit();

    toast.setDuration(3000);
    try std.testing.expect(toast.duration == 3000);

    toast.setAutoDismiss(false);
    try std.testing.expect(!toast.auto_dismiss);
    try std.testing.expect(!toast.shouldAutoDismiss());
}

test "toast remaining time" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const toast = try Toast.init(allocator, "Test message", props);
    defer toast.deinit();

    // Not visible, should return null
    try std.testing.expect(toast.getRemainingTime() == null);

    toast.show();
    const remaining = toast.getRemainingTime();
    try std.testing.expect(remaining != null);
    try std.testing.expect(remaining.? <= 5000);
}

test "toast manager creation" {
    const allocator = std.testing.allocator;
    var manager = ToastManager.init(allocator);
    defer manager.deinit();

    try std.testing.expect(manager.toasts.items.len == 0);
    try std.testing.expect(manager.max_toasts == 5);
}

test "toast manager add and remove" {
    const allocator = std.testing.allocator;
    var manager = ToastManager.init(allocator);
    defer manager.deinit();

    const props = ComponentProps{};
    const toast1 = try Toast.init(allocator, "Toast 1", props);
    const toast2 = try Toast.init(allocator, "Toast 2", props);

    try manager.add(toast1);
    try manager.add(toast2);

    try std.testing.expect(manager.toasts.items.len == 2);
    try std.testing.expect(toast1.visible);
    try std.testing.expect(toast2.visible);

    manager.removeAt(0);
    try std.testing.expect(manager.toasts.items.len == 1);
}

test "toast manager max capacity" {
    const allocator = std.testing.allocator;
    var manager = ToastManager.init(allocator);
    defer manager.deinit();

    manager.setMaxToasts(3);

    const props = ComponentProps{};

    // Add 4 toasts, should only keep 3
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        const toast = try Toast.init(allocator, "Toast", props);
        try manager.add(toast);
    }

    try std.testing.expect(manager.toasts.items.len == 3);
}

test "toast manager clear" {
    const allocator = std.testing.allocator;
    var manager = ToastManager.init(allocator);
    defer manager.deinit();

    const props = ComponentProps{};
    const toast1 = try Toast.init(allocator, "Toast 1", props);
    const toast2 = try Toast.init(allocator, "Toast 2", props);

    try manager.add(toast1);
    try manager.add(toast2);

    manager.clear();
    try std.testing.expect(manager.toasts.items.len == 0);
}
