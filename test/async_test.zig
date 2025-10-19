const std = @import("std");
const testing = std.testing;
const async_mod = @import("../src/async.zig");

test "Async - basic module import" {
    try testing.expect(true);
}
