const std = @import("std");

/// Error overlay for visual error display in development mode
/// Shows errors with stack traces and actionable suggestions

pub const ErrorSeverity = enum {
    Error,
    Warning,
    Info,
};

pub const ErrorInfo = struct {
    message: []const u8,
    severity: ErrorSeverity,
    file: ?[]const u8 = null,
    line: ?u32 = null,
    column: ?u32 = null,
    stack_trace: ?[]const u8 = null,
    suggestion: ?[]const u8 = null,
    timestamp: i64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, message: []const u8, severity: ErrorSeverity) !ErrorInfo {
        return ErrorInfo{
            .message = try allocator.dupe(u8, message),
            .severity = severity,
            .timestamp = std.time.milliTimestamp(),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ErrorInfo) void {
        self.allocator.free(self.message);
        if (self.file) |file| self.allocator.free(file);
        if (self.stack_trace) |st| self.allocator.free(st);
        if (self.suggestion) |sug| self.allocator.free(sug);
    }

    pub fn setLocation(self: *ErrorInfo, file: []const u8, line: u32, column: u32) !void {
        self.file = try self.allocator.dupe(u8, file);
        self.line = line;
        self.column = column;
    }

    pub fn setStackTrace(self: *ErrorInfo, stack_trace: []const u8) !void {
        self.stack_trace = try self.allocator.dupe(u8, stack_trace);
    }

    pub fn setSuggestion(self: *ErrorInfo, suggestion: []const u8) !void {
        self.suggestion = try self.allocator.dupe(u8, suggestion);
    }
};

