const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// PDFKit-backed reader for PDFs on disk. Currently exposes:
///
///   - `countPages(path)`   — total page count
///   - `extractText(path)`  — concatenated plaintext of all pages
///
/// Apps that need richer extraction (per-page text, embedded images,
/// annotations, form-field values) should walk `PDFDocument` directly
/// via `-pageAtIndex:` / `-extractionResults:`. The two methods above
/// cover the common "read the file and let me grep it" use case.
pub const PDFBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(_: *Self) void {}

    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "countPages")) try self.countPages(data)
        else if (std.mem.eql(u8, action, "extractText")) try self.extractText(data)
        else return BridgeError.UnknownAction;
    }

    fn countPages(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "countPages", "{\"pages\":0}");
            return;
        }
        const doc = try openPDF(self.allocator, data) orelse {
            bridge_error.sendResultToJS(self.allocator, "countPages", "{\"pages\":0}");
            return;
        };
        defer {
            const macos = @import("macos.zig");
            _ = macos.msgSend0(doc, "release");
        }

        const macos = @import("macos.zig");
        const Fn = *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) c_ulong;
        const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
        const count = f(doc, macos.sel("pageCount"));
        var buf: [64]u8 = undefined;
        const json = try std.fmt.bufPrint(&buf, "{{\"pages\":{d}}}", .{count});
        bridge_error.sendResultToJS(self.allocator, "countPages", json);
    }

    fn extractText(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "extractText", "{\"text\":\"\"}");
            return;
        }
        const doc = try openPDF(self.allocator, data) orelse {
            bridge_error.sendResultToJS(self.allocator, "extractText", "{\"text\":\"\"}");
            return;
        };
        defer {
            const macos = @import("macos.zig");
            _ = macos.msgSend0(doc, "release");
        }

        const macos = @import("macos.zig");
        const text_ns = macos.msgSend0(doc, "string");
        var buf: std.ArrayListUnmanaged(u8) = .empty;
        defer buf.deinit(self.allocator);
        try buf.appendSlice(self.allocator, "{\"text\":\"");
        appendNSStringEscaped(self.allocator, &buf, text_ns);
        try buf.appendSlice(self.allocator, "\"}");
        const owned = try buf.toOwnedSlice(self.allocator);
        defer self.allocator.free(owned);
        bridge_error.sendResultToJS(self.allocator, "extractText", owned);
    }
};

fn openPDF(allocator: std.mem.Allocator, data: []const u8) !?@import("macos.zig").objc.id {
    const ParseShape = struct { path: []const u8 = "" };
    const parsed = std.json.parseFromSlice(ParseShape, allocator, data, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    }) catch return null;
    defer parsed.deinit();
    if (parsed.value.path.len == 0) return null;

    const macos = @import("macos.zig");
    const PDFDocument = macos.getClass("PDFDocument");
    if (@intFromPtr(PDFDocument) == 0) return null;
    const NSURL = macos.getClass("NSURL");
    const path_ns = macos.createNSString(parsed.value.path);
    const url = macos.msgSend1(NSURL, "fileURLWithPath:", path_ns);
    const doc = macos.msgSend1(macos.msgSend0(PDFDocument, "alloc"), "initWithURL:", url);
    if (@intFromPtr(doc) == 0) return null;
    return doc;
}

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
