//! Cross-platform home screen widgets module
//! Provides abstractions for WidgetKit (iOS/macOS) and App Widgets (Android)

const std = @import("std");

/// Widget platform
pub const WidgetPlatform = enum {
    widget_kit, // iOS 14+, macOS 11+
    app_widgets, // Android
    live_tiles, // Windows (legacy)
    desktop_widgets, // macOS Dashboard (legacy)

    pub fn toString(self: WidgetPlatform) []const u8 {
        return switch (self) {
            .widget_kit => "WidgetKit",
            .app_widgets => "App Widgets",
            .live_tiles => "Live Tiles",
            .desktop_widgets => "Desktop Widgets",
        };
    }

    pub fn supportsInteractivity(self: WidgetPlatform) bool {
        return switch (self) {
            .widget_kit => true, // iOS 17+
            .app_widgets => true,
            .live_tiles => false,
            .desktop_widgets => true,
        };
    }
};

/// Widget family/size
pub const WidgetFamily = enum {
    small,
    medium,
    large,
    extra_large,
    accessory_circular, // Lock screen / Watch
    accessory_rectangular,
    accessory_inline,

    pub fn toString(self: WidgetFamily) []const u8 {
        return switch (self) {
            .small => "Small",
            .medium => "Medium",
            .large => "Large",
            .extra_large => "Extra Large",
            .accessory_circular => "Circular",
            .accessory_rectangular => "Rectangular",
            .accessory_inline => "Inline",
        };
    }

    pub fn isAccessory(self: WidgetFamily) bool {
        return switch (self) {
            .accessory_circular, .accessory_rectangular, .accessory_inline => true,
            else => false,
        };
    }

    pub fn defaultSize(self: WidgetFamily) struct { width: u32, height: u32 } {
        return switch (self) {
            .small => .{ .width = 169, .height = 169 },
            .medium => .{ .width = 360, .height = 169 },
            .large => .{ .width = 360, .height = 376 },
            .extra_large => .{ .width = 715, .height = 376 },
            .accessory_circular => .{ .width = 76, .height = 76 },
            .accessory_rectangular => .{ .width = 172, .height = 76 },
            .accessory_inline => .{ .width = 200, .height = 20 },
        };
    }
};

/// Widget refresh policy
pub const RefreshPolicy = enum {
    never,
    after_date,
    at_end, // After timeline ends

    pub fn toString(self: RefreshPolicy) []const u8 {
        return switch (self) {
            .never => "Never",
            .after_date => "After Date",
            .at_end => "At End",
        };
    }
};

/// Timeline entry for widget updates
pub const TimelineEntry = struct {
    date: u64, // Unix timestamp in milliseconds
    relevance: f32, // 0.0 - 1.0
    data: ?[]const u8,

    pub fn init(date: u64) TimelineEntry {
        return .{
            .date = date,
            .relevance = 1.0,
            .data = null,
        };
    }

    pub fn now() TimelineEntry {
        var ts: std.c.timespec = undefined;
        if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
            const ms: u64 = @intCast(ts.sec * 1000 + @divTrunc(ts.nsec, 1_000_000));
            return TimelineEntry.init(ms);
        }
        return TimelineEntry.init(0);
    }

    pub fn withRelevance(self: TimelineEntry, relevance: f32) TimelineEntry {
        var entry = self;
        entry.relevance = std.math.clamp(relevance, 0.0, 1.0);
        return entry;
    }

    pub fn withData(self: TimelineEntry, data: []const u8) TimelineEntry {
        var entry = self;
        entry.data = data;
        return entry;
    }

    pub fn isExpired(self: TimelineEntry) bool {
        var ts: std.c.timespec = undefined;
        if (std.c.clock_gettime(.REALTIME, &ts) != 0) return false;
        const now_ms: u64 = @intCast(ts.sec * 1000 + @divTrunc(ts.nsec, 1_000_000));
        return self.date < now_ms;
    }
};

