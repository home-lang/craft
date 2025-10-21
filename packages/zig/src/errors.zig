const std = @import("std");

/// Comprehensive error set for Zyte
pub const ZyteError = error{
    // Window errors
    WindowCreationFailed,
    WindowNotFound,
    InvalidWindowHandle,
    NoWindows,
    NoWindowsOrTray,

    // WebView errors
    WebViewCreationFailed,
    WebViewLoadFailed,
    InvalidURL,

    // File errors
    FileNotFound,
    FileReadError,
    FileWriteError,
    InvalidPath,

    // Plugin errors
    PluginLoadFailed,
    PluginNotFound,
    PluginFunctionNotFound,
    InvalidPluginPath,

    // IPC errors
    IpcChannelNotFound,
    IpcMessageSendFailed,
    InvalidMessage,
    BridgeNotInitialized,

    // Permission errors
    PermissionDenied,
    SandboxViolation,

    // Configuration errors
    ConfigLoadFailed,
    ConfigParseError,
    InvalidConfiguration,

    // Platform errors
    UnsupportedPlatform,
    PlatformApiError,
    PlatformNotSupported,

    // System tray errors
    InvalidIconPath,
    InvalidMenuStructure,

    // Notification errors
    NotificationFailed,

    // Hotkey errors
    HotkeyRegistrationFailed,

    // Storage errors
    StorageError,

    // Network errors
    WebSocketConnectionFailed,
    NetworkError,

    // General errors
    NotImplemented,
    InvalidArgument,
    OutOfMemory,
    Timeout,
};

/// Error context for better debugging
pub const ErrorContext = struct {
    message: []const u8,
    file: []const u8,
    line: u32,
    
    pub fn create(message: []const u8, file: []const u8, line: u32) ErrorContext {
        return .{
            .message = message,
            .file = file,
            .line = line,
        };
    }
    
    pub fn print(self: ErrorContext) void {
        std.debug.print("[ERROR] {s}:{d} - {s}\n", .{ self.file, self.line, self.message });
    }
};

/// Helper macro for creating error contexts
pub fn errorContext(comptime message: []const u8) ErrorContext {
    return ErrorContext.create(message, @src().file, @src().line);
}

/// Format error with actionable suggestions
pub fn formatError(err: anyerror, allocator: std.mem.Allocator) ![]const u8 {
    return switch (err) {
        error.NoWindows, error.NoWindowsOrTray => try allocator.dupe(u8,
            \\❌ Error: No windows or system tray configured
            \\
            \\This usually means you need to either:
            \\  1. Create a window with createWindow()
            \\  2. Enable system tray with --system-tray
            \\  3. Use menubarOnly mode with menubarOnly: true
            \\
            \\Example:
            \\  const app = createApp({
            \\    window: { menubarOnly: true }
            \\  })
            \\
            \\Docs: https://docs.zyte.dev/errors/no-windows
        ),
        error.PlatformNotSupported, error.UnsupportedPlatform => try allocator.dupe(u8,
            \\❌ Error: Platform not supported
            \\
            \\This feature is not available on your current platform.
            \\
            \\Supported platforms:
            \\  - macOS (arm64, x86_64)
            \\  - Linux (x86_64, arm64)
            \\  - Windows (x86_64)
            \\
            \\Check the feature compatibility matrix:
            \\  https://docs.zyte.dev/platform-support
        ),
        error.InvalidIconPath => try allocator.dupe(u8,
            \\❌ Error: Invalid icon path
            \\
            \\The icon file could not be loaded. Common issues:
            \\  1. File does not exist at the specified path
            \\  2. File is not a valid image format (PNG, ICNS, ICO)
            \\  3. Path is relative instead of absolute
            \\
            \\Try:
            \\  - Use an absolute path: /path/to/icon.png
            \\  - Verify file exists: stat <path>
            \\  - Check file format is supported
            \\
            \\Supported formats:
            \\  macOS: .png, .icns, .pdf
            \\  Linux: .png, .svg
            \\  Windows: .ico, .png
        ),
        error.BridgeNotInitialized => try allocator.dupe(u8,
            \\❌ Error: Bridge API not initialized
            \\
            \\You need to initialize the bridge before using window.zyte APIs.
            \\
            \\Fix:
            \\  await app.initBridge()
            \\
            \\Or in Zig:
            \\  try app.initBridge();
        ),
        error.NotificationFailed => try allocator.dupe(u8,
            \\❌ Error: Failed to send notification
            \\
            \\Common causes:
            \\  1. Notification permissions not granted
            \\  2. Notification center disabled
            \\  3. Invalid notification parameters
            \\
            \\On macOS:
            \\  Check System Settings → Notifications → [Your App]
            \\
            \\On Linux:
            \\  Ensure notify-send is installed: sudo apt install libnotify-bin
        ),
        error.HotkeyRegistrationFailed => try allocator.dupe(u8,
            \\❌ Error: Failed to register global hotkey
            \\
            \\Common causes:
            \\  1. Hotkey already registered by another app
            \\  2. Invalid key combination
            \\  3. Accessibility permissions not granted
            \\
            \\On macOS:
            \\  System Settings → Privacy & Security → Accessibility
            \\  Add your app to the list
            \\
            \\Try a different key combination or check for conflicts.
        ),
        error.StorageError => try allocator.dupe(u8,
            \\❌ Error: Local storage operation failed
            \\
            \\Common causes:
            \\  1. Insufficient disk space
            \\  2. Permission denied to write to app support directory
            \\  3. Corrupted storage file
            \\
            \\Try:
            \\  1. Check disk space: df -h
            \\  2. Verify permissions on ~/Library/Application Support
            \\  3. Delete corrupted storage: rm ~/Library/Application Support/[app]/storage.json
        ),
        error.InvalidMenuStructure => try allocator.dupe(u8,
            \\❌ Error: Invalid menu structure
            \\
            \\Menu items must have either:
            \\  1. A label and action
            \\  2. Type "separator" (no label needed)
            \\
            \\Example:
            \\  [
            \\    { label: "Show", action: "show" },
            \\    { type: "separator" },
            \\    { label: "Quit", action: "quit" }
            \\  ]
        ),
        else => try std.fmt.allocPrint(allocator, "❌ Error: {s}", .{@errorName(err)}),
    };
}

/// Print error with helpful message to stderr
pub fn printError(err: anyerror, allocator: std.mem.Allocator) void {
    const msg = formatError(err, allocator) catch {
        std.debug.print("Error: {s}\n", .{@errorName(err)});
        return;
    };
    defer allocator.free(msg);
    std.debug.print("{s}\n", .{msg});
}
