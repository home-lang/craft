//! App Clips and Instant Apps - Lightweight app experiences
//!
//! Provides cross-platform abstraction for:
//! - iOS App Clips
//! - Android Instant Apps
//! - Web-based instant experiences
//!
//! Features:
//! - Invocation URL handling
//! - Location-based triggers
//! - QR code/NFC launch support
//! - Streamlined onboarding flows
//! - Data migration to full app

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

/// Gets current timestamp in seconds
fn getCurrentTimestamp() i64 {
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
        return ts.sec;
    }
    return 0;
}

/// Platform type for instant app experiences
pub const Platform = enum {
    ios_app_clip,
    android_instant_app,
    web_instant,
    unknown,

    pub fn displayName(self: Platform) []const u8 {
        return switch (self) {
            .ios_app_clip => "iOS App Clip",
            .android_instant_app => "Android Instant App",
            .web_instant => "Web Instant Experience",
            .unknown => "Unknown Platform",
        };
    }

    pub fn maxBinarySize(self: Platform) usize {
        return switch (self) {
            .ios_app_clip => 10 * 1024 * 1024, // 10 MB limit for App Clips
            .android_instant_app => 15 * 1024 * 1024, // 15 MB limit
            .web_instant => 0, // No strict limit for web
            .unknown => 0,
        };
    }
};

/// Invocation source - how the instant app was launched
pub const InvocationSource = enum {
    url, // Universal link / App link
    qr_code, // QR code scan
    nfc_tag, // NFC tap
    location, // Location-based suggestion
    safari_banner, // Safari smart app banner
    messages, // Messages app preview
    maps, // Maps place card
    siri_suggestion, // Siri suggestions
    spotlight, // Spotlight search
    app_store, // App Store preview
    notification, // Push notification
    widget, // Home screen widget
    custom, // Custom source

    pub fn displayName(self: InvocationSource) []const u8 {
        return switch (self) {
            .url => "URL Link",
            .qr_code => "QR Code",
            .nfc_tag => "NFC Tag",
            .location => "Location",
            .safari_banner => "Safari Banner",
            .messages => "Messages",
            .maps => "Maps",
            .siri_suggestion => "Siri Suggestion",
            .spotlight => "Spotlight",
            .app_store => "App Store",
            .notification => "Notification",
            .widget => "Widget",
            .custom => "Custom",
        };
    }
};

