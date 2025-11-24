const std = @import("std");

/// File System API for cross-platform file operations
/// Provides async file operations with proper error handling

pub const FileSystemError = error{
    FileNotFound,
    PermissionDenied,
    PathTooLong,
    DirectoryNotEmpty,
    NotADirectory,
    IsADirectory,
    InvalidPath,
    DiskFull,
    ReadOnlyFilesystem,
};

/// File system configuration
pub const FileSystemConfig = struct {
    enable_watch: bool = false,
    max_file_size: usize = 100 * 1024 * 1024, // 100MB default
    enable_cache: bool = true,
    cache_size: usize = 10 * 1024 * 1024, // 10MB cache
};

/// File metadata
pub const FileMetadata = struct {
    size: usize,
    created: i64,
    modified: i64,
    accessed: i64,
    is_directory: bool,
    is_file: bool,
    is_symlink: bool,
    permissions: u32,
};

/// Directory entry
pub const DirEntry = struct {
    name: []const u8,
    path: []const u8,
    metadata: FileMetadata,
};

/// File System API implementation
pub const FileSystem = struct {
    allocator: std.mem.Allocator,
    config: FileSystemConfig,
    cache: std.StringHashMap([]const u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: FileSystemConfig) FileSystem {
        return FileSystem{
            .allocator = allocator,
            .config = config,
            .cache = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        // Clear cache
        var it = self.cache.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.cache.deinit();
    }

    /// Read file contents
    pub fn readFile(self: *Self, path: []const u8) ![]const u8 {
        // Check cache first
        if (self.config.enable_cache) {
            if (self.cache.get(path)) |cached| {
                return try self.allocator.dupe(u8, cached);
            }
        }

        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            return switch (err) {
                error.FileNotFound => FileSystemError.FileNotFound,
                error.AccessDenied => FileSystemError.PermissionDenied,
                else => err,
            };
        };
        defer file.close();

        const stat = try file.stat();
        if (stat.size > self.config.max_file_size) {
            return error.FileTooLarge;
        }

        const content = try file.readToEndAlloc(self.allocator, self.config.max_file_size);

        // Cache the content
        if (self.config.enable_cache and content.len < self.config.cache_size) {
            const cached_content = try self.allocator.dupe(u8, content);
            try self.cache.put(path, cached_content);
        }

        return content;
    }

    /// Write file contents
    pub fn writeFile(self: *Self, path: []const u8, content: []const u8) !void {
        const file = std.fs.cwd().createFile(path, .{}) catch |err| {
            return switch (err) {
                error.AccessDenied => FileSystemError.PermissionDenied,
                error.PathAlreadyExists => blk: {
                    // Overwrite existing file
                    const f = try std.fs.cwd().openFile(path, .{ .mode = .write_only });
                    break :blk f;
                },
                else => err,
            };
        };
        defer file.close();

        try file.writeAll(content);

        // Update cache
        if (self.config.enable_cache and content.len < self.config.cache_size) {
            if (self.cache.get(path)) |old_content| {
                self.allocator.free(old_content);
            }
            const cached_content = try self.allocator.dupe(u8, content);
            try self.cache.put(path, cached_content);
        }
    }

    /// Read directory contents
    pub fn readDir(self: *Self, path: []const u8) ![]DirEntry {
        var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch |err| {
            return switch (err) {
                error.FileNotFound => FileSystemError.FileNotFound,
                error.AccessDenied => FileSystemError.PermissionDenied,
                error.NotDir => FileSystemError.NotADirectory,
                else => err,
            };
        };
        defer dir.close();

        var entries = std.ArrayList(DirEntry).init(self.allocator);
        defer entries.deinit();

        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            const full_path = try std.fs.path.join(self.allocator, &[_][]const u8{ path, entry.name });
            defer self.allocator.free(full_path);

            const stat = try dir.statFile(entry.name);
            const metadata = FileMetadata{
                .size = stat.size,
                .created = @intCast(stat.ctime),
                .modified = @intCast(stat.mtime),
                .accessed = @intCast(stat.atime),
                .is_directory = entry.kind == .directory,
                .is_file = entry.kind == .file,
                .is_symlink = entry.kind == .sym_link,
                .permissions = @intCast(stat.mode),
            };

            try entries.append(.{
                .name = try self.allocator.dupe(u8, entry.name),
                .path = try self.allocator.dupe(u8, full_path),
                .metadata = metadata,
            });
        }

        return try entries.toOwnedSlice();
    }

    /// Create directory
    pub fn mkdir(self: *Self, path: []const u8) !void {
        _ = self;
        std.fs.cwd().makePath(path) catch |err| {
            return switch (err) {
                error.AccessDenied => FileSystemError.PermissionDenied,
                error.PathAlreadyExists => return, // Already exists, success
                else => err,
            };
        };
    }

    /// Remove file or directory
    pub fn remove(self: *Self, path: []const u8) !void {
        _ = self;

        // Try to determine if it's a directory or file
        const stat = std.fs.cwd().statFile(path) catch |err| {
            return switch (err) {
                error.FileNotFound => FileSystemError.FileNotFound,
                error.AccessDenied => FileSystemError.PermissionDenied,
                else => err,
            };
        };

        if (stat.kind == .directory) {
            std.fs.cwd().deleteTree(path) catch |err| {
                return switch (err) {
                    error.AccessDenied => FileSystemError.PermissionDenied,
                    error.DirNotEmpty => FileSystemError.DirectoryNotEmpty,
                    else => err,
                };
            };
        } else {
            std.fs.cwd().deleteFile(path) catch |err| {
                return switch (err) {
                    error.AccessDenied => FileSystemError.PermissionDenied,
                    error.FileNotFound => FileSystemError.FileNotFound,
                    else => err,
                };
            };
        }

        // Remove from cache if present
        if (self.cache.fetchRemove(path)) |entry| {
            self.allocator.free(entry.value);
        }
    }

    /// Check if path exists
    pub fn exists(self: *Self, path: []const u8) bool {
        _ = self;
        std.fs.cwd().access(path, .{}) catch {
            return false;
        };
        return true;
    }

    /// Get file metadata
    pub fn stat(self: *Self, path: []const u8) !FileMetadata {
        _ = self;
        const file_stat = std.fs.cwd().statFile(path) catch |err| {
            return switch (err) {
                error.FileNotFound => FileSystemError.FileNotFound,
                error.AccessDenied => FileSystemError.PermissionDenied,
                else => err,
            };
        };

        return FileMetadata{
            .size = file_stat.size,
            .created = @intCast(file_stat.ctime),
            .modified = @intCast(file_stat.mtime),
            .accessed = @intCast(file_stat.atime),
            .is_directory = file_stat.kind == .directory,
            .is_file = file_stat.kind == .file,
            .is_symlink = file_stat.kind == .sym_link,
            .permissions = @intCast(file_stat.mode),
        };
    }

    /// Copy file
    pub fn copyFile(self: *Self, src: []const u8, dest: []const u8) !void {
        _ = self;
        try std.fs.cwd().copyFile(src, std.fs.cwd(), dest, .{});
    }

    /// Move/rename file
    pub fn moveFile(self: *Self, src: []const u8, dest: []const u8) !void {
        _ = self;
        try std.fs.cwd().rename(src, dest);

        // Update cache key if present
        if (self.cache.fetchRemove(src)) |entry| {
            try self.cache.put(dest, entry.value);
        }
    }

    /// Watch directory for changes (simplified)
    pub fn watch(self: *Self, path: []const u8, callback: *const fn ([]const u8) void) !void {
        if (!self.config.enable_watch) {
            return error.WatchNotEnabled;
        }

        _ = path;
        _ = callback;
        // Would implement file system watching using platform-specific APIs
        // - inotify on Linux
        // - FSEvents on macOS
        // - ReadDirectoryChangesW on Windows
    }

    /// Clear file cache
    pub fn clearCache(self: *Self) void {
        var it = self.cache.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.cache.clearRetainingCapacity();
    }
};

// Tests
test "filesystem read/write" {
    const allocator = std.testing.allocator;
    var fs = FileSystem.init(allocator, .{});
    defer fs.deinit();

    const test_path = "test_file.txt";
    const content = "Hello, Craft FileSystem!";

    // Write file
    try fs.writeFile(test_path, content);
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Read file
    const read_content = try fs.readFile(test_path);
    defer allocator.free(read_content);

    try std.testing.expectEqualStrings(content, read_content);
}

test "filesystem exists" {
    const allocator = std.testing.allocator;
    var fs = FileSystem.init(allocator, .{});
    defer fs.deinit();

    const test_path = "test_exists.txt";
    try fs.writeFile(test_path, "test");
    defer std.fs.cwd().deleteFile(test_path) catch {};

    try std.testing.expect(fs.exists(test_path));
    try std.testing.expect(!fs.exists("nonexistent.txt"));
}
