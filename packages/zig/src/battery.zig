//! Cross-platform battery and power management module for Craft
//! Provides battery status, charging state, and power source information
//! for iOS, Android, macOS, Windows, and Linux.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Battery charging state
pub const ChargingState = enum {
    unknown,
    unplugged,
    charging,
    full,
    not_charging, // plugged in but not charging (battery full or temp issue)

    pub fn toString(self: ChargingState) []const u8 {
        return switch (self) {
            .unknown => "Unknown",
            .unplugged => "Unplugged",
            .charging => "Charging",
            .full => "Full",
            .not_charging => "Not Charging",
        };
    }

    pub fn isPluggedIn(self: ChargingState) bool {
        return switch (self) {
            .charging, .full, .not_charging => true,
            .unknown, .unplugged => false,
        };
    }

    pub fn icon(self: ChargingState) []const u8 {
        return switch (self) {
            .unknown => "?",
            .unplugged => "",
            .charging => "⚡",
            .full => "✓",
            .not_charging => "⏸",
        };
    }
};

/// Battery health status
pub const BatteryHealth = enum {
    unknown,
    good,
    overheat,
    dead,
    over_voltage,
    cold,
    unspecified_failure,

    pub fn toString(self: BatteryHealth) []const u8 {
        return switch (self) {
            .unknown => "Unknown",
            .good => "Good",
            .overheat => "Overheat",
            .dead => "Dead",
            .over_voltage => "Over Voltage",
            .cold => "Cold",
            .unspecified_failure => "Failure",
        };
    }

    pub fn isHealthy(self: BatteryHealth) bool {
        return self == .good;
    }

    pub fn requiresAttention(self: BatteryHealth) bool {
        return switch (self) {
            .overheat, .dead, .over_voltage, .cold, .unspecified_failure => true,
            .unknown, .good => false,
        };
    }
};

/// Power source type
pub const PowerSource = enum {
    unknown,
    battery,
    ac, // AC adapter / wall power
    usb, // USB power
    wireless, // Wireless charging
    dock, // Docking station

    pub fn toString(self: PowerSource) []const u8 {
        return switch (self) {
            .unknown => "Unknown",
            .battery => "Battery",
            .ac => "AC Power",
            .usb => "USB",
            .wireless => "Wireless",
            .dock => "Dock",
        };
    }

    pub fn icon(self: PowerSource) []const u8 {
        return switch (self) {
            .unknown => "?",
            .battery => "🔋",
            .ac => "🔌",
            .usb => "🔌",
            .wireless => "📶",
            .dock => "⚓",
        };
    }
};

/// Low power mode status
pub const LowPowerMode = enum {
    unknown,
    disabled,
    enabled,

    pub fn isEnabled(self: LowPowerMode) bool {
        return self == .enabled;
    }

    pub fn toString(self: LowPowerMode) []const u8 {
        return switch (self) {
            .unknown => "Unknown",
            .disabled => "Off",
            .enabled => "On",
        };
    }
};

/// Thermal state of the device
pub const ThermalState = enum {
    nominal, // Normal operating conditions
    fair, // Slightly elevated temperature
    serious, // High temperature, performance may be reduced
    critical, // Critical temperature, immediate action needed

    pub fn toString(self: ThermalState) []const u8 {
        return switch (self) {
            .nominal => "Normal",
            .fair => "Warm",
            .serious => "Hot",
            .critical => "Critical",
        };
    }

    pub fn shouldReduceActivity(self: ThermalState) bool {
        return switch (self) {
            .serious, .critical => true,
            .nominal, .fair => false,
        };
    }

    pub fn severityLevel(self: ThermalState) u8 {
        return switch (self) {
            .nominal => 0,
            .fair => 1,
            .serious => 2,
            .critical => 3,
        };
    }
};

