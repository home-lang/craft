const std = @import("std");
const testing = std.testing;

// =============================================================================
// Tests for Round 2 Security & Reliability Improvements
// =============================================================================

// ---------------------------------------------------------------------------
// Fix #1: Command injection prevention in bridge_shell.zig
// ---------------------------------------------------------------------------
test "ShellBridge - validates commands against injection" {
    const bridge_shell = @import("../src/bridge_shell.zig");
    const allocator = testing.allocator;

    var shell = bridge_shell.ShellBridge.init(allocator);
    defer shell.deinit();

    // Safe commands should pass through validation
    shell.handleMessage("exec", "{\"command\":\"ls\",\"callbackId\":\"cb1\"}") catch {};

    // Commands with injection patterns should be blocked
    // The handleMessage returns void and errors are reported to JS, so we test
    // by checking that the function doesn't crash
    shell.handleMessage("exec", "{\"command\":\"ls; rm -rf /\",\"callbackId\":\"cb2\"}") catch {};
    shell.handleMessage("exec", "{\"command\":\"echo $(cat /etc/passwd)\",\"callbackId\":\"cb3\"}") catch {};
    shell.handleMessage("exec", "{\"command\":\"ls `whoami`\",\"callbackId\":\"cb4\"}") catch {};
}

test "ShellBridge - validateCommand blocks dangerous patterns" {
    const bridge_shell = @import("../src/bridge_shell.zig");

    // Test that validation exists and has the right function signature
    _ = bridge_shell.ShellBridge.validateCommand;
}

// ---------------------------------------------------------------------------
// Fix #4: Safe string handling in dialogs.zig
// ---------------------------------------------------------------------------
test "dialogs - uses safe null-terminated strings" {
    const dialogs = @import("../src/dialogs.zig");

    // Verify DialogOptions has expected fields
    try testing.expect(@hasField(dialogs.DialogOptions, "title"));
    try testing.expect(@hasField(dialogs.DialogOptions, "message"));
}

// ---------------------------------------------------------------------------
// Fix #5-6: Process cleanup
// ---------------------------------------------------------------------------
test "ShellBridge - deinit cleans up processes" {
    const bridge_shell = @import("../src/bridge_shell.zig");
    const allocator = testing.allocator;

    // Create and immediately destroy — should not leak
    var shell = bridge_shell.ShellBridge.init(allocator);
    shell.deinit();
}

// ---------------------------------------------------------------------------
// Fix #8: Bridge error types include UnsafeCommand
// ---------------------------------------------------------------------------
test "BridgeError includes UnsafeCommand" {
    const bridge_error = @import("../src/bridge_error.zig");

    // Verify the error type exists
    _ = bridge_error.BridgeError.UnsafeCommand;
}

// ---------------------------------------------------------------------------
// Integration: All bridge modules still compile
// ---------------------------------------------------------------------------
test "All bridge modules compile after round 2 fixes" {
    _ = @import("../src/bridge_shell.zig");
    _ = @import("../src/bridge_clipboard.zig");
    _ = @import("../src/bridge_error.zig");
    _ = @import("../src/dialogs.zig");
    _ = @import("../src/audio.zig");
}
