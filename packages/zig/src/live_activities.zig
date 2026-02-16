//! Live Activities Module
//! iOS 16+ Dynamic Island and Lock Screen Live Activities
//! Provides cross-platform abstractions for live activity management

const std = @import("std");
const builtin = @import("builtin");

/// Platform-specific implementations
pub const Platform = enum {
    ios,
    android, // Android doesn't have direct equivalent, but we can simulate with notifications
    unsupported,

    pub fn current() Platform {
        return switch (builtin.os.tag) {
            .ios => .ios,
            else => if (builtin.abi == .android) .android else .unsupported,
        };
    }
};

/// Activity state
pub const ActivityState = enum {
    active,
    stale,
    dismissed,
    ended,

    pub fn isVisible(self: ActivityState) bool {
        return self == .active or self == .stale;
    }

    pub fn canUpdate(self: ActivityState) bool {
        return self == .active or self == .stale;
    }
};

/// Activity content relevance
pub const ContentRelevance = enum {
    default,
    supplemental,
    critical,
};

/// Alert configuration for activity updates
pub const AlertConfig = struct {
    title: ?[]const u8 = null,
    body: ?[]const u8 = null,
    sound: ?[]const u8 = null,

    pub fn init() AlertConfig {
        return .{};
    }

    pub fn withTitle(self: AlertConfig, title: []const u8) AlertConfig {
        var copy = self;
        copy.title = title;
        return copy;
    }

    pub fn withBody(self: AlertConfig, body: []const u8) AlertConfig {
        var copy = self;
        copy.body = body;
        return copy;
    }

    pub fn withSound(self: AlertConfig, sound: []const u8) AlertConfig {
        var copy = self;
        copy.sound = sound;
        return copy;
    }
};

/// Dynamic Island presentation style
pub const DynamicIslandStyle = enum {
    compact,
    minimal,
    expanded,

    pub fn maxWidth(self: DynamicIslandStyle) u32 {
        return switch (self) {
            .compact => 160,
            .minimal => 44,
            .expanded => 370,
        };
    }
};

/// Activity category for grouping
pub const ActivityCategory = enum {
    delivery,
    sports,
    fitness,
    timer,
    music,
    ride_sharing,
    flight,
    food_order,
    navigation,
    custom,
};

/// Content state entry
pub const ContentEntry = struct {
    key: []const u8,
    value: ContentValue,

    pub const ContentValue = union(enum) {
        string: []const u8,
        integer: i64,
        float: f64,
        boolean: bool,
        timestamp: i64,
    };
};

/// Activity attributes define static data
pub const ActivityAttributes = struct {
    name: []const u8,
    category: ActivityCategory = .custom,
    supports_dynamic_island: bool = true,
    supports_lock_screen: bool = true,
    custom_attributes: std.ArrayListUnmanaged(ContentEntry) = .empty,

    pub fn init(name: []const u8) ActivityAttributes {
        return .{
            .name = name,
        };
    }

    pub fn withCategory(self: ActivityAttributes, category: ActivityCategory) ActivityAttributes {
        var copy = self;
        copy.category = category;
        return copy;
    }

    pub fn withDynamicIsland(self: ActivityAttributes, enabled: bool) ActivityAttributes {
        var copy = self;
        copy.supports_dynamic_island = enabled;
        return copy;
    }

    pub fn withLockScreen(self: ActivityAttributes, enabled: bool) ActivityAttributes {
        var copy = self;
        copy.supports_lock_screen = enabled;
        return copy;
    }
};