/// Battery level thresholds for UI display
pub const BatteryLevel = enum {
    critical, // 0-10%
    low, // 10-20%
    medium, // 20-50%
    high, // 50-80%
    full, // 80-100%

    pub fn fromPercentage(percentage: u8) BatteryLevel {
        if (percentage <= 10) return .critical;
        if (percentage <= 20) return .low;
        if (percentage <= 50) return .medium;
        if (percentage <= 80) return .high;
        return .full;
    }

    pub fn icon(self: BatteryLevel) []const u8 {
        return switch (self) {
            .critical => "🪫",
            .low => "🔋",
            .medium => "🔋",
            .high => "🔋",
            .full => "🔋",
        };
    }

    pub fn color(self: BatteryLevel) []const u8 {
        return switch (self) {
            .critical => "#FF0000", // Red
            .low => "#FF8C00", // Orange
            .medium => "#FFD700", // Yellow
            .high => "#90EE90", // Light green
            .full => "#00FF00", // Green
        };
    }

    pub fn shouldNotify(self: BatteryLevel) bool {
        return switch (self) {
            .critical, .low => true,
            .medium, .high, .full => false,
        };
    }
};

/// Complete battery status snapshot
pub const BatteryStatus = struct {
    /// Battery level as percentage (0-100)
    level: u8,
    /// Current charging state
    charging_state: ChargingState,
    /// Battery health status
    health: BatteryHealth,
    /// Current power source
    power_source: PowerSource,
    /// Whether low power mode is enabled
    low_power_mode: LowPowerMode,
    /// Device thermal state
    thermal_state: ThermalState,
    /// Whether battery is present (for removable batteries)
    is_present: bool,
    /// Estimated time remaining in seconds (null if unknown or charging)
    time_remaining: ?i64,
    /// Estimated time to full charge in seconds (null if unknown or not charging)
    time_to_full: ?i64,
    /// Current battery capacity in mAh (null if unknown)
    current_capacity: ?u32,
    /// Maximum battery capacity in mAh (null if unknown)
    max_capacity: ?u32,
    /// Design capacity in mAh (original capacity)
    design_capacity: ?u32,
    /// Battery cycle count (null if unknown)
    cycle_count: ?u32,
    /// Battery voltage in millivolts (null if unknown)
    voltage: ?u32,
    /// Battery temperature in celsius (null if unknown)
    temperature: ?f32,
    /// Timestamp when this status was captured
    timestamp: i64,

    const Self = @This();

    pub fn init() Self {
        return .{
            .level = 0,
            .charging_state = .unknown,
            .health = .unknown,
            .power_source = .unknown,
            .low_power_mode = .unknown,
            .thermal_state = .nominal,
            .is_present = false,
            .time_remaining = null,
            .time_to_full = null,
            .current_capacity = null,
            .max_capacity = null,
            .design_capacity = null,
            .cycle_count = null,
            .voltage = null,
            .temperature = null,
            .timestamp = 0,
        };
    }

    /// Get battery level category
    pub fn getBatteryLevel(self: Self) BatteryLevel {
        return BatteryLevel.fromPercentage(self.level);
    }

    /// Check if battery is charging
    pub fn isCharging(self: Self) bool {
        return self.charging_state == .charging;
    }

    /// Check if device is plugged in
    pub fn isPluggedIn(self: Self) bool {
        return self.charging_state.isPluggedIn();
    }

    /// Check if battery is critically low
    pub fn isCritical(self: Self) bool {
        return self.level <= 10 and !self.isPluggedIn();
    }

    /// Check if battery needs attention
    pub fn needsAttention(self: Self) bool {
        return self.health.requiresAttention() or
            self.thermal_state.shouldReduceActivity() or
            self.isCritical();
    }

    /// Get battery health percentage (current vs design capacity)
    pub fn getHealthPercentage(self: Self) ?u8 {
        if (self.max_capacity) |max| {
            if (self.design_capacity) |design| {
                if (design > 0) {
                    const ratio = @as(u64, max) * 100 / @as(u64, design);
                    return @intCast(@min(ratio, 100));
                }
            }
        }
        return null;
    }

    /// Format time remaining as human readable string
    pub fn formatTimeRemaining(self: Self, buffer: []u8) []const u8 {
        if (self.time_remaining) |seconds| {
            return formatDuration(seconds, buffer);
        }
        return "Unknown";
    }

    /// Format time to full charge as human readable string
    pub fn formatTimeToFull(self: Self, buffer: []u8) []const u8 {
        if (self.time_to_full) |seconds| {
            return formatDuration(seconds, buffer);
        }
        return "Unknown";
    }

    /// Get a summary string for display
    pub fn getSummary(self: Self, buffer: []u8) []const u8 {
        const charging_icon = self.charging_state.icon();
        const level_str = std.fmt.bufPrint(buffer, "{d}%{s}", .{ self.level, charging_icon }) catch return "Error";
        return level_str;
    }
};

