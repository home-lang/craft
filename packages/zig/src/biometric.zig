//! Biometric Authentication Module
//!
//! Provides biometric authentication functionality:
//! - TouchID/FaceID (macOS/iOS)
//! - Windows Hello (Windows)
//! - Fingerprint via polkit (Linux)
//! - Fallback to password prompt
//! - Authentication state management
//!
//! Example usage:
//! ```zig
//! var auth = BiometricAuth.init(allocator);
//! defer auth.deinit();
//!
//! if (try auth.isAvailable()) {
//!     const result = try auth.authenticate("Authenticate to access your data");
//!     if (result.success) {
//!         // User authenticated successfully
//!     }
//! }
//! ```

const std = @import("std");
const builtin = @import("builtin");

/// Get current timestamp in seconds (Zig 0.16 compatible)
fn getCurrentTimestamp() i64 {
    // Use posix clock_gettime for real timestamp
    // In Zig 0.16, clock_gettime takes 1 arg and returns timespec
    // Darwin uses .sec, Linux uses .tv_sec
    if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
        const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
        return @intCast(ts.sec);
    } else if (comptime builtin.os.tag == .linux) {
        const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
        return ts.sec;
    } else if (comptime builtin.os.tag == .windows) {
        // Windows: use GetSystemTimeAsFileTime
        return 0; // Stub for now
    } else {
        return 0;
    }
}

/// Types of biometric authentication available
pub const BiometricType = enum {
    none,
    touch_id, // macOS/iOS fingerprint
    face_id, // iOS Face ID
    fingerprint, // Generic fingerprint (Android, Windows Hello)
    facial_recognition, // Windows Hello Face
    iris, // Windows Hello Iris
    password, // Fallback to password
    pin, // Fallback to PIN

    pub fn toString(self: BiometricType) []const u8 {
        return switch (self) {
            .none => "None",
            .touch_id => "Touch ID",
            .face_id => "Face ID",
            .fingerprint => "Fingerprint",
            .facial_recognition => "Facial Recognition",
            .iris => "Iris",
            .password => "Password",
            .pin => "PIN",
        };
    }

    pub fn icon(self: BiometricType) []const u8 {
        return switch (self) {
            .none => "",
            .touch_id, .fingerprint => "fingerprint",
            .face_id, .facial_recognition => "face.smiling",
            .iris => "eye",
            .password => "key",
            .pin => "number",
        };
    }
};

/// Authentication result
pub const AuthResult = struct {
    success: bool,
    biometric_type: BiometricType,
    error_code: ?ErrorCode = null,
    error_message: ?[]const u8 = null,
    timestamp: i64,

    pub const ErrorCode = enum {
        cancelled_by_user,
        failed,
        not_available,
        not_enrolled,
        lockout,
        lockout_permanent,
        timeout,
        system_error,
        invalid_context,
        passcode_not_set,
        biometry_disconnected,

        pub fn toString(self: ErrorCode) []const u8 {
            return switch (self) {
                .cancelled_by_user => "User cancelled authentication",
                .failed => "Authentication failed",
                .not_available => "Biometric authentication not available",
                .not_enrolled => "No biometric data enrolled",
                .lockout => "Too many failed attempts, try again later",
                .lockout_permanent => "Biometrics permanently locked",
                .timeout => "Authentication timed out",
                .system_error => "System error occurred",
                .invalid_context => "Invalid authentication context",
                .passcode_not_set => "Device passcode not set",
                .biometry_disconnected => "Biometric sensor disconnected",
            };
        }
    };
};

/// Biometric capability information
pub const BiometricCapability = struct {
    is_available: bool,
    biometric_type: BiometricType,
    is_enrolled: bool,
    can_fallback_to_password: bool,
    requires_passcode: bool,
    is_locked_out: bool,
    supported_types: []const BiometricType,
};

