const std = @import("std");
const testing = std.testing;
const lifecycle = @import("../src/lifecycle.zig");

// LifecyclePhase tests
test "LifecyclePhase - all phases" {
    try testing.expectEqual(lifecycle.LifecyclePhase.initializing, .initializing);
    try testing.expectEqual(lifecycle.LifecyclePhase.starting, .starting);
    try testing.expectEqual(lifecycle.LifecyclePhase.running, .running);
    try testing.expectEqual(lifecycle.LifecyclePhase.pausing, .pausing);
    try testing.expectEqual(lifecycle.LifecyclePhase.paused, .paused);
    try testing.expectEqual(lifecycle.LifecyclePhase.resuming, .resuming);
    try testing.expectEqual(lifecycle.LifecyclePhase.stopping, .stopping);
    try testing.expectEqual(lifecycle.LifecyclePhase.stopped, .stopped);
}

// Lifecycle tests
test "Lifecycle - initialization" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    try testing.expectEqual(lifecycle.LifecyclePhase.initializing, lc.phase);
    try testing.expectEqual(@as(usize, 0), lc.hooks.count());
}

test "Lifecycle - getPhase" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    try testing.expectEqual(lifecycle.LifecyclePhase.initializing, lc.getPhase());
}

test "Lifecycle - isRunning" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    try testing.expect(!lc.isRunning());

    try lc.start();
    try testing.expect(lc.isRunning());
}

test "Lifecycle - isPaused" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    try testing.expect(!lc.isPaused());

    try lc.start();
    try lc.pause();
    try testing.expect(lc.isPaused());
}

test "Lifecycle - isStopped" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    try testing.expect(!lc.isStopped());

    try lc.start();
    try lc.stop();
    try testing.expect(lc.isStopped());
}

// Hook tests
var hook_called = false;
var hook_call_count: usize = 0;

fn testHook() !void {
    hook_called = true;
    hook_call_count += 1;
}

fn failingHook() !void {
    return error.HookFailed;
}

test "Lifecycle - registerHook" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    try lc.registerHook("test", testHook);

    const hooks = lc.hooks.get("test");
    try testing.expect(hooks != null);
    try testing.expectEqual(@as(usize, 1), hooks.?.items.len);
}

test "Lifecycle - onStart hook" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    hook_called = false;

    try lc.onStart(testHook);
    try lc.start();

    try testing.expect(hook_called);
}

test "Lifecycle - onStop hook" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    hook_called = false;

    try lc.onStop(testHook);
    try lc.start();
    try lc.stop();

    try testing.expect(hook_called);
}

test "Lifecycle - onPause hook" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    hook_called = false;

    try lc.onPause(testHook);
    try lc.start();
    try lc.pause();

    try testing.expect(hook_called);
}

test "Lifecycle - onResume hook" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    hook_called = false;

    try lc.onResume(testHook);
    try lc.start();
    try lc.pause();
    try lc.unpause();

    try testing.expect(hook_called);
}

test "Lifecycle - beforeStart hook" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    hook_called = false;

    try lc.beforeStart(testHook);
    try lc.start();

    try testing.expect(hook_called);
}

test "Lifecycle - afterStart hook" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    hook_called = false;

    try lc.afterStart(testHook);
    try lc.start();

    try testing.expect(hook_called);
}

test "Lifecycle - beforeStop hook" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    hook_called = false;

    try lc.beforeStop(testHook);
    try lc.start();
    try lc.stop();

    try testing.expect(hook_called);
}

test "Lifecycle - afterStop hook" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    hook_called = false;

    try lc.afterStop(testHook);
    try lc.start();
    try lc.stop();

    try testing.expect(hook_called);
}

test "Lifecycle - multiple hooks same phase" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    hook_call_count = 0;

    try lc.onStart(testHook);
    try lc.onStart(testHook);
    try lc.onStart(testHook);

    try lc.start();

    try testing.expectEqual(@as(usize, 3), hook_call_count);
}

test "Lifecycle - start lifecycle" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    try testing.expectEqual(lifecycle.LifecyclePhase.initializing, lc.phase);

    try lc.start();

    try testing.expectEqual(lifecycle.LifecyclePhase.running, lc.phase);
}

