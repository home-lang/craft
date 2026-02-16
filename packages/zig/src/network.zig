const std = @import("std");
const builtin = @import("builtin");

/// Network/Connectivity Module
/// Provides cross-platform network status monitoring for iOS (NWPathMonitor),
/// Android (ConnectivityManager), and desktop platforms.
/// Includes reachability checking, connection type detection, and WiFi info.

// ============================================================================
// Connection Types
// ============================================================================

/// Network connection type
pub const ConnectionType = enum {
    /// No network connection
    none,
    /// WiFi connection
    wifi,
    /// Cellular connection
    cellular,
    /// Ethernet connection
    ethernet,
    /// Bluetooth connection
    bluetooth,
    /// VPN connection
    vpn,
    /// Other/unknown connection
    other,

    pub fn toString(self: ConnectionType) []const u8 {
        return switch (self) {
            .none => "none",
            .wifi => "wifi",
            .cellular => "cellular",
            .ethernet => "ethernet",
            .bluetooth => "bluetooth",
            .vpn => "vpn",
            .other => "other",
        };
    }

    pub fn displayName(self: ConnectionType) []const u8 {
        return switch (self) {
            .none => "No Connection",
            .wifi => "Wi-Fi",
            .cellular => "Cellular",
            .ethernet => "Ethernet",
            .bluetooth => "Bluetooth",
            .vpn => "VPN",
            .other => "Other",
        };
    }

    pub fn isConnected(self: ConnectionType) bool {
        return self != .none;
    }

    pub fn isWireless(self: ConnectionType) bool {
        return self == .wifi or self == .cellular or self == .bluetooth;
    }

    pub fn isMetered(self: ConnectionType) bool {
        return self == .cellular;
    }
};

/// Cellular technology type
pub const CellularType = enum {
    unknown,
    gprs, // 2G
    edge, // 2.5G
    cdma, // 2G
    wcdma, // 3G
    hspa, // 3.5G
    hspap, // 3.75G
    lte, // 4G
    lte_a, // 4G+
    nr, // 5G
    nr_nsa, // 5G NSA

    pub fn toString(self: CellularType) []const u8 {
        return switch (self) {
            .unknown => "Unknown",
            .gprs => "GPRS",
            .edge => "EDGE",
            .cdma => "CDMA",
            .wcdma => "WCDMA",
            .hspa => "HSPA",
            .hspap => "HSPA+",
            .lte => "LTE",
            .lte_a => "LTE-A",
            .nr => "5G",
            .nr_nsa => "5G NSA",
        };
    }

    pub fn generation(self: CellularType) u8 {
        return switch (self) {
            .unknown => 0,
            .gprs, .edge, .cdma => 2,
            .wcdma, .hspa, .hspap => 3,
            .lte, .lte_a => 4,
            .nr, .nr_nsa => 5,
        };
    }

    pub fn isFast(self: CellularType) bool {
        return self.generation() >= 4;
    }
};

// ============================================================================
// Network Status
// ============================================================================

/// Network reachability status
pub const ReachabilityStatus = enum {
    /// Network is reachable
    reachable,
    /// Network is not reachable
    not_reachable,
    /// Reachability is unknown
    unknown,

    pub fn toString(self: ReachabilityStatus) []const u8 {
        return switch (self) {
            .reachable => "reachable",
            .not_reachable => "not_reachable",
            .unknown => "unknown",
        };
    }

    pub fn isReachable(self: ReachabilityStatus) bool {
        return self == .reachable;
    }
};

/// Network quality level
pub const NetworkQuality = enum {
    /// Excellent connection
    excellent,
    /// Good connection
    good,
    /// Fair connection
    fair,
    /// Poor connection
    poor,
    /// No connection
    none,

    pub fn toString(self: NetworkQuality) []const u8 {
        return switch (self) {
            .excellent => "excellent",
            .good => "good",
            .fair => "fair",
            .poor => "poor",
            .none => "none",
        };
    }

    pub fn isUsable(self: NetworkQuality) bool {
        return self != .none and self != .poor;
    }

    pub fn isSufficientForVideo(self: NetworkQuality) bool {
        return self == .excellent or self == .good;
    }

    pub fn isSufficientForStreaming(self: NetworkQuality) bool {
        return self != .none and self != .poor;
    }
};

