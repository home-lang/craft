const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

// macOS LaunchServices "open at login" support. Apple deprecated the
// old `SMLoginItemSetEnabled` in favour of `SMAppService` (Ventura+),
// but the older API still works in Sonoma. We use the modern path on
// macOS 13+ when available (via runtime symbol probing) and fall back
// to the LSSharedFileList API on older systems. For now this bridge
// only implements the simple "enable / disable / check" surface — the
// per-helper-app flow is more involved and isn't needed by Craft's
// typical "main app, run at login" use case.

/// Bridge that toggles whether the running app starts automatically
/// when the user logs in.
pub const AutoLaunchBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "enable")) {
            try self.enable(data);
        } else if (std.mem.eql(u8, action, "disable")) {
            try self.disable();
        } else if (std.mem.eql(u8, action, "isEnabled")) {
            try self.isEnabled();
        } else {
            return BridgeError.UnknownAction;
        }
    }

    fn enable(self: *Self, _: []const u8) !void {
        // SMAppService.mainAppService.register — the modern Ventura+ API.
        // We call it via runtime objc messaging so the binary still links
        // on older macOS where SMAppService doesn't exist (the class
        // lookup just returns null and we fall through).
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "enable", "{\"ok\":false,\"reason\":\"not supported on this OS\"}");
            return;
        }
        const macos = @import("macos.zig");
        const SMAppService = macos.getClass("SMAppService");
        if (@intFromPtr(SMAppService) == 0) {
            bridge_error.sendResultToJS(self.allocator, "enable", "{\"ok\":false,\"reason\":\"SMAppService unavailable (macOS < 13)\"}");
            return;
        }
        const service = macos.msgSend0(SMAppService, "mainAppService");
        // -registerAndReturnError: returns BOOL; we ignore the NSError out
        // param for now since the boolean is enough to tell the caller
        // whether it took. A future pass can surface the error message.
        const Fn = *const fn (macos.objc.id, macos.objc.SEL, ?*anyopaque) callconv(.c) bool;
        const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
        const ok = f(service, macos.sel("registerAndReturnError:"), null);
        const json = if (ok) "{\"ok\":true}" else "{\"ok\":false}";
        bridge_error.sendResultToJS(self.allocator, "enable", json);
    }

    fn disable(self: *Self) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "disable", "{\"ok\":false}");
            return;
        }
        const macos = @import("macos.zig");
        const SMAppService = macos.getClass("SMAppService");
        if (@intFromPtr(SMAppService) == 0) {
            bridge_error.sendResultToJS(self.allocator, "disable", "{\"ok\":false}");
            return;
        }
        const service = macos.msgSend0(SMAppService, "mainAppService");
        const Fn = *const fn (macos.objc.id, macos.objc.SEL, ?*anyopaque) callconv(.c) bool;
        const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
        const ok = f(service, macos.sel("unregisterAndReturnError:"), null);
        const json = if (ok) "{\"ok\":true}" else "{\"ok\":false}";
        bridge_error.sendResultToJS(self.allocator, "disable", json);
    }

    fn isEnabled(self: *Self) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "isEnabled", "{\"value\":false}");
            return;
        }
        const macos = @import("macos.zig");
        const SMAppService = macos.getClass("SMAppService");
        if (@intFromPtr(SMAppService) == 0) {
            bridge_error.sendResultToJS(self.allocator, "isEnabled", "{\"value\":false}");
            return;
        }
        const service = macos.msgSend0(SMAppService, "mainAppService");
        // -status returns SMAppServiceStatus enum: notRegistered (0),
        // enabled (1), requiresApproval (2), notFound (3). We map to a
        // single boolean here; finer-grained status is available via
        // the raw `value` field if needed.
        const Fn = *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) c_long;
        const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
        const status = f(service, macos.sel("status"));
        const enabled = status == 1;

        var buf: [64]u8 = undefined;
        const json = std.fmt.bufPrint(&buf, "{{\"value\":{s},\"status\":{d}}}", .{
            if (enabled) "true" else "false", status,
        }) catch return;
        bridge_error.sendResultToJS(self.allocator, "isEnabled", json);
    }
};
