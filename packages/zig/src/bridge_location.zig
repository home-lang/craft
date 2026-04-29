const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// CoreLocation bridge.
///
/// macOS lazily creates a singleton `CLLocationManager` on first use and
/// installs a delegate class via the objc runtime. Location samples are
/// pushed to JS as `craft:location:update` events; authorization
/// changes are pushed as `craft:location:authChanged`.
///
/// Apps must declare `NSLocationUsageDescription` (or the macOS-specific
/// keys) in `Info.plist` for the system prompt to render — without it
/// `requestPermission` silently returns "denied."
pub const LocationBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(_: *Self) void {}

    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        ensureManager();
        if (std.mem.eql(u8, action, "requestPermission")) try self.requestPermission(data)
        else if (std.mem.eql(u8, action, "getAuthorization")) try self.getAuthorization()
        else if (std.mem.eql(u8, action, "getCurrentLocation")) try self.getCurrentLocation()
        else if (std.mem.eql(u8, action, "startWatching")) try self.startWatching(data)
        else if (std.mem.eql(u8, action, "stopWatching")) try self.stopWatching()
        else return BridgeError.UnknownAction;
    }

    fn requestPermission(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "requestPermission", "{\"status\":\"not-supported\"}");
            return;
        }
        const ParseShape = struct { mode: []const u8 = "whenInUse" };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();

        const macos = @import("macos.zig");
        const sel_name: [*:0]const u8 = if (std.mem.eql(u8, parsed.value.mode, "always"))
            "requestAlwaysAuthorization"
        else
            "requestWhenInUseAuthorization";
        _ = macos.msgSend0(manager, sel_name);

        // Authorization is async — the delegate callback will fire
        // craft:location:authChanged. Resolve the JS promise with the
        // current (still-pending in many cases) status.
        const status = currentAuthorizationString();
        try sendStatusResult(self.allocator, "requestPermission", status);
    }

    fn getAuthorization(self: *Self) !void {
        const status = currentAuthorizationString();
        try sendStatusResult(self.allocator, "getAuthorization", status);
    }

    fn getCurrentLocation(self: *Self) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "getCurrentLocation", "{\"location\":null}");
            return;
        }
        const macos = @import("macos.zig");
        // `-requestLocation` delivers a single update via the delegate
        // — the JS promise resolves immediately so the caller can
        // subscribe to `craft:location:update` for the actual value.
        _ = macos.msgSend0(manager, "requestLocation");
        bridge_error.sendResultToJS(self.allocator, "getCurrentLocation", "{\"requested\":true}");
    }

    fn startWatching(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "startWatching", "{\"ok\":false}");
            return;
        }
        const ParseShape = struct {
            // Significant-change vs continuous. Default to continuous
            // (more accurate, costs more battery — apps that need
            // the cheap mode opt in explicitly).
            mode: []const u8 = "continuous",
            distanceFilter: ?f64 = null,
        };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();

        const macos = @import("macos.zig");
        if (parsed.value.distanceFilter) |df| {
            _ = macos.msgSend1Double(manager, "setDistanceFilter:", df);
        }
        if (std.mem.eql(u8, parsed.value.mode, "significant")) {
            _ = macos.msgSend0(manager, "startMonitoringSignificantLocationChanges");
        } else {
            _ = macos.msgSend0(manager, "startUpdatingLocation");
        }
        bridge_error.sendResultToJS(self.allocator, "startWatching", "{\"ok\":true}");
    }

    fn stopWatching(self: *Self) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "stopWatching", "{\"ok\":true}");
            return;
        }
        const macos = @import("macos.zig");
        _ = macos.msgSend0(manager, "stopUpdatingLocation");
        _ = macos.msgSend0(manager, "stopMonitoringSignificantLocationChanges");
        bridge_error.sendResultToJS(self.allocator, "stopWatching", "{\"ok\":true}");
    }
};

// =============================================================================
// CLLocationManager + delegate
// =============================================================================

var manager_installed: bool = false;
var manager: @import("macos.zig").objc.id = null;
var delegate_instance: @import("macos.zig").objc.id = null;

fn ensureManager() void {
    if (manager_installed) return;
    if (builtin.target.os.tag != .macos) return;

    const macos = @import("macos.zig");
    const objc = macos.objc;

    const NSObject = macos.getClass("NSObject");
    const class_name = "CraftLocationDelegate";
    var cls = objc.objc_getClass(class_name);
    if (cls == null) {
        cls = objc.objc_allocateClassPair(NSObject, class_name, 0);
        if (cls == null) return;
        addMethod(cls, "locationManager:didUpdateLocations:", &didUpdateLocations);
        addMethod(cls, "locationManager:didFailWithError:", &didFailWithError);
        addMethod(cls, "locationManager:didChangeAuthorizationStatus:", &didChangeAuthorizationStatus);
        objc.objc_registerClassPair(cls);
    }
    delegate_instance = macos.msgSend0(macos.msgSend0(cls, "alloc"), "init");

    const CLLocationManager = macos.getClass("CLLocationManager");
    if (@intFromPtr(CLLocationManager) == 0) return;
    manager = macos.msgSend0(macos.msgSend0(CLLocationManager, "alloc"), "init");
    _ = macos.msgSend1(manager, "setDelegate:", delegate_instance);

    manager_installed = true;
}

fn addMethod(cls: @import("macos.zig").objc.Class, sel_name: [*:0]const u8, imp: *const anyopaque) void {
    const macos = @import("macos.zig");
    _ = macos.objc.class_addMethod(cls, macos.sel(sel_name), @ptrCast(@constCast(imp)), "v@:@@");
}

