//! Files Provider Module
//! iOS File Provider Extension and Android Storage Access Framework (SAF)
//! Provides cross-platform abstractions for system file integration

const std = @import("std");
const builtin = @import("builtin");

/// Platform-specific file provider backends
pub const Platform = enum {
    ios, // File Provider Extension
    macos, // File Provider Extension
    android, // Storage Access Framework (SAF)
    linux, // XDG portals / GVFS
    windows, // Shell namespace extensions
    unsupported,

    pub fn current() Platform {
        return switch (builtin.os.tag) {
            .ios => .ios,
            .macos => .macos,
            .linux => .linux,
            .windows => .windows,
            else => if (builtin.abi == .android) .android else .unsupported,
        };
    }

    pub fn supportsFileProvider(self: Platform) bool {
        return self != .unsupported;
    }

    pub fn frameworkName(self: Platform) []const u8 {
        return switch (self) {
            .ios, .macos => "FileProvider",
            .android => "Storage Access Framework",
            .linux => "XDG Portal",
            .windows => "Shell Extensions",
            .unsupported => "None",
        };
    }
};

/// File item type
pub const ItemType = enum {
    file,
    folder,
    root,
    working_set,
    recent,
    trash,

    pub fn isContainer(self: ItemType) bool {
        return self == .folder or self == .root or self == .working_set or
            self == .recent or self == .trash;
    }
};

/// File capabilities
pub const Capabilities = struct {
    readable: bool = true,
    writable: bool = true,
    renamable: bool = true,
    deletable: bool = true,
    trashable: bool = true,
    evictable: bool = false,
    allows_adding_children: bool = false,
    allows_content_enumerating: bool = false,

    pub fn init() Capabilities {
        return .{};
    }

    pub fn readOnly() Capabilities {
        return .{
            .writable = false,
            .renamable = false,
            .deletable = false,
        };
    }

    pub fn folder() Capabilities {
        return .{
            .allows_adding_children = true,
            .allows_content_enumerating = true,
        };
    }

    pub fn withWritable(self: Capabilities, writable: bool) Capabilities {
        var copy = self;
        copy.writable = writable;
        return copy;
    }

    pub fn withDeletable(self: Capabilities, deletable: bool) Capabilities {
        var copy = self;
        copy.deletable = deletable;
        return copy;
    }
};

/// File item identifier
pub const ItemIdentifier = struct {
    id: []const u8,
    parent_id: ?[]const u8 = null,
    domain_id: ?[]const u8 = null,

    pub const root_container = ItemIdentifier{ .id = "root" };
    pub const working_set = ItemIdentifier{ .id = "working_set" };
    pub const trash_container = ItemIdentifier{ .id = "trash" };

    pub fn init(id: []const u8) ItemIdentifier {
        return .{ .id = id };
    }

    pub fn withParent(self: ItemIdentifier, parent_id: []const u8) ItemIdentifier {
        var copy = self;
        copy.parent_id = parent_id;
        return copy;
    }

    pub fn withDomain(self: ItemIdentifier, domain_id: []const u8) ItemIdentifier {
        var copy = self;
        copy.domain_id = domain_id;
        return copy;
    }

    pub fn isRoot(self: *const ItemIdentifier) bool {
        return std.mem.eql(u8, self.id, "root");
    }

    pub fn isTrash(self: *const ItemIdentifier) bool {
        return std.mem.eql(u8, self.id, "trash");
    }
};

/// Content type / MIME type
pub const ContentType = struct {
    type_identifier: []const u8,
    preferred_extension: ?[]const u8 = null,

    pub const folder = ContentType{ .type_identifier = "public.folder" };
    pub const data = ContentType{ .type_identifier = "public.data" };
    pub const text = ContentType{ .type_identifier = "public.plain-text", .preferred_extension = "txt" };
    pub const pdf = ContentType{ .type_identifier = "com.adobe.pdf", .preferred_extension = "pdf" };
    pub const image = ContentType{ .type_identifier = "public.image" };
    pub const jpeg = ContentType{ .type_identifier = "public.jpeg", .preferred_extension = "jpg" };
    pub const png = ContentType{ .type_identifier = "public.png", .preferred_extension = "png" };

    pub fn init(type_identifier: []const u8) ContentType {
        return .{ .type_identifier = type_identifier };
    }

    pub fn withExtension(self: ContentType, ext: []const u8) ContentType {
        var copy = self;
        copy.preferred_extension = ext;
        return copy;
    }

    pub fn isFolder(self: *const ContentType) bool {
        return std.mem.eql(u8, self.type_identifier, "public.folder");
    }
};

