//! Analytics module for Craft
//! Provides cross-platform event tracking, user analytics, and crash reporting.
//! Abstracts platform-specific implementations and supports multiple backends.

const std = @import("std");

/// Get current timestamp in milliseconds (Zig 0.16 compatible)
fn getTimestampMs() i64 {
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
        return @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000);
    }
    return 0;
}

/// Event type categories
pub const EventCategory = enum {
    /// User interaction (taps, clicks, gestures)
    interaction,
    /// Screen/page views
    screen_view,
    /// User actions (login, signup, purchase)
    user_action,
    /// App lifecycle events
    lifecycle,
    /// Error/crash events
    error_event,
    /// Performance metrics
    performance,
    /// Custom/other events
    custom,

    /// Get category name
    pub fn name(self: EventCategory) []const u8 {
        return switch (self) {
            .interaction => "interaction",
            .screen_view => "screen_view",
            .user_action => "user_action",
            .lifecycle => "lifecycle",
            .error_event => "error",
            .performance => "performance",
            .custom => "custom",
        };
    }
};

/// Event parameter value types
pub const ParamValue = union(enum) {
    string: []const u8,
    int: i64,
    float: f64,
    bool: bool,

    /// Get as string representation
    pub fn toString(self: ParamValue, buf: []u8) ![]const u8 {
        return switch (self) {
            .string => |s| s,
            .int => |i| try std.fmt.bufPrint(buf, "{d}", .{i}),
            .float => |f| try std.fmt.bufPrint(buf, "{d:.2}", .{f}),
            .bool => |b| if (b) "true" else "false",
        };
    }
};

/// Analytics event
pub const Event = struct {
    /// Event name
    event_name: []const u8,
    /// Event category
    category: EventCategory = .custom,
    /// Parameters
    params: std.StringHashMapUnmanaged(ParamValue) = .{},
    /// Timestamp (milliseconds)
    timestamp: i64,
    /// Session ID
    session_id: ?[]const u8 = null,
    /// User ID
    user_id: ?[]const u8 = null,

    /// Create new event
    pub fn init(allocator: std.mem.Allocator, event_name: []const u8) Event {
        _ = allocator;
        return .{
            .event_name = event_name,
            .timestamp = getTimestampMs(),
        };
    }

    /// Set parameter
    pub fn setParam(self: *Event, allocator: std.mem.Allocator, key: []const u8, value: ParamValue) !void {
        try self.params.put(allocator, key, value);
    }

    /// Get parameter
    pub fn getParam(self: *const Event, key: []const u8) ?ParamValue {
        return self.params.get(key);
    }

    /// Deinitialize
    pub fn deinit(self: *Event, allocator: std.mem.Allocator) void {
        self.params.deinit(allocator);
    }
};

/// User properties
pub const UserProperties = struct {
    /// User ID
    user_id: ?[]const u8 = null,
    /// Anonymous ID
    anonymous_id: ?[]const u8 = null,
    /// Email
    email: ?[]const u8 = null,
    /// Name
    name_prop: ?[]const u8 = null,
    /// Age
    age: ?u8 = null,
    /// Gender
    gender: ?[]const u8 = null,
    /// Custom properties
    custom: std.StringHashMapUnmanaged(ParamValue) = .{},
    /// Creation date
    created_at: i64 = 0,
    /// Last seen
    last_seen: i64 = 0,

    /// Initialize with user ID
    pub fn init(user_id: ?[]const u8) UserProperties {
        return .{
            .user_id = user_id,
            .created_at = getTimestampMs(),
            .last_seen = getTimestampMs(),
        };
    }

    /// Set custom property
    pub fn setProperty(self: *UserProperties, allocator: std.mem.Allocator, key: []const u8, value: ParamValue) !void {
        try self.custom.put(allocator, key, value);
    }

    /// Update last seen
    pub fn updateLastSeen(self: *UserProperties) void {
        self.last_seen = getTimestampMs();
    }

    /// Deinitialize
    pub fn deinit(self: *UserProperties, allocator: std.mem.Allocator) void {
        self.custom.deinit(allocator);
    }
};