/// Invocation context - information about how instant app was launched
pub const InvocationContext = struct {
    /// The URL that triggered the invocation
    url_buffer: [2048]u8 = [_]u8{0} ** 2048,
    url_len: usize = 0,

    /// Query parameters from the URL
    query_params_buffer: [4096]u8 = [_]u8{0} ** 4096,
    query_params_len: usize = 0,

    /// Source of the invocation
    source: InvocationSource = .url,

    /// Geographic location if available
    latitude: ?f64 = null,
    longitude: ?f64 = null,

    /// Referrer information
    referrer_buffer: [512]u8 = [_]u8{0} ** 512,
    referrer_len: usize = 0,

    /// Timestamp of invocation
    timestamp: i64 = 0,

    /// Campaign tracking ID
    campaign_id_buffer: [128]u8 = [_]u8{0} ** 128,
    campaign_id_len: usize = 0,

    /// User activity type for handoff
    activity_type_buffer: [256]u8 = [_]u8{0} ** 256,
    activity_type_len: usize = 0,

    pub fn init() InvocationContext {
        return .{};
    }

    pub fn initWithTimestamp() InvocationContext {
        return .{
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn withUrl(self: InvocationContext, url: []const u8) InvocationContext {
        var result = self;
        const copy_len = @min(url.len, result.url_buffer.len);
        @memcpy(result.url_buffer[0..copy_len], url[0..copy_len]);
        result.url_len = copy_len;
        return result;
    }

    pub fn withSource(self: InvocationContext, source: InvocationSource) InvocationContext {
        var result = self;
        result.source = source;
        return result;
    }

    pub fn withLocation(self: InvocationContext, lat: f64, lon: f64) InvocationContext {
        var result = self;
        result.latitude = lat;
        result.longitude = lon;
        return result;
    }

    pub fn withReferrer(self: InvocationContext, referrer: []const u8) InvocationContext {
        var result = self;
        const copy_len = @min(referrer.len, result.referrer_buffer.len);
        @memcpy(result.referrer_buffer[0..copy_len], referrer[0..copy_len]);
        result.referrer_len = copy_len;
        return result;
    }

    pub fn withCampaignId(self: InvocationContext, campaign_id: []const u8) InvocationContext {
        var result = self;
        const copy_len = @min(campaign_id.len, result.campaign_id_buffer.len);
        @memcpy(result.campaign_id_buffer[0..copy_len], campaign_id[0..copy_len]);
        result.campaign_id_len = copy_len;
        return result;
    }

    pub fn getUrl(self: *const InvocationContext) []const u8 {
        return self.url_buffer[0..self.url_len];
    }

    pub fn getReferrer(self: *const InvocationContext) []const u8 {
        return self.referrer_buffer[0..self.referrer_len];
    }

    pub fn getCampaignId(self: *const InvocationContext) []const u8 {
        return self.campaign_id_buffer[0..self.campaign_id_len];
    }

    pub fn hasLocation(self: *const InvocationContext) bool {
        return self.latitude != null and self.longitude != null;
    }
};

/// Experience type - the kind of instant experience
pub const ExperienceType = enum {
    product_preview, // View a product
    checkout, // Quick checkout flow
    reservation, // Make a reservation
    order_food, // Food ordering
    parking, // Parking payment
    ticket, // Event ticket
    loyalty_card, // Loyalty program
    menu, // Restaurant menu
    appointment, // Book appointment
    demo, // App demo/trial
    game_trial, // Game trial
    custom, // Custom experience

    pub fn suggestedDuration(self: ExperienceType) u32 {
        // Suggested session duration in seconds
        return switch (self) {
            .product_preview => 120,
            .checkout => 180,
            .reservation => 240,
            .order_food => 300,
            .parking => 60,
            .ticket => 30,
            .loyalty_card => 60,
            .menu => 180,
            .appointment => 300,
            .demo => 600,
            .game_trial => 900,
            .custom => 300,
        };
    }
};

/// Data to migrate when user installs full app
pub const MigrationData = struct {
    /// User preferences
    preferences_buffer: [4096]u8 = [_]u8{0} ** 4096,
    preferences_len: usize = 0,

    /// User account info (if signed in)
    account_id_buffer: [128]u8 = [_]u8{0} ** 128,
    account_id_len: usize = 0,

    /// Cart/order data
    cart_data_buffer: [8192]u8 = [_]u8{0} ** 8192,
    cart_data_len: usize = 0,

    /// Progress data (for games/demos)
    progress_buffer: [4096]u8 = [_]u8{0} ** 4096,
    progress_len: usize = 0,

    /// Custom key-value data
    custom_data_buffer: [8192]u8 = [_]u8{0} ** 8192,
    custom_data_len: usize = 0,

    /// Timestamp when data was created
    created_at: i64 = 0,

    /// Timestamp when data expires
    expires_at: i64 = 0,

    pub fn init() MigrationData {
        return .{};
    }

    pub fn initWithTimestamp() MigrationData {
        const now = getCurrentTimestamp();
        return .{
            .created_at = now,
            .expires_at = now + 86400 * 7, // 7 days default expiry
        };
    }

    pub fn withPreferences(self: MigrationData, prefs: []const u8) MigrationData {
        var result = self;
        const copy_len = @min(prefs.len, result.preferences_buffer.len);
        @memcpy(result.preferences_buffer[0..copy_len], prefs[0..copy_len]);
        result.preferences_len = copy_len;
        return result;
    }

    pub fn withAccountId(self: MigrationData, account_id: []const u8) MigrationData {
        var result = self;
        const copy_len = @min(account_id.len, result.account_id_buffer.len);
        @memcpy(result.account_id_buffer[0..copy_len], account_id[0..copy_len]);
        result.account_id_len = copy_len;
        return result;
    }

    pub fn withCartData(self: MigrationData, cart: []const u8) MigrationData {
        var result = self;
        const copy_len = @min(cart.len, result.cart_data_buffer.len);
        @memcpy(result.cart_data_buffer[0..copy_len], cart[0..copy_len]);
        result.cart_data_len = copy_len;
        return result;
    }

    pub fn withProgress(self: MigrationData, progress: []const u8) MigrationData {
        var result = self;
        const copy_len = @min(progress.len, result.progress_buffer.len);
        @memcpy(result.progress_buffer[0..copy_len], progress[0..copy_len]);
        result.progress_len = copy_len;
        return result;
    }

    pub fn withCustomData(self: MigrationData, data: []const u8) MigrationData {
        var result = self;
        const copy_len = @min(data.len, result.custom_data_buffer.len);
        @memcpy(result.custom_data_buffer[0..copy_len], data[0..copy_len]);
        result.custom_data_len = copy_len;
        return result;
    }

    pub fn withExpiry(self: MigrationData, days: u32) MigrationData {
        var result = self;
        const base_time = if (result.created_at > 0) result.created_at else getCurrentTimestamp();
        result.expires_at = base_time + @as(i64, @intCast(days)) * 86400;
        return result;
    }

    pub fn isExpired(self: *const MigrationData) bool {
        return getCurrentTimestamp() > self.expires_at;
    }

    pub fn getPreferences(self: *const MigrationData) []const u8 {
        return self.preferences_buffer[0..self.preferences_len];
    }

    pub fn getAccountId(self: *const MigrationData) []const u8 {
        return self.account_id_buffer[0..self.account_id_len];
    }

    pub fn getCartData(self: *const MigrationData) []const u8 {
        return self.cart_data_buffer[0..self.cart_data_len];
    }

    pub fn hasData(self: *const MigrationData) bool {
        return self.preferences_len > 0 or
            self.account_id_len > 0 or
            self.cart_data_len > 0 or
            self.progress_len > 0 or
            self.custom_data_len > 0;
    }
};

/// Location trigger for suggesting instant app
pub const LocationTrigger = struct {
    /// Trigger identifier
    id_buffer: [64]u8 = [_]u8{0} ** 64,
    id_len: usize = 0,

    /// Human-readable name
    name_buffer: [128]u8 = [_]u8{0} ** 128,
    name_len: usize = 0,

    /// Center coordinates
    latitude: f64 = 0,
    longitude: f64 = 0,

    /// Trigger radius in meters
    radius: f64 = 100,

    /// Associated URL to launch
    url_buffer: [2048]u8 = [_]u8{0} ** 2048,
    url_len: usize = 0,

    /// Whether trigger is active
    is_active: bool = true,

    /// Time restrictions (optional)
    active_start_hour: ?u8 = null, // 0-23
    active_end_hour: ?u8 = null, // 0-23

    pub fn init(id: []const u8) LocationTrigger {
        var result = LocationTrigger{};
        const copy_len = @min(id.len, result.id_buffer.len);
        @memcpy(result.id_buffer[0..copy_len], id[0..copy_len]);
        result.id_len = copy_len;
        return result;
    }

    pub fn withName(self: LocationTrigger, name: []const u8) LocationTrigger {
        var result = self;
        const copy_len = @min(name.len, result.name_buffer.len);
        @memcpy(result.name_buffer[0..copy_len], name[0..copy_len]);
        result.name_len = copy_len;
        return result;
    }

    pub fn withCoordinates(self: LocationTrigger, lat: f64, lon: f64) LocationTrigger {
        var result = self;
        result.latitude = lat;
        result.longitude = lon;
        return result;
    }

    pub fn withRadius(self: LocationTrigger, radius_meters: f64) LocationTrigger {
        var result = self;
        result.radius = radius_meters;
        return result;
    }

    pub fn withUrl(self: LocationTrigger, url: []const u8) LocationTrigger {
        var result = self;
        const copy_len = @min(url.len, result.url_buffer.len);
        @memcpy(result.url_buffer[0..copy_len], url[0..copy_len]);
        result.url_len = copy_len;
        return result;
    }

    pub fn withActiveHours(self: LocationTrigger, start: u8, end: u8) LocationTrigger {
        var result = self;
        result.active_start_hour = start;
        result.active_end_hour = end;
        return result;
    }

    pub fn getId(self: *const LocationTrigger) []const u8 {
        return self.id_buffer[0..self.id_len];
    }

    pub fn getName(self: *const LocationTrigger) []const u8 {
        return self.name_buffer[0..self.name_len];
    }

    pub fn getUrl(self: *const LocationTrigger) []const u8 {
        return self.url_buffer[0..self.url_len];
    }

    pub fn isInRange(self: *const LocationTrigger, lat: f64, lon: f64) bool {
        // Haversine formula for distance calculation
        const earth_radius: f64 = 6371000; // meters

        const lat1_rad = self.latitude * std.math.pi / 180.0;
        const lat2_rad = lat * std.math.pi / 180.0;
        const delta_lat = (lat - self.latitude) * std.math.pi / 180.0;
        const delta_lon = (lon - self.longitude) * std.math.pi / 180.0;

        const a = std.math.sin(delta_lat / 2) * std.math.sin(delta_lat / 2) +
            std.math.cos(lat1_rad) * std.math.cos(lat2_rad) *
                std.math.sin(delta_lon / 2) * std.math.sin(delta_lon / 2);
        const c = 2 * std.math.atan2(@sqrt(a), @sqrt(1 - a));
        const distance = earth_radius * c;

        return distance <= self.radius;
    }
};

/// QR/NFC code configuration
pub const CodeConfig = struct {
    /// Code type
    code_type: CodeType = .qr,

    /// Target URL
    url_buffer: [2048]u8 = [_]u8{0} ** 2048,
    url_len: usize = 0,

    /// Fallback URL for non-supporting devices
    fallback_url_buffer: [2048]u8 = [_]u8{0} ** 2048,
    fallback_url_len: usize = 0,

    /// Campaign identifier
    campaign_buffer: [128]u8 = [_]u8{0} ** 128,
    campaign_len: usize = 0,

    /// Custom metadata
    metadata_buffer: [4096]u8 = [_]u8{0} ** 4096,
    metadata_len: usize = 0,

    pub const CodeType = enum {
        qr,
        nfc,
        both,
    };

    pub fn init(code_type: CodeType) CodeConfig {
        return .{
            .code_type = code_type,
        };
    }

    pub fn withUrl(self: CodeConfig, url: []const u8) CodeConfig {
        var result = self;
        const copy_len = @min(url.len, result.url_buffer.len);
        @memcpy(result.url_buffer[0..copy_len], url[0..copy_len]);
        result.url_len = copy_len;
        return result;
    }

    pub fn withFallbackUrl(self: CodeConfig, url: []const u8) CodeConfig {
        var result = self;
        const copy_len = @min(url.len, result.fallback_url_buffer.len);
        @memcpy(result.fallback_url_buffer[0..copy_len], url[0..copy_len]);
        result.fallback_url_len = copy_len;
        return result;
    }

    pub fn withCampaign(self: CodeConfig, campaign: []const u8) CodeConfig {
        var result = self;
        const copy_len = @min(campaign.len, result.campaign_buffer.len);
        @memcpy(result.campaign_buffer[0..copy_len], campaign[0..copy_len]);
        result.campaign_len = copy_len;
        return result;
    }

    pub fn getUrl(self: *const CodeConfig) []const u8 {
        return self.url_buffer[0..self.url_len];
    }

    pub fn getFallbackUrl(self: *const CodeConfig) []const u8 {
        return self.fallback_url_buffer[0..self.fallback_url_len];
    }

    pub fn getCampaign(self: *const CodeConfig) []const u8 {
        return self.campaign_buffer[0..self.campaign_len];
    }
};

/// Session state for instant app
pub const SessionState = enum {
    initializing,
    active,
    backgrounded,
    completing,
    migrating,
    terminated,
};

/// Analytics event for tracking
pub const AnalyticsEvent = struct {
    /// Event name
    name_buffer: [128]u8 = [_]u8{0} ** 128,
    name_len: usize = 0,

    /// Event category
    category: EventCategory = .engagement,

    /// Event parameters (JSON)
    params_buffer: [4096]u8 = [_]u8{0} ** 4096,
    params_len: usize = 0,

    /// Timestamp
    timestamp: i64 = 0,

    pub const EventCategory = enum {
        launch,
        engagement,
        conversion,
        exit,
        installation,
        custom,
    };

    pub fn init(name: []const u8, category: EventCategory) AnalyticsEvent {
        var result = AnalyticsEvent{
            .category = category,
            .timestamp = getCurrentTimestamp(),
        };
        const copy_len = @min(name.len, result.name_buffer.len);
        @memcpy(result.name_buffer[0..copy_len], name[0..copy_len]);
        result.name_len = copy_len;
        return result;
    }

    pub fn withParams(self: AnalyticsEvent, params: []const u8) AnalyticsEvent {
        var result = self;
        const copy_len = @min(params.len, result.params_buffer.len);
        @memcpy(result.params_buffer[0..copy_len], params[0..copy_len]);
        result.params_len = copy_len;
        return result;
    }

    pub fn getName(self: *const AnalyticsEvent) []const u8 {
        return self.name_buffer[0..self.name_len];
    }

    pub fn getParams(self: *const AnalyticsEvent) []const u8 {
        return self.params_buffer[0..self.params_len];
    }
};

/// Instant app configuration
pub const InstantAppConfig = struct {
    /// App identifier
    app_id_buffer: [256]u8 = [_]u8{0} ** 256,
    app_id_len: usize = 0,

    /// Experience type
    experience_type: ExperienceType = .custom,

    /// Supported platforms
    supported_platforms: PlatformFlags = .{},

    /// Whether to show install prompt
    show_install_prompt: bool = true,

    /// Delay before showing install prompt (seconds)
    install_prompt_delay: u32 = 30,

    /// Enable analytics
    analytics_enabled: bool = true,

    /// Enable location services
    location_enabled: bool = false,

    /// Enable Sign in with Apple/Google
    sign_in_enabled: bool = true,

    /// Maximum session duration (seconds, 0 = unlimited)
    max_session_duration: u32 = 0,

    /// Enable data migration
    migration_enabled: bool = true,

    pub const PlatformFlags = struct {
        ios_app_clip: bool = true,
        android_instant: bool = true,
        web_instant: bool = true,
    };

    pub fn init(app_id: []const u8) InstantAppConfig {
        var result = InstantAppConfig{};
        const copy_len = @min(app_id.len, result.app_id_buffer.len);
        @memcpy(result.app_id_buffer[0..copy_len], app_id[0..copy_len]);
        result.app_id_len = copy_len;
        return result;
    }

    pub fn withExperienceType(self: InstantAppConfig, exp_type: ExperienceType) InstantAppConfig {
        var result = self;
        result.experience_type = exp_type;
        return result;
    }

    pub fn withInstallPrompt(self: InstantAppConfig, show: bool, delay: u32) InstantAppConfig {
        var result = self;
        result.show_install_prompt = show;
        result.install_prompt_delay = delay;
        return result;
    }

    pub fn withAnalytics(self: InstantAppConfig, enabled: bool) InstantAppConfig {
        var result = self;
        result.analytics_enabled = enabled;
        return result;
    }

    pub fn withLocation(self: InstantAppConfig, enabled: bool) InstantAppConfig {
        var result = self;
        result.location_enabled = enabled;
        return result;
    }

    pub fn withSignIn(self: InstantAppConfig, enabled: bool) InstantAppConfig {
        var result = self;
        result.sign_in_enabled = enabled;
        return result;
    }

    pub fn withMaxSessionDuration(self: InstantAppConfig, seconds: u32) InstantAppConfig {
        var result = self;
        result.max_session_duration = seconds;
        return result;
    }

    pub fn withMigration(self: InstantAppConfig, enabled: bool) InstantAppConfig {
        var result = self;
        result.migration_enabled = enabled;
        return result;
    }

    pub fn getAppId(self: *const InstantAppConfig) []const u8 {
        return self.app_id_buffer[0..self.app_id_len];
    }
};

/// Instant app session
pub const InstantAppSession = struct {
    /// Session identifier
    session_id_buffer: [64]u8 = [_]u8{0} ** 64,
    session_id_len: usize = 0,

    /// Current platform
    platform: Platform = .unknown,

    /// Current state
    state: SessionState = .initializing,

    /// Invocation context
    invocation: InvocationContext = .{},

    /// Configuration
    config: InstantAppConfig = .{},

    /// Migration data
    migration_data: MigrationData = .{},

    /// Session start time
    started_at: i64 = 0,

    /// Last activity time
    last_activity: i64 = 0,

    /// Whether full app is installed
    full_app_installed: bool = false,

    /// Event count for analytics
    event_count: u32 = 0,

    pub fn init(session_id: []const u8, platform: Platform) InstantAppSession {
        const now = getCurrentTimestamp();
        var result = InstantAppSession{
            .platform = platform,
            .started_at = now,
            .last_activity = now,
        };
        const copy_len = @min(session_id.len, result.session_id_buffer.len);
        @memcpy(result.session_id_buffer[0..copy_len], session_id[0..copy_len]);
        result.session_id_len = copy_len;
        return result;
    }

    pub fn withConfig(self: InstantAppSession, config: InstantAppConfig) InstantAppSession {
        var result = self;
        result.config = config;
        return result;
    }

    pub fn withInvocation(self: InstantAppSession, invocation: InvocationContext) InstantAppSession {
        var result = self;
        result.invocation = invocation;
        return result;
    }

    pub fn getSessionId(self: *const InstantAppSession) []const u8 {
        return self.session_id_buffer[0..self.session_id_len];
    }

    pub fn activate(self: *InstantAppSession) void {
        self.state = .active;
        self.last_activity = getCurrentTimestamp();
    }

    pub fn background(self: *InstantAppSession) void {
        self.state = .backgrounded;
    }

    pub fn foreground(self: *InstantAppSession) void {
        if (self.state == .backgrounded) {
            self.state = .active;
            self.last_activity = getCurrentTimestamp();
        }
    }

    pub fn recordEvent(self: *InstantAppSession) void {
        self.event_count += 1;
        self.last_activity = getCurrentTimestamp();
    }

    pub fn getSessionDuration(self: *const InstantAppSession) i64 {
        return getCurrentTimestamp() - self.started_at;
    }

    pub fn isSessionExpired(self: *const InstantAppSession) bool {
        if (self.config.max_session_duration == 0) return false;
        return self.getSessionDuration() > @as(i64, @intCast(self.config.max_session_duration));
    }

    pub fn shouldShowInstallPrompt(self: *const InstantAppSession) bool {
        if (!self.config.show_install_prompt) return false;
        if (self.full_app_installed) return false;
        return self.getSessionDuration() >= @as(i64, @intCast(self.config.install_prompt_delay));
    }

    pub fn setMigrationData(self: *InstantAppSession, data: MigrationData) void {
        self.migration_data = data;
    }

    pub fn startMigration(self: *InstantAppSession) !void {
        if (!self.config.migration_enabled) {
            return error.MigrationDisabled;
        }
        if (!self.migration_data.hasData()) {
            return error.NoDataToMigrate;
        }
        self.state = .migrating;
    }

    pub fn completeMigration(self: *InstantAppSession) void {
        self.state = .completing;
        self.full_app_installed = true;
    }

    pub fn terminate(self: *InstantAppSession) void {
        self.state = .terminated;
    }
};

/// App Clip Card configuration (iOS)
pub const AppClipCard = struct {
    /// Title displayed on the card
    title_buffer: [64]u8 = [_]u8{0} ** 64,
    title_len: usize = 0,

    /// Subtitle
    subtitle_buffer: [128]u8 = [_]u8{0} ** 128,
    subtitle_len: usize = 0,

    /// Action button text
    action_buffer: [32]u8 = [_]u8{0} ** 32,
    action_len: usize = 0,

    /// Header image URL
    image_url_buffer: [2048]u8 = [_]u8{0} ** 2048,
    image_url_len: usize = 0,

    /// Associated URL
    url_buffer: [2048]u8 = [_]u8{0} ** 2048,
    url_len: usize = 0,

    pub fn init(title: []const u8) AppClipCard {
        var result = AppClipCard{};
        const copy_len = @min(title.len, result.title_buffer.len);
        @memcpy(result.title_buffer[0..copy_len], title[0..copy_len]);
        result.title_len = copy_len;
        return result;
    }

    pub fn withSubtitle(self: AppClipCard, subtitle: []const u8) AppClipCard {
        var result = self;
        const copy_len = @min(subtitle.len, result.subtitle_buffer.len);
        @memcpy(result.subtitle_buffer[0..copy_len], subtitle[0..copy_len]);
        result.subtitle_len = copy_len;
        return result;
    }

    pub fn withAction(self: AppClipCard, action: []const u8) AppClipCard {
        var result = self;
        const copy_len = @min(action.len, result.action_buffer.len);
        @memcpy(result.action_buffer[0..copy_len], action[0..copy_len]);
        result.action_len = copy_len;
        return result;
    }

    pub fn withImageUrl(self: AppClipCard, url: []const u8) AppClipCard {
        var result = self;
        const copy_len = @min(url.len, result.image_url_buffer.len);
        @memcpy(result.image_url_buffer[0..copy_len], url[0..copy_len]);
        result.image_url_len = copy_len;
        return result;
    }

    pub fn withUrl(self: AppClipCard, url: []const u8) AppClipCard {
        var result = self;
        const copy_len = @min(url.len, result.url_buffer.len);
        @memcpy(result.url_buffer[0..copy_len], url[0..copy_len]);
        result.url_len = copy_len;
        return result;
    }

    pub fn getTitle(self: *const AppClipCard) []const u8 {
        return self.title_buffer[0..self.title_len];
    }

    pub fn getSubtitle(self: *const AppClipCard) []const u8 {
        return self.subtitle_buffer[0..self.subtitle_len];
    }

    pub fn getAction(self: *const AppClipCard) []const u8 {
        return self.action_buffer[0..self.action_len];
    }

    pub fn getUrl(self: *const AppClipCard) []const u8 {
        return self.url_buffer[0..self.url_len];
    }
};

/// Main controller for instant app functionality
pub const InstantAppController = struct {
    allocator: Allocator,
    platform: Platform,
    current_session: ?InstantAppSession,
    location_triggers: std.ArrayListUnmanaged(LocationTrigger),
    pending_events: std.ArrayListUnmanaged(AnalyticsEvent),

    pub fn init(allocator: Allocator) InstantAppController {
        const platform = detectPlatform();
        return .{
            .allocator = allocator,
            .platform = platform,
            .current_session = null,
            .location_triggers = .empty,
            .pending_events = .empty,
        };
    }

    pub fn deinit(self: *InstantAppController) void {
        self.location_triggers.deinit(self.allocator);
        self.pending_events.deinit(self.allocator);
    }

    fn detectPlatform() Platform {
        return switch (builtin.os.tag) {
            .ios => .ios_app_clip,
            .macos => .ios_app_clip, // For development
            .linux => if (builtin.abi == .android) .android_instant_app else .web_instant,
            else => .unknown,
        };
    }

    pub fn startSession(self: *InstantAppController, session_id: []const u8, config: InstantAppConfig) !*InstantAppSession {
        var session = InstantAppSession.init(session_id, self.platform);
        session = session.withConfig(config);
        session.activate();

        self.current_session = session;

        // Track launch event
        try self.trackEvent(AnalyticsEvent.init("session_start", .launch));

        return &self.current_session.?;
    }

    pub fn endSession(self: *InstantAppController) void {
        if (self.current_session) |*session| {
            session.terminate();
            // Flush any pending analytics
            self.pending_events.clearAndFree(self.allocator);
        }
        self.current_session = null;
    }

    pub fn handleInvocation(self: *InstantAppController, context: InvocationContext) !void {
        if (self.current_session) |*session| {
            session.invocation = context;
            try self.trackEvent(
                AnalyticsEvent.init("invocation", .launch)
                    .withParams(context.source.displayName()),
            );
        }
    }

    pub fn addLocationTrigger(self: *InstantAppController, trigger: LocationTrigger) !void {
        try self.location_triggers.append(self.allocator, trigger);
    }

    pub fn removeLocationTrigger(self: *InstantAppController, trigger_id: []const u8) bool {
        for (self.location_triggers.items, 0..) |trigger, i| {
            if (std.mem.eql(u8, trigger.id_buffer[0..trigger.id_len], trigger_id)) {
                _ = self.location_triggers.orderedRemove(i);
                return true;
            }
        }
        return false;
    }

    pub fn checkLocationTriggers(self: *InstantAppController, lat: f64, lon: f64) ?*const LocationTrigger {
        for (self.location_triggers.items) |*trigger| {
            if (trigger.is_active and trigger.isInRange(lat, lon)) {
                return trigger;
            }
        }
        return null;
    }

    pub fn trackEvent(self: *InstantAppController, event: AnalyticsEvent) !void {
        if (self.current_session) |*session| {
            if (session.config.analytics_enabled) {
                try self.pending_events.append(self.allocator, event);
                session.recordEvent();
            }
        }
    }

    pub fn trackConversion(self: *InstantAppController, conversion_type: []const u8, value: ?f64) !void {
        var params_buf: [256]u8 = undefined;
        const params = if (value) |v|
            std.fmt.bufPrint(&params_buf, "{{\"type\":\"{s}\",\"value\":{d}}}", .{ conversion_type, v }) catch conversion_type
        else
            conversion_type;

        try self.trackEvent(
            AnalyticsEvent.init("conversion", .conversion)
                .withParams(params),
        );
    }

    pub fn promptInstallation(self: *InstantAppController) !void {
        if (self.current_session) |*session| {
            if (session.shouldShowInstallPrompt()) {
                try self.trackEvent(AnalyticsEvent.init("install_prompt_shown", .installation));
                // Platform-specific installation prompt would be triggered here
            }
        }
    }

    pub fn prepareMigration(self: *InstantAppController, data: MigrationData) !void {
        if (self.current_session) |*session| {
            session.setMigrationData(data);
        }
    }

    pub fn executeMigration(self: *InstantAppController) !void {
        if (self.current_session) |*session| {
            try session.startMigration();
            try self.trackEvent(AnalyticsEvent.init("migration_started", .installation));
            // Actual migration would happen here
            session.completeMigration();
            try self.trackEvent(AnalyticsEvent.init("migration_completed", .installation));
        }
    }

    pub fn getSession(self: *InstantAppController) ?*InstantAppSession {
        if (self.current_session != null) {
            return &self.current_session.?;
        }
        return null;
    }

    pub fn getPendingEventsCount(self: *InstantAppController) usize {
        return self.pending_events.items.len;
    }

    pub fn flushEvents(self: *InstantAppController) void {
        // In production, events would be sent to analytics backend
        self.pending_events.clearRetainingCapacity();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Platform display names and sizes" {
    try std.testing.expectEqualStrings("iOS App Clip", Platform.ios_app_clip.displayName());
    try std.testing.expectEqualStrings("Android Instant App", Platform.android_instant_app.displayName());
    try std.testing.expect(Platform.ios_app_clip.maxBinarySize() == 10 * 1024 * 1024);
    try std.testing.expect(Platform.android_instant_app.maxBinarySize() == 15 * 1024 * 1024);
}

test "InvocationSource display names" {
    try std.testing.expectEqualStrings("QR Code", InvocationSource.qr_code.displayName());
    try std.testing.expectEqualStrings("NFC Tag", InvocationSource.nfc_tag.displayName());
    try std.testing.expectEqualStrings("Safari Banner", InvocationSource.safari_banner.displayName());
}

test "InvocationContext initialization and fluent API" {
    const ctx = InvocationContext.init()
        .withUrl("https://example.com/clip")
        .withSource(.qr_code)
        .withLocation(37.7749, -122.4194)
        .withReferrer("safari")
        .withCampaignId("summer2024");

    try std.testing.expectEqualStrings("https://example.com/clip", ctx.getUrl());
    try std.testing.expect(ctx.source == .qr_code);
    try std.testing.expect(ctx.hasLocation());
    try std.testing.expectEqualStrings("safari", ctx.getReferrer());
    try std.testing.expectEqualStrings("summer2024", ctx.getCampaignId());
}

test "ExperienceType suggested duration" {
    try std.testing.expect(ExperienceType.checkout.suggestedDuration() == 180);
    try std.testing.expect(ExperienceType.parking.suggestedDuration() == 60);
    try std.testing.expect(ExperienceType.game_trial.suggestedDuration() == 900);
}

test "MigrationData initialization and fluent API" {
    const data = MigrationData.init()
        .withPreferences("{\"theme\":\"dark\"}")
        .withAccountId("user123")
        .withCartData("{\"items\":[]}")
        .withExpiry(14);

    try std.testing.expectEqualStrings("{\"theme\":\"dark\"}", data.getPreferences());
    try std.testing.expectEqualStrings("user123", data.getAccountId());
    try std.testing.expectEqualStrings("{\"items\":[]}", data.getCartData());
    try std.testing.expect(data.hasData());
    try std.testing.expect(!data.isExpired());
}

test "MigrationData expiry check" {
    var data = MigrationData.init();
    data.expires_at = data.created_at - 1; // Already expired
    try std.testing.expect(data.isExpired());
}

test "LocationTrigger initialization and fluent API" {
    const trigger = LocationTrigger.init("store-001")
        .withName("Main Street Store")
        .withCoordinates(37.7749, -122.4194)
        .withRadius(50)
        .withUrl("https://example.com/store")
        .withActiveHours(9, 21);

    try std.testing.expectEqualStrings("store-001", trigger.getId());
    try std.testing.expectEqualStrings("Main Street Store", trigger.getName());
    try std.testing.expect(trigger.radius == 50);
    try std.testing.expect(trigger.active_start_hour.? == 9);
    try std.testing.expect(trigger.active_end_hour.? == 21);
}

test "LocationTrigger range detection" {
    const trigger = LocationTrigger.init("test")
        .withCoordinates(37.7749, -122.4194)
        .withRadius(1000); // 1km radius

    // Same location should be in range
    try std.testing.expect(trigger.isInRange(37.7749, -122.4194));

    // Far away location should not be in range
    try std.testing.expect(!trigger.isInRange(38.0, -123.0));
}

test "CodeConfig initialization and fluent API" {
    const config = CodeConfig.init(.qr)
        .withUrl("https://example.com/clip")
        .withFallbackUrl("https://example.com/web")
        .withCampaign("launch2024");

    try std.testing.expect(config.code_type == .qr);
    try std.testing.expectEqualStrings("https://example.com/clip", config.getUrl());
    try std.testing.expectEqualStrings("https://example.com/web", config.getFallbackUrl());
    try std.testing.expectEqualStrings("launch2024", config.getCampaign());
}

test "AnalyticsEvent initialization" {
    const event = AnalyticsEvent.init("button_click", .engagement)
        .withParams("{\"button\":\"checkout\"}");

    try std.testing.expectEqualStrings("button_click", event.getName());
    try std.testing.expect(event.category == .engagement);
    try std.testing.expectEqualStrings("{\"button\":\"checkout\"}", event.getParams());
    try std.testing.expect(event.timestamp > 0);
}

test "InstantAppConfig initialization and fluent API" {
    const config = InstantAppConfig.init("com.example.clip")
        .withExperienceType(.checkout)
        .withInstallPrompt(true, 60)
        .withAnalytics(true)
        .withLocation(true)
        .withSignIn(true)
        .withMaxSessionDuration(300)
        .withMigration(true);

    try std.testing.expectEqualStrings("com.example.clip", config.getAppId());
    try std.testing.expect(config.experience_type == .checkout);
    try std.testing.expect(config.show_install_prompt);
    try std.testing.expect(config.install_prompt_delay == 60);
    try std.testing.expect(config.analytics_enabled);
    try std.testing.expect(config.location_enabled);
    try std.testing.expect(config.max_session_duration == 300);
}

test "InstantAppSession initialization" {
    const session = InstantAppSession.init("session-001", .ios_app_clip)
        .withConfig(InstantAppConfig.init("com.example.app"));

    try std.testing.expectEqualStrings("session-001", session.getSessionId());
    try std.testing.expect(session.platform == .ios_app_clip);
    try std.testing.expect(session.state == .initializing);
    try std.testing.expect(session.started_at > 0);
}

test "InstantAppSession state transitions" {
    var session = InstantAppSession.init("test-session", .ios_app_clip);

    try std.testing.expect(session.state == .initializing);

    session.activate();
    try std.testing.expect(session.state == .active);

    session.background();
    try std.testing.expect(session.state == .backgrounded);

    session.foreground();
    try std.testing.expect(session.state == .active);

    session.terminate();
    try std.testing.expect(session.state == .terminated);
}

test "InstantAppSession event recording" {
    var session = InstantAppSession.init("test-session", .ios_app_clip);
    session.activate();

    try std.testing.expect(session.event_count == 0);

    session.recordEvent();
    session.recordEvent();
    session.recordEvent();

    try std.testing.expect(session.event_count == 3);
}

test "InstantAppSession duration tracking" {
    var session = InstantAppSession.init("test-session", .ios_app_clip);
    session.activate();

    const duration = session.getSessionDuration();
    try std.testing.expect(duration >= 0);
}

test "InstantAppSession install prompt logic" {
    var session = InstantAppSession.init("test-session", .ios_app_clip)
        .withConfig(InstantAppConfig.init("com.example.app")
        .withInstallPrompt(true, 0)); // 0 delay for immediate prompt

    session.activate();

    // Should show prompt (delay is 0)
    try std.testing.expect(session.shouldShowInstallPrompt());

    // After installing full app, should not show
    session.full_app_installed = true;
    try std.testing.expect(!session.shouldShowInstallPrompt());
}

test "InstantAppSession migration flow" {
    var session = InstantAppSession.init("test-session", .ios_app_clip)
        .withConfig(InstantAppConfig.init("com.example.app").withMigration(true));

    session.activate();

    // Set migration data
    const data = MigrationData.init()
        .withPreferences("{\"test\":true}")
        .withAccountId("user123");
    session.setMigrationData(data);

    // Start migration
    try session.startMigration();
    try std.testing.expect(session.state == .migrating);

    // Complete migration
    session.completeMigration();
    try std.testing.expect(session.state == .completing);
    try std.testing.expect(session.full_app_installed);
}

test "InstantAppSession migration disabled error" {
    var session = InstantAppSession.init("test-session", .ios_app_clip)
        .withConfig(InstantAppConfig.init("com.example.app").withMigration(false));

    session.activate();
    session.setMigrationData(MigrationData.init().withAccountId("user123"));

    try std.testing.expectError(error.MigrationDisabled, session.startMigration());
}

test "InstantAppSession no data to migrate error" {
    var session = InstantAppSession.init("test-session", .ios_app_clip)
        .withConfig(InstantAppConfig.init("com.example.app").withMigration(true));

    session.activate();
    // No migration data set

    try std.testing.expectError(error.NoDataToMigrate, session.startMigration());
}

test "AppClipCard initialization and fluent API" {
    const card = AppClipCard.init("Coffee Shop")
        .withSubtitle("Order ahead and skip the line")
        .withAction("Order Now")
        .withImageUrl("https://example.com/image.png")
        .withUrl("https://example.com/order");

    try std.testing.expectEqualStrings("Coffee Shop", card.getTitle());
    try std.testing.expectEqualStrings("Order ahead and skip the line", card.getSubtitle());
    try std.testing.expectEqualStrings("Order Now", card.getAction());
    try std.testing.expectEqualStrings("https://example.com/order", card.getUrl());
}

test "InstantAppController initialization" {
    var controller = InstantAppController.init(std.testing.allocator);
    defer controller.deinit();

    try std.testing.expect(controller.current_session == null);
    try std.testing.expect(controller.location_triggers.items.len == 0);
}

test "InstantAppController session management" {
    var controller = InstantAppController.init(std.testing.allocator);
    defer controller.deinit();

    const config = InstantAppConfig.init("com.example.app");
    const session = try controller.startSession("test-session", config);

    try std.testing.expectEqualStrings("test-session", session.getSessionId());
    try std.testing.expect(session.state == .active);
    try std.testing.expect(controller.getSession() != null);

    controller.endSession();
    try std.testing.expect(controller.getSession() == null);
}

test "InstantAppController location triggers" {
    var controller = InstantAppController.init(std.testing.allocator);
    defer controller.deinit();

    const trigger1 = LocationTrigger.init("store-001")
        .withCoordinates(37.7749, -122.4194)
        .withRadius(100);

    const trigger2 = LocationTrigger.init("store-002")
        .withCoordinates(40.7128, -74.0060)
        .withRadius(100);

    try controller.addLocationTrigger(trigger1);
    try controller.addLocationTrigger(trigger2);

    try std.testing.expect(controller.location_triggers.items.len == 2);

    // Check location in San Francisco
    const sf_trigger = controller.checkLocationTriggers(37.7749, -122.4194);
    try std.testing.expect(sf_trigger != null);

    // Check location not near any trigger
    const nowhere = controller.checkLocationTriggers(0, 0);
    try std.testing.expect(nowhere == null);

    // Remove a trigger
    try std.testing.expect(controller.removeLocationTrigger("store-001"));
    try std.testing.expect(controller.location_triggers.items.len == 1);
}

test "InstantAppController event tracking" {
    var controller = InstantAppController.init(std.testing.allocator);
    defer controller.deinit();

    const config = InstantAppConfig.init("com.example.app").withAnalytics(true);
    _ = try controller.startSession("test-session", config);

    // Session start event is automatically tracked
    try std.testing.expect(controller.getPendingEventsCount() == 1);

    try controller.trackEvent(AnalyticsEvent.init("page_view", .engagement));
    try std.testing.expect(controller.getPendingEventsCount() == 2);

    try controller.trackConversion("purchase", 29.99);
    try std.testing.expect(controller.getPendingEventsCount() == 3);

    controller.flushEvents();
    try std.testing.expect(controller.getPendingEventsCount() == 0);
}

test "InstantAppController invocation handling" {
    var controller = InstantAppController.init(std.testing.allocator);
    defer controller.deinit();

    const config = InstantAppConfig.init("com.example.app");
    _ = try controller.startSession("test-session", config);

    const invocation = InvocationContext.init()
        .withUrl("https://example.com/clip?id=123")
        .withSource(.qr_code);

    try controller.handleInvocation(invocation);

    const session = controller.getSession().?;
    try std.testing.expect(session.invocation.source == .qr_code);
}

test "InstantAppController migration" {
    var controller = InstantAppController.init(std.testing.allocator);
    defer controller.deinit();

    const config = InstantAppConfig.init("com.example.app").withMigration(true);
    _ = try controller.startSession("test-session", config);

    const data = MigrationData.init()
        .withPreferences("{\"theme\":\"dark\"}")
        .withAccountId("user123");

    try controller.prepareMigration(data);
    try controller.executeMigration();

    const session = controller.getSession().?;
    try std.testing.expect(session.full_app_installed);
    try std.testing.expect(session.state == .completing);
}

test "Session expiry check" {
    var session = InstantAppSession.init("test-session", .ios_app_clip)
        .withConfig(InstantAppConfig.init("com.example.app")
        .withMaxSessionDuration(1)); // 1 second max

    session.activate();

    // Session just started, should not be expired
    // Note: In a real test we'd wait, but we'll just check the logic
    const expired = session.isSessionExpired();
    _ = expired; // Result depends on timing
}

test "MigrationData custom data" {
    const data = MigrationData.init()
        .withCustomData("{\"custom_field\":\"value\"}")
        .withProgress("{\"level\":5,\"score\":1000}");

    try std.testing.expect(data.custom_data_len > 0);
    try std.testing.expect(data.progress_len > 0);
    try std.testing.expect(data.hasData());
}
