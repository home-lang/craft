const std = @import("std");
const builtin = @import("builtin");

/// Device Info Module
/// Provides cross-platform device information for iOS, Android, macOS, Windows, and Linux.
/// Includes device model, OS version, screen size, battery status, and system capabilities.

// ============================================================================
// Platform Types
// ============================================================================

/// Operating system type
pub const Platform = enum {
    ios,
    android,
    macos,
    windows,
    linux,
    unknown,

    pub fn toString(self: Platform) []const u8 {
        return switch (self) {
            .ios => "iOS",
            .android => "Android",
            .macos => "macOS",
            .windows => "Windows",
            .linux => "Linux",
            .unknown => "Unknown",
        };
    }

    pub fn isMobile(self: Platform) bool {
        return self == .ios or self == .android;
    }

    pub fn isDesktop(self: Platform) bool {
        return self == .macos or self == .windows or self == .linux;
    }

    pub fn isApple(self: Platform) bool {
        return self == .ios or self == .macos;
    }

    pub fn current() Platform {
        if (comptime builtin.os.tag == .ios) return .ios;
        if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) return .macos;
        if (comptime builtin.os.tag == .windows) return .windows;
        if (comptime builtin.os.tag == .linux) {
            if (comptime builtin.abi == .android) return .android;
            return .linux;
        }
        return .unknown;
    }
};

/// Device form factor
pub const FormFactor = enum {
    phone,
    tablet,
    desktop,
    laptop,
    tv,
    watch,
    car,
    unknown,

    pub fn toString(self: FormFactor) []const u8 {
        return switch (self) {
            .phone => "phone",
            .tablet => "tablet",
            .desktop => "desktop",
            .laptop => "laptop",
            .tv => "tv",
            .watch => "watch",
            .car => "car",
            .unknown => "unknown",
        };
    }

    pub fn isMobile(self: FormFactor) bool {
        return self == .phone or self == .tablet or self == .watch;
    }

    pub fn hasLargeScreen(self: FormFactor) bool {
        return self == .tablet or self == .desktop or self == .laptop or self == .tv;
    }
};

// ============================================================================
// Version Information
// ============================================================================

/// Semantic version
pub const Version = struct {
    major: u32,
    minor: u32,
    patch: u32,
    build: ?[]const u8,

    pub fn init(major: u32, minor: u32, patch: u32) Version {
        return .{
            .major = major,
            .minor = minor,
            .patch = patch,
            .build = null,
        };
    }

    pub fn withBuild(self: Version, build: []const u8) Version {
        var v = self;
        v.build = build;
        return v;
    }

    pub fn compare(self: Version, other: Version) i32 {
        if (self.major != other.major) {
            return if (self.major > other.major) 1 else -1;
        }
        if (self.minor != other.minor) {
            return if (self.minor > other.minor) 1 else -1;
        }
        if (self.patch != other.patch) {
            return if (self.patch > other.patch) 1 else -1;
        }
        return 0;
    }

    pub fn isAtLeast(self: Version, major: u32, minor: u32) bool {
        if (self.major > major) return true;
        if (self.major < major) return false;
        return self.minor >= minor;
    }

    pub fn format(self: Version, buf: []u8) ![]const u8 {
        if (self.build) |b| {
            return std.fmt.bufPrint(buf, "{d}.{d}.{d} ({s})", .{ self.major, self.minor, self.patch, b });
        }
        return std.fmt.bufPrint(buf, "{d}.{d}.{d}", .{ self.major, self.minor, self.patch });
    }
};

// ============================================================================
// Screen Information
// ============================================================================

/// Screen orientation
pub const Orientation = enum {
    portrait,
    portrait_upside_down,
    landscape_left,
    landscape_right,
    unknown,

    pub fn toString(self: Orientation) []const u8 {
        return switch (self) {
            .portrait => "portrait",
            .portrait_upside_down => "portrait_upside_down",
            .landscape_left => "landscape_left",
            .landscape_right => "landscape_right",
            .unknown => "unknown",
        };
    }

    pub fn isPortrait(self: Orientation) bool {
        return self == .portrait or self == .portrait_upside_down;
    }

    pub fn isLandscape(self: Orientation) bool {
        return self == .landscape_left or self == .landscape_right;
    }
};

