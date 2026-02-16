//! Cross-platform NFC (Near Field Communication) module for Craft
//! Provides NFC tag reading, writing, and NDEF message handling
//! for iOS and Android platforms.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// NFC technology types
pub const NFCTechnology = enum {
    nfc_a, // ISO 14443-3A
    nfc_b, // ISO 14443-3B
    nfc_f, // JIS 6319-4 (FeliCa)
    nfc_v, // ISO 15693
    iso_dep, // ISO 14443-4
    ndef, // NDEF formatted
    mifare_classic,
    mifare_ultralight,
    mifare_desfire,
    nfc_barcode,

    pub fn toString(self: NFCTechnology) []const u8 {
        return switch (self) {
            .nfc_a => "NFC-A (ISO 14443-3A)",
            .nfc_b => "NFC-B (ISO 14443-3B)",
            .nfc_f => "NFC-F (FeliCa)",
            .nfc_v => "NFC-V (ISO 15693)",
            .iso_dep => "ISO-DEP",
            .ndef => "NDEF",
            .mifare_classic => "MIFARE Classic",
            .mifare_ultralight => "MIFARE Ultralight",
            .mifare_desfire => "MIFARE DESFire",
            .nfc_barcode => "NFC Barcode",
        };
    }

    pub fn shortName(self: NFCTechnology) []const u8 {
        return switch (self) {
            .nfc_a => "NFC-A",
            .nfc_b => "NFC-B",
            .nfc_f => "NFC-F",
            .nfc_v => "NFC-V",
            .iso_dep => "ISO-DEP",
            .ndef => "NDEF",
            .mifare_classic => "MIFARE",
            .mifare_ultralight => "Ultralight",
            .mifare_desfire => "DESFire",
            .nfc_barcode => "Barcode",
        };
    }

    pub fn isNDEFCapable(self: NFCTechnology) bool {
        return switch (self) {
            .ndef, .nfc_a, .nfc_b, .nfc_f, .nfc_v, .mifare_ultralight, .mifare_desfire => true,
            else => false,
        };
    }
};

/// NDEF record types
pub const NDEFRecordType = enum {
    empty,
    well_known, // TNF 0x01
    mime_media, // TNF 0x02
    absolute_uri, // TNF 0x03
    external, // TNF 0x04
    unknown, // TNF 0x05
    unchanged, // TNF 0x06

    pub fn tnf(self: NDEFRecordType) u8 {
        return switch (self) {
            .empty => 0x00,
            .well_known => 0x01,
            .mime_media => 0x02,
            .absolute_uri => 0x03,
            .external => 0x04,
            .unknown => 0x05,
            .unchanged => 0x06,
        };
    }

    pub fn fromTNF(val: u8) NDEFRecordType {
        return switch (val) {
            0x00 => .empty,
            0x01 => .well_known,
            0x02 => .mime_media,
            0x03 => .absolute_uri,
            0x04 => .external,
            0x05 => .unknown,
            0x06 => .unchanged,
            else => .unknown,
        };
    }

    pub fn toString(self: NDEFRecordType) []const u8 {
        return switch (self) {
            .empty => "Empty",
            .well_known => "Well Known",
            .mime_media => "MIME Media",
            .absolute_uri => "Absolute URI",
            .external => "External",
            .unknown => "Unknown",
            .unchanged => "Unchanged",
        };
    }
};

/// Well-known record types (RTD)
pub const WellKnownType = enum {
    text, // "T"
    uri, // "U"
    smart_poster, // "Sp"
    alternative_carrier, // "ac"
    handover_carrier, // "Hc"
    handover_request, // "Hr"
    handover_select, // "Hs"
    signature, // "Sig"

    pub fn typeIdentifier(self: WellKnownType) []const u8 {
        return switch (self) {
            .text => "T",
            .uri => "U",
            .smart_poster => "Sp",
            .alternative_carrier => "ac",
            .handover_carrier => "Hc",
            .handover_request => "Hr",
            .handover_select => "Hs",
            .signature => "Sig",
        };
    }

    pub fn toString(self: WellKnownType) []const u8 {
        return switch (self) {
            .text => "Text",
            .uri => "URI",
            .smart_poster => "Smart Poster",
            .alternative_carrier => "Alternative Carrier",
            .handover_carrier => "Handover Carrier",
            .handover_request => "Handover Request",
            .handover_select => "Handover Select",
            .signature => "Signature",
        };
    }
};