test "Lifecycle - stop lifecycle" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    try lc.start();
    try testing.expectEqual(lifecycle.LifecyclePhase.running, lc.phase);

    try lc.stop();

    try testing.expectEqual(lifecycle.LifecyclePhase.stopped, lc.phase);
}

test "Lifecycle - pause lifecycle" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    try lc.start();
    try testing.expectEqual(lifecycle.LifecyclePhase.running, lc.phase);

    try lc.pause();

    try testing.expectEqual(lifecycle.LifecyclePhase.paused, lc.phase);
}

test "Lifecycle - resume lifecycle" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    try lc.start();
    try lc.pause();
    try testing.expectEqual(lifecycle.LifecyclePhase.paused, lc.phase);

    try lc.unpause();

    try testing.expectEqual(lifecycle.LifecyclePhase.running, lc.phase);
}

test "Lifecycle - full lifecycle" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    try testing.expectEqual(lifecycle.LifecyclePhase.initializing, lc.phase);

    try lc.start();
    try testing.expectEqual(lifecycle.LifecyclePhase.running, lc.phase);

    try lc.pause();
    try testing.expectEqual(lifecycle.LifecyclePhase.paused, lc.phase);

    try lc.unpause();
    try testing.expectEqual(lifecycle.LifecyclePhase.running, lc.phase);

    try lc.stop();
    try testing.expectEqual(lifecycle.LifecyclePhase.stopped, lc.phase);
}

// Module-level variables for hook execution order test
var execution_order_counter: u8 = 0;
var execution_order_values: [3]u8 = undefined;

fn hookRecordOrder1() !void {
    execution_order_values[execution_order_counter] = 1;
    execution_order_counter += 1;
}

fn hookRecordOrder2() !void {
    execution_order_values[execution_order_counter] = 2;
    execution_order_counter += 1;
}

fn hookRecordOrder3() !void {
    execution_order_values[execution_order_counter] = 3;
    execution_order_counter += 1;
}

test "Lifecycle - hook execution order" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    // Reset module-level state
    execution_order_counter = 0;
    execution_order_values = undefined;

    try lc.beforeStart(hookRecordOrder1);
    try lc.onStart(hookRecordOrder2);
    try lc.afterStart(hookRecordOrder3);

    try lc.start();

    try testing.expectEqual(@as(u8, 3), execution_order_counter);
    try testing.expectEqual(@as(u8, 1), execution_order_values[0]);
    try testing.expectEqual(@as(u8, 2), execution_order_values[1]);
    try testing.expectEqual(@as(u8, 3), execution_order_values[2]);
}

test "Lifecycle - failing hook stops execution" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    hook_called = false;

    try lc.beforeStart(failingHook);
    try lc.onStart(testHook);

    const result = lc.start();

    try testing.expectError(error.HookFailed, result);
    try testing.expect(!hook_called); // onStart should not be called
}

fn noopHook() !void {
    // Empty hook for phase transitions test
}

test "Lifecycle - phase transitions during start" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    try lc.beforeStart(noopHook);
    try lc.start();

    try testing.expectEqual(lifecycle.LifecyclePhase.running, lc.phase);
}

test "Lifecycle - phase transitions during stop" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    try lc.start();
    try testing.expectEqual(lifecycle.LifecyclePhase.running, lc.phase);

    try lc.stop();
    try testing.expectEqual(lifecycle.LifecyclePhase.stopped, lc.phase);
}

test "Lifecycle - no hooks registered" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    // Should not crash with no hooks
    try lc.start();
    try lc.pause();
    try lc.unpause();
    try lc.stop();
}

test "Lifecycle - hook count per phase" {
    const allocator = testing.allocator;
    var lc = lifecycle.Lifecycle.init(allocator);
    defer lc.deinit();

    try lc.onStart(testHook);
    try lc.onStart(testHook);

    try lc.onStop(testHook);
    try lc.onStop(testHook);
    try lc.onStop(testHook);

    const start_hooks = lc.hooks.get("start");
    try testing.expectEqual(@as(usize, 2), start_hooks.?.items.len);

    const stop_hooks = lc.hooks.get("stop");
    try testing.expectEqual(@as(usize, 3), stop_hooks.?.items.len);
}
