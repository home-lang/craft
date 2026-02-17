//! Geolocation module for Craft
//! Provides cross-platform location services including GPS, geocoding, and distance calculations.
//! Abstracts platform-specific implementations:
//! - iOS: Core Location (CLLocationManager)
//! - Android: Fused Location Provider (Google Play Services)
//! - Desktop: IP-based geolocation or system location services

const std = @import("std");

/// Get current timestamp in milliseconds (Zig 0.16 compatible)
fn getTimestampMs() i64 {
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
        return @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000);
    }
    return 0;
}

/// Location accuracy levels
pub const LocationAccuracy = enum {
    /// Best accuracy (GPS), high battery usage
    best,
    /// High accuracy (~10m), moderate battery usage
    high,
    /// Medium accuracy (~100m), low battery usage
    medium,
    /// Low accuracy (~1km), minimal battery usage
    low,
    /// Coarse accuracy (~3km), very minimal battery usage
    coarse,

    /// Get approximate accuracy in meters
    pub fn meters(self: LocationAccuracy) f64 {
        return switch (self) {
            .best => 5.0,
            .high => 10.0,
            .medium => 100.0,
            .low => 1000.0,
            .coarse => 3000.0,
        };
    }
};

/// Location authorization status
pub const AuthorizationStatus = enum {
    /// Authorization status not determined
    not_determined,
    /// User denied location access
    denied,
    /// Location services restricted (parental controls, etc.)
    restricted,
    /// Authorized for foreground use only
    authorized_when_in_use,
    /// Authorized for background use
    authorized_always,

    /// Check if location access is granted
    pub fn isAuthorized(self: AuthorizationStatus) bool {
        return self == .authorized_when_in_use or self == .authorized_always;
    }
};

/// Geographic coordinate
pub const Coordinate = struct {
    /// Latitude in degrees (-90 to 90)
    latitude: f64,
    /// Longitude in degrees (-180 to 180)
    longitude: f64,

    /// Create a coordinate
    pub fn init(latitude: f64, longitude: f64) Coordinate {
        return .{
            .latitude = std.math.clamp(latitude, -90.0, 90.0),
            .longitude = std.math.clamp(longitude, -180.0, 180.0),
        };
    }

    /// Earth's radius in meters
    const EARTH_RADIUS: f64 = 6371000.0;

    /// Calculate distance to another coordinate using Haversine formula
    pub fn distanceTo(self: Coordinate, other: Coordinate) f64 {
        const lat1 = std.math.degreesToRadians(self.latitude);
        const lat2 = std.math.degreesToRadians(other.latitude);
        const delta_lat = std.math.degreesToRadians(other.latitude - self.latitude);
        const delta_lon = std.math.degreesToRadians(other.longitude - self.longitude);

        const a = std.math.sin(delta_lat / 2.0) * std.math.sin(delta_lat / 2.0) +
            std.math.cos(lat1) * std.math.cos(lat2) *
                std.math.sin(delta_lon / 2.0) * std.math.sin(delta_lon / 2.0);

        const c = 2.0 * std.math.atan2(@sqrt(a), @sqrt(1.0 - a));

        return EARTH_RADIUS * c;
    }

    /// Calculate bearing to another coordinate (in degrees, 0-360)
    pub fn bearingTo(self: Coordinate, other: Coordinate) f64 {
        const lat1 = std.math.degreesToRadians(self.latitude);
        const lat2 = std.math.degreesToRadians(other.latitude);
        const delta_lon = std.math.degreesToRadians(other.longitude - self.longitude);

        const y = std.math.sin(delta_lon) * std.math.cos(lat2);
        const x = std.math.cos(lat1) * std.math.sin(lat2) -
            std.math.sin(lat1) * std.math.cos(lat2) * std.math.cos(delta_lon);

        var bearing = std.math.radiansToDegrees(std.math.atan2(y, x));
        bearing = @mod(bearing + 360.0, 360.0);
        return bearing;
    }

    /// Get compass direction to another coordinate
    pub fn directionTo(self: Coordinate, other: Coordinate) CompassDirection {
        const bearing = self.bearingTo(other);
        return CompassDirection.fromBearing(bearing);
    }

    /// Check if coordinate is valid
    pub fn isValid(self: Coordinate) bool {
        return self.latitude >= -90.0 and self.latitude <= 90.0 and
            self.longitude >= -180.0 and self.longitude <= 180.0;
    }

    /// Format as string (for debugging)
    pub fn format(self: Coordinate, buf: []u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "{d:.6}, {d:.6}", .{ self.latitude, self.longitude });
    }
};