/// Widget timeline
pub const Timeline = struct {
    entries: std.ArrayListUnmanaged(TimelineEntry),
    policy: RefreshPolicy,
    refresh_date: ?u64,

    pub fn init() Timeline {
        return .{
            .entries = .{},
            .policy = .at_end,
            .refresh_date = null,
        };
    }

    pub fn deinit(self: *Timeline, allocator: std.mem.Allocator) void {
        self.entries.deinit(allocator);
    }

    pub fn addEntry(self: *Timeline, allocator: std.mem.Allocator, entry: TimelineEntry) !void {
        try self.entries.append(allocator, entry);
    }

    pub fn withPolicy(self: Timeline, policy: RefreshPolicy) Timeline {
        var timeline = self;
        timeline.policy = policy;
        return timeline;
    }

    pub fn withRefreshDate(self: Timeline, date: u64) Timeline {
        var timeline = self;
        timeline.refresh_date = date;
        timeline.policy = .after_date;
        return timeline;
    }

    pub fn entryCount(self: *const Timeline) usize {
        return self.entries.items.len;
    }

    pub fn getCurrentEntry(self: *const Timeline) ?TimelineEntry {
        if (self.entries.items.len == 0) return null;

        var ts: std.c.timespec = undefined;
        if (std.c.clock_gettime(.REALTIME, &ts) != 0) return self.entries.items[0];
        const now_ms: u64 = @intCast(ts.sec * 1000 + @divTrunc(ts.nsec, 1_000_000));

        var best: ?TimelineEntry = null;
        for (self.entries.items) |entry| {
            if (entry.date <= now_ms) {
                if (best == null or entry.date > best.?.date) {
                    best = entry;
                }
            }
        }
        return best orelse self.entries.items[0];
    }
};

/// Widget content type
pub const ContentType = enum {
    static,
    timeline,
    intent_based,
    live_activity,

    pub fn toString(self: ContentType) []const u8 {
        return switch (self) {
            .static => "Static",
            .timeline => "Timeline",
            .intent_based => "Intent Based",
            .live_activity => "Live Activity",
        };
    }
};

/// Widget display mode
pub const DisplayMode = enum {
    full_color,
    vibrant, // For lock screen
    accented, // Single accent color

    pub fn toString(self: DisplayMode) []const u8 {
        return switch (self) {
            .full_color => "Full Color",
            .vibrant => "Vibrant",
            .accented => "Accented",
        };
    }
};

/// Widget background style
pub const BackgroundStyle = enum {
    automatic,
    color,
    gradient,
    blur,
    image,
    transparent,

    pub fn toString(self: BackgroundStyle) []const u8 {
        return switch (self) {
            .automatic => "Automatic",
            .color => "Color",
            .gradient => "Gradient",
            .blur => "Blur",
            .image => "Image",
            .transparent => "Transparent",
        };
    }
};

/// Color for widget styling
pub const WidgetColor = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub const white = WidgetColor{ .r = 255, .g = 255, .b = 255, .a = 255 };
    pub const black = WidgetColor{ .r = 0, .g = 0, .b = 0, .a = 255 };
    pub const clear = WidgetColor{ .r = 0, .g = 0, .b = 0, .a = 0 };

    pub fn init(r: u8, g: u8, b: u8) WidgetColor {
        return .{ .r = r, .g = g, .b = b, .a = 255 };
    }

    pub fn withAlpha(self: WidgetColor, alpha: u8) WidgetColor {
        var color = self;
        color.a = alpha;
        return color;
    }

    pub fn toHex(self: WidgetColor) u32 {
        return (@as(u32, self.a) << 24) |
            (@as(u32, self.r) << 16) |
            (@as(u32, self.g) << 8) |
            @as(u32, self.b);
    }

    pub fn fromHex(hex: u32) WidgetColor {
        return .{
            .a = @truncate((hex >> 24) & 0xFF),
            .r = @truncate((hex >> 16) & 0xFF),
            .g = @truncate((hex >> 8) & 0xFF),
            .b = @truncate(hex & 0xFF),
        };
    }
};

