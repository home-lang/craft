//! App Lifecycle module for Craft
//! Provides cross-platform app state management and lifecycle events.
//! Abstracts platform-specific implementations:
//! - iOS: UIApplicationDelegate / SceneDelegate
//! - Android: Activity lifecycle / ProcessLifecycleOwner
//! - macOS: NSApplicationDelegate
//! - Desktop: Window focus events

const std = @import("std");

/// Get current timestamp in milliseconds (Zig 0.16 compatible)
fn getTimestampMs() i64 {
    const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
    return @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000);
}

/// Application state
pub const AppState = enum {
    /// App is not running
    not_running,
    /// App is launching
    launching,
    /// App is active and in foreground
    active,
    /// App is inactive (transitioning)
    inactive,
    /// App is in background
    background,
    /// App is suspended (iOS)
    suspended,
    /// App is terminating
    terminating,

    /// Check if app is in foreground
    pub fn isForeground(self: AppState) bool {
        return self == .active or self == .inactive;
    }

    /// Check if app is running
    pub fn isRunning(self: AppState) bool {
        return self != .not_running and self != .terminating;
    }

    /// Get display name
    pub fn name(self: AppState) []const u8 {
        return switch (self) {
            .not_running => "Not Running",
            .launching => "Launching",
            .active => "Active",
            .inactive => "Inactive",
            .background => "Background",
            .suspended => "Suspended",
            .terminating => "Terminating",
        };
    }
};

/// Lifecycle event types
pub const LifecycleEvent = enum {
    /// App did finish launching
    did_finish_launching,
    /// App will enter foreground
    will_enter_foreground,
    /// App did become active
    did_become_active,
    /// App will resign active
    will_resign_active,
    /// App did enter background
    did_enter_background,
    /// App will terminate
    will_terminate,
    /// App received memory warning
    memory_warning,
    /// App significant time change (midnight, timezone)
    significant_time_change,
    /// App will change status bar orientation
    status_bar_orientation_change,
    /// Protected data will become unavailable
    protected_data_will_become_unavailable,
    /// Protected data did become available
    protected_data_did_become_available,

    /// Get event name
    pub fn name(self: LifecycleEvent) []const u8 {
        return switch (self) {
            .did_finish_launching => "didFinishLaunching",
            .will_enter_foreground => "willEnterForeground",
            .did_become_active => "didBecomeActive",
            .will_resign_active => "willResignActive",
            .did_enter_background => "didEnterBackground",
            .will_terminate => "willTerminate",
            .memory_warning => "memoryWarning",
            .significant_time_change => "significantTimeChange",
            .status_bar_orientation_change => "statusBarOrientationChange",
            .protected_data_will_become_unavailable => "protectedDataWillBecomeUnavailable",
            .protected_data_did_become_available => "protectedDataDidBecomeAvailable",
        };
    }
};

/// Background task identifier
pub const BackgroundTaskId = u64;

/// Background task completion handler
pub const BackgroundTaskCompletion = *const fn () void;

/// Lifecycle event callback
pub const LifecycleCallback = *const fn (event: LifecycleEvent) void;

/// State change callback
pub const StateChangeCallback = *const fn (old_state: AppState, new_state: AppState) void;

/// Launch options
pub const LaunchOptions = struct {
    /// URL that caused the launch
    url: ?[]const u8 = null,
    /// Source app bundle ID
    source_application: ?[]const u8 = null,
    /// Notification that caused the launch
    notification: ?[]const u8 = null,
    /// Shortcut item that caused the launch
    shortcut_item: ?[]const u8 = null,
    /// User activity (Handoff)
    user_activity: ?[]const u8 = null,
    /// Launch was from background fetch
    background_fetch: bool = false,
    /// Launch was from remote notification
    remote_notification: bool = false,
    /// Launch was from location event
    location: bool = false,

    /// Check if launched from URL
    pub fn wasLaunchedFromUrl(self: LaunchOptions) bool {
        return self.url != null;
    }

    /// Check if launched from notification
    pub fn wasLaunchedFromNotification(self: LaunchOptions) bool {
        return self.notification != null or self.remote_notification;
    }
};

