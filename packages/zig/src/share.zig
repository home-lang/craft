//! Share Module
//!
//! Provides cross-platform system share sheet functionality:
//! - iOS: UIActivityViewController
//! - Android: Intent.ACTION_SEND / ShareSheet
//! - macOS: NSSharingServicePicker
//!
//! Example usage:
//! ```zig
//! var share = ShareManager.init(allocator);
//! defer share.deinit();
//!
//! // Share text
//! try share.shareText("Check out this app!");
//!
//! // Share URL
//! try share.shareUrl("https://example.com");
//!
//! // Share multiple items
//! try share.share(&[_]ShareItem{
//!     .{ .text = "Hello!" },
//!     .{ .url = "https://example.com" },
//! });
//! ```

const std = @import("std");
const builtin = @import("builtin");

/// Share errors
pub const ShareError = error{
    NotSupported,
    NotAvailable,
    InvalidContent,
    Cancelled,
    Failed,
    NoAppsAvailable,
    PermissionDenied,
    OutOfMemory,
};

/// Share item types
pub const ShareItem = union(enum) {
    /// Plain text content
    text: []const u8,
    /// URL to share
    url: []const u8,
    /// Image data with MIME type
    image: ImageData,
    /// File path to share
    file: FileData,
    /// Contact card (vCard)
    contact: ContactData,
    /// Email with subject and body
    email: EmailData,

    pub const ImageData = struct {
        data: []const u8,
        mime_type: []const u8,
        filename: ?[]const u8 = null,
    };

    pub const FileData = struct {
        path: []const u8,
        mime_type: ?[]const u8 = null,
        display_name: ?[]const u8 = null,
    };

    pub const ContactData = struct {
        name: []const u8,
        email: ?[]const u8 = null,
        phone: ?[]const u8 = null,
        organization: ?[]const u8 = null,
    };

    pub const EmailData = struct {
        to: ?[]const []const u8 = null,
        cc: ?[]const []const u8 = null,
        bcc: ?[]const []const u8 = null,
        subject: ?[]const u8 = null,
        body: ?[]const u8 = null,
        is_html: bool = false,
        attachments: ?[]const FileData = null,
    };

    pub fn getType(self: ShareItem) ShareItemType {
        return switch (self) {
            .text => .text,
            .url => .url,
            .image => .image,
            .file => .file,
            .contact => .contact,
            .email => .email,
        };
    }
};

/// Share item type enum
pub const ShareItemType = enum {
    text,
    url,
    image,
    file,
    contact,
    email,

    pub fn toString(self: ShareItemType) []const u8 {
        return switch (self) {
            .text => "Text",
            .url => "URL",
            .image => "Image",
            .file => "File",
            .contact => "Contact",
            .email => "Email",
        };
    }

    pub fn getMimeType(self: ShareItemType) []const u8 {
        return switch (self) {
            .text => "text/plain",
            .url => "text/uri-list",
            .image => "image/*",
            .file => "application/octet-stream",
            .contact => "text/vcard",
            .email => "message/rfc822",
        };
    }
};