/// Widget text style
pub const TextStyle = enum {
    headline,
    subheadline,
    body,
    caption,
    footnote,
    title,
    large_title,

    pub fn toString(self: TextStyle) []const u8 {
        return switch (self) {
            .headline => "Headline",
            .subheadline => "Subheadline",
            .body => "Body",
            .caption => "Caption",
            .footnote => "Footnote",
            .title => "Title",
            .large_title => "Large Title",
        };
    }

    pub fn defaultSize(self: TextStyle) f32 {
        return switch (self) {
            .large_title => 34.0,
            .title => 28.0,
            .headline => 17.0,
            .subheadline => 15.0,
            .body => 17.0,
            .caption => 12.0,
            .footnote => 13.0,
        };
    }
};

/// Widget element types
pub const ElementType = enum {
    text,
    image,
    gauge,
    progress_bar,
    chart,
    spacer,
    divider,
    container,
    link,
    button,

    pub fn toString(self: ElementType) []const u8 {
        return switch (self) {
            .text => "Text",
            .image => "Image",
            .gauge => "Gauge",
            .progress_bar => "Progress Bar",
            .chart => "Chart",
            .spacer => "Spacer",
            .divider => "Divider",
            .container => "Container",
            .link => "Link",
            .button => "Button",
        };
    }

    pub fn isInteractive(self: ElementType) bool {
        return self == .link or self == .button;
    }
};

/// Widget element
pub const WidgetElement = struct {
    element_type: ElementType,
    content: ?[]const u8,
    style: ?TextStyle,
    color: ?WidgetColor,
    url: ?[]const u8,
    children: std.ArrayListUnmanaged(WidgetElement),

    pub fn text(content: []const u8) WidgetElement {
        return .{
            .element_type = .text,
            .content = content,
            .style = .body,
            .color = null,
            .url = null,
            .children = .{},
        };
    }

    pub fn image(name: []const u8) WidgetElement {
        return .{
            .element_type = .image,
            .content = name,
            .style = null,
            .color = null,
            .url = null,
            .children = .{},
        };
    }

    pub fn spacer() WidgetElement {
        return .{
            .element_type = .spacer,
            .content = null,
            .style = null,
            .color = null,
            .url = null,
            .children = .{},
        };
    }

    pub fn link(label: []const u8, url: []const u8) WidgetElement {
        return .{
            .element_type = .link,
            .content = label,
            .style = null,
            .color = null,
            .url = url,
            .children = .{},
        };
    }

    pub fn gauge(value: f32) WidgetElement {
        _ = value;
        return .{
            .element_type = .gauge,
            .content = null,
            .style = null,
            .color = null,
            .url = null,
            .children = .{},
        };
    }

    pub fn deinit(self: *WidgetElement, allocator: std.mem.Allocator) void {
        for (self.children.items) |*child| {
            child.deinit(allocator);
        }
        self.children.deinit(allocator);
    }

    pub fn withStyle(self: WidgetElement, style: TextStyle) WidgetElement {
        var elem = self;
        elem.style = style;
        return elem;
    }

    pub fn withColor(self: WidgetElement, color: WidgetColor) WidgetElement {
        var elem = self;
        elem.color = color;
        return elem;
    }

    pub fn addChild(self: *WidgetElement, allocator: std.mem.Allocator, child: WidgetElement) !void {
        try self.children.append(allocator, child);
    }

    pub fn childCount(self: *const WidgetElement) usize {
        return self.children.items.len;
    }
};

