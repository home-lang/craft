//! Deep Linking Module
//!
//! Provides cross-platform deep linking and URL scheme handling:
//! - iOS: URL Schemes, Universal Links, App Clips
//! - Android: Intent Filters, App Links, Instant Apps
//! - macOS: URL Schemes, Associated Domains
//!
//! Example usage:
//! ```zig
//! var deep_link = DeepLinkManager.init(allocator);
//! defer deep_link.deinit();
//!
//! // Register URL scheme handler
//! try deep_link.registerScheme("myapp", handleMyAppScheme);
//!
//! // Handle incoming URL
//! try deep_link.handleUrl("myapp://product/123?ref=share");
//!
//! // Create a deep link URL
//! const url = try deep_link.createUrl("product/123", &[_]QueryParam{
//!     .{ .key = "ref", .value = "share" },
//! });
//! ```

const std = @import("std");
const builtin = @import("builtin");

/// Deep link errors
pub const DeepLinkError = error{
    InvalidUrl,
    SchemeNotRegistered,
    HandlerFailed,
    InvalidPath,
    MissingParameter,
    ParseError,
    NotSupported,
    OutOfMemory,
};

/// URL scheme types
pub const SchemeType = enum {
    /// Custom URL scheme (myapp://)
    custom,
    /// Universal Link / App Link (https://)
    universal,
    /// System URL scheme (tel:, mailto:, sms:)
    system,

    pub fn toString(self: SchemeType) []const u8 {
        return switch (self) {
            .custom => "Custom",
            .universal => "Universal",
            .system => "System",
        };
    }
};

/// Query parameter
pub const QueryParam = struct {
    key: []const u8,
    value: []const u8,
};

/// Parsed deep link URL
pub const ParsedDeepLink = struct {
    /// Original URL string
    original_url: []const u8,
    /// URL scheme (e.g., "myapp", "https")
    scheme: []const u8,
    /// Host (for universal links)
    host: ?[]const u8,
    /// Path components (e.g., ["product", "123"])
    path: []const u8,
    /// Path segments
    path_segments: []const []const u8,
    /// Query parameters
    query_params: std.StringHashMapUnmanaged([]const u8),
    /// Fragment (after #)
    fragment: ?[]const u8,
    /// Scheme type
    scheme_type: SchemeType,

    pub fn getParam(self: *const ParsedDeepLink, key: []const u8) ?[]const u8 {
        return self.query_params.get(key);
    }

    pub fn hasParam(self: *const ParsedDeepLink, key: []const u8) bool {
        return self.query_params.contains(key);
    }

    pub fn getPathSegment(self: *const ParsedDeepLink, index: usize) ?[]const u8 {
        if (index < self.path_segments.len) {
            return self.path_segments[index];
        }
        return null;
    }

    pub fn deinit(self: *ParsedDeepLink, allocator: std.mem.Allocator) void {
        self.query_params.deinit(allocator);
        if (self.path_segments.len > 0) {
            allocator.free(self.path_segments);
        }
    }
};

/// Deep link route
pub const Route = struct {
    /// Route pattern (e.g., "product/:id", "user/:username/posts")
    pattern: []const u8,
    /// Handler function
    handler: *const fn (*const ParsedDeepLink, ?*anyopaque) DeepLinkError!void,
    /// User context
    context: ?*anyopaque = null,
    /// Route name for debugging
    name: ?[]const u8 = null,

    /// Check if a path matches this route pattern
    pub fn matches(self: *const Route, path: []const u8) bool {
        return matchPattern(self.pattern, path);
    }

    /// Extract parameters from path based on pattern
    pub fn extractParams(self: *const Route, allocator: std.mem.Allocator, path: []const u8) !std.StringHashMapUnmanaged([]const u8) {
        var params: std.StringHashMapUnmanaged([]const u8) = .empty;

        var pattern_iter = std.mem.splitScalar(u8, self.pattern, '/');
        var path_iter = std.mem.splitScalar(u8, path, '/');

        while (pattern_iter.next()) |pattern_segment| {
            const path_segment = path_iter.next() orelse break;

            if (pattern_segment.len > 0 and pattern_segment[0] == ':') {
                // This is a parameter
                const param_name = pattern_segment[1..];
                try params.put(allocator, param_name, path_segment);
            }
        }

        return params;
    }
};