// ============================================================================
// Network State
// ============================================================================

/// Complete network state
pub const NetworkState = struct {
    /// Whether connected to any network
    is_connected: bool,
    /// Primary connection type
    connection_type: ConnectionType,
    /// Cellular type (if cellular)
    cellular_type: CellularType,
    /// Whether connection is expensive/metered
    is_expensive: bool,
    /// Whether connection is constrained (low data mode)
    is_constrained: bool,
    /// Whether VPN is active
    is_vpn_active: bool,
    /// Estimated quality
    quality: NetworkQuality,
    /// Reachability status
    reachability: ReachabilityStatus,

    pub fn init() NetworkState {
        return .{
            .is_connected = false,
            .connection_type = .none,
            .cellular_type = .unknown,
            .is_expensive = false,
            .is_constrained = false,
            .is_vpn_active = false,
            .quality = .none,
            .reachability = .unknown,
        };
    }

    pub fn connected(conn_type: ConnectionType) NetworkState {
        var state = init();
        state.is_connected = true;
        state.connection_type = conn_type;
        state.reachability = .reachable;
        state.quality = .good;
        state.is_expensive = conn_type.isMetered();
        return state;
    }

    pub fn wifi() NetworkState {
        return connected(.wifi);
    }

    pub fn cellular(cell_type: CellularType) NetworkState {
        var state = connected(.cellular);
        state.cellular_type = cell_type;
        state.is_expensive = true;
        if (cell_type.isFast()) {
            state.quality = .good;
        } else {
            state.quality = .fair;
        }
        return state;
    }

    /// Check if should download large files
    pub fn shouldDownloadLargeFiles(self: *const NetworkState) bool {
        return self.is_connected and !self.is_expensive and !self.is_constrained;
    }

    /// Check if should stream video
    pub fn shouldStreamVideo(self: *const NetworkState) bool {
        return self.is_connected and self.quality.isSufficientForVideo();
    }

    /// Check if should sync in background
    pub fn shouldSyncInBackground(self: *const NetworkState) bool {
        return self.is_connected and !self.is_constrained;
    }
};

// ============================================================================
// WiFi Information
// ============================================================================

/// WiFi information
pub const WiFiInfo = struct {
    /// SSID (network name)
    ssid: ?[]const u8,
    /// BSSID (access point MAC)
    bssid: ?[]const u8,
    /// Signal strength in dBm
    rssi: ?i32,
    /// Channel number
    channel: ?u32,
    /// Frequency in MHz
    frequency: ?u32,
    /// Is secure network
    is_secure: bool,
    /// Link speed in Mbps
    link_speed: ?u32,

    pub fn init() WiFiInfo {
        return .{
            .ssid = null,
            .bssid = null,
            .rssi = null,
            .channel = null,
            .frequency = null,
            .is_secure = true,
            .link_speed = null,
        };
    }

    /// Get signal quality from RSSI
    pub fn signalQuality(self: *const WiFiInfo) NetworkQuality {
        const rssi = self.rssi orelse return .none;

        if (rssi >= -50) return .excellent;
        if (rssi >= -60) return .good;
        if (rssi >= -70) return .fair;
        return .poor;
    }

    /// Get signal strength as percentage (0-100)
    pub fn signalPercent(self: *const WiFiInfo) u32 {
        const rssi = self.rssi orelse return 0;

        // RSSI typically ranges from -100 to -30 dBm
        if (rssi >= -30) return 100;
        if (rssi <= -100) return 0;

        // Map -100 to -30 to 0-100
        const normalized: i32 = rssi + 100;
        return @intCast(@as(u32, @intCast(normalized)) * 100 / 70);
    }

    /// Check if 5GHz network
    pub fn is5GHz(self: *const WiFiInfo) bool {
        if (self.frequency) |freq| {
            return freq >= 5000;
        }
        return false;
    }

    /// Check if 6GHz network (WiFi 6E)
    pub fn is6GHz(self: *const WiFiInfo) bool {
        if (self.frequency) |freq| {
            return freq >= 5925;
        }
        return false;
    }
};

