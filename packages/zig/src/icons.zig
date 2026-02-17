const std = @import("std");
const builtin = @import("builtin");

/// Cross-platform icon support
/// Provides a unified icon API that works across macOS (SF Symbols),
/// Windows (Segoe MDL2/Fluent icons), and Linux (Freedesktop icons)
/// Icon category for grouping related icons
pub const IconCategory = enum {
    navigation,
    action,
    media,
    communication,
    file,
    system,
    status,
    device,
    weather,
    object,
};

/// Icon style/variant
pub const IconStyle = enum {
    regular,
    filled,
    outline,
    thin,
    bold,
};

/// Cross-platform icon definition
pub const Icon = struct {
    /// Canonical icon name (used as identifier)
    name: []const u8,

    /// SF Symbol name (macOS)
    sf_symbol: ?[]const u8 = null,

    /// Segoe MDL2 Assets code point (Windows)
    segoe_mdl2: ?u21 = null,

    /// Segoe Fluent Icons code point (Windows 11+)
    fluent: ?u21 = null,

    /// Freedesktop icon name (Linux)
    freedesktop: ?[]const u8 = null,

    /// Unicode fallback character
    unicode_fallback: ?u21 = null,

    /// Category for organization
    category: IconCategory = .system,
};

/// Common icon mappings across platforms
pub const icons = struct {
    // Navigation
    pub const chevron_left = Icon{
        .name = "chevron-left",
        .sf_symbol = "chevron.left",
        .segoe_mdl2 = 0xE76B,
        .fluent = 0xE76B,
        .freedesktop = "go-previous",
        .unicode_fallback = 0x2039,
        .category = .navigation,
    };

    pub const chevron_right = Icon{
        .name = "chevron-right",
        .sf_symbol = "chevron.right",
        .segoe_mdl2 = 0xE76C,
        .fluent = 0xE76C,
        .freedesktop = "go-next",
        .unicode_fallback = 0x203A,
        .category = .navigation,
    };

    pub const chevron_up = Icon{
        .name = "chevron-up",
        .sf_symbol = "chevron.up",
        .segoe_mdl2 = 0xE70E,
        .fluent = 0xE70E,
        .freedesktop = "go-up",
        .unicode_fallback = 0x2303,
        .category = .navigation,
    };

    pub const chevron_down = Icon{
        .name = "chevron-down",
        .sf_symbol = "chevron.down",
        .segoe_mdl2 = 0xE70D,
        .fluent = 0xE70D,
        .freedesktop = "go-down",
        .unicode_fallback = 0x2304,
        .category = .navigation,
    };

    pub const arrow_left = Icon{
        .name = "arrow-left",
        .sf_symbol = "arrow.left",
        .segoe_mdl2 = 0xE72B,
        .fluent = 0xE72B,
        .freedesktop = "go-previous-symbolic",
        .unicode_fallback = 0x2190,
        .category = .navigation,
    };

    pub const arrow_right = Icon{
        .name = "arrow-right",
        .sf_symbol = "arrow.right",
        .segoe_mdl2 = 0xE72A,
        .fluent = 0xE72A,
        .freedesktop = "go-next-symbolic",
        .unicode_fallback = 0x2192,
        .category = .navigation,
    };

    pub const arrow_up = Icon{
        .name = "arrow-up",
        .sf_symbol = "arrow.up",
        .segoe_mdl2 = 0xE74A,
        .fluent = 0xE74A,
        .freedesktop = "go-up-symbolic",
        .unicode_fallback = 0x2191,
        .category = .navigation,
    };

    pub const arrow_down = Icon{
        .name = "arrow-down",
        .sf_symbol = "arrow.down",
        .segoe_mdl2 = 0xE74B,
        .fluent = 0xE74B,
        .freedesktop = "go-down-symbolic",
        .unicode_fallback = 0x2193,
        .category = .navigation,
    };

    pub const home = Icon{
        .name = "home",
        .sf_symbol = "house.fill",
        .segoe_mdl2 = 0xE80F,
        .fluent = 0xE80F,
        .freedesktop = "go-home",
        .unicode_fallback = 0x2302,
        .category = .navigation,
    };

    // Actions
    pub const plus = Icon{
        .name = "plus",
        .sf_symbol = "plus",
        .segoe_mdl2 = 0xE710,
        .fluent = 0xE710,
        .freedesktop = "list-add",
        .unicode_fallback = 0x002B,
        .category = .action,
    };

    pub const minus = Icon{
        .name = "minus",
        .sf_symbol = "minus",
        .segoe_mdl2 = 0xE738,
        .fluent = 0xE738,
        .freedesktop = "list-remove",
        .unicode_fallback = 0x2212,
        .category = .action,
    };

    pub const close = Icon{
        .name = "close",
        .sf_symbol = "xmark",
        .segoe_mdl2 = 0xE711,
        .fluent = 0xE711,
        .freedesktop = "window-close",
        .unicode_fallback = 0x2715,
        .category = .action,
    };

    pub const check = Icon{
        .name = "check",
        .sf_symbol = "checkmark",
        .segoe_mdl2 = 0xE73E,
        .fluent = 0xE73E,
        .freedesktop = "emblem-ok-symbolic",
        .unicode_fallback = 0x2713,
        .category = .action,
    };

    pub const trash = Icon{
        .name = "trash",
        .sf_symbol = "trash",
        .segoe_mdl2 = 0xE74D,
        .fluent = 0xE74D,
        .freedesktop = "user-trash",
        .unicode_fallback = 0x1F5D1,
        .category = .action,
    };

    pub const edit = Icon{
        .name = "edit",
        .sf_symbol = "pencil",
        .segoe_mdl2 = 0xE70F,
        .fluent = 0xE70F,
        .freedesktop = "document-edit",
        .unicode_fallback = 0x270E,
        .category = .action,
    };

    pub const copy = Icon{
        .name = "copy",
        .sf_symbol = "doc.on.doc",
        .segoe_mdl2 = 0xE8C8,
        .fluent = 0xE8C8,
        .freedesktop = "edit-copy",
        .unicode_fallback = 0x1F4CB,
        .category = .action,
    };

    pub const paste = Icon{
        .name = "paste",
        .sf_symbol = "doc.on.clipboard",
        .segoe_mdl2 = 0xE77F,
        .fluent = 0xE77F,
        .freedesktop = "edit-paste",
        .unicode_fallback = 0x1F4CB,
        .category = .action,
    };

    pub const cut = Icon{
        .name = "cut",
        .sf_symbol = "scissors",
        .segoe_mdl2 = 0xE8C6,
        .fluent = 0xE8C6,
        .freedesktop = "edit-cut",
        .unicode_fallback = 0x2702,
        .category = .action,
    };

    pub const undo = Icon{
        .name = "undo",
        .sf_symbol = "arrow.uturn.backward",
        .segoe_mdl2 = 0xE7A7,
        .fluent = 0xE7A7,
        .freedesktop = "edit-undo",
        .unicode_fallback = 0x21B6,
        .category = .action,
    };

    pub const redo = Icon{
        .name = "redo",
        .sf_symbol = "arrow.uturn.forward",
        .segoe_mdl2 = 0xE7A6,
        .fluent = 0xE7A6,
        .freedesktop = "edit-redo",
        .unicode_fallback = 0x21B7,
        .category = .action,
    };

    pub const refresh = Icon{
        .name = "refresh",
        .sf_symbol = "arrow.clockwise",
        .segoe_mdl2 = 0xE72C,
        .fluent = 0xE72C,
        .freedesktop = "view-refresh",
        .unicode_fallback = 0x21BB,
        .category = .action,
    };

    pub const search = Icon{
        .name = "search",
        .sf_symbol = "magnifyingglass",
        .segoe_mdl2 = 0xE721,
        .fluent = 0xE721,
        .freedesktop = "edit-find",
        .unicode_fallback = 0x1F50D,
        .category = .action,
    };

    pub const settings = Icon{
        .name = "settings",
        .sf_symbol = "gear",
        .segoe_mdl2 = 0xE713,
        .fluent = 0xE713,
        .freedesktop = "preferences-system",
        .unicode_fallback = 0x2699,
        .category = .action,
    };

    pub const share = Icon{
        .name = "share",
        .sf_symbol = "square.and.arrow.up",
        .segoe_mdl2 = 0xE72D,
        .fluent = 0xE72D,
        .freedesktop = "emblem-shared",
        .unicode_fallback = 0x2B06,
        .category = .action,
    };

    pub const download = Icon{
        .name = "download",
        .sf_symbol = "arrow.down.circle",
        .segoe_mdl2 = 0xE896,
        .fluent = 0xE896,
        .freedesktop = "emblem-downloads",
        .unicode_fallback = 0x2B07,
        .category = .action,
    };

    pub const upload = Icon{
        .name = "upload",
        .sf_symbol = "arrow.up.circle",
        .segoe_mdl2 = 0xE898,
        .fluent = 0xE898,
        .freedesktop = "go-up",
        .unicode_fallback = 0x2B06,
        .category = .action,
    };

    // Media
    pub const play = Icon{
        .name = "play",
        .sf_symbol = "play.fill",
        .segoe_mdl2 = 0xE768,
        .fluent = 0xE768,
        .freedesktop = "media-playback-start",
        .unicode_fallback = 0x25B6,
        .category = .media,
    };

    pub const pause = Icon{
        .name = "pause",
        .sf_symbol = "pause.fill",
        .segoe_mdl2 = 0xE769,
        .fluent = 0xE769,
        .freedesktop = "media-playback-pause",
        .unicode_fallback = 0x23F8,
        .category = .media,
    };

    pub const stop = Icon{
        .name = "stop",
        .sf_symbol = "stop.fill",
        .segoe_mdl2 = 0xE71A,
        .fluent = 0xE71A,
        .freedesktop = "media-playback-stop",
        .unicode_fallback = 0x23F9,
        .category = .media,
    };

    pub const skip_forward = Icon{
        .name = "skip-forward",
        .sf_symbol = "forward.fill",
        .segoe_mdl2 = 0xE893,
        .fluent = 0xE893,
        .freedesktop = "media-skip-forward",
        .unicode_fallback = 0x23ED,
        .category = .media,
    };

    pub const skip_back = Icon{
        .name = "skip-back",
        .sf_symbol = "backward.fill",
        .segoe_mdl2 = 0xE892,
        .fluent = 0xE892,
        .freedesktop = "media-skip-backward",
        .unicode_fallback = 0x23EE,
        .category = .media,
    };

    pub const volume_high = Icon{
        .name = "volume-high",
        .sf_symbol = "speaker.wave.3.fill",
        .segoe_mdl2 = 0xE995,
        .fluent = 0xE995,
        .freedesktop = "audio-volume-high",
        .unicode_fallback = 0x1F50A,
        .category = .media,
    };

    pub const volume_mute = Icon{
        .name = "volume-mute",
        .sf_symbol = "speaker.slash.fill",
        .segoe_mdl2 = 0xE74F,
        .fluent = 0xE74F,
        .freedesktop = "audio-volume-muted",
        .unicode_fallback = 0x1F507,
        .category = .media,
    };

    // Files
    pub const folder = Icon{
        .name = "folder",
        .sf_symbol = "folder.fill",
        .segoe_mdl2 = 0xE8B7,
        .fluent = 0xE8B7,
        .freedesktop = "folder",
        .unicode_fallback = 0x1F4C1,
        .category = .file,
    };

    pub const folder_open = Icon{
        .name = "folder-open",
        .sf_symbol = "folder.badge.plus",
        .segoe_mdl2 = 0xE8DA,
        .fluent = 0xE8DA,
        .freedesktop = "folder-open",
        .unicode_fallback = 0x1F4C2,
        .category = .file,
    };

    pub const file = Icon{
        .name = "file",
        .sf_symbol = "doc.fill",
        .segoe_mdl2 = 0xE7C3,
        .fluent = 0xE7C3,
        .freedesktop = "text-x-generic",
        .unicode_fallback = 0x1F4C4,
        .category = .file,
    };

    pub const save = Icon{
        .name = "save",
        .sf_symbol = "square.and.arrow.down",
        .segoe_mdl2 = 0xE74E,
        .fluent = 0xE74E,
        .freedesktop = "document-save",
        .unicode_fallback = 0x1F4BE,
        .category = .file,
    };

    // Communication
    pub const mail = Icon{
        .name = "mail",
        .sf_symbol = "envelope.fill",
        .segoe_mdl2 = 0xE715,
        .fluent = 0xE715,
        .freedesktop = "mail-unread",
        .unicode_fallback = 0x2709,
        .category = .communication,
    };

    pub const phone = Icon{
        .name = "phone",
        .sf_symbol = "phone.fill",
        .segoe_mdl2 = 0xE717,
        .fluent = 0xE717,
        .freedesktop = "call-start",
        .unicode_fallback = 0x260E,
        .category = .communication,
    };

    pub const message = Icon{
        .name = "message",
        .sf_symbol = "message.fill",
        .segoe_mdl2 = 0xE8BD,
        .fluent = 0xE8BD,
        .freedesktop = "mail-message-new",
        .unicode_fallback = 0x1F4AC,
        .category = .communication,
    };

    pub const notification = Icon{
        .name = "notification",
        .sf_symbol = "bell.fill",
        .segoe_mdl2 = 0xEA8F,
        .fluent = 0xEA8F,
        .freedesktop = "notification",
        .unicode_fallback = 0x1F514,
        .category = .communication,
    };

    // System
    pub const user = Icon{
        .name = "user",
        .sf_symbol = "person.fill",
        .segoe_mdl2 = 0xE77B,
        .fluent = 0xE77B,
        .freedesktop = "avatar-default",
        .unicode_fallback = 0x1F464,
        .category = .system,
    };

    pub const lock = Icon{
        .name = "lock",
        .sf_symbol = "lock.fill",
        .segoe_mdl2 = 0xE72E,
        .fluent = 0xE72E,
        .freedesktop = "system-lock-screen",
        .unicode_fallback = 0x1F512,
        .category = .system,
    };

    pub const unlock = Icon{
        .name = "unlock",
        .sf_symbol = "lock.open.fill",
        .segoe_mdl2 = 0xE785,
        .fluent = 0xE785,
        .freedesktop = "changes-allow",
        .unicode_fallback = 0x1F513,
        .category = .system,
    };

    pub const wifi = Icon{
        .name = "wifi",
        .sf_symbol = "wifi",
        .segoe_mdl2 = 0xE701,
        .fluent = 0xE701,
        .freedesktop = "network-wireless",
        .unicode_fallback = 0x1F4F6,
        .category = .system,
    };

    pub const bluetooth = Icon{
        .name = "bluetooth",
        .sf_symbol = "wave.3.right",
        .segoe_mdl2 = 0xE702,
        .fluent = 0xE702,
        .freedesktop = "bluetooth-active",
        .unicode_fallback = 0x1F4F6,
        .category = .system,
    };

    pub const battery_full = Icon{
        .name = "battery-full",
        .sf_symbol = "battery.100",
        .segoe_mdl2 = 0xE83F,
        .fluent = 0xE83F,
        .freedesktop = "battery-full",
        .unicode_fallback = 0x1F50B,
        .category = .system,
    };

    pub const battery_low = Icon{
        .name = "battery-low",
        .sf_symbol = "battery.25",
        .segoe_mdl2 = 0xE851,
        .fluent = 0xE851,
        .freedesktop = "battery-low",
        .unicode_fallback = 0x1FAAB,
        .category = .system,
    };

    // Status
    pub const success = Icon{
        .name = "success",
        .sf_symbol = "checkmark.circle.fill",
        .segoe_mdl2 = 0xE73E,
        .fluent = 0xE73E,
        .freedesktop = "emblem-ok",
        .unicode_fallback = 0x2705,
        .category = .status,
    };

    pub const warning = Icon{
        .name = "warning",
        .sf_symbol = "exclamationmark.triangle.fill",
        .segoe_mdl2 = 0xE7BA,
        .fluent = 0xE7BA,
        .freedesktop = "dialog-warning",
        .unicode_fallback = 0x26A0,
        .category = .status,
    };

    pub const @"error" = Icon{
        .name = "error",
        .sf_symbol = "xmark.circle.fill",
        .segoe_mdl2 = 0xEB90,
        .fluent = 0xEB90,
        .freedesktop = "dialog-error",
        .unicode_fallback = 0x274C,
        .category = .status,
    };

    pub const info = Icon{
        .name = "info",
        .sf_symbol = "info.circle.fill",
        .segoe_mdl2 = 0xE946,
        .fluent = 0xE946,
        .freedesktop = "dialog-information",
        .unicode_fallback = 0x2139,
        .category = .status,
    };

    pub const question = Icon{
        .name = "question",
        .sf_symbol = "questionmark.circle.fill",
        .segoe_mdl2 = 0xE897,
        .fluent = 0xE897,
        .freedesktop = "dialog-question",
        .unicode_fallback = 0x2753,
        .category = .status,
    };

    pub const star = Icon{
        .name = "star",
        .sf_symbol = "star.fill",
        .segoe_mdl2 = 0xE735,
        .fluent = 0xE735,
        .freedesktop = "starred",
        .unicode_fallback = 0x2B50,
        .category = .status,
    };

    pub const heart = Icon{
        .name = "heart",
        .sf_symbol = "heart.fill",
        .segoe_mdl2 = 0xEB52,
        .fluent = 0xEB52,
        .freedesktop = "emblem-favorite",
        .unicode_fallback = 0x2764,
        .category = .status,
    };
};