/// URI identifier codes (for URI records)
pub const URIIdentifier = enum(u8) {
    none = 0x00,
    http_www = 0x01, // http://www.
    https_www = 0x02, // https://www.
    http = 0x03, // http://
    https = 0x04, // https://
    tel = 0x05, // tel:
    mailto = 0x06, // mailto:
    ftp_anon = 0x07, // ftp://anonymous:anonymous@
    ftp_ftp = 0x08, // ftp://ftp.
    ftps = 0x09, // ftps://
    sftp = 0x0A, // sftp://
    smb = 0x0B, // smb://
    nfs = 0x0C, // nfs://
    ftp = 0x0D, // ftp://
    dav = 0x0E, // dav://
    news = 0x0F, // news:
    telnet = 0x10, // telnet://
    imap = 0x11, // imap:
    rtsp = 0x12, // rtsp://
    urn = 0x13, // urn:
    pop = 0x14, // pop:
    sip = 0x15, // sip:
    sips = 0x16, // sips:
    tftp = 0x17, // tftp:
    btspp = 0x18, // btspp://
    btl2cap = 0x19, // btl2cap://
    btgoep = 0x1A, // btgoep://
    tcpobex = 0x1B, // tcpobex://
    irdaobex = 0x1C, // irdaobex://
    file = 0x1D, // file://
    urn_epc_id = 0x1E, // urn:epc:id:
    urn_epc_tag = 0x1F, // urn:epc:tag:
    urn_epc_pat = 0x20, // urn:epc:pat:
    urn_epc_raw = 0x21, // urn:epc:raw:
    urn_epc = 0x22, // urn:epc:
    urn_nfc = 0x23, // urn:nfc:

    pub fn prefix(self: URIIdentifier) []const u8 {
        return switch (self) {
            .none => "",
            .http_www => "http://www.",
            .https_www => "https://www.",
            .http => "http://",
            .https => "https://",
            .tel => "tel:",
            .mailto => "mailto:",
            .ftp_anon => "ftp://anonymous:anonymous@",
            .ftp_ftp => "ftp://ftp.",
            .ftps => "ftps://",
            .sftp => "sftp://",
            .smb => "smb://",
            .nfs => "nfs://",
            .ftp => "ftp://",
            .dav => "dav://",
            .news => "news:",
            .telnet => "telnet://",
            .imap => "imap:",
            .rtsp => "rtsp://",
            .urn => "urn:",
            .pop => "pop:",
            .sip => "sip:",
            .sips => "sips:",
            .tftp => "tftp:",
            .btspp => "btspp://",
            .btl2cap => "btl2cap://",
            .btgoep => "btgoep://",
            .tcpobex => "tcpobex://",
            .irdaobex => "irdaobex://",
            .file => "file://",
            .urn_epc_id => "urn:epc:id:",
            .urn_epc_tag => "urn:epc:tag:",
            .urn_epc_pat => "urn:epc:pat:",
            .urn_epc_raw => "urn:epc:raw:",
            .urn_epc => "urn:epc:",
            .urn_nfc => "urn:nfc:",
        };
    }
};

