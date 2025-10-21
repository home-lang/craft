const std = @import("std");
const error_context = @import("../src/error_context.zig");
const ErrorContext = error_context.ErrorContext;
const ErrorCode = error_context.ErrorCode;
const ErrorSeverity = error_context.ErrorSeverity;
const RecoveryAction = error_context.RecoveryAction;
const RecoveryStrategy = error_context.RecoveryStrategy;

test "error context lifecycle" {
    const allocator = std.testing.allocator;
    const ctx = try ErrorContext.init(allocator, .file_not_found, "Test file missing");
    defer ctx.deinit();

    try std.testing.expectEqualStrings("Test file missing", ctx.message);
}

test "error severity levels" {
    try std.testing.expectEqualStrings("INFO", ErrorSeverity.info.toString());
    try std.testing.expectEqualStrings("WARNING", ErrorSeverity.warning.toString());
    try std.testing.expectEqualStrings("ERROR", ErrorSeverity.err.toString());
    try std.testing.expectEqualStrings("FATAL", ErrorSeverity.fatal.toString());
}

test "error formatting" {
    const allocator = std.testing.allocator;
    const ctx = try ErrorContext.init(allocator, .invalid_input, "Bad email");
    defer ctx.deinit();

    _ = try ctx.addMetadata("field", "email");
    _ = try ctx.addStackFrame("validate", "validator.zig", 50);

    const formatted = try ctx.format(allocator);
    defer allocator.free(formatted);

    try std.testing.expect(formatted.len > 0);
}
