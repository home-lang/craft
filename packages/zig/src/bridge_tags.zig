const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

extern "c" fn getxattr(path: [*:0]const u8, name: [*:0]const u8, value: ?[*]u8, size: usize, position: u32, options: c_int) isize;
extern "c" fn setxattr(path: [*:0]const u8, name: [*:0]const u8, value: [*]const u8, size: usize, position: u32, options: c_int) c_int;
extern "c" fn removexattr(path: [*:0]const u8, name: [*:0]const u8, options: c_int) c_int;

/// Finder colour tags via the `com.apple.metadata:_kMDItemUserTags`
/// extended attribute. The xattr stores a binary plist (NSArray of
/// NSStrings); we round-trip through `NSPropertyListSerialization` so
/// callers see a plain string array on the JS side.
///
/// Tag strings often look like `"Red\n0"` — the `\nN` suffix encodes
/// the colour index. We pass them through unchanged so apps can
/// strip or preserve the suffix as they like.
pub const TagsBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(_: *Self) void {}

    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "get")) try self.getTags(data)
        else if (std.mem.eql(u8, action, "set")) try self.setTags(data)
        else if (std.mem.eql(u8, action, "clear")) try self.clearTags(data)
        else return BridgeError.UnknownAction;
    }

    fn getTags(self: *Self, data: []const u8) !void {
        const ParseShape = struct { path: []const u8 = "" };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        if (parsed.value.path.len == 0) return BridgeError.MissingData;

        const path_z = try self.allocator.dupeZ(u8, parsed.value.path);
        defer self.allocator.free(path_z);

        const xattr_name: [*:0]const u8 = "com.apple.metadata:_kMDItemUserTags";
        const size = getxattr(path_z.ptr, xattr_name, null, 0, 0, 0);
        if (size <= 0) {
            bridge_error.sendResultToJS(self.allocator, "get", "{\"tags\":[]}");
            return;
        }

        const buf = try self.allocator.alloc(u8, @intCast(size));
        defer self.allocator.free(buf);
        const read = getxattr(path_z.ptr, xattr_name, buf.ptr, @intCast(size), 0, 0);
        if (read <= 0 or builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "get", "{\"tags\":[]}");
            return;
        }

        const macos = @import("macos.zig");
        const NSData = macos.getClass("NSData");
        const data_obj = macos.msgSend2(NSData, "dataWithBytes:length:",
            @as([*]const u8, buf.ptr), @as(c_ulong, @intCast(read)));

        const NSPropertyListSerialization = macos.getClass("NSPropertyListSerialization");
        const Fn = *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id, c_ulong, ?*anyopaque, ?*anyopaque) callconv(.c) macos.objc.id;
        const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
        const arr = f(NSPropertyListSerialization, macos.sel("propertyListWithData:options:format:error:"),
            data_obj, 0, null, null);
        if (@intFromPtr(arr) == 0) {
            bridge_error.sendResultToJS(self.allocator, "get", "{\"tags\":[]}");
            return;
        }

        var out: std.ArrayListUnmanaged(u8) = .empty;
        defer out.deinit(self.allocator);
        try out.appendSlice(self.allocator, "{\"tags\":[");
        const CountFn = *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) c_ulong;
        const cf: CountFn = @ptrCast(&macos.objc.objc_msgSend);
        const count = cf(arr, macos.sel("count"));
        var i: c_ulong = 0;
        while (i < count) : (i += 1) {
            if (i > 0) try out.append(self.allocator, ',');
            try out.append(self.allocator, '"');
            const item = macos.msgSend1(arr, "objectAtIndex:", i);
            appendNSStringEscaped(self.allocator, &out, item);
            try out.append(self.allocator, '"');
        }
        try out.appendSlice(self.allocator, "]}");

        const owned = try out.toOwnedSlice(self.allocator);
        defer self.allocator.free(owned);
        bridge_error.sendResultToJS(self.allocator, "get", owned);
    }

    fn setTags(self: *Self, data: []const u8) !void {
        const ParseShape = struct { path: []const u8 = "", tags: []const []const u8 = &[_][]const u8{} };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        if (parsed.value.path.len == 0) return BridgeError.MissingData;

        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "set", "{\"ok\":false}");
            return;
        }

        const macos = @import("macos.zig");
        const NSMutableArray = macos.getClass("NSMutableArray");
        const arr = macos.msgSend0(NSMutableArray, "array");
        for (parsed.value.tags) |tag| {
            const ns = macos.createNSString(tag);
            _ = macos.msgSend1(arr, "addObject:", ns);
        }

        // NSPropertyListBinaryFormat_v1_0 = 200 — Apple's binary plist
        // format. The xattr itself is plain bytes; we choose binary
        // because that's what Finder writes and what other tools expect.
        const NSPropertyListSerialization = macos.getClass("NSPropertyListSerialization");
        const Fn = *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id, c_ulong, c_ulong, ?*anyopaque) callconv(.c) macos.objc.id;
        const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
        const data_obj = f(NSPropertyListSerialization,
            macos.sel("dataWithPropertyList:format:options:error:"),
            arr, 200, 0, null);
        if (@intFromPtr(data_obj) == 0) {
            bridge_error.sendResultToJS(self.allocator, "set", "{\"ok\":false}");
            return;
        }

        const path_z = try self.allocator.dupeZ(u8, parsed.value.path);
        defer self.allocator.free(path_z);

        const Bytes = *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) [*]const u8;
        const bf: Bytes = @ptrCast(&macos.objc.objc_msgSend);
        const Length = *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) c_ulong;
        const lf: Length = @ptrCast(&macos.objc.objc_msgSend);
        const bytes = bf(data_obj, macos.sel("bytes"));
        const len = lf(data_obj, macos.sel("length"));

        const xattr_name: [*:0]const u8 = "com.apple.metadata:_kMDItemUserTags";
        const status = setxattr(path_z.ptr, xattr_name, bytes, len, 0, 0);
        const json = if (status == 0) "{\"ok\":true}" else "{\"ok\":false}";
        bridge_error.sendResultToJS(self.allocator, "set", json);
    }

    fn clearTags(self: *Self, data: []const u8) !void {
        const ParseShape = struct { path: []const u8 = "" };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        if (parsed.value.path.len == 0) return BridgeError.MissingData;

        const path_z = try self.allocator.dupeZ(u8, parsed.value.path);
        defer self.allocator.free(path_z);

        _ = removexattr(path_z.ptr, "com.apple.metadata:_kMDItemUserTags", 0);
        bridge_error.sendResultToJS(self.allocator, "clear", "{\"ok\":true}");
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
