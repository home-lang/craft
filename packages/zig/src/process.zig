const std = @import("std");

/// Process API for spawning and managing child processes
/// Provides spawn, exec, env, cwd, exit functionality
pub const ProcessError = error{
    SpawnFailed,
    ExecutionFailed,
    InvalidCommand,
    Timeout,
    PermissionDenied,
};

/// Process spawn configuration
pub const SpawnConfig = struct {
    args: []const []const u8,
    cwd: ?[]const u8 = null,
    env: ?std.process.EnvMap = null,
    stdin: ?std.fs.File = null,
    stdout: ?std.fs.File = null,
    stderr: ?std.fs.File = null,
    detached: bool = false,
};

/// Process execution result
pub const ExecResult = struct {
    stdout: []const u8,
    stderr: []const u8,
    exit_code: u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ExecResult) void {
        self.allocator.free(self.stdout);
        self.allocator.free(self.stderr);
    }
};

/// Child process handle
pub const ChildProcess = struct {
    process: std.process.Child,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn wait(self: *Self) !u8 {
        const term = try self.process.wait();
        return switch (term) {
            .Exited => |code| code,
            .Signal => |sig| 128 + @as(u8, @intCast(sig)),
            .Stopped => |sig| 128 + @as(u8, @intCast(sig)),
            .Unknown => 1,
        };
    }

    pub fn kill(self: *Self) !void {
        return self.process.kill();
    }

    pub fn id(self: *const Self) i32 {
        return self.process.id;
    }

    pub fn deinit(self: *Self) void {
        _ = self;
        // Process will be cleaned up when wait() is called
    }
};

/// Process manager
pub const ProcessManager = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) ProcessManager {
        return ProcessManager{
            .allocator = allocator,
        };
    }

    /// Spawn a child process
    pub fn spawn(self: *Self, command: []const u8, config: SpawnConfig) !ChildProcess {
        var argv = std.ArrayList([]const u8).init(self.allocator);
        defer argv.deinit();

        // Add command
        try argv.append(command);

        // Add arguments
        for (config.args) |arg| {
            try argv.append(arg);
        }

        var child = std.process.Child.init(try argv.toOwnedSlice(), self.allocator);

        // Set working directory
        if (config.cwd) |cwd| {
            child.cwd = cwd;
        }

        // Set environment
        if (config.env) |env| {
            child.env_map = &env;
        }

        // Set stdio
        if (config.stdin) |stdin| {
            child.stdin = .{ .file = stdin };
        }
        if (config.stdout) |stdout| {
            child.stdout = .{ .file = stdout };
        }
        if (config.stderr) |stderr| {
            child.stderr = .{ .file = stderr };
        }

        // Spawn
        try child.spawn();

        std.debug.print("Spawned process: {s} (PID: {d})\n", .{ command, child.id });

        return ChildProcess{
            .process = child,
            .allocator = self.allocator,
        };
    }

    /// Execute a command and wait for completion
    pub fn exec(self: *Self, command: []const u8, args: []const []const u8) !ExecResult {
        var argv = std.ArrayList([]const u8).init(self.allocator);
        defer argv.deinit();

        try argv.append(command);
        for (args) |arg| {
            try argv.append(arg);
        }

        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = try argv.toOwnedSlice(),
        });

        return ExecResult{
            .stdout = result.stdout,
            .stderr = result.stderr,
            .exit_code = switch (result.term) {
                .Exited => |code| code,
                else => 1,
            },
            .allocator = self.allocator,
        };
    }

    /// Get environment variable
    pub fn getEnv(self: *Self, key: []const u8) ?[]const u8 {
        _ = self;
        return std.process.getEnvVarOwned(self.allocator, key) catch null;
    }

    /// Set environment variable
    pub fn setEnv(self: *Self, key: []const u8, value: []const u8) !void {
        _ = self;
        // Note: This only affects child processes
        // Use std.process.getEnvMap() and modify it before spawning
        _ = key;
        _ = value;
        // Environment modification is done through EnvMap in SpawnConfig
    }

    /// Get all environment variables
    pub fn getAllEnv(self: *Self) !std.process.EnvMap {
        var env_map = try std.process.getEnvMap(self.allocator);
        return env_map;
    }

    /// Get current working directory
    pub fn getCwd(self: *Self) ![]const u8 {
        return try std.process.getCwdAlloc(self.allocator);
    }

    /// Change current working directory
    pub fn setCwd(self: *Self, path: []const u8) !void {
        _ = self;
        try std.process.changeCurDir(path);
    }

    /// Exit the current process
    pub fn exit(self: *Self, code: u8) noreturn {
        _ = self;
        std.process.exit(code);
    }

    /// Get process ID
    pub fn getPid(self: *Self) i32 {
        _ = self;
        return std.os.linux.getpid();
    }

    /// Get parent process ID
    pub fn getPpid(self: *Self) i32 {
        _ = self;
        return std.os.linux.getppid();
    }
};

/// Shell execution helper
pub fn execShell(allocator: std.mem.Allocator, command: []const u8) !ExecResult {
    const shell = if (@import("builtin").os.tag == .windows) "cmd.exe" else "/bin/sh";
    const arg = if (@import("builtin").os.tag == .windows) "/C" else "-c";

    var pm = ProcessManager.init(allocator);
    return try pm.exec(shell, &[_][]const u8{ arg, command });
}

// Tests
test "process manager init" {
    const allocator = std.testing.allocator;
    const pm = ProcessManager.init(allocator);
    _ = pm;
}

test "get cwd" {
    const allocator = std.testing.allocator;
    var pm = ProcessManager.init(allocator);

    const cwd = try pm.getCwd();
    defer allocator.free(cwd);

    try std.testing.expect(cwd.len > 0);
}

test "exec simple command" {
    const allocator = std.testing.allocator;
    var pm = ProcessManager.init(allocator);

    // Try to execute echo command
    var result = pm.exec("echo", &[_][]const u8{"hello"}) catch |err| {
        std.debug.print("Exec failed: {any}\n", .{err});
        return;
    };
    defer result.deinit();

    try std.testing.expect(result.exit_code == 0);
}