/// Get platform-specific icon representation
pub fn getPlatformIcon(icon: Icon) PlatformIcon {
    return switch (builtin.os.tag) {
        .macos => .{
            .kind = .sf_symbol,
            .value = icon.sf_symbol orelse "",
        },
        .windows => .{
            .kind = .segoe_mdl2,
            .codepoint = icon.segoe_mdl2 orelse icon.unicode_fallback orelse 0x003F,
        },
        .linux => .{
            .kind = .freedesktop,
            .value = icon.freedesktop orelse "",
        },
        else => .{
            .kind = .unicode,
            .codepoint = icon.unicode_fallback orelse 0x003F,
        },
    };
}

pub const PlatformIconKind = enum {
    sf_symbol,
    segoe_mdl2,
    freedesktop,
    unicode,
};

pub const PlatformIcon = struct {
    kind: PlatformIconKind,
    value: []const u8 = "",
    codepoint: u21 = 0,

    /// Get UTF-8 representation for codepoint-based icons
    pub fn toUtf8(self: PlatformIcon, buf: *[4]u8) []const u8 {
        if (self.kind == .sf_symbol or self.kind == .freedesktop) {
            return self.value;
        }

        const len = std.unicode.utf8Encode(self.codepoint, buf) catch return "?";
        return buf[0..len];
    }
};

