const std = @import("std");

/// JSON parsing utilities for bridge modules
/// Provides type-safe JSON parsing to replace manual indexOf patterns

pub const JsonError = error{
    ParseError,
    MissingField,
    InvalidType,
};

/// Parse a string value from JSON data
pub fn getString(data: []const u8, key: []const u8) ?[]const u8 {
    // Build pattern: "key":"
    var pattern_buf: [128]u8 = undefined;
    const pattern = std.fmt.bufPrint(&pattern_buf, "\"{s}\":\"", .{key}) catch return null;

    if (std.mem.indexOf(u8, data, pattern)) |idx| {
        const start = idx + pattern.len;
        if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
            return data[start..end];
        }
    }
    return null;
}

/// Parse an integer value from JSON data
pub fn getInt(comptime T: type, data: []const u8, key: []const u8) ?T {
    // Build pattern: "key":
    var pattern_buf: [128]u8 = undefined;
    const pattern = std.fmt.bufPrint(&pattern_buf, "\"{s}\":", .{key}) catch return null;

    if (std.mem.indexOf(u8, data, pattern)) |idx| {
        var start = idx + pattern.len;
        // Skip whitespace
        while (start < data.len and (data[start] == ' ' or data[start] == '\t')) : (start += 1) {}
        var end = start;
        // Find end of number (handle negative)
        if (end < data.len and data[end] == '-') end += 1;
        while (end < data.len and data[end] >= '0' and data[end] <= '9') : (end += 1) {}
        if (end > start) {
            return std.fmt.parseInt(T, data[start..end], 10) catch null;
        }
    }
    return null;
}

/// Parse a float value from JSON data
pub fn getFloat(comptime T: type, data: []const u8, key: []const u8) ?T {
    var pattern_buf: [128]u8 = undefined;
    const pattern = std.fmt.bufPrint(&pattern_buf, "\"{s}\":", .{key}) catch return null;

    if (std.mem.indexOf(u8, data, pattern)) |idx| {
        var start = idx + pattern.len;
        while (start < data.len and (data[start] == ' ' or data[start] == '\t')) : (start += 1) {}
        var end = start;
        if (end < data.len and data[end] == '-') end += 1;
        while (end < data.len and ((data[end] >= '0' and data[end] <= '9') or data[end] == '.')) : (end += 1) {}
        if (end > start) {
            return std.fmt.parseFloat(T, data[start..end]) catch null;
        }
    }
    return null;
}

/// Parse a boolean value from JSON data
pub fn getBool(data: []const u8, key: []const u8) ?bool {
    var pattern_buf: [128]u8 = undefined;
    const true_pattern = std.fmt.bufPrint(&pattern_buf, "\"{s}\":true", .{key}) catch return null;
    if (std.mem.indexOf(u8, data, true_pattern) != null) return true;

    const false_pattern = std.fmt.bufPrint(&pattern_buf, "\"{s}\":false", .{key}) catch return null;
    if (std.mem.indexOf(u8, data, false_pattern) != null) return false;

    return null;
}

/// Check if a JSON object contains a specific key
pub fn hasKey(data: []const u8, key: []const u8) bool {
    var pattern_buf: [128]u8 = undefined;
    const pattern = std.fmt.bufPrint(&pattern_buf, "\"{s}\":", .{key}) catch return false;
    return std.mem.indexOf(u8, data, pattern) != null;
}

/// Escape a string for safe JSON embedding
pub fn escapeJson(allocator: std.mem.Allocator, str: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    for (str) |ch| {
        switch (ch) {
            '"' => try result.appendSlice("\\\""),
            '\\' => try result.appendSlice("\\\\"),
            '\n' => try result.appendSlice("\\n"),
            '\r' => try result.appendSlice("\\r"),
            '\t' => try result.appendSlice("\\t"),
            else => try result.append(ch),
        }
    }

    return result.toOwnedSlice();
}