/// Session information
pub const Session = struct {
    /// Session ID
    id: []const u8,
    /// Start time (milliseconds)
    start_time: i64,
    /// End time (milliseconds, 0 if active)
    end_time: i64 = 0,
    /// Event count
    event_count: u32 = 0,
    /// Screen view count
    screen_count: u32 = 0,
    /// Is first session
    is_first_session: bool = false,
    /// Referrer
    referrer: ?[]const u8 = null,
    /// Campaign
    campaign: ?[]const u8 = null,

    /// Create new session
    pub fn init(id: []const u8) Session {
        return .{
            .id = id,
            .start_time = getTimestampMs(),
        };
    }

    /// Get duration (milliseconds)
    pub fn duration(self: Session) i64 {
        const end = if (self.end_time > 0) self.end_time else getTimestampMs();
        return end - self.start_time;
    }

    /// Get duration in seconds
    pub fn durationSeconds(self: Session) f64 {
        return @as(f64, @floatFromInt(self.duration())) / 1000.0;
    }

    /// Check if session is active
    pub fn isActive(self: Session) bool {
        return self.end_time == 0;
    }

    /// End session
    pub fn endSession(self: *Session) void {
        if (self.end_time == 0) {
            self.end_time = getTimestampMs();
        }
    }
};

/// Screen/page view
pub const ScreenView = struct {
    /// Screen name
    screen_name: []const u8,
    /// Screen class (optional)
    screen_class: ?[]const u8 = null,
    /// Previous screen
    previous_screen: ?[]const u8 = null,
    /// Timestamp
    timestamp: i64,
    /// Duration on screen (milliseconds)
    duration: i64 = 0,

    /// Create screen view
    pub fn init(screen_name: []const u8) ScreenView {
        return .{
            .screen_name = screen_name,
            .timestamp = getTimestampMs(),
        };
    }
};

/// Timing metric
pub const TimingMetric = struct {
    /// Metric name
    metric_name: []const u8,
    /// Category
    category: []const u8,
    /// Duration (milliseconds)
    duration_ms: i64,
    /// Label (optional)
    label: ?[]const u8 = null,
    /// Timestamp
    timestamp: i64,

    /// Create timing metric
    pub fn init(metric_name: []const u8, category: []const u8, duration_ms: i64) TimingMetric {
        return .{
            .metric_name = metric_name,
            .category = category,
            .duration_ms = duration_ms,
            .timestamp = getTimestampMs(),
        };
    }

    /// Get duration in seconds
    pub fn durationSeconds(self: TimingMetric) f64 {
        return @as(f64, @floatFromInt(self.duration_ms)) / 1000.0;
    }
};

/// Error/exception tracking
pub const ErrorInfo = struct {
    /// Error message
    message: []const u8,
    /// Error type/name
    error_type: ?[]const u8 = null,
    /// Stack trace
    stack_trace: ?[]const u8 = null,
    /// Is fatal
    is_fatal: bool = false,
    /// Additional context
    context: ?[]const u8 = null,
    /// Timestamp
    timestamp: i64,

    /// Create error info
    pub fn init(message: []const u8) ErrorInfo {
        return .{
            .message = message,
            .timestamp = getTimestampMs(),
        };
    }

    /// Create fatal error
    pub fn fatal(message: []const u8) ErrorInfo {
        var info = ErrorInfo.init(message);
        info.is_fatal = true;
        return info;
    }
};

