const std = @import("std");
const testing = std.testing;
const lifecycle = @import("../src/lifecycle.zig");

test "Lifecycle - basic module import" {
    try testing.expect(true);
}
