const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// mDNS / Bonjour service discovery.
///
/// The full implementation needs `NWBrowser` (modern API) or
/// `NSNetServiceBrowser` (legacy) to subscribe to service discovery
/// events and forward them to the JS layer. Both flows require a
/// per-service-type session that outlives the bridge call, plus the
/// usual delegate scaffolding.
///
/// What ships today is the stable JS surface (`browse`, `stop`,
/// `onFound`, `onLost`) so apps can write against it; the native
/// NWBrowser delegate is the next thing to wire and will start
/// firing `craft:bonjour:found` / `craft:bonjour:lost` once it
/// lands. Returning `started: false` tells callers their listener
/// won't actually receive anything yet.
pub const BonjourBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(a: std.mem.Allocator) Self {
        return .{ .allocator = a };
    }

    pub fn deinit(_: *Self) void {}

    pub fn handleMessage(self: *Self, action: []const u8, _: []const u8) !void {
        if (std.mem.eql(u8, action, "browse")) {
            bridge_error.sendResultToJS(self.allocator, "browse", "{\"started\":false,\"reason\":\"native NWBrowser wiring pending\"}");
        } else if (std.mem.eql(u8, action, "stop")) {
            bridge_error.sendResultToJS(self.allocator, "stop", "{\"ok\":true}");
        } else return BridgeError.UnknownAction;
    }
};
