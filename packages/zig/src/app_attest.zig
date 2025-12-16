const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

/// Cross-platform device attestation module for app security and integrity verification.
/// Provides unified API for iOS App Attest, Android SafetyNet/Play Integrity, and platform-specific attestation.

// ============================================================================
// Platform Detection
// ============================================================================

pub const Platform = enum {
    ios,
    macos,
    android,
    linux,
    windows,
    unsupported,

    pub fn current() Platform {
        return switch (builtin.os.tag) {
            .ios => .ios,
            .macos => .macos,
            .linux => if (builtin.abi == .android) .android else .linux,
            .windows => .windows,
            else => .unsupported,
        };
    }

    pub fn supportsDeviceAttestation(self: Platform) bool {
        return switch (self) {
            .ios, .macos, .android => true,
            .linux, .windows, .unsupported => false,
        };
    }

    pub fn supportsAppIntegrity(self: Platform) bool {
        return switch (self) {
            .ios, .android => true,
            .macos, .linux, .windows, .unsupported => false,
        };
    }
};

// ============================================================================
// Helper Functions
// ============================================================================

fn getCurrentTimestamp() i64 {
    if (builtin.os.tag == .macos or builtin.os.tag == .ios or
        builtin.os.tag == .linux or builtin.os.tag == .windows)
    {
        const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
        return ts.sec;
    }
    return 0;
}

// ============================================================================
// Attestation Types
// ============================================================================

/// Attestation service type
pub const AttestationType = enum {
    app_attest, // iOS App Attest
    device_check, // iOS DeviceCheck
    safety_net, // Android SafetyNet (deprecated)
    play_integrity, // Android Play Integrity
    key_attestation, // Android Key Attestation
    tpm, // Windows TPM attestation
    custom, // Custom attestation implementation

    pub fn isAvailable(self: AttestationType) bool {
        const platform = Platform.current();
        return switch (self) {
            .app_attest, .device_check => platform == .ios or platform == .macos,
            .safety_net, .play_integrity, .key_attestation => platform == .android,
            .tpm => platform == .windows,
            .custom => true,
        };
    }

    pub fn getDisplayName(self: AttestationType) []const u8 {
        return switch (self) {
            .app_attest => "App Attest",
            .device_check => "Device Check",
            .safety_net => "SafetyNet",
            .play_integrity => "Play Integrity",
            .key_attestation => "Key Attestation",
            .tpm => "TPM Attestation",
            .custom => "Custom",
        };
    }
};

/// Attestation result status
pub const AttestationStatus = enum {
    success,
    device_not_supported,
    key_generation_failed,
    attestation_failed,
    verification_failed,
    server_error,
    network_error,
    invalid_challenge,
    expired,
    revoked,
    unknown_error,

    pub fn isSuccess(self: AttestationStatus) bool {
        return self == .success;
    }

    pub fn isRetryable(self: AttestationStatus) bool {
        return switch (self) {
            .network_error, .server_error => true,
            else => false,
        };
    }

    pub fn getDescription(self: AttestationStatus) []const u8 {
        return switch (self) {
            .success => "Attestation successful",
            .device_not_supported => "Device does not support attestation",
            .key_generation_failed => "Failed to generate attestation key",
            .attestation_failed => "Attestation process failed",
            .verification_failed => "Server verification failed",
            .server_error => "Server returned an error",
            .network_error => "Network connection error",
            .invalid_challenge => "Challenge data is invalid",
            .expired => "Attestation has expired",
            .revoked => "Attestation key has been revoked",
            .unknown_error => "An unknown error occurred",
        };
    }
};

/// Risk level from integrity check
pub const RiskLevel = enum {
    low,
    medium,
    high,
    critical,
    unknown,

    pub fn fromScore(score: u8) RiskLevel {
        if (score >= 90) return .low;
        if (score >= 70) return .medium;
        if (score >= 40) return .high;
        if (score > 0) return .critical;
        return .unknown;
    }

    pub fn toScore(self: RiskLevel) u8 {
        return switch (self) {
            .low => 95,
            .medium => 75,
            .high => 50,
            .critical => 20,
            .unknown => 0,
        };
    }
};

// ============================================================================
// Attestation Key
// ============================================================================

/// Attestation key identifier
pub const AttestationKey = struct {
    key_id: [64]u8,
    key_id_len: usize,
    attestation_type: AttestationType,
    created_at: i64,
    expires_at: i64,
    is_valid: bool,

    pub fn init(attestation_type: AttestationType) AttestationKey {
        const now = getCurrentTimestamp();
        return .{
            .key_id = [_]u8{0} ** 64,
            .key_id_len = 0,
            .attestation_type = attestation_type,
            .created_at = now,
            .expires_at = now + 86400 * 30, // 30 days default
            .is_valid = false,
        };
    }

    pub fn withKeyId(self: AttestationKey, key_id: []const u8) AttestationKey {
        var result = self;
        const copy_len = @min(key_id.len, 64);
        @memcpy(result.key_id[0..copy_len], key_id[0..copy_len]);
        result.key_id_len = copy_len;
        result.is_valid = copy_len > 0;
        return result;
    }

    pub fn withExpiration(self: AttestationKey, expires_at: i64) AttestationKey {
        var result = self;
        result.expires_at = expires_at;
        return result;
    }

    pub fn getKeyIdSlice(self: *const AttestationKey) []const u8 {
        return self.key_id[0..self.key_id_len];
    }

    pub fn isExpired(self: *const AttestationKey) bool {
        return getCurrentTimestamp() > self.expires_at;
    }

    pub fn getRemainingValidity(self: *const AttestationKey) i64 {
        const remaining = self.expires_at - getCurrentTimestamp();
        return if (remaining > 0) remaining else 0;
    }
};