/// Deep link handler type
pub const DeepLinkHandler = *const fn (*const ParsedDeepLink, ?*anyopaque) DeepLinkError!void;

/// Deep link event
pub const DeepLinkEvent = struct {
    url: []const u8,
    timestamp: i64,
    handled: bool,
    source: Source,

    pub const Source = enum {
        /// App was opened via URL
        app_open,
        /// Link clicked while app was running
        foreground,
        /// Universal link / App link
        universal_link,
        /// System action (e.g., Spotlight, Siri)
        system,
        /// Unknown source
        unknown,

        pub fn toString(self: Source) []const u8 {
            return switch (self) {
                .app_open => "App Open",
                .foreground => "Foreground",
                .universal_link => "Universal Link",
                .system => "System",
                .unknown => "Unknown",
            };
        }
    };
};

/// Deep link manager
pub const DeepLinkManager = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    schemes: std.StringHashMapUnmanaged(SchemeHandler),
    routes: std.ArrayListUnmanaged(Route),
    history: std.ArrayListUnmanaged(DeepLinkEvent),
    max_history: usize,
    default_scheme: ?[]const u8,
    base_host: ?[]const u8,
    delegate: ?*const DeepLinkDelegate = null,

    pub const SchemeHandler = struct {
        handler: DeepLinkHandler,
        context: ?*anyopaque,
    };

    pub const DeepLinkDelegate = struct {
        context: ?*anyopaque = null,
        on_link_received: ?*const fn (?*anyopaque, *const ParsedDeepLink) void = null,
        on_link_handled: ?*const fn (?*anyopaque, *const DeepLinkEvent) void = null,
        on_link_failed: ?*const fn (?*anyopaque, []const u8, DeepLinkError) void = null,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .schemes = .empty,
            .routes = .empty,
            .history = .empty,
            .max_history = 100,
            .default_scheme = null,
            .base_host = null,
            .delegate = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.schemes.deinit(self.allocator);
        self.routes.deinit(self.allocator);
        self.history.deinit(self.allocator);
    }

    /// Set delegate for deep link events
    pub fn setDelegate(self: *Self, delegate: *const DeepLinkDelegate) void {
        self.delegate = delegate;
    }

    /// Set default URL scheme
    pub fn setDefaultScheme(self: *Self, scheme: []const u8) void {
        self.default_scheme = scheme;
    }

    /// Set base host for universal links
    pub fn setBaseHost(self: *Self, host: []const u8) void {
        self.base_host = host;
    }

    /// Register a URL scheme handler
    pub fn registerScheme(self: *Self, scheme: []const u8, handler: DeepLinkHandler) DeepLinkError!void {
        return self.registerSchemeWithContext(scheme, handler, null);
    }

    /// Register a URL scheme handler with context
    pub fn registerSchemeWithContext(self: *Self, scheme: []const u8, handler: DeepLinkHandler, context: ?*anyopaque) DeepLinkError!void {
        self.schemes.put(self.allocator, scheme, .{
            .handler = handler,
            .context = context,
        }) catch return DeepLinkError.OutOfMemory;
    }

    /// Unregister a URL scheme
    pub fn unregisterScheme(self: *Self, scheme: []const u8) void {
        _ = self.schemes.remove(scheme);
    }

    /// Check if a scheme is registered
    pub fn hasScheme(self: *const Self, scheme: []const u8) bool {
        return self.schemes.contains(scheme);
    }

    /// Register a route
    pub fn registerRoute(self: *Self, r: Route) DeepLinkError!void {
        self.routes.append(self.allocator, r) catch return DeepLinkError.OutOfMemory;
    }

    /// Register a simple route with pattern and handler
    pub fn addRoute(self: *Self, pattern: []const u8, handler: DeepLinkHandler) DeepLinkError!void {
        return self.registerRoute(.{
            .pattern = pattern,
            .handler = handler,
        });
    }

    /// Parse a URL into components
    pub fn parseUrl(self: *Self, url: []const u8) DeepLinkError!ParsedDeepLink {
        if (url.len == 0) {
            return DeepLinkError.InvalidUrl;
        }

        var result = ParsedDeepLink{
            .original_url = url,
            .scheme = "",
            .host = null,
            .path = "",
            .path_segments = &[_][]const u8{},
            .query_params = .empty,
            .fragment = null,
            .scheme_type = .custom,
        };

        var remaining = url;

        // Parse scheme
        if (std.mem.indexOf(u8, remaining, "://")) |scheme_end| {
            result.scheme = remaining[0..scheme_end];
            remaining = remaining[scheme_end + 3 ..];

            // Determine scheme type
            if (std.mem.eql(u8, result.scheme, "https") or std.mem.eql(u8, result.scheme, "http")) {
                result.scheme_type = .universal;
            } else if (std.mem.eql(u8, result.scheme, "tel") or
                std.mem.eql(u8, result.scheme, "mailto") or
                std.mem.eql(u8, result.scheme, "sms"))
            {
                result.scheme_type = .system;
            }
        } else {
            // No scheme, might be a path-only URL
            result.scheme = self.default_scheme orelse return DeepLinkError.InvalidUrl;
        }

        // Parse fragment
        if (std.mem.indexOf(u8, remaining, "#")) |fragment_start| {
            result.fragment = remaining[fragment_start + 1 ..];
            remaining = remaining[0..fragment_start];
        }

        // Parse query string
        if (std.mem.indexOf(u8, remaining, "?")) |query_start| {
            const query_string = remaining[query_start + 1 ..];
            remaining = remaining[0..query_start];

            // Parse query parameters
            var query_iter = std.mem.splitScalar(u8, query_string, '&');
            while (query_iter.next()) |param| {
                if (std.mem.indexOf(u8, param, "=")) |eq_pos| {
                    const key = param[0..eq_pos];
                    const value = param[eq_pos + 1 ..];
                    result.query_params.put(self.allocator, key, value) catch return DeepLinkError.OutOfMemory;
                }
            }
        }

        // Parse host and path
        if (result.scheme_type == .universal) {
            if (std.mem.indexOf(u8, remaining, "/")) |path_start| {
                result.host = remaining[0..path_start];
                result.path = remaining[path_start..];
            } else {
                result.host = remaining;
                result.path = "/";
            }
        } else {
            result.path = remaining;
        }

        // Split path into segments
        if (result.path.len > 0) {
            var segments: std.ArrayListUnmanaged([]const u8) = .empty;
            var path_iter = std.mem.splitScalar(u8, result.path, '/');
            while (path_iter.next()) |segment| {
                if (segment.len > 0) {
                    segments.append(self.allocator, segment) catch return DeepLinkError.OutOfMemory;
                }
            }
            result.path_segments = segments.toOwnedSlice(self.allocator) catch return DeepLinkError.OutOfMemory;
        }

        return result;
    }

    /// Handle an incoming URL
    pub fn handleUrl(self: *Self, url: []const u8) DeepLinkError!void {
        return self.handleUrlWithSource(url, .unknown);
    }

    /// Handle an incoming URL with source information
    pub fn handleUrlWithSource(self: *Self, url: []const u8, source: DeepLinkEvent.Source) DeepLinkError!void {
        var parsed = try self.parseUrl(url);
        defer parsed.deinit(self.allocator);

        // Notify delegate
        if (self.delegate) |delegate| {
            if (delegate.on_link_received) |callback| {
                callback(delegate.context, &parsed);
            }
        }

        // Try scheme handlers first
        if (self.schemes.get(parsed.scheme)) |handler| {
            handler.handler(&parsed, handler.context) catch |err| {
                if (self.delegate) |delegate| {
                    if (delegate.on_link_failed) |callback| {
                        callback(delegate.context, url, err);
                    }
                }
                return err;
            };

            try self.recordEvent(url, true, source);
            return;
        }

        // Try route matching
        for (self.routes.items) |r| {
            if (r.matches(parsed.path)) {
                r.handler(&parsed, r.context) catch |err| {
                    if (self.delegate) |delegate| {
                        if (delegate.on_link_failed) |callback| {
                            callback(delegate.context, url, err);
                        }
                    }
                    return err;
                };

                try self.recordEvent(url, true, source);
                return;
            }
        }

        // No handler found
        try self.recordEvent(url, false, source);
        return DeepLinkError.SchemeNotRegistered;
    }

    /// Create a deep link URL
    pub fn createUrl(self: *Self, path: []const u8, params: ?[]const QueryParam) DeepLinkError![]const u8 {
        const scheme = self.default_scheme orelse return DeepLinkError.InvalidUrl;
        return self.createUrlWithScheme(scheme, path, params);
    }

    /// Create a deep link URL with specific scheme
    pub fn createUrlWithScheme(self: *Self, scheme: []const u8, path: []const u8, params: ?[]const QueryParam) DeepLinkError![]const u8 {
        _ = self;

        var result: std.ArrayListUnmanaged(u8) = .empty;
        const allocator = std.heap.page_allocator; // Use page allocator for URL building
        errdefer result.deinit(allocator);

        // Add scheme
        result.appendSlice(allocator, scheme) catch return DeepLinkError.OutOfMemory;
        result.appendSlice(allocator, "://") catch return DeepLinkError.OutOfMemory;

        // Add path
        if (path.len > 0 and path[0] != '/') {
            result.append(allocator, '/') catch return DeepLinkError.OutOfMemory;
        }
        result.appendSlice(allocator, path) catch return DeepLinkError.OutOfMemory;

        // Add query parameters
        if (params) |p| {
            if (p.len > 0) {
                result.append(allocator, '?') catch return DeepLinkError.OutOfMemory;
                for (p, 0..) |param, i| {
                    if (i > 0) {
                        result.append(allocator, '&') catch return DeepLinkError.OutOfMemory;
                    }
                    result.appendSlice(allocator, param.key) catch return DeepLinkError.OutOfMemory;
                    result.append(allocator, '=') catch return DeepLinkError.OutOfMemory;
                    result.appendSlice(allocator, param.value) catch return DeepLinkError.OutOfMemory;
                }
            }
        }

        return result.toOwnedSlice(allocator) catch return DeepLinkError.OutOfMemory;
    }

    /// Create a universal link URL
    pub fn createUniversalLink(self: *Self, path: []const u8, params: ?[]const QueryParam) DeepLinkError![]const u8 {
        const host = self.base_host orelse return DeepLinkError.InvalidUrl;

        var result: std.ArrayListUnmanaged(u8) = .empty;
        const allocator = std.heap.page_allocator;
        errdefer result.deinit(allocator);

        result.appendSlice(allocator, "https://") catch return DeepLinkError.OutOfMemory;
        result.appendSlice(allocator, host) catch return DeepLinkError.OutOfMemory;

        if (path.len > 0 and path[0] != '/') {
            result.append(allocator, '/') catch return DeepLinkError.OutOfMemory;
        }
        result.appendSlice(allocator, path) catch return DeepLinkError.OutOfMemory;

        if (params) |p| {
            if (p.len > 0) {
                result.append(allocator, '?') catch return DeepLinkError.OutOfMemory;
                for (p, 0..) |param, i| {
                    if (i > 0) {
                        result.append(allocator, '&') catch return DeepLinkError.OutOfMemory;
                    }
                    result.appendSlice(allocator, param.key) catch return DeepLinkError.OutOfMemory;
                    result.append(allocator, '=') catch return DeepLinkError.OutOfMemory;
                    result.appendSlice(allocator, param.value) catch return DeepLinkError.OutOfMemory;
                }
            }
        }

        return result.toOwnedSlice(allocator) catch return DeepLinkError.OutOfMemory;
    }

    /// Get link history
    pub fn getHistory(self: *const Self) []const DeepLinkEvent {
        return self.history.items;
    }

    /// Clear history
    pub fn clearHistory(self: *Self) void {
        self.history.clearRetainingCapacity();
    }

    /// Get last handled link
    pub fn getLastLink(self: *const Self) ?DeepLinkEvent {
        if (self.history.items.len > 0) {
            return self.history.items[self.history.items.len - 1];
        }
        return null;
    }

    fn recordEvent(self: *Self, url: []const u8, handled: bool, source: DeepLinkEvent.Source) DeepLinkError!void {
        // Trim history if needed
        if (self.history.items.len >= self.max_history) {
            _ = self.history.orderedRemove(0);
        }

        const event = DeepLinkEvent{
            .url = url,
            .timestamp = getCurrentTimestamp(),
            .handled = handled,
            .source = source,
        };

        self.history.append(self.allocator, event) catch return DeepLinkError.OutOfMemory;

        // Notify delegate
        if (self.delegate) |delegate| {
            if (delegate.on_link_handled) |callback| {
                callback(delegate.context, &event);
            }
        }
    }
};

