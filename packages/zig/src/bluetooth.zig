//! Bluetooth Low Energy (BLE) Module for Craft Framework
//!
//! Cross-platform Bluetooth connectivity providing:
//! - Device scanning and discovery
//! - Connection management
//! - GATT services and characteristics
//! - Data transfer (read/write/notify)
//! - Peripheral mode support
//!
//! Platform implementations:
//! - iOS: CoreBluetooth framework
//! - Android: android.bluetooth.* APIs
//! - macOS: CoreBluetooth framework
//! - Windows: Windows.Devices.Bluetooth
//! - Linux: BlueZ D-Bus API

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// Enums
// ============================================================================

pub const BluetoothState = enum {
    unknown,
    resetting,
    unsupported,
    unauthorized,
    powered_off,
    powered_on,

    pub fn isAvailable(self: BluetoothState) bool {
        return self == .powered_on;
    }

    pub fn toString(self: BluetoothState) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .resetting => "resetting",
            .unsupported => "unsupported",
            .unauthorized => "unauthorized",
            .powered_off => "powered_off",
            .powered_on => "powered_on",
        };
    }
};

pub const ConnectionState = enum {
    disconnected,
    connecting,
    connected,
    disconnecting,

    pub fn isConnected(self: ConnectionState) bool {
        return self == .connected;
    }

    pub fn toString(self: ConnectionState) []const u8 {
        return switch (self) {
            .disconnected => "disconnected",
            .connecting => "connecting",
            .connected => "connected",
            .disconnecting => "disconnecting",
        };
    }
};

pub const ScanMode = enum {
    low_power,
    balanced,
    low_latency,
    opportunistic,

    pub fn toString(self: ScanMode) []const u8 {
        return switch (self) {
            .low_power => "low_power",
            .balanced => "balanced",
            .low_latency => "low_latency",
            .opportunistic => "opportunistic",
        };
    }
};

pub const CharacteristicProperty = enum(u8) {
    broadcast = 0x01,
    read = 0x02,
    write_without_response = 0x04,
    write = 0x08,
    notify = 0x10,
    indicate = 0x20,
    authenticated_signed_writes = 0x40,
    extended_properties = 0x80,

    pub fn toValue(self: CharacteristicProperty) u8 {
        return @intFromEnum(self);
    }
};

pub const WriteType = enum {
    with_response,
    without_response,

    pub fn toString(self: WriteType) []const u8 {
        return switch (self) {
            .with_response => "with_response",
            .without_response => "without_response",
        };
    }
};

pub const AdvertisementType = enum {
    connectable_undirected,
    connectable_directed,
    scannable_undirected,
    non_connectable_undirected,
    scan_response,

    pub fn toString(self: AdvertisementType) []const u8 {
        return switch (self) {
            .connectable_undirected => "connectable_undirected",
            .connectable_directed => "connectable_directed",
            .scannable_undirected => "scannable_undirected",
            .non_connectable_undirected => "non_connectable_undirected",
            .scan_response => "scan_response",
        };
    }
};

// ============================================================================
// Data Structures
// ============================================================================

pub const UUID = struct {
    data: [16]u8,

    const Self = @This();

    pub fn init(data: [16]u8) Self {
        return .{ .data = data };
    }

    pub fn fromString(uuid_str: []const u8) ?Self {
        var result: Self = .{ .data = undefined };
        var idx: usize = 0;
        var byte_idx: usize = 0;

        while (idx < uuid_str.len and byte_idx < 16) {
            if (uuid_str[idx] == '-') {
                idx += 1;
                continue;
            }

            if (idx + 1 >= uuid_str.len) break;

            const high = hexCharToNibble(uuid_str[idx]) orelse return null;
            const low = hexCharToNibble(uuid_str[idx + 1]) orelse return null;
            result.data[byte_idx] = (@as(u8, high) << 4) | low;

            idx += 2;
            byte_idx += 1;
        }

        if (byte_idx != 16) return null;
        return result;
    }

    pub fn from16Bit(short_uuid: u16) Self {
        var result: Self = .{ .data = .{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x00, 0x80, 0x00, 0x00, 0x80, 0x5F, 0x9B, 0x34, 0xFB } };
        result.data[2] = @truncate(short_uuid >> 8);
        result.data[3] = @truncate(short_uuid);
        return result;
    }

    pub fn toString(self: Self, buffer: []u8) []const u8 {
        if (buffer.len < 36) return "";

        const hex_chars = "0123456789abcdef";
        var out_idx: usize = 0;

        for (self.data, 0..) |byte, i| {
            if (i == 4 or i == 6 or i == 8 or i == 10) {
                buffer[out_idx] = '-';
                out_idx += 1;
            }
            buffer[out_idx] = hex_chars[byte >> 4];
            buffer[out_idx + 1] = hex_chars[byte & 0x0F];
            out_idx += 2;
        }

        return buffer[0..36];
    }

    pub fn eql(self: Self, other: Self) bool {
        return std.mem.eql(u8, &self.data, &other.data);
    }

    fn hexCharToNibble(c: u8) ?u4 {
        return switch (c) {
            '0'...'9' => @truncate(c - '0'),
            'a'...'f' => @truncate(c - 'a' + 10),
            'A'...'F' => @truncate(c - 'A' + 10),
            else => null,
        };
    }
};

pub const AdvertisementData = struct {
    local_name: ?[]const u8 = null,
    manufacturer_data: ?[]const u8 = null,
    service_uuids: []UUID = &[_]UUID{},
    service_data: ?[]const u8 = null,
    tx_power_level: ?i8 = null,
    is_connectable: bool = true,
    overflow_service_uuids: []UUID = &[_]UUID{},

    const Self = @This();

    pub fn hasService(self: Self, uuid: UUID) bool {
        for (self.service_uuids) |service_uuid| {
            if (service_uuid.eql(uuid)) return true;
        }
        return false;
    }
};