/// Widget configuration
pub const WidgetConfiguration = struct {
    kind: []const u8,
    display_name: []const u8,
    description: ?[]const u8,
    supported_families: std.ArrayListUnmanaged(WidgetFamily),
    content_type: ContentType,
    is_configurable: bool,
    supports_container_background: bool,

    pub fn init(allocator: std.mem.Allocator, kind: []const u8, display_name: []const u8) WidgetConfiguration {
        _ = allocator;
        return .{
            .kind = kind,
            .display_name = display_name,
            .description = null,
            .supported_families = .{},
            .content_type = .static,
            .is_configurable = false,
            .supports_container_background = true,
        };
    }

    pub fn deinit(self: *WidgetConfiguration, allocator: std.mem.Allocator) void {
        self.supported_families.deinit(allocator);
    }

    pub fn addFamily(self: *WidgetConfiguration, allocator: std.mem.Allocator, family: WidgetFamily) !void {
        try self.supported_families.append(allocator, family);
    }

    pub fn withDescription(self: WidgetConfiguration, desc: []const u8) WidgetConfiguration {
        var config = self;
        config.description = desc;
        return config;
    }

    pub fn configurable(self: WidgetConfiguration, is_configurable: bool) WidgetConfiguration {
        var config = self;
        config.is_configurable = is_configurable;
        return config;
    }

    pub fn supportsFamily(self: *const WidgetConfiguration, family: WidgetFamily) bool {
        for (self.supported_families.items) |f| {
            if (f == family) return true;
        }
        return false;
    }
};

/// Widget intent/action
pub const WidgetIntent = struct {
    identifier: []const u8,
    title: []const u8,
    parameters: std.StringHashMapUnmanaged([]const u8),

    pub fn init(identifier: []const u8, title: []const u8) WidgetIntent {
        return .{
            .identifier = identifier,
            .title = title,
            .parameters = .{},
        };
    }

    pub fn deinit(self: *WidgetIntent, allocator: std.mem.Allocator) void {
        self.parameters.deinit(allocator);
    }

    pub fn setParameter(self: *WidgetIntent, allocator: std.mem.Allocator, key: []const u8, value: []const u8) !void {
        try self.parameters.put(allocator, key, value);
    }

    pub fn getParameter(self: *const WidgetIntent, key: []const u8) ?[]const u8 {
        return self.parameters.get(key);
    }

    pub fn hasParameters(self: *const WidgetIntent) bool {
        return self.parameters.count() > 0;
    }
};

/// Live Activity state (iOS 16+)
pub const LiveActivityState = enum {
    active,
    dismissed,
    ended,
    stale,

    pub fn toString(self: LiveActivityState) []const u8 {
        return switch (self) {
            .active => "Active",
            .dismissed => "Dismissed",
            .ended => "Ended",
            .stale => "Stale",
        };
    }

    pub fn isVisible(self: LiveActivityState) bool {
        return self == .active or self == .stale;
    }
};

/// Live Activity
pub const LiveActivity = struct {
    id: []const u8,
    activity_type: []const u8,
    state: LiveActivityState,
    start_time: u64,
    stale_date: ?u64,
    content: ?WidgetElement,

    pub fn init(id: []const u8, activity_type: []const u8) LiveActivity {
        var start: u64 = 0;
        var ts: std.c.timespec = undefined;
        if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
            start = @intCast(ts.sec * 1000 + @divTrunc(ts.nsec, 1_000_000));
        }
        return .{
            .id = id,
            .activity_type = activity_type,
            .state = .active,
            .start_time = start,
            .stale_date = null,
            .content = null,
        };
    }

    pub fn end(self: *LiveActivity) void {
        self.state = .ended;
    }

    pub fn dismiss(self: *LiveActivity) void {
        self.state = .dismissed;
    }

    pub fn setStaleDate(self: *LiveActivity, date: u64) void {
        self.stale_date = date;
    }

    pub fn isActive(self: *const LiveActivity) bool {
        return self.state.isVisible();
    }

    pub fn duration(self: *const LiveActivity) u64 {
        var ts: std.c.timespec = undefined;
        if (std.c.clock_gettime(.REALTIME, &ts) != 0) return 0;
        const now_ms: u64 = @intCast(ts.sec * 1000 + @divTrunc(ts.nsec, 1_000_000));
        if (now_ms > self.start_time) {
            return now_ms - self.start_time;
        }
        return 0;
    }
};