/// Compass directions
pub const CompassDirection = enum {
    north,
    north_east,
    east,
    south_east,
    south,
    south_west,
    west,
    north_west,

    /// Get compass direction from bearing
    pub fn fromBearing(bearing: f64) CompassDirection {
        const normalized = @mod(bearing + 22.5, 360.0);
        const index: usize = @intFromFloat(normalized / 45.0);
        const directions = [_]CompassDirection{
            .north, .north_east, .east, .south_east,
            .south, .south_west, .west, .north_west,
        };
        return directions[index % 8];
    }

    /// Get abbreviation
    pub fn abbreviation(self: CompassDirection) []const u8 {
        return switch (self) {
            .north => "N",
            .north_east => "NE",
            .east => "E",
            .south_east => "SE",
            .south => "S",
            .south_west => "SW",
            .west => "W",
            .north_west => "NW",
        };
    }
};

/// Full location data
pub const Location = struct {
    /// Geographic coordinate
    coordinate: Coordinate,
    /// Altitude in meters (above sea level)
    altitude: ?f64 = null,
    /// Horizontal accuracy in meters
    horizontal_accuracy: ?f64 = null,
    /// Vertical accuracy in meters
    vertical_accuracy: ?f64 = null,
    /// Speed in meters per second
    speed: ?f64 = null,
    /// Course/heading in degrees (0-360)
    course: ?f64 = null,
    /// Timestamp (Unix time in milliseconds)
    timestamp: i64 = 0,
    /// Floor level (if available)
    floor: ?i32 = null,

    /// Create a location
    pub fn init(latitude: f64, longitude: f64) Location {
        return .{
            .coordinate = Coordinate.init(latitude, longitude),
            .timestamp = getTimestampMs(),
        };
    }

    /// Create with full data
    pub fn initFull(
        latitude: f64,
        longitude: f64,
        altitude: ?f64,
        horizontal_accuracy: ?f64,
        speed: ?f64,
        course: ?f64,
    ) Location {
        return .{
            .coordinate = Coordinate.init(latitude, longitude),
            .altitude = altitude,
            .horizontal_accuracy = horizontal_accuracy,
            .speed = speed,
            .course = course,
            .timestamp = getTimestampMs(),
        };
    }

    /// Check if location is recent (within given milliseconds)
    pub fn isRecent(self: Location, max_age_ms: i64) bool {
        const now = getTimestampMs();
        return (now - self.timestamp) <= max_age_ms;
    }

    /// Check if location meets accuracy requirement
    pub fn meetsAccuracy(self: Location, required: LocationAccuracy) bool {
        const accuracy = self.horizontal_accuracy orelse return false;
        return accuracy <= required.meters();
    }

    /// Get speed in km/h
    pub fn speedKmh(self: Location) ?f64 {
        const speed = self.speed orelse return null;
        return speed * 3.6;
    }

    /// Get speed in mph
    pub fn speedMph(self: Location) ?f64 {
        const speed = self.speed orelse return null;
        return speed * 2.237;
    }
};

/// Location error types
pub const LocationError = error{
    /// Location services disabled
    ServicesDisabled,
    /// Permission denied
    PermissionDenied,
    /// Location unavailable
    Unavailable,
    /// Request timed out
    Timeout,
    /// Network error (for geocoding)
    NetworkError,
    /// Invalid input
    InvalidInput,
    /// Rate limited
    RateLimited,
    /// Out of memory
    OutOfMemory,
};

/// Geocoding result
pub const GeocodingResult = struct {
    /// Formatted address
    formatted_address: ?[]const u8 = null,
    /// Street name
    street: ?[]const u8 = null,
    /// Street number
    street_number: ?[]const u8 = null,
    /// City/locality
    city: ?[]const u8 = null,
    /// State/province/region
    state: ?[]const u8 = null,
    /// Postal/ZIP code
    postal_code: ?[]const u8 = null,
    /// Country name
    country: ?[]const u8 = null,
    /// Country code (ISO 3166-1 alpha-2)
    country_code: ?[]const u8 = null,
    /// Coordinate (for forward geocoding)
    coordinate: ?Coordinate = null,

    /// Simulated result for testing
    pub fn simulated() GeocodingResult {
        return .{
            .formatted_address = "1 Infinite Loop, Cupertino, CA 95014, USA",
            .street = "Infinite Loop",
            .street_number = "1",
            .city = "Cupertino",
            .state = "California",
            .postal_code = "95014",
            .country = "United States",
            .country_code = "US",
            .coordinate = Coordinate.init(37.3318, -122.0312),
        };
    }
};

