//! Permissions Module
//!
//! Provides cross-platform runtime permission handling:
//! - iOS: Privacy permissions (camera, microphone, photos, location, etc.)
//! - Android: Runtime permissions (camera, storage, location, etc.)
//! - macOS: Privacy permissions (camera, microphone, screen recording, etc.)
//!
//! Example usage:
//! ```zig
//! var permissions = PermissionsManager.init(allocator);
//! defer permissions.deinit();
//!
//! // Check permission status
//! const status = try permissions.check(.camera);
//!
//! // Request permission
//! const result = try permissions.request(.camera);
//! if (result == .granted) {
//!     // Use camera
//! }
//!
//! // Request multiple permissions
//! const results = try permissions.requestMultiple(&[_]Permission{
//!     .camera,
//!     .microphone,
//! });
//! ```

const std = @import("std");
const builtin = @import("builtin");

/// Permission errors
pub const PermissionError = error{
    NotSupported,
    NotAvailable,
    InvalidPermission,
    RequestFailed,
    SettingsError,
    Timeout,
    Cancelled,
    OutOfMemory,
};

/// Permission types
pub const Permission = enum {
    // Camera & Media
    camera,
    microphone,
    photos,
    photos_add_only,
    media_library,

    // Location
    location_when_in_use,
    location_always,
    location_background,

    // Notifications
    notifications,

    // Contacts & Calendar
    contacts,
    calendar,
    reminders,

    // Health & Fitness
    health_read,
    health_write,
    motion,
    fitness,

    // Bluetooth & Network
    bluetooth,
    local_network,

    // Other
    speech_recognition,
    siri,
    tracking,
    face_id,
    app_tracking_transparency,

    // Storage (Android)
    storage,
    storage_read,
    storage_write,
    manage_external_storage,

    // Phone (Android)
    phone,
    call_log,
    sms,

    // Background (Android)
    background_location,
    foreground_service,

    // macOS specific
    screen_recording,
    accessibility,
    full_disk_access,
    automation,
    input_monitoring,

    pub fn toString(self: Permission) []const u8 {
        return switch (self) {
            .camera => "Camera",
            .microphone => "Microphone",
            .photos => "Photos",
            .photos_add_only => "Photos (Add Only)",
            .media_library => "Media Library",
            .location_when_in_use => "Location (When In Use)",
            .location_always => "Location (Always)",
            .location_background => "Location (Background)",
            .notifications => "Notifications",
            .contacts => "Contacts",
            .calendar => "Calendar",
            .reminders => "Reminders",
            .health_read => "Health (Read)",
            .health_write => "Health (Write)",
            .motion => "Motion",
            .fitness => "Fitness",
            .bluetooth => "Bluetooth",
            .local_network => "Local Network",
            .speech_recognition => "Speech Recognition",
            .siri => "Siri",
            .tracking => "Tracking",
            .face_id => "Face ID",
            .app_tracking_transparency => "App Tracking Transparency",
            .storage => "Storage",
            .storage_read => "Storage (Read)",
            .storage_write => "Storage (Write)",
            .manage_external_storage => "Manage External Storage",
            .phone => "Phone",
            .call_log => "Call Log",
            .sms => "SMS",
            .background_location => "Background Location",
            .foreground_service => "Foreground Service",
            .screen_recording => "Screen Recording",
            .accessibility => "Accessibility",
            .full_disk_access => "Full Disk Access",
            .automation => "Automation",
            .input_monitoring => "Input Monitoring",
        };
    }

    /// Get iOS permission string
    pub fn toIOSString(self: Permission) ?[]const u8 {
        return switch (self) {
            .camera => "NSCameraUsageDescription",
            .microphone => "NSMicrophoneUsageDescription",
            .photos => "NSPhotoLibraryUsageDescription",
            .photos_add_only => "NSPhotoLibraryAddUsageDescription",
            .location_when_in_use => "NSLocationWhenInUseUsageDescription",
            .location_always => "NSLocationAlwaysUsageDescription",
            .notifications => "UNAuthorizationOptions",
            .contacts => "NSContactsUsageDescription",
            .calendar => "NSCalendarsUsageDescription",
            .reminders => "NSRemindersUsageDescription",
            .health_read => "NSHealthShareUsageDescription",
            .health_write => "NSHealthUpdateUsageDescription",
            .motion => "NSMotionUsageDescription",
            .bluetooth => "NSBluetoothAlwaysUsageDescription",
            .speech_recognition => "NSSpeechRecognitionUsageDescription",
            .siri => "NSSiriUsageDescription",
            .tracking => "NSUserTrackingUsageDescription",
            .face_id => "NSFaceIDUsageDescription",
            .app_tracking_transparency => "NSUserTrackingUsageDescription",
            else => null,
        };
    }

    /// Get Android permission string
    pub fn toAndroidString(self: Permission) ?[]const u8 {
        return switch (self) {
            .camera => "android.permission.CAMERA",
            .microphone => "android.permission.RECORD_AUDIO",
            .photos => "android.permission.READ_MEDIA_IMAGES",
            .location_when_in_use => "android.permission.ACCESS_FINE_LOCATION",
            .location_always => "android.permission.ACCESS_BACKGROUND_LOCATION",
            .contacts => "android.permission.READ_CONTACTS",
            .calendar => "android.permission.READ_CALENDAR",
            .storage => "android.permission.READ_EXTERNAL_STORAGE",
            .storage_read => "android.permission.READ_EXTERNAL_STORAGE",
            .storage_write => "android.permission.WRITE_EXTERNAL_STORAGE",
            .phone => "android.permission.CALL_PHONE",
            .call_log => "android.permission.READ_CALL_LOG",
            .sms => "android.permission.READ_SMS",
            .bluetooth => "android.permission.BLUETOOTH_CONNECT",
            .notifications => "android.permission.POST_NOTIFICATIONS",
            else => null,
        };
    }

    /// Check if permission requires runtime request
    pub fn requiresRuntimeRequest(self: Permission) bool {
        return switch (self) {
            .camera, .microphone, .photos, .photos_add_only, .location_when_in_use, .location_always, .location_background, .contacts, .calendar, .reminders, .health_read, .health_write, .motion, .bluetooth, .speech_recognition, .tracking, .app_tracking_transparency, .storage, .storage_read, .storage_write, .phone, .call_log, .sms, .notifications => true,
            .screen_recording, .accessibility, .full_disk_access, .automation, .input_monitoring => false,
            else => true,
        };
    }

    /// Get permission group (Android)
    pub fn getGroup(self: Permission) PermissionGroup {
        return switch (self) {
            .camera => .camera,
            .microphone => .microphone,
            .photos, .photos_add_only, .media_library, .storage, .storage_read, .storage_write, .manage_external_storage => .storage,
            .location_when_in_use, .location_always, .location_background, .background_location => .location,
            .contacts => .contacts,
            .calendar, .reminders => .calendar,
            .phone, .call_log => .phone,
            .sms => .sms,
            .bluetooth, .local_network => .nearby_devices,
            else => .other,
        };
    }
};

