const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// Accordion Component - Collapsible sections with headers
pub const Accordion = struct {
    component: Component,
    sections: std.ArrayList(Section),
    allow_multiple: bool,
    on_section_change: ?*const fn (usize, bool) void,

    pub const Section = struct {
        title: []const u8,
        content: ?*Component,
        expanded: bool = false,
        disabled: bool = false,
        icon: ?[]const u8 = null,
    };

    pub const Config = struct {
        allow_multiple: bool = false,
        default_expanded: ?usize = null,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps, config: Config) !*Accordion {
        const accordion = try allocator.create(Accordion);
        accordion.* = Accordion{
            .component = try Component.init(allocator, "accordion", props),
            .sections = .{},
            .allow_multiple = config.allow_multiple,
            .on_section_change = null,
        };
        return accordion;
    }

    pub fn deinit(self: *Accordion) void {
        for (self.sections.items) |*section| {
            if (section.content) |content| {
                content.deinit();
                self.component.allocator.destroy(content);
            }
        }
        self.sections.deinit(self.component.allocator);
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    /// Add a new section to the accordion
    pub fn addSection(self: *Accordion, title: []const u8, content: ?*Component) !void {
        try self.sections.append(self.component.allocator, .{
            .title = title,
            .content = content,
            .expanded = false,
            .disabled = false,
            .icon = null,
        });
    }

    /// Add a section with custom configuration
    pub fn addSectionWithConfig(self: *Accordion, section: Section) !void {
        try self.sections.append(self.component.allocator, section);
    }

    /// Remove a section by index
    pub fn removeSection(self: *Accordion, index: usize) void {
        if (index < self.sections.items.len) {
            var section = self.sections.orderedRemove(index);
            if (section.content) |content| {
                content.deinit();
                self.component.allocator.destroy(content);
            }
        }
    }

    /// Toggle a section's expanded state
    pub fn toggleSection(self: *Accordion, index: usize) void {
        if (index >= self.sections.items.len) return;
        if (self.sections.items[index].disabled) return;

        const new_state = !self.sections.items[index].expanded;

        // If not allowing multiple, collapse all others
        if (!self.allow_multiple and new_state) {
            for (self.sections.items) |*section| {
                section.expanded = false;
            }
        }

        self.sections.items[index].expanded = new_state;

        if (self.on_section_change) |callback| {
            callback(index, new_state);
        }
    }

    /// Expand a specific section
    pub fn expandSection(self: *Accordion, index: usize) void {
        if (index >= self.sections.items.len) return;
        if (self.sections.items[index].disabled) return;

        if (!self.allow_multiple) {
            for (self.sections.items) |*section| {
                section.expanded = false;
            }
        }

        self.sections.items[index].expanded = true;

        if (self.on_section_change) |callback| {
            callback(index, true);
        }
    }

    /// Collapse a specific section
    pub fn collapseSection(self: *Accordion, index: usize) void {
        if (index >= self.sections.items.len) return;

        self.sections.items[index].expanded = false;

        if (self.on_section_change) |callback| {
            callback(index, false);
        }
    }

    /// Expand all sections (only works if allow_multiple is true)
    pub fn expandAll(self: *Accordion) void {
        if (!self.allow_multiple) return;

        for (self.sections.items, 0..) |*section, i| {
            if (!section.disabled) {
                section.expanded = true;
                if (self.on_section_change) |callback| {
                    callback(i, true);
                }
            }
        }
    }

    /// Collapse all sections
    pub fn collapseAll(self: *Accordion) void {
        for (self.sections.items, 0..) |*section, i| {
            section.expanded = false;
            if (self.on_section_change) |callback| {
                callback(i, false);
            }
        }
    }

    /// Set a section's disabled state
    pub fn setSectionDisabled(self: *Accordion, index: usize, disabled: bool) void {
        if (index < self.sections.items.len) {
            self.sections.items[index].disabled = disabled;
            // Collapse if disabling an expanded section
            if (disabled and self.sections.items[index].expanded) {
                self.sections.items[index].expanded = false;
            }
        }
    }

    /// Set a section's icon
    pub fn setSectionIcon(self: *Accordion, index: usize, icon: ?[]const u8) void {
        if (index < self.sections.items.len) {
            self.sections.items[index].icon = icon;
        }
    }

    /// Update a section's title
    pub fn setSectionTitle(self: *Accordion, index: usize, title: []const u8) void {
        if (index < self.sections.items.len) {
            self.sections.items[index].title = title;
        }
    }

    /// Get a section by index
    pub fn getSection(self: *const Accordion, index: usize) ?Section {
        if (index < self.sections.items.len) {
            return self.sections.items[index];
        }
        return null;
    }

    /// Get all expanded section indices
    pub fn getExpandedIndices(self: *const Accordion, allocator: std.mem.Allocator) ![]usize {
        var indices: std.ArrayList(usize) = .{};
        for (self.sections.items, 0..) |section, i| {
            if (section.expanded) {
                try indices.append(allocator, i);
            }
        }
        return indices.toOwnedSlice(allocator);
    }

    /// Get the number of sections
    pub fn getSectionCount(self: *const Accordion) usize {
        return self.sections.items.len;
    }

    /// Check if a section is expanded
    pub fn isSectionExpanded(self: *const Accordion, index: usize) bool {
        if (index < self.sections.items.len) {
            return self.sections.items[index].expanded;
        }
        return false;
    }

    /// Set callback for section state changes
    pub fn onSectionChange(self: *Accordion, callback: *const fn (usize, bool) void) void {
        self.on_section_change = callback;
    }

    /// Set whether multiple sections can be expanded simultaneously
    pub fn setAllowMultiple(self: *Accordion, allow: bool) void {
        self.allow_multiple = allow;
        // If switching to single mode, collapse all but the first expanded
        if (!allow) {
            var found_expanded = false;
            for (self.sections.items) |*section| {
                if (section.expanded) {
                    if (found_expanded) {
                        section.expanded = false;
                    } else {
                        found_expanded = true;
                    }
                }
            }
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "accordion creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var accordion = try Accordion.init(allocator, props, .{});
    defer accordion.deinit();

    try std.testing.expectEqual(@as(usize, 0), accordion.getSectionCount());
    try std.testing.expect(!accordion.allow_multiple);
}

test "accordion add and remove sections" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var accordion = try Accordion.init(allocator, props, .{});
    defer accordion.deinit();

    try accordion.addSection("Section 1", null);
    try accordion.addSection("Section 2", null);
    try accordion.addSection("Section 3", null);

    try std.testing.expectEqual(@as(usize, 3), accordion.getSectionCount());

    accordion.removeSection(1);
    try std.testing.expectEqual(@as(usize, 2), accordion.getSectionCount());
}

test "accordion toggle section - single mode" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var accordion = try Accordion.init(allocator, props, .{ .allow_multiple = false });
    defer accordion.deinit();

    try accordion.addSection("Section 1", null);
    try accordion.addSection("Section 2", null);

    accordion.toggleSection(0);
    try std.testing.expect(accordion.isSectionExpanded(0));
    try std.testing.expect(!accordion.isSectionExpanded(1));

    // Toggle second should collapse first
    accordion.toggleSection(1);
    try std.testing.expect(!accordion.isSectionExpanded(0));
    try std.testing.expect(accordion.isSectionExpanded(1));
}

test "accordion toggle section - multiple mode" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var accordion = try Accordion.init(allocator, props, .{ .allow_multiple = true });
    defer accordion.deinit();

    try accordion.addSection("Section 1", null);
    try accordion.addSection("Section 2", null);

    accordion.toggleSection(0);
    accordion.toggleSection(1);

    try std.testing.expect(accordion.isSectionExpanded(0));
    try std.testing.expect(accordion.isSectionExpanded(1));
}