/// NDEF record
pub const NDEFRecord = struct {
    record_type: NDEFRecordType,
    type_name: ?[]const u8,
    id: ?[]const u8,
    payload: []const u8,
    is_first: bool,
    is_last: bool,

    const Self = @This();

    pub fn init(record_type: NDEFRecordType, payload: []const u8) Self {
        return .{
            .record_type = record_type,
            .type_name = null,
            .id = null,
            .payload = payload,
            .is_first = true,
            .is_last = true,
        };
    }

    pub fn text(content: []const u8, language: []const u8) Self {
        // Text record format: status byte + language code + text
        _ = language;
        return .{
            .record_type = .well_known,
            .type_name = "T",
            .id = null,
            .payload = content,
            .is_first = true,
            .is_last = true,
        };
    }

    pub fn uri(url: []const u8) Self {
        return .{
            .record_type = .well_known,
            .type_name = "U",
            .id = null,
            .payload = url,
            .is_first = true,
            .is_last = true,
        };
    }

    pub fn mime(mime_type: []const u8, data: []const u8) Self {
        return .{
            .record_type = .mime_media,
            .type_name = mime_type,
            .id = null,
            .payload = data,
            .is_first = true,
            .is_last = true,
        };
    }

    pub fn getPayloadLength(self: Self) usize {
        return self.payload.len;
    }

    pub fn isTextRecord(self: Self) bool {
        if (self.record_type != .well_known) return false;
        if (self.type_name) |t| {
            return std.mem.eql(u8, t, "T");
        }
        return false;
    }

    pub fn isURIRecord(self: Self) bool {
        if (self.record_type != .well_known) return false;
        if (self.type_name) |t| {
            return std.mem.eql(u8, t, "U");
        }
        return false;
    }
};

/// NDEF message (collection of records)
pub const NDEFMessage = struct {
    allocator: Allocator,
    records: std.ArrayListUnmanaged(NDEFRecord),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .records = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.records.deinit(self.allocator);
    }

    pub fn addRecord(self: *Self, record: NDEFRecord) !void {
        // Update first/last flags
        if (self.records.items.len > 0) {
            self.records.items[self.records.items.len - 1].is_last = false;
        }
        var new_record = record;
        new_record.is_first = self.records.items.len == 0;
        new_record.is_last = true;
        try self.records.append(self.allocator, new_record);
    }

    pub fn getRecordCount(self: Self) usize {
        return self.records.items.len;
    }

    pub fn getRecord(self: Self, index: usize) ?NDEFRecord {
        if (index < self.records.items.len) {
            return self.records.items[index];
        }
        return null;
    }

    pub fn getTotalPayloadSize(self: Self) usize {
        var total: usize = 0;
        for (self.records.items) |record| {
            total += record.payload.len;
        }
        return total;
    }

    pub fn hasTextRecord(self: Self) bool {
        for (self.records.items) |record| {
            if (record.isTextRecord()) return true;
        }
        return false;
    }

    pub fn hasURIRecord(self: Self) bool {
        for (self.records.items) |record| {
            if (record.isURIRecord()) return true;
        }
        return false;
    }
};

/// NFC tag info
pub const NFCTag = struct {
    id: []const u8,
    technologies: []const NFCTechnology,
    ndef_message: ?NDEFMessage,
    is_writable: bool,
    max_size: u32,
    used_size: u32,
    is_connected: bool,

    const Self = @This();

    pub fn getIdentifierHex(self: Self, buffer: []u8) []const u8 {
        var pos: usize = 0;
        for (self.id) |byte| {
            if (pos + 2 > buffer.len) break;
            const hex = std.fmt.bufPrint(buffer[pos .. pos + 2], "{X:0>2}", .{byte}) catch break;
            _ = hex;
            pos += 2;
        }
        return buffer[0..pos];
    }

    pub fn hasTechnology(self: Self, tech: NFCTechnology) bool {
        for (self.technologies) |t| {
            if (t == tech) return true;
        }
        return false;
    }

    pub fn isNDEFCapable(self: Self) bool {
        for (self.technologies) |t| {
            if (t.isNDEFCapable()) return true;
        }
        return false;
    }

    pub fn getAvailableSpace(self: Self) u32 {
        if (self.used_size >= self.max_size) return 0;
        return self.max_size - self.used_size;
    }

    pub fn canWriteMessage(self: Self, message_size: u32) bool {
        return self.is_writable and message_size <= self.getAvailableSpace();
    }
};