/// Region for monitoring
pub const Region = struct {
    /// Region identifier
    identifier: []const u8,
    /// Center coordinate
    center: Coordinate,
    /// Radius in meters
    radius: f64,
    /// Notify on entry
    notify_on_entry: bool = true,
    /// Notify on exit
    notify_on_exit: bool = true,

    /// Create a region
    pub fn init(identifier: []const u8, center: Coordinate, radius: f64) Region {
        return .{
            .identifier = identifier,
            .center = center,
            .radius = radius,
        };
    }

    /// Check if coordinate is inside region
    pub fn contains(self: Region, coordinate: Coordinate) bool {
        const distance = self.center.distanceTo(coordinate);
        return distance <= self.radius;
    }
};

/// Region event type
pub const RegionEvent = enum {
    /// Entered the region
    enter,
    /// Exited the region
    exit,
};

/// Location update callback
pub const LocationCallback = *const fn (location: Location) void;

/// Location error callback
pub const ErrorCallback = *const fn (err: LocationError) void;

/// Region event callback
pub const RegionCallback = *const fn (region: *const Region, event: RegionEvent) void;

/// Heading/compass data
pub const Heading = struct {
    /// Magnetic heading in degrees (0-360)
    magnetic_heading: f64,
    /// True heading in degrees (0-360, if available)
    true_heading: ?f64 = null,
    /// Heading accuracy in degrees
    accuracy: ?f64 = null,
    /// Raw magnetometer X value
    x: ?f64 = null,
    /// Raw magnetometer Y value
    y: ?f64 = null,
    /// Raw magnetometer Z value
    z: ?f64 = null,
    /// Timestamp
    timestamp: i64 = 0,

    /// Create heading
    pub fn init(magnetic: f64) Heading {
        return .{
            .magnetic_heading = @mod(magnetic, 360.0),
            .timestamp = getTimestampMs(),
        };
    }

    /// Get compass direction
    pub fn direction(self: Heading) CompassDirection {
        return CompassDirection.fromBearing(self.magnetic_heading);
    }
};

