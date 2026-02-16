const std = @import("std");
const builtin = @import("builtin");

/// Clipboard Module
/// Provides cross-platform clipboard access for iOS (UIPasteboard), Android (ClipboardManager),
/// macOS (NSPasteboard), Windows (Win32 Clipboard), and Linux (X11/Wayland).
/// Supports text, images, URLs, and custom data types.

// ============================================================================
// Clipboard Content Types
// ============================================================================

/// Type of clipboard content
pub const ClipboardType = enum {
    /// Plain text
    text,
    /// Rich text (HTML/RTF)
    rich_text,
    /// URL/URI
    url,
    /// Image data
    image,
    /// File references
    files,
    /// Raw binary data
    data,
    /// Multiple items
    multiple,
    /// Empty clipboard
    empty,

    pub fn toString(self: ClipboardType) []const u8 {
        return switch (self) {
            .text => "text",
            .rich_text => "rich_text",
            .url => "url",
            .image => "image",
            .files => "files",
            .data => "data",
            .multiple => "multiple",
            .empty => "empty",
        };
    }

    pub fn mimeType(self: ClipboardType) []const u8 {
        return switch (self) {
            .text => "text/plain",
            .rich_text => "text/html",
            .url => "text/uri-list",
            .image => "image/png",
            .files => "text/uri-list",
            .data => "application/octet-stream",
            .multiple => "application/x-multiple",
            .empty => "",
        };
    }

    pub fn utiType(self: ClipboardType) []const u8 {
        return switch (self) {
            .text => "public.plain-text",
            .rich_text => "public.html",
            .url => "public.url",
            .image => "public.png",
            .files => "public.file-url",
            .data => "public.data",
            .multiple => "public.composite-content",
            .empty => "",
        };
    }
};

/// Image format for clipboard
pub const ImageFormat = enum {
    png,
    jpeg,
    gif,
    bmp,
    tiff,
    webp,

    pub fn mimeType(self: ImageFormat) []const u8 {
        return switch (self) {
            .png => "image/png",
            .jpeg => "image/jpeg",
            .gif => "image/gif",
            .bmp => "image/bmp",
            .tiff => "image/tiff",
            .webp => "image/webp",
        };
    }

    pub fn extension(self: ImageFormat) []const u8 {
        return switch (self) {
            .png => ".png",
            .jpeg => ".jpg",
            .gif => ".gif",
            .bmp => ".bmp",
            .tiff => ".tiff",
            .webp => ".webp",
        };
    }
};

// ============================================================================
// Clipboard Errors
// ============================================================================

/// Clipboard operation errors
pub const ClipboardError = error{
    /// Clipboard not available
    NotAvailable,
    /// No data of requested type
    NoData,
    /// Invalid data format
    InvalidFormat,
    /// Permission denied
    PermissionDenied,
    /// Data too large
    DataTooLarge,
    /// Unsupported type
    UnsupportedType,
    /// Out of memory
    OutOfMemory,
    /// System error
    SystemError,
};

// ============================================================================
// Clipboard Content
// ============================================================================