/// Permission groups (Android-style)
pub const PermissionGroup = enum {
    calendar,
    camera,
    contacts,
    location,
    microphone,
    phone,
    sensors,
    sms,
    storage,
    nearby_devices,
    other,

    pub fn toString(self: PermissionGroup) []const u8 {
        return switch (self) {
            .calendar => "Calendar",
            .camera => "Camera",
            .contacts => "Contacts",
            .location => "Location",
            .microphone => "Microphone",
            .phone => "Phone",
            .sensors => "Sensors",
            .sms => "SMS",
            .storage => "Storage",
            .nearby_devices => "Nearby Devices",
            .other => "Other",
        };
    }
};

/// Permission status
pub const PermissionStatus = enum {
    /// Permission has not been requested yet
    not_determined,
    /// Permission is restricted by parental controls or device policy
    restricted,
    /// Permission was denied by user
    denied,
    /// Permission was granted
    granted,
    /// Permission was granted with limitations (iOS 14+)
    limited,
    /// Permission is permanently denied (user selected "Don't ask again")
    permanently_denied,

    pub fn isGranted(self: PermissionStatus) bool {
        return self == .granted or self == .limited;
    }

    pub fn isDenied(self: PermissionStatus) bool {
        return self == .denied or self == .permanently_denied or self == .restricted;
    }

    pub fn canRequest(self: PermissionStatus) bool {
        return self == .not_determined or self == .denied;
    }

    pub fn toString(self: PermissionStatus) []const u8 {
        return switch (self) {
            .not_determined => "Not Determined",
            .restricted => "Restricted",
            .denied => "Denied",
            .granted => "Granted",
            .limited => "Limited",
            .permanently_denied => "Permanently Denied",
        };
    }
};

