const std = @import("std");
const testing = std.testing;
const errors = @import("../src/errors.zig");

test "CraftError - window errors exist" {
    const err1: errors.CraftError = error.WindowCreationFailed;
    const err2: errors.CraftError = error.WindowNotFound;
    const err3: errors.CraftError = error.InvalidWindowHandle;

    try testing.expectError(error.WindowCreationFailed, err1);
    try testing.expectError(error.WindowNotFound, err2);
    try testing.expectError(error.InvalidWindowHandle, err3);
}

test "CraftError - webview errors exist" {
    const err1: errors.CraftError = error.WebViewCreationFailed;
    const err2: errors.CraftError = error.WebViewLoadFailed;
    const err3: errors.CraftError = error.InvalidURL;

    try testing.expectError(error.WebViewCreationFailed, err1);
    try testing.expectError(error.WebViewLoadFailed, err2);
    try testing.expectError(error.InvalidURL, err3);
}

test "CraftError - file errors exist" {
    const err1: errors.CraftError = error.FileNotFound;
    const err2: errors.CraftError = error.FileReadError;
    const err3: errors.CraftError = error.FileWriteError;
    const err4: errors.CraftError = error.InvalidPath;

    try testing.expectError(error.FileNotFound, err1);
    try testing.expectError(error.FileReadError, err2);
    try testing.expectError(error.FileWriteError, err3);
    try testing.expectError(error.InvalidPath, err4);
}

test "CraftError - plugin errors exist" {
    const err1: errors.CraftError = error.PluginLoadFailed;
    const err2: errors.CraftError = error.PluginNotFound;
    const err3: errors.CraftError = error.PluginFunctionNotFound;
    const err4: errors.CraftError = error.InvalidPluginPath;

    try testing.expectError(error.PluginLoadFailed, err1);
    try testing.expectError(error.PluginNotFound, err2);
    try testing.expectError(error.PluginFunctionNotFound, err3);
    try testing.expectError(error.InvalidPluginPath, err4);
}

test "CraftError - ipc errors exist" {
    const err1: errors.CraftError = error.IpcChannelNotFound;
    const err2: errors.CraftError = error.IpcMessageSendFailed;
    const err3: errors.CraftError = error.InvalidMessage;

    try testing.expectError(error.IpcChannelNotFound, err1);
    try testing.expectError(error.IpcMessageSendFailed, err2);
    try testing.expectError(error.InvalidMessage, err3);
}

test "CraftError - permission errors exist" {
    const err1: errors.CraftError = error.PermissionDenied;
    const err2: errors.CraftError = error.SandboxViolation;

    try testing.expectError(error.PermissionDenied, err1);
    try testing.expectError(error.SandboxViolation, err2);
}

test "CraftError - configuration errors exist" {
    const err1: errors.CraftError = error.ConfigLoadFailed;
    const err2: errors.CraftError = error.ConfigParseError;
    const err3: errors.CraftError = error.InvalidConfiguration;

    try testing.expectError(error.ConfigLoadFailed, err1);
    try testing.expectError(error.ConfigParseError, err2);
    try testing.expectError(error.InvalidConfiguration, err3);
}

test "CraftError - platform errors exist" {
    const err1: errors.CraftError = error.UnsupportedPlatform;
    const err2: errors.CraftError = error.PlatformApiError;

    try testing.expectError(error.UnsupportedPlatform, err1);
    try testing.expectError(error.PlatformApiError, err2);
}

test "CraftError - network errors exist" {
    const err1: errors.CraftError = error.WebSocketConnectionFailed;
    const err2: errors.CraftError = error.NetworkError;

    try testing.expectError(error.WebSocketConnectionFailed, err1);
    try testing.expectError(error.NetworkError, err2);
}

test "CraftError - general errors exist" {
    const err1: errors.CraftError = error.NotImplemented;
    const err2: errors.CraftError = error.InvalidArgument;
    const err3: errors.CraftError = error.OutOfMemory;
    const err4: errors.CraftError = error.Timeout;

    try testing.expectError(error.NotImplemented, err1);
    try testing.expectError(error.InvalidArgument, err2);
    try testing.expectError(error.OutOfMemory, err3);
    try testing.expectError(error.Timeout, err4);
}