/// Analytics configuration
pub const AnalyticsConfig = struct {
    /// Enable analytics
    enabled: bool = true,
    /// Enable automatic screen tracking
    auto_screen_tracking: bool = true,
    /// Enable crash reporting
    crash_reporting: bool = true,
    /// Enable performance monitoring
    performance_monitoring: bool = true,
    /// Session timeout (milliseconds)
    session_timeout: i64 = 30 * 60 * 1000, // 30 minutes
    /// Minimum session duration (milliseconds)
    min_session_duration: i64 = 10 * 1000, // 10 seconds
    /// Flush interval (milliseconds)
    flush_interval: i64 = 30 * 1000, // 30 seconds
    /// Max events in queue
    max_queue_size: usize = 1000,
    /// Debug mode
    debug: bool = false,
    /// Anonymize IP
    anonymize_ip: bool = false,
    /// Respect do not track
    respect_dnt: bool = true,

    /// Default configuration
    pub fn default() AnalyticsConfig {
        return .{};
    }

    /// Debug configuration
    pub fn forDebug() AnalyticsConfig {
        return .{
            .debug = true,
            .flush_interval = 5 * 1000, // 5 seconds
        };
    }

    /// Privacy-focused configuration
    pub fn privacyFocused() AnalyticsConfig {
        return .{
            .anonymize_ip = true,
            .respect_dnt = true,
            .crash_reporting = false,
        };
    }
};

