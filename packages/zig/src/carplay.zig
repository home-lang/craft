//! Cross-platform automotive module for Craft
//! Provides CarPlay (iOS) and Android Auto connectivity
//! for in-vehicle infotainment integration.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Automotive platform type
pub const AutomotivePlatform = enum {
    carplay, // Apple CarPlay
    android_auto, // Android Auto
    unknown,

    pub fn toString(self: AutomotivePlatform) []const u8 {
        return switch (self) {
            .carplay => "CarPlay",
            .android_auto => "Android Auto",
            .unknown => "Unknown",
        };
    }

    pub fn manufacturer(self: AutomotivePlatform) []const u8 {
        return switch (self) {
            .carplay => "Apple",
            .android_auto => "Google",
            .unknown => "Unknown",
        };
    }
};

/// Connection type
pub const ConnectionType = enum {
    usb, // Wired USB connection
    wireless, // Wireless connection (WiFi/Bluetooth)
    unknown,

    pub fn toString(self: ConnectionType) []const u8 {
        return switch (self) {
            .usb => "USB",
            .wireless => "Wireless",
            .unknown => "Unknown",
        };
    }

    pub fn isWired(self: ConnectionType) bool {
        return self == .usb;
    }

    pub fn isWireless(self: ConnectionType) bool {
        return self == .wireless;
    }
};

/// Connection state
pub const ConnectionState = enum {
    disconnected,
    connecting,
    connected,
    disconnecting,

    pub fn toString(self: ConnectionState) []const u8 {
        return switch (self) {
            .disconnected => "Disconnected",
            .connecting => "Connecting",
            .connected => "Connected",
            .disconnecting => "Disconnecting",
        };
    }

    pub fn isActive(self: ConnectionState) bool {
        return self == .connected;
    }

    pub fn isTransitioning(self: ConnectionState) bool {
        return self == .connecting or self == .disconnecting;
    }
};

/// Template type for CarPlay/Android Auto apps
pub const TemplateType = enum {
    // Navigation templates
    map,
    navigation,
    trip_preview,
    route_preview,

    // Information display templates
    list,
    grid,
    information,
    point_of_interest,

    // Media templates
    now_playing,
    tab_bar,
    content_list,

    // Communication templates
    voice,
    contact,
    message,
    call,

    // Action templates
    action_sheet,
    alert,
    search,

    pub fn toString(self: TemplateType) []const u8 {
        return switch (self) {
            .map => "Map",
            .navigation => "Navigation",
            .trip_preview => "Trip Preview",
            .route_preview => "Route Preview",
            .list => "List",
            .grid => "Grid",
            .information => "Information",
            .point_of_interest => "Point of Interest",
            .now_playing => "Now Playing",
            .tab_bar => "Tab Bar",
            .content_list => "Content List",
            .voice => "Voice",
            .contact => "Contact",
            .message => "Message",
            .call => "Call",
            .action_sheet => "Action Sheet",
            .alert => "Alert",
            .search => "Search",
        };
    }

    pub fn category(self: TemplateType) TemplateCategory {
        return switch (self) {
            .map, .navigation, .trip_preview, .route_preview => .navigation,
            .list, .grid, .information, .point_of_interest => .information,
            .now_playing, .tab_bar, .content_list => .media,
            .voice, .contact, .message, .call => .communication,
            .action_sheet, .alert, .search => .action,
        };
    }
};

/// Template category
pub const TemplateCategory = enum {
    navigation,
    information,
    media,
    communication,
    action,

    pub fn toString(self: TemplateCategory) []const u8 {
        return switch (self) {
            .navigation => "Navigation",
            .information => "Information",
            .media => "Media",
            .communication => "Communication",
            .action => "Action",
        };
    }
};

/// App category for CarPlay/Android Auto
pub const AppCategory = enum {
    audio, // Music, podcasts, audiobooks
    communication, // Messaging, calling
    navigation, // Maps, navigation
    parking, // Parking apps
    charging, // EV charging
    quick_ordering, // Food ordering
    driving_task, // Driving utilities

    pub fn toString(self: AppCategory) []const u8 {
        return switch (self) {
            .audio => "Audio",
            .communication => "Communication",
            .navigation => "Navigation",
            .parking => "Parking",
            .charging => "Charging",
            .quick_ordering => "Quick Ordering",
            .driving_task => "Driving Task",
        };
    }

    pub fn icon(self: AppCategory) []const u8 {
        return switch (self) {
            .audio => "music.note",
            .communication => "message",
            .navigation => "map",
            .parking => "parkingsign",
            .charging => "bolt.car",
            .quick_ordering => "bag",
            .driving_task => "car",
        };
    }

    pub fn requiresNavigation(self: AppCategory) bool {
        return self == .navigation or self == .parking or self == .charging;
    }
};

