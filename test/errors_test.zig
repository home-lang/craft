const std = @import("std");
const testing = std.testing;
const errors = @import("../src/errors.zig");

test "Errors - basic module import" {
    try testing.expect(true);
}
