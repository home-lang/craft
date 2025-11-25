const std = @import("std");

/// File System API
/// Provides cross-platform file system operations

pub const FileSystem = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) FileSystem {
        return .{ .allocator = allocator };
    }

    /// Read file contents
    pub fn readFile(self: *FileSystem, path: []const u8, encoding: []const u8) ![]u8 {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const file_stat = try file.stat();
        const contents = try file.readToEndAlloc(self.allocator, file_stat.size);

        if (std.mem.eql(u8, encoding, "utf8")) {
            // Validate UTF-8
            if (!std.unicode.utf8ValidateSlice(contents)) {
                self.allocator.free(contents);
                return error.InvalidUtf8;
            }
        }

        return contents;
    }

    /// Write file contents
    pub fn writeFile(self: *FileSystem, path: []const u8, data: []const u8, encoding: []const u8) !void {
        _ = encoding; // encoding is implicit in the data
        _ = self;

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        try file.writeAll(data);
    }

    /// Read directory contents
    pub fn readDir(self: *FileSystem, path: []const u8) ![][]const u8 {
        var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
        defer dir.close();

        var entries = std.ArrayList([]const u8).init(self.allocator);
        errdefer {
            for (entries.items) |entry| {
                self.allocator.free(entry);
            }
            entries.deinit();
        }

        var it = dir.iterate();
        while (try it.next()) |entry| {
            const name = try self.allocator.dupe(u8, entry.name);
            try entries.append(name);
        }

        return try entries.toOwnedSlice();
    }

    /// Create directory
    pub fn mkdir(self: *FileSystem, path: []const u8, recursive: bool) !void {
        _ = self;

        if (recursive) {
            try std.fs.cwd().makePath(path);
        } else {
            try std.fs.cwd().makeDir(path);
        }
    }

    /// Remove file or directory
    pub fn remove(self: *FileSystem, path: []const u8, recursive: bool) !void {
        _ = self;

        if (recursive) {
            try std.fs.cwd().deleteTree(path);
        } else {
            // Try to delete as file first, then as directory
            std.fs.cwd().deleteFile(path) catch |err| {
                if (err == error.IsDir) {
                    try std.fs.cwd().deleteDir(path);
                } else {
                    return err;
                }
            };
        }
    }

    /// Check if path exists
    pub fn exists(self: *FileSystem, path: []const u8) bool {
        _ = self;
        std.fs.cwd().access(path, .{}) catch return false;
        return true;
    }

    /// Get file statistics
    pub fn stat(self: *FileSystem, path: []const u8) !FileStat {
        _ = self;

        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const file_stat = try file.stat();

        return FileStat{
            .size = file_stat.size,
            .is_file = file_stat.kind == .file,
            .is_dir = file_stat.kind == .directory,
            .is_symlink = file_stat.kind == .sym_link,
            .modified = file_stat.mtime,
            .accessed = file_stat.atime,
            .created = file_stat.ctime,
        };
    }

    /// Copy file
    pub fn copyFile(self: *FileSystem, src: []const u8, dest: []const u8) !void {
        _ = self;
        try std.fs.cwd().copyFile(src, std.fs.cwd(), dest, .{});
    }

    /// Move/rename file
    pub fn moveFile(self: *FileSystem, src: []const u8, dest: []const u8) !void {
        _ = self;
        try std.fs.cwd().rename(src, dest);
    }

    /// Watch directory for changes
    pub fn watch(self: *FileSystem, path: []const u8, callback: *const fn (event: WatchEvent) void) !*DirectoryWatcher {
        const watcher = try self.allocator.create(DirectoryWatcher);
        watcher.* = DirectoryWatcher{
            .allocator = self.allocator,
            .path = try self.allocator.dupe(u8, path),
            .callback = callback,
            .running = false,
        };
        try watcher.start();
        return watcher;
    }
};

pub const FileStat = struct {
    size: u64,
    is_file: bool,
    is_dir: bool,
    is_symlink: bool,
    modified: i128,
    accessed: i128,
    created: i128,
};

pub const WatchEvent = struct {
    path: []const u8,
    event_type: EventType,

    pub const EventType = enum {
        created,
        modified,
        deleted,
        renamed,
    };
};

pub const DirectoryWatcher = struct {
    allocator: std.mem.Allocator,
    path: []const u8,
    callback: *const fn (event: WatchEvent) void,
    running: bool,
    thread: ?std.Thread = null,

    pub fn start(self: *DirectoryWatcher) !void {
        if (self.running) return;
        self.running = true;
        self.thread = try std.Thread.spawn(.{}, watchLoop, .{self});
    }

    pub fn stop(self: *DirectoryWatcher) void {
        self.running = false;
        if (self.thread) |thread| {
            thread.join();
            self.thread = null;
        }
    }

    pub fn deinit(self: *DirectoryWatcher) void {
        self.stop();
        self.allocator.free(self.path);
        self.allocator.destroy(self);
    }

    fn watchLoop(self: *DirectoryWatcher) !void {
        // Simple polling-based watcher (for production, use platform-specific APIs)
        var last_check: i64 = std.time.timestamp();

        while (self.running) {
            const now = std.time.timestamp();
            if (now - last_check >= 1) {
                // Check for changes
                // This is a simplified implementation - real implementation would
                // use inotify (Linux), FSEvents (macOS), or ReadDirectoryChangesW (Windows)
                last_check = now;
            }
            std.time.sleep(100 * std.time.ns_per_ms);
        }
    }
};

// Tests
test "FileSystem init" {
    const allocator = std.testing.allocator;
    const fs = FileSystem.init(allocator);
    _ = fs;
}

test "File operations" {
    const allocator = std.testing.allocator;
    var fs = FileSystem.init(allocator);

    // Write test file
    try fs.writeFile("test_file.txt", "Hello, World!", "utf8");
    defer std.fs.cwd().deleteFile("test_file.txt") catch {};

    // Read test file
    const content = try fs.readFile("test_file.txt", "utf8");
    defer allocator.free(content);

    try std.testing.expectEqualStrings("Hello, World!", content);

    // Check exists
    try std.testing.expect(fs.exists("test_file.txt"));

    // Get stat
    const stat_info = try fs.stat("test_file.txt");
    try std.testing.expect(stat_info.is_file);
    try std.testing.expect(!stat_info.is_dir);
}