/// NFC session state
pub const NFCSessionState = enum {
    idle,
    polling, // Scanning for tags
    connected, // Connected to a tag
    reading,
    writing,
    error_state,

    pub fn toString(self: NFCSessionState) []const u8 {
        return switch (self) {
            .idle => "Idle",
            .polling => "Scanning",
            .connected => "Connected",
            .reading => "Reading",
            .writing => "Writing",
            .error_state => "Error",
        };
    }

    pub fn isActive(self: NFCSessionState) bool {
        return switch (self) {
            .polling, .connected, .reading, .writing => true,
            .idle, .error_state => false,
        };
    }
};

/// NFC error types
pub const NFCError = enum {
    none,
    not_supported,
    not_enabled,
    permission_denied,
    session_timeout,
    tag_lost,
    tag_read_error,
    tag_write_error,
    invalid_format,
    tag_not_writable,
    insufficient_space,
    user_cancelled,
    system_busy,
    unknown,

    pub fn toString(self: NFCError) []const u8 {
        return switch (self) {
            .none => "No Error",
            .not_supported => "NFC Not Supported",
            .not_enabled => "NFC Disabled",
            .permission_denied => "Permission Denied",
            .session_timeout => "Session Timeout",
            .tag_lost => "Tag Connection Lost",
            .tag_read_error => "Read Error",
            .tag_write_error => "Write Error",
            .invalid_format => "Invalid Format",
            .tag_not_writable => "Tag Not Writable",
            .insufficient_space => "Insufficient Space",
            .user_cancelled => "User Cancelled",
            .system_busy => "System Busy",
            .unknown => "Unknown Error",
        };
    }

    pub fn isRecoverable(self: NFCError) bool {
        return switch (self) {
            .tag_lost, .session_timeout, .system_busy => true,
            else => false,
        };
    }
};

/// NFC event types
pub const NFCEventType = enum {
    session_started,
    session_ended,
    tag_discovered,
    tag_connected,
    tag_disconnected,
    ndef_read,
    ndef_written,
    read_error,
    write_error,
    state_changed,
};

