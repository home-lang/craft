const std = @import("std");

/// Process API
/// Spawn and manage system processes
pub const Process = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Process {
        return .{ .allocator = allocator };
    }

    /// Spawn a new process
    pub fn spawn(self: *Process, args: []const []const u8, options: SpawnOptions) !*ChildProcess {
        var child = try self.allocator.create(ChildProcess);
        errdefer self.allocator.destroy(child);

        child.* = ChildProcess{
            .allocator = self.allocator,
            .args = args,
            .cwd = options.cwd,
            .env = options.env,
            .stdout = null,
            .stderr = null,
            .stdin = null,
            .process = null,
        };

        var process = std.process.Child.init(args, self.allocator);

        if (options.cwd) |cwd| {
            process.cwd = cwd;
        }

        if (options.env) |env| {
            process.env_map = env;
        }

        // Set stdio
        if (options.capture_stdout) {
            process.stdout_behavior = .Pipe;
        }
        if (options.capture_stderr) {
            process.stderr_behavior = .Pipe;
        }
        if (options.pipe_stdin) {
            process.stdin_behavior = .Pipe;
        }

        try process.spawn();

        child.process = process;
        return child;
    }

    /// Execute a command and wait for it to complete
    pub fn exec(self: *Process, args: []const []const u8, options: SpawnOptions) !ExecResult {
        var process = std.process.Child.init(args, self.allocator);

        if (options.cwd) |cwd| {
            process.cwd = cwd;
        }

        if (options.env) |env| {
            process.env_map = env;
        }

        process.stdout_behavior = .Pipe;
        process.stderr_behavior = .Pipe;

        try process.spawn();

        // Read stdout and stderr
        const stdout = if (process.stdout) |stdout_pipe|
            try stdout_pipe.reader().readAllAlloc(self.allocator, 10 * 1024 * 1024)
        else
            try self.allocator.dupe(u8, "");

        const stderr = if (process.stderr) |stderr_pipe|
            try stderr_pipe.reader().readAllAlloc(self.allocator, 10 * 1024 * 1024)
        else
            try self.allocator.dupe(u8, "");

        const term = try process.wait();

        return ExecResult{
            .stdout = stdout,
            .stderr = stderr,
            .exit_code = switch (term) {
                .Exited => |code| code,
                .Signal => |sig| 128 + sig,
                .Stopped => |sig| 128 + sig,
                .Unknown => |code| code,
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
    stdout: ?[]const u8,
    stderr: ?[]const u8,
    stdin: ?std.fs.File.Writer,
    process: ?std.process.Child,

    pub fn wait(self: *ChildProcess) !u32 {
        if (self.process) |*process| {
            const term = try process.wait();
            return switch (term) {
                .Exited => |code| code,
                .Signal => |sig| 128 + sig,
                .Stopped => |sig| 128 + sig,
                .Unknown => |code| code,
            };
        }
        return 0;
    }

    pub fn kill(self: *ChildProcess) !void {
        if (self.process) |*process| {
            return process.kill();
        }
    }

    pub fn deinit(self: *ChildProcess) void {
        if (self.stdout) |stdout| {
            self.allocator.free(stdout);
        }
        if (self.stderr) |stderr| {
            self.allocator.free(stderr);
        }
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
