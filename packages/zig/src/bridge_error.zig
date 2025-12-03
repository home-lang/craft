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

    /// Format error as JSON for sending to JavaScript
    pub fn toJSON(self: ErrorContext, allocator: std.mem.Allocator) ![]u8 {
        // Use a fixed buffer for the JSON output
        var buf: [1024]u8 = undefined;
        var pos: usize = 0;

        // Build JSON manually
        const prefix = "{\"error\":true,\"code\":\"";
        @memcpy(buf[pos..][0..prefix.len], prefix);
        pos += prefix.len;

        const code = errorCodeString(self.err);
        @memcpy(buf[pos..][0..code.len], code);
        pos += code.len;

        const action_prefix = "\",\"action\":\"";
        @memcpy(buf[pos..][0..action_prefix.len], action_prefix);
        pos += action_prefix.len;

        @memcpy(buf[pos..][0..self.action.len], self.action);
        pos += self.action.len;

        const msg_prefix = "\",\"message\":\"";
        @memcpy(buf[pos..][0..msg_prefix.len], msg_prefix);
        pos += msg_prefix.len;

        // Simple message copy (no escaping for simplicity)
        for (self.message) |c| {
            if (c == '"') {
                buf[pos] = '\\';
                pos += 1;
                buf[pos] = '"';
            } else if (c == '\\') {
                buf[pos] = '\\';
                pos += 1;
                buf[pos] = '\\';
            } else {
                buf[pos] = c;
            }
            pos += 1;
        }

        const suffix = "\"}";
        @memcpy(buf[pos..][0..suffix.len], suffix);
        pos += suffix.len;

        // Copy to allocated buffer
        const result = try allocator.alloc(u8, pos);
        @memcpy(result, buf[0..pos]);
        return result;
    }
};

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
    };
}

/// Send error to JavaScript via eval
pub fn sendErrorToJS(allocator: std.mem.Allocator, action: []const u8, err: BridgeError) void {
    const ctx = ErrorContext.init(err, action, errorMessage(err));
    const json = ctx.toJSON(allocator) catch {
        std.debug.print("[BridgeError] Failed to serialize error\n", .{});
        return;
    };
    defer allocator.free(json);

    if (builtin.os.tag == .macos) {
        const macos = @import("macos.zig");

        // Build JavaScript to call error handler
        var js_buf: [1024]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buf, "if(window.__craftBridgeError)window.__craftBridgeError({s});", .{json}) catch {
            std.debug.print("[BridgeError] Failed to format JS\n", .{});
            return;
        };

        macos.tryEvalJS(js) catch |eval_err| {
            std.debug.print("[BridgeError] Failed to send error to JS: {}\n", .{eval_err});
        };
    }

    // Always log to console
    std.debug.print("[BridgeError] {s}: {s} - {s}\n", .{ action, errorCodeString(err), errorMessage(err) });
}

/// Send success result to JavaScript
pub fn sendResultToJS(allocator: std.mem.Allocator, action: []const u8, result_json: []const u8) void {
    if (builtin.os.tag == .macos) {
        const macos = @import("macos.zig");

        // Build JavaScript to call result handler
        const js_template = "if(window.__craftBridgeResult)window.__craftBridgeResult('{s}',{s});";
        const js_len = js_template.len + action.len + result_json.len;

        const js_buf = allocator.alloc(u8, js_len) catch {
            std.debug.print("[BridgeResult] Failed to allocate JS buffer\n", .{});
            return;
        };
        defer allocator.free(js_buf);

        const js = std.fmt.bufPrint(js_buf, js_template, .{ action, result_json }) catch {
            std.debug.print("[BridgeResult] Failed to format JS\n", .{});
            return;
        };

        macos.tryEvalJS(js) catch |eval_err| {
            std.debug.print("[BridgeResult] Failed to send result to JS: {}\n", .{eval_err});
        };
    }
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
