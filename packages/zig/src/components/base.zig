const std = @import("std");

/// Base Component - Foundation for all UI components
pub const Component = struct {
    id: []const u8,
    handle: ?*anyopaque,
    props: ComponentProps,
    children: std.ArrayList(*Component),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, id: []const u8, props: ComponentProps) !Component {
        return Component{
            .id = id,
            .handle = null,
            .props = props,
            .children = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Component) void {
        for (self.children.items) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }
        self.children.deinit(self.allocator);
    }

    pub fn appendChild(self: *Component, child: *Component) !void {
        try self.children.append(self.allocator, child);
    }

    pub fn removeChild(self: *Component, child: *Component) void {
        for (self.children.items, 0..) |c, i| {
            if (c == child) {
                _ = self.children.swapRemove(i);
                break;
            }
        }
    }
};

pub const ComponentProps = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: u32 = 100,
    height: u32 = 30,
    enabled: bool = true,
    visible: bool = true,
    style: Style = .{},
};

pub const Style = struct {
    background_color: ?[4]u8 = null,
    foreground_color: ?[4]u8 = null,
    border_color: ?[4]u8 = null,
    border_width: u32 = 0,
    border_radius: u32 = 0,
    font_size: u32 = 14,
    font_weight: FontWeight = .regular,
    padding: Padding = .{},
    margin: Margin = .{},

    pub const FontWeight = enum {
        light,
        regular,
        medium,
        bold,
    };

    pub const Padding = struct {
        top: u32 = 0,
        right: u32 = 0,
        bottom: u32 = 0,
        left: u32 = 0,
    };

    pub const Margin = struct {
        top: u32 = 0,
        right: u32 = 0,
        bottom: u32 = 0,
        left: u32 = 0,
    };
};

test "component creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var component = try Component.init(allocator, "test", props);
    defer component.deinit();

    try std.testing.expectEqualStrings("test", component.id);
    try std.testing.expect(component.props.enabled);
}

test "component children" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var parent = try Component.init(allocator, "parent", props);
    defer parent.deinit();

    const child = try allocator.create(Component);
    child.* = try Component.init(allocator, "child", props);

    try parent.appendChild(child);
    try std.testing.expect(parent.children.items.len == 1);
}
