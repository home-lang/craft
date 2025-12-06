const std = @import("std");
const builtin = @import("builtin");
const tray_menu = @import("tray_menu.zig");
const bridge_error = @import("bridge_error.zig");
const logging = @import("logging.zig");
const icons = @import("icons.zig");

const log = logging.tray;

const BridgeError = bridge_error.BridgeError;

/// Decode Unicode escape sequences like \Ud83c\Udf45 to actual UTF-8
/// Unicode emoji are represented as surrogate pairs in UTF-16:
/// 🍅 (U+1F345) = \Ud83c\Udf45 (high surrogate d83c + low surrogate df45)
fn decodeUnicodeEscapes(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, input.len);
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        // Check for \Uxxxx pattern (6 chars total)
        if (i + 6 <= input.len and input[i] == '\\' and (input[i + 1] == 'U' or input[i + 1] == 'u')) {
            const hex_str = input[i + 2 .. i + 6];
            const codepoint = std.fmt.parseInt(u16, hex_str, 16) catch {
                // If parsing fails, just copy the backslash and continue
                try result.append(allocator, input[i]);
                i += 1;
                continue;
            };

            // Check if this is a high surrogate (start of surrogate pair)
            if (codepoint >= 0xD800 and codepoint <= 0xDBFF) {
                // This is a high surrogate, check for low surrogate
                if (i + 12 <= input.len and
                    input[i + 6] == '\\' and
                    (input[i + 7] == 'U' or input[i + 7] == 'u'))
                {
                    const low_hex = input[i + 8 .. i + 12];
                    const low_surrogate = std.fmt.parseInt(u16, low_hex, 16) catch {
                        // Failed to parse low surrogate, copy high as-is
                        try result.append(allocator, input[i]);
                        i += 1;
                        continue;
                    };

                    if (low_surrogate >= 0xDC00 and low_surrogate <= 0xDFFF) {
                        // Valid surrogate pair! Convert to UTF-32 codepoint
                        const high: u32 = codepoint;
                        const low: u32 = low_surrogate;
                        const utf32: u21 = @intCast(0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00));

                        // Encode as UTF-8
                        var utf8_buf: [4]u8 = undefined;
                        const len = std.unicode.utf8Encode(utf32, &utf8_buf) catch {
                            // Encoding failed, skip both surrogates
                            i += 12;
                            continue;
                        };
                        try result.appendSlice(allocator, utf8_buf[0..len]);
                        i += 12; // Skip both \Uxxxx\Uxxxx
                        continue;
                    }
                }
            }

            // Not a surrogate pair, treat as single codepoint
            var utf8_buf: [4]u8 = undefined;
            const len = std.unicode.utf8Encode(@intCast(codepoint), &utf8_buf) catch {
                // Encoding failed, skip this escape
                i += 6;
                continue;
            };
            try result.appendSlice(allocator, utf8_buf[0..len]);
            i += 6;
            continue;
        }

        try result.append(allocator, input[i]);
        i += 1;
    }

    return result.toOwnedSlice(allocator);
}