pub const ErrorOverlay = struct {
    enabled: bool,
    errors: std.ArrayList(ErrorInfo),
    max_errors: usize,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, max_errors: usize) ErrorOverlay {
        return ErrorOverlay{
            .enabled = true,
            .errors = std.ArrayList(ErrorInfo).init(allocator),
            .max_errors = max_errors,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.errors.items) |*err| {
            err.deinit();
        }
        self.errors.deinit();
    }

    pub fn addError(self: *Self, error_info: ErrorInfo) !void {
        if (!self.enabled) {
            var err = error_info;
            err.deinit();
            return;
        }

        // Limit number of errors
        if (self.errors.items.len >= self.max_errors) {
            var oldest = self.errors.orderedRemove(0);
            oldest.deinit();
        }

        try self.errors.append(error_info);
        try self.render();
    }

    pub fn clear(self: *Self) void {
        for (self.errors.items) |*err| {
            err.deinit();
        }
        self.errors.clearRetainingCapacity();
    }

    pub fn enable(self: *Self) void {
        self.enabled = true;
    }

    pub fn disable(self: *Self) void {
        self.enabled = false;
    }

    /// Generate HTML overlay
    pub fn generateHTML(self: *Self) ![]u8 {
        var html = std.ArrayList(u8).init(self.allocator);
        const writer = html.writer();

        try writer.writeAll(
            \\<!DOCTYPE html>
            \\<html>
            \\<head>
            \\<style>
            \\.error-overlay {
            \\  position: fixed;
            \\  top: 0;
            \\  left: 0;
            \\  width: 100%;
            \\  height: 100%;
            \\  background: rgba(0, 0, 0, 0.9);
            \\  color: #fff;
            \\  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
            \\  z-index: 999999;
            \\  overflow: auto;
            \\  padding: 20px;
            \\  box-sizing: border-box;
            \\}
            \\.error-header {
            \\  font-size: 24px;
            \\  font-weight: bold;
            \\  margin-bottom: 20px;
            \\  color: #ff5555;
            \\}
            \\.error-item {
            \\  background: #1e1e1e;
            \\  border-left: 4px solid #ff5555;
            \\  padding: 15px;
            \\  margin-bottom: 15px;
            \\  border-radius: 4px;
            \\}
            \\.error-message {
            \\  font-size: 16px;
            \\  margin-bottom: 10px;
            \\}
            \\.error-location {
            \\  font-size: 14px;
            \\  color: #888;
            \\  margin-bottom: 10px;
            \\}
            \\.error-stack {
            \\  background: #2d2d2d;
            \\  padding: 10px;
            \\  border-radius: 4px;
            \\  font-size: 12px;
            \\  overflow-x: auto;
            \\  white-space: pre;
            \\}
            \\.error-suggestion {
            \\  background: #2a5d2a;
            \\  border-left: 4px solid #4CAF50;
            \\  padding: 10px;
            \\  margin-top: 10px;
            \\  border-radius: 4px;
            \\}
            \\.close-button {
            \\  position: fixed;
            \\  top: 20px;
            \\  right: 20px;
            \\  background: #ff5555;
            \\  color: white;
            \\  border: none;
            \\  padding: 10px 20px;
            \\  border-radius: 4px;
            \\  cursor: pointer;
            \\  font-size: 14px;
            \\}
            \\.close-button:hover {
            \\  background: #ff3333;
            \\}
            \\</style>
            \\</head>
            \\<body>
            \\<div class="error-overlay">
            \\  <button class="close-button" onclick="document.body.innerHTML=''">Close (ESC)</button>
            \\  <div class="error-header">⚠️ Build Error</div>
            \\
        );

        for (self.errors.items) |*err| {
            try writer.writeAll("  <div class=\"error-item\">\n");
            try writer.print("    <div class=\"error-message\">{s}</div>\n", .{err.message});

            if (err.file) |file| {
                try writer.print("    <div class=\"error-location\">{s}", .{file});
                if (err.line) |line| {
                    try writer.print(":{d}", .{line});
                    if (err.column) |column| {
                        try writer.print(":{d}", .{column});
                    }
                }
                try writer.writeAll("</div>\n");
            }

            if (err.stack_trace) |st| {
                try writer.print("    <div class=\"error-stack\">{s}</div>\n", .{st});
            }

            if (err.suggestion) |sug| {
                try writer.print("    <div class=\"error-suggestion\">💡 {s}</div>\n", .{sug});
            }

            try writer.writeAll("  </div>\n");
        }

        try writer.writeAll(
            \\</div>
            \\<script>
            \\  document.addEventListener('keydown', (e) => {
            \\    if (e.key === 'Escape') document.body.innerHTML = '';
            \\  });
            \\</script>
            \\</body>
            \\</html>
            \\
        );

        return try html.toOwnedSlice();
    }

    /// Render overlay to console
    pub fn render(self: *Self) !void {
        if (self.errors.items.len == 0) return;

        std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
        std.debug.print("⚠️  ERROR OVERLAY ({d} errors)\n", .{self.errors.items.len});
        std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});

        for (self.errors.items, 1..) |*err, i| {
            std.debug.print("Error {d}: {s}\n", .{ i, err.message });

            if (err.file) |file| {
                std.debug.print("  at {s}", .{file});
                if (err.line) |line| {
                    std.debug.print(":{d}", .{line});
                    if (err.column) |column| {
                        std.debug.print(":{d}", .{column});
                    }
                }
                std.debug.print("\n", .{});
            }

            if (err.stack_trace) |st| {
                std.debug.print("\nStack trace:\n{s}\n", .{st});
            }

            if (err.suggestion) |sug| {
                std.debug.print("\n💡 Suggestion: {s}\n", .{sug});
            }

            std.debug.print("\n", .{});
        }

        std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
    }
};

// Tests
test "error overlay creation" {
    const allocator = std.testing.allocator;

    var overlay = ErrorOverlay.init(allocator, 10);
    defer overlay.deinit();

    var error_info = try ErrorInfo.init(allocator, "Test error", .Error);
    try error_info.setLocation("test.zig", 10, 5);
    try error_info.setSuggestion("Check your syntax");

    try overlay.addError(error_info);

    try std.testing.expectEqual(1, overlay.errors.items.len);
}

test "error overlay HTML generation" {
    const allocator = std.testing.allocator;

    var overlay = ErrorOverlay.init(allocator, 10);
    defer overlay.deinit();

    var error_info = try ErrorInfo.init(allocator, "Syntax error", .Error);
    try overlay.addError(error_info);

    const html = try overlay.generateHTML();
    defer allocator.free(html);

    try std.testing.expect(std.mem.indexOf(u8, html, "Syntax error") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "error-overlay") != null);
}

test "error overlay max errors" {
    const allocator = std.testing.allocator;

    var overlay = ErrorOverlay.init(allocator, 2);
    defer overlay.deinit();

    var err1 = try ErrorInfo.init(allocator, "Error 1", .Error);
    try overlay.addError(err1);

    var err2 = try ErrorInfo.init(allocator, "Error 2", .Error);
    try overlay.addError(err2);

    var err3 = try ErrorInfo.init(allocator, "Error 3", .Error);
    try overlay.addError(err3);

    // Should only keep last 2 errors
    try std.testing.expectEqual(2, overlay.errors.items.len);
}
