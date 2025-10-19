const std = @import("std");
const testing = std.testing;
const state = @import("../src/state.zig");

// StateError tests
test "StateError enum" {
    try testing.expectEqual(state.StateError.InvalidState, .InvalidState);
    try testing.expectEqual(state.StateError.MutationDuringComputation, .MutationDuringComputation);
    try testing.expectEqual(state.StateError.CircularDependency, .CircularDependency);
}

// State initialization
test "State - init and deinit" {
    const allocator = testing.allocator;
    var s = state.State.init(allocator);
    defer s.deinit();

    try testing.expect(!s.is_computing);
}

// StateValue tests
test "StateValue - int variant" {
    const value = state.StateValue{ .int = 42 };
    try testing.expectEqual(@as(i64, 42), value.int);
}

test "StateValue - float variant" {
    const value = state.StateValue{ .float = 3.14 };
    try testing.expectEqual(@as(f64, 3.14), value.float);
}

test "StateValue - bool variant" {
    const value_true = state.StateValue{ .bool = true };
    const value_false = state.StateValue{ .bool = false };

    try testing.expect(value_true.bool);
    try testing.expect(!value_false.bool);
}

test "StateValue - string variant" {
    const value = state.StateValue{ .string = "hello" };
    try testing.expectEqualStrings("hello", value.string);
}

test "StateValue - null variant" {
    const value = state.StateValue{ .null_value = {} };
    try testing.expect(value == .null_value);
}

// StateValue.eql tests
test "StateValue - eql with same int" {
    const v1 = state.StateValue{ .int = 42 };
    const v2 = state.StateValue{ .int = 42 };

    try testing.expect(v1.eql(v2));
}

test "StateValue - eql with different int" {
    const v1 = state.StateValue{ .int = 42 };
    const v2 = state.StateValue{ .int = 43 };

    try testing.expect(!v1.eql(v2));
}

test "StateValue - eql with same float" {
    const v1 = state.StateValue{ .float = 3.14 };
    const v2 = state.StateValue{ .float = 3.14 };

    try testing.expect(v1.eql(v2));
}

test "StateValue - eql with same bool" {
    const v1 = state.StateValue{ .bool = true };
    const v2 = state.StateValue{ .bool = true };

    try testing.expect(v1.eql(v2));
}

test "StateValue - eql with same string" {
    const v1 = state.StateValue{ .string = "test" };
    const v2 = state.StateValue{ .string = "test" };

    try testing.expect(v1.eql(v2));
}

test "StateValue - eql with different string" {
    const v1 = state.StateValue{ .string = "test" };
    const v2 = state.StateValue{ .string = "other" };

    try testing.expect(!v1.eql(v2));
}

test "StateValue - eql with null" {
    const v1 = state.StateValue{ .null_value = {} };
    const v2 = state.StateValue{ .null_value = {} };

    try testing.expect(v1.eql(v2));
}

test "StateValue - eql with different types" {
    const v1 = state.StateValue{ .int = 42 };
    const v2 = state.StateValue{ .string = "42" };

    try testing.expect(!v1.eql(v2));
}

test "StateValue - eql with null parameter" {
    const v1 = state.StateValue{ .int = 42 };

    try testing.expect(!v1.eql(null));
}

// State get/set tests
test "State - set and get int value" {
    const allocator = testing.allocator;
    var s = state.State.init(allocator);
    defer s.deinit();

    const value = state.StateValue{ .int = 42 };
    try s.set("count", value);

    const retrieved = s.get("count");
    try testing.expect(retrieved != null);
    try testing.expectEqual(@as(i64, 42), retrieved.?.int);
}

test "State - set and get string value" {
    const allocator = testing.allocator;
    var s = state.State.init(allocator);
    defer s.deinit();

    const value = state.StateValue{ .string = "hello" };
    try s.set("message", value);

    const retrieved = s.get("message");
    try testing.expect(retrieved != null);
    try testing.expectEqualStrings("hello", retrieved.?.string);
}

test "State - get non-existent key" {
    const allocator = testing.allocator;
    var s = state.State.init(allocator);
    defer s.deinit();

    const retrieved = s.get("nonexistent");
    try testing.expectEqual(@as(?state.StateValue, null), retrieved);
}