pub const ScannedDevice = struct {
    id: []const u8,
    name: ?[]const u8 = null,
    rssi: i16 = 0,
    advertisement_data: AdvertisementData = .{},
    timestamp: i64 = 0,
    is_connectable: bool = true,

    const Self = @This();

    pub fn signalStrength(self: Self) SignalStrength {
        if (self.rssi >= -50) return .excellent;
        if (self.rssi >= -60) return .good;
        if (self.rssi >= -70) return .fair;
        return .poor;
    }

    pub fn displayName(self: Self) []const u8 {
        if (self.name) |n| return n;
        if (self.advertisement_data.local_name) |ln| return ln;
        return self.id;
    }
};

pub const SignalStrength = enum {
    excellent,
    good,
    fair,
    poor,

    pub fn toString(self: SignalStrength) []const u8 {
        return switch (self) {
            .excellent => "excellent",
            .good => "good",
            .fair => "fair",
            .poor => "poor",
        };
    }
};

pub const Characteristic = struct {
    uuid: UUID,
    service_uuid: UUID,
    properties: u8 = 0,
    value: ?[]const u8 = null,
    is_notifying: bool = false,
    descriptors: []Descriptor = &[_]Descriptor{},

    const Self = @This();

    pub fn hasProperty(self: Self, property: CharacteristicProperty) bool {
        return (self.properties & property.toValue()) != 0;
    }

    pub fn canRead(self: Self) bool {
        return self.hasProperty(.read);
    }

    pub fn canWrite(self: Self) bool {
        return self.hasProperty(.write) or self.hasProperty(.write_without_response);
    }

    pub fn canNotify(self: Self) bool {
        return self.hasProperty(.notify) or self.hasProperty(.indicate);
    }
};

pub const Descriptor = struct {
    uuid: UUID,
    value: ?[]const u8 = null,
};

pub const Service = struct {
    uuid: UUID,
    is_primary: bool = true,
    characteristics: []Characteristic = &[_]Characteristic{},
    included_services: []UUID = &[_]UUID{},

    const Self = @This();

    pub fn findCharacteristic(self: Self, uuid: UUID) ?*const Characteristic {
        for (self.characteristics) |*char| {
            if (char.uuid.eql(uuid)) return char;
        }
        return null;
    }
};

pub const ConnectedDevice = struct {
    id: []const u8,
    name: ?[]const u8 = null,
    state: ConnectionState = .disconnected,
    services: []Service = &[_]Service{},
    mtu: u16 = 23,
    rssi: i16 = 0,
    connection_timestamp: i64 = 0,

    const Self = @This();

    pub fn findService(self: Self, uuid: UUID) ?*const Service {
        for (self.services) |*service| {
            if (service.uuid.eql(uuid)) return service;
        }
        return null;
    }

    pub fn findCharacteristic(self: Self, service_uuid: UUID, char_uuid: UUID) ?*const Characteristic {
        if (self.findService(service_uuid)) |service| {
            return service.findCharacteristic(char_uuid);
        }
        return null;
    }

    pub fn isConnected(self: Self) bool {
        return self.state == .connected;
    }
};

pub const ScanFilter = struct {
    service_uuids: []UUID = &[_]UUID{},
    name_prefix: ?[]const u8 = null,
    name_contains: ?[]const u8 = null,
    min_rssi: ?i16 = null,
    manufacturer_id: ?u16 = null,
    connectable_only: bool = false,

    const Self = @This();

    pub fn matches(self: Self, device: ScannedDevice) bool {
        if (self.connectable_only and !device.is_connectable) return false;

        if (self.min_rssi) |min| {
            if (device.rssi < min) return false;
        }

        if (self.name_prefix) |prefix| {
            const name = device.displayName();
            if (!std.mem.startsWith(u8, name, prefix)) return false;
        }

        if (self.name_contains) |substr| {
            const name = device.displayName();
            if (std.mem.indexOf(u8, name, substr) == null) return false;
        }

        if (self.service_uuids.len > 0) {
            var found = false;
            for (self.service_uuids) |filter_uuid| {
                if (device.advertisement_data.hasService(filter_uuid)) {
                    found = true;
                    break;
                }
            }
            if (!found) return false;
        }

        return true;
    }
};

pub const ScanOptions = struct {
    mode: ScanMode = .balanced,
    filter: ?ScanFilter = null,
    allow_duplicates: bool = false,
    timeout_ms: ?u32 = null,
    report_delay_ms: u32 = 0,
};

pub const ConnectionOptions = struct {
    auto_connect: bool = false,
    transport: Transport = .le,
    phy: PhyOption = .le_1m,
    timeout_ms: u32 = 30000,

    pub const Transport = enum {
        auto,
        le,
        br_edr,
    };

    pub const PhyOption = enum {
        le_1m,
        le_2m,
        le_coded,
    };
};

// ============================================================================
// Peripheral Mode Structures
// ============================================================================

pub const PeripheralService = struct {
    uuid: UUID,
    is_primary: bool = true,
    characteristics: std.ArrayListUnmanaged(PeripheralCharacteristic) = .{},

    const Self = @This();

    pub fn deinit(self: *Self, allocator: Allocator) void {
        self.characteristics.deinit(allocator);
    }

    pub fn addCharacteristic(self: *Self, allocator: Allocator, char: PeripheralCharacteristic) !void {
        try self.characteristics.append(allocator, char);
    }
};

