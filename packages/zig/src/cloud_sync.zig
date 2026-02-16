//! Cross-platform cloud storage and sync abstraction
//! Supports iCloud, Google Drive, Dropbox, OneDrive

const std = @import("std");

/// Get current timestamp in seconds
fn getCurrentTimestamp() i64 {
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
        return ts.sec;
    }
    return 0;
}

/// Cloud storage provider
pub const CloudProvider = enum {
    icloud,
    google_drive,
    dropbox,
    onedrive,
    box,
    s3,
    azure_blob,
    custom,

    pub fn displayName(self: CloudProvider) []const u8 {
        return switch (self) {
            .icloud => "iCloud",
            .google_drive => "Google Drive",
            .dropbox => "Dropbox",
            .onedrive => "OneDrive",
            .box => "Box",
            .s3 => "Amazon S3",
            .azure_blob => "Azure Blob Storage",
            .custom => "Custom Storage",
        };
    }

    pub fn supportsRealTimeSync(self: CloudProvider) bool {
        return switch (self) {
            .icloud, .google_drive, .dropbox, .onedrive => true,
            .box, .s3, .azure_blob, .custom => false,
        };
    }

    pub fn maxFileSize(self: CloudProvider) u64 {
        return switch (self) {
            .icloud => 50 * 1024 * 1024 * 1024, // 50GB
            .google_drive => 5 * 1024 * 1024 * 1024 * 1024, // 5TB
            .dropbox => 2 * 1024 * 1024 * 1024, // 2GB for free
            .onedrive => 250 * 1024 * 1024 * 1024, // 250GB
            .box => 5 * 1024 * 1024 * 1024, // 5GB
            .s3 => 5 * 1024 * 1024 * 1024 * 1024, // 5TB
            .azure_blob => 190 * 1024 * 1024 * 1024, // ~190GB block blob
            .custom => std.math.maxInt(u64),
        };
    }
};

/// Sync state
pub const SyncState = enum {
    idle,
    syncing,
    uploading,
    downloading,
    paused,
    failed,
    offline,

    pub fn isActive(self: SyncState) bool {
        return self == .syncing or self == .uploading or self == .downloading;
    }

    pub fn canSync(self: SyncState) bool {
        return self == .idle or self == .paused;
    }
};

/// Conflict resolution strategy
pub const ConflictStrategy = enum {
    keep_local,
    keep_remote,
    keep_both,
    keep_newest,
    ask_user,
    merge,

    pub fn isAutomatic(self: ConflictStrategy) bool {
        return self != .ask_user;
    }
};

/// File sync status
pub const FileSyncStatus = enum {
    synced,
    pending_upload,
    pending_download,
    uploading,
    downloading,
    conflict,
    failed,
    excluded,

    pub fn needsAction(self: FileSyncStatus) bool {
        return switch (self) {
            .pending_upload, .pending_download, .conflict, .failed => true,
            else => false,
        };
    }
};

