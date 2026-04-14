const std = @import("std");
const builtin = @import("builtin");

/// Common error types for all bridge operations
pub const BridgeError = error{
    /// Window handle is not set or invalid
    WindowHandleNotSet,
    /// WebView handle is not set or invalid
    WebViewHandleNotSet,
    /// Tray handle is not set or invalid
    TrayHandleNotSet,
    /// The requested action is not recognized
    UnknownAction,
    /// JSON data is missing when required
    MissingData,
    /// JSON parsing failed
    InvalidJSON,
    /// Invalid parameter value
    InvalidParameter,
    /// Platform not supported for this operation
    PlatformNotSupported,
    /// Native API call failed
    NativeCallFailed,
    /// Memory allocation failed
    AllocationFailed,
    /// Operation was cancelled by user
    Cancelled,
    /// File or resource not found
    NotFound,
    /// Permission denied
    PermissionDenied,
    /// Operation timed out
    Timeout,
    /// Command contains unsafe shell metacharacters
    UnsafeCommand,
};

/// Result type for bridge operations that return data
pub fn BridgeResult(comptime T: type) type {
    return union(enum) {
        success: T,
        err: BridgeError,

        pub fn ok(value: T) @This() {
            return .{ .success = value };
        }

        pub fn fail(e: BridgeError) @This() {
            return .{ .err = e };
        }

        pub fn isOk(self: @This()) bool {
            return self == .success;
        }

        pub fn unwrap(self: @This()) !T {
            return switch (self) {
                .success => |v| v,
                .err => |e| e,
            };
        }
    };
}

/// Error context with additional information
pub const ErrorContext = struct {
    err: BridgeError,
    action: []const u8,
    message: []const u8,

    pub fn init(err: BridgeError, action: []const u8, message: []const u8) ErrorContext {
        return .{
            .err = err,
            .action = action,
            .message = message,
        };
    }

    /// Format error as JSON for sending to JavaScript.
    /// Builds into a dynamic ArrayList so long action/message strings can't
    /// overflow the previously fixed 1024-byte stack buffer. Escapes both
    /// `"` and `\` plus control bytes that would produce invalid JSON.
    pub fn toJSON(self: ErrorContext, allocator: std.mem.Allocator) ![]u8 {
        var out: std.ArrayListUnmanaged(u8) = .{};
        errdefer out.deinit(allocator);

        try out.appendSlice(allocator, "{\"error\":true,\"code\":\"");
        try out.appendSlice(allocator, errorCodeString(self.err));
        try out.appendSlice(allocator, "\",\"action\":\"");
        try appendJsonEscaped(allocator, &out, self.action);
        try out.appendSlice(allocator, "\",\"message\":\"");
        try appendJsonEscaped(allocator, &out, self.message);
        try out.appendSlice(allocator, "\"}");

        return out.toOwnedSlice(allocator);
    }
};

/// Append `s` to `out` with JSON-string escaping for `"`, `\`, and control
/// characters below 0x20. Exported at module scope so other bridge modules
/// can reuse the same escaping rules.
pub fn appendJsonEscaped(
    allocator: std.mem.Allocator,
    out: *std.ArrayListUnmanaged(u8),
    s: []const u8,
) !void {
    for (s) |c| {
        switch (c) {
            '"' => try out.appendSlice(allocator, "\\\""),
            '\\' => try out.appendSlice(allocator, "\\\\"),
            '\n' => try out.appendSlice(allocator, "\\n"),
            '\r' => try out.appendSlice(allocator, "\\r"),
            '\t' => try out.appendSlice(allocator, "\\t"),
            0x00...0x08, 0x0B, 0x0C, 0x0E...0x1F => {
                var hex_buf: [6]u8 = undefined;
                const hex = try std.fmt.bufPrint(&hex_buf, "\\u{x:0>4}", .{c});
                try out.appendSlice(allocator, hex);
            },
            else => try out.append(allocator, c),
        }
    }
}