// ============================================================================
// Challenge
// ============================================================================

/// Server challenge for attestation
pub const Challenge = struct {
    data: [256]u8,
    data_len: usize,
    created_at: i64,
    expires_at: i64,
    nonce: [32]u8,

    pub fn init() Challenge {
        const now = getCurrentTimestamp();
        return .{
            .data = [_]u8{0} ** 256,
            .data_len = 0,
            .created_at = now,
            .expires_at = now + 300, // 5 minutes default
            .nonce = [_]u8{0} ** 32,
        };
    }

    pub fn withData(self: Challenge, data: []const u8) Challenge {
        var result = self;
        const copy_len = @min(data.len, 256);
        @memcpy(result.data[0..copy_len], data[0..copy_len]);
        result.data_len = copy_len;
        return result;
    }

    pub fn withNonce(self: Challenge, nonce: []const u8) Challenge {
        var result = self;
        const copy_len = @min(nonce.len, 32);
        @memcpy(result.nonce[0..copy_len], nonce[0..copy_len]);
        return result;
    }

    pub fn withExpiration(self: Challenge, expires_at: i64) Challenge {
        var result = self;
        result.expires_at = expires_at;
        return result;
    }

    pub fn getDataSlice(self: *const Challenge) []const u8 {
        return self.data[0..self.data_len];
    }

    pub fn isExpired(self: *const Challenge) bool {
        return getCurrentTimestamp() > self.expires_at;
    }

    pub fn isValid(self: *const Challenge) bool {
        return self.data_len > 0 and !self.isExpired();
    }
};

// ============================================================================
// Attestation Object
// ============================================================================

/// Attestation object containing proof
pub const AttestationObject = struct {
    data: [4096]u8,
    data_len: usize,
    format: AttestationFormat,
    created_at: i64,

    pub const AttestationFormat = enum {
        cbor,
        json,
        binary,
        jwt,
    };

    pub fn init(format: AttestationFormat) AttestationObject {
        return .{
            .data = [_]u8{0} ** 4096,
            .data_len = 0,
            .format = format,
            .created_at = getCurrentTimestamp(),
        };
    }

    pub fn withData(self: AttestationObject, data: []const u8) AttestationObject {
        var result = self;
        const copy_len = @min(data.len, 4096);
        @memcpy(result.data[0..copy_len], data[0..copy_len]);
        result.data_len = copy_len;
        return result;
    }

    pub fn getDataSlice(self: *const AttestationObject) []const u8 {
        return self.data[0..self.data_len];
    }

    pub fn isEmpty(self: *const AttestationObject) bool {
        return self.data_len == 0;
    }
};

// ============================================================================
// Assertion
// ============================================================================

/// Cryptographic assertion for server validation
pub const Assertion = struct {
    signature: [512]u8,
    signature_len: usize,
    authenticator_data: [256]u8,
    authenticator_data_len: usize,
    client_data_hash: [32]u8,
    counter: u64,
    created_at: i64,

    pub fn init() Assertion {
        return .{
            .signature = [_]u8{0} ** 512,
            .signature_len = 0,
            .authenticator_data = [_]u8{0} ** 256,
            .authenticator_data_len = 0,
            .client_data_hash = [_]u8{0} ** 32,
            .counter = 0,
            .created_at = getCurrentTimestamp(),
        };
    }

    pub fn withSignature(self: Assertion, signature: []const u8) Assertion {
        var result = self;
        const copy_len = @min(signature.len, 512);
        @memcpy(result.signature[0..copy_len], signature[0..copy_len]);
        result.signature_len = copy_len;
        return result;
    }

    pub fn withAuthenticatorData(self: Assertion, data: []const u8) Assertion {
        var result = self;
        const copy_len = @min(data.len, 256);
        @memcpy(result.authenticator_data[0..copy_len], data[0..copy_len]);
        result.authenticator_data_len = copy_len;
        return result;
    }

    pub fn withClientDataHash(self: Assertion, hash: []const u8) Assertion {
        var result = self;
        const copy_len = @min(hash.len, 32);
        @memcpy(result.client_data_hash[0..copy_len], hash[0..copy_len]);
        return result;
    }

    pub fn withCounter(self: Assertion, counter: u64) Assertion {
        var result = self;
        result.counter = counter;
        return result;
    }

    pub fn getSignatureSlice(self: *const Assertion) []const u8 {
        return self.signature[0..self.signature_len];
    }

    pub fn getAuthenticatorDataSlice(self: *const Assertion) []const u8 {
        return self.authenticator_data[0..self.authenticator_data_len];
    }
};

// ============================================================================
// Integrity Verdict
// ============================================================================

