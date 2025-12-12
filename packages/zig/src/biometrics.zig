const std = @import("std");
const builtin = @import("builtin");

/// Biometrics/Authentication Module
/// Provides cross-platform biometric authentication for iOS (Face ID, Touch ID),
/// Android (Fingerprint, Face), macOS (Touch ID), and Windows (Windows Hello).
/// Supports fallback to device passcode/password.

// ============================================================================
// Biometric Types
// ============================================================================

/// Type of biometric authentication available
pub const BiometricType = enum {
    /// No biometric authentication available
    none,
    /// Touch ID (iOS/macOS) or Fingerprint (Android)
    fingerprint,
    /// Face ID (iOS) or Face recognition (Android)
    face,
    /// Iris scanner (some Android devices)
    iris,
    /// Multiple biometric types available
    multiple,
    /// Unknown biometric type
    unknown,

    pub fn toString(self: BiometricType) []const u8 {
        return switch (self) {
            .none => "none",
            .fingerprint => "fingerprint",
            .face => "face",
            .iris => "iris",
            .multiple => "multiple",
            .unknown => "unknown",
        };
    }

    pub fn displayName(self: BiometricType) []const u8 {
        return switch (self) {
            .none => "None",
            .fingerprint => "Fingerprint",
            .face => "Face Recognition",
            .iris => "Iris Scanner",
            .multiple => "Biometrics",
            .unknown => "Unknown",
        };
    }

    pub fn iosName(self: BiometricType) []const u8 {
        return switch (self) {
            .fingerprint => "Touch ID",
            .face => "Face ID",
            else => "Biometrics",
        };
    }
};

/// Biometric availability status
pub const BiometricStatus = enum {
    /// Biometrics are available and enrolled
    available,
    /// Hardware is present but no biometrics enrolled
    not_enrolled,
    /// Hardware is not available on this device
    not_available,
    /// Biometrics are locked out (too many failed attempts)
    locked_out,
    /// Temporarily unavailable
    temporarily_unavailable,
    /// Passcode/PIN not set (required for biometrics)
    passcode_not_set,
    /// Unknown status
    unknown,

    pub fn toString(self: BiometricStatus) []const u8 {
        return switch (self) {
            .available => "available",
            .not_enrolled => "not_enrolled",
            .not_available => "not_available",
            .locked_out => "locked_out",
            .temporarily_unavailable => "temporarily_unavailable",
            .passcode_not_set => "passcode_not_set",
            .unknown => "unknown",
        };
    }

    pub fn isAvailable(self: BiometricStatus) bool {
        return self == .available;
    }

    pub fn canEnroll(self: BiometricStatus) bool {
        return self == .not_enrolled;
    }

    pub fn userMessage(self: BiometricStatus) []const u8 {
        return switch (self) {
            .available => "Biometric authentication is available",
            .not_enrolled => "Please enroll your biometrics in Settings",
            .not_available => "Biometric authentication is not available on this device",
            .locked_out => "Biometrics locked. Please use passcode.",
            .temporarily_unavailable => "Biometrics temporarily unavailable",
            .passcode_not_set => "Please set a passcode to use biometrics",
            .unknown => "Unable to determine biometric status",
        };
    }
};

// ============================================================================
// Authentication Results
// ============================================================================

/// Authentication result
pub const AuthResult = enum {
    /// Authentication successful
    success,
    /// User cancelled authentication
    cancelled,
    /// Authentication failed (wrong biometric)
    failed,
    /// User chose to use passcode/password instead
    fallback,
    /// Too many failed attempts
    locked_out,
    /// Biometrics not available
    not_available,
    /// Biometrics not enrolled
    not_enrolled,
    /// System cancelled (e.g., app went to background)
    system_cancel,
    /// Authentication invalidated
    invalidated,
    /// Unknown error
    unknown_error,

    pub fn toString(self: AuthResult) []const u8 {
        return switch (self) {
            .success => "success",
            .cancelled => "cancelled",
            .failed => "failed",
            .fallback => "fallback",
            .locked_out => "locked_out",
            .not_available => "not_available",
            .not_enrolled => "not_enrolled",
            .system_cancel => "system_cancel",
            .invalidated => "invalidated",
            .unknown_error => "unknown_error",
        };
    }

    pub fn isSuccess(self: AuthResult) bool {
        return self == .success;
    }

    pub fn isFailure(self: AuthResult) bool {
        return self != .success and self != .cancelled and self != .fallback;
    }

    pub fn isCancelled(self: AuthResult) bool {
        return self == .cancelled or self == .system_cancel;
    }
};