/// Format duration in seconds to human readable format
pub fn formatDuration(seconds: i64, buffer: []u8) []const u8 {
    if (seconds < 0) return "Unknown";

    const s: u64 = @intCast(seconds);
    const hours = s / 3600;
    const minutes = (s % 3600) / 60;

    if (hours > 0) {
        return std.fmt.bufPrint(buffer, "{d}h {d}m", .{ hours, minutes }) catch "Error";
    } else {
        return std.fmt.bufPrint(buffer, "{d}m", .{minutes}) catch "Error";
    }
}

/// Battery event types for monitoring
pub const BatteryEventType = enum {
    level_changed,
    charging_state_changed,
    power_source_changed,
    low_power_mode_changed,
    thermal_state_changed,
    health_changed,
    battery_low,
    battery_critical,
    battery_okay,
    charging_started,
    charging_stopped,
    fully_charged,
};

/// Battery event with details
pub const BatteryEvent = struct {
    event_type: BatteryEventType,
    old_value: ?i32,
    new_value: ?i32,
    status: BatteryStatus,
    timestamp: i64,

    const Self = @This();

    pub fn create(event_type: BatteryEventType, status: BatteryStatus) Self {
        return .{
            .event_type = event_type,
            .old_value = null,
            .new_value = null,
            .status = status,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn withValues(event_type: BatteryEventType, old: i32, new: i32, status: BatteryStatus) Self {
        return .{
            .event_type = event_type,
            .old_value = old,
            .new_value = new,
            .status = status,
            .timestamp = getCurrentTimestamp(),
        };
    }
};

/// Callback type for battery events
pub const BatteryCallback = *const fn (event: BatteryEvent) void;

/// Battery monitor configuration
pub const BatteryMonitorConfig = struct {
    /// Interval between status checks in milliseconds
    poll_interval_ms: u32 = 30000, // 30 seconds
    /// Enable level change notifications
    notify_level_changes: bool = true,
    /// Level change threshold for notifications (percentage points)
    level_change_threshold: u8 = 5,
    /// Enable charging state change notifications
    notify_charging_changes: bool = true,
    /// Enable thermal state change notifications
    notify_thermal_changes: bool = true,
    /// Enable low battery warnings
    low_battery_threshold: u8 = 20,
    /// Enable critical battery warnings
    critical_battery_threshold: u8 = 10,
};

/// Battery monitor for tracking battery status changes
pub const BatteryMonitor = struct {
    allocator: Allocator,
    config: BatteryMonitorConfig,
    last_status: BatteryStatus,
    callbacks: std.ArrayListUnmanaged(BatteryCallback),
    is_monitoring: bool,
    last_notified_level: u8,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .config = .{},
            .last_status = BatteryStatus.init(),
            .callbacks = .{},
            .is_monitoring = false,
            .last_notified_level = 100,
        };
    }

    pub fn initWithConfig(allocator: Allocator, config: BatteryMonitorConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .last_status = BatteryStatus.init(),
            .callbacks = .{},
            .is_monitoring = false,
            .last_notified_level = 100,
        };
    }

    pub fn deinit(self: *Self) void {
        self.callbacks.deinit(self.allocator);
    }

    /// Add a callback for battery events
    pub fn addCallback(self: *Self, callback: BatteryCallback) !void {
        try self.callbacks.append(self.allocator, callback);
    }

    /// Remove a callback
    pub fn removeCallback(self: *Self, callback: BatteryCallback) bool {
        for (self.callbacks.items, 0..) |cb, i| {
            if (cb == callback) {
                _ = self.callbacks.orderedRemove(i);
                return true;
            }
        }
        return false;
    }

    /// Start monitoring battery status
    pub fn startMonitoring(self: *Self) void {
        self.is_monitoring = true;
        // In real implementation, this would start a timer or use platform APIs
    }

    /// Stop monitoring battery status
    pub fn stopMonitoring(self: *Self) void {
        self.is_monitoring = false;
    }

    /// Process a new battery status (called by platform-specific code)
    pub fn processStatus(self: *Self, new_status: BatteryStatus) void {
        const old_status = self.last_status;

        // Check for level changes
        if (self.config.notify_level_changes) {
            const level_diff = if (new_status.level > old_status.level)
                new_status.level - old_status.level
            else
                old_status.level - new_status.level;

            if (level_diff >= self.config.level_change_threshold) {
                self.notifyCallbacks(BatteryEvent.withValues(
                    .level_changed,
                    @intCast(old_status.level),
                    @intCast(new_status.level),
                    new_status,
                ));
            }
        }

        // Check for charging state changes
        if (self.config.notify_charging_changes and
            old_status.charging_state != new_status.charging_state)
        {
            const event_type: BatteryEventType = switch (new_status.charging_state) {
                .charging => .charging_started,
                .full => .fully_charged,
                .unplugged, .not_charging => .charging_stopped,
                .unknown => .charging_state_changed,
            };
            self.notifyCallbacks(BatteryEvent.create(event_type, new_status));
        }

        // Check for thermal state changes
        if (self.config.notify_thermal_changes and
            old_status.thermal_state != new_status.thermal_state)
        {
            self.notifyCallbacks(BatteryEvent.create(.thermal_state_changed, new_status));
        }

        // Check for low battery
        if (new_status.level <= self.config.critical_battery_threshold and
            self.last_notified_level > self.config.critical_battery_threshold and
            !new_status.isPluggedIn())
        {
            self.notifyCallbacks(BatteryEvent.create(.battery_critical, new_status));
            self.last_notified_level = new_status.level;
        } else if (new_status.level <= self.config.low_battery_threshold and
            self.last_notified_level > self.config.low_battery_threshold and
            !new_status.isPluggedIn())
        {
            self.notifyCallbacks(BatteryEvent.create(.battery_low, new_status));
            self.last_notified_level = new_status.level;
        } else if (new_status.level > self.config.low_battery_threshold and
            self.last_notified_level <= self.config.low_battery_threshold)
        {
            self.notifyCallbacks(BatteryEvent.create(.battery_okay, new_status));
            self.last_notified_level = new_status.level;
        }

        self.last_status = new_status;
    }

    fn notifyCallbacks(self: *Self, event: BatteryEvent) void {
        for (self.callbacks.items) |callback| {
            callback(event);
        }
    }

    /// Get the current battery status
    pub fn getCurrentStatus(self: Self) BatteryStatus {
        return self.last_status;
    }

    /// Check if monitoring is active
    pub fn isActive(self: Self) bool {
        return self.is_monitoring;
    }
};