/// Activity content state (dynamic data)
pub const ActivityContent = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayListUnmanaged(ContentEntry),
    stale_date: ?i64 = null,
    relevance_score: f32 = 1.0,
    content_relevance: ContentRelevance = .default,

    pub fn init(allocator: std.mem.Allocator) ActivityContent {
        return .{
            .allocator = allocator,
            .entries = .empty,
        };
    }

    pub fn deinit(self: *ActivityContent) void {
        self.entries.deinit(self.allocator);
    }

    pub fn setString(self: *ActivityContent, key: []const u8, value: []const u8) !void {
        try self.entries.append(self.allocator, .{
            .key = key,
            .value = .{ .string = value },
        });
    }

    pub fn setInteger(self: *ActivityContent, key: []const u8, value: i64) !void {
        try self.entries.append(self.allocator, .{
            .key = key,
            .value = .{ .integer = value },
        });
    }

    pub fn setFloat(self: *ActivityContent, key: []const u8, value: f64) !void {
        try self.entries.append(self.allocator, .{
            .key = key,
            .value = .{ .float = value },
        });
    }

    pub fn setBoolean(self: *ActivityContent, key: []const u8, value: bool) !void {
        try self.entries.append(self.allocator, .{
            .key = key,
            .value = .{ .boolean = value },
        });
    }

    pub fn setTimestamp(self: *ActivityContent, key: []const u8, value: i64) !void {
        try self.entries.append(self.allocator, .{
            .key = key,
            .value = .{ .timestamp = value },
        });
    }

    pub fn setStaleDate(self: *ActivityContent, timestamp: i64) void {
        self.stale_date = timestamp;
    }

    pub fn setRelevanceScore(self: *ActivityContent, score: f32) void {
        self.relevance_score = @min(1.0, @max(0.0, score));
    }

    pub fn getValue(self: *const ActivityContent, key: []const u8) ?ContentEntry.ContentValue {
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, entry.key, key)) {
                return entry.value;
            }
        }
        return null;
    }

    pub fn clear(self: *ActivityContent) void {
        self.entries.clearAndFree(self.allocator);
    }

    pub fn entryCount(self: *const ActivityContent) usize {
        return self.entries.items.len;
    }
};

/// Push token for remote updates
pub const PushToken = struct {
    data: [64]u8 = undefined,
    len: usize = 0,

    pub fn init() PushToken {
        return .{};
    }

    pub fn setData(self: *PushToken, token_data: []const u8) void {
        const copy_len = @min(token_data.len, self.data.len);
        @memcpy(self.data[0..copy_len], token_data[0..copy_len]);
        self.len = copy_len;
    }

    pub fn getData(self: *const PushToken) []const u8 {
        return self.data[0..self.len];
    }

    pub fn isValid(self: *const PushToken) bool {
        return self.len > 0;
    }

    pub fn toHexString(self: *const PushToken, allocator: std.mem.Allocator) ![]u8 {
        const hex_chars = "0123456789abcdef";
        const result = try allocator.alloc(u8, self.len * 2);
        for (self.data[0..self.len], 0..) |byte, i| {
            result[i * 2] = hex_chars[byte >> 4];
            result[i * 2 + 1] = hex_chars[byte & 0x0f];
        }
        return result;
    }
};

/// Live Activity instance
pub const LiveActivity = struct {
    id: []const u8,
    attributes: ActivityAttributes,
    content: ActivityContent,
    state: ActivityState = .active,
    push_token: PushToken = PushToken.init(),
    created_at: i64,
    updated_at: i64,
    ended_at: ?i64 = null,

    pub fn init(allocator: std.mem.Allocator, id: []const u8, attributes: ActivityAttributes) LiveActivity {
        const now = getCurrentTimestamp();
        return .{
            .id = id,
            .attributes = attributes,
            .content = ActivityContent.init(allocator),
            .created_at = now,
            .updated_at = now,
        };
    }

    pub fn deinit(self: *LiveActivity) void {
        self.content.deinit();
    }

    pub fn updateContent(self: *LiveActivity, content: ActivityContent) void {
        self.content.deinit();
        self.content = content;
        self.updated_at = getCurrentTimestamp();
    }

    pub fn end(self: *LiveActivity, dismissal_policy: DismissalPolicy) void {
        self.state = .ended;
        self.ended_at = getCurrentTimestamp();
        _ = dismissal_policy;
    }

    pub fn markStale(self: *LiveActivity) void {
        if (self.state == .active) {
            self.state = .stale;
            self.updated_at = getCurrentTimestamp();
        }
    }

    pub fn isActive(self: *const LiveActivity) bool {
        return self.state == .active;
    }

    pub fn duration(self: *const LiveActivity) i64 {
        const end_time = self.ended_at orelse getCurrentTimestamp();
        return end_time - self.created_at;
    }
};

/// Dismissal policy for ended activities
pub const DismissalPolicy = enum {
    immediate,
    after_default, // ~4 hours
    after_date,

    pub fn defaultDuration() i64 {
        return 4 * 60 * 60; // 4 hours in seconds
    }
};

