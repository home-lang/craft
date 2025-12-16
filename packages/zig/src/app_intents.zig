//! App Intents and Shortcuts
//!
//! Provides cross-platform abstraction for app automation:
//! - iOS App Intents (iOS 16+)
//! - iOS Shortcuts integration
//! - Android App Actions
//! - macOS Shortcuts
//!
//! Features:
//! - Intent definition and parameters
//! - Shortcut creation and management
//! - Focus filter support
//! - Widget integration
//! - Automation triggers

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

/// Gets current timestamp in seconds
fn getCurrentTimestamp() i64 {
    const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
    return ts.sec;
}

/// Platform for app intents
pub const IntentPlatform = enum {
    app_intents, // iOS 16+ App Intents
    siri_shortcuts, // iOS Shortcuts
    app_actions, // Android App Actions
    macos_shortcuts, // macOS Shortcuts
    unknown,

    pub fn displayName(self: IntentPlatform) []const u8 {
        return switch (self) {
            .app_intents => "App Intents",
            .siri_shortcuts => "Siri Shortcuts",
            .app_actions => "App Actions",
            .macos_shortcuts => "macOS Shortcuts",
            .unknown => "Unknown",
        };
    }

    pub fn supportsWidgets(self: IntentPlatform) bool {
        return switch (self) {
            .app_intents => true,
            .siri_shortcuts => false,
            .app_actions => true,
            .macos_shortcuts => true,
            .unknown => false,
        };
    }

    pub fn supportsFocusFilters(self: IntentPlatform) bool {
        return switch (self) {
            .app_intents => true,
            .siri_shortcuts => false,
            .app_actions => false,
            .macos_shortcuts => true,
            .unknown => false,
        };
    }
};

/// Intent category for organization
pub const IntentCategory = enum {
    generic,
    create,
    edit,
    delete,
    view,
    share,
    search,
    play,
    pause,
    start,
    stop,
    toggle,
    set,
    get,
    open,
    send,
    order,
    book,

    pub fn displayName(self: IntentCategory) []const u8 {
        return switch (self) {
            .generic => "Generic",
            .create => "Create",
            .edit => "Edit",
            .delete => "Delete",
            .view => "View",
            .share => "Share",
            .search => "Search",
            .play => "Play",
            .pause => "Pause",
            .start => "Start",
            .stop => "Stop",
            .toggle => "Toggle",
            .set => "Set",
            .get => "Get",
            .open => "Open",
            .send => "Send",
            .order => "Order",
            .book => "Book",
        };
    }

    pub fn verb(self: IntentCategory) []const u8 {
        return switch (self) {
            .generic => "Do",
            .create => "Create",
            .edit => "Edit",
            .delete => "Delete",
            .view => "View",
            .share => "Share",
            .search => "Search",
            .play => "Play",
            .pause => "Pause",
            .start => "Start",
            .stop => "Stop",
            .toggle => "Toggle",
            .set => "Set",
            .get => "Get",
            .open => "Open",
            .send => "Send",
            .order => "Order",
            .book => "Book",
        };
    }
};

/// Parameter type for intent parameters
pub const ParameterType = enum {
    string,
    integer,
    double,
    boolean,
    date,
    duration,
    url,
    file,
    image,
    location,
    person,
    currency,
    measurement,
    app_enum, // Custom enum
    app_entity, // Custom entity

    pub fn displayName(self: ParameterType) []const u8 {
        return switch (self) {
            .string => "Text",
            .integer => "Integer",
            .double => "Number",
            .boolean => "Boolean",
            .date => "Date",
            .duration => "Duration",
            .url => "URL",
            .file => "File",
            .image => "Image",
            .location => "Location",
            .person => "Person",
            .currency => "Currency",
            .measurement => "Measurement",
            .app_enum => "Enum",
            .app_entity => "Entity",
        };
    }
};