pub const PeripheralCharacteristic = struct {
    uuid: UUID,
    properties: u8 = 0,
    value: []const u8 = &[_]u8{},
    permissions: Permissions = .{},
    descriptors: []Descriptor = &[_]Descriptor{},

    pub const Permissions = struct {
        readable: bool = true,
        writeable: bool = false,
        read_encrypted: bool = false,
        write_encrypted: bool = false,
    };
};

pub const AdvertisementOptions = struct {
    local_name: ?[]const u8 = null,
    service_uuids: []UUID = &[_]UUID{},
    manufacturer_data: ?[]const u8 = null,
    include_tx_power: bool = false,
    connectable: bool = true,
    interval_ms: u32 = 100,
};

// ============================================================================
// Event Types
// ============================================================================

pub const BluetoothEvent = union(enum) {
    state_changed: BluetoothState,
    device_discovered: ScannedDevice,
    device_connected: ConnectedDevice,
    device_disconnected: []const u8,
    services_discovered: struct { device_id: []const u8, services: []Service },
    characteristic_read: struct { device_id: []const u8, characteristic: Characteristic },
    characteristic_written: struct { device_id: []const u8, characteristic_uuid: UUID },
    characteristic_changed: struct { device_id: []const u8, characteristic: Characteristic },
    rssi_read: struct { device_id: []const u8, rssi: i16 },
    mtu_changed: struct { device_id: []const u8, mtu: u16 },
    scan_started: void,
    scan_stopped: void,
    advertising_started: void,
    advertising_stopped: void,
    connection_failed: struct { device_id: []const u8, reason: []const u8 },
};

// ============================================================================
// Bluetooth Central Manager
// ============================================================================

pub const BluetoothCentral = struct {
    allocator: Allocator,
    state: BluetoothState = .unknown,
    is_scanning: bool = false,
    discovered_devices: std.ArrayListUnmanaged(ScannedDevice) = .{},
    connected_devices: std.ArrayListUnmanaged(ConnectedDevice) = .{},
    event_callback: ?*const fn (BluetoothEvent) void = null,
    scan_options: ?ScanOptions = null,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        self.discovered_devices.deinit(self.allocator);
        self.connected_devices.deinit(self.allocator);
    }

    pub fn setEventCallback(self: *Self, callback: *const fn (BluetoothEvent) void) void {
        self.event_callback = callback;
    }

    pub fn getState(self: Self) BluetoothState {
        return self.state;
    }

    pub fn isAvailable(self: Self) bool {
        return self.state.isAvailable();
    }

    pub fn startScan(self: *Self, options: ScanOptions) !void {
        if (!self.isAvailable()) return error.BluetoothNotAvailable;
        if (self.is_scanning) return error.AlreadyScanning;

        self.scan_options = options;
        self.is_scanning = true;
        self.discovered_devices.clearRetainingCapacity();

        if (self.event_callback) |cb| {
            cb(.scan_started);
        }
    }

    pub fn stopScan(self: *Self) void {
        if (!self.is_scanning) return;

        self.is_scanning = false;
        self.scan_options = null;

        if (self.event_callback) |cb| {
            cb(.scan_stopped);
        }
    }

    pub fn connect(self: *Self, device_id: []const u8, options: ConnectionOptions) !void {
        _ = options;
        if (!self.isAvailable()) return error.BluetoothNotAvailable;

        for (self.connected_devices.items) |*device| {
            if (std.mem.eql(u8, device.id, device_id)) {
                if (device.state == .connected or device.state == .connecting) {
                    return error.AlreadyConnected;
                }
            }
        }

        const new_device = ConnectedDevice{
            .id = device_id,
            .state = .connecting,
            .connection_timestamp = getTimestampMs(),
        };

        try self.connected_devices.append(self.allocator, new_device);
    }

    pub fn disconnect(self: *Self, device_id: []const u8) !void {
        for (self.connected_devices.items, 0..) |*device, i| {
            if (std.mem.eql(u8, device.id, device_id)) {
                device.state = .disconnecting;
                _ = self.connected_devices.orderedRemove(i);

                if (self.event_callback) |cb| {
                    cb(.{ .device_disconnected = device_id });
                }
                return;
            }
        }
        return error.DeviceNotFound;
    }

    pub fn discoverServices(self: *Self, device_id: []const u8, service_uuids: ?[]UUID) !void {
        _ = service_uuids;
        for (self.connected_devices.items) |device| {
            if (std.mem.eql(u8, device.id, device_id)) {
                if (device.state != .connected) return error.DeviceNotConnected;
                return;
            }
        }
        return error.DeviceNotFound;
    }

    pub fn readCharacteristic(self: *Self, device_id: []const u8, service_uuid: UUID, char_uuid: UUID) !void {
        for (self.connected_devices.items) |device| {
            if (std.mem.eql(u8, device.id, device_id)) {
                if (device.state != .connected) return error.DeviceNotConnected;
                if (device.findCharacteristic(service_uuid, char_uuid)) |char| {
                    if (!char.canRead()) return error.CharacteristicNotReadable;
                    return;
                }
                return error.CharacteristicNotFound;
            }
        }
        return error.DeviceNotFound;
    }

    pub fn writeCharacteristic(self: *Self, device_id: []const u8, service_uuid: UUID, char_uuid: UUID, data: []const u8, write_type: WriteType) !void {
        _ = data;
        _ = write_type;
        for (self.connected_devices.items) |device| {
            if (std.mem.eql(u8, device.id, device_id)) {
                if (device.state != .connected) return error.DeviceNotConnected;
                if (device.findCharacteristic(service_uuid, char_uuid)) |char| {
                    if (!char.canWrite()) return error.CharacteristicNotWriteable;
                    return;
                }
                return error.CharacteristicNotFound;
            }
        }
        return error.DeviceNotFound;
    }

    pub fn setNotify(self: *Self, device_id: []const u8, service_uuid: UUID, char_uuid: UUID, enabled: bool) !void {
        _ = enabled;
        for (self.connected_devices.items) |device| {
            if (std.mem.eql(u8, device.id, device_id)) {
                if (device.state != .connected) return error.DeviceNotConnected;
                if (device.findCharacteristic(service_uuid, char_uuid)) |char| {
                    if (!char.canNotify()) return error.CharacteristicNotNotifiable;
                    return;
                }
                return error.CharacteristicNotFound;
            }
        }
        return error.DeviceNotFound;
    }

    pub fn readRssi(self: *Self, device_id: []const u8) !i16 {
        for (self.connected_devices.items) |device| {
            if (std.mem.eql(u8, device.id, device_id)) {
                if (device.state != .connected) return error.DeviceNotConnected;
                return device.rssi;
            }
        }
        return error.DeviceNotFound;
    }

    pub fn requestMtu(self: *Self, device_id: []const u8, mtu: u16) !void {
        _ = mtu;
        for (self.connected_devices.items) |device| {
            if (std.mem.eql(u8, device.id, device_id)) {
                if (device.state != .connected) return error.DeviceNotConnected;
                return;
            }
        }
        return error.DeviceNotFound;
    }

    pub fn getConnectedDevice(self: Self, device_id: []const u8) ?*const ConnectedDevice {
        for (self.connected_devices.items) |*device| {
            if (std.mem.eql(u8, device.id, device_id)) return device;
        }
        return null;
    }

    pub fn getDiscoveredDevices(self: Self) []const ScannedDevice {
        return self.discovered_devices.items;
    }

    pub fn getConnectedDeviceCount(self: Self) usize {
        var count: usize = 0;
        for (self.connected_devices.items) |device| {
            if (device.state == .connected) count += 1;
        }
        return count;
    }

    fn handleDeviceDiscovered(self: *Self, device: ScannedDevice) void {
        if (self.scan_options) |options| {
            if (options.filter) |filter| {
                if (!filter.matches(device)) return;
            }

            if (!options.allow_duplicates) {
                for (self.discovered_devices.items) |*existing| {
                    if (std.mem.eql(u8, existing.id, device.id)) {
                        existing.* = device;
                        return;
                    }
                }
            }
        }

        self.discovered_devices.append(self.allocator, device) catch return;

        if (self.event_callback) |cb| {
            cb(.{ .device_discovered = device });
        }
    }

    fn simulateStateChange(self: *Self, new_state: BluetoothState) void {
        self.state = new_state;
        if (self.event_callback) |cb| {
            cb(.{ .state_changed = new_state });
        }
    }
};

