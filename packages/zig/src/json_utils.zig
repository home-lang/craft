const std = @import("std");

/// JSON parsing utilities for bridge modules
/// Provides type-safe JSON parsing to replace manual indexOf patterns
pub const JsonError = error{
    ParseError,
    MissingField,
    InvalidType,
};

/// Parse a string value from JSON data. Scans for the closing quote while
/// respecting backslash escapes so values containing `\"` are not truncated.
/// Previously this used `indexOfPos(..., "\"")` which would stop at the first
/// `"` even when it was escaped, returning the value up to the escape.
///
/// IMPORTANT: the returned slice contains the **raw bytes between the
/// quotes** — escape sequences like `\"`, `\\`, `\n` are NOT decoded. If you
/// need a decoded string use `getStringDecoded` below, which allocates and
/// returns the fully-decoded value.
pub fn getString(data: []const u8, key: []const u8) ?[]const u8 {
    // Build pattern: "key":"
    var pattern_buf: [128]u8 = undefined;
    const pattern = std.fmt.bufPrint(&pattern_buf, "\"{s}\":\"", .{key}) catch return null;

    if (std.mem.indexOf(u8, data, pattern)) |idx| {
        const start = idx + pattern.len;
        var i = start;
        while (i < data.len) : (i += 1) {
            if (data[i] == '\\') {
                // Skip the escape and the escaped character (e.g. \" or \\).
                i += 1;
                continue;
            }
            if (data[i] == '"') return data[start..i];
        }
    }
    return null;
}

/// Decode a JSON string value into a freshly-allocated buffer. Handles the
/// standard escape set (`\"`, `\\`, `\/`, `\b`, `\f`, `\n`, `\r`, `\t`) and
/// basic `\uXXXX` Unicode escapes (surrogate pairs included). Caller owns
/// the returned slice. Returns `null` when the key is missing; returns an
/// error when allocation fails or the escape stream is malformed.
pub fn getStringDecoded(allocator: std.mem.Allocator, data: []const u8, key: []const u8) !?[]u8 {
    const raw = getString(data, key) orelse return null;

    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);

    var i: usize = 0;
    while (i < raw.len) {
        const c = raw[i];
        if (c != '\\') {
            try out.append(allocator, c);
            i += 1;
            continue;
        }
        if (i + 1 >= raw.len) return error.InvalidEscape;
        const next = raw[i + 1];
        switch (next) {
            '"', '\\', '/' => {
                try out.append(allocator, next);
                i += 2;
            },
            'b' => { try out.append(allocator, 0x08); i += 2; },
            'f' => { try out.append(allocator, 0x0C); i += 2; },
            'n' => { try out.append(allocator, '\n'); i += 2; },
            'r' => { try out.append(allocator, '\r'); i += 2; },
            't' => { try out.append(allocator, '\t'); i += 2; },
            'u' => {
                if (i + 6 > raw.len) return error.InvalidEscape;
                const cp1 = std.fmt.parseInt(u16, raw[i + 2 .. i + 6], 16) catch return error.InvalidEscape;
                i += 6;

                var codepoint: u21 = cp1;
                if (cp1 >= 0xD800 and cp1 <= 0xDBFF) {
                    // High surrogate — expect a `\uXXXX` low surrogate.
                    if (i + 6 > raw.len or raw[i] != '\\' or raw[i + 1] != 'u') return error.InvalidEscape;
                    const cp2 = std.fmt.parseInt(u16, raw[i + 2 .. i + 6], 16) catch return error.InvalidEscape;
                    if (cp2 < 0xDC00 or cp2 > 0xDFFF) return error.InvalidEscape;
                    codepoint = @intCast(0x10000 + ((@as(u32, cp1) - 0xD800) << 10) + (@as(u32, cp2) - 0xDC00));
                    i += 6;
                }

                var enc_buf: [4]u8 = undefined;
                const n = std.unicode.utf8Encode(codepoint, &enc_buf) catch return error.InvalidEscape;
                try out.appendSlice(allocator, enc_buf[0..n]);
            },
            else => return error.InvalidEscape,
        }
    }

    return try out.toOwnedSlice(allocator);
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

/// Parse a float value from JSON data. Accepts the full JSON number grammar,
/// including scientific notation (`1.5e-3`, `2E10`) — the previous version
/// only consumed digits and a dot, so any valid number with an exponent was
/// parsed as the integer part up to the `e`.
pub fn getFloat(comptime T: type, data: []const u8, key: []const u8) ?T {
    var pattern_buf: [128]u8 = undefined;
    const pattern = std.fmt.bufPrint(&pattern_buf, "\"{s}\":", .{key}) catch return null;

    if (std.mem.indexOf(u8, data, pattern)) |idx| {
        var start = idx + pattern.len;
        while (start < data.len and (data[start] == ' ' or data[start] == '\t')) : (start += 1) {}
        var end = start;
        if (end < data.len and data[end] == '-') end += 1;
        while (end < data.len and ((data[end] >= '0' and data[end] <= '9') or data[end] == '.')) : (end += 1) {}
        // Optional exponent: e|E [+|-] digits
        if (end < data.len and (data[end] == 'e' or data[end] == 'E')) {
            end += 1;
            if (end < data.len and (data[end] == '+' or data[end] == '-')) end += 1;
            while (end < data.len and data[end] >= '0' and data[end] <= '9') : (end += 1) {}
        }
        if (end > start) {
            return std.fmt.parseFloat(T, data[start..end]) catch null;
        }
    }
    return null;
}