/// Cloud file metadata
pub const CloudFile = struct {
    id: [128]u8,
    id_len: u8,
    name: [256]u8,
    name_len: u16,
    path: [512]u8,
    path_len: u16,
    size: u64,
    mime_type: [64]u8,
    mime_len: u8,
    is_folder: bool,
    created_at: i64,
    modified_at: i64,
    version: [64]u8,
    version_len: u8,
    checksum: [64]u8,
    checksum_len: u8,
    sync_status: FileSyncStatus,

    pub fn init() CloudFile {
        return .{
            .id = [_]u8{0} ** 128,
            .id_len = 0,
            .name = [_]u8{0} ** 256,
            .name_len = 0,
            .path = [_]u8{0} ** 512,
            .path_len = 0,
            .size = 0,
            .mime_type = [_]u8{0} ** 64,
            .mime_len = 0,
            .is_folder = false,
            .created_at = getCurrentTimestamp(),
            .modified_at = getCurrentTimestamp(),
            .version = [_]u8{0} ** 64,
            .version_len = 0,
            .checksum = [_]u8{0} ** 64,
            .checksum_len = 0,
            .sync_status = .pending_upload,
        };
    }

    pub fn withId(self: CloudFile, id: []const u8) CloudFile {
        var file = self;
        const len = @min(id.len, 128);
        @memcpy(file.id[0..len], id[0..len]);
        file.id_len = @intCast(len);
        return file;
    }

    pub fn withName(self: CloudFile, name: []const u8) CloudFile {
        var file = self;
        const len = @min(name.len, 256);
        @memcpy(file.name[0..len], name[0..len]);
        file.name_len = @intCast(len);
        return file;
    }

    pub fn withPath(self: CloudFile, path: []const u8) CloudFile {
        var file = self;
        const len = @min(path.len, 512);
        @memcpy(file.path[0..len], path[0..len]);
        file.path_len = @intCast(len);
        return file;
    }

    pub fn withSize(self: CloudFile, size: u64) CloudFile {
        var file = self;
        file.size = size;
        return file;
    }

    pub fn withMimeType(self: CloudFile, mime: []const u8) CloudFile {
        var file = self;
        const len = @min(mime.len, 64);
        @memcpy(file.mime_type[0..len], mime[0..len]);
        file.mime_len = @intCast(len);
        return file;
    }

    pub fn asFolder(self: CloudFile) CloudFile {
        var file = self;
        file.is_folder = true;
        return file;
    }

    pub fn withVersion(self: CloudFile, version: []const u8) CloudFile {
        var file = self;
        const len = @min(version.len, 64);
        @memcpy(file.version[0..len], version[0..len]);
        file.version_len = @intCast(len);
        return file;
    }

    pub fn withChecksum(self: CloudFile, checksum: []const u8) CloudFile {
        var file = self;
        const len = @min(checksum.len, 64);
        @memcpy(file.checksum[0..len], checksum[0..len]);
        file.checksum_len = @intCast(len);
        return file;
    }

    pub fn withStatus(self: CloudFile, status: FileSyncStatus) CloudFile {
        var file = self;
        file.sync_status = status;
        return file;
    }

    pub fn getName(self: CloudFile) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn getPath(self: CloudFile) []const u8 {
        return self.path[0..self.path_len];
    }

    pub fn getId(self: CloudFile) []const u8 {
        return self.id[0..self.id_len];
    }

    pub fn getExtension(self: CloudFile) ?[]const u8 {
        const name = self.getName();
        var i: usize = name.len;
        while (i > 0) : (i -= 1) {
            if (name[i - 1] == '.') {
                return name[i..];
            }
        }
        return null;
    }

    pub fn sizeFormatted(self: CloudFile) struct { value: f64, unit: []const u8 } {
        if (self.size < 1024) {
            return .{ .value = @floatFromInt(self.size), .unit = "B" };
        } else if (self.size < 1024 * 1024) {
            return .{ .value = @as(f64, @floatFromInt(self.size)) / 1024.0, .unit = "KB" };
        } else if (self.size < 1024 * 1024 * 1024) {
            return .{ .value = @as(f64, @floatFromInt(self.size)) / (1024.0 * 1024.0), .unit = "MB" };
        } else {
            return .{ .value = @as(f64, @floatFromInt(self.size)) / (1024.0 * 1024.0 * 1024.0), .unit = "GB" };
        }
    }
};

/// Sync conflict information
pub const SyncConflict = struct {
    file: CloudFile,
    local_version: [64]u8,
    local_version_len: u8,
    remote_version: [64]u8,
    remote_version_len: u8,
    local_modified: i64,
    remote_modified: i64,
    resolved: bool,
    resolution: ?ConflictStrategy,

    pub fn init(file: CloudFile) SyncConflict {
        return .{
            .file = file,
            .local_version = [_]u8{0} ** 64,
            .local_version_len = 0,
            .remote_version = [_]u8{0} ** 64,
            .remote_version_len = 0,
            .local_modified = 0,
            .remote_modified = 0,
            .resolved = false,
            .resolution = null,
        };
    }

    pub fn withLocalVersion(self: SyncConflict, version: []const u8, modified: i64) SyncConflict {
        var conflict = self;
        const len = @min(version.len, 64);
        @memcpy(conflict.local_version[0..len], version[0..len]);
        conflict.local_version_len = @intCast(len);
        conflict.local_modified = modified;
        return conflict;
    }

    pub fn withRemoteVersion(self: SyncConflict, version: []const u8, modified: i64) SyncConflict {
        var conflict = self;
        const len = @min(version.len, 64);
        @memcpy(conflict.remote_version[0..len], version[0..len]);
        conflict.remote_version_len = @intCast(len);
        conflict.remote_modified = modified;
        return conflict;
    }

    pub fn resolve(self: SyncConflict, strategy: ConflictStrategy) SyncConflict {
        var conflict = self;
        conflict.resolved = true;
        conflict.resolution = strategy;
        return conflict;
    }

    pub fn localIsNewer(self: SyncConflict) bool {
        return self.local_modified > self.remote_modified;
    }

    pub fn suggestedResolution(self: SyncConflict) ConflictStrategy {
        if (self.localIsNewer()) {
            return .keep_local;
        } else {
            return .keep_remote;
        }
    }
};

