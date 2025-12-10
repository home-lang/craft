const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;
const Style = base.Style;

/// Label Component - A text display element
pub const Label = struct {
    component: Component,
    text: []const u8,
    for_id: ?[]const u8,
    text_align: TextAlign,
    truncate: bool,
    selectable: bool,

    pub const TextAlign = enum {
        left,
        center,
        right,
    };

    pub fn init(allocator: std.mem.Allocator, text: []const u8, props: ComponentProps) !*Label {
        const label = try allocator.create(Label);
        label.* = Label{
            .component = try Component.init(allocator, "label", props),
            .text = text,
            .for_id = null,
            .text_align = .left,
            .truncate = false,
            .selectable = false,
        };
        return label;
    }

    pub fn deinit(self: *Label) void {
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    /// Set the text content
    pub fn setText(self: *Label, text: []const u8) void {
        self.text = text;
    }

    /// Get the text content
    pub fn getText(self: *const Label) []const u8 {
        return self.text;
    }

    /// Associate with a form element by ID (for accessibility)
    pub fn setForId(self: *Label, for_id: []const u8) void {
        self.for_id = for_id;
    }

    /// Get the associated element ID
    pub fn getForId(self: *const Label) ?[]const u8 {
        return self.for_id;
    }

    /// Set text alignment
    pub fn setTextAlign(self: *Label, alignment: TextAlign) void {
        self.text_align = alignment;
    }

    /// Get text alignment
    pub fn getTextAlign(self: *const Label) TextAlign {
        return self.text_align;
    }

    /// Enable text truncation with ellipsis
    pub fn setTruncate(self: *Label, truncate: bool) void {
        self.truncate = truncate;
    }

    /// Check if truncation is enabled
    pub fn isTruncated(self: *const Label) bool {
        return self.truncate;
    }

    /// Make text selectable
    pub fn setSelectable(self: *Label, selectable: bool) void {
        self.selectable = selectable;
    }

    /// Check if text is selectable
    pub fn isSelectable(self: *const Label) bool {
        return self.selectable;
    }

    /// Set font size
    pub fn setFontSize(self: *Label, size: u32) void {
        self.component.props.style.font_size = size;
    }

    /// Get font size
    pub fn getFontSize(self: *const Label) u32 {
        return self.component.props.style.font_size;
    }

    /// Set font weight
    pub fn setFontWeight(self: *Label, weight: Style.FontWeight) void {
        self.component.props.style.font_weight = weight;
    }

    /// Get font weight
    pub fn getFontWeight(self: *const Label) Style.FontWeight {
        return self.component.props.style.font_weight;
    }

    /// Set text color (RGBA)
    pub fn setColor(self: *Label, color: [4]u8) void {
        self.component.props.style.foreground_color = color;
    }

    /// Get text color
    pub fn getColor(self: *const Label) ?[4]u8 {
        return self.component.props.style.foreground_color;
    }

    /// Set visibility
    pub fn setVisible(self: *Label, visible: bool) void {
        self.component.props.visible = visible;
    }

    /// Check if visible
    pub fn isVisible(self: *const Label) bool {
        return self.component.props.visible;
    }
};

test "label creation" {
    const allocator = std.testing.allocator;
    const label = try Label.init(allocator, "Hello, World!", .{});
    defer label.deinit();

    try std.testing.expectEqualStrings("Hello, World!", label.getText());
    try std.testing.expect(label.getTextAlign() == .left);
}

test "label text modification" {
    const allocator = std.testing.allocator;
    const label = try Label.init(allocator, "Initial", .{});
    defer label.deinit();

    label.setText("Updated");
    try std.testing.expectEqualStrings("Updated", label.getText());
}

test "label alignment" {
    const allocator = std.testing.allocator;
    const label = try Label.init(allocator, "Centered", .{});
    defer label.deinit();

    label.setTextAlign(.center);
    try std.testing.expect(label.getTextAlign() == .center);

    label.setTextAlign(.right);
    try std.testing.expect(label.getTextAlign() == .right);
}

test "label for attribute" {
    const allocator = std.testing.allocator;
    const label = try Label.init(allocator, "Username:", .{});
    defer label.deinit();

    try std.testing.expect(label.getForId() == null);

    label.setForId("username-input");
    try std.testing.expectEqualStrings("username-input", label.getForId().?);
}

test "label styling" {
    const allocator = std.testing.allocator;
    const label = try Label.init(allocator, "Styled", .{});
    defer label.deinit();

    label.setFontSize(18);
    try std.testing.expect(label.getFontSize() == 18);

    label.setFontWeight(.bold);
    try std.testing.expect(label.getFontWeight() == .bold);

    label.setColor(.{ 255, 0, 0, 255 });
    try std.testing.expect(label.getColor().?[0] == 255);
}

test "label truncation" {
    const allocator = std.testing.allocator;
    const label = try Label.init(allocator, "Very long text that might need truncation", .{});
    defer label.deinit();

    try std.testing.expect(!label.isTruncated());

    label.setTruncate(true);
    try std.testing.expect(label.isTruncated());
}