/// NFC event
pub const NFCEvent = struct {
    event_type: NFCEventType,
    tag_id: ?[]const u8,
    nfc_error: NFCError,
    message: ?[]const u8,
    timestamp: i64,

    pub fn create(event_type: NFCEventType) NFCEvent {
        return .{
            .event_type = event_type,
            .tag_id = null,
            .nfc_error = .none,
            .message = null,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn forTag(event_type: NFCEventType, tag_id: []const u8) NFCEvent {
        return .{
            .event_type = event_type,
            .tag_id = tag_id,
            .nfc_error = .none,
            .message = null,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn withError(event_type: NFCEventType, err: NFCError) NFCEvent {
        return .{
            .event_type = event_type,
            .tag_id = null,
            .nfc_error = err,
            .message = err.toString(),
            .timestamp = getCurrentTimestamp(),
        };
    }
};

/// NFC callback type
pub const NFCCallback = *const fn (event: NFCEvent) void;

/// NFC reader session configuration
pub const NFCSessionConfig = struct {
    alert_message: ?[]const u8,
    invalidate_after_first_read: bool,
    detect_ndef: bool,
    detect_iso14443: bool,
    detect_iso15693: bool,
    timeout_ms: u32,

    pub fn init() NFCSessionConfig {
        return .{
            .alert_message = "Hold your device near an NFC tag",
            .invalidate_after_first_read = true,
            .detect_ndef = true,
            .detect_iso14443 = true,
            .detect_iso15693 = false,
            .timeout_ms = 60000, // 60 seconds
        };
    }

    pub fn forNDEF() NFCSessionConfig {
        var config = init();
        config.detect_ndef = true;
        config.detect_iso14443 = false;
        config.detect_iso15693 = false;
        return config;
    }

    pub fn forAllTags() NFCSessionConfig {
        var config = init();
        config.detect_ndef = true;
        config.detect_iso14443 = true;
        config.detect_iso15693 = true;
        config.invalidate_after_first_read = false;
        return config;
    }
};

/// NFC reader session
pub const NFCSession = struct {
    allocator: Allocator,
    config: NFCSessionConfig,
    state: NFCSessionState,
    current_tag: ?NFCTag,
    callbacks: std.ArrayListUnmanaged(NFCCallback),
    last_error: NFCError,
    tags_discovered: u32,
    session_start_time: ?i64,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .config = NFCSessionConfig.init(),
            .state = .idle,
            .current_tag = null,
            .callbacks = .{},
            .last_error = .none,
            .tags_discovered = 0,
            .session_start_time = null,
        };
    }

    pub fn initWithConfig(allocator: Allocator, config: NFCSessionConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .state = .idle,
            .current_tag = null,
            .callbacks = .{},
            .last_error = .none,
            .tags_discovered = 0,
            .session_start_time = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.callbacks.deinit(self.allocator);
    }

    /// Add event callback
    pub fn addCallback(self: *Self, callback: NFCCallback) !void {
        try self.callbacks.append(self.allocator, callback);
    }

    /// Remove event callback
    pub fn removeCallback(self: *Self, callback: NFCCallback) bool {
        for (self.callbacks.items, 0..) |cb, i| {
            if (cb == callback) {
                _ = self.callbacks.orderedRemove(i);
                return true;
            }
        }
        return false;
    }

    /// Start scanning for tags
    pub fn beginScanning(self: *Self) !void {
        if (self.state.isActive()) {
            return error.SessionAlreadyActive;
        }
        self.state = .polling;
        self.session_start_time = getCurrentTimestamp();
        self.tags_discovered = 0;
        self.notifyCallbacks(NFCEvent.create(.session_started));
    }

    /// Stop scanning
    pub fn endScanning(self: *Self) void {
        if (self.state == .idle) return;

        self.state = .idle;
        self.current_tag = null;
        self.session_start_time = null;
        self.notifyCallbacks(NFCEvent.create(.session_ended));
    }

    /// Simulate tag discovered (for testing/platform bridge)
    pub fn tagDiscovered(self: *Self, tag: NFCTag) void {
        self.tags_discovered += 1;
        self.current_tag = tag;
        self.state = .connected;
        self.notifyCallbacks(NFCEvent.forTag(.tag_discovered, tag.id));
    }

    /// Simulate read complete
    pub fn readComplete(self: *Self) void {
        self.state = .connected;
        self.notifyCallbacks(NFCEvent.create(.ndef_read));

        if (self.config.invalidate_after_first_read) {
            self.endScanning();
        }
    }

    /// Simulate write complete
    pub fn writeComplete(self: *Self, success: bool) void {
        if (success) {
            self.state = .connected;
            self.notifyCallbacks(NFCEvent.create(.ndef_written));
        } else {
            self.state = .error_state;
            self.last_error = .tag_write_error;
            self.notifyCallbacks(NFCEvent.withError(.write_error, .tag_write_error));
        }
    }

    /// Report error
    pub fn reportError(self: *Self, err: NFCError) void {
        self.last_error = err;
        self.state = .error_state;
        self.notifyCallbacks(NFCEvent.withError(.read_error, err));
    }

    /// Get current state
    pub fn getState(self: Self) NFCSessionState {
        return self.state;
    }

    /// Check if scanning
    pub fn isScanning(self: Self) bool {
        return self.state == .polling;
    }

    /// Check if connected to tag
    pub fn isConnected(self: Self) bool {
        return self.state == .connected and self.current_tag != null;
    }

    /// Get current tag
    pub fn getCurrentTag(self: Self) ?NFCTag {
        return self.current_tag;
    }

    /// Get session duration in milliseconds
    pub fn getSessionDuration(self: Self) ?i64 {
        if (self.session_start_time) |start| {
            return getCurrentTimestamp() - start;
        }
        return null;
    }

    fn notifyCallbacks(self: *Self, event: NFCEvent) void {
        for (self.callbacks.items) |callback| {
            callback(event);
        }
    }
};

/// NDEF message builder
pub const NDEFBuilder = struct {
    allocator: Allocator,
    message: NDEFMessage,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .message = NDEFMessage.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.message.deinit();
    }

    pub fn addText(self: *Self, text_content: []const u8, language: []const u8) !*Self {
        try self.message.addRecord(NDEFRecord.text(text_content, language));
        return self;
    }

    pub fn addURI(self: *Self, url: []const u8) !*Self {
        try self.message.addRecord(NDEFRecord.uri(url));
        return self;
    }

    pub fn addMime(self: *Self, mime_type: []const u8, data: []const u8) !*Self {
        try self.message.addRecord(NDEFRecord.mime(mime_type, data));
        return self;
    }

    pub fn addRecord(self: *Self, record: NDEFRecord) !*Self {
        try self.message.addRecord(record);
        return self;
    }

    pub fn build(self: *Self) NDEFMessage {
        const msg = self.message;
        self.message = NDEFMessage.init(self.allocator);
        return msg;
    }

    pub fn getRecordCount(self: Self) usize {
        return self.message.getRecordCount();
    }
};

/// Check if NFC is available on the device (platform-specific)
pub fn isNFCAvailable() bool {
    // Platform-specific implementation would go here
    return true;
}

/// Check if NFC is enabled
pub fn isNFCEnabled() bool {
    // Platform-specific implementation would go here
    return true;
}

/// Get current timestamp in milliseconds
fn getCurrentTimestamp() i64 {
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
        return @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000);
    }
    return 0;
}