/// Sync progress information
pub const SyncProgress = struct {
    total_files: u32,
    completed_files: u32,
    total_bytes: u64,
    transferred_bytes: u64,
    current_file: [256]u8,
    current_file_len: u16,
    started_at: i64,
    estimated_remaining: i64,

    pub fn init() SyncProgress {
        return .{
            .total_files = 0,
            .completed_files = 0,
            .total_bytes = 0,
            .transferred_bytes = 0,
            .current_file = [_]u8{0} ** 256,
            .current_file_len = 0,
            .started_at = getCurrentTimestamp(),
            .estimated_remaining = 0,
        };
    }

    pub fn percentComplete(self: SyncProgress) f32 {
        if (self.total_bytes == 0) {
            if (self.total_files == 0) return 100.0;
            return @as(f32, @floatFromInt(self.completed_files)) / @as(f32, @floatFromInt(self.total_files)) * 100.0;
        }
        return @as(f32, @floatFromInt(self.transferred_bytes)) / @as(f32, @floatFromInt(self.total_bytes)) * 100.0;
    }

    pub fn bytesPerSecond(self: SyncProgress) f64 {
        const elapsed = getCurrentTimestamp() - self.started_at;
        if (elapsed <= 0) return 0;
        return @as(f64, @floatFromInt(self.transferred_bytes)) / @as(f64, @floatFromInt(elapsed));
    }

    pub fn isComplete(self: SyncProgress) bool {
        return self.completed_files >= self.total_files and self.transferred_bytes >= self.total_bytes;
    }

    pub fn updateProgress(self: *SyncProgress, bytes: u64) void {
        self.transferred_bytes += bytes;
        self.updateEstimate();
    }

    pub fn completeFile(self: *SyncProgress) void {
        self.completed_files += 1;
    }

    pub fn setCurrentFile(self: *SyncProgress, name: []const u8) void {
        const len = @min(name.len, 256);
        @memcpy(self.current_file[0..len], name[0..len]);
        self.current_file_len = @intCast(len);
    }

    fn updateEstimate(self: *SyncProgress) void {
        const speed = self.bytesPerSecond();
        if (speed > 0) {
            const remaining_bytes = self.total_bytes - self.transferred_bytes;
            self.estimated_remaining = @intFromFloat(@as(f64, @floatFromInt(remaining_bytes)) / speed);
        }
    }
};

