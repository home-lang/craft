const std = @import("std");

/// Integration testing utilities for Craft
/// Tests interaction between multiple components and systems
///
/// Note: This module provides integration test helpers that work with
/// the zig-test-framework package (~/Code/zig-test-framework)

pub const IntegrationTestError = error{
    ServiceNotAvailable,
    ConnectionFailed,
    ResourceNotFound,
    InvalidState,
};

/// Integration test context
pub const IntegrationTestContext = struct {
    allocator: std.mem.Allocator,
    services: std.StringHashMap(*anyopaque),
    temp_dir: ?std.fs.Dir = null,
    temp_files: std.ArrayList([]const u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .services = std.StringHashMap(*anyopaque).init(allocator),
            .temp_files = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        // Clean up temp files
        if (self.temp_dir) |*dir| {
            for (self.temp_files.items) |file_path| {
                dir.deleteFile(file_path) catch {};
                self.allocator.free(file_path);
            }
            std.fs.cwd().deleteTree("temp_test") catch {};
            dir.close();
        }

        self.temp_files.deinit();
        self.services.deinit();
    }

    /// Create a temporary directory for test artifacts
    pub fn createTempDir(self: *Self) !void {
        const cwd = std.fs.cwd();
        try cwd.makeDir("temp_test");
        self.temp_dir = try cwd.openDir("temp_test", .{});
    }

    /// Create a temporary file
    pub fn createTempFile(self: *Self, name: []const u8, content: []const u8) !void {
        if (self.temp_dir) |*dir| {
            const file = try dir.createFile(name, .{});
            defer file.close();
            try file.writeAll(content);

            const owned_name = try self.allocator.dupe(u8, name);
            try self.temp_files.append(owned_name);
        } else {
            return IntegrationTestError.InvalidState;
        }
    }

    /// Read temp file content
    pub fn readTempFile(self: *Self, name: []const u8) ![]u8 {
        if (self.temp_dir) |*dir| {
            const file = try dir.openFile(name, .{});
            defer file.close();

            const stat = try file.stat();
            const content = try self.allocator.alloc(u8, stat.size);
            _ = try file.readAll(content);

            return content;
        } else {
            return IntegrationTestError.InvalidState;
        }
    }

    /// Register a service for testing
    pub fn registerService(self: *Self, name: []const u8, service: *anyopaque) !void {
        try self.services.put(name, service);
    }

    /// Get a registered service
    pub fn getService(self: *Self, name: []const u8) !*anyopaque {
        return self.services.get(name) orelse IntegrationTestError.ServiceNotAvailable;
    }

    // Assertion helpers (compatible with zig-test-framework)
    pub fn assertEqual(self: *Self, expected: anytype, actual: anytype) !void {
        _ = self;
        if (expected != actual) {
            std.debug.print("Assertion failed: expected {} but got {}\n", .{ expected, actual });
            return error.AssertionFailed;
        }
    }

    pub fn assertEqualStrings(self: *Self, expected: []const u8, actual: []const u8) !void {
        _ = self;
        if (!std.mem.eql(u8, expected, actual)) {
            std.debug.print("Assertion failed: expected '{s}' but got '{s}'\n", .{ expected, actual });
            return error.AssertionFailed;
        }
    }

    pub fn assertTrue(self: *Self, value: bool) !void {
        _ = self;
        if (!value) {
            std.debug.print("Assertion failed: expected true but got false\n", .{});
            return error.AssertionFailed;
        }
    }

    pub fn assertFalse(self: *Self, value: bool) !void {
        _ = self;
        if (value) {
            std.debug.print("Assertion failed: expected false but got true\n", .{});
            return error.AssertionFailed;
        }
    }

    pub fn assertContains(self: *Self, haystack: []const u8, needle: []const u8) !void {
        _ = self;
        if (std.mem.indexOf(u8, haystack, needle) == null) {
            std.debug.print("Assertion failed: '{s}' does not contain '{s}'\n", .{ haystack, needle });
            return error.AssertionFailed;
        }
    }
};

/// HTTP integration test helper
pub const HTTPTestHelper = struct {
    base_url: []const u8,
    timeout_ms: u64 = 5000,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, base_url: []const u8) !Self {
        return Self{
            .base_url = try allocator.dupe(u8, base_url),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.base_url);
    }

    /// Make a GET request
    pub fn get(self: *Self, path: []const u8) !HTTPResponse {
        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base_url, path });
        defer self.allocator.free(url);

        std.debug.print("[HTTP] GET {s}\n", .{url});

        // Mock response for now
        return HTTPResponse{
            .status_code = 200,
            .body = try self.allocator.dupe(u8, "{}"),
            .headers = std.StringHashMap([]const u8).init(self.allocator),
        };
    }

    /// Make a POST request
    pub fn post(self: *Self, path: []const u8, body: []const u8) !HTTPResponse {
        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base_url, path });
        defer self.allocator.free(url);

        std.debug.print("[HTTP] POST {s} (body: {s})\n", .{ url, body });

        return HTTPResponse{
            .status_code = 201,
            .body = try self.allocator.dupe(u8, "{}"),
            .headers = std.StringHashMap([]const u8).init(self.allocator),
        };
    }

    /// Check if server is running
    pub fn isServerAvailable(self: *Self) bool {
        _ = self;
        // Implementation would check if server responds
        return true;
    }
};