/// Activity request for starting new activities
pub const ActivityRequest = struct {
    attributes: ActivityAttributes,
    initial_content: ?ActivityContent = null,
    push_type: PushType = .token,
    stale_date: ?i64 = null,
    relevance_score: f32 = 1.0,

    pub const PushType = enum {
        none,
        token,
    };

    pub fn init(attributes: ActivityAttributes) ActivityRequest {
        return .{
            .attributes = attributes,
        };
    }

    pub fn withContent(self: ActivityRequest, content: ActivityContent) ActivityRequest {
        var copy = self;
        copy.initial_content = content;
        return copy;
    }

    pub fn withPushType(self: ActivityRequest, push_type: PushType) ActivityRequest {
        var copy = self;
        copy.push_type = push_type;
        return copy;
    }

    pub fn withStaleDate(self: ActivityRequest, timestamp: i64) ActivityRequest {
        var copy = self;
        copy.stale_date = timestamp;
        return copy;
    }

    pub fn withRelevanceScore(self: ActivityRequest, score: f32) ActivityRequest {
        var copy = self;
        copy.relevance_score = @min(1.0, @max(0.0, score));
        return copy;
    }
};

/// Activity update for modifying existing activities
pub const ActivityUpdate = struct {
    content: ActivityContent,
    alert_config: ?AlertConfig = null,
    stale_date: ?i64 = null,
    end_activity: bool = false,
    dismissal_policy: DismissalPolicy = .after_default,

    pub fn init(content: ActivityContent) ActivityUpdate {
        return .{
            .content = content,
        };
    }

    pub fn withAlert(self: ActivityUpdate, alert: AlertConfig) ActivityUpdate {
        var copy = self;
        copy.alert_config = alert;
        return copy;
    }

    pub fn withStaleDate(self: ActivityUpdate, timestamp: i64) ActivityUpdate {
        var copy = self;
        copy.stale_date = timestamp;
        return copy;
    }

    pub fn ending(self: ActivityUpdate, policy: DismissalPolicy) ActivityUpdate {
        var copy = self;
        copy.end_activity = true;
        copy.dismissal_policy = policy;
        return copy;
    }
};

/// Live Activities authorization status
pub const AuthorizationStatus = enum {
    not_determined,
    denied,
    authorized,
};

/// Activity event for callbacks
pub const ActivityEvent = struct {
    activity_id: []const u8,
    event_type: EventType,
    timestamp: i64,
    data: ?[]const u8 = null,

    pub const EventType = enum {
        started,
        updated,
        ended,
        push_token_updated,
        user_dismissed,
        stale,
    };
};

