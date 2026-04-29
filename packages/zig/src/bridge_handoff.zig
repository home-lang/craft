const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Handoff / NSUserActivity bridge.
///
/// Handoff lets users start a task on one Apple device and continue
/// it on another (their iPhone, iPad, etc), powered by NSUserActivity
/// objects. We expose:
///
///   - `startActivity(type, opts)`  — create + becomeCurrent. The
///                                    activity is broadcast over
///                                    Bluetooth/Wi-Fi to nearby
///                                    devices signed into the same
///                                    iCloud account.
///   - `updateActivity(opts)`       — mutate the in-flight activity
///                                    (title, userInfo, webpageURL).
///   - `stopActivity()`             — invalidate.
///   - `getCurrentActivity()`       — fetch the snapshot the JS layer
///                                    can use as state.
///
/// On macOS we also bridge the inbound side: when another device
/// sends an activity to ours, the AppDelegate's
/// `application:continueUserActivity:restorationHandler:` fires. We
/// install a handler at app boot that re-emits as `craft:handoff:incoming`
/// so the JS app can pick up and restore state.
pub const HandoffBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(_: *Self) void {
        if (current_activity) |a| {
            const macos = @import("macos.zig");
            _ = macos.msgSend0(a, "release");
            current_activity = null;
        }
    }

    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "startActivity")) {
            try self.startActivity(data);
        } else if (std.mem.eql(u8, action, "updateActivity")) {
            try self.updateActivity(data);
        } else if (std.mem.eql(u8, action, "stopActivity")) {
            try self.stopActivity();
        } else if (std.mem.eql(u8, action, "getCurrentActivity")) {
            try self.getCurrentActivity();
        } else {
            return BridgeError.UnknownAction;
        }
    }

    fn startActivity(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "startActivity", "{\"ok\":false,\"reason\":\"not supported\"}");
            return;
        }

        const ParseShape = struct {
            type: []const u8 = "",
            title: []const u8 = "",
            webpageURL: []const u8 = "",
            // userInfo isn't typed here — we accept any JSON object and
            // serialize it through to NSDictionary via NSJSONSerialization.
            // Caller is responsible for keeping the values plist-compatible.
            userInfo: ?std.json.Value = null,
        };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        if (parsed.value.type.len == 0) return BridgeError.MissingData;

        const macos = @import("macos.zig");

        // Tear down any in-flight activity. NSUserActivity is one-at-a-time
        // per app — invalidating before starting a new one is the
        // documented pattern.
        if (current_activity) |old| {
            _ = macos.msgSend0(old, "invalidate");
            _ = macos.msgSend0(old, "release");
            current_activity = null;
        }

        const NSUserActivity = macos.getClass("NSUserActivity");
        if (@intFromPtr(NSUserActivity) == 0) {
            bridge_error.sendResultToJS(self.allocator, "startActivity", "{\"ok\":false,\"reason\":\"NSUserActivity unavailable\"}");
            return;
        }
        const type_ns = macos.createNSString(parsed.value.type);
        const activity = macos.msgSend1(macos.msgSend0(NSUserActivity, "alloc"), "initWithActivityType:", type_ns);
        if (@intFromPtr(activity) == 0) {
            bridge_error.sendResultToJS(self.allocator, "startActivity", "{\"ok\":false}");
            return;
        }

        if (parsed.value.title.len > 0) {
            const t = macos.createNSString(parsed.value.title);
            _ = macos.msgSend1(activity, "setTitle:", t);
        }
        if (parsed.value.webpageURL.len > 0) {
            const NSURL = macos.getClass("NSURL");
            const url_ns = macos.createNSString(parsed.value.webpageURL);
            const url = macos.msgSend1(NSURL, "URLWithString:", url_ns);
            if (@intFromPtr(url) != 0) {
                _ = macos.msgSend1(activity, "setWebpageURL:", url);
            }
        }
        if (parsed.value.userInfo) |info| {
            // Convert the JSON value into an NSDictionary by going
            // through NSJSONSerialization. Round-tripping through JSON
            // is the simplest way to handle nested values without
            // hand-rolling Value→NSObject conversion.
            const dict = jsonValueToNSDictionary(self.allocator, info) orelse {
                bridge_error.sendResultToJS(self.allocator, "startActivity", "{\"ok\":false,\"reason\":\"userInfo serialization failed\"}");
                _ = macos.msgSend0(activity, "release");
                return;
            };
            _ = macos.msgSend1(activity, "setUserInfo:", dict);
        }

        // Allow handoff broadcast — this is what nearby devices pick up.
        _ = macos.msgSend1(activity, "setEligibleForHandoff:", @as(c_int, 1));
        // SearchableIndex / publicIndexing are off by default; apps that
        // want their activities surfaced in Spotlight should override.

        _ = macos.msgSend0(activity, "becomeCurrent");
        current_activity = activity;

        bridge_error.sendResultToJS(self.allocator, "startActivity", "{\"ok\":true}");
    }

    fn updateActivity(self: *Self, data: []const u8) !void {
        if (current_activity == null) {
            bridge_error.sendResultToJS(self.allocator, "updateActivity", "{\"ok\":false,\"reason\":\"no active activity\"}");
            return;
        }

        const ParseShape = struct {
            title: []const u8 = "",
            webpageURL: []const u8 = "",
            userInfo: ?std.json.Value = null,
        };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();

        const macos = @import("macos.zig");
        const activity = current_activity.?;

        if (parsed.value.title.len > 0) {
            const t = macos.createNSString(parsed.value.title);
            _ = macos.msgSend1(activity, "setTitle:", t);
        }
        if (parsed.value.webpageURL.len > 0) {
            const NSURL = macos.getClass("NSURL");
            const url_ns = macos.createNSString(parsed.value.webpageURL);
            const url = macos.msgSend1(NSURL, "URLWithString:", url_ns);
            if (@intFromPtr(url) != 0) _ = macos.msgSend1(activity, "setWebpageURL:", url);
        }
        if (parsed.value.userInfo) |info| {
            if (jsonValueToNSDictionary(self.allocator, info)) |dict| {
                _ = macos.msgSend1(activity, "setUserInfo:", dict);
            }
        }

        // Apple recommends calling -needsSave = YES so the framework
        // flushes the updated state to nearby devices on its next tick.
        _ = macos.msgSend1(activity, "setNeedsSave:", @as(c_int, 1));

        bridge_error.sendResultToJS(self.allocator, "updateActivity", "{\"ok\":true}");
    }

    fn stopActivity(self: *Self) !void {
        if (current_activity == null) {
            bridge_error.sendResultToJS(self.allocator, "stopActivity", "{\"ok\":true}");
            return;
        }
        const macos = @import("macos.zig");
        const activity = current_activity.?;
        _ = macos.msgSend0(activity, "invalidate");
        _ = macos.msgSend0(activity, "release");
        current_activity = null;
        bridge_error.sendResultToJS(self.allocator, "stopActivity", "{\"ok\":true}");
    }

    fn getCurrentActivity(self: *Self) !void {
        if (current_activity == null) {
            bridge_error.sendResultToJS(self.allocator, "getCurrentActivity", "{\"activity\":null}");
            return;
        }
        const macos = @import("macos.zig");
        const activity = current_activity.?;

        var buf: std.ArrayListUnmanaged(u8) = .empty;
        defer buf.deinit(self.allocator);
        try buf.appendSlice(self.allocator, "{\"activity\":{");
        try buf.appendSlice(self.allocator, "\"type\":\"");
        appendNSStringEscaped(self.allocator, &buf, macos.msgSend0(activity, "activityType"));
        try buf.appendSlice(self.allocator, "\",\"title\":\"");
        appendNSStringEscaped(self.allocator, &buf, macos.msgSend0(activity, "title"));
        try buf.appendSlice(self.allocator, "\",\"webpageURL\":\"");
        const url = macos.msgSend0(activity, "webpageURL");
        if (@intFromPtr(url) != 0) {
            const url_str = macos.msgSend0(url, "absoluteString");
            appendNSStringEscaped(self.allocator, &buf, url_str);
        }
        try buf.appendSlice(self.allocator, "\"}}");

        const owned = try buf.toOwnedSlice(self.allocator);
        defer self.allocator.free(owned);
        bridge_error.sendResultToJS(self.allocator, "getCurrentActivity", owned);
    }
};