/// Playback state for media
pub const PlaybackState = enum {
    stopped,
    playing,
    paused,
    loading,
    interrupted,

    pub fn toString(self: PlaybackState) []const u8 {
        return switch (self) {
            .stopped => "Stopped",
            .playing => "Playing",
            .paused => "Paused",
            .loading => "Loading",
            .interrupted => "Interrupted",
        };
    }

    pub fn isActive(self: PlaybackState) bool {
        return self == .playing or self == .paused or self == .loading;
    }
};

/// Repeat mode
pub const RepeatMode = enum {
    off,
    one,
    all,

    pub fn toString(self: RepeatMode) []const u8 {
        return switch (self) {
            .off => "Off",
            .one => "Repeat One",
            .all => "Repeat All",
        };
    }

    pub fn next(self: RepeatMode) RepeatMode {
        return switch (self) {
            .off => .one,
            .one => .all,
            .all => .off,
        };
    }
};

/// Shuffle mode
pub const ShuffleMode = enum {
    off,
    songs,
    albums,

    pub fn toString(self: ShuffleMode) []const u8 {
        return switch (self) {
            .off => "Off",
            .songs => "Songs",
            .albums => "Albums",
        };
    }

    pub fn isEnabled(self: ShuffleMode) bool {
        return self != .off;
    }
};

/// Playback speed
pub const PlaybackSpeed = enum {
    half,
    three_quarters,
    normal,
    one_and_quarter,
    one_and_half,
    double,

    pub fn multiplier(self: PlaybackSpeed) f32 {
        return switch (self) {
            .half => 0.5,
            .three_quarters => 0.75,
            .normal => 1.0,
            .one_and_quarter => 1.25,
            .one_and_half => 1.5,
            .double => 2.0,
        };
    }

    pub fn toString(self: PlaybackSpeed) []const u8 {
        return switch (self) {
            .half => "0.5x",
            .three_quarters => "0.75x",
            .normal => "1x",
            .one_and_quarter => "1.25x",
            .one_and_half => "1.5x",
            .double => "2x",
        };
    }
};

/// Now playing info
pub const NowPlayingInfo = struct {
    title: []const u8,
    artist: ?[]const u8,
    album: ?[]const u8,
    artwork_url: ?[]const u8,
    duration_ms: u64,
    elapsed_ms: u64,
    playback_state: PlaybackState,
    playback_speed: PlaybackSpeed,
    repeat_mode: RepeatMode,
    shuffle_mode: ShuffleMode,
    is_live_stream: bool,
    is_explicit: bool,

    const Self = @This();

    pub fn init(title: []const u8) Self {
        return .{
            .title = title,
            .artist = null,
            .album = null,
            .artwork_url = null,
            .duration_ms = 0,
            .elapsed_ms = 0,
            .playback_state = .stopped,
            .playback_speed = .normal,
            .repeat_mode = .off,
            .shuffle_mode = .off,
            .is_live_stream = false,
            .is_explicit = false,
        };
    }

    pub fn getProgress(self: Self) f32 {
        if (self.duration_ms == 0 or self.is_live_stream) return 0;
        return @as(f32, @floatFromInt(self.elapsed_ms)) / @as(f32, @floatFromInt(self.duration_ms));
    }

    pub fn getRemainingMs(self: Self) u64 {
        if (self.is_live_stream) return 0;
        if (self.elapsed_ms >= self.duration_ms) return 0;
        return self.duration_ms - self.elapsed_ms;
    }

    pub fn formatElapsed(self: Self, buffer: []u8) []const u8 {
        return formatDuration(self.elapsed_ms, buffer);
    }

    pub fn formatDurationStr(self: Self, buffer: []u8) []const u8 {
        if (self.is_live_stream) return "LIVE";
        return formatDuration(self.duration_ms, buffer);
    }
};