/// Permission request result
pub const PermissionResult = struct {
    permission: Permission,
    status: PermissionStatus,
    timestamp: i64,

    pub fn isGranted(self: PermissionResult) bool {
        return self.status.isGranted();
    }
};

/// Permission request options
pub const RequestOptions = struct {
    /// Show rationale before requesting (Android)
    show_rationale: bool = false,
    /// Rationale message to show
    rationale_message: ?[]const u8 = null,
    /// Open settings if permanently denied
    open_settings_if_denied: bool = false,
    /// Timeout for the request in milliseconds
    timeout_ms: ?u32 = null,
};

/// Platform permission capabilities
pub const PlatformCapabilities = struct {
    /// Supported permissions on this platform
    supported_permissions: []const Permission,
    /// Whether runtime permissions are required
    requires_runtime_permissions: bool,
    /// Whether app can open settings
    can_open_settings: bool,
    /// Whether "Don't ask again" is supported
    supports_permanent_denial: bool,
    /// OS version
    os_version: []const u8,
    /// Platform name
    platform: Platform,

    pub const Platform = enum {
        ios,
        android,
        macos,
        linux,
        windows,
        unknown,

        pub fn toString(self: Platform) []const u8 {
            return switch (self) {
                .ios => "iOS",
                .android => "Android",
                .macos => "macOS",
                .linux => "Linux",
                .windows => "Windows",
                .unknown => "Unknown",
            };
        }
    };
};

