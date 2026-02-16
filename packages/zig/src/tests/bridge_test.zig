const std = @import("std");
const testing = std.testing;
const io_context = @import("../io_context.zig");

// Import modules to test
const memory = @import("../memory.zig");
const types = @import("../types.zig");

// ============================================
// Memory Management Tests
// ============================================

test "MemoryPool - basic allocation and deallocation" {
    var pool = memory.MemoryPool.init(testing.allocator);
    defer pool.deinit();

    // Allocate some memory
    const ptr1 = try pool.alloc(u8, 1024);
    @memset(ptr1, 0);

    // Allocate more
    const ptr2 = try pool.alloc(u8, 2048);
    @memset(ptr2, 0);

    // Free first allocation
    pool.free(ptr1);

    // Allocate again - might reuse freed memory
    const ptr3 = try pool.alloc(u8, 1024);
    @memset(ptr3, 0);

    // Verify pool stats
    const stats = pool.getStats();
    try testing.expect(stats.totalAllocated >= 3072);
    try testing.expect(stats.allocCount >= 3);
}

test "TempAllocator - scoped allocations" {
    var temp = memory.TempAllocator.init(testing.allocator);
    defer temp.deinit();

    // Start a scope
    temp.beginScope();

    // Allocate within scope
    const ptr1 = try temp.alloc(u8, 512);
    @memset(ptr1, 42);
    try testing.expectEqual(@as(u8, 42), ptr1[0]);

    const ptr2 = try temp.alloc(u8, 256);
    @memset(ptr2, 84);

    // End scope - all allocations freed
    temp.endScope();

    // New scope
    temp.beginScope();
    const ptr3 = try temp.alloc(u8, 512);
    @memset(ptr3, 21);
    try testing.expectEqual(@as(u8, 21), ptr3[0]);
    temp.endScope();
}

test "TrackingAllocator - leak detection" {
    var tracking = memory.TrackingAllocator.init(testing.allocator);
    defer tracking.deinit();

    const allocator = tracking.allocator();

    // Allocate and free properly
    const ptr1 = try allocator.alloc(u8, 100);
    allocator.free(ptr1);

    // Check no leaks
    const leaks = tracking.getLeaks();
    try testing.expectEqual(@as(usize, 0), leaks.len);
}

// ============================================
// Type System Tests
// ============================================

test "Value - type coercion" {
    // Test null
    const null_val = types.Value.null_value;
    try testing.expect(null_val.isNull());

    // Test boolean
    const bool_val = types.Value.initBool(true);
    try testing.expect(bool_val.isBool());
    try testing.expectEqual(true, bool_val.asBool());

    // Test integer
    const int_val = types.Value.initInt(42);
    try testing.expect(int_val.isNumber());
    try testing.expectEqual(@as(i64, 42), int_val.asInt());

    // Test float
    const float_val = types.Value.initFloat(3.14);
    try testing.expect(float_val.isNumber());
    try testing.expect(@abs(float_val.asFloat() - 3.14) < 0.001);

    // Test string
    const str_val = types.Value.initString("hello");
    try testing.expect(str_val.isString());
    try testing.expectEqualStrings("hello", str_val.asString() orelse "");
}

test "Value - array operations" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var arr = types.Value.initArray(arena.allocator());

    // Add elements
    try arr.arrayAppend(types.Value.initInt(1));
    try arr.arrayAppend(types.Value.initInt(2));
    try arr.arrayAppend(types.Value.initInt(3));

    // Check length
    try testing.expectEqual(@as(usize, 3), arr.arrayLen());

    // Access elements
    const elem = arr.arrayGet(1);
    try testing.expect(elem != null);
    try testing.expectEqual(@as(i64, 2), elem.?.asInt());
}

test "Value - object operations" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var obj = types.Value.initObject(arena.allocator());

    // Set properties
    try obj.objectSet("name", types.Value.initString("Craft"));
    try obj.objectSet("version", types.Value.initInt(1));
    try obj.objectSet("active", types.Value.initBool(true));

    // Get properties
    const name = obj.objectGet("name");
    try testing.expect(name != null);
    try testing.expectEqualStrings("Craft", name.?.asString() orelse "");

    const version = obj.objectGet("version");
    try testing.expect(version != null);
    try testing.expectEqual(@as(i64, 1), version.?.asInt());

    // Check has
    try testing.expect(obj.objectHas("name"));
    try testing.expect(!obj.objectHas("missing"));
}