/// Screen information
pub const ScreenInfo = struct {
    /// Width in pixels
    width: u32,
    /// Height in pixels
    height: u32,
    /// Scale factor (e.g., 2.0 for Retina, 3.0 for 3x)
    scale: f32,
    /// Refresh rate in Hz
    refresh_rate: u32,
    /// Current orientation
    orientation: Orientation,
    /// Is HDR capable
    hdr_capable: bool,
    /// Color depth in bits
    color_depth: u32,

    pub fn init(width: u32, height: u32, scale: f32) ScreenInfo {
        return .{
            .width = width,
            .height = height,
            .scale = scale,
            .refresh_rate = 60,
            .orientation = .portrait,
            .hdr_capable = false,
            .color_depth = 24,
        };
    }

    /// Get physical width (points/dp)
    pub fn logicalWidth(self: *const ScreenInfo) u32 {
        return @intFromFloat(@as(f32, @floatFromInt(self.width)) / self.scale);
    }

    /// Get physical height (points/dp)
    pub fn logicalHeight(self: *const ScreenInfo) u32 {
        return @intFromFloat(@as(f32, @floatFromInt(self.height)) / self.scale);
    }

    /// Get aspect ratio
    pub fn aspectRatio(self: *const ScreenInfo) f32 {
        if (self.height == 0) return 0;
        return @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(self.height));
    }

    /// Check if screen is tall (19.5:9 or taller)
    pub fn isTallScreen(self: *const ScreenInfo) bool {
        return self.aspectRatio() >= 2.0 or self.aspectRatio() <= 0.5;
    }

    /// Get diagonal in inches (approximate)
    pub fn diagonalInches(self: *const ScreenInfo, ppi: u32) f32 {
        if (ppi == 0) return 0;
        const w = @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(ppi));
        const h = @as(f32, @floatFromInt(self.height)) / @as(f32, @floatFromInt(ppi));
        return @sqrt(w * w + h * h);
    }

    /// Is high refresh rate (> 60Hz)
    pub fn isHighRefreshRate(self: *const ScreenInfo) bool {
        return self.refresh_rate > 60;
    }

    /// Is Retina/HiDPI
    pub fn isHighDensity(self: *const ScreenInfo) bool {
        return self.scale >= 2.0;
    }
};

// ============================================================================
// Battery Information
// ============================================================================

/// Battery state
pub const BatteryState = enum {
    unknown,
    unplugged,
    charging,
    full,
    not_charging, // Plugged in but not charging (e.g., battery maintenance)

    pub fn toString(self: BatteryState) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .unplugged => "unplugged",
            .charging => "charging",
            .full => "full",
            .not_charging => "not_charging",
        };
    }

    pub fn isPluggedIn(self: BatteryState) bool {
        return self == .charging or self == .full or self == .not_charging;
    }
};

/// Battery information
pub const BatteryInfo = struct {
    /// Battery level (0.0 - 1.0)
    level: f32,
    /// Battery state
    state: BatteryState,
    /// Is low power mode enabled
    low_power_mode: bool,
    /// Estimated time remaining in minutes (if available)
    time_remaining: ?u32,
    /// Battery health percentage (if available)
    health: ?f32,
    /// Cycle count (if available)
    cycle_count: ?u32,

    pub fn init() BatteryInfo {
        return .{
            .level = 1.0,
            .state = .unknown,
            .low_power_mode = false,
            .time_remaining = null,
            .health = null,
            .cycle_count = null,
        };
    }

    /// Get level as percentage (0-100)
    pub fn levelPercent(self: *const BatteryInfo) u32 {
        return @intFromFloat(self.level * 100);
    }

    /// Is battery low (< 20%)
    pub fn isLow(self: *const BatteryInfo) bool {
        return self.level < 0.2;
    }

    /// Is battery critical (< 5%)
    pub fn isCritical(self: *const BatteryInfo) bool {
        return self.level < 0.05;
    }

    /// Is battery charging or full
    pub fn isCharging(self: *const BatteryInfo) bool {
        return self.state == .charging;
    }

    /// Should save power (low battery or low power mode)
    pub fn shouldSavePower(self: *const BatteryInfo) bool {
        return self.low_power_mode or self.isLow();
    }
};

// ============================================================================
// Memory Information
// ============================================================================

