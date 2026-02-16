//! Voice Assistant Integration - Siri, Google Assistant, Alexa
//!
//! Provides cross-platform abstraction for voice assistant integration:
//! - Siri Intents and SiriKit
//! - Google Assistant Actions
//! - Alexa Skills
//! - Cortana Skills
//!
//! Features:
//! - Intent registration and handling
//! - Voice command parsing
//! - Response generation (spoken and visual)
//! - Shortcut donation
//! - Custom vocabulary

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

/// Voice assistant platform
pub const AssistantPlatform = enum {
    siri,
    google_assistant,
    alexa,
    cortana,
    bixby,
    unknown,

    pub fn displayName(self: AssistantPlatform) []const u8 {
        return switch (self) {
            .siri => "Siri",
            .google_assistant => "Google Assistant",
            .alexa => "Amazon Alexa",
            .cortana => "Microsoft Cortana",
            .bixby => "Samsung Bixby",
            .unknown => "Unknown Assistant",
        };
    }

    pub fn supportsVisualResponse(self: AssistantPlatform) bool {
        return switch (self) {
            .siri => true,
            .google_assistant => true,
            .alexa => true, // Echo Show, Fire TV
            .cortana => true,
            .bixby => true,
            .unknown => false,
        };
    }
};

/// Intent category for organizing voice commands
pub const IntentCategory = enum {
    messaging, // Send message, read messages
    calling, // Make calls, video calls
    media, // Play music, control playback
    lists, // Create/manage lists, reminders
    notes, // Create/search notes
    calendar, // Schedule events, check calendar
    navigation, // Get directions, find places
    smart_home, // Control devices
    payments, // Send money, check balance
    fitness, // Start workout, log activity
    food, // Order food, find restaurants
    shopping, // Add to cart, reorder
    information, // Weather, news, facts
    custom, // App-specific intents

    pub fn displayName(self: IntentCategory) []const u8 {
        return switch (self) {
            .messaging => "Messaging",
            .calling => "Calling",
            .media => "Media",
            .lists => "Lists & Reminders",
            .notes => "Notes",
            .calendar => "Calendar",
            .navigation => "Navigation",
            .smart_home => "Smart Home",
            .payments => "Payments",
            .fitness => "Fitness",
            .food => "Food & Dining",
            .shopping => "Shopping",
            .information => "Information",
            .custom => "Custom",
        };
    }
};

/// Parameter type for intent parameters
pub const ParameterType = enum {
    string,
    number,
    boolean,
    date,
    time,
    datetime,
    duration,
    currency,
    location,
    contact,
    app_entity, // Custom app-defined entity
    list,

    pub fn displayName(self: ParameterType) []const u8 {
        return switch (self) {
            .string => "Text",
            .number => "Number",
            .boolean => "Yes/No",
            .date => "Date",
            .time => "Time",
            .datetime => "Date & Time",
            .duration => "Duration",
            .currency => "Currency",
            .location => "Location",
            .contact => "Contact",
            .app_entity => "App Entity",
            .list => "List",
        };
    }
};