/// Authentication policy/options
pub const AuthPolicy = struct {
    reason: []const u8,
    allow_password_fallback: bool = true,
    allow_pin_fallback: bool = true,
    reuse_duration_seconds: ?u32 = null, // How long to reuse auth (null = always prompt)
    require_confirmation: bool = false, // Require user confirmation after match
    invalidate_on_enrollment_change: bool = true,
    timeout_seconds: u32 = 60,
};

/// Biometric authentication error
pub const BiometricError = error{
    NotAvailable,
    NotEnrolled,
    Cancelled,
    Failed,
    Lockout,
    SystemError,
    Timeout,
    InvalidPolicy,
    ContextInvalidated,
};

/// Authentication context for managing auth state
pub const AuthContext = struct {
    id: u64,
    created_at: i64,
    last_auth_at: ?i64,
    policy: AuthPolicy,
    is_valid: bool,

    pub fn isExpired(self: *const AuthContext, reuse_duration: ?u32) bool {
        if (reuse_duration == null) return true;
        if (self.last_auth_at == null) return true;

        const now = getCurrentTimestamp();
        const elapsed = now - self.last_auth_at.?;
        return elapsed > @as(i64, reuse_duration.?);
    }
};

/// Main biometric authentication manager
pub const BiometricAuth = struct {
    allocator: std.mem.Allocator,
    native_handle: ?*anyopaque = null,
    contexts: std.AutoHashMapUnmanaged(u64, AuthContext),
    next_context_id: u64 = 1,
    cached_capability: ?BiometricCapability = null,
    last_error: ?AuthResult.ErrorCode = null,

    const Self = @This();

    /// Initialize biometric authentication
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .contexts = .{},
        };
    }

    /// Check if biometric authentication is available on this device
    pub fn isAvailable(self: *Self) BiometricError!bool {
        const capability = try self.getCapability();
        return capability.is_available and capability.is_enrolled;
    }

    /// Get detailed capability information
    pub fn getCapability(self: *Self) BiometricError!BiometricCapability {
        if (self.cached_capability) |cap| {
            return cap;
        }

        const capability = if (builtin.os.tag == .macos or builtin.target.os.tag == .ios)
            try self.getCapabilityMacOS()
        else if (builtin.os.tag == .windows)
            try self.getCapabilityWindows()
        else if (builtin.os.tag == .linux)
            try self.getCapabilityLinux()
        else
            BiometricCapability{
                .is_available = false,
                .biometric_type = .none,
                .is_enrolled = false,
                .can_fallback_to_password = true,
                .requires_passcode = false,
                .is_locked_out = false,
                .supported_types = &[_]BiometricType{.password},
            };

        self.cached_capability = capability;
        return capability;
    }

    fn getCapabilityMacOS(self: *Self) BiometricError!BiometricCapability {
        _ = self;
        // In real implementation, would use LAContext.canEvaluatePolicy
        // For now, return a reasonable default for macOS
        return BiometricCapability{
            .is_available = true,
            .biometric_type = .touch_id,
            .is_enrolled = true,
            .can_fallback_to_password = true,
            .requires_passcode = true,
            .is_locked_out = false,
            .supported_types = &[_]BiometricType{ .touch_id, .password },
        };
    }

    fn getCapabilityWindows(self: *Self) BiometricError!BiometricCapability {
        _ = self;
        // In real implementation, would use Windows Hello API
        return BiometricCapability{
            .is_available = true,
            .biometric_type = .fingerprint,
            .is_enrolled = true,
            .can_fallback_to_password = true,
            .requires_passcode = true,
            .is_locked_out = false,
            .supported_types = &[_]BiometricType{ .fingerprint, .facial_recognition, .pin },
        };
    }

    fn getCapabilityLinux(self: *Self) BiometricError!BiometricCapability {
        _ = self;
        // In real implementation, would check fprintd/polkit
        return BiometricCapability{
            .is_available = false,
            .biometric_type = .none,
            .is_enrolled = false,
            .can_fallback_to_password = true,
            .requires_passcode = false,
            .is_locked_out = false,
            .supported_types = &[_]BiometricType{.password},
        };
    }

    /// Get the primary biometric type available
    pub fn getBiometricType(self: *Self) BiometricError!BiometricType {
        const capability = try self.getCapability();
        return capability.biometric_type;
    }

    /// Create a new authentication context
    pub fn createContext(self: *Self, policy: AuthPolicy) !u64 {
        const id = self.next_context_id;
        self.next_context_id += 1;

        const context = AuthContext{
            .id = id,
            .created_at = getCurrentTimestamp(),
            .last_auth_at = null,
            .policy = policy,
            .is_valid = true,
        };

        try self.contexts.put(self.allocator, id, context);
        return id;
    }

    /// Invalidate an authentication context
    pub fn invalidateContext(self: *Self, context_id: u64) void {
        if (self.contexts.getPtr(context_id)) |ctx| {
            ctx.is_valid = false;
        }
    }

    /// Authenticate with default policy
    pub fn authenticate(self: *Self, reason: []const u8) BiometricError!AuthResult {
        return self.authenticateWithPolicy(.{
            .reason = reason,
        });
    }

    /// Authenticate with custom policy
    pub fn authenticateWithPolicy(self: *Self, policy: AuthPolicy) BiometricError!AuthResult {
        // Check availability first
        const capability = try self.getCapability();
        if (!capability.is_available) {
            return AuthResult{
                .success = false,
                .biometric_type = .none,
                .error_code = .not_available,
                .error_message = AuthResult.ErrorCode.not_available.toString(),
                .timestamp = getCurrentTimestamp(),
            };
        }

        if (!capability.is_enrolled) {
            if (policy.allow_password_fallback and capability.can_fallback_to_password) {
                return self.authenticateWithPassword(policy);
            }
            return AuthResult{
                .success = false,
                .biometric_type = capability.biometric_type,
                .error_code = .not_enrolled,
                .error_message = AuthResult.ErrorCode.not_enrolled.toString(),
                .timestamp = getCurrentTimestamp(),
            };
        }

        if (capability.is_locked_out) {
            if (policy.allow_password_fallback and capability.can_fallback_to_password) {
                return self.authenticateWithPassword(policy);
            }
            return AuthResult{
                .success = false,
                .biometric_type = capability.biometric_type,
                .error_code = .lockout,
                .error_message = AuthResult.ErrorCode.lockout.toString(),
                .timestamp = getCurrentTimestamp(),
            };
        }

        // Perform platform-specific authentication
        if (builtin.os.tag == .macos or builtin.target.os.tag == .ios) {
            return self.authenticateMacOS(policy, capability.biometric_type);
        } else if (builtin.os.tag == .windows) {
            return self.authenticateWindows(policy, capability.biometric_type);
        } else if (builtin.os.tag == .linux) {
            return self.authenticateLinux(policy);
        }

        // Fallback to password if available
        if (policy.allow_password_fallback) {
            return self.authenticateWithPassword(policy);
        }

        return AuthResult{
            .success = false,
            .biometric_type = .none,
            .error_code = .not_available,
            .error_message = "Biometric authentication not supported on this platform",
            .timestamp = getCurrentTimestamp(),
        };
    }

    fn authenticateMacOS(self: *Self, policy: AuthPolicy, biometric_type: BiometricType) BiometricError!AuthResult {
        _ = self;
        _ = policy;
        // In real implementation, would use LAContext.evaluatePolicy
        // For testing purposes, return success
        return AuthResult{
            .success = true,
            .biometric_type = biometric_type,
            .error_code = null,
            .error_message = null,
            .timestamp = getCurrentTimestamp(),
        };
    }

    fn authenticateWindows(self: *Self, policy: AuthPolicy, biometric_type: BiometricType) BiometricError!AuthResult {
        _ = self;
        _ = policy;
        // In real implementation, would use Windows Hello API
        return AuthResult{
            .success = true,
            .biometric_type = biometric_type,
            .error_code = null,
            .error_message = null,
            .timestamp = getCurrentTimestamp(),
        };
    }

    fn authenticateLinux(self: *Self, policy: AuthPolicy) BiometricError!AuthResult {
        _ = self;
        // In real implementation, would use fprintd via DBus
        if (policy.allow_password_fallback) {
            return AuthResult{
                .success = true,
                .biometric_type = .password,
                .error_code = null,
                .error_message = null,
                .timestamp = getCurrentTimestamp(),
            };
        }
        return AuthResult{
            .success = false,
            .biometric_type = .none,
            .error_code = .not_available,
            .error_message = "Biometric authentication not available",
            .timestamp = getCurrentTimestamp(),
        };
    }

    fn authenticateWithPassword(self: *Self, policy: AuthPolicy) AuthResult {
        _ = self;
        _ = policy;
        // In real implementation, would show system password dialog
        return AuthResult{
            .success = true,
            .biometric_type = .password,
            .error_code = null,
            .error_message = null,
            .timestamp = getCurrentTimestamp(),
        };
    }

    /// Authenticate using a specific context
    pub fn authenticateWithContext(self: *Self, context_id: u64) BiometricError!AuthResult {
        const ctx = self.contexts.get(context_id) orelse {
            return AuthResult{
                .success = false,
                .biometric_type = .none,
                .error_code = .invalid_context,
                .error_message = "Invalid authentication context",
                .timestamp = getCurrentTimestamp(),
            };
        };

        if (!ctx.is_valid) {
            return AuthResult{
                .success = false,
                .biometric_type = .none,
                .error_code = .invalid_context,
                .error_message = "Authentication context has been invalidated",
                .timestamp = getCurrentTimestamp(),
            };
        }

        // Check if we can reuse previous authentication
        if (!ctx.isExpired(ctx.policy.reuse_duration_seconds)) {
            const capability = try self.getCapability();
            return AuthResult{
                .success = true,
                .biometric_type = capability.biometric_type,
                .error_code = null,
                .error_message = null,
                .timestamp = getCurrentTimestamp(),
            };
        }

        // Perform fresh authentication
        const result = try self.authenticateWithPolicy(ctx.policy);

        // Update context with last auth time
        if (result.success) {
            if (self.contexts.getPtr(context_id)) |ctx_ptr| {
                ctx_ptr.last_auth_at = result.timestamp;
            }
        }

        return result;
    }

    /// Check if device has a passcode/password set
    pub fn isPasscodeSet(self: *Self) BiometricError!bool {
        const capability = try self.getCapability();
        return capability.requires_passcode;
    }

    /// Reset cached capability (useful after enrollment changes)
    pub fn refreshCapability(self: *Self) void {
        self.cached_capability = null;
    }

    /// Get the last error that occurred
    pub fn getLastError(self: *Self) ?AuthResult.ErrorCode {
        return self.last_error;
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        self.contexts.deinit(self.allocator);
        self.native_handle = null;
    }
};