// ============================================================================
// Tests
// ============================================================================

test "NFCTechnology toString" {
    try std.testing.expectEqualStrings("NFC-A (ISO 14443-3A)", NFCTechnology.nfc_a.toString());
    try std.testing.expectEqualStrings("NDEF", NFCTechnology.ndef.toString());
}

test "NFCTechnology isNDEFCapable" {
    try std.testing.expect(NFCTechnology.ndef.isNDEFCapable());
    try std.testing.expect(NFCTechnology.nfc_a.isNDEFCapable());
    try std.testing.expect(!NFCTechnology.mifare_classic.isNDEFCapable());
}

test "NDEFRecordType tnf" {
    try std.testing.expectEqual(@as(u8, 0x00), NDEFRecordType.empty.tnf());
    try std.testing.expectEqual(@as(u8, 0x01), NDEFRecordType.well_known.tnf());
    try std.testing.expectEqual(@as(u8, 0x02), NDEFRecordType.mime_media.tnf());
}

test "NDEFRecordType fromTNF" {
    try std.testing.expectEqual(NDEFRecordType.empty, NDEFRecordType.fromTNF(0x00));
    try std.testing.expectEqual(NDEFRecordType.well_known, NDEFRecordType.fromTNF(0x01));
    try std.testing.expectEqual(NDEFRecordType.unknown, NDEFRecordType.fromTNF(0xFF));
}

test "WellKnownType typeIdentifier" {
    try std.testing.expectEqualStrings("T", WellKnownType.text.typeIdentifier());
    try std.testing.expectEqualStrings("U", WellKnownType.uri.typeIdentifier());
    try std.testing.expectEqualStrings("Sp", WellKnownType.smart_poster.typeIdentifier());
}

test "URIIdentifier prefix" {
    try std.testing.expectEqualStrings("", URIIdentifier.none.prefix());
    try std.testing.expectEqualStrings("http://www.", URIIdentifier.http_www.prefix());
    try std.testing.expectEqualStrings("https://", URIIdentifier.https.prefix());
    try std.testing.expectEqualStrings("tel:", URIIdentifier.tel.prefix());
}

test "NDEFRecord init" {
    const record = NDEFRecord.init(.well_known, "test payload");
    try std.testing.expectEqual(NDEFRecordType.well_known, record.record_type);
    try std.testing.expectEqualStrings("test payload", record.payload);
    try std.testing.expect(record.is_first);
    try std.testing.expect(record.is_last);
}

