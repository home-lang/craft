const std = @import("std");
const builtin = @import("builtin");

/// JavaScript ↔ Zig Bridge API
/// Provides bidirectional communication between WebView and native code
pub const BridgeAPI = struct {
    allocator: std.mem.Allocator,
    message_handlers: std.StringHashMap(MessageHandler),
    app_handle: ?*anyopaque = null,
    tray_handle: ?*anyopaque = null,

    const Self = @This();

    pub const MessageHandler = *const fn (data: []const u8) void;

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .message_handlers = std.StringHashMap(MessageHandler).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.message_handlers.deinit();
    }

    /// Register a message handler for a specific method
    pub fn registerHandler(self: *Self, method: []const u8, handler: MessageHandler) !void {
        try self.message_handlers.put(method, handler);
    }

    /// Handle incoming message from JavaScript
    pub fn handleMessage(self: *Self, method: []const u8, data: []const u8) ![]const u8 {
        if (self.message_handlers.get(method)) |handler| {
            return handler(data);
        }
        return error.UnknownMethod;
    }

    /// Set the system tray handle for tray operations
    pub fn setTrayHandle(self: *Self, handle: *anyopaque) void {
        self.tray_handle = handle;
    }

    /// Set the app handle for app operations
    pub fn setAppHandle(self: *Self, handle: *anyopaque) void {
        self.app_handle = handle;
    }

    /// Generate JavaScript injection code
    pub fn generateInjectionScript(self: *Self) ![]const u8 {
        _ = self;
        return 
        \\(function() {
        \\  window.craft = {
        \\    tray: {
        \\      setTitle: function(title) {
        \\        return window.webkit.messageHandlers.craft.postMessage({
        \\          method: 'tray.setTitle',
        \\          args: { title: title }
        \\        });
        \\      },
        \\      setTooltip: function(tooltip) {
        \\        return window.webkit.messageHandlers.craft.postMessage({
        \\          method: 'tray.setTooltip',
        \\          args: { tooltip: tooltip }
        \\        });
        \\      },
        \\      setMenu: function(items) {
        \\        return window.webkit.messageHandlers.craft.postMessage({
        \\          method: 'tray.setMenu',
        \\          args: { items: items }
        \\        });
        \\      }
        \\    },
        \\    window: {
        \\      show: function() {
        \\        return window.webkit.messageHandlers.craft.postMessage({
        \\          method: 'window.show',
        \\          args: {}
        \\        });
        \\      },
        \\      hide: function() {
        \\        return window.webkit.messageHandlers.craft.postMessage({
        \\          method: 'window.hide',
        \\          args: {}
        \\        });
        \\      },
        \\      minimize: function() {
        \\        return window.webkit.messageHandlers.craft.postMessage({
        \\          method: 'window.minimize',
        \\          args: {}
        \\        });
        \\      },
        \\      close: function() {
        \\        return window.webkit.messageHandlers.craft.postMessage({
        \\          method: 'window.close',
        \\          args: {}
        \\        });
        \\      }
        \\    },
        \\    app: {
        \\      quit: function() {
        \\        return window.webkit.messageHandlers.craft.postMessage({
        \\          method: 'app.quit',
        \\          args: {}
        \\        });
        \\      },
        \\      notify: function(options) {
        \\        return window.webkit.messageHandlers.craft.postMessage({
        \\          method: 'app.notify',
        \\          args: options
        \\        });
        \\      }
        \\    },
        \\    _internal: {
        \\      call: function(method, args) {
        \\        return window.webkit.messageHandlers.craft.postMessage({
        \\          method: method,
        \\          args: args || {}
        \\        });
        \\      }
        \\    }
        \\  };
        \\
        \\  // Notify that craft API is ready
        \\  window.dispatchEvent(new Event('craft:ready'));
        \\})();
        ;
    }
};