/// Sync configuration
pub const SyncConfig = struct {
    provider: CloudProvider,
    sync_path: [512]u8,
    sync_path_len: u16,
    conflict_strategy: ConflictStrategy,
    sync_interval_seconds: u32,
    auto_sync: bool,
    sync_on_wifi_only: bool,
    compress_uploads: bool,
    exclude_patterns: [8][64]u8,
    exclude_lens: [8]u8,
    exclude_count: u8,

    pub fn init(provider: CloudProvider) SyncConfig {
        return .{
            .provider = provider,
            .sync_path = [_]u8{0} ** 512,
            .sync_path_len = 0,
            .conflict_strategy = .keep_newest,
            .sync_interval_seconds = 300, // 5 minutes
            .auto_sync = true,
            .sync_on_wifi_only = false,
            .compress_uploads = false,
            .exclude_patterns = [_][64]u8{[_]u8{0} ** 64} ** 8,
            .exclude_lens = [_]u8{0} ** 8,
            .exclude_count = 0,
        };
    }

    pub fn withSyncPath(self: SyncConfig, path: []const u8) SyncConfig {
        var config = self;
        const len = @min(path.len, 512);
        @memcpy(config.sync_path[0..len], path[0..len]);
        config.sync_path_len = @intCast(len);
        return config;
    }

    pub fn withConflictStrategy(self: SyncConfig, strategy: ConflictStrategy) SyncConfig {
        var config = self;
        config.conflict_strategy = strategy;
        return config;
    }

    pub fn withSyncInterval(self: SyncConfig, seconds: u32) SyncConfig {
        var config = self;
        config.sync_interval_seconds = seconds;
        return config;
    }

    pub fn withAutoSync(self: SyncConfig, enabled: bool) SyncConfig {
        var config = self;
        config.auto_sync = enabled;
        return config;
    }

    pub fn withWifiOnly(self: SyncConfig, enabled: bool) SyncConfig {
        var config = self;
        config.sync_on_wifi_only = enabled;
        return config;
    }

    pub fn withCompression(self: SyncConfig, enabled: bool) SyncConfig {
        var config = self;
        config.compress_uploads = enabled;
        return config;
    }

    pub fn addExcludePattern(self: *SyncConfig, pattern: []const u8) void {
        if (self.exclude_count >= 8) return;
        const len = @min(pattern.len, 64);
        @memcpy(self.exclude_patterns[self.exclude_count][0..len], pattern[0..len]);
        self.exclude_lens[self.exclude_count] = @intCast(len);
        self.exclude_count += 1;
    }

    pub fn shouldExclude(self: SyncConfig, filename: []const u8) bool {
        for (0..self.exclude_count) |i| {
            const pattern = self.exclude_patterns[i][0..self.exclude_lens[i]];
            if (matchPattern(pattern, filename)) return true;
        }
        return false;
    }

    fn matchPattern(pattern: []const u8, filename: []const u8) bool {
        // Simple wildcard matching (*.ext)
        if (pattern.len > 0 and pattern[0] == '*') {
            const ext = pattern[1..];
            if (filename.len >= ext.len) {
                return std.mem.eql(u8, filename[filename.len - ext.len ..], ext);
            }
        }
        return std.mem.eql(u8, pattern, filename);
    }
};

/// Sync error
pub const SyncError = enum {
    none,
    network_unavailable,
    authentication_failed,
    quota_exceeded,
    file_not_found,
    permission_denied,
    conflict_unresolved,
    server_error,
    timeout,
    cancelled,
    unknown,

    pub fn description(self: SyncError) []const u8 {
        return switch (self) {
            .none => "No error",
            .network_unavailable => "Network is unavailable",
            .authentication_failed => "Authentication failed",
            .quota_exceeded => "Storage quota exceeded",
            .file_not_found => "File not found",
            .permission_denied => "Permission denied",
            .conflict_unresolved => "Sync conflict not resolved",
            .server_error => "Server error",
            .timeout => "Operation timed out",
            .cancelled => "Operation cancelled",
            .unknown => "Unknown error",
        };
    }

    pub fn isRetryable(self: SyncError) bool {
        return switch (self) {
            .network_unavailable, .server_error, .timeout => true,
            else => false,
        };
    }
};

