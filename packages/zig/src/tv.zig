//! TV platform support for Craft
//! Provides cross-platform abstractions for tvOS, Android TV, Fire TV, and smart TV platforms.
//! Covers focus management, remote control input, and TV-specific UI patterns.

const std = @import("std");

/// TV platform types
pub const TVPlatform = enum {
    tvos,
    android_tv,
    fire_tv,
    tizen,
    webos,
    roku,
    unknown,

    pub fn toString(self: TVPlatform) []const u8 {
        return switch (self) {
            .tvos => "tvOS",
            .android_tv => "Android TV",
            .fire_tv => "Fire TV",
            .tizen => "Tizen (Samsung)",
            .webos => "webOS (LG)",
            .roku => "Roku",
            .unknown => "Unknown",
        };
    }

    pub fn supportsRemote(self: TVPlatform) bool {
        return self != .unknown;
    }

    pub fn supportsVoice(self: TVPlatform) bool {
        return switch (self) {
            .tvos, .android_tv, .fire_tv, .roku => true,
            .tizen, .webos, .unknown => false,
        };
    }

    pub fn maxResolution(self: TVPlatform) Resolution {
        return switch (self) {
            .tvos, .android_tv, .fire_tv => .res_4k,
            .tizen, .webos => .res_4k,
            .roku => .res_4k,
            .unknown => .res_1080p,
        };
    }
};

/// TV display resolution
pub const Resolution = enum {
    res_720p,
    res_1080p,
    res_4k,
    res_8k,

    pub fn width(self: Resolution) u32 {
        return switch (self) {
            .res_720p => 1280,
            .res_1080p => 1920,
            .res_4k => 3840,
            .res_8k => 7680,
        };
    }

    pub fn height(self: Resolution) u32 {
        return switch (self) {
            .res_720p => 720,
            .res_1080p => 1080,
            .res_4k => 2160,
            .res_8k => 4320,
        };
    }

    pub fn toString(self: Resolution) []const u8 {
        return switch (self) {
            .res_720p => "720p",
            .res_1080p => "1080p",
            .res_4k => "4K UHD",
            .res_8k => "8K UHD",
        };
    }

    pub fn pixelCount(self: Resolution) u64 {
        return @as(u64, self.width()) * @as(u64, self.height());
    }
};

/// Remote control button types
pub const RemoteButton = enum {
    // Navigation
    up,
    down,
    left,
    right,
    select,
    back,
    menu,
    home,

    // Media controls
    play_pause,
    play,
    pause,
    stop,
    rewind,
    fast_forward,
    skip_back,
    skip_forward,

    // Volume
    volume_up,
    volume_down,
    mute,

    // Channel
    channel_up,
    channel_down,

    // Numbers
    num_0,
    num_1,
    num_2,
    num_3,
    num_4,
    num_5,
    num_6,
    num_7,
    num_8,
    num_9,

    // Special
    voice,
    search,
    info,
    guide,
    options,
    red,
    green,
    yellow,
    blue,

    pub fn isNavigation(self: RemoteButton) bool {
        return switch (self) {
            .up, .down, .left, .right, .select, .back, .menu, .home => true,
            else => false,
        };
    }

    pub fn isMedia(self: RemoteButton) bool {
        return switch (self) {
            .play_pause, .play, .pause, .stop, .rewind, .fast_forward, .skip_back, .skip_forward => true,
            else => false,
        };
    }

    pub fn isNumber(self: RemoteButton) bool {
        return switch (self) {
            .num_0, .num_1, .num_2, .num_3, .num_4, .num_5, .num_6, .num_7, .num_8, .num_9 => true,
            else => false,
        };
    }

    pub fn toNumber(self: RemoteButton) ?u8 {
        return switch (self) {
            .num_0 => 0,
            .num_1 => 1,
            .num_2 => 2,
            .num_3 => 3,
            .num_4 => 4,
            .num_5 => 5,
            .num_6 => 6,
            .num_7 => 7,
            .num_8 => 8,
            .num_9 => 9,
            else => null,
        };
    }

    pub fn isColorButton(self: RemoteButton) bool {
        return switch (self) {
            .red, .green, .yellow, .blue => true,
            else => false,
        };
    }
};