/// URL builder for creating deep links
pub const DeepLinkBuilder = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    scheme: []const u8,
    host: ?[]const u8,
    path_segments: std.ArrayListUnmanaged([]const u8),
    params: std.ArrayListUnmanaged(QueryParam),
    fragment: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator, scheme: []const u8) Self {
        return .{
            .allocator = allocator,
            .scheme = scheme,
            .host = null,
            .path_segments = .empty,
            .params = .empty,
            .fragment = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.path_segments.deinit(self.allocator);
        self.params.deinit(self.allocator);
    }

    pub fn setHost(self: *Self, host: []const u8) *Self {
        self.host = host;
        return self;
    }

    pub fn addPath(self: *Self, segment: []const u8) !*Self {
        try self.path_segments.append(self.allocator, segment);
        return self;
    }

    pub fn addParam(self: *Self, key: []const u8, value: []const u8) !*Self {
        try self.params.append(self.allocator, .{ .key = key, .value = value });
        return self;
    }

    pub fn setFragment(self: *Self, fragment: []const u8) *Self {
        self.fragment = fragment;
        return self;
    }

    pub fn build(self: *const Self) ![]const u8 {
        var result: std.ArrayListUnmanaged(u8) = .empty;
        errdefer result.deinit(self.allocator);

        // Scheme
        try result.appendSlice(self.allocator, self.scheme);
        try result.appendSlice(self.allocator, "://");

        // Host
        if (self.host) |h| {
            try result.appendSlice(self.allocator, h);
        }

        // Path
        for (self.path_segments.items) |segment| {
            try result.append(self.allocator, '/');
            try result.appendSlice(self.allocator, segment);
        }

        // Query params
        if (self.params.items.len > 0) {
            try result.append(self.allocator, '?');
            for (self.params.items, 0..) |param, i| {
                if (i > 0) try result.append(self.allocator, '&');
                try result.appendSlice(self.allocator, param.key);
                try result.append(self.allocator, '=');
                try result.appendSlice(self.allocator, param.value);
            }
        }

        // Fragment
        if (self.fragment) |f| {
            try result.append(self.allocator, '#');
            try result.appendSlice(self.allocator, f);
        }

        return result.toOwnedSlice(self.allocator);
    }
};