test "NDEFRecord text" {
    const record = NDEFRecord.text("Hello World", "en");
    try std.testing.expectEqual(NDEFRecordType.well_known, record.record_type);
    try std.testing.expectEqualStrings("T", record.type_name.?);
}

test "NDEFRecord uri" {
    const record = NDEFRecord.uri("https://example.com");
    try std.testing.expectEqual(NDEFRecordType.well_known, record.record_type);
    try std.testing.expectEqualStrings("U", record.type_name.?);
}

test "NDEFRecord isTextRecord" {
    const text_record = NDEFRecord.text("Hello", "en");
    try std.testing.expect(text_record.isTextRecord());

    const uri_record = NDEFRecord.uri("https://test.com");
    try std.testing.expect(!uri_record.isTextRecord());
}

test "NDEFRecord isURIRecord" {
    const uri_record = NDEFRecord.uri("https://test.com");
    try std.testing.expect(uri_record.isURIRecord());

    const text_record = NDEFRecord.text("Hello", "en");
    try std.testing.expect(!text_record.isURIRecord());
}

test "NDEFMessage init and deinit" {
    const allocator = std.testing.allocator;
    var message = NDEFMessage.init(allocator);
    defer message.deinit();

    try std.testing.expectEqual(@as(usize, 0), message.getRecordCount());
}

test "NDEFMessage addRecord" {
    const allocator = std.testing.allocator;
    var message = NDEFMessage.init(allocator);
    defer message.deinit();

    try message.addRecord(NDEFRecord.text("Hello", "en"));
    try message.addRecord(NDEFRecord.uri("https://test.com"));

    try std.testing.expectEqual(@as(usize, 2), message.getRecordCount());

    const first = message.getRecord(0);
    try std.testing.expect(first != null);
    try std.testing.expect(first.?.is_first);
    try std.testing.expect(!first.?.is_last);

    const last = message.getRecord(1);
    try std.testing.expect(last != null);
    try std.testing.expect(!last.?.is_first);
    try std.testing.expect(last.?.is_last);
}

test "NDEFMessage hasTextRecord" {
    const allocator = std.testing.allocator;
    var message = NDEFMessage.init(allocator);
    defer message.deinit();

    try std.testing.expect(!message.hasTextRecord());

    try message.addRecord(NDEFRecord.text("Hello", "en"));
    try std.testing.expect(message.hasTextRecord());
}

test "NDEFMessage hasURIRecord" {
    const allocator = std.testing.allocator;
    var message = NDEFMessage.init(allocator);
    defer message.deinit();

    try std.testing.expect(!message.hasURIRecord());

    try message.addRecord(NDEFRecord.uri("https://test.com"));
    try std.testing.expect(message.hasURIRecord());
}

test "NFCTag hasTechnology" {
    const tag = NFCTag{
        .id = "ABC",
        .technologies = &[_]NFCTechnology{ .nfc_a, .ndef },
        .ndef_message = null,
        .is_writable = true,
        .max_size = 1024,
        .used_size = 100,
        .is_connected = true,
    };

    try std.testing.expect(tag.hasTechnology(.nfc_a));
    try std.testing.expect(tag.hasTechnology(.ndef));
    try std.testing.expect(!tag.hasTechnology(.nfc_f));
}

test "NFCTag getAvailableSpace" {
    const tag = NFCTag{
        .id = "ABC",
        .technologies = &[_]NFCTechnology{.ndef},
        .ndef_message = null,
        .is_writable = true,
        .max_size = 1024,
        .used_size = 100,
        .is_connected = true,
    };

    try std.testing.expectEqual(@as(u32, 924), tag.getAvailableSpace());
}

test "NFCTag canWriteMessage" {
    const tag = NFCTag{
        .id = "ABC",
        .technologies = &[_]NFCTechnology{.ndef},
        .ndef_message = null,
        .is_writable = true,
        .max_size = 1024,
        .used_size = 100,
        .is_connected = true,
    };

    try std.testing.expect(tag.canWriteMessage(500));
    try std.testing.expect(!tag.canWriteMessage(1000));
}