/// Location manager for accessing location services
pub const LocationManager = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    // Configuration
    desired_accuracy: LocationAccuracy = .high,
    distance_filter: f64 = 10.0, // Minimum distance in meters before update

    // State
    is_updating: bool = false,
    last_location: ?Location = null,
    authorization_status: AuthorizationStatus = .not_determined,

    // Callbacks
    location_callback: ?LocationCallback = null,
    error_callback: ?ErrorCallback = null,

    // Region monitoring
    monitored_regions: std.ArrayListUnmanaged(Region) = .{},
    region_callback: ?RegionCallback = null,

    // Heading
    is_heading_updating: bool = false,
    last_heading: ?Heading = null,

    // Simulation
    simulated_location: ?Location = null,
    simulated_heading: ?Heading = null,

    /// Initialize location manager
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    /// Deinitialize
    pub fn deinit(self: *Self) void {
        self.monitored_regions.deinit(self.allocator);
    }

    /// Request location permission
    pub fn requestPermission(self: *Self, always: bool) void {
        _ = always;
        // Platform-specific permission request
        // Simulated: grant permission
        self.authorization_status = .authorized_when_in_use;
    }

    /// Check if location services are enabled
    pub fn isLocationServicesEnabled(_: *const Self) bool {
        // Platform check for location services
        return true; // Simulated
    }

    /// Get current authorization status
    pub fn getAuthorizationStatus(self: *const Self) AuthorizationStatus {
        return self.authorization_status;
    }

    /// Set desired accuracy
    pub fn setDesiredAccuracy(self: *Self, accuracy: LocationAccuracy) void {
        self.desired_accuracy = accuracy;
    }

    /// Set distance filter (minimum meters between updates)
    pub fn setDistanceFilter(self: *Self, meters: f64) void {
        self.distance_filter = meters;
    }

    /// Start location updates
    pub fn startUpdating(self: *Self) LocationError!void {
        if (!self.isLocationServicesEnabled()) {
            return LocationError.ServicesDisabled;
        }
        if (!self.authorization_status.isAuthorized()) {
            return LocationError.PermissionDenied;
        }
        self.is_updating = true;
    }

    /// Stop location updates
    pub fn stopUpdating(self: *Self) void {
        self.is_updating = false;
    }

    /// Request single location update
    pub fn requestLocation(self: *Self) LocationError!Location {
        if (!self.isLocationServicesEnabled()) {
            return LocationError.ServicesDisabled;
        }
        if (!self.authorization_status.isAuthorized()) {
            return LocationError.PermissionDenied;
        }

        // Return simulated location if set
        if (self.simulated_location) |loc| {
            self.last_location = loc;
            return loc;
        }

        // Simulated location (San Francisco)
        const location = Location.initFull(
            37.7749,
            -122.4194,
            10.0,
            self.desired_accuracy.meters(),
            0.0,
            0.0,
        );
        self.last_location = location;
        return location;
    }

    /// Get last known location
    pub fn getLastLocation(self: *const Self) ?Location {
        return self.last_location;
    }

    /// Start heading updates
    pub fn startHeadingUpdates(self: *Self) void {
        self.is_heading_updating = true;
    }

    /// Stop heading updates
    pub fn stopHeadingUpdates(self: *Self) void {
        self.is_heading_updating = false;
    }

    /// Get current heading
    pub fn getHeading(self: *Self) ?Heading {
        if (self.simulated_heading) |h| {
            self.last_heading = h;
            return h;
        }
        // Simulated heading (North)
        const heading = Heading.init(0.0);
        self.last_heading = heading;
        return heading;
    }

    /// Start monitoring a region
    pub fn startMonitoring(self: *Self, region: Region) LocationError!void {
        // Check for duplicate
        for (self.monitored_regions.items) |r| {
            if (std.mem.eql(u8, r.identifier, region.identifier)) {
                return; // Already monitoring
            }
        }
        self.monitored_regions.append(self.allocator, region) catch return LocationError.OutOfMemory;
    }

    /// Stop monitoring a region
    pub fn stopMonitoring(self: *Self, identifier: []const u8) void {
        var i: usize = 0;
        while (i < self.monitored_regions.items.len) {
            if (std.mem.eql(u8, self.monitored_regions.items[i].identifier, identifier)) {
                _ = self.monitored_regions.swapRemove(i);
                return;
            }
            i += 1;
        }
    }

    /// Get monitored regions
    pub fn getMonitoredRegions(self: *const Self) []const Region {
        return self.monitored_regions.items;
    }

    /// Check if currently in region
    pub fn isInRegion(self: *const Self, identifier: []const u8) bool {
        const location = self.last_location orelse return false;
        for (self.monitored_regions.items) |region| {
            if (std.mem.eql(u8, region.identifier, identifier)) {
                return region.contains(location.coordinate);
            }
        }
        return false;
    }

    /// Set location callback
    pub fn setLocationCallback(self: *Self, callback: ?LocationCallback) void {
        self.location_callback = callback;
    }

    /// Set error callback
    pub fn setErrorCallback(self: *Self, callback: ?ErrorCallback) void {
        self.error_callback = callback;
    }

    /// Set region callback
    pub fn setRegionCallback(self: *Self, callback: ?RegionCallback) void {
        self.region_callback = callback;
    }

    // Simulation methods for testing

    /// Simulate a location
    pub fn simulateLocation(self: *Self, latitude: f64, longitude: f64) void {
        self.simulated_location = Location.init(latitude, longitude);
        self.last_location = self.simulated_location;
    }

    /// Simulate a full location
    pub fn simulateFullLocation(self: *Self, location: Location) void {
        self.simulated_location = location;
        self.last_location = location;
    }

    /// Simulate heading
    pub fn simulateHeading(self: *Self, degrees: f64) void {
        self.simulated_heading = Heading.init(degrees);
        self.last_heading = self.simulated_heading;
    }

    /// Simulate authorization
    pub fn simulateAuthorization(self: *Self, status: AuthorizationStatus) void {
        self.authorization_status = status;
    }
};

/// Geocoder for address lookups
pub const Geocoder = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    cache: std.StringHashMapUnmanaged(GeocodingResult) = .{},

    /// Initialize geocoder
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    /// Deinitialize
    pub fn deinit(self: *Self) void {
        self.cache.deinit(self.allocator);
    }

    /// Forward geocode: address to coordinate
    pub fn geocode(self: *Self, address: []const u8) LocationError!GeocodingResult {
        _ = self;
        if (address.len == 0) {
            return LocationError.InvalidInput;
        }

        // Simulated geocoding
        var result = GeocodingResult.simulated();
        result.formatted_address = address;
        return result;
    }

    /// Reverse geocode: coordinate to address
    pub fn reverseGeocode(self: *Self, coordinate: Coordinate) LocationError!GeocodingResult {
        _ = self;
        if (!coordinate.isValid()) {
            return LocationError.InvalidInput;
        }

        // Simulated reverse geocoding
        var result = GeocodingResult.simulated();
        result.coordinate = coordinate;
        return result;
    }

    /// Check if geocoding is available
    pub fn isAvailable(_: *const Self) bool {
        return true; // Simulated
    }
};

