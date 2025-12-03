const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Bridge handler for native dialog operations (file pickers, alerts, etc.)
pub const DialogBridge = struct {
    allocator: std.mem.Allocator,
    window_handle: ?*anyopaque,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .window_handle = null,
        };
    }

    pub fn setWindowHandle(self: *Self, handle: *anyopaque) void {
        self.window_handle = handle;
    }

    /// Handle dialog-related messages from JavaScript
    pub fn handleMessage(self: *Self, action: []const u8) !void {
        self.handleMessageWithData(action, null) catch |err| {
            self.reportError(action, err);
        };
    }

    pub fn handleMessageWithData(self: *Self, action: []const u8, data: ?[]const u8) !void {
        if (std.mem.eql(u8, action, "openFile")) {
            try self.openFile(data);
        } else if (std.mem.eql(u8, action, "openFiles")) {
            try self.openFiles(data);
        } else if (std.mem.eql(u8, action, "openFolder")) {
            try self.openFolder(data);
        } else if (std.mem.eql(u8, action, "saveFile")) {
            try self.saveFile(data);
        } else if (std.mem.eql(u8, action, "showAlert")) {
            try self.showAlert(data);
        } else if (std.mem.eql(u8, action, "showConfirm")) {
            try self.showConfirm(data);
        } else {
            return BridgeError.UnknownAction;
        }
    }

    /// Report error to JavaScript and log
    fn reportError(self: *Self, action: []const u8, err: anyerror) void {
        const bridge_err: BridgeError = switch (err) {
            BridgeError.MissingData => BridgeError.MissingData,
            BridgeError.InvalidJSON => BridgeError.InvalidJSON,
            BridgeError.Cancelled => BridgeError.Cancelled,
            else => BridgeError.NativeCallFailed,
        };
        bridge_error.sendErrorToJS(self.allocator, action, bridge_err);
    }

    /// Open a single file picker
    /// JSON: {"title": "Open File", "filters": [{"name": "Images", "extensions": ["png", "jpg"]}], "defaultPath": "/Users"}
    fn openFile(self: *Self, data: ?[]const u8) !void {
        _ = self;
        std.debug.print("[DialogBridge] openFile called\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Create NSOpenPanel
            const NSOpenPanel = macos.getClass("NSOpenPanel");
            const panel = macos.msgSend0(NSOpenPanel, "openPanel");

            // Configure panel
            _ = macos.msgSend1(panel, "setCanChooseFiles:", @as(c_long, 1));
            _ = macos.msgSend1(panel, "setCanChooseDirectories:", @as(c_long, 0));
            _ = macos.msgSend1(panel, "setAllowsMultipleSelection:", @as(c_long, 0));

            // Parse options from data
            if (data) |json_data| {
                // Parse title
                if (std.mem.indexOf(u8, json_data, "\"title\":\"")) |idx| {
                    const start = idx + 9;
                    if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                        const title = json_data[start..end];
                        const title_cstr = try std.heap.c_allocator.dupeZ(u8, title);
                        defer std.heap.c_allocator.free(title_cstr);
                        const NSString = macos.getClass("NSString");
                        const str_alloc = macos.msgSend0(NSString, "alloc");
                        const ns_title = macos.msgSend1(str_alloc, "initWithUTF8String:", title_cstr.ptr);
                        _ = macos.msgSend1(panel, "setTitle:", ns_title);
                    }
                }
            }

            // Run modal
            const result = macos.msgSend0(panel, "runModal");
            const result_int = @as(c_long, @intCast(@intFromPtr(result)));

            if (result_int == 1) { // NSModalResponseOK
                const urls = macos.msgSend0(panel, "URLs");
                const count_ptr = macos.msgSend0(urls, "count");
                const count = @as(usize, @intFromPtr(count_ptr));

                if (count > 0) {
                    const url = macos.msgSend1(urls, "objectAtIndex:", @as(c_ulong, 0));
                    const path = macos.msgSend0(url, "path");
                    const path_cstr = macos.msgSend0(path, "UTF8String");
                    const path_str = std.mem.span(@as([*:0]const u8, @ptrCast(path_cstr)));
                    std.debug.print("[DialogBridge] Selected file: {s}\n", .{path_str});
                    // TODO: Send result back to JavaScript via callback
                }
            } else {
                std.debug.print("[DialogBridge] File dialog cancelled\n", .{});
            }
        }
    }

    /// Open multiple files picker
    fn openFiles(self: *Self, data: ?[]const u8) !void {
        _ = self;
        std.debug.print("[DialogBridge] openFiles called\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const NSOpenPanel = macos.getClass("NSOpenPanel");
            const panel = macos.msgSend0(NSOpenPanel, "openPanel");

            _ = macos.msgSend1(panel, "setCanChooseFiles:", @as(c_long, 1));
            _ = macos.msgSend1(panel, "setCanChooseDirectories:", @as(c_long, 0));
            _ = macos.msgSend1(panel, "setAllowsMultipleSelection:", @as(c_long, 1));

            if (data) |json_data| {
                if (std.mem.indexOf(u8, json_data, "\"title\":\"")) |idx| {
                    const start = idx + 9;
                    if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                        const title = json_data[start..end];
                        const title_cstr = try std.heap.c_allocator.dupeZ(u8, title);
                        defer std.heap.c_allocator.free(title_cstr);
                        const NSString = macos.getClass("NSString");
                        const str_alloc = macos.msgSend0(NSString, "alloc");
                        const ns_title = macos.msgSend1(str_alloc, "initWithUTF8String:", title_cstr.ptr);
                        _ = macos.msgSend1(panel, "setTitle:", ns_title);
                    }
                }
            }

            const result = macos.msgSend0(panel, "runModal");
            const result_int = @as(c_long, @intCast(@intFromPtr(result)));

            if (result_int == 1) {
                const urls = macos.msgSend0(panel, "URLs");
                const count_ptr = macos.msgSend0(urls, "count");
                const count = @as(usize, @intFromPtr(count_ptr));

                std.debug.print("[DialogBridge] Selected {d} files\n", .{count});
                // TODO: Send results back to JavaScript
            }
        }
    }

    /// Open folder picker
    fn openFolder(self: *Self, data: ?[]const u8) !void {
        _ = self;
        std.debug.print("[DialogBridge] openFolder called\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const NSOpenPanel = macos.getClass("NSOpenPanel");
            const panel = macos.msgSend0(NSOpenPanel, "openPanel");

            _ = macos.msgSend1(panel, "setCanChooseFiles:", @as(c_long, 0));
            _ = macos.msgSend1(panel, "setCanChooseDirectories:", @as(c_long, 1));
            _ = macos.msgSend1(panel, "setAllowsMultipleSelection:", @as(c_long, 0));

            if (data) |json_data| {
                if (std.mem.indexOf(u8, json_data, "\"title\":\"")) |idx| {
                    const start = idx + 9;
                    if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                        const title = json_data[start..end];
                        const title_cstr = try std.heap.c_allocator.dupeZ(u8, title);
                        defer std.heap.c_allocator.free(title_cstr);
                        const NSString = macos.getClass("NSString");
                        const str_alloc = macos.msgSend0(NSString, "alloc");
                        const ns_title = macos.msgSend1(str_alloc, "initWithUTF8String:", title_cstr.ptr);
                        _ = macos.msgSend1(panel, "setTitle:", ns_title);
                    }
                }
            }

            const result = macos.msgSend0(panel, "runModal");
            const result_int = @as(c_long, @intCast(@intFromPtr(result)));

            if (result_int == 1) {
                const urls = macos.msgSend0(panel, "URLs");
                const url = macos.msgSend1(urls, "objectAtIndex:", @as(c_ulong, 0));
                const path = macos.msgSend0(url, "path");
                const path_cstr = macos.msgSend0(path, "UTF8String");
                const path_str = std.mem.span(@as([*:0]const u8, @ptrCast(path_cstr)));
                std.debug.print("[DialogBridge] Selected folder: {s}\n", .{path_str});
            }
        }
    }

    /// Save file dialog
    /// JSON: {"title": "Save File", "defaultName": "untitled.txt", "filters": [...]}
    fn saveFile(self: *Self, data: ?[]const u8) !void {
        _ = self;
        std.debug.print("[DialogBridge] saveFile called\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const NSSavePanel = macos.getClass("NSSavePanel");
            const panel = macos.msgSend0(NSSavePanel, "savePanel");

            if (data) |json_data| {
                // Parse title
                if (std.mem.indexOf(u8, json_data, "\"title\":\"")) |idx| {
                    const start = idx + 9;
                    if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                        const title = json_data[start..end];
                        const title_cstr = try std.heap.c_allocator.dupeZ(u8, title);
                        defer std.heap.c_allocator.free(title_cstr);
                        const NSString = macos.getClass("NSString");
                        const str_alloc = macos.msgSend0(NSString, "alloc");
                        const ns_title = macos.msgSend1(str_alloc, "initWithUTF8String:", title_cstr.ptr);
                        _ = macos.msgSend1(panel, "setTitle:", ns_title);
                    }
                }

                // Parse default name
                if (std.mem.indexOf(u8, json_data, "\"defaultName\":\"")) |idx| {
                    const start = idx + 15;
                    if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                        const name = json_data[start..end];
                        const name_cstr = try std.heap.c_allocator.dupeZ(u8, name);
                        defer std.heap.c_allocator.free(name_cstr);
                        const NSString = macos.getClass("NSString");
                        const str_alloc = macos.msgSend0(NSString, "alloc");
                        const ns_name = macos.msgSend1(str_alloc, "initWithUTF8String:", name_cstr.ptr);
                        _ = macos.msgSend1(panel, "setNameFieldStringValue:", ns_name);
                    }
                }
            }

            const result = macos.msgSend0(panel, "runModal");
            const result_int = @as(c_long, @intCast(@intFromPtr(result)));

            if (result_int == 1) {
                const url = macos.msgSend0(panel, "URL");
                const path = macos.msgSend0(url, "path");
                const path_cstr = macos.msgSend0(path, "UTF8String");
                const path_str = std.mem.span(@as([*:0]const u8, @ptrCast(path_cstr)));
                std.debug.print("[DialogBridge] Save path: {s}\n", .{path_str});
            }
        }
    }

    /// Show alert dialog
    /// JSON: {"title": "Alert", "message": "Something happened", "style": "warning"}
    fn showAlert(self: *Self, data: ?[]const u8) !void {
        _ = self;
        if (data == null) return;

        std.debug.print("[DialogBridge] showAlert called\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const NSAlert = macos.getClass("NSAlert");
            const alert = macos.msgSend0(macos.msgSend0(NSAlert, "alloc"), "init");

            const json_data = data.?;

            // Parse title (messageText in NSAlert)
            if (std.mem.indexOf(u8, json_data, "\"title\":\"")) |idx| {
                const start = idx + 9;
                if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                    const title = json_data[start..end];
                    const title_cstr = try std.heap.c_allocator.dupeZ(u8, title);
                    defer std.heap.c_allocator.free(title_cstr);
                    const NSString = macos.getClass("NSString");
                    const str_alloc = macos.msgSend0(NSString, "alloc");
                    const ns_title = macos.msgSend1(str_alloc, "initWithUTF8String:", title_cstr.ptr);
                    _ = macos.msgSend1(alert, "setMessageText:", ns_title);
                }
            }

            // Parse message (informativeText)
            if (std.mem.indexOf(u8, json_data, "\"message\":\"")) |idx| {
                const start = idx + 11;
                if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                    const message = json_data[start..end];
                    const msg_cstr = try std.heap.c_allocator.dupeZ(u8, message);
                    defer std.heap.c_allocator.free(msg_cstr);
                    const NSString = macos.getClass("NSString");
                    const str_alloc = macos.msgSend0(NSString, "alloc");
                    const ns_msg = macos.msgSend1(str_alloc, "initWithUTF8String:", msg_cstr.ptr);
                    _ = macos.msgSend1(alert, "setInformativeText:", ns_msg);
                }
            }

            // Parse style
            if (std.mem.indexOf(u8, json_data, "\"style\":\"")) |idx| {
                const start = idx + 9;
                if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                    const style = json_data[start..end];
                    var alert_style: c_long = 1; // NSAlertStyleInformational
                    if (std.mem.eql(u8, style, "warning")) {
                        alert_style = 0; // NSAlertStyleWarning
                    } else if (std.mem.eql(u8, style, "critical")) {
                        alert_style = 2; // NSAlertStyleCritical
                    }
                    _ = macos.msgSend1(alert, "setAlertStyle:", alert_style);
                }
            }

            // Add OK button
            const ok_str = "OK";
            const ok_cstr = @as([*:0]const u8, @ptrCast(ok_str.ptr));
            const NSString = macos.getClass("NSString");
            const str_alloc = macos.msgSend0(NSString, "alloc");
            const ns_ok = macos.msgSend1(str_alloc, "initWithUTF8String:", ok_cstr);
            _ = macos.msgSend1(alert, "addButtonWithTitle:", ns_ok);

            // Run modal
            _ = macos.msgSend0(alert, "runModal");
        }
    }

    /// Show confirm dialog with OK/Cancel
    /// JSON: {"title": "Confirm", "message": "Are you sure?"}
    fn showConfirm(self: *Self, data: ?[]const u8) !void {
        _ = self;
        if (data == null) return;

        std.debug.print("[DialogBridge] showConfirm called\n", .{});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const NSAlert = macos.getClass("NSAlert");
            const alert = macos.msgSend0(macos.msgSend0(NSAlert, "alloc"), "init");

            const json_data = data.?;

            // Parse title
            if (std.mem.indexOf(u8, json_data, "\"title\":\"")) |idx| {
                const start = idx + 9;
                if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                    const title = json_data[start..end];
                    const title_cstr = try std.heap.c_allocator.dupeZ(u8, title);
                    defer std.heap.c_allocator.free(title_cstr);
                    const NSString = macos.getClass("NSString");
                    const str_alloc = macos.msgSend0(NSString, "alloc");
                    const ns_title = macos.msgSend1(str_alloc, "initWithUTF8String:", title_cstr.ptr);
                    _ = macos.msgSend1(alert, "setMessageText:", ns_title);
                }
            }

            // Parse message
            if (std.mem.indexOf(u8, json_data, "\"message\":\"")) |idx| {
                const start = idx + 11;
                if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                    const message = json_data[start..end];
                    const msg_cstr = try std.heap.c_allocator.dupeZ(u8, message);
                    defer std.heap.c_allocator.free(msg_cstr);
                    const NSString = macos.getClass("NSString");
                    const str_alloc = macos.msgSend0(NSString, "alloc");
                    const ns_msg = macos.msgSend1(str_alloc, "initWithUTF8String:", msg_cstr.ptr);
                    _ = macos.msgSend1(alert, "setInformativeText:", ns_msg);
                }
            }

            // Add OK and Cancel buttons
            const NSString = macos.getClass("NSString");

            const ok_str = "OK";
            const ok_cstr = @as([*:0]const u8, @ptrCast(ok_str.ptr));
            const str_alloc1 = macos.msgSend0(NSString, "alloc");
            const ns_ok = macos.msgSend1(str_alloc1, "initWithUTF8String:", ok_cstr);
            _ = macos.msgSend1(alert, "addButtonWithTitle:", ns_ok);

            const cancel_str = "Cancel";
            const cancel_cstr = @as([*:0]const u8, @ptrCast(cancel_str.ptr));
            const str_alloc2 = macos.msgSend0(NSString, "alloc");
            const ns_cancel = macos.msgSend1(str_alloc2, "initWithUTF8String:", cancel_cstr);
            _ = macos.msgSend1(alert, "addButtonWithTitle:", ns_cancel);

            // Run modal and check result
            const result = macos.msgSend0(alert, "runModal");
            const result_int = @as(c_long, @intCast(@intFromPtr(result)));

            // NSAlertFirstButtonReturn = 1000
            if (result_int == 1000) {
                std.debug.print("[DialogBridge] Confirm: OK clicked\n", .{});
            } else {
                std.debug.print("[DialogBridge] Confirm: Cancel clicked\n", .{});
            }
        }
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};
