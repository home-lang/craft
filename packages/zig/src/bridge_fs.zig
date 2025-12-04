const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// File watcher entry
const WatchEntry = struct {
    id: []const u8,
    path: []const u8,
    callback_id: []const u8,
    recursive: bool,
};

/// File system bridge for file operations
pub const FSBridge = struct {
    allocator: std.mem.Allocator,
    watchers: std.StringHashMap(WatchEntry),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .watchers = std.StringHashMap(WatchEntry).init(allocator),
        };
    }

    /// Handle file system-related messages from JavaScript
    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        self.handleMessageInternal(action, data) catch |err| {
            self.reportError(action, err);
        };
    }

    fn handleMessageInternal(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "readFile")) {
            try self.readFile(data);
        } else if (std.mem.eql(u8, action, "writeFile")) {
            try self.writeFile(data);
        } else if (std.mem.eql(u8, action, "appendFile")) {
            try self.appendFile(data);
        } else if (std.mem.eql(u8, action, "deleteFile")) {
            try self.deleteFile(data);
        } else if (std.mem.eql(u8, action, "exists")) {
            try self.exists(data);
        } else if (std.mem.eql(u8, action, "stat")) {
            try self.stat(data);
        } else if (std.mem.eql(u8, action, "readDir")) {
            try self.readDir(data);
        } else if (std.mem.eql(u8, action, "mkdir")) {
            try self.mkdir(data);
        } else if (std.mem.eql(u8, action, "rmdir")) {
            try self.rmdir(data);
        } else if (std.mem.eql(u8, action, "copy")) {
            try self.copy(data);
        } else if (std.mem.eql(u8, action, "move")) {
            try self.move(data);
        } else if (std.mem.eql(u8, action, "watch")) {
            try self.watch(data);
        } else if (std.mem.eql(u8, action, "unwatch")) {
            try self.unwatch(data);
        } else if (std.mem.eql(u8, action, "getHomeDir")) {
            try self.getHomeDir();
        } else if (std.mem.eql(u8, action, "getTempDir")) {
            try self.getTempDir();
        } else if (std.mem.eql(u8, action, "getAppDataDir")) {
            try self.getAppDataDir();
        } else {
            return BridgeError.UnknownAction;
        }
    }

    fn reportError(self: *Self, action: []const u8, err: anyerror) void {
        const bridge_err: BridgeError = switch (err) {
            BridgeError.MissingData => BridgeError.MissingData,
            BridgeError.InvalidJSON => BridgeError.InvalidJSON,
            BridgeError.NotFound => BridgeError.NotFound,
            BridgeError.PermissionDenied => BridgeError.PermissionDenied,
            else => BridgeError.NativeCallFailed,
        };
        bridge_error.sendErrorToJS(self.allocator, action, bridge_err);
    }

    /// Read file contents
    /// JSON: {"path": "/path/to/file", "encoding": "utf8", "callbackId": "cb1"}
    fn readFile(self: *Self, data: []const u8) !void {
        var path: []const u8 = "";
        var callback_id: []const u8 = "";

        // Parse path
        if (std.mem.indexOf(u8, data, "\"path\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                path = data[start..end];
            }
        }

        // Parse callbackId
        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        if (path.len == 0) return BridgeError.MissingData;

        std.debug.print("[FSBridge] readFile: {s}\n", .{path});

        // Read file
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            self.sendFSError(callback_id, "readFile", path, err);
            return;
        };
        defer file.close();

        // Get file size
        const file_stat = file.stat() catch |err| {
            self.sendFSError(callback_id, "readFile", path, err);
            return;
        };
        const size = file_stat.size;

        // Allocate and read using pread
        const content = self.allocator.alloc(u8, size) catch |err| {
            self.sendFSError(callback_id, "readFile", path, err);
            return;
        };
        defer self.allocator.free(content);

        const bytes_read = file.pread(content, 0) catch |err| {
            self.sendFSError(callback_id, "readFile", path, err);
            return;
        };
        _ = bytes_read;

        // Send result to JavaScript (escape content for JS string)
        self.sendFSResult(callback_id, "readFile", content);
    }

    /// Write file contents
    /// JSON: {"path": "/path/to/file", "content": "data", "callbackId": "cb1"}
    fn writeFile(self: *Self, data: []const u8) !void {
        var path: []const u8 = "";
        var content: []const u8 = "";
        var callback_id: []const u8 = "";

        // Parse path
        if (std.mem.indexOf(u8, data, "\"path\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                path = data[start..end];
            }
        }

        // Parse content
        if (std.mem.indexOf(u8, data, "\"content\":\"")) |idx| {
            const start = idx + 11;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                content = data[start..end];
            }
        }

        // Parse callbackId
        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        if (path.len == 0) return BridgeError.MissingData;

        std.debug.print("[FSBridge] writeFile: {s} ({d} bytes)\n", .{ path, content.len });

        // Write file
        const file = std.fs.cwd().createFile(path, .{}) catch |err| {
            self.sendFSError(callback_id, "writeFile", path, err);
            return;
        };
        defer file.close();

        file.writeAll(content) catch |err| {
            self.sendFSError(callback_id, "writeFile", path, err);
            return;
        };

        self.sendFSSuccess(callback_id, "writeFile");
    }

    /// Append to file
    /// JSON: {"path": "/path/to/file", "content": "data", "callbackId": "cb1"}
    fn appendFile(self: *Self, data: []const u8) !void {
        var path: []const u8 = "";
        var content: []const u8 = "";
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"path\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                path = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"content\":\"")) |idx| {
            const start = idx + 11;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                content = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        if (path.len == 0) return BridgeError.MissingData;

        std.debug.print("[FSBridge] appendFile: {s}\n", .{path});

        const file = std.fs.cwd().openFile(path, .{ .mode = .write_only }) catch |err| {
            self.sendFSError(callback_id, "appendFile", path, err);
            return;
        };
        defer file.close();

        file.seekFromEnd(0) catch {};
        file.writeAll(content) catch |err| {
            self.sendFSError(callback_id, "appendFile", path, err);
            return;
        };

        self.sendFSSuccess(callback_id, "appendFile");
    }

    /// Delete file
    /// JSON: {"path": "/path/to/file", "callbackId": "cb1"}
    fn deleteFile(self: *Self, data: []const u8) !void {
        var path: []const u8 = "";
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"path\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                path = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        if (path.len == 0) return BridgeError.MissingData;

        std.debug.print("[FSBridge] deleteFile: {s}\n", .{path});

        std.fs.cwd().deleteFile(path) catch |err| {
            self.sendFSError(callback_id, "deleteFile", path, err);
            return;
        };

        self.sendFSSuccess(callback_id, "deleteFile");
    }

    /// Check if path exists
    /// JSON: {"path": "/path/to/check", "callbackId": "cb1"}
    fn exists(self: *Self, data: []const u8) !void {
        var path: []const u8 = "";
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"path\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                path = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        if (path.len == 0) return BridgeError.MissingData;

        const file_exists = std.fs.cwd().access(path, .{}) != error.FileNotFound;

        self.sendFSBool(callback_id, "exists", file_exists);
    }

    /// Get file stats
    /// JSON: {"path": "/path/to/file", "callbackId": "cb1"}
    fn stat(self: *Self, data: []const u8) !void {
        var path: []const u8 = "";
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"path\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                path = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        if (path.len == 0) return BridgeError.MissingData;

        const file_stat = std.fs.cwd().statFile(path) catch |err| {
            self.sendFSError(callback_id, "stat", path, err);
            return;
        };

        const is_dir = file_stat.kind == .directory;
        const is_file = file_stat.kind == .file;
        const size = file_stat.size;
        // In Zig 0.16, mtime type changed - use 0 as placeholder
        const mtime: i64 = 0;

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            var buf: [512]u8 = undefined;
            const js = std.fmt.bufPrint(&buf,
                \\if(window.__craftFSCallback)window.__craftFSCallback('{s}','stat',{{
                \\"isDirectory":{},
                \\"isFile":{},
                \\"size":{d},
                \\"mtime":{d}
                \\}});
            , .{ callback_id, is_dir, is_file, size, mtime }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Read directory contents
    /// JSON: {"path": "/path/to/dir", "callbackId": "cb1"}
    fn readDir(self: *Self, data: []const u8) !void {
        var path: []const u8 = "";
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"path\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                path = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        if (path.len == 0) return BridgeError.MissingData;

        std.debug.print("[FSBridge] readDir: {s}\n", .{path});

        var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch |err| {
            self.sendFSError(callback_id, "readDir", path, err);
            return;
        };
        defer dir.close();

        // Build JSON array of entries
        var buf: [8192]u8 = undefined;
        var pos: usize = 0;
        buf[pos] = '[';
        pos += 1;

        var first = true;
        var iter = dir.iterate();
        while (iter.next() catch null) |entry| {
            if (!first) {
                buf[pos] = ',';
                pos += 1;
            }
            first = false;

            const is_dir = entry.kind == .directory;
            const item = std.fmt.bufPrint(buf[pos..],
                \\{{"name":"{s}","isDirectory":{}}}
            , .{ entry.name, is_dir }) catch break;
            pos += item.len;
        }

        buf[pos] = ']';
        pos += 1;

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            var js_buf: [8500]u8 = undefined;
            const js = std.fmt.bufPrint(&js_buf,
                \\if(window.__craftFSCallback)window.__craftFSCallback('{s}','readDir',{s});
            , .{ callback_id, buf[0..pos] }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Create directory
    /// JSON: {"path": "/path/to/dir", "recursive": true, "callbackId": "cb1"}
    fn mkdir(self: *Self, data: []const u8) !void {
        var path: []const u8 = "";
        var callback_id: []const u8 = "";
        const recursive = std.mem.indexOf(u8, data, "\"recursive\":true") != null;

        if (std.mem.indexOf(u8, data, "\"path\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                path = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        if (path.len == 0) return BridgeError.MissingData;

        std.debug.print("[FSBridge] mkdir: {s} (recursive={})\n", .{ path, recursive });

        if (recursive) {
            std.fs.cwd().makePath(path) catch |err| {
                self.sendFSError(callback_id, "mkdir", path, err);
                return;
            };
        } else {
            std.fs.cwd().makeDir(path) catch |err| {
                self.sendFSError(callback_id, "mkdir", path, err);
                return;
            };
        }

        self.sendFSSuccess(callback_id, "mkdir");
    }

    /// Remove directory
    /// JSON: {"path": "/path/to/dir", "callbackId": "cb1"}
    fn rmdir(self: *Self, data: []const u8) !void {
        var path: []const u8 = "";
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"path\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                path = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        if (path.len == 0) return BridgeError.MissingData;

        std.debug.print("[FSBridge] rmdir: {s}\n", .{path});

        std.fs.cwd().deleteDir(path) catch |err| {
            self.sendFSError(callback_id, "rmdir", path, err);
            return;
        };

        self.sendFSSuccess(callback_id, "rmdir");
    }

    /// Copy file
    /// JSON: {"src": "/path/from", "dest": "/path/to", "callbackId": "cb1"}
    fn copy(self: *Self, data: []const u8) !void {
        var src: []const u8 = "";
        var dest: []const u8 = "";
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"src\":\"")) |idx| {
            const start = idx + 7;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                src = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"dest\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                dest = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        if (src.len == 0 or dest.len == 0) return BridgeError.MissingData;

        std.debug.print("[FSBridge] copy: {s} -> {s}\n", .{ src, dest });

        // In Zig 0.16, copyFile uses dest_dir parameter
        std.fs.cwd().copyFile(src, std.fs.cwd(), dest, .{}) catch |err| {
            self.sendFSError(callback_id, "copy", src, err);
            return;
        };

        self.sendFSSuccess(callback_id, "copy");
    }

    /// Move/rename file
    /// JSON: {"src": "/path/from", "dest": "/path/to", "callbackId": "cb1"}
    fn move(self: *Self, data: []const u8) !void {
        var src: []const u8 = "";
        var dest: []const u8 = "";
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"src\":\"")) |idx| {
            const start = idx + 7;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                src = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"dest\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                dest = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        if (src.len == 0 or dest.len == 0) return BridgeError.MissingData;

        std.debug.print("[FSBridge] move: {s} -> {s}\n", .{ src, dest });

        std.fs.cwd().rename(src, dest) catch |err| {
            self.sendFSError(callback_id, "move", src, err);
            return;
        };

        self.sendFSSuccess(callback_id, "move");
    }

    /// Watch a file or directory for changes
    /// JSON: {"id": "watch1", "path": "/path/to/watch", "recursive": false, "callbackId": "cb1"}
    fn watch(self: *Self, data: []const u8) !void {
        var id: []const u8 = "";
        var path: []const u8 = "";
        var callback_id: []const u8 = "";
        const recursive = std.mem.indexOf(u8, data, "\"recursive\":true") != null;

        if (std.mem.indexOf(u8, data, "\"id\":\"")) |idx| {
            const start = idx + 6;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                id = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"path\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                path = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        if (id.len == 0 or path.len == 0) return BridgeError.MissingData;

        std.debug.print("[FSBridge] watch: {s} -> {s} (recursive={})\n", .{ id, path, recursive });

        // Store watcher entry
        const id_owned = try self.allocator.dupe(u8, id);
        const path_owned = try self.allocator.dupe(u8, path);
        const callback_owned = try self.allocator.dupe(u8, callback_id);

        try self.watchers.put(id_owned, WatchEntry{
            .id = id_owned,
            .path = path_owned,
            .callback_id = callback_owned,
            .recursive = recursive,
        });

        // Note: Actual file system watching would require FSEvents on macOS
        // For now, this just registers the intent to watch
        self.sendFSSuccess(callback_id, "watch");
    }

    /// Stop watching
    /// JSON: {"id": "watch1"}
    fn unwatch(self: *Self, data: []const u8) !void {
        var id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"id\":\"")) |idx| {
            const start = idx + 6;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                id = data[start..end];
            }
        }

        if (id.len == 0) return BridgeError.MissingData;

        std.debug.print("[FSBridge] unwatch: {s}\n", .{id});

        if (self.watchers.fetchRemove(id)) |kv| {
            self.allocator.free(kv.value.id);
            self.allocator.free(kv.value.path);
            self.allocator.free(kv.value.callback_id);
        }
    }

    /// Get home directory
    fn getHomeDir(self: *Self) !void {
        _ = self;
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        // Get home directory using NSHomeDirectory
        const NSHomeDirectory = macos.getClass("NSFileManager");
        const fm = macos.msgSend0(NSHomeDirectory, "defaultManager");
        const home_url = macos.msgSend0(fm, "homeDirectoryForCurrentUser");
        const home_path = macos.msgSend0(home_url, "path");

        if (home_path) |path_obj| {
            const cstr = macos.msgSend0(path_obj, "UTF8String");
            if (cstr) |c| {
                const path_str = std.mem.span(@as([*:0]const u8, @ptrCast(c)));

                var buf: [512]u8 = undefined;
                const js = std.fmt.bufPrint(&buf,
                    \\if(window.__craftFSCallback)window.__craftFSCallback('','getHomeDir','{s}');
                , .{path_str}) catch return;

                macos.tryEvalJS(js) catch {};
            }
        }
    }

    /// Get temp directory
    fn getTempDir(self: *Self) !void {
        _ = self;
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        const NSFileManager = macos.getClass("NSFileManager");
        const fm = macos.msgSend0(NSFileManager, "defaultManager");
        const temp_url = macos.msgSend0(fm, "temporaryDirectory");
        const temp_path = macos.msgSend0(temp_url, "path");

        if (temp_path) |path_obj| {
            const cstr = macos.msgSend0(path_obj, "UTF8String");
            if (cstr) |c| {
                const path_str = std.mem.span(@as([*:0]const u8, @ptrCast(c)));

                var buf: [512]u8 = undefined;
                const js = std.fmt.bufPrint(&buf,
                    \\if(window.__craftFSCallback)window.__craftFSCallback('','getTempDir','{s}');
                , .{path_str}) catch return;

                macos.tryEvalJS(js) catch {};
            }
        }
    }

    /// Get app data directory (Application Support)
    fn getAppDataDir(self: *Self) !void {
        _ = self;
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        // NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES)
        const NSFileManager = macos.getClass("NSFileManager");
        const fm = macos.msgSend0(NSFileManager, "defaultManager");

        // Use URLsForDirectory:inDomains:
        // NSApplicationSupportDirectory = 14, NSUserDomainMask = 1
        const urls = macos.msgSend2(fm, "URLsForDirectory:inDomains:", @as(c_ulong, 14), @as(c_ulong, 1));
        if (urls) |url_array| {
            const first_url = macos.msgSend1(url_array, "firstObject", @as(?*anyopaque, null));
            if (first_url) |url| {
                const path_obj = macos.msgSend0(url, "path");
                if (path_obj) |p| {
                    const cstr = macos.msgSend0(p, "UTF8String");
                    if (cstr) |c| {
                        const path_str = std.mem.span(@as([*:0]const u8, @ptrCast(c)));

                        var buf: [512]u8 = undefined;
                        const js = std.fmt.bufPrint(&buf,
                            \\if(window.__craftFSCallback)window.__craftFSCallback('','getAppDataDir','{s}');
                        , .{path_str}) catch return;

                        macos.tryEvalJS(js) catch {};
                    }
                }
            }
        }
    }

    /// Send success callback
    fn sendFSSuccess(_: *Self, callback_id: []const u8, action: []const u8) void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        var buf: [256]u8 = undefined;
        const js = std.fmt.bufPrint(&buf,
            \\if(window.__craftFSCallback)window.__craftFSCallback('{s}','{s}',{{success:true}});
        , .{ callback_id, action }) catch return;

        macos.tryEvalJS(js) catch {};
    }

    /// Send boolean result callback
    fn sendFSBool(_: *Self, callback_id: []const u8, action: []const u8, value: bool) void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        var buf: [256]u8 = undefined;
        const js = std.fmt.bufPrint(&buf,
            \\if(window.__craftFSCallback)window.__craftFSCallback('{s}','{s}',{});
        , .{ callback_id, action, value }) catch return;

        macos.tryEvalJS(js) catch {};
    }

    /// Send file content result (base64 encoded for safety)
    fn sendFSResult(_: *Self, callback_id: []const u8, action: []const u8, content: []const u8) void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        // For text content, escape and send directly
        // In production, would want to base64 encode binary files
        var buf: [65536]u8 = undefined;
        var pos: usize = 0;

        const prefix = std.fmt.bufPrint(buf[pos..],
            \\if(window.__craftFSCallback)window.__craftFSCallback('{s}','{s}','
        , .{ callback_id, action }) catch return;
        pos += prefix.len;

        // Escape content for JS string
        for (content) |c| {
            if (pos >= buf.len - 10) break;
            switch (c) {
                '\n' => {
                    buf[pos] = '\\';
                    pos += 1;
                    buf[pos] = 'n';
                    pos += 1;
                },
                '\r' => {
                    buf[pos] = '\\';
                    pos += 1;
                    buf[pos] = 'r';
                    pos += 1;
                },
                '\t' => {
                    buf[pos] = '\\';
                    pos += 1;
                    buf[pos] = 't';
                    pos += 1;
                },
                '\\' => {
                    buf[pos] = '\\';
                    pos += 1;
                    buf[pos] = '\\';
                    pos += 1;
                },
                '\'' => {
                    buf[pos] = '\\';
                    pos += 1;
                    buf[pos] = '\'';
                    pos += 1;
                },
                else => {
                    buf[pos] = c;
                    pos += 1;
                },
            }
        }

        const suffix = "');";
        @memcpy(buf[pos .. pos + suffix.len], suffix);
        pos += suffix.len;

        macos.tryEvalJS(buf[0..pos]) catch {};
    }

    /// Send error callback
    fn sendFSError(_: *Self, callback_id: []const u8, action: []const u8, path: []const u8, err: anyerror) void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        const err_msg = switch (err) {
            error.FileNotFound => "File not found",
            error.AccessDenied => "Access denied",
            error.IsDir => "Is a directory",
            error.NotDir => "Not a directory",
            error.PathAlreadyExists => "Path already exists",
            else => "Operation failed",
        };

        var buf: [512]u8 = undefined;
        const js = std.fmt.bufPrint(&buf,
            \\if(window.__craftFSError)window.__craftFSError('{s}','{s}','{s}','{s}');
        , .{ callback_id, action, path, err_msg }) catch return;

        macos.tryEvalJS(js) catch {};
    }

    pub fn deinit(self: *Self) void {
        var it = self.watchers.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.id);
            self.allocator.free(entry.value_ptr.path);
            self.allocator.free(entry.value_ptr.callback_id);
        }
        self.watchers.deinit();
    }
};

/// Global FS bridge instance
var global_fs_bridge: ?*FSBridge = null;

pub fn getGlobalFSBridge() ?*FSBridge {
    return global_fs_bridge;
}

pub fn setGlobalFSBridge(bridge: *FSBridge) void {
    global_fs_bridge = bridge;
}