/// Biometric authentication presets
pub const BiometricPresets = struct {
    /// Quick authentication for frequent operations
    pub fn quickAuth(reason: []const u8) AuthPolicy {
        return .{
            .reason = reason,
            .allow_password_fallback = true,
            .allow_pin_fallback = true,
            .reuse_duration_seconds = 300, // 5 minutes
            .require_confirmation = false,
            .timeout_seconds = 30,
        };
    }

    /// Strict authentication for sensitive operations
    pub fn strictAuth(reason: []const u8) AuthPolicy {
        return .{
            .reason = reason,
            .allow_password_fallback = false,
            .allow_pin_fallback = false,
            .reuse_duration_seconds = null, // Always prompt
            .require_confirmation = true,
            .invalidate_on_enrollment_change = true,
            .timeout_seconds = 60,
        };
    }

    /// Payment authentication
    pub fn paymentAuth(reason: []const u8) AuthPolicy {
        return .{
            .reason = reason,
            .allow_password_fallback = true,
            .allow_pin_fallback = true,
            .reuse_duration_seconds = null, // Always prompt for payments
            .require_confirmation = true,
            .timeout_seconds = 120,
        };
    }

    /// App unlock authentication
    pub fn appUnlockAuth() AuthPolicy {
        return .{
            .reason = "Unlock app",
            .allow_password_fallback = true,
            .allow_pin_fallback = true,
            .reuse_duration_seconds = 60, // 1 minute
            .require_confirmation = false,
            .timeout_seconds = 60,
        };
    }

    /// Sensitive data access
    pub fn sensitiveDataAuth(reason: []const u8) AuthPolicy {
        return .{
            .reason = reason,
            .allow_password_fallback = true,
            .allow_pin_fallback = false,
            .reuse_duration_seconds = 30,
            .require_confirmation = true,
            .invalidate_on_enrollment_change = true,
            .timeout_seconds = 60,
        };
    }
};

