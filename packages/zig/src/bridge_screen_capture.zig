const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Screen capture bridge.
///
/// Three operations:
///   - `captureScreen()`     — full primary display as base64 PNG
///   - `captureWindow(id)`   — single window by id
///   - `listWindows()`       — array of capturable windows
///                             (id, name, ownerName, bounds)
///
/// Implementation uses the legacy `CGWindowListCreateImage` /
/// `CGWindowListCopyWindowInfo` APIs. They're permission-gated by
/// the user via System Settings → Privacy → Screen Recording. If
/// the user hasn't granted access, capture returns a black image.
/// Apps should guide them via `permissions.openSettings('screen_recording')`
/// before calling here.
///
/// **TODO**: ScreenCaptureKit (Sonoma+) gives you per-frame access
/// for live streaming + finer-grained content filters. We use
/// CGWindowList for one-shot stills since it's simpler and works
/// on every supported macOS version.
pub const ScreenCaptureBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(_: *Self) void {}

    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "captureScreen")) try self.captureScreen()
        else if (std.mem.eql(u8, action, "captureWindow")) try self.captureWindow(data)
        else if (std.mem.eql(u8, action, "listWindows")) try self.listWindows()
        else return BridgeError.UnknownAction;
    }

    fn captureScreen(self: *Self) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "captureScreen", "{\"image\":null}");
            return;
        }
        // CGRectInfinite + kCGWindowListOptionOnScreenOnly + kCGNullWindowID
        // captures the entire screen at native resolution.
        const cg_image = cgWindowListCreateImage(0, 0, 1 << 0, 0, 0);
        if (cg_image == null) {
            bridge_error.sendResultToJS(self.allocator, "captureScreen", "{\"image\":null}");
            return;
        }
        defer cgImageRelease(cg_image);
        try sendImageResult(self, "captureScreen", cg_image);
    }

    fn captureWindow(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "captureWindow", "{\"image\":null}");
            return;
        }
        const ParseShape = struct { id: u32 = 0 };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        if (parsed.value.id == 0) return BridgeError.MissingData;

        // kCGWindowListOptionIncludingWindow = 1<<3, kCGWindowImageBoundsIgnoreFraming = 1<<0
        const cg_image = cgWindowListCreateImage(0, 1 << 3, parsed.value.id, 1 << 0, 0);
        if (cg_image == null) {
            bridge_error.sendResultToJS(self.allocator, "captureWindow", "{\"image\":null}");
            return;
        }
        defer cgImageRelease(cg_image);
        try sendImageResult(self, "captureWindow", cg_image);
    }

    fn listWindows(self: *Self) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "listWindows", "{\"windows\":[]}");
            return;
        }
        const macos = @import("macos.zig");
        // kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements = 0x10
        const list = cgWindowListCopyWindowInfo(0x10, 0);
        if (list == null) {
            bridge_error.sendResultToJS(self.allocator, "listWindows", "{\"windows\":[]}");
            return;
        }
        defer cfRelease(list);

        const Fn = *const fn (?*anyopaque, macos.objc.SEL) callconv(.c) c_ulong;
        const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
        const count = f(list, macos.sel("count"));

        var buf: std.ArrayListUnmanaged(u8) = .empty;
        defer buf.deinit(self.allocator);
        try buf.appendSlice(self.allocator, "{\"windows\":[");

        var i: c_ulong = 0;
        while (i < count) : (i += 1) {
            const dict = macos.msgSend1(@as(macos.objc.id, @ptrCast(@constCast(list))), "objectAtIndex:", i);
            if (@intFromPtr(dict) == 0) continue;
            if (i > 0) try buf.append(self.allocator, ',');
            try appendWindowJson(self.allocator, &buf, dict);
        }
        try buf.appendSlice(self.allocator, "]}");

        const owned = try buf.toOwnedSlice(self.allocator);
        defer self.allocator.free(owned);
        bridge_error.sendResultToJS(self.allocator, "listWindows", owned);
    }
};

// =============================================================================
// CoreGraphics + JSON helpers
// =============================================================================

extern "c" fn CGWindowListCreateImage(rect: CGRect, list_options: u32, window_id: u32, image_options: u32) ?*anyopaque;
extern "c" fn CGWindowListCopyWindowInfo(options: u32, relative_to: u32) ?*anyopaque;
extern "c" fn CGImageRelease(image: ?*anyopaque) void;
extern "c" fn CFRelease(cf: ?*anyopaque) void;

const CGRect = extern struct {
    origin: CGPoint,
    size: CGSize,
};
const CGPoint = extern struct { x: f64, y: f64 };
const CGSize = extern struct { width: f64, height: f64 };

const CGRectInfinite = CGRect{
    .origin = .{ .x = -1e9, .y = -1e9 },
    .size = .{ .width = 2e9, .height = 2e9 },
};

fn cgWindowListCreateImage(_: u32, options: u32, window_id: u32, image_options: u32, _: u32) ?*anyopaque {
    if (builtin.os.tag != .macos) return null;
    return CGWindowListCreateImage(CGRectInfinite, options, window_id, image_options);
}