/// Remote button event type
pub const ButtonEventType = enum {
    pressed,
    released,
    long_pressed,
    repeated,

    pub fn toString(self: ButtonEventType) []const u8 {
        return switch (self) {
            .pressed => "Pressed",
            .released => "Released",
            .long_pressed => "Long Pressed",
            .repeated => "Repeated",
        };
    }
};

/// Remote control event
pub const RemoteEvent = struct {
    button: RemoteButton,
    event_type: ButtonEventType,
    timestamp: u64,
    repeat_count: u32,

    pub fn init(button: RemoteButton, event_type: ButtonEventType) RemoteEvent {
        return .{
            .button = button,
            .event_type = event_type,
            .timestamp = getCurrentTimestamp(),
            .repeat_count = 0,
        };
    }

    pub fn withRepeat(self: RemoteEvent, count: u32) RemoteEvent {
        var event = self;
        event.repeat_count = count;
        return event;
    }

    pub fn isPress(self: RemoteEvent) bool {
        return self.event_type == .pressed;
    }

    pub fn isRelease(self: RemoteEvent) bool {
        return self.event_type == .released;
    }

    pub fn isLongPress(self: RemoteEvent) bool {
        return self.event_type == .long_pressed;
    }
};

/// Focus direction for navigation
pub const FocusDirection = enum {
    up,
    down,
    left,
    right,
    forward,
    backward,

    pub fn opposite(self: FocusDirection) FocusDirection {
        return switch (self) {
            .up => .down,
            .down => .up,
            .left => .right,
            .right => .left,
            .forward => .backward,
            .backward => .forward,
        };
    }

    pub fn isHorizontal(self: FocusDirection) bool {
        return self == .left or self == .right;
    }

    pub fn isVertical(self: FocusDirection) bool {
        return self == .up or self == .down;
    }

    pub fn fromButton(button: RemoteButton) ?FocusDirection {
        return switch (button) {
            .up => .up,
            .down => .down,
            .left => .left,
            .right => .right,
            else => null,
        };
    }
};

/// Focus state for focusable elements
pub const FocusState = enum {
    unfocused,
    focused,
    pressed,
    disabled,

    pub fn isFocused(self: FocusState) bool {
        return self == .focused or self == .pressed;
    }

    pub fn isInteractive(self: FocusState) bool {
        return self != .disabled;
    }

    pub fn toString(self: FocusState) []const u8 {
        return switch (self) {
            .unfocused => "Unfocused",
            .focused => "Focused",
            .pressed => "Pressed",
            .disabled => "Disabled",
        };
    }
};

/// Focusable element identifier
pub const FocusableId = struct {
    group: []const u8,
    index: u32,

    pub fn init(group: []const u8, index: u32) FocusableId {
        return .{ .group = group, .index = index };
    }

    pub fn inGroup(self: FocusableId, group: []const u8) bool {
        return std.mem.eql(u8, self.group, group);
    }
};

/// Focus manager for TV navigation
pub const FocusManager = struct {
    current_group: []const u8,
    current_index: u32,
    group_count: u32,
    wrap_navigation: bool,
    history_len: usize,

    pub fn init() FocusManager {
        return .{
            .current_group = "default",
            .current_index = 0,
            .group_count = 1,
            .wrap_navigation = true,
            .history_len = 0,
        };
    }

    pub fn currentId(self: *const FocusManager) FocusableId {
        return FocusableId.init(self.current_group, self.current_index);
    }

    pub fn setGroup(self: *FocusManager, group: []const u8, count: u32) void {
        self.current_group = group;
        self.group_count = count;
        if (self.current_index >= count and count > 0) {
            self.current_index = count - 1;
        }
    }

    pub fn moveFocus(self: *FocusManager, direction: FocusDirection) bool {
        if (self.group_count == 0) return false;

        switch (direction) {
            .up, .left, .backward => {
                if (self.current_index > 0) {
                    self.current_index -= 1;
                    self.history_len += 1;
                    return true;
                } else if (self.wrap_navigation) {
                    self.current_index = self.group_count - 1;
                    self.history_len += 1;
                    return true;
                }
            },
            .down, .right, .forward => {
                if (self.current_index < self.group_count - 1) {
                    self.current_index += 1;
                    self.history_len += 1;
                    return true;
                } else if (self.wrap_navigation) {
                    self.current_index = 0;
                    self.history_len += 1;
                    return true;
                }
            },
        }
        return false;
    }

    pub fn setFocus(self: *FocusManager, index: u32) bool {
        if (index < self.group_count) {
            self.current_index = index;
            self.history_len += 1;
            return true;
        }
        return false;
    }

    pub fn setWrap(self: *FocusManager, wrap: bool) void {
        self.wrap_navigation = wrap;
    }
};