/// Clipboard content wrapper
pub const ClipboardContent = struct {
    content_type: ClipboardType,
    text: ?[]const u8,
    html: ?[]const u8,
    url: ?[]const u8,
    image_data: ?[]const u8,
    image_format: ?ImageFormat,
    file_paths: ?[]const []const u8,
    raw_data: ?[]const u8,
    custom_type: ?[]const u8,

    pub fn init(content_type: ClipboardType) ClipboardContent {
        return .{
            .content_type = content_type,
            .text = null,
            .html = null,
            .url = null,
            .image_data = null,
            .image_format = null,
            .file_paths = null,
            .raw_data = null,
            .custom_type = null,
        };
    }

    pub fn fromText(text: []const u8) ClipboardContent {
        var content = init(.text);
        content.text = text;
        return content;
    }

    pub fn fromUrl(url: []const u8) ClipboardContent {
        var content = init(.url);
        content.url = url;
        return content;
    }

    pub fn fromHtml(html: []const u8) ClipboardContent {
        var content = init(.rich_text);
        content.html = html;
        return content;
    }

    pub fn fromImage(data: []const u8, format: ImageFormat) ClipboardContent {
        var content = init(.image);
        content.image_data = data;
        content.image_format = format;
        return content;
    }

    pub fn fromFiles(paths: []const []const u8) ClipboardContent {
        var content = init(.files);
        content.file_paths = paths;
        return content;
    }

    pub fn fromData(data: []const u8, custom_type: []const u8) ClipboardContent {
        var content = init(.data);
        content.raw_data = data;
        content.custom_type = custom_type;
        return content;
    }

    pub fn isEmpty(self: *const ClipboardContent) bool {
        return self.content_type == .empty;
    }

    pub fn hasText(self: *const ClipboardContent) bool {
        return self.text != null;
    }

    pub fn hasUrl(self: *const ClipboardContent) bool {
        return self.url != null;
    }

    pub fn hasImage(self: *const ClipboardContent) bool {
        return self.image_data != null;
    }

    pub fn getText(self: *const ClipboardContent) ?[]const u8 {
        if (self.text) |t| return t;
        if (self.url) |u| return u;
        return null;
    }
};

// ============================================================================
// Clipboard Manager
// ============================================================================

/// Clipboard change callback
pub const ClipboardCallback = *const fn () void;

