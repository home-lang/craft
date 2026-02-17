const std = @import("std");
const io_context = @import("io_context.zig");
const mobile = @import("mobile.zig");

/// Unified JavaScript Bridge API
/// Provides consistent window.craft API across iOS, Android, and Desktop
///
/// Usage:
/// ```javascript
/// // Check platform
/// const platform = await window.craft.getPlatform();
///
/// // Navigate
/// await window.craft.navigate('https://example.com');
///
/// // Execute native code
/// const result = await window.craft.invoke('myMethod', { param: 'value' });
///
/// // Listen for events
/// window.craft.on('ready', () => console.log('App ready'));
/// ```
pub const JSBridgeError = error{
    InvalidJSON,
    MethodNotFound,
    InvalidParameters,
    ExecutionFailed,
};

/// JavaScript Bridge Message
pub const JSMessage = struct {
    id: []const u8,
    method: []const u8,
    params: ?std.json.Value = null,
    callback: ?[]const u8 = null,

    pub fn parse(allocator: std.mem.Allocator, json_str: []const u8) !JSMessage {
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) return JSBridgeError.InvalidJSON;

        const obj = root.object;

        return JSMessage{
            .id = if (obj.get("id")) |id_val| try allocator.dupe(u8, id_val.string) else "",
            .method = if (obj.get("method")) |method_val| try allocator.dupe(u8, method_val.string) else "",
            .params = if (obj.get("params")) |params_val| params_val else null,
            .callback = if (obj.get("callback")) |cb_val| try allocator.dupe(u8, cb_val.string) else null,
        };
    }

    pub fn deinit(self: *JSMessage, allocator: std.mem.Allocator) void {
        if (self.id.len > 0) allocator.free(self.id);
        if (self.method.len > 0) allocator.free(self.method);
        if (self.callback) |cb| allocator.free(cb);
    }
};

/// JavaScript Bridge Response
pub const JSResponse = struct {
    id: []const u8,
    success: bool,
    result: ?std.json.Value = null,
    error_msg: ?[]const u8 = null,

    pub fn toJSON(self: JSResponse, allocator: std.mem.Allocator) ![]u8 {
        var string = std.ArrayList(u8).init(allocator);
        errdefer string.deinit();

        try string.appendSlice("{");

        // ID
        try string.appendSlice("\"id\":\"");
        try string.appendSlice(self.id);
        try string.appendSlice("\",");

        // Success
        try string.appendSlice("\"success\":");
        try string.appendSlice(if (self.success) "true" else "false");

        // Result or error
        if (self.result) |result| {
            try string.appendSlice(",\"result\":");
            try std.json.stringify(result, .{}, string.writer());
        }

        if (self.error_msg) |err| {
            try string.appendSlice(",\"error\":\"");
            try string.appendSlice(err);
            try string.appendSlice("\"");
        }

        try string.appendSlice("}");

        return string.toOwnedSlice();
    }
};

/// JavaScript Bridge Handler
pub const JSBridge = struct {
    allocator: std.mem.Allocator,
    handlers: std.StringHashMap(Handler),
    event_listeners: std.StringHashMap(std.ArrayList(EventCallback)),

    const Handler = *const fn (allocator: std.mem.Allocator, params: ?std.json.Value) anyerror!std.json.Value;
    const EventCallback = *const fn (data: std.json.Value) void;

    pub fn init(allocator: std.mem.Allocator) JSBridge {
        return JSBridge{
            .allocator = allocator,
            .handlers = std.StringHashMap(Handler).init(allocator),
            .event_listeners = std.StringHashMap(std.ArrayList(EventCallback)).init(allocator),
        };
    }

    pub fn deinit(self: *JSBridge) void {
        self.handlers.deinit();

        var it = self.event_listeners.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.event_listeners.deinit();
    }

    /// Register a method handler
    pub fn registerMethod(self: *JSBridge, method_name: []const u8, handler: Handler) !void {
        try self.handlers.put(method_name, handler);
    }

    /// Handle incoming JavaScript message
    pub fn handleMessage(self: *JSBridge, json_str: []const u8) ![]u8 {
        var message = try JSMessage.parse(self.allocator, json_str);
        defer message.deinit(self.allocator);

        // Look up handler
        const handler = self.handlers.get(message.method) orelse {
            const response = JSResponse{
                .id = message.id,
                .success = false,
                .error_msg = "Method not found",
            };
            return try response.toJSON(self.allocator);
        };

        // Execute handler
        const result = handler(self.allocator, message.params) catch |err| {
            const err_name = @errorName(err);
            const response = JSResponse{
                .id = message.id,
                .success = false,
                .error_msg = err_name,
            };
            return try response.toJSON(self.allocator);
        };

        // Return success response
        const response = JSResponse{
            .id = message.id,
            .success = true,
            .result = result,
        };
        return try response.toJSON(self.allocator);
    }

    /// Emit event to JavaScript
    pub fn emit(self: *JSBridge, event_name: []const u8, data: std.json.Value) ![]u8 {
        var string = std.ArrayList(u8).init(self.allocator);
        errdefer string.deinit();

        try string.appendSlice("{\"event\":\"");
        try string.appendSlice(event_name);
        try string.appendSlice("\",\"data\":");
        try std.json.stringify(data, .{}, string.writer());
        try string.appendSlice("}");

        return string.toOwnedSlice();
    }
};

