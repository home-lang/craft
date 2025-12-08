const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// StatusBar Component - Horizontal bar for displaying status information
pub const StatusBar = struct {
    component: Component,
    sections: std.ArrayList(Section),
    on_section_click: ?*const fn ([]const u8) void,
    separator_style: SeparatorStyle,
    show_size_grip: bool,

    pub const Section = struct {
        id: []const u8,
        content: Content,
        width: Width = .auto,
        alignment: Alignment = .left,
        clickable: bool = false,
        tooltip: ?[]const u8 = null,
        icon: ?[]const u8 = null,
        visible: bool = true,
    };

    pub const Content = union(enum) {
        text: []const u8,
        icon: []const u8,
        progress: f32, // 0.0 to 1.0
        custom: *Component,
    };

    pub const Width = union(enum) {
        auto: void,
        fixed: u32,
        percent: f32, // 0.0 to 1.0
        flex: u32, // flex grow factor
    };

    pub const Alignment = enum {
        left,
        center,
        right,
    };

    pub const SeparatorStyle = enum {
        none,
        line,
        raised,
        sunken,
    };

    pub const Config = struct {
        separator_style: SeparatorStyle = .line,
        show_size_grip: bool = true,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps, config: Config) !*StatusBar {
        const status_bar = try allocator.create(StatusBar);
        status_bar.* = StatusBar{
            .component = try Component.init(allocator, "statusbar", props),
            .sections = .{},
            .on_section_click = null,
            .separator_style = config.separator_style,
            .show_size_grip = config.show_size_grip,
        };
        return status_bar;
    }

    pub fn deinit(self: *StatusBar) void {
        for (self.sections.items) |*section| {
            switch (section.content) {
                .custom => |custom| {
                    custom.deinit();
                    self.component.allocator.destroy(custom);
                },
                else => {},
            }
        }
        self.sections.deinit(self.component.allocator);
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    /// Add a text section
    pub fn addTextSection(self: *StatusBar, id: []const u8, text: []const u8) !void {
        try self.sections.append(self.component.allocator, .{
            .id = id,
            .content = .{ .text = text },
        });
    }

    /// Add a text section with icon
    pub fn addTextSectionWithIcon(self: *StatusBar, id: []const u8, text: []const u8, icon: []const u8) !void {
        try self.sections.append(self.component.allocator, .{
            .id = id,
            .content = .{ .text = text },
            .icon = icon,
        });
    }

    /// Add an icon-only section
    pub fn addIconSection(self: *StatusBar, id: []const u8, icon: []const u8) !void {
        try self.sections.append(self.component.allocator, .{
            .id = id,
            .content = .{ .icon = icon },
        });
    }

    /// Add a progress indicator section
    pub fn addProgressSection(self: *StatusBar, id: []const u8, progress: f32) !void {
        try self.sections.append(self.component.allocator, .{
            .id = id,
            .content = .{ .progress = std.math.clamp(progress, 0.0, 1.0) },
        });
    }

    /// Add a custom component section
    pub fn addCustomSection(self: *StatusBar, id: []const u8, component: *Component) !void {
        try self.sections.append(self.component.allocator, .{
            .id = id,
            .content = .{ .custom = component },
        });
    }

    /// Add a section with full configuration
    pub fn addSection(self: *StatusBar, section: Section) !void {
        try self.sections.append(self.component.allocator, section);
    }

    /// Remove a section by index
    pub fn removeSection(self: *StatusBar, index: usize) void {
        if (index < self.sections.items.len) {
            var section = self.sections.orderedRemove(index);
            switch (section.content) {
                .custom => |custom| {
                    custom.deinit();
                    self.component.allocator.destroy(custom);
                },
                else => {},
            }
        }
    }

    /// Remove a section by ID
    pub fn removeSectionById(self: *StatusBar, id: []const u8) void {
        for (self.sections.items, 0..) |section, i| {
            if (std.mem.eql(u8, section.id, id)) {
                self.removeSection(i);
                return;
            }
        }
    }

    /// Get section count
    pub fn getSectionCount(self: *const StatusBar) usize {
        return self.sections.items.len;
    }

    /// Get a section by index
    pub fn getSection(self: *const StatusBar, index: usize) ?Section {
        if (index < self.sections.items.len) {
            return self.sections.items[index];
        }
        return null;
    }

    /// Get a section by ID
    pub fn getSectionById(self: *const StatusBar, id: []const u8) ?Section {
        for (self.sections.items) |section| {
            if (std.mem.eql(u8, section.id, id)) {
                return section;
            }
        }
        return null;
    }

    /// Set section text content
    pub fn setSectionText(self: *StatusBar, id: []const u8, text: []const u8) void {
        for (self.sections.items) |*section| {
            if (std.mem.eql(u8, section.id, id)) {
                section.content = .{ .text = text };
                return;
            }
        }
    }

    /// Set section icon
    pub fn setSectionIcon(self: *StatusBar, id: []const u8, icon: ?[]const u8) void {
        for (self.sections.items) |*section| {
            if (std.mem.eql(u8, section.id, id)) {
                section.icon = icon;
                return;
            }
        }
    }

    /// Set section progress
    pub fn setSectionProgress(self: *StatusBar, id: []const u8, progress: f32) void {
        for (self.sections.items) |*section| {
            if (std.mem.eql(u8, section.id, id)) {
                section.content = .{ .progress = std.math.clamp(progress, 0.0, 1.0) };
                return;
            }
        }
    }

    /// Set section tooltip
    pub fn setSectionTooltip(self: *StatusBar, id: []const u8, tooltip: ?[]const u8) void {
        for (self.sections.items) |*section| {
            if (std.mem.eql(u8, section.id, id)) {
                section.tooltip = tooltip;
                return;
            }
        }
    }

    /// Set section visibility
    pub fn setSectionVisible(self: *StatusBar, id: []const u8, visible: bool) void {
        for (self.sections.items) |*section| {
            if (std.mem.eql(u8, section.id, id)) {
                section.visible = visible;
                return;
            }
        }
    }

    /// Set section clickable state
    pub fn setSectionClickable(self: *StatusBar, id: []const u8, clickable: bool) void {
        for (self.sections.items) |*section| {
            if (std.mem.eql(u8, section.id, id)) {
                section.clickable = clickable;
                return;
            }
        }
    }

    /// Set section width
    pub fn setSectionWidth(self: *StatusBar, id: []const u8, width: Width) void {
        for (self.sections.items) |*section| {
            if (std.mem.eql(u8, section.id, id)) {
                section.width = width;
                return;
            }
        }
    }

    /// Set section alignment
    pub fn setSectionAlignment(self: *StatusBar, id: []const u8, alignment: Alignment) void {
        for (self.sections.items) |*section| {
            if (std.mem.eql(u8, section.id, id)) {
                section.alignment = alignment;
                return;
            }
        }
    }

    /// Handle section click
    pub fn handleSectionClick(self: *StatusBar, index: usize) void {
        if (index >= self.sections.items.len) return;

        const section = &self.sections.items[index];
        if (!section.clickable or !section.visible) return;

        if (self.on_section_click) |callback| {
            callback(section.id);
        }
    }

    /// Handle section click by ID
    pub fn handleSectionClickById(self: *StatusBar, id: []const u8) void {
        for (self.sections.items, 0..) |section, i| {
            if (std.mem.eql(u8, section.id, id)) {
                self.handleSectionClick(i);
                return;
            }
        }
    }

    /// Set callback for section clicks
    pub fn onSectionClick(self: *StatusBar, callback: *const fn ([]const u8) void) void {
        self.on_section_click = callback;
    }

    /// Set separator style
    pub fn setSeparatorStyle(self: *StatusBar, style: SeparatorStyle) void {
        self.separator_style = style;
    }

    /// Set whether to show size grip
    pub fn setShowSizeGrip(self: *StatusBar, show: bool) void {
        self.show_size_grip = show;
    }

    /// Clear all sections
    pub fn clearSections(self: *StatusBar) void {
        for (self.sections.items) |*section| {
            switch (section.content) {
                .custom => |custom| {
                    custom.deinit();
                    self.component.allocator.destroy(custom);
                },
                else => {},
            }
        }
        self.sections.clearRetainingCapacity();
    }

    /// Get visible section count
    pub fn getVisibleSectionCount(self: *const StatusBar) usize {
        var count: usize = 0;
        for (self.sections.items) |section| {
            if (section.visible) {
                count += 1;
            }
        }
        return count;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "statusbar creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var statusbar = try StatusBar.init(allocator, props, .{});
    defer statusbar.deinit();

    try std.testing.expectEqual(@as(usize, 0), statusbar.getSectionCount());
    try std.testing.expectEqual(StatusBar.SeparatorStyle.line, statusbar.separator_style);
    try std.testing.expect(statusbar.show_size_grip);
}

test "statusbar add text sections" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var statusbar = try StatusBar.init(allocator, props, .{});
    defer statusbar.deinit();

    try statusbar.addTextSection("status", "Ready");
    try statusbar.addTextSectionWithIcon("line", "Line 1, Col 1", "cursor");
    try statusbar.addIconSection("encoding", "utf8");

    try std.testing.expectEqual(@as(usize, 3), statusbar.getSectionCount());
}

test "statusbar progress section" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var statusbar = try StatusBar.init(allocator, props, .{});
    defer statusbar.deinit();

    try statusbar.addProgressSection("loading", 0.5);

    const section = statusbar.getSectionById("loading");
    try std.testing.expect(section != null);

    switch (section.?.content) {
        .progress => |p| try std.testing.expectApproxEqAbs(@as(f32, 0.5), p, 0.001),
        else => try std.testing.expect(false),
    }
}