/// Cloud sync session
pub const SyncSession = struct {
    config: SyncConfig,
    state: SyncState,
    progress: SyncProgress,
    last_sync: i64,
    last_error: SyncError,
    pending_count: u32,
    conflict_count: u32,
    is_authenticated: bool,
    account_id: [128]u8,
    account_id_len: u8,

    pub fn init(config: SyncConfig) SyncSession {
        return .{
            .config = config,
            .state = .idle,
            .progress = SyncProgress.init(),
            .last_sync = 0,
            .last_error = .none,
            .pending_count = 0,
            .conflict_count = 0,
            .is_authenticated = false,
            .account_id = [_]u8{0} ** 128,
            .account_id_len = 0,
        };
    }

    pub fn authenticate(self: *SyncSession, account_id: []const u8) void {
        const len = @min(account_id.len, 128);
        @memcpy(self.account_id[0..len], account_id[0..len]);
        self.account_id_len = @intCast(len);
        self.is_authenticated = true;
    }

    pub fn startSync(self: *SyncSession) bool {
        if (!self.is_authenticated) {
            self.last_error = .authentication_failed;
            return false;
        }
        if (!self.state.canSync()) {
            return false;
        }
        self.state = .syncing;
        self.progress = SyncProgress.init();
        self.last_error = .none;
        return true;
    }

    pub fn pauseSync(self: *SyncSession) void {
        if (self.state.isActive()) {
            self.state = .paused;
        }
    }

    pub fn resumeSync(self: *SyncSession) void {
        if (self.state == .paused) {
            self.state = .syncing;
        }
    }

    pub fn completeSync(self: *SyncSession) void {
        self.state = .idle;
        self.last_sync = getCurrentTimestamp();
    }

    pub fn failSync(self: *SyncSession, err: SyncError) void {
        self.state = .failed;
        self.last_error = err;
    }

    pub fn goOffline(self: *SyncSession) void {
        self.state = .offline;
    }

    pub fn goOnline(self: *SyncSession) void {
        if (self.state == .offline) {
            self.state = .idle;
        }
    }

    pub fn needsSync(self: SyncSession) bool {
        if (!self.config.auto_sync) return false;
        if (!self.is_authenticated) return false;
        if (!self.state.canSync()) return false;

        const now = getCurrentTimestamp();
        const interval: i64 = self.config.sync_interval_seconds;
        return (now - self.last_sync) >= interval;
    }

    pub fn getAccountId(self: SyncSession) []const u8 {
        return self.account_id[0..self.account_id_len];
    }

    pub fn addPending(self: *SyncSession, count: u32) void {
        self.pending_count += count;
    }

    pub fn resolvePending(self: *SyncSession, count: u32) void {
        if (count > self.pending_count) {
            self.pending_count = 0;
        } else {
            self.pending_count -= count;
        }
    }

    pub fn addConflict(self: *SyncSession) void {
        self.conflict_count += 1;
    }

    pub fn resolveConflict(self: *SyncSession) void {
        if (self.conflict_count > 0) {
            self.conflict_count -= 1;
        }
    }
};

/// Cloud sync controller
pub const CloudSyncController = struct {
    sessions: [4]?SyncSession,
    session_count: u8,
    default_session: ?u8,
    is_online: bool,

    pub fn init() CloudSyncController {
        return .{
            .sessions = [_]?SyncSession{null} ** 4,
            .session_count = 0,
            .default_session = null,
            .is_online = true,
        };
    }

    pub fn createSession(self: *CloudSyncController, config: SyncConfig) ?u8 {
        if (self.session_count >= 4) return null;

        var slot: u8 = 0;
        while (slot < 4) : (slot += 1) {
            if (self.sessions[slot] == null) break;
        }
        if (slot >= 4) return null;

        self.sessions[slot] = SyncSession.init(config);
        self.session_count += 1;

        if (self.default_session == null) {
            self.default_session = slot;
        }

        return slot;
    }

    pub fn getSession(self: *CloudSyncController, index: u8) ?*SyncSession {
        if (index >= 4) return null;
        if (self.sessions[index]) |*session| {
            return session;
        }
        return null;
    }

    pub fn getDefaultSession(self: *CloudSyncController) ?*SyncSession {
        if (self.default_session) |idx| {
            return self.getSession(idx);
        }
        return null;
    }

    pub fn removeSession(self: *CloudSyncController, index: u8) bool {
        if (index >= 4) return false;
        if (self.sessions[index] != null) {
            self.sessions[index] = null;
            self.session_count -= 1;

            if (self.default_session == index) {
                self.default_session = null;
                for (0..4) |i| {
                    if (self.sessions[i] != null) {
                        self.default_session = @intCast(i);
                        break;
                    }
                }
            }
            return true;
        }
        return false;
    }

    pub fn findSessionByProvider(self: *CloudSyncController, provider: CloudProvider) ?u8 {
        for (0..4) |i| {
            if (self.sessions[i]) |session| {
                if (session.config.provider == provider) {
                    return @intCast(i);
                }
            }
        }
        return null;
    }

    pub fn setOnlineStatus(self: *CloudSyncController, online: bool) void {
        self.is_online = online;
        for (0..4) |i| {
            if (self.sessions[i]) |*session| {
                if (online) {
                    session.goOnline();
                } else {
                    session.goOffline();
                }
            }
        }
    }

    pub fn syncAll(self: *CloudSyncController) u8 {
        if (!self.is_online) return 0;

        var started: u8 = 0;
        for (0..4) |i| {
            if (self.sessions[i]) |*session| {
                if (session.needsSync() and session.startSync()) {
                    started += 1;
                }
            }
        }
        return started;
    }

    pub fn getTotalPending(self: CloudSyncController) u32 {
        var total: u32 = 0;
        for (self.sessions) |maybe_session| {
            if (maybe_session) |session| {
                total += session.pending_count;
            }
        }
        return total;
    }

    pub fn getTotalConflicts(self: CloudSyncController) u32 {
        var total: u32 = 0;
        for (self.sessions) |maybe_session| {
            if (maybe_session) |session| {
                total += session.conflict_count;
            }
        }
        return total;
    }
};