/// Memory information
pub const MemoryInfo = struct {
    /// Total physical memory in bytes
    total: u64,
    /// Available memory in bytes
    available: u64,
    /// Used memory in bytes
    used: u64,
    /// App memory usage in bytes
    app_usage: u64,

    pub fn init() MemoryInfo {
        return .{
            .total = 0,
            .available = 0,
            .used = 0,
            .app_usage = 0,
        };
    }

    /// Get total memory in MB
    pub fn totalMB(self: *const MemoryInfo) u64 {
        return self.total / (1024 * 1024);
    }

    /// Get available memory in MB
    pub fn availableMB(self: *const MemoryInfo) u64 {
        return self.available / (1024 * 1024);
    }

    /// Get memory usage percentage
    pub fn usagePercent(self: *const MemoryInfo) u32 {
        if (self.total == 0) return 0;
        return @intCast((self.used * 100) / self.total);
    }

    /// Is memory low (< 10% available)
    pub fn isLow(self: *const MemoryInfo) bool {
        if (self.total == 0) return false;
        return (self.available * 100) / self.total < 10;
    }
};

// ============================================================================
// Storage Information
// ============================================================================

/// Storage information
pub const StorageInfo = struct {
    /// Total storage in bytes
    total: u64,
    /// Free storage in bytes
    free: u64,
    /// Used storage in bytes
    used: u64,

    pub fn init() StorageInfo {
        return .{
            .total = 0,
            .free = 0,
            .used = 0,
        };
    }

    /// Get total storage in GB
    pub fn totalGB(self: *const StorageInfo) f64 {
        return @as(f64, @floatFromInt(self.total)) / (1024 * 1024 * 1024);
    }

    /// Get free storage in GB
    pub fn freeGB(self: *const StorageInfo) f64 {
        return @as(f64, @floatFromInt(self.free)) / (1024 * 1024 * 1024);
    }

    /// Get usage percentage
    pub fn usagePercent(self: *const StorageInfo) u32 {
        if (self.total == 0) return 0;
        return @intCast((self.used * 100) / self.total);
    }

    /// Is storage low (< 10% free)
    pub fn isLow(self: *const StorageInfo) bool {
        if (self.total == 0) return false;
        return (self.free * 100) / self.total < 10;
    }
};

// ============================================================================
// Device Capabilities
// ============================================================================

/// Device capabilities
pub const DeviceCapabilities = struct {
    /// Has camera
    has_camera: bool,
    /// Has front camera
    has_front_camera: bool,
    /// Has flash
    has_flash: bool,
    /// Has GPS
    has_gps: bool,
    /// Has compass
    has_compass: bool,
    /// Has accelerometer
    has_accelerometer: bool,
    /// Has gyroscope
    has_gyroscope: bool,
    /// Has barometer
    has_barometer: bool,
    /// Has NFC
    has_nfc: bool,
    /// Has Bluetooth
    has_bluetooth: bool,
    /// Has cellular
    has_cellular: bool,
    /// Has WiFi
    has_wifi: bool,
    /// Has biometrics
    has_biometrics: bool,
    /// Has haptics
    has_haptics: bool,
    /// Has ARKit/ARCore
    has_ar: bool,
    /// Has LiDAR
    has_lidar: bool,

    pub fn init() DeviceCapabilities {
        return .{
            .has_camera = true,
            .has_front_camera = true,
            .has_flash = true,
            .has_gps = true,
            .has_compass = true,
            .has_accelerometer = true,
            .has_gyroscope = true,
            .has_barometer = false,
            .has_nfc = false,
            .has_bluetooth = true,
            .has_cellular = false,
            .has_wifi = true,
            .has_biometrics = true,
            .has_haptics = true,
            .has_ar = false,
            .has_lidar = false,
        };
    }

    /// Check if all sensors for motion tracking are available
    pub fn hasMotionTracking(self: *const DeviceCapabilities) bool {
        return self.has_accelerometer and self.has_gyroscope and self.has_compass;
    }

    /// Check if suitable for AR
    pub fn isSuitableForAR(self: *const DeviceCapabilities) bool {
        return self.has_ar and self.hasMotionTracking() and self.has_camera;
    }
};

// ============================================================================
// Device Information Manager
// ============================================================================