// ============================================================================
// Bluetooth Peripheral Manager
// ============================================================================

pub const BluetoothPeripheral = struct {
    allocator: Allocator,
    state: BluetoothState = .unknown,
    is_advertising: bool = false,
    services: std.ArrayListUnmanaged(PeripheralService) = .{},
    connected_centrals: std.ArrayListUnmanaged([]const u8) = .{},
    event_callback: ?*const fn (BluetoothEvent) void = null,
    advertisement_options: ?AdvertisementOptions = null,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        for (self.services.items) |*service| {
            service.deinit(self.allocator);
        }
        self.services.deinit(self.allocator);
        self.connected_centrals.deinit(self.allocator);
    }

    pub fn setEventCallback(self: *Self, callback: *const fn (BluetoothEvent) void) void {
        self.event_callback = callback;
    }

    pub fn getState(self: Self) BluetoothState {
        return self.state;
    }

    pub fn addService(self: *Self, service: PeripheralService) !void {
        try self.services.append(self.allocator, service);
    }

    pub fn removeService(self: *Self, uuid: UUID) !void {
        for (self.services.items, 0..) |service, i| {
            if (service.uuid.eql(uuid)) {
                var removed = self.services.orderedRemove(i);
                removed.deinit(self.allocator);
                return;
            }
        }
        return error.ServiceNotFound;
    }

    pub fn startAdvertising(self: *Self, options: AdvertisementOptions) !void {
        if (self.state != .powered_on) return error.BluetoothNotAvailable;
        if (self.is_advertising) return error.AlreadyAdvertising;

        self.advertisement_options = options;
        self.is_advertising = true;

        if (self.event_callback) |cb| {
            cb(.advertising_started);
        }
    }

    pub fn stopAdvertising(self: *Self) void {
        if (!self.is_advertising) return;

        self.is_advertising = false;
        self.advertisement_options = null;

        if (self.event_callback) |cb| {
            cb(.advertising_stopped);
        }
    }

    pub fn updateCharacteristicValue(self: *Self, service_uuid: UUID, char_uuid: UUID, value: []const u8) !void {
        for (self.services.items) |*service| {
            if (service.uuid.eql(service_uuid)) {
                for (service.characteristics.items) |*char| {
                    if (char.uuid.eql(char_uuid)) {
                        char.value = value;
                        return;
                    }
                }
                return error.CharacteristicNotFound;
            }
        }
        return error.ServiceNotFound;
    }

    pub fn notifyValue(self: *Self, service_uuid: UUID, char_uuid: UUID, value: []const u8, central_id: ?[]const u8) !void {
        _ = value;
        _ = central_id;

        for (self.services.items) |service| {
            if (service.uuid.eql(service_uuid)) {
                for (service.characteristics.items) |char| {
                    if (char.uuid.eql(char_uuid)) {
                        if ((char.properties & CharacteristicProperty.notify.toValue()) == 0 and
                            (char.properties & CharacteristicProperty.indicate.toValue()) == 0)
                        {
                            return error.CharacteristicNotNotifiable;
                        }
                        return;
                    }
                }
                return error.CharacteristicNotFound;
            }
        }
        return error.ServiceNotFound;
    }

    pub fn getConnectedCentralCount(self: Self) usize {
        return self.connected_centrals.items.len;
    }

    fn simulateStateChange(self: *Self, new_state: BluetoothState) void {
        self.state = new_state;
        if (self.event_callback) |cb| {
            cb(.{ .state_changed = new_state });
        }
    }
};