/// TV content rating
pub const ContentRating = enum {
    tv_g,
    tv_pg,
    tv_14,
    tv_ma,
    unrated,

    pub fn toString(self: ContentRating) []const u8 {
        return switch (self) {
            .tv_g => "TV-G",
            .tv_pg => "TV-PG",
            .tv_14 => "TV-14",
            .tv_ma => "TV-MA",
            .unrated => "Unrated",
        };
    }

    pub fn minimumAge(self: ContentRating) u8 {
        return switch (self) {
            .tv_g => 0,
            .tv_pg => 7,
            .tv_14 => 14,
            .tv_ma => 18,
            .unrated => 0,
        };
    }

    pub fn requiresParentalControl(self: ContentRating) bool {
        return self == .tv_14 or self == .tv_ma;
    }
};

/// TV content category
pub const ContentCategory = enum {
    movie,
    series,
    episode,
    live,
    sports,
    news,
    kids,
    documentary,
    music,
    game,

    pub fn toString(self: ContentCategory) []const u8 {
        return switch (self) {
            .movie => "Movie",
            .series => "Series",
            .episode => "Episode",
            .live => "Live",
            .sports => "Sports",
            .news => "News",
            .kids => "Kids",
            .documentary => "Documentary",
            .music => "Music",
            .game => "Game",
        };
    }

    pub fn supportsEpisodes(self: ContentCategory) bool {
        return self == .series;
    }

    pub fn isLiveContent(self: ContentCategory) bool {
        return self == .live or self == .sports or self == .news;
    }
};

/// TV content metadata
pub const ContentMetadata = struct {
    title: []const u8,
    category: ContentCategory,
    rating: ContentRating,
    duration_seconds: u32,
    release_year: u16,
    season: ?u16,
    episode: ?u16,
    progress_seconds: u32,

    pub fn init(title: []const u8, category: ContentCategory) ContentMetadata {
        return .{
            .title = title,
            .category = category,
            .rating = .unrated,
            .duration_seconds = 0,
            .release_year = 0,
            .season = null,
            .episode = null,
            .progress_seconds = 0,
        };
    }

    pub fn withRating(self: ContentMetadata, rating: ContentRating) ContentMetadata {
        var meta = self;
        meta.rating = rating;
        return meta;
    }

    pub fn withDuration(self: ContentMetadata, seconds: u32) ContentMetadata {
        var meta = self;
        meta.duration_seconds = seconds;
        return meta;
    }

    pub fn withEpisodeInfo(self: ContentMetadata, season: u16, episode: u16) ContentMetadata {
        var meta = self;
        meta.season = season;
        meta.episode = episode;
        return meta;
    }

    pub fn progressPercent(self: ContentMetadata) f32 {
        if (self.duration_seconds == 0) return 0;
        return @as(f32, @floatFromInt(self.progress_seconds)) / @as(f32, @floatFromInt(self.duration_seconds)) * 100.0;
    }

    pub fn isComplete(self: ContentMetadata) bool {
        return self.progress_seconds >= self.duration_seconds and self.duration_seconds > 0;
    }

    pub fn remainingSeconds(self: ContentMetadata) u32 {
        if (self.progress_seconds >= self.duration_seconds) return 0;
        return self.duration_seconds - self.progress_seconds;
    }
};