/// Intent parameter definition
pub const IntentParameter = struct {
    /// Parameter identifier
    id_buffer: [64]u8 = [_]u8{0} ** 64,
    id_len: usize = 0,

    /// Display title
    title_buffer: [128]u8 = [_]u8{0} ** 128,
    title_len: usize = 0,

    /// Description
    description_buffer: [256]u8 = [_]u8{0} ** 256,
    description_len: usize = 0,

    /// Parameter type
    param_type: ParameterType = .string,

    /// Whether required
    is_required: bool = false,

    /// Default value (as string)
    default_buffer: [256]u8 = [_]u8{0} ** 256,
    default_len: usize = 0,

    /// Placeholder text
    placeholder_buffer: [128]u8 = [_]u8{0} ** 128,
    placeholder_len: usize = 0,

    /// Whether to request value at runtime
    request_value_dialog: bool = false,

    /// Input options for enums (max 8)
    options: [8][64]u8 = [_][64]u8{[_]u8{0} ** 64} ** 8,
    option_lens: [8]usize = [_]usize{0} ** 8,
    option_count: usize = 0,

    pub fn init(id: []const u8) IntentParameter {
        var result = IntentParameter{};
        const copy_len = @min(id.len, result.id_buffer.len);
        @memcpy(result.id_buffer[0..copy_len], id[0..copy_len]);
        result.id_len = copy_len;
        return result;
    }

    pub fn withTitle(self: IntentParameter, title: []const u8) IntentParameter {
        var result = self;
        const copy_len = @min(title.len, result.title_buffer.len);
        @memcpy(result.title_buffer[0..copy_len], title[0..copy_len]);
        result.title_len = copy_len;
        return result;
    }

    pub fn withDescription(self: IntentParameter, desc: []const u8) IntentParameter {
        var result = self;
        const copy_len = @min(desc.len, result.description_buffer.len);
        @memcpy(result.description_buffer[0..copy_len], desc[0..copy_len]);
        result.description_len = copy_len;
        return result;
    }

    pub fn withType(self: IntentParameter, param_type: ParameterType) IntentParameter {
        var result = self;
        result.param_type = param_type;
        return result;
    }

    pub fn withRequired(self: IntentParameter, required: bool) IntentParameter {
        var result = self;
        result.is_required = required;
        return result;
    }

    pub fn withDefault(self: IntentParameter, default: []const u8) IntentParameter {
        var result = self;
        const copy_len = @min(default.len, result.default_buffer.len);
        @memcpy(result.default_buffer[0..copy_len], default[0..copy_len]);
        result.default_len = copy_len;
        return result;
    }

    pub fn withPlaceholder(self: IntentParameter, placeholder: []const u8) IntentParameter {
        var result = self;
        const copy_len = @min(placeholder.len, result.placeholder_buffer.len);
        @memcpy(result.placeholder_buffer[0..copy_len], placeholder[0..copy_len]);
        result.placeholder_len = copy_len;
        return result;
    }

    pub fn withRequestDialog(self: IntentParameter, request: bool) IntentParameter {
        var result = self;
        result.request_value_dialog = request;
        return result;
    }

    pub fn addOption(self: IntentParameter, option: []const u8) IntentParameter {
        var result = self;
        if (result.option_count < 8) {
            const copy_len = @min(option.len, 64);
            @memcpy(result.options[result.option_count][0..copy_len], option[0..copy_len]);
            result.option_lens[result.option_count] = copy_len;
            result.option_count += 1;
        }
        return result;
    }

    pub fn getId(self: *const IntentParameter) []const u8 {
        return self.id_buffer[0..self.id_len];
    }

    pub fn getTitle(self: *const IntentParameter) []const u8 {
        if (self.title_len > 0) {
            return self.title_buffer[0..self.title_len];
        }
        return self.id_buffer[0..self.id_len];
    }

    pub fn getDescription(self: *const IntentParameter) []const u8 {
        return self.description_buffer[0..self.description_len];
    }

    pub fn getDefault(self: *const IntentParameter) []const u8 {
        return self.default_buffer[0..self.default_len];
    }

    pub fn getOption(self: *const IntentParameter, index: usize) ?[]const u8 {
        if (index < self.option_count) {
            return self.options[index][0..self.option_lens[index]];
        }
        return null;
    }
};