/// Build a JSON string with escaped values
pub fn buildJsonString(allocator: std.mem.Allocator, key: []const u8, value: []const u8) ![]u8 {
    const escaped = try escapeJson(allocator, value);
    defer allocator.free(escaped);

    return try std.fmt.allocPrint(allocator, "{{\"{s}\":\"{s}\"}}", .{ key, escaped });
}

/// Build JSON object with multiple string fields
pub fn JsonBuilder(comptime max_fields: usize) type {
    return struct {
        allocator: std.mem.Allocator,
        buffer: std.ArrayList(u8),
        field_count: usize,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            var buffer = std.ArrayList(u8).init(allocator);
            buffer.append('{') catch {};
            return .{
                .allocator = allocator,
                .buffer = buffer,
                .field_count = 0,
            };
        }

        pub fn addString(self: *Self, key: []const u8, value: []const u8) !void {
            if (self.field_count > 0) {
                try self.buffer.append(',');
            }
            try self.buffer.append('"');
            try self.buffer.appendSlice(key);
            try self.buffer.appendSlice("\":\"");

            // Escape the value
            for (value) |ch| {
                switch (ch) {
                    '"' => try self.buffer.appendSlice("\\\""),
                    '\\' => try self.buffer.appendSlice("\\\\"),
                    '\n' => try self.buffer.appendSlice("\\n"),
                    '\r' => try self.buffer.appendSlice("\\r"),
                    '\t' => try self.buffer.appendSlice("\\t"),
                    else => try self.buffer.append(ch),
                }
            }

            try self.buffer.append('"');
            self.field_count += 1;
            _ = max_fields;
        }

        pub fn addBool(self: *Self, key: []const u8, value: bool) !void {
            if (self.field_count > 0) {
                try self.buffer.append(',');
            }
            try self.buffer.append('"');
            try self.buffer.appendSlice(key);
            try self.buffer.appendSlice("\":");
            try self.buffer.appendSlice(if (value) "true" else "false");
            self.field_count += 1;
        }

        pub fn addInt(self: *Self, key: []const u8, value: anytype) !void {
            if (self.field_count > 0) {
                try self.buffer.append(',');
            }
            try self.buffer.append('"');
            try self.buffer.appendSlice(key);
            try self.buffer.appendSlice("\":");

            var num_buf: [32]u8 = undefined;
            const num_str = std.fmt.bufPrint(&num_buf, "{}", .{value}) catch return;
            try self.buffer.appendSlice(num_str);
            self.field_count += 1;
        }

        pub fn finish(self: *Self) ![]u8 {
            try self.buffer.append('}');
            return self.buffer.toOwnedSlice();
        }

        pub fn deinit(self: *Self) void {
            self.buffer.deinit();
        }
    };
}

// Tests
test "getString" {
    const data = "{\"title\":\"Hello\",\"body\":\"World\"}";
    try std.testing.expectEqualStrings("Hello", getString(data, "title").?);
    try std.testing.expectEqualStrings("World", getString(data, "body").?);
    try std.testing.expect(getString(data, "missing") == null);
}

test "getInt" {
    const data = "{\"count\":42,\"negative\":-10}";
    try std.testing.expectEqual(@as(i32, 42), getInt(i32, data, "count").?);
    try std.testing.expectEqual(@as(i32, -10), getInt(i32, data, "negative").?);
    try std.testing.expect(getInt(i32, data, "missing") == null);
}

test "getBool" {
    const data = "{\"enabled\":true,\"disabled\":false}";
    try std.testing.expect(getBool(data, "enabled").? == true);
    try std.testing.expect(getBool(data, "disabled").? == false);
    try std.testing.expect(getBool(data, "missing") == null);
}

test "escapeJson" {
    const allocator = std.testing.allocator;
    const escaped = try escapeJson(allocator, "Hello \"World\"\nNew Line");
    defer allocator.free(escaped);
    try std.testing.expectEqualStrings("Hello \\\"World\\\"\\nNew Line", escaped);
}