// ============================================
// Event System Tests
// ============================================

test "EventEmitter - basic events" {
    var emitter = types.EventEmitter.init(testing.allocator);
    defer emitter.deinit();

    var call_count: u32 = 0;
    var received_data: ?types.Value = null;

    // Add listener
    const listener_id = try emitter.on("test-event", struct {
        fn handler(data: types.Value, ctx: *anyopaque) void {
            const count_ptr: *u32 = @ptrCast(@alignCast(ctx));
            count_ptr.* += 1;
            _ = data;
        }
    }.handler, &call_count);

    // Emit event
    emitter.emit("test-event", types.Value.initInt(42));
    try testing.expectEqual(@as(u32, 1), call_count);

    // Emit again
    emitter.emit("test-event", types.Value.initInt(100));
    try testing.expectEqual(@as(u32, 2), call_count);

    // Remove listener
    emitter.off(listener_id);

    // Should not fire
    emitter.emit("test-event", types.Value.initInt(200));
    try testing.expectEqual(@as(u32, 2), call_count);

    _ = received_data;
}

test "EventEmitter - once listener" {
    var emitter = types.EventEmitter.init(testing.allocator);
    defer emitter.deinit();

    var call_count: u32 = 0;

    // Add once listener
    _ = try emitter.once("single-event", struct {
        fn handler(data: types.Value, ctx: *anyopaque) void {
            const count_ptr: *u32 = @ptrCast(@alignCast(ctx));
            count_ptr.* += 1;
            _ = data;
        }
    }.handler, &call_count);

    // First emit - should fire
    emitter.emit("single-event", types.Value.null_value);
    try testing.expectEqual(@as(u32, 1), call_count);

    // Second emit - should not fire (listener removed)
    emitter.emit("single-event", types.Value.null_value);
    try testing.expectEqual(@as(u32, 1), call_count);
}

// ============================================
// String Utilities Tests
// ============================================

test "String utilities - hash" {
    const str1 = "hello world";
    const str2 = "hello world";
    const str3 = "different";

    const hash1 = types.stringHash(str1);
    const hash2 = types.stringHash(str2);
    const hash3 = types.stringHash(str3);

    // Same strings should have same hash
    try testing.expectEqual(hash1, hash2);

    // Different strings should (likely) have different hashes
    try testing.expect(hash1 != hash3);
}

test "String utilities - compare" {
    try testing.expect(types.stringCompare("abc", "abc") == 0);
    try testing.expect(types.stringCompare("abc", "abd") < 0);
    try testing.expect(types.stringCompare("abd", "abc") > 0);
    try testing.expect(types.stringCompare("ab", "abc") < 0);
}

// ============================================
// JSON Parsing Tests
// ============================================

test "JSON parsing - primitives" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    // Parse null
    const null_val = try types.parseJson(arena.allocator(), "null");
    try testing.expect(null_val.isNull());

    // Parse bool
    const true_val = try types.parseJson(arena.allocator(), "true");
    try testing.expectEqual(true, true_val.asBool());

    const false_val = try types.parseJson(arena.allocator(), "false");
    try testing.expectEqual(false, false_val.asBool());

    // Parse number
    const int_val = try types.parseJson(arena.allocator(), "42");
    try testing.expectEqual(@as(i64, 42), int_val.asInt());

    // Parse string
    const str_val = try types.parseJson(arena.allocator(), "\"hello\"");
    try testing.expectEqualStrings("hello", str_val.asString() orelse "");
}

test "JSON parsing - array" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const val = try types.parseJson(arena.allocator(), "[1, 2, 3]");
    try testing.expect(val.isArray());
    try testing.expectEqual(@as(usize, 3), val.arrayLen());
    try testing.expectEqual(@as(i64, 1), val.arrayGet(0).?.asInt());
    try testing.expectEqual(@as(i64, 2), val.arrayGet(1).?.asInt());
    try testing.expectEqual(@as(i64, 3), val.arrayGet(2).?.asInt());
}

