const std = @import("std");
const components = @import("components");
const Modal = components.Modal;
const Component = components.Component;
const ComponentProps = components.ComponentProps;

var modal_opened = false;
var modal_closed = false;

fn handleOpen() void {
    modal_opened = true;
}

fn handleClose() void {
    modal_closed = true;
}

test "modal creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};

    const content = try allocator.create(Component);
    content.* = try Component.init(allocator, "content", props);

    const modal = try Modal.init(allocator, content, props);
    defer modal.deinit();

    try std.testing.expect(!modal.visible);
    try std.testing.expect(modal.closable);
    try std.testing.expect(modal.backdrop);
    try std.testing.expect(modal.title == null);
    try std.testing.expect(modal.footer == null);
}

test "modal open and close" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};

    const content = try allocator.create(Component);
    content.* = try Component.init(allocator, "content", props);

    const modal = try Modal.init(allocator, content, props);
    defer modal.deinit();

    modal_opened = false;
    modal_closed = false;
    modal.onOpen(&handleOpen);
    modal.onClose(&handleClose);

    modal.open();
    try std.testing.expect(modal.visible);
    try std.testing.expect(modal_opened);

    modal.close();
    try std.testing.expect(!modal.visible);
    try std.testing.expect(modal_closed);
}

test "modal toggle" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};

    const content = try allocator.create(Component);
    content.* = try Component.init(allocator, "content", props);

    const modal = try Modal.init(allocator, content, props);
    defer modal.deinit();

    try std.testing.expect(!modal.visible);

    modal.toggle();
    try std.testing.expect(modal.visible);

    modal.toggle();
    try std.testing.expect(!modal.visible);
}

test "modal closable state" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};

    const content = try allocator.create(Component);
    content.* = try Component.init(allocator, "content", props);

    const modal = try Modal.init(allocator, content, props);
    defer modal.deinit();

    modal.open();
    try std.testing.expect(modal.visible);

    // Make modal non-closable
    modal.setClosable(false);
    modal.close();

    // Should still be visible since it's not closable
    try std.testing.expect(modal.visible);

    // Make it closable again
    modal.setClosable(true);
    modal.close();
    try std.testing.expect(!modal.visible);
}

test "modal title and footer" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};

    const content = try allocator.create(Component);
    content.* = try Component.init(allocator, "content", props);

    const modal = try Modal.init(allocator, content, props);
    defer modal.deinit();

    modal.setTitle("Test Modal");
    try std.testing.expectEqualStrings("Test Modal", modal.title.?);

    const footer = try allocator.create(Component);
    footer.* = try Component.init(allocator, "footer", props);

    modal.setFooter(footer);
    try std.testing.expect(modal.footer != null);
}

test "modal backdrop" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};

    const content = try allocator.create(Component);
    content.* = try Component.init(allocator, "content", props);

    const modal = try Modal.init(allocator, content, props);
    defer modal.deinit();

    try std.testing.expect(modal.backdrop);

    modal.setBackdrop(false);
    try std.testing.expect(!modal.backdrop);
}
