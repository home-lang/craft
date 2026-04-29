const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Biometric authentication via LocalAuthentication framework.
///
///   - `isAvailable()`           — `LAContext canEvaluatePolicy:error:`
///   - `getBiometryType()`       — touchID / faceID / opticID / none
///   - `evaluate(reason, opts)`  — present the system prompt and resolve
///                                 with `{success, errorCode?, errorMessage?}`
///
/// Apps must declare `NSFaceIDUsageDescription` in `Info.plist` for the
/// system prompt to render — required when the device supports FaceID.
/// Without it, evaluate() fails immediately with a permissions error.
pub const BiometricBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(_: *Self) void {}

    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "isAvailable")) try self.isAvailable()
        else if (std.mem.eql(u8, action, "getBiometryType")) try self.getBiometryType()
        else if (std.mem.eql(u8, action, "evaluate")) try self.evaluate(data)
        else return BridgeError.UnknownAction;
    }

    fn isAvailable(self: *Self) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "isAvailable", "{\"value\":false}");
            return;
        }
        const macos = @import("macos.zig");
        const LAContext = macos.getClass("LAContext");
        if (@intFromPtr(LAContext) == 0) {
            bridge_error.sendResultToJS(self.allocator, "isAvailable", "{\"value\":false}");
            return;
        }
        const ctx = macos.msgSend0(macos.msgSend0(LAContext, "alloc"), "init");
        // LAPolicyDeviceOwnerAuthenticationWithBiometrics = 1
        const Fn = *const fn (macos.objc.id, macos.objc.SEL, c_long, ?*anyopaque) callconv(.c) bool;
        const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
        const ok = f(ctx, macos.sel("canEvaluatePolicy:error:"), 1, null);
        const json = if (ok) "{\"value\":true}" else "{\"value\":false}";
        bridge_error.sendResultToJS(self.allocator, "isAvailable", json);
        _ = macos.msgSend0(ctx, "release");
    }

    fn getBiometryType(self: *Self) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "getBiometryType", "{\"type\":\"none\"}");
            return;
        }
        const macos = @import("macos.zig");
        const LAContext = macos.getClass("LAContext");
        if (@intFromPtr(LAContext) == 0) {
            bridge_error.sendResultToJS(self.allocator, "getBiometryType", "{\"type\":\"none\"}");
            return;
        }
        const ctx = macos.msgSend0(macos.msgSend0(LAContext, "alloc"), "init");
        defer _ = macos.msgSend0(ctx, "release");
        // canEvaluatePolicy: must be called once for biometryType to be valid.
        const Fn = *const fn (macos.objc.id, macos.objc.SEL, c_long, ?*anyopaque) callconv(.c) bool;
        const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
        _ = f(ctx, macos.sel("canEvaluatePolicy:error:"), 1, null);

        // -biometryType returns LABiometryType enum:
        //   0=none, 1=touchID, 2=faceID, 3=opticID (visionOS)
        const TypeFn = *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) c_long;
        const tf: TypeFn = @ptrCast(&macos.objc.objc_msgSend);
        const t = tf(ctx, macos.sel("biometryType"));
        const type_str: []const u8 = switch (t) {
            1 => "touchID",
            2 => "faceID",
            3 => "opticID",
            else => "none",
        };
        var buf: [64]u8 = undefined;
        const json = try std.fmt.bufPrint(&buf, "{{\"type\":\"{s}\"}}", .{type_str});
        bridge_error.sendResultToJS(self.allocator, "getBiometryType", json);
    }

    fn evaluate(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "evaluate", "{\"success\":false,\"reason\":\"not supported\"}");
            return;
        }
        const ParseShape = struct {
            reason: []const u8 = "Authenticate to continue",
            // Allow falling back to passcode when biometrics aren't
            // available or have failed too many times.
            allowPasscodeFallback: bool = false,
        };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        if (parsed.value.reason.len == 0) return BridgeError.MissingData;

        const macos = @import("macos.zig");
        const LAContext = macos.getClass("LAContext");
        if (@intFromPtr(LAContext) == 0) {
            bridge_error.sendResultToJS(self.allocator, "evaluate", "{\"success\":false}");
            return;
        }
        const ctx = macos.msgSend0(macos.msgSend0(LAContext, "alloc"), "init");

        const reason_ns = macos.createNSString(parsed.value.reason);

        // LAPolicyDeviceOwnerAuthentication = 2 (biometrics + passcode)
        // LAPolicyDeviceOwnerAuthenticationWithBiometrics = 1 (biometrics only)
        const policy: c_long = if (parsed.value.allowPasscodeFallback) 2 else 1;

        // -evaluatePolicy:localizedReason:reply: takes a (^block)(BOOL,NSError*)
        // — we synthesize a no-op block. The actual prompt result is
        // delivered via the block, but since we can't easily await a
        // block from zig, we use the synchronous canEvaluatePolicy
        // pattern: re-call with a busy wait pulling from a shared
        // result slot the block writes to.
        //
        // This blocks the current run-loop turn — apps using `evaluate`
        // are inherently waiting on a modal anyway, so it's fine.
        eval_result_set = false;
        eval_success = false;
        eval_error_code = 0;

        const Fn = *const fn (macos.objc.id, macos.objc.SEL, c_long, macos.objc.id, *const anyopaque) callconv(.c) void;
        const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
        f(ctx, macos.sel("evaluatePolicy:localizedReason:reply:"), policy, reason_ns, &eval_block);

        // Pump the run loop until the block fires. -[NSRunLoop runMode:beforeDate:]
        // returns each time it processes events; we keep going until
        // our shared flag flips. 60s is the hard ceiling — biometric
        // prompts auto-cancel after that anyway.
        const NSRunLoop = macos.getClass("NSRunLoop");
        const NSDate = macos.getClass("NSDate");
        const default_mode = macos.createNSString("kCFRunLoopDefaultMode");
        const run_loop = macos.msgSend0(NSRunLoop, "currentRunLoop");

        var elapsed: u32 = 0;
        while (!eval_result_set and elapsed < 60_000) : (elapsed += 50) {
            const tick = macos.msgSend1Double(NSDate, "dateWithTimeIntervalSinceNow:", 0.05);
            _ = macos.msgSend2(run_loop, "runMode:beforeDate:", default_mode, tick);
        }
        _ = macos.msgSend0(ctx, "release");

        var buf: [128]u8 = undefined;
        const json = if (eval_success)
            try std.fmt.bufPrint(&buf, "{{\"success\":true}}", .{})
        else
            try std.fmt.bufPrint(&buf, "{{\"success\":false,\"errorCode\":{d}}}", .{eval_error_code});
        bridge_error.sendResultToJS(self.allocator, "evaluate", json);
    }
};

