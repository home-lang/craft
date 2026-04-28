const std = @import("std");
const io_context = @import("io_context.zig");

/// Process API
/// Spawn and manage system processes
pub const Process = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Process {
        return .{ .allocator = allocator };
    }

    /// Spawn a new process. Uses the Zig-0.16 `std.process.spawn(io, …)` API.
    ///
    /// Wires the spawned child's stdio pipes into the returned `ChildProcess`
    /// so callers can actually read `stdout`/`stderr` and write `stdin` —
    /// previously the struct's pipe fields were left `null`, making the
    /// `capture_stdout`/`capture_stderr`/`pipe_stdin` options do nothing.
    pub fn spawn(self: *Process, args: []const []const u8, options: SpawnOptions) !*ChildProcess {
        var child = try self.allocator.create(ChildProcess);
        errdefer self.allocator.destroy(child);

        const io = io_context.get();

        const stdout_opt: std.process.SpawnOptions.StdioOption = if (options.capture_stdout) .pipe else .inherit;
        const stderr_opt: std.process.SpawnOptions.StdioOption = if (options.capture_stderr) .pipe else .inherit;
        const stdin_opt: std.process.SpawnOptions.StdioOption = if (options.pipe_stdin) .pipe else .inherit;

        var process = try std.process.spawn(io, .{
            .argv = args,
            .cwd = if (options.cwd) |c| .{ .path = c } else .inherit,
            .env_map = options.env,
            .stdout = stdout_opt,
            .stderr = stderr_opt,
            .stdin = stdin_opt,
        });

        child.* = ChildProcess{
            .allocator = self.allocator,
            .args = args,
            .cwd = options.cwd,
            .env = options.env,
            .stdout_file = if (process.stdout) |f| f else null,
            .stderr_file = if (process.stderr) |f| f else null,
            .stdin_file = if (process.stdin) |f| f else null,
            .process = process,
        };
        return child;
    }

    /// Execute a command and wait for it to complete.
    ///
    /// Drains stdout and stderr **concurrently** before waiting. Previously
    /// we read stdout to EOF, then stderr, then called `wait()` — a child
    /// that filled stderr's pipe buffer (~64 KB) before finishing stdout
    /// would deadlock because nobody was draining stderr.
    pub fn exec(self: *Process, args: []const []const u8, options: SpawnOptions) !ExecResult {
        const io = io_context.get();

        var process = try std.process.spawn(io, .{
            .argv = args,
            .cwd = if (options.cwd) |c| .{ .path = c } else .inherit,
            .env_map = options.env,
            .stdout = .pipe,
            .stderr = .pipe,
            .stdin = .ignore,
        });
        errdefer {
            process.kill(io) catch {};
            _ = process.wait(io) catch {};
        }

        var stdout_list: std.ArrayListUnmanaged(u8) = .empty;
        errdefer stdout_list.deinit(self.allocator);
        var stderr_list: std.ArrayListUnmanaged(u8) = .empty;
        errdefer stderr_list.deinit(self.allocator);

        // Spawn a tiny drainer thread for stderr so stdout and stderr are
        // both being consumed concurrently. The main thread drains stdout
        // synchronously and joins the stderr thread before `wait()`.
        const Drainer = struct {
            fn run(
                io_ref: anytype,
                file: anytype,
                out: *std.ArrayListUnmanaged(u8),
                allocator: std.mem.Allocator,
            ) void {
                var chunk: [8192]u8 = undefined;
                while (true) {
                    const n = file.readStreaming(io_ref, &.{&chunk}) catch |err| switch (err) {
                        error.EndOfStream => break,
                        else => return,
                    };
                    if (n == 0) break;
                    out.appendSlice(allocator, chunk[0..n]) catch return;
                }
            }
        };

        var stderr_thread: ?std.Thread = null;
        if (process.stderr) |stderr_pipe| {
            stderr_thread = std.Thread.spawn(.{}, Drainer.run, .{ io, stderr_pipe, &stderr_list, self.allocator }) catch null;
        }

        if (process.stdout) |stdout_pipe| {
            Drainer.run(io, stdout_pipe, &stdout_list, self.allocator);
        }

        if (stderr_thread) |t| t.join();

        const term = try process.wait(io);

        return ExecResult{
            .stdout = try stdout_list.toOwnedSlice(self.allocator),
            .stderr = try stderr_list.toOwnedSlice(self.allocator),
            // Lowercase variants — Zig 0.16 renamed `.Exited`/`.Signal`/etc.
            .exit_code = switch (term) {
                .exited => |code| code,
                .signal => |sig| 128 + @as(u32, sig),
                .stopped => |sig| 128 + @as(u32, sig),
                .unknown => |code| code,
            },
        };
    }

    /// Get environment variable
    pub fn getEnv(self: *Process, key: []const u8) ?[]const u8 {
        return std.process.getEnvVarOwned(self.allocator, key) catch null;
    }

    /// Set environment variable
    pub fn setEnv(self: *Process, key: []const u8, value: []const u8) !void {
        _ = self;
        _ = key;
        _ = value;
        // Not directly supported in Zig - must be done through env_map in child processes
        return error.NotSupported;
    }

    /// Get current working directory
    pub fn getCwd(self: *Process) ![]const u8 {
        return try std.process.getCwdAlloc(self.allocator);
    }

    /// Change current working directory
    pub fn setCwd(self: *Process, path: []const u8) !void {
        _ = self;
        try std.process.changeCurDir(path);
    }

    /// Exit the current process
    pub fn exit(self: *Process, code: u8) noreturn {
        _ = self;
        std.process.exit(code);
    }
};