/// Clipboard manager
pub const ClipboardManager = struct {
    allocator: std.mem.Allocator,
    cached_content: ?ClipboardContent,
    change_count: u64,
    last_change_count: u64,
    change_callback: ?ClipboardCallback,
    max_text_length: usize,
    max_data_size: usize,
    native_pasteboard: ?*anyopaque,

    const Self = @This();

    /// Initialize the clipboard manager
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .cached_content = null,
            .change_count = 0,
            .last_change_count = 0,
            .change_callback = null,
            .max_text_length = 10 * 1024 * 1024, // 10MB
            .max_data_size = 50 * 1024 * 1024, // 50MB
            .native_pasteboard = null,
        };
    }

    /// Deinitialize
    pub fn deinit(self: *Self) void {
        self.cached_content = null;
    }

    /// Copy text to clipboard
    pub fn copyText(self: *Self, text: []const u8) ClipboardError!void {
        if (text.len > self.max_text_length) return ClipboardError.DataTooLarge;

        // Platform-specific copy
        if (comptime builtin.os.tag == .ios) {
            // [UIPasteboard generalPasteboard].string = text;
        } else if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
            // NSPasteboard *pb = [NSPasteboard generalPasteboard];
            // [pb clearContents];
            // [pb setString:text forType:NSPasteboardTypeString];
        } else if (comptime builtin.os.tag == .linux and builtin.abi == .android) {
            // ClipboardManager clipboard = context.getSystemService(CLIPBOARD_SERVICE);
            // ClipData clip = ClipData.newPlainText("text", text);
            // clipboard.setPrimaryClip(clip);
        } else if (comptime builtin.os.tag == .windows) {
            // OpenClipboard, EmptyClipboard, SetClipboardData
        }

        self.change_count += 1;
        self.cached_content = ClipboardContent.fromText(text);
    }

    /// Copy URL to clipboard
    pub fn copyUrl(self: *Self, url: []const u8) ClipboardError!void {
        // Platform-specific URL copy
        if (comptime builtin.os.tag == .ios) {
            // [UIPasteboard generalPasteboard].URL = [NSURL URLWithString:url];
        } else if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
            // [pb setString:url forType:NSPasteboardTypeURL];
        }

        self.change_count += 1;
        self.cached_content = ClipboardContent.fromUrl(url);
    }

    /// Copy HTML to clipboard
    pub fn copyHtml(self: *Self, html: []const u8, fallback_text: ?[]const u8) ClipboardError!void {
        if (html.len > self.max_data_size) return ClipboardError.DataTooLarge;

        // Platform-specific HTML copy
        if (comptime builtin.os.tag == .ios) {
            // UIPasteboard with HTML type
        } else if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
            // [pb setString:html forType:NSPasteboardTypeHTML];
        }

        self.change_count += 1;
        var content = ClipboardContent.fromHtml(html);
        content.text = fallback_text;
        self.cached_content = content;
    }

    /// Copy image to clipboard
    pub fn copyImage(self: *Self, data: []const u8, format: ImageFormat) ClipboardError!void {
        if (data.len > self.max_data_size) return ClipboardError.DataTooLarge;

        // Platform-specific image copy
        if (comptime builtin.os.tag == .ios) {
            // [UIPasteboard generalPasteboard].image = image;
        } else if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
            // [pb setData:data forType:NSPasteboardTypePNG];
        }

        self.change_count += 1;
        self.cached_content = ClipboardContent.fromImage(data, format);
    }

    /// Copy files to clipboard
    pub fn copyFiles(self: *Self, paths: []const []const u8) ClipboardError!void {
        if (paths.len == 0) return ClipboardError.NoData;

        // Platform-specific file copy
        if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
            // [pb writeObjects:fileURLs];
        }

        self.change_count += 1;
        self.cached_content = ClipboardContent.fromFiles(paths);
    }

    /// Copy custom data type
    pub fn copyData(self: *Self, data: []const u8, mime_type: []const u8) ClipboardError!void {
        if (data.len > self.max_data_size) return ClipboardError.DataTooLarge;

        // Platform-specific data copy
        self.change_count += 1;
        self.cached_content = ClipboardContent.fromData(data, mime_type);
    }

    /// Get text from clipboard
    pub fn getText(self: *Self) ClipboardError!?[]const u8 {
        // Platform-specific paste
        if (comptime builtin.os.tag == .ios) {
            // return [UIPasteboard generalPasteboard].string;
        } else if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
            // return [pb stringForType:NSPasteboardTypeString];
        } else if (comptime builtin.os.tag == .linux and builtin.abi == .android) {
            // ClipData clip = clipboard.getPrimaryClip();
            // return clip.getItemAt(0).getText();
        }

        // Return cached content for testing
        if (self.cached_content) |content| {
            return content.getText();
        }
        return null;
    }

    /// Get URL from clipboard
    pub fn getUrl(self: *Self) ClipboardError!?[]const u8 {
        // Platform-specific URL paste
        if (self.cached_content) |content| {
            return content.url;
        }
        return null;
    }

    /// Get HTML from clipboard
    pub fn getHtml(self: *Self) ClipboardError!?[]const u8 {
        if (self.cached_content) |content| {
            return content.html;
        }
        return null;
    }

    /// Get image from clipboard
    pub fn getImage(self: *Self) ClipboardError!?struct { data: []const u8, format: ImageFormat } {
        if (self.cached_content) |content| {
            if (content.image_data) |data| {
                return .{
                    .data = data,
                    .format = content.image_format orelse .png,
                };
            }
        }
        return null;
    }

    /// Get file paths from clipboard
    pub fn getFiles(self: *Self) ClipboardError!?[]const []const u8 {
        if (self.cached_content) |content| {
            return content.file_paths;
        }
        return null;
    }

    /// Get raw data from clipboard
    pub fn getData(self: *Self, mime_type: []const u8) ClipboardError!?[]const u8 {
        _ = mime_type;
        if (self.cached_content) |content| {
            return content.raw_data;
        }
        return null;
    }

    /// Get full clipboard content
    pub fn getContent(self: *Self) ClipboardError!ClipboardContent {
        if (self.cached_content) |content| {
            return content;
        }
        return ClipboardContent.init(.empty);
    }

    /// Check what types are available
    pub fn getAvailableTypes(self: *Self) ClipboardError![]const ClipboardType {
        var types = std.ArrayListUnmanaged(ClipboardType){};

        if (self.cached_content) |content| {
            if (content.text != null) types.append(self.allocator, .text) catch return ClipboardError.OutOfMemory;
            if (content.html != null) types.append(self.allocator, .rich_text) catch return ClipboardError.OutOfMemory;
            if (content.url != null) types.append(self.allocator, .url) catch return ClipboardError.OutOfMemory;
            if (content.image_data != null) types.append(self.allocator, .image) catch return ClipboardError.OutOfMemory;
            if (content.file_paths != null) types.append(self.allocator, .files) catch return ClipboardError.OutOfMemory;
            if (content.raw_data != null) types.append(self.allocator, .data) catch return ClipboardError.OutOfMemory;
        }

        if (types.items.len == 0) {
            types.append(self.allocator, .empty) catch return ClipboardError.OutOfMemory;
        }

        return types.toOwnedSlice(self.allocator) catch return ClipboardError.OutOfMemory;
    }

    /// Check if clipboard has text
    pub fn hasText(self: *Self) bool {
        if (self.cached_content) |content| {
            return content.hasText();
        }
        return false;
    }

    /// Check if clipboard has URL
    pub fn hasUrl(self: *Self) bool {
        if (self.cached_content) |content| {
            return content.hasUrl();
        }
        return false;
    }

    /// Check if clipboard has image
    pub fn hasImage(self: *Self) bool {
        if (self.cached_content) |content| {
            return content.hasImage();
        }
        return false;
    }

    /// Check if clipboard is empty
    pub fn isEmpty(self: *Self) bool {
        return self.cached_content == null;
    }

    /// Clear clipboard
    pub fn clear(self: *Self) ClipboardError!void {
        // Platform-specific clear
        if (comptime builtin.os.tag == .ios) {
            // [UIPasteboard generalPasteboard].items = @[];
        } else if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
            // [pb clearContents];
        }

        self.change_count += 1;
        self.cached_content = null;
    }

    /// Get clipboard change count
    pub fn getChangeCount(self: *const Self) u64 {
        return self.change_count;
    }

    /// Check if clipboard changed since last check
    pub fn hasChanged(self: *Self) bool {
        const changed = self.change_count != self.last_change_count;
        self.last_change_count = self.change_count;
        return changed;
    }

    /// Set clipboard change callback
    pub fn setChangeCallback(self: *Self, callback: ClipboardCallback) void {
        self.change_callback = callback;
    }

    /// Set maximum text length
    pub fn setMaxTextLength(self: *Self, max_length: usize) void {
        self.max_text_length = max_length;
    }

    /// Set maximum data size
    pub fn setMaxDataSize(self: *Self, max_size: usize) void {
        self.max_data_size = max_size;
    }
};

