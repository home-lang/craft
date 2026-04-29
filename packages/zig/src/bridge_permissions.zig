const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Bridge for runtime permission checks (camera, microphone, etc).
///
/// JS sends `{name: 'camera'}` etc. and receives `{status: 'granted' |
/// 'denied' | 'restricted' | 'undetermined' | 'not-supported'}`.
///
/// We do the AVCaptureDevice / CLLocationManager calls inline rather
/// than going through the rich `permissions.zig` module — the bridge
/// surface here is "is X granted right now" / "ask for X." Anything
/// fancier (delegates, multi-permission requests) belongs in the TS
/// layer where the call-site context is richer.
pub const PermissionsBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "check")) {
            try self.check(data);
        } else if (std.mem.eql(u8, action, "request")) {
            try self.request(data);
        } else if (std.mem.eql(u8, action, "openSettings")) {
            try self.openSettings(data);
        } else {
            return BridgeError.UnknownAction;
        }
    }

    fn check(self: *Self, data: []const u8) !void {
        const name = parseName(data) orelse {
            bridge_error.sendErrorToJS(self.allocator, "check", BridgeError.MissingData);
            return;
        };
        defer std.heap.c_allocator.free(name);
        const status = self.queryStatus(name);
        try sendStatus(self.allocator, "check", status);
    }

    fn request(self: *Self, data: []const u8) !void {
        const name = parseName(data) orelse {
            bridge_error.sendErrorToJS(self.allocator, "request", BridgeError.MissingData);
            return;
        };
        defer std.heap.c_allocator.free(name);
        // The TCC services that have an interactive prompt on macOS are
        // camera/mic/screen-recording/etc. For each we call the canonical
        // request API; the system shows its modal and (per Apple) caches
        // the choice. After the call returns we re-query for the new
        // status so the JS side gets the post-prompt value.
        if (builtin.os.tag == .macos) self.requestMacOS(name);
        const status = self.queryStatus(name);
        try sendStatus(self.allocator, "request", status);
    }

    fn openSettings(self: *Self, data: []const u8) !void {
        const name_opt = parseName(data);
        defer if (name_opt) |n| std.heap.c_allocator.free(n);
        const name: []const u8 = name_opt orelse "";

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            const NSWorkspace = macos.getClass("NSWorkspace");
            const ws = macos.msgSend0(NSWorkspace, "sharedWorkspace");

            // Build the right Privacy pane URL for the named permission.
            // x-apple.systempreferences URLs jump straight to the listed
            // section, which is what apps normally want.
            const url_str = anchorURL(name);
            const NSURL = macos.getClass("NSURL");
            const ns_url_str = macos.createNSString(url_str);
            const url = macos.msgSend1(NSURL, "URLWithString:", ns_url_str);
            _ = macos.msgSend1(ws, "openURL:", url);
        }

        bridge_error.sendResultToJS(self.allocator, "openSettings", "{\"ok\":true}");
    }

    fn queryStatus(_: *Self, name: []const u8) []const u8 {
        if (builtin.os.tag != .macos) return "not-supported";
        const macos = @import("macos.zig");

        // Camera / microphone use AVCaptureDevice authorizationStatusForMediaType:
        // returning AVAuthorizationStatus (notDetermined=0, restricted=1,
        // denied=2, authorized=3).
        if (std.mem.eql(u8, name, "camera") or std.mem.eql(u8, name, "microphone")) {
            const AVCaptureDevice = macos.getClass("AVCaptureDevice");
            if (@intFromPtr(AVCaptureDevice) == 0) return "not-supported";
            const media_type = if (std.mem.eql(u8, name, "camera")) "vide" else "soun";
            const ns_type = macos.createNSString(media_type);
            const Fn = *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id) callconv(.c) c_long;
            const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
            const status = f(AVCaptureDevice, macos.sel("authorizationStatusForMediaType:"), ns_type);
            return mapAVStatus(status);
        }

        return "not-supported";
    }

    fn requestMacOS(_: *Self, name: []const u8) void {
        if (builtin.os.tag != .macos) return;
        const macos = @import("macos.zig");

        if (std.mem.eql(u8, name, "camera") or std.mem.eql(u8, name, "microphone")) {
            const AVCaptureDevice = macos.getClass("AVCaptureDevice");
            if (@intFromPtr(AVCaptureDevice) == 0) return;
            const media_type = if (std.mem.eql(u8, name, "camera")) "vide" else "soun";
            const ns_type = macos.createNSString(media_type);
            // -requestAccessForMediaType:completionHandler: takes a
            // (^block)(BOOL) — passing nil is documented as undefined
            // behavior and crashes on some macOS releases. We synthesize
            // a static no-op block via the standard 5-field block layout
            // (isa, flags, reserved, invoke, descriptor) that AppKit can
            // dispatch into safely. Status is re-queried in request()
            // so we don't need the block to do anything substantive.
            const Fn = *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id, *const anyopaque) callconv(.c) void;
            const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
            f(AVCaptureDevice, macos.sel("requestAccessForMediaType:completionHandler:"), ns_type, &noop_block);
        }
    }
};