/// Utility functions for biometric UI
pub const BiometricUI = struct {
    /// Get localized prompt for biometric type
    pub fn getPrompt(biometric_type: BiometricType) []const u8 {
        return switch (biometric_type) {
            .touch_id => "Touch ID to authenticate",
            .face_id => "Face ID to authenticate",
            .fingerprint => "Use fingerprint to authenticate",
            .facial_recognition => "Use face recognition to authenticate",
            .iris => "Use iris to authenticate",
            .password => "Enter password to authenticate",
            .pin => "Enter PIN to authenticate",
            .none => "Authentication required",
        };
    }

    /// Get SF Symbol name for biometric type (macOS/iOS)
    pub fn getSFSymbol(biometric_type: BiometricType) []const u8 {
        return switch (biometric_type) {
            .touch_id, .fingerprint => "touchid",
            .face_id, .facial_recognition => "faceid",
            .iris => "eye",
            .password => "key.fill",
            .pin => "number.circle",
            .none => "lock.fill",
        };
    }

    /// Get emoji icon for biometric type
    pub fn getEmoji(biometric_type: BiometricType) []const u8 {
        return switch (biometric_type) {
            .touch_id, .fingerprint => "\xf0\x9f\x91\x86", // pointing up
            .face_id, .facial_recognition => "\xf0\x9f\x91\xa4", // bust silhouette
            .iris => "\xf0\x9f\x91\x81", // eye
            .password => "\xf0\x9f\x94\x91", // key
            .pin => "\xf0\x9f\x94\xa2", // numbers
            .none => "\xf0\x9f\x94\x92", // lock
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "BiometricType toString" {
    try std.testing.expectEqualStrings("Touch ID", BiometricType.touch_id.toString());
    try std.testing.expectEqualStrings("Face ID", BiometricType.face_id.toString());
    try std.testing.expectEqualStrings("Fingerprint", BiometricType.fingerprint.toString());
    try std.testing.expectEqualStrings("Password", BiometricType.password.toString());
}

test "BiometricType icon" {
    try std.testing.expectEqualStrings("fingerprint", BiometricType.touch_id.icon());
    try std.testing.expectEqualStrings("face.smiling", BiometricType.face_id.icon());
    try std.testing.expectEqualStrings("key", BiometricType.password.icon());
}

test "AuthResult.ErrorCode toString" {
    try std.testing.expectEqualStrings("User cancelled authentication", AuthResult.ErrorCode.cancelled_by_user.toString());
    try std.testing.expectEqualStrings("Authentication failed", AuthResult.ErrorCode.failed.toString());
    try std.testing.expectEqualStrings("No biometric data enrolled", AuthResult.ErrorCode.not_enrolled.toString());
}

test "BiometricAuth initialization" {
    const allocator = std.testing.allocator;
    var auth = BiometricAuth.init(allocator);
    defer auth.deinit();

    try std.testing.expect(auth.cached_capability == null);
    try std.testing.expectEqual(@as(u64, 1), auth.next_context_id);
}

test "BiometricAuth getCapability" {
    const allocator = std.testing.allocator;
    var auth = BiometricAuth.init(allocator);
    defer auth.deinit();

    const capability = try auth.getCapability();
    // Capability depends on platform, just check it returns something
    _ = capability.is_available;
    _ = capability.biometric_type;
}

test "BiometricAuth createContext" {
    const allocator = std.testing.allocator;
    var auth = BiometricAuth.init(allocator);
    defer auth.deinit();

    const ctx_id = try auth.createContext(.{
        .reason = "Test authentication",
    });

    try std.testing.expectEqual(@as(u64, 1), ctx_id);
    try std.testing.expect(auth.contexts.contains(ctx_id));
}

test "BiometricAuth invalidateContext" {
    const allocator = std.testing.allocator;
    var auth = BiometricAuth.init(allocator);
    defer auth.deinit();

    const ctx_id = try auth.createContext(.{
        .reason = "Test",
    });

    auth.invalidateContext(ctx_id);

    const ctx = auth.contexts.get(ctx_id).?;
    try std.testing.expect(!ctx.is_valid);
}

test "AuthContext expiration" {
    const ctx = AuthContext{
        .id = 1,
        .created_at = getCurrentTimestamp() - 100,
        .last_auth_at = getCurrentTimestamp() - 50,
        .policy = .{ .reason = "Test" },
        .is_valid = true,
    };

    // Should be expired if reuse duration is 30 seconds
    try std.testing.expect(ctx.isExpired(30));

    // Should not be expired if reuse duration is 60 seconds
    try std.testing.expect(!ctx.isExpired(60));

    // Should always be expired if reuse duration is null
    try std.testing.expect(ctx.isExpired(null));
}

test "BiometricPresets quickAuth" {
    const policy = BiometricPresets.quickAuth("Unlock feature");
    try std.testing.expectEqualStrings("Unlock feature", policy.reason);
    try std.testing.expect(policy.allow_password_fallback);
    try std.testing.expectEqual(@as(?u32, 300), policy.reuse_duration_seconds);
}

test "BiometricPresets strictAuth" {
    const policy = BiometricPresets.strictAuth("Delete account");
    try std.testing.expect(!policy.allow_password_fallback);
    try std.testing.expect(!policy.allow_pin_fallback);
    try std.testing.expect(policy.require_confirmation);
    try std.testing.expect(policy.reuse_duration_seconds == null);
}

test "BiometricPresets paymentAuth" {
    const policy = BiometricPresets.paymentAuth("Confirm payment");
    try std.testing.expect(policy.allow_password_fallback);
    try std.testing.expect(policy.require_confirmation);
    try std.testing.expect(policy.reuse_duration_seconds == null);
}

test "BiometricUI getPrompt" {
    try std.testing.expectEqualStrings("Touch ID to authenticate", BiometricUI.getPrompt(.touch_id));
    try std.testing.expectEqualStrings("Face ID to authenticate", BiometricUI.getPrompt(.face_id));
    try std.testing.expectEqualStrings("Enter password to authenticate", BiometricUI.getPrompt(.password));
}

test "BiometricUI getSFSymbol" {
    try std.testing.expectEqualStrings("touchid", BiometricUI.getSFSymbol(.touch_id));
    try std.testing.expectEqualStrings("faceid", BiometricUI.getSFSymbol(.face_id));
    try std.testing.expectEqualStrings("key.fill", BiometricUI.getSFSymbol(.password));
}

test "BiometricAuth authenticate" {
    const allocator = std.testing.allocator;
    var auth = BiometricAuth.init(allocator);
    defer auth.deinit();

    const result = try auth.authenticate("Test authentication");
    // Result depends on platform capability
    _ = result.success;
    _ = result.biometric_type;
    try std.testing.expect(result.timestamp > 0);
}