/// App Intent definition
pub const AppIntent = struct {
    /// Unique identifier
    id_buffer: [128]u8 = [_]u8{0} ** 128,
    id_len: usize = 0,

    /// Display title
    title_buffer: [128]u8 = [_]u8{0} ** 128,
    title_len: usize = 0,

    /// Description
    description_buffer: [512]u8 = [_]u8{0} ** 512,
    description_len: usize = 0,

    /// Category
    category: IntentCategory = .generic,

    /// Parameters (max 8)
    parameters: [8]IntentParameter = [_]IntentParameter{IntentParameter{}} ** 8,
    parameter_count: usize = 0,

    /// Whether intent opens the app
    opens_app_when_run: bool = false,

    /// Whether intent is user-configurable
    is_discoverable: bool = true,

    /// System image name (SF Symbol)
    image_name_buffer: [64]u8 = [_]u8{0} ** 64,
    image_name_len: usize = 0,

    /// Shortcut phrase suggestions (max 4)
    suggested_phrases: [4][128]u8 = [_][128]u8{[_]u8{0} ** 128} ** 4,
    suggested_phrase_lens: [4]usize = [_]usize{0} ** 4,
    suggested_phrase_count: usize = 0,

    pub fn init(id: []const u8) AppIntent {
        var result = AppIntent{};
        const copy_len = @min(id.len, result.id_buffer.len);
        @memcpy(result.id_buffer[0..copy_len], id[0..copy_len]);
        result.id_len = copy_len;
        return result;
    }

    pub fn withTitle(self: AppIntent, title: []const u8) AppIntent {
        var result = self;
        const copy_len = @min(title.len, result.title_buffer.len);
        @memcpy(result.title_buffer[0..copy_len], title[0..copy_len]);
        result.title_len = copy_len;
        return result;
    }

    pub fn withDescription(self: AppIntent, desc: []const u8) AppIntent {
        var result = self;
        const copy_len = @min(desc.len, result.description_buffer.len);
        @memcpy(result.description_buffer[0..copy_len], desc[0..copy_len]);
        result.description_len = copy_len;
        return result;
    }

    pub fn withCategory(self: AppIntent, category: IntentCategory) AppIntent {
        var result = self;
        result.category = category;
        return result;
    }

    pub fn addParameter(self: AppIntent, param: IntentParameter) AppIntent {
        var result = self;
        if (result.parameter_count < 8) {
            result.parameters[result.parameter_count] = param;
            result.parameter_count += 1;
        }
        return result;
    }

    pub fn withOpensApp(self: AppIntent, opens: bool) AppIntent {
        var result = self;
        result.opens_app_when_run = opens;
        return result;
    }

    pub fn withDiscoverable(self: AppIntent, discoverable: bool) AppIntent {
        var result = self;
        result.is_discoverable = discoverable;
        return result;
    }

    pub fn withImage(self: AppIntent, image_name: []const u8) AppIntent {
        var result = self;
        const copy_len = @min(image_name.len, result.image_name_buffer.len);
        @memcpy(result.image_name_buffer[0..copy_len], image_name[0..copy_len]);
        result.image_name_len = copy_len;
        return result;
    }

    pub fn addSuggestedPhrase(self: AppIntent, phrase: []const u8) AppIntent {
        var result = self;
        if (result.suggested_phrase_count < 4) {
            const copy_len = @min(phrase.len, 128);
            @memcpy(result.suggested_phrases[result.suggested_phrase_count][0..copy_len], phrase[0..copy_len]);
            result.suggested_phrase_lens[result.suggested_phrase_count] = copy_len;
            result.suggested_phrase_count += 1;
        }
        return result;
    }

    pub fn getId(self: *const AppIntent) []const u8 {
        return self.id_buffer[0..self.id_len];
    }

    pub fn getTitle(self: *const AppIntent) []const u8 {
        return self.title_buffer[0..self.title_len];
    }

    pub fn getDescription(self: *const AppIntent) []const u8 {
        return self.description_buffer[0..self.description_len];
    }

    pub fn getImageName(self: *const AppIntent) []const u8 {
        return self.image_name_buffer[0..self.image_name_len];
    }

    pub fn getParameter(self: *const AppIntent, index: usize) ?*const IntentParameter {
        if (index < self.parameter_count) {
            return &self.parameters[index];
        }
        return null;
    }

    pub fn getSuggestedPhrase(self: *const AppIntent, index: usize) ?[]const u8 {
        if (index < self.suggested_phrase_count) {
            return self.suggested_phrases[index][0..self.suggested_phrase_lens[index]];
        }
        return null;
    }
};

/// Shortcut definition
pub const AppShortcut = struct {
    /// Associated intent ID
    intent_id_buffer: [128]u8 = [_]u8{0} ** 128,
    intent_id_len: usize = 0,

    /// Shortcut phrase
    phrase_buffer: [256]u8 = [_]u8{0} ** 256,
    phrase_len: usize = 0,

    /// Short title for Shortcuts app
    short_title_buffer: [64]u8 = [_]u8{0} ** 64,
    short_title_len: usize = 0,

    /// System image name
    image_name_buffer: [64]u8 = [_]u8{0} ** 64,
    image_name_len: usize = 0,

    /// Pre-filled parameter values
    parameter_values: [8][256]u8 = [_][256]u8{[_]u8{0} ** 256} ** 8,
    parameter_value_lens: [8]usize = [_]usize{0} ** 8,
    parameter_keys: [8][64]u8 = [_][64]u8{[_]u8{0} ** 64} ** 8,
    parameter_key_lens: [8]usize = [_]usize{0} ** 8,
    parameter_count: usize = 0,

    pub fn init(intent_id: []const u8) AppShortcut {
        var result = AppShortcut{};
        const copy_len = @min(intent_id.len, result.intent_id_buffer.len);
        @memcpy(result.intent_id_buffer[0..copy_len], intent_id[0..copy_len]);
        result.intent_id_len = copy_len;
        return result;
    }

    pub fn withPhrase(self: AppShortcut, phrase: []const u8) AppShortcut {
        var result = self;
        const copy_len = @min(phrase.len, result.phrase_buffer.len);
        @memcpy(result.phrase_buffer[0..copy_len], phrase[0..copy_len]);
        result.phrase_len = copy_len;
        return result;
    }

    pub fn withShortTitle(self: AppShortcut, title: []const u8) AppShortcut {
        var result = self;
        const copy_len = @min(title.len, result.short_title_buffer.len);
        @memcpy(result.short_title_buffer[0..copy_len], title[0..copy_len]);
        result.short_title_len = copy_len;
        return result;
    }

    pub fn withImage(self: AppShortcut, image_name: []const u8) AppShortcut {
        var result = self;
        const copy_len = @min(image_name.len, result.image_name_buffer.len);
        @memcpy(result.image_name_buffer[0..copy_len], image_name[0..copy_len]);
        result.image_name_len = copy_len;
        return result;
    }

    pub fn setParameter(self: AppShortcut, key: []const u8, value: []const u8) AppShortcut {
        var result = self;
        if (result.parameter_count < 8) {
            const key_len = @min(key.len, 64);
            @memcpy(result.parameter_keys[result.parameter_count][0..key_len], key[0..key_len]);
            result.parameter_key_lens[result.parameter_count] = key_len;

            const value_len = @min(value.len, 256);
            @memcpy(result.parameter_values[result.parameter_count][0..value_len], value[0..value_len]);
            result.parameter_value_lens[result.parameter_count] = value_len;

            result.parameter_count += 1;
        }
        return result;
    }

    pub fn getIntentId(self: *const AppShortcut) []const u8 {
        return self.intent_id_buffer[0..self.intent_id_len];
    }

    pub fn getPhrase(self: *const AppShortcut) []const u8 {
        return self.phrase_buffer[0..self.phrase_len];
    }

    pub fn getShortTitle(self: *const AppShortcut) []const u8 {
        return self.short_title_buffer[0..self.short_title_len];
    }

    pub fn getImageName(self: *const AppShortcut) []const u8 {
        return self.image_name_buffer[0..self.image_name_len];
    }
};