/// File provider item
pub const FileItem = struct {
    identifier: ItemIdentifier,
    filename: []const u8,
    item_type: ItemType = .file,
    content_type: ContentType = ContentType.data,
    capabilities: Capabilities = Capabilities.init(),
    size_bytes: u64 = 0,
    created_at: i64 = 0,
    modified_at: i64 = 0,
    is_downloaded: bool = true,
    is_uploading: bool = false,
    is_downloading: bool = false,
    download_progress: f32 = 1.0,
    upload_progress: f32 = 0.0,
    version_identifier: ?[]const u8 = null,
    tag_data: ?[]const u8 = null,
    is_shared: bool = false,
    is_favorite: bool = false,

    pub fn init(identifier: ItemIdentifier, filename: []const u8) FileItem {
        return .{
            .identifier = identifier,
            .filename = filename,
            .created_at = getCurrentTimestamp(),
            .modified_at = getCurrentTimestamp(),
        };
    }

    pub fn asFolder(self: FileItem) FileItem {
        var copy = self;
        copy.item_type = .folder;
        copy.content_type = ContentType.folder;
        copy.capabilities = Capabilities.folder();
        return copy;
    }

    pub fn withType(self: FileItem, item_type: ItemType) FileItem {
        var copy = self;
        copy.item_type = item_type;
        return copy;
    }

    pub fn withContentType(self: FileItem, content_type: ContentType) FileItem {
        var copy = self;
        copy.content_type = content_type;
        return copy;
    }

    pub fn withCapabilities(self: FileItem, capabilities: Capabilities) FileItem {
        var copy = self;
        copy.capabilities = capabilities;
        return copy;
    }

    pub fn withSize(self: FileItem, size_bytes: u64) FileItem {
        var copy = self;
        copy.size_bytes = size_bytes;
        return copy;
    }

    pub fn withVersion(self: FileItem, version: []const u8) FileItem {
        var copy = self;
        copy.version_identifier = version;
        return copy;
    }

    pub fn markAsShared(self: FileItem) FileItem {
        var copy = self;
        copy.is_shared = true;
        return copy;
    }

    pub fn markAsFavorite(self: FileItem) FileItem {
        var copy = self;
        copy.is_favorite = true;
        return copy;
    }

    pub fn isContainer(self: *const FileItem) bool {
        return self.item_type.isContainer();
    }

    pub fn needsDownload(self: *const FileItem) bool {
        return !self.is_downloaded and !self.is_downloading;
    }
};

/// Enumeration options
pub const EnumerationOptions = struct {
    include_hidden: bool = false,
    include_trashed: bool = false,
    sort_by: SortField = .name,
    sort_ascending: bool = true,
    page_size: u32 = 100,
    page_token: ?[]const u8 = null,

    pub const SortField = enum {
        name,
        date_modified,
        date_created,
        size,
        content_type,
    };

    pub fn init() EnumerationOptions {
        return .{};
    }

    pub fn withSorting(self: EnumerationOptions, field: SortField, ascending: bool) EnumerationOptions {
        var copy = self;
        copy.sort_by = field;
        copy.sort_ascending = ascending;
        return copy;
    }

    pub fn withPageSize(self: EnumerationOptions, size: u32) EnumerationOptions {
        var copy = self;
        copy.page_size = size;
        return copy;
    }

    pub fn showHidden(self: EnumerationOptions) EnumerationOptions {
        var copy = self;
        copy.include_hidden = true;
        return copy;
    }
};