/// Bridge handler for system tray messages from JavaScript
pub const TrayBridge = struct {
    allocator: std.mem.Allocator,
    tray_handle: ?*anyopaque = null,
    current_menu: ?*anyopaque = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn setTrayHandle(self: *Self, handle: *anyopaque) void {
        self.tray_handle = handle;
    }

    /// Handle tray-related messages from JavaScript
    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        self.handleMessageInternal(action, data) catch |err| {
            self.reportError(action, err);
        };
    }

    fn handleMessageInternal(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "setTitle")) {
            try self.setTitle(data);
        } else if (std.mem.eql(u8, action, "setTooltip")) {
            try self.setTooltip(data);
        } else if (std.mem.eql(u8, action, "setMenu")) {
            try self.setMenu(data);
        } else if (std.mem.eql(u8, action, "pollActions")) {
            try self.pollActions();
        } else if (std.mem.eql(u8, action, "hide")) {
            try self.hide();
        } else if (std.mem.eql(u8, action, "show")) {
            try self.showTray();
        } else if (std.mem.eql(u8, action, "setIcon")) {
            try self.setIcon(data);
        } else if (std.mem.eql(u8, action, "setBadge")) {
            try self.setBadge(data);
        } else {
            return BridgeError.UnknownAction;
        }
    }

    /// Report error to JavaScript and log
    fn reportError(self: *Self, action: []const u8, err: anyerror) void {
        const bridge_err: BridgeError = switch (err) {
            BridgeError.TrayHandleNotSet => BridgeError.TrayHandleNotSet,
            BridgeError.MissingData => BridgeError.MissingData,
            BridgeError.InvalidJSON => BridgeError.InvalidJSON,
            else => BridgeError.NativeCallFailed,
        };
        bridge_error.sendErrorToJS(self.allocator, action, bridge_err);
    }

    /// Get tray handle or return error
    fn requireTrayHandle(self: *Self) BridgeError!*anyopaque {
        return self.tray_handle orelse BridgeError.TrayHandleNotSet;
    }

    fn pollActions(self: *Self) !void {
        _ = self;

        // Pop the next action from the queue
        if (tray_menu.getPendingAction()) |action| {
            log.debug("Polling found action: {s}", .{action});

            // Call the JavaScript global function to deliver the action
            const macos = @import("macos.zig");
            var buf: [256]u8 = undefined;
            const js = try std.fmt.bufPrint(&buf,
                \\if(window.__craftDeliverAction)window.__craftDeliverAction('{s}');
            , .{action});

            macos.tryEvalJS(js) catch |err| {
                log.debug("Failed to deliver action: {}", .{err});
            };
        }
    }

    fn setTitle(self: *Self, title: []const u8) !void {
        const handle = try self.requireTrayHandle();

        if (builtin.os.tag == .macos) {
            // Decode Unicode escapes like \Ud83c\Udf45 to actual UTF-8
            const decoded_title = try decodeUnicodeEscapes(self.allocator, title);
            defer self.allocator.free(decoded_title);

            const macos = @import("tray.zig");
            try macos.macosSetTitle(handle, decoded_title);
        }
    }

    fn setTooltip(self: *Self, tooltip: []const u8) !void {
        const handle = try self.requireTrayHandle();

        if (builtin.os.tag == .macos) {
            const macos = @import("tray.zig");
            try macos.macosSetTooltip(handle, tooltip);
        }
    }

    fn setMenu(self: *Self, menu_json: []const u8) !void {
        const handle = try self.requireTrayHandle();

        // Unescape the JSON (replace \" with ")
        var unescaped = try self.allocator.alloc(u8, menu_json.len);
        defer self.allocator.free(unescaped);

        var write_idx: usize = 0;
        var i: usize = 0;
        while (i < menu_json.len) : (i += 1) {
            if (menu_json[i] == '\\' and i + 1 < menu_json.len and menu_json[i + 1] == '"') {
                // Skip the backslash, copy the quote
                unescaped[write_idx] = '"';
                write_idx += 1;
                i += 1; // Skip next character (the quote)
            } else {
                unescaped[write_idx] = menu_json[i];
                write_idx += 1;
            }
        }

        const clean_json = unescaped[0..write_idx];

        // Parse the menu JSON
        const menu_items = try tray_menu.parseMenuJSON(self.allocator, clean_json);
        defer self.allocator.free(menu_items);

        // Create NSMenu (macOS)
        if (builtin.os.tag == .macos) {
            // Clean up previous menu if exists
            if (self.current_menu) |old_menu| {
                tray_menu.destroyNSMenu(old_menu);
            }

            // Create new menu
            const menu = try tray_menu.createNSMenu(self.allocator, menu_items);
            self.current_menu = menu;

            // Attach to tray
            const macos = @import("tray.zig");
            try macos.macosSetMenu(handle, menu);
        }
    }

    fn hide(self: *Self) !void {
        const handle = try self.requireTrayHandle();

        log.debug("hide", .{});

        if (builtin.os.tag == .macos) {
            const tray = @import("tray.zig");
            tray.macosHide(handle);
        }
    }

    fn showTray(self: *Self) !void {
        const handle = try self.requireTrayHandle();

        log.debug("show", .{});

        if (builtin.os.tag == .macos) {
            const tray = @import("tray.zig");
            tray.macosShow(handle);
        }
    }

    fn setIcon(self: *Self, icon_name: []const u8) !void {
        const handle = try self.requireTrayHandle();

        log.debug("setIcon: {s}", .{icon_name});

        // First try to resolve icon through cross-platform icons module
        const resolved_name = if (icons.getIconByName(icon_name)) |icon| blk: {
            const platform_icon = icons.getPlatformIcon(icon);
            if (platform_icon.kind == .sf_symbol and platform_icon.value.len > 0) {
                break :blk platform_icon.value;
            }
            break :blk icon_name;
        } else icon_name;

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Get NSStatusItem button
            const button = macos.msgSend0(handle, "button");
            if (button == null) return;

            // Try to load SF Symbol
            const NSImage = macos.getClass("NSImage");

            // Use resolved SF Symbol name
            const icon_cstr = try std.heap.c_allocator.dupeZ(u8, resolved_name);
            defer std.heap.c_allocator.free(icon_cstr);

            const NSString = macos.getClass("NSString");
            const str_alloc = macos.msgSend0(NSString, "alloc");
            const ns_name = macos.msgSend1(str_alloc, "initWithUTF8String:", icon_cstr.ptr);

            // Try systemSymbolNamed:accessibilityDescription:
            const image = macos.msgSend2(NSImage, "imageWithSystemSymbolName:accessibilityDescription:", ns_name, @as(?*anyopaque, null));

            if (image != null) {
                // Configure for template rendering (adapts to light/dark mode)
                _ = macos.msgSend1(image, "setTemplate:", @as(c_int, 1));
                _ = macos.msgSend1(button, "setImage:", image);
                log.debug("Set SF Symbol icon: {s}", .{resolved_name});
            } else {
                log.debug("SF Symbol not found: {s}", .{resolved_name});
            }
        }
    }

    /// Set dock badge (macOS only)
    /// JSON: {"badge": "42"} or {"badge": ""} to clear
    fn setBadge(self: *Self, badge_text: []const u8) !void {
        _ = try self.requireTrayHandle();

        log.debug("setBadge: {s}", .{badge_text});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Get NSApplication dock tile
            const NSApplication = macos.getClass("NSApplication");
            const app = macos.msgSend0(NSApplication, "sharedApplication");
            const dock_tile = macos.msgSend0(app, "dockTile");

            // Create NSString for badge
            const NSString = macos.getClass("NSString");
            const str_alloc = macos.msgSend0(NSString, "alloc");

            if (badge_text.len == 0) {
                // Clear badge with empty string
                const empty_cstr = @as([*:0]const u8, @ptrCast("".ptr));
                const ns_badge = macos.msgSend1(str_alloc, "initWithUTF8String:", empty_cstr);
                _ = macos.msgSend1(dock_tile, "setBadgeLabel:", ns_badge);
            } else {
                const badge_cstr = try std.heap.c_allocator.dupeZ(u8, badge_text);
                defer std.heap.c_allocator.free(badge_cstr);

                const ns_badge = macos.msgSend1(str_alloc, "initWithUTF8String:", badge_cstr.ptr);
                _ = macos.msgSend1(dock_tile, "setBadgeLabel:", ns_badge);
            }

            log.debug("Badge set to: {s}", .{badge_text});
        }
    }

    pub fn deinit(self: *Self) void {
        if (self.current_menu) |menu| {
            tray_menu.destroyNSMenu(menu);
        }
    }
};