/// List item for list templates
pub const ListItem = struct {
    id: []const u8,
    title: []const u8,
    subtitle: ?[]const u8,
    detail_text: ?[]const u8,
    image_name: ?[]const u8,
    is_enabled: bool,
    is_playing: bool,
    shows_disclosure: bool,
    accessory_type: AccessoryType,

    pub const AccessoryType = enum {
        none,
        disclosure_indicator,
        checkmark,
        cloud,

        pub fn toString(self: AccessoryType) []const u8 {
            return switch (self) {
                .none => "None",
                .disclosure_indicator => "Disclosure",
                .checkmark => "Checkmark",
                .cloud => "Cloud",
            };
        }
    };

    pub fn init(id: []const u8, title: []const u8) ListItem {
        return .{
            .id = id,
            .title = title,
            .subtitle = null,
            .detail_text = null,
            .image_name = null,
            .is_enabled = true,
            .is_playing = false,
            .shows_disclosure = false,
            .accessory_type = .none,
        };
    }

    pub fn withSubtitle(self: ListItem, subtitle: []const u8) ListItem {
        var item = self;
        item.subtitle = subtitle;
        return item;
    }

    pub fn withImage(self: ListItem, image_name: []const u8) ListItem {
        var item = self;
        item.image_name = image_name;
        return item;
    }

    pub fn withDisclosure(self: ListItem) ListItem {
        var item = self;
        item.shows_disclosure = true;
        item.accessory_type = .disclosure_indicator;
        return item;
    }

    pub fn playing(self: ListItem) ListItem {
        var item = self;
        item.is_playing = true;
        return item;
    }
};

/// Grid item for grid templates
pub const GridItem = struct {
    id: []const u8,
    title: []const u8,
    image_name: []const u8,
    is_enabled: bool,

    pub fn init(id: []const u8, title: []const u8, image_name: []const u8) GridItem {
        return .{
            .id = id,
            .title = title,
            .image_name = image_name,
            .is_enabled = true,
        };
    }

    pub fn disabled(self: GridItem) GridItem {
        var item = self;
        item.is_enabled = false;
        return item;
    }
};

/// Point of interest
pub const PointOfInterest = struct {
    id: []const u8,
    title: []const u8,
    subtitle: ?[]const u8,
    latitude: f64,
    longitude: f64,
    category: POICategory,
    pin_image: ?[]const u8,

    pub const POICategory = enum {
        restaurant,
        gas_station,
        ev_charger,
        parking,
        hotel,
        attraction,
        shopping,
        other,

        pub fn toString(self: POICategory) []const u8 {
            return switch (self) {
                .restaurant => "Restaurant",
                .gas_station => "Gas Station",
                .ev_charger => "EV Charger",
                .parking => "Parking",
                .hotel => "Hotel",
                .attraction => "Attraction",
                .shopping => "Shopping",
                .other => "Other",
            };
        }

        pub fn icon(self: POICategory) []const u8 {
            return switch (self) {
                .restaurant => "fork.knife",
                .gas_station => "fuelpump",
                .ev_charger => "bolt.car",
                .parking => "parkingsign",
                .hotel => "bed.double",
                .attraction => "star",
                .shopping => "bag",
                .other => "mappin",
            };
        }
    };

    pub fn init(id: []const u8, title: []const u8, lat: f64, lon: f64) PointOfInterest {
        return .{
            .id = id,
            .title = title,
            .subtitle = null,
            .latitude = lat,
            .longitude = lon,
            .category = .other,
            .pin_image = null,
        };
    }

    pub fn withCategory(self: PointOfInterest, cat: POICategory) PointOfInterest {
        var poi = self;
        poi.category = cat;
        return poi;
    }

    pub fn withSubtitle(self: PointOfInterest, subtitle: []const u8) PointOfInterest {
        var poi = self;
        poi.subtitle = subtitle;
        return poi;
    }
};

/// Navigation maneuver
pub const Maneuver = struct {
    instruction: []const u8,
    distance_meters: u32,
    maneuver_type: ManeuverType,
    road_name: ?[]const u8,
    exit_number: ?[]const u8,

    pub const ManeuverType = enum {
        straight,
        turn_left,
        turn_right,
        slight_left,
        slight_right,
        sharp_left,
        sharp_right,
        u_turn,
        merge,
        exit,
        roundabout,
        ferry,
        arrive,

        pub fn toString(self: ManeuverType) []const u8 {
            return switch (self) {
                .straight => "Continue Straight",
                .turn_left => "Turn Left",
                .turn_right => "Turn Right",
                .slight_left => "Slight Left",
                .slight_right => "Slight Right",
                .sharp_left => "Sharp Left",
                .sharp_right => "Sharp Right",
                .u_turn => "U-Turn",
                .merge => "Merge",
                .exit => "Exit",
                .roundabout => "Roundabout",
                .ferry => "Ferry",
                .arrive => "Arrive",
            };
        }

        pub fn symbol(self: ManeuverType) []const u8 {
            return switch (self) {
                .straight => "arrow.up",
                .turn_left => "arrow.turn.up.left",
                .turn_right => "arrow.turn.up.right",
                .slight_left => "arrow.up.left",
                .slight_right => "arrow.up.right",
                .sharp_left => "arrow.turn.down.left",
                .sharp_right => "arrow.turn.down.right",
                .u_turn => "arrow.uturn.down",
                .merge => "arrow.merge",
                .exit => "arrow.up.right",
                .roundabout => "arrow.triangle.swap",
                .ferry => "ferry",
                .arrive => "mappin.circle",
            };
        }
    };

    pub fn init(instruction: []const u8, distance: u32, maneuver_type: ManeuverType) Maneuver {
        return .{
            .instruction = instruction,
            .distance_meters = distance,
            .maneuver_type = maneuver_type,
            .road_name = null,
            .exit_number = null,
        };
    }

    pub fn formatDistance(self: Maneuver, buffer: []u8) []const u8 {
        if (self.distance_meters < 1000) {
            return std.fmt.bufPrint(buffer, "{d} m", .{self.distance_meters}) catch "?";
        } else {
            const km = @as(f32, @floatFromInt(self.distance_meters)) / 1000.0;
            return std.fmt.bufPrint(buffer, "{d:.1} km", .{km}) catch "?";
        }
    }
};