/// Widget update request
pub const UpdateRequest = struct {
    widget_kind: []const u8,
    families: std.ArrayListUnmanaged(WidgetFamily),
    is_relevant: bool,

    pub fn init(allocator: std.mem.Allocator, kind: []const u8) UpdateRequest {
        _ = allocator;
        return .{
            .widget_kind = kind,
            .families = .{},
            .is_relevant = true,
        };
    }

    pub fn deinit(self: *UpdateRequest, allocator: std.mem.Allocator) void {
        self.families.deinit(allocator);
    }

    pub fn addFamily(self: *UpdateRequest, allocator: std.mem.Allocator, family: WidgetFamily) !void {
        try self.families.append(allocator, family);
    }

    pub fn allFamilies(self: *UpdateRequest, allocator: std.mem.Allocator) !void {
        const all = [_]WidgetFamily{ .small, .medium, .large, .extra_large };
        for (all) |f| {
            try self.families.append(allocator, f);
        }
    }
};

/// Widget center for managing widgets
pub const WidgetCenter = struct {
    allocator: std.mem.Allocator,
    configurations: std.ArrayListUnmanaged(WidgetConfiguration),
    live_activities: std.ArrayListUnmanaged(LiveActivity),
    pending_updates: std.ArrayListUnmanaged(UpdateRequest),

    pub fn init(allocator: std.mem.Allocator) WidgetCenter {
        return .{
            .allocator = allocator,
            .configurations = .{},
            .live_activities = .{},
            .pending_updates = .{},
        };
    }

    pub fn deinit(self: *WidgetCenter) void {
        for (self.configurations.items) |*config| {
            config.deinit(self.allocator);
        }
        self.configurations.deinit(self.allocator);
        self.live_activities.deinit(self.allocator);
        for (self.pending_updates.items) |*update| {
            update.deinit(self.allocator);
        }
        self.pending_updates.deinit(self.allocator);
    }

    pub fn registerWidget(self: *WidgetCenter, config: WidgetConfiguration) !void {
        try self.configurations.append(self.allocator, config);
    }

    pub fn reloadTimelines(self: *WidgetCenter, kind: []const u8) !void {
        var request = UpdateRequest.init(self.allocator, kind);
        try request.allFamilies(self.allocator);
        try self.pending_updates.append(self.allocator, request);
    }

    pub fn reloadAllTimelines(self: *WidgetCenter) !void {
        for (self.configurations.items) |config| {
            try self.reloadTimelines(config.kind);
        }
    }

    pub fn startLiveActivity(self: *WidgetCenter, id: []const u8, activity_type: []const u8) !*LiveActivity {
        try self.live_activities.append(self.allocator, LiveActivity.init(id, activity_type));
        return &self.live_activities.items[self.live_activities.items.len - 1];
    }

    pub fn endLiveActivity(self: *WidgetCenter, id: []const u8) bool {
        for (self.live_activities.items) |*activity| {
            if (std.mem.eql(u8, activity.id, id)) {
                activity.end();
                return true;
            }
        }
        return false;
    }

    pub fn getActiveLiveActivities(self: *const WidgetCenter) usize {
        var count: usize = 0;
        for (self.live_activities.items) |activity| {
            if (activity.isActive()) count += 1;
        }
        return count;
    }

    pub fn widgetCount(self: *const WidgetCenter) usize {
        return self.configurations.items.len;
    }

    pub fn pendingUpdateCount(self: *const WidgetCenter) usize {
        return self.pending_updates.items.len;
    }
};

/// Check if widgets are available
pub fn isWidgetKitAvailable() bool {
    return true; // Stub for platform check
}

/// Check if live activities are available (iOS 16+)
pub fn isLiveActivityAvailable() bool {
    return true; // Stub for platform check
}

/// Get the current widget platform
pub fn currentPlatform() WidgetPlatform {
    return .widget_kit; // Would detect at runtime
}

// ============================================================================
// Tests
// ============================================================================

test "WidgetPlatform properties" {
    try std.testing.expectEqualStrings("WidgetKit", WidgetPlatform.widget_kit.toString());
    try std.testing.expect(WidgetPlatform.widget_kit.supportsInteractivity());
    try std.testing.expect(!WidgetPlatform.live_tiles.supportsInteractivity());
}