// ============================================================================
// Network Errors
// ============================================================================

/// Network operation errors
pub const NetworkError = error{
    /// No network connection
    NoConnection,
    /// Connection timed out
    Timeout,
    /// Host not reachable
    HostUnreachable,
    /// DNS resolution failed
    DNSFailed,
    /// SSL/TLS error
    SSLError,
    /// Permission denied
    PermissionDenied,
    /// Network changed during operation
    NetworkChanged,
    /// Operation cancelled
    Cancelled,
    /// Unknown error
    Unknown,
};

// ============================================================================
// Network Monitor
// ============================================================================

/// Network change callback
pub const NetworkCallback = *const fn (state: NetworkState) void;

/// Network monitor
pub const NetworkMonitor = struct {
    allocator: std.mem.Allocator,
    current_state: NetworkState,
    wifi_info: WiFiInfo,
    is_monitoring: bool,
    callback: ?NetworkCallback,
    native_monitor: ?*anyopaque,

    // Simulated values for testing
    simulated_state: ?NetworkState,

    const Self = @This();

    /// Initialize network monitor
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .current_state = NetworkState.init(),
            .wifi_info = WiFiInfo.init(),
            .is_monitoring = false,
            .callback = null,
            .native_monitor = null,
            .simulated_state = null,
        };
    }

    /// Deinitialize
    pub fn deinit(self: *Self) void {
        if (self.is_monitoring) {
            self.stopMonitoring();
        }
    }

    /// Start monitoring network changes
    pub fn startMonitoring(self: *Self) void {
        if (self.is_monitoring) return;

        // Platform-specific monitoring
        if (comptime builtin.os.tag == .ios or builtin.os.tag.isDarwin()) {
            // NWPathMonitor *monitor = [[NWPathMonitor alloc] init];
            // [monitor setUpdateHandler:^(nw_path_t path) { ... }];
            // [monitor startWithQueue:dispatch_get_main_queue()];
        } else if (comptime builtin.os.tag == .linux and builtin.abi == .android) {
            // ConnectivityManager.registerDefaultNetworkCallback(...)
        }

        self.is_monitoring = true;
        self.refresh();
    }

    /// Stop monitoring network changes
    pub fn stopMonitoring(self: *Self) void {
        if (!self.is_monitoring) return;

        // Platform-specific cleanup
        if (comptime builtin.os.tag == .ios or builtin.os.tag.isDarwin()) {
            // [monitor cancel];
        }

        self.is_monitoring = false;
    }

    /// Refresh current network state
    pub fn refresh(self: *Self) void {
        // Use simulated state if set
        if (self.simulated_state) |state| {
            self.current_state = state;
            return;
        }

        // Platform-specific state detection
        if (comptime builtin.os.tag == .ios or builtin.os.tag.isDarwin()) {
            // Check NWPath status
        } else if (comptime builtin.os.tag == .linux and builtin.abi == .android) {
            // Check NetworkCapabilities
        }

        // Default to connected WiFi for testing
        self.current_state = NetworkState.wifi();
    }

    /// Get current network state
    pub fn getState(self: *Self) NetworkState {
        if (!self.is_monitoring) {
            self.refresh();
        }
        return self.current_state;
    }

    /// Check if connected to any network
    pub fn isConnected(self: *Self) bool {
        return self.getState().is_connected;
    }

    /// Get current connection type
    pub fn getConnectionType(self: *Self) ConnectionType {
        return self.getState().connection_type;
    }

    /// Check if on WiFi
    pub fn isOnWiFi(self: *Self) bool {
        return self.getConnectionType() == .wifi;
    }

    /// Check if on cellular
    pub fn isOnCellular(self: *Self) bool {
        return self.getConnectionType() == .cellular;
    }

    /// Check if connection is metered/expensive
    pub fn isExpensive(self: *Self) bool {
        return self.getState().is_expensive;
    }

    /// Check if in low data mode
    pub fn isConstrained(self: *Self) bool {
        return self.getState().is_constrained;
    }

    /// Get network quality
    pub fn getQuality(self: *Self) NetworkQuality {
        return self.getState().quality;
    }

    /// Get WiFi information
    pub fn getWiFiInfo(self: *Self) WiFiInfo {
        if (self.getConnectionType() != .wifi) {
            return WiFiInfo.init();
        }

        // Platform-specific WiFi info
        if (comptime builtin.os.tag == .ios) {
            // NEHotspotNetwork.fetchCurrent()
        } else if (comptime builtin.os.tag == .linux and builtin.abi == .android) {
            // WifiManager.getConnectionInfo()
        }

        return self.wifi_info;
    }

    /// Check reachability of a specific host
    pub fn checkReachability(self: *Self, host: []const u8) NetworkError!ReachabilityStatus {
        if (!self.isConnected()) {
            return .not_reachable;
        }

        // Platform-specific reachability check
        if (comptime builtin.os.tag == .ios or builtin.os.tag.isDarwin()) {
            // SCNetworkReachabilityCreateWithName
        }

        _ = host;
        return .reachable;
    }

    /// Set network change callback
    pub fn setCallback(self: *Self, callback: NetworkCallback) void {
        self.callback = callback;
    }

    // Testing/simulation methods

    /// Set simulated network state (for testing)
    pub fn setSimulatedState(self: *Self, state: NetworkState) void {
        self.simulated_state = state;
        self.current_state = state;

        // Notify callback
        if (self.callback) |cb| {
            cb(state);
        }
    }

    /// Clear simulated state
    pub fn clearSimulatedState(self: *Self) void {
        self.simulated_state = null;
    }

    /// Simulate WiFi connection
    pub fn simulateWiFi(self: *Self) void {
        self.setSimulatedState(NetworkState.wifi());
    }

    /// Simulate cellular connection
    pub fn simulateCellular(self: *Self, cell_type: CellularType) void {
        self.setSimulatedState(NetworkState.cellular(cell_type));
    }

    /// Simulate disconnection
    pub fn simulateDisconnect(self: *Self) void {
        self.setSimulatedState(NetworkState.init());
    }

    /// Set WiFi info (for testing)
    pub fn setWiFiInfo(self: *Self, ssid: ?[]const u8, rssi: ?i32) void {
        self.wifi_info.ssid = ssid;
        self.wifi_info.rssi = rssi;
    }
};

