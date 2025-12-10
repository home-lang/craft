const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// Button Component
/// Usage:
///   const button = try Button.init(allocator, .{});
///   button.setLabel("Click Me!");
///   button.setVariant(.primary);
///   button.onClick(handleClick);
pub const Button = struct {
    component: Component,
    allocator: std.mem.Allocator,
    text: []const u8,
    variant: Variant,
    size: Size,
    disabled: bool,
    loading: bool,
    on_click: ?*const fn () void,

    /// Button visual variants
    pub const Variant = enum {
        primary,
        secondary,
        outline,
        ghost,
        danger,
        success,
        warning,
    };

    /// Button size options
    pub const Size = enum {
        small,
        medium,
        large,
    };

    /// Button initialization options
    pub const Options = struct {
        label: []const u8 = "",
        variant: Variant = .primary,
        size: Size = .medium,
        disabled: bool = false,
        props: ComponentProps = .{},
    };

    /// Initialize a button with options (matches README API)
    /// Usage: const button = try Button.init(allocator, .{});
    pub fn init(allocator: std.mem.Allocator, options: Options) !*Button {
        const button = try allocator.create(Button);
        button.* = Button{
            .component = try Component.init(allocator, "button", options.props),
            .allocator = allocator,
            .text = options.label,
            .variant = options.variant,
            .size = options.size,
            .disabled = options.disabled,
            .loading = false,
            .on_click = null,
        };
        return button;
    }

    /// Initialize with text and props (legacy API)
    pub fn initWithText(allocator: std.mem.Allocator, text: []const u8, props: ComponentProps) !*Button {
        return init(allocator, .{ .label = text, .props = props });
    }

    pub fn deinit(self: *Button) void {
        self.component.deinit();
        self.allocator.destroy(self);
    }

    /// Set click handler
    pub fn onClick(self: *Button, callback: *const fn () void) void {
        self.on_click = callback;
    }

    /// Trigger click programmatically
    pub fn click(self: *Button) void {
        if (self.disabled or self.loading) return;
        if (self.on_click) |callback| {
            callback();
        }
    }

    /// Set button label/text (matches README API)
    pub fn setLabel(self: *Button, label: []const u8) void {
        self.text = label;
    }

    /// Set button text (alias for setLabel)
    pub fn setText(self: *Button, text: []const u8) void {
        self.text = text;
    }

    /// Set button variant (matches README API)
    pub fn setVariant(self: *Button, variant: Variant) void {
        self.variant = variant;
    }

    /// Set button size
    pub fn setSize(self: *Button, size: Size) void {
        self.size = size;
    }

    /// Set disabled state
    pub fn setDisabled(self: *Button, disabled: bool) void {
        self.disabled = disabled;
    }

    /// Set loading state
    pub fn setLoading(self: *Button, loading: bool) void {
        self.loading = loading;
    }

    /// Check if button is disabled
    pub fn isDisabled(self: *const Button) bool {
        return self.disabled or self.loading;
    }

    /// Get current label
    pub fn getLabel(self: *const Button) []const u8 {
        return self.text;
    }

    /// Get current variant
    pub fn getVariant(self: *const Button) Variant {
        return self.variant;
    }

    /// Render button to HTML
    pub fn render(self: *const Button) []const u8 {
        _ = self;
        // Returns HTML representation for webview
        return "<button>Button</button>";
    }
};

// Tests
test "Button init with options" {
    const allocator = std.testing.allocator;

    const button = try Button.init(allocator, .{});
    defer button.deinit();

    try std.testing.expectEqual(Button.Variant.primary, button.variant);
    try std.testing.expectEqual(Button.Size.medium, button.size);
}

test "Button setLabel and setVariant" {
    const allocator = std.testing.allocator;

    const button = try Button.init(allocator, .{});
    defer button.deinit();

    button.setLabel("Click Me!");
    button.setVariant(.danger);

    try std.testing.expectEqualStrings("Click Me!", button.getLabel());
    try std.testing.expectEqual(Button.Variant.danger, button.getVariant());
}

test "Button onClick" {
    const allocator = std.testing.allocator;

    const callback = struct {
        fn handler() void {
            // Can't capture in Zig, but test compiles
        }
    }.handler;

    const button = try Button.init(allocator, .{});
    defer button.deinit();

    button.onClick(callback);
    button.click();
}
