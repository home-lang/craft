const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

extern "c" fn LSCopyDefaultRoleHandlerForContentType(content_type: ?*anyopaque, role: u32) ?*anyopaque;
extern "c" fn LSSetDefaultRoleHandlerForContentType(content_type: ?*anyopaque, role: u32, handler: ?*anyopaque) i32;

/// LaunchServices-backed file-association controls. Apps use this to
/// register themselves as the default handler for a content type
/// (e.g. opening `.myext` files, `myapp://` URLs after the user clicks
/// "Always open with…").
///
/// `kLSRolesAll = 0xFFFFFFFF` — covers viewer + editor + shell roles.
/// We treat them uniformly because the distinction matters mostly to
/// QuickLook generators, not to typical app content claims.
pub const FileAssociationsBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(_: *Self) void {}

    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "getDefault")) try self.getDefault(data)
        else if (std.mem.eql(u8, action, "setDefault")) try self.setDefault(data)
        else return BridgeError.UnknownAction;
    }

    fn getDefault(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "getDefault", "{\"bundleId\":null}");
            return;
        }
        const ParseShape = struct { uti: []const u8 = "" };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        if (parsed.value.uti.len == 0) return BridgeError.MissingData;

        const macos = @import("macos.zig");
        const uti_ns = macos.createNSString(parsed.value.uti);
        const handler = LSCopyDefaultRoleHandlerForContentType(@ptrCast(uti_ns), 0xFFFFFFFF);

        var buf: std.ArrayListUnmanaged(u8) = .empty;
        defer buf.deinit(self.allocator);
        try buf.appendSlice(self.allocator, "{\"bundleId\":");
        if (@intFromPtr(handler) == 0) {
            try buf.appendSlice(self.allocator, "null}");
        } else {
            try buf.append(self.allocator, '"');
            const utf8 = macos.msgSend0(@as(macos.objc.id, @ptrCast(@constCast(handler))), "UTF8String");
            if (@intFromPtr(utf8) != 0) {
                const slice = std.mem.span(@as([*:0]const u8, @ptrCast(utf8)));
                try buf.appendSlice(self.allocator, slice);
            }
            try buf.appendSlice(self.allocator, "\"}");
        }
        const owned = try buf.toOwnedSlice(self.allocator);
        defer self.allocator.free(owned);
        bridge_error.sendResultToJS(self.allocator, "getDefault", owned);
    }

    fn setDefault(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "setDefault", "{\"ok\":false}");
            return;
        }
        const ParseShape = struct { uti: []const u8 = "", bundleId: []const u8 = "" };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        if (parsed.value.uti.len == 0 or parsed.value.bundleId.len == 0) return BridgeError.MissingData;

        const macos = @import("macos.zig");
        const uti_ns = macos.createNSString(parsed.value.uti);
        const bundle_ns = macos.createNSString(parsed.value.bundleId);
        const status = LSSetDefaultRoleHandlerForContentType(@ptrCast(uti_ns), 0xFFFFFFFF, @ptrCast(bundle_ns));
        const json = if (status == 0) "{\"ok\":true}" else "{\"ok\":false}";
        bridge_error.sendResultToJS(self.allocator, "setDefault", json);
    }
};
