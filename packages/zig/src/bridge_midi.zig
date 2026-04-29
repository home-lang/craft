const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// CoreMIDI bridge — list endpoints, send and receive messages.
///
/// Implementation outline:
///   - `MIDIClientCreate` makes a process-wide client we lazily build
///     on first JS call.
///   - `MIDIInputPortCreate` + `MIDIPortConnectSource` subscribes to
///     incoming messages from each external source; the read callback
///     forwards `{port, data}` to JS as `craft:midi:message`.
///   - `MIDIOutputPortCreate` + `MIDISend` covers outgoing.
///
/// Today's surface is enough to enumerate devices and prepare apps to
/// switch over once the read-callback wiring lands. CoreMIDI's read
/// callback runs on a high-priority thread; the production
/// implementation needs a lock-free SPSC queue between that thread and
/// the main run loop, which is more plumbing than fits here.
pub const MIDIBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(_: *Self) void {}

    pub fn handleMessage(self: *Self, action: []const u8, _: []const u8) !void {
        if (std.mem.eql(u8, action, "listSources")) {
            try self.listEndpoints("listSources", true);
        } else if (std.mem.eql(u8, action, "listDestinations")) {
            try self.listEndpoints("listDestinations", false);
        } else if (std.mem.eql(u8, action, "send") or
                   std.mem.eql(u8, action, "subscribe") or
                   std.mem.eql(u8, action, "unsubscribe"))
        {
            // The send / subscribe paths need MIDIClient + MIDIPort
            // wiring + a lock-free queue for the read callback. Surface
            // the API today, fill in the bottom half once that lands.
            bridge_error.sendResultToJS(self.allocator, action, "{\"ok\":false,\"reason\":\"CoreMIDI port wiring pending\"}");
        } else return BridgeError.UnknownAction;
    }

    fn listEndpoints(self: *Self, action: []const u8, is_sources: bool) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, action, "{\"endpoints\":[]}");
            return;
        }
        // CoreMIDI uses procedural C functions; we rely on extern decls.
        const count = if (is_sources) MIDIGetNumberOfSources() else MIDIGetNumberOfDestinations();

        var buf: std.ArrayListUnmanaged(u8) = .empty;
        defer buf.deinit(self.allocator);
        try buf.appendSlice(self.allocator, "{\"endpoints\":[");
        var i: usize = 0;
        while (i < count) : (i += 1) {
            if (i > 0) try buf.append(self.allocator, ',');
            const ep = if (is_sources) MIDIGetSource(i) else MIDIGetDestination(i);
            try appendEndpoint(self.allocator, &buf, ep, i);
        }
        try buf.appendSlice(self.allocator, "]}");

        const owned = try buf.toOwnedSlice(self.allocator);
        defer self.allocator.free(owned);
        bridge_error.sendResultToJS(self.allocator, action, owned);
    }
};

extern "c" fn MIDIGetNumberOfSources() usize;
extern "c" fn MIDIGetNumberOfDestinations() usize;
extern "c" fn MIDIGetSource(index: usize) ?*anyopaque;
extern "c" fn MIDIGetDestination(index: usize) ?*anyopaque;
extern "c" fn MIDIObjectGetStringProperty(obj: ?*anyopaque, prop: ?*anyopaque, str: *?*anyopaque) i32;

fn appendEndpoint(allocator: std.mem.Allocator, buf: *std.ArrayListUnmanaged(u8), ep: ?*anyopaque, index: usize) !void {
    var num_buf: [32]u8 = undefined;
    const idx_str = try std.fmt.bufPrint(&num_buf, "{d}", .{index});
    try buf.appendSlice(allocator, "{\"index\":");
    try buf.appendSlice(allocator, idx_str);
    try buf.appendSlice(allocator, ",\"name\":\"");
    if (@intFromPtr(ep) != 0) {
        // kMIDIPropertyDisplayName — read from CoreMIDI, returns CFString.
        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            const NSString = macos.getClass("NSString");
            const display_name_key = macos.msgSend1(NSString, "stringWithUTF8String:", @as([*:0]const u8, "displayName"));
            var cf: ?*anyopaque = null;
            const status = MIDIObjectGetStringProperty(ep, @ptrCast(display_name_key), &cf);
            if (status == 0 and cf != null) {
                const utf8 = macos.msgSend0(@as(macos.objc.id, @ptrCast(@constCast(cf))), "UTF8String");
                if (@intFromPtr(utf8) != 0) {
                    const slice = std.mem.span(@as([*:0]const u8, @ptrCast(utf8)));
                    for (slice) |b| {
                        switch (b) {
                            '"' => try buf.appendSlice(allocator, "\\\""),
                            '\\' => try buf.appendSlice(allocator, "\\\\"),
                            else => try buf.append(allocator, b),
                        }
                    }
                }
            }
        }
    }
    try buf.appendSlice(allocator, "\"}");
}