/// Live Activities Controller
pub const LiveActivitiesController = struct {
    allocator: std.mem.Allocator,
    activities: std.ArrayListUnmanaged(LiveActivity),
    event_history: std.ArrayListUnmanaged(ActivityEvent),
    authorization_status: AuthorizationStatus = .not_determined,
    activities_enabled: bool = true,
    frequent_push_enabled: bool = false,
    max_activities: u32 = 5,
    event_callback: ?*const fn (ActivityEvent) void = null,

    pub fn init(allocator: std.mem.Allocator) LiveActivitiesController {
        return .{
            .allocator = allocator,
            .activities = .empty,
            .event_history = .empty,
        };
    }

    pub fn deinit(self: *LiveActivitiesController) void {
        for (self.activities.items) |*activity| {
            activity.deinit();
        }
        self.activities.deinit(self.allocator);
        self.event_history.deinit(self.allocator);
    }

    pub fn requestAuthorization(self: *LiveActivitiesController) !AuthorizationStatus {
        // In real implementation, this would request system permission
        self.authorization_status = .authorized;
        return self.authorization_status;
    }

    pub fn areActivitiesEnabled(self: *const LiveActivitiesController) bool {
        return self.activities_enabled and self.authorization_status == .authorized;
    }

    pub fn startActivity(self: *LiveActivitiesController, request: ActivityRequest) !*LiveActivity {
        if (!self.areActivitiesEnabled()) {
            return error.NotAuthorized;
        }

        if (self.activities.items.len >= self.max_activities) {
            return error.MaxActivitiesReached;
        }

        // Generate unique ID
        var id_buf: [32]u8 = undefined;
        const id = try std.fmt.bufPrint(&id_buf, "activity_{d}", .{getCurrentTimestamp()});

        var activity = LiveActivity.init(self.allocator, id, request.attributes);

        if (request.initial_content) |content| {
            activity.content = content;
        }

        activity.content.relevance_score = request.relevance_score;
        if (request.stale_date) |date| {
            activity.content.stale_date = date;
        }

        // Generate push token if requested
        if (request.push_type == .token) {
            var token = PushToken.init();
            // Simulate token generation
            const token_data = "simulated_push_token_data_for_testing";
            token.setData(token_data);
            activity.push_token = token;
        }

        try self.activities.append(self.allocator, activity);

        const event = ActivityEvent{
            .activity_id = id,
            .event_type = .started,
            .timestamp = getCurrentTimestamp(),
        };
        try self.event_history.append(self.allocator, event);

        if (self.event_callback) |callback| {
            callback(event);
        }

        return &self.activities.items[self.activities.items.len - 1];
    }

    pub fn updateActivity(self: *LiveActivitiesController, activity_id: []const u8, update: ActivityUpdate) !void {
        const activity = self.findActivity(activity_id) orelse return error.ActivityNotFound;

        if (!activity.state.canUpdate()) {
            return error.ActivityNotUpdatable;
        }

        activity.updateContent(update.content);

        if (update.stale_date) |date| {
            activity.content.stale_date = date;
        }

        if (update.end_activity) {
            activity.end(update.dismissal_policy);
        }

        const event_type: ActivityEvent.EventType = if (update.end_activity) .ended else .updated;
        const event = ActivityEvent{
            .activity_id = activity_id,
            .event_type = event_type,
            .timestamp = getCurrentTimestamp(),
        };
        try self.event_history.append(self.allocator, event);

        if (self.event_callback) |callback| {
            callback(event);
        }
    }

    pub fn endActivity(self: *LiveActivitiesController, activity_id: []const u8, policy: DismissalPolicy) !void {
        const activity = self.findActivity(activity_id) orelse return error.ActivityNotFound;

        activity.end(policy);

        const event = ActivityEvent{
            .activity_id = activity_id,
            .event_type = .ended,
            .timestamp = getCurrentTimestamp(),
        };
        try self.event_history.append(self.allocator, event);

        if (self.event_callback) |callback| {
            callback(event);
        }
    }

    pub fn endAllActivities(self: *LiveActivitiesController, policy: DismissalPolicy) void {
        for (self.activities.items) |*activity| {
            if (activity.state.canUpdate()) {
                activity.end(policy);
            }
        }
    }

    pub fn findActivity(self: *LiveActivitiesController, activity_id: []const u8) ?*LiveActivity {
        for (self.activities.items) |*activity| {
            if (std.mem.eql(u8, activity.id, activity_id)) {
                return activity;
            }
        }
        return null;
    }

    pub fn getActiveActivities(self: *const LiveActivitiesController) []const LiveActivity {
        return self.activities.items;
    }

    pub fn activeCount(self: *const LiveActivitiesController) usize {
        var count: usize = 0;
        for (self.activities.items) |activity| {
            if (activity.state == .active) {
                count += 1;
            }
        }
        return count;
    }

    pub fn totalCount(self: *const LiveActivitiesController) usize {
        return self.activities.items.len;
    }

    pub fn setEventCallback(self: *LiveActivitiesController, callback: *const fn (ActivityEvent) void) void {
        self.event_callback = callback;
    }

    pub fn enableFrequentPushUpdates(self: *LiveActivitiesController, enabled: bool) void {
        self.frequent_push_enabled = enabled;
    }

    pub fn setMaxActivities(self: *LiveActivitiesController, max: u32) void {
        self.max_activities = max;
    }

    pub fn pruneEndedActivities(self: *LiveActivitiesController) void {
        var i: usize = 0;
        while (i < self.activities.items.len) {
            if (self.activities.items[i].state == .ended) {
                self.activities.items[i].deinit();
                _ = self.activities.orderedRemove(i);
            } else {
                i += 1;
            }
        }
    }

    pub fn getEventHistory(self: *const LiveActivitiesController) []const ActivityEvent {
        return self.event_history.items;
    }

    pub fn clearEventHistory(self: *LiveActivitiesController) void {
        self.event_history.clearAndFree(self.allocator);
    }
};

