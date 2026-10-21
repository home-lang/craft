//! Chrome tab capture has no CoreGraphics sharing window. Its native
//! accessibility window title includes a browser-owned sharing suffix.
//! Read only that surface, with the user's Accessibility grant, on a worker.
const std = @import("std");
const builtin = @import("builtin");
const detect = @import("screen_sharing.zig");

pub fn matches(bundle_id: []const u8, title: []const u8) bool {
    if (!std.mem.eql(u8, bundle_id, "com.google.Chrome")) return false;
    const suffix = " - Tab content shared - Google Chrome";
    return title.len >= suffix.len and detect.containsIgnoreCase(title[title.len - suffix.len ..], suffix);
}

/// The caller supplies an autorelease pool and runs off AppKit's main thread.
/// A stalled browser gets a short IPC timeout and cannot stall other UI work.
pub fn visit(context: anytype, comptime onWindow: anytype) !void {
    if (comptime builtin.os.tag != .macos) return;
    if (!AXIsProcessTrusted()) return;
    const macos = @import("macos.zig");
    const io = @import("io_context.zig").get();
    const deadline = std.Io.Clock.awake.now(io).nanoseconds + 750 * std.time.ns_per_ms;
    const workspace = macos.msgSend0(macos.getClass("NSWorkspace"), "sharedWorkspace");
    const apps = macos.msgSend0(workspace, "runningApplications");
    const Count = *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) c_ulong;
    const count: Count = @ptrCast(&macos.objc.objc_msgSend);
    const Pid = *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) c_int;
    const pid: Pid = @ptrCast(&macos.objc.objc_msgSend);
    var index: c_ulong = 0;
    while (index < count(apps, macos.sel("count"))) : (index += 1) {
        if (std.Io.Clock.awake.now(io).nanoseconds >= deadline) break;
        const app = macos.msgSend1(apps, "objectAtIndex:", index);
        const bundle_id = string(macos.msgSend0(app, "bundleIdentifier")) orelse continue;
        if (!std.mem.eql(u8, bundle_id, "com.google.Chrome")) continue;
        const element = AXUIElementCreateApplication(pid(app, macos.sel("processIdentifier"))) orelse continue;
        defer CFRelease(element);
        _ = AXUIElementSetMessagingTimeout(element, 0.05);
        var windows: ?*anyopaque = null;
        if (AXUIElementCopyAttributeValue(element, macos.createNSString("AXWindows"), &windows) != 0 or windows == null) continue;
        defer CFRelease(windows);
        const length = @min(CFArrayGetCount(windows), 128);
        var window_index: c_long = 0;
        while (window_index < length) : (window_index += 1) {
            if (std.Io.Clock.awake.now(io).nanoseconds >= deadline) break;
            const window = CFArrayGetValueAtIndex(windows, window_index) orelse continue;
            _ = AXUIElementSetMessagingTimeout(window, 0.05);
            var title: ?*anyopaque = null;
            if (AXUIElementCopyAttributeValue(window, macos.createNSString("AXTitle"), &title) != 0 or title == null) continue;
            defer CFRelease(title);
            const text = string(title) orelse continue;
            if (matches(bundle_id, text)) try onWindow(context, "Google Chrome", text);
        }
    }
}

fn string(value: ?*anyopaque) ?[]const u8 {
    if (value == null) return null;
    const macos = @import("macos.zig");
    const utf8 = macos.msgSend0(value, "UTF8String");
    if (utf8 == null) return null;
    return std.mem.span(@as([*:0]const u8, @ptrCast(utf8)));
}

extern "c" fn AXIsProcessTrusted() bool;
extern "c" fn AXUIElementCreateApplication(pid: c_int) ?*anyopaque;
extern "c" fn AXUIElementSetMessagingTimeout(element: ?*anyopaque, timeout: f32) c_int;
extern "c" fn AXUIElementCopyAttributeValue(element: ?*anyopaque, attribute: ?*anyopaque, value: *?*anyopaque) c_int;
extern "c" fn CFArrayGetCount(array: ?*anyopaque) c_long;
extern "c" fn CFArrayGetValueAtIndex(array: ?*anyopaque, index: c_long) ?*anyopaque;
extern "c" fn CFRelease(value: ?*anyopaque) void;

test "tab capture requires Chrome's native sharing suffix" {
    try std.testing.expect(matches("com.google.Chrome", "Hush capture check - Tab content shared - Google Chrome"));
    try std.testing.expect(!matches("com.google.Chrome", "Tab content shared - Google Chrome"));
    try std.testing.expect(!matches("com.google.Chrome", "Hush capture check - Google Chrome"));
    try std.testing.expect(!matches("com.apple.TextEdit", "Hush capture check - Tab content shared - Google Chrome"));
    try std.testing.expect(!matches("com.google.Chrome", "Hush capture check - Tab content shared - Google Chrome Notes"));
}
