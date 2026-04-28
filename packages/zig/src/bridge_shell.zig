const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");
const io_context = @import("io_context.zig");

const BridgeError = bridge_error.BridgeError;

// libc env mutators. `std.c.setenv` was removed in zig 0.17, so we
// declare the externs ourselves; on Windows the runtime exports
// `_putenv_s` from msvcrt instead.
extern "c" fn setenv(name: [*:0]const u8, value: [*:0]const u8, overwrite: c_int) c_int;
const c_setenv = setenv;
extern "c" fn _putenv_s(name: [*:0]const u8, value: [*:0]const u8) c_int;
const c_putenv_s = _putenv_s;

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
            BridgeError.UnsafeCommand => BridgeError.UnsafeCommand,
            else => BridgeError.NativeCallFailed,
        };
        bridge_error.sendErrorToJS(self.allocator, action, bridge_err);
    }

    /// Fire-and-forget spawn used by `openUrl` / `openPath` / `showInFinder`
    /// on Linux and Windows. Ignores all stdio so we don't need to drain
    /// anything. Consolidates the legacy `Child.init + spawn()` call sites
    /// onto the same Zig-0.16 API that `exec`/`spawn` already use.
    fn fireAndForget(self: *Self, argv: []const []const u8) void {
        _ = self;
        const io = io_context.get();
        var child = std.process.spawn(io, .{
            .argv = argv,
            .stdout = .ignore,
            .stderr = .ignore,
            .stdin = .ignore,
        }) catch return;
        _ = child.wait(io) catch |err| {
            std.log.debug("child process wait failed: {}", .{err});
        };
    }

    /// Drain all bytes from `file` into `out`, growing the buffer as needed.
    /// Returns when the pipe hits EOF. Previously we read once into a
    /// fixed-size buffer and silently truncated output larger than 64KB.
    fn drainInto(
        io: anytype,
        file: anytype,
        out: *std.ArrayListUnmanaged(u8),
        allocator: std.mem.Allocator,
    ) !void {
        var chunk: [8192]u8 = undefined;
        while (true) {
            const n = file.readStreaming(io, &.{&chunk}) catch |err| switch (err) {
                error.EndOfStream => break,
                else => return err,
            };
            if (n == 0) break;
            try out.appendSlice(allocator, chunk[0..n]);
        }
    }

    /// Shell argument tuple for cross-platform support.
    const ShellArgs = struct { argv: [3][]const u8 };

    /// Return the platform-appropriate shell invocation for a command string.
    fn getShellArgs(command: []const u8) ShellArgs {
        return switch (builtin.os.tag) {
            .windows => .{ .argv = .{ "cmd.exe", "/c", command } },
            else => .{ .argv = .{ "/bin/sh", "-c", command } },
        };
    }

    /// Validate a command string for dangerous shell metacharacters.
    /// Returns error.UnsafeCommand if the command contains injection patterns.
    ///
    /// Previously used `"; "` (with a trailing space) as the command-separator
    /// check, which let attackers bypass the filter with a simple `;attack`.
    /// Now all of `;`, `|`, `&`, `>`, `<`, and `\n` are blocked — any of them
    /// is sufficient for command chaining or redirection via `sh -c`.
    fn validateCommand(command: []const u8) BridgeError!void {
        // Multi-byte dangerous patterns (command substitution only).
        const multi_patterns = [_][]const u8{ "$(", "`" };
        for (multi_patterns) |pattern| {
            if (std.mem.indexOf(u8, command, pattern) != null) {
                std.log.warn("bridge_shell: blocked unsafe command containing '{s}': {s}", .{ pattern, command });
                return BridgeError.UnsafeCommand;
            }
        }
        // Single-byte metacharacters that can chain commands or redirect IO.
        // We reject if any appear unescaped in the command.
        for (command) |c| {
            switch (c) {
                ';', '|', '&', '>', '<', '\n' => {
                    std.log.warn("bridge_shell: blocked unsafe command metacharacter '{c}': {s}", .{ c, command });
                    return BridgeError.UnsafeCommand;
                },
                else => {},
            }
        }
    }

    /// Validate that a URL has a safe scheme (http, https, or file).
    fn validateUrl(url: []const u8) BridgeError!void {
        const valid_schemes = [_][]const u8{ "http://", "https://", "file://" };
        for (valid_schemes) |scheme| {
            if (url.len >= scheme.len and std.mem.eql(u8, url[0..scheme.len], scheme)) {
                return; // valid scheme found
            }
        }
        std.log.warn("bridge_shell: blocked URL with invalid scheme: {s}", .{url});
        return BridgeError.UnsafeCommand;
    }

    /// Validate that a path does not contain shell metacharacters. Same
    /// hardening as `validateCommand`: the previous `"; "` check let `;attack`
    /// slip through because it required a trailing space.
    fn validatePath(path: []const u8) BridgeError!void {
        const multi_patterns = [_][]const u8{ "$(", "`" };
        for (multi_patterns) |pattern| {
            if (std.mem.indexOf(u8, path, pattern) != null) {
                std.log.warn("bridge_shell: blocked unsafe path containing '{s}': {s}", .{ pattern, path });
                return BridgeError.UnsafeCommand;
            }
        }
        for (path) |c| {
            switch (c) {
                ';', '|', '&', '>', '<', '\n' => {
                    std.log.warn("bridge_shell: blocked unsafe path metacharacter '{c}': {s}", .{ c, path });
                    return BridgeError.UnsafeCommand;
                },
                else => {},
            }
        }
    }

    /// Execute command and wait for result
    /// JSON: {"command": "ls -la", "cwd": "/path", "callbackId": "cb1"}
    fn exec(self: *Self, data: []const u8) !void {
        const ExecParams = struct {
            command: []const u8 = "",
            cwd: []const u8 = "",
            callbackId: []const u8 = "",
        };

        const parsed = std.json.parseFromSlice(ExecParams, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        const params = parsed.value;

        const command = params.command;
        const cwd = params.cwd;
        const callback_id = params.callbackId;

        if (command.len == 0) return BridgeError.MissingData;

        try validateCommand(command);

        if (comptime builtin.mode == .Debug)
            std.debug.print("[ShellBridge] exec: {s}\n", .{command});

        // Build argv array using cross-platform shell args
        const shell = getShellArgs(command);
        const io = io_context.get();

        // Create child process using Zig 0.16 API
        var child = std.process.spawn(io, .{
            .argv = &shell.argv,
            .cwd = if (cwd.len > 0) .{ .path = cwd } else .inherit,
            .stdout = .pipe,
            .stderr = .pipe,
            .stdin = .ignore,
        }) catch |err| {
            self.sendShellError(callback_id, "exec", command, err);
            return;
        };

        // Drain stdout/stderr BEFORE waiting. A child that writes more than
        // the pipe buffer (~64KB on macOS/Linux) blocks on its next write
        // until a reader drains it — so `wait()` before reading would
        // deadlock on any non-trivial command output.
        var stdout_list = std.ArrayListUnmanaged(u8).empty;
        defer stdout_list.deinit(self.allocator);
        var stderr_list = std.ArrayListUnmanaged(u8).empty;
        defer stderr_list.deinit(self.allocator);

        if (child.stdout) |stdout_file| {
            drainInto(io, stdout_file, &stdout_list, self.allocator) catch {};
        }
        if (child.stderr) |stderr_file| {
            drainInto(io, stderr_file, &stderr_list, self.allocator) catch {};
        }

        const term = child.wait(io) catch |err| {
            self.sendShellError(callback_id, "exec", command, err);
            return;
        };

        const stdout = stdout_list.items;
        const stderr = stderr_list.items;

        const exit_code: i32 = switch (term) {
            .exited => |code| @intCast(code),
            .signal => |sig| -@as(i32, @intCast(@intFromEnum(sig))),
            else => -1,
        };

        self.sendShellResult(callback_id, "exec", exit_code, stdout, stderr);
    }

    /// Spawn a process without waiting
    /// JSON: {"id": "proc1", "command": "long-running-cmd", "cwd": "/path"}
    fn spawn(self: *Self, data: []const u8) !void {
        const SpawnParams = struct {
            id: []const u8 = "",
            command: []const u8 = "",
            cwd: []const u8 = "",
        };

        const parsed = std.json.parseFromSlice(SpawnParams, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        const params = parsed.value;

        const id = params.id;
        const command = params.command;
        const cwd = params.cwd;

        if (id.len == 0 or command.len == 0) return BridgeError.MissingData;

        try validateCommand(command);

        if (comptime builtin.mode == .Debug)
            std.debug.print("[ShellBridge] spawn: {s} -> {s}\n", .{ id, command });

        // Build argv array using cross-platform shell args
        const shell = getShellArgs(command);
        const io = io_context.get();

        // Create child process using Zig 0.16 API
        const child = std.process.spawn(io, .{
            .argv = &shell.argv,
            .cwd = if (cwd.len > 0) .{ .path = cwd } else .inherit,
            .stdout = .inherit,
            .stderr = .inherit,
            .stdin = .ignore,
        }) catch |err| {
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
        const KillParams = struct {
            id: []const u8 = "",
        };

        const parsed = std.json.parseFromSlice(KillParams, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        const id = parsed.value.id;

        if (id.len == 0) return BridgeError.MissingData;

        if (comptime builtin.mode == .Debug)
            std.debug.print("[ShellBridge] kill: {s}\n", .{id});

        // Mirror the cleanup order from `deinit`: close any open pipes
        // (prevents fd leaks), signal the process, then reap it with `wait`
        // so we don't leave zombies behind.
        if (self.processes.getPtr(id)) |entry| {
            if (entry.child) |*child| {
                if (child.stdout) |*stdout| {
                    stdout.close(io_context.get());
                    child.stdout = null;
                }
                if (child.stderr) |*stderr| {
                    stderr.close(io_context.get());
                    child.stderr = null;
                }
                child.kill(io_context.get());
                _ = child.wait(io_context.get()) catch {};
            }
        }

        if (self.processes.fetchRemove(id)) |kv| {
            self.allocator.free(kv.value.id);
        }
    }

    /// Open URL in default browser
    /// JSON: {"url": "https://example.com"}
    fn openUrl(self: *Self, data: []const u8) !void {
        const OpenUrlParams = struct {
            url: []const u8 = "",
        };

        const parsed = std.json.parseFromSlice(OpenUrlParams, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        const url = parsed.value.url;

        if (url.len == 0) return BridgeError.MissingData;

        try validateUrl(url);

        if (comptime builtin.mode == .Debug)
            std.debug.print("[ShellBridge] openUrl: {s}\n", .{url});

        if (comptime builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            // [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]]
            const NSWorkspace = macos.getClass("NSWorkspace");
            const workspace = macos.msgSend0(NSWorkspace, "sharedWorkspace");

            const url_z = self.allocator.dupeZ(u8, url) catch return;
            defer self.allocator.free(url_z);
            const NSString = macos.getClass("NSString");
            const url_str = macos.msgSend1(
                NSString,
                "stringWithUTF8String:",
                url_z.ptr,
            );

            const NSURL = macos.getClass("NSURL");
            const nsurl = macos.msgSend1(NSURL, "URLWithString:", url_str);

            _ = macos.msgSend1(workspace, "openURL:", nsurl);
        } else if (comptime builtin.os.tag == .linux) {
            // Linux: use xdg-open
            // Use the same Zig-0.16 `std.process.spawn` API as exec/spawn —
            // previously these branches used the legacy `Child.init + spawn()`
            // shape which doesn't compile alongside the new API.
            const argv = [_][]const u8{ "xdg-open", url };
            const io = io_context.get();
            var child = std.process.spawn(io, .{
                .argv = &argv,
                .stdout = .ignore,
                .stderr = .ignore,
                .stdin = .ignore,
            }) catch return;
            _ = child.wait(io) catch |err| {
                std.log.debug("child process wait failed: {}", .{err});
            };
        } else if (comptime builtin.os.tag == .windows) {
            const argv = [_][]const u8{ "cmd", "/c", "start", url };
            self.fireAndForget(&argv);
        }
    }

    /// Open file/folder with default app
    /// JSON: {"path": "/path/to/file"}
    fn openPath(self: *Self, data: []const u8) !void {
        const PathParams = struct {
            path: []const u8 = "",
        };

        const parsed = std.json.parseFromSlice(PathParams, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        const path = parsed.value.path;

        if (path.len == 0) return BridgeError.MissingData;

        try validatePath(path);

        if (comptime builtin.mode == .Debug)
            std.debug.print("[ShellBridge] openPath: {s}\n", .{path});

        if (comptime builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const NSWorkspace = macos.getClass("NSWorkspace");
            const workspace = macos.msgSend0(NSWorkspace, "sharedWorkspace");

            const path_z = self.allocator.dupeZ(u8, path) catch return;
            defer self.allocator.free(path_z);
            const NSString = macos.getClass("NSString");
            const path_str = macos.msgSend1(
                NSString,
                "stringWithUTF8String:",
                path_z.ptr,
            );

            const NSURL = macos.getClass("NSURL");
            const file_url = macos.msgSend1(NSURL, "fileURLWithPath:", path_str);

            _ = macos.msgSend1(workspace, "openURL:", file_url);
        } else if (comptime builtin.os.tag == .linux) {
            const argv = [_][]const u8{ "xdg-open", path };
            self.fireAndForget(&argv);
        } else if (comptime builtin.os.tag == .windows) {
            // `cmd /c start "" <path>` — the empty `""` is `start`'s title
            // argument, needed so that `start` doesn't treat a quoted path as
            // a window title. `validatePath` already rejects `&`, `|`, `;`,
            // `<`, `>` and newline, so the remaining characters are safe to
            // pass via cmd's argv.
            const argv = [_][]const u8{ "cmd", "/c", "start", "", path };
            self.fireAndForget(&argv);
        }
    }

    /// Show file in file manager
    /// JSON: {"path": "/path/to/file"}
    fn showInFinder(self: *Self, data: []const u8) !void {
        const PathParams = struct {
            path: []const u8 = "",
        };

        const parsed = std.json.parseFromSlice(PathParams, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        const path = parsed.value.path;

        if (path.len == 0) return BridgeError.MissingData;

        try validatePath(path);

        if (comptime builtin.mode == .Debug)
            std.debug.print("[ShellBridge] showInFinder: {s}\n", .{path});

        if (comptime builtin.os.tag == .macos) {
            const macos = @import("macos.zig");

            const NSWorkspace = macos.getClass("NSWorkspace");
            const workspace = macos.msgSend0(NSWorkspace, "sharedWorkspace");

            const path_z = self.allocator.dupeZ(u8, path) catch return;
            defer self.allocator.free(path_z);
            const NSString = macos.getClass("NSString");
            const path_str = macos.msgSend1(
                NSString,
                "stringWithUTF8String:",
                path_z.ptr,
            );

            const NSURL = macos.getClass("NSURL");
            const file_url = macos.msgSend1(NSURL, "fileURLWithPath:", path_str);

            // selectFile:inFileViewerRootedAtPath: - selects file and reveals in Finder
            _ = macos.msgSend1(workspace, "activateFileViewerSelectingURLs:", file_url);
        } else if (comptime builtin.os.tag == .linux) {
            // Linux: use dbus or xdg-open on the parent directory
            // nautilus/dolphin/thunar have different "reveal" APIs, so open parent dir
            const argv = [_][]const u8{ "xdg-open", path };
            self.fireAndForget(&argv);
        } else if (comptime builtin.os.tag == .windows) {
            // Windows: explorer /select,path
            const argv = [_][]const u8{ "explorer", "/select,", path };
            self.fireAndForget(&argv);
        }
    }

    /// Get environment variable
    /// JSON: {"name": "PATH", "callbackId": "cb1"}
    fn getEnv(self: *Self, data: []const u8) !void {
        const GetEnvParams = struct {
            name: []const u8 = "",
            callbackId: []const u8 = "",
        };

        const parsed = std.json.parseFromSlice(GetEnvParams, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        const name = parsed.value.name;
        const callback_id = parsed.value.callbackId;

        if (name.len == 0) return BridgeError.MissingData;

        // Cross-platform: use C getenv with a null-terminated name. If the
        // name doesn't fit, surface a clear error instead of reusing
        // `MissingData` (which callers interpret as "no `name` provided").
        var name_buf: [256]u8 = undefined;
        if (name.len >= name_buf.len) return BridgeError.InvalidParameter;
        @memcpy(name_buf[0..name.len], name);
        name_buf[name.len] = 0;
        const value = if (std.c.getenv(@ptrCast(name_buf[0..name.len :0]))) |v| std.mem.span(v) else "";

        // Escape both the callback id and the env value. Env vars can
        // contain arbitrary bytes (including `'` and `\`), so inlining them
        // with `{s}` used to break the JS string literal and let a crafted
        // env variable execute attacker-controlled code in the webview.
        var cb_buf: [128]u8 = undefined;
        var val_buf: [4096]u8 = undefined;
        const cb_esc = bridge_error.escapeJsSingleQuoted(&cb_buf, callback_id) catch return;
        const val_esc = bridge_error.escapeJsSingleQuoted(&val_buf, value) catch return;

        const bridge = @import("bridge.zig");
        var buf: [4600]u8 = undefined;
        const js = std.fmt.bufPrint(&buf,
            \\if(window.__craftShellCallback)window.__craftShellCallback('{s}','getEnv','{s}');
        , .{ cb_esc, val_esc }) catch return;

        bridge.evalJS(js) catch |eval_err| {
            std.log.debug("JS eval failed for getEnv callback: {}", .{eval_err});
        };
    }

    /// Set environment variable (for child processes)
    /// JSON: {"name": "MY_VAR", "value": "my_value"}
    fn setEnv(self: *Self, data: []const u8) !void {
        const SetEnvParams = struct {
            name: []const u8 = "",
            value: []const u8 = "",
        };

        const parsed = std.json.parseFromSlice(SetEnvParams, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        const name = parsed.value.name;
        const value = parsed.value.value;

        if (name.len == 0) return BridgeError.MissingData;

        if (comptime builtin.mode == .Debug)
            std.debug.print("[ShellBridge] setEnv: {s}={s}\n", .{ name, value });

        // Previously this was a no-op that silently "succeeded" — callers
        // believed env changes took effect, but no variable was ever set.
        // Now we call the platform's libc `setenv`/`_putenv_s` so the value
        // sticks for this process and any children it spawns.
        const name_z = try self.allocator.dupeZ(u8, name);
        defer self.allocator.free(name_z);
        const value_z = try self.allocator.dupeZ(u8, value);
        defer self.allocator.free(value_z);

        if (comptime builtin.os.tag == .windows) {
            const rc = c_putenv_s(name_z.ptr, value_z.ptr);
            if (rc != 0) return BridgeError.NativeCallFailed;
        } else {
            const rc = c_setenv(name_z.ptr, value_z.ptr, 1);
            if (rc != 0) return BridgeError.NativeCallFailed;
        }
    }

    /// Send shell result callback. Escapes every identifier before embedding
    /// it into the generated JS. The stdout/stderr payloads are still
    /// handled by the per-byte loops below; only the prefix IDs were
    /// missing escaping, which meant a crafted callback id or action could
    /// break out of the JS string literal and execute arbitrary code.
    fn sendShellResult(_: *Self, callback_id: []const u8, action: []const u8, exit_code: i32, stdout: []const u8, stderr: []const u8) void {
        const bridge = @import("bridge.zig");

        var cb_buf: [128]u8 = undefined;
        var act_buf: [64]u8 = undefined;
        const cb_esc = bridge_error.escapeJsSingleQuoted(&cb_buf, callback_id) catch return;
        const act_esc = bridge_error.escapeJsSingleQuoted(&act_buf, action) catch return;

        // Escape stdout and stderr for JS
        var buf: [65536]u8 = undefined;
        var pos: usize = 0;

        const prefix = std.fmt.bufPrint(buf[pos..],
            \\if(window.__craftShellCallback)window.__craftShellCallback('{s}','{s}',{{exitCode:{d},stdout:'
        , .{ cb_esc, act_esc, exit_code }) catch return;
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

        bridge.evalJS(buf[0..pos]) catch |eval_err| {
            std.log.debug("JS eval failed for shell result callback: {}", .{eval_err});
        };
    }

    /// Send spawn success callback
    fn sendSpawnSuccess(_: *Self, id: []const u8) void {
        const bridge = @import("bridge.zig");

        // Escape the spawned process id — it's derived from caller input
        // (e.g. a user-supplied label), so embedding unescaped could let an
        // attacker-controlled label inject JS.
        var id_buf: [128]u8 = undefined;
        const id_esc = bridge_error.escapeJsSingleQuoted(&id_buf, id) catch return;

        var buf: [256]u8 = undefined;
        const js = std.fmt.bufPrint(&buf,
            \\if(window.__craftShellCallback)window.__craftShellCallback('','spawn',{{id:'{s}',started:true}});
        , .{id_esc}) catch return;

        bridge.evalJS(js) catch |eval_err| {
            std.log.debug("JS eval failed for spawn success callback: {}", .{eval_err});
        };
    }

    /// Send shell error callback. Escapes every user-influenced field — the
    /// command in particular is caller-supplied and often contains quotes
    /// or backslashes that previously would have broken the JS string
    /// literal and allowed injection.
    fn sendShellError(_: *Self, callback_id: []const u8, action: []const u8, command: []const u8, err: anyerror) void {
        const bridge = @import("bridge.zig");

        const err_msg = switch (err) {
            error.FileNotFound => "Command not found",
            error.AccessDenied => "Access denied",
            else => "Execution failed",
        };

        var cb_buf: [128]u8 = undefined;
        var act_buf: [64]u8 = undefined;
        var cmd_buf: [512]u8 = undefined;
        const cb_esc = bridge_error.escapeJsSingleQuoted(&cb_buf, callback_id) catch return;
        const act_esc = bridge_error.escapeJsSingleQuoted(&act_buf, action) catch return;
        const cmd_esc = bridge_error.escapeJsSingleQuoted(&cmd_buf, command) catch return;

        var buf: [1024]u8 = undefined;
        const js = std.fmt.bufPrint(&buf,
            \\if(window.__craftShellError)window.__craftShellError('{s}','{s}','{s}','{s}');
        , .{ cb_esc, act_esc, cmd_esc, err_msg }) catch return;

        bridge.evalJS(js) catch |eval_err| {
            std.log.debug("JS eval failed for shell error callback: {}", .{eval_err});
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.processes.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.child) |*child| {
                // Close stdout/stderr pipes before killing to avoid fd leaks
                if (child.stdout) |*stdout| {
                    stdout.close(io_context.get());
                    child.stdout = null;
                }
                if (child.stderr) |*stderr| {
                    stderr.close(io_context.get());
                    child.stderr = null;
                }
                child.kill(io_context.get());
                // Wait to reap the process and prevent zombies
                _ = child.wait(io_context.get()) catch {};
            }
            self.allocator.free(entry.value_ptr.id);
        }
        self.processes.deinit();
    }
};

const global_state = @import("global_state.zig");

pub fn getGlobalShellBridge() ?*ShellBridge {
    return global_state.instance.getShellBridge();
}

pub fn setGlobalShellBridge(bridge: *ShellBridge) void {
    global_state.instance.setShellBridge(bridge);
}
