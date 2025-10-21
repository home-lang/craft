const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// Button Component
pub const Button = struct {
    component: Component,
    text: []const u8,
    on_click: ?*const fn () void,

    pub fn init(allocator: std.mem.Allocator, text: []const u8, props: ComponentProps) !*Button {
        const button = try allocator.create(Button);
        button.* = Button{
            .component = try Component.init(allocator, "button", props),
            .text = text,
            .on_click = null,
        };
        return button;
    }

    pub fn deinit(self: *Button) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn onClick(self: *Button, callback: *const fn () void) void {
        self.on_click = callback;
    }

    pub fn click(self: *Button) void {
        if (self.on_click) |callback| {
            callback();
        }
    }

    pub fn setText(self: *Button, text: []const u8) void {
        self.text = text;
    }
};