test "WidgetFamily properties" {
    try std.testing.expectEqualStrings("Small", WidgetFamily.small.toString());
    try std.testing.expect(WidgetFamily.accessory_circular.isAccessory());
    try std.testing.expect(!WidgetFamily.large.isAccessory());
}

test "WidgetFamily defaultSize" {
    const size = WidgetFamily.small.defaultSize();
    try std.testing.expectEqual(@as(u32, 169), size.width);
    try std.testing.expectEqual(@as(u32, 169), size.height);
}

test "RefreshPolicy toString" {
    try std.testing.expectEqualStrings("At End", RefreshPolicy.at_end.toString());
}

test "TimelineEntry init" {
    const entry = TimelineEntry.init(1000);
    try std.testing.expectEqual(@as(u64, 1000), entry.date);
    try std.testing.expectEqual(@as(f32, 1.0), entry.relevance);
}

test "TimelineEntry builder" {
    const entry = TimelineEntry.init(1000)
        .withRelevance(0.5)
        .withData("test");
    try std.testing.expectEqual(@as(f32, 0.5), entry.relevance);
    try std.testing.expectEqualStrings("test", entry.data.?);
}

test "TimelineEntry now" {
    const entry = TimelineEntry.now();
    try std.testing.expect(entry.date > 0);
}

test "Timeline operations" {
    var timeline = Timeline.init();
    defer timeline.deinit(std.testing.allocator);

    try timeline.addEntry(std.testing.allocator, TimelineEntry.init(1000));
    try timeline.addEntry(std.testing.allocator, TimelineEntry.init(2000));

    try std.testing.expectEqual(@as(usize, 2), timeline.entryCount());
}

test "Timeline policy" {
    const timeline = Timeline.init()
        .withPolicy(.never);
    try std.testing.expectEqual(RefreshPolicy.never, timeline.policy);

    const timeline2 = Timeline.init()
        .withRefreshDate(5000);
    try std.testing.expectEqual(RefreshPolicy.after_date, timeline2.policy);
    try std.testing.expectEqual(@as(?u64, 5000), timeline2.refresh_date);
}

test "ContentType toString" {
    try std.testing.expectEqualStrings("Timeline", ContentType.timeline.toString());
}

test "DisplayMode toString" {
    try std.testing.expectEqualStrings("Vibrant", DisplayMode.vibrant.toString());
}

test "BackgroundStyle toString" {
    try std.testing.expectEqualStrings("Gradient", BackgroundStyle.gradient.toString());
}

test "WidgetColor operations" {
    const color = WidgetColor.init(255, 128, 64);
    try std.testing.expectEqual(@as(u8, 255), color.r);
    try std.testing.expectEqual(@as(u8, 255), color.a);

    const with_alpha = color.withAlpha(128);
    try std.testing.expectEqual(@as(u8, 128), with_alpha.a);
}

test "WidgetColor hex conversion" {
    const color = WidgetColor.init(255, 128, 64);
    const hex = color.toHex();
    const back = WidgetColor.fromHex(hex);
    try std.testing.expectEqual(color.r, back.r);
    try std.testing.expectEqual(color.g, back.g);
    try std.testing.expectEqual(color.b, back.b);
}

test "TextStyle properties" {
    try std.testing.expectEqualStrings("Headline", TextStyle.headline.toString());
    try std.testing.expectEqual(@as(f32, 34.0), TextStyle.large_title.defaultSize());
}

test "ElementType properties" {
    try std.testing.expectEqualStrings("Text", ElementType.text.toString());
    try std.testing.expect(ElementType.button.isInteractive());
    try std.testing.expect(!ElementType.text.isInteractive());
}

test "WidgetElement text" {
    var elem = WidgetElement.text("Hello")
        .withStyle(.headline)
        .withColor(WidgetColor.black);
    defer elem.deinit(std.testing.allocator);

    try std.testing.expectEqual(ElementType.text, elem.element_type);
    try std.testing.expectEqualStrings("Hello", elem.content.?);
    try std.testing.expectEqual(TextStyle.headline, elem.style.?);
}