test "accordion disabled section" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var accordion = try Accordion.init(allocator, props, .{});
    defer accordion.deinit();

    try accordion.addSection("Section 1", null);
    accordion.setSectionDisabled(0, true);

    accordion.toggleSection(0);
    try std.testing.expect(!accordion.isSectionExpanded(0));
}

test "accordion expand and collapse all" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var accordion = try Accordion.init(allocator, props, .{ .allow_multiple = true });
    defer accordion.deinit();

    try accordion.addSection("Section 1", null);
    try accordion.addSection("Section 2", null);
    try accordion.addSection("Section 3", null);

    accordion.expandAll();
    try std.testing.expect(accordion.isSectionExpanded(0));
    try std.testing.expect(accordion.isSectionExpanded(1));
    try std.testing.expect(accordion.isSectionExpanded(2));

    accordion.collapseAll();
    try std.testing.expect(!accordion.isSectionExpanded(0));
    try std.testing.expect(!accordion.isSectionExpanded(1));
    try std.testing.expect(!accordion.isSectionExpanded(2));
}

test "accordion get expanded indices" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var accordion = try Accordion.init(allocator, props, .{ .allow_multiple = true });
    defer accordion.deinit();

    try accordion.addSection("Section 1", null);
    try accordion.addSection("Section 2", null);
    try accordion.addSection("Section 3", null);

    accordion.expandSection(0);
    accordion.expandSection(2);

    const indices = try accordion.getExpandedIndices(allocator);
    defer allocator.free(indices);

    try std.testing.expectEqual(@as(usize, 2), indices.len);
    try std.testing.expectEqual(@as(usize, 0), indices[0]);
    try std.testing.expectEqual(@as(usize, 2), indices[1]);
}