/// Device and app integrity verdict
pub const IntegrityVerdict = struct {
    device_integrity: DeviceIntegrity,
    app_integrity: AppIntegrity,
    account_integrity: AccountIntegrity,
    risk_level: RiskLevel,
    timestamp: i64,
    details: [512]u8,
    details_len: usize,

    pub const DeviceIntegrity = struct {
        meets_device_integrity: bool,
        meets_basic_integrity: bool,
        meets_strong_integrity: bool,
        is_emulator: bool,
        is_rooted: bool,
    };

    pub const AppIntegrity = struct {
        is_recognized: bool,
        is_licensed: bool,
        package_name_matches: bool,
        certificate_matches: bool,
        version_code: u32,
    };

    pub const AccountIntegrity = struct {
        is_licensed: bool,
        has_play_store: bool,
    };

    pub fn init() IntegrityVerdict {
        return .{
            .device_integrity = .{
                .meets_device_integrity = false,
                .meets_basic_integrity = false,
                .meets_strong_integrity = false,
                .is_emulator = false,
                .is_rooted = false,
            },
            .app_integrity = .{
                .is_recognized = false,
                .is_licensed = false,
                .package_name_matches = false,
                .certificate_matches = false,
                .version_code = 0,
            },
            .account_integrity = .{
                .is_licensed = false,
                .has_play_store = false,
            },
            .risk_level = .unknown,
            .timestamp = getCurrentTimestamp(),
            .details = [_]u8{0} ** 512,
            .details_len = 0,
        };
    }

    pub fn withDeviceIntegrity(self: IntegrityVerdict, integrity: DeviceIntegrity) IntegrityVerdict {
        var result = self;
        result.device_integrity = integrity;
        return result;
    }

    pub fn withAppIntegrity(self: IntegrityVerdict, integrity: AppIntegrity) IntegrityVerdict {
        var result = self;
        result.app_integrity = integrity;
        return result;
    }

    pub fn withRiskLevel(self: IntegrityVerdict, level: RiskLevel) IntegrityVerdict {
        var result = self;
        result.risk_level = level;
        return result;
    }

    pub fn withDetails(self: IntegrityVerdict, details: []const u8) IntegrityVerdict {
        var result = self;
        const copy_len = @min(details.len, 512);
        @memcpy(result.details[0..copy_len], details[0..copy_len]);
        result.details_len = copy_len;
        return result;
    }

    pub fn getDetailsSlice(self: *const IntegrityVerdict) []const u8 {
        return self.details[0..self.details_len];
    }

    pub fn isPassing(self: *const IntegrityVerdict) bool {
        return self.device_integrity.meets_basic_integrity and
            self.app_integrity.is_recognized;
    }

    pub fn isHighTrust(self: *const IntegrityVerdict) bool {
        return self.device_integrity.meets_strong_integrity and
            self.app_integrity.is_licensed and
            !self.device_integrity.is_emulator and
            !self.device_integrity.is_rooted;
    }
};

// ============================================================================
// Attestation Result
// ============================================================================

/// Complete attestation result
pub const AttestationResult = struct {
    status: AttestationStatus,
    attestation_type: AttestationType,
    key: AttestationKey,
    attestation_object: ?AttestationObject,
    assertion: ?Assertion,
    verdict: ?IntegrityVerdict,
    timestamp: i64,
    request_id: [64]u8,
    request_id_len: usize,

    pub fn init(attestation_type: AttestationType, status: AttestationStatus) AttestationResult {
        return .{
            .status = status,
            .attestation_type = attestation_type,
            .key = AttestationKey.init(attestation_type),
            .attestation_object = null,
            .assertion = null,
            .verdict = null,
            .timestamp = getCurrentTimestamp(),
            .request_id = [_]u8{0} ** 64,
            .request_id_len = 0,
        };
    }

    pub fn withKey(self: AttestationResult, key: AttestationKey) AttestationResult {
        var result = self;
        result.key = key;
        return result;
    }

    pub fn withAttestationObject(self: AttestationResult, obj: AttestationObject) AttestationResult {
        var result = self;
        result.attestation_object = obj;
        return result;
    }

    pub fn withAssertion(self: AttestationResult, assertion: Assertion) AttestationResult {
        var result = self;
        result.assertion = assertion;
        return result;
    }

    pub fn withVerdict(self: AttestationResult, verdict: IntegrityVerdict) AttestationResult {
        var result = self;
        result.verdict = verdict;
        return result;
    }

    pub fn withRequestId(self: AttestationResult, request_id: []const u8) AttestationResult {
        var result = self;
        const copy_len = @min(request_id.len, 64);
        @memcpy(result.request_id[0..copy_len], request_id[0..copy_len]);
        result.request_id_len = copy_len;
        return result;
    }

    pub fn isSuccess(self: *const AttestationResult) bool {
        return self.status.isSuccess();
    }

    pub fn getRequestIdSlice(self: *const AttestationResult) []const u8 {
        return self.request_id[0..self.request_id_len];
    }
};

// ============================================================================
// Attestation Configuration
// ============================================================================