// =============================================================================
// Tiny no-op block we hand to AVCaptureDevice's completionHandler.
//
// The block ABI on macOS lays out: { isa, flags, reserved, invoke, desc }.
// `_NSConcreteStackBlock` is the symbol Apple resolves blocks against;
// linking to it lets us hand a "real" block to `requestAccess…` without
// bringing in the libBlocksRuntime helpers.
// =============================================================================

const BlockLayout = extern struct {
    isa: ?*anyopaque,
    flags: c_int,
    reserved: c_int,
    invoke: *const fn (*const anyopaque, bool) callconv(.c) void,
    descriptor: *const BlockDescriptor,
};

const BlockDescriptor = extern struct {
    reserved: usize = 0,
    size: usize,
};

extern var _NSConcreteStackBlock: anyopaque;

fn noop_invoke(_: *const anyopaque, _: bool) callconv(.c) void {}

const noop_descriptor = BlockDescriptor{ .size = @sizeOf(BlockLayout) };
const noop_block = BlockLayout{
    .isa = &_NSConcreteStackBlock,
    .flags = 0,
    .reserved = 0,
    .invoke = noop_invoke,
    .descriptor = &noop_descriptor,
};

fn parseName(data: []const u8) ?[]const u8 {
    // Earlier we used `indexOf("\"name\":\"")` + `indexOfPos(start, "\"")`
    // which breaks on escaped quotes (e.g. `{"name":"a\"b"}`) and on
    // payloads where `name` appears as a value before the real key. Use
    // the JSON parser directly. The slice we return points into `data`,
    // which is freed by the dispatcher AFTER handleMessage returns —
    // safe for our caller's read-only use.
    const ParseShape = struct { name: []const u8 = "" };
    const allocator = std.heap.c_allocator;
    const parsed = std.json.parseFromSlice(ParseShape, allocator, data, .{
        .ignore_unknown_fields = true,
    }) catch return null;
    defer parsed.deinit();
    if (parsed.value.name.len == 0) return null;
    // The parsed string is owned by `parsed.arena`; copy for the caller
    // since we deinit on return. Caller only uses synchronously, so a
    // small buffer-backed copy via std.mem.span isn't possible — we
    // dupe and accept the leak (1 extra allocation per call for a
    // fixed-size permission name).
    return allocator.dupe(u8, parsed.value.name) catch null;
}

fn mapAVStatus(status: c_long) []const u8 {
    return switch (status) {
        0 => "undetermined",
        1 => "restricted",
        2 => "denied",
        3 => "granted",
        else => "undetermined",
    };
}

fn sendStatus(allocator: std.mem.Allocator, action: []const u8, status: []const u8) !void {
    var buf: [128]u8 = undefined;
    const json = try std.fmt.bufPrint(&buf, "{{\"status\":\"{s}\"}}", .{status});
    bridge_error.sendResultToJS(allocator, action, json);
}

fn anchorURL(name: []const u8) []const u8 {
    if (std.mem.eql(u8, name, "camera"))
        return "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera";
    if (std.mem.eql(u8, name, "microphone"))
        return "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone";
    if (std.mem.eql(u8, name, "screen_recording"))
        return "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture";
    if (std.mem.eql(u8, name, "accessibility"))
        return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
    if (std.mem.eql(u8, name, "full_disk_access"))
        return "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles";
    if (std.mem.eql(u8, name, "input_monitoring"))
        return "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent";
    return "x-apple.systempreferences:com.apple.preference.security?Privacy";
}
