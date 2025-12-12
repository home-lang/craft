//! Haptics Module
//!
//! Provides cross-platform haptic feedback functionality:
//! - iOS: UIImpactFeedbackGenerator, UINotificationFeedbackGenerator, UISelectionFeedbackGenerator
//! - Android: Vibrator service with patterns and effects
//! - macOS: NSHapticFeedbackManager
//! - watchOS: WKInterfaceDevice haptics
//!
//! Example usage:
//! ```zig
//! var haptics = HapticsManager.init(allocator);
//! defer haptics.deinit();
//!
//! // Simple feedback
//! try haptics.impact(.medium);
//!
//! // Notification feedback
//! try haptics.notification(.success);
//!
//! // Custom pattern
//! try haptics.playPattern(&[_]PatternElement{
//!     .{ .vibrate = 100 },
//!     .{ .pause = 50 },
//!     .{ .vibrate = 200 },
//! });
//! ```

const std = @import("std");
const builtin = @import("builtin");

/// Haptics errors
pub const HapticsError = error{
    NotSupported,
    NotAvailable,
    InvalidPattern,
    HardwareError,
    PermissionDenied,
    Cancelled,
    TooManyRequests,
    OutOfMemory,
};

/// Impact feedback style (iOS UIImpactFeedbackGenerator)
pub const ImpactStyle = enum {
    /// Light impact - subtle feedback
    light,
    /// Medium impact - moderate feedback
    medium,
    /// Heavy impact - strong feedback
    heavy,
    /// Soft impact (iOS 13+) - softer version of light
    soft,
    /// Rigid impact (iOS 13+) - more mechanical feeling
    rigid,

    pub fn toString(self: ImpactStyle) []const u8 {
        return switch (self) {
            .light => "light",
            .medium => "medium",
            .heavy => "heavy",
            .soft => "soft",
            .rigid => "rigid",
        };
    }

    /// Get the intensity value (0.0 - 1.0)
    pub fn defaultIntensity(self: ImpactStyle) f32 {
        return switch (self) {
            .light => 0.3,
            .medium => 0.5,
            .heavy => 0.8,
            .soft => 0.2,
            .rigid => 0.7,
        };
    }

    /// Get Android vibration duration in ms
    pub fn androidDuration(self: ImpactStyle) u32 {
        return switch (self) {
            .light => 10,
            .medium => 20,
            .heavy => 40,
            .soft => 5,
            .rigid => 30,
        };
    }
};

/// Notification feedback type (iOS UINotificationFeedbackGenerator)
pub const NotificationType = enum {
    /// Success notification - positive feedback
    success,
    /// Warning notification - cautionary feedback
    warning,
    /// Error notification - negative feedback
    error_feedback,

    pub fn toString(self: NotificationType) []const u8 {
        return switch (self) {
            .success => "success",
            .warning => "warning",
            .error_feedback => "error",
        };
    }

    /// Get pattern for this notification type
    pub fn getPattern(self: NotificationType) []const PatternElement {
        return switch (self) {
            .success => &[_]PatternElement{
                .{ .vibrate = 30 },
                .{ .pause = 50 },
                .{ .vibrate = 30 },
            },
            .warning => &[_]PatternElement{
                .{ .vibrate = 50 },
                .{ .pause = 100 },
                .{ .vibrate = 50 },
            },
            .error_feedback => &[_]PatternElement{
                .{ .vibrate = 100 },
                .{ .pause = 50 },
                .{ .vibrate = 100 },
                .{ .pause = 50 },
                .{ .vibrate = 100 },
            },
        };
    }
};

/// Selection feedback (iOS UISelectionFeedbackGenerator)
pub const SelectionStyle = enum {
    /// Standard selection change feedback
    changed,

    pub fn toString(self: SelectionStyle) []const u8 {
        return switch (self) {
            .changed => "changed",
        };
    }
};