/// Power management hints for the application
pub const PowerHint = enum {
    none,
    reduce_network, // Reduce network activity
    reduce_location, // Reduce location updates
    reduce_processing, // Reduce background processing
    reduce_animations, // Reduce UI animations
    defer_work, // Defer non-essential work
    aggressive_saving, // Maximum power saving

    pub fn toString(self: PowerHint) []const u8 {
        return switch (self) {
            .none => "None",
            .reduce_network => "Reduce Network",
            .reduce_location => "Reduce Location",
            .reduce_processing => "Reduce Processing",
            .reduce_animations => "Reduce Animations",
            .defer_work => "Defer Work",
            .aggressive_saving => "Aggressive Saving",
        };
    }
};

/// Get power saving hints based on battery status
pub fn getPowerHints(status: BatteryStatus, buffer: []PowerHint) []PowerHint {
    var count: usize = 0;

    // Check if we need power saving
    if (status.isPluggedIn() and status.thermal_state == .nominal) {
        return buffer[0..0];
    }

    // Add hints based on battery level
    const level = status.getBatteryLevel();

    switch (level) {
        .critical => {
            if (count < buffer.len) {
                buffer[count] = .aggressive_saving;
                count += 1;
            }
        },
        .low => {
            if (count < buffer.len) {
                buffer[count] = .reduce_network;
                count += 1;
            }
            if (count < buffer.len) {
                buffer[count] = .reduce_location;
                count += 1;
            }
            if (count < buffer.len) {
                buffer[count] = .defer_work;
                count += 1;
            }
        },
        .medium => {
            if (count < buffer.len) {
                buffer[count] = .reduce_location;
                count += 1;
            }
        },
        else => {},
    }

    // Add hints based on thermal state
    if (status.thermal_state.shouldReduceActivity()) {
        if (count < buffer.len) {
            buffer[count] = .reduce_processing;
            count += 1;
        }
        if (count < buffer.len) {
            buffer[count] = .reduce_animations;
            count += 1;
        }
    }

    // Add hints for low power mode
    if (status.low_power_mode.isEnabled()) {
        if (count < buffer.len) {
            buffer[count] = .reduce_animations;
            count += 1;
        }
    }

    return buffer[0..count];
}