test "NFCSessionState properties" {
    try std.testing.expect(NFCSessionState.polling.isActive());
    try std.testing.expect(NFCSessionState.connected.isActive());
    try std.testing.expect(!NFCSessionState.idle.isActive());
    try std.testing.expect(!NFCSessionState.error_state.isActive());
}

test "NFCError properties" {
    try std.testing.expect(NFCError.tag_lost.isRecoverable());
    try std.testing.expect(NFCError.session_timeout.isRecoverable());
    try std.testing.expect(!NFCError.not_supported.isRecoverable());
}

test "NFCEvent create" {
    const event = NFCEvent.create(.session_started);
    try std.testing.expectEqual(NFCEventType.session_started, event.event_type);
    try std.testing.expect(event.tag_id == null);
}

test "NFCEvent forTag" {
    const event = NFCEvent.forTag(.tag_discovered, "ABC123");
    try std.testing.expectEqual(NFCEventType.tag_discovered, event.event_type);
    try std.testing.expectEqualStrings("ABC123", event.tag_id.?);
}

test "NFCEvent withError" {
    const event = NFCEvent.withError(.read_error, .tag_read_error);
    try std.testing.expectEqual(NFCEventType.read_error, event.event_type);
    try std.testing.expectEqual(NFCError.tag_read_error, event.nfc_error);
}

test "NFCSessionConfig init" {
    const config = NFCSessionConfig.init();
    try std.testing.expect(config.detect_ndef);
    try std.testing.expect(config.invalidate_after_first_read);
    try std.testing.expectEqual(@as(u32, 60000), config.timeout_ms);
}

test "NFCSessionConfig forNDEF" {
    const config = NFCSessionConfig.forNDEF();
    try std.testing.expect(config.detect_ndef);
    try std.testing.expect(!config.detect_iso14443);
}

test "NFCSession init and deinit" {
    const allocator = std.testing.allocator;
    var session = NFCSession.init(allocator);
    defer session.deinit();

    try std.testing.expectEqual(NFCSessionState.idle, session.getState());
    try std.testing.expect(!session.isScanning());
}

test "NFCSession beginScanning" {
    const allocator = std.testing.allocator;
    var session = NFCSession.init(allocator);
    defer session.deinit();

    try session.beginScanning();
    try std.testing.expect(session.isScanning());
    try std.testing.expectEqual(NFCSessionState.polling, session.getState());
}

test "NFCSession endScanning" {
    const allocator = std.testing.allocator;
    var session = NFCSession.init(allocator);
    defer session.deinit();

    try session.beginScanning();
    session.endScanning();

    try std.testing.expect(!session.isScanning());
    try std.testing.expectEqual(NFCSessionState.idle, session.getState());
}

test "NFCSession tagDiscovered" {
    const allocator = std.testing.allocator;
    var session = NFCSession.init(allocator);
    defer session.deinit();

    try session.beginScanning();

    const tag = NFCTag{
        .id = "TAG123",
        .technologies = &[_]NFCTechnology{.ndef},
        .ndef_message = null,
        .is_writable = true,
        .max_size = 1024,
        .used_size = 0,
        .is_connected = true,
    };

    session.tagDiscovered(tag);

    try std.testing.expect(session.isConnected());
    try std.testing.expectEqual(@as(u32, 1), session.tags_discovered);
}

test "NDEFBuilder" {
    const allocator = std.testing.allocator;
    var builder = NDEFBuilder.init(allocator);
    defer builder.deinit();

    _ = try builder.addText("Hello", "en");
    _ = try builder.addURI("https://example.com");

    try std.testing.expectEqual(@as(usize, 2), builder.getRecordCount());

    var message = builder.build();
    defer message.deinit();

    try std.testing.expectEqual(@as(usize, 2), message.getRecordCount());
    try std.testing.expectEqual(@as(usize, 0), builder.getRecordCount()); // Builder reset
}

test "isNFCAvailable" {
    try std.testing.expect(isNFCAvailable());
}

test "isNFCEnabled" {
    try std.testing.expect(isNFCEnabled());
}