/// Look up icon by name
pub fn getIconByName(name: []const u8) ?Icon {
    const name_map = std.StaticStringMap(Icon).initComptime(.{
        .{ "chevron-left", icons.chevron_left },
        .{ "chevron-right", icons.chevron_right },
        .{ "chevron-up", icons.chevron_up },
        .{ "chevron-down", icons.chevron_down },
        .{ "arrow-left", icons.arrow_left },
        .{ "arrow-right", icons.arrow_right },
        .{ "arrow-up", icons.arrow_up },
        .{ "arrow-down", icons.arrow_down },
        .{ "home", icons.home },
        .{ "plus", icons.plus },
        .{ "minus", icons.minus },
        .{ "close", icons.close },
        .{ "check", icons.check },
        .{ "trash", icons.trash },
        .{ "edit", icons.edit },
        .{ "copy", icons.copy },
        .{ "paste", icons.paste },
        .{ "cut", icons.cut },
        .{ "undo", icons.undo },
        .{ "redo", icons.redo },
        .{ "refresh", icons.refresh },
        .{ "search", icons.search },
        .{ "settings", icons.settings },
        .{ "share", icons.share },
        .{ "download", icons.download },
        .{ "upload", icons.upload },
        .{ "play", icons.play },
        .{ "pause", icons.pause },
        .{ "stop", icons.stop },
        .{ "skip-forward", icons.skip_forward },
        .{ "skip-back", icons.skip_back },
        .{ "volume-high", icons.volume_high },
        .{ "volume-mute", icons.volume_mute },
        .{ "folder", icons.folder },
        .{ "folder-open", icons.folder_open },
        .{ "file", icons.file },
        .{ "save", icons.save },
        .{ "mail", icons.mail },
        .{ "phone", icons.phone },
        .{ "message", icons.message },
        .{ "notification", icons.notification },
        .{ "user", icons.user },
        .{ "lock", icons.lock },
        .{ "unlock", icons.unlock },
        .{ "wifi", icons.wifi },
        .{ "bluetooth", icons.bluetooth },
        .{ "battery-full", icons.battery_full },
        .{ "battery-low", icons.battery_low },
        .{ "success", icons.success },
        .{ "warning", icons.warning },
        .{ "error", icons.@"error" },
        .{ "info", icons.info },
        .{ "question", icons.question },
        .{ "star", icons.star },
        .{ "heart", icons.heart },
    });

    return name_map.get(name);
}

