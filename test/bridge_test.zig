const std = @import("std");
const testing = std.testing;
const bridge = @import("../src/bridge.zig");

test "Bridge - basic module import" {
    try testing.expect(true);
}