/// TV shelf/row layout type
pub const ShelfLayout = enum {
    horizontal,
    vertical,
    grid,
    hero,
    featured,

    pub fn toString(self: ShelfLayout) []const u8 {
        return switch (self) {
            .horizontal => "Horizontal",
            .vertical => "Vertical",
            .grid => "Grid",
            .hero => "Hero",
            .featured => "Featured",
        };
    }

    pub fn itemsPerRow(self: ShelfLayout, screen_width: u32) u32 {
        return switch (self) {
            .horizontal => @max(1, screen_width / 300),
            .vertical => 1,
            .grid => @max(1, screen_width / 200),
            .hero => 1,
            .featured => 3,
        };
    }
};

/// TV card size
pub const CardSize = enum {
    small,
    medium,
    large,
    hero,

    pub fn width(self: CardSize) u32 {
        return switch (self) {
            .small => 150,
            .medium => 200,
            .large => 300,
            .hero => 600,
        };
    }

    pub fn height(self: CardSize) u32 {
        return switch (self) {
            .small => 225,
            .medium => 300,
            .large => 450,
            .hero => 340,
        };
    }

    pub fn aspectRatio(self: CardSize) f32 {
        return @as(f32, @floatFromInt(self.width())) / @as(f32, @floatFromInt(self.height()));
    }
};

/// Content shelf for TV UI
pub const ContentShelf = struct {
    title: []const u8,
    layout: ShelfLayout,
    card_size: CardSize,
    item_count: u32,
    focused_index: u32,

    pub fn init(title: []const u8, layout: ShelfLayout) ContentShelf {
        return .{
            .title = title,
            .layout = layout,
            .card_size = .medium,
            .item_count = 0,
            .focused_index = 0,
        };
    }

    pub fn withCardSize(self: ContentShelf, size: CardSize) ContentShelf {
        var shelf = self;
        shelf.card_size = size;
        return shelf;
    }

    pub fn setItemCount(self: *ContentShelf, count: u32) void {
        self.item_count = count;
        if (self.focused_index >= count and count > 0) {
            self.focused_index = count - 1;
        }
    }

    pub fn moveFocus(self: *ContentShelf, direction: FocusDirection) bool {
        if (self.item_count == 0) return false;

        switch (direction) {
            .left, .backward => {
                if (self.focused_index > 0) {
                    self.focused_index -= 1;
                    return true;
                }
            },
            .right, .forward => {
                if (self.focused_index < self.item_count - 1) {
                    self.focused_index += 1;
                    return true;
                }
            },
            else => {},
        }
        return false;
    }
};

/// TV app lifecycle state
pub const TVAppState = enum {
    launching,
    active,
    background,
    suspended,
    terminating,

    pub fn isVisible(self: TVAppState) bool {
        return self == .active;
    }

    pub fn canPlayMedia(self: TVAppState) bool {
        return self == .active;
    }

    pub fn toString(self: TVAppState) []const u8 {
        return switch (self) {
            .launching => "Launching",
            .active => "Active",
            .background => "Background",
            .suspended => "Suspended",
            .terminating => "Terminating",
        };
    }
};

/// TV screen saver state
pub const ScreenSaverState = enum {
    inactive,
    pending,
    active,

    pub fn toString(self: ScreenSaverState) []const u8 {
        return switch (self) {
            .inactive => "Inactive",
            .pending => "Pending",
            .active => "Active",
        };
    }
};