/// Check if a path matches a pattern (with :param placeholders)
fn matchPattern(pattern: []const u8, path: []const u8) bool {
    var pattern_iter = std.mem.splitScalar(u8, pattern, '/');
    var path_iter = std.mem.splitScalar(u8, path, '/');

    while (true) {
        const pattern_segment = pattern_iter.next();
        const path_segment = path_iter.next();

        if (pattern_segment == null and path_segment == null) {
            return true; // Both exhausted, match!
        }

        if (pattern_segment == null or path_segment == null) {
            return false; // One exhausted before other
        }

        const ps = pattern_segment.?;
        const pp = path_segment.?;

        // Skip empty segments
        if (ps.len == 0 and pp.len == 0) continue;

        // Check if pattern segment is a parameter
        if (ps.len > 0 and ps[0] == ':') {
            continue; // Parameters match anything
        }

        // Wildcard
        if (std.mem.eql(u8, ps, "*")) {
            continue;
        }

        // Exact match required
        if (!std.mem.eql(u8, ps, pp)) {
            return false;
        }
    }
}

/// Get current timestamp in milliseconds
fn getCurrentTimestamp() i64 {
    const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
    if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
        return @as(i64, @intCast(ts.sec)) * 1000 + @divTrunc(@as(i64, @intCast(ts.nsec)), 1_000_000);
    } else {
        return @as(i64, @intCast(ts.sec)) * 1000 + @divTrunc(@as(i64, @intCast(ts.nsec)), 1_000_000);
    }
}