fn cgWindowListCopyWindowInfo(options: u32, relative: u32) ?*anyopaque {
    if (builtin.os.tag != .macos) return null;
    return CGWindowListCopyWindowInfo(options, relative);
}

fn cgImageRelease(img: ?*anyopaque) void {
    if (builtin.os.tag != .macos) return;
    CGImageRelease(img);
}

fn cfRelease(cf: ?*anyopaque) void {
    if (builtin.os.tag != .macos) return;
    CFRelease(cf);
}

/// Wrap a CGImageRef as an NSBitmapImageRep, encode as PNG, base64.
/// We round-trip through Cocoa rather than using ImageIO directly
/// because NSBitmapImageRep is the standard idiomatic path on macOS
/// and gives us color-space handling for free.
fn sendImageResult(self: anytype, action: []const u8, cg_image: ?*anyopaque) !void {
    if (builtin.os.tag != .macos) return;
    const macos = @import("macos.zig");

    const NSBitmapImageRep = macos.getClass("NSBitmapImageRep");
    const rep = macos.msgSend1(macos.msgSend0(NSBitmapImageRep, "alloc"), "initWithCGImage:", @as(macos.objc.id, @ptrCast(@constCast(cg_image))));
    if (@intFromPtr(rep) == 0) {
        bridge_error.sendResultToJS(self.allocator, action, "{\"image\":null}");
        return;
    }

    // NSBitmapImageFileTypePNG = 4
    const Fn = *const fn (macos.objc.id, macos.objc.SEL, c_ulong, ?*anyopaque) callconv(.c) macos.objc.id;
    const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
    const png_data = f(rep, macos.sel("representationUsingType:properties:"), 4, null);
    if (@intFromPtr(png_data) == 0) {
        bridge_error.sendResultToJS(self.allocator, action, "{\"image\":null}");
        return;
    }

    const b64 = macos.msgSend1(png_data, "base64EncodedStringWithOptions:", @as(c_ulong, 0));
    const utf8 = macos.msgSend0(b64, "UTF8String");
    if (@intFromPtr(utf8) == 0) {
        bridge_error.sendResultToJS(self.allocator, action, "{\"image\":null}");
        return;
    }
    const slice = std.mem.span(@as([*:0]const u8, @ptrCast(utf8)));

    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(self.allocator);
    try buf.appendSlice(self.allocator, "{\"image\":\"data:image/png;base64,");
    try buf.appendSlice(self.allocator, slice);
    try buf.appendSlice(self.allocator, "\"}");
    const owned = try buf.toOwnedSlice(self.allocator);
    defer self.allocator.free(owned);
    bridge_error.sendResultToJS(self.allocator, action, owned);
}

fn appendWindowJson(allocator: std.mem.Allocator, buf: *std.ArrayListUnmanaged(u8), dict: @import("macos.zig").objc.id) !void {
    const macos = @import("macos.zig");

    const id_key = macos.createNSString("kCGWindowNumber");
    const name_key = macos.createNSString("kCGWindowName");
    const owner_key = macos.createNSString("kCGWindowOwnerName");

    const id_num = macos.msgSend1(dict, "objectForKey:", id_key);
    const name_str = macos.msgSend1(dict, "objectForKey:", name_key);
    const owner_str = macos.msgSend1(dict, "objectForKey:", owner_key);

    const win_id: c_ulong = blk: {
        if (@intFromPtr(id_num) == 0) break :blk 0;
        const Fn = *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) c_ulong;
        const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
        break :blk f(id_num, macos.sel("unsignedIntegerValue"));
    };

    var num_buf: [32]u8 = undefined;
    const id_str = try std.fmt.bufPrint(&num_buf, "{d}", .{win_id});

    try buf.appendSlice(allocator, "{\"id\":");
    try buf.appendSlice(allocator, id_str);
    try buf.appendSlice(allocator, ",\"name\":\"");
    appendNSStringEscaped(allocator, buf, name_str);
    try buf.appendSlice(allocator, "\",\"ownerName\":\"");
    appendNSStringEscaped(allocator, buf, owner_str);
    try buf.appendSlice(allocator, "\"}");
}

fn appendNSStringEscaped(allocator: std.mem.Allocator, buf: *std.ArrayListUnmanaged(u8), ns_str: @import("macos.zig").objc.id) void {
    if (@intFromPtr(ns_str) == 0) return;
    const macos = @import("macos.zig");
    const utf8 = macos.msgSend0(ns_str, "UTF8String");
    if (@intFromPtr(utf8) == 0) return;
    const slice = std.mem.span(@as([*:0]const u8, @ptrCast(utf8)));
    for (slice) |b| {
        switch (b) {
            '"' => buf.appendSlice(allocator, "\\\"") catch return,
            '\\' => buf.appendSlice(allocator, "\\\\") catch return,
            '\n' => buf.appendSlice(allocator, "\\n") catch return,
            '\r' => buf.appendSlice(allocator, "\\r") catch return,
            '\t' => buf.appendSlice(allocator, "\\t") catch return,
            else => buf.append(allocator, b) catch return,
        }
    }
}