/// Focus filter configuration
pub const FocusFilter = struct {
    /// Filter identifier
    id_buffer: [64]u8 = [_]u8{0} ** 64,
    id_len: usize = 0,

    /// Display title
    title_buffer: [128]u8 = [_]u8{0} ** 128,
    title_len: usize = 0,

    /// Associated Focus mode name
    focus_mode_buffer: [64]u8 = [_]u8{0} ** 64,
    focus_mode_len: usize = 0,

    /// Configuration parameters
    config_keys: [8][64]u8 = [_][64]u8{[_]u8{0} ** 64} ** 8,
    config_key_lens: [8]usize = [_]usize{0} ** 8,
    config_values: [8][256]u8 = [_][256]u8{[_]u8{0} ** 256} ** 8,
    config_value_lens: [8]usize = [_]usize{0} ** 8,
    config_count: usize = 0,

    pub fn init(id: []const u8) FocusFilter {
        var result = FocusFilter{};
        const copy_len = @min(id.len, result.id_buffer.len);
        @memcpy(result.id_buffer[0..copy_len], id[0..copy_len]);
        result.id_len = copy_len;
        return result;
    }

    pub fn withTitle(self: FocusFilter, title: []const u8) FocusFilter {
        var result = self;
        const copy_len = @min(title.len, result.title_buffer.len);
        @memcpy(result.title_buffer[0..copy_len], title[0..copy_len]);
        result.title_len = copy_len;
        return result;
    }

    pub fn withFocusMode(self: FocusFilter, mode: []const u8) FocusFilter {
        var result = self;
        const copy_len = @min(mode.len, result.focus_mode_buffer.len);
        @memcpy(result.focus_mode_buffer[0..copy_len], mode[0..copy_len]);
        result.focus_mode_len = copy_len;
        return result;
    }

    pub fn setConfig(self: FocusFilter, key: []const u8, value: []const u8) FocusFilter {
        var result = self;
        if (result.config_count < 8) {
            const key_len = @min(key.len, 64);
            @memcpy(result.config_keys[result.config_count][0..key_len], key[0..key_len]);
            result.config_key_lens[result.config_count] = key_len;

            const value_len = @min(value.len, 256);
            @memcpy(result.config_values[result.config_count][0..value_len], value[0..value_len]);
            result.config_value_lens[result.config_count] = value_len;

            result.config_count += 1;
        }
        return result;
    }

    pub fn getId(self: *const FocusFilter) []const u8 {
        return self.id_buffer[0..self.id_len];
    }

    pub fn getTitle(self: *const FocusFilter) []const u8 {
        return self.title_buffer[0..self.title_len];
    }

    pub fn getFocusMode(self: *const FocusFilter) []const u8 {
        return self.focus_mode_buffer[0..self.focus_mode_len];
    }
};