/// Configuration for attestation service
pub const AttestationConfig = struct {
    attestation_type: AttestationType,
    challenge_timeout_seconds: u32,
    key_validity_days: u32,
    require_strong_integrity: bool,
    allow_emulators: bool,
    server_url: [256]u8,
    server_url_len: usize,
    app_id: [128]u8,
    app_id_len: usize,

    pub fn init(attestation_type: AttestationType) AttestationConfig {
        return .{
            .attestation_type = attestation_type,
            .challenge_timeout_seconds = 300,
            .key_validity_days = 30,
            .require_strong_integrity = false,
            .allow_emulators = false,
            .server_url = [_]u8{0} ** 256,
            .server_url_len = 0,
            .app_id = [_]u8{0} ** 128,
            .app_id_len = 0,
        };
    }

    pub fn withChallengeTimeout(self: AttestationConfig, timeout: u32) AttestationConfig {
        var result = self;
        result.challenge_timeout_seconds = timeout;
        return result;
    }

    pub fn withKeyValidity(self: AttestationConfig, days: u32) AttestationConfig {
        var result = self;
        result.key_validity_days = days;
        return result;
    }

    pub fn withStrongIntegrity(self: AttestationConfig, require: bool) AttestationConfig {
        var result = self;
        result.require_strong_integrity = require;
        return result;
    }

    pub fn withEmulatorSupport(self: AttestationConfig, allow: bool) AttestationConfig {
        var result = self;
        result.allow_emulators = allow;
        return result;
    }

    pub fn withServerUrl(self: AttestationConfig, url: []const u8) AttestationConfig {
        var result = self;
        const copy_len = @min(url.len, 256);
        @memcpy(result.server_url[0..copy_len], url[0..copy_len]);
        result.server_url_len = copy_len;
        return result;
    }

    pub fn withAppId(self: AttestationConfig, app_id: []const u8) AttestationConfig {
        var result = self;
        const copy_len = @min(app_id.len, 128);
        @memcpy(result.app_id[0..copy_len], app_id[0..copy_len]);
        result.app_id_len = copy_len;
        return result;
    }

    pub fn getServerUrlSlice(self: *const AttestationConfig) []const u8 {
        return self.server_url[0..self.server_url_len];
    }

    pub fn getAppIdSlice(self: *const AttestationConfig) []const u8 {
        return self.app_id[0..self.app_id_len];
    }
};

// ============================================================================
// Attestation Event
// ============================================================================

/// Events from attestation operations
pub const AttestationEvent = struct {
    event_type: EventType,
    attestation_type: AttestationType,
    status: AttestationStatus,
    timestamp: i64,
    message: [256]u8,
    message_len: usize,

    pub const EventType = enum {
        key_generated,
        key_expired,
        key_revoked,
        attestation_started,
        attestation_completed,
        attestation_failed,
        assertion_generated,
        assertion_verified,
        challenge_received,
        challenge_expired,
        integrity_check_passed,
        integrity_check_failed,
    };

    pub fn init(event_type: EventType, attestation_type: AttestationType) AttestationEvent {
        return .{
            .event_type = event_type,
            .attestation_type = attestation_type,
            .status = .success,
            .timestamp = getCurrentTimestamp(),
            .message = [_]u8{0} ** 256,
            .message_len = 0,
        };
    }

    pub fn withStatus(self: AttestationEvent, status: AttestationStatus) AttestationEvent {
        var result = self;
        result.status = status;
        return result;
    }

    pub fn withMessage(self: AttestationEvent, message: []const u8) AttestationEvent {
        var result = self;
        const copy_len = @min(message.len, 256);
        @memcpy(result.message[0..copy_len], message[0..copy_len]);
        result.message_len = copy_len;
        return result;
    }

    pub fn getMessageSlice(self: *const AttestationEvent) []const u8 {
        return self.message[0..self.message_len];
    }
};

// ============================================================================
// App Attest Service (iOS)
// ============================================================================

/// iOS App Attest service wrapper
pub const AppAttestService = struct {
    config: AttestationConfig,
    current_key: ?AttestationKey,
    assertion_counter: u64,
    is_supported: bool,

    pub fn init(config: AttestationConfig) AppAttestService {
        return .{
            .config = config,
            .current_key = null,
            .assertion_counter = 0,
            .is_supported = Platform.current() == .ios or Platform.current() == .macos,
        };
    }

    pub fn isSupported(self: *const AppAttestService) bool {
        return self.is_supported;
    }

    pub fn generateKey(self: *AppAttestService) AttestationResult {
        if (!self.is_supported) {
            return AttestationResult.init(.app_attest, .device_not_supported);
        }

        // Simulate key generation
        const key = AttestationKey.init(.app_attest)
            .withKeyId("simulated-app-attest-key-id");

        self.current_key = key;
        self.assertion_counter = 0;

        return AttestationResult.init(.app_attest, .success)
            .withKey(key);
    }

    pub fn attestKey(self: *AppAttestService, challenge: Challenge) AttestationResult {
        if (!self.is_supported) {
            return AttestationResult.init(.app_attest, .device_not_supported);
        }

        if (!challenge.isValid()) {
            return AttestationResult.init(.app_attest, .invalid_challenge);
        }

        const key = self.current_key orelse {
            return AttestationResult.init(.app_attest, .key_generation_failed);
        };

        // Simulate attestation object creation
        const attestation_obj = AttestationObject.init(.cbor)
            .withData("simulated-attestation-object-data");

        return AttestationResult.init(.app_attest, .success)
            .withKey(key)
            .withAttestationObject(attestation_obj);
    }

    pub fn generateAssertion(self: *AppAttestService, client_data: []const u8) AttestationResult {
        if (!self.is_supported) {
            return AttestationResult.init(.app_attest, .device_not_supported);
        }

        const key = self.current_key orelse {
            return AttestationResult.init(.app_attest, .key_generation_failed);
        };

        if (key.isExpired()) {
            return AttestationResult.init(.app_attest, .expired);
        }

        self.assertion_counter += 1;

        // Compute client data hash (simulated)
        var hash: [32]u8 = [_]u8{0} ** 32;
        if (client_data.len > 0) {
            const copy_len = @min(client_data.len, 32);
            @memcpy(hash[0..copy_len], client_data[0..copy_len]);
        }

        const assertion = Assertion.init()
            .withSignature("simulated-assertion-signature")
            .withAuthenticatorData("simulated-authenticator-data")
            .withClientDataHash(&hash)
            .withCounter(self.assertion_counter);

        return AttestationResult.init(.app_attest, .success)
            .withKey(key)
            .withAssertion(assertion);
    }

    pub fn hasValidKey(self: *const AppAttestService) bool {
        if (self.current_key) |key| {
            return key.is_valid and !key.isExpired();
        }
        return false;
    }

    pub fn getAssertionCount(self: *const AppAttestService) u64 {
        return self.assertion_counter;
    }
};