/// App termination reason
pub const TerminationReason = enum {
    /// User quit the app
    user_quit,
    /// System forced termination
    system_forced,
    /// Memory pressure
    memory_pressure,
    /// System shutdown/restart
    system_shutdown,
    /// App update
    app_update,
    /// Unknown reason
    unknown,

    /// Get display name
    pub fn name(self: TerminationReason) []const u8 {
        return switch (self) {
            .user_quit => "User Quit",
            .system_forced => "System Forced",
            .memory_pressure => "Memory Pressure",
            .system_shutdown => "System Shutdown",
            .app_update => "App Update",
            .unknown => "Unknown",
        };
    }
};

/// Background fetch result
pub const BackgroundFetchResult = enum {
    /// New data was downloaded
    new_data,
    /// No new data available
    no_data,
    /// Fetch failed
    failed,
};

/// App lifecycle manager
pub const LifecycleManager = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    // State
    current_state: AppState = .not_running,
    previous_state: AppState = .not_running,
    launch_options: ?LaunchOptions = null,
    launch_time: i64 = 0,
    last_active_time: i64 = 0,
    background_time: i64 = 0,

    // Callbacks
    lifecycle_callbacks: std.ArrayListUnmanaged(LifecycleCallback) = .{},
    state_change_callbacks: std.ArrayListUnmanaged(StateChangeCallback) = .{},

    // Background tasks
    next_task_id: BackgroundTaskId = 1,
    active_background_tasks: std.AutoHashMapUnmanaged(BackgroundTaskId, []const u8) = .{},

    // Metrics
    total_foreground_time: i64 = 0,
    total_background_time: i64 = 0,
    session_count: u32 = 0,

    /// Initialize lifecycle manager
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    /// Deinitialize
    pub fn deinit(self: *Self) void {
        self.lifecycle_callbacks.deinit(self.allocator);
        self.state_change_callbacks.deinit(self.allocator);
        self.active_background_tasks.deinit(self.allocator);
    }

    /// Get current app state
    pub fn getState(self: *const Self) AppState {
        return self.current_state;
    }

    /// Check if app is active
    pub fn isActive(self: *const Self) bool {
        return self.current_state == .active;
    }

    /// Check if app is in background
    pub fn isInBackground(self: *const Self) bool {
        return self.current_state == .background or self.current_state == .suspended;
    }

    /// Check if app is in foreground
    pub fn isInForeground(self: *const Self) bool {
        return self.current_state.isForeground();
    }

    /// Get launch options
    pub fn getLaunchOptions(self: *const Self) ?LaunchOptions {
        return self.launch_options;
    }

    /// Get time since launch (milliseconds)
    pub fn timeSinceLaunch(self: *const Self) i64 {
        if (self.launch_time == 0) return 0;
        return getTimestampMs() - self.launch_time;
    }

    /// Get time in background (milliseconds)
    pub fn timeInBackground(self: *const Self) i64 {
        if (self.background_time == 0) return 0;
        if (self.current_state == .background or self.current_state == .suspended) {
            return getTimestampMs() - self.background_time;
        }
        return 0;
    }

    /// Add lifecycle event callback
    pub fn addLifecycleCallback(self: *Self, callback: LifecycleCallback) !void {
        try self.lifecycle_callbacks.append(self.allocator, callback);
    }

    /// Remove lifecycle event callback
    pub fn removeLifecycleCallback(self: *Self, callback: LifecycleCallback) void {
        var i: usize = 0;
        while (i < self.lifecycle_callbacks.items.len) {
            if (self.lifecycle_callbacks.items[i] == callback) {
                _ = self.lifecycle_callbacks.swapRemove(i);
                return;
            }
            i += 1;
        }
    }

    /// Add state change callback
    pub fn addStateChangeCallback(self: *Self, callback: StateChangeCallback) !void {
        try self.state_change_callbacks.append(self.allocator, callback);
    }

    /// Begin background task
    pub fn beginBackgroundTask(self: *Self, task_name: []const u8) BackgroundTaskId {
        const task_id = self.next_task_id;
        self.next_task_id += 1;
        self.active_background_tasks.put(self.allocator, task_id, task_name) catch {};
        return task_id;
    }

    /// End background task
    pub fn endBackgroundTask(self: *Self, task_id: BackgroundTaskId) void {
        _ = self.active_background_tasks.remove(task_id);
    }

    /// Get active background task count
    pub fn activeBackgroundTaskCount(self: *const Self) usize {
        return self.active_background_tasks.count();
    }

    /// Get background time remaining (simulated)
    pub fn backgroundTimeRemaining(_: *const Self) f64 {
        // Platform-specific: iOS returns actual remaining time
        return 30.0; // Simulated: 30 seconds
    }

    // Internal state transition methods

    /// Simulate app launch
    pub fn simulateLaunch(self: *Self, options: ?LaunchOptions) void {
        self.launch_options = options;
        self.launch_time = getTimestampMs();
        self.session_count += 1;
        self.transitionTo(.launching);
        self.notifyEvent(.did_finish_launching);
        self.transitionTo(.active);
        self.notifyEvent(.did_become_active);
    }

    /// Simulate entering background
    pub fn simulateEnterBackground(self: *Self) void {
        if (self.current_state == .active) {
            self.notifyEvent(.will_resign_active);
            self.transitionTo(.inactive);
        }
        self.notifyEvent(.did_enter_background);
        self.background_time = getTimestampMs();
        self.transitionTo(.background);
    }

    /// Simulate entering foreground
    pub fn simulateEnterForeground(self: *Self) void {
        if (self.current_state == .background or self.current_state == .suspended) {
            // Update background time metrics
            if (self.background_time > 0) {
                self.total_background_time += getTimestampMs() - self.background_time;
                self.background_time = 0;
            }
            self.notifyEvent(.will_enter_foreground);
            self.transitionTo(.inactive);
            self.notifyEvent(.did_become_active);
            self.transitionTo(.active);
            self.last_active_time = getTimestampMs();
        }
    }

    /// Simulate memory warning
    pub fn simulateMemoryWarning(self: *Self) void {
        self.notifyEvent(.memory_warning);
    }

    /// Simulate termination
    pub fn simulateTerminate(self: *Self) void {
        self.notifyEvent(.will_terminate);
        self.transitionTo(.terminating);
        self.transitionTo(.not_running);
    }

    /// Internal: transition to new state
    fn transitionTo(self: *Self, new_state: AppState) void {
        const old_state = self.current_state;
        self.previous_state = old_state;
        self.current_state = new_state;

        // Track foreground time
        if (old_state == .active and new_state != .active) {
            if (self.last_active_time > 0) {
                self.total_foreground_time += getTimestampMs() - self.last_active_time;
            }
        }

        // Notify callbacks
        for (self.state_change_callbacks.items) |callback| {
            callback(old_state, new_state);
        }
    }

    /// Internal: notify lifecycle event
    fn notifyEvent(self: *Self, event: LifecycleEvent) void {
        for (self.lifecycle_callbacks.items) |callback| {
            callback(event);
        }
    }

    // Metrics

    /// Get total foreground time (milliseconds)
    pub fn getTotalForegroundTime(self: *const Self) i64 {
        var total = self.total_foreground_time;
        if (self.current_state == .active and self.last_active_time > 0) {
            total += getTimestampMs() - self.last_active_time;
        }
        return total;
    }

    /// Get total background time (milliseconds)
    pub fn getTotalBackgroundTime(self: *const Self) i64 {
        var total = self.total_background_time;
        if ((self.current_state == .background or self.current_state == .suspended) and self.background_time > 0) {
            total += getTimestampMs() - self.background_time;
        }
        return total;
    }

    /// Get session count
    pub fn getSessionCount(self: *const Self) u32 {
        return self.session_count;
    }
};

