const std = @import("std");
const testing = std.testing;
const ipc = @import("../src/ipc.zig");

test "IPC - basic module import" {
    try testing.expect(true);
}