/// TV app controller
pub const TVController = struct {
    platform: TVPlatform,
    resolution: Resolution,
    app_state: TVAppState,
    screen_saver: ScreenSaverState,
    focus_manager: FocusManager,
    idle_timeout_ms: u32,
    last_interaction: u64,

    pub fn init(platform: TVPlatform) TVController {
        return .{
            .platform = platform,
            .resolution = platform.maxResolution(),
            .app_state = .launching,
            .screen_saver = .inactive,
            .focus_manager = FocusManager.init(),
            .idle_timeout_ms = 300000, // 5 minutes
            .last_interaction = getCurrentTimestamp(),
        };
    }

    pub fn activate(self: *TVController) void {
        self.app_state = .active;
        self.screen_saver = .inactive;
        self.last_interaction = getCurrentTimestamp();
    }

    pub fn deactivate(self: *TVController) void {
        self.app_state = .background;
    }

    pub fn handleRemoteEvent(self: *TVController, event: RemoteEvent) bool {
        self.last_interaction = event.timestamp;
        self.screen_saver = .inactive;

        if (event.button.isNavigation()) {
            if (FocusDirection.fromButton(event.button)) |direction| {
                return self.focus_manager.moveFocus(direction);
            }
        }
        return true;
    }

    pub fn checkIdleState(self: *TVController) void {
        const now = getCurrentTimestamp();
        const elapsed = now - self.last_interaction;

        if (elapsed > self.idle_timeout_ms) {
            self.screen_saver = .active;
        } else if (elapsed > self.idle_timeout_ms / 2) {
            self.screen_saver = .pending;
        }
    }

    pub fn setIdleTimeout(self: *TVController, timeout_ms: u32) void {
        self.idle_timeout_ms = timeout_ms;
    }

    pub fn preventScreenSaver(self: *TVController) void {
        self.last_interaction = getCurrentTimestamp();
        self.screen_saver = .inactive;
    }

    pub fn isActive(self: *const TVController) bool {
        return self.app_state == .active;
    }
};

/// Voice command result
pub const VoiceCommandResult = struct {
    transcript: []const u8,
    confidence: f32,
    action: VoiceAction,

    pub fn init(transcript: []const u8, action: VoiceAction) VoiceCommandResult {
        return .{
            .transcript = transcript,
            .confidence = 1.0,
            .action = action,
        };
    }

    pub fn withConfidence(self: VoiceCommandResult, confidence: f32) VoiceCommandResult {
        var result = self;
        result.confidence = confidence;
        return result;
    }

    pub fn isHighConfidence(self: VoiceCommandResult) bool {
        return self.confidence >= 0.8;
    }
};

/// Voice action types
pub const VoiceAction = enum {
    search,
    play,
    pause,
    stop,
    volume_up,
    volume_down,
    mute,
    navigate,
    select_item,
    go_back,
    go_home,
    unknown,

    pub fn toString(self: VoiceAction) []const u8 {
        return switch (self) {
            .search => "Search",
            .play => "Play",
            .pause => "Pause",
            .stop => "Stop",
            .volume_up => "Volume Up",
            .volume_down => "Volume Down",
            .mute => "Mute",
            .navigate => "Navigate",
            .select_item => "Select",
            .go_back => "Back",
            .go_home => "Home",
            .unknown => "Unknown",
        };
    }

    pub fn toRemoteButton(self: VoiceAction) ?RemoteButton {
        return switch (self) {
            .play => .play,
            .pause => .pause,
            .stop => .stop,
            .volume_up => .volume_up,
            .volume_down => .volume_down,
            .mute => .mute,
            .select_item => .select,
            .go_back => .back,
            .go_home => .home,
            else => null,
        };
    }
};

/// Safe area insets for TV overscan
pub const SafeAreaInsets = struct {
    top: u32,
    bottom: u32,
    left: u32,
    right: u32,

    pub const standard = SafeAreaInsets{
        .top = 60,
        .bottom = 60,
        .left = 90,
        .right = 90,
    };

    pub const none = SafeAreaInsets{
        .top = 0,
        .bottom = 0,
        .left = 0,
        .right = 0,
    };

    pub fn safeWidth(self: SafeAreaInsets, screen_width: u32) u32 {
        const inset = self.left + self.right;
        if (inset >= screen_width) return 0;
        return screen_width - inset;
    }

    pub fn safeHeight(self: SafeAreaInsets, screen_height: u32) u32 {
        const inset = self.top + self.bottom;
        if (inset >= screen_height) return 0;
        return screen_height - inset;
    }
};

/// Get current timestamp in milliseconds
fn getCurrentTimestamp() u64 {
    const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
    const ms = @divTrunc(ts.nsec, 1_000_000);
    return @intCast(@as(i128, ts.sec) * 1000 + ms);
}