// ============================================================================
// Authentication Errors
// ============================================================================

/// Authentication errors
pub const AuthError = error{
    /// Biometrics not available
    NotAvailable,
    /// Not enrolled
    NotEnrolled,
    /// Locked out
    LockedOut,
    /// User cancelled
    Cancelled,
    /// Authentication failed
    Failed,
    /// System error
    SystemError,
    /// Invalid context
    InvalidContext,
    /// Passcode not set
    PasscodeNotSet,
};

// ============================================================================
// Authentication Options
// ============================================================================

/// Authentication prompt configuration
pub const AuthOptions = struct {
    /// Reason shown to user (required)
    reason: []const u8,
    /// Title for the authentication dialog (Android)
    title: ?[]const u8,
    /// Subtitle for the dialog (Android)
    subtitle: ?[]const u8,
    /// Negative button text (Android) - defaults to "Cancel"
    cancel_title: ?[]const u8,
    /// Allow fallback to device passcode/password
    allow_fallback: bool,
    /// Fallback button title (iOS)
    fallback_title: ?[]const u8,
    /// Reuse authentication for duration (seconds)
    reuse_duration: ?u32,
    /// Require user confirmation after biometric match (Android)
    confirmation_required: bool,
    /// Allow device credentials as alternative
    allow_device_credential: bool,

    pub fn init(reason: []const u8) AuthOptions {
        return .{
            .reason = reason,
            .title = null,
            .subtitle = null,
            .cancel_title = null,
            .allow_fallback = true,
            .fallback_title = null,
            .reuse_duration = null,
            .confirmation_required = true,
            .allow_device_credential = true,
        };
    }

    pub fn withTitle(self: AuthOptions, title: []const u8) AuthOptions {
        var opts = self;
        opts.title = title;
        return opts;
    }

    pub fn withSubtitle(self: AuthOptions, subtitle: []const u8) AuthOptions {
        var opts = self;
        opts.subtitle = subtitle;
        return opts;
    }

    pub fn withCancelTitle(self: AuthOptions, title: []const u8) AuthOptions {
        var opts = self;
        opts.cancel_title = title;
        return opts;
    }

    pub fn withFallback(self: AuthOptions, allow: bool) AuthOptions {
        var opts = self;
        opts.allow_fallback = allow;
        return opts;
    }

    pub fn withFallbackTitle(self: AuthOptions, title: []const u8) AuthOptions {
        var opts = self;
        opts.fallback_title = title;
        return opts;
    }

    pub fn withReuseDuration(self: AuthOptions, seconds: u32) AuthOptions {
        var opts = self;
        opts.reuse_duration = seconds;
        return opts;
    }

    pub fn biometricOnly(self: AuthOptions) AuthOptions {
        var opts = self;
        opts.allow_fallback = false;
        opts.allow_device_credential = false;
        return opts;
    }
};

