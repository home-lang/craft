//! Native deadlines for hidden WebKit pages. All state belongs to the main loop.
//! Timers own their reply routes rather than occupying the shared async pool.
const std = @import("std");
const builtin = @import("builtin");
const errors = @import("bridge_error.zig");
const request = @import("request_context.zig");
const page = @import("window_context.zig");
const activity = @import("background_activity.zig");
const objc = @import("objc_runtime.zig").objc;

const capacity = 256;
const Entry = struct {
    timer: objc.id,
    activity: objc.id,
    window: usize,
    webview: usize,
    request_id: u64,
    client_id: u64,
};
var entries: [capacity]?Entry = @splat(null);
var generations: [capacity]u32 = @splat(0);
var target: objc.id = null;

pub fn handleMessage(allocator: std.mem.Allocator, action: []const u8, data: []const u8) void {
    dispatch(allocator, action, data) catch |err| {
        const code: errors.BridgeError = switch (@as(anyerror, err)) {
            error.InvalidJSON => error.InvalidJSON,
            error.InvalidParameter => error.InvalidParameter,
            error.Busy => error.Busy,
            error.PlatformNotSupported => error.PlatformNotSupported,
            else => error.NativeCallFailed,
        };
        errors.sendErrorToJS(allocator, action, code);
    };
}

fn dispatch(allocator: std.mem.Allocator, action: []const u8, data: []const u8) !void {
    if (comptime builtin.os.tag != .macos) return error.PlatformNotSupported;
    const owner = page.currentWebView() orelse return error.InvalidParameter;
    if (std.mem.eql(u8, action, "cancelAll")) {
        forgetWebView(owner);
        errors.sendResultToJS(allocator, action, "{\"ok\":true}");
        return;
    }
    const Params = struct { timerId: u64, delayMs: u32 = 0 };
    const parsed = std.json.parseFromSlice(Params, allocator, data, .{}) catch return error.InvalidJSON;
    defer parsed.deinit();
    const params = parsed.value;
    if (params.timerId == 0 or params.timerId > 9007199254740991 or params.delayMs > 86_400_000) return error.InvalidParameter;
    if (std.mem.eql(u8, action, "cancel")) {
        var cancelled = false;
        for (entries, 0..) |entry, index| {
            if (entry) |value| {
                if (value.webview == owner and value.client_id == params.timerId) {
                    finish(index, false, true);
                    cancelled = true;
                    break;
                }
            }
        }
        errors.sendResultToJS(allocator, action, if (cancelled) "{\"cancelled\":true}" else "{\"cancelled\":false}");
        return;
    }
    if (!std.mem.eql(u8, action, "sleep")) return error.InvalidParameter;
    const request_id = request.current() orelse return error.InvalidParameter;
    var available: ?usize = null;
    for (entries, 0..) |entry, index| {
        if (entry) |value| {
            if (value.webview == owner and value.client_id == params.timerId) return error.InvalidParameter;
        } else if (available == null) available = index;
    }
    const index = available orelse return error.Busy;
    const macos = @import("macos.zig");
    if (target == null) {
        var cls = objc.objc_getClass("CraftBackgroundTimer");
        if (cls == null) {
            cls = objc.objc_allocateClassPair(macos.getClass("NSObject"), "CraftBackgroundTimer", 0);
            if (cls == null) return error.NativeCallFailed;
            _ = objc.class_addMethod(cls, macos.sel("onTimer:"), @ptrCast(@constCast(&onTimer)), "v@:@");
            objc.objc_registerClassPair(cls);
        }
        target = macos.msgSend0(macos.msgSend0(cls, "alloc"), "init");
        if (target == null) return error.NativeCallFailed;
    }
    generations[index] +%= 1;
    const key = (@as(u64, generations[index]) << 8) | index;
    const info = macos.msgSend1(macos.getClass("NSNumber"), "numberWithUnsignedLongLong:", key);
    const Create = *const fn (objc.id, objc.SEL, f64, objc.id, objc.SEL, objc.id, bool) callconv(.c) objc.id;
    const create: Create = @ptrCast(&objc.objc_msgSend);
    const timer = create(macos.getClass("NSTimer"), macos.sel("timerWithTimeInterval:target:selector:userInfo:repeats:"), @max(0.000001, @as(f64, @floatFromInt(params.delayMs)) / 1000.0), target, macos.sel("onTimer:"), info, false);
    if (timer == null) return error.NativeCallFailed;
    _ = macos.msgSend0(timer, "retain");
    _ = macos.msgSend0(@as(objc.id, @ptrFromInt(owner)), "retain");
    entries[index] = .{
        .timer = timer,
        .activity = activity.begin("Complete a background deadline requested by the application"),
        .window = page.current() orelse 0,
        .webview = owner,
        .request_id = request_id,
        .client_id = params.timerId,
    };
    const run_loop = macos.msgSend0(macos.getClass("NSRunLoop"), "mainRunLoop");
    _ = macos.msgSend2(run_loop, "addTimer:forMode:", timer, macos.createNSString("kCFRunLoopCommonModes"));
}

fn onTimer(_: objc.id, _: objc.SEL, timer: objc.id) callconv(.c) void {
    const macos = @import("macos.zig");
    const info = macos.msgSend0(timer, "userInfo");
    const Read = *const fn (objc.id, objc.SEL) callconv(.c) u64;
    const read: Read = @ptrCast(&objc.objc_msgSend);
    const key = read(info, macos.sel("unsignedLongLongValue"));
    const index: usize = @intCast(key & 255);
    if (entries[index] == null or generations[index] != key >> 8) return;
    finish(index, true, true);
}

fn finish(index: usize, fired: bool, deliver: bool) void {
    const entry = entries[index] orelse return;
    entries[index] = null;
    const macos = @import("macos.zig");
    defer _ = macos.msgSend0(entry.timer, "release");
    defer _ = macos.msgSend0(@as(objc.id, @ptrFromInt(entry.webview)), "release");
    defer activity.end(entry.activity);
    _ = macos.msgSend0(entry.timer, "invalidate");
    if (deliver) {
        request.push(entry.request_id);
        defer request.pop();
        page.push(entry.window, entry.webview);
        defer page.pop();
        errors.sendResultToJS(std.heap.c_allocator, "sleep", if (fired) "{\"fired\":true}" else "{\"fired\":false}");
    }
}

/// Navigation/destruction discards callbacks belonging to the previous page.
pub fn forgetWebView(webview: usize) void {
    if (comptime builtin.os.tag != .macos) return;
    for (entries, 0..) |entry, index| {
        if (entry) |value| if (value.webview == webview) finish(index, false, false);
    }
}