/// Analytics tracker
pub const AnalyticsTracker = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    // Configuration
    config: AnalyticsConfig,

    // State
    is_initialized: bool = false,
    is_enabled: bool = true,

    // User
    user_properties: UserProperties,

    // Session
    current_session: ?Session = null,
    session_count: u32 = 0,

    // Screen tracking
    current_screen: ?[]const u8 = null,
    screen_start_time: i64 = 0,

    // Event queue
    event_queue: std.ArrayListUnmanaged(Event) = .{},

    // Metrics
    total_events: u64 = 0,
    total_screens: u64 = 0,
    total_errors: u64 = 0,

    /// Initialize tracker
    pub fn init(allocator: std.mem.Allocator, config: AnalyticsConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .user_properties = UserProperties.init(null),
        };
    }

    /// Deinitialize
    pub fn deinit(self: *Self) void {
        // Clear event queue
        for (self.event_queue.items) |*event| {
            event.deinit(self.allocator);
        }
        self.event_queue.deinit(self.allocator);
        self.user_properties.deinit(self.allocator);
    }

    /// Start tracking
    pub fn start(self: *Self) void {
        if (self.is_initialized) return;
        self.is_initialized = true;
        self.startNewSession();
    }

    /// Stop tracking
    pub fn stop(self: *Self) void {
        if (self.current_session) |*session| {
            session.endSession();
        }
        self.is_initialized = false;
    }

    /// Enable/disable tracking
    pub fn setEnabled(self: *Self, enabled: bool) void {
        self.is_enabled = enabled;
        self.config.enabled = enabled;
    }

    /// Check if tracking is enabled
    pub fn isTrackingEnabled(self: *const Self) bool {
        return self.is_enabled and self.config.enabled;
    }

    /// Set user ID
    pub fn setUserId(self: *Self, user_id: []const u8) void {
        self.user_properties.user_id = user_id;
        self.user_properties.updateLastSeen();
    }

    /// Clear user ID (logout)
    pub fn clearUserId(self: *Self) void {
        self.user_properties.user_id = null;
    }

    /// Set user property
    pub fn setUserProperty(self: *Self, key: []const u8, value: ParamValue) !void {
        try self.user_properties.setProperty(self.allocator, key, value);
    }

    /// Track event
    pub fn trackEvent(self: *Self, event_name: []const u8, category: EventCategory) !void {
        if (!self.isTrackingEnabled()) return;

        var event = Event.init(self.allocator, event_name);
        event.category = category;
        event.user_id = self.user_properties.user_id;
        if (self.current_session) |session| {
            event.session_id = session.id;
        }

        try self.queueEvent(event);
        self.total_events += 1;

        if (self.current_session) |*session| {
            session.event_count += 1;
        }
    }

    /// Track event with parameters
    pub fn trackEventWithParams(self: *Self, event_name: []const u8, category: EventCategory, params: anytype) !void {
        if (!self.isTrackingEnabled()) return;

        var event = Event.init(self.allocator, event_name);
        event.category = category;
        event.user_id = self.user_properties.user_id;

        // Add parameters
        inline for (std.meta.fields(@TypeOf(params))) |field| {
            const value = @field(params, field.name);
            const param_value: ParamValue = switch (@TypeOf(value)) {
                []const u8 => .{ .string = value },
                i64, i32, i16, i8, u64, u32, u16, u8 => .{ .int = @intCast(value) },
                f64, f32 => .{ .float = @floatCast(value) },
                bool => .{ .bool = value },
                else => continue,
            };
            try event.setParam(self.allocator, field.name, param_value);
        }

        try self.queueEvent(event);
        self.total_events += 1;
    }

    /// Track screen view
    pub fn trackScreenView(self: *Self, screen_name: []const u8) !void {
        if (!self.isTrackingEnabled()) return;
        if (!self.config.auto_screen_tracking) return;

        // Track duration on previous screen
        if (self.current_screen != null and self.screen_start_time > 0) {
            const duration = getTimestampMs() - self.screen_start_time;
            _ = duration; // Would be used for screen duration tracking
        }

        self.current_screen = screen_name;
        self.screen_start_time = getTimestampMs();
        self.total_screens += 1;

        if (self.current_session) |*session| {
            session.screen_count += 1;
        }

        try self.trackEvent(screen_name, .screen_view);
    }

    /// Track timing
    pub fn trackTiming(self: *Self, metric_name: []const u8, category: []const u8, duration_ms: i64) !void {
        if (!self.isTrackingEnabled()) return;
        if (!self.config.performance_monitoring) return;

        const timing = TimingMetric.init(metric_name, category, duration_ms);
        _ = timing;

        try self.trackEvent(metric_name, .performance);
    }

    /// Track error
    pub fn trackError(self: *Self, error_info: ErrorInfo) !void {
        if (!self.isTrackingEnabled()) return;

        self.total_errors += 1;

        var event = Event.init(self.allocator, "error");
        event.category = .error_event;
        try event.setParam(self.allocator, "message", .{ .string = error_info.message });
        try event.setParam(self.allocator, "is_fatal", .{ .bool = error_info.is_fatal });

        try self.queueEvent(event);
    }

    /// Track purchase
    pub fn trackPurchase(self: *Self, product_id: []const u8, amount: f64, currency: []const u8) !void {
        if (!self.isTrackingEnabled()) return;

        var event = Event.init(self.allocator, "purchase");
        event.category = .user_action;
        try event.setParam(self.allocator, "product_id", .{ .string = product_id });
        try event.setParam(self.allocator, "amount", .{ .float = amount });
        try event.setParam(self.allocator, "currency", .{ .string = currency });

        try self.queueEvent(event);
        self.total_events += 1;
    }

    /// Start new session
    pub fn startNewSession(self: *Self) void {
        self.session_count += 1;

        // Generate session ID
        var id_buf: [16]u8 = undefined;
        const id = std.fmt.bufPrint(&id_buf, "session_{d}", .{self.session_count}) catch "session_0";

        var session = Session.init(id);
        session.is_first_session = self.session_count == 1;

        self.current_session = session;
    }

    /// Get current session
    pub fn getCurrentSession(self: *const Self) ?Session {
        return self.current_session;
    }

    /// Queue event
    fn queueEvent(self: *Self, event: Event) !void {
        if (self.event_queue.items.len >= self.config.max_queue_size) {
            // Remove oldest event
            if (self.event_queue.items.len > 0) {
                var old_event = self.event_queue.orderedRemove(0);
                old_event.deinit(self.allocator);
            }
        }
        try self.event_queue.append(self.allocator, event);
    }

    /// Flush events (send to backend)
    pub fn flush(self: *Self) !void {
        if (self.event_queue.items.len == 0) return;

        // In real implementation, this would send to analytics backend
        // For now, just clear the queue
        for (self.event_queue.items) |*event| {
            event.deinit(self.allocator);
        }
        self.event_queue.clearRetainingCapacity();
    }

    /// Get queued event count
    pub fn queuedEventCount(self: *const Self) usize {
        return self.event_queue.items.len;
    }

    /// Get total event count
    pub fn totalEventCount(self: *const Self) u64 {
        return self.total_events;
    }

    /// Get total screen count
    pub fn totalScreenCount(self: *const Self) u64 {
        return self.total_screens;
    }

    /// Get total error count
    pub fn totalErrorCount(self: *const Self) u64 {
        return self.total_errors;
    }

    /// Reset analytics data
    pub fn reset(self: *Self) void {
        for (self.event_queue.items) |*event| {
            event.deinit(self.allocator);
        }
        self.event_queue.clearRetainingCapacity();
        self.total_events = 0;
        self.total_screens = 0;
        self.total_errors = 0;
        self.session_count = 0;
        self.current_session = null;
    }
};