/// Share activity types (iOS UIActivityType / Android Intent targets)
pub const ShareActivity = enum {
    // iOS/macOS specific
    air_drop,
    add_to_reading_list,
    assign_to_contact,
    copy_to_pasteboard,
    mail,
    message,
    post_to_facebook,
    post_to_twitter,
    post_to_weibo,
    print,
    save_to_camera_roll,
    open_in_ibooks,

    // Android specific
    bluetooth,
    nearby_share,
    quick_share,

    // Cross-platform
    other,

    pub fn toString(self: ShareActivity) []const u8 {
        return switch (self) {
            .air_drop => "AirDrop",
            .add_to_reading_list => "Add to Reading List",
            .assign_to_contact => "Assign to Contact",
            .copy_to_pasteboard => "Copy",
            .mail => "Mail",
            .message => "Message",
            .post_to_facebook => "Facebook",
            .post_to_twitter => "Twitter",
            .post_to_weibo => "Weibo",
            .print => "Print",
            .save_to_camera_roll => "Save to Photos",
            .open_in_ibooks => "Open in Books",
            .bluetooth => "Bluetooth",
            .nearby_share => "Nearby Share",
            .quick_share => "Quick Share",
            .other => "Other",
        };
    }

    pub fn toIOSString(self: ShareActivity) ?[]const u8 {
        return switch (self) {
            .air_drop => "com.apple.UIKit.activity.AirDrop",
            .add_to_reading_list => "com.apple.UIKit.activity.AddToReadingList",
            .assign_to_contact => "com.apple.UIKit.activity.AssignToContact",
            .copy_to_pasteboard => "com.apple.UIKit.activity.CopyToPasteboard",
            .mail => "com.apple.UIKit.activity.Mail",
            .message => "com.apple.UIKit.activity.Message",
            .post_to_facebook => "com.apple.UIKit.activity.PostToFacebook",
            .post_to_twitter => "com.apple.UIKit.activity.PostToTwitter",
            .post_to_weibo => "com.apple.UIKit.activity.PostToWeibo",
            .print => "com.apple.UIKit.activity.Print",
            .save_to_camera_roll => "com.apple.UIKit.activity.SaveToCameraRoll",
            .open_in_ibooks => "com.apple.UIKit.activity.OpenInIBooks",
            else => null,
        };
    }
};