/// Distance utilities
pub const Distance = struct {
    /// Convert meters to kilometers
    pub fn toKilometers(meters: f64) f64 {
        return meters / 1000.0;
    }

    /// Convert meters to miles
    pub fn toMiles(meters: f64) f64 {
        return meters / 1609.344;
    }

    /// Convert meters to feet
    pub fn toFeet(meters: f64) f64 {
        return meters * 3.28084;
    }

    /// Convert meters to yards
    pub fn toYards(meters: f64) f64 {
        return meters * 1.09361;
    }

    /// Convert kilometers to meters
    pub fn fromKilometers(km: f64) f64 {
        return km * 1000.0;
    }

    /// Convert miles to meters
    pub fn fromMiles(miles: f64) f64 {
        return miles * 1609.344;
    }

    /// Format distance as human-readable string
    pub fn formatMetric(meters: f64, buf: []u8) ![]const u8 {
        if (meters < 1000.0) {
            return std.fmt.bufPrint(buf, "{d:.0}m", .{meters});
        } else {
            return std.fmt.bufPrint(buf, "{d:.1}km", .{meters / 1000.0});
        }
    }

    /// Format distance as imperial string
    pub fn formatImperial(meters: f64, buf: []u8) ![]const u8 {
        const feet = toFeet(meters);
        if (feet < 5280.0) {
            return std.fmt.bufPrint(buf, "{d:.0}ft", .{feet});
        } else {
            return std.fmt.bufPrint(buf, "{d:.1}mi", .{toMiles(meters)});
        }
    }
};

/// Quick location utilities
pub const QuickLocation = struct {
    var manager: ?LocationManager = null;

    /// Get current location (blocking)
    pub fn current(allocator: std.mem.Allocator) LocationError!Location {
        if (manager == null) {
            manager = LocationManager.init(allocator);
            manager.?.requestPermission(false);
        }
        return manager.?.requestLocation();
    }

    /// Check if location services are available
    pub fn isAvailable() bool {
        return true; // Simulated
    }

    /// Calculate distance between two coordinates
    pub fn distance(lat1: f64, lon1: f64, lat2: f64, lon2: f64) f64 {
        const c1 = Coordinate.init(lat1, lon1);
        const c2 = Coordinate.init(lat2, lon2);
        return c1.distanceTo(c2);
    }
};

/// Common location presets
pub const LocationPresets = struct {
    /// San Francisco, CA
    pub fn sanFrancisco() Coordinate {
        return Coordinate.init(37.7749, -122.4194);
    }

    /// New York City, NY
    pub fn newYork() Coordinate {
        return Coordinate.init(40.7128, -74.0060);
    }

    /// London, UK
    pub fn london() Coordinate {
        return Coordinate.init(51.5074, -0.1278);
    }

    /// Tokyo, Japan
    pub fn tokyo() Coordinate {
        return Coordinate.init(35.6762, 139.6503);
    }

    /// Sydney, Australia
    pub fn sydney() Coordinate {
        return Coordinate.init(-33.8688, 151.2093);
    }

    /// Paris, France
    pub fn paris() Coordinate {
        return Coordinate.init(48.8566, 2.3522);
    }

    /// Apple Park (Cupertino)
    pub fn applePark() Coordinate {
        return Coordinate.init(37.3349, -122.0090);
    }

    /// Null Island (0, 0)
    pub fn nullIsland() Coordinate {
        return Coordinate.init(0.0, 0.0);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "LocationAccuracy meters" {
    try std.testing.expectEqual(@as(f64, 5.0), LocationAccuracy.best.meters());
    try std.testing.expectEqual(@as(f64, 10.0), LocationAccuracy.high.meters());
    try std.testing.expectEqual(@as(f64, 100.0), LocationAccuracy.medium.meters());
    try std.testing.expectEqual(@as(f64, 1000.0), LocationAccuracy.low.meters());
    try std.testing.expectEqual(@as(f64, 3000.0), LocationAccuracy.coarse.meters());
}

test "AuthorizationStatus isAuthorized" {
    try std.testing.expect(!AuthorizationStatus.not_determined.isAuthorized());
    try std.testing.expect(!AuthorizationStatus.denied.isAuthorized());
    try std.testing.expect(!AuthorizationStatus.restricted.isAuthorized());
    try std.testing.expect(AuthorizationStatus.authorized_when_in_use.isAuthorized());
    try std.testing.expect(AuthorizationStatus.authorized_always.isAuthorized());
}

test "Coordinate creation" {
    const coord = Coordinate.init(37.7749, -122.4194);
    try std.testing.expectApproxEqAbs(@as(f64, 37.7749), coord.latitude, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, -122.4194), coord.longitude, 0.0001);
}

test "Coordinate clamping" {
    const coord = Coordinate.init(100.0, -200.0);
    try std.testing.expectApproxEqAbs(@as(f64, 90.0), coord.latitude, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, -180.0), coord.longitude, 0.0001);
}

