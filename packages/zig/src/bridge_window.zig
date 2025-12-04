const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Bridge handler for window control messages from JavaScript
pub const WindowBridge = struct {
    allocator: std.mem.Allocator,
    window_handle: ?*anyopaque = null,
    webview_handle: ?*anyopaque = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn setWindowHandle(self: *Self, handle: *anyopaque) void {
        self.window_handle = handle;
    }

    pub fn setWebViewHandle(self: *Self, handle: *anyopaque) void {
        self.webview_handle = handle;
    }

    /// Handle window-related messages from JavaScript
    /// action: the action name, data: optional JSON data string
    pub fn handleMessage(self: *Self, action: []const u8) !void {
        self.handleMessageWithData(action, null) catch |err| {
            self.reportError(action, err);
        };
    }

    /// Report error to JavaScript and log
    fn reportError(self: *Self, action: []const u8, err: anyerror) void {
        const bridge_err: BridgeError = switch (err) {
            BridgeError.WindowHandleNotSet => BridgeError.WindowHandleNotSet,
            BridgeError.WebViewHandleNotSet => BridgeError.WebViewHandleNotSet,
            BridgeError.MissingData => BridgeError.MissingData,
            BridgeError.InvalidJSON => BridgeError.InvalidJSON,
            BridgeError.InvalidParameter => BridgeError.InvalidParameter,
            else => BridgeError.NativeCallFailed,
        };
        bridge_error.sendErrorToJS(self.allocator, action, bridge_err);
    }

    pub fn handleMessageWithData(self: *Self, action: []const u8, data: ?[]const u8) !void {
        if (std.mem.eql(u8, action, "show")) {
            try self.show();
        } else if (std.mem.eql(u8, action, "hide")) {
            try self.hide();
        } else if (std.mem.eql(u8, action, "toggle")) {
            try self.toggle();
        } else if (std.mem.eql(u8, action, "focus")) {
            try self.focus();
        } else if (std.mem.eql(u8, action, "minimize")) {
            try self.minimize();
        } else if (std.mem.eql(u8, action, "maximize")) {
            try self.maximize();
        } else if (std.mem.eql(u8, action, "close")) {
            try self.close();
        } else if (std.mem.eql(u8, action, "center")) {
            try self.center();
        } else if (std.mem.eql(u8, action, "toggleFullscreen")) {
            try self.toggleFullscreen();
        } else if (std.mem.eql(u8, action, "setFullscreen")) {
            try self.setFullscreen(data);
        } else if (std.mem.eql(u8, action, "setSize")) {
            try self.setSize(data);
        } else if (std.mem.eql(u8, action, "setPosition")) {
            try self.setPosition(data);
        } else if (std.mem.eql(u8, action, "setTitle")) {
            try self.setTitle(data);
        } else if (std.mem.eql(u8, action, "reload")) {
            try self.reload();
        } else if (std.mem.eql(u8, action, "setVibrancy")) {
            try self.setVibrancy(data);
        } else if (std.mem.eql(u8, action, "setAlwaysOnTop")) {
            try self.setAlwaysOnTop(data);
        } else if (std.mem.eql(u8, action, "setOpacity")) {
            try self.setOpacity(data);
        } else if (std.mem.eql(u8, action, "setResizable")) {
            try self.setResizable(data);
        } else if (std.mem.eql(u8, action, "setBackgroundColor")) {
            try self.setBackgroundColor(data);
        } else if (std.mem.eql(u8, action, "setMinSize")) {
            try self.setMinSize(data);
        } else if (std.mem.eql(u8, action, "setMaxSize")) {
            try self.setMaxSize(data);
        } else if (std.mem.eql(u8, action, "setMovable")) {
            try self.setMovable(data);
        } else if (std.mem.eql(u8, action, "setHasShadow")) {
            try self.setHasShadow(data);
        } else if (std.mem.eql(u8, action, "setAspectRatio")) {
            try self.setAspectRatio(data);
        } else if (std.mem.eql(u8, action, "flashFrame")) {
            try self.flashFrame(data);
        } else if (std.mem.eql(u8, action, "setProgressBar")) {
            try self.setProgressBar(data);
        } else {
            return BridgeError.UnknownAction;
        }
    }

    /// Get window handle or return error
    fn requireWindowHandle(self: *Self) BridgeError!*anyopaque {
        return self.window_handle orelse BridgeError.WindowHandleNotSet;
    }

    /// Get webview handle or return error
    fn requireWebViewHandle(self: *Self) BridgeError!*anyopaque {
        return self.webview_handle orelse BridgeError.WebViewHandleNotSet;
    }

    fn show(self: *Self) !void {
        const handle = try self.requireWindowHandle();

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            macos.showWindow(handle);
        }
    }

    fn hide(self: *Self) !void {
        const handle = try self.requireWindowHandle();

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            macos.hideWindow(handle);
        }
    }

    fn toggle(self: *Self) !void {
        const handle = try self.requireWindowHandle();

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            macos.toggleWindow(handle);
        }
    }

    fn minimize(self: *Self) !void {
        const handle = try self.requireWindowHandle();

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            macos.minimizeWindow(handle);
        }
    }

    fn close(self: *Self) !void {
        const handle = try self.requireWindowHandle();

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            macos.closeWindow(handle);
        }
    }

    fn focus(self: *Self) !void {
        const handle = try self.requireWindowHandle();

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            // makeKeyAndOrderFront focuses the window
            macos.showWindow(handle);
        }
    }

    fn maximize(self: *Self) !void {
        const handle = try self.requireWindowHandle();

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            // On macOS, "zoom" is the maximize equivalent
            macos.msgSendVoid0(handle, "zoom:");
        }
    }

    fn center(self: *Self) !void {
        const handle = try self.requireWindowHandle();

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            macos.msgSendVoid0(handle, "center");
        }
    }

    fn toggleFullscreen(self: *Self) !void {
        const handle = try self.requireWindowHandle();

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            macos.toggleFullscreen(handle);
        }
    }

    fn setFullscreen(self: *Self, data: ?[]const u8) !void {
        const handle = try self.requireWindowHandle();
        _ = data; // TODO: Parse fullscreen boolean from data

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            macos.toggleFullscreen(handle);
        }
    }

    fn setSize(self: *Self, data: ?[]const u8) !void {
        const handle = try self.requireWindowHandle();
        const json_data = data orelse return BridgeError.MissingData;

        // Simple JSON parsing for {"width": N, "height": M}
        var width: u32 = 800;
        var height: u32 = 600;

        // Skip whitespace and find digits after "width":
        if (std.mem.indexOf(u8, json_data, "\"width\":")) |idx| {
            var start = idx + 8;
            // Skip whitespace
            while (start < json_data.len and (json_data[start] == ' ' or json_data[start] == '\t')) : (start += 1) {}
            var end = start;
            while (end < json_data.len and json_data[end] >= '0' and json_data[end] <= '9') : (end += 1) {}
            if (end > start) {
                width = std.fmt.parseInt(u32, json_data[start..end], 10) catch 800;
            }
        }

        if (std.mem.indexOf(u8, json_data, "\"height\":")) |idx| {
            var start = idx + 9;
            while (start < json_data.len and (json_data[start] == ' ' or json_data[start] == '\t')) : (start += 1) {}
            var end = start;
            while (end < json_data.len and json_data[end] >= '0' and json_data[end] <= '9') : (end += 1) {}
            if (end > start) {
                height = std.fmt.parseInt(u32, json_data[start..end], 10) catch 600;
            }
        }

        std.debug.print("[WindowBridge] setSize: {}x{}\n", .{ width, height });

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            macos.setWindowSize(handle, width, height);
        }
    }

    fn setPosition(self: *Self, data: ?[]const u8) !void {
        const handle = try self.requireWindowHandle();
        const json_data = data orelse return BridgeError.MissingData;

        var x: i32 = 100;
        var y: i32 = 100;

        if (std.mem.indexOf(u8, json_data, "\"x\":")) |idx| {
            const start = idx + 4;
            var end = start;
            while (end < json_data.len and ((json_data[end] >= '0' and json_data[end] <= '9') or json_data[end] == '-')) : (end += 1) {}
            if (end > start) {
                x = std.fmt.parseInt(i32, json_data[start..end], 10) catch 100;
            }
        }

        if (std.mem.indexOf(u8, json_data, "\"y\":")) |idx| {
            const start = idx + 4;
            var end = start;
            while (end < json_data.len and ((json_data[end] >= '0' and json_data[end] <= '9') or json_data[end] == '-')) : (end += 1) {}
            if (end > start) {
                y = std.fmt.parseInt(i32, json_data[start..end], 10) catch 100;
            }
        }

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            macos.setWindowPosition(handle, x, y);
        }
    }

    fn setTitle(self: *Self, data: ?[]const u8) !void {
        const handle = try self.requireWindowHandle();
        const json_data = data orelse return BridgeError.MissingData;

        // Extract title from {"title": "..."}
        if (std.mem.indexOf(u8, json_data, "\"title\":\"")) |idx| {
            const start = idx + 9;
            if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                const title = json_data[start..end];

                if (builtin.os.tag == .macos) {
                    const macos = @import("macos.zig");
                    const title_cstr = try self.allocator.dupeZ(u8, title);
                    defer self.allocator.free(title_cstr);

                    const NSString = macos.getClass("NSString");
                    const str_alloc = macos.msgSend0(NSString, "alloc");
                    const ns_title = macos.msgSend1(str_alloc, "initWithUTF8String:", title_cstr.ptr);
                    _ = macos.msgSend1(handle, "setTitle:", ns_title);
                }
            }
        } else {
            return BridgeError.InvalidJSON;
        }
    }

    fn reload(self: *Self) !void {
        const handle = try self.requireWebViewHandle();

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            macos.reloadWindow(handle);
        }
    }

    fn setVibrancy(self: *Self, data: ?[]const u8) !void {
        const handle = try self.requireWindowHandle();

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Parse vibrancy type from {"vibrancy": "..."}
            var vibrancy_type: []const u8 = "none";
            if (data) |json_data| {
                if (std.mem.indexOf(u8, json_data, "\"vibrancy\":\"")) |idx| {
                    const start = idx + 12;
                    if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                        vibrancy_type = json_data[start..end];
                    }
                }
            }

            std.debug.print("[WindowBridge] setVibrancy: {s}\n", .{vibrancy_type});

            // Get NSVisualEffectView material enum value
            // Common values: 0=appearance-based, 1=light, 2=dark, 3=titlebar, 4=selection
            // 10=menu, 11=popover, 12=sidebar, 13=header, 14=sheet, 17=HUD, etc.
            var material: c_long = 0;
            if (std.mem.eql(u8, vibrancy_type, "sidebar")) {
                material = 12;
            } else if (std.mem.eql(u8, vibrancy_type, "header")) {
                material = 13;
            } else if (std.mem.eql(u8, vibrancy_type, "sheet")) {
                material = 14;
            } else if (std.mem.eql(u8, vibrancy_type, "menu")) {
                material = 10;
            } else if (std.mem.eql(u8, vibrancy_type, "popover")) {
                material = 11;
            } else if (std.mem.eql(u8, vibrancy_type, "fullscreen-ui")) {
                material = 15;
            } else if (std.mem.eql(u8, vibrancy_type, "hud")) {
                material = 17;
            } else if (std.mem.eql(u8, vibrancy_type, "titlebar")) {
                material = 3;
            } else if (std.mem.eql(u8, vibrancy_type, "none") or std.mem.eql(u8, vibrancy_type, "null")) {
                // Remove vibrancy - set window to opaque
                _ = macos.msgSend1(handle, "setOpaque:", true);
                return;
            }

            // Make window non-opaque for vibrancy
            _ = macos.msgSend1(handle, "setOpaque:", false);

            // Get content view and set up visual effect
            const content_view = macos.msgSend0(handle, "contentView");
            if (content_view != null) {
                // Create NSVisualEffectView
                const NSVisualEffectView = macos.getClass("NSVisualEffectView");
                const effect_view = macos.msgSend0(macos.msgSend0(NSVisualEffectView, "alloc"), "init");

                // Set material
                _ = macos.msgSend1(effect_view, "setMaterial:", material);

                // Set blending mode (behindWindow = 0)
                _ = macos.msgSend1(effect_view, "setBlendingMode:", @as(c_long, 0));

                // Set state (followsWindowActiveState = 1)
                _ = macos.msgSend1(effect_view, "setState:", @as(c_long, 1));

                // Set as background of content view
                _ = macos.msgSend3(content_view, "addSubview:positioned:relativeTo:", effect_view, @as(c_long, -1), @as(?*anyopaque, null));
            }
        }
    }

    fn setAlwaysOnTop(self: *Self, data: ?[]const u8) !void {
        const handle = try self.requireWindowHandle();

        var always_on_top = true;
        if (data) |json_data| {
            // Parse {"alwaysOnTop": true/false}
            if (std.mem.indexOf(u8, json_data, "false")) |_| {
                always_on_top = false;
            }
        }

        std.debug.print("[WindowBridge] setAlwaysOnTop: {}\n", .{always_on_top});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            // NSFloatingWindowLevel = 3, NSNormalWindowLevel = 0
            const level: c_long = if (always_on_top) 3 else 0;
            _ = macos.msgSend1(handle, "setLevel:", level);
        }
    }

    fn setOpacity(self: *Self, data: ?[]const u8) !void {
        const handle = try self.requireWindowHandle();

        var opacity: f64 = 1.0;
        if (data) |json_data| {
            // Parse {"opacity": 0.8}
            if (std.mem.indexOf(u8, json_data, "\"opacity\":")) |idx| {
                var start = idx + 10;
                while (start < json_data.len and (json_data[start] == ' ' or json_data[start] == '\t')) : (start += 1) {}
                var end = start;
                while (end < json_data.len and ((json_data[end] >= '0' and json_data[end] <= '9') or json_data[end] == '.')) : (end += 1) {}
                if (end > start) {
                    opacity = std.fmt.parseFloat(f64, json_data[start..end]) catch 1.0;
                }
            }
        }

        // Clamp to valid range
        opacity = @max(0.0, @min(1.0, opacity));
        std.debug.print("[WindowBridge] setOpacity: {d:.2}\n", .{opacity});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            const msg = @as(*const fn (@TypeOf(handle), macos.objc.SEL, f64) callconv(.c) void, @ptrCast(&macos.objc.objc_msgSend));
            msg(handle, macos.sel("setAlphaValue:"), opacity);
        }
    }

    fn setResizable(self: *Self, data: ?[]const u8) !void {
        const handle = try self.requireWindowHandle();

        var resizable = true;
        if (data) |json_data| {
            if (std.mem.indexOf(u8, json_data, "false")) |_| {
                resizable = false;
            }
        }

        std.debug.print("[WindowBridge] setResizable: {}\n", .{resizable});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            // Get current style mask
            const current_mask_ptr = macos.msgSend0(handle, "styleMask");
            var style_mask = @as(c_ulong, @intFromPtr(current_mask_ptr));

            // NSWindowStyleMaskResizable = 1 << 3 = 8
            const resizable_mask: c_ulong = 8;
            if (resizable) {
                style_mask |= resizable_mask;
            } else {
                style_mask &= ~resizable_mask;
            }

            _ = macos.msgSend1(handle, "setStyleMask:", style_mask);
        }
    }

    fn setBackgroundColor(self: *Self, data: ?[]const u8) !void {
        const handle = try self.requireWindowHandle();

        // Default to white
        var r: f64 = 1.0;
        var g: f64 = 1.0;
        var b: f64 = 1.0;
        var a: f64 = 1.0;

        if (data) |json_data| {
            // Parse {"r": 0.5, "g": 0.5, "b": 0.5, "a": 1.0} or {"color": "#RRGGBB"}
            // Try hex color first
            if (std.mem.indexOf(u8, json_data, "\"color\":\"#")) |idx| {
                const start = idx + 10;
                if (start + 6 <= json_data.len) {
                    const hex = json_data[start .. start + 6];
                    // Parse hex RRGGBB
                    r = @as(f64, @floatFromInt(std.fmt.parseInt(u8, hex[0..2], 16) catch 255)) / 255.0;
                    g = @as(f64, @floatFromInt(std.fmt.parseInt(u8, hex[2..4], 16) catch 255)) / 255.0;
                    b = @as(f64, @floatFromInt(std.fmt.parseInt(u8, hex[4..6], 16) catch 255)) / 255.0;
                }
            } else {
                // Try RGBA components
                if (std.mem.indexOf(u8, json_data, "\"r\":")) |idx| {
                    var start = idx + 4;
                    while (start < json_data.len and (json_data[start] == ' ' or json_data[start] == '\t')) : (start += 1) {}
                    var end = start;
                    while (end < json_data.len and ((json_data[end] >= '0' and json_data[end] <= '9') or json_data[end] == '.')) : (end += 1) {}
                    if (end > start) {
                        r = std.fmt.parseFloat(f64, json_data[start..end]) catch 1.0;
                    }
                }
                if (std.mem.indexOf(u8, json_data, "\"g\":")) |idx| {
                    var start = idx + 4;
                    while (start < json_data.len and (json_data[start] == ' ' or json_data[start] == '\t')) : (start += 1) {}
                    var end = start;
                    while (end < json_data.len and ((json_data[end] >= '0' and json_data[end] <= '9') or json_data[end] == '.')) : (end += 1) {}
                    if (end > start) {
                        g = std.fmt.parseFloat(f64, json_data[start..end]) catch 1.0;
                    }
                }
                if (std.mem.indexOf(u8, json_data, "\"b\":")) |idx| {
                    var start = idx + 4;
                    while (start < json_data.len and (json_data[start] == ' ' or json_data[start] == '\t')) : (start += 1) {}
                    var end = start;
                    while (end < json_data.len and ((json_data[end] >= '0' and json_data[end] <= '9') or json_data[end] == '.')) : (end += 1) {}
                    if (end > start) {
                        b = std.fmt.parseFloat(f64, json_data[start..end]) catch 1.0;
                    }
                }
                if (std.mem.indexOf(u8, json_data, "\"a\":")) |idx| {
                    var start = idx + 4;
                    while (start < json_data.len and (json_data[start] == ' ' or json_data[start] == '\t')) : (start += 1) {}
                    var end = start;
                    while (end < json_data.len and ((json_data[end] >= '0' and json_data[end] <= '9') or json_data[end] == '.')) : (end += 1) {}
                    if (end > start) {
                        a = std.fmt.parseFloat(f64, json_data[start..end]) catch 1.0;
                    }
                }
            }
        }

        std.debug.print("[WindowBridge] setBackgroundColor: r={d:.2}, g={d:.2}, b={d:.2}, a={d:.2}\n", .{ r, g, b, a });

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Create NSColor
            const NSColor = macos.getClass("NSColor");
            const color_sel = macos.sel("colorWithRed:green:blue:alpha:");
            const msg = @as(*const fn (macos.objc.Class, macos.objc.SEL, f64, f64, f64, f64) callconv(.c) macos.objc.id, @ptrCast(&macos.objc.objc_msgSend));
            const color = msg(NSColor, color_sel, r, g, b, a);

            // Set window background color
            _ = macos.msgSend1(handle, "setBackgroundColor:", color);
        }
    }

    fn setMinSize(self: *Self, data: ?[]const u8) !void {
        const handle = try self.requireWindowHandle();

        var width: u32 = 100;
        var height: u32 = 100;

        if (data) |json_data| {
            // Parse {"width": 400, "height": 300}
            if (std.mem.indexOf(u8, json_data, "\"width\":")) |idx| {
                var start = idx + 8;
                while (start < json_data.len and (json_data[start] == ' ' or json_data[start] == '\t')) : (start += 1) {}
                var end = start;
                while (end < json_data.len and json_data[end] >= '0' and json_data[end] <= '9') : (end += 1) {}
                if (end > start) {
                    width = std.fmt.parseInt(u32, json_data[start..end], 10) catch 100;
                }
            }
            if (std.mem.indexOf(u8, json_data, "\"height\":")) |idx| {
                var start = idx + 9;
                while (start < json_data.len and (json_data[start] == ' ' or json_data[start] == '\t')) : (start += 1) {}
                var end = start;
                while (end < json_data.len and json_data[end] >= '0' and json_data[end] <= '9') : (end += 1) {}
                if (end > start) {
                    height = std.fmt.parseInt(u32, json_data[start..end], 10) catch 100;
                }
            }
        }

        std.debug.print("[WindowBridge] setMinSize: {}x{}\n", .{ width, height });

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            // Create NSSize and set minimum size
            const size = macos.NSSize{ .width = @floatFromInt(width), .height = @floatFromInt(height) };
            const msg = @as(*const fn (@TypeOf(handle), macos.objc.SEL, macos.NSSize) callconv(.c) void, @ptrCast(&macos.objc.objc_msgSend));
            msg(handle, macos.sel("setMinSize:"), size);
        }
    }

    fn setMaxSize(self: *Self, data: ?[]const u8) !void {
        const handle = try self.requireWindowHandle();

        var width: u32 = 10000;
        var height: u32 = 10000;

        if (data) |json_data| {
            if (std.mem.indexOf(u8, json_data, "\"width\":")) |idx| {
                var start = idx + 8;
                while (start < json_data.len and (json_data[start] == ' ' or json_data[start] == '\t')) : (start += 1) {}
                var end = start;
                while (end < json_data.len and json_data[end] >= '0' and json_data[end] <= '9') : (end += 1) {}
                if (end > start) {
                    width = std.fmt.parseInt(u32, json_data[start..end], 10) catch 10000;
                }
            }
            if (std.mem.indexOf(u8, json_data, "\"height\":")) |idx| {
                var start = idx + 9;
                while (start < json_data.len and (json_data[start] == ' ' or json_data[start] == '\t')) : (start += 1) {}
                var end = start;
                while (end < json_data.len and json_data[end] >= '0' and json_data[end] <= '9') : (end += 1) {}
                if (end > start) {
                    height = std.fmt.parseInt(u32, json_data[start..end], 10) catch 10000;
                }
            }
        }

        std.debug.print("[WindowBridge] setMaxSize: {}x{}\n", .{ width, height });

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            const size = macos.NSSize{ .width = @floatFromInt(width), .height = @floatFromInt(height) };
            const msg = @as(*const fn (@TypeOf(handle), macos.objc.SEL, macos.NSSize) callconv(.c) void, @ptrCast(&macos.objc.objc_msgSend));
            msg(handle, macos.sel("setMaxSize:"), size);
        }
    }

    fn setMovable(self: *Self, data: ?[]const u8) !void {
        const handle = try self.requireWindowHandle();

        var movable = true;
        if (data) |json_data| {
            if (std.mem.indexOf(u8, json_data, "false")) |_| {
                movable = false;
            }
        }

        std.debug.print("[WindowBridge] setMovable: {}\n", .{movable});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            _ = macos.msgSend1(handle, "setMovable:", @as(c_int, if (movable) 1 else 0));
        }
    }

    fn setHasShadow(self: *Self, data: ?[]const u8) !void {
        const handle = try self.requireWindowHandle();

        var has_shadow = true;
        if (data) |json_data| {
            if (std.mem.indexOf(u8, json_data, "false")) |_| {
                has_shadow = false;
            }
        }

        std.debug.print("[WindowBridge] setHasShadow: {}\n", .{has_shadow});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            _ = macos.msgSend1(handle, "setHasShadow:", @as(c_int, if (has_shadow) 1 else 0));
        }
    }

    /// Set aspect ratio for window resizing
    /// JSON: {"width": 16, "height": 9} or {"ratio": 1.777}
    fn setAspectRatio(self: *Self, data: ?[]const u8) !void {
        const handle = try self.requireWindowHandle();

        var width: f64 = 0;
        var height: f64 = 0;

        if (data) |json_data| {
            // Try ratio first
            if (std.mem.indexOf(u8, json_data, "\"ratio\":")) |idx| {
                var start = idx + 8;
                while (start < json_data.len and (json_data[start] == ' ' or json_data[start] == '\t')) : (start += 1) {}
                var end = start;
                while (end < json_data.len and ((json_data[end] >= '0' and json_data[end] <= '9') or json_data[end] == '.')) : (end += 1) {}
                if (end > start) {
                    const ratio = std.fmt.parseFloat(f64, json_data[start..end]) catch 0;
                    if (ratio > 0) {
                        width = ratio;
                        height = 1.0;
                    }
                }
            } else {
                // Parse width/height
                if (std.mem.indexOf(u8, json_data, "\"width\":")) |idx| {
                    var start = idx + 8;
                    while (start < json_data.len and (json_data[start] == ' ' or json_data[start] == '\t')) : (start += 1) {}
                    var end = start;
                    while (end < json_data.len and ((json_data[end] >= '0' and json_data[end] <= '9') or json_data[end] == '.')) : (end += 1) {}
                    if (end > start) {
                        width = std.fmt.parseFloat(f64, json_data[start..end]) catch 0;
                    }
                }
                if (std.mem.indexOf(u8, json_data, "\"height\":")) |idx| {
                    var start = idx + 9;
                    while (start < json_data.len and (json_data[start] == ' ' or json_data[start] == '\t')) : (start += 1) {}
                    var end = start;
                    while (end < json_data.len and ((json_data[end] >= '0' and json_data[end] <= '9') or json_data[end] == '.')) : (end += 1) {}
                    if (end > start) {
                        height = std.fmt.parseFloat(f64, json_data[start..end]) catch 0;
                    }
                }
            }
        }

        std.debug.print("[WindowBridge] setAspectRatio: {d:.2}:{d:.2}\n", .{ width, height });

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            if (width > 0 and height > 0) {
                // Set aspect ratio using setContentAspectRatio:
                const size = macos.NSSize{ .width = width, .height = height };
                const msg = @as(*const fn (@TypeOf(handle), macos.objc.SEL, macos.NSSize) callconv(.c) void, @ptrCast(&macos.objc.objc_msgSend));
                msg(handle, macos.sel("setContentAspectRatio:"), size);
            } else {
                // Clear aspect ratio by setting to 0,0
                const size = macos.NSSize{ .width = 0, .height = 0 };
                const msg = @as(*const fn (@TypeOf(handle), macos.objc.SEL, macos.NSSize) callconv(.c) void, @ptrCast(&macos.objc.objc_msgSend));
                msg(handle, macos.sel("setContentAspectRatio:"), size);
            }
        }
    }

    /// Flash the window frame to get user attention (bounce dock icon on macOS)
    /// JSON: {"flash": true} or {"count": 3}
    fn flashFrame(self: *Self, data: ?[]const u8) !void {
        _ = try self.requireWindowHandle();

        var should_flash = true;
        if (data) |json_data| {
            if (std.mem.indexOf(u8, json_data, "false")) |_| {
                should_flash = false;
            }
        }

        std.debug.print("[WindowBridge] flashFrame: {}\n", .{should_flash});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            if (should_flash) {
                // Get NSApplication and request user attention
                const NSApplication = macos.getClass("NSApplication");
                const app = macos.msgSend0(NSApplication, "sharedApplication");

                // NSCriticalRequest = 0, NSInformationalRequest = 10
                // Use informational (bounce once) by default
                const request_type: c_long = 10;
                _ = macos.msgSend1(app, "requestUserAttention:", request_type);
            } else {
                // Cancel any pending attention request
                const NSApplication = macos.getClass("NSApplication");
                const app = macos.msgSend0(NSApplication, "sharedApplication");
                _ = macos.msgSend1(app, "cancelUserAttentionRequest:", @as(c_long, 0));
            }
        }
    }

    /// Set dock progress bar (macOS only)
    /// JSON: {"progress": 0.5} (0.0-1.0) or {"progress": -1} to hide
    fn setProgressBar(self: *Self, data: ?[]const u8) !void {
        _ = try self.requireWindowHandle();

        var progress: f64 = -1;
        if (data) |json_data| {
            if (std.mem.indexOf(u8, json_data, "\"progress\":")) |idx| {
                var start = idx + 11;
                while (start < json_data.len and (json_data[start] == ' ' or json_data[start] == '\t')) : (start += 1) {}
                var end = start;
                // Allow negative numbers
                if (start < json_data.len and json_data[start] == '-') {
                    end += 1;
                }
                while (end < json_data.len and ((json_data[end] >= '0' and json_data[end] <= '9') or json_data[end] == '.')) : (end += 1) {}
                if (end > start) {
                    progress = std.fmt.parseFloat(f64, json_data[start..end]) catch -1;
                }
            }
        }

        std.debug.print("[WindowBridge] setProgressBar: {d:.2}\n", .{progress});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Get dock tile from NSApplication
            const NSApplication = macos.getClass("NSApplication");
            const app = macos.msgSend0(NSApplication, "sharedApplication");
            const dock_tile = macos.msgSend0(app, "dockTile");

            if (progress < 0) {
                // Hide progress indicator
                _ = macos.msgSend1(dock_tile, "setShowsApplicationBadge:", @as(c_int, 0));
                // Remove any existing progress view
                _ = macos.msgSend1(dock_tile, "setContentView:", @as(?*anyopaque, null));
            } else {
                // Clamp progress to 0-1
                const clamped = @max(0.0, @min(1.0, progress));

                // Create NSProgressIndicator for dock
                const NSProgressIndicator = macos.getClass("NSProgressIndicator");
                const indicator = macos.msgSend0(macos.msgSend0(NSProgressIndicator, "alloc"), "init");

                // Set determinate mode
                _ = macos.msgSend1(indicator, "setIndeterminate:", @as(c_int, 0));

                // Set min/max values
                const msg_double = @as(*const fn (@TypeOf(indicator), macos.objc.SEL, f64) callconv(.c) void, @ptrCast(&macos.objc.objc_msgSend));
                msg_double(indicator, macos.sel("setMinValue:"), 0.0);
                msg_double(indicator, macos.sel("setMaxValue:"), 1.0);
                msg_double(indicator, macos.sel("setDoubleValue:"), clamped);

                // Set content view on dock tile
                _ = macos.msgSend1(dock_tile, "setContentView:", indicator);
                _ = macos.msgSend0(dock_tile, "display");
            }
        }
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};

// Unit tests for WindowBridge
test "WindowBridge.requireWindowHandle returns error when null" {
    const testing = std.testing;
    var bridge = WindowBridge.init(testing.allocator);
    defer bridge.deinit();

    const result = bridge.requireWindowHandle();
    try testing.expectError(BridgeError.WindowHandleNotSet, result);
}

test "WindowBridge.requireWebViewHandle returns error when null" {
    const testing = std.testing;
    var bridge = WindowBridge.init(testing.allocator);
    defer bridge.deinit();

    const result = bridge.requireWebViewHandle();
    try testing.expectError(BridgeError.WebViewHandleNotSet, result);
}