test "JSON parsing - object" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const val = try types.parseJson(arena.allocator(), "{\"name\": \"craft\", \"version\": 1}");
    try testing.expect(val.isObject());
    try testing.expectEqualStrings("craft", val.objectGet("name").?.asString() orelse "");
    try testing.expectEqual(@as(i64, 1), val.objectGet("version").?.asInt());
}

// ============================================
// Bridge Message Tests
// ============================================

test "BridgeMessage - request creation" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var params = types.Value.initObject(arena.allocator());
    try params.objectSet("key", types.Value.initString("value"));

    const msg = types.BridgeMessage{
        .id = "msg_123",
        .msg_type = .request,
        .method = "test.method",
        .params = params,
        .result = null,
        .error_msg = null,
    };

    try testing.expectEqualStrings("msg_123", msg.id);
    try testing.expectEqual(types.MessageType.request, msg.msg_type);
    try testing.expectEqualStrings("test.method", msg.method orelse "");
}

test "BridgeMessage - response creation" {
    const msg = types.BridgeMessage{
        .id = "msg_456",
        .msg_type = .response,
        .method = null,
        .params = null,
        .result = types.Value.initInt(42),
        .error_msg = null,
    };

    try testing.expectEqualStrings("msg_456", msg.id);
    try testing.expectEqual(types.MessageType.response, msg.msg_type);
    try testing.expectEqual(@as(i64, 42), msg.result.?.asInt());
}

test "BridgeMessage - error creation" {
    const msg = types.BridgeMessage{
        .id = "msg_789",
        .msg_type = .response,
        .method = null,
        .params = null,
        .result = null,
        .error_msg = types.BridgeError{
            .code = -1,
            .message = "Something went wrong",
            .data = null,
        },
    };

    try testing.expectEqualStrings("msg_789", msg.id);
    try testing.expect(msg.error_msg != null);
    try testing.expectEqual(@as(i32, -1), msg.error_msg.?.code);
    try testing.expectEqualStrings("Something went wrong", msg.error_msg.?.message);
}

// ============================================
// Performance Tests
// ============================================

test "Performance - allocation benchmark" {
    const iterations: usize = 1000;

    var pool = memory.MemoryPool.init(testing.allocator);
    defer pool.deinit();

    const start_ts = std.Io.Timestamp.now(io_context.get(), .awake);

    // Benchmark allocations
    var ptrs: [iterations]*[1024]u8 = undefined;
    for (0..iterations) |i| {
        ptrs[i] = try pool.alloc(u8, 1024);
    }

    // Benchmark deallocations
    for (ptrs) |ptr| {
        pool.free(ptr);
    }

    const end_ts = std.Io.Timestamp.now(io_context.get(), .awake);
    const elapsed_dur = start_ts.durationTo(end_ts);
    const elapsed_ms = @as(f64, @floatFromInt(@as(u64, @intCast(elapsed_dur.nanoseconds)))) / 1_000_000.0;

    // Should complete in reasonable time (< 100ms for 1000 allocs)
    try testing.expect(elapsed_ms < 100.0);
}

test "Performance - event emission benchmark" {
    const iterations: usize = 10000;

    var emitter = types.EventEmitter.init(testing.allocator);
    defer emitter.deinit();

    var counter: u64 = 0;

    // Add listener
    _ = try emitter.on("perf-event", struct {
        fn handler(data: types.Value, ctx: *anyopaque) void {
            const cnt: *u64 = @ptrCast(@alignCast(ctx));
            cnt.* += 1;
            _ = data;
        }
    }.handler, &counter);

    const start_ts = std.Io.Timestamp.now(io_context.get(), .awake);

    // Emit events
    for (0..iterations) |_| {
        emitter.emit("perf-event", types.Value.null_value);
    }

    const end_ts = std.Io.Timestamp.now(io_context.get(), .awake);
    const elapsed_dur = start_ts.durationTo(end_ts);
    const elapsed_ms = @as(f64, @floatFromInt(@as(u64, @intCast(elapsed_dur.nanoseconds)))) / 1_000_000.0;

    try testing.expectEqual(@as(u64, iterations), counter);

    // Should complete quickly (< 50ms for 10000 events)
    try testing.expect(elapsed_ms < 50.0);
}
