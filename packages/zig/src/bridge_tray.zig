const std = @import("std");
const builtin = @import("builtin");
const tray_menu = @import("tray_menu.zig");

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
        if (std.mem.eql(u8, action, "setTitle")) {
            try self.setTitle(data);
        } else if (std.mem.eql(u8, action, "setTooltip")) {
            try self.setTooltip(data);
        } else if (std.mem.eql(u8, action, "setMenu")) {
            try self.setMenu(data);
        } else if (std.mem.eql(u8, action, "pollActions")) {
            try self.pollActions();
        } else {
            std.debug.print("Unknown tray action: {s}\n", .{action});
        }
    }

    fn pollActions(self: *Self) !void {
        _ = self;

        // Pop the next action from the queue
        if (tray_menu.getPendingAction()) |action| {
            std.debug.print("[Bridge] Polling found action: {s}\n", .{action});

            // Call the JavaScript global function to deliver the action
            const macos = @import("macos.zig");
            var buf: [256]u8 = undefined;
            const js = try std.fmt.bufPrint(&buf,
                \\if(window.__craftDeliverAction)window.__craftDeliverAction('{s}');
            , .{action});

            macos.tryEvalJS(js) catch |err| {
                std.debug.print("[Bridge] Failed to deliver action: {}\n", .{err});
            };
        }
    }

    fn setTitle(self: *Self, title: []const u8) !void {
        if (self.tray_handle == null) {
            std.debug.print("Warning: Tray handle not set\n", .{});
            return;
        }

        if (builtin.os.tag == .macos) {
            // Decode Unicode escapes like \Ud83c\Udf45 to actual UTF-8
            const decoded_title = try decodeUnicodeEscapes(self.allocator, title);
            defer self.allocator.free(decoded_title);

            const macos = @import("tray.zig");
            try macos.macosSetTitle(self.tray_handle.?, decoded_title);
        }
    }

    fn setTooltip(self: *Self, tooltip: []const u8) !void {
        if (self.tray_handle == null) {
            std.debug.print("Warning: Tray handle not set\n", .{});
            return;
        }

        if (builtin.os.tag == .macos) {
            const macos = @import("tray.zig");
            try macos.macosSetTooltip(self.tray_handle.?, tooltip);
        }
    }

    fn setMenu(self: *Self, menu_json: []const u8) !void {
        if (self.tray_handle == null) {
            std.debug.print("Warning: Tray handle not set\n", .{});
            return;
        }

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
            try macos.macosSetMenu(self.tray_handle.?, menu);
        }
    }

    pub fn deinit(self: *Self) void {
        if (self.current_menu) |menu| {
            tray_menu.destroyNSMenu(menu);
        }
    }
};
