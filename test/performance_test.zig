const std = @import("std");
const testing = std.testing;
const performance = @import("../src/performance.zig");

test "Performance - basic module import" {
    try testing.expect(true);
}