test "ErrorContext - create" {
    const ctx = errors.ErrorContext.create("Test error", "test_file.zig", 42);

    try testing.expectEqualStrings("Test error", ctx.message);
    try testing.expectEqualStrings("test_file.zig", ctx.file);
    try testing.expectEqual(@as(u32, 42), ctx.line);
}

test "ErrorContext - print does not crash" {
    const ctx = errors.ErrorContext.create("Test error message", "test.zig", 100);
    ctx.print();

    try testing.expect(true);
}

test "errorContext - helper function" {
    const ctx = errors.errorContext("Helper test");

    try testing.expectEqualStrings("Helper test", ctx.message);
    try testing.expect(ctx.file.len > 0);
    try testing.expect(ctx.line > 0);
}

test "CraftError - can be used in functions" {
    const testFunc = struct {
        fn fail() errors.CraftError!void {
            return error.NotImplemented;
        }
    }.fail;

    try testing.expectError(error.NotImplemented, testFunc());
}

test "CraftError - can be caught and handled" {
    const testFunc = struct {
        fn mayFail(should_fail: bool) errors.CraftError!i32 {
            if (should_fail) {
                return error.InvalidArgument;
            }
            return 42;
        }
    }.mayFail;

    const result = testFunc(false) catch |err| {
        try testing.expect(false); // Should not reach here
        return err;
    };

    try testing.expectEqual(@as(i32, 42), result);

    const error_result = testFunc(true);
    try testing.expectError(error.InvalidArgument, error_result);
}

test "ErrorContext - multiple contexts" {
    const ctx1 = errors.ErrorContext.create("First error", "file1.zig", 10);
    const ctx2 = errors.ErrorContext.create("Second error", "file2.zig", 20);
    const ctx3 = errors.ErrorContext.create("Third error", "file3.zig", 30);

    try testing.expectEqualStrings("First error", ctx1.message);
    try testing.expectEqualStrings("Second error", ctx2.message);
    try testing.expectEqualStrings("Third error", ctx3.message);

    try testing.expectEqual(@as(u32, 10), ctx1.line);
    try testing.expectEqual(@as(u32, 20), ctx2.line);
    try testing.expectEqual(@as(u32, 30), ctx3.line);
}

// Edge cases and thorough tests

test "ErrorContext - empty message" {
    const ctx = errors.ErrorContext.create("", "test.zig", 1);
    try testing.expectEqualStrings("", ctx.message);
}

test "ErrorContext - very long message" {
    const long_msg = "This is a very long error message that describes in great detail what went wrong and includes many technical terms and context information that might be useful for debugging the issue";
    const ctx = errors.ErrorContext.create(long_msg, "test.zig", 1);
    try testing.expectEqualStrings(long_msg, ctx.message);
}

test "ErrorContext - special characters in message" {
    const ctx = errors.ErrorContext.create("Error: \n\t\"Failed\" @ line $%^&*()", "test.zig", 1);
    try testing.expect(ctx.message.len > 0);
}

test "ErrorContext - line number edge cases" {
    const ctx_zero = errors.ErrorContext.create("Error", "test.zig", 0);
    const ctx_large = errors.ErrorContext.create("Error", "test.zig", 999999);

    try testing.expectEqual(@as(u32, 0), ctx_zero.line);
    try testing.expectEqual(@as(u32, 999999), ctx_large.line);
}

test "ErrorContext - long file path" {
    const long_path = "src/very/deeply/nested/directory/structure/that/goes/on/for/a/while/file.zig";
    const ctx = errors.ErrorContext.create("Error", long_path, 1);
    try testing.expectEqualStrings(long_path, ctx.file);
}

