const std = @import("std");
const builtin = @import("builtin");

/// Screen-sharing / screen-recording detection.
///
/// macOS deliberately offers no "is someone capturing my screen?" API — the
/// closest thing is the menu-bar indicator, which is drawn by the system and
/// not queryable. What *is* available, and what this module combines, are four
/// independent signals:
///
///   1. **System screen sharing** — `CGSessionCopyCurrentDictionary()` gains a
///      `CGSSessionScreenIsShared` entry while macOS Screen Sharing / Apple
///      Remote Desktop has the session. This is a real, public CoreGraphics
///      API and is authoritative when it fires.
///   2. **Remote session** — the same dictionary's `kCGSSessionOnConsoleKey`
///      goes false when the session is being driven from elsewhere.
///   3. **Conference sharing** — every major conferencing app puts a *floating
///      sharing control* on screen while, and only while, a share is live. The
///      window-name table below matches those controls specifically.
///   4. **Screen recording** — the system recorder (`screencaptureui`) and the
///      common recorders expose an equally specific window while capturing.
///
/// The critical design rule is signal 3: match the **sharing indicator**, never
/// merely "a conferencing app is running". Detecting "Chrome is open" or "Zoom
/// is frontmost" produces an app that silences notifications all day, which is
/// worse than not shipping the feature.
pub const Kind = enum {
    system,
    remote,
    conference,
    recording,

    pub fn name(self: Kind) []const u8 {
        return switch (self) {
            .system => "system",
            .remote => "remote",
            .conference => "conference",
            .recording => "recording",
        };
    }
};

/// One window-level indicator rule.
///
/// `owner` matches the owning application's name (case-insensitive substring).
/// An empty `owner` matches any application. `window` matches the window title
/// the same way; an empty `window` means the window's mere existence under that
/// owner is the signal (used for apps whose sharing control is an unnamed
/// panel, where `owner` alone is already specific — e.g. macOS Screen Sharing).
pub const Indicator = struct {
    owner: []const u8,
    window: []const u8,
    kind: Kind,
};

/// Default indicator table.
///
/// Entries are deliberately narrow. Each one corresponds to a control surface
/// that the app in question shows *only* while sharing or recording, so a match
/// is evidence of an active share rather than of the app being installed.
pub const default_indicators = [_]Indicator{
    // macOS built-in screen sharing / remote desktop.
    .{ .owner = "Screen Sharing", .window = "", .kind = .system },
    .{ .owner = "ScreenSharingUIAgent", .window = "", .kind = .system },
    .{ .owner = "AppleVNCServer", .window = "", .kind = .system },

    // Zoom: the share toolbar is a separate always-on-top window.
    .{ .owner = "zoom", .window = "as_toolbar", .kind = .conference },
    .{ .owner = "zoom", .window = "Zoom Share Statusbar Window", .kind = .conference },
    .{ .owner = "zoom", .window = "you are screen sharing", .kind = .conference },
    .{ .owner = "zoom", .window = "sharing toolbar", .kind = .conference },

    // Microsoft Teams (both the classic and the WebView2-based clients).
    .{ .owner = "Teams", .window = "screen sharing toolbar", .kind = .conference },
    .{ .owner = "Teams", .window = "sharing control bar", .kind = .conference },
    .{ .owner = "Teams", .window = "is sharing", .kind = .conference },

    // Chromium family — getDisplayMedia() shows a "sharing this tab/screen"
    // bar owned by the browser itself, whatever the meeting site is.
    .{ .owner = "", .window = "is sharing your screen", .kind = .conference },
    .{ .owner = "", .window = "is sharing a window", .kind = .conference },
    .{ .owner = "", .window = "is sharing this tab", .kind = .conference },
    .{ .owner = "", .window = "sharing indicator", .kind = .conference },
    .{ .owner = "", .window = "screen sharing toolbar", .kind = .conference },

    // Webex.
    .{ .owner = "Webex", .window = "sharing content", .kind = .conference },
    .{ .owner = "Webex", .window = "you are sharing", .kind = .conference },

    // Slack huddles / Discord Go Live.
    .{ .owner = "Slack", .window = "is sharing screen", .kind = .conference },
    .{ .owner = "Discord", .window = "go live", .kind = .conference },

    // Recording surfaces.
    .{ .owner = "screencaptureui", .window = "", .kind = .recording },
    .{ .owner = "QuickTime Player", .window = "Screen Recording", .kind = .recording },
    .{ .owner = "Loom", .window = "recording controls", .kind = .recording },
    .{ .owner = "Loom", .window = "recording toolbar", .kind = .recording },
};

/// A single matched indicator, resolved against a live window.
pub const Source = struct {
    app: []const u8,
    window: []const u8,
    kind: Kind,
};