/// Get all icons in a category
pub fn getIconsByCategory(category: IconCategory) []const Icon {
    // Would return filtered list - for now return all
    _ = category;
    return &[_]Icon{
        icons.chevron_left,
        icons.chevron_right,
        icons.plus,
        icons.check,
        icons.close,
        icons.search,
        icons.settings,
        icons.play,
        icons.pause,
        icons.folder,
        icons.file,
        icons.mail,
        icons.user,
        icons.success,
        icons.warning,
        icons.@"error",
        icons.info,
    };
}

// Tests
test "icon lookup" {
    const icon = getIconByName("settings");
    try std.testing.expect(icon != null);
    try std.testing.expectEqualStrings("settings", icon.?.name);
    try std.testing.expectEqualStrings("gear", icon.?.sf_symbol.?);
}

test "platform icon conversion" {
    const icon = icons.check;
    const platform = getPlatformIcon(icon);

    // Platform-dependent behavior
    switch (builtin.os.tag) {
        .macos => {
            try std.testing.expect(platform.kind == .sf_symbol);
            try std.testing.expectEqualStrings("checkmark", platform.value);
        },
        .windows => {
            try std.testing.expect(platform.kind == .segoe_mdl2);
        },
        .linux => {
            try std.testing.expect(platform.kind == .freedesktop);
        },
        else => {
            try std.testing.expect(platform.kind == .unicode);
        },
    }
}

test "unicode fallback" {
    const icon = icons.star;
    const platform = getPlatformIcon(icon);

    var buf: [4]u8 = undefined;
    const utf8 = platform.toUtf8(&buf);

    // Should have some representation
    try std.testing.expect(utf8.len > 0);
}

test "icon category" {
    try std.testing.expect(icons.play.category == .media);
    try std.testing.expect(icons.folder.category == .file);
    try std.testing.expect(icons.success.category == .status);
    try std.testing.expect(icons.search.category == .action);
}