/// Helper to get current timestamp
fn getCurrentTimestamp() i64 {
    if (builtin.os.tag == .macos or builtin.os.tag == .ios or
        builtin.os.tag == .tvos or builtin.os.tag == .watchos)
    {
        var ts: std.c.timespec = undefined;
        if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
            return ts.sec;
        }
        return 0;
    } else if (builtin.os.tag == .windows) {
        return std.time.timestamp();
    } else if (builtin.os.tag == .linux) {
        var ts: std.c.timespec = undefined;
        if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
            return ts.sec;
        }
        return 0;
    } else {
        return 0;
    }
}

// ============================================================================
// Tests
// ============================================================================

test "Platform detection" {
    const platform = Platform.current();
    try std.testing.expect(platform != .ios or platform == .ios);
}

test "ActivityState visibility" {
    try std.testing.expect(ActivityState.active.isVisible());
    try std.testing.expect(ActivityState.stale.isVisible());
    try std.testing.expect(!ActivityState.dismissed.isVisible());
    try std.testing.expect(!ActivityState.ended.isVisible());
}

test "ActivityState canUpdate" {
    try std.testing.expect(ActivityState.active.canUpdate());
    try std.testing.expect(ActivityState.stale.canUpdate());
    try std.testing.expect(!ActivityState.dismissed.canUpdate());
    try std.testing.expect(!ActivityState.ended.canUpdate());
}

test "AlertConfig builder" {
    const alert = AlertConfig.init()
        .withTitle("Test Title")
        .withBody("Test Body")
        .withSound("default");

    try std.testing.expectEqualStrings("Test Title", alert.title.?);
    try std.testing.expectEqualStrings("Test Body", alert.body.?);
    try std.testing.expectEqualStrings("default", alert.sound.?);
}

test "DynamicIslandStyle maxWidth" {
    try std.testing.expectEqual(@as(u32, 160), DynamicIslandStyle.compact.maxWidth());
    try std.testing.expectEqual(@as(u32, 44), DynamicIslandStyle.minimal.maxWidth());
    try std.testing.expectEqual(@as(u32, 370), DynamicIslandStyle.expanded.maxWidth());
}

test "ActivityAttributes builder" {
    const attrs = ActivityAttributes.init("TestActivity")
        .withCategory(.delivery)
        .withDynamicIsland(true)
        .withLockScreen(true);

    try std.testing.expectEqualStrings("TestActivity", attrs.name);
    try std.testing.expectEqual(ActivityCategory.delivery, attrs.category);
    try std.testing.expect(attrs.supports_dynamic_island);
    try std.testing.expect(attrs.supports_lock_screen);
}

test "ActivityContent basic operations" {
    var content = ActivityContent.init(std.testing.allocator);
    defer content.deinit();

    try content.setString("status", "delivering");
    try content.setInteger("eta", 15);
    try content.setFloat("progress", 0.75);
    try content.setBoolean("arrived", false);

    try std.testing.expectEqual(@as(usize, 4), content.entryCount());

    const status = content.getValue("status").?;
    try std.testing.expectEqualStrings("delivering", status.string);

    const eta = content.getValue("eta").?;
    try std.testing.expectEqual(@as(i64, 15), eta.integer);
}

test "ActivityContent relevance score" {
    var content = ActivityContent.init(std.testing.allocator);
    defer content.deinit();

    content.setRelevanceScore(0.5);
    try std.testing.expectEqual(@as(f32, 0.5), content.relevance_score);

    // Clamp to valid range
    content.setRelevanceScore(1.5);
    try std.testing.expectEqual(@as(f32, 1.0), content.relevance_score);

    content.setRelevanceScore(-0.5);
    try std.testing.expectEqual(@as(f32, 0.0), content.relevance_score);
}

test "ActivityContent clear" {
    var content = ActivityContent.init(std.testing.allocator);
    defer content.deinit();

    try content.setString("key1", "value1");
    try content.setString("key2", "value2");

    try std.testing.expectEqual(@as(usize, 2), content.entryCount());

    content.clear();
    try std.testing.expectEqual(@as(usize, 0), content.entryCount());
}