// ============================================================================
// Play Integrity Service (Android)
// ============================================================================

/// Android Play Integrity service wrapper
pub const PlayIntegrityService = struct {
    config: AttestationConfig,
    last_verdict: ?IntegrityVerdict,
    request_count: u64,
    is_supported: bool,

    pub fn init(config: AttestationConfig) PlayIntegrityService {
        return .{
            .config = config,
            .last_verdict = null,
            .request_count = 0,
            .is_supported = Platform.current() == .android,
        };
    }

    pub fn isSupported(self: *const PlayIntegrityService) bool {
        return self.is_supported;
    }

    pub fn requestIntegrityToken(self: *PlayIntegrityService, nonce: []const u8) AttestationResult {
        if (!self.is_supported) {
            return AttestationResult.init(.play_integrity, .device_not_supported);
        }

        if (nonce.len == 0) {
            return AttestationResult.init(.play_integrity, .invalid_challenge);
        }

        self.request_count += 1;

        // Simulate integrity token
        const attestation_obj = AttestationObject.init(.jwt)
            .withData("simulated-integrity-token");

        // Simulate verdict
        const verdict = IntegrityVerdict.init()
            .withDeviceIntegrity(.{
                .meets_device_integrity = true,
                .meets_basic_integrity = true,
                .meets_strong_integrity = false,
                .is_emulator = false,
                .is_rooted = false,
            })
            .withAppIntegrity(.{
                .is_recognized = true,
                .is_licensed = true,
                .package_name_matches = true,
                .certificate_matches = true,
                .version_code = 1,
            })
            .withRiskLevel(.low);

        self.last_verdict = verdict;

        return AttestationResult.init(.play_integrity, .success)
            .withAttestationObject(attestation_obj)
            .withVerdict(verdict);
    }

    pub fn getLastVerdict(self: *const PlayIntegrityService) ?IntegrityVerdict {
        return self.last_verdict;
    }

    pub fn getRequestCount(self: *const PlayIntegrityService) u64 {
        return self.request_count;
    }

    pub fn meetsRequirements(self: *const PlayIntegrityService) bool {
        if (self.last_verdict) |verdict| {
            if (self.config.require_strong_integrity) {
                return verdict.isHighTrust();
            }
            return verdict.isPassing();
        }
        return false;
    }
};

// ============================================================================
// App Attest Controller
// ============================================================================