// ============================================================================
// Standard BLE Service UUIDs
// ============================================================================

pub const StandardServices = struct {
    pub const generic_access = UUID.from16Bit(0x1800);
    pub const generic_attribute = UUID.from16Bit(0x1801);
    pub const immediate_alert = UUID.from16Bit(0x1802);
    pub const link_loss = UUID.from16Bit(0x1803);
    pub const tx_power = UUID.from16Bit(0x1804);
    pub const current_time = UUID.from16Bit(0x1805);
    pub const health_thermometer = UUID.from16Bit(0x1809);
    pub const device_information = UUID.from16Bit(0x180A);
    pub const heart_rate = UUID.from16Bit(0x180D);
    pub const battery = UUID.from16Bit(0x180F);
    pub const blood_pressure = UUID.from16Bit(0x1810);
    pub const running_speed_cadence = UUID.from16Bit(0x1814);
    pub const cycling_speed_cadence = UUID.from16Bit(0x1816);
    pub const cycling_power = UUID.from16Bit(0x1818);
    pub const location_navigation = UUID.from16Bit(0x1819);
    pub const environmental_sensing = UUID.from16Bit(0x181A);
    pub const body_composition = UUID.from16Bit(0x181B);
    pub const user_data = UUID.from16Bit(0x181C);
    pub const weight_scale = UUID.from16Bit(0x181D);
    pub const bond_management = UUID.from16Bit(0x181E);
    pub const glucose = UUID.from16Bit(0x1808);
};

pub const StandardCharacteristics = struct {
    pub const device_name = UUID.from16Bit(0x2A00);
    pub const appearance = UUID.from16Bit(0x2A01);
    pub const peripheral_preferred_connection = UUID.from16Bit(0x2A04);
    pub const service_changed = UUID.from16Bit(0x2A05);
    pub const alert_level = UUID.from16Bit(0x2A06);
    pub const tx_power_level = UUID.from16Bit(0x2A07);
    pub const battery_level = UUID.from16Bit(0x2A19);
    pub const system_id = UUID.from16Bit(0x2A23);
    pub const model_number = UUID.from16Bit(0x2A24);
    pub const serial_number = UUID.from16Bit(0x2A25);
    pub const firmware_revision = UUID.from16Bit(0x2A26);
    pub const hardware_revision = UUID.from16Bit(0x2A27);
    pub const software_revision = UUID.from16Bit(0x2A28);
    pub const manufacturer_name = UUID.from16Bit(0x2A29);
    pub const heart_rate_measurement = UUID.from16Bit(0x2A37);
    pub const body_sensor_location = UUID.from16Bit(0x2A38);
    pub const heart_rate_control_point = UUID.from16Bit(0x2A39);
    pub const temperature_measurement = UUID.from16Bit(0x2A1C);
    pub const temperature_type = UUID.from16Bit(0x2A1D);
    pub const intermediate_temperature = UUID.from16Bit(0x2A1E);
};

// ============================================================================
// Utility Functions
// ============================================================================

pub fn parseManufacturerData(data: []const u8) ?struct { company_id: u16, payload: []const u8 } {
    if (data.len < 2) return null;
    const company_id = @as(u16, data[0]) | (@as(u16, data[1]) << 8);
    return .{
        .company_id = company_id,
        .payload = if (data.len > 2) data[2..] else &[_]u8{},
    };
}

pub fn formatMacAddress(bytes: [6]u8, buffer: []u8) []const u8 {
    if (buffer.len < 17) return "";

    const hex_chars = "0123456789ABCDEF";
    var out_idx: usize = 0;

    for (bytes, 0..) |byte, i| {
        if (i > 0) {
            buffer[out_idx] = ':';
            out_idx += 1;
        }
        buffer[out_idx] = hex_chars[byte >> 4];
        buffer[out_idx + 1] = hex_chars[byte & 0x0F];
        out_idx += 2;
    }

    return buffer[0..17];
}

pub fn parseMacAddress(mac_str: []const u8) ?[6]u8 {
    if (mac_str.len != 17) return null;

    var result: [6]u8 = undefined;
    var byte_idx: usize = 0;

    var i: usize = 0;
    while (i < mac_str.len and byte_idx < 6) {
        if (i > 0) {
            if (mac_str[i] != ':' and mac_str[i] != '-') return null;
            i += 1;
        }

        const high = UUID.hexCharToNibble(mac_str[i]) orelse return null;
        const low = UUID.hexCharToNibble(mac_str[i + 1]) orelse return null;
        result[byte_idx] = (@as(u8, high) << 4) | low;

        i += 2;
        byte_idx += 1;
    }

    return result;
}

fn getTimestampMs() i64 {
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
        return @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000);
    }
    return 0;
}

// ============================================================================
// Tests
// ============================================================================

test "UUID from 16-bit" {
    const uuid = UUID.from16Bit(0x180D);

    var buffer: [36]u8 = undefined;
    const str = uuid.toString(&buffer);

    try std.testing.expectEqualStrings("0000180d-0000-1000-8000-00805f9b34fb", str);
}