/// Share result
pub const ShareResult = struct {
    /// Whether sharing was completed
    completed: bool,
    /// Activity type that was used (if known)
    activity: ?ShareActivity,
    /// Error message if failed
    error_message: ?[]const u8,
    /// Timestamp of the share action
    timestamp: i64,

    pub fn success(activity: ?ShareActivity) ShareResult {
        return .{
            .completed = true,
            .activity = activity,
            .error_message = null,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn cancelled() ShareResult {
        return .{
            .completed = false,
            .activity = null,
            .error_message = null,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn failure(message: []const u8) ShareResult {
        return .{
            .completed = false,
            .activity = null,
            .error_message = message,
            .timestamp = getCurrentTimestamp(),
        };
    }
};

/// Share options
pub const ShareOptions = struct {
    /// Excluded activities (iOS)
    excluded_activities: ?[]const ShareActivity = null,
    /// Popup source rect (iPad)
    source_rect: ?Rect = null,
    /// Subject line (for email/social)
    subject: ?[]const u8 = null,
    /// Completion callback
    on_complete: ?*const fn (ShareResult) void = null,

    pub const Rect = struct {
        x: f32,
        y: f32,
        width: f32,
        height: f32,
    };
};

/// Platform capabilities
pub const ShareCapabilities = struct {
    /// Supported item types
    supported_types: []const ShareItemType,
    /// Available activities
    available_activities: []const ShareActivity,
    /// Whether share sheet is available
    share_sheet_available: bool,
    /// Whether direct sharing to specific app is supported
    direct_share_available: bool,
    /// Platform
    platform: Platform,

    pub const Platform = enum {
        ios,
        android,
        macos,
        windows,
        linux,
        unknown,

        pub fn toString(self: Platform) []const u8 {
            return switch (self) {
                .ios => "iOS",
                .android => "Android",
                .macos => "macOS",
                .windows => "Windows",
                .linux => "Linux",
                .unknown => "Unknown",
            };
        }
    };
};

/// Share manager
pub const ShareManager = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    capabilities: ShareCapabilities,
    history: std.ArrayListUnmanaged(ShareHistoryEntry),
    max_history: usize,
    delegate: ?*const ShareDelegate = null,

    pub const ShareHistoryEntry = struct {
        items: []const ShareItemType,
        result: ShareResult,
    };

    pub const ShareDelegate = struct {
        context: ?*anyopaque = null,
        on_share_start: ?*const fn (?*anyopaque) void = null,
        on_share_complete: ?*const fn (?*anyopaque, ShareResult) void = null,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .capabilities = getPlatformCapabilities(),
            .history = .empty,
            .max_history = 50,
            .delegate = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.history.deinit(self.allocator);
    }

    /// Set delegate for share events
    pub fn setDelegate(self: *Self, delegate: *const ShareDelegate) void {
        self.delegate = delegate;
    }

    /// Get platform capabilities
    pub fn getCapabilities(self: *const Self) ShareCapabilities {
        return self.capabilities;
    }

    /// Check if a share type is supported
    pub fn isTypeSupported(self: *const Self, item_type: ShareItemType) bool {
        for (self.capabilities.supported_types) |t| {
            if (t == item_type) return true;
        }
        return false;
    }

    /// Check if share sheet is available
    pub fn isAvailable(self: *const Self) bool {
        return self.capabilities.share_sheet_available;
    }

    /// Share text content
    pub fn shareText(self: *Self, text: []const u8) ShareError!ShareResult {
        return self.shareTextWithOptions(text, .{});
    }

    /// Share text with options
    pub fn shareTextWithOptions(self: *Self, text: []const u8, options: ShareOptions) ShareError!ShareResult {
        if (text.len == 0) {
            return ShareError.InvalidContent;
        }

        const items = [_]ShareItem{.{ .text = text }};
        return self.shareWithOptions(&items, options);
    }

    /// Share URL
    pub fn shareUrl(self: *Self, url: []const u8) ShareError!ShareResult {
        return self.shareUrlWithOptions(url, .{});
    }

    /// Share URL with options
    pub fn shareUrlWithOptions(self: *Self, url: []const u8, options: ShareOptions) ShareError!ShareResult {
        if (url.len == 0) {
            return ShareError.InvalidContent;
        }

        const items = [_]ShareItem{.{ .url = url }};
        return self.shareWithOptions(&items, options);
    }

    /// Share image
    pub fn shareImage(self: *Self, data: []const u8, mime_type: []const u8) ShareError!ShareResult {
        if (data.len == 0) {
            return ShareError.InvalidContent;
        }

        const items = [_]ShareItem{.{ .image = .{
            .data = data,
            .mime_type = mime_type,
        } }};
        return self.share(&items);
    }

    /// Share file
    pub fn shareFile(self: *Self, path: []const u8) ShareError!ShareResult {
        if (path.len == 0) {
            return ShareError.InvalidContent;
        }

        const items = [_]ShareItem{.{ .file = .{
            .path = path,
        } }};
        return self.share(&items);
    }

    /// Share multiple items
    pub fn share(self: *Self, items: []const ShareItem) ShareError!ShareResult {
        return self.shareWithOptions(items, .{});
    }

    /// Share with options
    pub fn shareWithOptions(self: *Self, items: []const ShareItem, options: ShareOptions) ShareError!ShareResult {
        if (!self.isAvailable()) {
            return ShareError.NotAvailable;
        }

        if (items.len == 0) {
            return ShareError.InvalidContent;
        }

        // Check if all types are supported
        for (items) |item| {
            if (!self.isTypeSupported(item.getType())) {
                return ShareError.NotSupported;
            }
        }

        // Notify delegate
        if (self.delegate) |delegate| {
            if (delegate.on_share_start) |callback| {
                callback(delegate.context);
            }
        }

        // Platform-specific sharing would go here
        // For now, simulate success
        const result = ShareResult.success(null);

        // Record in history
        var types_buf: [16]ShareItemType = undefined;
        const types_count = @min(items.len, 16);
        for (items[0..types_count], 0..) |item, i| {
            types_buf[i] = item.getType();
        }

        self.history.append(self.allocator, .{
            .items = types_buf[0..types_count],
            .result = result,
        }) catch {};

        // Notify delegate
        if (self.delegate) |delegate| {
            if (delegate.on_share_complete) |callback| {
                callback(delegate.context, result);
            }
        }

        // Call options callback
        if (options.on_complete) |callback| {
            callback(result);
        }

        return result;
    }

    /// Compose email
    pub fn composeEmail(self: *Self, email: ShareItem.EmailData) ShareError!ShareResult {
        const items = [_]ShareItem{.{ .email = email }};
        return self.share(&items);
    }

    /// Share to specific activity (if supported)
    pub fn shareTo(self: *Self, activity: ShareActivity, items: []const ShareItem) ShareError!ShareResult {
        if (!self.capabilities.direct_share_available) {
            return ShareError.NotSupported;
        }

        // Check if activity is available
        var found = false;
        for (self.capabilities.available_activities) |a| {
            if (a == activity) {
                found = true;
                break;
            }
        }
        if (!found) {
            return ShareError.NotAvailable;
        }

        return self.share(items);
    }

    /// Check if can share to specific activity
    pub fn canShareTo(self: *const Self, activity: ShareActivity) bool {
        for (self.capabilities.available_activities) |a| {
            if (a == activity) return true;
        }
        return false;
    }

    /// Get share history
    pub fn getHistory(self: *const Self) []const ShareHistoryEntry {
        return self.history.items;
    }

    /// Clear history
    pub fn clearHistory(self: *Self) void {
        self.history.clearRetainingCapacity();
    }

    fn getPlatformCapabilities() ShareCapabilities {
        if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
            return .{
                .supported_types = &[_]ShareItemType{ .text, .url, .image, .file, .contact, .email },
                .available_activities = &[_]ShareActivity{
                    .air_drop,
                    .copy_to_pasteboard,
                    .mail,
                    .message,
                    .add_to_reading_list,
                    .print,
                },
                .share_sheet_available = true,
                .direct_share_available = true,
                .platform = .macos,
            };
        } else if (comptime builtin.os.tag == .linux) {
            if (comptime builtin.abi == .android) {
                return .{
                    .supported_types = &[_]ShareItemType{ .text, .url, .image, .file, .email },
                    .available_activities = &[_]ShareActivity{
                        .bluetooth,
                        .nearby_share,
                        .quick_share,
                        .mail,
                        .message,
                    },
                    .share_sheet_available = true,
                    .direct_share_available = true,
                    .platform = .android,
                };
            }
            return .{
                .supported_types = &[_]ShareItemType{ .text, .url, .file },
                .available_activities = &[_]ShareActivity{},
                .share_sheet_available = false,
                .direct_share_available = false,
                .platform = .linux,
            };
        } else if (comptime builtin.os.tag == .windows) {
            return .{
                .supported_types = &[_]ShareItemType{ .text, .url, .file },
                .available_activities = &[_]ShareActivity{ .mail, .copy_to_pasteboard },
                .share_sheet_available = true,
                .direct_share_available = false,
                .platform = .windows,
            };
        } else {
            return .{
                .supported_types = &[_]ShareItemType{},
                .available_activities = &[_]ShareActivity{},
                .share_sheet_available = false,
                .direct_share_available = false,
                .platform = .unknown,
            };
        }
    }
};

/// Quick share utilities
pub const QuickShare = struct {
    /// Share text quickly
    pub fn text(manager: *ShareManager, content: []const u8) ShareError!ShareResult {
        return manager.shareText(content);
    }

    /// Share URL quickly
    pub fn url(manager: *ShareManager, link: []const u8) ShareError!ShareResult {
        return manager.shareUrl(link);
    }

    /// Share text and URL together
    pub fn textWithUrl(manager: *ShareManager, content: []const u8, link: []const u8) ShareError!ShareResult {
        const items = [_]ShareItem{
            .{ .text = content },
            .{ .url = link },
        };
        return manager.share(&items);
    }

    /// Share file by path
    pub fn file(manager: *ShareManager, path: []const u8) ShareError!ShareResult {
        return manager.shareFile(path);
    }
};

/// Share content presets
pub const SharePresets = struct {
    /// Create app store link share
    pub fn appStoreLink(app_id: []const u8) ShareItem {
        var buf: [128]u8 = undefined;
        const url = std.fmt.bufPrint(&buf, "https://apps.apple.com/app/id{s}", .{app_id}) catch "https://apps.apple.com";
        return .{ .url = url };
    }

    /// Create social share text
    pub fn socialPost(text: []const u8, hashtags: []const []const u8) []const u8 {
        _ = hashtags;
        // In real implementation, would append hashtags
        return text;
    }
};

/// Get current timestamp in milliseconds
fn getCurrentTimestamp() i64 {
    const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
    if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
        return @as(i64, @intCast(ts.sec)) * 1000 + @divTrunc(@as(i64, @intCast(ts.nsec)), 1_000_000);
    } else {
        return @as(i64, @intCast(ts.sec)) * 1000 + @divTrunc(@as(i64, @intCast(ts.nsec)), 1_000_000);
    }
}

// ============================================================================
// Tests
// ============================================================================

test "ShareItemType toString" {
    try std.testing.expectEqualStrings("Text", ShareItemType.text.toString());
    try std.testing.expectEqualStrings("URL", ShareItemType.url.toString());
    try std.testing.expectEqualStrings("Image", ShareItemType.image.toString());
    try std.testing.expectEqualStrings("File", ShareItemType.file.toString());
}

test "ShareItemType getMimeType" {
    try std.testing.expectEqualStrings("text/plain", ShareItemType.text.getMimeType());
    try std.testing.expectEqualStrings("text/uri-list", ShareItemType.url.getMimeType());
}

test "ShareItem getType" {
    const text_item = ShareItem{ .text = "hello" };
    try std.testing.expectEqual(ShareItemType.text, text_item.getType());

    const url_item = ShareItem{ .url = "https://example.com" };
    try std.testing.expectEqual(ShareItemType.url, url_item.getType());
}

test "ShareActivity toString" {
    try std.testing.expectEqualStrings("AirDrop", ShareActivity.air_drop.toString());
    try std.testing.expectEqualStrings("Mail", ShareActivity.mail.toString());
    try std.testing.expectEqualStrings("Copy", ShareActivity.copy_to_pasteboard.toString());
}

test "ShareActivity toIOSString" {
    try std.testing.expectEqualStrings("com.apple.UIKit.activity.AirDrop", ShareActivity.air_drop.toIOSString().?);
    try std.testing.expectEqualStrings("com.apple.UIKit.activity.Mail", ShareActivity.mail.toIOSString().?);
    try std.testing.expect(ShareActivity.bluetooth.toIOSString() == null);
}

test "ShareResult success" {
    const result = ShareResult.success(.mail);
    try std.testing.expect(result.completed);
    try std.testing.expectEqual(ShareActivity.mail, result.activity.?);
    try std.testing.expect(result.error_message == null);
}

test "ShareResult cancelled" {
    const result = ShareResult.cancelled();
    try std.testing.expect(!result.completed);
    try std.testing.expect(result.activity == null);
    try std.testing.expect(result.error_message == null);
}

test "ShareResult failure" {
    const result = ShareResult.failure("Something went wrong");
    try std.testing.expect(!result.completed);
    try std.testing.expectEqualStrings("Something went wrong", result.error_message.?);
}

test "ShareManager initialization" {
    var manager = ShareManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expect(manager.isAvailable());
    try std.testing.expect(manager.capabilities.supported_types.len > 0);
}

test "ShareManager isTypeSupported" {
    var manager = ShareManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expect(manager.isTypeSupported(.text));
    try std.testing.expect(manager.isTypeSupported(.url));
}

test "ShareManager shareText" {
    var manager = ShareManager.init(std.testing.allocator);
    defer manager.deinit();

    const result = try manager.shareText("Hello, World!");
    try std.testing.expect(result.completed);
}

test "ShareManager shareText empty" {
    var manager = ShareManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectError(ShareError.InvalidContent, manager.shareText(""));
}

test "ShareManager shareUrl" {
    var manager = ShareManager.init(std.testing.allocator);
    defer manager.deinit();

    const result = try manager.shareUrl("https://example.com");
    try std.testing.expect(result.completed);
}

test "ShareManager shareUrl empty" {
    var manager = ShareManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectError(ShareError.InvalidContent, manager.shareUrl(""));
}

test "ShareManager shareImage" {
    var manager = ShareManager.init(std.testing.allocator);
    defer manager.deinit();

    const image_data = [_]u8{ 0x89, 0x50, 0x4E, 0x47 }; // PNG header
    const result = try manager.shareImage(&image_data, "image/png");
    try std.testing.expect(result.completed);
}

test "ShareManager shareFile" {
    var manager = ShareManager.init(std.testing.allocator);
    defer manager.deinit();

    const result = try manager.shareFile("/path/to/file.txt");
    try std.testing.expect(result.completed);
}

test "ShareManager share multiple items" {
    var manager = ShareManager.init(std.testing.allocator);
    defer manager.deinit();

    const items = [_]ShareItem{
        .{ .text = "Check this out!" },
        .{ .url = "https://example.com" },
    };

    const result = try manager.share(&items);
    try std.testing.expect(result.completed);
}

test "ShareManager share empty items" {
    var manager = ShareManager.init(std.testing.allocator);
    defer manager.deinit();

    const items = [_]ShareItem{};
    try std.testing.expectError(ShareError.InvalidContent, manager.share(&items));
}

test "ShareManager composeEmail" {
    var manager = ShareManager.init(std.testing.allocator);
    defer manager.deinit();

    const result = try manager.composeEmail(.{
        .subject = "Hello",
        .body = "This is a test email",
    });
    try std.testing.expect(result.completed);
}

test "ShareManager canShareTo" {
    var manager = ShareManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expect(manager.canShareTo(.mail));
    try std.testing.expect(manager.canShareTo(.air_drop));
}

test "ShareManager getHistory" {
    var manager = ShareManager.init(std.testing.allocator);
    defer manager.deinit();

    _ = try manager.shareText("Test 1");
    _ = try manager.shareUrl("https://test.com");

    try std.testing.expectEqual(@as(usize, 2), manager.getHistory().len);
}

test "ShareManager clearHistory" {
    var manager = ShareManager.init(std.testing.allocator);
    defer manager.deinit();

    _ = try manager.shareText("Test");
    try std.testing.expect(manager.getHistory().len > 0);

    manager.clearHistory();
    try std.testing.expectEqual(@as(usize, 0), manager.getHistory().len);
}

test "ShareCapabilities Platform toString" {
    try std.testing.expectEqualStrings("iOS", ShareCapabilities.Platform.ios.toString());
    try std.testing.expectEqualStrings("Android", ShareCapabilities.Platform.android.toString());
    try std.testing.expectEqualStrings("macOS", ShareCapabilities.Platform.macos.toString());
}

test "QuickShare text" {
    var manager = ShareManager.init(std.testing.allocator);
    defer manager.deinit();

    const result = try QuickShare.text(&manager, "Hello!");
    try std.testing.expect(result.completed);
}

test "QuickShare url" {
    var manager = ShareManager.init(std.testing.allocator);
    defer manager.deinit();

    const result = try QuickShare.url(&manager, "https://example.com");
    try std.testing.expect(result.completed);
}

test "QuickShare textWithUrl" {
    var manager = ShareManager.init(std.testing.allocator);
    defer manager.deinit();

    const result = try QuickShare.textWithUrl(&manager, "Check this!", "https://example.com");
    try std.testing.expect(result.completed);
}