export fn didUpdateLocations(
    _: @import("macos.zig").objc.id,
    _: @import("macos.zig").objc.SEL,
    _: @import("macos.zig").objc.id,
    locations: @import("macos.zig").objc.id,
) callconv(.c) void {
    const macos = @import("macos.zig");
    if (@intFromPtr(locations) == 0) return;

    // Take the most recent CLLocation; CLLocationManager hands them in
    // chronological order, last-most-recent. Apps that need the full
    // batch should subscribe to the raw delegate themselves.
    const Fn = *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) c_ulong;
    const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
    const count = f(locations, macos.sel("count"));
    if (count == 0) return;
    const loc = macos.msgSend1(locations, "objectAtIndex:", count - 1);

    // -coordinate returns CLLocationCoordinate2D = {f64 lat, f64 lng}.
    // On arm64 small struct returns (≤16 bytes) go through the regular
    // objc_msgSend; the *_stret variant only exists on x86_64 and
    // doesn't even link on arm targets. Cast to the plain symbol so
    // the binary stays portable across architectures.
    const Coord = extern struct { latitude: f64, longitude: f64 };
    const CoordFn = *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) Coord;
    const cf: CoordFn = @ptrCast(&macos.objc.objc_msgSend);
    const coord = cf(loc, macos.sel("coordinate"));

    const altitude = macos.msgSend0Double(loc, "altitude");
    const h_acc = macos.msgSend0Double(loc, "horizontalAccuracy");
    const v_acc = macos.msgSend0Double(loc, "verticalAccuracy");
    const speed = macos.msgSend0Double(loc, "speed");

    var buf: [512]u8 = undefined;
    const detail = std.fmt.bufPrint(&buf,
        "{{\"latitude\":{d},\"longitude\":{d},\"altitude\":{d}," ++
        "\"horizontalAccuracy\":{d},\"verticalAccuracy\":{d},\"speed\":{d}}}",
        .{ coord.latitude, coord.longitude, altitude, h_acc, v_acc, speed }) catch return;
    fireEvent("craft:location:update", detail);
}

export fn didFailWithError(
    _: @import("macos.zig").objc.id,
    _: @import("macos.zig").objc.SEL,
    _: @import("macos.zig").objc.id,
    err: @import("macos.zig").objc.id,
) callconv(.c) void {
    const macos = @import("macos.zig");
    if (@intFromPtr(err) == 0) return;
    const desc = macos.msgSend0(err, "localizedDescription");
    if (@intFromPtr(desc) == 0) return;
    const utf8 = macos.msgSend0(desc, "UTF8String");
    if (@intFromPtr(utf8) == 0) return;
    const msg = std.mem.span(@as([*:0]const u8, @ptrCast(utf8)));

    var buf: [1024]u8 = undefined;
    const detail = std.fmt.bufPrint(&buf, "{{\"message\":\"{s}\"}}", .{msg}) catch return;
    fireEvent("craft:location:error", detail);
}

export fn didChangeAuthorizationStatus(
    _: @import("macos.zig").objc.id,
    _: @import("macos.zig").objc.SEL,
    _: @import("macos.zig").objc.id,
    status: c_long,
) callconv(.c) void {
    const status_str = mapAuthStatus(status);
    var buf: [128]u8 = undefined;
    const detail = std.fmt.bufPrint(&buf, "{{\"status\":\"{s}\"}}", .{status_str}) catch return;
    fireEvent("craft:location:authChanged", detail);
}

fn currentAuthorizationString() []const u8 {
    if (builtin.target.os.tag != .macos) return "not-supported";
    const macos = @import("macos.zig");
    const CLLocationManager = macos.getClass("CLLocationManager");
    const Fn = *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) c_long;
    const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
    const status = f(CLLocationManager, macos.sel("authorizationStatus"));
    return mapAuthStatus(status);
}

fn mapAuthStatus(status: c_long) []const u8 {
    return switch (status) {
        0 => "undetermined",
        1, 2 => "restricted-or-denied", // restricted=1, denied=2
        3 => "authorizedAlways",
        4 => "authorizedWhenInUse",
        else => "unknown",
    };
}

fn sendStatusResult(allocator: std.mem.Allocator, action: []const u8, status: []const u8) !void {
    var buf: [128]u8 = undefined;
    const json = try std.fmt.bufPrint(&buf, "{{\"status\":\"{s}\"}}", .{status});
    bridge_error.sendResultToJS(allocator, action, json);
}

fn fireEvent(name: []const u8, detail_json: []const u8) void {
    const macos = @import("macos.zig");
    const webview = macos.getGlobalWebView() orelse return;

    var script: std.ArrayListUnmanaged(u8) = .empty;
    defer script.deinit(std.heap.c_allocator);
    script.appendSlice(std.heap.c_allocator,
        "if (window.dispatchEvent) window.dispatchEvent(new CustomEvent('") catch return;
    script.appendSlice(std.heap.c_allocator, name) catch return;
    script.appendSlice(std.heap.c_allocator, "', { detail: ") catch return;
    script.appendSlice(std.heap.c_allocator, detail_json) catch return;
    script.appendSlice(std.heap.c_allocator, " }));") catch return;
    script.append(std.heap.c_allocator, 0) catch return;

    const NSString = macos.getClass("NSString");
    const js = macos.msgSend1(NSString, "stringWithUTF8String:", @as([*:0]const u8, @ptrCast(script.items.ptr)));
    _ = macos.msgSend2(webview, "evaluateJavaScript:completionHandler:", js, @as(?*anyopaque, null));
}
