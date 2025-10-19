const std = @import("std");
const testing = std.testing;
const errors = @import("../src/errors.zig");

test "ZyteError - window errors exist" {
    const err1: errors.ZyteError = error.WindowCreationFailed;
    const err2: errors.ZyteError = error.WindowNotFound;
    const err3: errors.ZyteError = error.InvalidWindowHandle;

    try testing.expectError(error.WindowCreationFailed, err1);
    try testing.expectError(error.WindowNotFound, err2);
    try testing.expectError(error.InvalidWindowHandle, err3);
}

test "ZyteError - webview errors exist" {
    const err1: errors.ZyteError = error.WebViewCreationFailed;
    const err2: errors.ZyteError = error.WebViewLoadFailed;
    const err3: errors.ZyteError = error.InvalidURL;

    try testing.expectError(error.WebViewCreationFailed, err1);
    try testing.expectError(error.WebViewLoadFailed, err2);
    try testing.expectError(error.InvalidURL, err3);
}

test "ZyteError - file errors exist" {
    const err1: errors.ZyteError = error.FileNotFound;
    const err2: errors.ZyteError = error.FileReadError;
    const err3: errors.ZyteError = error.FileWriteError;
    const err4: errors.ZyteError = error.InvalidPath;

    try testing.expectError(error.FileNotFound, err1);
    try testing.expectError(error.FileReadError, err2);
    try testing.expectError(error.FileWriteError, err3);
    try testing.expectError(error.InvalidPath, err4);
}

test "ZyteError - plugin errors exist" {
    const err1: errors.ZyteError = error.PluginLoadFailed;
    const err2: errors.ZyteError = error.PluginNotFound;
    const err3: errors.ZyteError = error.PluginFunctionNotFound;
    const err4: errors.ZyteError = error.InvalidPluginPath;

    try testing.expectError(error.PluginLoadFailed, err1);
    try testing.expectError(error.PluginNotFound, err2);
    try testing.expectError(error.PluginFunctionNotFound, err3);
    try testing.expectError(error.InvalidPluginPath, err4);
}

test "ZyteError - ipc errors exist" {
    const err1: errors.ZyteError = error.IpcChannelNotFound;
    const err2: errors.ZyteError = error.IpcMessageSendFailed;
    const err3: errors.ZyteError = error.InvalidMessage;

    try testing.expectError(error.IpcChannelNotFound, err1);
    try testing.expectError(error.IpcMessageSendFailed, err2);
    try testing.expectError(error.InvalidMessage, err3);
}

test "ZyteError - permission errors exist" {
    const err1: errors.ZyteError = error.PermissionDenied;
    const err2: errors.ZyteError = error.SandboxViolation;

    try testing.expectError(error.PermissionDenied, err1);
    try testing.expectError(error.SandboxViolation, err2);
}

test "ZyteError - configuration errors exist" {
    const err1: errors.ZyteError = error.ConfigLoadFailed;
    const err2: errors.ZyteError = error.ConfigParseError;
    const err3: errors.ZyteError = error.InvalidConfiguration;

    try testing.expectError(error.ConfigLoadFailed, err1);
    try testing.expectError(error.ConfigParseError, err2);
    try testing.expectError(error.InvalidConfiguration, err3);
}

test "ZyteError - platform errors exist" {
    const err1: errors.ZyteError = error.UnsupportedPlatform;
    const err2: errors.ZyteError = error.PlatformApiError;

    try testing.expectError(error.UnsupportedPlatform, err1);
    try testing.expectError(error.PlatformApiError, err2);
}

test "ZyteError - network errors exist" {
    const err1: errors.ZyteError = error.WebSocketConnectionFailed;
    const err2: errors.ZyteError = error.NetworkError;

    try testing.expectError(error.WebSocketConnectionFailed, err1);
    try testing.expectError(error.NetworkError, err2);
}

test "ZyteError - general errors exist" {
    const err1: errors.ZyteError = error.NotImplemented;
    const err2: errors.ZyteError = error.InvalidArgument;
    const err3: errors.ZyteError = error.OutOfMemory;
    const err4: errors.ZyteError = error.Timeout;

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

test "ZyteError - can be used in functions" {
    const testFunc = struct {
        fn fail() errors.ZyteError!void {
            return error.NotImplemented;
        }
    }.fail;

    try testing.expectError(error.NotImplemented, testFunc());
}

test "ZyteError - can be caught and handled" {
    const testFunc = struct {
        fn mayFail(should_fail: bool) errors.ZyteError!i32 {
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