/// Device information manager
pub const DeviceInfo = struct {
    allocator: std.mem.Allocator,

    // Device identification
    model: []const u8,
    model_name: []const u8,
    manufacturer: []const u8,
    device_id: []const u8,

    // Platform info
    platform: Platform,
    form_factor: FormFactor,
    os_version: Version,
    app_version: Version,

    // Hardware info
    screen: ScreenInfo,
    battery: BatteryInfo,
    memory: MemoryInfo,
    storage: StorageInfo,
    capabilities: DeviceCapabilities,

    // Runtime info
    is_simulator: bool,
    is_jailbroken: bool,
    is_debugger_attached: bool,
    locale: []const u8,
    timezone: []const u8,
    language: []const u8,

    const Self = @This();

    /// Initialize device info
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .model = "Unknown",
            .model_name = "Unknown Device",
            .manufacturer = "Unknown",
            .device_id = "",
            .platform = Platform.current(),
            .form_factor = .unknown,
            .os_version = Version.init(0, 0, 0),
            .app_version = Version.init(1, 0, 0),
            .screen = ScreenInfo.init(375, 812, 3.0),
            .battery = BatteryInfo.init(),
            .memory = MemoryInfo.init(),
            .storage = StorageInfo.init(),
            .capabilities = DeviceCapabilities.init(),
            .is_simulator = false,
            .is_jailbroken = false,
            .is_debugger_attached = false,
            .locale = "en_US",
            .timezone = "UTC",
            .language = "en",
        };
    }

    /// Deinitialize
    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Refresh all device information
    pub fn refresh(self: *Self) void {
        self.refreshScreen();
        self.refreshBattery();
        self.refreshMemory();
        self.refreshStorage();
    }

    /// Refresh screen information
    pub fn refreshScreen(self: *Self) void {
        // Platform-specific screen info
        if (comptime builtin.os.tag == .ios) {
            // UIScreen.main.bounds, UIScreen.main.scale
        } else if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
            // NSScreen.main?.frame, NSScreen.main?.backingScaleFactor
        }
        _ = self;
    }

    /// Refresh battery information
    pub fn refreshBattery(self: *Self) void {
        // Platform-specific battery info
        if (comptime builtin.os.tag == .ios) {
            // UIDevice.current.batteryLevel, UIDevice.current.batteryState
        } else if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
            // IOPSCopyPowerSourcesInfo
        }
        _ = self;
    }

    /// Refresh memory information
    pub fn refreshMemory(self: *Self) void {
        // Platform-specific memory info
        if (comptime builtin.os.tag == .ios or builtin.os.tag.isDarwin()) {
            // task_info with MACH_TASK_BASIC_INFO
        }
        _ = self;
    }

    /// Refresh storage information
    pub fn refreshStorage(self: *Self) void {
        // Platform-specific storage info
        if (comptime builtin.os.tag == .ios) {
            // FileManager.default.attributesOfFileSystem
        }
        _ = self;
    }

    // Convenience getters

    /// Get platform name
    pub fn getPlatformName(self: *const Self) []const u8 {
        return self.platform.toString();
    }

    /// Is mobile device
    pub fn isMobile(self: *const Self) bool {
        return self.platform.isMobile();
    }

    /// Is desktop device
    pub fn isDesktop(self: *const Self) bool {
        return self.platform.isDesktop();
    }

    /// Is Apple device
    pub fn isApple(self: *const Self) bool {
        return self.platform.isApple();
    }

    /// Is phone
    pub fn isPhone(self: *const Self) bool {
        return self.form_factor == .phone;
    }

    /// Is tablet
    pub fn isTablet(self: *const Self) bool {
        return self.form_factor == .tablet;
    }

    /// Get full device description
    pub fn getDescription(self: *const Self) []const u8 {
        return self.model_name;
    }

    /// Get user agent string
    pub fn getUserAgent(self: *Self, app_name: []const u8, buf: []u8) ![]const u8 {
        var version_buf: [32]u8 = undefined;
        const version_str = try self.app_version.format(&version_buf);

        return std.fmt.bufPrint(buf, "{s}/{s} ({s}; {s} {d}.{d})", .{
            app_name,
            version_str,
            self.model,
            self.platform.toString(),
            self.os_version.major,
            self.os_version.minor,
        });
    }

    // Testing/simulation methods

    /// Set simulated model (for testing)
    pub fn setModel(self: *Self, model: []const u8, name: []const u8) void {
        self.model = model;
        self.model_name = name;
    }

    /// Set simulated platform (for testing)
    pub fn setPlatform(self: *Self, platform: Platform, form_factor: FormFactor) void {
        self.platform = platform;
        self.form_factor = form_factor;
    }

    /// Set OS version (for testing)
    pub fn setOSVersion(self: *Self, major: u32, minor: u32, patch: u32) void {
        self.os_version = Version.init(major, minor, patch);
    }

    /// Set app version
    pub fn setAppVersion(self: *Self, major: u32, minor: u32, patch: u32) void {
        self.app_version = Version.init(major, minor, patch);
    }

    /// Set screen info (for testing)
    pub fn setScreen(self: *Self, width: u32, height: u32, scale: f32) void {
        self.screen = ScreenInfo.init(width, height, scale);
    }

    /// Set battery info (for testing)
    pub fn setBattery(self: *Self, level: f32, state: BatteryState) void {
        self.battery.level = level;
        self.battery.state = state;
    }

    /// Set memory info (for testing)
    pub fn setMemory(self: *Self, total: u64, available: u64) void {
        self.memory.total = total;
        self.memory.available = available;
        self.memory.used = total - available;
    }

    /// Set storage info (for testing)
    pub fn setStorage(self: *Self, total: u64, free: u64) void {
        self.storage.total = total;
        self.storage.free = free;
        self.storage.used = total - free;
    }

    /// Mark as simulator (for testing)
    pub fn setSimulator(self: *Self, is_sim: bool) void {
        self.is_simulator = is_sim;
    }
};

