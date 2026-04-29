const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

extern "c" fn os_log_create(subsystem: [*:0]const u8, category: [*:0]const u8) ?*anyopaque;

/// Unified system log integration. Apps call `craft.log.{debug,info,
/// warn,error}(message)` and we route through `os_log` so messages
/// land in Console.app, `log show`, and any aggregator the user has
/// configured (e.g. Sentry's macOS log adapter).
///
/// `os_log` itself is macro-driven and can't be invoked from C
/// without going through libBlocksRuntime; for now we stamp messages
/// with `std.debug.print` which routes to stderr and is captured by
/// the unified log subsystem when run from a launched app. The
/// `os_log_create` hook is in place so a future revision can swap to
/// the proper macro path without touching the JS surface.
pub const LogBridge = struct {
    allocator: std.mem.Allocator,
    log_handle: ?*anyopaque = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        const handle = if (builtin.os.tag == .macos) os_log_create("com.craft.app", "default") else null;
        return .{ .allocator = allocator, .log_handle = handle };
    }

    pub fn deinit(_: *Self) void {}

    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "log")) try self.log(data) else return BridgeError.UnknownAction;
    }

    fn log(self: *Self, data: []const u8) !void {
        const ParseShape = struct {
            level: []const u8 = "info",
            message: []const u8 = "",
        };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();

        if (builtin.os.tag == .macos) {
            std.debug.print("[craft.{s}] {s}\n", .{ parsed.value.level, parsed.value.message });
        }
        bridge_error.sendResultToJS(self.allocator, "log", "{\"ok\":true}");
    }
};