test "CraftError - error union with success" {
    const testFunc = struct {
        fn maySucceed(should_succeed: bool) errors.CraftError!i32 {
            if (!should_succeed) {
                return error.InvalidArgument;
            }
            return 42;
        }
    }.maySucceed;

    const success_result = try testFunc(true);
    try testing.expectEqual(@as(i32, 42), success_result);

    const error_result = testFunc(false);
    try testing.expectError(error.InvalidArgument, error_result);
}

test "CraftError - chaining errors" {
    const func1 = struct {
        fn inner() errors.CraftError!void {
            return error.FileNotFound;
        }

        fn outer() errors.CraftError!void {
            return try inner();
        }
    };

    try testing.expectError(error.FileNotFound, func1.outer());
}

test "CraftError - error sets combination" {
    const func = struct {
        fn combined() (errors.CraftError || error{CustomError})!void {
            return error.CustomError;
        }
    }.combined;

    try testing.expectError(error.CustomError, func());
}

test "CraftError - all window errors" {
    const window_errors = [_]errors.CraftError{
        error.WindowCreationFailed,
        error.WindowNotFound,
        error.InvalidWindowHandle,
    };

    for (window_errors) |err| {
        try testing.expectError(err, err);
    }
}

test "CraftError - all webview errors" {
    const webview_errors = [_]errors.CraftError{
        error.WebViewCreationFailed,
        error.WebViewLoadFailed,
        error.InvalidURL,
    };

    for (webview_errors) |err| {
        try testing.expectError(err, err);
    }
}

test "CraftError - all file errors" {
    const file_errors = [_]errors.CraftError{
        error.FileNotFound,
        error.FileReadError,
        error.FileWriteError,
        error.InvalidPath,
    };

    for (file_errors) |err| {
        try testing.expectError(err, err);
    }
}

test "CraftError - all plugin errors" {
    const plugin_errors = [_]errors.CraftError{
        error.PluginLoadFailed,
        error.PluginNotFound,
        error.PluginFunctionNotFound,
        error.InvalidPluginPath,
    };

    for (plugin_errors) |err| {
        try testing.expectError(err, err);
    }
}

test "CraftError - all ipc errors" {
    const ipc_errors = [_]errors.CraftError{
        error.IpcChannelNotFound,
        error.IpcMessageSendFailed,
        error.InvalidMessage,
    };

    for (ipc_errors) |err| {
        try testing.expectError(err, err);
    }
}

test "CraftError - all permission errors" {
    const permission_errors = [_]errors.CraftError{
        error.PermissionDenied,
        error.SandboxViolation,
    };

    for (permission_errors) |err| {
        try testing.expectError(err, err);
    }
}

test "CraftError - all config errors" {
    const config_errors = [_]errors.CraftError{
        error.ConfigLoadFailed,
        error.ConfigParseError,
        error.InvalidConfiguration,
    };

    for (config_errors) |err| {
        try testing.expectError(err, err);
    }
}

test "CraftError - all platform errors" {
    const platform_errors = [_]errors.CraftError{
        error.UnsupportedPlatform,
        error.PlatformApiError,
    };

    for (platform_errors) |err| {
        try testing.expectError(err, err);
    }
}

test "CraftError - all network errors" {
    const network_errors = [_]errors.CraftError{
        error.WebSocketConnectionFailed,
        error.NetworkError,
    };

    for (network_errors) |err| {
        try testing.expectError(err, err);
    }
}

test "CraftError - all general errors" {
    const general_errors = [_]errors.CraftError{
        error.NotImplemented,
        error.InvalidArgument,
        error.OutOfMemory,
        error.Timeout,
    };

    for (general_errors) |err| {
        try testing.expectError(err, err);
    }
}

test "errorContext - captures source location" {
    const ctx = errors.errorContext("Auto-captured");
    try testing.expect(ctx.file.len > 0);
    try testing.expect(ctx.line > 0);
}

test "ErrorContext - multiple prints" {
    const ctx1 = errors.ErrorContext.create("Error 1", "file1.zig", 10);
    const ctx2 = errors.ErrorContext.create("Error 2", "file2.zig", 20);

    ctx1.print();
    ctx2.print();

    try testing.expect(true); // Should not crash
}