/// Scene state (iPadOS/iOS 13+)
pub const SceneState = enum {
    /// Scene is unattached
    unattached,
    /// Scene is in foreground active
    foreground_active,
    /// Scene is in foreground inactive
    foreground_inactive,
    /// Scene is in background
    background,
    /// Scene is suspended
    suspended,

    /// Check if foreground
    pub fn isForeground(self: SceneState) bool {
        return self == .foreground_active or self == .foreground_inactive;
    }
};

/// Scene session (for multi-window apps)
pub const SceneSession = struct {
    /// Unique identifier
    id: []const u8,
    /// Scene state
    state: SceneState = .unattached,
    /// Creation time
    creation_time: i64,
    /// Last active time
    last_active_time: i64 = 0,
    /// User info
    user_info: ?[]const u8 = null,

    /// Create new scene session
    pub fn init(id: []const u8) SceneSession {
        const now = getTimestampMs();
        return .{
            .id = id,
            .creation_time = now,
        };
    }
};

/// Memory usage information
pub const MemoryUsage = struct {
    /// Used memory in bytes
    used: u64,
    /// Available memory in bytes
    available: u64,
    /// Total memory in bytes
    total: u64,
    /// Memory pressure level
    pressure: MemoryPressure,

    /// Get usage percentage
    pub fn usagePercent(self: MemoryUsage) f64 {
        if (self.total == 0) return 0;
        return @as(f64, @floatFromInt(self.used)) / @as(f64, @floatFromInt(self.total)) * 100.0;
    }

    /// Simulated memory usage
    pub fn simulated() MemoryUsage {
        return .{
            .used = 256 * 1024 * 1024, // 256 MB
            .available = 768 * 1024 * 1024, // 768 MB
            .total = 1024 * 1024 * 1024, // 1 GB
            .pressure = .normal,
        };
    }
};

