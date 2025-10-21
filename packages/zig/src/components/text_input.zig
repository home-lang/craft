const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// Text Input Component
pub const TextInput = struct {
    component: Component,
    value: []const u8,
    placeholder: ?[]const u8,
    max_length: ?usize,
    password: bool,
    on_change: ?*const fn ([]const u8) void,

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*TextInput {
        const input = try allocator.create(TextInput);
        input.* = TextInput{
            .component = try Component.init(allocator, "text_input", props),
            .value = "",
            .placeholder = null,
            .max_length = null,
            .password = false,
            .on_change = null,
        };
        return input;
    }

    pub fn deinit(self: *TextInput) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setValue(self: *TextInput, value: []const u8) void {
        if (self.max_length) |max| {
            if (value.len > max) return;
        }
        self.value = value;
        if (self.on_change) |callback| {
            callback(value);
        }
    }

    pub fn onChange(self: *TextInput, callback: *const fn ([]const u8) void) void {
        self.on_change = callback;
    }

    pub fn setPlaceholder(self: *TextInput, placeholder: []const u8) void {
        self.placeholder = placeholder;
    }

    pub fn setPassword(self: *TextInput, password: bool) void {
        self.password = password;
    }

    pub fn setMaxLength(self: *TextInput, max_length: usize) void {
        self.max_length = max_length;
    }
};
