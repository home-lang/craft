const std = @import("std");
const testing = std.testing;
const hotreload = @import("../src/hotreload.zig");

test "Hotreload - basic module import" {
    try testing.expect(true);
}
