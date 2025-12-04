const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Running process entry
const ProcessEntry = struct {
    id: []const u8,
    child: ?std.process.Child,
};

/// Shell commands bridge for executing system commands
pub const ShellBridge = struct {
    allocator: std.mem.Allocator,
    processes: std.StringHashMap(ProcessEntry),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .processes = std.StringHashMap(ProcessEntry).init(allocator),
        };
    }

    /// Handle shell-related messages from JavaScript
    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        self.handleMessageInternal(action, data) catch |err| {
            self.reportError(action, err);
        };
    }

    fn handleMessageInternal(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "exec")) {
            try self.exec(data);
        } else if (std.mem.eql(u8, action, "spawn")) {
            try self.spawn(data);
        } else if (std.mem.eql(u8, action, "kill")) {
            try self.kill(data);
        } else if (std.mem.eql(u8, action, "openUrl")) {
            try self.openUrl(data);
        } else if (std.mem.eql(u8, action, "openPath")) {
            try self.openPath(data);
        } else if (std.mem.eql(u8, action, "showInFinder")) {
            try self.showInFinder(data);
        } else if (std.mem.eql(u8, action, "getEnv")) {
            try self.getEnv(data);
        } else if (std.mem.eql(u8, action, "setEnv")) {
            try self.setEnv(data);
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

    /// Execute command and wait for result
    /// JSON: {"command": "ls -la", "cwd": "/path", "callbackId": "cb1"}
    fn exec(self: *Self, data: []const u8) !void {
        var command: []const u8 = "";
        var cwd: []const u8 = "";
        var callback_id: []const u8 = "";

        // Parse command
        if (std.mem.indexOf(u8, data, "\"command\":\"")) |idx| {
            const start = idx + 11;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                command = data[start..end];
            }
        }

        // Parse cwd
        if (std.mem.indexOf(u8, data, "\"cwd\":\"")) |idx| {
            const start = idx + 7;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                cwd = data[start..end];
            }
        }

        // Parse callbackId
        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        if (command.len == 0) return BridgeError.MissingData;

        std.debug.print("[ShellBridge] exec: {s}\n", .{command});

        // Build argv array directly
        const argv = [_][]const u8{ "/bin/sh", "-c", command };

        // Create child process using Zig 0.16 API
        var child = std.process.Child.init(&argv, self.allocator);
        child.cwd = if (cwd.len > 0) cwd else null;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;
        child.stdin_behavior = .Ignore;

        child.spawn() catch |err| {
            self.sendShellError(callback_id, "exec", command, err);
            return;
        };

        // Wait for completion first
        const term = child.wait() catch |err| {
            self.sendShellError(callback_id, "exec", command, err);
            return;
        };

        // Read stdout (simplified - just read what we can with a fixed buffer)
        var stdout_buf: [65536]u8 = undefined;
        var stdout_len: usize = 0;
        if (child.stdout) |stdout_file| {
            stdout_len = stdout_file.read(&stdout_buf) catch 0;
        }
        const stdout = stdout_buf[0..stdout_len];

        // Read stderr
        var stderr_buf: [8192]u8 = undefined;
        var stderr_len: usize = 0;
        if (child.stderr) |stderr_file| {
            stderr_len = stderr_file.read(&stderr_buf) catch 0;
        }
        const stderr = stderr_buf[0..stderr_len];

        const exit_code: i32 = switch (term) {
            .Exited => |code| @intCast(code),
            .Signal => |sig| -@as(i32, @intCast(sig)),
            else => -1,
        };

        self.sendShellResult(callback_id, "exec", exit_code, stdout, stderr);
    }

    /// Spawn a process without waiting
    /// JSON: {"id": "proc1", "command": "long-running-cmd", "cwd": "/path"}
    fn spawn(self: *Self, data: []const u8) !void {
        var id: []const u8 = "";
        var command: []const u8 = "";
        var cwd: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"id\":\"")) |idx| {
            const start = idx + 6;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                id = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"command\":\"")) |idx| {
            const start = idx + 11;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                command = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"cwd\":\"")) |idx| {
            const start = idx + 7;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                cwd = data[start..end];
            }
        }

        if (id.len == 0 or command.len == 0) return BridgeError.MissingData;

        std.debug.print("[ShellBridge] spawn: {s} -> {s}\n", .{ id, command });

        // Build argv array directly
        const argv = [_][]const u8{ "/bin/sh", "-c", command };

        // Create child process using Zig 0.16 API
        var child = std.process.Child.init(&argv, self.allocator);
        child.cwd = if (cwd.len > 0) cwd else null;
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;
        child.stdin_behavior = .Ignore;

        child.spawn() catch |err| {
            self.sendShellError("", "spawn", command, err);
            return;
        };

        // Store process reference
        const id_owned = try self.allocator.dupe(u8, id);
        try self.processes.put(id_owned, ProcessEntry{
            .id = id_owned,
            .child = child,
        });

        self.sendSpawnSuccess(id);
    }

    /// Kill a spawned process
    /// JSON: {"id": "proc1"}
    fn kill(self: *Self, data: []const u8) !void {
        var id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"id\":\"")) |idx| {
            const start = idx + 6;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                id = data[start..end];
            }
        }

        if (id.len == 0) return BridgeError.MissingData;

        std.debug.print("[ShellBridge] kill: {s}\n", .{id});

        if (self.processes.getPtr(id)) |entry| {
            if (entry.child) |*child| {
                _ = child.kill() catch {};
            }
        }

        if (self.processes.fetchRemove(id)) |kv| {
            self.allocator.free(kv.value.id);
        }
    }

    /// Open URL in default browser
    /// JSON: {"url": "https://example.com"}
    fn openUrl(self: *Self, data: []const u8) !void {
        _ = self;
        var url: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"url\":\"")) |idx| {
            const start = idx + 7;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                url = data[start..end];
            }
        }

        if (url.len == 0) return BridgeError.MissingData;

        std.debug.print("[ShellBridge] openUrl: {s}\n", .{url});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]]
            const NSWorkspace = macos.getClass("NSWorkspace");
            const workspace = macos.msgSend0(NSWorkspace, "sharedWorkspace");

            const NSString = macos.getClass("NSString");
            const url_str = macos.msgSend1(
                NSString,
                "stringWithUTF8String:",
                @as([*c]const u8, @ptrCast(url.ptr)),
            );

            const NSURL = macos.getClass("NSURL");
            const nsurl = macos.msgSend1(NSURL, "URLWithString:", url_str);

            _ = macos.msgSend1(workspace, "openURL:", nsurl);
        }
    }

    /// Open file/folder with default app
    /// JSON: {"path": "/path/to/file"}
    fn openPath(self: *Self, data: []const u8) !void {
        _ = self;
        var path: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"path\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                path = data[start..end];
            }
        }

        if (path.len == 0) return BridgeError.MissingData;

        std.debug.print("[ShellBridge] openPath: {s}\n", .{path});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const NSWorkspace = macos.getClass("NSWorkspace");
            const workspace = macos.msgSend0(NSWorkspace, "sharedWorkspace");

            const NSString = macos.getClass("NSString");
            const path_str = macos.msgSend1(
                NSString,
                "stringWithUTF8String:",
                @as([*c]const u8, @ptrCast(path.ptr)),
            );

            const NSURL = macos.getClass("NSURL");
            const file_url = macos.msgSend1(NSURL, "fileURLWithPath:", path_str);

            _ = macos.msgSend1(workspace, "openURL:", file_url);
        }
    }

    /// Show file in Finder
    /// JSON: {"path": "/path/to/file"}
    fn showInFinder(self: *Self, data: []const u8) !void {
        _ = self;
        var path: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"path\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                path = data[start..end];
            }
        }

        if (path.len == 0) return BridgeError.MissingData;

        std.debug.print("[ShellBridge] showInFinder: {s}\n", .{path});

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const NSWorkspace = macos.getClass("NSWorkspace");
            const workspace = macos.msgSend0(NSWorkspace, "sharedWorkspace");

            const NSString = macos.getClass("NSString");
            const path_str = macos.msgSend1(
                NSString,
                "stringWithUTF8String:",
                @as([*c]const u8, @ptrCast(path.ptr)),
            );

            const NSURL = macos.getClass("NSURL");
            const file_url = macos.msgSend1(NSURL, "fileURLWithPath:", path_str);

            // selectFile:inFileViewerRootedAtPath: - selects file and reveals in Finder
            _ = macos.msgSend1(workspace, "activateFileViewerSelectingURLs:", file_url);
        }
    }

    /// Get environment variable
    /// JSON: {"name": "PATH", "callbackId": "cb1"}
    fn getEnv(self: *Self, data: []const u8) !void {
        _ = self;
        var name: []const u8 = "";
        var callback_id: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"name\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                name = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"callbackId\":\"")) |idx| {
            const start = idx + 14;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                callback_id = data[start..end];
            }
        }

        if (name.len == 0) return BridgeError.MissingData;

        if (builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // Use getenv
            const value = std.posix.getenv(name) orelse "";

            var buf: [4096]u8 = undefined;
            const js = std.fmt.bufPrint(&buf,
                \\if(window.__craftShellCallback)window.__craftShellCallback('{s}','getEnv','{s}');
            , .{ callback_id, value }) catch return;

            macos.tryEvalJS(js) catch {};
        }
    }

    /// Set environment variable (for child processes)
    /// JSON: {"name": "MY_VAR", "value": "my_value"}
    fn setEnv(_: *Self, data: []const u8) !void {
        var name: []const u8 = "";
        var value: []const u8 = "";

        if (std.mem.indexOf(u8, data, "\"name\":\"")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                name = data[start..end];
            }
        }

        if (std.mem.indexOf(u8, data, "\"value\":\"")) |idx| {
            const start = idx + 9;
            if (std.mem.indexOfPos(u8, data, start, "\"")) |end| {
                value = data[start..end];
            }
        }

        if (name.len == 0) return BridgeError.MissingData;

        std.debug.print("[ShellBridge] setEnv: {s}={s}\n", .{ name, value });

        // Note: setenv in Zig requires null-terminated strings
        // For now, just log the intent - actual setenv would need more work
    }

    /// Send shell result callback
    fn sendShellResult(_: *Self, callback_id: []const u8, action: []const u8, exit_code: i32, stdout: []const u8, stderr: []const u8) void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        // Escape stdout and stderr for JS
        var buf: [65536]u8 = undefined;
        var pos: usize = 0;

        const prefix = std.fmt.bufPrint(buf[pos..],
            \\if(window.__craftShellCallback)window.__craftShellCallback('{s}','{s}',{{exitCode:{d},stdout:'
        , .{ callback_id, action, exit_code }) catch return;
        pos += prefix.len;

        // Escape stdout
        for (stdout) |c| {
            if (pos >= buf.len - 100) break;
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
                '\'' => {
                    buf[pos] = '\\';
                    pos += 1;
                    buf[pos] = '\'';
                    pos += 1;
                },
                '\\' => {
                    buf[pos] = '\\';
                    pos += 1;
                    buf[pos] = '\\';
                    pos += 1;
                },
                else => {
                    buf[pos] = c;
                    pos += 1;
                },
            }
        }

        const mid = "',stderr:'";
        @memcpy(buf[pos .. pos + mid.len], mid);
        pos += mid.len;

        // Escape stderr
        for (stderr) |c| {
            if (pos >= buf.len - 20) break;
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
                '\'' => {
                    buf[pos] = '\\';
                    pos += 1;
                    buf[pos] = '\'';
                    pos += 1;
                },
                '\\' => {
                    buf[pos] = '\\';
                    pos += 1;
                    buf[pos] = '\\';
                    pos += 1;
                },
                else => {
                    buf[pos] = c;
                    pos += 1;
                },
            }
        }

        const suffix = "'});";
        @memcpy(buf[pos .. pos + suffix.len], suffix);
        pos += suffix.len;

        macos.tryEvalJS(buf[0..pos]) catch {};
    }

    /// Send spawn success callback
    fn sendSpawnSuccess(_: *Self, id: []const u8) void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        var buf: [256]u8 = undefined;
        const js = std.fmt.bufPrint(&buf,
            \\if(window.__craftShellCallback)window.__craftShellCallback('','spawn',{{id:'{s}',started:true}});
        , .{id}) catch return;

        macos.tryEvalJS(js) catch {};
    }

    /// Send shell error callback
    fn sendShellError(_: *Self, callback_id: []const u8, action: []const u8, command: []const u8, err: anyerror) void {
        if (builtin.os.tag != .macos) return;

        const macos = @import("macos.zig");

        const err_msg = switch (err) {
            error.FileNotFound => "Command not found",
            error.AccessDenied => "Access denied",
            else => "Execution failed",
        };

        var buf: [512]u8 = undefined;
        const js = std.fmt.bufPrint(&buf,
            \\if(window.__craftShellError)window.__craftShellError('{s}','{s}','{s}','{s}');
        , .{ callback_id, action, command, err_msg }) catch return;

        macos.tryEvalJS(js) catch {};
    }

    pub fn deinit(self: *Self) void {
        var it = self.processes.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.child) |*child| {
                _ = child.kill() catch {};
            }
            self.allocator.free(entry.value_ptr.id);
        }
        self.processes.deinit();
    }
};

/// Global shell bridge instance
var global_shell_bridge: ?*ShellBridge = null;

pub fn getGlobalShellBridge() ?*ShellBridge {
    return global_shell_bridge;
}

pub fn setGlobalShellBridge(bridge: *ShellBridge) void {
    global_shell_bridge = bridge;
}