/// Permissions manager
pub const PermissionsManager = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    status_cache: std.AutoHashMapUnmanaged(Permission, PermissionStatus),
    request_history: std.ArrayListUnmanaged(PermissionResult),
    capabilities: PlatformCapabilities,
    delegate: ?*const PermissionDelegate = null,

    pub const PermissionDelegate = struct {
        context: ?*anyopaque = null,
        on_status_changed: ?*const fn (?*anyopaque, Permission, PermissionStatus) void = null,
        on_request_completed: ?*const fn (?*anyopaque, PermissionResult) void = null,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .status_cache = .empty,
            .request_history = .empty,
            .capabilities = getPlatformCapabilities(),
            .delegate = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.status_cache.deinit(self.allocator);
        self.request_history.deinit(self.allocator);
    }

    /// Set delegate for permission events
    pub fn setDelegate(self: *Self, delegate: *const PermissionDelegate) void {
        self.delegate = delegate;
    }

    /// Get platform capabilities
    pub fn getCapabilities(self: *const Self) PlatformCapabilities {
        return self.capabilities;
    }

    /// Check if a permission is supported on this platform
    pub fn isSupported(self: *const Self, permission: Permission) bool {
        for (self.capabilities.supported_permissions) |p| {
            if (p == permission) return true;
        }
        return false;
    }

    /// Check current permission status
    pub fn check(self: *Self, permission: Permission) PermissionError!PermissionStatus {
        if (!self.isSupported(permission)) {
            return PermissionError.NotSupported;
        }

        // Check cache first
        if (self.status_cache.get(permission)) |status| {
            return status;
        }

        // Platform-specific check would go here
        // For now, return not_determined for supported permissions
        const status = PermissionStatus.not_determined;

        // Cache the result
        self.status_cache.put(self.allocator, permission, status) catch return PermissionError.OutOfMemory;

        return status;
    }

    /// Check multiple permissions at once
    pub fn checkMultiple(self: *Self, allocator: std.mem.Allocator, permissions: []const Permission) PermissionError![]PermissionResult {
        var results: std.ArrayListUnmanaged(PermissionResult) = .empty;
        errdefer results.deinit(allocator);

        const now = getCurrentTimestamp();
        for (permissions) |perm| {
            const status = self.check(perm) catch |err| {
                if (err == PermissionError.NotSupported) {
                    results.append(allocator, .{
                        .permission = perm,
                        .status = .restricted,
                        .timestamp = now,
                    }) catch return PermissionError.OutOfMemory;
                    continue;
                }
                return err;
            };
            results.append(allocator, .{
                .permission = perm,
                .status = status,
                .timestamp = now,
            }) catch return PermissionError.OutOfMemory;
        }

        return results.toOwnedSlice(allocator);
    }

    /// Request a single permission
    pub fn request(self: *Self, permission: Permission) PermissionError!PermissionStatus {
        return self.requestWithOptions(permission, .{});
    }

    /// Request a permission with options
    pub fn requestWithOptions(self: *Self, permission: Permission, options: RequestOptions) PermissionError!PermissionStatus {
        _ = options;

        if (!self.isSupported(permission)) {
            return PermissionError.NotSupported;
        }

        // Check current status
        const current_status = try self.check(permission);

        // If already granted, return immediately
        if (current_status.isGranted()) {
            return current_status;
        }

        // If permanently denied and not a runtime permission, can't request
        if (current_status == .permanently_denied and !permission.requiresRuntimeRequest()) {
            return current_status;
        }

        // Platform-specific request would go here
        // For testing/simulation, grant the permission
        const new_status = PermissionStatus.granted;

        // Update cache
        self.status_cache.put(self.allocator, permission, new_status) catch return PermissionError.OutOfMemory;

        // Record in history
        const result = PermissionResult{
            .permission = permission,
            .status = new_status,
            .timestamp = getCurrentTimestamp(),
        };
        self.request_history.append(self.allocator, result) catch return PermissionError.OutOfMemory;

        // Notify delegate
        if (self.delegate) |delegate| {
            if (delegate.on_status_changed) |callback| {
                callback(delegate.context, permission, new_status);
            }
            if (delegate.on_request_completed) |callback| {
                callback(delegate.context, result);
            }
        }

        return new_status;
    }

    /// Request multiple permissions
    pub fn requestMultiple(self: *Self, allocator: std.mem.Allocator, permissions: []const Permission) PermissionError![]PermissionResult {
        return self.requestMultipleWithOptions(allocator, permissions, .{});
    }

    /// Request multiple permissions with options
    pub fn requestMultipleWithOptions(self: *Self, allocator: std.mem.Allocator, permissions: []const Permission, options: RequestOptions) PermissionError![]PermissionResult {
        var results: std.ArrayListUnmanaged(PermissionResult) = .empty;
        errdefer results.deinit(allocator);

        for (permissions) |perm| {
            const status = self.requestWithOptions(perm, options) catch |err| {
                if (err == PermissionError.NotSupported) {
                    results.append(allocator, .{
                        .permission = perm,
                        .status = .restricted,
                        .timestamp = getCurrentTimestamp(),
                    }) catch return PermissionError.OutOfMemory;
                    continue;
                }
                return err;
            };
            results.append(allocator, .{
                .permission = perm,
                .status = status,
                .timestamp = getCurrentTimestamp(),
            }) catch return PermissionError.OutOfMemory;
        }

        return results.toOwnedSlice(allocator);
    }

    /// Open app settings
    pub fn openSettings(self: *Self) PermissionError!void {
        if (!self.capabilities.can_open_settings) {
            return PermissionError.NotSupported;
        }

        // Platform-specific implementation would go here
        // For now, just succeed
    }

    /// Open system settings for a specific permission
    pub fn openSettingsFor(self: *Self, permission: Permission) PermissionError!void {
        if (!self.capabilities.can_open_settings) {
            return PermissionError.NotSupported;
        }

        if (!self.isSupported(permission)) {
            return PermissionError.NotSupported;
        }

        // Platform-specific implementation would go here
    }

    /// Get request history
    pub fn getHistory(self: *const Self) []const PermissionResult {
        return self.request_history.items;
    }

    /// Clear status cache (forces fresh check on next query)
    pub fn clearCache(self: *Self) void {
        self.status_cache.clearRetainingCapacity();
    }

    /// Check if all permissions in a list are granted
    pub fn allGranted(self: *Self, permissions: []const Permission) bool {
        for (permissions) |perm| {
            const status = self.check(perm) catch return false;
            if (!status.isGranted()) return false;
        }
        return true;
    }

    /// Check if any permission in a list is granted
    pub fn anyGranted(self: *Self, permissions: []const Permission) bool {
        for (permissions) |perm| {
            const status = self.check(perm) catch continue;
            if (status.isGranted()) return true;
        }
        return false;
    }

    /// Get permissions that need to be requested
    pub fn getPermissionsNeedingRequest(self: *Self, allocator: std.mem.Allocator, permissions: []const Permission) PermissionError![]Permission {
        var needed: std.ArrayListUnmanaged(Permission) = .empty;
        errdefer needed.deinit(allocator);

        for (permissions) |perm| {
            const status = self.check(perm) catch continue;
            if (status.canRequest()) {
                needed.append(allocator, perm) catch return PermissionError.OutOfMemory;
            }
        }

        return needed.toOwnedSlice(allocator);
    }

    fn getPlatformCapabilities() PlatformCapabilities {
        if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
            return .{
                .supported_permissions = &[_]Permission{
                    .camera,
                    .microphone,
                    .photos,
                    .photos_add_only,
                    .location_when_in_use,
                    .location_always,
                    .contacts,
                    .calendar,
                    .reminders,
                    .notifications,
                    .bluetooth,
                    .speech_recognition,
                    .screen_recording,
                    .accessibility,
                    .full_disk_access,
                    .automation,
                    .input_monitoring,
                },
                .requires_runtime_permissions = true,
                .can_open_settings = true,
                .supports_permanent_denial = false,
                .os_version = "macOS",
                .platform = .macos,
            };
        } else if (comptime builtin.os.tag == .linux) {
            if (comptime builtin.abi == .android) {
                return .{
                    .supported_permissions = &[_]Permission{
                        .camera,
                        .microphone,
                        .photos,
                        .storage,
                        .storage_read,
                        .storage_write,
                        .location_when_in_use,
                        .location_always,
                        .background_location,
                        .contacts,
                        .calendar,
                        .phone,
                        .call_log,
                        .sms,
                        .bluetooth,
                        .notifications,
                    },
                    .requires_runtime_permissions = true,
                    .can_open_settings = true,
                    .supports_permanent_denial = true,
                    .os_version = "Android",
                    .platform = .android,
                };
            }
            return .{
                .supported_permissions = &[_]Permission{},
                .requires_runtime_permissions = false,
                .can_open_settings = false,
                .supports_permanent_denial = false,
                .os_version = "Linux",
                .platform = .linux,
            };
        } else if (comptime builtin.os.tag == .windows) {
            return .{
                .supported_permissions = &[_]Permission{
                    .camera,
                    .microphone,
                    .location_when_in_use,
                    .notifications,
                },
                .requires_runtime_permissions = true,
                .can_open_settings = true,
                .supports_permanent_denial = false,
                .os_version = "Windows",
                .platform = .windows,
            };
        } else {
            return .{
                .supported_permissions = &[_]Permission{},
                .requires_runtime_permissions = false,
                .can_open_settings = false,
                .supports_permanent_denial = false,
                .os_version = "Unknown",
                .platform = .unknown,
            };
        }
    }
};