// ============================================================================
// Tests
// ============================================================================

test "SchemeType toString" {
    try std.testing.expectEqualStrings("Custom", SchemeType.custom.toString());
    try std.testing.expectEqualStrings("Universal", SchemeType.universal.toString());
    try std.testing.expectEqualStrings("System", SchemeType.system.toString());
}

test "DeepLinkEvent Source toString" {
    try std.testing.expectEqualStrings("App Open", DeepLinkEvent.Source.app_open.toString());
    try std.testing.expectEqualStrings("Foreground", DeepLinkEvent.Source.foreground.toString());
}

test "DeepLinkManager initialization" {
    var manager = DeepLinkManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expect(manager.schemes.count() == 0);
    try std.testing.expect(manager.routes.items.len == 0);
}

test "DeepLinkManager setDefaultScheme" {
    var manager = DeepLinkManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setDefaultScheme("myapp");
    try std.testing.expectEqualStrings("myapp", manager.default_scheme.?);
}

test "DeepLinkManager setBaseHost" {
    var manager = DeepLinkManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setBaseHost("example.com");
    try std.testing.expectEqualStrings("example.com", manager.base_host.?);
}

fn testHandler(_: *const ParsedDeepLink, _: ?*anyopaque) DeepLinkError!void {}

test "DeepLinkManager registerScheme" {
    var manager = DeepLinkManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.registerScheme("myapp", testHandler);
    try std.testing.expect(manager.hasScheme("myapp"));
    try std.testing.expect(!manager.hasScheme("other"));
}