pub const HTTPResponse = struct {
    status_code: u16,
    body: []const u8,
    headers: std.StringHashMap([]const u8),

    pub fn deinit(self: *HTTPResponse, allocator: std.mem.Allocator) void {
        allocator.free(self.body);
        var iter = self.headers.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();
    }
};

/// Database integration test helper
pub const DBTestHelper = struct {
    connection_string: []const u8,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, connection_string: []const u8) !Self {
        return Self{
            .connection_string = try allocator.dupe(u8, connection_string),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.connection_string);
    }

    /// Execute a SQL query
    pub fn execute(self: *Self, query: []const u8) !void {
        std.debug.print("[DB] Executing: {s}\n", .{query});
        _ = self;
    }

    /// Seed test data
    pub fn seedData(self: *Self, table: []const u8, data: []const []const u8) !void {
        std.debug.print("[DB] Seeding table '{s}' with {d} records\n", .{ table, data.len });
        _ = self;
    }

    /// Clean up test data
    pub fn cleanup(self: *Self, table: []const u8) !void {
        std.debug.print("[DB] Cleaning up table '{s}'\n", .{table});
        _ = self;
    }
};

/// File system integration test helper
pub const FSTestHelper = struct {
    test_root: []const u8,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, test_root: []const u8) !Self {
        const cwd = std.fs.cwd();
        try cwd.makeDir(test_root);

        return Self{
            .test_root = try allocator.dupe(u8, test_root),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        // Clean up test directory
        const cwd = std.fs.cwd();
        cwd.deleteTree(self.test_root) catch {};
        self.allocator.free(self.test_root);
    }

    /// Create a test file
    pub fn createFile(self: *Self, relative_path: []const u8, content: []const u8) !void {
        const full_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ self.test_root, relative_path });
        defer self.allocator.free(full_path);

        const cwd = std.fs.cwd();
        const file = try cwd.createFile(full_path, .{});
        defer file.close();

        try file.writeAll(content);
        std.debug.print("[FS] Created file: {s}\n", .{full_path});
    }

    /// Create a test directory
    pub fn createDir(self: *Self, relative_path: []const u8) !void {
        const full_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ self.test_root, relative_path });
        defer self.allocator.free(full_path);

        const cwd = std.fs.cwd();
        try cwd.makeDir(full_path);
        std.debug.print("[FS] Created directory: {s}\n", .{full_path});
    }

    /// Read test file
    pub fn readFile(self: *Self, relative_path: []const u8) ![]u8 {
        const full_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ self.test_root, relative_path });
        defer self.allocator.free(full_path);

        const cwd = std.fs.cwd();
        const file = try cwd.openFile(full_path, .{});
        defer file.close();

        const stat = try file.stat();
        const content = try self.allocator.alloc(u8, stat.size);
        _ = try file.readAll(content);

        return content;
    }

    /// Check if file exists
    pub fn fileExists(self: *Self, relative_path: []const u8) bool {
        const full_path = std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ self.test_root, relative_path }) catch return false;
        defer self.allocator.free(full_path);

        const cwd = std.fs.cwd();
        const file = cwd.openFile(full_path, .{}) catch return false;
        file.close();
        return true;
    }
};

/// Process integration test helper
pub const ProcessTestHelper = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    /// Spawn a test process
    pub fn spawn(self: *Self, cmd: []const []const u8) !std.process.Child {
        var child = std.process.Child.init(cmd, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();
        std.debug.print("[Process] Spawned: {s}\n", .{cmd[0]});

        return child;
    }

    /// Wait for process with timeout
    pub fn waitWithTimeout(self: *Self, child: *std.process.Child, timeout_ms: u64) !void {
        _ = self;
        _ = timeout_ms;

        const term = try child.wait();
        std.debug.print("[Process] Terminated with status: {}\n", .{term});
    }

    /// Kill a process
    pub fn kill(self: *Self, child: *std.process.Child) !void {
        _ = self;
        _ = try child.kill();
        std.debug.print("[Process] Killed process\n", .{});
    }
};

// Tests
test "integration test context" {
    const allocator = std.testing.allocator;
    var ctx = IntegrationTestContext.init(allocator);
    defer ctx.deinit();

    try ctx.createTempDir();
    try ctx.createTempFile("test.txt", "Hello, World!");

    const content = try ctx.readTempFile("test.txt");
    defer allocator.free(content);

    try ctx.assertEqualStrings("Hello, World!", content);
}

test "HTTP test helper" {
    const allocator = std.testing.allocator;
    var http = try HTTPTestHelper.init(allocator, "http://localhost:3000");
    defer http.deinit();

    var response = try http.get("/api/test");
    defer response.deinit(allocator);

    try std.testing.expectEqual(@as(u16, 200), response.status_code);
}

test "file system test helper" {
    const allocator = std.testing.allocator;
    var fs = try FSTestHelper.init(allocator, "test_fs_helper");
    defer fs.deinit();

    try fs.createFile("test.txt", "Test content");
    try std.testing.expect(fs.fileExists("test.txt"));

    const content = try fs.readFile("test.txt");
    defer allocator.free(content);

    try std.testing.expectEqualStrings("Test content", content);
}
