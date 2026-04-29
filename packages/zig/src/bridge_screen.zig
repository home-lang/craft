const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Screen / Display info bridge.
///
/// macOS implementation reads `[NSScreen screens]` (every connected
/// display) and `[NSScreen mainScreen]` (the one with the menu bar).
/// Linux/Windows implementations land later — for now those return
/// empty `{displays:[]}` so JS callers can feature-detect cleanly.
pub const ScreenBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn handleMessage(self: *Self, action: []const u8, _: []const u8) !void {
        if (std.mem.eql(u8, action, "getDisplays")) {
            try self.getDisplays();
        } else if (std.mem.eql(u8, action, "getPrimary")) {
            try self.getPrimary();
        } else {
            return BridgeError.UnknownAction;
        }
    }

    fn getDisplays(self: *Self) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "getDisplays", "{\"displays\":[]}");
            return;
        }
        const macos = @import("macos.zig");
        const NSScreen = macos.getClass("NSScreen");
        const screens = macos.msgSend0(NSScreen, "screens");
        if (@intFromPtr(screens) == 0) {
            bridge_error.sendResultToJS(self.allocator, "getDisplays", "{\"displays\":[]}");
            return;
        }

        const getCount = @as(
            *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) c_ulong,
            @ptrCast(&macos.objc.objc_msgSend),
        );
        const count = getCount(screens, macos.sel("count"));

        var buf: std.ArrayListUnmanaged(u8) = .empty;
        defer buf.deinit(self.allocator);
        try buf.appendSlice(self.allocator, "{\"displays\":[");

        var i: c_ulong = 0;
        while (i < count) : (i += 1) {
            if (i > 0) try buf.append(self.allocator, ',');
            const screen = macos.msgSend1(screens, "objectAtIndex:", i);
            try appendScreenJson(&buf, self.allocator, screen, i);
        }
        try buf.appendSlice(self.allocator, "]}");

        const json = try buf.toOwnedSlice(self.allocator);
        defer self.allocator.free(json);
        bridge_error.sendResultToJS(self.allocator, "getDisplays", json);
    }

    fn getPrimary(self: *Self) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "getPrimary", "{}");
            return;
        }
        const macos = @import("macos.zig");
        const NSScreen = macos.getClass("NSScreen");
        const screen = macos.msgSend0(NSScreen, "mainScreen");
        if (@intFromPtr(screen) == 0) {
            bridge_error.sendResultToJS(self.allocator, "getPrimary", "{}");
            return;
        }
        var buf: std.ArrayListUnmanaged(u8) = .empty;
        defer buf.deinit(self.allocator);
        try appendScreenJson(&buf, self.allocator, screen, 0);
        const json = try buf.toOwnedSlice(self.allocator);
        defer self.allocator.free(json);
        bridge_error.sendResultToJS(self.allocator, "getPrimary", json);
    }
};

fn appendScreenJson(buf: *std.ArrayListUnmanaged(u8), allocator: std.mem.Allocator, screen: @import("macos.zig").objc.id, idx: c_ulong) !void {
    const macos = @import("macos.zig");
    // frame is the full screen (origin at bottom-left in AppKit coords).
    // visibleFrame excludes menu bar + dock — usually what apps want.
    const frame = macos.msgSendRect(screen, "frame");
    const visible = macos.msgSendRect(screen, "visibleFrame");
    const scale = macos.msgSendFloat(screen, "backingScaleFactor");

    var num_buf: [256]u8 = undefined;
    const written = try std.fmt.bufPrint(&num_buf,
        "{{\"id\":{d},\"x\":{d},\"y\":{d},\"width\":{d},\"height\":{d}," ++
        "\"workX\":{d},\"workY\":{d},\"workWidth\":{d},\"workHeight\":{d}," ++
        "\"scaleFactor\":{d}}}",
        .{
            idx,
            frame.origin.x, frame.origin.y, frame.size.width, frame.size.height,
            visible.origin.x, visible.origin.y, visible.size.width, visible.size.height,
            scale,
        });
    try buf.appendSlice(allocator, written);
}