/// Trip info
pub const TripInfo = struct {
    destination_name: []const u8,
    estimated_arrival: ?i64, // Unix timestamp
    remaining_distance_meters: u32,
    remaining_time_seconds: u32,
    current_maneuver: ?Maneuver,

    pub fn init(destination: []const u8) TripInfo {
        return .{
            .destination_name = destination,
            .estimated_arrival = null,
            .remaining_distance_meters = 0,
            .remaining_time_seconds = 0,
            .current_maneuver = null,
        };
    }

    pub fn formatRemainingDistance(self: TripInfo, buffer: []u8) []const u8 {
        if (self.remaining_distance_meters < 1000) {
            return std.fmt.bufPrint(buffer, "{d} m", .{self.remaining_distance_meters}) catch "?";
        } else {
            const km = @as(f32, @floatFromInt(self.remaining_distance_meters)) / 1000.0;
            return std.fmt.bufPrint(buffer, "{d:.1} km", .{km}) catch "?";
        }
    }

    pub fn formatRemainingTime(self: TripInfo, buffer: []u8) []const u8 {
        const hours = self.remaining_time_seconds / 3600;
        const minutes = (self.remaining_time_seconds % 3600) / 60;

        if (hours > 0) {
            return std.fmt.bufPrint(buffer, "{d}h {d}m", .{ hours, minutes }) catch "?";
        } else {
            return std.fmt.bufPrint(buffer, "{d} min", .{minutes}) catch "?";
        }
    }
};

/// Alert action
pub const AlertAction = struct {
    id: []const u8,
    title: []const u8,
    style: AlertStyle,

    pub const AlertStyle = enum {
        default,
        cancel,
        destructive,

        pub fn toString(self: AlertStyle) []const u8 {
            return switch (self) {
                .default => "Default",
                .cancel => "Cancel",
                .destructive => "Destructive",
            };
        }
    };

    pub fn init(id: []const u8, title: []const u8) AlertAction {
        return .{
            .id = id,
            .title = title,
            .style = .default,
        };
    }

    pub fn cancel(id: []const u8, title: []const u8) AlertAction {
        return .{
            .id = id,
            .title = title,
            .style = .cancel,
        };
    }

    pub fn destructive(id: []const u8, title: []const u8) AlertAction {
        return .{
            .id = id,
            .title = title,
            .style = .destructive,
        };
    }
};

/// Automotive event types
pub const AutomotiveEventType = enum {
    connected,
    disconnected,
    connection_failed,
    screen_became_main,
    screen_resigned_main,
    audio_focus_gained,
    audio_focus_lost,
    template_appeared,
    template_disappeared,
    button_pressed,
    list_item_selected,
    grid_item_selected,
    search_query_changed,
    voice_command_received,
    playback_command,
};

