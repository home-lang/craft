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
        std.debug.print("[DialogBridge] openFile called\n", .{});

        if (builtin.os.tag == .linux) {
            // Linux: Use zenity for file dialogs (widely available)
            try self.linuxOpenFileDialog(data, false, false, "openFile");
            return;
        } else if (builtin.os.tag == .windows) {
            // Windows: Use GetOpenFileName
            try self.windowsOpenFileDialog(data, false, "openFile");
            return;
        } else if (builtin.os.tag == .macos) {
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

            var json: []const u8 = "{\"canceled\":true,\"filePaths\":[]}";

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

                    var buf: std.ArrayList(u8) = .{};
                    defer buf.deinit(self.allocator);

                    try buf.appendSlice(self.allocator, "{\"canceled\":false,\"filePaths\":[\"");
                    for (path_str) |ch| {
                        switch (ch) {
                            '"' => try buf.appendSlice(self.allocator, "\\\""),
                            '\\' => try buf.appendSlice(self.allocator, "\\\\"),
                            '\n' => try buf.appendSlice(self.allocator, "\\n"),
                            '\r' => try buf.appendSlice(self.allocator, "\\r"),
                            '\t' => try buf.appendSlice(self.allocator, "\\t"),
                            else => try buf.append(self.allocator, ch),
                        }
                    }
                    try buf.appendSlice(self.allocator, "\"]}");
                    json = try buf.toOwnedSlice(self.allocator);
                }
            } else {
                std.debug.print("[DialogBridge] File dialog cancelled\n", .{});
            }

            bridge_error.sendResultToJS(self.allocator, "openFile", json);

            if (!std.mem.eql(u8, json, "{\"canceled\":true,\"filePaths\":[]}")) {
                self.allocator.free(json);
            }
        }
    }

    /// Open multiple files picker
    fn openFiles(self: *Self, data: ?[]const u8) !void {
        std.debug.print("[DialogBridge] openFiles called\n", .{});

        if (builtin.os.tag == .linux) {
            try self.linuxOpenFileDialog(data, true, false, "openFiles");
            return;
        } else if (builtin.os.tag == .windows) {
            try self.windowsOpenFileDialog(data, true, "openFiles");
            return;
        } else if (builtin.os.tag == .macos) {
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

            var json: []const u8 = "{\"canceled\":true,\"filePaths\":[]}";

            if (result_int == 1) {
                const urls = macos.msgSend0(panel, "URLs");
                const count_ptr = macos.msgSend0(urls, "count");
                const count = @as(usize, @intFromPtr(count_ptr));

                std.debug.print("[DialogBridge] Selected {d} files\n", .{count});

                var buf: std.ArrayList(u8) = .{};
                defer buf.deinit(self.allocator);

                try buf.appendSlice(self.allocator, "{\"canceled\":false,\"filePaths\":[");
                var first: bool = true;
                var i: usize = 0;
                while (i < count) : (i += 1) {
                    const url = macos.msgSend1(urls, "objectAtIndex:", @as(c_ulong, i));
                    const path = macos.msgSend0(url, "path");
                    const path_cstr = macos.msgSend0(path, "UTF8String");
                    const path_str = std.mem.span(@as([*:0]const u8, @ptrCast(path_cstr)));

                    if (!first) try buf.append(self.allocator, ',');
                    first = false;
                    try buf.append(self.allocator, '"');
                    for (path_str) |ch| {
                        switch (ch) {
                            '"' => try buf.appendSlice(self.allocator, "\\\""),
                            '\\' => try buf.appendSlice(self.allocator, "\\\\"),
                            '\n' => try buf.appendSlice(self.allocator, "\\n"),
                            '\r' => try buf.appendSlice(self.allocator, "\\r"),
                            '\t' => try buf.appendSlice(self.allocator, "\\t"),
                            else => try buf.append(self.allocator, ch),
                        }
                    }
                    try buf.append(self.allocator, '"');
                }
                try buf.appendSlice(self.allocator, "]}");
                json = try buf.toOwnedSlice(self.allocator);
            }

            bridge_error.sendResultToJS(self.allocator, "openFiles", json);

            if (!std.mem.eql(u8, json, "{\"canceled\":true,\"filePaths\":[]}")) {
                self.allocator.free(json);
            }
        }
    }

    /// Open folder picker
    fn openFolder(self: *Self, data: ?[]const u8) !void {
        std.debug.print("[DialogBridge] openFolder called\n", .{});

        if (builtin.os.tag == .linux) {
            try self.linuxOpenFileDialog(data, false, true, "openFolder");
            return;
        } else if (builtin.os.tag == .windows) {
            try self.windowsOpenFolderDialog(data);
            return;
        } else if (builtin.os.tag == .macos) {
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

            var json: []const u8 = "{\"canceled\":true,\"filePaths\":[]}";

            if (result_int == 1) {
                const urls = macos.msgSend0(panel, "URLs");
                const url = macos.msgSend1(urls, "objectAtIndex:", @as(c_ulong, 0));
                const path = macos.msgSend0(url, "path");
                const path_cstr = macos.msgSend0(path, "UTF8String");
                const path_str = std.mem.span(@as([*:0]const u8, @ptrCast(path_cstr)));
                std.debug.print("[DialogBridge] Selected folder: {s}\n", .{path_str});

                var buf: std.ArrayList(u8) = .{};
                defer buf.deinit(self.allocator);

                try buf.appendSlice(self.allocator, "{\"canceled\":false,\"filePaths\":[\"");
                for (path_str) |ch| {
                    switch (ch) {
                        '"' => try buf.appendSlice(self.allocator, "\\\""),
                        '\\' => try buf.appendSlice(self.allocator, "\\\\"),
                        '\n' => try buf.appendSlice(self.allocator, "\\n"),
                        '\r' => try buf.appendSlice(self.allocator, "\\r"),
                        '\t' => try buf.appendSlice(self.allocator, "\\t"),
                        else => try buf.append(self.allocator, ch),
                    }
                }
                try buf.appendSlice(self.allocator, "\"]}");
                json = try buf.toOwnedSlice(self.allocator);
            }

            bridge_error.sendResultToJS(self.allocator, "openFolder", json);

            if (!std.mem.eql(u8, json, "{\"canceled\":true,\"filePaths\":[]}")) {
                self.allocator.free(json);
            }
        }
    }

    /// Save file dialog
    /// JSON: {"title": "Save File", "defaultName": "untitled.txt", "filters": [...]}
    fn saveFile(self: *Self, data: ?[]const u8) !void {
        std.debug.print("[DialogBridge] saveFile called\n", .{});

        if (builtin.os.tag == .linux) {
            try self.linuxSaveFileDialog(data);
            return;
        } else if (builtin.os.tag == .windows) {
            try self.windowsSaveFileDialog(data);
            return;
        } else if (builtin.os.tag == .macos) {
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

            var json: []const u8 = "{\"canceled\":true}";

            if (result_int == 1) {
                const url = macos.msgSend0(panel, "URL");
                const path = macos.msgSend0(url, "path");
                const path_cstr = macos.msgSend0(path, "UTF8String");
                const path_str = std.mem.span(@as([*:0]const u8, @ptrCast(path_cstr)));
                std.debug.print("[DialogBridge] Save path: {s}\n", .{path_str});

                var buf: std.ArrayList(u8) = .{};
                defer buf.deinit(self.allocator);

                try buf.appendSlice(self.allocator, "{\"canceled\":false,\"filePath\":\"");
                for (path_str) |ch| {
                    switch (ch) {
                        '"' => try buf.appendSlice(self.allocator, "\\\""),
                        '\\' => try buf.appendSlice(self.allocator, "\\\\"),
                        '\n' => try buf.appendSlice(self.allocator, "\\n"),
                        '\r' => try buf.appendSlice(self.allocator, "\\r"),
                        '\t' => try buf.appendSlice(self.allocator, "\\t"),
                        else => try buf.append(self.allocator, ch),
                    }
                }
                try buf.appendSlice(self.allocator, "\"}");
                json = try buf.toOwnedSlice(self.allocator);
            }

            bridge_error.sendResultToJS(self.allocator, "saveFile", json);

            if (!std.mem.eql(u8, json, "{\"canceled\":true}")) {
                self.allocator.free(json);
            }
        }
    }

    /// Show alert dialog
    /// JSON: {"title": "Alert", "message": "Something happened", "style": "warning"}
    fn showAlert(self: *Self, data: ?[]const u8) !void {
        if (data == null) return;

        std.debug.print("[DialogBridge] showAlert called\n", .{});

        if (builtin.os.tag == .linux) {
            try self.linuxAlertDialog(data, "showAlert", false);
            return;
        } else if (builtin.os.tag == .windows) {
            try self.windowsAlertDialog(data, "showAlert", false);
            return;
        } else if (builtin.os.tag == .macos) {
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

            // Run modal (single OK button, index 0)
            _ = macos.msgSend0(alert, "runModal");

            const json = "{\"buttonIndex\":0}";
            bridge_error.sendResultToJS(self.allocator, "showAlert", json);
        }
    }

    /// Show confirm dialog with OK/Cancel
    /// JSON: {"title": "Confirm", "message": "Are you sure?"}
    fn showConfirm(self: *Self, data: ?[]const u8) !void {
        if (data == null) return;

        std.debug.print("[DialogBridge] showConfirm called\n", .{});

        if (builtin.os.tag == .linux) {
            try self.linuxAlertDialog(data, "showConfirm", true);
            return;
        } else if (builtin.os.tag == .windows) {
            try self.windowsAlertDialog(data, "showConfirm", true);
            return;
        } else if (builtin.os.tag == .macos) {
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
            const ok = result_int == 1000;
            if (ok) {
                std.debug.print("[DialogBridge] Confirm: OK clicked\n", .{});
            } else {
                std.debug.print("[DialogBridge] Confirm: Cancel clicked\n", .{});
            }

            const json = if (ok) "{\"ok\":true}" else "{\"ok\":false}";
            bridge_error.sendResultToJS(self.allocator, "showConfirm", json);
        }
    }

    // ============================================
    // Linux Dialog Implementations (using zenity)
    // ============================================

    fn linuxOpenFileDialog(self: *Self, data: ?[]const u8, multiple: bool, folder: bool, action: []const u8) !void {
        var args = std.ArrayList([]const u8).init(self.allocator);
        defer args.deinit();

        try args.append("zenity");

        if (folder) {
            try args.append("--file-selection");
            try args.append("--directory");
        } else {
            try args.append("--file-selection");
        }

        if (multiple) {
            try args.append("--multiple");
            try args.append("--separator=\n");
        }

        // Parse title from data
        if (data) |json_data| {
            if (std.mem.indexOf(u8, json_data, "\"title\":\"")) |idx| {
                const start = idx + 9;
                if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                    const title = json_data[start..end];
                    const title_arg = try std.fmt.allocPrint(self.allocator, "--title={s}", .{title});
                    defer self.allocator.free(title_arg);
                    try args.append(title_arg);
                }
            }
        }

        var child = std.process.Child.init(args.items, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();
        const result = try child.wait();

        var json: []const u8 = "{\"canceled\":true,\"filePaths\":[]}";

        if (result.Exited == 0) {
            if (child.stdout) |stdout| {
                const output = try stdout.reader().readAllAlloc(self.allocator, 1024 * 1024);
                defer self.allocator.free(output);

                const trimmed = std.mem.trim(u8, output, "\n\r ");

                if (trimmed.len > 0) {
                    var buf = std.ArrayList(u8).init(self.allocator);
                    defer buf.deinit();

                    try buf.appendSlice("{\"canceled\":false,\"filePaths\":[");

                    if (multiple) {
                        var it = std.mem.splitSequence(u8, trimmed, "\n");
                        var first = true;
                        while (it.next()) |path| {
                            if (path.len == 0) continue;
                            if (!first) try buf.append(',');
                            first = false;
                            try buf.append('"');
                            try self.appendEscapedJson(&buf, path);
                            try buf.append('"');
                        }
                    } else {
                        try buf.append('"');
                        try self.appendEscapedJson(&buf, trimmed);
                        try buf.append('"');
                    }

                    try buf.appendSlice("]}");
                    json = try buf.toOwnedSlice();
                }
            }
        }

        bridge_error.sendResultToJS(self.allocator, action, json);

        if (!std.mem.eql(u8, json, "{\"canceled\":true,\"filePaths\":[]}")) {
            self.allocator.free(json);
        }
    }

    fn linuxSaveFileDialog(self: *Self, data: ?[]const u8) !void {
        var args = std.ArrayList([]const u8).init(self.allocator);
        defer args.deinit();

        try args.append("zenity");
        try args.append("--file-selection");
        try args.append("--save");
        try args.append("--confirm-overwrite");

        // Parse title and default name from data
        if (data) |json_data| {
            if (std.mem.indexOf(u8, json_data, "\"title\":\"")) |idx| {
                const start = idx + 9;
                if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                    const title = json_data[start..end];
                    const title_arg = try std.fmt.allocPrint(self.allocator, "--title={s}", .{title});
                    defer self.allocator.free(title_arg);
                    try args.append(title_arg);
                }
            }

            if (std.mem.indexOf(u8, json_data, "\"defaultName\":\"")) |idx| {
                const start = idx + 15;
                if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                    const name = json_data[start..end];
                    const name_arg = try std.fmt.allocPrint(self.allocator, "--filename={s}", .{name});
                    defer self.allocator.free(name_arg);
                    try args.append(name_arg);
                }
            }
        }

        var child = std.process.Child.init(args.items, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();
        const result = try child.wait();

        var json: []const u8 = "{\"canceled\":true}";

        if (result.Exited == 0) {
            if (child.stdout) |stdout| {
                const output = try stdout.reader().readAllAlloc(self.allocator, 1024 * 1024);
                defer self.allocator.free(output);

                const trimmed = std.mem.trim(u8, output, "\n\r ");

                if (trimmed.len > 0) {
                    var buf = std.ArrayList(u8).init(self.allocator);
                    defer buf.deinit();

                    try buf.appendSlice("{\"canceled\":false,\"filePath\":\"");
                    try self.appendEscapedJson(&buf, trimmed);
                    try buf.appendSlice("\"}");
                    json = try buf.toOwnedSlice();
                }
            }
        }

        bridge_error.sendResultToJS(self.allocator, "saveFile", json);

        if (!std.mem.eql(u8, json, "{\"canceled\":true}")) {
            self.allocator.free(json);
        }
    }

    fn linuxAlertDialog(self: *Self, data: ?[]const u8, action: []const u8, with_cancel: bool) !void {
        var args = std.ArrayList([]const u8).init(self.allocator);
        defer args.deinit();

        try args.append("zenity");

        if (with_cancel) {
            try args.append("--question");
        } else {
            // Determine icon type from style
            var icon_type: []const u8 = "--info";
            if (data) |json_data| {
                if (std.mem.indexOf(u8, json_data, "\"style\":\"")) |idx| {
                    const start = idx + 9;
                    if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                        const style = json_data[start..end];
                        if (std.mem.eql(u8, style, "warning")) {
                            icon_type = "--warning";
                        } else if (std.mem.eql(u8, style, "critical") or std.mem.eql(u8, style, "error")) {
                            icon_type = "--error";
                        }
                    }
                }
            }
            try args.append(icon_type);
        }

        // Parse title and message from data
        if (data) |json_data| {
            if (std.mem.indexOf(u8, json_data, "\"title\":\"")) |idx| {
                const start = idx + 9;
                if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                    const title = json_data[start..end];
                    const title_arg = try std.fmt.allocPrint(self.allocator, "--title={s}", .{title});
                    defer self.allocator.free(title_arg);
                    try args.append(title_arg);
                }
            }

            if (std.mem.indexOf(u8, json_data, "\"message\":\"")) |idx| {
                const start = idx + 11;
                if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                    const message = json_data[start..end];
                    const msg_arg = try std.fmt.allocPrint(self.allocator, "--text={s}", .{message});
                    defer self.allocator.free(msg_arg);
                    try args.append(msg_arg);
                }
            }
        }

        var child = std.process.Child.init(args.items, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();
        const result = try child.wait();

        const json = if (with_cancel)
            (if (result.Exited == 0) "{\"ok\":true}" else "{\"ok\":false}")
        else
            "{\"buttonIndex\":0}";

        bridge_error.sendResultToJS(self.allocator, action, json);
    }

    // ============================================
    // Windows Dialog Implementations (using Win32)
    // ============================================

    fn windowsOpenFileDialog(self: *Self, data: ?[]const u8, multiple: bool, action: []const u8) !void {
        // Windows implementation using GetOpenFileName from comdlg32
        if (builtin.os.tag != .windows) {
            _ = &self;
            _ = &data;
            _ = &multiple;
            _ = &action;
            return;
        }

        // Windows-specific types and functions
        const OPENFILENAMEA = extern struct {
            lStructSize: u32,
            hwndOwner: ?*anyopaque,
            hInstance: ?*anyopaque,
            lpstrFilter: ?[*:0]const u8,
            lpstrCustomFilter: ?[*:0]u8,
            nMaxCustFilter: u32,
            nFilterIndex: u32,
            lpstrFile: [*:0]u8,
            nMaxFile: u32,
            lpstrFileTitle: ?[*:0]u8,
            nMaxFileTitle: u32,
            lpstrInitialDir: ?[*:0]const u8,
            lpstrTitle: ?[*:0]const u8,
            Flags: u32,
            nFileOffset: u16,
            nFileExtension: u16,
            lpstrDefExt: ?[*:0]const u8,
            lCustData: usize,
            lpfnHook: ?*anyopaque,
            lpTemplateName: ?[*:0]const u8,
            pvReserved: ?*anyopaque,
            dwReserved: u32,
            FlagsEx: u32,
        };

        const OFN_FILEMUSTEXIST = 0x00001000;
        const OFN_PATHMUSTEXIST = 0x00000800;
        const OFN_ALLOWMULTISELECT = 0x00000200;
        const OFN_EXPLORER = 0x00080000;

        const comdlg32 = @cImport({
            @cInclude("windows.h");
            @cInclude("commdlg.h");
        });

        var file_buf: [4096]u8 = undefined;
        @memset(&file_buf, 0);

        var title_buf: [256]u8 = undefined;
        @memset(&title_buf, 0);
        const default_title = "Open File";
        @memcpy(title_buf[0..default_title.len], default_title);

        // Parse title from data
        if (data) |json_data| {
            if (std.mem.indexOf(u8, json_data, "\"title\":\"")) |idx| {
                const start = idx + 9;
                if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                    const title = json_data[start..end];
                    const copy_len = @min(title.len, title_buf.len - 1);
                    @memcpy(title_buf[0..copy_len], title[0..copy_len]);
                    title_buf[copy_len] = 0;
                }
            }
        }

        var ofn: OPENFILENAMEA = undefined;
        @memset(std.mem.asBytes(&ofn), 0);
        ofn.lStructSize = @sizeOf(OPENFILENAMEA);
        ofn.hwndOwner = self.window_handle;
        ofn.lpstrFile = &file_buf;
        ofn.nMaxFile = file_buf.len;
        ofn.lpstrTitle = &title_buf;
        ofn.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_EXPLORER;

        if (multiple) {
            ofn.Flags |= OFN_ALLOWMULTISELECT;
        }

        const success = comdlg32.GetOpenFileNameA(&ofn);

        var json: []const u8 = "{\"canceled\":true,\"filePaths\":[]}";

        if (success != 0) {
            var buf = std.ArrayList(u8).init(self.allocator);
            defer buf.deinit();

            try buf.appendSlice("{\"canceled\":false,\"filePaths\":[");

            if (multiple and ofn.nFileOffset > 0) {
                // Multiple files: directory\0file1\0file2\0\0
                const dir = std.mem.sliceTo(&file_buf, 0);
                var offset: usize = dir.len + 1;
                var first = true;

                while (offset < file_buf.len and file_buf[offset] != 0) {
                    const filename = std.mem.sliceTo(file_buf[offset..], 0);
                    if (filename.len == 0) break;

                    if (!first) try buf.append(',');
                    first = false;

                    try buf.append('"');
                    try self.appendEscapedJson(&buf, dir);
                    try buf.append('\\');
                    try self.appendEscapedJson(&buf, filename);
                    try buf.append('"');

                    offset += filename.len + 1;
                }
            } else {
                // Single file
                const path = std.mem.sliceTo(&file_buf, 0);
                try buf.append('"');
                try self.appendEscapedJson(&buf, path);
                try buf.append('"');
            }

            try buf.appendSlice("]}");
            json = try buf.toOwnedSlice();
        }

        bridge_error.sendResultToJS(self.allocator, action, json);

        if (!std.mem.eql(u8, json, "{\"canceled\":true,\"filePaths\":[]}")) {
            self.allocator.free(json);
        }
    }

    fn windowsOpenFolderDialog(self: *Self, data: ?[]const u8) !void {
        if (builtin.os.tag != .windows) {
            _ = &self;
            _ = &data;
            return;
        }

        // Use SHBrowseForFolder for folder selection
        const shell32 = @cImport({
            @cInclude("windows.h");
            @cInclude("shlobj.h");
        });

        var title_buf: [256]u8 = undefined;
        @memset(&title_buf, 0);
        const default_title = "Select Folder";
        @memcpy(title_buf[0..default_title.len], default_title);

        if (data) |json_data| {
            if (std.mem.indexOf(u8, json_data, "\"title\":\"")) |idx| {
                const start = idx + 9;
                if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                    const title = json_data[start..end];
                    const copy_len = @min(title.len, title_buf.len - 1);
                    @memcpy(title_buf[0..copy_len], title[0..copy_len]);
                    title_buf[copy_len] = 0;
                }
            }
        }

        var bi: shell32.BROWSEINFOA = undefined;
        @memset(std.mem.asBytes(&bi), 0);
        bi.hwndOwner = self.window_handle;
        bi.lpszTitle = &title_buf;
        bi.ulFlags = shell32.BIF_RETURNONLYFSDIRS | shell32.BIF_NEWDIALOGSTYLE;

        const pidl = shell32.SHBrowseForFolderA(&bi);

        var json: []const u8 = "{\"canceled\":true,\"filePaths\":[]}";

        if (pidl != null) {
            var path_buf: [260]u8 = undefined;
            if (shell32.SHGetPathFromIDListA(pidl, &path_buf) != 0) {
                const path = std.mem.sliceTo(&path_buf, 0);

                var buf = std.ArrayList(u8).init(self.allocator);
                defer buf.deinit();

                try buf.appendSlice("{\"canceled\":false,\"filePaths\":[\"");
                try self.appendEscapedJson(&buf, path);
                try buf.appendSlice("\"]}");
                json = try buf.toOwnedSlice();
            }
            shell32.CoTaskMemFree(pidl);
        }

        bridge_error.sendResultToJS(self.allocator, "openFolder", json);

        if (!std.mem.eql(u8, json, "{\"canceled\":true,\"filePaths\":[]}")) {
            self.allocator.free(json);
        }
    }

    fn windowsSaveFileDialog(self: *Self, data: ?[]const u8) !void {
        if (builtin.os.tag != .windows) {
            _ = &self;
            _ = &data;
            return;
        }

        const OPENFILENAMEA = extern struct {
            lStructSize: u32,
            hwndOwner: ?*anyopaque,
            hInstance: ?*anyopaque,
            lpstrFilter: ?[*:0]const u8,
            lpstrCustomFilter: ?[*:0]u8,
            nMaxCustFilter: u32,
            nFilterIndex: u32,
            lpstrFile: [*:0]u8,
            nMaxFile: u32,
            lpstrFileTitle: ?[*:0]u8,
            nMaxFileTitle: u32,
            lpstrInitialDir: ?[*:0]const u8,
            lpstrTitle: ?[*:0]const u8,
            Flags: u32,
            nFileOffset: u16,
            nFileExtension: u16,
            lpstrDefExt: ?[*:0]const u8,
            lCustData: usize,
            lpfnHook: ?*anyopaque,
            lpTemplateName: ?[*:0]const u8,
            pvReserved: ?*anyopaque,
            dwReserved: u32,
            FlagsEx: u32,
        };

        const OFN_OVERWRITEPROMPT = 0x00000002;
        const OFN_PATHMUSTEXIST = 0x00000800;

        const comdlg32 = @cImport({
            @cInclude("windows.h");
            @cInclude("commdlg.h");
        });

        var file_buf: [260]u8 = undefined;
        @memset(&file_buf, 0);

        var title_buf: [256]u8 = undefined;
        @memset(&title_buf, 0);
        const default_title = "Save File";
        @memcpy(title_buf[0..default_title.len], default_title);

        if (data) |json_data| {
            if (std.mem.indexOf(u8, json_data, "\"title\":\"")) |idx| {
                const start = idx + 9;
                if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                    const title = json_data[start..end];
                    const copy_len = @min(title.len, title_buf.len - 1);
                    @memcpy(title_buf[0..copy_len], title[0..copy_len]);
                    title_buf[copy_len] = 0;
                }
            }

            if (std.mem.indexOf(u8, json_data, "\"defaultName\":\"")) |idx| {
                const start = idx + 15;
                if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                    const name = json_data[start..end];
                    const copy_len = @min(name.len, file_buf.len - 1);
                    @memcpy(file_buf[0..copy_len], name[0..copy_len]);
                    file_buf[copy_len] = 0;
                }
            }
        }

        var ofn: OPENFILENAMEA = undefined;
        @memset(std.mem.asBytes(&ofn), 0);
        ofn.lStructSize = @sizeOf(OPENFILENAMEA);
        ofn.hwndOwner = self.window_handle;
        ofn.lpstrFile = &file_buf;
        ofn.nMaxFile = file_buf.len;
        ofn.lpstrTitle = &title_buf;
        ofn.Flags = OFN_OVERWRITEPROMPT | OFN_PATHMUSTEXIST;

        const success = comdlg32.GetSaveFileNameA(&ofn);

        var json: []const u8 = "{\"canceled\":true}";

        if (success != 0) {
            const path = std.mem.sliceTo(&file_buf, 0);

            var buf = std.ArrayList(u8).init(self.allocator);
            defer buf.deinit();

            try buf.appendSlice("{\"canceled\":false,\"filePath\":\"");
            try self.appendEscapedJson(&buf, path);
            try buf.appendSlice("\"}");
            json = try buf.toOwnedSlice();
        }

        bridge_error.sendResultToJS(self.allocator, "saveFile", json);

        if (!std.mem.eql(u8, json, "{\"canceled\":true}")) {
            self.allocator.free(json);
        }
    }

    fn windowsAlertDialog(self: *Self, data: ?[]const u8, action: []const u8, with_cancel: bool) !void {
        if (builtin.os.tag != .windows) {
            _ = &self;
            _ = &data;
            _ = &action;
            _ = &with_cancel;
            return;
        }

        const user32 = @cImport({
            @cInclude("windows.h");
        });

        const MB_OK = 0x00000000;
        const MB_OKCANCEL = 0x00000001;
        const MB_ICONINFORMATION = 0x00000040;
        const MB_ICONWARNING = 0x00000030;
        const MB_ICONERROR = 0x00000010;
        const IDOK = 1;

        var title_buf: [256]u8 = undefined;
        @memset(&title_buf, 0);
        var message_buf: [1024]u8 = undefined;
        @memset(&message_buf, 0);

        var style: u32 = MB_ICONINFORMATION;

        if (data) |json_data| {
            if (std.mem.indexOf(u8, json_data, "\"title\":\"")) |idx| {
                const start = idx + 9;
                if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                    const title = json_data[start..end];
                    const copy_len = @min(title.len, title_buf.len - 1);
                    @memcpy(title_buf[0..copy_len], title[0..copy_len]);
                }
            }

            if (std.mem.indexOf(u8, json_data, "\"message\":\"")) |idx| {
                const start = idx + 11;
                if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                    const message = json_data[start..end];
                    const copy_len = @min(message.len, message_buf.len - 1);
                    @memcpy(message_buf[0..copy_len], message[0..copy_len]);
                }
            }

            if (std.mem.indexOf(u8, json_data, "\"style\":\"")) |idx| {
                const start = idx + 9;
                if (std.mem.indexOfPos(u8, json_data, start, "\"")) |end| {
                    const style_str = json_data[start..end];
                    if (std.mem.eql(u8, style_str, "warning")) {
                        style = MB_ICONWARNING;
                    } else if (std.mem.eql(u8, style_str, "critical") or std.mem.eql(u8, style_str, "error")) {
                        style = MB_ICONERROR;
                    }
                }
            }
        }

        if (with_cancel) {
            style |= MB_OKCANCEL;
        } else {
            style |= MB_OK;
        }

        const result = user32.MessageBoxA(
            self.window_handle,
            &message_buf,
            &title_buf,
            style,
        );

        const json = if (with_cancel)
            (if (result == IDOK) "{\"ok\":true}" else "{\"ok\":false}")
        else
            "{\"buttonIndex\":0}";

        bridge_error.sendResultToJS(self.allocator, action, json);
    }

    // ============================================
    // Helper Functions
    // ============================================

    fn appendEscapedJson(self: *Self, buf: *std.ArrayList(u8), str: []const u8) !void {
        _ = self;
        for (str) |ch| {
            switch (ch) {
                '"' => try buf.appendSlice("\\\""),
                '\\' => try buf.appendSlice("\\\\"),
                '\n' => try buf.appendSlice("\\n"),
                '\r' => try buf.appendSlice("\\r"),
                '\t' => try buf.appendSlice("\\t"),
                else => try buf.append(ch),
            }
        }
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};