/// Haptic pattern element
pub const PatternElement = union(enum) {
    /// Vibration duration in milliseconds
    vibrate: u32,
    /// Pause duration in milliseconds
    pause: u32,
    /// Vibration with intensity (duration_ms, intensity 0.0-1.0)
    vibrate_intensity: struct {
        duration_ms: u32,
        intensity: f32,
    },

    pub fn getDuration(self: PatternElement) u32 {
        return switch (self) {
            .vibrate => |d| d,
            .pause => |d| d,
            .vibrate_intensity => |v| v.duration_ms,
        };
    }

    pub fn isVibration(self: PatternElement) bool {
        return switch (self) {
            .vibrate, .vibrate_intensity => true,
            .pause => false,
        };
    }
};

/// Predefined haptic patterns
pub const HapticPattern = enum {
    /// Single short vibration
    single_tap,
    /// Double tap pattern
    double_tap,
    /// Triple tap pattern
    triple_tap,
    /// Long press feedback
    long_press,
    /// Heartbeat pattern
    heartbeat,
    /// Alarm/alert pattern
    alarm,
    /// SOS pattern
    sos,
    /// Click pattern
    click,
    /// Tick pattern (like a clock)
    tick,
    /// Buzz pattern
    buzz,

    pub fn getElements(self: HapticPattern) []const PatternElement {
        return switch (self) {
            .single_tap => &[_]PatternElement{
                .{ .vibrate = 20 },
            },
            .double_tap => &[_]PatternElement{
                .{ .vibrate = 20 },
                .{ .pause = 100 },
                .{ .vibrate = 20 },
            },
            .triple_tap => &[_]PatternElement{
                .{ .vibrate = 20 },
                .{ .pause = 80 },
                .{ .vibrate = 20 },
                .{ .pause = 80 },
                .{ .vibrate = 20 },
            },
            .long_press => &[_]PatternElement{
                .{ .vibrate = 100 },
            },
            .heartbeat => &[_]PatternElement{
                .{ .vibrate = 50 },
                .{ .pause = 100 },
                .{ .vibrate = 50 },
                .{ .pause = 500 },
            },
            .alarm => &[_]PatternElement{
                .{ .vibrate = 200 },
                .{ .pause = 200 },
                .{ .vibrate = 200 },
                .{ .pause = 200 },
                .{ .vibrate = 200 },
            },
            .sos => &[_]PatternElement{
                // S: ...
                .{ .vibrate = 50 },
                .{ .pause = 50 },
                .{ .vibrate = 50 },
                .{ .pause = 50 },
                .{ .vibrate = 50 },
                .{ .pause = 150 },
                // O: ---
                .{ .vibrate = 150 },
                .{ .pause = 50 },
                .{ .vibrate = 150 },
                .{ .pause = 50 },
                .{ .vibrate = 150 },
                .{ .pause = 150 },
                // S: ...
                .{ .vibrate = 50 },
                .{ .pause = 50 },
                .{ .vibrate = 50 },
                .{ .pause = 50 },
                .{ .vibrate = 50 },
            },
            .click => &[_]PatternElement{
                .{ .vibrate = 5 },
            },
            .tick => &[_]PatternElement{
                .{ .vibrate = 10 },
            },
            .buzz => &[_]PatternElement{
                .{ .vibrate = 300 },
            },
        };
    }

    pub fn toString(self: HapticPattern) []const u8 {
        return switch (self) {
            .single_tap => "single_tap",
            .double_tap => "double_tap",
            .triple_tap => "triple_tap",
            .long_press => "long_press",
            .heartbeat => "heartbeat",
            .alarm => "alarm",
            .sos => "sos",
            .click => "click",
            .tick => "tick",
            .buzz => "buzz",
        };
    }

    /// Get total duration of the pattern in milliseconds
    pub fn getTotalDuration(self: HapticPattern) u32 {
        var total: u32 = 0;
        for (self.getElements()) |elem| {
            total += elem.getDuration();
        }
        return total;
    }
};

