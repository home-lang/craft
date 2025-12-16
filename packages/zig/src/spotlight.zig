//! Spotlight/System Search Indexing
//!
//! Provides cross-platform abstraction for system search integration:
//! - iOS/macOS Spotlight (Core Spotlight)
//! - Android App Search
//! - Windows Search
//!
//! Features:
//! - Searchable item indexing
//! - Content attributes and metadata
//! - Batch indexing operations
//! - Search result handling
//! - Activity-based indexing

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

/// Gets current timestamp in seconds
fn getCurrentTimestamp() i64 {
    const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
    return ts.sec;
}

/// Search platform
pub const SearchPlatform = enum {
    spotlight, // iOS/macOS
    app_search, // Android
    windows_search, // Windows
    unknown,

    pub fn displayName(self: SearchPlatform) []const u8 {
        return switch (self) {
            .spotlight => "Spotlight",
            .app_search => "App Search",
            .windows_search => "Windows Search",
            .unknown => "Unknown",
        };
    }

    pub fn supportsRichContent(self: SearchPlatform) bool {
        return switch (self) {
            .spotlight => true,
            .app_search => true,
            .windows_search => true,
            .unknown => false,
        };
    }
};

/// Content type for searchable items
pub const ContentType = enum {
    generic,
    document,
    image,
    audio,
    video,
    message,
    email,
    contact,
    event,
    location,
    note,
    task,
    file,
    folder,
    webpage,
    app_content,

    pub fn displayName(self: ContentType) []const u8 {
        return switch (self) {
            .generic => "Generic",
            .document => "Document",
            .image => "Image",
            .audio => "Audio",
            .video => "Video",
            .message => "Message",
            .email => "Email",
            .contact => "Contact",
            .event => "Event",
            .location => "Location",
            .note => "Note",
            .task => "Task",
            .file => "File",
            .folder => "Folder",
            .webpage => "Webpage",
            .app_content => "App Content",
        };
    }

    pub fn mimeType(self: ContentType) []const u8 {
        return switch (self) {
            .generic => "application/octet-stream",
            .document => "application/pdf",
            .image => "image/*",
            .audio => "audio/*",
            .video => "video/*",
            .message => "text/plain",
            .email => "message/rfc822",
            .contact => "text/vcard",
            .event => "text/calendar",
            .location => "application/geo+json",
            .note => "text/plain",
            .task => "text/plain",
            .file => "application/octet-stream",
            .folder => "inode/directory",
            .webpage => "text/html",
            .app_content => "application/x-app-content",
        };
    }
};

/// Searchable attribute for items
pub const SearchAttribute = struct {
    /// Attribute key
    key_buffer: [64]u8 = [_]u8{0} ** 64,
    key_len: usize = 0,

    /// Attribute value
    value_buffer: [512]u8 = [_]u8{0} ** 512,
    value_len: usize = 0,

    /// Whether this attribute is searchable
    is_searchable: bool = true,

    /// Weight for ranking (0-10)
    weight: u8 = 5,

    pub fn init(key: []const u8, value: []const u8) SearchAttribute {
        var result = SearchAttribute{};
        const key_len = @min(key.len, result.key_buffer.len);
        @memcpy(result.key_buffer[0..key_len], key[0..key_len]);
        result.key_len = key_len;

        const value_len = @min(value.len, result.value_buffer.len);
        @memcpy(result.value_buffer[0..value_len], value[0..value_len]);
        result.value_len = value_len;
        return result;
    }

    pub fn withSearchable(self: SearchAttribute, searchable: bool) SearchAttribute {
        var result = self;
        result.is_searchable = searchable;
        return result;
    }

    pub fn withWeight(self: SearchAttribute, weight: u8) SearchAttribute {
        var result = self;
        result.weight = @min(weight, 10);
        return result;
    }

    pub fn getKey(self: *const SearchAttribute) []const u8 {
        return self.key_buffer[0..self.key_len];
    }

    pub fn getValue(self: *const SearchAttribute) []const u8 {
        return self.value_buffer[0..self.value_len];
    }
};

