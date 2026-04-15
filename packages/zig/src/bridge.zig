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

    pub fn deinit(self: *Self) void {
        self.handlers.deinit();
    }

    /// Register a handler for messages from JavaScript
    pub fn registerHandler(self: *Self, name: []const u8, handler: MessageHandler) !void {
        try self.handlers.put(name, handler);
    }

    /// Handle a message from JavaScript
    pub fn handleMessage(self: *Self, name: []const u8, message: []const u8) ![]const u8 {
        const handler = self.handlers.get(name) orelse return error.HandlerNotFound;
        return try handler(message);
    }

    /// Generate JavaScript code to inject into the WebView. Platform is
    /// substituted at comptime so `window.craft.platform` reflects the actual
    /// target — previously it was hardcoded to `'macos'` on every platform.
    pub fn generateInjectionScript(self: *Self) ![]const u8 {
        _ = self;
        const platform = comptime switch (builtin.os.tag) {
            .macos => "macos",
            .linux => "linux",
            .windows => "windows",
            .ios => "ios",
            else => "unknown",
        };
        // Keep the allocator-free behavior that the previous implementation
        // relied on by returning a comptime-concatenated string literal.
        return "window.craft = {\n" ++
            "    send: function(name, data) {\n" ++
            "        return new Promise((resolve, reject) => {\n" ++
            "            const message = JSON.stringify({ name: name, data: data });\n" ++
            "            window.webkit.messageHandlers.craft.postMessage(message)\n" ++
            "                .then(resolve)\n" ++
            "                .catch(reject);\n" ++
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