// =============================================================================
// Shared block + result slot used by evaluatePolicy
// =============================================================================

var eval_result_set: bool = false;
var eval_success: bool = false;
var eval_error_code: c_long = 0;

const BlockLayout = extern struct {
    isa: ?*anyopaque,
    flags: c_int,
    reserved: c_int,
    invoke: *const fn (*const anyopaque, bool, @import("macos.zig").objc.id) callconv(.c) void,
    descriptor: *const BlockDescriptor,
};

const BlockDescriptor = extern struct {
    reserved: usize = 0,
    size: usize,
};

extern var _NSConcreteStackBlock: anyopaque;

fn evalInvoke(_: *const anyopaque, success: bool, err: @import("macos.zig").objc.id) callconv(.c) void {
    eval_success = success;
    if (!success and @intFromPtr(err) != 0) {
        const macos = @import("macos.zig");
        const Fn = *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) c_long;
        const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
        eval_error_code = f(err, macos.sel("code"));
    }
    eval_result_set = true;
}

const eval_descriptor = BlockDescriptor{ .size = @sizeOf(BlockLayout) };
const eval_block = BlockLayout{
    .isa = &_NSConcreteStackBlock,
    .flags = 0,
    .reserved = 0,
    .invoke = evalInvoke,
    .descriptor = &eval_descriptor,
};