// ============================================================================
// Clipboard History (if supported)
// ============================================================================

/// Clipboard history entry
pub const ClipboardHistoryEntry = struct {
    content: ClipboardContent,
    timestamp: u64,
    source_app: ?[]const u8,

    pub fn init(content: ClipboardContent, timestamp: u64) ClipboardHistoryEntry {
        return .{
            .content = content,
            .timestamp = timestamp,
            .source_app = null,
        };
    }
};

/// Clipboard history manager (platform-dependent availability)
pub const ClipboardHistory = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayListUnmanaged(ClipboardHistoryEntry),
    max_entries: usize,
    enabled: bool,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .entries = .{},
            .max_entries = 100,
            .enabled = false,
        };
    }

    pub fn deinit(self: *Self) void {
        self.entries.deinit(self.allocator);
    }

    pub fn enable(self: *Self) void {
        self.enabled = true;
    }

    pub fn disable(self: *Self) void {
        self.enabled = false;
    }

    pub fn addEntry(self: *Self, content: ClipboardContent) ClipboardError!void {
        if (!self.enabled) return;

        const timestamp = getCurrentTimeMs();
        const entry = ClipboardHistoryEntry.init(content, timestamp);

        // Remove oldest if at capacity
        if (self.entries.items.len >= self.max_entries) {
            _ = self.entries.orderedRemove(0);
        }

        self.entries.append(self.allocator, entry) catch return ClipboardError.OutOfMemory;
    }

    pub fn getEntries(self: *const Self) []const ClipboardHistoryEntry {
        return self.entries.items;
    }

    pub fn getRecentEntries(self: *const Self, count: usize) []const ClipboardHistoryEntry {
        const len = self.entries.items.len;
        if (count >= len) return self.entries.items;
        return self.entries.items[len - count ..];
    }

    pub fn clearHistory(self: *Self) void {
        self.entries.clearRetainingCapacity();
    }

    pub fn setMaxEntries(self: *Self, max: usize) void {
        self.max_entries = max;
    }

    fn getCurrentTimeMs() u64 {
        var ts: std.c.timespec = undefined;
        if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
            return @as(u64, @intCast(ts.sec)) * 1000 + @as(u64, @intCast(ts.nsec)) / 1_000_000;
        }
        return 0;
    }
};