/// Permission presets for common use cases
pub const PermissionPresets = struct {
    /// Permissions needed for camera functionality
    pub const camera_full = [_]Permission{ .camera, .microphone, .photos };

    /// Permissions needed for photo library access
    pub const photos = [_]Permission{ .photos, .photos_add_only };

    /// Permissions needed for location services
    pub const location_full = [_]Permission{ .location_when_in_use, .location_always };

    /// Permissions needed for communication apps
    pub const communication = [_]Permission{ .microphone, .contacts, .notifications };

    /// Permissions needed for fitness apps
    pub const fitness = [_]Permission{ .motion, .health_read, .health_write, .location_when_in_use };

    /// Permissions needed for social apps
    pub const social = [_]Permission{ .camera, .microphone, .photos, .contacts, .notifications };

    /// Permissions needed for navigation apps
    pub const navigation = [_]Permission{ .location_when_in_use, .location_always, .notifications };

    /// Minimum permissions for basic functionality
    pub const minimal = [_]Permission{.notifications};
};

/// Permission rationale messages
pub const PermissionRationales = struct {
    pub fn getDefault(permission: Permission) []const u8 {
        return switch (permission) {
            .camera => "Camera access is needed to take photos and videos.",
            .microphone => "Microphone access is needed to record audio.",
            .photos => "Photo library access is needed to save and select photos.",
            .location_when_in_use => "Location access is needed to show your current location.",
            .location_always => "Background location access is needed for continuous tracking.",
            .contacts => "Contacts access is needed to find and invite friends.",
            .calendar => "Calendar access is needed to manage your events.",
            .notifications => "Notifications are needed to keep you updated.",
            .bluetooth => "Bluetooth access is needed to connect to nearby devices.",
            .health_read => "Health data access is needed to track your fitness.",
            .health_write => "Health data write access is needed to save your workouts.",
            else => "This permission is needed for app functionality.",
        };
    }
};

