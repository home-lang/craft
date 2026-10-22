const std = @import("std");
const host = @import("js_runtime.zig");

pub fn main() !void {
    var heap: std.heap.DebugAllocator(.{}) = .init;
    defer std.debug.assert(heap.deinit() == .ok);
    if (!host.available) {
        try std.testing.expectError(error.Unavailable, host.PersistentRuntime.init(heap.allocator(), .{}));
        var missing: host.PersistentRuntime = .{};
        const handle: host.hosting.Handle = .{ .runtime = 0, .slot = 0, .generation = 0 };
        var buffer: [1]u8 = undefined;
        try std.testing.expectError(error.Unavailable, missing.deinit());
        try std.testing.expectError(error.Unavailable, missing.evaluate("1"));
        try std.testing.expectError(error.Unavailable, missing.create(.undefined));
        try std.testing.expectError(error.Unavailable, missing.call(handle, null, &.{}));
        try std.testing.expectError(error.Unavailable, missing.release(handle));
        try std.testing.expectError(error.Unavailable, missing.kind(handle));
        try std.testing.expectError(error.Unavailable, missing.number(handle));
        try std.testing.expectError(error.Unavailable, missing.boolean(handle));
        try std.testing.expectError(error.Unavailable, missing.copyString(handle, heap.allocator()));
        try std.testing.expectError(error.Unavailable, missing.exception());
        try std.testing.expectError(error.Unavailable, missing.copyBuffer(handle, 0, &buffer));
        try std.testing.expectError(error.Unavailable, missing.writeBuffer(handle, 0, &.{1}));
        try std.testing.expectError(error.Unavailable, missing.collect());
        try std.testing.expectError(error.Unavailable, missing.interrupt());
        std.debug.print("persistent hosting: disabled backend refuses initialization and every operation\n", .{});
        return;
    }
    try std.testing.expectError(error.LimitExceeded, host.PersistentRuntime.init(heap.allocator(), .{ .max_handles = 0 }));
    try std.testing.expectError(error.LimitExceeded, host.PersistentRuntime.init(heap.allocator(), .{ .max_handles = 65537 }));
    try std.testing.expectError(error.OutOfMemory, host.PersistentRuntime.init(heap.allocator(), .{ .heap_limit_bytes = 1 }));
    var runtime = try host.PersistentRuntime.init(heap.allocator(), .{ .max_handles = 8, .max_output_bytes = 64 });
    defer runtime.deinit() catch unreachable;
    const frame = try runtime.evaluate("(function(){ let ticks = 0; return function(view) { view[0]++; return ++ticks; }; })()");
    const bytes = try runtime.create(.{ .typed_array = .{ .kind = .u8, .bytes = &.{ 0, 8 } } });
    for (0..100) |index| {
        const result = try runtime.call(frame, null, &.{bytes});
        try std.testing.expectEqual(@as(f64, @floatFromInt(index + 1)), try runtime.number(result));
        try runtime.release(result);
        try runtime.collect();
    }
    var snapshot: [2]u8 = undefined;
    try runtime.copyBuffer(bytes, 0, &snapshot);
    try std.testing.expectEqualSlices(u8, &.{ 100, 8 }, &snapshot);
    try runtime.writeBuffer(bytes, 1, &.{9});
    try runtime.copyBuffer(bytes, 0, &snapshot);
    try std.testing.expectEqualSlices(u8, &.{ 100, 9 }, &snapshot);
    const factory = try runtime.evaluate("(function(text, bytes){ return function(){ return text.length + bytes[0]; }; })");
    const input_text = try runtime.create(.{ .string = "kept" });
    const input_bytes = try runtime.create(.{ .typed_array = .{ .kind = .u8, .bytes = &.{43} } });
    const captured = try runtime.call(factory, null, &.{ input_text, input_bytes });
    try runtime.release(factory);
    try runtime.release(input_text);
    try runtime.release(input_bytes);
    try runtime.collect();
    const captured_result = try runtime.call(captured, null, &.{});
    try std.testing.expectEqual(@as(f64, 47), try runtime.number(captured_result));
    try runtime.release(captured_result);
    try runtime.release(captured);
    try std.testing.expectError(error.Parse, runtime.evaluate("function ("));
    try std.testing.expect((try runtime.exception()) == null);
    const stale = try runtime.create(.{ .number = 1 });
    try runtime.release(stale);
    const replacement = try runtime.create(.{ .number = 2 });
    try std.testing.expect(stale.slot == replacement.slot);
    try std.testing.expectError(error.InvalidHandle, runtime.number(stale));
    try std.testing.expectError(error.InvalidHandle, runtime.release(stale));
    try runtime.release(replacement);
    const throwing = try runtime.evaluate("(function(){ throw 'frame failed'; })");
    for (0..20) |_| {
        try std.testing.expectError(error.Throw, runtime.call(throwing, null, &.{}));
        const exception = (try runtime.exception()).?;
        const message = try runtime.copyString(exception, heap.allocator());
        defer heap.allocator().free(message);
        try std.testing.expectEqualStrings("frame failed", message);
        try runtime.release(exception);
    }
    const text = try runtime.create(.{ .string = "owned é" });
    const copied = try runtime.copyString(text, heap.allocator());
    defer heap.allocator().free(copied);
    const flag = try runtime.create(.{ .boolean = true });
    try std.testing.expect(try runtime.boolean(flag));
    try std.testing.expectEqual(host.hosting.Kind.string, try runtime.kind(text));
    try std.testing.expectError(error.WrongType, runtime.number(text));
    try std.testing.expectError(error.OutOfBounds, runtime.copyBuffer(bytes, 2, &snapshot));
    var full: [3]host.hosting.Handle = undefined;
    for (&full) |*handle| handle.* = try runtime.create(.undefined);
    try std.testing.expectError(error.LimitExceeded, runtime.call(frame, null, &.{bytes}));
    try runtime.copyBuffer(bytes, 0, &snapshot);
    try std.testing.expectEqualSlices(u8, &.{ 100, 9 }, &snapshot);
    for (full) |handle| try runtime.release(handle);
    var excess_arguments: [65]host.hosting.Handle = undefined;
    @memset(&excess_arguments, bytes);
    try std.testing.expectError(error.LimitExceeded, runtime.call(frame, null, &excess_arguments));
    var foreign = try host.PersistentRuntime.init(heap.allocator(), .{});
    defer foreign.deinit() catch unreachable;
    const foreign_value = try foreign.create(.{ .number = 2 });
    try std.testing.expectError(error.InvalidHandle, runtime.number(foreign_value));
    const overlong = try runtime.evaluate("'x'.repeat(100)");
    try std.testing.expectError(error.LimitExceeded, runtime.copyString(overlong, heap.allocator()));
    try runtime.release(overlong);
    const Probe = struct {
        fn run(owned: *host.PersistentRuntime, value: host.hosting.Handle) !void {
            try std.testing.expectError(error.WrongThread, owned.number(value));
            try std.testing.expectError(error.WrongThread, owned.deinit());
        }
    };
    const other_thread = try std.Thread.spawn(.{}, Probe.run, .{ &runtime, bytes });
    other_thread.join();
    var bounded = try host.PersistentRuntime.init(heap.allocator(), .{ .max_input_bytes = 3, .max_output_bytes = 2 });
    defer bounded.deinit() catch unreachable;
    try std.testing.expectError(error.LimitExceeded, bounded.create(.{ .string = "four" }));
    try std.testing.expectError(error.LimitExceeded, bounded.evaluate("1234"));
    const unicode = try bounded.create(.{ .string = "é" });
    const unicode_copy = try bounded.copyString(unicode, heap.allocator());
    defer heap.allocator().free(unicode_copy);
    try std.testing.expectEqualStrings("é", unicode_copy);
    try bounded.release(unicode);
    try std.testing.expectError(error.InvalidString, bounded.create(.{ .string = &.{0xff} }));
    try runtime.interrupt();
    try std.testing.expectError(error.Terminated, runtime.call(frame, null, &.{bytes}));
    try runtime.deinit();
    try runtime.deinit();
    try std.testing.expectError(error.Closed, runtime.number(bytes));
    try std.testing.expectEqualStrings("owned é", copied);
    std.debug.print("persistent hosting: retained frames, GC, buffers, exceptions, stale/foreign handles, input/output/handle bounds, wrong thread, termination and disposal passed\n", .{});
}