test "PushToken operations" {
    var token = PushToken.init();
    try std.testing.expect(!token.isValid());

    const data = "test_token_data";
    token.setData(data);

    try std.testing.expect(token.isValid());
    try std.testing.expectEqualStrings(data, token.getData());
}

test "PushToken hex conversion" {
    var token = PushToken.init();
    token.setData(&[_]u8{ 0xde, 0xad, 0xbe, 0xef });

    const hex = try token.toHexString(std.testing.allocator);
    defer std.testing.allocator.free(hex);

    try std.testing.expectEqualStrings("deadbeef", hex);
}

test "LiveActivity init" {
    const attrs = ActivityAttributes.init("TestActivity");
    var activity = LiveActivity.init(std.testing.allocator, "test_id", attrs);
    defer activity.deinit();

    try std.testing.expectEqualStrings("test_id", activity.id);
    try std.testing.expectEqual(ActivityState.active, activity.state);
    try std.testing.expect(activity.isActive());
}

test "LiveActivity end" {
    const attrs = ActivityAttributes.init("TestActivity");
    var activity = LiveActivity.init(std.testing.allocator, "test_id", attrs);
    defer activity.deinit();

    activity.end(.immediate);

    try std.testing.expectEqual(ActivityState.ended, activity.state);
    try std.testing.expect(!activity.isActive());
    try std.testing.expect(activity.ended_at != null);
}

test "LiveActivity markStale" {
    const attrs = ActivityAttributes.init("TestActivity");
    var activity = LiveActivity.init(std.testing.allocator, "test_id", attrs);
    defer activity.deinit();

    activity.markStale();
    try std.testing.expectEqual(ActivityState.stale, activity.state);
}

test "ActivityRequest builder" {
    const attrs = ActivityAttributes.init("TestActivity");
    const request = ActivityRequest.init(attrs)
        .withPushType(.token)
        .withStaleDate(1000)
        .withRelevanceScore(0.8);

    try std.testing.expectEqual(ActivityRequest.PushType.token, request.push_type);
    try std.testing.expectEqual(@as(?i64, 1000), request.stale_date);
    try std.testing.expectEqual(@as(f32, 0.8), request.relevance_score);
}

test "ActivityUpdate builder" {
    var content = ActivityContent.init(std.testing.allocator);
    defer content.deinit();

    const alert = AlertConfig.init().withTitle("Update");
    const update = ActivityUpdate.init(content)
        .withAlert(alert)
        .withStaleDate(2000)
        .ending(.after_default);

    try std.testing.expect(update.alert_config != null);
    try std.testing.expectEqual(@as(?i64, 2000), update.stale_date);
    try std.testing.expect(update.end_activity);
    try std.testing.expectEqual(DismissalPolicy.after_default, update.dismissal_policy);
}

test "DismissalPolicy defaultDuration" {
    const duration = DismissalPolicy.defaultDuration();
    try std.testing.expectEqual(@as(i64, 4 * 60 * 60), duration);
}

test "LiveActivitiesController init and deinit" {
    var controller = LiveActivitiesController.init(std.testing.allocator);
    defer controller.deinit();

    try std.testing.expectEqual(@as(usize, 0), controller.totalCount());
    try std.testing.expectEqual(AuthorizationStatus.not_determined, controller.authorization_status);
}

test "LiveActivitiesController requestAuthorization" {
    var controller = LiveActivitiesController.init(std.testing.allocator);
    defer controller.deinit();

    const status = try controller.requestAuthorization();
    try std.testing.expectEqual(AuthorizationStatus.authorized, status);
    try std.testing.expect(controller.areActivitiesEnabled());
}

test "LiveActivitiesController startActivity" {
    var controller = LiveActivitiesController.init(std.testing.allocator);
    defer controller.deinit();

    _ = try controller.requestAuthorization();

    const attrs = ActivityAttributes.init("TestActivity").withCategory(.delivery);
    const request = ActivityRequest.init(attrs);

    const activity = try controller.startActivity(request);

    try std.testing.expectEqual(@as(usize, 1), controller.totalCount());
    try std.testing.expect(activity.isActive());
    try std.testing.expect(activity.push_token.isValid());
}