test "WidgetElement children" {
    var parent = WidgetElement.text("Parent");
    defer parent.deinit(std.testing.allocator);

    try parent.addChild(std.testing.allocator, WidgetElement.text("Child"));
    try std.testing.expectEqual(@as(usize, 1), parent.childCount());
}

test "WidgetConfiguration operations" {
    var config = WidgetConfiguration.init(std.testing.allocator, "myWidget", "My Widget")
        .withDescription("A test widget")
        .configurable(true);
    defer config.deinit(std.testing.allocator);

    try config.addFamily(std.testing.allocator, .small);
    try config.addFamily(std.testing.allocator, .medium);

    try std.testing.expectEqualStrings("myWidget", config.kind);
    try std.testing.expect(config.supportsFamily(.small));
    try std.testing.expect(!config.supportsFamily(.large));
}

test "WidgetIntent operations" {
    var intent = WidgetIntent.init("com.app.action", "Do Something");
    defer intent.deinit(std.testing.allocator);

    try intent.setParameter(std.testing.allocator, "key1", "value1");
    try std.testing.expect(intent.hasParameters());
    try std.testing.expectEqualStrings("value1", intent.getParameter("key1").?);
}

test "LiveActivityState properties" {
    try std.testing.expectEqualStrings("Active", LiveActivityState.active.toString());
    try std.testing.expect(LiveActivityState.active.isVisible());
    try std.testing.expect(!LiveActivityState.ended.isVisible());
}

test "LiveActivity lifecycle" {
    var activity = LiveActivity.init("activity1", "delivery");
    try std.testing.expect(activity.isActive());

    activity.end();
    try std.testing.expect(!activity.isActive());
    try std.testing.expectEqual(LiveActivityState.ended, activity.state);
}

test "UpdateRequest operations" {
    var request = UpdateRequest.init(std.testing.allocator, "myWidget");
    defer request.deinit(std.testing.allocator);

    try request.addFamily(std.testing.allocator, .small);
    try request.addFamily(std.testing.allocator, .medium);

    try std.testing.expectEqual(@as(usize, 2), request.families.items.len);
}

test "UpdateRequest allFamilies" {
    var request = UpdateRequest.init(std.testing.allocator, "myWidget");
    defer request.deinit(std.testing.allocator);

    try request.allFamilies(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 4), request.families.items.len);
}

test "WidgetCenter init and deinit" {
    var center = WidgetCenter.init(std.testing.allocator);
    defer center.deinit();

    try std.testing.expectEqual(@as(usize, 0), center.widgetCount());
}

test "WidgetCenter registerWidget" {
    var center = WidgetCenter.init(std.testing.allocator);
    defer center.deinit();

    const config = WidgetConfiguration.init(std.testing.allocator, "test", "Test Widget");
    try center.registerWidget(config);

    try std.testing.expectEqual(@as(usize, 1), center.widgetCount());
}

test "WidgetCenter liveActivities" {
    var center = WidgetCenter.init(std.testing.allocator);
    defer center.deinit();

    _ = try center.startLiveActivity("act1", "delivery");
    try std.testing.expectEqual(@as(usize, 1), center.getActiveLiveActivities());

    try std.testing.expect(center.endLiveActivity("act1"));
    try std.testing.expectEqual(@as(usize, 0), center.getActiveLiveActivities());
}

test "WidgetCenter reloadTimelines" {
    var center = WidgetCenter.init(std.testing.allocator);
    defer center.deinit();

    try center.reloadTimelines("myWidget");
    try std.testing.expectEqual(@as(usize, 1), center.pendingUpdateCount());
}

test "isWidgetKitAvailable" {
    try std.testing.expect(isWidgetKitAvailable());
}

test "isLiveActivityAvailable" {
    try std.testing.expect(isLiveActivityAvailable());
}

test "currentPlatform" {
    try std.testing.expectEqual(WidgetPlatform.widget_kit, currentPlatform());
}