// ============================================================================
// Device Presets
// ============================================================================

/// Common device presets for testing
pub const DevicePresets = struct {
    pub fn iPhone15Pro(allocator: std.mem.Allocator) DeviceInfo {
        var device = DeviceInfo.init(allocator);
        device.setModel("iPhone16,1", "iPhone 15 Pro");
        device.manufacturer = "Apple";
        device.setPlatform(.ios, .phone);
        device.setOSVersion(17, 0, 0);
        device.setScreen(1179, 2556, 3.0);
        device.capabilities.has_lidar = true;
        device.capabilities.has_ar = true;
        return device;
    }

    pub fn iPadPro(allocator: std.mem.Allocator) DeviceInfo {
        var device = DeviceInfo.init(allocator);
        device.setModel("iPad14,5", "iPad Pro 12.9-inch");
        device.manufacturer = "Apple";
        device.setPlatform(.ios, .tablet);
        device.setOSVersion(17, 0, 0);
        device.setScreen(2048, 2732, 2.0);
        device.capabilities.has_lidar = true;
        device.capabilities.has_ar = true;
        return device;
    }

    pub fn pixelPhone(allocator: std.mem.Allocator) DeviceInfo {
        var device = DeviceInfo.init(allocator);
        device.setModel("Pixel 8", "Google Pixel 8");
        device.manufacturer = "Google";
        device.setPlatform(.android, .phone);
        device.setOSVersion(14, 0, 0);
        device.setScreen(1080, 2400, 2.5);
        device.capabilities.has_nfc = true;
        return device;
    }

    pub fn macBookPro(allocator: std.mem.Allocator) DeviceInfo {
        var device = DeviceInfo.init(allocator);
        device.setModel("MacBookPro18,3", "MacBook Pro 14-inch");
        device.manufacturer = "Apple";
        device.setPlatform(.macos, .laptop);
        device.setOSVersion(14, 0, 0);
        device.setScreen(3024, 1964, 2.0);
        device.capabilities.has_cellular = false;
        device.capabilities.has_gps = false;
        return device;
    }

    pub fn simulator(allocator: std.mem.Allocator) DeviceInfo {
        var device = DeviceInfo.init(allocator);
        device.setModel("x86_64", "iOS Simulator");
        device.manufacturer = "Apple";
        device.setPlatform(.ios, .phone);
        device.setSimulator(true);
        return device;
    }
};

// ============================================================================
// Quick Device Utilities
// ============================================================================

