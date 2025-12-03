const std = @import("std");
const builtin = @import("builtin");

/// Bridge handler for clipboard operations
pub const ClipboardBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    /// Handle clipboard-related messages from JavaScript
    pub fn handleMessage(self: *Self, action: []const u8) !void {
        try self.handleMessageWithData(action, null);
    }

    pub fn handleMessageWithData(self: *Self, action: []const u8, data: ?[]const u8) !void {
        if (std.mem.eql(u8, action, "writeText")) {
            try self.writeText(data);
        } else if (std.mem.eql(u8, action, "readText")) {
            try self.readText();
        } else if (std.mem.eql(u8, action, "writeHTML")) {
            try self.writeHTML(data);
        } else if (std.mem.eql(u8, action, "readHTML")) {
            try self.readHTML();
        } else if (std.mem.eql(u8, action, "clear")) {
            try self.clear();
        } else if (std.mem.eql(u8, action, "hasText")) {
            try self.hasText();
        } else if (std.mem.eql(u8, action, "hasHTML")) {
            try self.hasHTML();
        } else if (std.mem.eql(u8, action, "hasImage")) {
            try self.hasImage();
        } else {
            std.debug.print("[ClipboardBridge] Unknown action: {s}\n", .{action});
        }
    }

    /// Write text to clipboard
    /// JSON: {"text": "Hello World"}
    fn writeText(self: *Self, data: ?[]const u8) !void {
        _ = self;
        if (data == null) return;

        std.debug.print("[ClipboardBridge] writeText called\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            const json_data = data.?;

            // Parse text
            if (std.mem.indexOf(u8, json_data, "\"text\":\"")) |idx| {
                const start = idx + 8;
                if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                    const text = json_data[start..end];

                    // Get general pasteboard
                    const NSPasteboard = macos.getClass("NSPasteboard");
                    const pasteboard = macos.msgSend0(NSPasteboard, "generalPasteboard");

                    // Clear existing content
                    _ = macos.msgSend0(pasteboard, "clearContents");

                    // Create NSString with text
                    const text_cstr = try std.heap.c_allocator.dupeZ(u8, text);
                    defer std.heap.c_allocator.free(text_cstr);

                    const NSString = macos.getClass("NSString");
                    const str_alloc = macos.msgSend0(NSString, "alloc");
                    const ns_text = macos.msgSend1(str_alloc, "initWithUTF8String:", text_cstr.ptr);

                    // Create array with the string
                    const NSArray = macos.getClass("NSArray");
                    const array = macos.msgSend1(NSArray, "arrayWithObject:", ns_text);

                    // Write to pasteboard
                    _ = macos.msgSend1(pasteboard, "writeObjects:", array);

                    std.debug.print("[ClipboardBridge] Wrote text to clipboard: {s}\n", .{text});
                }
            }
        }
    }

    /// Read text from clipboard
    fn readText(self: *Self) !void {
        _ = self;
        std.debug.print("[ClipboardBridge] readText called\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const NSPasteboard = macos.getClass("NSPasteboard");
            const pasteboard = macos.msgSend0(NSPasteboard, "generalPasteboard");

            // Get string from pasteboard
            const NSString = macos.getClass("NSString");

            // NSPasteboardTypeString
            const type_str = "public.utf8-plain-text";
            const type_cstr = @as([*:0]const u8, @ptrCast(type_str.ptr));
            const str_alloc = macos.msgSend0(NSString, "alloc");
            const ns_type = macos.msgSend1(str_alloc, "initWithUTF8String:", type_cstr);

            const text = macos.msgSend1(pasteboard, "stringForType:", ns_type);

            if (text != null) {
                const text_cstr = macos.msgSend0(text, "UTF8String");
                if (text_cstr != null) {
                    const text_str = std.mem.span(@as([*:0]const u8, @ptrCast(text_cstr)));
                    std.debug.print("[ClipboardBridge] Read text from clipboard: {s}\n", .{text_str});
                    // TODO: Send result back to JavaScript
                }
            } else {
                std.debug.print("[ClipboardBridge] No text in clipboard\n", .{});
            }
        }
    }

    /// Write HTML to clipboard
    /// JSON: {"html": "<h1>Hello</h1>"}
    fn writeHTML(self: *Self, data: ?[]const u8) !void {
        _ = self;
        if (data == null) return;

        std.debug.print("[ClipboardBridge] writeHTML called\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            const json_data = data.?;

            if (std.mem.indexOf(u8, json_data, "\"html\":\"")) |idx| {
                const start = idx + 8;
                if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                    const html = json_data[start..end];

                    const NSPasteboard = macos.getClass("NSPasteboard");
                    const pasteboard = macos.msgSend0(NSPasteboard, "generalPasteboard");

                    _ = macos.msgSend0(pasteboard, "clearContents");

                    // Set HTML type
                    const html_cstr = try std.heap.c_allocator.dupeZ(u8, html);
                    defer std.heap.c_allocator.free(html_cstr);

                    const NSString = macos.getClass("NSString");
                    const str_alloc = macos.msgSend0(NSString, "alloc");
                    const ns_html = macos.msgSend1(str_alloc, "initWithUTF8String:", html_cstr.ptr);

                    // HTML pasteboard type
                    const type_str = "public.html";
                    const type_cstr = @as([*:0]const u8, @ptrCast(type_str.ptr));
                    const type_alloc = macos.msgSend0(NSString, "alloc");
                    const ns_type = macos.msgSend1(type_alloc, "initWithUTF8String:", type_cstr);

                    _ = macos.msgSend2(pasteboard, "setString:forType:", ns_html, ns_type);

                    std.debug.print("[ClipboardBridge] Wrote HTML to clipboard\n", .{});
                }
            }
        }
    }

    /// Read HTML from clipboard
    fn readHTML(self: *Self) !void {
        _ = self;
        std.debug.print("[ClipboardBridge] readHTML called\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const NSPasteboard = macos.getClass("NSPasteboard");
            const pasteboard = macos.msgSend0(NSPasteboard, "generalPasteboard");

            const NSString = macos.getClass("NSString");
            const type_str = "public.html";
            const type_cstr = @as([*:0]const u8, @ptrCast(type_str.ptr));
            const str_alloc = macos.msgSend0(NSString, "alloc");
            const ns_type = macos.msgSend1(str_alloc, "initWithUTF8String:", type_cstr);

            const html = macos.msgSend1(pasteboard, "stringForType:", ns_type);

            if (html != null) {
                const html_cstr = macos.msgSend0(html, "UTF8String");
                if (html_cstr != null) {
                    const html_str = std.mem.span(@as([*:0]const u8, @ptrCast(html_cstr)));
                    std.debug.print("[ClipboardBridge] Read HTML from clipboard: {s}\n", .{html_str});
                }
            } else {
                std.debug.print("[ClipboardBridge] No HTML in clipboard\n", .{});
            }
        }
    }

    /// Clear clipboard
    fn clear(self: *Self) !void {
        _ = self;
        std.debug.print("[ClipboardBridge] clear called\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const NSPasteboard = macos.getClass("NSPasteboard");
            const pasteboard = macos.msgSend0(NSPasteboard, "generalPasteboard");
            _ = macos.msgSend0(pasteboard, "clearContents");

            std.debug.print("[ClipboardBridge] Clipboard cleared\n", .{});
        }
    }

    /// Check if clipboard has text
    fn hasText(self: *Self) !void {
        _ = self;
        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const NSPasteboard = macos.getClass("NSPasteboard");
            const pasteboard = macos.msgSend0(NSPasteboard, "generalPasteboard");

            const NSString = macos.getClass("NSString");
            const type_str = "public.utf8-plain-text";
            const type_cstr = @as([*:0]const u8, @ptrCast(type_str.ptr));
            const str_alloc = macos.msgSend0(NSString, "alloc");
            const ns_type = macos.msgSend1(str_alloc, "initWithUTF8String:", type_cstr);

            const NSArray = macos.getClass("NSArray");
            const types = macos.msgSend1(NSArray, "arrayWithObject:", ns_type);

            const available = macos.msgSend1(pasteboard, "availableTypeFromArray:", types);
            const has_text = available != null;

            std.debug.print("[ClipboardBridge] hasText: {}\n", .{has_text});
        }
    }

    /// Check if clipboard has HTML
    fn hasHTML(self: *Self) !void {
        _ = self;
        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const NSPasteboard = macos.getClass("NSPasteboard");
            const pasteboard = macos.msgSend0(NSPasteboard, "generalPasteboard");

            const NSString = macos.getClass("NSString");
            const type_str = "public.html";
            const type_cstr = @as([*:0]const u8, @ptrCast(type_str.ptr));
            const str_alloc = macos.msgSend0(NSString, "alloc");
            const ns_type = macos.msgSend1(str_alloc, "initWithUTF8String:", type_cstr);

            const NSArray = macos.getClass("NSArray");
            const types = macos.msgSend1(NSArray, "arrayWithObject:", ns_type);

            const available = macos.msgSend1(pasteboard, "availableTypeFromArray:", types);
            const has_html = available != null;

            std.debug.print("[ClipboardBridge] hasHTML: {}\n", .{has_html});
        }
    }

    /// Check if clipboard has image
    fn hasImage(self: *Self) !void {
        _ = self;
        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const NSPasteboard = macos.getClass("NSPasteboard");
            const pasteboard = macos.msgSend0(NSPasteboard, "generalPasteboard");

            const NSString = macos.getClass("NSString");
            const type_str = "public.png";
            const type_cstr = @as([*:0]const u8, @ptrCast(type_str.ptr));
            const str_alloc = macos.msgSend0(NSString, "alloc");
            const ns_type = macos.msgSend1(str_alloc, "initWithUTF8String:", type_cstr);

            const NSArray = macos.getClass("NSArray");
            const types = macos.msgSend1(NSArray, "arrayWithObject:", ns_type);

            const available = macos.msgSend1(pasteboard, "availableTypeFromArray:", types);
            const has_image = available != null;

            std.debug.print("[ClipboardBridge] hasImage: {}\n", .{has_image});
        }
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};