// ============================================================================
// Reachability Checker
// ============================================================================

/// Reachability checker for specific hosts
pub const ReachabilityChecker = struct {
    allocator: std.mem.Allocator,
    host: []const u8,
    last_status: ReachabilityStatus,
    check_interval_ms: u64,
    last_check_time: u64,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, host: []const u8) Self {
        return .{
            .allocator = allocator,
            .host = host,
            .last_status = .unknown,
            .check_interval_ms = 30000, // 30 seconds
            .last_check_time = 0,
        };
    }

    pub fn check(self: *Self) ReachabilityStatus {
        // Simplified check - in real implementation would do actual network test
        self.last_status = .reachable;
        self.last_check_time = getCurrentTimeMs();
        return self.last_status;
    }

    pub fn isReachable(self: *Self) bool {
        return self.check() == .reachable;
    }

    pub fn setCheckInterval(self: *Self, interval_ms: u64) void {
        self.check_interval_ms = interval_ms;
    }

    fn getCurrentTimeMs() u64 {
        var ts: std.c.timespec = undefined;
        if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
            if (comptime builtin.os.tag == .macos or builtin.os.tag.isDarwin()) {
                return @as(u64, @intCast(ts.sec)) * 1000 + @as(u64, @intCast(ts.nsec)) / 1_000_000;
            } else {
                return @as(u64, @intCast(ts.sec)) * 1000 + @as(u64, @intCast(ts.nsec)) / 1_000_000;
            }
        }
        return 0;
    }
};