/// Check if cloud sync is supported
pub fn isSupported() bool {
    return true; // Cloud sync is platform-agnostic via HTTP
}

// Tests
test "CloudProvider properties" {
    const icloud = CloudProvider.icloud;
    try std.testing.expectEqualStrings("iCloud", icloud.displayName());
    try std.testing.expect(icloud.supportsRealTimeSync());
    try std.testing.expect(icloud.maxFileSize() > 0);
}

test "CloudProvider max file sizes" {
    try std.testing.expect(CloudProvider.google_drive.maxFileSize() > CloudProvider.dropbox.maxFileSize());
    try std.testing.expect(CloudProvider.s3.maxFileSize() > CloudProvider.icloud.maxFileSize());
}

test "SyncState properties" {
    try std.testing.expect(SyncState.syncing.isActive());
    try std.testing.expect(SyncState.uploading.isActive());
    try std.testing.expect(!SyncState.idle.isActive());
    try std.testing.expect(SyncState.idle.canSync());
    try std.testing.expect(!SyncState.syncing.canSync());
}

test "ConflictStrategy properties" {
    try std.testing.expect(ConflictStrategy.keep_local.isAutomatic());
    try std.testing.expect(!ConflictStrategy.ask_user.isAutomatic());
}

test "FileSyncStatus properties" {
    try std.testing.expect(FileSyncStatus.pending_upload.needsAction());
    try std.testing.expect(FileSyncStatus.conflict.needsAction());
    try std.testing.expect(!FileSyncStatus.synced.needsAction());
}

test "CloudFile initialization" {
    const file = CloudFile.init();
    try std.testing.expectEqual(FileSyncStatus.pending_upload, file.sync_status);
    try std.testing.expect(!file.is_folder);
}

test "CloudFile builder" {
    const file = CloudFile.init()
        .withId("file_123")
        .withName("document.pdf")
        .withPath("/documents/document.pdf")
        .withSize(1024 * 1024)
        .withMimeType("application/pdf");

    try std.testing.expectEqualStrings("file_123", file.getId());
    try std.testing.expectEqualStrings("document.pdf", file.getName());
    try std.testing.expectEqual(@as(u64, 1024 * 1024), file.size);
}

test "CloudFile as folder" {
    const folder = CloudFile.init()
        .withName("Documents")
        .asFolder();

    try std.testing.expect(folder.is_folder);
}

test "CloudFile extension" {
    const pdf = CloudFile.init().withName("report.pdf");
    try std.testing.expectEqualStrings("pdf", pdf.getExtension().?);

    const no_ext = CloudFile.init().withName("README");
    try std.testing.expect(no_ext.getExtension() == null);
}

test "CloudFile size formatting" {
    const small = CloudFile.init().withSize(500);
    try std.testing.expectEqualStrings("B", small.sizeFormatted().unit);

    const medium = CloudFile.init().withSize(1024 * 500);
    try std.testing.expectEqualStrings("KB", medium.sizeFormatted().unit);

    const large = CloudFile.init().withSize(1024 * 1024 * 50);
    try std.testing.expectEqualStrings("MB", large.sizeFormatted().unit);
}