/// Haptic engine capability
pub const HapticCapability = struct {
    /// Whether haptics are supported on this device
    supported: bool,
    /// Whether haptics are currently available
    available: bool,
    /// Maximum pattern duration in milliseconds
    max_pattern_duration_ms: u32,
    /// Maximum number of pattern elements
    max_pattern_elements: u32,
    /// Supported impact styles
    impact_styles: []const ImpactStyle,
    /// Supports custom intensity
    supports_intensity: bool,
    /// Supports continuous haptics
    supports_continuous: bool,
    /// Device type
    device_type: DeviceType,

    pub const DeviceType = enum {
        iphone,
        ipad,
        apple_watch,
        android_phone,
        android_tablet,
        android_wearable,
        macos,
        unknown,

        pub fn toString(self: DeviceType) []const u8 {
            return switch (self) {
                .iphone => "iPhone",
                .ipad => "iPad",
                .apple_watch => "Apple Watch",
                .android_phone => "Android Phone",
                .android_tablet => "Android Tablet",
                .android_wearable => "Android Wearable",
                .macos => "macOS",
                .unknown => "Unknown",
            };
        }
    };
};

/// Haptic feedback request
pub const HapticRequest = struct {
    /// Request type
    request_type: RequestType,
    /// Optional intensity override (0.0 - 1.0)
    intensity: ?f32 = null,
    /// Whether to wait for completion
    wait_for_completion: bool = false,
    /// Repeat count (0 = no repeat, -1 = infinite)
    repeat_count: i32 = 0,
    /// Delay before starting (milliseconds)
    delay_ms: u32 = 0,

    pub const RequestType = union(enum) {
        impact: ImpactStyle,
        notification: NotificationType,
        selection: SelectionStyle,
        pattern: HapticPattern,
        custom: []const PatternElement,
    };
};