/// Intent execution result
pub const IntentResult = struct {
    /// Whether execution succeeded
    success: bool = false,

    /// Result value (as string)
    value_buffer: [1024]u8 = [_]u8{0} ** 1024,
    value_len: usize = 0,

    /// Error message if failed
    error_buffer: [256]u8 = [_]u8{0} ** 256,
    error_len: usize = 0,

    /// Dialog to show user
    dialog_buffer: [512]u8 = [_]u8{0} ** 512,
    dialog_len: usize = 0,

    /// Whether to continue in app
    needs_app_context: bool = false,

    /// Deep link URL if opening app
    url_buffer: [512]u8 = [_]u8{0} ** 512,
    url_len: usize = 0,

    pub fn ok(value: []const u8) IntentResult {
        var result = IntentResult{
            .success = true,
        };
        const copy_len = @min(value.len, result.value_buffer.len);
        @memcpy(result.value_buffer[0..copy_len], value[0..copy_len]);
        result.value_len = copy_len;
        return result;
    }

    pub fn fail(err: []const u8) IntentResult {
        var result = IntentResult{
            .success = false,
        };
        const copy_len = @min(err.len, result.error_buffer.len);
        @memcpy(result.error_buffer[0..copy_len], err[0..copy_len]);
        result.error_len = copy_len;
        return result;
    }

    pub fn withDialog(self: IntentResult, dialog: []const u8) IntentResult {
        var result = self;
        const copy_len = @min(dialog.len, result.dialog_buffer.len);
        @memcpy(result.dialog_buffer[0..copy_len], dialog[0..copy_len]);
        result.dialog_len = copy_len;
        return result;
    }

    pub fn withNeedsApp(self: IntentResult, needs: bool) IntentResult {
        var result = self;
        result.needs_app_context = needs;
        return result;
    }

    pub fn withUrl(self: IntentResult, url: []const u8) IntentResult {
        var result = self;
        const copy_len = @min(url.len, result.url_buffer.len);
        @memcpy(result.url_buffer[0..copy_len], url[0..copy_len]);
        result.url_len = copy_len;
        return result;
    }

    pub fn getValue(self: *const IntentResult) []const u8 {
        return self.value_buffer[0..self.value_len];
    }

    pub fn getError(self: *const IntentResult) []const u8 {
        return self.error_buffer[0..self.error_len];
    }

    pub fn getDialog(self: *const IntentResult) []const u8 {
        return self.dialog_buffer[0..self.dialog_len];
    }

    pub fn getUrl(self: *const IntentResult) []const u8 {
        return self.url_buffer[0..self.url_len];
    }
};

/// Entity query for dynamic options
pub const EntityQuery = struct {
    /// Query string
    query_buffer: [256]u8 = [_]u8{0} ** 256,
    query_len: usize = 0,

    /// Suggested entities count
    suggested_count: u32 = 10,

    /// Include recent items
    include_recent: bool = true,

    pub fn init(query: []const u8) EntityQuery {
        var result = EntityQuery{};
        const copy_len = @min(query.len, result.query_buffer.len);
        @memcpy(result.query_buffer[0..copy_len], query[0..copy_len]);
        result.query_len = copy_len;
        return result;
    }

    pub fn withSuggestedCount(self: EntityQuery, count: u32) EntityQuery {
        var result = self;
        result.suggested_count = count;
        return result;
    }

    pub fn withRecent(self: EntityQuery, include: bool) EntityQuery {
        var result = self;
        result.include_recent = include;
        return result;
    }

    pub fn getQuery(self: *const EntityQuery) []const u8 {
        return self.query_buffer[0..self.query_len];
    }
};

/// App entity for parameters
pub const AppEntity = struct {
    /// Entity ID
    id_buffer: [128]u8 = [_]u8{0} ** 128,
    id_len: usize = 0,

    /// Display title
    title_buffer: [128]u8 = [_]u8{0} ** 128,
    title_len: usize = 0,

    /// Subtitle
    subtitle_buffer: [256]u8 = [_]u8{0} ** 256,
    subtitle_len: usize = 0,

    /// Image name
    image_buffer: [64]u8 = [_]u8{0} ** 64,
    image_len: usize = 0,

    pub fn init(id: []const u8) AppEntity {
        var result = AppEntity{};
        const copy_len = @min(id.len, result.id_buffer.len);
        @memcpy(result.id_buffer[0..copy_len], id[0..copy_len]);
        result.id_len = copy_len;
        return result;
    }

    pub fn withTitle(self: AppEntity, title: []const u8) AppEntity {
        var result = self;
        const copy_len = @min(title.len, result.title_buffer.len);
        @memcpy(result.title_buffer[0..copy_len], title[0..copy_len]);
        result.title_len = copy_len;
        return result;
    }

    pub fn withSubtitle(self: AppEntity, subtitle: []const u8) AppEntity {
        var result = self;
        const copy_len = @min(subtitle.len, result.subtitle_buffer.len);
        @memcpy(result.subtitle_buffer[0..copy_len], subtitle[0..copy_len]);
        result.subtitle_len = copy_len;
        return result;
    }

    pub fn withImage(self: AppEntity, image: []const u8) AppEntity {
        var result = self;
        const copy_len = @min(image.len, result.image_buffer.len);
        @memcpy(result.image_buffer[0..copy_len], image[0..copy_len]);
        result.image_len = copy_len;
        return result;
    }

    pub fn getId(self: *const AppEntity) []const u8 {
        return self.id_buffer[0..self.id_len];
    }

    pub fn getTitle(self: *const AppEntity) []const u8 {
        return self.title_buffer[0..self.title_len];
    }

    pub fn getSubtitle(self: *const AppEntity) []const u8 {
        return self.subtitle_buffer[0..self.subtitle_len];
    }

    pub fn getImage(self: *const AppEntity) []const u8 {
        return self.image_buffer[0..self.image_len];
    }
};