// ============================================================================
// Network Presets
// ============================================================================

/// Common network state presets
pub const NetworkPresets = struct {
    pub fn wifi() NetworkState {
        return NetworkState.wifi();
    }

    pub fn cellularLTE() NetworkState {
        return NetworkState.cellular(.lte);
    }

    pub fn cellular5G() NetworkState {
        return NetworkState.cellular(.nr);
    }

    pub fn cellularSlow() NetworkState {
        var state = NetworkState.cellular(.edge);
        state.quality = .poor;
        return state;
    }

    pub fn offline() NetworkState {
        return NetworkState.init();
    }

    pub fn lowDataMode() NetworkState {
        var state = NetworkState.wifi();
        state.is_constrained = true;
        return state;
    }

    pub fn vpn() NetworkState {
        var state = NetworkState.wifi();
        state.is_vpn_active = true;
        return state;
    }
};

// ============================================================================
// Quick Network Utilities
// ============================================================================

/// Quick network utilities
pub const QuickNetwork = struct {
    /// Check if network is available
    pub fn isAvailable(monitor: *NetworkMonitor) bool {
        return monitor.isConnected();
    }

    /// Check if should download now
    pub fn shouldDownload(monitor: *NetworkMonitor) bool {
        const state = monitor.getState();
        return state.shouldDownloadLargeFiles();
    }

    /// Check if should stream now
    pub fn shouldStream(monitor: *NetworkMonitor) bool {
        const state = monitor.getState();
        return state.shouldStreamVideo();
    }

    /// Get recommended quality for streaming
    pub fn getRecommendedQuality(monitor: *NetworkMonitor) []const u8 {
        const quality = monitor.getQuality();
        return switch (quality) {
            .excellent => "1080p",
            .good => "720p",
            .fair => "480p",
            .poor => "360p",
            .none => "offline",
        };
    }

    /// Get connection description
    pub fn getConnectionDescription(monitor: *NetworkMonitor) []const u8 {
        const state = monitor.getState();
        if (!state.is_connected) return "Offline";

        if (state.connection_type == .wifi) {
            return if (state.is_vpn_active) "Wi-Fi (VPN)" else "Wi-Fi";
        }

        if (state.connection_type == .cellular) {
            return state.cellular_type.toString();
        }

        return state.connection_type.displayName();
    }

    /// Check if on fast connection
    pub fn isOnFastConnection(monitor: *NetworkMonitor) bool {
        const state = monitor.getState();
        if (!state.is_connected) return false;

        if (state.connection_type == .wifi) return true;
        if (state.connection_type == .cellular) {
            return state.cellular_type.isFast();
        }
        if (state.connection_type == .ethernet) return true;

        return false;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "ConnectionType basics" {
    const wifi = ConnectionType.wifi;
    try std.testing.expectEqualStrings("wifi", wifi.toString());
    try std.testing.expectEqualStrings("Wi-Fi", wifi.displayName());
    try std.testing.expect(wifi.isConnected());
    try std.testing.expect(wifi.isWireless());
    try std.testing.expect(!wifi.isMetered());

    const cellular = ConnectionType.cellular;
    try std.testing.expect(cellular.isMetered());
    try std.testing.expect(cellular.isWireless());

    const none = ConnectionType.none;
    try std.testing.expect(!none.isConnected());
}

test "CellularType basics" {
    const lte = CellularType.lte;
    try std.testing.expectEqualStrings("LTE", lte.toString());
    try std.testing.expectEqual(@as(u8, 4), lte.generation());
    try std.testing.expect(lte.isFast());

    const edge = CellularType.edge;
    try std.testing.expectEqual(@as(u8, 2), edge.generation());
    try std.testing.expect(!edge.isFast());

    const nr = CellularType.nr;
    try std.testing.expectEqual(@as(u8, 5), nr.generation());
    try std.testing.expect(nr.isFast());
}

test "ReachabilityStatus basics" {
    const reachable = ReachabilityStatus.reachable;
    try std.testing.expect(reachable.isReachable());
    try std.testing.expectEqualStrings("reachable", reachable.toString());

    const not_reachable = ReachabilityStatus.not_reachable;
    try std.testing.expect(!not_reachable.isReachable());
}

test "NetworkQuality basics" {
    const excellent = NetworkQuality.excellent;
    try std.testing.expect(excellent.isUsable());
    try std.testing.expect(excellent.isSufficientForVideo());

    const poor = NetworkQuality.poor;
    try std.testing.expect(!poor.isUsable());
    try std.testing.expect(!poor.isSufficientForVideo());

    const fair = NetworkQuality.fair;
    try std.testing.expect(fair.isUsable());
    try std.testing.expect(fair.isSufficientForStreaming());
}

test "NetworkState creation" {
    const state = NetworkState.init();
    try std.testing.expect(!state.is_connected);
    try std.testing.expectEqual(ConnectionType.none, state.connection_type);
}

test "NetworkState wifi" {
    const state = NetworkState.wifi();
    try std.testing.expect(state.is_connected);
    try std.testing.expectEqual(ConnectionType.wifi, state.connection_type);
    try std.testing.expect(!state.is_expensive);
}

test "NetworkState cellular" {
    const state = NetworkState.cellular(.lte);
    try std.testing.expect(state.is_connected);
    try std.testing.expectEqual(ConnectionType.cellular, state.connection_type);
    try std.testing.expectEqual(CellularType.lte, state.cellular_type);
    try std.testing.expect(state.is_expensive);
}

test "NetworkState shouldDownloadLargeFiles" {
    var wifi_state = NetworkState.wifi();
    try std.testing.expect(wifi_state.shouldDownloadLargeFiles());

    var cellular_state = NetworkState.cellular(.lte);
    try std.testing.expect(!cellular_state.shouldDownloadLargeFiles());

    wifi_state.is_constrained = true;
    try std.testing.expect(!wifi_state.shouldDownloadLargeFiles());
}

test "NetworkState shouldStreamVideo" {
    const wifi_state = NetworkState.wifi();
    try std.testing.expect(wifi_state.shouldStreamVideo());

    var poor_state = NetworkState.wifi();
    poor_state.quality = .poor;
    try std.testing.expect(!poor_state.shouldStreamVideo());
}

test "WiFiInfo creation" {
    const info = WiFiInfo.init();
    try std.testing.expect(info.ssid == null);
    try std.testing.expect(info.rssi == null);
}

test "WiFiInfo signalQuality" {
    var info = WiFiInfo.init();

    info.rssi = -45;
    try std.testing.expectEqual(NetworkQuality.excellent, info.signalQuality());

    info.rssi = -55;
    try std.testing.expectEqual(NetworkQuality.good, info.signalQuality());

    info.rssi = -65;
    try std.testing.expectEqual(NetworkQuality.fair, info.signalQuality());

    info.rssi = -80;
    try std.testing.expectEqual(NetworkQuality.poor, info.signalQuality());
}

test "WiFiInfo signalPercent" {
    var info = WiFiInfo.init();

    info.rssi = -30;
    try std.testing.expectEqual(@as(u32, 100), info.signalPercent());

    info.rssi = -100;
    try std.testing.expectEqual(@as(u32, 0), info.signalPercent());

    info.rssi = -65;
    const percent = info.signalPercent();
    try std.testing.expect(percent > 0 and percent < 100);
}

test "WiFiInfo is5GHz and is6GHz" {
    var info = WiFiInfo.init();

    info.frequency = 2437;
    try std.testing.expect(!info.is5GHz());
    try std.testing.expect(!info.is6GHz());

    info.frequency = 5180;
    try std.testing.expect(info.is5GHz());
    try std.testing.expect(!info.is6GHz());

    info.frequency = 5975;
    try std.testing.expect(info.is5GHz());
    try std.testing.expect(info.is6GHz());
}

test "NetworkMonitor initialization" {
    var monitor = NetworkMonitor.init(std.testing.allocator);
    defer monitor.deinit();

    try std.testing.expect(!monitor.is_monitoring);
}

test "NetworkMonitor startMonitoring" {
    var monitor = NetworkMonitor.init(std.testing.allocator);
    defer monitor.deinit();

    monitor.startMonitoring();
    try std.testing.expect(monitor.is_monitoring);

    monitor.stopMonitoring();
    try std.testing.expect(!monitor.is_monitoring);
}

test "NetworkMonitor getState" {
    var monitor = NetworkMonitor.init(std.testing.allocator);
    defer monitor.deinit();

    const state = monitor.getState();
    try std.testing.expect(state.is_connected);
}

test "NetworkMonitor isConnected" {
    var monitor = NetworkMonitor.init(std.testing.allocator);
    defer monitor.deinit();

    try std.testing.expect(monitor.isConnected());
}

test "NetworkMonitor simulateWiFi" {
    var monitor = NetworkMonitor.init(std.testing.allocator);
    defer monitor.deinit();

    monitor.simulateWiFi();
    try std.testing.expect(monitor.isOnWiFi());
    try std.testing.expect(!monitor.isOnCellular());
}

test "NetworkMonitor simulateCellular" {
    var monitor = NetworkMonitor.init(std.testing.allocator);
    defer monitor.deinit();

    monitor.simulateCellular(.lte);
    try std.testing.expect(monitor.isOnCellular());
    try std.testing.expect(!monitor.isOnWiFi());
    try std.testing.expectEqual(CellularType.lte, monitor.getState().cellular_type);
}

test "NetworkMonitor simulateDisconnect" {
    var monitor = NetworkMonitor.init(std.testing.allocator);
    defer monitor.deinit();

    monitor.simulateDisconnect();
    try std.testing.expect(!monitor.isConnected());
}

test "NetworkMonitor isExpensive" {
    var monitor = NetworkMonitor.init(std.testing.allocator);
    defer monitor.deinit();

    monitor.simulateWiFi();
    try std.testing.expect(!monitor.isExpensive());

    monitor.simulateCellular(.lte);
    try std.testing.expect(monitor.isExpensive());
}

test "NetworkMonitor getQuality" {
    var monitor = NetworkMonitor.init(std.testing.allocator);
    defer monitor.deinit();

    monitor.simulateWiFi();
    try std.testing.expectEqual(NetworkQuality.good, monitor.getQuality());
}

test "NetworkMonitor setWiFiInfo" {
    var monitor = NetworkMonitor.init(std.testing.allocator);
    defer monitor.deinit();

    monitor.setWiFiInfo("MyNetwork", -50);
    // WiFi info only valid when on WiFi
    monitor.simulateWiFi();
    try std.testing.expectEqualStrings("MyNetwork", monitor.wifi_info.ssid.?);
}

test "NetworkMonitor checkReachability" {
    var monitor = NetworkMonitor.init(std.testing.allocator);
    defer monitor.deinit();

    monitor.simulateWiFi();
    const status = try monitor.checkReachability("example.com");
    try std.testing.expectEqual(ReachabilityStatus.reachable, status);

    monitor.simulateDisconnect();
    const offline_status = try monitor.checkReachability("example.com");
    try std.testing.expectEqual(ReachabilityStatus.not_reachable, offline_status);
}

test "ReachabilityChecker basics" {
    var checker = ReachabilityChecker.init(std.testing.allocator, "example.com");

    try std.testing.expect(checker.isReachable());
    try std.testing.expectEqual(ReachabilityStatus.reachable, checker.last_status);
}

test "ReachabilityChecker setCheckInterval" {
    var checker = ReachabilityChecker.init(std.testing.allocator, "example.com");
    checker.setCheckInterval(60000);
    try std.testing.expectEqual(@as(u64, 60000), checker.check_interval_ms);
}

test "NetworkPresets wifi" {
    const state = NetworkPresets.wifi();
    try std.testing.expectEqual(ConnectionType.wifi, state.connection_type);
    try std.testing.expect(!state.is_expensive);
}

test "NetworkPresets cellularLTE" {
    const state = NetworkPresets.cellularLTE();
    try std.testing.expectEqual(CellularType.lte, state.cellular_type);
}

test "NetworkPresets cellular5G" {
    const state = NetworkPresets.cellular5G();
    try std.testing.expectEqual(CellularType.nr, state.cellular_type);
}

test "NetworkPresets offline" {
    const state = NetworkPresets.offline();
    try std.testing.expect(!state.is_connected);
}

test "NetworkPresets lowDataMode" {
    const state = NetworkPresets.lowDataMode();
    try std.testing.expect(state.is_constrained);
}

test "NetworkPresets vpn" {
    const state = NetworkPresets.vpn();
    try std.testing.expect(state.is_vpn_active);
}

test "QuickNetwork isAvailable" {
    var monitor = NetworkMonitor.init(std.testing.allocator);
    defer monitor.deinit();

    monitor.simulateWiFi();
    try std.testing.expect(QuickNetwork.isAvailable(&monitor));

    monitor.simulateDisconnect();
    try std.testing.expect(!QuickNetwork.isAvailable(&monitor));
}

test "QuickNetwork shouldDownload" {
    var monitor = NetworkMonitor.init(std.testing.allocator);
    defer monitor.deinit();

    monitor.simulateWiFi();
    try std.testing.expect(QuickNetwork.shouldDownload(&monitor));

    monitor.simulateCellular(.lte);
    try std.testing.expect(!QuickNetwork.shouldDownload(&monitor));
}

test "QuickNetwork getRecommendedQuality" {
    var monitor = NetworkMonitor.init(std.testing.allocator);
    defer monitor.deinit();

    monitor.setSimulatedState(blk: {
        var state = NetworkState.wifi();
        state.quality = .excellent;
        break :blk state;
    });
    try std.testing.expectEqualStrings("1080p", QuickNetwork.getRecommendedQuality(&monitor));

    monitor.setSimulatedState(blk: {
        var state = NetworkState.wifi();
        state.quality = .fair;
        break :blk state;
    });
    try std.testing.expectEqualStrings("480p", QuickNetwork.getRecommendedQuality(&monitor));
}

test "QuickNetwork getConnectionDescription" {
    var monitor = NetworkMonitor.init(std.testing.allocator);
    defer monitor.deinit();

    monitor.simulateWiFi();
    try std.testing.expectEqualStrings("Wi-Fi", QuickNetwork.getConnectionDescription(&monitor));

    monitor.simulateCellular(.lte);
    try std.testing.expectEqualStrings("LTE", QuickNetwork.getConnectionDescription(&monitor));

    monitor.simulateDisconnect();
    try std.testing.expectEqualStrings("Offline", QuickNetwork.getConnectionDescription(&monitor));
}

test "QuickNetwork isOnFastConnection" {
    var monitor = NetworkMonitor.init(std.testing.allocator);
    defer monitor.deinit();

    monitor.simulateWiFi();
    try std.testing.expect(QuickNetwork.isOnFastConnection(&monitor));

    monitor.simulateCellular(.lte);
    try std.testing.expect(QuickNetwork.isOnFastConnection(&monitor));

    monitor.simulateCellular(.edge);
    try std.testing.expect(!QuickNetwork.isOnFastConnection(&monitor));

    monitor.simulateDisconnect();
    try std.testing.expect(!QuickNetwork.isOnFastConnection(&monitor));
}