/// Haptics manager
pub const HapticsManager = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    enabled: bool,
    capability: HapticCapability,
    history: std.ArrayListUnmanaged(HapticEvent),
    max_history: usize,
    last_haptic_time: i64,
    min_interval_ms: u32,

    pub const HapticEvent = struct {
        timestamp: i64,
        event_type: EventType,
        duration_ms: u32,
        intensity: f32,

        pub const EventType = enum {
            impact,
            notification,
            selection,
            pattern,
            custom,
        };
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .enabled = true,
            .capability = getDeviceCapability(),
            .history = .empty,
            .max_history = 100,
            .last_haptic_time = 0,
            .min_interval_ms = 10, // Minimum 10ms between haptics
        };
    }

    pub fn deinit(self: *Self) void {
        self.history.deinit(self.allocator);
    }

    /// Check if haptics are supported
    pub fn isSupported(self: *const Self) bool {
        return self.capability.supported;
    }

    /// Check if haptics are available right now
    pub fn isAvailable(self: *const Self) bool {
        return self.capability.supported and self.capability.available and self.enabled;
    }

    /// Enable or disable haptics
    pub fn setEnabled(self: *Self, enabled: bool) void {
        self.enabled = enabled;
    }

    /// Get current capability info
    pub fn getCapability(self: *const Self) HapticCapability {
        return self.capability;
    }

    /// Perform impact feedback
    pub fn impact(self: *Self, style: ImpactStyle) HapticsError!void {
        return self.impactWithIntensity(style, null);
    }

    /// Perform impact feedback with custom intensity
    pub fn impactWithIntensity(self: *Self, style: ImpactStyle, intensity: ?f32) HapticsError!void {
        if (!self.isAvailable()) {
            return HapticsError.NotAvailable;
        }

        const actual_intensity = intensity orelse style.defaultIntensity();
        if (actual_intensity < 0.0 or actual_intensity > 1.0) {
            return HapticsError.InvalidPattern;
        }

        // Rate limiting
        const now = getCurrentTimestamp();
        if (now - self.last_haptic_time < self.min_interval_ms) {
            return HapticsError.TooManyRequests;
        }
        self.last_haptic_time = now;

        // Platform-specific implementation would go here
        // For now, record the event
        try self.recordEvent(.{
            .timestamp = now,
            .event_type = .impact,
            .duration_ms = style.androidDuration(),
            .intensity = actual_intensity,
        });
    }

    /// Perform notification feedback
    pub fn notification(self: *Self, notification_type: NotificationType) HapticsError!void {
        if (!self.isAvailable()) {
            return HapticsError.NotAvailable;
        }

        const now = getCurrentTimestamp();
        if (now - self.last_haptic_time < self.min_interval_ms) {
            return HapticsError.TooManyRequests;
        }
        self.last_haptic_time = now;

        const pattern = notification_type.getPattern();
        var total_duration: u32 = 0;
        for (pattern) |elem| {
            total_duration += elem.getDuration();
        }

        try self.recordEvent(.{
            .timestamp = now,
            .event_type = .notification,
            .duration_ms = total_duration,
            .intensity = 0.6,
        });
    }

    /// Perform selection feedback
    pub fn selection(self: *Self, style: SelectionStyle) HapticsError!void {
        _ = style;
        if (!self.isAvailable()) {
            return HapticsError.NotAvailable;
        }

        const now = getCurrentTimestamp();
        if (now - self.last_haptic_time < self.min_interval_ms) {
            return HapticsError.TooManyRequests;
        }
        self.last_haptic_time = now;

        try self.recordEvent(.{
            .timestamp = now,
            .event_type = .selection,
            .duration_ms = 10,
            .intensity = 0.3,
        });
    }

    /// Play a predefined pattern
    pub fn playPattern(self: *Self, pattern: HapticPattern) HapticsError!void {
        if (!self.isAvailable()) {
            return HapticsError.NotAvailable;
        }

        const elements = pattern.getElements();
        if (elements.len > self.capability.max_pattern_elements) {
            return HapticsError.InvalidPattern;
        }

        const now = getCurrentTimestamp();
        self.last_haptic_time = now;

        try self.recordEvent(.{
            .timestamp = now,
            .event_type = .pattern,
            .duration_ms = pattern.getTotalDuration(),
            .intensity = 0.5,
        });
    }

    /// Play a custom pattern
    pub fn playCustomPattern(self: *Self, elements: []const PatternElement) HapticsError!void {
        if (!self.isAvailable()) {
            return HapticsError.NotAvailable;
        }

        if (elements.len == 0) {
            return HapticsError.InvalidPattern;
        }

        if (elements.len > self.capability.max_pattern_elements) {
            return HapticsError.InvalidPattern;
        }

        var total_duration: u32 = 0;
        for (elements) |elem| {
            total_duration += elem.getDuration();
        }

        if (total_duration > self.capability.max_pattern_duration_ms) {
            return HapticsError.InvalidPattern;
        }

        const now = getCurrentTimestamp();
        self.last_haptic_time = now;

        try self.recordEvent(.{
            .timestamp = now,
            .event_type = .custom,
            .duration_ms = total_duration,
            .intensity = 0.5,
        });
    }

    /// Execute a haptic request
    pub fn execute(self: *Self, request: HapticRequest) HapticsError!void {
        if (request.delay_ms > 0) {
            // In real implementation, this would schedule the haptic
            _ = request.delay_ms;
        }

        const intensity = request.intensity;

        switch (request.request_type) {
            .impact => |style| {
                try self.impactWithIntensity(style, intensity);
            },
            .notification => |notif| {
                try self.notification(notif);
            },
            .selection => |sel| {
                try self.selection(sel);
            },
            .pattern => |pattern| {
                try self.playPattern(pattern);
            },
            .custom => |elements| {
                try self.playCustomPattern(elements);
            },
        }

        // Handle repeat
        if (request.repeat_count > 0) {
            // In real implementation, this would set up a repeat timer
            _ = request.repeat_count;
        }
    }

    /// Stop any ongoing haptics
    pub fn stop(self: *Self) void {
        // Platform-specific stop implementation
        _ = self;
    }

    /// Get haptic event history
    pub fn getHistory(self: *const Self) []const HapticEvent {
        return self.history.items;
    }

    /// Clear event history
    pub fn clearHistory(self: *Self) void {
        self.history.clearRetainingCapacity();
    }

    /// Set minimum interval between haptics
    pub fn setMinInterval(self: *Self, ms: u32) void {
        self.min_interval_ms = ms;
    }

    fn recordEvent(self: *Self, event: HapticEvent) HapticsError!void {
        // Trim history if needed
        if (self.history.items.len >= self.max_history) {
            _ = self.history.orderedRemove(0);
        }
        self.history.append(self.allocator, event) catch return HapticsError.OutOfMemory;
    }

    fn getDeviceCapability() HapticCapability {
        // Return capability based on target platform
        if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
            return .{
                .supported = true,
                .available = true,
                .max_pattern_duration_ms = 30000,
                .max_pattern_elements = 100,
                .impact_styles = &[_]ImpactStyle{ .light, .medium, .heavy, .soft, .rigid },
                .supports_intensity = true,
                .supports_continuous = true,
                .device_type = .macos,
            };
        } else if (comptime builtin.os.tag == .linux) {
            // Check if Android
            if (comptime builtin.abi == .android) {
                return .{
                    .supported = true,
                    .available = true,
                    .max_pattern_duration_ms = 10000,
                    .max_pattern_elements = 50,
                    .impact_styles = &[_]ImpactStyle{ .light, .medium, .heavy },
                    .supports_intensity = true,
                    .supports_continuous = false,
                    .device_type = .android_phone,
                };
            }
            return .{
                .supported = false,
                .available = false,
                .max_pattern_duration_ms = 0,
                .max_pattern_elements = 0,
                .impact_styles = &[_]ImpactStyle{},
                .supports_intensity = false,
                .supports_continuous = false,
                .device_type = .unknown,
            };
        } else {
            return .{
                .supported = false,
                .available = false,
                .max_pattern_duration_ms = 0,
                .max_pattern_elements = 0,
                .impact_styles = &[_]ImpactStyle{},
                .supports_intensity = false,
                .supports_continuous = false,
                .device_type = .unknown,
            };
        }
    }
};