test "SyncConflict creation" {
    const file = CloudFile.init().withName("conflict.txt");
    const conflict = SyncConflict.init(file)
        .withLocalVersion("v1", 1000)
        .withRemoteVersion("v2", 2000);

    try std.testing.expect(!conflict.localIsNewer());
    try std.testing.expectEqual(ConflictStrategy.keep_remote, conflict.suggestedResolution());
}

test "SyncConflict resolution" {
    const file = CloudFile.init().withName("file.txt");
    var conflict = SyncConflict.init(file);
    conflict = conflict.resolve(.keep_both);

    try std.testing.expect(conflict.resolved);
    try std.testing.expectEqual(ConflictStrategy.keep_both, conflict.resolution.?);
}

test "SyncProgress initialization" {
    const progress = SyncProgress.init();
    try std.testing.expectEqual(@as(u32, 0), progress.total_files);
    try std.testing.expectEqual(@as(u64, 0), progress.transferred_bytes);
}

test "SyncProgress percentage" {
    var progress = SyncProgress.init();
    progress.total_bytes = 1000;
    progress.transferred_bytes = 500;

    try std.testing.expectApproxEqAbs(@as(f32, 50.0), progress.percentComplete(), 0.1);
}

test "SyncProgress completion" {
    var progress = SyncProgress.init();
    progress.total_files = 5;
    progress.completed_files = 5;
    progress.total_bytes = 1000;
    progress.transferred_bytes = 1000;

    try std.testing.expect(progress.isComplete());
}

test "SyncConfig initialization" {
    const config = SyncConfig.init(.google_drive);
    try std.testing.expectEqual(CloudProvider.google_drive, config.provider);
    try std.testing.expect(config.auto_sync);
    try std.testing.expectEqual(@as(u32, 300), config.sync_interval_seconds);
}

test "SyncConfig builder" {
    const config = SyncConfig.init(.icloud)
        .withSyncPath("/sync")
        .withConflictStrategy(.keep_local)
        .withSyncInterval(600)
        .withAutoSync(false)
        .withWifiOnly(true);

    try std.testing.expect(!config.auto_sync);
    try std.testing.expect(config.sync_on_wifi_only);
    try std.testing.expectEqual(@as(u32, 600), config.sync_interval_seconds);
}

test "SyncConfig exclude patterns" {
    var config = SyncConfig.init(.dropbox);
    config.addExcludePattern("*.tmp");
    config.addExcludePattern(".DS_Store");

    try std.testing.expect(config.shouldExclude("file.tmp"));
    try std.testing.expect(config.shouldExclude(".DS_Store"));
    try std.testing.expect(!config.shouldExclude("document.pdf"));
}

test "SyncError properties" {
    try std.testing.expect(SyncError.network_unavailable.isRetryable());
    try std.testing.expect(SyncError.timeout.isRetryable());
    try std.testing.expect(!SyncError.quota_exceeded.isRetryable());
    try std.testing.expect(SyncError.none.description().len > 0);
}

test "SyncSession initialization" {
    const config = SyncConfig.init(.onedrive);
    const session = SyncSession.init(config);

    try std.testing.expectEqual(SyncState.idle, session.state);
    try std.testing.expect(!session.is_authenticated);
}

test "SyncSession authentication" {
    const config = SyncConfig.init(.google_drive);
    var session = SyncSession.init(config);

    session.authenticate("user@example.com");
    try std.testing.expect(session.is_authenticated);
    try std.testing.expectEqual(@as(u8, 16), session.account_id_len);
}

test "SyncSession start sync" {
    const config = SyncConfig.init(.icloud);
    var session = SyncSession.init(config);

    // Should fail without auth
    try std.testing.expect(!session.startSync());
    try std.testing.expectEqual(SyncError.authentication_failed, session.last_error);

    // Should succeed with auth
    session.authenticate("user_123");
    try std.testing.expect(session.startSync());
    try std.testing.expectEqual(SyncState.syncing, session.state);
}

test "SyncSession pause/resume" {
    const config = SyncConfig.init(.dropbox);
    var session = SyncSession.init(config);
    session.authenticate("user");
    _ = session.startSync();

    session.pauseSync();
    try std.testing.expectEqual(SyncState.paused, session.state);

    session.resumeSync();
    try std.testing.expectEqual(SyncState.syncing, session.state);
}