test "UUID from string" {
    const uuid = UUID.fromString("12345678-1234-5678-9abc-def012345678");
    try std.testing.expect(uuid != null);

    var buffer: [36]u8 = undefined;
    const str = uuid.?.toString(&buffer);
    try std.testing.expectEqualStrings("12345678-1234-5678-9abc-def012345678", str);
}

test "UUID equality" {
    const uuid1 = UUID.from16Bit(0x180D);
    const uuid2 = UUID.from16Bit(0x180D);
    const uuid3 = UUID.from16Bit(0x180F);

    try std.testing.expect(uuid1.eql(uuid2));
    try std.testing.expect(!uuid1.eql(uuid3));
}

test "BluetoothState availability" {
    try std.testing.expect(BluetoothState.powered_on.isAvailable());
    try std.testing.expect(!BluetoothState.powered_off.isAvailable());
    try std.testing.expect(!BluetoothState.unauthorized.isAvailable());
}

test "ConnectionState connected check" {
    try std.testing.expect(ConnectionState.connected.isConnected());
    try std.testing.expect(!ConnectionState.connecting.isConnected());
    try std.testing.expect(!ConnectionState.disconnected.isConnected());
}

test "CharacteristicProperty values" {
    try std.testing.expectEqual(@as(u8, 0x02), CharacteristicProperty.read.toValue());
    try std.testing.expectEqual(@as(u8, 0x08), CharacteristicProperty.write.toValue());
    try std.testing.expectEqual(@as(u8, 0x10), CharacteristicProperty.notify.toValue());
}

test "Characteristic property checks" {
    const char = Characteristic{
        .uuid = UUID.from16Bit(0x2A37),
        .service_uuid = UUID.from16Bit(0x180D),
        .properties = CharacteristicProperty.read.toValue() | CharacteristicProperty.notify.toValue(),
    };

    try std.testing.expect(char.canRead());
    try std.testing.expect(!char.canWrite());
    try std.testing.expect(char.canNotify());
    try std.testing.expect(char.hasProperty(.read));
    try std.testing.expect(char.hasProperty(.notify));
    try std.testing.expect(!char.hasProperty(.write));
}

test "SignalStrength from RSSI" {
    const device1 = ScannedDevice{ .id = "1", .rssi = -45 };
    const device2 = ScannedDevice{ .id = "2", .rssi = -55 };
    const device3 = ScannedDevice{ .id = "3", .rssi = -65 };
    const device4 = ScannedDevice{ .id = "4", .rssi = -80 };

    try std.testing.expectEqual(SignalStrength.excellent, device1.signalStrength());
    try std.testing.expectEqual(SignalStrength.good, device2.signalStrength());
    try std.testing.expectEqual(SignalStrength.fair, device3.signalStrength());
    try std.testing.expectEqual(SignalStrength.poor, device4.signalStrength());
}

test "ScannedDevice display name" {
    const device1 = ScannedDevice{ .id = "AA:BB:CC:DD:EE:FF", .name = "Heart Rate Monitor" };
    const device2 = ScannedDevice{ .id = "AA:BB:CC:DD:EE:FF" };

    try std.testing.expectEqualStrings("Heart Rate Monitor", device1.displayName());
    try std.testing.expectEqualStrings("AA:BB:CC:DD:EE:FF", device2.displayName());
}

test "ScanFilter matching" {
    const device = ScannedDevice{
        .id = "AA:BB:CC:DD:EE:FF",
        .name = "Heart Rate Monitor",
        .rssi = -55,
        .is_connectable = true,
    };

    const filter1 = ScanFilter{ .name_prefix = "Heart" };
    try std.testing.expect(filter1.matches(device));

    const filter2 = ScanFilter{ .name_prefix = "Blood" };
    try std.testing.expect(!filter2.matches(device));

    const filter3 = ScanFilter{ .min_rssi = -60 };
    try std.testing.expect(filter3.matches(device));

    const filter4 = ScanFilter{ .min_rssi = -50 };
    try std.testing.expect(!filter4.matches(device));

    const filter5 = ScanFilter{ .connectable_only = true };
    try std.testing.expect(filter5.matches(device));
}

test "ScanFilter name contains" {
    const device = ScannedDevice{
        .id = "AA:BB:CC:DD:EE:FF",
        .name = "Heart Rate Monitor Pro",
        .rssi = -55,
    };

    const filter1 = ScanFilter{ .name_contains = "Rate" };
    try std.testing.expect(filter1.matches(device));

    const filter2 = ScanFilter{ .name_contains = "Blood" };
    try std.testing.expect(!filter2.matches(device));
}

test "BluetoothCentral initialization" {
    var central = BluetoothCentral.init(std.testing.allocator);
    defer central.deinit();

    try std.testing.expectEqual(BluetoothState.unknown, central.getState());
    try std.testing.expect(!central.isAvailable());
    try std.testing.expect(!central.is_scanning);
}

test "BluetoothCentral scan requires powered on" {
    var central = BluetoothCentral.init(std.testing.allocator);
    defer central.deinit();

    const result = central.startScan(.{});
    try std.testing.expectError(error.BluetoothNotAvailable, result);
}

test "BluetoothCentral scan start/stop" {
    var central = BluetoothCentral.init(std.testing.allocator);
    defer central.deinit();

    central.state = .powered_on;

    try central.startScan(.{});
    try std.testing.expect(central.is_scanning);

    central.stopScan();
    try std.testing.expect(!central.is_scanning);
}

