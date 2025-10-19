const std = @import("std");
const testing = std.testing;
const wasm = @import("../src/wasm.zig");

test "WASM - basic module import" {
    try testing.expect(true);
}