test "DeepLinkManager unregisterScheme" {
    var manager = DeepLinkManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.registerScheme("myapp", testHandler);
    try std.testing.expect(manager.hasScheme("myapp"));

    manager.unregisterScheme("myapp");
    try std.testing.expect(!manager.hasScheme("myapp"));
}

test "DeepLinkManager parseUrl custom scheme" {
    var manager = DeepLinkManager.init(std.testing.allocator);
    defer manager.deinit();

    var parsed = try manager.parseUrl("myapp://product/123?ref=share&id=456#section");
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("myapp", parsed.scheme);
    try std.testing.expectEqual(SchemeType.custom, parsed.scheme_type);
    try std.testing.expectEqualStrings("product/123", parsed.path);
    try std.testing.expectEqualStrings("share", parsed.getParam("ref").?);
    try std.testing.expectEqualStrings("456", parsed.getParam("id").?);
    try std.testing.expectEqualStrings("section", parsed.fragment.?);
}

test "DeepLinkManager parseUrl universal link" {
    var manager = DeepLinkManager.init(std.testing.allocator);
    defer manager.deinit();

    var parsed = try manager.parseUrl("https://example.com/product/123?ref=share");
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("https", parsed.scheme);
    try std.testing.expectEqual(SchemeType.universal, parsed.scheme_type);
    try std.testing.expectEqualStrings("example.com", parsed.host.?);
    try std.testing.expectEqualStrings("/product/123", parsed.path);
}

test "DeepLinkManager parseUrl system scheme" {
    var manager = DeepLinkManager.init(std.testing.allocator);
    defer manager.deinit();

    var parsed = try manager.parseUrl("tel://+1234567890");
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("tel", parsed.scheme);
    try std.testing.expectEqual(SchemeType.system, parsed.scheme_type);
}

test "DeepLinkManager parseUrl empty" {
    var manager = DeepLinkManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectError(DeepLinkError.InvalidUrl, manager.parseUrl(""));
}

test "DeepLinkManager handleUrl" {
    var manager = DeepLinkManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.registerScheme("myapp", testHandler);
    try manager.handleUrl("myapp://test");

    try std.testing.expectEqual(@as(usize, 1), manager.getHistory().len);
    try std.testing.expect(manager.getHistory()[0].handled);
}

test "DeepLinkManager handleUrl unregistered" {
    var manager = DeepLinkManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectError(DeepLinkError.SchemeNotRegistered, manager.handleUrl("unknown://test"));
}

test "DeepLinkManager getHistory" {
    var manager = DeepLinkManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.registerScheme("myapp", testHandler);
    try manager.handleUrl("myapp://test1");
    try manager.handleUrl("myapp://test2");

    try std.testing.expectEqual(@as(usize, 2), manager.getHistory().len);
}