test "SyncSession complete sync" {
    const config = SyncConfig.init(.onedrive);
    var session = SyncSession.init(config);
    session.authenticate("user");
    _ = session.startSync();

    session.completeSync();
    try std.testing.expectEqual(SyncState.idle, session.state);
    try std.testing.expect(session.last_sync > 0);
}

test "SyncSession error handling" {
    const config = SyncConfig.init(.s3);
    var session = SyncSession.init(config);
    session.authenticate("user");
    _ = session.startSync();

    session.failSync(.quota_exceeded);
    try std.testing.expectEqual(SyncState.failed, session.state);
    try std.testing.expectEqual(SyncError.quota_exceeded, session.last_error);
}

test "SyncSession online/offline" {
    const config = SyncConfig.init(.icloud);
    var session = SyncSession.init(config);

    session.goOffline();
    try std.testing.expectEqual(SyncState.offline, session.state);

    session.goOnline();
    try std.testing.expectEqual(SyncState.idle, session.state);
}

test "SyncSession pending/conflicts" {
    const config = SyncConfig.init(.google_drive);
    var session = SyncSession.init(config);

    session.addPending(5);
    try std.testing.expectEqual(@as(u32, 5), session.pending_count);

    session.resolvePending(3);
    try std.testing.expectEqual(@as(u32, 2), session.pending_count);

    session.addConflict();
    session.addConflict();
    try std.testing.expectEqual(@as(u32, 2), session.conflict_count);

    session.resolveConflict();
    try std.testing.expectEqual(@as(u32, 1), session.conflict_count);
}

test "CloudSyncController initialization" {
    const controller = CloudSyncController.init();
    try std.testing.expectEqual(@as(u8, 0), controller.session_count);
    try std.testing.expect(controller.is_online);
}

test "CloudSyncController create session" {
    var controller = CloudSyncController.init();
    const config = SyncConfig.init(.icloud);

    const idx = controller.createSession(config);
    try std.testing.expect(idx != null);
    try std.testing.expectEqual(@as(u8, 1), controller.session_count);
}

test "CloudSyncController multiple sessions" {
    var controller = CloudSyncController.init();

    _ = controller.createSession(SyncConfig.init(.icloud));
    _ = controller.createSession(SyncConfig.init(.google_drive));
    _ = controller.createSession(SyncConfig.init(.dropbox));

    try std.testing.expectEqual(@as(u8, 3), controller.session_count);
}

test "CloudSyncController find by provider" {
    var controller = CloudSyncController.init();

    _ = controller.createSession(SyncConfig.init(.icloud));
    _ = controller.createSession(SyncConfig.init(.google_drive));

    const icloud_idx = controller.findSessionByProvider(.icloud);
    const s3_idx = controller.findSessionByProvider(.s3);

    try std.testing.expect(icloud_idx != null);
    try std.testing.expect(s3_idx == null);
}

test "CloudSyncController remove session" {
    var controller = CloudSyncController.init();
    const idx = controller.createSession(SyncConfig.init(.dropbox));

    try std.testing.expect(controller.removeSession(idx.?));
    try std.testing.expectEqual(@as(u8, 0), controller.session_count);
}

test "CloudSyncController online status" {
    var controller = CloudSyncController.init();
    const idx = controller.createSession(SyncConfig.init(.icloud)).?;

    controller.setOnlineStatus(false);
    try std.testing.expect(!controller.is_online);

    if (controller.getSession(idx)) |session| {
        try std.testing.expectEqual(SyncState.offline, session.state);
    }
}

test "CloudSyncController totals" {
    var controller = CloudSyncController.init();

    const idx1 = controller.createSession(SyncConfig.init(.icloud)).?;
    const idx2 = controller.createSession(SyncConfig.init(.google_drive)).?;

    if (controller.getSession(idx1)) |s| {
        s.addPending(3);
        s.addConflict();
    }
    if (controller.getSession(idx2)) |s| {
        s.addPending(2);
        s.addConflict();
    }

    try std.testing.expectEqual(@as(u32, 5), controller.getTotalPending());
    try std.testing.expectEqual(@as(u32, 2), controller.getTotalConflicts());
}

test "isSupported" {
    try std.testing.expect(isSupported());
}