/// Simulated battery for testing
pub const SimulatedBattery = struct {
    status: BatteryStatus,

    const Self = @This();

    pub fn init() Self {
        return .{
            .status = .{
                .level = 75,
                .charging_state = .unplugged,
                .health = .good,
                .power_source = .battery,
                .low_power_mode = .disabled,
                .thermal_state = .nominal,
                .is_present = true,
                .time_remaining = 3600 * 4, // 4 hours
                .time_to_full = null,
                .current_capacity = 3000,
                .max_capacity = 4000,
                .design_capacity = 4500,
                .cycle_count = 150,
                .voltage = 3850,
                .temperature = 25.5,
                .timestamp = getCurrentTimestamp(),
            },
        };
    }

    pub fn setLevel(self: *Self, level: u8) void {
        self.status.level = @min(level, 100);
        self.updateTimeEstimates();
    }

    pub fn setChargingState(self: *Self, state: ChargingState) void {
        self.status.charging_state = state;
        self.status.power_source = if (state.isPluggedIn()) .ac else .battery;
        self.updateTimeEstimates();
    }

    pub fn setThermalState(self: *Self, state: ThermalState) void {
        self.status.thermal_state = state;
    }

    pub fn setLowPowerMode(self: *Self, enabled: bool) void {
        self.status.low_power_mode = if (enabled) .enabled else .disabled;
    }

    fn updateTimeEstimates(self: *Self) void {
        if (self.status.charging_state == .charging) {
            // Estimate time to full
            const remaining = 100 - self.status.level;
            self.status.time_to_full = @as(i64, remaining) * 60; // 1 minute per percent
            self.status.time_remaining = null;
        } else {
            // Estimate time remaining
            self.status.time_remaining = @as(i64, self.status.level) * 180; // 3 minutes per percent
            self.status.time_to_full = null;
        }
        self.status.timestamp = getCurrentTimestamp();
    }

    pub fn getStatus(self: Self) BatteryStatus {
        return self.status;
    }

    /// Simulate battery drain
    pub fn drain(self: *Self, percent: u8) void {
        if (self.status.level > percent) {
            self.status.level -= percent;
        } else {
            self.status.level = 0;
        }
        self.updateTimeEstimates();
    }

    /// Simulate charging
    pub fn charge(self: *Self, percent: u8) void {
        if (self.status.level + percent > 100) {
            self.status.level = 100;
            self.status.charging_state = .full;
        } else {
            self.status.level += percent;
        }
        self.updateTimeEstimates();
    }
};

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

test "ChargingState toString" {
    try std.testing.expectEqualStrings("Charging", ChargingState.charging.toString());
    try std.testing.expectEqualStrings("Full", ChargingState.full.toString());
    try std.testing.expectEqualStrings("Unplugged", ChargingState.unplugged.toString());
}

test "ChargingState isPluggedIn" {
    try std.testing.expect(ChargingState.charging.isPluggedIn());
    try std.testing.expect(ChargingState.full.isPluggedIn());
    try std.testing.expect(ChargingState.not_charging.isPluggedIn());
    try std.testing.expect(!ChargingState.unplugged.isPluggedIn());
    try std.testing.expect(!ChargingState.unknown.isPluggedIn());
}

test "BatteryHealth states" {
    try std.testing.expect(BatteryHealth.good.isHealthy());
    try std.testing.expect(!BatteryHealth.overheat.isHealthy());
    try std.testing.expect(BatteryHealth.overheat.requiresAttention());
    try std.testing.expect(BatteryHealth.dead.requiresAttention());
    try std.testing.expect(!BatteryHealth.good.requiresAttention());
}

test "PowerSource icon" {
    try std.testing.expectEqualStrings("🔋", PowerSource.battery.icon());
    try std.testing.expectEqualStrings("🔌", PowerSource.ac.icon());
    try std.testing.expectEqualStrings("📶", PowerSource.wireless.icon());
}