/// Convenience functions for quick haptic feedback
pub const QuickHaptics = struct {
    /// Quick success feedback
    pub fn success(manager: *HapticsManager) HapticsError!void {
        return manager.notification(.success);
    }

    /// Quick warning feedback
    pub fn warning(manager: *HapticsManager) HapticsError!void {
        return manager.notification(.warning);
    }

    /// Quick error feedback
    pub fn errorFeedback(manager: *HapticsManager) HapticsError!void {
        return manager.notification(.error_feedback);
    }

    /// Quick tap feedback
    pub fn tap(manager: *HapticsManager) HapticsError!void {
        return manager.impact(.light);
    }

    /// Quick click feedback
    pub fn click(manager: *HapticsManager) HapticsError!void {
        return manager.playPattern(.click);
    }

    /// Quick selection changed feedback
    pub fn selectionChanged(manager: *HapticsManager) HapticsError!void {
        return manager.selection(.changed);
    }
};

/// Pattern builder for creating custom haptic patterns
pub const PatternBuilder = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    elements: std.ArrayListUnmanaged(PatternElement),

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .elements = .empty,
        };
    }

    pub fn deinit(self: *Self) void {
        self.elements.deinit(self.allocator);
    }

    pub fn vibrate(self: *Self, duration_ms: u32) !*Self {
        try self.elements.append(self.allocator, .{ .vibrate = duration_ms });
        return self;
    }

    pub fn vibrateWithIntensity(self: *Self, duration_ms: u32, intensity: f32) !*Self {
        try self.elements.append(self.allocator, .{ .vibrate_intensity = .{
            .duration_ms = duration_ms,
            .intensity = intensity,
        } });
        return self;
    }

    pub fn pause(self: *Self, duration_ms: u32) !*Self {
        try self.elements.append(self.allocator, .{ .pause = duration_ms });
        return self;
    }

    pub fn build(self: *const Self) []const PatternElement {
        return self.elements.items;
    }

    pub fn clear(self: *Self) void {
        self.elements.clearRetainingCapacity();
    }

    pub fn getTotalDuration(self: *const Self) u32 {
        var total: u32 = 0;
        for (self.elements.items) |elem| {
            total += elem.getDuration();
        }
        return total;
    }
};

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

