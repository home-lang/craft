const std = @import("std");
const testing = std.testing;
const cli = @import("../src/cli.zig");

test "CLI - basic module import" {
    try testing.expect(true);
}
