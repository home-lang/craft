const std = @import("std");
const builtin = @import("builtin");

/// Evaluate JavaScript in the webview, cross-platform.
/// Dispatches to the correct platform's webview JS evaluation function.
pub fn evalJS(script: []const u8) !void {
    switch (comptime builtin.os.tag) {
        .macos => {
            const macos = @import("macos.zig");
            try macos.tryEvalJS(script);
        },
        .linux => {
            const linux = @import("linux.zig");
            try linux.evalJS(script);
        },
        .windows => {
            const windows = @import("windows.zig");
            try windows.evalJS(script);
        },
        else => return error.UnsupportedPlatform,
    }
}

/// JavaScript bridge for Zig <-> Web communication
/// Allows JavaScript to call Zig functions and Zig to evaluate JavaScript
pub const MessageHandler = *const fn (message: []const u8) anyerror![]const u8;

pub const Bridge = struct {
    allocator: std.mem.Allocator,
    handlers: std.StringHashMap(MessageHandler),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .handlers = std.StringHashMap(MessageHandler).init(allocator),
        };
    }

    /// Deinit frees every duped handler name so callers don't have to keep
    /// their own tracking list. The previous implementation just dropped
    /// the hashmap, which was safe only because handler names were being
    /// stored by borrowed reference — and that borrowing was itself a bug
    /// (see `registerHandler`).
    pub fn deinit(self: *Self) void {
        var it = self.handlers.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.handlers.deinit();
    }

    /// Register a handler for messages from JavaScript. The handler `name`
    /// is duped into the bridge's allocator so the caller can free/reuse
    /// its source buffer. If the key already exists, the previous duped
    /// copy is replaced and freed.
    pub fn registerHandler(self: *Self, name: []const u8, handler: MessageHandler) !void {
        const name_dup = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_dup);

        if (self.handlers.fetchRemove(name)) |old| {
            self.allocator.free(old.key);
        }
        try self.handlers.put(name_dup, handler);
    }

    /// Handle a message from JavaScript
    pub fn handleMessage(self: *Self, name: []const u8, message: []const u8) ![]const u8 {
        const handler = self.handlers.get(name) orelse return error.HandlerNotFound;
        return try handler(message);
    }

    /// Generate JavaScript code to inject into the WebView. Platform is
    /// substituted at comptime so `window.craft.platform` reflects the actual
    /// target, and the `postMessage` bridge is chosen per-platform:
    ///
    ///   - macOS / iOS (WKWebView): `window.webkit.messageHandlers.craft.postMessage`
    ///   - Linux (WebKitGTK):       `window.webkit.messageHandlers.craft.postMessage`
    ///   - Windows (WebView2):      `window.chrome.webview.postMessage`
    ///
    /// Previously the script was hardcoded to the WebKit path, so every
    /// `craft.send()` on Windows crashed with `Cannot read property …
    /// messageHandlers of undefined`.
    pub fn generateInjectionScript(self: *Self) ![]const u8 {
        _ = self;
        const platform = comptime switch (builtin.os.tag) {
            .macos => "macos",
            .linux => "linux",
            .windows => "windows",
            .ios => "ios",
            else => "unknown",
        };
        const post_message_body = comptime switch (builtin.os.tag) {
            .windows =>
            \\            if (window.chrome && window.chrome.webview) {
            \\                try { window.chrome.webview.postMessage(message); resolve(); }
            \\                catch (e) { reject(e); }
            \\            } else {
            \\                reject(new Error('WebView2 postMessage bridge unavailable'));
            \\            }
            ,
            .macos, .ios, .linux =>
            \\            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.craft) {
            \\                const r = window.webkit.messageHandlers.craft.postMessage(message);
            \\                if (r && typeof r.then === 'function') { r.then(resolve).catch(reject); }
            \\                else { resolve(); }
            \\            } else {
            \\                reject(new Error('WebKit messageHandlers.craft unavailable'));
            \\            }
            ,
            else =>
            \\            reject(new Error('no postMessage bridge available on this platform'));
            ,
        };

        return "window.craft = {\n" ++
            "    send: function(name, data) {\n" ++
            "        return new Promise((resolve, reject) => {\n" ++
            "            const message = JSON.stringify({ name: name, data: data });\n" ++
            post_message_body ++ "\n" ++
            "        });\n" ++
            "    },\n" ++
            "    notify: function(message) { return this.send('notify', { message: message }); },\n" ++
            "    readFile: function(path) { return this.send('readFile', { path: path }); },\n" ++
            "    writeFile: function(path, content) { return this.send('writeFile', { path: path, content: content }); },\n" ++
            "    openDialog: function(options) { return this.send('openDialog', options); },\n" ++
            "    getClipboard: function() { return this.send('getClipboard', {}); },\n" ++
            "    setClipboard: function(text) { return this.send('setClipboard', { text: text }); },\n" ++
            "    platform: '" ++ platform ++ "',\n" ++
            "    version: '0.2.0'\n" ++
            "};\n" ++
            "window.dispatchEvent(new CustomEvent('craft:ready'));\n";
    }
};

// Example handler functions
pub fn notifyHandler(message: []const u8) ![]const u8 {
    // Use the log facility (respects level configuration) rather than
    // `std.debug.print`, which would flood stderr on every notification.
    std.log.scoped(.bridge).info("notification from web: {s}", .{message});
    return "OK";
}

pub fn readFileHandler(message: []const u8) ![]const u8 {
    // Parse JSON to get file path
    // Read file
    // Return contents
    _ = message;
    return "File contents here";
}

pub fn writeFileHandler(message: []const u8) ![]const u8 {
    // Parse JSON to get path and content
    // Write file
    // Return success
    _ = message;
    return "OK";
}