/// Helper to check platform support
pub fn isPlatformSupported(permission: Permission) bool {
    const caps = PermissionsManager.getPlatformCapabilities();
    for (caps.supported_permissions) |p| {
        if (p == permission) return true;
    }
    return false;
}

/// Get current timestamp in milliseconds
fn getCurrentTimestamp() i64 {
    const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
    if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
        return @as(i64, @intCast(ts.sec)) * 1000 + @divTrunc(@as(i64, @intCast(ts.nsec)), 1_000_000);
    } else {
        return @as(i64, @intCast(ts.sec)) * 1000 + @divTrunc(@as(i64, @intCast(ts.nsec)), 1_000_000);
    }
}

// ============================================================================
// Tests
// ============================================================================

test "Permission toString" {
    try std.testing.expectEqualStrings("Camera", Permission.camera.toString());
    try std.testing.expectEqualStrings("Microphone", Permission.microphone.toString());
    try std.testing.expectEqualStrings("Photos", Permission.photos.toString());
    try std.testing.expectEqualStrings("Location (When In Use)", Permission.location_when_in_use.toString());
}

test "Permission toIOSString" {
    try std.testing.expectEqualStrings("NSCameraUsageDescription", Permission.camera.toIOSString().?);
    try std.testing.expectEqualStrings("NSMicrophoneUsageDescription", Permission.microphone.toIOSString().?);
    try std.testing.expect(Permission.screen_recording.toIOSString() == null);
}

test "Permission toAndroidString" {
    try std.testing.expectEqualStrings("android.permission.CAMERA", Permission.camera.toAndroidString().?);
    try std.testing.expectEqualStrings("android.permission.RECORD_AUDIO", Permission.microphone.toAndroidString().?);
}

test "Permission requiresRuntimeRequest" {
    try std.testing.expect(Permission.camera.requiresRuntimeRequest());
    try std.testing.expect(Permission.microphone.requiresRuntimeRequest());
    try std.testing.expect(!Permission.screen_recording.requiresRuntimeRequest());
    try std.testing.expect(!Permission.accessibility.requiresRuntimeRequest());
}

