const std = @import("std");
const testing = std.testing;
const devmode = @import("../src/devmode.zig");

test "Devmode - basic module import" {
    try testing.expect(true);
}