/// Thumbnail configuration
pub const Thumbnail = struct {
    /// Image data (base64 or raw bytes reference)
    data_buffer: [8192]u8 = [_]u8{0} ** 8192,
    data_len: usize = 0,

    /// Image URL (alternative to embedded data)
    url_buffer: [512]u8 = [_]u8{0} ** 512,
    url_len: usize = 0,

    /// MIME type
    mime_type_buffer: [64]u8 = [_]u8{0} ** 64,
    mime_type_len: usize = 0,

    /// Width in pixels
    width: u32 = 0,

    /// Height in pixels
    height: u32 = 0,

    pub fn fromUrl(url: []const u8) Thumbnail {
        var result = Thumbnail{};
        const copy_len = @min(url.len, result.url_buffer.len);
        @memcpy(result.url_buffer[0..copy_len], url[0..copy_len]);
        result.url_len = copy_len;
        return result;
    }

    pub fn fromData(data: []const u8, mime_type: []const u8) Thumbnail {
        var result = Thumbnail{};
        const data_len = @min(data.len, result.data_buffer.len);
        @memcpy(result.data_buffer[0..data_len], data[0..data_len]);
        result.data_len = data_len;

        const mime_len = @min(mime_type.len, result.mime_type_buffer.len);
        @memcpy(result.mime_type_buffer[0..mime_len], mime_type[0..mime_len]);
        result.mime_type_len = mime_len;
        return result;
    }

    pub fn withDimensions(self: Thumbnail, width: u32, height: u32) Thumbnail {
        var result = self;
        result.width = width;
        result.height = height;
        return result;
    }

    pub fn getUrl(self: *const Thumbnail) []const u8 {
        return self.url_buffer[0..self.url_len];
    }

    pub fn hasData(self: *const Thumbnail) bool {
        return self.data_len > 0 or self.url_len > 0;
    }
};

/// Searchable item to index
pub const SearchableItem = struct {
    /// Unique identifier for the item
    id_buffer: [128]u8 = [_]u8{0} ** 128,
    id_len: usize = 0,

    /// Domain identifier (for grouping)
    domain_buffer: [64]u8 = [_]u8{0} ** 64,
    domain_len: usize = 0,

    /// Title (main searchable text)
    title_buffer: [256]u8 = [_]u8{0} ** 256,
    title_len: usize = 0,

    /// Description/subtitle
    description_buffer: [1024]u8 = [_]u8{0} ** 1024,
    description_len: usize = 0,

    /// Full content for search (optional)
    content_buffer: [4096]u8 = [_]u8{0} ** 4096,
    content_len: usize = 0,

    /// Content type
    content_type: ContentType = .generic,

    /// Keywords for search
    keywords: [16][64]u8 = [_][64]u8{[_]u8{0} ** 64} ** 16,
    keyword_lens: [16]usize = [_]usize{0} ** 16,
    keyword_count: usize = 0,

    /// Custom attributes
    attributes: [8]SearchAttribute = [_]SearchAttribute{SearchAttribute{}} ** 8,
    attribute_count: usize = 0,

    /// Thumbnail
    thumbnail: ?Thumbnail = null,

    /// Deep link URL
    url_buffer: [512]u8 = [_]u8{0} ** 512,
    url_len: usize = 0,

    /// Expiration date (0 = never expires)
    expiration_date: i64 = 0,

    /// Last modified date
    last_modified: i64 = 0,

    /// Creation date
    created_at: i64 = 0,

    /// Rating (0-5 stars)
    rating: ?f32 = null,

    /// Whether item should be displayed prominently
    is_featured: bool = false,

    pub fn init(id: []const u8) SearchableItem {
        var result = SearchableItem{
            .created_at = getCurrentTimestamp(),
            .last_modified = getCurrentTimestamp(),
        };
        const copy_len = @min(id.len, result.id_buffer.len);
        @memcpy(result.id_buffer[0..copy_len], id[0..copy_len]);
        result.id_len = copy_len;
        return result;
    }

    pub fn withDomain(self: SearchableItem, domain: []const u8) SearchableItem {
        var result = self;
        const copy_len = @min(domain.len, result.domain_buffer.len);
        @memcpy(result.domain_buffer[0..copy_len], domain[0..copy_len]);
        result.domain_len = copy_len;
        return result;
    }

    pub fn withTitle(self: SearchableItem, title: []const u8) SearchableItem {
        var result = self;
        const copy_len = @min(title.len, result.title_buffer.len);
        @memcpy(result.title_buffer[0..copy_len], title[0..copy_len]);
        result.title_len = copy_len;
        return result;
    }

    pub fn withDescription(self: SearchableItem, description: []const u8) SearchableItem {
        var result = self;
        const copy_len = @min(description.len, result.description_buffer.len);
        @memcpy(result.description_buffer[0..copy_len], description[0..copy_len]);
        result.description_len = copy_len;
        return result;
    }

    pub fn withContent(self: SearchableItem, content: []const u8) SearchableItem {
        var result = self;
        const copy_len = @min(content.len, result.content_buffer.len);
        @memcpy(result.content_buffer[0..copy_len], content[0..copy_len]);
        result.content_len = copy_len;
        return result;
    }

    pub fn withContentType(self: SearchableItem, content_type: ContentType) SearchableItem {
        var result = self;
        result.content_type = content_type;
        return result;
    }

    pub fn addKeyword(self: SearchableItem, keyword: []const u8) SearchableItem {
        var result = self;
        if (result.keyword_count < 16) {
            const copy_len = @min(keyword.len, 64);
            @memcpy(result.keywords[result.keyword_count][0..copy_len], keyword[0..copy_len]);
            result.keyword_lens[result.keyword_count] = copy_len;
            result.keyword_count += 1;
        }
        return result;
    }

    pub fn addAttribute(self: SearchableItem, attr: SearchAttribute) SearchableItem {
        var result = self;
        if (result.attribute_count < 8) {
            result.attributes[result.attribute_count] = attr;
            result.attribute_count += 1;
        }
        return result;
    }

    pub fn withThumbnail(self: SearchableItem, thumb: Thumbnail) SearchableItem {
        var result = self;
        result.thumbnail = thumb;
        return result;
    }

    pub fn withUrl(self: SearchableItem, url: []const u8) SearchableItem {
        var result = self;
        const copy_len = @min(url.len, result.url_buffer.len);
        @memcpy(result.url_buffer[0..copy_len], url[0..copy_len]);
        result.url_len = copy_len;
        return result;
    }

    pub fn withExpiration(self: SearchableItem, expiration_timestamp: i64) SearchableItem {
        var result = self;
        result.expiration_date = expiration_timestamp;
        return result;
    }

    pub fn withExpirationDays(self: SearchableItem, days: u32) SearchableItem {
        var result = self;
        result.expiration_date = getCurrentTimestamp() + @as(i64, @intCast(days)) * 86400;
        return result;
    }

    pub fn withRating(self: SearchableItem, rating: f32) SearchableItem {
        var result = self;
        result.rating = @min(rating, 5.0);
        return result;
    }

    pub fn withFeatured(self: SearchableItem, featured: bool) SearchableItem {
        var result = self;
        result.is_featured = featured;
        return result;
    }

    pub fn updateModified(self: *SearchableItem) void {
        self.last_modified = getCurrentTimestamp();
    }

    pub fn getId(self: *const SearchableItem) []const u8 {
        return self.id_buffer[0..self.id_len];
    }

    pub fn getDomain(self: *const SearchableItem) []const u8 {
        return self.domain_buffer[0..self.domain_len];
    }

    pub fn getTitle(self: *const SearchableItem) []const u8 {
        return self.title_buffer[0..self.title_len];
    }

    pub fn getDescription(self: *const SearchableItem) []const u8 {
        return self.description_buffer[0..self.description_len];
    }

    pub fn getContent(self: *const SearchableItem) []const u8 {
        return self.content_buffer[0..self.content_len];
    }

    pub fn getUrl(self: *const SearchableItem) []const u8 {
        return self.url_buffer[0..self.url_len];
    }

    pub fn getKeyword(self: *const SearchableItem, index: usize) ?[]const u8 {
        if (index < self.keyword_count) {
            return self.keywords[index][0..self.keyword_lens[index]];
        }
        return null;
    }

    pub fn getAttribute(self: *const SearchableItem, index: usize) ?*const SearchAttribute {
        if (index < self.attribute_count) {
            return &self.attributes[index];
        }
        return null;
    }

    pub fn isExpired(self: *const SearchableItem) bool {
        if (self.expiration_date == 0) return false;
        return getCurrentTimestamp() > self.expiration_date;
    }
};