test "Permission getGroup" {
    try std.testing.expectEqual(PermissionGroup.camera, Permission.camera.getGroup());
    try std.testing.expectEqual(PermissionGroup.location, Permission.location_when_in_use.getGroup());
    try std.testing.expectEqual(PermissionGroup.storage, Permission.photos.getGroup());
}

test "PermissionGroup toString" {
    try std.testing.expectEqualStrings("Camera", PermissionGroup.camera.toString());
    try std.testing.expectEqualStrings("Location", PermissionGroup.location.toString());
}

test "PermissionStatus isGranted" {
    try std.testing.expect(PermissionStatus.granted.isGranted());
    try std.testing.expect(PermissionStatus.limited.isGranted());
    try std.testing.expect(!PermissionStatus.denied.isGranted());
    try std.testing.expect(!PermissionStatus.not_determined.isGranted());
}

test "PermissionStatus isDenied" {
    try std.testing.expect(PermissionStatus.denied.isDenied());
    try std.testing.expect(PermissionStatus.permanently_denied.isDenied());
    try std.testing.expect(PermissionStatus.restricted.isDenied());
    try std.testing.expect(!PermissionStatus.granted.isDenied());
}

test "PermissionStatus canRequest" {
    try std.testing.expect(PermissionStatus.not_determined.canRequest());
    try std.testing.expect(PermissionStatus.denied.canRequest());
    try std.testing.expect(!PermissionStatus.granted.canRequest());
    try std.testing.expect(!PermissionStatus.permanently_denied.canRequest());
}

test "PermissionStatus toString" {
    try std.testing.expectEqualStrings("Granted", PermissionStatus.granted.toString());
    try std.testing.expectEqualStrings("Denied", PermissionStatus.denied.toString());
    try std.testing.expectEqualStrings("Not Determined", PermissionStatus.not_determined.toString());
}

test "PermissionsManager initialization" {
    var manager = PermissionsManager.init(std.testing.allocator);
    defer manager.deinit();

    const caps = manager.getCapabilities();
    try std.testing.expect(caps.supported_permissions.len > 0);
}

test "PermissionsManager isSupported" {
    var manager = PermissionsManager.init(std.testing.allocator);
    defer manager.deinit();

    // Camera should be supported on macOS
    try std.testing.expect(manager.isSupported(.camera));
    try std.testing.expect(manager.isSupported(.microphone));
}

test "PermissionsManager check" {
    var manager = PermissionsManager.init(std.testing.allocator);
    defer manager.deinit();

    const status = try manager.check(.camera);
    try std.testing.expectEqual(PermissionStatus.not_determined, status);
}

test "PermissionsManager checkMultiple" {
    var manager = PermissionsManager.init(std.testing.allocator);
    defer manager.deinit();

    const permissions = [_]Permission{ .camera, .microphone };
    const results = try manager.checkMultiple(std.testing.allocator, &permissions);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 2), results.len);
}

test "PermissionsManager request" {
    var manager = PermissionsManager.init(std.testing.allocator);
    defer manager.deinit();

    const status = try manager.request(.camera);
    try std.testing.expectEqual(PermissionStatus.granted, status);

    // Should be cached now
    const cached_status = try manager.check(.camera);
    try std.testing.expectEqual(PermissionStatus.granted, cached_status);
}

test "PermissionsManager requestMultiple" {
    var manager = PermissionsManager.init(std.testing.allocator);
    defer manager.deinit();

    const permissions = [_]Permission{ .camera, .microphone };
    const results = try manager.requestMultiple(std.testing.allocator, &permissions);
    defer std.testing.allocator.free(results);

    try std.testing.expectEqual(@as(usize, 2), results.len);
    for (results) |result| {
        try std.testing.expect(result.isGranted());
    }
}

test "PermissionsManager getHistory" {
    var manager = PermissionsManager.init(std.testing.allocator);
    defer manager.deinit();

    _ = try manager.request(.camera);
    _ = try manager.request(.microphone);

    const history = manager.getHistory();
    try std.testing.expectEqual(@as(usize, 2), history.len);
}