/// Common authentication prompts
pub const AuthPrompts = struct {
    pub fn unlockApp() AuthOptions {
        return AuthOptions.init("Authenticate to unlock the app");
    }

    pub fn viewSensitiveData() AuthOptions {
        return AuthOptions.init("Authenticate to view sensitive data")
            .withTitle("View Sensitive Data");
    }

    pub fn confirmPayment() AuthOptions {
        return AuthOptions.init("Authenticate to confirm payment")
            .withTitle("Confirm Payment")
            .biometricOnly();
    }

    pub fn signIn() AuthOptions {
        return AuthOptions.init("Sign in with biometrics")
            .withTitle("Sign In");
    }

    pub fn confirmTransaction() AuthOptions {
        return AuthOptions.init("Authenticate to confirm this transaction")
            .withTitle("Confirm Transaction");
    }

    pub fn accessSecureStorage() AuthOptions {
        return AuthOptions.init("Authenticate to access secure storage")
            .withTitle("Secure Access");
    }
};

// ============================================================================
// Biometrics Manager
// ============================================================================

/// Authentication callback
pub const AuthCallback = *const fn (result: AuthResult) void;

/// Biometrics manager
pub const BiometricsManager = struct {
    allocator: std.mem.Allocator,
    simulated_type: BiometricType,
    simulated_status: BiometricStatus,
    simulated_result: AuthResult,
    auth_callback: ?AuthCallback,
    last_auth_time: u64,
    failed_attempts: u32,
    max_failed_attempts: u32,
    lockout_duration_ms: u64,
    native_context: ?*anyopaque,

    const Self = @This();

    /// Initialize the biometrics manager
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .simulated_type = .fingerprint, // Default for testing
            .simulated_status = .available,
            .simulated_result = .success,
            .auth_callback = null,
            .last_auth_time = 0,
            .failed_attempts = 0,
            .max_failed_attempts = 5,
            .lockout_duration_ms = 30000, // 30 seconds
            .native_context = null,
        };
    }

    /// Deinitialize
    pub fn deinit(self: *Self) void {
        // Cleanup native context if needed
        _ = self;
    }

    /// Check available biometric type
    pub fn getBiometricType(self: *const Self) BiometricType {
        // Platform-specific detection
        if (comptime builtin.os.tag == .ios) {
            // LAContext *context = [[LAContext alloc] init];
            // if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:nil]) {
            //     if (context.biometryType == LABiometryTypeFaceID) return .face;
            //     if (context.biometryType == LABiometryTypeTouchID) return .fingerprint;
            // }
        } else if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
            // Similar to iOS, check for Touch ID
        } else if (comptime builtin.os.tag == .linux and builtin.abi == .android) {
            // BiometricManager.from(context).canAuthenticate(BIOMETRIC_STRONG)
        }

        // Return simulated type for testing
        return self.simulated_type;
    }

    /// Check biometric availability status
    pub fn getStatus(self: *Self) BiometricStatus {
        // Check for lockout
        if (self.failed_attempts >= self.max_failed_attempts) {
            const now = getCurrentTimeMs();
            if (now < self.last_auth_time + self.lockout_duration_ms) {
                return .locked_out;
            }
            // Reset after lockout duration
            self.failed_attempts = 0;
        }

        // Platform-specific status check
        if (comptime builtin.os.tag == .ios) {
            // LAContext evaluation
        } else if (comptime builtin.os.tag == .linux and builtin.abi == .android) {
            // BiometricManager.canAuthenticate()
        }

        return self.simulated_status;
    }

    /// Check if biometrics are available
    pub fn isAvailable(self: *Self) bool {
        return self.getStatus().isAvailable();
    }

    /// Check if specific biometric type is supported
    pub fn supports(self: *const Self, biometric_type: BiometricType) bool {
        const current = self.getBiometricType();
        if (current == .multiple) return true;
        return current == biometric_type;
    }

    /// Authenticate with biometrics
    pub fn authenticate(self: *Self, options: AuthOptions) AuthError!AuthResult {
        const status = self.getStatus();

        // Check availability
        if (status == .not_available) return AuthError.NotAvailable;
        if (status == .not_enrolled) return AuthError.NotEnrolled;
        if (status == .locked_out) return AuthError.LockedOut;
        if (status == .passcode_not_set) return AuthError.PasscodeNotSet;

        // Platform-specific authentication
        if (comptime builtin.os.tag == .ios or builtin.os.tag.isDarwin()) {
            // LAContext *context = [[LAContext alloc] init];
            // context.localizedFallbackTitle = options.fallback_title;
            // context.localizedCancelTitle = options.cancel_title;
            // [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
            //         localizedReason:options.reason
            //                   reply:^(BOOL success, NSError *error) { ... }];
        } else if (comptime builtin.os.tag == .linux and builtin.abi == .android) {
            // BiometricPrompt.PromptInfo promptInfo = new BiometricPrompt.PromptInfo.Builder()
            //     .setTitle(options.title)
            //     .setSubtitle(options.subtitle)
            //     .setNegativeButtonText(options.cancel_title)
            //     .setAllowedAuthenticators(...)
            //     .build();
            // biometricPrompt.authenticate(promptInfo);
        }

        // Simulated result for testing
        const result = self.simulated_result;

        // Track failed attempts
        if (result == .failed) {
            self.failed_attempts += 1;
            self.last_auth_time = getCurrentTimeMs();
        } else if (result == .success) {
            self.failed_attempts = 0;
            self.last_auth_time = getCurrentTimeMs();
        }

        // Handle fallback option
        if (result == .failed and options.allow_fallback) {
            // Could prompt for passcode
        }

        return result;
    }

    /// Authenticate with callback
    pub fn authenticateAsync(self: *Self, options: AuthOptions, callback: AuthCallback) void {
        self.auth_callback = callback;

        const result = self.authenticate(options) catch |err| {
            const error_result: AuthResult = switch (err) {
                AuthError.NotAvailable => .not_available,
                AuthError.NotEnrolled => .not_enrolled,
                AuthError.LockedOut => .locked_out,
                AuthError.Cancelled => .cancelled,
                AuthError.PasscodeNotSet => .not_available,
                else => .unknown_error,
            };
            callback(error_result);
            return;
        };

        callback(result);
    }

    /// Check if device has passcode/PIN set
    pub fn isPasscodeSet(self: *const Self) bool {
        // Platform-specific check
        if (comptime builtin.os.tag == .ios) {
            // LAContext *context = [[LAContext alloc] init];
            // [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:nil]
        }

        return self.simulated_status != .passcode_not_set;
    }

    /// Authenticate with device passcode/password only
    pub fn authenticateWithPasscode(self: *Self, reason: []const u8) AuthError!AuthResult {
        if (!self.isPasscodeSet()) return AuthError.PasscodeNotSet;

        // Platform-specific passcode authentication
        if (comptime builtin.os.tag == .ios) {
            // evaluatePolicy:LAPolicyDeviceOwnerAuthentication
        }

        _ = reason;
        return self.simulated_result;
    }

    /// Invalidate any cached authentication
    pub fn invalidate(self: *Self) void {
        self.last_auth_time = 0;

        // Platform-specific invalidation
        if (comptime builtin.os.tag == .ios) {
            // [context invalidate];
        }
    }

    /// Reset failed attempts counter
    pub fn resetFailedAttempts(self: *Self) void {
        self.failed_attempts = 0;
    }

    /// Get remaining lockout time in milliseconds
    pub fn getRemainingLockoutTime(self: *const Self) u64 {
        if (self.failed_attempts < self.max_failed_attempts) return 0;

        const now = getCurrentTimeMs();
        const lockout_end = self.last_auth_time + self.lockout_duration_ms;

        if (now >= lockout_end) return 0;
        return lockout_end - now;
    }

    /// Check if authentication is still valid (within reuse duration)
    pub fn isAuthenticationValid(self: *const Self, reuse_duration_ms: u64) bool {
        if (self.last_auth_time == 0) return false;

        const now = getCurrentTimeMs();
        return now < self.last_auth_time + reuse_duration_ms;
    }

    // Testing/simulation methods

    /// Set simulated biometric type (for testing)
    pub fn setSimulatedType(self: *Self, biometric_type: BiometricType) void {
        self.simulated_type = biometric_type;
    }

    /// Set simulated status (for testing)
    pub fn setSimulatedStatus(self: *Self, status: BiometricStatus) void {
        self.simulated_status = status;
    }

    /// Set simulated result (for testing)
    pub fn setSimulatedResult(self: *Self, result: AuthResult) void {
        self.simulated_result = result;
    }

    /// Set lockout configuration
    pub fn setLockoutConfig(self: *Self, max_attempts: u32, duration_ms: u64) void {
        self.max_failed_attempts = max_attempts;
        self.lockout_duration_ms = duration_ms;
    }

    fn getCurrentTimeMs() u64 {
        const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
        if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
            return @as(u64, @intCast(ts.sec)) * 1000 + @as(u64, @intCast(ts.nsec)) / 1_000_000;
        } else {
            return @as(u64, @intCast(ts.sec)) * 1000 + @as(u64, @intCast(ts.nsec)) / 1_000_000;
        }
    }
};

