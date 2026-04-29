const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Continuity Camera — using an iPhone (or other paired iOS device)
/// as a webcam for the Mac.
///
/// Detection works through `AVCaptureDevice.devicesWithMediaType:`
/// for AVMediaTypeVideo plus filtering by `transportType` ==
/// kIOAudioDeviceTransportTypeContinuityCaptureWired (or wireless).
/// The list is what apps need to populate "choose camera" UIs.
///
/// Streaming itself is the standard `AVCaptureSession` flow; apps
/// already integrating AVFoundation pick up Continuity cameras
/// automatically once the user enables it in Settings → General →
/// AirPlay & Handoff. We expose `listCameras()` so app UIs can
/// filter / surface them; binding the actual capture is the app's
/// responsibility (or the standard `getUserMedia()` Web flow).
pub const ContinuityCameraBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(_: *Self) void {}

    pub fn handleMessage(self: *Self, action: []const u8, _: []const u8) !void {
        if (std.mem.eql(u8, action, "listCameras")) try self.listCameras()
        else return BridgeError.UnknownAction;
    }

    fn listCameras(self: *Self) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "listCameras", "{\"cameras\":[]}");
            return;
        }
        const macos = @import("macos.zig");
        const AVCaptureDevice = macos.getClass("AVCaptureDevice");
        if (@intFromPtr(AVCaptureDevice) == 0) {
            bridge_error.sendResultToJS(self.allocator, "listCameras", "{\"cameras\":[]}");
            return;
        }

        // AVMediaTypeVideo = "vide" (FourCC). devicesWithMediaType: was
        // deprecated in 10.15 in favor of AVCaptureDeviceDiscoverySession,
        // but it's still valid and returns the same content; the new
        // session adds change-notification support which we don't need
        // for a one-shot enumeration.
        const media_type = macos.createNSString("vide");
        const devices = macos.msgSend1(AVCaptureDevice, "devicesWithMediaType:", media_type);
        if (@intFromPtr(devices) == 0) {
            bridge_error.sendResultToJS(self.allocator, "listCameras", "{\"cameras\":[]}");
            return;
        }

        const Fn = *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) c_ulong;
        const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
        const count = f(devices, macos.sel("count"));

        var buf: std.ArrayListUnmanaged(u8) = .empty;
        defer buf.deinit(self.allocator);
        try buf.appendSlice(self.allocator, "{\"cameras\":[");

        var i: c_ulong = 0;
        while (i < count) : (i += 1) {
            if (i > 0) try buf.append(self.allocator, ',');
            const device = macos.msgSend1(devices, "objectAtIndex:", i);
            try appendCamera(self.allocator, &buf, device);
        }
        try buf.appendSlice(self.allocator, "]}");

        const owned = try buf.toOwnedSlice(self.allocator);
        defer self.allocator.free(owned);
        bridge_error.sendResultToJS(self.allocator, "listCameras", owned);
    }
};

fn appendCamera(allocator: std.mem.Allocator, buf: *std.ArrayListUnmanaged(u8), device: @import("macos.zig").objc.id) !void {
    const macos = @import("macos.zig");

    try buf.append(allocator, '{');
    try buf.appendSlice(allocator, "\"id\":\"");
    appendNSStringEscaped(allocator, buf, macos.msgSend0(device, "uniqueID"));
    try buf.appendSlice(allocator, "\",\"name\":\"");
    appendNSStringEscaped(allocator, buf, macos.msgSend0(device, "localizedName"));
    try buf.appendSlice(allocator, "\",\"manufacturer\":\"");
    appendNSStringEscaped(allocator, buf, macos.msgSend0(device, "manufacturer"));
    try buf.appendSlice(allocator, "\",\"isContinuity\":");

    // -[AVCaptureDevice transportType] returns FourCC. The Continuity
    // Camera transport type is `'cont'` (0x636F6E74). Devices added
    // via Continuity show that transport; built-in cameras show
    // `'bltn'` (built-in), USB ones show `'usb '`, etc.
    const Fn = *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) c_uint;
    const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
    const transport = f(device, macos.sel("transportType"));
    const continuity_fourcc: c_uint = 0x636F6E74; // 'cont'
    try buf.appendSlice(allocator, if (transport == continuity_fourcc) "true" else "false");

    try buf.append(allocator, '}');
}

fn appendNSStringEscaped(allocator: std.mem.Allocator, buf: *std.ArrayListUnmanaged(u8), ns_string: @import("macos.zig").objc.id) void {
    if (@intFromPtr(ns_string) == 0) return;
    const macos = @import("macos.zig");
    const utf8 = macos.msgSend0(ns_string, "UTF8String");
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