test "ThermalState severity" {
    try std.testing.expectEqual(@as(u8, 0), ThermalState.nominal.severityLevel());
    try std.testing.expectEqual(@as(u8, 3), ThermalState.critical.severityLevel());
    try std.testing.expect(!ThermalState.nominal.shouldReduceActivity());
    try std.testing.expect(ThermalState.serious.shouldReduceActivity());
    try std.testing.expect(ThermalState.critical.shouldReduceActivity());
}

test "BatteryLevel fromPercentage" {
    try std.testing.expectEqual(BatteryLevel.critical, BatteryLevel.fromPercentage(5));
    try std.testing.expectEqual(BatteryLevel.critical, BatteryLevel.fromPercentage(10));
    try std.testing.expectEqual(BatteryLevel.low, BatteryLevel.fromPercentage(15));
    try std.testing.expectEqual(BatteryLevel.low, BatteryLevel.fromPercentage(20));
    try std.testing.expectEqual(BatteryLevel.medium, BatteryLevel.fromPercentage(35));
    try std.testing.expectEqual(BatteryLevel.medium, BatteryLevel.fromPercentage(50));
    try std.testing.expectEqual(BatteryLevel.high, BatteryLevel.fromPercentage(75));
    try std.testing.expectEqual(BatteryLevel.high, BatteryLevel.fromPercentage(80));
    try std.testing.expectEqual(BatteryLevel.full, BatteryLevel.fromPercentage(95));
    try std.testing.expectEqual(BatteryLevel.full, BatteryLevel.fromPercentage(100));
}

test "BatteryLevel notifications" {
    try std.testing.expect(BatteryLevel.critical.shouldNotify());
    try std.testing.expect(BatteryLevel.low.shouldNotify());
    try std.testing.expect(!BatteryLevel.medium.shouldNotify());
    try std.testing.expect(!BatteryLevel.high.shouldNotify());
    try std.testing.expect(!BatteryLevel.full.shouldNotify());
}

test "BatteryStatus init" {
    const status = BatteryStatus.init();
    try std.testing.expectEqual(@as(u8, 0), status.level);
    try std.testing.expectEqual(ChargingState.unknown, status.charging_state);
    try std.testing.expectEqual(BatteryHealth.unknown, status.health);
    try std.testing.expect(!status.is_present);
}

test "BatteryStatus getBatteryLevel" {
    var status = BatteryStatus.init();
    status.level = 5;
    try std.testing.expectEqual(BatteryLevel.critical, status.getBatteryLevel());

    status.level = 75;
    try std.testing.expectEqual(BatteryLevel.high, status.getBatteryLevel());
}

test "BatteryStatus charging checks" {
    var status = BatteryStatus.init();
    status.charging_state = .charging;
    try std.testing.expect(status.isCharging());
    try std.testing.expect(status.isPluggedIn());

    status.charging_state = .full;
    try std.testing.expect(!status.isCharging());
    try std.testing.expect(status.isPluggedIn());

    status.charging_state = .unplugged;
    try std.testing.expect(!status.isCharging());
    try std.testing.expect(!status.isPluggedIn());
}

test "BatteryStatus isCritical" {
    var status = BatteryStatus.init();
    status.level = 5;
    status.charging_state = .unplugged;
    try std.testing.expect(status.isCritical());

    status.charging_state = .charging;
    try std.testing.expect(!status.isCritical());

    status.charging_state = .unplugged;
    status.level = 15;
    try std.testing.expect(!status.isCritical());
}

test "BatteryStatus getHealthPercentage" {
    var status = BatteryStatus.init();
    status.max_capacity = 4000;
    status.design_capacity = 5000;

    const health = status.getHealthPercentage();
    try std.testing.expect(health != null);
    try std.testing.expectEqual(@as(u8, 80), health.?);
}

test "BatteryStatus needsAttention" {
    var status = BatteryStatus.init();
    status.health = .good;
    status.thermal_state = .nominal;
    status.level = 50;
    try std.testing.expect(!status.needsAttention());

    status.health = .overheat;
    try std.testing.expect(status.needsAttention());

    status.health = .good;
    status.thermal_state = .critical;
    try std.testing.expect(status.needsAttention());

    status.thermal_state = .nominal;
    status.level = 5;
    status.charging_state = .unplugged;
    try std.testing.expect(status.needsAttention());
}

