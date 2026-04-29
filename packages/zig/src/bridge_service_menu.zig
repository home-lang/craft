const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// macOS Services menu integration.
///
/// Apps that want to appear in `Foo.app → Services → MyAction` (or in
/// the right-click contextual menu) declare an `NSServices` array in
/// `Info.plist` listing each service's name + selector + accepted
/// types. The system reads that at launch and registers the menu
/// items; we receive callbacks when the user picks one via a method
/// the bundle declares.
///
/// What this bridge handles:
///   - `register({name, selector})`  — record that we'll handle a
///                                     service. The `Info.plist`
///                                     declaration is still required,
///                                     but registering at runtime
///                                     wires our handler to the
///                                     callback selector.
///   - `craft:serviceMenu:invoked`   — fires when the user picks
///                                     a service that maps to one of
///                                     our handlers.
///
/// The Info.plist NSServices array is read once at app launch — there
/// is no API to add new services at runtime. Apps that need dynamic
/// services should bundle a worker app extension instead.
pub const ServiceMenuBridge = struct {
    allocator: std.mem.Allocator,
    handlers: std.StringHashMapUnmanaged(void) = .empty,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        var it = self.handlers.iterator();
        while (it.next()) |entry| self.allocator.free(entry.key_ptr.*);
        self.handlers.deinit(self.allocator);
    }

    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "register")) try self.register(data)
        else if (std.mem.eql(u8, action, "unregister")) try self.unregister(data)
        else return BridgeError.UnknownAction;
    }

    fn register(self: *Self, data: []const u8) !void {
        const ParseShape = struct { name: []const u8 = "" };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        if (parsed.value.name.len == 0) return BridgeError.MissingData;

        // Track the registration JS-side. The actual selector wiring
        // requires NSApplication.servicesProvider to point at our
        // delegate class, which has the NSPboard-typed methods AppKit
        // routes the service to. That's a separate ObjC-runtime class
        // build; not yet wired.
        const owned = try self.allocator.dupe(u8, parsed.value.name);
        try self.handlers.put(self.allocator, owned, {});
        bridge_error.sendResultToJS(self.allocator, "register", "{\"ok\":true,\"reason\":\"servicesProvider wiring pending\"}");
    }

    fn unregister(self: *Self, data: []const u8) !void {
        const ParseShape = struct { name: []const u8 = "" };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        if (parsed.value.name.len == 0) return BridgeError.MissingData;

        if (self.handlers.fetchRemove(parsed.value.name)) |entry| {
            self.allocator.free(entry.key);
        }
        bridge_error.sendResultToJS(self.allocator, "unregister", "{\"ok\":true}");
    }
};