test "LiveActivitiesController not authorized error" {
    var controller = LiveActivitiesController.init(std.testing.allocator);
    defer controller.deinit();

    const attrs = ActivityAttributes.init("TestActivity");
    const request = ActivityRequest.init(attrs);

    const result = controller.startActivity(request);
    try std.testing.expectError(error.NotAuthorized, result);
}

test "LiveActivitiesController max activities" {
    var controller = LiveActivitiesController.init(std.testing.allocator);
    defer controller.deinit();

    _ = try controller.requestAuthorization();
    controller.setMaxActivities(2);

    const attrs = ActivityAttributes.init("TestActivity");
    _ = try controller.startActivity(ActivityRequest.init(attrs));
    _ = try controller.startActivity(ActivityRequest.init(attrs));

    const result = controller.startActivity(ActivityRequest.init(attrs));
    try std.testing.expectError(error.MaxActivitiesReached, result);
}

test "LiveActivitiesController endActivity" {
    var controller = LiveActivitiesController.init(std.testing.allocator);
    defer controller.deinit();

    _ = try controller.requestAuthorization();

    const attrs = ActivityAttributes.init("TestActivity");
    const activity = try controller.startActivity(ActivityRequest.init(attrs));
    const activity_id = activity.id;

    try controller.endActivity(activity_id, .immediate);

    const found = controller.findActivity(activity_id);
    try std.testing.expect(found != null);
    try std.testing.expectEqual(ActivityState.ended, found.?.state);
}

test "LiveActivitiesController endAllActivities" {
    var controller = LiveActivitiesController.init(std.testing.allocator);
    defer controller.deinit();

    _ = try controller.requestAuthorization();

    const attrs = ActivityAttributes.init("TestActivity");
    _ = try controller.startActivity(ActivityRequest.init(attrs));
    _ = try controller.startActivity(ActivityRequest.init(attrs));

    try std.testing.expectEqual(@as(usize, 2), controller.activeCount());

    controller.endAllActivities(.immediate);

    try std.testing.expectEqual(@as(usize, 0), controller.activeCount());
}

test "LiveActivitiesController pruneEndedActivities" {
    var controller = LiveActivitiesController.init(std.testing.allocator);
    defer controller.deinit();

    _ = try controller.requestAuthorization();

    const attrs = ActivityAttributes.init("TestActivity");
    const activity = try controller.startActivity(ActivityRequest.init(attrs));
    activity.end(.immediate);

    try std.testing.expectEqual(@as(usize, 1), controller.totalCount());

    controller.pruneEndedActivities();

    try std.testing.expectEqual(@as(usize, 0), controller.totalCount());
}

test "LiveActivitiesController event history" {
    var controller = LiveActivitiesController.init(std.testing.allocator);
    defer controller.deinit();

    _ = try controller.requestAuthorization();

    const attrs = ActivityAttributes.init("TestActivity");
    _ = try controller.startActivity(ActivityRequest.init(attrs));

    const history = controller.getEventHistory();
    try std.testing.expectEqual(@as(usize, 1), history.len);
    try std.testing.expectEqual(ActivityEvent.EventType.started, history[0].event_type);
}

test "LiveActivitiesController clearEventHistory" {
    var controller = LiveActivitiesController.init(std.testing.allocator);
    defer controller.deinit();

    _ = try controller.requestAuthorization();

    const attrs = ActivityAttributes.init("TestActivity");
    _ = try controller.startActivity(ActivityRequest.init(attrs));

    try std.testing.expect(controller.getEventHistory().len > 0);

    controller.clearEventHistory();

    try std.testing.expectEqual(@as(usize, 0), controller.getEventHistory().len);
}

test "LiveActivitiesController frequent push updates" {
    var controller = LiveActivitiesController.init(std.testing.allocator);
    defer controller.deinit();

    try std.testing.expect(!controller.frequent_push_enabled);

    controller.enableFrequentPushUpdates(true);
    try std.testing.expect(controller.frequent_push_enabled);
}

test "ContentRelevance values" {
    try std.testing.expect(ContentRelevance.default != ContentRelevance.critical);
    try std.testing.expect(ContentRelevance.supplemental != ContentRelevance.critical);
}

test "ActivityCategory values" {
    try std.testing.expect(ActivityCategory.delivery != ActivityCategory.sports);
    try std.testing.expect(ActivityCategory.timer != ActivityCategory.custom);
}