test "formatDuration" {
    var buffer: [32]u8 = undefined;

    try std.testing.expectEqualStrings("0m", formatDuration(0, &buffer));
    try std.testing.expectEqualStrings("30m", formatDuration(1800, &buffer));
    try std.testing.expectEqualStrings("1h 0m", formatDuration(3600, &buffer));
    try std.testing.expectEqualStrings("2h 30m", formatDuration(9000, &buffer));
    try std.testing.expectEqualStrings("Unknown", formatDuration(-1, &buffer));
}

test "BatteryStatus formatTimeRemaining" {
    var status = BatteryStatus.init();
    var buffer: [32]u8 = undefined;

    try std.testing.expectEqualStrings("Unknown", status.formatTimeRemaining(&buffer));

    status.time_remaining = 7200; // 2 hours
    try std.testing.expectEqualStrings("2h 0m", status.formatTimeRemaining(&buffer));
}

test "BatteryEvent create" {
    const status = BatteryStatus.init();
    const event = BatteryEvent.create(.level_changed, status);

    try std.testing.expectEqual(BatteryEventType.level_changed, event.event_type);
    try std.testing.expect(event.old_value == null);
    try std.testing.expect(event.new_value == null);
}

test "BatteryEvent withValues" {
    const status = BatteryStatus.init();
    const event = BatteryEvent.withValues(.level_changed, 80, 75, status);

    try std.testing.expectEqual(BatteryEventType.level_changed, event.event_type);
    try std.testing.expectEqual(@as(i32, 80), event.old_value.?);
    try std.testing.expectEqual(@as(i32, 75), event.new_value.?);
}

test "BatteryMonitor initialization" {
    const allocator = std.testing.allocator;
    var monitor = BatteryMonitor.init(allocator);
    defer monitor.deinit();

    try std.testing.expect(!monitor.is_monitoring);
    try std.testing.expectEqual(@as(usize, 0), monitor.callbacks.items.len);
}

test "BatteryMonitor startStop" {
    const allocator = std.testing.allocator;
    var monitor = BatteryMonitor.init(allocator);
    defer monitor.deinit();

    try std.testing.expect(!monitor.isActive());
    monitor.startMonitoring();
    try std.testing.expect(monitor.isActive());
    monitor.stopMonitoring();
    try std.testing.expect(!monitor.isActive());
}

var test_event_count: u32 = 0;
fn testCallback(_: BatteryEvent) void {
    test_event_count += 1;
}

test "BatteryMonitor callbacks" {
    const allocator = std.testing.allocator;
    var monitor = BatteryMonitor.init(allocator);
    defer monitor.deinit();

    test_event_count = 0;

    try monitor.addCallback(testCallback);
    try std.testing.expectEqual(@as(usize, 1), monitor.callbacks.items.len);

    // Process a status change that triggers a notification
    var status1 = BatteryStatus.init();
    status1.level = 100;
    status1.charging_state = .unplugged;
    monitor.last_status = status1;
    monitor.last_notified_level = 100;

    var status2 = BatteryStatus.init();
    status2.level = 90;
    status2.charging_state = .unplugged;
    monitor.processStatus(status2);

    try std.testing.expect(test_event_count > 0);

    const removed = monitor.removeCallback(testCallback);
    try std.testing.expect(removed);
    try std.testing.expectEqual(@as(usize, 0), monitor.callbacks.items.len);
}

test "BatteryMonitorConfig defaults" {
    const config = BatteryMonitorConfig{};
    try std.testing.expectEqual(@as(u32, 30000), config.poll_interval_ms);
    try std.testing.expect(config.notify_level_changes);
    try std.testing.expectEqual(@as(u8, 5), config.level_change_threshold);
    try std.testing.expectEqual(@as(u8, 20), config.low_battery_threshold);
    try std.testing.expectEqual(@as(u8, 10), config.critical_battery_threshold);
}

test "getPowerHints no hints when plugged in" {
    var status = BatteryStatus.init();
    status.charging_state = .charging;
    status.thermal_state = .nominal;

    var buffer: [8]PowerHint = undefined;
    const hints = getPowerHints(status, &buffer);
    try std.testing.expectEqual(@as(usize, 0), hints.len);
}