/// Get current TV platform
pub fn currentPlatform() TVPlatform {
    return .unknown; // Would use runtime detection
}

/// Check if running on TV platform
pub fn isTVPlatform() bool {
    return currentPlatform() != .unknown;
}

// ============================================================================
// Tests
// ============================================================================

test "TVPlatform properties" {
    try std.testing.expect(TVPlatform.tvos.supportsRemote());
    try std.testing.expect(TVPlatform.tvos.supportsVoice());
    try std.testing.expect(TVPlatform.android_tv.supportsVoice());
    try std.testing.expect(!TVPlatform.tizen.supportsVoice());
    try std.testing.expectEqual(Resolution.res_4k, TVPlatform.tvos.maxResolution());
}

test "TVPlatform toString" {
    try std.testing.expectEqualStrings("tvOS", TVPlatform.tvos.toString());
    try std.testing.expectEqualStrings("Android TV", TVPlatform.android_tv.toString());
    try std.testing.expectEqualStrings("Fire TV", TVPlatform.fire_tv.toString());
}

test "Resolution properties" {
    try std.testing.expectEqual(@as(u32, 1920), Resolution.res_1080p.width());
    try std.testing.expectEqual(@as(u32, 1080), Resolution.res_1080p.height());
    try std.testing.expectEqual(@as(u32, 3840), Resolution.res_4k.width());
    try std.testing.expectEqual(@as(u32, 2160), Resolution.res_4k.height());
    try std.testing.expectEqual(@as(u64, 1920 * 1080), Resolution.res_1080p.pixelCount());
}

test "RemoteButton navigation" {
    try std.testing.expect(RemoteButton.up.isNavigation());
    try std.testing.expect(RemoteButton.select.isNavigation());
    try std.testing.expect(!RemoteButton.play.isNavigation());
    try std.testing.expect(RemoteButton.play_pause.isMedia());
}

test "RemoteButton numbers" {
    try std.testing.expect(RemoteButton.num_5.isNumber());
    try std.testing.expectEqual(@as(?u8, 5), RemoteButton.num_5.toNumber());
    try std.testing.expectEqual(@as(?u8, 0), RemoteButton.num_0.toNumber());
    try std.testing.expectEqual(@as(?u8, null), RemoteButton.play.toNumber());
}

test "RemoteButton colors" {
    try std.testing.expect(RemoteButton.red.isColorButton());
    try std.testing.expect(RemoteButton.green.isColorButton());
    try std.testing.expect(!RemoteButton.play.isColorButton());
}

test "RemoteEvent creation" {
    const event = RemoteEvent.init(.select, .pressed);
    try std.testing.expect(event.isPress());
    try std.testing.expect(!event.isRelease());
    try std.testing.expectEqual(@as(u32, 0), event.repeat_count);
}

test "RemoteEvent withRepeat" {
    const event = RemoteEvent.init(.right, .repeated).withRepeat(5);
    try std.testing.expectEqual(@as(u32, 5), event.repeat_count);
    try std.testing.expectEqual(RemoteButton.right, event.button);
}

test "FocusDirection properties" {
    try std.testing.expect(FocusDirection.left.isHorizontal());
    try std.testing.expect(FocusDirection.right.isHorizontal());
    try std.testing.expect(FocusDirection.up.isVertical());
    try std.testing.expect(FocusDirection.down.isVertical());
    try std.testing.expectEqual(FocusDirection.down, FocusDirection.up.opposite());
}

test "FocusDirection fromButton" {
    try std.testing.expectEqual(FocusDirection.up, FocusDirection.fromButton(.up).?);
    try std.testing.expectEqual(FocusDirection.down, FocusDirection.fromButton(.down).?);
    try std.testing.expect(FocusDirection.fromButton(.select) == null);
}

test "FocusState properties" {
    try std.testing.expect(FocusState.focused.isFocused());
    try std.testing.expect(FocusState.pressed.isFocused());
    try std.testing.expect(!FocusState.unfocused.isFocused());
    try std.testing.expect(!FocusState.disabled.isInteractive());
}