/// Predefined event names
pub const StandardEvents = struct {
    // App events
    pub const app_open = "app_open";
    pub const app_close = "app_close";
    pub const app_update = "app_update";
    pub const first_open = "first_open";

    // User events
    pub const sign_up = "sign_up";
    pub const login = "login";
    pub const logout = "logout";

    // Commerce events
    pub const view_item = "view_item";
    pub const add_to_cart = "add_to_cart";
    pub const remove_from_cart = "remove_from_cart";
    pub const begin_checkout = "begin_checkout";
    pub const purchase = "purchase";
    pub const refund = "refund";

    // Engagement events
    pub const share = "share";
    pub const search = "search";
    pub const select_content = "select_content";

    // Error events
    pub const error_event = "error";
    pub const crash = "crash";
};

/// Predefined parameter names
pub const StandardParams = struct {
    pub const item_id = "item_id";
    pub const item_name = "item_name";
    pub const item_category = "item_category";
    pub const price = "price";
    pub const quantity = "quantity";
    pub const currency = "currency";
    pub const value = "value";
    pub const method = "method";
    pub const content_type = "content_type";
    pub const search_term = "search_term";
    pub const success = "success";
};

/// Quick analytics utilities
pub const QuickAnalytics = struct {
    var tracker: ?AnalyticsTracker = null;

    /// Get shared tracker
    pub fn shared(allocator: std.mem.Allocator) *AnalyticsTracker {
        if (tracker == null) {
            tracker = AnalyticsTracker.init(allocator, AnalyticsConfig.default());
            tracker.?.start();
        }
        return &tracker.?;
    }

    /// Track simple event
    pub fn track(allocator: std.mem.Allocator, event_name: []const u8) !void {
        try shared(allocator).trackEvent(event_name, .custom);
    }

    /// Track screen
    pub fn screen(allocator: std.mem.Allocator, screen_name: []const u8) !void {
        try shared(allocator).trackScreenView(screen_name);
    }

    /// Track error
    pub fn trackError(allocator: std.mem.Allocator, message: []const u8) !void {
        try shared(allocator).trackError(ErrorInfo.init(message));
    }
};

// ============================================================================
// Tests
// ============================================================================

test "EventCategory name" {
    try std.testing.expectEqualStrings("interaction", EventCategory.interaction.name());
    try std.testing.expectEqualStrings("screen_view", EventCategory.screen_view.name());
    try std.testing.expectEqualStrings("error", EventCategory.error_event.name());
}

test "Event creation" {
    var event = Event.init(std.testing.allocator, "test_event");
    defer event.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("test_event", event.event_name);
    try std.testing.expect(event.timestamp > 0);
}