test "BluetoothCentral double scan prevention" {
    var central = BluetoothCentral.init(std.testing.allocator);
    defer central.deinit();

    central.state = .powered_on;

    try central.startScan(.{});
    const result = central.startScan(.{});
    try std.testing.expectError(error.AlreadyScanning, result);
}

test "BluetoothCentral connect" {
    var central = BluetoothCentral.init(std.testing.allocator);
    defer central.deinit();

    central.state = .powered_on;

    try central.connect("device-123", .{});
    try std.testing.expectEqual(@as(usize, 1), central.connected_devices.items.len);
}

test "BluetoothCentral disconnect" {
    var central = BluetoothCentral.init(std.testing.allocator);
    defer central.deinit();

    central.state = .powered_on;

    try central.connect("device-123", .{});
    try central.disconnect("device-123");
    try std.testing.expectEqual(@as(usize, 0), central.connected_devices.items.len);
}

test "BluetoothCentral disconnect not found" {
    var central = BluetoothCentral.init(std.testing.allocator);
    defer central.deinit();

    const result = central.disconnect("non-existent");
    try std.testing.expectError(error.DeviceNotFound, result);
}

test "BluetoothPeripheral initialization" {
    var peripheral = BluetoothPeripheral.init(std.testing.allocator);
    defer peripheral.deinit();

    try std.testing.expectEqual(BluetoothState.unknown, peripheral.getState());
    try std.testing.expect(!peripheral.is_advertising);
}

test "BluetoothPeripheral add service" {
    var peripheral = BluetoothPeripheral.init(std.testing.allocator);
    defer peripheral.deinit();

    const service = PeripheralService{
        .uuid = StandardServices.heart_rate,
        .is_primary = true,
    };

    try peripheral.addService(service);
    try std.testing.expectEqual(@as(usize, 1), peripheral.services.items.len);
}

test "BluetoothPeripheral remove service" {
    var peripheral = BluetoothPeripheral.init(std.testing.allocator);
    defer peripheral.deinit();

    const service = PeripheralService{
        .uuid = StandardServices.heart_rate,
        .is_primary = true,
    };

    try peripheral.addService(service);
    try peripheral.removeService(StandardServices.heart_rate);
    try std.testing.expectEqual(@as(usize, 0), peripheral.services.items.len);
}

test "BluetoothPeripheral advertising requires powered on" {
    var peripheral = BluetoothPeripheral.init(std.testing.allocator);
    defer peripheral.deinit();

    const result = peripheral.startAdvertising(.{});
    try std.testing.expectError(error.BluetoothNotAvailable, result);
}

test "BluetoothPeripheral start/stop advertising" {
    var peripheral = BluetoothPeripheral.init(std.testing.allocator);
    defer peripheral.deinit();

    peripheral.state = .powered_on;

    try peripheral.startAdvertising(.{ .local_name = "Test Device" });
    try std.testing.expect(peripheral.is_advertising);

    peripheral.stopAdvertising();
    try std.testing.expect(!peripheral.is_advertising);
}

test "Standard service UUIDs" {
    var buffer: [36]u8 = undefined;

    const heart_rate_str = StandardServices.heart_rate.toString(&buffer);
    try std.testing.expectEqualStrings("0000180d-0000-1000-8000-00805f9b34fb", heart_rate_str);

    const battery_str = StandardServices.battery.toString(&buffer);
    try std.testing.expectEqualStrings("0000180f-0000-1000-8000-00805f9b34fb", battery_str);
}

test "Standard characteristic UUIDs" {
    var buffer: [36]u8 = undefined;

    const hr_measurement_str = StandardCharacteristics.heart_rate_measurement.toString(&buffer);
    try std.testing.expectEqualStrings("00002a37-0000-1000-8000-00805f9b34fb", hr_measurement_str);
}

test "Service find characteristic" {
    const char1 = Characteristic{
        .uuid = StandardCharacteristics.heart_rate_measurement,
        .service_uuid = StandardServices.heart_rate,
        .properties = CharacteristicProperty.notify.toValue(),
    };

    const char2 = Characteristic{
        .uuid = StandardCharacteristics.body_sensor_location,
        .service_uuid = StandardServices.heart_rate,
        .properties = CharacteristicProperty.read.toValue(),
    };

    const service = Service{
        .uuid = StandardServices.heart_rate,
        .characteristics = @constCast(&[_]Characteristic{ char1, char2 }),
    };

    const found = service.findCharacteristic(StandardCharacteristics.heart_rate_measurement);
    try std.testing.expect(found != null);
    try std.testing.expect(found.?.uuid.eql(StandardCharacteristics.heart_rate_measurement));

    const not_found = service.findCharacteristic(StandardCharacteristics.battery_level);
    try std.testing.expect(not_found == null);
}

test "ConnectedDevice find service and characteristic" {
    const char1 = Characteristic{
        .uuid = StandardCharacteristics.heart_rate_measurement,
        .service_uuid = StandardServices.heart_rate,
        .properties = CharacteristicProperty.notify.toValue(),
    };

    const service = Service{
        .uuid = StandardServices.heart_rate,
        .characteristics = @constCast(&[_]Characteristic{char1}),
    };

    const device = ConnectedDevice{
        .id = "device-123",
        .state = .connected,
        .services = @constCast(&[_]Service{service}),
    };

    const found_service = device.findService(StandardServices.heart_rate);
    try std.testing.expect(found_service != null);

    const found_char = device.findCharacteristic(StandardServices.heart_rate, StandardCharacteristics.heart_rate_measurement);
    try std.testing.expect(found_char != null);

    const not_found = device.findService(StandardServices.battery);
    try std.testing.expect(not_found == null);
}