/// Memory pressure levels
pub const MemoryPressure = enum {
    /// Normal memory usage
    normal,
    /// Warning level
    warning,
    /// Critical level
    critical,

    /// Get display name
    pub fn name(self: MemoryPressure) []const u8 {
        return switch (self) {
            .normal => "Normal",
            .warning => "Warning",
            .critical => "Critical",
        };
    }
};

/// Battery state
pub const BatteryState = enum {
    /// Unknown state
    unknown,
    /// Not charging, on battery
    unplugged,
    /// Charging
    charging,
    /// Fully charged
    full,

    /// Get display name
    pub fn name(self: BatteryState) []const u8 {
        return switch (self) {
            .unknown => "Unknown",
            .unplugged => "Unplugged",
            .charging => "Charging",
            .full => "Full",
        };
    }
};

/// Device state information
pub const DeviceState = struct {
    /// Battery level (0-100)
    battery_level: u8 = 100,
    /// Battery state
    battery_state: BatteryState = .full,
    /// Low power mode enabled
    low_power_mode: bool = false,
    /// Thermal state
    thermal_state: ThermalState = .nominal,
    /// Memory usage
    memory: MemoryUsage,

    /// Check if should reduce work
    pub fn shouldReduceWork(self: DeviceState) bool {
        return self.low_power_mode or
            self.thermal_state == .critical or
            self.thermal_state == .serious or
            self.battery_level < 20;
    }

    /// Simulated device state
    pub fn simulated() DeviceState {
        return .{
            .battery_level = 75,
            .battery_state = .unplugged,
            .low_power_mode = false,
            .thermal_state = .nominal,
            .memory = MemoryUsage.simulated(),
        };
    }
};

/// Thermal state
pub const ThermalState = enum {
    /// Normal temperature
    nominal,
    /// Slightly elevated
    fair,
    /// High temperature
    serious,
    /// Critical temperature
    critical,

    /// Get display name
    pub fn name(self: ThermalState) []const u8 {
        return switch (self) {
            .nominal => "Nominal",
            .fair => "Fair",
            .serious => "Serious",
            .critical => "Critical",
        };
    }
};

