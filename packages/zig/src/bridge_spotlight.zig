const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

pub const SpotlightBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    const SpotlightItem = struct {
        uniqueIdentifier: []const u8 = "",
        domainIdentifier: ?[]const u8 = null,
        title: []const u8 = "",
        contentDescription: ?[]const u8 = null,
        thumbnailURL: ?[]const u8 = null,
        contentType: ?[]const u8 = null,
        contentURL: ?[]const u8 = null,
        keywords: ?[][]const u8 = null,
    };

    pub fn init(a: std.mem.Allocator) Self {
        return .{ .allocator = a };
    }

    pub fn deinit(_: *Self) void {}

    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        if (builtin.os.tag != .macos) return BridgeError.PlatformNotSupported;

        if (std.mem.eql(u8, action, "index") or std.mem.eql(u8, action, "indexItems")) {
            try self.index(data);
        } else if (std.mem.eql(u8, action, "remove") or std.mem.eql(u8, action, "deleteItems")) {
            try self.deleteItems(data);
        } else if (std.mem.eql(u8, action, "deleteItemsInDomain")) {
            try self.deleteItemsInDomain(data);
        } else if (std.mem.eql(u8, action, "removeAll") or std.mem.eql(u8, action, "deleteAllItems")) {
            try self.deleteAllItems();
        } else return BridgeError.UnknownAction;
    }

    fn index(self: *Self, data: []const u8) !void {
        const macos = @import("macos.zig");

        const ParseShape = struct {
            items: []SpotlightItem = &.{},
        };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();

        const CSSearchableIndex = macos.getClass("CSSearchableIndex") orelse return BridgeError.NativeCallFailed;
        const CSSearchableItem = macos.getClass("CSSearchableItem") orelse return BridgeError.NativeCallFailed;
        const CSSearchableItemAttributeSet = macos.getClass("CSSearchableItemAttributeSet") orelse return BridgeError.NativeCallFailed;
        const NSMutableArray = macos.getClass("NSMutableArray") orelse return BridgeError.NativeCallFailed;

        const items_array = macos.msgSend0(NSMutableArray, "array");

        for (parsed.value.items) |item| {
            if (item.uniqueIdentifier.len == 0 or item.title.len == 0) return BridgeError.MissingData;

            const content_type = item.contentType orelse "public.data";
            const attribute_set_alloc = macos.msgSend0(CSSearchableItemAttributeSet, "alloc");
            const attribute_set = macos.msgSend1(attribute_set_alloc, "initWithItemContentType:", macos.createNSString(content_type));
            _ = macos.msgSend1(attribute_set, "setTitle:", macos.createNSString(item.title));

            if (item.contentDescription) |description| {
                if (description.len > 0) _ = macos.msgSend1(attribute_set, "setContentDescription:", macos.createNSString(description));
            }
            if (item.keywords) |keywords| {
                const keywords_array = macos.msgSend0(NSMutableArray, "array");
                for (keywords) |keyword| {
                    if (keyword.len > 0) _ = macos.msgSend1(keywords_array, "addObject:", macos.createNSString(keyword));
                }
                _ = macos.msgSend1(attribute_set, "setKeywords:", keywords_array);
            }
            if (item.thumbnailURL) |path_or_url| {
                if (path_or_url.len > 0) {
                    if (makeUrl(path_or_url)) |url| {
                        _ = macos.msgSend1(attribute_set, "setThumbnailURL:", url);
                    }
                }
            }
            if (item.contentURL) |path_or_url| {
                if (path_or_url.len > 0) {
                    if (makeUrl(path_or_url)) |url| {
                        _ = macos.msgSend1(attribute_set, "setContentURL:", url);
                    }
                }
            }

            const searchable_item_alloc = macos.msgSend0(CSSearchableItem, "alloc");
            const searchable_item = macos.msgSend3(
                searchable_item_alloc,
                "initWithUniqueIdentifier:domainIdentifier:attributeSet:",
                macos.createNSString(item.uniqueIdentifier),
                if (item.domainIdentifier) |domain| macos.createNSString(domain) else @as(?*anyopaque, null),
                attribute_set,
            );
            _ = macos.msgSend1(items_array, "addObject:", searchable_item);
        }

        const index_instance = macos.msgSend0(CSSearchableIndex, "defaultSearchableIndex");
        _ = macos.msgSend2(index_instance, "indexSearchableItems:completionHandler:", items_array, @as(?*anyopaque, null));
        bridge_error.sendResultToJS(self.allocator, "index", "{\"ok\":true}");
    }

    fn deleteItems(self: *Self, data: []const u8) !void {
        const macos = @import("macos.zig");

        const ParseShape = struct {
            ids: [][]const u8 = &.{},
            identifiers: [][]const u8 = &.{},
        };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();

        const ids = if (parsed.value.ids.len > 0) parsed.value.ids else parsed.value.identifiers;
        const CSSearchableIndex = macos.getClass("CSSearchableIndex") orelse return BridgeError.NativeCallFailed;
        const index_instance = macos.msgSend0(CSSearchableIndex, "defaultSearchableIndex");
        _ = macos.msgSend2(index_instance, "deleteSearchableItemsWithIdentifiers:completionHandler:", try stringArray(ids), @as(?*anyopaque, null));
        bridge_error.sendResultToJS(self.allocator, "remove", "{\"ok\":true}");
    }

    fn deleteItemsInDomain(self: *Self, data: []const u8) !void {
        const macos = @import("macos.zig");

        const ParseShape = struct { domainIdentifier: []const u8 = "" };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();

        if (parsed.value.domainIdentifier.len == 0) return BridgeError.MissingData;

        const ids = [_][]const u8{parsed.value.domainIdentifier};
        const CSSearchableIndex = macos.getClass("CSSearchableIndex") orelse return BridgeError.NativeCallFailed;
        const index_instance = macos.msgSend0(CSSearchableIndex, "defaultSearchableIndex");
        _ = macos.msgSend2(index_instance, "deleteSearchableItemsWithDomainIdentifiers:completionHandler:", try stringArray(&ids), @as(?*anyopaque, null));
        bridge_error.sendResultToJS(self.allocator, "deleteItemsInDomain", "{\"ok\":true}");
    }

    fn deleteAllItems(self: *Self) !void {
        const macos = @import("macos.zig");
        const CSSearchableIndex = macos.getClass("CSSearchableIndex") orelse return BridgeError.NativeCallFailed;
        const index_instance = macos.msgSend0(CSSearchableIndex, "defaultSearchableIndex");
        _ = macos.msgSend1(index_instance, "deleteAllSearchableItemsWithCompletionHandler:", @as(?*anyopaque, null));
        bridge_error.sendResultToJS(self.allocator, "removeAll", "{\"ok\":true}");
    }
};

fn stringArray(items: []const []const u8) !?*anyopaque {
    const macos = @import("macos.zig");
    const NSMutableArray = macos.getClass("NSMutableArray") orelse return BridgeError.NativeCallFailed;
    const array = macos.msgSend0(NSMutableArray, "array");
    for (items) |item| {
        _ = macos.msgSend1(array, "addObject:", macos.createNSString(item));
    }
    return array;
}

fn makeUrl(path_or_url: []const u8) ?*anyopaque {
    const macos = @import("macos.zig");
    const NSURL = macos.getClass("NSURL") orelse return null;
    if (std.mem.startsWith(u8, path_or_url, "file://") or
        std.mem.startsWith(u8, path_or_url, "http://") or
        std.mem.startsWith(u8, path_or_url, "https://"))
    {
        return macos.msgSend1(NSURL, "URLWithString:", macos.createNSString(path_or_url));
    }
    return macos.msgSend1(NSURL, "fileURLWithPath:", macos.createNSString(path_or_url));
}