test "FocusableId" {
    const id = FocusableId.init("menu", 3);
    try std.testing.expect(id.inGroup("menu"));
    try std.testing.expect(!id.inGroup("other"));
    try std.testing.expectEqual(@as(u32, 3), id.index);
}

test "FocusManager init" {
    const fm = FocusManager.init();
    try std.testing.expectEqualStrings("default", fm.current_group);
    try std.testing.expectEqual(@as(u32, 0), fm.current_index);
    try std.testing.expect(fm.wrap_navigation);
}

test "FocusManager navigation" {
    var fm = FocusManager.init();
    fm.setGroup("items", 5);

    try std.testing.expect(fm.moveFocus(.right));
    try std.testing.expectEqual(@as(u32, 1), fm.current_index);

    try std.testing.expect(fm.moveFocus(.down));
    try std.testing.expectEqual(@as(u32, 2), fm.current_index);

    try std.testing.expect(fm.moveFocus(.left));
    try std.testing.expectEqual(@as(u32, 1), fm.current_index);
}

test "FocusManager wrap" {
    var fm = FocusManager.init();
    fm.setGroup("items", 3);
    fm.current_index = 0;

    // Wrap backward
    try std.testing.expect(fm.moveFocus(.left));
    try std.testing.expectEqual(@as(u32, 2), fm.current_index);

    // Wrap forward
    try std.testing.expect(fm.moveFocus(.right));
    try std.testing.expectEqual(@as(u32, 0), fm.current_index);
}

test "FocusManager no wrap" {
    var fm = FocusManager.init();
    fm.setGroup("items", 3);
    fm.setWrap(false);
    fm.current_index = 0;

    try std.testing.expect(!fm.moveFocus(.left));
    try std.testing.expectEqual(@as(u32, 0), fm.current_index);
}

test "ContentRating properties" {
    try std.testing.expectEqual(@as(u8, 0), ContentRating.tv_g.minimumAge());
    try std.testing.expectEqual(@as(u8, 18), ContentRating.tv_ma.minimumAge());
    try std.testing.expect(ContentRating.tv_ma.requiresParentalControl());
    try std.testing.expect(!ContentRating.tv_g.requiresParentalControl());
}

test "ContentCategory properties" {
    try std.testing.expect(ContentCategory.series.supportsEpisodes());
    try std.testing.expect(!ContentCategory.movie.supportsEpisodes());
    try std.testing.expect(ContentCategory.live.isLiveContent());
    try std.testing.expect(ContentCategory.sports.isLiveContent());
}

test "ContentMetadata creation" {
    const meta = ContentMetadata.init("Test Movie", .movie)
        .withRating(.tv_pg)
        .withDuration(7200);

    try std.testing.expectEqualStrings("Test Movie", meta.title);
    try std.testing.expectEqual(ContentCategory.movie, meta.category);
    try std.testing.expectEqual(ContentRating.tv_pg, meta.rating);
    try std.testing.expectEqual(@as(u32, 7200), meta.duration_seconds);
}

test "ContentMetadata episode info" {
    const meta = ContentMetadata.init("Episode Title", .episode)
        .withEpisodeInfo(2, 5);

    try std.testing.expectEqual(@as(?u16, 2), meta.season);
    try std.testing.expectEqual(@as(?u16, 5), meta.episode);
}

test "ContentMetadata progress" {
    var meta = ContentMetadata.init("Movie", .movie).withDuration(100);
    meta.progress_seconds = 50;

    try std.testing.expect(meta.progressPercent() > 49.9);
    try std.testing.expect(meta.progressPercent() < 50.1);
    try std.testing.expectEqual(@as(u32, 50), meta.remainingSeconds());
    try std.testing.expect(!meta.isComplete());

    meta.progress_seconds = 100;
    try std.testing.expect(meta.isComplete());
}

test "ShelfLayout properties" {
    try std.testing.expectEqualStrings("Horizontal", ShelfLayout.horizontal.toString());
    try std.testing.expect(ShelfLayout.horizontal.itemsPerRow(1920) > 0);
    try std.testing.expectEqual(@as(u32, 1), ShelfLayout.vertical.itemsPerRow(1920));
}