/// Built-in method handlers
pub const BuiltInHandlers = struct {
    /// Get platform information
    pub fn getPlatform(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        _ = params;
        const platform = mobile.Platform.current();

        const platform_str = switch (platform) {
            .ios => "ios",
            .android => "android",
            .unknown => "unknown",
        };

        var obj = std.json.ObjectMap.init(allocator);
        try obj.put("platform", .{ .string = platform_str });
        try obj.put("version", .{ .string = "1.3.0" });

        return std.json.Value{ .object = obj };
    }

    /// Get device information
    pub fn getDeviceInfo(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        _ = params;
        var obj = std.json.ObjectMap.init(allocator);

        const builtin = @import("builtin");
        const platform = mobile.Platform.current();

        try obj.put("platform", .{ .string = switch (platform) {
            .ios => "ios",
            .android => "android",
            .unknown => if (builtin.os.tag == .macos) "macos" else if (builtin.os.tag == .linux) "linux" else if (builtin.os.tag == .windows) "windows" else "unknown",
        } });

        // Get actual device info from native APIs
        if (builtin.os.tag == .macos or builtin.os.tag == .ios) {
            // Use NSProcessInfo for macOS/iOS
            const device_info = getMacOSDeviceInfo(allocator);
            try obj.put("model", .{ .string = device_info.model });
            try obj.put("os_version", .{ .string = device_info.os_version });
            try obj.put("os_name", .{ .string = device_info.os_name });
            try obj.put("processor_count", .{ .integer = @intCast(device_info.processor_count) });
        } else if (builtin.os.tag == .linux) {
            // Read from /etc/os-release for Linux
            const linux_info = getLinuxDeviceInfo(allocator);
            try obj.put("model", .{ .string = linux_info.model });
            try obj.put("os_version", .{ .string = linux_info.os_version });
            try obj.put("os_name", .{ .string = linux_info.os_name });
        } else {
            try obj.put("model", .{ .string = "Unknown" });
            try obj.put("os_version", .{ .string = "Unknown" });
        }

        return std.json.Value{ .object = obj };
    }

    const MacOSDeviceInfo = struct {
        model: []const u8,
        os_version: []const u8,
        os_name: []const u8,
        processor_count: u32,
    };

    fn getMacOSDeviceInfo(allocator: std.mem.Allocator) MacOSDeviceInfo {
        const builtin = @import("builtin");
        if (builtin.os.tag != .macos and builtin.os.tag != .ios) {
            return .{ .model = "Unknown", .os_version = "Unknown", .os_name = "Unknown", .processor_count = 1 };
        }

        var model: []const u8 = "Mac";
        var os_version: []const u8 = "Unknown";
        var os_name: []const u8 = "macOS";
        var processor_count: u32 = 1;

        // Get system info using sysctl
        const CTL_HW = 6;
        const HW_MODEL = 2;
        const HW_NCPU = 3;

        // Get model
        var model_buf: [256]u8 = undefined;
        var model_size: usize = model_buf.len;
        var mib = [_]c_int{ CTL_HW, HW_MODEL };

        const sysctl = @extern(*fn ([*]c_int, c_uint, ?*anyopaque, *usize, ?*anyopaque, usize) callconv(.c) c_int, .{ .name = "sysctl" });

        if (sysctl(&mib, 2, &model_buf, &model_size, null, 0) == 0) {
            model = allocator.dupe(u8, model_buf[0 .. model_size - 1]) catch "Mac";
        }

        // Get processor count
        var ncpu: c_int = 1;
        var ncpu_size: usize = @sizeOf(c_int);
        mib = [_]c_int{ CTL_HW, HW_NCPU };
        if (sysctl(&mib, 2, @ptrCast(&ncpu), &ncpu_size, null, 0) == 0) {
            processor_count = @intCast(ncpu);
        }

        // Get OS version using sysctlbyname
        var version_buf: [64]u8 = undefined;
        var version_size: usize = version_buf.len;

        const sysctlbyname = @extern(*fn ([*:0]const u8, ?*anyopaque, *usize, ?*anyopaque, usize) callconv(.c) c_int, .{ .name = "sysctlbyname" });

        if (sysctlbyname("kern.osproductversion", &version_buf, &version_size, null, 0) == 0) {
            os_version = allocator.dupe(u8, version_buf[0 .. version_size - 1]) catch "Unknown";
        }

        // Determine OS name
        if (builtin.os.tag == .ios) {
            os_name = "iOS";
        }

        return .{
            .model = model,
            .os_version = os_version,
            .os_name = os_name,
            .processor_count = processor_count,
        };
    }

    const LinuxDeviceInfo = struct {
        model: []const u8,
        os_version: []const u8,
        os_name: []const u8,
    };

    fn getLinuxDeviceInfo(allocator: std.mem.Allocator) LinuxDeviceInfo {
        var model: []const u8 = "Linux PC";
        var os_version: []const u8 = "Unknown";
        var os_name: []const u8 = "Linux";

        // Read /etc/os-release
        const io = io_context.get();
        const file = io_context.cwd().openFile(io, "/etc/os-release", .{}) catch {
            return .{ .model = model, .os_version = os_version, .os_name = os_name };
        };
        defer file.close(io);

        var buf: [4096]u8 = undefined;
        const bytes_read = file.readPositional(io, &.{&buf}, 0) catch return .{ .model = model, .os_version = os_version, .os_name = os_name };
        const content = buf[0..bytes_read];

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "PRETTY_NAME=")) {
                const value = std.mem.trim(u8, line["PRETTY_NAME=".len..], "\"");
                os_name = allocator.dupe(u8, value) catch "Linux";
            } else if (std.mem.startsWith(u8, line, "VERSION_ID=")) {
                const value = std.mem.trim(u8, line["VERSION_ID=".len..], "\"");
                os_version = allocator.dupe(u8, value) catch "Unknown";
            }
        }

        // Try to get hardware model from /sys/class/dmi/id/product_name
        const model_file = io_context.cwd().openFile(io, "/sys/class/dmi/id/product_name", .{}) catch {
            return .{ .model = model, .os_version = os_version, .os_name = os_name };
        };
        defer model_file.close(io);

        var model_buf: [256]u8 = undefined;
        const model_len = model_file.readPositional(io, &.{&model_buf}, 0) catch 0;
        if (model_len > 0) {
            model = allocator.dupe(u8, std.mem.trim(u8, model_buf[0..model_len], " \n\r\t")) catch "Linux PC";
        }

        return .{ .model = model, .os_version = os_version, .os_name = os_name };
    }

    /// Show toast/notification
    pub fn showToast(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        if (params == null or params.? != .object) {
            return JSBridgeError.InvalidParameters;
        }

        const obj = params.?.object;
        const message = if (obj.get("message")) |msg| msg.string else return JSBridgeError.InvalidParameters;
        const duration_str = if (obj.get("duration")) |dur| dur.string else "short";

        const platform = mobile.Platform.current();
        switch (platform) {
            .android => {
                // Call Android toast via mobile module
                const toast_duration: mobile.Android.ToastDuration = if (std.mem.eql(u8, duration_str, "long"))
                    .long
                else
                    .short;
                // Note: Android toast requires Context, which would come from the app's main activity
                // For now, log that toast was requested - full implementation needs Context access
                std.debug.print("[JSBridge] Android toast requested: {s}\n", .{message});
                _ = toast_duration;
            },
            .ios => {
                // Show iOS alert/toast
                const is_short = std.mem.eql(u8, duration_str, "short");
                mobile.iOS.showAlert(message, is_short);
            },
            .unknown => {},
        }

        var result = std.json.ObjectMap.init(allocator);
        try result.put("success", .{ .bool = true });

        return std.json.Value{ .object = result };
    }

    /// Trigger haptic feedback
    pub fn haptic(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        if (params == null or params.? != .object) {
            return JSBridgeError.InvalidParameters;
        }

        const obj = params.?.object;
        const haptic_type = if (obj.get("type")) |t| t.string else "selection";

        const platform = mobile.Platform.current();
        switch (platform) {
            .ios => {
                const haptic_enum: mobile.iOS.HapticType = blk: {
                    if (std.mem.eql(u8, haptic_type, "selection")) break :blk .selection;
                    if (std.mem.eql(u8, haptic_type, "impact_light")) break :blk .impact_light;
                    if (std.mem.eql(u8, haptic_type, "impact_medium")) break :blk .impact_medium;
                    if (std.mem.eql(u8, haptic_type, "impact_heavy")) break :blk .impact_heavy;
                    if (std.mem.eql(u8, haptic_type, "notification_success")) break :blk .notification_success;
                    if (std.mem.eql(u8, haptic_type, "notification_warning")) break :blk .notification_warning;
                    if (std.mem.eql(u8, haptic_type, "notification_error")) break :blk .notification_error;
                    break :blk .selection;
                };
                mobile.iOS.triggerHaptic(haptic_enum);
            },
            .android => {
                // Call Android vibration based on haptic_type
                const duration_ms: u64 = if (std.mem.eql(u8, haptic_type, "impact_heavy"))
                    100
                else if (std.mem.eql(u8, haptic_type, "impact_medium"))
                    50
                else
                    25;
                // Note: Android vibrate requires Context - log for now
                std.debug.print("[JSBridge] Android haptic requested: {s} ({d}ms)\n", .{ haptic_type, duration_ms });
            },
            .unknown => {},
        }

        var result = std.json.ObjectMap.init(allocator);
        try result.put("success", .{ .bool = true });

        return std.json.Value{ .object = result };
    }

    /// Request permission
    pub fn requestPermission(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        if (params == null or params.? != .object) {
            return JSBridgeError.InvalidParameters;
        }

        const obj = params.?.object;
        const permission_str = if (obj.get("permission")) |p| p.string else return JSBridgeError.InvalidParameters;

        // Map permission string to platform permission type
        var granted = false;
        var message: []const u8 = "Unknown permission";

        const platform = mobile.Platform.current();
        switch (platform) {
            .ios => {
                // iOS permissions are typically requested at first use
                // For now, log and return pending state
                std.debug.print("[JSBridge] iOS permission requested: {s}\n", .{permission_str});
                message = "iOS permission request initiated";
            },
            .android => {
                // Android runtime permissions
                std.debug.print("[JSBridge] Android permission requested: {s}\n", .{permission_str});
                message = "Android permission request initiated";
            },
            .unknown => {
                message = "Unknown platform";
            },
        }

        var result = std.json.ObjectMap.init(allocator);
        try result.put("granted", .{ .bool = granted });
        try result.put("message", .{ .string = message });

        return std.json.Value{ .object = result };
    }
};