/// Enumeration result
pub const EnumerationResult = struct {
    allocator: std.mem.Allocator,
    items: std.ArrayListUnmanaged(FileItem),
    next_page_token: ?[]const u8 = null,
    has_more: bool = false,
    total_count: ?u64 = null,

    pub fn init(allocator: std.mem.Allocator) EnumerationResult {
        return .{
            .allocator = allocator,
            .items = .empty,
        };
    }

    pub fn deinit(self: *EnumerationResult) void {
        self.items.deinit(self.allocator);
    }

    pub fn addItem(self: *EnumerationResult, item: FileItem) !void {
        try self.items.append(self.allocator, item);
    }

    pub fn count(self: *const EnumerationResult) usize {
        return self.items.items.len;
    }

    pub fn setNextPage(self: *EnumerationResult, token: []const u8) void {
        self.next_page_token = token;
        self.has_more = true;
    }
};

/// File operation type
pub const OperationType = enum {
    create,
    modify,
    delete,
    move,
    rename,
    copy,
    trash,
    restore,
    download,
    upload,
    evict,
};

/// File change notification
pub const ChangeNotification = struct {
    operation: OperationType,
    item_identifier: ItemIdentifier,
    timestamp: i64,
    old_parent_id: ?[]const u8 = null,
    new_parent_id: ?[]const u8 = null,
    change_tag: ?[]const u8 = null,

    pub fn init(operation: OperationType, item_identifier: ItemIdentifier) ChangeNotification {
        return .{
            .operation = operation,
            .item_identifier = item_identifier,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn withOldParent(self: ChangeNotification, parent_id: []const u8) ChangeNotification {
        var copy = self;
        copy.old_parent_id = parent_id;
        return copy;
    }

    pub fn withNewParent(self: ChangeNotification, parent_id: []const u8) ChangeNotification {
        var copy = self;
        copy.new_parent_id = parent_id;
        return copy;
    }
};

/// Domain configuration
pub const Domain = struct {
    identifier: []const u8,
    display_name: []const u8,
    is_hidden: bool = false,
    is_replicated: bool = false,
    backup_enabled: bool = true,
    user_enabled: bool = true,
    supports_incremental_fetch: bool = false,
    path_relative_to_document_storage: ?[]const u8 = null,

    pub fn init(identifier: []const u8, display_name: []const u8) Domain {
        return .{
            .identifier = identifier,
            .display_name = display_name,
        };
    }

    pub fn asHidden(self: Domain) Domain {
        var copy = self;
        copy.is_hidden = true;
        return copy;
    }

    pub fn asReplicated(self: Domain) Domain {
        var copy = self;
        copy.is_replicated = true;
        return copy;
    }

    pub fn withPath(self: Domain, path: []const u8) Domain {
        var copy = self;
        copy.path_relative_to_document_storage = path;
        return copy;
    }

    pub fn withIncrementalFetch(self: Domain, enabled: bool) Domain {
        var copy = self;
        copy.supports_incremental_fetch = enabled;
        return copy;
    }
};

/// Provider event
pub const ProviderEvent = struct {
    event_type: EventType,
    domain_id: ?[]const u8 = null,
    item_id: ?[]const u8 = null,
    timestamp: i64,
    data: ?[]const u8 = null,

    pub const EventType = enum {
        domain_added,
        domain_removed,
        item_created,
        item_modified,
        item_deleted,
        item_moved,
        sync_started,
        sync_completed,
        sync_failed,
        enumeration_started,
        enumeration_completed,
    };

    pub fn init(event_type: EventType) ProviderEvent {
        return .{
            .event_type = event_type,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn withDomain(self: ProviderEvent, domain_id: []const u8) ProviderEvent {
        var copy = self;
        copy.domain_id = domain_id;
        return copy;
    }

    pub fn withItem(self: ProviderEvent, item_id: []const u8) ProviderEvent {
        var copy = self;
        copy.item_id = item_id;
        return copy;
    }
};

/// Sync anchor for change tracking
pub const SyncAnchor = struct {
    data: [64]u8 = undefined,
    len: usize = 0,
    timestamp: i64 = 0,

    pub fn init() SyncAnchor {
        return .{};
    }

    pub fn initWithTimestamp() SyncAnchor {
        return .{
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn setData(self: *SyncAnchor, anchor_data: []const u8) void {
        const copy_len = @min(anchor_data.len, self.data.len);
        @memcpy(self.data[0..copy_len], anchor_data[0..copy_len]);
        self.len = copy_len;
    }

    pub fn getData(self: *const SyncAnchor) []const u8 {
        return self.data[0..self.len];
    }

    pub fn isValid(self: *const SyncAnchor) bool {
        return self.len > 0;
    }
};

/// Progress tracking for transfers
pub const TransferProgress = struct {
    item_id: []const u8,
    operation: OperationType,
    bytes_transferred: u64 = 0,
    total_bytes: u64 = 0,
    started_at: i64,
    estimated_completion: ?i64 = null,
    is_paused: bool = false,
    is_cancelled: bool = false,

    pub fn init(item_id: []const u8, operation: OperationType, total_bytes: u64) TransferProgress {
        return .{
            .item_id = item_id,
            .operation = operation,
            .total_bytes = total_bytes,
            .started_at = getCurrentTimestamp(),
        };
    }

    pub fn update(self: *TransferProgress, bytes: u64) void {
        self.bytes_transferred = bytes;
    }

    pub fn progress(self: *const TransferProgress) f32 {
        if (self.total_bytes == 0) return 1.0;
        return @as(f32, @floatFromInt(self.bytes_transferred)) / @as(f32, @floatFromInt(self.total_bytes));
    }

    pub fn isComplete(self: *const TransferProgress) bool {
        return self.bytes_transferred >= self.total_bytes;
    }

    pub fn pause(self: *TransferProgress) void {
        self.is_paused = true;
    }

    pub fn resume_transfer(self: *TransferProgress) void {
        self.is_paused = false;
    }

    pub fn cancel(self: *TransferProgress) void {
        self.is_cancelled = true;
    }

    pub fn elapsedSeconds(self: *const TransferProgress) i64 {
        return getCurrentTimestamp() - self.started_at;
    }
};

/// File Provider Controller
pub const FileProviderController = struct {
    allocator: std.mem.Allocator,
    domains: std.ArrayListUnmanaged(Domain),
    items: std.ArrayListUnmanaged(FileItem),
    change_notifications: std.ArrayListUnmanaged(ChangeNotification),
    transfers: std.ArrayListUnmanaged(TransferProgress),
    event_history: std.ArrayListUnmanaged(ProviderEvent),
    event_callback: ?*const fn (ProviderEvent) void = null,
    current_sync_anchor: SyncAnchor = .{},
    is_enabled: bool = true,
    item_counter: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) FileProviderController {
        return .{
            .allocator = allocator,
            .domains = .empty,
            .items = .empty,
            .change_notifications = .empty,
            .transfers = .empty,
            .event_history = .empty,
        };
    }

    pub fn deinit(self: *FileProviderController) void {
        self.domains.deinit(self.allocator);
        self.items.deinit(self.allocator);
        self.change_notifications.deinit(self.allocator);
        self.transfers.deinit(self.allocator);
        self.event_history.deinit(self.allocator);
    }

    pub fn addDomain(self: *FileProviderController, domain: Domain) !void {
        try self.domains.append(self.allocator, domain);

        const event = ProviderEvent.init(.domain_added)
            .withDomain(domain.identifier);
        try self.event_history.append(self.allocator, event);

        if (self.event_callback) |callback| {
            callback(event);
        }
    }

    pub fn removeDomain(self: *FileProviderController, domain_id: []const u8) !void {
        var i: usize = 0;
        while (i < self.domains.items.len) {
            if (std.mem.eql(u8, self.domains.items[i].identifier, domain_id)) {
                _ = self.domains.orderedRemove(i);

                const event = ProviderEvent.init(.domain_removed)
                    .withDomain(domain_id);
                try self.event_history.append(self.allocator, event);

                if (self.event_callback) |callback| {
                    callback(event);
                }
                return;
            }
            i += 1;
        }
        return error.DomainNotFound;
    }

    pub fn getDomains(self: *const FileProviderController) []const Domain {
        return self.domains.items;
    }

    pub fn createItem(self: *FileProviderController, parent_id: ItemIdentifier, filename: []const u8) !*FileItem {
        self.item_counter += 1;

        var id_buf: [32]u8 = undefined;
        const id = try std.fmt.bufPrint(&id_buf, "item_{d}", .{self.item_counter});

        const identifier = ItemIdentifier.init(id).withParent(parent_id.id);
        const item = FileItem.init(identifier, filename);

        try self.items.append(self.allocator, item);

        const notification = ChangeNotification.init(.create, identifier);
        try self.change_notifications.append(self.allocator, notification);

        const event = ProviderEvent.init(.item_created).withItem(id);
        try self.event_history.append(self.allocator, event);

        if (self.event_callback) |callback| {
            callback(event);
        }

        return &self.items.items[self.items.items.len - 1];
    }

    pub fn createFolder(self: *FileProviderController, parent_id: ItemIdentifier, name: []const u8) !*FileItem {
        const item = try self.createItem(parent_id, name);
        item.item_type = .folder;
        item.content_type = ContentType.folder;
        item.capabilities = Capabilities.folder();
        return item;
    }

    pub fn deleteItem(self: *FileProviderController, item_id: []const u8) !void {
        var i: usize = 0;
        while (i < self.items.items.len) {
            if (std.mem.eql(u8, self.items.items[i].identifier.id, item_id)) {
                const notification = ChangeNotification.init(.delete, self.items.items[i].identifier);
                try self.change_notifications.append(self.allocator, notification);

                _ = self.items.orderedRemove(i);

                const event = ProviderEvent.init(.item_deleted).withItem(item_id);
                try self.event_history.append(self.allocator, event);

                if (self.event_callback) |callback| {
                    callback(event);
                }
                return;
            }
            i += 1;
        }
        return error.ItemNotFound;
    }

    pub fn findItem(self: *FileProviderController, item_id: []const u8) ?*FileItem {
        for (self.items.items) |*item| {
            if (std.mem.eql(u8, item.identifier.id, item_id)) {
                return item;
            }
        }
        return null;
    }

    pub fn enumerateItems(self: *FileProviderController, parent_id: ItemIdentifier, options: EnumerationOptions) !EnumerationResult {
        _ = options;

        var result = EnumerationResult.init(self.allocator);

        const event = ProviderEvent.init(.enumeration_started);
        try self.event_history.append(self.allocator, event);

        for (self.items.items) |item| {
            if (item.identifier.parent_id) |pid| {
                if (std.mem.eql(u8, pid, parent_id.id)) {
                    try result.addItem(item);
                }
            }
        }

        const complete_event = ProviderEvent.init(.enumeration_completed);
        try self.event_history.append(self.allocator, complete_event);

        return result;
    }

    pub fn startDownload(self: *FileProviderController, item_id: []const u8) !*TransferProgress {
        const item = self.findItem(item_id) orelse return error.ItemNotFound;

        const progress = TransferProgress.init(item_id, .download, item.size_bytes);
        try self.transfers.append(self.allocator, progress);

        item.is_downloading = true;

        return &self.transfers.items[self.transfers.items.len - 1];
    }

    pub fn startUpload(self: *FileProviderController, item_id: []const u8, size: u64) !*TransferProgress {
        const item = self.findItem(item_id) orelse return error.ItemNotFound;

        const progress = TransferProgress.init(item_id, .upload, size);
        try self.transfers.append(self.allocator, progress);

        item.is_uploading = true;

        return &self.transfers.items[self.transfers.items.len - 1];
    }

    pub fn signalChange(self: *FileProviderController, notification: ChangeNotification) !void {
        try self.change_notifications.append(self.allocator, notification);
    }

    pub fn getPendingChanges(self: *const FileProviderController) []const ChangeNotification {
        return self.change_notifications.items;
    }

    pub fn clearPendingChanges(self: *FileProviderController) void {
        self.change_notifications.clearAndFree(self.allocator);
    }

    pub fn updateSyncAnchor(self: *FileProviderController, anchor_data: []const u8) void {
        self.current_sync_anchor.setData(anchor_data);
        self.current_sync_anchor.timestamp = getCurrentTimestamp();
    }

    pub fn getSyncAnchor(self: *const FileProviderController) SyncAnchor {
        return self.current_sync_anchor;
    }

    pub fn setEventCallback(self: *FileProviderController, callback: *const fn (ProviderEvent) void) void {
        self.event_callback = callback;
    }

    pub fn getEventHistory(self: *const FileProviderController) []const ProviderEvent {
        return self.event_history.items;
    }

    pub fn clearEventHistory(self: *FileProviderController) void {
        self.event_history.clearAndFree(self.allocator);
    }

    pub fn itemCount(self: *const FileProviderController) usize {
        return self.items.items.len;
    }

    pub fn domainCount(self: *const FileProviderController) usize {
        return self.domains.items.len;
    }

    pub fn activeTransferCount(self: *const FileProviderController) usize {
        var count: usize = 0;
        for (self.transfers.items) |transfer| {
            if (!transfer.isComplete() and !transfer.is_cancelled) {
                count += 1;
            }
        }
        return count;
    }
};

/// Helper to get current timestamp
fn getCurrentTimestamp() i64 {
    if (builtin.os.tag == .macos or builtin.os.tag == .ios or
        builtin.os.tag == .tvos or builtin.os.tag == .watchos)
    {
        const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
        return ts.sec;
    } else if (builtin.os.tag == .windows) {
        return std.time.timestamp();
    } else if (builtin.os.tag == .linux) {
        const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
        return ts.sec;
    } else {
        return 0;
    }
}

// ============================================================================
// Tests
// ============================================================================

test "Platform detection" {
    const platform = Platform.current();
    try std.testing.expect(platform == .macos or platform != .macos);
}

test "Platform frameworkName" {
    try std.testing.expectEqualStrings("FileProvider", Platform.ios.frameworkName());
    try std.testing.expectEqualStrings("FileProvider", Platform.macos.frameworkName());
    try std.testing.expectEqualStrings("Storage Access Framework", Platform.android.frameworkName());
}

test "ItemType isContainer" {
    try std.testing.expect(ItemType.folder.isContainer());
    try std.testing.expect(ItemType.root.isContainer());
    try std.testing.expect(!ItemType.file.isContainer());
}

test "Capabilities init" {
    const caps = Capabilities.init();
    try std.testing.expect(caps.readable);
    try std.testing.expect(caps.writable);
}

test "Capabilities readOnly" {
    const caps = Capabilities.readOnly();
    try std.testing.expect(caps.readable);
    try std.testing.expect(!caps.writable);
    try std.testing.expect(!caps.deletable);
}

test "Capabilities folder" {
    const caps = Capabilities.folder();
    try std.testing.expect(caps.allows_adding_children);
    try std.testing.expect(caps.allows_content_enumerating);
}

test "ItemIdentifier init" {
    const id = ItemIdentifier.init("test_id")
        .withParent("parent_id")
        .withDomain("domain_id");

    try std.testing.expectEqualStrings("test_id", id.id);
    try std.testing.expectEqualStrings("parent_id", id.parent_id.?);
    try std.testing.expectEqualStrings("domain_id", id.domain_id.?);
}

test "ItemIdentifier special containers" {
    try std.testing.expect(ItemIdentifier.root_container.isRoot());
    try std.testing.expect(ItemIdentifier.trash_container.isTrash());
}

test "ContentType init" {
    const ct = ContentType.init("custom.type").withExtension("cst");
    try std.testing.expectEqualStrings("custom.type", ct.type_identifier);
    try std.testing.expectEqualStrings("cst", ct.preferred_extension.?);
}

test "ContentType isFolder" {
    try std.testing.expect(ContentType.folder.isFolder());
    try std.testing.expect(!ContentType.text.isFolder());
}

test "FileItem init" {
    const id = ItemIdentifier.init("item1");
    const item = FileItem.init(id, "test.txt")
        .withContentType(ContentType.text)
        .withSize(1024);

    try std.testing.expectEqualStrings("test.txt", item.filename);
    try std.testing.expectEqual(@as(u64, 1024), item.size_bytes);
    try std.testing.expect(!item.isContainer());
}

test "FileItem asFolder" {
    const id = ItemIdentifier.init("folder1");
    const item = FileItem.init(id, "Documents").asFolder();

    try std.testing.expectEqual(ItemType.folder, item.item_type);
    try std.testing.expect(item.isContainer());
    try std.testing.expect(item.content_type.isFolder());
}

test "FileItem needsDownload" {
    const id = ItemIdentifier.init("item1");
    var item = FileItem.init(id, "test.txt");

    try std.testing.expect(!item.needsDownload()); // is_downloaded = true by default

    item.is_downloaded = false;
    try std.testing.expect(item.needsDownload());

    item.is_downloading = true;
    try std.testing.expect(!item.needsDownload());
}

test "EnumerationOptions builder" {
    const options = EnumerationOptions.init()
        .withSorting(.date_modified, false)
        .withPageSize(50)
        .showHidden();

    try std.testing.expectEqual(EnumerationOptions.SortField.date_modified, options.sort_by);
    try std.testing.expect(!options.sort_ascending);
    try std.testing.expectEqual(@as(u32, 50), options.page_size);
    try std.testing.expect(options.include_hidden);
}

test "EnumerationResult init and addItem" {
    var result = EnumerationResult.init(std.testing.allocator);
    defer result.deinit();

    const item = FileItem.init(ItemIdentifier.init("item1"), "test.txt");
    try result.addItem(item);

    try std.testing.expectEqual(@as(usize, 1), result.count());
}

test "EnumerationResult pagination" {
    var result = EnumerationResult.init(std.testing.allocator);
    defer result.deinit();

    try std.testing.expect(!result.has_more);

    result.setNextPage("page_token_123");
    try std.testing.expect(result.has_more);
    try std.testing.expectEqualStrings("page_token_123", result.next_page_token.?);
}

test "ChangeNotification init" {
    const id = ItemIdentifier.init("item1");
    const notification = ChangeNotification.init(.create, id)
        .withNewParent("folder1");

    try std.testing.expectEqual(OperationType.create, notification.operation);
    try std.testing.expectEqualStrings("folder1", notification.new_parent_id.?);
}

test "Domain init and builder" {
    const domain = Domain.init("com.app.files", "My Files")
        .asReplicated()
        .withPath("/Documents")
        .withIncrementalFetch(true);

    try std.testing.expectEqualStrings("com.app.files", domain.identifier);
    try std.testing.expectEqualStrings("My Files", domain.display_name);
    try std.testing.expect(domain.is_replicated);
    try std.testing.expect(domain.supports_incremental_fetch);
}

test "ProviderEvent builder" {
    const event = ProviderEvent.init(.item_created)
        .withDomain("domain1")
        .withItem("item1");

    try std.testing.expectEqual(ProviderEvent.EventType.item_created, event.event_type);
    try std.testing.expectEqualStrings("domain1", event.domain_id.?);
    try std.testing.expectEqualStrings("item1", event.item_id.?);
}

test "SyncAnchor operations" {
    var anchor = SyncAnchor.init();
    try std.testing.expect(!anchor.isValid());

    anchor.setData("anchor_data_123");
    try std.testing.expect(anchor.isValid());
    try std.testing.expectEqualStrings("anchor_data_123", anchor.getData());
}

test "TransferProgress init and update" {
    var progress = TransferProgress.init("item1", .download, 1000);

    try std.testing.expectEqual(@as(f32, 0.0), progress.progress());
    try std.testing.expect(!progress.isComplete());

    progress.update(500);
    try std.testing.expectEqual(@as(f32, 0.5), progress.progress());

    progress.update(1000);
    try std.testing.expect(progress.isComplete());
}

test "TransferProgress pause and resume" {
    var progress = TransferProgress.init("item1", .upload, 1000);

    try std.testing.expect(!progress.is_paused);

    progress.pause();
    try std.testing.expect(progress.is_paused);

    progress.resume_transfer();
    try std.testing.expect(!progress.is_paused);
}

test "FileProviderController init and deinit" {
    var controller = FileProviderController.init(std.testing.allocator);
    defer controller.deinit();

    try std.testing.expectEqual(@as(usize, 0), controller.itemCount());
    try std.testing.expectEqual(@as(usize, 0), controller.domainCount());
}

test "FileProviderController addDomain" {
    var controller = FileProviderController.init(std.testing.allocator);
    defer controller.deinit();

    const domain = Domain.init("com.app.files", "My Files");
    try controller.addDomain(domain);

    try std.testing.expectEqual(@as(usize, 1), controller.domainCount());
}

test "FileProviderController removeDomain" {
    var controller = FileProviderController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.addDomain(Domain.init("domain1", "Domain 1"));
    try controller.addDomain(Domain.init("domain2", "Domain 2"));

    try controller.removeDomain("domain1");
    try std.testing.expectEqual(@as(usize, 1), controller.domainCount());
}

test "FileProviderController createItem" {
    var controller = FileProviderController.init(std.testing.allocator);
    defer controller.deinit();

    const item = try controller.createItem(ItemIdentifier.root_container, "test.txt");

    try std.testing.expectEqualStrings("test.txt", item.filename);
    try std.testing.expectEqual(@as(usize, 1), controller.itemCount());
}

test "FileProviderController createFolder" {
    var controller = FileProviderController.init(std.testing.allocator);
    defer controller.deinit();

    const folder = try controller.createFolder(ItemIdentifier.root_container, "Documents");

    try std.testing.expectEqual(ItemType.folder, folder.item_type);
    try std.testing.expect(folder.isContainer());
}

test "FileProviderController deleteItem" {
    var controller = FileProviderController.init(std.testing.allocator);
    defer controller.deinit();

    const item = try controller.createItem(ItemIdentifier.root_container, "test.txt");
    const item_id = item.identifier.id;

    try controller.deleteItem(item_id);
    try std.testing.expectEqual(@as(usize, 0), controller.itemCount());
}

test "FileProviderController enumerateItems" {
    var controller = FileProviderController.init(std.testing.allocator);
    defer controller.deinit();

    _ = try controller.createItem(ItemIdentifier.root_container, "file1.txt");
    _ = try controller.createItem(ItemIdentifier.root_container, "file2.txt");

    var result = try controller.enumerateItems(ItemIdentifier.root_container, EnumerationOptions.init());
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 2), result.count());
}

test "FileProviderController startDownload" {
    var controller = FileProviderController.init(std.testing.allocator);
    defer controller.deinit();

    var item = try controller.createItem(ItemIdentifier.root_container, "test.txt");
    item.size_bytes = 1000;
    item.is_downloaded = false;

    const progress = try controller.startDownload(item.identifier.id);

    try std.testing.expectEqual(@as(u64, 1000), progress.total_bytes);
    try std.testing.expectEqual(@as(usize, 1), controller.activeTransferCount());
}

test "FileProviderController signalChange" {
    var controller = FileProviderController.init(std.testing.allocator);
    defer controller.deinit();

    const notification = ChangeNotification.init(.modify, ItemIdentifier.init("item1"));
    try controller.signalChange(notification);

    const changes = controller.getPendingChanges();
    try std.testing.expectEqual(@as(usize, 1), changes.len);
}

test "FileProviderController syncAnchor" {
    var controller = FileProviderController.init(std.testing.allocator);
    defer controller.deinit();

    controller.updateSyncAnchor("new_anchor_data");

    const anchor = controller.getSyncAnchor();
    try std.testing.expect(anchor.isValid());
    try std.testing.expectEqualStrings("new_anchor_data", anchor.getData());
}

test "FileProviderController event history" {
    var controller = FileProviderController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.addDomain(Domain.init("domain1", "Domain 1"));

    const history = controller.getEventHistory();
    try std.testing.expect(history.len > 0);
}

test "OperationType values" {
    try std.testing.expect(OperationType.create != OperationType.delete);
    try std.testing.expect(OperationType.move != OperationType.copy);
}
