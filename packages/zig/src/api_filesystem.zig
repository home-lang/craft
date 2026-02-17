const std = @import("std");
const io_context = @import("io_context.zig");

/// File System API
/// Provides cross-platform file system operations
pub const FileSystem = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) FileSystem {
        return .{ .allocator = allocator };
    }

    /// Read file contents
    pub fn readFile(self: *FileSystem, path: []const u8, encoding: []const u8) ![]u8 {
        const io = io_context.get();
        const file = try io_context.cwd().openFile(io, path, .{});
        defer file.close(io);

        const file_stat = try file.stat(io);
        const contents = try self.allocator.alloc(u8, file_stat.size);
        errdefer self.allocator.free(contents);
        _ = try file.readPositional(io, &.{contents}, 0);

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

        const io = io_context.get();
        const file = try io_context.cwd().createFile(io, path, .{});
        defer file.close(io);

        try file.writeStreamingAll(io, data);
    }

    /// Read directory contents
    pub fn readDir(self: *FileSystem, path: []const u8) ![][]const u8 {
        const io = io_context.get();
        var dir = try io_context.cwd().openDir(io, path, .{ .iterate = true });
        defer dir.close(io);

        var entries = std.ArrayList([]const u8).init(self.allocator);
        errdefer {
            for (entries.items) |entry| {
                self.allocator.free(entry);
            }
            entries.deinit();
        }

        var it = dir.iterate();
        while (try it.next(io)) |entry| {
            const name = try self.allocator.dupe(u8, entry.name);
            try entries.append(name);
        }

        return try entries.toOwnedSlice();
    }

    /// Create directory
    pub fn mkdir(self: *FileSystem, path: []const u8, recursive: bool) !void {
        _ = self;
        const io = io_context.get();

        if (recursive) {
            try io_context.cwd().createDirPath(io, path);
        } else {
            try io_context.cwd().createDir(io, path, .default_dir);
        }
    }

    /// Remove file or directory
    pub fn remove(self: *FileSystem, path: []const u8, recursive: bool) !void {
        _ = self;
        const io = io_context.get();
        const d = io_context.cwd();

        if (recursive) {
            try d.deleteTree(io, path);
        } else {
            // Try to delete as file first, then as directory
            d.deleteFile(io, path) catch |err| {
                if (err == error.IsDir) {
                    try d.deleteDir(io, path);
                } else {
                    return err;
                }
            };
        }
    }

    /// Check if path exists
    pub fn exists(self: *FileSystem, path: []const u8) bool {
        _ = self;
        io_context.cwd().access(io_context.get(), path, .{}) catch return false;
        return true;
    }

    /// Get file statistics
    pub fn stat(self: *FileSystem, path: []const u8) !FileStat {
        _ = self;
        const io = io_context.get();

        const file = try io_context.cwd().openFile(io, path, .{});
        defer file.close(io);

        const file_stat = try file.stat(io);

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
        const io = io_context.get();
        const d = io_context.cwd();
        try std.Io.Dir.copyFile(d, src, d, dest, io, .{});
    }

    /// Move/rename file
    pub fn moveFile(self: *FileSystem, src: []const u8, dest: []const u8) !void {
        _ = self;
        const io = io_context.get();
        const d = io_context.cwd();
        try std.Io.Dir.rename(d, src, d, dest, io);
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
    defer io_context.cwd().deleteFile(io_context.get(), "test_file.txt") catch {};

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