/// Generate JavaScript bridge initialization code
pub fn generateBridgeScript(allocator: std.mem.Allocator) ![]u8 {
    const script =
        \\(function() {
        \\  // Create craft namespace
        \\  window.craft = window.craft || {};
        \\
        \\  // Message ID counter
        \\  let messageId = 0;
        \\  const callbacks = new Map();
        \\  const eventListeners = new Map();
        \\
        \\  // Send message to native layer
        \\  function sendMessage(method, params) {
        \\    return new Promise((resolve, reject) => {
        \\      const id = `msg_${messageId++}`;
        \\      callbacks.set(id, { resolve, reject });
        \\
        \\      const message = JSON.stringify({
        \\        id,
        \\        method,
        \\        params
        \\      });
        \\
        \\      // Platform-specific message sending
        \\      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.craft) {
        \\        // iOS
        \\        window.webkit.messageHandlers.craft.postMessage(message);
        \\      } else if (window.Android && window.Android.postMessage) {
        \\        // Android
        \\        window.Android.postMessage(message);
        \\      } else if (window.chrome && window.chrome.webview) {
        \\        // Windows WebView2
        \\        window.chrome.webview.postMessage(message);
        \\      } else {
        \\        // Desktop/Other
        \\        console.warn('No native bridge found, message:', message);
        \\        reject(new Error('Native bridge not available'));
        \\      }
        \\    });
        \\  }
        \\
        \\  // Handle response from native
        \\  window.craftHandleResponse = function(responseJson) {
        \\    const response = JSON.parse(responseJson);
        \\
        \\    if (response.event) {
        \\      // Event emission
        \\      const listeners = eventListeners.get(response.event) || [];
        \\      listeners.forEach(listener => listener(response.data));
        \\      return;
        \\    }
        \\
        \\    const callback = callbacks.get(response.id);
        \\    if (!callback) return;
        \\
        \\    callbacks.delete(response.id);
        \\
        \\    if (response.success) {
        \\      callback.resolve(response.result);
        \\    } else {
        \\      callback.reject(new Error(response.error || 'Unknown error'));
        \\    }
        \\  };
        \\
        \\  // Public API
        \\  window.craft.invoke = sendMessage;
        \\
        \\  window.craft.getPlatform = () => sendMessage('getPlatform', {});
        \\
        \\  window.craft.getDeviceInfo = () => sendMessage('getDeviceInfo', {});
        \\
        \\  window.craft.showToast = (message, duration = 'short') => {
        \\    return sendMessage('showToast', { message, duration });
        \\  };
        \\
        \\  window.craft.haptic = (type = 'selection') => {
        \\    return sendMessage('haptic', { type });
        \\  };
        \\
        \\  window.craft.requestPermission = (permission) => {
        \\    return sendMessage('requestPermission', { permission });
        \\  };
        \\
        \\  window.craft.on = (event, listener) => {
        \\    if (!eventListeners.has(event)) {
        \\      eventListeners.set(event, []);
        \\    }
        \\    eventListeners.get(event).push(listener);
        \\  };
        \\
        \\  window.craft.off = (event, listener) => {
        \\    if (!eventListeners.has(event)) return;
        \\    const listeners = eventListeners.get(event);
        \\    const index = listeners.indexOf(listener);
        \\    if (index > -1) {
        \\      listeners.splice(index, 1);
        \\    }
        \\  };
        \\
        \\  window.craft.emit = (event, data) => {
        \\    const listeners = eventListeners.get(event) || [];
        \\    listeners.forEach(listener => listener(data));
        \\  };
        \\
        \\  // Dispatch ready event
        \\  window.dispatchEvent(new CustomEvent('craftReady'));
        \\  window.craft.emit('ready', {});
        \\
        \\  console.log('Craft bridge initialized');
        \\})();
    ;

    return try allocator.dupe(u8, script);
}

// Tests
test "JSMessage parse" {
    const allocator = std.testing.allocator;

    const json = "{\"id\":\"msg_1\",\"method\":\"getPlatform\",\"params\":{}}";
    var message = try JSMessage.parse(allocator, json);
    defer message.deinit(allocator);

    try std.testing.expectEqualStrings("msg_1", message.id);
    try std.testing.expectEqualStrings("getPlatform", message.method);
}

test "JSResponse toJSON" {
    const allocator = std.testing.allocator;

    const response = JSResponse{
        .id = "msg_1",
        .success = true,
        .result = std.json.Value{ .bool = true },
    };

    const json = try response.toJSON(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"success\":true") != null);
}

test "JSBridge handler" {
    const allocator = std.testing.allocator;
    var bridge = JSBridge.init(allocator);
    defer bridge.deinit();

    try bridge.registerMethod("getPlatform", BuiltInHandlers.getPlatform);

    const request = "{\"id\":\"msg_1\",\"method\":\"getPlatform\",\"params\":{}}";
    const response = try bridge.handleMessage(request);
    defer allocator.free(response);

    try std.testing.expect(std.mem.indexOf(u8, response, "\"success\":true") != null);
}