test "getPowerHints low battery" {
    var status = BatteryStatus.init();
    status.level = 15;
    status.charging_state = .unplugged;
    status.thermal_state = .nominal;
    status.low_power_mode = .disabled;

    var buffer: [8]PowerHint = undefined;
    const hints = getPowerHints(status, &buffer);
    try std.testing.expect(hints.len > 0);
}

test "getPowerHints critical battery" {
    var status = BatteryStatus.init();
    status.level = 5;
    status.charging_state = .unplugged;
    status.thermal_state = .nominal;

    var buffer: [8]PowerHint = undefined;
    const hints = getPowerHints(status, &buffer);
    try std.testing.expect(hints.len > 0);
    try std.testing.expectEqual(PowerHint.aggressive_saving, hints[0]);
}

test "getPowerHints thermal throttling" {
    var status = BatteryStatus.init();
    status.level = 80;
    status.charging_state = .unplugged;
    status.thermal_state = .serious;

    var buffer: [8]PowerHint = undefined;
    const hints = getPowerHints(status, &buffer);

    var has_reduce_processing = false;
    for (hints) |hint| {
        if (hint == .reduce_processing) has_reduce_processing = true;
    }
    try std.testing.expect(has_reduce_processing);
}

test "SimulatedBattery init" {
    const battery = SimulatedBattery.init();
    const status = battery.getStatus();

    try std.testing.expectEqual(@as(u8, 75), status.level);
    try std.testing.expectEqual(ChargingState.unplugged, status.charging_state);
    try std.testing.expectEqual(BatteryHealth.good, status.health);
    try std.testing.expect(status.is_present);
}

test "SimulatedBattery setLevel" {
    var battery = SimulatedBattery.init();
    battery.setLevel(50);
    try std.testing.expectEqual(@as(u8, 50), battery.getStatus().level);

    battery.setLevel(150); // Should clamp to 100
    try std.testing.expectEqual(@as(u8, 100), battery.getStatus().level);
}

test "SimulatedBattery charging" {
    var battery = SimulatedBattery.init();
    battery.setChargingState(.charging);

    const status = battery.getStatus();
    try std.testing.expectEqual(ChargingState.charging, status.charging_state);
    try std.testing.expectEqual(PowerSource.ac, status.power_source);
    try std.testing.expect(status.time_to_full != null);
}

test "SimulatedBattery drain and charge" {
    var battery = SimulatedBattery.init();
    battery.setLevel(50);

    battery.drain(10);
    try std.testing.expectEqual(@as(u8, 40), battery.getStatus().level);

    battery.charge(20);
    try std.testing.expectEqual(@as(u8, 60), battery.getStatus().level);

    // Test boundary conditions
    battery.drain(100);
    try std.testing.expectEqual(@as(u8, 0), battery.getStatus().level);

    battery.charge(200);
    try std.testing.expectEqual(@as(u8, 100), battery.getStatus().level);
}

test "SimulatedBattery thermal state" {
    var battery = SimulatedBattery.init();
    battery.setThermalState(.serious);

    try std.testing.expectEqual(ThermalState.serious, battery.getStatus().thermal_state);
}

test "SimulatedBattery low power mode" {
    var battery = SimulatedBattery.init();
    battery.setLowPowerMode(true);

    try std.testing.expectEqual(LowPowerMode.enabled, battery.getStatus().low_power_mode);
}

test "PowerHint toString" {
    try std.testing.expectEqualStrings("None", PowerHint.none.toString());
    try std.testing.expectEqualStrings("Reduce Network", PowerHint.reduce_network.toString());
    try std.testing.expectEqualStrings("Aggressive Saving", PowerHint.aggressive_saving.toString());
}

test "LowPowerMode states" {
    try std.testing.expect(!LowPowerMode.unknown.isEnabled());
    try std.testing.expect(!LowPowerMode.disabled.isEnabled());
    try std.testing.expect(LowPowerMode.enabled.isEnabled());
}

test "BatteryStatus getSummary" {
    var status = BatteryStatus.init();
    status.level = 75;
    status.charging_state = .charging;

    var buffer: [32]u8 = undefined;
    const summary = status.getSummary(&buffer);
    try std.testing.expect(summary.len > 0);
}