/// Intent handler type
pub const IntentHandler = *const fn (intent_id: []const u8, params: []const u8) IntentResult;

/// App Intents controller
pub const AppIntentsController = struct {
    allocator: Allocator,
    platform: IntentPlatform,
    intents: std.ArrayListUnmanaged(AppIntent),
    shortcuts: std.ArrayListUnmanaged(AppShortcut),
    focus_filters: std.ArrayListUnmanaged(FocusFilter),
    is_enabled: bool,

    pub fn init(allocator: Allocator) AppIntentsController {
        const platform = detectPlatform();
        return .{
            .allocator = allocator,
            .platform = platform,
            .intents = .empty,
            .shortcuts = .empty,
            .focus_filters = .empty,
            .is_enabled = true,
        };
    }

    pub fn deinit(self: *AppIntentsController) void {
        self.intents.deinit(self.allocator);
        self.shortcuts.deinit(self.allocator);
        self.focus_filters.deinit(self.allocator);
    }

    fn detectPlatform() IntentPlatform {
        return switch (builtin.os.tag) {
            .ios => .app_intents,
            .macos => .macos_shortcuts,
            .linux => if (builtin.abi == .android) .app_actions else .unknown,
            else => .unknown,
        };
    }

    pub fn registerIntent(self: *AppIntentsController, intent: AppIntent) !void {
        // Check for duplicate
        for (self.intents.items) |existing| {
            if (std.mem.eql(u8, existing.id_buffer[0..existing.id_len], intent.id_buffer[0..intent.id_len])) {
                return error.IntentAlreadyExists;
            }
        }
        try self.intents.append(self.allocator, intent);
    }

    pub fn unregisterIntent(self: *AppIntentsController, intent_id: []const u8) bool {
        for (self.intents.items, 0..) |intent, i| {
            if (std.mem.eql(u8, intent.id_buffer[0..intent.id_len], intent_id)) {
                _ = self.intents.orderedRemove(i);
                return true;
            }
        }
        return false;
    }

    pub fn getIntent(self: *AppIntentsController, intent_id: []const u8) ?*const AppIntent {
        for (self.intents.items) |*intent| {
            if (std.mem.eql(u8, intent.id_buffer[0..intent.id_len], intent_id)) {
                return intent;
            }
        }
        return null;
    }

    pub fn addShortcut(self: *AppIntentsController, shortcut: AppShortcut) !void {
        try self.shortcuts.append(self.allocator, shortcut);
    }

    pub fn removeShortcut(self: *AppIntentsController, intent_id: []const u8) bool {
        for (self.shortcuts.items, 0..) |shortcut, i| {
            if (std.mem.eql(u8, shortcut.intent_id_buffer[0..shortcut.intent_id_len], intent_id)) {
                _ = self.shortcuts.orderedRemove(i);
                return true;
            }
        }
        return false;
    }

    pub fn addFocusFilter(self: *AppIntentsController, filter: FocusFilter) !void {
        try self.focus_filters.append(self.allocator, filter);
    }

    pub fn removeFocusFilter(self: *AppIntentsController, filter_id: []const u8) bool {
        for (self.focus_filters.items, 0..) |filter, i| {
            if (std.mem.eql(u8, filter.id_buffer[0..filter.id_len], filter_id)) {
                _ = self.focus_filters.orderedRemove(i);
                return true;
            }
        }
        return false;
    }

    pub fn handleIntent(self: *AppIntentsController, intent_id: []const u8, params: []const u8, handler: IntentHandler) IntentResult {
        if (!self.is_enabled) {
            return IntentResult.fail("App Intents are disabled");
        }

        if (self.getIntent(intent_id) == null) {
            return IntentResult.fail("Unknown intent");
        }

        return handler(intent_id, params);
    }

    pub fn setEnabled(self: *AppIntentsController, enabled: bool) void {
        self.is_enabled = enabled;
    }

    pub fn getIntentCount(self: *AppIntentsController) usize {
        return self.intents.items.len;
    }

    pub fn getShortcutCount(self: *AppIntentsController) usize {
        return self.shortcuts.items.len;
    }

    pub fn getFocusFilterCount(self: *AppIntentsController) usize {
        return self.focus_filters.items.len;
    }

    pub fn supportsWidgets(self: *AppIntentsController) bool {
        return self.platform.supportsWidgets();
    }

    pub fn supportsFocusFilters(self: *AppIntentsController) bool {
        return self.platform.supportsFocusFilters();
    }

    pub fn getDiscoverableIntents(self: *AppIntentsController) []const AppIntent {
        // Return all discoverable intents (in real impl would filter)
        return self.intents.items;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "IntentPlatform display names and capabilities" {
    try std.testing.expectEqualStrings("App Intents", IntentPlatform.app_intents.displayName());
    try std.testing.expectEqualStrings("Siri Shortcuts", IntentPlatform.siri_shortcuts.displayName());
    try std.testing.expect(IntentPlatform.app_intents.supportsWidgets());
    try std.testing.expect(IntentPlatform.app_intents.supportsFocusFilters());
    try std.testing.expect(!IntentPlatform.siri_shortcuts.supportsFocusFilters());
}

test "IntentCategory display names and verbs" {
    try std.testing.expectEqualStrings("Create", IntentCategory.create.displayName());
    try std.testing.expectEqualStrings("Create", IntentCategory.create.verb());
    try std.testing.expectEqualStrings("Toggle", IntentCategory.toggle.verb());
}

test "ParameterType display names" {
    try std.testing.expectEqualStrings("Text", ParameterType.string.displayName());
    try std.testing.expectEqualStrings("Boolean", ParameterType.boolean.displayName());
    try std.testing.expectEqualStrings("Location", ParameterType.location.displayName());
}

test "IntentParameter initialization and fluent API" {
    const param = IntentParameter.init("amount")
        .withTitle("Amount")
        .withDescription("The amount to transfer")
        .withType(.currency)
        .withRequired(true)
        .withDefault("0")
        .withPlaceholder("Enter amount")
        .withRequestDialog(true);

    try std.testing.expectEqualStrings("amount", param.getId());
    try std.testing.expectEqualStrings("Amount", param.getTitle());
    try std.testing.expectEqualStrings("The amount to transfer", param.getDescription());
    try std.testing.expect(param.param_type == .currency);
    try std.testing.expect(param.is_required);
    try std.testing.expect(param.request_value_dialog);
}

test "IntentParameter options" {
    const param = IntentParameter.init("size")
        .withType(.app_enum)
        .addOption("Small")
        .addOption("Medium")
        .addOption("Large");

    try std.testing.expect(param.option_count == 3);
    try std.testing.expectEqualStrings("Small", param.getOption(0).?);
    try std.testing.expectEqualStrings("Medium", param.getOption(1).?);
    try std.testing.expect(param.getOption(10) == null);
}

test "AppIntent initialization and fluent API" {
    const intent = AppIntent.init("com.example.sendmoney")
        .withTitle("Send Money")
        .withDescription("Send money to someone")
        .withCategory(.send)
        .withImage("dollarsign.circle")
        .withOpensApp(false)
        .withDiscoverable(true)
        .addParameter(IntentParameter.init("amount").withType(.currency))
        .addParameter(IntentParameter.init("recipient").withType(.person))
        .addSuggestedPhrase("Send money to")
        .addSuggestedPhrase("Pay");

    try std.testing.expectEqualStrings("com.example.sendmoney", intent.getId());
    try std.testing.expectEqualStrings("Send Money", intent.getTitle());
    try std.testing.expect(intent.category == .send);
    try std.testing.expect(intent.parameter_count == 2);
    try std.testing.expect(intent.suggested_phrase_count == 2);
    try std.testing.expectEqualStrings("Send money to", intent.getSuggestedPhrase(0).?);
}

test "AppIntent parameter access" {
    const intent = AppIntent.init("test")
        .addParameter(IntentParameter.init("param1").withTitle("First"))
        .addParameter(IntentParameter.init("param2").withTitle("Second"));

    const p1 = intent.getParameter(0);
    try std.testing.expect(p1 != null);
    try std.testing.expectEqualStrings("First", p1.?.getTitle());

    const missing = intent.getParameter(10);
    try std.testing.expect(missing == null);
}

test "AppShortcut initialization and fluent API" {
    const shortcut = AppShortcut.init("com.example.order")
        .withPhrase("Order my usual coffee")
        .withShortTitle("Order Coffee")
        .withImage("cup.and.saucer")
        .setParameter("size", "Large")
        .setParameter("type", "Latte");

    try std.testing.expectEqualStrings("com.example.order", shortcut.getIntentId());
    try std.testing.expectEqualStrings("Order my usual coffee", shortcut.getPhrase());
    try std.testing.expectEqualStrings("Order Coffee", shortcut.getShortTitle());
    try std.testing.expect(shortcut.parameter_count == 2);
}

test "FocusFilter initialization and fluent API" {
    const filter = FocusFilter.init("work-filter")
        .withTitle("Work Mode")
        .withFocusMode("Work")
        .setConfig("showWorkProjects", "true")
        .setConfig("hidePersonalTasks", "true");

    try std.testing.expectEqualStrings("work-filter", filter.getId());
    try std.testing.expectEqualStrings("Work Mode", filter.getTitle());
    try std.testing.expectEqualStrings("Work", filter.getFocusMode());
    try std.testing.expect(filter.config_count == 2);
}

test "IntentResult success" {
    const result = IntentResult.ok("Payment sent successfully")
        .withDialog("Your payment has been processed");

    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("Payment sent successfully", result.getValue());
    try std.testing.expectEqualStrings("Your payment has been processed", result.getDialog());
}

test "IntentResult failure" {
    const result = IntentResult.fail("Insufficient funds");

    try std.testing.expect(!result.success);
    try std.testing.expectEqualStrings("Insufficient funds", result.getError());
}

test "IntentResult needs app" {
    const result = IntentResult.ok("")
        .withNeedsApp(true)
        .withUrl("myapp://complete-action");

    try std.testing.expect(result.needs_app_context);
    try std.testing.expectEqualStrings("myapp://complete-action", result.getUrl());
}

test "EntityQuery initialization" {
    const query = EntityQuery.init("search term")
        .withSuggestedCount(20)
        .withRecent(false);

    try std.testing.expectEqualStrings("search term", query.getQuery());
    try std.testing.expect(query.suggested_count == 20);
    try std.testing.expect(!query.include_recent);
}

test "AppEntity initialization and fluent API" {
    const entity = AppEntity.init("contact-123")
        .withTitle("John Doe")
        .withSubtitle("john@example.com")
        .withImage("person.circle");

    try std.testing.expectEqualStrings("contact-123", entity.getId());
    try std.testing.expectEqualStrings("John Doe", entity.getTitle());
    try std.testing.expectEqualStrings("john@example.com", entity.getSubtitle());
    try std.testing.expectEqualStrings("person.circle", entity.getImage());
}

test "AppIntentsController initialization" {
    var controller = AppIntentsController.init(std.testing.allocator);
    defer controller.deinit();

    try std.testing.expect(controller.is_enabled);
    try std.testing.expect(controller.getIntentCount() == 0);
}

test "AppIntentsController intent registration" {
    var controller = AppIntentsController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.registerIntent(AppIntent.init("intent1").withTitle("First"));
    try controller.registerIntent(AppIntent.init("intent2").withTitle("Second"));

    try std.testing.expect(controller.getIntentCount() == 2);

    const found = controller.getIntent("intent1");
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("First", found.?.getTitle());
}

test "AppIntentsController duplicate intent error" {
    var controller = AppIntentsController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.registerIntent(AppIntent.init("intent1"));
    const result = controller.registerIntent(AppIntent.init("intent1"));
    try std.testing.expectError(error.IntentAlreadyExists, result);
}

test "AppIntentsController intent unregistration" {
    var controller = AppIntentsController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.registerIntent(AppIntent.init("intent1"));
    try std.testing.expect(controller.getIntentCount() == 1);

    try std.testing.expect(controller.unregisterIntent("intent1"));
    try std.testing.expect(controller.getIntentCount() == 0);

    try std.testing.expect(!controller.unregisterIntent("nonexistent"));
}

test "AppIntentsController shortcuts" {
    var controller = AppIntentsController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.addShortcut(AppShortcut.init("intent1").withPhrase("Do thing"));
    try std.testing.expect(controller.getShortcutCount() == 1);

    try std.testing.expect(controller.removeShortcut("intent1"));
    try std.testing.expect(controller.getShortcutCount() == 0);
}

test "AppIntentsController focus filters" {
    var controller = AppIntentsController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.addFocusFilter(FocusFilter.init("filter1").withTitle("Work"));
    try std.testing.expect(controller.getFocusFilterCount() == 1);

    try std.testing.expect(controller.removeFocusFilter("filter1"));
    try std.testing.expect(controller.getFocusFilterCount() == 0);
}

fn testHandler(_: []const u8, _: []const u8) IntentResult {
    return IntentResult.ok("Handled");
}

test "AppIntentsController handle intent" {
    var controller = AppIntentsController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.registerIntent(AppIntent.init("test-intent"));

    const result = controller.handleIntent("test-intent", "{}", testHandler);
    try std.testing.expect(result.success);
    try std.testing.expectEqualStrings("Handled", result.getValue());
}

test "AppIntentsController handle unknown intent" {
    var controller = AppIntentsController.init(std.testing.allocator);
    defer controller.deinit();

    const result = controller.handleIntent("unknown", "{}", testHandler);
    try std.testing.expect(!result.success);
    try std.testing.expectEqualStrings("Unknown intent", result.getError());
}

test "AppIntentsController disabled" {
    var controller = AppIntentsController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.registerIntent(AppIntent.init("test-intent"));
    controller.setEnabled(false);

    const result = controller.handleIntent("test-intent", "{}", testHandler);
    try std.testing.expect(!result.success);
}

test "AppIntentsController platform capabilities" {
    var controller = AppIntentsController.init(std.testing.allocator);
    defer controller.deinit();

    // Should not crash regardless of platform
    _ = controller.supportsWidgets();
    _ = controller.supportsFocusFilters();
}

test "IntentParameter title fallback" {
    const param = IntentParameter.init("myParam");
    // Without explicit title, should return ID
    try std.testing.expectEqualStrings("myParam", param.getTitle());
}
