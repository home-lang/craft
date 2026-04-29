const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Spotlight indexing via `CSSearchableIndex`. Surfaces app content
/// (notes, contacts, conversations) in system-wide search.
///
/// Full implementation needs to construct `CSSearchableItem` instances
/// from the JS-side payload, attach an index identifier, and call
/// `-indexSearchableItems:completionHandler:` on the default index.
/// The shape of each `CSSearchableItem` is rich (metadata keys for
/// title, contentDescription, keywords, thumbnailURL, etc) — we'll
/// thread the JSON shape through once the binding exists.
///
/// Today's stub returns `ok:false` with a reason, and the no-op
/// remove paths return `ok:true` so apps can write the symmetric
/// flow without branching.
pub const SpotlightBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(a: std.mem.Allocator) Self {
        return .{ .allocator = a };
    }

    pub fn deinit(_: *Self) void {}

    pub fn handleMessage(self: *Self, action: []const u8, _: []const u8) !void {
        if (std.mem.eql(u8, action, "index")) {
            bridge_error.sendResultToJS(self.allocator, "index", "{\"ok\":false,\"reason\":\"CSSearchableIndex wiring pending\"}");
        } else if (std.mem.eql(u8, action, "remove")) {
            bridge_error.sendResultToJS(self.allocator, "remove", "{\"ok\":true}");
        } else if (std.mem.eql(u8, action, "removeAll")) {
            bridge_error.sendResultToJS(self.allocator, "removeAll", "{\"ok\":true}");
        } else return BridgeError.UnknownAction;
    }
};