/// Search result from system search
pub const SearchResult = struct {
    /// Item ID that was found
    item_id_buffer: [128]u8 = [_]u8{0} ** 128,
    item_id_len: usize = 0,

    /// Relevance score (0-1)
    relevance: f32 = 0,

    /// Highlighted title snippet
    title_snippet_buffer: [256]u8 = [_]u8{0} ** 256,
    title_snippet_len: usize = 0,

    /// Highlighted content snippet
    content_snippet_buffer: [512]u8 = [_]u8{0} ** 512,
    content_snippet_len: usize = 0,

    /// Content type
    content_type: ContentType = .generic,

    /// Deep link URL
    url_buffer: [512]u8 = [_]u8{0} ** 512,
    url_len: usize = 0,

    pub fn init(item_id: []const u8, relevance: f32) SearchResult {
        var result = SearchResult{
            .relevance = relevance,
        };
        const copy_len = @min(item_id.len, result.item_id_buffer.len);
        @memcpy(result.item_id_buffer[0..copy_len], item_id[0..copy_len]);
        result.item_id_len = copy_len;
        return result;
    }

    pub fn withTitleSnippet(self: SearchResult, snippet: []const u8) SearchResult {
        var result = self;
        const copy_len = @min(snippet.len, result.title_snippet_buffer.len);
        @memcpy(result.title_snippet_buffer[0..copy_len], snippet[0..copy_len]);
        result.title_snippet_len = copy_len;
        return result;
    }

    pub fn withContentSnippet(self: SearchResult, snippet: []const u8) SearchResult {
        var result = self;
        const copy_len = @min(snippet.len, result.content_snippet_buffer.len);
        @memcpy(result.content_snippet_buffer[0..copy_len], snippet[0..copy_len]);
        result.content_snippet_len = copy_len;
        return result;
    }

    pub fn withContentType(self: SearchResult, content_type: ContentType) SearchResult {
        var result = self;
        result.content_type = content_type;
        return result;
    }

    pub fn withUrl(self: SearchResult, url: []const u8) SearchResult {
        var result = self;
        const copy_len = @min(url.len, result.url_buffer.len);
        @memcpy(result.url_buffer[0..copy_len], url[0..copy_len]);
        result.url_len = copy_len;
        return result;
    }

    pub fn getItemId(self: *const SearchResult) []const u8 {
        return self.item_id_buffer[0..self.item_id_len];
    }

    pub fn getTitleSnippet(self: *const SearchResult) []const u8 {
        return self.title_snippet_buffer[0..self.title_snippet_len];
    }

    pub fn getContentSnippet(self: *const SearchResult) []const u8 {
        return self.content_snippet_buffer[0..self.content_snippet_len];
    }

    pub fn getUrl(self: *const SearchResult) []const u8 {
        return self.url_buffer[0..self.url_len];
    }
};