/// Main controller for cross-platform attestation
pub const AppAttestController = struct {
    config: AttestationConfig,
    app_attest_service: AppAttestService,
    play_integrity_service: PlayIntegrityService,
    event_history: std.ArrayListUnmanaged(AttestationEvent),
    result_history: std.ArrayListUnmanaged(AttestationResult),
    event_callback: ?*const fn (AttestationEvent) void,
    is_initialized: bool,

    pub fn init(config: AttestationConfig) AppAttestController {
        return .{
            .config = config,
            .app_attest_service = AppAttestService.init(config),
            .play_integrity_service = PlayIntegrityService.init(config),
            .event_history = .empty,
            .result_history = .empty,
            .event_callback = null,
            .is_initialized = true,
        };
    }

    pub fn deinit(self: *AppAttestController, allocator: Allocator) void {
        self.event_history.deinit(allocator);
        self.result_history.deinit(allocator);
        self.is_initialized = false;
    }

    pub fn setEventCallback(self: *AppAttestController, callback: *const fn (AttestationEvent) void) void {
        self.event_callback = callback;
    }

    fn emitEvent(self: *AppAttestController, event: AttestationEvent, allocator: Allocator) void {
        self.event_history.append(allocator, event) catch {};
        if (self.event_callback) |callback| {
            callback(event);
        }
    }

    fn recordResult(self: *AppAttestController, result: AttestationResult, allocator: Allocator) void {
        self.result_history.append(allocator, result) catch {};
    }

    pub fn isSupported(self: *const AppAttestController) bool {
        return self.app_attest_service.isSupported() or self.play_integrity_service.isSupported();
    }

    pub fn generateKey(self: *AppAttestController, allocator: Allocator) AttestationResult {
        const platform = Platform.current();

        const result = switch (platform) {
            .ios, .macos => blk: {
                self.emitEvent(
                    AttestationEvent.init(.key_generated, .app_attest)
                        .withMessage("Generating App Attest key"),
                    allocator,
                );
                break :blk self.app_attest_service.generateKey();
            },
            else => AttestationResult.init(self.config.attestation_type, .device_not_supported),
        };

        self.recordResult(result, allocator);
        return result;
    }

    pub fn performAttestation(self: *AppAttestController, challenge: Challenge, allocator: Allocator) AttestationResult {
        const platform = Platform.current();

        self.emitEvent(
            AttestationEvent.init(.attestation_started, self.config.attestation_type)
                .withMessage("Starting attestation"),
            allocator,
        );

        const result = switch (platform) {
            .ios, .macos => self.app_attest_service.attestKey(challenge),
            .android => self.play_integrity_service.requestIntegrityToken(challenge.getDataSlice()),
            else => AttestationResult.init(self.config.attestation_type, .device_not_supported),
        };

        const event_type: AttestationEvent.EventType = if (result.status.isSuccess())
            .attestation_completed
        else
            .attestation_failed;

        self.emitEvent(
            AttestationEvent.init(event_type, self.config.attestation_type)
                .withStatus(result.status)
                .withMessage(result.status.getDescription()),
            allocator,
        );

        self.recordResult(result, allocator);
        return result;
    }

    pub fn generateAssertion(self: *AppAttestController, client_data: []const u8, allocator: Allocator) AttestationResult {
        const platform = Platform.current();

        const result = switch (platform) {
            .ios, .macos => self.app_attest_service.generateAssertion(client_data),
            else => AttestationResult.init(self.config.attestation_type, .device_not_supported),
        };

        if (result.status.isSuccess()) {
            self.emitEvent(
                AttestationEvent.init(.assertion_generated, .app_attest)
                    .withMessage("Assertion generated"),
                allocator,
            );
        }

        self.recordResult(result, allocator);
        return result;
    }

    pub fn checkIntegrity(self: *AppAttestController, nonce: []const u8, allocator: Allocator) AttestationResult {
        const platform = Platform.current();

        const result = switch (platform) {
            .android => self.play_integrity_service.requestIntegrityToken(nonce),
            else => AttestationResult.init(.play_integrity, .device_not_supported),
        };

        if (result.verdict) |verdict| {
            const event_type: AttestationEvent.EventType = if (verdict.isPassing())
                .integrity_check_passed
            else
                .integrity_check_failed;

            self.emitEvent(
                AttestationEvent.init(event_type, .play_integrity),
                allocator,
            );
        }

        self.recordResult(result, allocator);
        return result;
    }

    pub fn hasValidKey(self: *const AppAttestController) bool {
        return self.app_attest_service.hasValidKey();
    }

    pub fn meetsIntegrityRequirements(self: *const AppAttestController) bool {
        return self.play_integrity_service.meetsRequirements();
    }

    pub fn getEventHistory(self: *const AppAttestController) []const AttestationEvent {
        return self.event_history.items;
    }

    pub fn getResultHistory(self: *const AppAttestController) []const AttestationResult {
        return self.result_history.items;
    }

    pub fn clearHistory(self: *AppAttestController, allocator: Allocator) void {
        self.event_history.clearAndFree(allocator);
        self.result_history.clearAndFree(allocator);
    }

    pub fn getStatistics(self: *const AppAttestController) Statistics {
        var stats = Statistics{
            .total_attestations = 0,
            .successful_attestations = 0,
            .failed_attestations = 0,
            .total_assertions = self.app_attest_service.getAssertionCount(),
            .integrity_checks = self.play_integrity_service.getRequestCount(),
        };

        for (self.result_history.items) |result| {
            stats.total_attestations += 1;
            if (result.status.isSuccess()) {
                stats.successful_attestations += 1;
            } else {
                stats.failed_attestations += 1;
            }
        }

        return stats;
    }

    pub const Statistics = struct {
        total_attestations: u64,
        successful_attestations: u64,
        failed_attestations: u64,
        total_assertions: u64,
        integrity_checks: u64,

        pub fn getSuccessRate(self: Statistics) f32 {
            if (self.total_attestations == 0) return 0.0;
            return @as(f32, @floatFromInt(self.successful_attestations)) /
                @as(f32, @floatFromInt(self.total_attestations));
        }
    };
};

// ============================================================================
// Tests
// ============================================================================

test "Platform detection" {
    const platform = Platform.current();
    try std.testing.expect(platform != .unsupported or builtin.os.tag == .freestanding);
}

test "Platform attestation support" {
    try std.testing.expect(Platform.ios.supportsDeviceAttestation());
    try std.testing.expect(Platform.android.supportsDeviceAttestation());
    try std.testing.expect(!Platform.linux.supportsDeviceAttestation());
}

test "AttestationType availability" {
    const app_attest = AttestationType.app_attest;
    try std.testing.expectEqualStrings("App Attest", app_attest.getDisplayName());

    const play_integrity = AttestationType.play_integrity;
    try std.testing.expectEqualStrings("Play Integrity", play_integrity.getDisplayName());
}

test "AttestationStatus properties" {
    try std.testing.expect(AttestationStatus.success.isSuccess());
    try std.testing.expect(!AttestationStatus.attestation_failed.isSuccess());
    try std.testing.expect(AttestationStatus.network_error.isRetryable());
    try std.testing.expect(!AttestationStatus.device_not_supported.isRetryable());
}

test "RiskLevel from score" {
    try std.testing.expectEqual(RiskLevel.low, RiskLevel.fromScore(95));
    try std.testing.expectEqual(RiskLevel.medium, RiskLevel.fromScore(75));
    try std.testing.expectEqual(RiskLevel.high, RiskLevel.fromScore(50));
    try std.testing.expectEqual(RiskLevel.critical, RiskLevel.fromScore(20));
    try std.testing.expectEqual(RiskLevel.unknown, RiskLevel.fromScore(0));
}

test "RiskLevel to score" {
    try std.testing.expectEqual(@as(u8, 95), RiskLevel.low.toScore());
    try std.testing.expectEqual(@as(u8, 75), RiskLevel.medium.toScore());
}

test "AttestationKey creation" {
    const key = AttestationKey.init(.app_attest);
    try std.testing.expectEqual(AttestationType.app_attest, key.attestation_type);
    try std.testing.expect(!key.is_valid);
    try std.testing.expectEqual(@as(usize, 0), key.key_id_len);
}