/// ASCII-case-insensitive substring match. Window titles come from the window
/// server as UTF-8; only ASCII case is folded, which is what every pattern in
/// the table needs and avoids dragging in a Unicode case table.
pub fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (needle.len > haystack.len) return false;
    const limit = haystack.len - needle.len;
    var i: usize = 0;
    while (i <= limit) : (i += 1) {
        var j: usize = 0;
        while (j < needle.len) : (j += 1) {
            if (lower(haystack[i + j]) != lower(needle[j])) break;
        } else return true;
    }
    return false;
}

fn lower(c: u8) u8 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

/// Test one window against the indicator table, returning the matched kind.
///
/// An indicator with an empty `window` pattern requires a non-empty `owner`
/// pattern, otherwise it would match literally every window; the table is
/// asserted against that rule in the tests below.
pub fn matchWindow(
    indicators: []const Indicator,
    owner: []const u8,
    window: []const u8,
) ?Kind {
    for (indicators) |ind| {
        if (ind.owner.len > 0 and !containsIgnoreCase(owner, ind.owner)) continue;
        if (ind.window.len > 0 and !containsIgnoreCase(window, ind.window)) continue;
        if (ind.owner.len == 0 and ind.window.len == 0) continue;
        return ind.kind;
    }
    return null;
}

/// Order-independent digest of the detected state, used by the watcher to
/// decide whether anything actually changed between polls. Hashing the sources
/// rather than comparing counts means a share that hands off from one app to
/// another still reports as a change.
pub const Digest = struct {
    value: u64 = 0,

    pub fn add(self: *Digest, kind: Kind, app: []const u8, window: []const u8) void {
        // FNV-1a per entry, XOR-combined so poll-to-poll window reordering
        // (which CGWindowList does freely) doesn't look like a state change.
        var h: u64 = 0xcbf29ce484222325;
        h = mix(h, @backingInt(kind));
        for (app) |c| h = mix(h, lower(c));
        h = mix(h, 0x1f);
        for (window) |c| h = mix(h, lower(c));
        self.value ^= h;
    }

    fn mix(h: u64, byte: u8) u64 {
        return (h ^ byte) *% 0x100000001b3;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "containsIgnoreCase folds ASCII case only" {
    try std.testing.expect(containsIgnoreCase("Zoom Share Statusbar Window", "share statusbar"));
    try std.testing.expect(containsIgnoreCase("as_toolbar", "AS_TOOLBAR"));
    try std.testing.expect(containsIgnoreCase("anything", ""));
    try std.testing.expect(!containsIgnoreCase("short", "much longer needle"));
    try std.testing.expect(!containsIgnoreCase("Zoom Meeting", "sharing"));
}

test "matchWindow requires an actual sharing indicator, not a running app" {
    // A conferencing app merely having a window open is not a share.
    try std.testing.expect(matchWindow(&default_indicators, "zoom.us", "Zoom Meeting") == null);
    try std.testing.expect(matchWindow(&default_indicators, "Google Chrome", "Inbox — Gmail") == null);
    try std.testing.expect(matchWindow(&default_indicators, "Microsoft Teams", "Chat | Team") == null);

    // The sharing controls are.
    try std.testing.expectEqual(Kind.conference, matchWindow(&default_indicators, "zoom.us", "as_toolbar").?);
    try std.testing.expectEqual(
        Kind.conference,
        matchWindow(&default_indicators, "Google Chrome", "meet.google.com is sharing your screen.").?,
    );
    try std.testing.expectEqual(Kind.system, matchWindow(&default_indicators, "Screen Sharing", "").?);
    try std.testing.expectEqual(Kind.recording, matchWindow(&default_indicators, "screencaptureui", "").?);
}

test "no default indicator matches every window" {
    for (default_indicators) |ind| {
        try std.testing.expect(ind.owner.len > 0 or ind.window.len > 0);
    }
    // The empty-owner rules must all carry a window pattern, or they would
    // match the entire window list.
    for (default_indicators) |ind| {
        if (ind.owner.len == 0) try std.testing.expect(ind.window.len > 0);
    }
}

test "digest is order independent but content sensitive" {
    var a: Digest = .{};
    a.add(.conference, "zoom.us", "as_toolbar");
    a.add(.recording, "screencaptureui", "");

    var b: Digest = .{};
    b.add(.recording, "screencaptureui", "");
    b.add(.conference, "zoom.us", "as_toolbar");
    try std.testing.expectEqual(a.value, b.value);

    var c: Digest = .{};
    c.add(.conference, "zoom.us", "as_toolbar");
    try std.testing.expect(c.value != a.value);
}