test "Event setParam and getParam" {
    var event = Event.init(std.testing.allocator, "test_event");
    defer event.deinit(std.testing.allocator);

    try event.setParam(std.testing.allocator, "key", .{ .string = "value" });
    try event.setParam(std.testing.allocator, "count", .{ .int = 42 });

    const string_param = event.getParam("key");
    try std.testing.expect(string_param != null);
    try std.testing.expectEqualStrings("value", string_param.?.string);

    const int_param = event.getParam("count");
    try std.testing.expect(int_param != null);
    try std.testing.expectEqual(@as(i64, 42), int_param.?.int);
}

test "UserProperties init" {
    var props = UserProperties.init("user_123");
    defer props.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("user_123", props.user_id.?);
    try std.testing.expect(props.created_at > 0);
}

test "UserProperties setProperty" {
    var props = UserProperties.init(null);
    defer props.deinit(std.testing.allocator);

    try props.setProperty(std.testing.allocator, "level", .{ .int = 5 });

    const level = props.custom.get("level");
    try std.testing.expect(level != null);
    try std.testing.expectEqual(@as(i64, 5), level.?.int);
}

test "Session init" {
    const session = Session.init("session_1");
    try std.testing.expectEqualStrings("session_1", session.id);
    try std.testing.expect(session.start_time > 0);
    try std.testing.expect(session.isActive());
}

test "Session duration" {
    var session = Session.init("session_1");
    try std.testing.expect(session.duration() >= 0);
    try std.testing.expect(session.durationSeconds() >= 0);
}

test "Session endSession" {
    var session = Session.init("session_1");
    try std.testing.expect(session.isActive());

    session.endSession();
    try std.testing.expect(!session.isActive());
    try std.testing.expect(session.end_time > 0);
}

test "ScreenView init" {
    const screen_view = ScreenView.init("HomeScreen");
    try std.testing.expectEqualStrings("HomeScreen", screen_view.screen_name);
    try std.testing.expect(screen_view.timestamp > 0);
}

test "TimingMetric init" {
    const timing = TimingMetric.init("api_call", "network", 250);
    try std.testing.expectEqualStrings("api_call", timing.metric_name);
    try std.testing.expectEqualStrings("network", timing.category);
    try std.testing.expectEqual(@as(i64, 250), timing.duration_ms);
    try std.testing.expectApproxEqAbs(@as(f64, 0.25), timing.durationSeconds(), 0.001);
}

test "ErrorInfo init" {
    const error_info = ErrorInfo.init("Something went wrong");
    try std.testing.expectEqualStrings("Something went wrong", error_info.message);
    try std.testing.expect(!error_info.is_fatal);
}

test "ErrorInfo fatal" {
    const error_info = ErrorInfo.fatal("Critical error");
    try std.testing.expect(error_info.is_fatal);
}

test "AnalyticsConfig default" {
    const config = AnalyticsConfig.default();
    try std.testing.expect(config.enabled);
    try std.testing.expect(config.auto_screen_tracking);
    try std.testing.expect(config.crash_reporting);
}

test "AnalyticsConfig forDebug" {
    const config = AnalyticsConfig.forDebug();
    try std.testing.expect(config.debug);
    try std.testing.expect(config.flush_interval < AnalyticsConfig.default().flush_interval);
}

test "AnalyticsConfig privacyFocused" {
    const config = AnalyticsConfig.privacyFocused();
    try std.testing.expect(config.anonymize_ip);
    try std.testing.expect(config.respect_dnt);
    try std.testing.expect(!config.crash_reporting);
}

test "AnalyticsTracker initialization" {
    var tracker = AnalyticsTracker.init(std.testing.allocator, AnalyticsConfig.default());
    defer tracker.deinit();

    try std.testing.expect(!tracker.is_initialized);
    try std.testing.expect(tracker.isTrackingEnabled());
}

test "AnalyticsTracker start" {
    var tracker = AnalyticsTracker.init(std.testing.allocator, AnalyticsConfig.default());
    defer tracker.deinit();

    tracker.start();
    try std.testing.expect(tracker.is_initialized);
    try std.testing.expect(tracker.current_session != null);
}