test "AttestationKey with key ID" {
    const key = AttestationKey.init(.app_attest)
        .withKeyId("test-key-id");
    try std.testing.expect(key.is_valid);
    try std.testing.expectEqualStrings("test-key-id", key.getKeyIdSlice());
}

test "AttestationKey expiration" {
    const key = AttestationKey.init(.app_attest)
        .withExpiration(0);
    try std.testing.expect(key.isExpired());
    try std.testing.expectEqual(@as(i64, 0), key.getRemainingValidity());
}

test "Challenge creation" {
    const challenge = Challenge.init();
    try std.testing.expectEqual(@as(usize, 0), challenge.data_len);
}

test "Challenge with data" {
    const challenge = Challenge.init()
        .withData("test-challenge-data");
    try std.testing.expectEqualStrings("test-challenge-data", challenge.getDataSlice());
}

test "Challenge with nonce" {
    const nonce = [_]u8{1} ** 32;
    const challenge = Challenge.init()
        .withNonce(&nonce);
    try std.testing.expectEqual(@as(u8, 1), challenge.nonce[0]);
}

test "Challenge validity" {
    const valid_challenge = Challenge.init()
        .withData("test")
        .withExpiration(getCurrentTimestamp() + 3600);
    try std.testing.expect(valid_challenge.isValid());

    const expired_challenge = Challenge.init()
        .withData("test")
        .withExpiration(0);
    try std.testing.expect(!expired_challenge.isValid());
}

test "AttestationObject creation" {
    const obj = AttestationObject.init(.cbor);
    try std.testing.expect(obj.isEmpty());
    try std.testing.expectEqual(AttestationObject.AttestationFormat.cbor, obj.format);
}

test "AttestationObject with data" {
    const obj = AttestationObject.init(.json)
        .withData("test-attestation-data");
    try std.testing.expect(!obj.isEmpty());
    try std.testing.expectEqualStrings("test-attestation-data", obj.getDataSlice());
}

test "Assertion creation" {
    const assertion = Assertion.init();
    try std.testing.expectEqual(@as(usize, 0), assertion.signature_len);
    try std.testing.expectEqual(@as(u64, 0), assertion.counter);
}

test "Assertion with signature" {
    const assertion = Assertion.init()
        .withSignature("test-signature")
        .withCounter(5);
    try std.testing.expectEqualStrings("test-signature", assertion.getSignatureSlice());
    try std.testing.expectEqual(@as(u64, 5), assertion.counter);
}

test "Assertion with authenticator data" {
    const assertion = Assertion.init()
        .withAuthenticatorData("auth-data");
    try std.testing.expectEqualStrings("auth-data", assertion.getAuthenticatorDataSlice());
}

test "IntegrityVerdict creation" {
    const verdict = IntegrityVerdict.init();
    try std.testing.expect(!verdict.isPassing());
    try std.testing.expect(!verdict.isHighTrust());
}

test "IntegrityVerdict passing" {
    const verdict = IntegrityVerdict.init()
        .withDeviceIntegrity(.{
            .meets_device_integrity = true,
            .meets_basic_integrity = true,
            .meets_strong_integrity = false,
            .is_emulator = false,
            .is_rooted = false,
        })
        .withAppIntegrity(.{
            .is_recognized = true,
            .is_licensed = false,
            .package_name_matches = true,
            .certificate_matches = true,
            .version_code = 1,
        });
    try std.testing.expect(verdict.isPassing());
    try std.testing.expect(!verdict.isHighTrust());
}

test "IntegrityVerdict high trust" {
    const verdict = IntegrityVerdict.init()
        .withDeviceIntegrity(.{
            .meets_device_integrity = true,
            .meets_basic_integrity = true,
            .meets_strong_integrity = true,
            .is_emulator = false,
            .is_rooted = false,
        })
        .withAppIntegrity(.{
            .is_recognized = true,
            .is_licensed = true,
            .package_name_matches = true,
            .certificate_matches = true,
            .version_code = 1,
        });
    try std.testing.expect(verdict.isHighTrust());
}

test "AttestationResult creation" {
    const result = AttestationResult.init(.app_attest, .success);
    try std.testing.expect(result.isSuccess());
    try std.testing.expectEqual(AttestationType.app_attest, result.attestation_type);
}

test "AttestationResult with components" {
    const key = AttestationKey.init(.app_attest).withKeyId("key");
    const obj = AttestationObject.init(.cbor).withData("data");

    const result = AttestationResult.init(.app_attest, .success)
        .withKey(key)
        .withAttestationObject(obj)
        .withRequestId("req-123");

    try std.testing.expect(result.attestation_object != null);
    try std.testing.expectEqualStrings("req-123", result.getRequestIdSlice());
}

test "AttestationConfig creation" {
    const config = AttestationConfig.init(.app_attest);
    try std.testing.expectEqual(@as(u32, 300), config.challenge_timeout_seconds);
    try std.testing.expectEqual(@as(u32, 30), config.key_validity_days);
}

test "AttestationConfig builder" {
    const config = AttestationConfig.init(.play_integrity)
        .withChallengeTimeout(600)
        .withKeyValidity(60)
        .withStrongIntegrity(true)
        .withEmulatorSupport(true)
        .withServerUrl("https://api.example.com")
        .withAppId("com.example.app");

    try std.testing.expectEqual(@as(u32, 600), config.challenge_timeout_seconds);
    try std.testing.expectEqual(@as(u32, 60), config.key_validity_days);
    try std.testing.expect(config.require_strong_integrity);
    try std.testing.expect(config.allow_emulators);
    try std.testing.expectEqualStrings("https://api.example.com", config.getServerUrlSlice());
    try std.testing.expectEqualStrings("com.example.app", config.getAppIdSlice());
}