/// Quick device utilities
pub const QuickDevice = struct {
    /// Get current platform
    pub fn platform() Platform {
        return Platform.current();
    }

    /// Is running on iOS
    pub fn isiOS() bool {
        return Platform.current() == .ios;
    }

    /// Is running on Android
    pub fn isAndroid() bool {
        return Platform.current() == .android;
    }

    /// Is running on macOS
    pub fn isMacOS() bool {
        return Platform.current() == .macos;
    }

    /// Is running on mobile
    pub fn isMobile() bool {
        return Platform.current().isMobile();
    }

    /// Is running on desktop
    pub fn isDesktop() bool {
        return Platform.current().isDesktop();
    }

    /// Check if battery is low
    pub fn isBatteryLow(device: *const DeviceInfo) bool {
        return device.battery.isLow();
    }

    /// Check if should reduce animations
    pub fn shouldReduceAnimations(device: *const DeviceInfo) bool {
        return device.battery.shouldSavePower() or device.memory.isLow();
    }

    /// Check if high-quality mode is appropriate
    pub fn canUseHighQuality(device: *const DeviceInfo) bool {
        return !device.battery.shouldSavePower() and
            !device.memory.isLow() and
            device.screen.isHighDensity();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Platform basics" {
    const ios = Platform.ios;
    try std.testing.expectEqualStrings("iOS", ios.toString());
    try std.testing.expect(ios.isMobile());
    try std.testing.expect(!ios.isDesktop());
    try std.testing.expect(ios.isApple());

    const android = Platform.android;
    try std.testing.expect(android.isMobile());
    try std.testing.expect(!android.isApple());

    const macos = Platform.macos;
    try std.testing.expect(macos.isDesktop());
    try std.testing.expect(macos.isApple());
}

test "Platform current" {
    const current = Platform.current();
    try std.testing.expect(current != .unknown);
}

test "FormFactor basics" {
    const phone = FormFactor.phone;
    try std.testing.expectEqualStrings("phone", phone.toString());
    try std.testing.expect(phone.isMobile());
    try std.testing.expect(!phone.hasLargeScreen());

    const tablet = FormFactor.tablet;
    try std.testing.expect(tablet.isMobile());
    try std.testing.expect(tablet.hasLargeScreen());

    const desktop = FormFactor.desktop;
    try std.testing.expect(!desktop.isMobile());
    try std.testing.expect(desktop.hasLargeScreen());
}

test "Version creation" {
    const version = Version.init(1, 2, 3);
    try std.testing.expectEqual(@as(u32, 1), version.major);
    try std.testing.expectEqual(@as(u32, 2), version.minor);
    try std.testing.expectEqual(@as(u32, 3), version.patch);
}

test "Version comparison" {
    const v1 = Version.init(1, 0, 0);
    const v2 = Version.init(2, 0, 0);
    const v3 = Version.init(1, 1, 0);

    try std.testing.expect(v1.compare(v2) < 0);
    try std.testing.expect(v2.compare(v1) > 0);
    try std.testing.expect(v1.compare(v3) < 0);
    try std.testing.expect(v1.compare(v1) == 0);
}

test "Version isAtLeast" {
    const version = Version.init(17, 2, 0);
    try std.testing.expect(version.isAtLeast(17, 0));
    try std.testing.expect(version.isAtLeast(17, 2));
    try std.testing.expect(!version.isAtLeast(17, 3));
    try std.testing.expect(!version.isAtLeast(18, 0));
    try std.testing.expect(version.isAtLeast(16, 0));
}

test "Version format" {
    const version = Version.init(1, 2, 3);
    var buf: [32]u8 = undefined;
    const str = try version.format(&buf);
    try std.testing.expectEqualStrings("1.2.3", str);
}

test "Orientation basics" {
    const portrait = Orientation.portrait;
    try std.testing.expect(portrait.isPortrait());
    try std.testing.expect(!portrait.isLandscape());

    const landscape = Orientation.landscape_left;
    try std.testing.expect(landscape.isLandscape());
    try std.testing.expect(!landscape.isPortrait());
}

test "ScreenInfo creation" {
    const screen = ScreenInfo.init(1170, 2532, 3.0);
    try std.testing.expectEqual(@as(u32, 1170), screen.width);
    try std.testing.expectEqual(@as(u32, 2532), screen.height);
    try std.testing.expectEqual(@as(f32, 3.0), screen.scale);
}

test "ScreenInfo logical dimensions" {
    const screen = ScreenInfo.init(1170, 2532, 3.0);
    try std.testing.expectEqual(@as(u32, 390), screen.logicalWidth());
    try std.testing.expectEqual(@as(u32, 844), screen.logicalHeight());
}

test "ScreenInfo aspect ratio" {
    const screen = ScreenInfo.init(1080, 1920, 2.0);
    const ratio = screen.aspectRatio();
    try std.testing.expect(ratio > 0.5 and ratio < 0.6);
}

test "ScreenInfo isHighDensity" {
    const retina = ScreenInfo.init(1170, 2532, 3.0);
    try std.testing.expect(retina.isHighDensity());

    const standard = ScreenInfo.init(1080, 1920, 1.0);
    try std.testing.expect(!standard.isHighDensity());
}

test "ScreenInfo isHighRefreshRate" {
    var screen = ScreenInfo.init(1170, 2532, 3.0);
    screen.refresh_rate = 120;
    try std.testing.expect(screen.isHighRefreshRate());

    screen.refresh_rate = 60;
    try std.testing.expect(!screen.isHighRefreshRate());
}

test "BatteryState basics" {
    const charging = BatteryState.charging;
    try std.testing.expectEqualStrings("charging", charging.toString());
    try std.testing.expect(charging.isPluggedIn());

    const unplugged = BatteryState.unplugged;
    try std.testing.expect(!unplugged.isPluggedIn());
}

test "BatteryInfo creation" {
    const battery = BatteryInfo.init();
    try std.testing.expectEqual(@as(f32, 1.0), battery.level);
    try std.testing.expectEqual(BatteryState.unknown, battery.state);
}

test "BatteryInfo levelPercent" {
    var battery = BatteryInfo.init();
    battery.level = 0.75;
    try std.testing.expectEqual(@as(u32, 75), battery.levelPercent());
}

test "BatteryInfo isLow and isCritical" {
    var battery = BatteryInfo.init();

    battery.level = 0.5;
    try std.testing.expect(!battery.isLow());
    try std.testing.expect(!battery.isCritical());

    battery.level = 0.15;
    try std.testing.expect(battery.isLow());
    try std.testing.expect(!battery.isCritical());

    battery.level = 0.03;
    try std.testing.expect(battery.isLow());
    try std.testing.expect(battery.isCritical());
}

test "BatteryInfo shouldSavePower" {
    var battery = BatteryInfo.init();

    battery.level = 0.5;
    battery.low_power_mode = false;
    try std.testing.expect(!battery.shouldSavePower());

    battery.low_power_mode = true;
    try std.testing.expect(battery.shouldSavePower());

    battery.low_power_mode = false;
    battery.level = 0.1;
    try std.testing.expect(battery.shouldSavePower());
}

test "MemoryInfo basics" {
    var memory = MemoryInfo.init();
    memory.total = 8 * 1024 * 1024 * 1024; // 8GB
    memory.available = 2 * 1024 * 1024 * 1024; // 2GB
    memory.used = 6 * 1024 * 1024 * 1024; // 6GB

    try std.testing.expectEqual(@as(u64, 8192), memory.totalMB());
    try std.testing.expectEqual(@as(u64, 2048), memory.availableMB());
    try std.testing.expectEqual(@as(u32, 75), memory.usagePercent());
}

test "MemoryInfo isLow" {
    var memory = MemoryInfo.init();
    memory.total = 100;
    memory.available = 20;
    try std.testing.expect(!memory.isLow());

    memory.available = 5;
    try std.testing.expect(memory.isLow());
}

test "StorageInfo basics" {
    var storage = StorageInfo.init();
    storage.total = 256 * 1024 * 1024 * 1024; // 256GB
    storage.free = 64 * 1024 * 1024 * 1024; // 64GB
    storage.used = 192 * 1024 * 1024 * 1024; // 192GB

    try std.testing.expectEqual(@as(u32, 75), storage.usagePercent());
}

test "StorageInfo isLow" {
    var storage = StorageInfo.init();
    storage.total = 100;
    storage.free = 20;
    try std.testing.expect(!storage.isLow());

    storage.free = 5;
    try std.testing.expect(storage.isLow());
}

test "DeviceCapabilities basics" {
    const caps = DeviceCapabilities.init();
    try std.testing.expect(caps.has_camera);
    try std.testing.expect(caps.has_wifi);
    try std.testing.expect(caps.hasMotionTracking());
}

test "DeviceInfo initialization" {
    var device = DeviceInfo.init(std.testing.allocator);
    defer device.deinit();

    try std.testing.expectEqualStrings("Unknown", device.model);
    try std.testing.expect(device.platform != .unknown);
}

test "DeviceInfo setters" {
    var device = DeviceInfo.init(std.testing.allocator);
    defer device.deinit();

    device.setModel("iPhone15,2", "iPhone 14 Pro");
    try std.testing.expectEqualStrings("iPhone15,2", device.model);
    try std.testing.expectEqualStrings("iPhone 14 Pro", device.model_name);

    device.setPlatform(.ios, .phone);
    try std.testing.expectEqual(Platform.ios, device.platform);
    try std.testing.expectEqual(FormFactor.phone, device.form_factor);

    device.setOSVersion(17, 0, 1);
    try std.testing.expectEqual(@as(u32, 17), device.os_version.major);
}

test "DeviceInfo isMobile and isDesktop" {
    var device = DeviceInfo.init(std.testing.allocator);
    defer device.deinit();

    device.setPlatform(.ios, .phone);
    try std.testing.expect(device.isMobile());
    try std.testing.expect(!device.isDesktop());

    device.setPlatform(.macos, .laptop);
    try std.testing.expect(!device.isMobile());
    try std.testing.expect(device.isDesktop());
}

test "DeviceInfo isPhone and isTablet" {
    var device = DeviceInfo.init(std.testing.allocator);
    defer device.deinit();

    device.form_factor = .phone;
    try std.testing.expect(device.isPhone());
    try std.testing.expect(!device.isTablet());

    device.form_factor = .tablet;
    try std.testing.expect(!device.isPhone());
    try std.testing.expect(device.isTablet());
}

test "DeviceInfo battery and memory setters" {
    var device = DeviceInfo.init(std.testing.allocator);
    defer device.deinit();

    device.setBattery(0.75, .charging);
    try std.testing.expectEqual(@as(f32, 0.75), device.battery.level);
    try std.testing.expectEqual(BatteryState.charging, device.battery.state);

    device.setMemory(8000, 2000);
    try std.testing.expectEqual(@as(u64, 8000), device.memory.total);
    try std.testing.expectEqual(@as(u64, 2000), device.memory.available);
}

test "DevicePresets iPhone15Pro" {
    var device = DevicePresets.iPhone15Pro(std.testing.allocator);
    defer device.deinit();

    try std.testing.expectEqualStrings("iPhone 15 Pro", device.model_name);
    try std.testing.expectEqual(Platform.ios, device.platform);
    try std.testing.expectEqual(FormFactor.phone, device.form_factor);
    try std.testing.expect(device.capabilities.has_lidar);
}

test "DevicePresets iPadPro" {
    var device = DevicePresets.iPadPro(std.testing.allocator);
    defer device.deinit();

    try std.testing.expectEqual(FormFactor.tablet, device.form_factor);
    try std.testing.expect(device.isTablet());
}

test "DevicePresets macBookPro" {
    var device = DevicePresets.macBookPro(std.testing.allocator);
    defer device.deinit();

    try std.testing.expectEqual(Platform.macos, device.platform);
    try std.testing.expectEqual(FormFactor.laptop, device.form_factor);
    try std.testing.expect(device.isDesktop());
}

test "DevicePresets simulator" {
    var device = DevicePresets.simulator(std.testing.allocator);
    defer device.deinit();

    try std.testing.expect(device.is_simulator);
}

test "QuickDevice platform checks" {
    // Just verify these don't crash
    _ = QuickDevice.platform();
    _ = QuickDevice.isiOS();
    _ = QuickDevice.isAndroid();
    _ = QuickDevice.isMacOS();
    _ = QuickDevice.isMobile();
    _ = QuickDevice.isDesktop();
}

test "QuickDevice battery and performance checks" {
    var device = DeviceInfo.init(std.testing.allocator);
    defer device.deinit();

    device.setBattery(0.1, .unplugged);
    try std.testing.expect(QuickDevice.isBatteryLow(&device));
    try std.testing.expect(QuickDevice.shouldReduceAnimations(&device));

    device.setBattery(0.9, .unplugged);
    device.setMemory(8000, 4000);
    device.setScreen(1170, 2532, 3.0);
    try std.testing.expect(QuickDevice.canUseHighQuality(&device));
}