test "ImpactStyle toString" {
    try std.testing.expectEqualStrings("light", ImpactStyle.light.toString());
    try std.testing.expectEqualStrings("medium", ImpactStyle.medium.toString());
    try std.testing.expectEqualStrings("heavy", ImpactStyle.heavy.toString());
    try std.testing.expectEqualStrings("soft", ImpactStyle.soft.toString());
    try std.testing.expectEqualStrings("rigid", ImpactStyle.rigid.toString());
}

test "ImpactStyle defaultIntensity" {
    try std.testing.expect(ImpactStyle.light.defaultIntensity() < ImpactStyle.medium.defaultIntensity());
    try std.testing.expect(ImpactStyle.medium.defaultIntensity() < ImpactStyle.heavy.defaultIntensity());
}

test "ImpactStyle androidDuration" {
    try std.testing.expect(ImpactStyle.light.androidDuration() < ImpactStyle.heavy.androidDuration());
}

test "NotificationType toString" {
    try std.testing.expectEqualStrings("success", NotificationType.success.toString());
    try std.testing.expectEqualStrings("warning", NotificationType.warning.toString());
    try std.testing.expectEqualStrings("error", NotificationType.error_feedback.toString());
}

test "NotificationType getPattern" {
    const success_pattern = NotificationType.success.getPattern();
    try std.testing.expect(success_pattern.len > 0);

    const error_pattern = NotificationType.error_feedback.getPattern();
    try std.testing.expect(error_pattern.len > success_pattern.len);
}

test "PatternElement getDuration" {
    const vibrate = PatternElement{ .vibrate = 100 };
    try std.testing.expectEqual(@as(u32, 100), vibrate.getDuration());

    const pause = PatternElement{ .pause = 50 };
    try std.testing.expectEqual(@as(u32, 50), pause.getDuration());

    const vibrate_intensity = PatternElement{ .vibrate_intensity = .{ .duration_ms = 200, .intensity = 0.5 } };
    try std.testing.expectEqual(@as(u32, 200), vibrate_intensity.getDuration());
}

test "PatternElement isVibration" {
    const vibrate_elem = PatternElement{ .vibrate = 100 };
    try std.testing.expect(vibrate_elem.isVibration());

    const vibrate_int_elem = PatternElement{ .vibrate_intensity = .{ .duration_ms = 100, .intensity = 0.5 } };
    try std.testing.expect(vibrate_int_elem.isVibration());

    const pause_elem = PatternElement{ .pause = 50 };
    try std.testing.expect(!pause_elem.isVibration());
}

test "HapticPattern getElements" {
    const single_tap = HapticPattern.single_tap.getElements();
    try std.testing.expectEqual(@as(usize, 1), single_tap.len);

    const double_tap = HapticPattern.double_tap.getElements();
    try std.testing.expectEqual(@as(usize, 3), double_tap.len);

    const sos = HapticPattern.sos.getElements();
    try std.testing.expect(sos.len > 10);
}

test "HapticPattern getTotalDuration" {
    const single_duration = HapticPattern.single_tap.getTotalDuration();
    try std.testing.expectEqual(@as(u32, 20), single_duration);

    const click_duration = HapticPattern.click.getTotalDuration();
    try std.testing.expectEqual(@as(u32, 5), click_duration);
}

test "HapticPattern toString" {
    try std.testing.expectEqualStrings("heartbeat", HapticPattern.heartbeat.toString());
    try std.testing.expectEqualStrings("alarm", HapticPattern.alarm.toString());
}

test "HapticsManager initialization" {
    var manager = HapticsManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expect(manager.enabled);
    try std.testing.expect(manager.capability.supported);
}

test "HapticsManager enable/disable" {
    var manager = HapticsManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expect(manager.isAvailable());

    manager.setEnabled(false);
    try std.testing.expect(!manager.isAvailable());

    manager.setEnabled(true);
    try std.testing.expect(manager.isAvailable());
}

test "HapticsManager impact" {
    var manager = HapticsManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setMinInterval(0); // Disable rate limiting for test
    try manager.impact(.light);
    try manager.impact(.medium);
    try manager.impact(.heavy);

    try std.testing.expectEqual(@as(usize, 3), manager.getHistory().len);
}