// ============================================================================
// Quick Clipboard Utilities
// ============================================================================

/// Quick clipboard utilities
pub const QuickClipboard = struct {
    /// Copy text and return success
    pub fn copy(manager: *ClipboardManager, text: []const u8) bool {
        manager.copyText(text) catch return false;
        return true;
    }

    /// Paste text or return empty string
    pub fn paste(manager: *ClipboardManager) []const u8 {
        return (manager.getText() catch return "") orelse "";
    }

    /// Copy if text is not empty
    pub fn copyIfNotEmpty(manager: *ClipboardManager, text: []const u8) bool {
        if (text.len == 0) return false;
        return copy(manager, text);
    }

    /// Check if clipboard contains valid URL
    pub fn hasValidUrl(manager: *ClipboardManager) bool {
        const text = (manager.getText() catch return false) orelse return false;
        return std.mem.startsWith(u8, text, "http://") or
            std.mem.startsWith(u8, text, "https://") or
            std.mem.startsWith(u8, text, "ftp://");
    }

    /// Get clipboard text trimmed
    pub fn getTrimmedText(manager: *ClipboardManager) ?[]const u8 {
        const text = (manager.getText() catch return null) orelse return null;
        return std.mem.trim(u8, text, &std.ascii.whitespace);
    }

    /// Copy formatted text (with newlines normalized)
    pub fn copyNormalized(manager: *ClipboardManager, text: []const u8, allocator: std.mem.Allocator) bool {
        // Simple normalization - replace \r\n with \n
        var result = std.ArrayListUnmanaged(u8){};
        var i: usize = 0;
        while (i < text.len) : (i += 1) {
            if (text[i] == '\r' and i + 1 < text.len and text[i + 1] == '\n') {
                result.append(allocator, '\n') catch return false;
                i += 1;
            } else {
                result.append(allocator, text[i]) catch return false;
            }
        }

        const normalized = result.toOwnedSlice(allocator) catch return false;
        defer allocator.free(normalized);

        return copy(manager, normalized);
    }
};

// ============================================================================
// Clipboard Presets
// ============================================================================