/// Search query configuration
pub const SearchQuery = struct {
    /// Query string
    query_buffer: [256]u8 = [_]u8{0} ** 256,
    query_len: usize = 0,

    /// Filter by domain
    domain_filter_buffer: [64]u8 = [_]u8{0} ** 64,
    domain_filter_len: usize = 0,

    /// Filter by content type
    content_type_filter: ?ContentType = null,

    /// Maximum results
    max_results: u32 = 20,

    /// Minimum relevance score
    min_relevance: f32 = 0,

    /// Sort order
    sort_by: SortOrder = .relevance,

    pub const SortOrder = enum {
        relevance,
        date_newest,
        date_oldest,
        title_asc,
        title_desc,
    };

    pub fn init(query: []const u8) SearchQuery {
        var result = SearchQuery{};
        const copy_len = @min(query.len, result.query_buffer.len);
        @memcpy(result.query_buffer[0..copy_len], query[0..copy_len]);
        result.query_len = copy_len;
        return result;
    }

    pub fn withDomainFilter(self: SearchQuery, domain: []const u8) SearchQuery {
        var result = self;
        const copy_len = @min(domain.len, result.domain_filter_buffer.len);
        @memcpy(result.domain_filter_buffer[0..copy_len], domain[0..copy_len]);
        result.domain_filter_len = copy_len;
        return result;
    }

    pub fn withContentTypeFilter(self: SearchQuery, content_type: ContentType) SearchQuery {
        var result = self;
        result.content_type_filter = content_type;
        return result;
    }

    pub fn withMaxResults(self: SearchQuery, max: u32) SearchQuery {
        var result = self;
        result.max_results = max;
        return result;
    }

    pub fn withMinRelevance(self: SearchQuery, min: f32) SearchQuery {
        var result = self;
        result.min_relevance = min;
        return result;
    }

    pub fn withSortOrder(self: SearchQuery, order: SortOrder) SearchQuery {
        var result = self;
        result.sort_by = order;
        return result;
    }

    pub fn getQuery(self: *const SearchQuery) []const u8 {
        return self.query_buffer[0..self.query_len];
    }

    pub fn getDomainFilter(self: *const SearchQuery) []const u8 {
        return self.domain_filter_buffer[0..self.domain_filter_len];
    }
};

/// Indexing operation status
pub const IndexingStatus = enum {
    pending,
    in_progress,
    completed,
    failed,

    pub fn displayName(self: IndexingStatus) []const u8 {
        return switch (self) {
            .pending => "Pending",
            .in_progress => "In Progress",
            .completed => "Completed",
            .failed => "Failed",
        };
    }
};

/// Batch operation result
pub const BatchResult = struct {
    /// Number of items successfully indexed
    success_count: u32 = 0,

    /// Number of items that failed
    failure_count: u32 = 0,

    /// Operation status
    status: IndexingStatus = .pending,

    /// Error message if failed
    error_message_buffer: [256]u8 = [_]u8{0} ** 256,
    error_message_len: usize = 0,

    /// Time taken in milliseconds
    duration_ms: u64 = 0,

    pub fn success(count: u32, duration_ms: u64) BatchResult {
        return .{
            .success_count = count,
            .failure_count = 0,
            .status = .completed,
            .duration_ms = duration_ms,
        };
    }

    pub fn partial(success_count: u32, failure_count: u32, duration_ms: u64) BatchResult {
        return .{
            .success_count = success_count,
            .failure_count = failure_count,
            .status = .completed,
            .duration_ms = duration_ms,
        };
    }

    pub fn failure(error_msg: []const u8) BatchResult {
        var result = BatchResult{
            .status = .failed,
        };
        const copy_len = @min(error_msg.len, result.error_message_buffer.len);
        @memcpy(result.error_message_buffer[0..copy_len], error_msg[0..copy_len]);
        result.error_message_len = copy_len;
        return result;
    }

    pub fn getErrorMessage(self: *const BatchResult) []const u8 {
        return self.error_message_buffer[0..self.error_message_len];
    }

    pub fn getTotalCount(self: *const BatchResult) u32 {
        return self.success_count + self.failure_count;
    }

    pub fn getSuccessRate(self: *const BatchResult) f32 {
        const total = self.getTotalCount();
        if (total == 0) return 0;
        return @as(f32, @floatFromInt(self.success_count)) / @as(f32, @floatFromInt(total));
    }
};