test "Coordinate isValid" {
    try std.testing.expect(Coordinate.init(37.7749, -122.4194).isValid());
    try std.testing.expect(Coordinate.init(0.0, 0.0).isValid());
    try std.testing.expect(Coordinate.init(-90.0, 180.0).isValid());
}

test "Coordinate distanceTo" {
    const sf = LocationPresets.sanFrancisco();
    const ny = LocationPresets.newYork();

    const distance = sf.distanceTo(ny);
    // SF to NY is approximately 4,129 km
    try std.testing.expect(distance > 4_000_000.0);
    try std.testing.expect(distance < 4_200_000.0);
}

test "Coordinate distanceTo same point" {
    const coord = Coordinate.init(37.7749, -122.4194);
    const distance = coord.distanceTo(coord);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), distance, 0.1);
}

test "Coordinate bearingTo" {
    const sf = LocationPresets.sanFrancisco();
    const ny = LocationPresets.newYork();

    const bearing = sf.bearingTo(ny);
    // SF to NY is roughly east-northeast
    try std.testing.expect(bearing > 60.0);
    try std.testing.expect(bearing < 80.0);
}

test "Coordinate directionTo" {
    const london = LocationPresets.london();
    const paris = LocationPresets.paris();

    const direction = london.directionTo(paris);
    try std.testing.expectEqual(CompassDirection.south_east, direction);
}

test "CompassDirection fromBearing" {
    try std.testing.expectEqual(CompassDirection.north, CompassDirection.fromBearing(0.0));
    try std.testing.expectEqual(CompassDirection.east, CompassDirection.fromBearing(90.0));
    try std.testing.expectEqual(CompassDirection.south, CompassDirection.fromBearing(180.0));
    try std.testing.expectEqual(CompassDirection.west, CompassDirection.fromBearing(270.0));
}

test "CompassDirection abbreviation" {
    try std.testing.expectEqualStrings("N", CompassDirection.north.abbreviation());
    try std.testing.expectEqualStrings("NE", CompassDirection.north_east.abbreviation());
    try std.testing.expectEqualStrings("SW", CompassDirection.south_west.abbreviation());
}

test "Location creation" {
    const loc = Location.init(37.7749, -122.4194);
    try std.testing.expectApproxEqAbs(@as(f64, 37.7749), loc.coordinate.latitude, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, -122.4194), loc.coordinate.longitude, 0.0001);
    try std.testing.expect(loc.timestamp > 0);
}

test "Location initFull" {
    const loc = Location.initFull(37.7749, -122.4194, 100.0, 10.0, 5.0, 90.0);
    try std.testing.expectEqual(@as(?f64, 100.0), loc.altitude);
    try std.testing.expectEqual(@as(?f64, 10.0), loc.horizontal_accuracy);
    try std.testing.expectEqual(@as(?f64, 5.0), loc.speed);
    try std.testing.expectEqual(@as(?f64, 90.0), loc.course);
}

test "Location isRecent" {
    const loc = Location.init(37.7749, -122.4194);
    try std.testing.expect(loc.isRecent(1000)); // Within 1 second
}

test "Location meetsAccuracy" {
    var loc = Location.init(37.7749, -122.4194);
    loc.horizontal_accuracy = 5.0;

    try std.testing.expect(loc.meetsAccuracy(.best));
    try std.testing.expect(loc.meetsAccuracy(.high));
    try std.testing.expect(loc.meetsAccuracy(.medium));
}

test "Location speedKmh" {
    var loc = Location.init(37.7749, -122.4194);
    loc.speed = 10.0; // 10 m/s

    const kmh = loc.speedKmh().?;
    try std.testing.expectApproxEqAbs(@as(f64, 36.0), kmh, 0.1);
}