test "PermissionsManager clearCache" {
    var manager = PermissionsManager.init(std.testing.allocator);
    defer manager.deinit();

    _ = try manager.check(.camera);
    try std.testing.expect(manager.status_cache.count() > 0);

    manager.clearCache();
    try std.testing.expectEqual(@as(u32, 0), manager.status_cache.count());
}

test "PermissionsManager allGranted" {
    var manager = PermissionsManager.init(std.testing.allocator);
    defer manager.deinit();

    // Initially not granted
    const permissions = [_]Permission{ .camera, .microphone };
    try std.testing.expect(!manager.allGranted(&permissions));

    // Request both
    _ = try manager.request(.camera);
    _ = try manager.request(.microphone);

    try std.testing.expect(manager.allGranted(&permissions));
}

test "PermissionsManager anyGranted" {
    var manager = PermissionsManager.init(std.testing.allocator);
    defer manager.deinit();

    const permissions = [_]Permission{ .camera, .microphone };
    try std.testing.expect(!manager.anyGranted(&permissions));

    _ = try manager.request(.camera);
    try std.testing.expect(manager.anyGranted(&permissions));
}

test "PermissionsManager getPermissionsNeedingRequest" {
    var manager = PermissionsManager.init(std.testing.allocator);
    defer manager.deinit();

    const permissions = [_]Permission{ .camera, .microphone, .photos };
    const needed = try manager.getPermissionsNeedingRequest(std.testing.allocator, &permissions);
    defer std.testing.allocator.free(needed);

    try std.testing.expectEqual(@as(usize, 3), needed.len);

    // Request one
    _ = try manager.request(.camera);

    const needed_after = try manager.getPermissionsNeedingRequest(std.testing.allocator, &permissions);
    defer std.testing.allocator.free(needed_after);

    try std.testing.expectEqual(@as(usize, 2), needed_after.len);
}

test "PermissionsManager openSettings" {
    var manager = PermissionsManager.init(std.testing.allocator);
    defer manager.deinit();

    // Should succeed on macOS
    try manager.openSettings();
}

test "PermissionsManager unsupported permission" {
    var manager = PermissionsManager.init(std.testing.allocator);
    defer manager.deinit();

    // SMS is not supported on macOS
    if (!manager.isSupported(.sms)) {
        try std.testing.expectError(PermissionError.NotSupported, manager.check(.sms));
    }
}

test "PermissionPresets camera_full" {
    try std.testing.expectEqual(@as(usize, 3), PermissionPresets.camera_full.len);
    try std.testing.expectEqual(Permission.camera, PermissionPresets.camera_full[0]);
}

test "PermissionPresets location_full" {
    try std.testing.expectEqual(@as(usize, 2), PermissionPresets.location_full.len);
}

test "PermissionRationales getDefault" {
    const camera_rationale = PermissionRationales.getDefault(.camera);
    try std.testing.expect(camera_rationale.len > 0);

    const location_rationale = PermissionRationales.getDefault(.location_when_in_use);
    try std.testing.expect(location_rationale.len > 0);
}

test "PlatformCapabilities Platform toString" {
    try std.testing.expectEqualStrings("iOS", PlatformCapabilities.Platform.ios.toString());
    try std.testing.expectEqualStrings("Android", PlatformCapabilities.Platform.android.toString());
    try std.testing.expectEqualStrings("macOS", PlatformCapabilities.Platform.macos.toString());
}

test "PermissionResult isGranted" {
    const result = PermissionResult{
        .permission = .camera,
        .status = .granted,
        .timestamp = 0,
    };
    try std.testing.expect(result.isGranted());

    const denied_result = PermissionResult{
        .permission = .camera,
        .status = .denied,
        .timestamp = 0,
    };
    try std.testing.expect(!denied_result.isGranted());
}

test "isPlatformSupported" {
    // Camera should be supported
    try std.testing.expect(isPlatformSupported(.camera));
}