// =============================================================================
// Module-level state — the one in-flight activity (NSUserActivity is
// effectively a singleton per app, despite the API allowing multiple
// instances).
// =============================================================================

var current_activity: ?@import("macos.zig").objc.id = null;

/// Convert an std.json.Value to an NSDictionary by round-tripping through
/// NSJSONSerialization. `Value` may be an object, array, number, bool,
/// or string — same set NSJSONSerialization understands. Returns null
/// on conversion failure (caller falls through to "userInfo unset").
fn jsonValueToNSDictionary(allocator: std.mem.Allocator, value: std.json.Value) ?@import("macos.zig").objc.id {
    if (builtin.os.tag != .macos) return null;
    const macos = @import("macos.zig");

    // Re-serialize the value to JSON bytes — std.json.Value carries
    // arbitrary nesting which we can't manually walk into NSDictionary
    // without a lot of code. NSJSONSerialization handles all of it.
    var json_bytes: std.ArrayListUnmanaged(u8) = .empty;
    defer json_bytes.deinit(allocator);
    serializeValue(allocator, &json_bytes, value) catch return null;
    json_bytes.append(allocator, 0) catch return null;

    const NSData = macos.getClass("NSData");
    const data = macos.msgSend2(NSData, "dataWithBytes:length:",
        @as([*]const u8, @ptrCast(json_bytes.items.ptr)),
        @as(c_ulong, json_bytes.items.len - 1));
    if (@intFromPtr(data) == 0) return null;

    const NSJSONSerialization = macos.getClass("NSJSONSerialization");
    if (@intFromPtr(NSJSONSerialization) == 0) return null;

    // -[NSJSONSerialization JSONObjectWithData:options:error:]
    const Fn = *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id, c_ulong, ?*anyopaque) callconv(.c) macos.objc.id;
    const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
    const obj = f(NSJSONSerialization, macos.sel("JSONObjectWithData:options:error:"), data, 0, null);
    return obj;
}

