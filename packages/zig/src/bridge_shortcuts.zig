const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Modifier flags for keyboard shortcuts
pub const Modifiers = struct {
    cmd: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    shift: bool = false,

    pub fn toCocoaFlags(self: Modifiers) c_ulong {
        var flags: c_ulong = 0;
        if (self.cmd) flags |= (1 << 20); // NSEventModifierFlagCommand
        if (self.ctrl) flags |= (1 << 18); // NSEventModifierFlagControl
        if (self.alt) flags |= (1 << 19); // NSEventModifierFlagOption
        if (self.shift) flags |= (1 << 17); // NSEventModifierFlagShift
        return flags;
    }
};

/// Registered shortcut
pub const Shortcut = struct {
    id: []const u8,
    key: []const u8,
    modifiers: Modifiers,
    callback_id: []const u8,
    enabled: bool = true,
};

/// Bridge handler for global keyboard shortcuts
pub const ShortcutsBridge = struct {
    allocator: std.mem.Allocator,
    shortcuts: std.StringHashMap(Shortcut),
    global_monitor: ?*anyopaque = null,
    local_monitor: ?*anyopaque = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .shortcuts = std.StringHashMap(Shortcut).init(allocator),
        };
    }

    /// Handle shortcut-related messages from JavaScript
    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        self.handleMessageInternal(action, data) catch |err| {
            self.reportError(action, err);
        };
    }

    fn handleMessageInternal(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "register")) {
            try self.registerShortcut(data);
        } else if (std.mem.eql(u8, action, "unregister")) {
            try self.unregisterShortcut(data);
        } else if (std.mem.eql(u8, action, "unregisterAll")) {
            try self.unregisterAllShortcuts();
        } else if (std.mem.eql(u8, action, "enable")) {
            try self.enableShortcut(data);
        } else if (std.mem.eql(u8, action, "disable")) {
            try self.disableShortcut(data);
        } else if (std.mem.eql(u8, action, "isRegistered")) {
            try self.isRegistered(data);
        } else if (std.mem.eql(u8, action, "list")) {
            try self.listShortcuts();
        } else {
            return BridgeError.UnknownAction;
        }
    }

    fn reportError(self: *Self, action: []const u8, err: anyerror) void {
        const bridge_err: BridgeError = switch (err) {
            BridgeError.MissingData => BridgeError.MissingData,
            BridgeError.InvalidJSON => BridgeError.InvalidJSON,
            else => BridgeError.NativeCallFailed,
        };
        bridge_error.sendErrorToJS(self.allocator, action, bridge_err);
    }

    /// Register a global shortcut
    /// JSON: {"id": "toggle", "key": "Space", "modifiers": {"cmd": true, "shift": true}, "callback": "onToggle"}
    fn registerShortcut(self: *Self, data: []const u8) !void {
        // Parse shortcut data
        var id: []const u8 = "";
        var key: []const u8 = "";
        var callback_id: []const u8 = "";
        var modifiers = Modifiers{};

        // Parse id
        if (std.mem.indexOf(u8, data, "\"id\":\"")) |idx| {
            const start = idx + 6;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                id = data[start..end];
            }
        }

        // Parse key
        if (std.mem.indexOf(u8, data, "\"key\":\"")) |idx| {
            const start = idx + 7;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                key = data[start..end];
            }
        }

        // Parse callback
        if (std.mem.indexOf(u8, data, "\"callback\":\"")) |idx| {
            const start = idx + 12;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        // Parse modifiers
        if (std.mem.indexOf(u8, data, "\"cmd\":true")) |_| modifiers.cmd = true;
        if (std.mem.indexOf(u8, data, "\"ctrl\":true")) |_| modifiers.ctrl = true;
        if (std.mem.indexOf(u8, data, "\"alt\":true")) |_| modifiers.alt = true;
        if (std.mem.indexOf(u8, data, "\"shift\":true")) |_| modifiers.shift = true;

        if (id.len == 0 or key.len == 0) {
            return BridgeError.MissingData;
        }

        std.debug.print("[ShortcutsBridge] register: id={s}, key={s}, cmd={}, ctrl={}, alt={}, shift={}\n", .{ id, key, modifiers.cmd, modifiers.ctrl, modifiers.alt, modifiers.shift });

        // Store shortcut
        const id_owned = try self.allocator.dupe(u8, id);
        const key_owned = try self.allocator.dupe(u8, key);
        const callback_owned = try self.allocator.dupe(u8, callback_id);

        try self.shortcuts.put(id_owned, Shortcut{
            .id = id_owned,
            .key = key_owned,
            .modifiers = modifiers,
            .callback_id = callback_owned,
            .enabled = true,
        });

        // Setup global monitor if not already done
        if (self.global_monitor == null) {
            try self.setupGlobalMonitor();
        }
    }

    /// Setup global event monitor
    fn setupGlobalMonitor(self: *Self) !void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        // Create a global monitor for key down events
        // NSEventMaskKeyDown = 1 << 10 = 1024
        const event_mask: c_ulonglong = 1 << 10;

        // We need to use addGlobalMonitorForEventsMatchingMask:handler:
        // This requires creating an Objective-C block, which is complex in Zig
        // For now, we'll use a polling approach via the run loop

        // Alternative: Use local monitor for when app is active
        const NSEvent = macos.getClass("NSEvent");
        _ = NSEvent;
        _ = event_mask;

        // Store reference to self for callback
        global_shortcuts_bridge = self;

        std.debug.print("[ShortcutsBridge] Global monitor setup (polling mode)\n", .{});
    }

    /// Check if a key event matches any registered shortcut
    pub fn checkKeyEvent(self: *Self, keycode: u16, flags: c_ulong) void {
        const key_name = keycodeToName(keycode);

        var it = self.shortcuts.iterator();
        while (it.next()) |entry| {
            const shortcut = entry.value_ptr.*;
            if (!shortcut.enabled) continue;

            // Check if key matches
            if (!std.mem.eql(u8, shortcut.key, key_name)) continue;

            // Check modifiers
            const required_flags = shortcut.modifiers.toCocoaFlags();
            const masked_flags = flags & ((1 << 17) | (1 << 18) | (1 << 19) | (1 << 20));

            if (masked_flags == required_flags) {
                std.debug.print("[ShortcutsBridge] Shortcut triggered: {s}\n", .{shortcut.id});
                self.triggerCallback(shortcut.id, shortcut.callback_id);
            }
        }
    }

    /// Trigger JavaScript callback for shortcut
    fn triggerCallback(self: *Self, shortcut_id: []const u8, callback_id: []const u8) void {
        _ = self;

        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        var buf: [512]u8 = undefined;
        const js = std.fmt.bufPrint(&buf,
            \\if(window.__craftShortcutCallback)window.__craftShortcutCallback('{s}','{s}');
        , .{ shortcut_id, callback_id }) catch return;

        macos.tryEvalJS(js) catch |err| {
            std.debug.print("[ShortcutsBridge] Failed to trigger callback: {}\n", .{err});
        };
    }

    /// Unregister a shortcut
    /// JSON: {"id": "toggle"}
    fn unregisterShortcut(self: *Self, data: []const u8) !void {
        var id: []const u8 = "";
        if (std.mem.indexOf(u8, data, "\"id\":\"")) |idx| {
            const start = idx + 6;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                id = data[start..end];
            }
        }

        if (id.len == 0) return BridgeError.MissingData;

        std.debug.print("[ShortcutsBridge] unregister: {s}\n", .{id});

        if (self.shortcuts.fetchRemove(id)) |kv| {
            self.allocator.free(kv.value.id);
            self.allocator.free(kv.value.key);
            self.allocator.free(kv.value.callback_id);
        }
    }

    /// Unregister all shortcuts
    fn unregisterAllShortcuts(self: *Self) !void {
        std.debug.print("[ShortcutsBridge] unregisterAll\n", .{});

        var it = self.shortcuts.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.id);
            self.allocator.free(entry.value_ptr.key);
            self.allocator.free(entry.value_ptr.callback_id);
        }
        self.shortcuts.clearAndFree();
    }

    /// Enable a shortcut
    /// JSON: {"id": "toggle"}
    fn enableShortcut(self: *Self, data: []const u8) !void {
        var id: []const u8 = "";
        if (std.mem.indexOf(u8, data, "\"id\":\"")) |idx| {
            const start = idx + 6;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                id = data[start..end];
            }
        }

        if (self.shortcuts.getPtr(id)) |shortcut| {
            shortcut.enabled = true;
            std.debug.print("[ShortcutsBridge] enabled: {s}\n", .{id});
        }
    }

    /// Disable a shortcut
    /// JSON: {"id": "toggle"}
    fn disableShortcut(self: *Self, data: []const u8) !void {
        var id: []const u8 = "";
        if (std.mem.indexOf(u8, data, "\"id\":\"")) |idx| {
            const start = idx + 6;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                id = data[start..end];
            }
        }

        if (self.shortcuts.getPtr(id)) |shortcut| {
            shortcut.enabled = false;
            std.debug.print("[ShortcutsBridge] disabled: {s}\n", .{id});
        }
    }

    /// Check if shortcut is registered
    /// JSON: {"id": "toggle"}
    fn isRegistered(self: *Self, data: []const u8) !void {
        var id: []const u8 = "";
        if (std.mem.indexOf(u8, data, "\"id\":\"")) |idx| {
            const start = idx + 6;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                id = data[start..end];
            }
        }

        const registered = self.shortcuts.contains(id);

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");
            var buf: [256]u8 = undefined;
            const js = std.fmt.bufPrint(&buf,
                \\if(window.__craftShortcutRegistered)window.__craftShortcutRegistered('{s}',{});
            , .{ id, registered }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// List all registered shortcuts
    fn listShortcuts(self: *Self) !void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        var buf: [2048]u8 = undefined;
        var pos: usize = 0;

        // Start JSON array
        buf[pos] = '[';
        pos += 1;

        var first = true;
        var it = self.shortcuts.iterator();
        while (it.next()) |entry| {
            const s = entry.value_ptr.*;
            if (!first) {
                buf[pos] = ',';
                pos += 1;
            }
            first = false;

            const item = std.fmt.bufPrint(buf[pos..],
                \\{{"id":"{s}","key":"{s}","enabled":{}}}
            , .{ s.id, s.key, s.enabled }) catch break;
            pos += item.len;
        }

        buf[pos] = ']';
        pos += 1;

        var js_buf: [2200]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buf,
            \\if(window.__craftShortcutList)window.__craftShortcutList({s});
        , .{buf[0..pos]}) catch return;

        macos.tryEvalJS(js) catch {};
    }

    pub fn deinit(self: *Self) void {
        var it = self.shortcuts.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.id);
            self.allocator.free(entry.value_ptr.key);
            self.allocator.free(entry.value_ptr.callback_id);
        }
        self.shortcuts.deinit();
        global_shortcuts_bridge = null;
    }
};

