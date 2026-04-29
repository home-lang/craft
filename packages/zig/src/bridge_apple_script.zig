const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Compile and execute AppleScript via `NSAppleScript`. Apps use this
/// for system-automation flows: telling Mail to compose a message,
/// asking Music to play a track, etc.
///
/// `executeAndReturnError:` returns an `NSAppleEventDescriptor`; we
/// surface its `stringValue` as the result. The output param of the
/// real call is an NSDictionary** with rich error info — we pass nil
/// to keep the bridge surface compact (callers see `{ok: false}` on
/// failure). Future work: thread the rich error through to JS.
pub const AppleScriptBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(_: *Self) void {}

    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "execute")) try self.execute(data) else return BridgeError.UnknownAction;
    }

    fn execute(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "execute", "{\"ok\":false,\"reason\":\"not supported\"}");
            return;
        }
        const ParseShape = struct { source: []const u8 = "" };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        if (parsed.value.source.len == 0) return BridgeError.MissingData;

        const macos = @import("macos.zig");
        const NSAppleScript = macos.getClass("NSAppleScript");
        if (@intFromPtr(NSAppleScript) == 0) {
            bridge_error.sendResultToJS(self.allocator, "execute", "{\"ok\":false,\"reason\":\"NSAppleScript unavailable\"}");
            return;
        }

        const source_ns = macos.createNSString(parsed.value.source);
        const script = macos.msgSend1(macos.msgSend0(NSAppleScript, "alloc"), "initWithSource:", source_ns);

        const Fn = *const fn (macos.objc.id, macos.objc.SEL, ?*anyopaque) callconv(.c) macos.objc.id;
        const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
        const result = f(script, macos.sel("executeAndReturnError:"), null);

        var buf: std.ArrayListUnmanaged(u8) = .empty;
        defer buf.deinit(self.allocator);
        try buf.appendSlice(self.allocator, "{\"ok\":");
        if (@intFromPtr(result) == 0) {
            try buf.appendSlice(self.allocator, "false}");
        } else {
            try buf.appendSlice(self.allocator, "true,\"result\":\"");
            const desc_str = macos.msgSend0(result, "stringValue");
            if (@intFromPtr(desc_str) != 0) appendNSStringEscaped(self.allocator, &buf, desc_str);
            try buf.appendSlice(self.allocator, "\"}");
        }
        const owned = try buf.toOwnedSlice(self.allocator);
        defer self.allocator.free(owned);
        bridge_error.sendResultToJS(self.allocator, "execute", owned);
    }
};

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