test "Location speedMph" {
    var loc = Location.init(37.7749, -122.4194);
    loc.speed = 10.0; // 10 m/s

    const mph = loc.speedMph().?;
    try std.testing.expectApproxEqAbs(@as(f64, 22.37), mph, 0.1);
}

test "Region creation" {
    const center = LocationPresets.sanFrancisco();
    const region = Region.init("test_region", center, 100.0);

    try std.testing.expectEqualStrings("test_region", region.identifier);
    try std.testing.expectEqual(@as(f64, 100.0), region.radius);
    try std.testing.expect(region.notify_on_entry);
    try std.testing.expect(region.notify_on_exit);
}

test "Region contains" {
    const center = LocationPresets.sanFrancisco();
    const region = Region.init("sf", center, 1000.0); // 1km radius

    // Center should be inside
    try std.testing.expect(region.contains(center));

    // Far away point should be outside
    const ny = LocationPresets.newYork();
    try std.testing.expect(!region.contains(ny));
}

test "Heading creation" {
    const heading = Heading.init(45.0);
    try std.testing.expectApproxEqAbs(@as(f64, 45.0), heading.magnetic_heading, 0.001);
    try std.testing.expect(heading.timestamp > 0);
}

test "Heading direction" {
    try std.testing.expectEqual(CompassDirection.north, Heading.init(0.0).direction());
    try std.testing.expectEqual(CompassDirection.east, Heading.init(90.0).direction());
    try std.testing.expectEqual(CompassDirection.south, Heading.init(180.0).direction());
}

test "Heading normalization" {
    const heading = Heading.init(450.0);
    try std.testing.expectApproxEqAbs(@as(f64, 90.0), heading.magnetic_heading, 0.001);
}

test "LocationManager initialization" {
    var manager = LocationManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectEqual(LocationAccuracy.high, manager.desired_accuracy);
    try std.testing.expectEqual(@as(f64, 10.0), manager.distance_filter);
    try std.testing.expect(!manager.is_updating);
}

test "LocationManager requestPermission" {
    var manager = LocationManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectEqual(AuthorizationStatus.not_determined, manager.authorization_status);
    manager.requestPermission(false);
    try std.testing.expect(manager.authorization_status.isAuthorized());
}

test "LocationManager setDesiredAccuracy" {
    var manager = LocationManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setDesiredAccuracy(.best);
    try std.testing.expectEqual(LocationAccuracy.best, manager.desired_accuracy);
}

test "LocationManager setDistanceFilter" {
    var manager = LocationManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.setDistanceFilter(50.0);
    try std.testing.expectEqual(@as(f64, 50.0), manager.distance_filter);
}

test "LocationManager startUpdating requires permission" {
    var manager = LocationManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expectError(LocationError.PermissionDenied, manager.startUpdating());

    manager.requestPermission(false);
    try manager.startUpdating();
    try std.testing.expect(manager.is_updating);
}

test "LocationManager stopUpdating" {
    var manager = LocationManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.requestPermission(false);
    try manager.startUpdating();
    manager.stopUpdating();
    try std.testing.expect(!manager.is_updating);
}

test "LocationManager requestLocation" {
    var manager = LocationManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.requestPermission(false);
    const location = try manager.requestLocation();

    try std.testing.expect(location.coordinate.isValid());
    try std.testing.expect(manager.last_location != null);
}

test "LocationManager simulateLocation" {
    var manager = LocationManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.requestPermission(false);
    manager.simulateLocation(40.7128, -74.0060);

    const location = try manager.requestLocation();
    try std.testing.expectApproxEqAbs(@as(f64, 40.7128), location.coordinate.latitude, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, -74.0060), location.coordinate.longitude, 0.0001);
}

test "LocationManager heading" {
    var manager = LocationManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.startHeadingUpdates();
    try std.testing.expect(manager.is_heading_updating);

    const heading = manager.getHeading();
    try std.testing.expect(heading != null);

    manager.stopHeadingUpdates();
    try std.testing.expect(!manager.is_heading_updating);
}

test "LocationManager simulateHeading" {
    var manager = LocationManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.simulateHeading(90.0);
    const heading = manager.getHeading().?;
    try std.testing.expectApproxEqAbs(@as(f64, 90.0), heading.magnetic_heading, 0.001);
}

