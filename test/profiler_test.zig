const std = @import("std");
const testing = std.testing;
const profiler = @import("../src/profiler.zig");

test "Profiler - basic module import" {
    try testing.expect(true);
}