/// Global reference for event callbacks
var global_shortcuts_bridge: ?*ShortcutsBridge = null;

/// Convert keycode to key name
fn keycodeToName(keycode: u16) []const u8 {
    return switch (keycode) {
        0 => "A",
        1 => "S",
        2 => "D",
        3 => "F",
        4 => "H",
        5 => "G",
        6 => "Z",
        7 => "X",
        8 => "C",
        9 => "V",
        11 => "B",
        12 => "Q",
        13 => "W",
        14 => "E",
        15 => "R",
        16 => "Y",
        17 => "T",
        18 => "1",
        19 => "2",
        20 => "3",
        21 => "4",
        22 => "6",
        23 => "5",
        24 => "=",
        25 => "9",
        26 => "7",
        27 => "-",
        28 => "8",
        29 => "0",
        30 => "]",
        31 => "O",
        32 => "U",
        33 => "[",
        34 => "I",
        35 => "P",
        36 => "Return",
        37 => "L",
        38 => "J",
        39 => "'",
        40 => "K",
        41 => ";",
        42 => "\\",
        43 => ",",
        44 => "/",
        45 => "N",
        46 => "M",
        47 => ".",
        48 => "Tab",
        49 => "Space",
        50 => "`",
        51 => "Delete",
        53 => "Escape",
        96 => "F5",
        97 => "F6",
        98 => "F7",
        99 => "F3",
        100 => "F8",
        101 => "F9",
        103 => "F11",
        109 => "F10",
        111 => "F12",
        118 => "F4",
        120 => "F2",
        122 => "F1",
        123 => "Left",
        124 => "Right",
        125 => "Down",
        126 => "Up",
        else => "Unknown",
    };
}

/// Public function for external event handling
pub fn handleGlobalKeyEvent(keycode: u16, flags: c_ulong) void {
    if (global_shortcuts_bridge) |bridge| {
        bridge.checkKeyEvent(keycode, flags);
    }
}