pub const ChildProcess = struct {
    allocator: std.mem.Allocator,
    args: []const []const u8,
    cwd: ?[]const u8,
    env: ?*std.process.EnvMap,
    /// Pipes wired from the spawned process when the corresponding
    /// `SpawnOptions.capture_*` / `pipe_stdin` flag was set. Previously the
    /// struct had `stdout: ?[]const u8` etc. and left them `null`, making
    /// the capture options silently useless.
    stdout_file: ?std.Io.File,
    stderr_file: ?std.Io.File,
    stdin_file: ?std.Io.File,
    process: std.process.Child,

    pub fn wait(self: *ChildProcess) !u32 {
        const io = io_context.get();
        const term = try self.process.wait(io);
        return switch (term) {
            .exited => |code| code,
            .signal => |sig| 128 + @as(u32, sig),
            .stopped => |sig| 128 + @as(u32, sig),
            .unknown => |code| code,
        };
    }

    /// Kill the child **and** reap it so we don't leave zombies behind.
    /// Previously `kill()` fired SIGKILL and returned without waiting, so
    /// every `kill` leaked a zombie until the parent exited.
    pub fn kill(self: *ChildProcess) !void {
        const io = io_context.get();
        try self.process.kill(io);
        _ = self.process.wait(io) catch {};
    }

    pub fn deinit(self: *ChildProcess) void {
        // Pipes stay open for the caller's use; they're closed by Zig's
        // `std.process.Child.wait` (or by the OS on process exit). If the
        // caller never waited, close them here to avoid fd leaks.
        const io = io_context.get();
        if (self.stdout_file) |*f| f.close(io);
        if (self.stderr_file) |*f| f.close(io);
        if (self.stdin_file) |*f| f.close(io);
        self.allocator.destroy(self);
    }
};

pub const SpawnOptions = struct {
    cwd: ?[]const u8 = null,
    env: ?*std.process.EnvMap = null,
    capture_stdout: bool = false,
    capture_stderr: bool = false,
    pipe_stdin: bool = false,
};

pub const ExecResult = struct {
    stdout: []const u8,
    stderr: []const u8,
    exit_code: u32,
};

// Tests
test "Process init" {
    const allocator = std.testing.allocator;
    const proc = Process.init(allocator);
    _ = proc;
}

test "Get current working directory" {
    const allocator = std.testing.allocator;
    var proc = Process.init(allocator);

    const cwd = try proc.getCwd();
    defer allocator.free(cwd);

    try std.testing.expect(cwd.len > 0);
}