test "DeepLinkManager clearHistory" {
    var manager = DeepLinkManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.registerScheme("myapp", testHandler);
    try manager.handleUrl("myapp://test");
    try std.testing.expect(manager.getHistory().len > 0);

    manager.clearHistory();
    try std.testing.expectEqual(@as(usize, 0), manager.getHistory().len);
}

test "DeepLinkManager getLastLink" {
    var manager = DeepLinkManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expect(manager.getLastLink() == null);

    try manager.registerScheme("myapp", testHandler);
    try manager.handleUrl("myapp://test");

    const last = manager.getLastLink();
    try std.testing.expect(last != null);
    try std.testing.expectEqualStrings("myapp://test", last.?.url);
}

test "DeepLinkManager registerRoute" {
    var manager = DeepLinkManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.addRoute("product/:id", testHandler);
    try std.testing.expectEqual(@as(usize, 1), manager.routes.items.len);
}

test "matchPattern exact" {
    try std.testing.expect(matchPattern("product/123", "product/123"));
    try std.testing.expect(!matchPattern("product/123", "product/456"));
}

test "matchPattern with params" {
    try std.testing.expect(matchPattern("product/:id", "product/123"));
    try std.testing.expect(matchPattern("user/:username/posts", "user/john/posts"));
}

test "matchPattern with wildcard" {
    try std.testing.expect(matchPattern("product/*", "product/anything"));
}

test "Route matches" {
    const r = Route{
        .pattern = "product/:id",
        .handler = testHandler,
    };

    try std.testing.expect(r.matches("product/123"));
    try std.testing.expect(r.matches("product/abc"));
    try std.testing.expect(!r.matches("category/123"));
}

test "Route extractParams" {
    const r = Route{
        .pattern = "product/:id/variant/:variant_id",
        .handler = testHandler,
    };

    var params = try r.extractParams(std.testing.allocator, "product/123/variant/456");
    defer params.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("123", params.get("id").?);
    try std.testing.expectEqualStrings("456", params.get("variant_id").?);
}

test "DeepLinkBuilder basic" {
    var builder = DeepLinkBuilder.init(std.testing.allocator, "myapp");
    defer builder.deinit();

    _ = try builder.addPath("product");
    _ = try builder.addPath("123");
    _ = try builder.addParam("ref", "share");

    const url = try builder.build();
    defer std.testing.allocator.free(url);

    try std.testing.expectEqualStrings("myapp:///product/123?ref=share", url);
}

test "DeepLinkBuilder with host" {
    var builder = DeepLinkBuilder.init(std.testing.allocator, "https");
    defer builder.deinit();

    _ = builder.setHost("example.com");
    _ = try builder.addPath("product");
    _ = try builder.addParam("id", "123");
    _ = builder.setFragment("details");

    const url = try builder.build();
    defer std.testing.allocator.free(url);

    try std.testing.expectEqualStrings("https://example.com/product?id=123#details", url);
}

test "ParsedDeepLink getParam" {
    var manager = DeepLinkManager.init(std.testing.allocator);
    defer manager.deinit();

    var parsed = try manager.parseUrl("myapp://test?key=value&other=data");
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("value", parsed.getParam("key").?);
    try std.testing.expectEqualStrings("data", parsed.getParam("other").?);
    try std.testing.expect(parsed.getParam("missing") == null);
}

test "ParsedDeepLink hasParam" {
    var manager = DeepLinkManager.init(std.testing.allocator);
    defer manager.deinit();

    var parsed = try manager.parseUrl("myapp://test?key=value");
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expect(parsed.hasParam("key"));
    try std.testing.expect(!parsed.hasParam("missing"));
}

test "ParsedDeepLink getPathSegment" {
    var manager = DeepLinkManager.init(std.testing.allocator);
    defer manager.deinit();

    var parsed = try manager.parseUrl("myapp://product/123/details");
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("product", parsed.getPathSegment(0).?);
    try std.testing.expectEqualStrings("123", parsed.getPathSegment(1).?);
    try std.testing.expectEqualStrings("details", parsed.getPathSegment(2).?);
    try std.testing.expect(parsed.getPathSegment(3) == null);
}