/// Index statistics
pub const IndexStats = struct {
    /// Total items in index
    total_items: u32 = 0,

    /// Items by content type
    document_count: u32 = 0,
    image_count: u32 = 0,
    audio_count: u32 = 0,
    video_count: u32 = 0,
    other_count: u32 = 0,

    /// Index size in bytes (estimated)
    size_bytes: u64 = 0,

    /// Last update timestamp
    last_updated: i64 = 0,

    /// Number of domains
    domain_count: u32 = 0,

    pub fn init() IndexStats {
        return .{
            .last_updated = getCurrentTimestamp(),
        };
    }

    pub fn incrementForType(self: *IndexStats, content_type: ContentType) void {
        self.total_items += 1;
        switch (content_type) {
            .document => self.document_count += 1,
            .image => self.image_count += 1,
            .audio => self.audio_count += 1,
            .video => self.video_count += 1,
            else => self.other_count += 1,
        }
        self.last_updated = getCurrentTimestamp();
    }

    pub fn decrementForType(self: *IndexStats, content_type: ContentType) void {
        if (self.total_items > 0) self.total_items -= 1;
        switch (content_type) {
            .document => if (self.document_count > 0) {
                self.document_count -= 1;
            },
            .image => if (self.image_count > 0) {
                self.image_count -= 1;
            },
            .audio => if (self.audio_count > 0) {
                self.audio_count -= 1;
            },
            .video => if (self.video_count > 0) {
                self.video_count -= 1;
            },
            else => if (self.other_count > 0) {
                self.other_count -= 1;
            },
        }
        self.last_updated = getCurrentTimestamp();
    }
};

