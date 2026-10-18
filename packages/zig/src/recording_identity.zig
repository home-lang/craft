//! Shared recording identity validation. Call on the recorder's owning serial
//! executor immediately before its file access or state transition.
const std = @import("std");

pub fn expectedId(allocator: std.mem.Allocator, payload: []const u8) !?[]u8 {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, payload, .{});
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidArgument;
    const expected = parsed.value.object.get("expectedId") orelse return null;
    if (expected != .string or std.mem.trim(u8, expected.string, " \t\r\n").len == 0)
        return error.InvalidArgument;
    return try allocator.dupe(u8, expected.string);
}

pub fn validate(allocator: std.mem.Allocator, payload: []const u8, actual_id: ?[]const u8) !void {
    const expected = try expectedId(allocator, payload) orelse return;
    defer allocator.free(expected);
    if (actual_id == null or !std.mem.eql(u8, actual_id.?, expected)) return error.RecordingConflict;
}

test "recording guards preserve omission and reject changed or invalid identities" {
    const a = std.testing.allocator;
    try validate(a, "{}", "B");
    try validate(a, "{\"expectedId\":\"B\"}", "B");
    try std.testing.expectError(error.RecordingConflict, validate(a, "{\"expectedId\":\"A\"}", "B"));
    try std.testing.expectError(error.RecordingConflict, validate(a, "{\"expectedId\":\"A\"}", null));
    inline for (.{ "null", "42", "\"\"", "\"  \"" }) |invalid| {
        try std.testing.expectError(error.InvalidArgument, validate(a, "{\"expectedId\":" ++ invalid ++ "}", "B"));
    }
}