test "LocationManager region monitoring" {
    var manager = LocationManager.init(std.testing.allocator);
    defer manager.deinit();

    const region = Region.init("home", LocationPresets.sanFrancisco(), 100.0);
    try manager.startMonitoring(region);

    try std.testing.expectEqual(@as(usize, 1), manager.getMonitoredRegions().len);

    manager.stopMonitoring("home");
    try std.testing.expectEqual(@as(usize, 0), manager.getMonitoredRegions().len);
}

test "LocationManager isInRegion" {
    var manager = LocationManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.requestPermission(false);

    const sf = LocationPresets.sanFrancisco();
    const region = Region.init("sf", sf, 1000.0);
    try manager.startMonitoring(region);

    manager.simulateLocation(sf.latitude, sf.longitude);
    try std.testing.expect(manager.isInRegion("sf"));

    manager.simulateLocation(40.7128, -74.0060); // NY
    try std.testing.expect(!manager.isInRegion("sf"));
}

test "Geocoder initialization" {
    var geocoder = Geocoder.init(std.testing.allocator);
    defer geocoder.deinit();

    try std.testing.expect(geocoder.isAvailable());
}

test "Geocoder geocode" {
    var geocoder = Geocoder.init(std.testing.allocator);
    defer geocoder.deinit();

    const result = try geocoder.geocode("1 Infinite Loop, Cupertino, CA");
    try std.testing.expect(result.coordinate != null);
}

test "Geocoder geocode empty address" {
    var geocoder = Geocoder.init(std.testing.allocator);
    defer geocoder.deinit();

    try std.testing.expectError(LocationError.InvalidInput, geocoder.geocode(""));
}

test "Geocoder reverseGeocode" {
    var geocoder = Geocoder.init(std.testing.allocator);
    defer geocoder.deinit();

    const result = try geocoder.reverseGeocode(LocationPresets.sanFrancisco());
    try std.testing.expect(result.formatted_address != null);
}

test "GeocodingResult simulated" {
    const result = GeocodingResult.simulated();
    try std.testing.expect(result.formatted_address != null);
    try std.testing.expect(result.city != null);
    try std.testing.expect(result.country_code != null);
    try std.testing.expect(result.coordinate != null);
}

test "Distance conversions" {
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), Distance.toKilometers(1000.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 1000.0), Distance.fromKilometers(1.0), 0.001);

    try std.testing.expectApproxEqAbs(@as(f64, 1.0), Distance.toMiles(1609.344), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 1609.344), Distance.fromMiles(1.0), 0.001);

    try std.testing.expectApproxEqAbs(@as(f64, 3.28084), Distance.toFeet(1.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.09361), Distance.toYards(1.0), 0.001);
}

test "Distance formatMetric" {
    var buf: [32]u8 = undefined;

    const short = try Distance.formatMetric(500.0, &buf);
    try std.testing.expectEqualStrings("500m", short);

    const long = try Distance.formatMetric(5000.0, &buf);
    try std.testing.expectEqualStrings("5.0km", long);
}

test "Distance formatImperial" {
    var buf: [32]u8 = undefined;

    const short = try Distance.formatImperial(100.0, &buf);
    try std.testing.expect(std.mem.indexOf(u8, short, "ft") != null);

    const long = try Distance.formatImperial(5000.0, &buf);
    try std.testing.expect(std.mem.indexOf(u8, long, "mi") != null);
}

test "QuickLocation distance" {
    const dist = QuickLocation.distance(37.7749, -122.4194, 40.7128, -74.0060);
    try std.testing.expect(dist > 4_000_000.0);
}

test "QuickLocation isAvailable" {
    try std.testing.expect(QuickLocation.isAvailable());
}

test "LocationPresets" {
    const sf = LocationPresets.sanFrancisco();
    try std.testing.expectApproxEqAbs(@as(f64, 37.7749), sf.latitude, 0.001);

    const ny = LocationPresets.newYork();
    try std.testing.expectApproxEqAbs(@as(f64, 40.7128), ny.latitude, 0.001);

    const london = LocationPresets.london();
    try std.testing.expectApproxEqAbs(@as(f64, 51.5074), london.latitude, 0.001);

    const tokyo = LocationPresets.tokyo();
    try std.testing.expectApproxEqAbs(@as(f64, 35.6762), tokyo.latitude, 0.001);

    const nullIsland = LocationPresets.nullIsland();
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), nullIsland.latitude, 0.001);
}

test "Coordinate format" {
    var buf: [64]u8 = undefined;
    const coord = Coordinate.init(37.774900, -122.419400);
    const formatted = try coord.format(&buf);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "37.77") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "-122.41") != null);
}