fn serializeValue(allocator: std.mem.Allocator, buf: *std.ArrayListUnmanaged(u8), v: std.json.Value) !void {
    switch (v) {
        .null => try buf.appendSlice(allocator, "null"),
        .bool => |b| try buf.appendSlice(allocator, if (b) "true" else "false"),
        .integer => |i| {
            var num_buf: [32]u8 = undefined;
            const s = try std.fmt.bufPrint(&num_buf, "{d}", .{i});
            try buf.appendSlice(allocator, s);
        },
        .float => |f| {
            var num_buf: [64]u8 = undefined;
            const s = try std.fmt.bufPrint(&num_buf, "{d}", .{f});
            try buf.appendSlice(allocator, s);
        },
        .number_string => |s| try buf.appendSlice(allocator, s),
        .string => |s| {
            try buf.append(allocator, '"');
            for (s) |b| {
                switch (b) {
                    '"' => try buf.appendSlice(allocator, "\\\""),
                    '\\' => try buf.appendSlice(allocator, "\\\\"),
                    '\n' => try buf.appendSlice(allocator, "\\n"),
                    '\r' => try buf.appendSlice(allocator, "\\r"),
                    '\t' => try buf.appendSlice(allocator, "\\t"),
                    else => try buf.append(allocator, b),
                }
            }
            try buf.append(allocator, '"');
        },
        .array => |arr| {
            try buf.append(allocator, '[');
            for (arr.items, 0..) |item, i| {
                if (i > 0) try buf.append(allocator, ',');
                try serializeValue(allocator, buf, item);
            }
            try buf.append(allocator, ']');
        },
        .object => |obj| {
            try buf.append(allocator, '{');
            var it = obj.iterator();
            var first = true;
            while (it.next()) |entry| {
                if (!first) try buf.append(allocator, ',');
                first = false;
                try buf.append(allocator, '"');
                try buf.appendSlice(allocator, entry.key_ptr.*);
                try buf.appendSlice(allocator, "\":");
                try serializeValue(allocator, buf, entry.value_ptr.*);
            }
            try buf.append(allocator, '}');
        },
    }
}

fn appendNSStringEscaped(allocator: std.mem.Allocator, buf: *std.ArrayListUnmanaged(u8), ns_string: @import("macos.zig").objc.id) void {
    if (@intFromPtr(ns_string) == 0) return;
    const macos = @import("macos.zig");
    const utf8 = macos.msgSend0(ns_string, "UTF8String");
    if (@intFromPtr(utf8) == 0) return;
    const slice = std.mem.span(@as([*:0]const u8, @ptrCast(utf8)));
    for (slice) |b| {
        switch (b) {
            '"' => buf.appendSlice(allocator, "\\\"") catch return,
            '\\' => buf.appendSlice(allocator, "\\\\") catch return,
            '\n' => buf.appendSlice(allocator, "\\n") catch return,
            '\r' => buf.appendSlice(allocator, "\\r") catch return,
            '\t' => buf.appendSlice(allocator, "\\t") catch return,
            else => buf.append(allocator, b) catch return,
        }
    }
}