/// Convert BridgeError to string code for JavaScript
pub fn errorCodeString(err: BridgeError) []const u8 {
    return switch (err) {
        BridgeError.WindowHandleNotSet => "WINDOW_HANDLE_NOT_SET",
        BridgeError.WebViewHandleNotSet => "WEBVIEW_HANDLE_NOT_SET",
        BridgeError.TrayHandleNotSet => "TRAY_HANDLE_NOT_SET",
        BridgeError.UnknownAction => "UNKNOWN_ACTION",
        BridgeError.MissingData => "MISSING_DATA",
        BridgeError.InvalidJSON => "INVALID_JSON",
        BridgeError.InvalidParameter => "INVALID_PARAMETER",
        BridgeError.PlatformNotSupported => "PLATFORM_NOT_SUPPORTED",
        BridgeError.NativeCallFailed => "NATIVE_CALL_FAILED",
        BridgeError.AllocationFailed => "ALLOCATION_FAILED",
        BridgeError.Cancelled => "CANCELLED",
        BridgeError.NotFound => "NOT_FOUND",
        BridgeError.PermissionDenied => "PERMISSION_DENIED",
        BridgeError.Timeout => "TIMEOUT",
        BridgeError.UnsafeCommand => "UNSAFE_COMMAND",
    };
}

/// Convert BridgeError to human-readable message
pub fn errorMessage(err: BridgeError) []const u8 {
    return switch (err) {
        BridgeError.WindowHandleNotSet => "Window handle is not initialized",
        BridgeError.WebViewHandleNotSet => "WebView handle is not initialized",
        BridgeError.TrayHandleNotSet => "Tray handle is not initialized",
        BridgeError.UnknownAction => "The requested action is not recognized",
        BridgeError.MissingData => "Required data is missing",
        BridgeError.InvalidJSON => "Failed to parse JSON data",
        BridgeError.InvalidParameter => "Invalid parameter value",
        BridgeError.PlatformNotSupported => "This operation is not supported on the current platform",
        BridgeError.NativeCallFailed => "Native API call failed",
        BridgeError.AllocationFailed => "Memory allocation failed",
        BridgeError.Cancelled => "Operation was cancelled",
        BridgeError.NotFound => "Resource not found",
        BridgeError.PermissionDenied => "Permission denied",
        BridgeError.Timeout => "Operation timed out",
        BridgeError.UnsafeCommand => "Command contains unsafe shell metacharacters",
    };
}

/// Send error to JavaScript via eval
pub fn sendErrorToJS(allocator: std.mem.Allocator, action: []const u8, err: BridgeError) void {
    const ctx = ErrorContext.init(err, action, errorMessage(err));
    const json = ctx.toJSON(allocator) catch {
        if (comptime builtin.mode == .Debug)
            std.debug.print("[BridgeError] Failed to serialize error\n", .{});
        return;
    };
    defer allocator.free(json);

    const bridge = @import("bridge.zig");

    // Allocate the JS string so long action/message strings (which the new
    // `toJSON` will faithfully include) can't overflow a fixed stack buffer.
    const js = std.fmt.allocPrint(
        allocator,
        "if(window.__craftBridgeError)window.__craftBridgeError({s});",
        .{json},
    ) catch {
        if (comptime builtin.mode == .Debug)
            std.debug.print("[BridgeError] Failed to format JS\n", .{});
        return;
    };
    defer allocator.free(js);

    bridge.evalJS(js) catch |eval_err| {
        if (comptime builtin.mode == .Debug)
            std.debug.print("[BridgeError] Failed to send error to JS: {}\n", .{eval_err});
    };

    // Always log to console
    if (comptime builtin.mode == .Debug)
        std.debug.print("[BridgeError] {s}: {s} - {s}\n", .{ action, errorCodeString(err), errorMessage(err) });
}