test "AnalyticsTracker setEnabled" {
    var tracker = AnalyticsTracker.init(std.testing.allocator, AnalyticsConfig.default());
    defer tracker.deinit();

    tracker.setEnabled(false);
    try std.testing.expect(!tracker.isTrackingEnabled());

    tracker.setEnabled(true);
    try std.testing.expect(tracker.isTrackingEnabled());
}

test "AnalyticsTracker setUserId" {
    var tracker = AnalyticsTracker.init(std.testing.allocator, AnalyticsConfig.default());
    defer tracker.deinit();

    tracker.setUserId("user_456");
    try std.testing.expectEqualStrings("user_456", tracker.user_properties.user_id.?);

    tracker.clearUserId();
    try std.testing.expect(tracker.user_properties.user_id == null);
}

test "AnalyticsTracker trackEvent" {
    var tracker = AnalyticsTracker.init(std.testing.allocator, AnalyticsConfig.default());
    defer tracker.deinit();

    tracker.start();
    try tracker.trackEvent("button_click", .interaction);

    try std.testing.expectEqual(@as(u64, 1), tracker.totalEventCount());
    try std.testing.expectEqual(@as(usize, 1), tracker.queuedEventCount());
}

test "AnalyticsTracker trackScreenView" {
    var tracker = AnalyticsTracker.init(std.testing.allocator, AnalyticsConfig.default());
    defer tracker.deinit();

    tracker.start();
    try tracker.trackScreenView("HomeScreen");

    try std.testing.expectEqual(@as(u64, 1), tracker.totalScreenCount());
    try std.testing.expectEqualStrings("HomeScreen", tracker.current_screen.?);
}

test "AnalyticsTracker trackError" {
    var tracker = AnalyticsTracker.init(std.testing.allocator, AnalyticsConfig.default());
    defer tracker.deinit();

    tracker.start();
    try tracker.trackError(ErrorInfo.init("Test error"));

    try std.testing.expectEqual(@as(u64, 1), tracker.totalErrorCount());
}

test "AnalyticsTracker trackPurchase" {
    var tracker = AnalyticsTracker.init(std.testing.allocator, AnalyticsConfig.default());
    defer tracker.deinit();

    tracker.start();
    try tracker.trackPurchase("product_123", 9.99, "USD");

    try std.testing.expectEqual(@as(u64, 1), tracker.totalEventCount());
}

test "AnalyticsTracker flush" {
    var tracker = AnalyticsTracker.init(std.testing.allocator, AnalyticsConfig.default());
    defer tracker.deinit();

    tracker.start();
    try tracker.trackEvent("test", .custom);
    try std.testing.expectEqual(@as(usize, 1), tracker.queuedEventCount());

    try tracker.flush();
    try std.testing.expectEqual(@as(usize, 0), tracker.queuedEventCount());
}

test "AnalyticsTracker reset" {
    var tracker = AnalyticsTracker.init(std.testing.allocator, AnalyticsConfig.default());
    defer tracker.deinit();

    tracker.start();
    try tracker.trackEvent("test", .custom);
    try tracker.trackScreenView("TestScreen");

    tracker.reset();
    try std.testing.expectEqual(@as(u64, 0), tracker.totalEventCount());
    try std.testing.expectEqual(@as(u64, 0), tracker.totalScreenCount());
    try std.testing.expectEqual(@as(usize, 0), tracker.queuedEventCount());
}

test "StandardEvents constants" {
    try std.testing.expectEqualStrings("app_open", StandardEvents.app_open);
    try std.testing.expectEqualStrings("login", StandardEvents.login);
    try std.testing.expectEqualStrings("purchase", StandardEvents.purchase);
}

test "StandardParams constants" {
    try std.testing.expectEqualStrings("item_id", StandardParams.item_id);
    try std.testing.expectEqualStrings("price", StandardParams.price);
    try std.testing.expectEqualStrings("currency", StandardParams.currency);
}