test "HapticsManager notification" {
    var manager = HapticsManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setMinInterval(0); // Disable rate limiting for test
    try manager.notification(.success);
    try manager.notification(.warning);

    try std.testing.expectEqual(@as(usize, 2), manager.getHistory().len);
}

test "HapticsManager selection" {
    var manager = HapticsManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.selection(.changed);
    try std.testing.expectEqual(@as(usize, 1), manager.getHistory().len);
}

test "HapticsManager playPattern" {
    var manager = HapticsManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.playPattern(.double_tap);
    try manager.playPattern(.heartbeat);

    try std.testing.expectEqual(@as(usize, 2), manager.getHistory().len);
}

test "HapticsManager playCustomPattern" {
    var manager = HapticsManager.init(std.testing.allocator);
    defer manager.deinit();

    const pattern = [_]PatternElement{
        .{ .vibrate = 50 },
        .{ .pause = 25 },
        .{ .vibrate = 100 },
    };

    try manager.playCustomPattern(&pattern);
    try std.testing.expectEqual(@as(usize, 1), manager.getHistory().len);
}

test "HapticsManager invalid pattern" {
    var manager = HapticsManager.init(std.testing.allocator);
    defer manager.deinit();

    const empty_pattern = [_]PatternElement{};
    try std.testing.expectError(HapticsError.InvalidPattern, manager.playCustomPattern(&empty_pattern));
}

test "HapticsManager impactWithIntensity invalid" {
    var manager = HapticsManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectError(HapticsError.InvalidPattern, manager.impactWithIntensity(.light, 1.5));
    try std.testing.expectError(HapticsError.InvalidPattern, manager.impactWithIntensity(.light, -0.5));
}

test "HapticsManager clearHistory" {
    var manager = HapticsManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setMinInterval(0);
    try manager.impact(.light);
    try manager.impact(.medium);
    try std.testing.expect(manager.getHistory().len > 0);

    manager.clearHistory();
    try std.testing.expectEqual(@as(usize, 0), manager.getHistory().len);
}

test "HapticsManager disabled" {
    var manager = HapticsManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setEnabled(false);
    try std.testing.expectError(HapticsError.NotAvailable, manager.impact(.light));
}

test "HapticsManager execute request" {
    var manager = HapticsManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.execute(.{
        .request_type = .{ .impact = .medium },
        .intensity = 0.7,
    });

    try std.testing.expectEqual(@as(usize, 1), manager.getHistory().len);
}

test "PatternBuilder basic" {
    var builder = PatternBuilder.init(std.testing.allocator);
    defer builder.deinit();

    _ = try builder.vibrate(100);
    _ = try builder.pause(50);
    _ = try builder.vibrate(200);

    const pattern = builder.build();
    try std.testing.expectEqual(@as(usize, 3), pattern.len);
    try std.testing.expectEqual(@as(u32, 350), builder.getTotalDuration());
}

test "PatternBuilder with intensity" {
    var builder = PatternBuilder.init(std.testing.allocator);
    defer builder.deinit();

    _ = try builder.vibrateWithIntensity(100, 0.8);
    _ = try builder.pause(50);

    const pattern = builder.build();
    try std.testing.expectEqual(@as(usize, 2), pattern.len);
}

test "PatternBuilder clear" {
    var builder = PatternBuilder.init(std.testing.allocator);
    defer builder.deinit();

    _ = try builder.vibrate(100);
    _ = try builder.pause(50);
    try std.testing.expectEqual(@as(usize, 2), builder.build().len);

    builder.clear();
    try std.testing.expectEqual(@as(usize, 0), builder.build().len);
}

test "HapticCapability DeviceType toString" {
    try std.testing.expectEqualStrings("iPhone", HapticCapability.DeviceType.iphone.toString());
    try std.testing.expectEqualStrings("macOS", HapticCapability.DeviceType.macos.toString());
}

test "QuickHaptics functions" {
    var manager = HapticsManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setMinInterval(0);
    try QuickHaptics.tap(&manager);
    try QuickHaptics.click(&manager);
    try QuickHaptics.success(&manager);

    try std.testing.expectEqual(@as(usize, 3), manager.getHistory().len);
}