test "AttestationEvent creation" {
    const event = AttestationEvent.init(.key_generated, .app_attest);
    try std.testing.expectEqual(AttestationEvent.EventType.key_generated, event.event_type);
}

test "AttestationEvent with message" {
    const event = AttestationEvent.init(.attestation_completed, .play_integrity)
        .withStatus(.success)
        .withMessage("Attestation successful");
    try std.testing.expectEqual(AttestationStatus.success, event.status);
    try std.testing.expectEqualStrings("Attestation successful", event.getMessageSlice());
}

test "AppAttestService creation" {
    const config = AttestationConfig.init(.app_attest);
    const service = AppAttestService.init(config);
    try std.testing.expect(!service.hasValidKey());
    try std.testing.expectEqual(@as(u64, 0), service.getAssertionCount());
}

test "PlayIntegrityService creation" {
    const config = AttestationConfig.init(.play_integrity);
    const service = PlayIntegrityService.init(config);
    try std.testing.expectEqual(@as(u64, 0), service.getRequestCount());
    try std.testing.expect(service.getLastVerdict() == null);
}

test "AppAttestController initialization" {
    const allocator = std.testing.allocator;
    const config = AttestationConfig.init(.app_attest);
    var controller = AppAttestController.init(config);
    defer controller.deinit(allocator);

    try std.testing.expect(controller.is_initialized);
}

test "AppAttestController statistics" {
    const allocator = std.testing.allocator;
    const config = AttestationConfig.init(.app_attest);
    var controller = AppAttestController.init(config);
    defer controller.deinit(allocator);

    const stats = controller.getStatistics();
    try std.testing.expectEqual(@as(u64, 0), stats.total_attestations);
    try std.testing.expectEqual(@as(f32, 0.0), stats.getSuccessRate());
}

test "AppAttestController generate key" {
    const allocator = std.testing.allocator;
    const config = AttestationConfig.init(.app_attest);
    var controller = AppAttestController.init(config);
    defer controller.deinit(allocator);

    const result = controller.generateKey(allocator);
    // Platform-dependent - may succeed on iOS/macOS or fail elsewhere
    try std.testing.expect(result.status == .success or result.status == .device_not_supported);
}

test "AppAttestController event callback" {
    const allocator = std.testing.allocator;
    const config = AttestationConfig.init(.app_attest);
    var controller = AppAttestController.init(config);
    defer controller.deinit(allocator);

    const S = struct {
        fn callback(_: AttestationEvent) void {
            // Callback invoked
        }
    };

    controller.setEventCallback(S.callback);
    try std.testing.expect(controller.event_callback != null);
}

test "AppAttestController attestation flow" {
    const allocator = std.testing.allocator;
    const config = AttestationConfig.init(.app_attest);
    var controller = AppAttestController.init(config);
    defer controller.deinit(allocator);

    // Generate key first
    _ = controller.generateKey(allocator);

    // Create challenge
    const challenge = Challenge.init()
        .withData("server-challenge")
        .withExpiration(getCurrentTimestamp() + 300);

    // Perform attestation
    const result = controller.performAttestation(challenge, allocator);
    try std.testing.expect(result.status == .success or result.status == .device_not_supported);

    // Check history
    try std.testing.expect(controller.getResultHistory().len > 0);
}

test "AppAttestController assertion generation" {
    const allocator = std.testing.allocator;
    const config = AttestationConfig.init(.app_attest);
    var controller = AppAttestController.init(config);
    defer controller.deinit(allocator);

    // Generate key first
    _ = controller.generateKey(allocator);

    // Generate assertion
    const result = controller.generateAssertion("client-data-to-sign", allocator);
    try std.testing.expect(result.status == .success or result.status == .device_not_supported);
}

test "AppAttestController integrity check" {
    const allocator = std.testing.allocator;
    const config = AttestationConfig.init(.play_integrity);
    var controller = AppAttestController.init(config);
    defer controller.deinit(allocator);

    const result = controller.checkIntegrity("nonce-data", allocator);
    // Will fail on non-Android platforms
    try std.testing.expect(result.status == .success or result.status == .device_not_supported);
}

test "AppAttestController clear history" {
    const allocator = std.testing.allocator;
    const config = AttestationConfig.init(.app_attest);
    var controller = AppAttestController.init(config);
    defer controller.deinit(allocator);

    _ = controller.generateKey(allocator);
    try std.testing.expect(controller.getEventHistory().len > 0 or controller.getResultHistory().len > 0);

    controller.clearHistory(allocator);
    try std.testing.expectEqual(@as(usize, 0), controller.getEventHistory().len);
    try std.testing.expectEqual(@as(usize, 0), controller.getResultHistory().len);
}

test "Statistics success rate calculation" {
    const stats = AppAttestController.Statistics{
        .total_attestations = 10,
        .successful_attestations = 8,
        .failed_attestations = 2,
        .total_assertions = 5,
        .integrity_checks = 3,
    };

    try std.testing.expectEqual(@as(f32, 0.8), stats.getSuccessRate());
}

test "Statistics zero attestations" {
    const stats = AppAttestController.Statistics{
        .total_attestations = 0,
        .successful_attestations = 0,
        .failed_attestations = 0,
        .total_assertions = 0,
        .integrity_checks = 0,
    };

    try std.testing.expectEqual(@as(f32, 0.0), stats.getSuccessRate());
}