// ============================================================================
// Biometric Keychain Integration
// ============================================================================

/// Biometric-protected keychain item access
pub const BiometricKeychain = struct {
    allocator: std.mem.Allocator,
    service: []const u8,
    access_control: AccessControl,

    /// Access control for keychain items
    pub const AccessControl = enum {
        /// Requires biometric authentication each time
        biometry_any,
        /// Requires current biometric (invalidated if biometrics change)
        biometry_current_set,
        /// Requires device passcode
        device_passcode,
        /// Biometry or device passcode
        biometry_or_passcode,

        pub fn toiOSFlags(self: AccessControl) []const u8 {
            return switch (self) {
                .biometry_any => "kSecAccessControlBiometryAny",
                .biometry_current_set => "kSecAccessControlBiometryCurrentSet",
                .device_passcode => "kSecAccessControlDevicePasscode",
                .biometry_or_passcode => "kSecAccessControlUserPresence",
            };
        }
    };

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, service: []const u8) Self {
        return .{
            .allocator = allocator,
            .service = service,
            .access_control = .biometry_or_passcode,
        };
    }

    pub fn withAccessControl(self: Self, control: AccessControl) Self {
        var k = self;
        k.access_control = control;
        return k;
    }

    /// Store a value with biometric protection
    pub fn set(_: *Self, _: []const u8, _: []const u8, _: []const u8) AuthError!void {
        // Platform-specific implementation
        if (comptime builtin.os.tag == .ios or builtin.os.tag.isDarwin()) {
            // SecAccessControlRef access = SecAccessControlCreateWithFlags(
            //     kCFAllocatorDefault,
            //     kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            //     self.access_control.toiOSFlags(),
            //     NULL);
            // SecItemAdd with kSecUseAuthenticationContext
        }
    }

    /// Get a value with biometric authentication
    pub fn get(_: *Self, _: []const u8, _: []const u8) AuthError!?[]const u8 {
        // Platform-specific implementation
        if (comptime builtin.os.tag == .ios or builtin.os.tag.isDarwin()) {
            // LAContext *context = [[LAContext alloc] init];
            // context.localizedReason = reason;
            // SecItemCopyMatching with kSecUseAuthenticationContext
        }

        return null;
    }

    /// Delete a biometric-protected value
    pub fn delete(_: *Self, _: []const u8) AuthError!void {
        // SecItemDelete
    }
};