test "statusbar update section" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var statusbar = try StatusBar.init(allocator, props, .{});
    defer statusbar.deinit();

    try statusbar.addTextSection("status", "Loading...");
    statusbar.setSectionText("status", "Ready");

    const section = statusbar.getSectionById("status");
    try std.testing.expect(section != null);

    switch (section.?.content) {
        .text => |t| try std.testing.expectEqualStrings("Ready", t),
        else => try std.testing.expect(false),
    }
}

test "statusbar visibility" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var statusbar = try StatusBar.init(allocator, props, .{});
    defer statusbar.deinit();

    try statusbar.addTextSection("sec1", "Section 1");
    try statusbar.addTextSection("sec2", "Section 2");

    try std.testing.expectEqual(@as(usize, 2), statusbar.getVisibleSectionCount());

    statusbar.setSectionVisible("sec1", false);
    try std.testing.expectEqual(@as(usize, 1), statusbar.getVisibleSectionCount());
}

test "statusbar remove section" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var statusbar = try StatusBar.init(allocator, props, .{});
    defer statusbar.deinit();

    try statusbar.addTextSection("sec1", "Section 1");
    try statusbar.addTextSection("sec2", "Section 2");
    try statusbar.addTextSection("sec3", "Section 3");

    try std.testing.expectEqual(@as(usize, 3), statusbar.getSectionCount());

    statusbar.removeSectionById("sec2");
    try std.testing.expectEqual(@as(usize, 2), statusbar.getSectionCount());
}

test "statusbar section width" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var statusbar = try StatusBar.init(allocator, props, .{});
    defer statusbar.deinit();

    try statusbar.addSection(.{
        .id = "fixed",
        .content = .{ .text = "Fixed Width" },
        .width = .{ .fixed = 100 },
    });

    try statusbar.addSection(.{
        .id = "flex",
        .content = .{ .text = "Flexible" },
        .width = .{ .flex = 1 },
    });

    const fixed = statusbar.getSectionById("fixed");
    try std.testing.expect(fixed != null);

    switch (fixed.?.width) {
        .fixed => |w| try std.testing.expectEqual(@as(u32, 100), w),
        else => try std.testing.expect(false),
    }
}