/// Automotive event
pub const AutomotiveEvent = struct {
    event_type: AutomotiveEventType,
    item_id: ?[]const u8,
    search_query: ?[]const u8,
    voice_text: ?[]const u8,
    timestamp: i64,

    pub fn create(event_type: AutomotiveEventType) AutomotiveEvent {
        return .{
            .event_type = event_type,
            .item_id = null,
            .search_query = null,
            .voice_text = null,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn forItem(event_type: AutomotiveEventType, item_id: []const u8) AutomotiveEvent {
        return .{
            .event_type = event_type,
            .item_id = item_id,
            .search_query = null,
            .voice_text = null,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn forSearch(query: []const u8) AutomotiveEvent {
        return .{
            .event_type = .search_query_changed,
            .item_id = null,
            .search_query = query,
            .voice_text = null,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn forVoice(text: []const u8) AutomotiveEvent {
        return .{
            .event_type = .voice_command_received,
            .item_id = null,
            .search_query = null,
            .voice_text = text,
            .timestamp = getCurrentTimestamp(),
        };
    }
};

/// Callback type
pub const AutomotiveCallback = *const fn (event: AutomotiveEvent) void;

/// Screen info
pub const ScreenInfo = struct {
    width: u32,
    height: u32,
    scale: f32,
    safe_area_insets: struct {
        top: u32,
        bottom: u32,
        left: u32,
        right: u32,
    },

    pub fn init() ScreenInfo {
        return .{
            .width = 800,
            .height = 480,
            .scale = 2.0,
            .safe_area_insets = .{
                .top = 0,
                .bottom = 0,
                .left = 0,
                .right = 0,
            },
        };
    }

    pub fn getUsableWidth(self: ScreenInfo) u32 {
        const insets = self.safe_area_insets.left + self.safe_area_insets.right;
        if (insets >= self.width) return 0;
        return self.width - insets;
    }

    pub fn getUsableHeight(self: ScreenInfo) u32 {
        const insets = self.safe_area_insets.top + self.safe_area_insets.bottom;
        if (insets >= self.height) return 0;
        return self.height - insets;
    }

    pub fn aspectRatio(self: ScreenInfo) f32 {
        if (self.height == 0) return 0;
        return @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(self.height));
    }
};

/// Automotive session
pub const AutomotiveSession = struct {
    allocator: Allocator,
    platform: AutomotivePlatform,
    connection_type: ConnectionType,
    connection_state: ConnectionState,
    app_category: AppCategory,
    screen_info: ScreenInfo,
    now_playing: ?NowPlayingInfo,
    trip_info: ?TripInfo,
    template_stack: std.ArrayListUnmanaged(TemplateType),
    callbacks: std.ArrayListUnmanaged(AutomotiveCallback),
    has_audio_focus: bool,
    is_screen_main: bool,

    const Self = @This();

    pub fn init(allocator: Allocator, app_category: AppCategory) Self {
        return .{
            .allocator = allocator,
            .platform = .unknown,
            .connection_type = .unknown,
            .connection_state = .disconnected,
            .app_category = app_category,
            .screen_info = ScreenInfo.init(),
            .now_playing = null,
            .trip_info = null,
            .template_stack = .{},
            .callbacks = .{},
            .has_audio_focus = false,
            .is_screen_main = false,
        };
    }

    pub fn deinit(self: *Self) void {
        self.template_stack.deinit(self.allocator);
        self.callbacks.deinit(self.allocator);
    }

    /// Add event callback
    pub fn addCallback(self: *Self, callback: AutomotiveCallback) !void {
        try self.callbacks.append(self.allocator, callback);
    }

    /// Remove event callback
    pub fn removeCallback(self: *Self, callback: AutomotiveCallback) bool {
        for (self.callbacks.items, 0..) |cb, i| {
            if (cb == callback) {
                _ = self.callbacks.orderedRemove(i);
                return true;
            }
        }
        return false;
    }

    /// Connect to automotive system
    pub fn connect(self: *Self, platform: AutomotivePlatform, connection_type: ConnectionType) void {
        self.platform = platform;
        self.connection_type = connection_type;
        self.connection_state = .connecting;
    }

    /// Set connected state
    pub fn setConnected(self: *Self, screen_info: ScreenInfo) void {
        self.connection_state = .connected;
        self.screen_info = screen_info;
        self.notifyCallbacks(AutomotiveEvent.create(.connected));
    }

    /// Disconnect
    pub fn disconnect(self: *Self) void {
        self.connection_state = .disconnecting;
        self.has_audio_focus = false;
        self.is_screen_main = false;
        self.notifyCallbacks(AutomotiveEvent.create(.disconnected));
        self.connection_state = .disconnected;
    }

    /// Check if connected
    pub fn isConnected(self: Self) bool {
        return self.connection_state == .connected;
    }

    /// Push template
    pub fn pushTemplate(self: *Self, template_type: TemplateType) !void {
        try self.template_stack.append(self.allocator, template_type);
        self.notifyCallbacks(AutomotiveEvent.create(.template_appeared));
    }

    /// Pop template
    pub fn popTemplate(self: *Self) ?TemplateType {
        if (self.template_stack.items.len > 0) {
            const template = self.template_stack.pop();
            self.notifyCallbacks(AutomotiveEvent.create(.template_disappeared));
            return template;
        }
        return null;
    }

    /// Get current template
    pub fn getCurrentTemplate(self: Self) ?TemplateType {
        if (self.template_stack.items.len > 0) {
            return self.template_stack.items[self.template_stack.items.len - 1];
        }
        return null;
    }

    /// Get template stack depth
    pub fn getTemplateStackDepth(self: Self) usize {
        return self.template_stack.items.len;
    }

    /// Set now playing info
    pub fn setNowPlaying(self: *Self, info: NowPlayingInfo) void {
        self.now_playing = info;
    }

    /// Clear now playing info
    pub fn clearNowPlaying(self: *Self) void {
        self.now_playing = null;
    }

    /// Set trip info
    pub fn setTripInfo(self: *Self, info: TripInfo) void {
        self.trip_info = info;
    }

    /// Clear trip info
    pub fn clearTripInfo(self: *Self) void {
        self.trip_info = null;
    }

    /// Set audio focus
    pub fn setAudioFocus(self: *Self, has_focus: bool) void {
        self.has_audio_focus = has_focus;
        const event_type: AutomotiveEventType = if (has_focus) .audio_focus_gained else .audio_focus_lost;
        self.notifyCallbacks(AutomotiveEvent.create(event_type));
    }

    /// Set screen main status
    pub fn setScreenMain(self: *Self, is_main: bool) void {
        self.is_screen_main = is_main;
        const event_type: AutomotiveEventType = if (is_main) .screen_became_main else .screen_resigned_main;
        self.notifyCallbacks(AutomotiveEvent.create(event_type));
    }

    fn notifyCallbacks(self: *Self, event: AutomotiveEvent) void {
        for (self.callbacks.items) |callback| {
            callback(event);
        }
    }
};

/// Format duration in milliseconds to mm:ss or h:mm:ss
fn formatDuration(ms: u64, buffer: []u8) []const u8 {
    const total_seconds = ms / 1000;
    const hours = total_seconds / 3600;
    const minutes = (total_seconds % 3600) / 60;
    const seconds = total_seconds % 60;

    if (hours > 0) {
        return std.fmt.bufPrint(buffer, "{d}:{d:0>2}:{d:0>2}", .{ hours, minutes, seconds }) catch "?";
    } else {
        return std.fmt.bufPrint(buffer, "{d}:{d:0>2}", .{ minutes, seconds }) catch "?";
    }
}

/// Get current timestamp in milliseconds
fn getCurrentTimestamp() i64 {
    const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
    return @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000);
}

// ============================================================================
// Tests
// ============================================================================

test "AutomotivePlatform toString" {
    try std.testing.expectEqualStrings("CarPlay", AutomotivePlatform.carplay.toString());
    try std.testing.expectEqualStrings("Android Auto", AutomotivePlatform.android_auto.toString());
}

test "AutomotivePlatform manufacturer" {
    try std.testing.expectEqualStrings("Apple", AutomotivePlatform.carplay.manufacturer());
    try std.testing.expectEqualStrings("Google", AutomotivePlatform.android_auto.manufacturer());
}

test "ConnectionType properties" {
    try std.testing.expect(ConnectionType.usb.isWired());
    try std.testing.expect(!ConnectionType.usb.isWireless());
    try std.testing.expect(ConnectionType.wireless.isWireless());
    try std.testing.expect(!ConnectionType.wireless.isWired());
}

test "ConnectionState properties" {
    try std.testing.expect(ConnectionState.connected.isActive());
    try std.testing.expect(!ConnectionState.disconnected.isActive());
    try std.testing.expect(ConnectionState.connecting.isTransitioning());
    try std.testing.expect(!ConnectionState.connected.isTransitioning());
}

test "TemplateType category" {
    try std.testing.expectEqual(TemplateCategory.navigation, TemplateType.map.category());
    try std.testing.expectEqual(TemplateCategory.media, TemplateType.now_playing.category());
    try std.testing.expectEqual(TemplateCategory.communication, TemplateType.message.category());
    try std.testing.expectEqual(TemplateCategory.action, TemplateType.alert.category());
}

test "AppCategory properties" {
    try std.testing.expect(AppCategory.navigation.requiresNavigation());
    try std.testing.expect(AppCategory.parking.requiresNavigation());
    try std.testing.expect(!AppCategory.audio.requiresNavigation());
}

test "PlaybackState properties" {
    try std.testing.expect(PlaybackState.playing.isActive());
    try std.testing.expect(PlaybackState.paused.isActive());
    try std.testing.expect(!PlaybackState.stopped.isActive());
}

test "RepeatMode next" {
    try std.testing.expectEqual(RepeatMode.one, RepeatMode.off.next());
    try std.testing.expectEqual(RepeatMode.all, RepeatMode.one.next());
    try std.testing.expectEqual(RepeatMode.off, RepeatMode.all.next());
}

test "ShuffleMode isEnabled" {
    try std.testing.expect(!ShuffleMode.off.isEnabled());
    try std.testing.expect(ShuffleMode.songs.isEnabled());
    try std.testing.expect(ShuffleMode.albums.isEnabled());
}

test "PlaybackSpeed multiplier" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), PlaybackSpeed.normal.multiplier(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), PlaybackSpeed.half.multiplier(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), PlaybackSpeed.double.multiplier(), 0.01);
}

test "NowPlayingInfo init" {
    const info = NowPlayingInfo.init("Test Song");
    try std.testing.expectEqualStrings("Test Song", info.title);
    try std.testing.expectEqual(PlaybackState.stopped, info.playback_state);
}

test "NowPlayingInfo getProgress" {
    var info = NowPlayingInfo.init("Song");
    info.duration_ms = 180000; // 3 minutes
    info.elapsed_ms = 90000; // 1.5 minutes

    try std.testing.expectApproxEqAbs(@as(f32, 0.5), info.getProgress(), 0.01);
}

test "NowPlayingInfo getRemainingMs" {
    var info = NowPlayingInfo.init("Song");
    info.duration_ms = 180000;
    info.elapsed_ms = 60000;

    try std.testing.expectEqual(@as(u64, 120000), info.getRemainingMs());
}

test "ListItem init" {
    const item = ListItem.init("1", "Test Item");
    try std.testing.expectEqualStrings("1", item.id);
    try std.testing.expectEqualStrings("Test Item", item.title);
    try std.testing.expect(item.is_enabled);
}

test "ListItem fluent API" {
    const item = ListItem.init("1", "Song")
        .withSubtitle("Artist")
        .withImage("album.png")
        .withDisclosure()
        .playing();

    try std.testing.expectEqualStrings("Artist", item.subtitle.?);
    try std.testing.expectEqualStrings("album.png", item.image_name.?);
    try std.testing.expect(item.shows_disclosure);
    try std.testing.expect(item.is_playing);
}

test "GridItem init" {
    const item = GridItem.init("1", "Albums", "albums.png");
    try std.testing.expectEqualStrings("1", item.id);
    try std.testing.expect(item.is_enabled);
}

test "PointOfInterest init" {
    const poi = PointOfInterest.init("1", "Coffee Shop", 37.7749, -122.4194);
    try std.testing.expectEqualStrings("Coffee Shop", poi.title);
    try std.testing.expectApproxEqAbs(@as(f64, 37.7749), poi.latitude, 0.0001);
}

test "PointOfInterest fluent API" {
    const poi = PointOfInterest.init("1", "Gas Station", 37.0, -122.0)
        .withCategory(.gas_station)
        .withSubtitle("$3.99/gal");

    try std.testing.expectEqual(PointOfInterest.POICategory.gas_station, poi.category);
    try std.testing.expectEqualStrings("$3.99/gal", poi.subtitle.?);
}

test "Maneuver init" {
    const maneuver = Maneuver.init("Turn right onto Main St", 500, .turn_right);
    try std.testing.expectEqualStrings("Turn right onto Main St", maneuver.instruction);
    try std.testing.expectEqual(@as(u32, 500), maneuver.distance_meters);
}

test "Maneuver formatDistance" {
    var buffer: [32]u8 = undefined;

    const short = Maneuver.init("Turn", 500, .turn_right);
    try std.testing.expectEqualStrings("500 m", short.formatDistance(&buffer));

    const long = Maneuver.init("Continue", 5000, .straight);
    try std.testing.expectEqualStrings("5.0 km", long.formatDistance(&buffer));
}

test "TripInfo init" {
    const trip = TripInfo.init("Home");
    try std.testing.expectEqualStrings("Home", trip.destination_name);
}

test "TripInfo formatRemainingTime" {
    var buffer: [32]u8 = undefined;

    var trip = TripInfo.init("Dest");
    trip.remaining_time_seconds = 3900; // 1h 5m

    try std.testing.expectEqualStrings("1h 5m", trip.formatRemainingTime(&buffer));

    trip.remaining_time_seconds = 600; // 10m
    try std.testing.expectEqualStrings("10 min", trip.formatRemainingTime(&buffer));
}

test "AlertAction styles" {
    const default_action = AlertAction.init("ok", "OK");
    try std.testing.expectEqual(AlertAction.AlertStyle.default, default_action.style);

    const cancel_action = AlertAction.cancel("cancel", "Cancel");
    try std.testing.expectEqual(AlertAction.AlertStyle.cancel, cancel_action.style);

    const destructive_action = AlertAction.destructive("delete", "Delete");
    try std.testing.expectEqual(AlertAction.AlertStyle.destructive, destructive_action.style);
}

test "AutomotiveEvent create" {
    const event = AutomotiveEvent.create(.connected);
    try std.testing.expectEqual(AutomotiveEventType.connected, event.event_type);
}

test "AutomotiveEvent forItem" {
    const event = AutomotiveEvent.forItem(.list_item_selected, "item_1");
    try std.testing.expectEqual(AutomotiveEventType.list_item_selected, event.event_type);
    try std.testing.expectEqualStrings("item_1", event.item_id.?);
}

test "AutomotiveEvent forSearch" {
    const event = AutomotiveEvent.forSearch("coffee");
    try std.testing.expectEqual(AutomotiveEventType.search_query_changed, event.event_type);
    try std.testing.expectEqualStrings("coffee", event.search_query.?);
}

test "ScreenInfo init" {
    const screen = ScreenInfo.init();
    try std.testing.expectEqual(@as(u32, 800), screen.width);
    try std.testing.expectEqual(@as(u32, 480), screen.height);
}

test "ScreenInfo aspectRatio" {
    const screen = ScreenInfo.init();
    try std.testing.expectApproxEqAbs(@as(f32, 1.666), screen.aspectRatio(), 0.01);
}

test "ScreenInfo usable dimensions" {
    var screen = ScreenInfo.init();
    screen.safe_area_insets = .{ .top = 20, .bottom = 20, .left = 10, .right = 10 };

    try std.testing.expectEqual(@as(u32, 780), screen.getUsableWidth());
    try std.testing.expectEqual(@as(u32, 440), screen.getUsableHeight());
}

test "AutomotiveSession init and deinit" {
    const allocator = std.testing.allocator;
    var session = AutomotiveSession.init(allocator, .audio);
    defer session.deinit();

    try std.testing.expectEqual(AppCategory.audio, session.app_category);
    try std.testing.expect(!session.isConnected());
}

test "AutomotiveSession connect" {
    const allocator = std.testing.allocator;
    var session = AutomotiveSession.init(allocator, .audio);
    defer session.deinit();

    session.connect(.carplay, .wireless);
    try std.testing.expectEqual(AutomotivePlatform.carplay, session.platform);
    try std.testing.expectEqual(ConnectionType.wireless, session.connection_type);
    try std.testing.expectEqual(ConnectionState.connecting, session.connection_state);
}

test "AutomotiveSession setConnected" {
    const allocator = std.testing.allocator;
    var session = AutomotiveSession.init(allocator, .audio);
    defer session.deinit();

    session.connect(.android_auto, .usb);
    session.setConnected(ScreenInfo.init());

    try std.testing.expect(session.isConnected());
}

test "AutomotiveSession templates" {
    const allocator = std.testing.allocator;
    var session = AutomotiveSession.init(allocator, .audio);
    defer session.deinit();

    try session.pushTemplate(.now_playing);
    try session.pushTemplate(.list);

    try std.testing.expectEqual(@as(usize, 2), session.getTemplateStackDepth());
    try std.testing.expectEqual(TemplateType.list, session.getCurrentTemplate().?);

    _ = session.popTemplate();
    try std.testing.expectEqual(TemplateType.now_playing, session.getCurrentTemplate().?);
}

test "AutomotiveSession nowPlaying" {
    const allocator = std.testing.allocator;
    var session = AutomotiveSession.init(allocator, .audio);
    defer session.deinit();

    session.setNowPlaying(NowPlayingInfo.init("Test Song"));
    try std.testing.expect(session.now_playing != null);

    session.clearNowPlaying();
    try std.testing.expect(session.now_playing == null);
}

test "AutomotiveSession tripInfo" {
    const allocator = std.testing.allocator;
    var session = AutomotiveSession.init(allocator, .navigation);
    defer session.deinit();

    session.setTripInfo(TripInfo.init("Home"));
    try std.testing.expect(session.trip_info != null);

    session.clearTripInfo();
    try std.testing.expect(session.trip_info == null);
}

test "formatDuration" {
    var buffer: [32]u8 = undefined;

    try std.testing.expectEqualStrings("0:00", formatDuration(0, &buffer));
    try std.testing.expectEqualStrings("3:00", formatDuration(180000, &buffer));
    try std.testing.expectEqualStrings("1:30:00", formatDuration(5400000, &buffer));
}

test "ManeuverType symbol" {
    try std.testing.expectEqualStrings("arrow.up", Maneuver.ManeuverType.straight.symbol());
    try std.testing.expectEqualStrings("arrow.turn.up.left", Maneuver.ManeuverType.turn_left.symbol());
}

test "POICategory icon" {
    try std.testing.expectEqualStrings("fork.knife", PointOfInterest.POICategory.restaurant.icon());
    try std.testing.expectEqualStrings("fuelpump", PointOfInterest.POICategory.gas_station.icon());
}