test "parse manufacturer data" {
    const data = [_]u8{ 0x4C, 0x00, 0x02, 0x15, 0xAA, 0xBB };
    const parsed = parseManufacturerData(&data);

    try std.testing.expect(parsed != null);
    try std.testing.expectEqual(@as(u16, 0x004C), parsed.?.company_id);
    try std.testing.expectEqual(@as(usize, 4), parsed.?.payload.len);
}

test "parse manufacturer data too short" {
    const data = [_]u8{0x4C};
    const parsed = parseManufacturerData(&data);
    try std.testing.expect(parsed == null);
}

test "format MAC address" {
    const mac = [6]u8{ 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF };
    var buffer: [17]u8 = undefined;

    const result = formatMacAddress(mac, &buffer);
    try std.testing.expectEqualStrings("AA:BB:CC:DD:EE:FF", result);
}

test "parse MAC address" {
    const mac = parseMacAddress("AA:BB:CC:DD:EE:FF");
    try std.testing.expect(mac != null);
    try std.testing.expectEqual([6]u8{ 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF }, mac.?);
}

test "parse MAC address with dash" {
    const mac = parseMacAddress("AA-BB-CC-DD-EE-FF");
    try std.testing.expect(mac != null);
    try std.testing.expectEqual([6]u8{ 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF }, mac.?);
}

test "parse MAC address invalid" {
    try std.testing.expect(parseMacAddress("AABBCCDDEEFF") == null);
    try std.testing.expect(parseMacAddress("AA:BB:CC") == null);
    try std.testing.expect(parseMacAddress("GG:BB:CC:DD:EE:FF") == null);
}

test "ConnectionOptions defaults" {
    const options = ConnectionOptions{};
    try std.testing.expectEqual(ConnectionOptions.Transport.le, options.transport);
    try std.testing.expectEqual(ConnectionOptions.PhyOption.le_1m, options.phy);
    try std.testing.expectEqual(@as(u32, 30000), options.timeout_ms);
}

test "ScanOptions defaults" {
    const options = ScanOptions{};
    try std.testing.expectEqual(ScanMode.balanced, options.mode);
    try std.testing.expect(options.filter == null);
    try std.testing.expect(!options.allow_duplicates);
}

test "AdvertisementData has service" {
    const service1 = UUID.from16Bit(0x180D);
    const service2 = UUID.from16Bit(0x180F);

    const ad = AdvertisementData{
        .service_uuids = @constCast(&[_]UUID{service1}),
    };

    try std.testing.expect(ad.hasService(service1));
    try std.testing.expect(!ad.hasService(service2));
}

test "BluetoothCentral event callback" {
    var central = BluetoothCentral.init(std.testing.allocator);
    defer central.deinit();

    const callback = struct {
        fn cb(_: BluetoothEvent) void {
            // Event received
        }
    }.cb;

    central.setEventCallback(callback);
    try std.testing.expect(central.event_callback != null);
}

test "PeripheralService add characteristic" {
    var service = PeripheralService{
        .uuid = StandardServices.heart_rate,
    };
    defer service.deinit(std.testing.allocator);

    const char = PeripheralCharacteristic{
        .uuid = StandardCharacteristics.heart_rate_measurement,
        .properties = CharacteristicProperty.notify.toValue(),
    };

    try service.addCharacteristic(std.testing.allocator, char);
    try std.testing.expectEqual(@as(usize, 1), service.characteristics.items.len);
}

test "ConnectedDevice isConnected" {
    const connected = ConnectedDevice{ .id = "1", .state = .connected };
    const disconnected = ConnectedDevice{ .id = "2", .state = .disconnected };
    const connecting = ConnectedDevice{ .id = "3", .state = .connecting };

    try std.testing.expect(connected.isConnected());
    try std.testing.expect(!disconnected.isConnected());
    try std.testing.expect(!connecting.isConnected());
}

test "ScanMode toString" {
    try std.testing.expectEqualStrings("low_power", ScanMode.low_power.toString());
    try std.testing.expectEqualStrings("balanced", ScanMode.balanced.toString());
    try std.testing.expectEqualStrings("low_latency", ScanMode.low_latency.toString());
}

test "WriteType toString" {
    try std.testing.expectEqualStrings("with_response", WriteType.with_response.toString());
    try std.testing.expectEqualStrings("without_response", WriteType.without_response.toString());
}

test "AdvertisementType toString" {
    try std.testing.expectEqualStrings("connectable_undirected", AdvertisementType.connectable_undirected.toString());
    try std.testing.expectEqualStrings("scan_response", AdvertisementType.scan_response.toString());
}

test "BluetoothPeripheral update characteristic value" {
    var peripheral = BluetoothPeripheral.init(std.testing.allocator);
    defer peripheral.deinit();

    var service = PeripheralService{
        .uuid = StandardServices.heart_rate,
    };

    const char = PeripheralCharacteristic{
        .uuid = StandardCharacteristics.heart_rate_measurement,
        .properties = CharacteristicProperty.notify.toValue(),
        .value = &[_]u8{ 0x00, 0x60 },
    };

    try service.addCharacteristic(std.testing.allocator, char);
    try peripheral.addService(service);

    try peripheral.updateCharacteristicValue(
        StandardServices.heart_rate,
        StandardCharacteristics.heart_rate_measurement,
        &[_]u8{ 0x00, 0x70 },
    );
}

test "BluetoothPeripheral update non-existent service" {
    var peripheral = BluetoothPeripheral.init(std.testing.allocator);
    defer peripheral.deinit();

    const result = peripheral.updateCharacteristicValue(
        StandardServices.heart_rate,
        StandardCharacteristics.heart_rate_measurement,
        &[_]u8{0x00},
    );

    try std.testing.expectError(error.ServiceNotFound, result);
}