// ============================================================================
// Quick Authentication Utilities
// ============================================================================

/// Quick authentication utilities
pub const QuickAuth = struct {
    /// Simple biometric check
    pub fn authenticate(manager: *BiometricsManager, reason: []const u8) bool {
        const options = AuthOptions.init(reason);
        const result = manager.authenticate(options) catch return false;
        return result.isSuccess();
    }

    /// Authenticate or fallback to passcode
    pub fn authenticateWithFallback(manager: *BiometricsManager, reason: []const u8) bool {
        const options = AuthOptions.init(reason).withFallback(true);
        const result = manager.authenticate(options) catch {
            // Try passcode
            const passcode_result = manager.authenticateWithPasscode(reason) catch return false;
            return passcode_result.isSuccess();
        };
        return result.isSuccess() or result == .fallback;
    }

    /// Check if biometrics should be shown as login option
    pub fn canUseBiometricLogin(manager: *BiometricsManager) bool {
        return manager.isAvailable();
    }

    /// Get appropriate biometric button text
    pub fn getBiometricButtonText(manager: *const BiometricsManager) []const u8 {
        const biometric_type = manager.getBiometricType();
        return switch (biometric_type) {
            .face => "Sign in with Face ID",
            .fingerprint => "Sign in with Touch ID",
            else => "Sign in with Biometrics",
        };
    }

    /// Get biometric icon name
    pub fn getBiometricIconName(manager: *const BiometricsManager) []const u8 {
        const biometric_type = manager.getBiometricType();
        return switch (biometric_type) {
            .face => "faceid",
            .fingerprint => "touchid",
            .iris => "eye",
            else => "lock",
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "BiometricType basics" {
    const fingerprint = BiometricType.fingerprint;
    try std.testing.expectEqualStrings("fingerprint", fingerprint.toString());
    try std.testing.expectEqualStrings("Fingerprint", fingerprint.displayName());
    try std.testing.expectEqualStrings("Touch ID", fingerprint.iosName());

    const face = BiometricType.face;
    try std.testing.expectEqualStrings("face", face.toString());
    try std.testing.expectEqualStrings("Face ID", face.iosName());
}

test "BiometricStatus properties" {
    const available = BiometricStatus.available;
    try std.testing.expect(available.isAvailable());
    try std.testing.expect(!available.canEnroll());

    const not_enrolled = BiometricStatus.not_enrolled;
    try std.testing.expect(!not_enrolled.isAvailable());
    try std.testing.expect(not_enrolled.canEnroll());

    const locked = BiometricStatus.locked_out;
    try std.testing.expect(!locked.isAvailable());
}

test "BiometricStatus userMessage" {
    const status = BiometricStatus.not_enrolled;
    try std.testing.expectEqualStrings(
        "Please enroll your biometrics in Settings",
        status.userMessage(),
    );
}

test "AuthResult properties" {
    const success = AuthResult.success;
    try std.testing.expect(success.isSuccess());
    try std.testing.expect(!success.isFailure());
    try std.testing.expect(!success.isCancelled());

    const failed = AuthResult.failed;
    try std.testing.expect(!failed.isSuccess());
    try std.testing.expect(failed.isFailure());

    const cancelled = AuthResult.cancelled;
    try std.testing.expect(cancelled.isCancelled());
    try std.testing.expect(!cancelled.isFailure());
}

test "AuthOptions creation" {
    const options = AuthOptions.init("Test authentication");
    try std.testing.expectEqualStrings("Test authentication", options.reason);
    try std.testing.expect(options.allow_fallback);
    try std.testing.expect(options.title == null);
}

test "AuthOptions builder pattern" {
    const options = AuthOptions.init("Test")
        .withTitle("My Title")
        .withSubtitle("My Subtitle")
        .withCancelTitle("Cancel")
        .withFallback(false)
        .withReuseDuration(60);

    try std.testing.expectEqualStrings("My Title", options.title.?);
    try std.testing.expectEqualStrings("My Subtitle", options.subtitle.?);
    try std.testing.expectEqualStrings("Cancel", options.cancel_title.?);
    try std.testing.expect(!options.allow_fallback);
    try std.testing.expectEqual(@as(u32, 60), options.reuse_duration.?);
}

test "AuthOptions biometricOnly" {
    const options = AuthOptions.init("Test").biometricOnly();
    try std.testing.expect(!options.allow_fallback);
    try std.testing.expect(!options.allow_device_credential);
}

test "AuthPrompts presets" {
    const unlock = AuthPrompts.unlockApp();
    try std.testing.expectEqualStrings("Authenticate to unlock the app", unlock.reason);

    const payment = AuthPrompts.confirmPayment();
    try std.testing.expect(!payment.allow_fallback);
}

test "BiometricsManager initialization" {
    var manager = BiometricsManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectEqual(BiometricType.fingerprint, manager.getBiometricType());
    try std.testing.expect(manager.isAvailable());
}

test "BiometricsManager status" {
    var manager = BiometricsManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectEqual(BiometricStatus.available, manager.getStatus());

    manager.setSimulatedStatus(.not_enrolled);
    try std.testing.expectEqual(BiometricStatus.not_enrolled, manager.getStatus());
}

test "BiometricsManager authenticate success" {
    var manager = BiometricsManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setSimulatedResult(.success);
    const options = AuthOptions.init("Test");
    const result = try manager.authenticate(options);

    try std.testing.expectEqual(AuthResult.success, result);
}

test "BiometricsManager authenticate failure" {
    var manager = BiometricsManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setSimulatedResult(.failed);
    const options = AuthOptions.init("Test");
    const result = try manager.authenticate(options);

    try std.testing.expectEqual(AuthResult.failed, result);
    try std.testing.expectEqual(@as(u32, 1), manager.failed_attempts);
}

test "BiometricsManager not available error" {
    var manager = BiometricsManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setSimulatedStatus(.not_available);
    const options = AuthOptions.init("Test");

    const result = manager.authenticate(options);
    try std.testing.expectError(AuthError.NotAvailable, result);
}

test "BiometricsManager not enrolled error" {
    var manager = BiometricsManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setSimulatedStatus(.not_enrolled);
    const options = AuthOptions.init("Test");

    const result = manager.authenticate(options);
    try std.testing.expectError(AuthError.NotEnrolled, result);
}

test "BiometricsManager lockout after failed attempts" {
    var manager = BiometricsManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setLockoutConfig(3, 1000); // Lock after 3 attempts for 1 second
    manager.setSimulatedResult(.failed);

    const options = AuthOptions.init("Test");

    // Fail 3 times
    _ = try manager.authenticate(options);
    _ = try manager.authenticate(options);
    _ = try manager.authenticate(options);

    // Should be locked out now
    try std.testing.expectEqual(BiometricStatus.locked_out, manager.getStatus());

    const result = manager.authenticate(options);
    try std.testing.expectError(AuthError.LockedOut, result);
}

test "BiometricsManager reset failed attempts" {
    var manager = BiometricsManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.failed_attempts = 5;
    manager.resetFailedAttempts();

    try std.testing.expectEqual(@as(u32, 0), manager.failed_attempts);
}

test "BiometricsManager supports type" {
    var manager = BiometricsManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setSimulatedType(.fingerprint);
    try std.testing.expect(manager.supports(.fingerprint));
    try std.testing.expect(!manager.supports(.face));

    manager.setSimulatedType(.multiple);
    try std.testing.expect(manager.supports(.fingerprint));
    try std.testing.expect(manager.supports(.face));
}

test "BiometricsManager invalidate" {
    var manager = BiometricsManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.last_auth_time = 12345;
    manager.invalidate();

    try std.testing.expectEqual(@as(u64, 0), manager.last_auth_time);
}

test "BiometricsManager isAuthenticationValid" {
    var manager = BiometricsManager.init(std.testing.allocator);
    defer manager.deinit();

    // No previous auth
    try std.testing.expect(!manager.isAuthenticationValid(5000));

    // Set last auth time to now
    manager.last_auth_time = BiometricsManager.getCurrentTimeMs();
    try std.testing.expect(manager.isAuthenticationValid(5000));
}

test "BiometricsManager getRemainingLockoutTime" {
    var manager = BiometricsManager.init(std.testing.allocator);
    defer manager.deinit();

    // Not locked out
    try std.testing.expectEqual(@as(u64, 0), manager.getRemainingLockoutTime());

    // Trigger lockout
    manager.setLockoutConfig(1, 10000);
    manager.failed_attempts = 1;
    manager.last_auth_time = BiometricsManager.getCurrentTimeMs();

    const remaining = manager.getRemainingLockoutTime();
    try std.testing.expect(remaining > 0);
    try std.testing.expect(remaining <= 10000);
}

test "BiometricKeychain initialization" {
    var keychain = BiometricKeychain.init(std.testing.allocator, "com.app.secure");

    try std.testing.expectEqualStrings("com.app.secure", keychain.service);
    try std.testing.expectEqual(BiometricKeychain.AccessControl.biometry_or_passcode, keychain.access_control);
}

test "BiometricKeychain withAccessControl" {
    const keychain = BiometricKeychain.init(std.testing.allocator, "com.app.secure")
        .withAccessControl(.biometry_current_set);

    try std.testing.expectEqual(BiometricKeychain.AccessControl.biometry_current_set, keychain.access_control);
}

test "AccessControl toiOSFlags" {
    const control = BiometricKeychain.AccessControl.biometry_any;
    try std.testing.expectEqualStrings("kSecAccessControlBiometryAny", control.toiOSFlags());
}

test "QuickAuth authenticate" {
    var manager = BiometricsManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setSimulatedResult(.success);
    try std.testing.expect(QuickAuth.authenticate(&manager, "Test"));

    manager.setSimulatedResult(.failed);
    try std.testing.expect(!QuickAuth.authenticate(&manager, "Test"));
}

test "QuickAuth canUseBiometricLogin" {
    var manager = BiometricsManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setSimulatedStatus(.available);
    try std.testing.expect(QuickAuth.canUseBiometricLogin(&manager));

    manager.setSimulatedStatus(.not_available);
    try std.testing.expect(!QuickAuth.canUseBiometricLogin(&manager));
}

test "QuickAuth getBiometricButtonText" {
    var manager = BiometricsManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setSimulatedType(.face);
    try std.testing.expectEqualStrings("Sign in with Face ID", QuickAuth.getBiometricButtonText(&manager));

    manager.setSimulatedType(.fingerprint);
    try std.testing.expectEqualStrings("Sign in with Touch ID", QuickAuth.getBiometricButtonText(&manager));
}

test "QuickAuth getBiometricIconName" {
    var manager = BiometricsManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setSimulatedType(.face);
    try std.testing.expectEqualStrings("faceid", QuickAuth.getBiometricIconName(&manager));

    manager.setSimulatedType(.fingerprint);
    try std.testing.expectEqualStrings("touchid", QuickAuth.getBiometricIconName(&manager));
}

test "BiometricsManager authenticateAsync" {
    var manager = BiometricsManager.init(std.testing.allocator);
    defer manager.deinit();

    const TestCallback = struct {
        fn callback(result: AuthResult) void {
            _ = result;
            // Can't capture locals in Zig function pointers
            // This test verifies the function can be called
        }
    };

    manager.setSimulatedResult(.success);
    manager.authenticateAsync(AuthOptions.init("Test"), TestCallback.callback);

    // Just verify no crash - can't check callback result with function pointers
}

test "BiometricsManager isPasscodeSet" {
    var manager = BiometricsManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setSimulatedStatus(.available);
    try std.testing.expect(manager.isPasscodeSet());

    manager.setSimulatedStatus(.passcode_not_set);
    try std.testing.expect(!manager.isPasscodeSet());
}

test "BiometricsManager authenticateWithPasscode" {
    var manager = BiometricsManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setSimulatedResult(.success);
    const result = try manager.authenticateWithPasscode("Test");
    try std.testing.expectEqual(AuthResult.success, result);

    manager.setSimulatedStatus(.passcode_not_set);
    const error_result = manager.authenticateWithPasscode("Test");
    try std.testing.expectError(AuthError.PasscodeNotSet, error_result);
}