/// Parse a boolean value from JSON data. Uses separate buffers for the two
/// patterns so we don't alias — the previous version re-used a single buffer,
/// which made the `true_pattern` slice point at stale bytes once we reformatted
/// the false pattern into the same storage.
pub fn getBool(data: []const u8, key: []const u8) ?bool {
    var true_buf: [128]u8 = undefined;
    const true_pattern = std.fmt.bufPrint(&true_buf, "\"{s}\":true", .{key}) catch return null;
    if (std.mem.indexOf(u8, data, true_pattern) != null) return true;

    var false_buf: [128]u8 = undefined;
    const false_pattern = std.fmt.bufPrint(&false_buf, "\"{s}\":false", .{key}) catch return null;
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
    var result: std.ArrayListUnmanaged(u8) = .empty;
    errdefer result.deinit(allocator);

    for (str) |ch| {
        switch (ch) {
            '"' => try result.appendSlice(allocator, "\\\""),
            '\\' => try result.appendSlice(allocator, "\\\\"),
            '\n' => try result.appendSlice(allocator, "\\n"),
            '\r' => try result.appendSlice(allocator, "\\r"),
            '\t' => try result.appendSlice(allocator, "\\t"),
            else => try result.append(allocator, ch),
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Build a JSON string with escaped values
pub fn buildJsonString(allocator: std.mem.Allocator, key: []const u8, value: []const u8) ![]u8 {
    const escaped = try escapeJson(allocator, value);
    defer allocator.free(escaped);

    return try std.fmt.allocPrint(allocator, "{{\"{s}\":\"{s}\"}}", .{ key, escaped });
}

/// Build JSON object with multiple string fields. `max_fields` is a
/// historical knob — the buffer grows dynamically, so it's purely a
/// type-level tag for callers that want distinct builder types.
pub fn JsonBuilder(comptime max_fields: usize) type {
    _ = max_fields;
    return struct {
        allocator: std.mem.Allocator,
        buffer: std.ArrayListUnmanaged(u8),
        field_count: usize,

        const Self = @This();

        /// Initialize a JSON object builder. Returns an error on allocation
        /// failure instead of silently continuing with an empty buffer (the
        /// previous behavior would produce invalid JSON like `"key":"value"}`
        /// with no opening brace).
        pub fn init(allocator: std.mem.Allocator) !Self {
            var buffer: std.ArrayListUnmanaged(u8) = .empty;
            errdefer buffer.deinit(allocator);
            try buffer.append(allocator, '{');
            return .{
                .allocator = allocator,
                .buffer = buffer,
                .field_count = 0,
            };
        }

        pub fn addString(self: *Self, key: []const u8, value: []const u8) !void {
            if (self.field_count > 0) {
                try self.buffer.append(self.allocator, ',');
            }
            try self.buffer.append(self.allocator, '"');
            try self.buffer.appendSlice(self.allocator, key);
            try self.buffer.appendSlice(self.allocator, "\":\"");

            // Escape the value
            for (value) |ch| {
                switch (ch) {
                    '"' => try self.buffer.appendSlice(self.allocator, "\\\""),
                    '\\' => try self.buffer.appendSlice(self.allocator, "\\\\"),
                    '\n' => try self.buffer.appendSlice(self.allocator, "\\n"),
                    '\r' => try self.buffer.appendSlice(self.allocator, "\\r"),
                    '\t' => try self.buffer.appendSlice(self.allocator, "\\t"),
                    else => try self.buffer.append(self.allocator, ch),
                }
            }

            try self.buffer.append(self.allocator, '"');
            self.field_count += 1;
        }

        pub fn addBool(self: *Self, key: []const u8, value: bool) !void {
            if (self.field_count > 0) {
                try self.buffer.append(self.allocator, ',');
            }
            try self.buffer.append(self.allocator, '"');
            try self.buffer.appendSlice(self.allocator, key);
            try self.buffer.appendSlice(self.allocator, "\":");
            try self.buffer.appendSlice(self.allocator, if (value) "true" else "false");
            self.field_count += 1;
        }

        pub fn addInt(self: *Self, key: []const u8, value: anytype) !void {
            if (self.field_count > 0) {
                try self.buffer.append(self.allocator, ',');
            }
            try self.buffer.append(self.allocator, '"');
            try self.buffer.appendSlice(self.allocator, key);
            try self.buffer.appendSlice(self.allocator, "\":");

            // 32 bytes fits the largest u64/i64 decimal + sign. Propagate the
            // error on overflow instead of silently truncating the field and
            // leaving a dangling `"key":` with no value in the output.
            var num_buf: [32]u8 = undefined;
            const num_str = try std.fmt.bufPrint(&num_buf, "{}", .{value});
            try self.buffer.appendSlice(self.allocator, num_str);
            self.field_count += 1;
        }

        pub fn finish(self: *Self) ![]u8 {
            try self.buffer.append(self.allocator, '}');
            return self.buffer.toOwnedSlice(self.allocator);
        }

        pub fn deinit(self: *Self) void {
            self.buffer.deinit(self.allocator);
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

test "getString respects escaped quotes" {
    const data = "{\"msg\":\"hello \\\"world\\\"\",\"next\":\"ok\"}";
    const msg = getString(data, "msg").?;
    try std.testing.expectEqualStrings("hello \\\"world\\\"", msg);
    try std.testing.expectEqualStrings("ok", getString(data, "next").?);
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