/// Spotlight/Search index controller
pub const SearchIndexController = struct {
    allocator: Allocator,
    platform: SearchPlatform,
    indexed_items: std.ArrayListUnmanaged(SearchableItem),
    stats: IndexStats,
    is_enabled: bool,

    pub fn init(allocator: Allocator) SearchIndexController {
        const platform = detectPlatform();
        return .{
            .allocator = allocator,
            .platform = platform,
            .indexed_items = .empty,
            .stats = IndexStats.init(),
            .is_enabled = true,
        };
    }

    pub fn deinit(self: *SearchIndexController) void {
        self.indexed_items.deinit(self.allocator);
    }

    fn detectPlatform() SearchPlatform {
        return switch (builtin.os.tag) {
            .ios, .macos => .spotlight,
            .linux => if (builtin.abi == .android) .app_search else .unknown,
            .windows => .windows_search,
            else => .unknown,
        };
    }

    pub fn indexItem(self: *SearchIndexController, item: SearchableItem) !void {
        if (!self.is_enabled) return error.IndexingDisabled;

        // Check if item already exists and update it
        for (self.indexed_items.items, 0..) |existing, i| {
            if (std.mem.eql(u8, existing.id_buffer[0..existing.id_len], item.id_buffer[0..item.id_len])) {
                // Update existing item
                self.stats.decrementForType(existing.content_type);
                self.indexed_items.items[i] = item;
                self.stats.incrementForType(item.content_type);
                return;
            }
        }

        // Add new item
        try self.indexed_items.append(self.allocator, item);
        self.stats.incrementForType(item.content_type);
    }

    pub fn removeItem(self: *SearchIndexController, item_id: []const u8) bool {
        for (self.indexed_items.items, 0..) |item, i| {
            if (std.mem.eql(u8, item.id_buffer[0..item.id_len], item_id)) {
                self.stats.decrementForType(item.content_type);
                _ = self.indexed_items.orderedRemove(i);
                return true;
            }
        }
        return false;
    }

    pub fn removeItemsInDomain(self: *SearchIndexController, domain: []const u8) u32 {
        var removed: u32 = 0;
        var i: usize = 0;
        while (i < self.indexed_items.items.len) {
            const item = &self.indexed_items.items[i];
            if (std.mem.eql(u8, item.domain_buffer[0..item.domain_len], domain)) {
                self.stats.decrementForType(item.content_type);
                _ = self.indexed_items.orderedRemove(i);
                removed += 1;
            } else {
                i += 1;
            }
        }
        return removed;
    }

    pub fn clearIndex(self: *SearchIndexController) void {
        self.indexed_items.clearRetainingCapacity();
        self.stats = IndexStats.init();
    }

    pub fn getItem(self: *SearchIndexController, item_id: []const u8) ?*const SearchableItem {
        for (self.indexed_items.items) |*item| {
            if (std.mem.eql(u8, item.id_buffer[0..item.id_len], item_id)) {
                return item;
            }
        }
        return null;
    }

    pub fn search(self: *SearchIndexController, query: SearchQuery) std.ArrayListUnmanaged(SearchResult) {
        var results: std.ArrayListUnmanaged(SearchResult) = .empty;

        if (!self.is_enabled) return results;

        const query_str = query.getQuery();
        const query_lower = blk: {
            var buf: [256]u8 = undefined;
            const len = @min(query_str.len, buf.len);
            for (0..len) |i| {
                buf[i] = std.ascii.toLower(query_str[i]);
            }
            break :blk buf[0..len];
        };

        for (self.indexed_items.items) |*item| {
            // Apply domain filter
            if (query.domain_filter_len > 0) {
                if (!std.mem.eql(u8, item.domain_buffer[0..item.domain_len], query.getDomainFilter())) {
                    continue;
                }
            }

            // Apply content type filter
            if (query.content_type_filter) |ct| {
                if (item.content_type != ct) continue;
            }

            // Calculate relevance
            var relevance: f32 = 0;

            // Check title match
            const title = item.getTitle();
            if (containsIgnoreCase(title, query_lower)) {
                relevance += 0.5;
            }

            // Check description match
            const desc = item.getDescription();
            if (containsIgnoreCase(desc, query_lower)) {
                relevance += 0.3;
            }

            // Check keywords
            for (0..item.keyword_count) |ki| {
                if (item.getKeyword(ki)) |kw| {
                    if (containsIgnoreCase(kw, query_lower)) {
                        relevance += 0.1;
                        break;
                    }
                }
            }

            // Check content
            const content = item.getContent();
            if (containsIgnoreCase(content, query_lower)) {
                relevance += 0.1;
            }

            // Apply minimum relevance filter
            if (relevance >= query.min_relevance and relevance > 0) {
                const result = SearchResult.init(item.getId(), relevance)
                    .withTitleSnippet(title)
                    .withContentType(item.content_type)
                    .withUrl(item.getUrl());

                results.append(self.allocator, result) catch continue;

                if (results.items.len >= query.max_results) break;
            }
        }

        return results;
    }

    fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
        if (needle.len == 0) return true;
        if (haystack.len < needle.len) return false;

        var i: usize = 0;
        while (i <= haystack.len - needle.len) : (i += 1) {
            var match = true;
            for (0..needle.len) |j| {
                if (std.ascii.toLower(haystack[i + j]) != needle[j]) {
                    match = false;
                    break;
                }
            }
            if (match) return true;
        }
        return false;
    }

    pub fn setEnabled(self: *SearchIndexController, enabled: bool) void {
        self.is_enabled = enabled;
    }

    pub fn getStats(self: *SearchIndexController) IndexStats {
        return self.stats;
    }

    pub fn getItemCount(self: *SearchIndexController) usize {
        return self.indexed_items.items.len;
    }

    pub fn removeExpiredItems(self: *SearchIndexController) u32 {
        var removed: u32 = 0;
        var i: usize = 0;
        while (i < self.indexed_items.items.len) {
            const item = &self.indexed_items.items[i];
            if (item.isExpired()) {
                self.stats.decrementForType(item.content_type);
                _ = self.indexed_items.orderedRemove(i);
                removed += 1;
            } else {
                i += 1;
            }
        }
        return removed;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "SearchPlatform display names and features" {
    try std.testing.expectEqualStrings("Spotlight", SearchPlatform.spotlight.displayName());
    try std.testing.expectEqualStrings("App Search", SearchPlatform.app_search.displayName());
    try std.testing.expect(SearchPlatform.spotlight.supportsRichContent());
}

test "ContentType display names and MIME types" {
    try std.testing.expectEqualStrings("Document", ContentType.document.displayName());
    try std.testing.expectEqualStrings("application/pdf", ContentType.document.mimeType());
    try std.testing.expectEqualStrings("image/*", ContentType.image.mimeType());
}

test "SearchAttribute initialization and fluent API" {
    const attr = SearchAttribute.init("author", "John Doe")
        .withSearchable(true)
        .withWeight(8);

    try std.testing.expectEqualStrings("author", attr.getKey());
    try std.testing.expectEqualStrings("John Doe", attr.getValue());
    try std.testing.expect(attr.is_searchable);
    try std.testing.expect(attr.weight == 8);
}

test "SearchAttribute weight clamping" {
    const attr = SearchAttribute.init("test", "value")
        .withWeight(15); // Should be clamped to 10

    try std.testing.expect(attr.weight == 10);
}

test "Thumbnail from URL" {
    const thumb = Thumbnail.fromUrl("https://example.com/image.png")
        .withDimensions(100, 100);

    try std.testing.expectEqualStrings("https://example.com/image.png", thumb.getUrl());
    try std.testing.expect(thumb.width == 100);
    try std.testing.expect(thumb.height == 100);
    try std.testing.expect(thumb.hasData());
}

test "Thumbnail from data" {
    const thumb = Thumbnail.fromData("fake-image-data", "image/png");

    try std.testing.expect(thumb.data_len > 0);
    try std.testing.expect(thumb.hasData());
}

test "SearchableItem initialization and fluent API" {
    const item = SearchableItem.init("doc-001")
        .withDomain("documents")
        .withTitle("Important Document")
        .withDescription("This is a very important document")
        .withContent("Full document content here...")
        .withContentType(.document)
        .addKeyword("important")
        .addKeyword("report")
        .withUrl("myapp://documents/doc-001")
        .withRating(4.5)
        .withFeatured(true);

    try std.testing.expectEqualStrings("doc-001", item.getId());
    try std.testing.expectEqualStrings("documents", item.getDomain());
    try std.testing.expectEqualStrings("Important Document", item.getTitle());
    try std.testing.expect(item.content_type == .document);
    try std.testing.expect(item.keyword_count == 2);
    try std.testing.expectEqualStrings("important", item.getKeyword(0).?);
    try std.testing.expect(item.rating.? == 4.5);
    try std.testing.expect(item.is_featured);
}

test "SearchableItem attributes" {
    const item = SearchableItem.init("item-001")
        .addAttribute(SearchAttribute.init("author", "Jane"))
        .addAttribute(SearchAttribute.init("category", "Tech"));

    try std.testing.expect(item.attribute_count == 2);
    try std.testing.expectEqualStrings("author", item.getAttribute(0).?.getKey());
    try std.testing.expectEqualStrings("Jane", item.getAttribute(0).?.getValue());
}

test "SearchableItem expiration" {
    var item = SearchableItem.init("item-001");

    // No expiration by default
    try std.testing.expect(!item.isExpired());

    // Set expiration in the past
    item.expiration_date = getCurrentTimestamp() - 1;
    try std.testing.expect(item.isExpired());
}

test "SearchableItem thumbnail" {
    const item = SearchableItem.init("item-001")
        .withThumbnail(Thumbnail.fromUrl("https://example.com/thumb.png"));

    try std.testing.expect(item.thumbnail != null);
    try std.testing.expectEqualStrings("https://example.com/thumb.png", item.thumbnail.?.getUrl());
}

test "SearchResult initialization and fluent API" {
    const result = SearchResult.init("item-001", 0.85)
        .withTitleSnippet("Important **Document**")
        .withContentSnippet("...contains the **important** information...")
        .withContentType(.document)
        .withUrl("myapp://view/item-001");

    try std.testing.expectEqualStrings("item-001", result.getItemId());
    try std.testing.expect(result.relevance == 0.85);
    try std.testing.expectEqualStrings("Important **Document**", result.getTitleSnippet());
    try std.testing.expect(result.content_type == .document);
}

test "SearchQuery initialization and fluent API" {
    const query = SearchQuery.init("important document")
        .withDomainFilter("documents")
        .withContentTypeFilter(.document)
        .withMaxResults(10)
        .withMinRelevance(0.5)
        .withSortOrder(.date_newest);

    try std.testing.expectEqualStrings("important document", query.getQuery());
    try std.testing.expectEqualStrings("documents", query.getDomainFilter());
    try std.testing.expect(query.content_type_filter.? == .document);
    try std.testing.expect(query.max_results == 10);
    try std.testing.expect(query.min_relevance == 0.5);
    try std.testing.expect(query.sort_by == .date_newest);
}

test "BatchResult success" {
    const result = BatchResult.success(100, 500);

    try std.testing.expect(result.success_count == 100);
    try std.testing.expect(result.status == .completed);
    try std.testing.expect(result.duration_ms == 500);
    try std.testing.expect(result.getSuccessRate() == 1.0);
}

test "BatchResult partial" {
    const result = BatchResult.partial(80, 20, 600);

    try std.testing.expect(result.success_count == 80);
    try std.testing.expect(result.failure_count == 20);
    try std.testing.expect(result.getTotalCount() == 100);
    try std.testing.expect(result.getSuccessRate() == 0.8);
}

test "BatchResult failure" {
    const result = BatchResult.failure("Index full");

    try std.testing.expect(result.status == .failed);
    try std.testing.expectEqualStrings("Index full", result.getErrorMessage());
}

test "IndexStats initialization" {
    var stats = IndexStats.init();

    try std.testing.expect(stats.total_items == 0);
    try std.testing.expect(stats.last_updated > 0);
}

test "IndexStats increment and decrement" {
    var stats = IndexStats.init();

    stats.incrementForType(.document);
    stats.incrementForType(.document);
    stats.incrementForType(.image);

    try std.testing.expect(stats.total_items == 3);
    try std.testing.expect(stats.document_count == 2);
    try std.testing.expect(stats.image_count == 1);

    stats.decrementForType(.document);
    try std.testing.expect(stats.total_items == 2);
    try std.testing.expect(stats.document_count == 1);
}

test "SearchIndexController initialization" {
    var controller = SearchIndexController.init(std.testing.allocator);
    defer controller.deinit();

    try std.testing.expect(controller.is_enabled);
    try std.testing.expect(controller.getItemCount() == 0);
}

test "SearchIndexController indexing" {
    var controller = SearchIndexController.init(std.testing.allocator);
    defer controller.deinit();

    const item = SearchableItem.init("doc-001")
        .withTitle("Test Document")
        .withContentType(.document);

    try controller.indexItem(item);
    try std.testing.expect(controller.getItemCount() == 1);

    const stats = controller.getStats();
    try std.testing.expect(stats.total_items == 1);
    try std.testing.expect(stats.document_count == 1);
}

test "SearchIndexController item retrieval" {
    var controller = SearchIndexController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.indexItem(SearchableItem.init("item-001").withTitle("First"));
    try controller.indexItem(SearchableItem.init("item-002").withTitle("Second"));

    const found = controller.getItem("item-001");
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("First", found.?.getTitle());

    const not_found = controller.getItem("item-999");
    try std.testing.expect(not_found == null);
}

test "SearchIndexController item removal" {
    var controller = SearchIndexController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.indexItem(SearchableItem.init("item-001").withContentType(.document));
    try controller.indexItem(SearchableItem.init("item-002").withContentType(.image));

    try std.testing.expect(controller.getItemCount() == 2);

    try std.testing.expect(controller.removeItem("item-001"));
    try std.testing.expect(controller.getItemCount() == 1);

    const stats = controller.getStats();
    try std.testing.expect(stats.document_count == 0);
    try std.testing.expect(stats.image_count == 1);
}

test "SearchIndexController domain removal" {
    var controller = SearchIndexController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.indexItem(SearchableItem.init("doc-001").withDomain("documents"));
    try controller.indexItem(SearchableItem.init("doc-002").withDomain("documents"));
    try controller.indexItem(SearchableItem.init("img-001").withDomain("images"));

    const removed = controller.removeItemsInDomain("documents");
    try std.testing.expect(removed == 2);
    try std.testing.expect(controller.getItemCount() == 1);
}

test "SearchIndexController clear" {
    var controller = SearchIndexController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.indexItem(SearchableItem.init("item-001"));
    try controller.indexItem(SearchableItem.init("item-002"));

    controller.clearIndex();
    try std.testing.expect(controller.getItemCount() == 0);
}

test "SearchIndexController search" {
    var controller = SearchIndexController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.indexItem(SearchableItem.init("doc-001")
        .withTitle("Important Report")
        .withDescription("Annual financial report")
        .withContentType(.document));

    try controller.indexItem(SearchableItem.init("doc-002")
        .withTitle("Meeting Notes")
        .withDescription("Notes from the meeting")
        .withContentType(.document));

    var results = controller.search(SearchQuery.init("report"));
    defer results.deinit(std.testing.allocator);

    try std.testing.expect(results.items.len == 1);
    try std.testing.expectEqualStrings("doc-001", results.items[0].getItemId());
}

test "SearchIndexController search with filters" {
    var controller = SearchIndexController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.indexItem(SearchableItem.init("doc-001")
        .withTitle("Report")
        .withDomain("work")
        .withContentType(.document));

    try controller.indexItem(SearchableItem.init("doc-002")
        .withTitle("Report")
        .withDomain("personal")
        .withContentType(.document));

    var results = controller.search(SearchQuery.init("report").withDomainFilter("work"));
    defer results.deinit(std.testing.allocator);

    try std.testing.expect(results.items.len == 1);
    try std.testing.expectEqualStrings("doc-001", results.items[0].getItemId());
}

test "SearchIndexController disabled" {
    var controller = SearchIndexController.init(std.testing.allocator);
    defer controller.deinit();

    controller.setEnabled(false);

    const result = controller.indexItem(SearchableItem.init("item-001"));
    try std.testing.expectError(error.IndexingDisabled, result);
}

test "SearchIndexController update existing item" {
    var controller = SearchIndexController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.indexItem(SearchableItem.init("item-001")
        .withTitle("Original Title")
        .withContentType(.document));

    try controller.indexItem(SearchableItem.init("item-001")
        .withTitle("Updated Title")
        .withContentType(.image));

    try std.testing.expect(controller.getItemCount() == 1);

    const item = controller.getItem("item-001");
    try std.testing.expectEqualStrings("Updated Title", item.?.getTitle());

    const stats = controller.getStats();
    try std.testing.expect(stats.document_count == 0);
    try std.testing.expect(stats.image_count == 1);
}

test "SearchableItem null keyword access" {
    const item = SearchableItem.init("item-001");

    try std.testing.expect(item.getKeyword(0) == null);
    try std.testing.expect(item.getAttribute(0) == null);
}

test "SearchableItem rating clamping" {
    const item = SearchableItem.init("item-001")
        .withRating(10.0); // Should be clamped to 5.0

    try std.testing.expect(item.rating.? == 5.0);
}

test "IndexingStatus display names" {
    try std.testing.expectEqualStrings("Pending", IndexingStatus.pending.displayName());
    try std.testing.expectEqualStrings("Completed", IndexingStatus.completed.displayName());
}