/// Quick app state utilities
pub const QuickApp = struct {
    var manager: ?LifecycleManager = null;

    /// Get shared manager
    pub fn shared(allocator: std.mem.Allocator) *LifecycleManager {
        if (manager == null) {
            manager = LifecycleManager.init(allocator);
        }
        return &manager.?;
    }

    /// Check if app is active
    pub fn isActive(allocator: std.mem.Allocator) bool {
        return shared(allocator).isActive();
    }

    /// Check if app is in background
    pub fn isInBackground(allocator: std.mem.Allocator) bool {
        return shared(allocator).isInBackground();
    }

    /// Get current state
    pub fn getState(allocator: std.mem.Allocator) AppState {
        return shared(allocator).getState();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "AppState basics" {
    try std.testing.expect(AppState.active.isForeground());
    try std.testing.expect(AppState.inactive.isForeground());
    try std.testing.expect(!AppState.background.isForeground());
    try std.testing.expect(!AppState.not_running.isForeground());
}

test "AppState isRunning" {
    try std.testing.expect(AppState.active.isRunning());
    try std.testing.expect(AppState.background.isRunning());
    try std.testing.expect(!AppState.not_running.isRunning());
    try std.testing.expect(!AppState.terminating.isRunning());
}

test "AppState name" {
    try std.testing.expectEqualStrings("Active", AppState.active.name());
    try std.testing.expectEqualStrings("Background", AppState.background.name());
}

test "LifecycleEvent name" {
    try std.testing.expectEqualStrings("didFinishLaunching", LifecycleEvent.did_finish_launching.name());
    try std.testing.expectEqualStrings("didBecomeActive", LifecycleEvent.did_become_active.name());
    try std.testing.expectEqualStrings("memoryWarning", LifecycleEvent.memory_warning.name());
}

test "LaunchOptions wasLaunchedFromUrl" {
    const with_url = LaunchOptions{ .url = "myapp://test" };
    try std.testing.expect(with_url.wasLaunchedFromUrl());

    const without_url = LaunchOptions{};
    try std.testing.expect(!without_url.wasLaunchedFromUrl());
}

test "LaunchOptions wasLaunchedFromNotification" {
    const with_notification = LaunchOptions{ .notification = "test" };
    try std.testing.expect(with_notification.wasLaunchedFromNotification());

    const with_remote = LaunchOptions{ .remote_notification = true };
    try std.testing.expect(with_remote.wasLaunchedFromNotification());

    const without = LaunchOptions{};
    try std.testing.expect(!without.wasLaunchedFromNotification());
}

test "TerminationReason name" {
    try std.testing.expectEqualStrings("User Quit", TerminationReason.user_quit.name());
    try std.testing.expectEqualStrings("Memory Pressure", TerminationReason.memory_pressure.name());
}

test "LifecycleManager initialization" {
    var manager = LifecycleManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectEqual(AppState.not_running, manager.getState());
    try std.testing.expect(!manager.isActive());
    try std.testing.expect(!manager.isInBackground());
}

test "LifecycleManager simulateLaunch" {
    var manager = LifecycleManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.simulateLaunch(null);

    try std.testing.expectEqual(AppState.active, manager.getState());
    try std.testing.expect(manager.isActive());
    try std.testing.expect(manager.isInForeground());
    try std.testing.expect(manager.launch_time > 0);
    try std.testing.expectEqual(@as(u32, 1), manager.getSessionCount());
}

test "LifecycleManager simulateEnterBackground" {
    var manager = LifecycleManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.simulateLaunch(null);
    manager.simulateEnterBackground();

    try std.testing.expectEqual(AppState.background, manager.getState());
    try std.testing.expect(manager.isInBackground());
    try std.testing.expect(!manager.isActive());
}

test "LifecycleManager simulateEnterForeground" {
    var manager = LifecycleManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.simulateLaunch(null);
    manager.simulateEnterBackground();
    manager.simulateEnterForeground();

    try std.testing.expectEqual(AppState.active, manager.getState());
    try std.testing.expect(manager.isActive());
    try std.testing.expect(manager.isInForeground());
}

test "LifecycleManager simulateTerminate" {
    var manager = LifecycleManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.simulateLaunch(null);
    manager.simulateTerminate();

    try std.testing.expectEqual(AppState.not_running, manager.getState());
    try std.testing.expect(!manager.isActive());
}

test "LifecycleManager background tasks" {
    var manager = LifecycleManager.init(std.testing.allocator);
    defer manager.deinit();

    const task1 = manager.beginBackgroundTask("download");
    try std.testing.expectEqual(@as(usize, 1), manager.activeBackgroundTaskCount());

    const task2 = manager.beginBackgroundTask("upload");
    try std.testing.expectEqual(@as(usize, 2), manager.activeBackgroundTaskCount());

    manager.endBackgroundTask(task1);
    try std.testing.expectEqual(@as(usize, 1), manager.activeBackgroundTaskCount());

    manager.endBackgroundTask(task2);
    try std.testing.expectEqual(@as(usize, 0), manager.activeBackgroundTaskCount());
}

test "LifecycleManager backgroundTimeRemaining" {
    var manager = LifecycleManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expect(manager.backgroundTimeRemaining() > 0);
}

test "LifecycleManager timeSinceLaunch" {
    var manager = LifecycleManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectEqual(@as(i64, 0), manager.timeSinceLaunch());

    manager.simulateLaunch(null);
    try std.testing.expect(manager.timeSinceLaunch() >= 0);
}

test "SceneState isForeground" {
    try std.testing.expect(SceneState.foreground_active.isForeground());
    try std.testing.expect(SceneState.foreground_inactive.isForeground());
    try std.testing.expect(!SceneState.background.isForeground());
    try std.testing.expect(!SceneState.unattached.isForeground());
}

test "SceneSession init" {
    const session = SceneSession.init("test_scene");
    try std.testing.expectEqualStrings("test_scene", session.id);
    try std.testing.expectEqual(SceneState.unattached, session.state);
    try std.testing.expect(session.creation_time > 0);
}

test "MemoryUsage usagePercent" {
    const usage = MemoryUsage{
        .used = 500,
        .available = 500,
        .total = 1000,
        .pressure = .normal,
    };
    try std.testing.expectApproxEqAbs(@as(f64, 50.0), usage.usagePercent(), 0.1);
}

test "MemoryUsage simulated" {
    const usage = MemoryUsage.simulated();
    try std.testing.expect(usage.total > 0);
    try std.testing.expect(usage.used > 0);
}

test "MemoryPressure name" {
    try std.testing.expectEqualStrings("Normal", MemoryPressure.normal.name());
    try std.testing.expectEqualStrings("Critical", MemoryPressure.critical.name());
}

test "BatteryState name" {
    try std.testing.expectEqualStrings("Charging", BatteryState.charging.name());
    try std.testing.expectEqualStrings("Full", BatteryState.full.name());
}

test "ThermalState name" {
    try std.testing.expectEqualStrings("Nominal", ThermalState.nominal.name());
    try std.testing.expectEqualStrings("Critical", ThermalState.critical.name());
}

test "DeviceState shouldReduceWork" {
    const normal = DeviceState.simulated();
    try std.testing.expect(!normal.shouldReduceWork());

    const low_power = DeviceState{
        .battery_level = 75,
        .battery_state = .unplugged,
        .low_power_mode = true,
        .thermal_state = .nominal,
        .memory = MemoryUsage.simulated(),
    };
    try std.testing.expect(low_power.shouldReduceWork());

    const low_battery = DeviceState{
        .battery_level = 15,
        .battery_state = .unplugged,
        .low_power_mode = false,
        .thermal_state = .nominal,
        .memory = MemoryUsage.simulated(),
    };
    try std.testing.expect(low_battery.shouldReduceWork());
}

test "DeviceState simulated" {
    const state = DeviceState.simulated();
    try std.testing.expect(state.battery_level > 0);
    try std.testing.expect(!state.low_power_mode);
}