test "CardSize dimensions" {
    try std.testing.expectEqual(@as(u32, 200), CardSize.medium.width());
    try std.testing.expectEqual(@as(u32, 300), CardSize.medium.height());
    try std.testing.expect(CardSize.hero.width() > CardSize.large.width());
}

test "ContentShelf creation" {
    const shelf = ContentShelf.init("Continue Watching", .horizontal)
        .withCardSize(.large);

    try std.testing.expectEqualStrings("Continue Watching", shelf.title);
    try std.testing.expectEqual(ShelfLayout.horizontal, shelf.layout);
    try std.testing.expectEqual(CardSize.large, shelf.card_size);
}

test "ContentShelf navigation" {
    var shelf = ContentShelf.init("Movies", .horizontal);
    shelf.setItemCount(5);

    try std.testing.expect(shelf.moveFocus(.right));
    try std.testing.expectEqual(@as(u32, 1), shelf.focused_index);

    try std.testing.expect(shelf.moveFocus(.left));
    try std.testing.expectEqual(@as(u32, 0), shelf.focused_index);

    // Can't go past beginning
    try std.testing.expect(!shelf.moveFocus(.left));
}

test "TVAppState properties" {
    try std.testing.expect(TVAppState.active.isVisible());
    try std.testing.expect(TVAppState.active.canPlayMedia());
    try std.testing.expect(!TVAppState.background.isVisible());
    try std.testing.expect(!TVAppState.suspended.canPlayMedia());
}

test "TVController init" {
    const controller = TVController.init(.tvos);
    try std.testing.expectEqual(TVPlatform.tvos, controller.platform);
    try std.testing.expectEqual(Resolution.res_4k, controller.resolution);
    try std.testing.expectEqual(TVAppState.launching, controller.app_state);
}

test "TVController lifecycle" {
    var controller = TVController.init(.android_tv);
    try std.testing.expect(!controller.isActive());

    controller.activate();
    try std.testing.expect(controller.isActive());
    try std.testing.expectEqual(TVAppState.active, controller.app_state);

    controller.deactivate();
    try std.testing.expectEqual(TVAppState.background, controller.app_state);
}

test "TVController remote handling" {
    var controller = TVController.init(.tvos);
    controller.activate();
    controller.focus_manager.setGroup("menu", 5);

    const event = RemoteEvent.init(.right, .pressed);
    try std.testing.expect(controller.handleRemoteEvent(event));
    try std.testing.expectEqual(@as(u32, 1), controller.focus_manager.current_index);
}

test "VoiceAction properties" {
    try std.testing.expectEqualStrings("Play", VoiceAction.play.toString());
    try std.testing.expectEqual(RemoteButton.play, VoiceAction.play.toRemoteButton().?);
    try std.testing.expectEqual(RemoteButton.home, VoiceAction.go_home.toRemoteButton().?);
    try std.testing.expect(VoiceAction.search.toRemoteButton() == null);
}

test "VoiceCommandResult" {
    const result = VoiceCommandResult.init("play movie", .play)
        .withConfidence(0.95);

    try std.testing.expectEqualStrings("play movie", result.transcript);
    try std.testing.expect(result.isHighConfidence());
    try std.testing.expectEqual(VoiceAction.play, result.action);
}

test "SafeAreaInsets" {
    const insets = SafeAreaInsets.standard;
    try std.testing.expectEqual(@as(u32, 60), insets.top);

    const safe_width = insets.safeWidth(1920);
    try std.testing.expectEqual(@as(u32, 1920 - 90 - 90), safe_width);

    const safe_height = insets.safeHeight(1080);
    try std.testing.expectEqual(@as(u32, 1080 - 60 - 60), safe_height);
}

test "currentPlatform" {
    const platform = currentPlatform();
    try std.testing.expectEqual(TVPlatform.unknown, platform);
}

test "isTVPlatform" {
    // On non-TV platform, should return false
    try std.testing.expect(!isTVPlatform());
}