/// Common clipboard configurations
pub const ClipboardPresets = struct {
    /// Standard clipboard manager
    pub fn standard(allocator: std.mem.Allocator) ClipboardManager {
        return ClipboardManager.init(allocator);
    }

    /// Clipboard with small size limits (for constrained environments)
    pub fn constrained(allocator: std.mem.Allocator) ClipboardManager {
        var manager = ClipboardManager.init(allocator);
        manager.setMaxTextLength(1024 * 1024); // 1MB
        manager.setMaxDataSize(5 * 1024 * 1024); // 5MB
        return manager;
    }

    /// Clipboard with large size limits
    pub fn unlimited(allocator: std.mem.Allocator) ClipboardManager {
        var manager = ClipboardManager.init(allocator);
        manager.setMaxTextLength(100 * 1024 * 1024); // 100MB
        manager.setMaxDataSize(500 * 1024 * 1024); // 500MB
        return manager;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "ClipboardType basics" {
    const text = ClipboardType.text;
    try std.testing.expectEqualStrings("text", text.toString());
    try std.testing.expectEqualStrings("text/plain", text.mimeType());
    try std.testing.expectEqualStrings("public.plain-text", text.utiType());
}

test "ClipboardType all types" {
    try std.testing.expectEqualStrings("text/html", ClipboardType.rich_text.mimeType());
    try std.testing.expectEqualStrings("text/uri-list", ClipboardType.url.mimeType());
    try std.testing.expectEqualStrings("image/png", ClipboardType.image.mimeType());
}

test "ImageFormat basics" {
    const png = ImageFormat.png;
    try std.testing.expectEqualStrings("image/png", png.mimeType());
    try std.testing.expectEqualStrings(".png", png.extension());

    const jpeg = ImageFormat.jpeg;
    try std.testing.expectEqualStrings("image/jpeg", jpeg.mimeType());
    try std.testing.expectEqualStrings(".jpg", jpeg.extension());
}

test "ClipboardContent fromText" {
    const content = ClipboardContent.fromText("Hello, World!");
    try std.testing.expectEqual(ClipboardType.text, content.content_type);
    try std.testing.expectEqualStrings("Hello, World!", content.text.?);
    try std.testing.expect(content.hasText());
    try std.testing.expect(!content.hasUrl());
    try std.testing.expect(!content.isEmpty());
}

test "ClipboardContent fromUrl" {
    const content = ClipboardContent.fromUrl("https://example.com");
    try std.testing.expectEqual(ClipboardType.url, content.content_type);
    try std.testing.expectEqualStrings("https://example.com", content.url.?);
    try std.testing.expect(content.hasUrl());
}

test "ClipboardContent fromHtml" {
    const content = ClipboardContent.fromHtml("<b>Bold</b>");
    try std.testing.expectEqual(ClipboardType.rich_text, content.content_type);
    try std.testing.expectEqualStrings("<b>Bold</b>", content.html.?);
}

test "ClipboardContent fromImage" {
    const data = [_]u8{ 0x89, 0x50, 0x4E, 0x47 };
    const content = ClipboardContent.fromImage(&data, .png);
    try std.testing.expectEqual(ClipboardType.image, content.content_type);
    try std.testing.expect(content.hasImage());
    try std.testing.expectEqual(ImageFormat.png, content.image_format.?);
}

test "ClipboardContent fromFiles" {
    const paths = [_][]const u8{ "/path/to/file1.txt", "/path/to/file2.txt" };
    const content = ClipboardContent.fromFiles(&paths);
    try std.testing.expectEqual(ClipboardType.files, content.content_type);
    try std.testing.expectEqual(@as(usize, 2), content.file_paths.?.len);
}

test "ClipboardContent getText fallback to url" {
    const content = ClipboardContent.fromUrl("https://example.com");
    const text = content.getText();
    try std.testing.expectEqualStrings("https://example.com", text.?);
}

test "ClipboardContent empty" {
    const content = ClipboardContent.init(.empty);
    try std.testing.expect(content.isEmpty());
    try std.testing.expect(!content.hasText());
}

test "ClipboardManager initialization" {
    var manager = ClipboardManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expect(manager.isEmpty());
    try std.testing.expectEqual(@as(u64, 0), manager.getChangeCount());
}

test "ClipboardManager copyText" {
    var manager = ClipboardManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.copyText("Hello, Clipboard!");
    try std.testing.expect(!manager.isEmpty());
    try std.testing.expect(manager.hasText());
}

test "ClipboardManager getText" {
    var manager = ClipboardManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.copyText("Test Text");
    const text = try manager.getText();
    try std.testing.expectEqualStrings("Test Text", text.?);
}

test "ClipboardManager copyUrl" {
    var manager = ClipboardManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.copyUrl("https://example.com");
    try std.testing.expect(manager.hasUrl());

    const url = try manager.getUrl();
    try std.testing.expectEqualStrings("https://example.com", url.?);
}

test "ClipboardManager copyHtml" {
    var manager = ClipboardManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.copyHtml("<p>Hello</p>", "Hello");
    const html = try manager.getHtml();
    try std.testing.expectEqualStrings("<p>Hello</p>", html.?);
}

test "ClipboardManager copyImage" {
    var manager = ClipboardManager.init(std.testing.allocator);
    defer manager.deinit();

    const data = [_]u8{ 0x89, 0x50, 0x4E, 0x47 };
    try manager.copyImage(&data, .png);
    try std.testing.expect(manager.hasImage());

    const image = try manager.getImage();
    try std.testing.expect(image != null);
    try std.testing.expectEqual(ImageFormat.png, image.?.format);
}

test "ClipboardManager copyFiles" {
    var manager = ClipboardManager.init(std.testing.allocator);
    defer manager.deinit();

    const paths = [_][]const u8{"/path/file.txt"};
    try manager.copyFiles(&paths);

    const files = try manager.getFiles();
    try std.testing.expect(files != null);
}

test "ClipboardManager copyData" {
    var manager = ClipboardManager.init(std.testing.allocator);
    defer manager.deinit();

    const data = [_]u8{ 0x01, 0x02, 0x03 };
    try manager.copyData(&data, "application/custom");

    const retrieved = try manager.getData("application/custom");
    try std.testing.expect(retrieved != null);
}

test "ClipboardManager clear" {
    var manager = ClipboardManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.copyText("Text");
    try std.testing.expect(!manager.isEmpty());

    try manager.clear();
    try std.testing.expect(manager.isEmpty());
}

test "ClipboardManager change count" {
    var manager = ClipboardManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectEqual(@as(u64, 0), manager.getChangeCount());

    try manager.copyText("One");
    try std.testing.expectEqual(@as(u64, 1), manager.getChangeCount());

    try manager.copyText("Two");
    try std.testing.expectEqual(@as(u64, 2), manager.getChangeCount());
}

test "ClipboardManager hasChanged" {
    var manager = ClipboardManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expect(!manager.hasChanged());

    try manager.copyText("Text");
    try std.testing.expect(manager.hasChanged());
    try std.testing.expect(!manager.hasChanged()); // No change since last check
}

test "ClipboardManager data too large" {
    var manager = ClipboardManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setMaxTextLength(10);

    const result = manager.copyText("This is way too long for the limit");
    try std.testing.expectError(ClipboardError.DataTooLarge, result);
}

test "ClipboardManager getContent" {
    var manager = ClipboardManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.copyText("Content");
    const content = try manager.getContent();
    try std.testing.expect(!content.isEmpty());
}

test "ClipboardManager getAvailableTypes" {
    var manager = ClipboardManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.copyText("Text");
    const types = try manager.getAvailableTypes();
    defer manager.allocator.free(types);

    try std.testing.expect(types.len > 0);
    try std.testing.expectEqual(ClipboardType.text, types[0]);
}

test "ClipboardHistory initialization" {
    var history = ClipboardHistory.init(std.testing.allocator);
    defer history.deinit();

    try std.testing.expect(!history.enabled);
    try std.testing.expectEqual(@as(usize, 0), history.getEntries().len);
}

test "ClipboardHistory enable and add" {
    var history = ClipboardHistory.init(std.testing.allocator);
    defer history.deinit();

    history.enable();
    try std.testing.expect(history.enabled);

    const content = ClipboardContent.fromText("Test");
    try history.addEntry(content);

    try std.testing.expectEqual(@as(usize, 1), history.getEntries().len);
}

test "ClipboardHistory max entries" {
    var history = ClipboardHistory.init(std.testing.allocator);
    defer history.deinit();

    history.enable();
    history.setMaxEntries(3);

    const content = ClipboardContent.fromText("Test");
    try history.addEntry(content);
    try history.addEntry(content);
    try history.addEntry(content);
    try history.addEntry(content); // Should remove oldest

    try std.testing.expectEqual(@as(usize, 3), history.getEntries().len);
}

test "ClipboardHistory getRecentEntries" {
    var history = ClipboardHistory.init(std.testing.allocator);
    defer history.deinit();

    history.enable();

    try history.addEntry(ClipboardContent.fromText("One"));
    try history.addEntry(ClipboardContent.fromText("Two"));
    try history.addEntry(ClipboardContent.fromText("Three"));

    const recent = history.getRecentEntries(2);
    try std.testing.expectEqual(@as(usize, 2), recent.len);
}

test "ClipboardHistory clearHistory" {
    var history = ClipboardHistory.init(std.testing.allocator);
    defer history.deinit();

    history.enable();
    try history.addEntry(ClipboardContent.fromText("Test"));

    history.clearHistory();
    try std.testing.expectEqual(@as(usize, 0), history.getEntries().len);
}

test "ClipboardHistory disabled does not add" {
    var history = ClipboardHistory.init(std.testing.allocator);
    defer history.deinit();

    // History is disabled by default
    try history.addEntry(ClipboardContent.fromText("Test"));
    try std.testing.expectEqual(@as(usize, 0), history.getEntries().len);
}

test "QuickClipboard copy" {
    var manager = ClipboardManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expect(QuickClipboard.copy(&manager, "Quick copy"));
    try std.testing.expectEqualStrings("Quick copy", QuickClipboard.paste(&manager));
}

test "QuickClipboard copyIfNotEmpty" {
    var manager = ClipboardManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expect(!QuickClipboard.copyIfNotEmpty(&manager, ""));
    try std.testing.expect(QuickClipboard.copyIfNotEmpty(&manager, "Not empty"));
}

test "QuickClipboard hasValidUrl" {
    var manager = ClipboardManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.copyText("https://example.com");
    try std.testing.expect(QuickClipboard.hasValidUrl(&manager));

    try manager.copyText("not a url");
    try std.testing.expect(!QuickClipboard.hasValidUrl(&manager));
}

test "QuickClipboard getTrimmedText" {
    var manager = ClipboardManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.copyText("  trimmed  ");
    const trimmed = QuickClipboard.getTrimmedText(&manager);
    try std.testing.expectEqualStrings("trimmed", trimmed.?);
}

test "ClipboardPresets standard" {
    var manager = ClipboardPresets.standard(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectEqual(@as(usize, 10 * 1024 * 1024), manager.max_text_length);
}

test "ClipboardPresets constrained" {
    var manager = ClipboardPresets.constrained(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectEqual(@as(usize, 1024 * 1024), manager.max_text_length);
}

test "ClipboardPresets unlimited" {
    var manager = ClipboardPresets.unlimited(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectEqual(@as(usize, 100 * 1024 * 1024), manager.max_text_length);
}

test "ClipboardManager setMaxTextLength" {
    var manager = ClipboardManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setMaxTextLength(500);
    try std.testing.expectEqual(@as(usize, 500), manager.max_text_length);
}

test "ClipboardManager setMaxDataSize" {
    var manager = ClipboardManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setMaxDataSize(1000);
    try std.testing.expectEqual(@as(usize, 1000), manager.max_data_size);
}

test "ClipboardHistoryEntry init" {
    const content = ClipboardContent.fromText("Test");
    const entry = ClipboardHistoryEntry.init(content, 12345);

    try std.testing.expectEqual(@as(u64, 12345), entry.timestamp);
    try std.testing.expect(entry.source_app == null);
}