test "State - overwrite existing value" {
    const allocator = testing.allocator;
    var s = state.State.init(allocator);
    defer s.deinit();

    const value1 = state.StateValue{ .int = 42 };
    try s.set("count", value1);

    const value2 = state.StateValue{ .int = 100 };
    try s.set("count", value2);

    const retrieved = s.get("count");
    try testing.expectEqual(@as(i64, 100), retrieved.?.int);
}

// Observer tests
test "Observer - struct creation" {
    const observer = state.Observer{
        .id = 1,
        .fn_ptr = testObserverFn,
    };

    try testing.expectEqual(@as(usize, 1), observer.id);
}

var observer_called = false;
var observer_new_value: ?state.StateValue = null;
var observer_old_value: ?state.StateValue = null;

fn testObserverFn(new: state.StateValue, old: ?state.StateValue) void {
    observer_called = true;
    observer_new_value = new;
    observer_old_value = old;
}

test "State - observe and notify" {
    const allocator = testing.allocator;
    var s = state.State.init(allocator);
    defer s.deinit();

    observer_called = false;
    observer_new_value = null;
    observer_old_value = null;

    const observer = state.Observer{
        .id = 1,
        .fn_ptr = testObserverFn,
    };

    try s.observe("count", observer);

    const value = state.StateValue{ .int = 42 };
    try s.set("count", value);

    try testing.expect(observer_called);
    try testing.expectEqual(@as(i64, 42), observer_new_value.?.int);
}

test "State - unobserve" {
    const allocator = testing.allocator;
    var s = state.State.init(allocator);
    defer s.deinit();

    observer_called = false;

    const observer = state.Observer{
        .id = 1,
        .fn_ptr = testObserverFn,
    };

    try s.observe("count", observer);
    s.unobserve("count", observer);

    const value = state.StateValue{ .int = 42 };
    try s.set("count", value);

    try testing.expect(!observer_called);
}

test "State - multiple observers" {
    const allocator = testing.allocator;
    var s = state.State.init(allocator);
    defer s.deinit();

    const observer1 = state.Observer{
        .id = 1,
        .fn_ptr = testObserverFn,
    };

    const observer2 = state.Observer{
        .id = 2,
        .fn_ptr = testObserverFn,
    };

    try s.observe("count", observer1);
    try s.observe("count", observer2);

    const value = state.StateValue{ .int = 42 };
    try s.set("count", value);

    // Both observers should be called
    try testing.expect(observer_called);
}

// Middleware tests
fn testMiddleware(key: []const u8, new: state.StateValue, old: ?state.StateValue) bool {
    _ = key;
    _ = old;
    // Block values greater than 100
    return if (new == .int) new.int <= 100 else true;
}

test "State - middleware allows change" {
    const allocator = testing.allocator;
    var s = state.State.init(allocator);
    defer s.deinit();

    const middleware = state.Middleware{
        .fn_ptr = testMiddleware,
    };

    try s.addMiddleware(middleware);

    const value = state.StateValue{ .int = 50 };
    try s.set("count", value);

    const retrieved = s.get("count");
    try testing.expectEqual(@as(i64, 50), retrieved.?.int);
}

test "State - middleware blocks change" {
    const allocator = testing.allocator;
    var s = state.State.init(allocator);
    defer s.deinit();

    const middleware = state.Middleware{
        .fn_ptr = testMiddleware,
    };

    try s.addMiddleware(middleware);

    // First set an allowed value
    const value1 = state.StateValue{ .int = 50 };
    try s.set("count", value1);

    // Try to set a blocked value
    const value2 = state.StateValue{ .int = 150 };
    try s.set("count", value2);

    // Should still be the old value
    const retrieved = s.get("count");
    try testing.expectEqual(@as(i64, 50), retrieved.?.int);
}

// Mutation during computation test
test "State - mutation during computation error" {
    const allocator = testing.allocator;
    var s = state.State.init(allocator);
    defer s.deinit();

    s.is_computing = true;

    const value = state.StateValue{ .int = 42 };
    const result = s.set("count", value);

    try testing.expectError(state.StateError.MutationDuringComputation, result);
}