/// Intent parameter definition
pub const IntentParameter = struct {
    /// Parameter name/key
    name_buffer: [64]u8 = [_]u8{0} ** 64,
    name_len: usize = 0,

    /// Display name for disambiguation
    display_name_buffer: [128]u8 = [_]u8{0} ** 128,
    display_name_len: usize = 0,

    /// Parameter type
    param_type: ParameterType = .string,

    /// Whether parameter is required
    is_required: bool = false,

    /// Default value (as string)
    default_value_buffer: [256]u8 = [_]u8{0} ** 256,
    default_value_len: usize = 0,

    /// Prompt to ask user for this parameter
    prompt_buffer: [256]u8 = [_]u8{0} ** 256,
    prompt_len: usize = 0,

    pub fn init(name: []const u8) IntentParameter {
        var result = IntentParameter{};
        const copy_len = @min(name.len, result.name_buffer.len);
        @memcpy(result.name_buffer[0..copy_len], name[0..copy_len]);
        result.name_len = copy_len;
        return result;
    }

    pub fn withDisplayName(self: IntentParameter, display_name: []const u8) IntentParameter {
        var result = self;
        const copy_len = @min(display_name.len, result.display_name_buffer.len);
        @memcpy(result.display_name_buffer[0..copy_len], display_name[0..copy_len]);
        result.display_name_len = copy_len;
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

    pub fn withDefault(self: IntentParameter, default_value: []const u8) IntentParameter {
        var result = self;
        const copy_len = @min(default_value.len, result.default_value_buffer.len);
        @memcpy(result.default_value_buffer[0..copy_len], default_value[0..copy_len]);
        result.default_value_len = copy_len;
        return result;
    }

    pub fn withPrompt(self: IntentParameter, prompt: []const u8) IntentParameter {
        var result = self;
        const copy_len = @min(prompt.len, result.prompt_buffer.len);
        @memcpy(result.prompt_buffer[0..copy_len], prompt[0..copy_len]);
        result.prompt_len = copy_len;
        return result;
    }

    pub fn getName(self: *const IntentParameter) []const u8 {
        return self.name_buffer[0..self.name_len];
    }

    pub fn getDisplayName(self: *const IntentParameter) []const u8 {
        if (self.display_name_len > 0) {
            return self.display_name_buffer[0..self.display_name_len];
        }
        return self.name_buffer[0..self.name_len];
    }

    pub fn getPrompt(self: *const IntentParameter) []const u8 {
        return self.prompt_buffer[0..self.prompt_len];
    }

    pub fn getDefault(self: *const IntentParameter) []const u8 {
        return self.default_value_buffer[0..self.default_value_len];
    }
};

/// Intent definition
pub const IntentDefinition = struct {
    /// Unique intent identifier
    id_buffer: [128]u8 = [_]u8{0} ** 128,
    id_len: usize = 0,

    /// Human-readable title
    title_buffer: [128]u8 = [_]u8{0} ** 128,
    title_len: usize = 0,

    /// Description for users
    description_buffer: [512]u8 = [_]u8{0} ** 512,
    description_len: usize = 0,

    /// Intent category
    category: IntentCategory = .custom,

    /// Sample invocation phrases
    invocation_phrases: [8][256]u8 = [_][256]u8{[_]u8{0} ** 256} ** 8,
    invocation_phrase_lens: [8]usize = [_]usize{0} ** 8,
    invocation_phrase_count: usize = 0,

    /// Parameters (max 8)
    parameters: [8]IntentParameter = [_]IntentParameter{IntentParameter{}} ** 8,
    parameter_count: usize = 0,

    /// Whether intent supports background execution
    supports_background: bool = false,

    /// Whether intent requires confirmation
    requires_confirmation: bool = false,

    /// Whether intent is suggestable by assistant
    is_suggestable: bool = true,

    pub fn init(id: []const u8) IntentDefinition {
        var result = IntentDefinition{};
        const copy_len = @min(id.len, result.id_buffer.len);
        @memcpy(result.id_buffer[0..copy_len], id[0..copy_len]);
        result.id_len = copy_len;
        return result;
    }

    pub fn withTitle(self: IntentDefinition, title: []const u8) IntentDefinition {
        var result = self;
        const copy_len = @min(title.len, result.title_buffer.len);
        @memcpy(result.title_buffer[0..copy_len], title[0..copy_len]);
        result.title_len = copy_len;
        return result;
    }

    pub fn withDescription(self: IntentDefinition, description: []const u8) IntentDefinition {
        var result = self;
        const copy_len = @min(description.len, result.description_buffer.len);
        @memcpy(result.description_buffer[0..copy_len], description[0..copy_len]);
        result.description_len = copy_len;
        return result;
    }

    pub fn withCategory(self: IntentDefinition, category: IntentCategory) IntentDefinition {
        var result = self;
        result.category = category;
        return result;
    }

    pub fn addInvocationPhrase(self: IntentDefinition, phrase: []const u8) IntentDefinition {
        var result = self;
        if (result.invocation_phrase_count < 8) {
            const copy_len = @min(phrase.len, 256);
            @memcpy(result.invocation_phrases[result.invocation_phrase_count][0..copy_len], phrase[0..copy_len]);
            result.invocation_phrase_lens[result.invocation_phrase_count] = copy_len;
            result.invocation_phrase_count += 1;
        }
        return result;
    }

    pub fn addParameter(self: IntentDefinition, param: IntentParameter) IntentDefinition {
        var result = self;
        if (result.parameter_count < 8) {
            result.parameters[result.parameter_count] = param;
            result.parameter_count += 1;
        }
        return result;
    }

    pub fn withBackground(self: IntentDefinition, supported: bool) IntentDefinition {
        var result = self;
        result.supports_background = supported;
        return result;
    }

    pub fn withConfirmation(self: IntentDefinition, required: bool) IntentDefinition {
        var result = self;
        result.requires_confirmation = required;
        return result;
    }

    pub fn withSuggestable(self: IntentDefinition, suggestable: bool) IntentDefinition {
        var result = self;
        result.is_suggestable = suggestable;
        return result;
    }

    pub fn getId(self: *const IntentDefinition) []const u8 {
        return self.id_buffer[0..self.id_len];
    }

    pub fn getTitle(self: *const IntentDefinition) []const u8 {
        return self.title_buffer[0..self.title_len];
    }

    pub fn getDescription(self: *const IntentDefinition) []const u8 {
        return self.description_buffer[0..self.description_len];
    }

    pub fn getInvocationPhrase(self: *const IntentDefinition, index: usize) ?[]const u8 {
        if (index < self.invocation_phrase_count) {
            return self.invocation_phrases[index][0..self.invocation_phrase_lens[index]];
        }
        return null;
    }

    pub fn getParameter(self: *const IntentDefinition, index: usize) ?*const IntentParameter {
        if (index < self.parameter_count) {
            return &self.parameters[index];
        }
        return null;
    }
};

/// Parsed parameter value from voice input
pub const ParameterValue = struct {
    /// Parameter name
    name_buffer: [64]u8 = [_]u8{0} ** 64,
    name_len: usize = 0,

    /// String value
    string_value_buffer: [512]u8 = [_]u8{0} ** 512,
    string_value_len: usize = 0,

    /// Numeric value (if applicable)
    number_value: ?f64 = null,

    /// Boolean value (if applicable)
    bool_value: ?bool = null,

    /// Timestamp value (if date/time)
    timestamp_value: ?i64 = null,

    /// Confidence score (0-1)
    confidence: f32 = 1.0,

    pub fn initString(name: []const u8, value: []const u8) ParameterValue {
        var result = ParameterValue{};
        const name_len = @min(name.len, result.name_buffer.len);
        @memcpy(result.name_buffer[0..name_len], name[0..name_len]);
        result.name_len = name_len;

        const value_len = @min(value.len, result.string_value_buffer.len);
        @memcpy(result.string_value_buffer[0..value_len], value[0..value_len]);
        result.string_value_len = value_len;
        return result;
    }

    pub fn initNumber(name: []const u8, value: f64) ParameterValue {
        var result = ParameterValue{};
        const name_len = @min(name.len, result.name_buffer.len);
        @memcpy(result.name_buffer[0..name_len], name[0..name_len]);
        result.name_len = name_len;
        result.number_value = value;
        return result;
    }

    pub fn initBool(name: []const u8, value: bool) ParameterValue {
        var result = ParameterValue{};
        const name_len = @min(name.len, result.name_buffer.len);
        @memcpy(result.name_buffer[0..name_len], name[0..name_len]);
        result.name_len = name_len;
        result.bool_value = value;
        return result;
    }

    pub fn withConfidence(self: ParameterValue, confidence: f32) ParameterValue {
        var result = self;
        result.confidence = confidence;
        return result;
    }

    pub fn getName(self: *const ParameterValue) []const u8 {
        return self.name_buffer[0..self.name_len];
    }

    pub fn getStringValue(self: *const ParameterValue) []const u8 {
        return self.string_value_buffer[0..self.string_value_len];
    }
};

/// Voice request from assistant
pub const VoiceRequest = struct {
    /// Request ID
    request_id_buffer: [64]u8 = [_]u8{0} ** 64,
    request_id_len: usize = 0,

    /// Intent ID
    intent_id_buffer: [128]u8 = [_]u8{0} ** 128,
    intent_id_len: usize = 0,

    /// Raw transcription
    transcription_buffer: [1024]u8 = [_]u8{0} ** 1024,
    transcription_len: usize = 0,

    /// Source platform
    platform: AssistantPlatform = .unknown,

    /// Parsed parameters (max 8)
    parameters: [8]ParameterValue = [_]ParameterValue{ParameterValue{}} ** 8,
    parameter_count: usize = 0,

    /// User locale
    locale_buffer: [16]u8 = [_]u8{0} ** 16,
    locale_len: usize = 0,

    /// Timestamp
    timestamp: i64 = 0,

    /// Whether user confirmed the action
    is_confirmed: bool = false,

    /// Confidence score for intent match
    intent_confidence: f32 = 1.0,

    pub fn init(request_id: []const u8) VoiceRequest {
        var result = VoiceRequest{
            .timestamp = getCurrentTimestamp(),
        };
        const copy_len = @min(request_id.len, result.request_id_buffer.len);
        @memcpy(result.request_id_buffer[0..copy_len], request_id[0..copy_len]);
        result.request_id_len = copy_len;
        return result;
    }

    pub fn withIntent(self: VoiceRequest, intent_id: []const u8) VoiceRequest {
        var result = self;
        const copy_len = @min(intent_id.len, result.intent_id_buffer.len);
        @memcpy(result.intent_id_buffer[0..copy_len], intent_id[0..copy_len]);
        result.intent_id_len = copy_len;
        return result;
    }

    pub fn withTranscription(self: VoiceRequest, transcription: []const u8) VoiceRequest {
        var result = self;
        const copy_len = @min(transcription.len, result.transcription_buffer.len);
        @memcpy(result.transcription_buffer[0..copy_len], transcription[0..copy_len]);
        result.transcription_len = copy_len;
        return result;
    }

    pub fn withPlatform(self: VoiceRequest, platform: AssistantPlatform) VoiceRequest {
        var result = self;
        result.platform = platform;
        return result;
    }

    pub fn addParameter(self: VoiceRequest, param: ParameterValue) VoiceRequest {
        var result = self;
        if (result.parameter_count < 8) {
            result.parameters[result.parameter_count] = param;
            result.parameter_count += 1;
        }
        return result;
    }

    pub fn withLocale(self: VoiceRequest, locale: []const u8) VoiceRequest {
        var result = self;
        const copy_len = @min(locale.len, result.locale_buffer.len);
        @memcpy(result.locale_buffer[0..copy_len], locale[0..copy_len]);
        result.locale_len = copy_len;
        return result;
    }

    pub fn withConfirmed(self: VoiceRequest, confirmed: bool) VoiceRequest {
        var result = self;
        result.is_confirmed = confirmed;
        return result;
    }

    pub fn withIntentConfidence(self: VoiceRequest, confidence: f32) VoiceRequest {
        var result = self;
        result.intent_confidence = confidence;
        return result;
    }

    pub fn getRequestId(self: *const VoiceRequest) []const u8 {
        return self.request_id_buffer[0..self.request_id_len];
    }

    pub fn getIntentId(self: *const VoiceRequest) []const u8 {
        return self.intent_id_buffer[0..self.intent_id_len];
    }

    pub fn getTranscription(self: *const VoiceRequest) []const u8 {
        return self.transcription_buffer[0..self.transcription_len];
    }

    pub fn getLocale(self: *const VoiceRequest) []const u8 {
        return self.locale_buffer[0..self.locale_len];
    }

    pub fn getParameter(self: *const VoiceRequest, name: []const u8) ?*const ParameterValue {
        for (&self.parameters, 0..) |*param, i| {
            if (i >= self.parameter_count) break;
            if (std.mem.eql(u8, param.name_buffer[0..param.name_len], name)) {
                return param;
            }
        }
        return null;
    }
};

/// Response type
pub const ResponseType = enum {
    success,
    failure,
    needs_confirmation,
    needs_disambiguation,
    needs_more_info,
    in_progress,
};

/// Visual card for response
pub const ResponseCard = struct {
    /// Card title
    title_buffer: [128]u8 = [_]u8{0} ** 128,
    title_len: usize = 0,

    /// Card subtitle
    subtitle_buffer: [256]u8 = [_]u8{0} ** 256,
    subtitle_len: usize = 0,

    /// Card body text
    body_buffer: [1024]u8 = [_]u8{0} ** 1024,
    body_len: usize = 0,

    /// Image URL
    image_url_buffer: [512]u8 = [_]u8{0} ** 512,
    image_url_len: usize = 0,

    /// Action URL (deep link)
    action_url_buffer: [512]u8 = [_]u8{0} ** 512,
    action_url_len: usize = 0,

    pub fn init(title: []const u8) ResponseCard {
        var result = ResponseCard{};
        const copy_len = @min(title.len, result.title_buffer.len);
        @memcpy(result.title_buffer[0..copy_len], title[0..copy_len]);
        result.title_len = copy_len;
        return result;
    }

    pub fn withSubtitle(self: ResponseCard, subtitle: []const u8) ResponseCard {
        var result = self;
        const copy_len = @min(subtitle.len, result.subtitle_buffer.len);
        @memcpy(result.subtitle_buffer[0..copy_len], subtitle[0..copy_len]);
        result.subtitle_len = copy_len;
        return result;
    }

    pub fn withBody(self: ResponseCard, body: []const u8) ResponseCard {
        var result = self;
        const copy_len = @min(body.len, result.body_buffer.len);
        @memcpy(result.body_buffer[0..copy_len], body[0..copy_len]);
        result.body_len = copy_len;
        return result;
    }

    pub fn withImageUrl(self: ResponseCard, url: []const u8) ResponseCard {
        var result = self;
        const copy_len = @min(url.len, result.image_url_buffer.len);
        @memcpy(result.image_url_buffer[0..copy_len], url[0..copy_len]);
        result.image_url_len = copy_len;
        return result;
    }

    pub fn withActionUrl(self: ResponseCard, url: []const u8) ResponseCard {
        var result = self;
        const copy_len = @min(url.len, result.action_url_buffer.len);
        @memcpy(result.action_url_buffer[0..copy_len], url[0..copy_len]);
        result.action_url_len = copy_len;
        return result;
    }

    pub fn getTitle(self: *const ResponseCard) []const u8 {
        return self.title_buffer[0..self.title_len];
    }

    pub fn getSubtitle(self: *const ResponseCard) []const u8 {
        return self.subtitle_buffer[0..self.subtitle_len];
    }

    pub fn getBody(self: *const ResponseCard) []const u8 {
        return self.body_buffer[0..self.body_len];
    }
};

/// Voice response to send back
pub const VoiceResponse = struct {
    /// Response type
    response_type: ResponseType = .success,

    /// Spoken response text (SSML supported)
    speech_buffer: [2048]u8 = [_]u8{0} ** 2048,
    speech_len: usize = 0,

    /// Display text (if different from speech)
    display_text_buffer: [2048]u8 = [_]u8{0} ** 2048,
    display_text_len: usize = 0,

    /// Visual card (optional)
    card: ?ResponseCard = null,

    /// Whether to keep session open for follow-up
    keep_session_open: bool = false,

    /// Reprompt text if user doesn't respond
    reprompt_buffer: [512]u8 = [_]u8{0} ** 512,
    reprompt_len: usize = 0,

    /// Disambiguation options (for needs_disambiguation)
    disambiguation_options: [4][128]u8 = [_][128]u8{[_]u8{0} ** 128} ** 4,
    disambiguation_option_lens: [4]usize = [_]usize{0} ** 4,
    disambiguation_count: usize = 0,

    /// Custom data to pass to app
    custom_data_buffer: [4096]u8 = [_]u8{0} ** 4096,
    custom_data_len: usize = 0,

    pub fn success(speech: []const u8) VoiceResponse {
        var result = VoiceResponse{
            .response_type = .success,
        };
        const copy_len = @min(speech.len, result.speech_buffer.len);
        @memcpy(result.speech_buffer[0..copy_len], speech[0..copy_len]);
        result.speech_len = copy_len;
        return result;
    }

    pub fn failure(speech: []const u8) VoiceResponse {
        var result = VoiceResponse{
            .response_type = .failure,
        };
        const copy_len = @min(speech.len, result.speech_buffer.len);
        @memcpy(result.speech_buffer[0..copy_len], speech[0..copy_len]);
        result.speech_len = copy_len;
        return result;
    }

    pub fn needsConfirmation(speech: []const u8) VoiceResponse {
        var result = VoiceResponse{
            .response_type = .needs_confirmation,
            .keep_session_open = true,
        };
        const copy_len = @min(speech.len, result.speech_buffer.len);
        @memcpy(result.speech_buffer[0..copy_len], speech[0..copy_len]);
        result.speech_len = copy_len;
        return result;
    }

    pub fn needsMoreInfo(speech: []const u8) VoiceResponse {
        var result = VoiceResponse{
            .response_type = .needs_more_info,
            .keep_session_open = true,
        };
        const copy_len = @min(speech.len, result.speech_buffer.len);
        @memcpy(result.speech_buffer[0..copy_len], speech[0..copy_len]);
        result.speech_len = copy_len;
        return result;
    }

    pub fn withDisplayText(self: VoiceResponse, text: []const u8) VoiceResponse {
        var result = self;
        const copy_len = @min(text.len, result.display_text_buffer.len);
        @memcpy(result.display_text_buffer[0..copy_len], text[0..copy_len]);
        result.display_text_len = copy_len;
        return result;
    }

    pub fn withCard(self: VoiceResponse, card: ResponseCard) VoiceResponse {
        var result = self;
        result.card = card;
        return result;
    }

    pub fn withReprompt(self: VoiceResponse, reprompt: []const u8) VoiceResponse {
        var result = self;
        const copy_len = @min(reprompt.len, result.reprompt_buffer.len);
        @memcpy(result.reprompt_buffer[0..copy_len], reprompt[0..copy_len]);
        result.reprompt_len = copy_len;
        return result;
    }

    pub fn addDisambiguationOption(self: VoiceResponse, option: []const u8) VoiceResponse {
        var result = self;
        if (result.disambiguation_count < 4) {
            const copy_len = @min(option.len, 128);
            @memcpy(result.disambiguation_options[result.disambiguation_count][0..copy_len], option[0..copy_len]);
            result.disambiguation_option_lens[result.disambiguation_count] = copy_len;
            result.disambiguation_count += 1;
        }
        return result;
    }

    pub fn withCustomData(self: VoiceResponse, data: []const u8) VoiceResponse {
        var result = self;
        const copy_len = @min(data.len, result.custom_data_buffer.len);
        @memcpy(result.custom_data_buffer[0..copy_len], data[0..copy_len]);
        result.custom_data_len = copy_len;
        return result;
    }

    pub fn getSpeech(self: *const VoiceResponse) []const u8 {
        return self.speech_buffer[0..self.speech_len];
    }

    pub fn getDisplayText(self: *const VoiceResponse) []const u8 {
        if (self.display_text_len > 0) {
            return self.display_text_buffer[0..self.display_text_len];
        }
        return self.speech_buffer[0..self.speech_len];
    }

    pub fn getReprompt(self: *const VoiceResponse) []const u8 {
        return self.reprompt_buffer[0..self.reprompt_len];
    }
};

/// Shortcut/routine donation for suggestions
pub const ShortcutDonation = struct {
    /// Intent ID
    intent_id_buffer: [128]u8 = [_]u8{0} ** 128,
    intent_id_len: usize = 0,

    /// Suggested phrase
    phrase_buffer: [256]u8 = [_]u8{0} ** 256,
    phrase_len: usize = 0,

    /// Title for shortcut
    title_buffer: [128]u8 = [_]u8{0} ** 128,
    title_len: usize = 0,

    /// Subtitle
    subtitle_buffer: [256]u8 = [_]u8{0} ** 256,
    subtitle_len: usize = 0,

    /// Parameters to include
    parameters: [8]ParameterValue = [_]ParameterValue{ParameterValue{}} ** 8,
    parameter_count: usize = 0,

    /// When this shortcut was last used
    last_used: i64 = 0,

    /// Usage count for relevance
    usage_count: u32 = 0,

    pub fn init(intent_id: []const u8) ShortcutDonation {
        var result = ShortcutDonation{};
        const copy_len = @min(intent_id.len, result.intent_id_buffer.len);
        @memcpy(result.intent_id_buffer[0..copy_len], intent_id[0..copy_len]);
        result.intent_id_len = copy_len;
        return result;
    }

    pub fn withPhrase(self: ShortcutDonation, phrase: []const u8) ShortcutDonation {
        var result = self;
        const copy_len = @min(phrase.len, result.phrase_buffer.len);
        @memcpy(result.phrase_buffer[0..copy_len], phrase[0..copy_len]);
        result.phrase_len = copy_len;
        return result;
    }

    pub fn withTitle(self: ShortcutDonation, title: []const u8) ShortcutDonation {
        var result = self;
        const copy_len = @min(title.len, result.title_buffer.len);
        @memcpy(result.title_buffer[0..copy_len], title[0..copy_len]);
        result.title_len = copy_len;
        return result;
    }

    pub fn withSubtitle(self: ShortcutDonation, subtitle: []const u8) ShortcutDonation {
        var result = self;
        const copy_len = @min(subtitle.len, result.subtitle_buffer.len);
        @memcpy(result.subtitle_buffer[0..copy_len], subtitle[0..copy_len]);
        result.subtitle_len = copy_len;
        return result;
    }

    pub fn addParameter(self: ShortcutDonation, param: ParameterValue) ShortcutDonation {
        var result = self;
        if (result.parameter_count < 8) {
            result.parameters[result.parameter_count] = param;
            result.parameter_count += 1;
        }
        return result;
    }

    pub fn getIntentId(self: *const ShortcutDonation) []const u8 {
        return self.intent_id_buffer[0..self.intent_id_len];
    }

    pub fn getPhrase(self: *const ShortcutDonation) []const u8 {
        return self.phrase_buffer[0..self.phrase_len];
    }

    pub fn getTitle(self: *const ShortcutDonation) []const u8 {
        return self.title_buffer[0..self.title_len];
    }

    pub fn recordUsage(self: *ShortcutDonation) void {
        self.last_used = getCurrentTimestamp();
        self.usage_count += 1;
    }
};

/// Custom vocabulary term
pub const VocabularyTerm = struct {
    /// The term/phrase
    term_buffer: [128]u8 = [_]u8{0} ** 128,
    term_len: usize = 0,

    /// Alternative pronunciations
    pronunciations: [4][128]u8 = [_][128]u8{[_]u8{0} ** 128} ** 4,
    pronunciation_lens: [4]usize = [_]usize{0} ** 4,
    pronunciation_count: usize = 0,

    /// Type of vocabulary
    vocab_type: VocabType = .custom,

    pub const VocabType = enum {
        contact_name,
        place_name,
        media_title,
        playlist_name,
        custom,
    };

    pub fn init(term: []const u8) VocabularyTerm {
        var result = VocabularyTerm{};
        const copy_len = @min(term.len, result.term_buffer.len);
        @memcpy(result.term_buffer[0..copy_len], term[0..copy_len]);
        result.term_len = copy_len;
        return result;
    }

    pub fn withType(self: VocabularyTerm, vocab_type: VocabType) VocabularyTerm {
        var result = self;
        result.vocab_type = vocab_type;
        return result;
    }

    pub fn addPronunciation(self: VocabularyTerm, pronunciation: []const u8) VocabularyTerm {
        var result = self;
        if (result.pronunciation_count < 4) {
            const copy_len = @min(pronunciation.len, 128);
            @memcpy(result.pronunciations[result.pronunciation_count][0..copy_len], pronunciation[0..copy_len]);
            result.pronunciation_lens[result.pronunciation_count] = copy_len;
            result.pronunciation_count += 1;
        }
        return result;
    }

    pub fn getTerm(self: *const VocabularyTerm) []const u8 {
        return self.term_buffer[0..self.term_len];
    }
};

/// Intent handler callback type
pub const IntentHandler = *const fn (*const VoiceRequest) VoiceResponse;

/// Voice assistant controller
pub const VoiceAssistantController = struct {
    allocator: Allocator,
    platform: AssistantPlatform,
    intents: std.ArrayListUnmanaged(IntentDefinition),
    shortcuts: std.ArrayListUnmanaged(ShortcutDonation),
    vocabulary: std.ArrayListUnmanaged(VocabularyTerm),
    is_enabled: bool,

    pub fn init(allocator: Allocator) VoiceAssistantController {
        const platform = detectPlatform();
        return .{
            .allocator = allocator,
            .platform = platform,
            .intents = .empty,
            .shortcuts = .empty,
            .vocabulary = .empty,
            .is_enabled = true,
        };
    }

    pub fn deinit(self: *VoiceAssistantController) void {
        self.intents.deinit(self.allocator);
        self.shortcuts.deinit(self.allocator);
        self.vocabulary.deinit(self.allocator);
    }

    fn detectPlatform() AssistantPlatform {
        return switch (builtin.os.tag) {
            .ios, .macos => .siri,
            .linux => if (builtin.abi == .android) .google_assistant else .unknown,
            .windows => .cortana,
            else => .unknown,
        };
    }

    pub fn registerIntent(self: *VoiceAssistantController, intent: IntentDefinition) !void {
        try self.intents.append(self.allocator, intent);
    }

    pub fn unregisterIntent(self: *VoiceAssistantController, intent_id: []const u8) bool {
        for (self.intents.items, 0..) |intent, i| {
            if (std.mem.eql(u8, intent.id_buffer[0..intent.id_len], intent_id)) {
                _ = self.intents.orderedRemove(i);
                return true;
            }
        }
        return false;
    }

    pub fn getIntent(self: *VoiceAssistantController, intent_id: []const u8) ?*const IntentDefinition {
        for (self.intents.items) |*intent| {
            if (std.mem.eql(u8, intent.id_buffer[0..intent.id_len], intent_id)) {
                return intent;
            }
        }
        return null;
    }

    pub fn donateShortcut(self: *VoiceAssistantController, shortcut: ShortcutDonation) !void {
        try self.shortcuts.append(self.allocator, shortcut);
    }

    pub fn deleteShortcut(self: *VoiceAssistantController, intent_id: []const u8) bool {
        for (self.shortcuts.items, 0..) |shortcut, i| {
            if (std.mem.eql(u8, shortcut.intent_id_buffer[0..shortcut.intent_id_len], intent_id)) {
                _ = self.shortcuts.orderedRemove(i);
                return true;
            }
        }
        return false;
    }

    pub fn addVocabulary(self: *VoiceAssistantController, term: VocabularyTerm) !void {
        try self.vocabulary.append(self.allocator, term);
    }

    pub fn clearVocabulary(self: *VoiceAssistantController) void {
        self.vocabulary.clearRetainingCapacity();
    }

    pub fn setEnabled(self: *VoiceAssistantController, enabled: bool) void {
        self.is_enabled = enabled;
    }

    pub fn handleRequest(self: *VoiceAssistantController, request: VoiceRequest, handler: IntentHandler) VoiceResponse {
        if (!self.is_enabled) {
            return VoiceResponse.failure("Voice assistant is currently disabled.");
        }

        // Verify intent is registered
        const intent_id = request.getIntentId();
        if (self.getIntent(intent_id) == null) {
            return VoiceResponse.failure("I don't know how to handle that request.");
        }

        // Call the handler
        return handler(&request);
    }

    pub fn getIntentCount(self: *VoiceAssistantController) usize {
        return self.intents.items.len;
    }

    pub fn getShortcutCount(self: *VoiceAssistantController) usize {
        return self.shortcuts.items.len;
    }

    pub fn getVocabularyCount(self: *VoiceAssistantController) usize {
        return self.vocabulary.items.len;
    }

    pub fn getSuggestedShortcuts(self: *VoiceAssistantController, max_count: usize) []const ShortcutDonation {
        const count = @min(max_count, self.shortcuts.items.len);
        return self.shortcuts.items[0..count];
    }
};

// ============================================================================
// Tests
// ============================================================================

test "AssistantPlatform display names and features" {
    try std.testing.expectEqualStrings("Siri", AssistantPlatform.siri.displayName());
    try std.testing.expectEqualStrings("Google Assistant", AssistantPlatform.google_assistant.displayName());
    try std.testing.expect(AssistantPlatform.siri.supportsVisualResponse());
    try std.testing.expect(AssistantPlatform.alexa.supportsVisualResponse());
}

test "IntentCategory display names" {
    try std.testing.expectEqualStrings("Messaging", IntentCategory.messaging.displayName());
    try std.testing.expectEqualStrings("Smart Home", IntentCategory.smart_home.displayName());
    try std.testing.expectEqualStrings("Lists & Reminders", IntentCategory.lists.displayName());
}

test "ParameterType display names" {
    try std.testing.expectEqualStrings("Text", ParameterType.string.displayName());
    try std.testing.expectEqualStrings("Date & Time", ParameterType.datetime.displayName());
    try std.testing.expectEqualStrings("Currency", ParameterType.currency.displayName());
}

test "IntentParameter initialization and fluent API" {
    const param = IntentParameter.init("amount")
        .withDisplayName("Payment Amount")
        .withType(.currency)
        .withRequired(true)
        .withDefault("10.00")
        .withPrompt("How much would you like to send?");

    try std.testing.expectEqualStrings("amount", param.getName());
    try std.testing.expectEqualStrings("Payment Amount", param.getDisplayName());
    try std.testing.expect(param.param_type == .currency);
    try std.testing.expect(param.is_required);
    try std.testing.expectEqualStrings("10.00", param.getDefault());
    try std.testing.expectEqualStrings("How much would you like to send?", param.getPrompt());
}

test "IntentDefinition initialization and fluent API" {
    const intent = IntentDefinition.init("com.example.sendmoney")
        .withTitle("Send Money")
        .withDescription("Send money to a contact")
        .withCategory(.payments)
        .addInvocationPhrase("send money to")
        .addInvocationPhrase("pay")
        .addParameter(IntentParameter.init("recipient").withType(.contact).withRequired(true))
        .addParameter(IntentParameter.init("amount").withType(.currency).withRequired(true))
        .withConfirmation(true)
        .withBackground(false);

    try std.testing.expectEqualStrings("com.example.sendmoney", intent.getId());
    try std.testing.expectEqualStrings("Send Money", intent.getTitle());
    try std.testing.expect(intent.category == .payments);
    try std.testing.expect(intent.invocation_phrase_count == 2);
    try std.testing.expectEqualStrings("send money to", intent.getInvocationPhrase(0).?);
    try std.testing.expect(intent.parameter_count == 2);
    try std.testing.expect(intent.requires_confirmation);
}

test "ParameterValue string initialization" {
    const param = ParameterValue.initString("recipient", "John Doe")
        .withConfidence(0.95);

    try std.testing.expectEqualStrings("recipient", param.getName());
    try std.testing.expectEqualStrings("John Doe", param.getStringValue());
    try std.testing.expect(param.confidence == 0.95);
}

test "ParameterValue number initialization" {
    const param = ParameterValue.initNumber("amount", 50.0);

    try std.testing.expectEqualStrings("amount", param.getName());
    try std.testing.expect(param.number_value.? == 50.0);
}

test "ParameterValue bool initialization" {
    const param = ParameterValue.initBool("confirmed", true);

    try std.testing.expectEqualStrings("confirmed", param.getName());
    try std.testing.expect(param.bool_value.?);
}

test "VoiceRequest initialization and fluent API" {
    const request = VoiceRequest.init("req-001")
        .withIntent("com.example.sendmoney")
        .withTranscription("Send 50 dollars to John")
        .withPlatform(.siri)
        .addParameter(ParameterValue.initString("recipient", "John"))
        .addParameter(ParameterValue.initNumber("amount", 50.0))
        .withLocale("en-US")
        .withConfirmed(false)
        .withIntentConfidence(0.92);

    try std.testing.expectEqualStrings("req-001", request.getRequestId());
    try std.testing.expectEqualStrings("com.example.sendmoney", request.getIntentId());
    try std.testing.expectEqualStrings("Send 50 dollars to John", request.getTranscription());
    try std.testing.expect(request.platform == .siri);
    try std.testing.expect(request.parameter_count == 2);
    try std.testing.expectEqualStrings("en-US", request.getLocale());
    try std.testing.expect(request.intent_confidence == 0.92);
}

test "VoiceRequest parameter lookup" {
    const request = VoiceRequest.init("req-001")
        .addParameter(ParameterValue.initString("recipient", "John"))
        .addParameter(ParameterValue.initNumber("amount", 50.0));

    const recipient = request.getParameter("recipient");
    try std.testing.expect(recipient != null);
    try std.testing.expectEqualStrings("John", recipient.?.getStringValue());

    const amount = request.getParameter("amount");
    try std.testing.expect(amount != null);
    try std.testing.expect(amount.?.number_value.? == 50.0);

    const missing = request.getParameter("nonexistent");
    try std.testing.expect(missing == null);
}

test "ResponseCard initialization and fluent API" {
    const card = ResponseCard.init("Payment Sent")
        .withSubtitle("$50.00 to John Doe")
        .withBody("Your payment has been processed successfully.")
        .withImageUrl("https://example.com/success.png")
        .withActionUrl("myapp://payments/history");

    try std.testing.expectEqualStrings("Payment Sent", card.getTitle());
    try std.testing.expectEqualStrings("$50.00 to John Doe", card.getSubtitle());
    try std.testing.expectEqualStrings("Your payment has been processed successfully.", card.getBody());
}

test "VoiceResponse success" {
    const response = VoiceResponse.success("I've sent $50 to John.")
        .withDisplayText("Payment of $50 sent to John Doe")
        .withCard(ResponseCard.init("Payment Complete"));

    try std.testing.expect(response.response_type == .success);
    try std.testing.expectEqualStrings("I've sent $50 to John.", response.getSpeech());
    try std.testing.expectEqualStrings("Payment of $50 sent to John Doe", response.getDisplayText());
    try std.testing.expect(response.card != null);
}

test "VoiceResponse failure" {
    const response = VoiceResponse.failure("Sorry, I couldn't complete that payment.");

    try std.testing.expect(response.response_type == .failure);
    try std.testing.expectEqualStrings("Sorry, I couldn't complete that payment.", response.getSpeech());
}

test "VoiceResponse needsConfirmation" {
    const response = VoiceResponse.needsConfirmation("Would you like me to send $50 to John?")
        .withReprompt("Should I send the payment?");

    try std.testing.expect(response.response_type == .needs_confirmation);
    try std.testing.expect(response.keep_session_open);
    try std.testing.expectEqualStrings("Should I send the payment?", response.getReprompt());
}

test "VoiceResponse needsMoreInfo" {
    const response = VoiceResponse.needsMoreInfo("Who would you like to send money to?");

    try std.testing.expect(response.response_type == .needs_more_info);
    try std.testing.expect(response.keep_session_open);
}

test "VoiceResponse disambiguation" {
    var response = VoiceResponse.success("Which John did you mean?");
    response.response_type = .needs_disambiguation;
    response = response
        .addDisambiguationOption("John Doe")
        .addDisambiguationOption("John Smith")
        .addDisambiguationOption("John Williams");

    try std.testing.expect(response.response_type == .needs_disambiguation);
    try std.testing.expect(response.disambiguation_count == 3);
}

test "ShortcutDonation initialization and fluent API" {
    const shortcut = ShortcutDonation.init("com.example.ordercoffee")
        .withPhrase("Order my usual coffee")
        .withTitle("Order Coffee")
        .withSubtitle("Large latte with oat milk")
        .addParameter(ParameterValue.initString("size", "large"))
        .addParameter(ParameterValue.initString("type", "latte"));

    try std.testing.expectEqualStrings("com.example.ordercoffee", shortcut.getIntentId());
    try std.testing.expectEqualStrings("Order my usual coffee", shortcut.getPhrase());
    try std.testing.expectEqualStrings("Order Coffee", shortcut.getTitle());
    try std.testing.expect(shortcut.parameter_count == 2);
}

test "ShortcutDonation usage tracking" {
    var shortcut = ShortcutDonation.init("com.example.test");

    try std.testing.expect(shortcut.usage_count == 0);

    shortcut.recordUsage();
    try std.testing.expect(shortcut.usage_count == 1);
    try std.testing.expect(shortcut.last_used > 0);

    shortcut.recordUsage();
    try std.testing.expect(shortcut.usage_count == 2);
}

test "VocabularyTerm initialization and fluent API" {
    const term = VocabularyTerm.init("Acai Bowl")
        .withType(.media_title)
        .addPronunciation("ah-sah-ee bowl")
        .addPronunciation("ah-kai bowl");

    try std.testing.expectEqualStrings("Acai Bowl", term.getTerm());
    try std.testing.expect(term.vocab_type == .media_title);
    try std.testing.expect(term.pronunciation_count == 2);
}

test "VoiceAssistantController initialization" {
    var controller = VoiceAssistantController.init(std.testing.allocator);
    defer controller.deinit();

    try std.testing.expect(controller.is_enabled);
    try std.testing.expect(controller.getIntentCount() == 0);
    try std.testing.expect(controller.getShortcutCount() == 0);
}

test "VoiceAssistantController intent registration" {
    var controller = VoiceAssistantController.init(std.testing.allocator);
    defer controller.deinit();

    const intent = IntentDefinition.init("com.example.test")
        .withTitle("Test Intent")
        .withCategory(.custom);

    try controller.registerIntent(intent);
    try std.testing.expect(controller.getIntentCount() == 1);

    const found = controller.getIntent("com.example.test");
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("Test Intent", found.?.getTitle());
}

test "VoiceAssistantController intent unregistration" {
    var controller = VoiceAssistantController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.registerIntent(IntentDefinition.init("intent1"));
    try controller.registerIntent(IntentDefinition.init("intent2"));
    try std.testing.expect(controller.getIntentCount() == 2);

    try std.testing.expect(controller.unregisterIntent("intent1"));
    try std.testing.expect(controller.getIntentCount() == 1);

    try std.testing.expect(!controller.unregisterIntent("nonexistent"));
}

test "VoiceAssistantController shortcut donation" {
    var controller = VoiceAssistantController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.donateShortcut(ShortcutDonation.init("intent1").withPhrase("Do thing 1"));
    try controller.donateShortcut(ShortcutDonation.init("intent2").withPhrase("Do thing 2"));

    try std.testing.expect(controller.getShortcutCount() == 2);

    const suggestions = controller.getSuggestedShortcuts(10);
    try std.testing.expect(suggestions.len == 2);
}

test "VoiceAssistantController vocabulary" {
    var controller = VoiceAssistantController.init(std.testing.allocator);
    defer controller.deinit();

    try controller.addVocabulary(VocabularyTerm.init("Custom Term 1"));
    try controller.addVocabulary(VocabularyTerm.init("Custom Term 2"));

    try std.testing.expect(controller.getVocabularyCount() == 2);

    controller.clearVocabulary();
    try std.testing.expect(controller.getVocabularyCount() == 0);
}

test "VoiceAssistantController enable/disable" {
    var controller = VoiceAssistantController.init(std.testing.allocator);
    defer controller.deinit();

    try std.testing.expect(controller.is_enabled);

    controller.setEnabled(false);
    try std.testing.expect(!controller.is_enabled);

    controller.setEnabled(true);
    try std.testing.expect(controller.is_enabled);
}

fn testHandler(_: *const VoiceRequest) VoiceResponse {
    return VoiceResponse.success("Test response");
}

test "VoiceAssistantController request handling" {
    var controller = VoiceAssistantController.init(std.testing.allocator);
    defer controller.deinit();

    const intent = IntentDefinition.init("com.example.test");
    try controller.registerIntent(intent);

    const request = VoiceRequest.init("req-001")
        .withIntent("com.example.test");

    const response = controller.handleRequest(request, testHandler);
    try std.testing.expect(response.response_type == .success);
    try std.testing.expectEqualStrings("Test response", response.getSpeech());
}

test "VoiceAssistantController disabled handling" {
    var controller = VoiceAssistantController.init(std.testing.allocator);
    defer controller.deinit();

    controller.setEnabled(false);

    const request = VoiceRequest.init("req-001")
        .withIntent("com.example.test");

    const response = controller.handleRequest(request, testHandler);
    try std.testing.expect(response.response_type == .failure);
}

test "VoiceAssistantController unknown intent handling" {
    var controller = VoiceAssistantController.init(std.testing.allocator);
    defer controller.deinit();

    const request = VoiceRequest.init("req-001")
        .withIntent("com.example.unknown");

    const response = controller.handleRequest(request, testHandler);
    try std.testing.expect(response.response_type == .failure);
}

test "IntentDefinition null parameter access" {
    const intent = IntentDefinition.init("test");

    try std.testing.expect(intent.getParameter(0) == null);
    try std.testing.expect(intent.getInvocationPhrase(0) == null);
}

test "VoiceResponse getDisplayText fallback" {
    const response = VoiceResponse.success("Spoken text only");

    // When no display text is set, should return speech text
    try std.testing.expectEqualStrings("Spoken text only", response.getDisplayText());
}