/// Send success result to JavaScript
pub fn sendResultToJS(allocator: std.mem.Allocator, action: []const u8, result_json: []const u8) void {
    const bridge = @import("bridge.zig");

    // Build JavaScript to call result handler
    const js_template = "if(window.__craftBridgeResult)window.__craftBridgeResult('{s}',{s});";
    const js_len = js_template.len + action.len + result_json.len;

    const js_buf = allocator.alloc(u8, js_len) catch {
        if (comptime builtin.mode == .Debug)
            std.debug.print("[BridgeResult] Failed to allocate JS buffer\n", .{});
        return;
    };
    defer allocator.free(js_buf);

    const js = std.fmt.bufPrint(js_buf, js_template, .{ action, result_json }) catch {
        if (comptime builtin.mode == .Debug)
            std.debug.print("[BridgeResult] Failed to format JS\n", .{});
        return;
    };

    bridge.evalJS(js) catch |err| {
        std.log.warn("failed to send error to JS: {}", .{err});
    };
}

/// Helper to validate required handle
pub fn requireHandle(handle: ?*anyopaque, err: BridgeError) BridgeError!*anyopaque {
    return handle orelse err;
}

/// Helper to validate required data
pub fn requireData(data: ?[]const u8) BridgeError![]const u8 {
    return data orelse BridgeError.MissingData;
}

// Unit tests
test "errorCodeString returns correct codes" {
    const testing = std.testing;
    try testing.expectEqualStrings("WINDOW_HANDLE_NOT_SET", errorCodeString(BridgeError.WindowHandleNotSet));
    try testing.expectEqualStrings("UNKNOWN_ACTION", errorCodeString(BridgeError.UnknownAction));
    try testing.expectEqualStrings("MISSING_DATA", errorCodeString(BridgeError.MissingData));
}

test "ErrorContext.toJSON produces valid JSON" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const ctx = ErrorContext.init(BridgeError.WindowHandleNotSet, "setSize", "Window handle is not initialized");
    const json = try ctx.toJSON(allocator);
    defer allocator.free(json);

    // Verify JSON structure
    try testing.expect(std.mem.indexOf(u8, json, "\"error\":true") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"code\":\"WINDOW_HANDLE_NOT_SET\"") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"action\":\"setSize\"") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"message\":\"Window handle is not initialized\"") != null);
}

test "requireHandle returns error when null" {
    const testing = std.testing;

    const result = requireHandle(null, BridgeError.WindowHandleNotSet);
    try testing.expectError(BridgeError.WindowHandleNotSet, result);
}

test "requireData returns error when null" {
    const testing = std.testing;

    const result = requireData(null);
    try testing.expectError(BridgeError.MissingData, result);
}

test "requireData returns data when present" {
    const testing = std.testing;

    const data = "test data";
    const result = try requireData(data);
    try testing.expectEqualStrings("test data", result);
}

test "ErrorContext.toJSON escapes quotes, backslashes, and control bytes" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const ctx = ErrorContext.init(
        BridgeError.InvalidJSON,
        "parse",
        "broken: \"quote\" \\slash\n\tnewline\x01ctrl",
    );
    const json = try ctx.toJSON(allocator);
    defer allocator.free(json);

    // Quotes, backslashes, \n, \t escaped. Control bytes go via \uXXXX.
    try testing.expect(std.mem.indexOf(u8, json, "\\\"quote\\\"") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\\\\slash") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\\n\\tnewline") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\\u0001ctrl") != null);
}

test "ErrorContext.toJSON handles long messages without overflow" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Build a 4096-byte message; old code had a 1024-byte stack buffer that
    // would have overflowed. New code grows dynamically.
    var long_msg_buf: [4096]u8 = undefined;
    @memset(&long_msg_buf, 'a');

    const ctx = ErrorContext.init(BridgeError.InvalidJSON, "parse", &long_msg_buf);
    const json = try ctx.toJSON(allocator);
    defer allocator.free(json);

    try testing.expect(json.len > 4096);
}
