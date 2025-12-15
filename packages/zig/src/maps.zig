//! Cross-platform mapping and geolocation module
//! Provides abstractions for MapKit (iOS/macOS) and Google Maps (Android)

const std = @import("std");

/// Map provider platform
pub const MapProvider = enum {
    apple_maps,
    google_maps,
    mapbox,
    openstreetmap,
    here_maps,

    pub fn toString(self: MapProvider) []const u8 {
        return switch (self) {
            .apple_maps => "Apple Maps",
            .google_maps => "Google Maps",
            .mapbox => "Mapbox",
            .openstreetmap => "OpenStreetMap",
            .here_maps => "HERE Maps",
        };
    }

    pub fn supportsOffline(self: MapProvider) bool {
        return switch (self) {
            .apple_maps => true,
            .google_maps => true,
            .mapbox => true,
            .openstreetmap => false,
            .here_maps => true,
        };
    }
};

/// Map display type
pub const MapType = enum {
    standard,
    satellite,
    hybrid,
    terrain,
    muted_standard,
    satellite_flyover,
    hybrid_flyover,

    pub fn toString(self: MapType) []const u8 {
        return switch (self) {
            .standard => "Standard",
            .satellite => "Satellite",
            .hybrid => "Hybrid",
            .terrain => "Terrain",
            .muted_standard => "Muted Standard",
            .satellite_flyover => "Satellite Flyover",
            .hybrid_flyover => "Hybrid Flyover",
        };
    }

    pub fn is3D(self: MapType) bool {
        return self == .satellite_flyover or self == .hybrid_flyover;
    }
};

/// Geographic coordinate
pub const Coordinate = struct {
    latitude: f64,
    longitude: f64,

    pub const zero = Coordinate{ .latitude = 0, .longitude = 0 };

    pub fn init(latitude: f64, longitude: f64) Coordinate {
        return .{
            .latitude = std.math.clamp(latitude, -90.0, 90.0),
            .longitude = std.math.clamp(longitude, -180.0, 180.0),
        };
    }

    pub fn isValid(self: Coordinate) bool {
        return self.latitude >= -90.0 and self.latitude <= 90.0 and
            self.longitude >= -180.0 and self.longitude <= 180.0;
    }

    /// Calculate distance to another coordinate in meters using Haversine formula
    pub fn distanceTo(self: Coordinate, other: Coordinate) f64 {
        const earth_radius: f64 = 6371000.0; // meters
        const lat1 = self.latitude * std.math.pi / 180.0;
        const lat2 = other.latitude * std.math.pi / 180.0;
        const delta_lat = (other.latitude - self.latitude) * std.math.pi / 180.0;
        const delta_lon = (other.longitude - self.longitude) * std.math.pi / 180.0;

        const a = @sin(delta_lat / 2.0) * @sin(delta_lat / 2.0) +
            @cos(lat1) * @cos(lat2) * @sin(delta_lon / 2.0) * @sin(delta_lon / 2.0);
        const c = 2.0 * std.math.atan2(@sqrt(a), @sqrt(1.0 - a));

        return earth_radius * c;
    }

    /// Calculate bearing to another coordinate in degrees
    pub fn bearingTo(self: Coordinate, other: Coordinate) f64 {
        const lat1 = self.latitude * std.math.pi / 180.0;
        const lat2 = other.latitude * std.math.pi / 180.0;
        const delta_lon = (other.longitude - self.longitude) * std.math.pi / 180.0;

        const y = @sin(delta_lon) * @cos(lat2);
        const x = @cos(lat1) * @sin(lat2) - @sin(lat1) * @cos(lat2) * @cos(delta_lon);
        const bearing = std.math.atan2(y, x) * 180.0 / std.math.pi;

        return @mod(bearing + 360.0, 360.0);
    }

    /// Get coordinate at distance and bearing from this coordinate
    pub fn coordinateAtDistance(self: Coordinate, distance_meters: f64, bearing_degrees: f64) Coordinate {
        const earth_radius: f64 = 6371000.0;
        const lat1 = self.latitude * std.math.pi / 180.0;
        const lon1 = self.longitude * std.math.pi / 180.0;
        const bearing = bearing_degrees * std.math.pi / 180.0;
        const angular_distance = distance_meters / earth_radius;

        const lat2 = std.math.asin(@sin(lat1) * @cos(angular_distance) +
            @cos(lat1) * @sin(angular_distance) * @cos(bearing));
        const lon2 = lon1 + std.math.atan2(
            @sin(bearing) * @sin(angular_distance) * @cos(lat1),
            @cos(angular_distance) - @sin(lat1) * @sin(lat2),
        );

        return Coordinate.init(
            lat2 * 180.0 / std.math.pi,
            lon2 * 180.0 / std.math.pi,
        );
    }

    pub fn eql(self: Coordinate, other: Coordinate) bool {
        const epsilon: f64 = 0.000001;
        return @abs(self.latitude - other.latitude) < epsilon and
            @abs(self.longitude - other.longitude) < epsilon;
    }
};

/// Coordinate span (delta values for region)
pub const CoordinateSpan = struct {
    latitude_delta: f64,
    longitude_delta: f64,

    pub fn init(latitude_delta: f64, longitude_delta: f64) CoordinateSpan {
        return .{
            .latitude_delta = @max(0.0, latitude_delta),
            .longitude_delta = @max(0.0, longitude_delta),
        };
    }

    pub fn fromZoomLevel(zoom: f32, latitude: f64) CoordinateSpan {
        const scale = @as(f64, @floatCast(std.math.pow(f32, 2.0, 20.0 - zoom)));
        const lat_delta = 180.0 / scale;
        const lon_delta = 360.0 / scale * @cos(latitude * std.math.pi / 180.0);
        return .{
            .latitude_delta = lat_delta,
            .longitude_delta = lon_delta,
        };
    }
};

/// Map region (center + span)
pub const MapRegion = struct {
    center: Coordinate,
    span: CoordinateSpan,

    pub fn init(center: Coordinate, span: CoordinateSpan) MapRegion {
        return .{ .center = center, .span = span };
    }

    pub fn fromCenterAndRadius(center: Coordinate, radius_meters: f64) MapRegion {
        const lat_delta = (radius_meters / 111320.0) * 2.0;
        const lon_delta = (radius_meters / (111320.0 * @cos(center.latitude * std.math.pi / 180.0))) * 2.0;
        return .{
            .center = center,
            .span = CoordinateSpan.init(lat_delta, lon_delta),
        };
    }

    pub fn northEast(self: MapRegion) Coordinate {
        return Coordinate.init(
            self.center.latitude + self.span.latitude_delta / 2.0,
            self.center.longitude + self.span.longitude_delta / 2.0,
        );
    }

    pub fn southWest(self: MapRegion) Coordinate {
        return Coordinate.init(
            self.center.latitude - self.span.latitude_delta / 2.0,
            self.center.longitude - self.span.longitude_delta / 2.0,
        );
    }

    pub fn containsCoordinate(self: MapRegion, coord: Coordinate) bool {
        const sw = self.southWest();
        const ne = self.northEast();
        return coord.latitude >= sw.latitude and coord.latitude <= ne.latitude and
            coord.longitude >= sw.longitude and coord.longitude <= ne.longitude;
    }

    pub fn expand(self: MapRegion, factor: f64) MapRegion {
        return .{
            .center = self.center,
            .span = CoordinateSpan.init(
                self.span.latitude_delta * factor,
                self.span.longitude_delta * factor,
            ),
        };
    }
};

/// Bounding box for coordinates
pub const BoundingBox = struct {
    south_west: Coordinate,
    north_east: Coordinate,

    pub fn init(sw: Coordinate, ne: Coordinate) BoundingBox {
        return .{ .south_west = sw, .north_east = ne };
    }

    pub fn fromCoordinates(coords: []const Coordinate) ?BoundingBox {
        if (coords.len == 0) return null;

        var min_lat: f64 = 90.0;
        var max_lat: f64 = -90.0;
        var min_lon: f64 = 180.0;
        var max_lon: f64 = -180.0;

        for (coords) |coord| {
            min_lat = @min(min_lat, coord.latitude);
            max_lat = @max(max_lat, coord.latitude);
            min_lon = @min(min_lon, coord.longitude);
            max_lon = @max(max_lon, coord.longitude);
        }

        return .{
            .south_west = Coordinate.init(min_lat, min_lon),
            .north_east = Coordinate.init(max_lat, max_lon),
        };
    }

    pub fn center(self: BoundingBox) Coordinate {
        return Coordinate.init(
            (self.south_west.latitude + self.north_east.latitude) / 2.0,
            (self.south_west.longitude + self.north_east.longitude) / 2.0,
        );
    }

    pub fn toRegion(self: BoundingBox) MapRegion {
        return .{
            .center = self.center(),
            .span = CoordinateSpan.init(
                self.north_east.latitude - self.south_west.latitude,
                self.north_east.longitude - self.south_west.longitude,
            ),
        };
    }

    pub fn contains(self: BoundingBox, coord: Coordinate) bool {
        return coord.latitude >= self.south_west.latitude and
            coord.latitude <= self.north_east.latitude and
            coord.longitude >= self.south_west.longitude and
            coord.longitude <= self.north_east.longitude;
    }

    pub fn intersects(self: BoundingBox, other: BoundingBox) bool {
        return !(self.north_east.latitude < other.south_west.latitude or
            self.south_west.latitude > other.north_east.latitude or
            self.north_east.longitude < other.south_west.longitude or
            self.south_west.longitude > other.north_east.longitude);
    }
};

/// Map camera position
pub const MapCamera = struct {
    center: Coordinate,
    zoom: f32,
    pitch: f32, // tilt angle in degrees (0-90)
    heading: f32, // rotation in degrees (0-360)

    pub fn init(center: Coordinate) MapCamera {
        return .{
            .center = center,
            .zoom = 15.0,
            .pitch = 0.0,
            .heading = 0.0,
        };
    }

    pub fn withZoom(self: MapCamera, zoom: f32) MapCamera {
        var camera = self;
        camera.zoom = std.math.clamp(zoom, 0.0, 22.0);
        return camera;
    }

    pub fn withPitch(self: MapCamera, pitch: f32) MapCamera {
        var camera = self;
        camera.pitch = std.math.clamp(pitch, 0.0, 90.0);
        return camera;
    }

    pub fn withHeading(self: MapCamera, heading: f32) MapCamera {
        var camera = self;
        camera.heading = @mod(heading, 360.0);
        return camera;
    }

    pub fn lookingAt(target: Coordinate, from_distance: f64, pitch: f32, heading: f32) MapCamera {
        return .{
            .center = target,
            .zoom = distanceToZoom(from_distance),
            .pitch = std.math.clamp(pitch, 0.0, 90.0),
            .heading = @mod(heading, 360.0),
        };
    }

    fn distanceToZoom(distance: f64) f32 {
        // Approximate conversion from distance to zoom level
        const log_dist = @log2(distance);
        return @floatCast(std.math.clamp(20.0 - log_dist, 0.0, 22.0));
    }
};

/// Marker/annotation color
pub const MarkerColor = enum {
    red,
    green,
    blue,
    yellow,
    orange,
    purple,
    cyan,
    magenta,

    pub fn toRGB(self: MarkerColor) struct { r: u8, g: u8, b: u8 } {
        return switch (self) {
            .red => .{ .r = 255, .g = 59, .b = 48 },
            .green => .{ .r = 52, .g = 199, .b = 89 },
            .blue => .{ .r = 0, .g = 122, .b = 255 },
            .yellow => .{ .r = 255, .g = 204, .b = 0 },
            .orange => .{ .r = 255, .g = 149, .b = 0 },
            .purple => .{ .r = 175, .g = 82, .b = 222 },
            .cyan => .{ .r = 50, .g = 173, .b = 230 },
            .magenta => .{ .r = 255, .g = 45, .b = 85 },
        };
    }
};

/// Map marker/annotation
pub const MapMarker = struct {
    id: u64,
    coordinate: Coordinate,
    title: ?[]const u8,
    subtitle: ?[]const u8,
    color: MarkerColor,
    is_draggable: bool,
    is_selected: bool,
    custom_icon: ?[]const u8,
    anchor_x: f32, // 0.0-1.0, default 0.5
    anchor_y: f32, // 0.0-1.0, default 1.0

    pub fn init(id: u64, coordinate: Coordinate) MapMarker {
        return .{
            .id = id,
            .coordinate = coordinate,
            .title = null,
            .subtitle = null,
            .color = .red,
            .is_draggable = false,
            .is_selected = false,
            .custom_icon = null,
            .anchor_x = 0.5,
            .anchor_y = 1.0,
        };
    }

    pub fn withTitle(self: MapMarker, title: []const u8) MapMarker {
        var marker = self;
        marker.title = title;
        return marker;
    }

    pub fn withSubtitle(self: MapMarker, subtitle: []const u8) MapMarker {
        var marker = self;
        marker.subtitle = subtitle;
        return marker;
    }

    pub fn withColor(self: MapMarker, color: MarkerColor) MapMarker {
        var marker = self;
        marker.color = color;
        return marker;
    }

    pub fn draggable(self: MapMarker, is_draggable: bool) MapMarker {
        var marker = self;
        marker.is_draggable = is_draggable;
        return marker;
    }

    pub fn withCustomIcon(self: MapMarker, icon_path: []const u8) MapMarker {
        var marker = self;
        marker.custom_icon = icon_path;
        return marker;
    }

    pub fn withAnchor(self: MapMarker, x: f32, y: f32) MapMarker {
        var marker = self;
        marker.anchor_x = std.math.clamp(x, 0.0, 1.0);
        marker.anchor_y = std.math.clamp(y, 0.0, 1.0);
        return marker;
    }
};

/// Polyline stroke pattern
pub const StrokePattern = enum {
    solid,
    dashed,
    dotted,
    dash_dot,

    pub fn dashLengths(self: StrokePattern) []const f32 {
        return switch (self) {
            .solid => &[_]f32{},
            .dashed => &[_]f32{ 10.0, 5.0 },
            .dotted => &[_]f32{ 2.0, 2.0 },
            .dash_dot => &[_]f32{ 10.0, 5.0, 2.0, 5.0 },
        };
    }
};

/// Map polyline
pub const MapPolyline = struct {
    id: u64,
    coordinates: std.ArrayListUnmanaged(Coordinate),
    stroke_color: MarkerColor,
    stroke_width: f32,
    stroke_pattern: StrokePattern,
    is_geodesic: bool,
    z_index: i32,

    pub fn init(allocator: std.mem.Allocator, id: u64) MapPolyline {
        _ = allocator;
        return .{
            .id = id,
            .coordinates = .{},
            .stroke_color = .blue,
            .stroke_width = 3.0,
            .stroke_pattern = .solid,
            .is_geodesic = false,
            .z_index = 0,
        };
    }

    pub fn deinit(self: *MapPolyline, allocator: std.mem.Allocator) void {
        self.coordinates.deinit(allocator);
    }

    pub fn addPoint(self: *MapPolyline, allocator: std.mem.Allocator, coord: Coordinate) !void {
        try self.coordinates.append(allocator, coord);
    }

    pub fn withStrokeColor(self: MapPolyline, color: MarkerColor) MapPolyline {
        var polyline = self;
        polyline.stroke_color = color;
        return polyline;
    }

    pub fn withStrokeWidth(self: MapPolyline, width: f32) MapPolyline {
        var polyline = self;
        polyline.stroke_width = @max(0.5, width);
        return polyline;
    }

    pub fn geodesic(self: MapPolyline, is_geodesic: bool) MapPolyline {
        var polyline = self;
        polyline.is_geodesic = is_geodesic;
        return polyline;
    }

    pub fn totalDistance(self: *const MapPolyline) f64 {
        if (self.coordinates.items.len < 2) return 0.0;

        var total: f64 = 0.0;
        for (self.coordinates.items[0 .. self.coordinates.items.len - 1], 0..) |coord, i| {
            total += coord.distanceTo(self.coordinates.items[i + 1]);
        }
        return total;
    }

    pub fn getBounds(self: *const MapPolyline) ?BoundingBox {
        return BoundingBox.fromCoordinates(self.coordinates.items);
    }
};

/// Map polygon
pub const MapPolygon = struct {
    id: u64,
    exterior_ring: std.ArrayListUnmanaged(Coordinate),
    interior_rings: std.ArrayListUnmanaged(std.ArrayListUnmanaged(Coordinate)),
    fill_color: MarkerColor,
    fill_opacity: f32,
    stroke_color: MarkerColor,
    stroke_width: f32,
    z_index: i32,

    pub fn init(allocator: std.mem.Allocator, id: u64) MapPolygon {
        _ = allocator;
        return .{
            .id = id,
            .exterior_ring = .{},
            .interior_rings = .{},
            .fill_color = .blue,
            .fill_opacity = 0.3,
            .stroke_color = .blue,
            .stroke_width = 2.0,
            .z_index = 0,
        };
    }

    pub fn deinit(self: *MapPolygon, allocator: std.mem.Allocator) void {
        self.exterior_ring.deinit(allocator);
        for (self.interior_rings.items) |*ring| {
            ring.deinit(allocator);
        }
        self.interior_rings.deinit(allocator);
    }

    pub fn addExteriorPoint(self: *MapPolygon, allocator: std.mem.Allocator, coord: Coordinate) !void {
        try self.exterior_ring.append(allocator, coord);
    }

    pub fn withFillColor(self: MapPolygon, color: MarkerColor) MapPolygon {
        var polygon = self;
        polygon.fill_color = color;
        return polygon;
    }

    pub fn withFillOpacity(self: MapPolygon, opacity: f32) MapPolygon {
        var polygon = self;
        polygon.fill_opacity = std.math.clamp(opacity, 0.0, 1.0);
        return polygon;
    }

    pub fn withStroke(self: MapPolygon, color: MarkerColor, width: f32) MapPolygon {
        var polygon = self;
        polygon.stroke_color = color;
        polygon.stroke_width = @max(0.0, width);
        return polygon;
    }

    pub fn getArea(self: *const MapPolygon) f64 {
        // Shoelace formula for approximate area
        const coords = self.exterior_ring.items;
        if (coords.len < 3) return 0.0;

        var area: f64 = 0.0;
        const n = coords.len;
        for (0..n) |i| {
            const j = (i + 1) % n;
            area += coords[i].longitude * coords[j].latitude;
            area -= coords[j].longitude * coords[i].latitude;
        }
        // Convert to approximate square meters
        return @abs(area) * 0.5 * 111320.0 * 111320.0;
    }

    pub fn getBounds(self: *const MapPolygon) ?BoundingBox {
        return BoundingBox.fromCoordinates(self.exterior_ring.items);
    }
};

/// Circle overlay
pub const MapCircle = struct {
    id: u64,
    center: Coordinate,
    radius_meters: f64,
    fill_color: MarkerColor,
    fill_opacity: f32,
    stroke_color: MarkerColor,
    stroke_width: f32,

    pub fn init(id: u64, center: Coordinate, radius: f64) MapCircle {
        return .{
            .id = id,
            .center = center,
            .radius_meters = @max(0.0, radius),
            .fill_color = .blue,
            .fill_opacity = 0.2,
            .stroke_color = .blue,
            .stroke_width = 2.0,
        };
    }

    pub fn containsCoordinate(self: MapCircle, coord: Coordinate) bool {
        return self.center.distanceTo(coord) <= self.radius_meters;
    }

    pub fn getBounds(self: MapCircle) BoundingBox {
        const north = self.center.coordinateAtDistance(self.radius_meters, 0);
        const south = self.center.coordinateAtDistance(self.radius_meters, 180);
        const east = self.center.coordinateAtDistance(self.radius_meters, 90);
        const west = self.center.coordinateAtDistance(self.radius_meters, 270);

        return BoundingBox.init(
            Coordinate.init(south.latitude, west.longitude),
            Coordinate.init(north.latitude, east.longitude),
        );
    }
};

/// Transport type for routing
pub const TransportType = enum {
    automobile,
    walking,
    transit,
    cycling,

    pub fn toString(self: TransportType) []const u8 {
        return switch (self) {
            .automobile => "Driving",
            .walking => "Walking",
            .transit => "Transit",
            .cycling => "Cycling",
        };
    }

    pub fn averageSpeed(self: TransportType) f64 {
        return switch (self) {
            .automobile => 13.9, // ~50 km/h in m/s
            .walking => 1.4, // ~5 km/h
            .transit => 8.3, // ~30 km/h
            .cycling => 4.2, // ~15 km/h
        };
    }
};

/// Route step/maneuver
pub const RouteStep = struct {
    instruction: []const u8,
    distance_meters: f64,
    duration_seconds: f64,
    start_coordinate: Coordinate,
    end_coordinate: Coordinate,
    maneuver_type: ManeuverType,

    pub const ManeuverType = enum {
        depart,
        arrive,
        turn_left,
        turn_right,
        turn_slight_left,
        turn_slight_right,
        turn_sharp_left,
        turn_sharp_right,
        uturn,
        straight,
        merge,
        exit,
        roundabout,
        ferry,
    };
};

/// Calculated route
pub const Route = struct {
    name: ?[]const u8,
    distance_meters: f64,
    expected_duration_seconds: f64,
    transport_type: TransportType,
    polyline: std.ArrayListUnmanaged(Coordinate),
    steps: std.ArrayListUnmanaged(RouteStep),
    is_toll_road: bool,
    has_highways: bool,

    pub fn init(allocator: std.mem.Allocator) Route {
        _ = allocator;
        return .{
            .name = null,
            .distance_meters = 0,
            .expected_duration_seconds = 0,
            .transport_type = .automobile,
            .polyline = .{},
            .steps = .{},
            .is_toll_road = false,
            .has_highways = false,
        };
    }

    pub fn deinit(self: *Route, allocator: std.mem.Allocator) void {
        self.polyline.deinit(allocator);
        self.steps.deinit(allocator);
    }

    pub fn formattedDistance(self: *const Route) []const u8 {
        if (self.distance_meters < 1000) {
            return "< 1 km";
        } else {
            return "> 1 km";
        }
    }

    pub fn formattedDuration(self: *const Route) []const u8 {
        if (self.expected_duration_seconds < 60) {
            return "< 1 min";
        } else if (self.expected_duration_seconds < 3600) {
            return "< 1 hour";
        } else {
            return "> 1 hour";
        }
    }
};

/// Geocoding result
pub const GeocodingResult = struct {
    coordinate: Coordinate,
    formatted_address: ?[]const u8,
    street_number: ?[]const u8,
    street: ?[]const u8,
    city: ?[]const u8,
    state: ?[]const u8,
    postal_code: ?[]const u8,
    country: ?[]const u8,
    country_code: ?[]const u8,
    place_type: PlaceType,

    pub const PlaceType = enum {
        address,
        street,
        city,
        state,
        country,
        poi,
        postal_code,
        unknown,
    };

    pub fn init(coordinate: Coordinate) GeocodingResult {
        return .{
            .coordinate = coordinate,
            .formatted_address = null,
            .street_number = null,
            .street = null,
            .city = null,
            .state = null,
            .postal_code = null,
            .country = null,
            .country_code = null,
            .place_type = .unknown,
        };
    }

    pub fn withAddress(self: GeocodingResult, address: []const u8) GeocodingResult {
        var result = self;
        result.formatted_address = address;
        return result;
    }

    pub fn withCity(self: GeocodingResult, city: []const u8) GeocodingResult {
        var result = self;
        result.city = city;
        return result;
    }

    pub fn withCountry(self: GeocodingResult, country: []const u8, code: []const u8) GeocodingResult {
        var result = self;
        result.country = country;
        result.country_code = code;
        return result;
    }
};

/// Point of interest category
pub const POICategory = enum {
    restaurant,
    cafe,
    bar,
    hotel,
    gas_station,
    parking,
    hospital,
    pharmacy,
    bank,
    atm,
    shopping,
    grocery,
    gym,
    park,
    museum,
    theater,
    airport,
    train_station,
    bus_station,
    ev_charging,

    pub fn toString(self: POICategory) []const u8 {
        return switch (self) {
            .restaurant => "Restaurant",
            .cafe => "Cafe",
            .bar => "Bar",
            .hotel => "Hotel",
            .gas_station => "Gas Station",
            .parking => "Parking",
            .hospital => "Hospital",
            .pharmacy => "Pharmacy",
            .bank => "Bank",
            .atm => "ATM",
            .shopping => "Shopping",
            .grocery => "Grocery",
            .gym => "Gym",
            .park => "Park",
            .museum => "Museum",
            .theater => "Theater",
            .airport => "Airport",
            .train_station => "Train Station",
            .bus_station => "Bus Station",
            .ev_charging => "EV Charging",
        };
    }

    pub fn icon(self: POICategory) []const u8 {
        return switch (self) {
            .restaurant => "fork.knife",
            .cafe => "cup.and.saucer",
            .bar => "wineglass",
            .hotel => "bed.double",
            .gas_station => "fuelpump",
            .parking => "p.circle",
            .hospital => "cross.circle",
            .pharmacy => "pills",
            .bank => "building.columns",
            .atm => "banknote",
            .shopping => "bag",
            .grocery => "cart",
            .gym => "dumbbell",
            .park => "leaf",
            .museum => "building.2",
            .theater => "theatermasks",
            .airport => "airplane",
            .train_station => "tram",
            .bus_station => "bus",
            .ev_charging => "bolt.car",
        };
    }
};

/// Point of interest
pub const PointOfInterest = struct {
    id: []const u8,
    name: []const u8,
    coordinate: Coordinate,
    category: POICategory,
    phone: ?[]const u8,
    website: ?[]const u8,
    rating: ?f32,
    price_level: ?u8, // 1-4
    is_open: ?bool,

    pub fn init(id: []const u8, name: []const u8, coordinate: Coordinate, category: POICategory) PointOfInterest {
        return .{
            .id = id,
            .name = name,
            .coordinate = coordinate,
            .category = category,
            .phone = null,
            .website = null,
            .rating = null,
            .price_level = null,
            .is_open = null,
        };
    }

    pub fn distanceFrom(self: PointOfInterest, coord: Coordinate) f64 {
        return self.coordinate.distanceTo(coord);
    }

    pub fn priceLevelString(self: PointOfInterest) []const u8 {
        if (self.price_level) |level| {
            return switch (level) {
                1 => "$",
                2 => "$$",
                3 => "$$$",
                4 => "$$$$",
                else => "?",
            };
        }
        return "";
    }
};

/// Map event types
pub const MapEvent = enum {
    region_changed,
    region_will_change,
    did_finish_loading,
    did_fail_loading,
    annotation_selected,
    annotation_deselected,
    annotation_drag_started,
    annotation_dragged,
    annotation_drag_ended,
    user_location_updated,
    camera_changed,
    tap,
    long_press,
    poi_selected,

    pub fn isUserInteraction(self: MapEvent) bool {
        return switch (self) {
            .tap, .long_press, .annotation_selected, .annotation_drag_started, .poi_selected => true,
            else => false,
        };
    }
};

/// User location tracking mode
pub const UserTrackingMode = enum {
    none,
    follow,
    follow_with_heading,

    pub fn toString(self: UserTrackingMode) []const u8 {
        return switch (self) {
            .none => "None",
            .follow => "Follow",
            .follow_with_heading => "Follow with Heading",
        };
    }
};

/// Map view configuration
pub const MapConfiguration = struct {
    provider: MapProvider,
    map_type: MapType,
    shows_user_location: bool,
    user_tracking_mode: UserTrackingMode,
    shows_compass: bool,
    shows_scale: bool,
    shows_traffic: bool,
    shows_buildings: bool,
    is_rotate_enabled: bool,
    is_scroll_enabled: bool,
    is_zoom_enabled: bool,
    is_pitch_enabled: bool,
    min_zoom: f32,
    max_zoom: f32,

    pub fn defaults() MapConfiguration {
        return .{
            .provider = .apple_maps,
            .map_type = .standard,
            .shows_user_location = false,
            .user_tracking_mode = .none,
            .shows_compass = true,
            .shows_scale = true,
            .shows_traffic = false,
            .shows_buildings = true,
            .is_rotate_enabled = true,
            .is_scroll_enabled = true,
            .is_zoom_enabled = true,
            .is_pitch_enabled = true,
            .min_zoom = 0.0,
            .max_zoom = 22.0,
        };
    }

    pub fn withProvider(self: MapConfiguration, provider: MapProvider) MapConfiguration {
        var config = self;
        config.provider = provider;
        return config;
    }

    pub fn withMapType(self: MapConfiguration, map_type: MapType) MapConfiguration {
        var config = self;
        config.map_type = map_type;
        return config;
    }

    pub fn withUserLocation(self: MapConfiguration, enabled: bool) MapConfiguration {
        var config = self;
        config.shows_user_location = enabled;
        return config;
    }

    pub fn withTraffic(self: MapConfiguration, enabled: bool) MapConfiguration {
        var config = self;
        config.shows_traffic = enabled;
        return config;
    }

    pub fn withZoomLimits(self: MapConfiguration, min: f32, max: f32) MapConfiguration {
        var config = self;
        config.min_zoom = std.math.clamp(min, 0.0, 22.0);
        config.max_zoom = std.math.clamp(max, min, 22.0);
        return config;
    }
};

/// Map view state
pub const MapView = struct {
    allocator: std.mem.Allocator,
    configuration: MapConfiguration,
    camera: MapCamera,
    markers: std.ArrayListUnmanaged(MapMarker),
    polylines: std.ArrayListUnmanaged(MapPolyline),
    polygons: std.ArrayListUnmanaged(MapPolygon),
    circles: std.ArrayListUnmanaged(MapCircle),
    selected_marker_id: ?u64,
    next_id: u64,

    pub fn init(allocator: std.mem.Allocator) MapView {
        return .{
            .allocator = allocator,
            .configuration = MapConfiguration.defaults(),
            .camera = MapCamera.init(Coordinate.zero),
            .markers = .{},
            .polylines = .{},
            .polygons = .{},
            .circles = .{},
            .selected_marker_id = null,
            .next_id = 1,
        };
    }

    pub fn deinit(self: *MapView) void {
        self.markers.deinit(self.allocator);
        for (self.polylines.items) |*pl| {
            pl.deinit(self.allocator);
        }
        self.polylines.deinit(self.allocator);
        for (self.polygons.items) |*pg| {
            pg.deinit(self.allocator);
        }
        self.polygons.deinit(self.allocator);
        self.circles.deinit(self.allocator);
    }

    pub fn setCamera(self: *MapView, camera: MapCamera) void {
        self.camera = camera;
    }

    pub fn setRegion(self: *MapView, region: MapRegion) void {
        self.camera.center = region.center;
        // Approximate zoom from span
        const zoom = @as(f32, @floatCast(std.math.log2(360.0 / region.span.longitude_delta)));
        self.camera.zoom = std.math.clamp(zoom, self.configuration.min_zoom, self.configuration.max_zoom);
    }

    pub fn addMarker(self: *MapView, coordinate: Coordinate) !*MapMarker {
        const id = self.next_id;
        self.next_id += 1;
        try self.markers.append(self.allocator, MapMarker.init(id, coordinate));
        return &self.markers.items[self.markers.items.len - 1];
    }

    pub fn removeMarker(self: *MapView, id: u64) bool {
        for (self.markers.items, 0..) |marker, i| {
            if (marker.id == id) {
                _ = self.markers.orderedRemove(i);
                if (self.selected_marker_id == id) {
                    self.selected_marker_id = null;
                }
                return true;
            }
        }
        return false;
    }

    pub fn addPolyline(self: *MapView) !*MapPolyline {
        const id = self.next_id;
        self.next_id += 1;
        try self.polylines.append(self.allocator, MapPolyline.init(self.allocator, id));
        return &self.polylines.items[self.polylines.items.len - 1];
    }

    pub fn addPolygon(self: *MapView) !*MapPolygon {
        const id = self.next_id;
        self.next_id += 1;
        try self.polygons.append(self.allocator, MapPolygon.init(self.allocator, id));
        return &self.polygons.items[self.polygons.items.len - 1];
    }

    pub fn addCircle(self: *MapView, center: Coordinate, radius: f64) !*MapCircle {
        const id = self.next_id;
        self.next_id += 1;
        try self.circles.append(self.allocator, MapCircle.init(id, center, radius));
        return &self.circles.items[self.circles.items.len - 1];
    }

    pub fn selectMarker(self: *MapView, id: u64) void {
        for (self.markers.items) |*marker| {
            marker.is_selected = marker.id == id;
        }
        self.selected_marker_id = id;
    }

    pub fn deselectAll(self: *MapView) void {
        for (self.markers.items) |*marker| {
            marker.is_selected = false;
        }
        self.selected_marker_id = null;
    }

    pub fn fitToMarkers(self: *MapView, padding: f64) void {
        if (self.markers.items.len == 0) return;

        var coords = std.ArrayListUnmanaged(Coordinate){};
        defer coords.deinit(self.allocator);

        for (self.markers.items) |marker| {
            coords.append(self.allocator, marker.coordinate) catch continue;
        }

        if (BoundingBox.fromCoordinates(coords.items)) |bounds| {
            var region = bounds.toRegion();
            region = region.expand(1.0 + padding / 100.0);
            self.setRegion(region);
        }
    }

    pub fn markerCount(self: *const MapView) usize {
        return self.markers.items.len;
    }

    pub fn overlayCount(self: *const MapView) usize {
        return self.polylines.items.len + self.polygons.items.len + self.circles.items.len;
    }
};

/// Check if maps are available on this platform
pub fn isMapsAvailable() bool {
    return true; // Stub for cross-platform check
}

/// Get the default map provider for the current platform
pub fn defaultProvider() MapProvider {
    // Would check platform at runtime
    return .apple_maps;
}

// ============================================================================
// Tests
// ============================================================================

test "MapProvider toString" {
    try std.testing.expectEqualStrings("Apple Maps", MapProvider.apple_maps.toString());
    try std.testing.expectEqualStrings("Google Maps", MapProvider.google_maps.toString());
}

test "MapProvider supportsOffline" {
    try std.testing.expect(MapProvider.apple_maps.supportsOffline());
    try std.testing.expect(!MapProvider.openstreetmap.supportsOffline());
}

test "MapType properties" {
    try std.testing.expectEqualStrings("Standard", MapType.standard.toString());
    try std.testing.expect(MapType.satellite_flyover.is3D());
    try std.testing.expect(!MapType.standard.is3D());
}

test "Coordinate init clamps values" {
    const coord = Coordinate.init(100.0, 200.0);
    try std.testing.expectEqual(@as(f64, 90.0), coord.latitude);
    try std.testing.expectEqual(@as(f64, 180.0), coord.longitude);
}

test "Coordinate isValid" {
    try std.testing.expect(Coordinate.init(45.0, -122.0).isValid());
    try std.testing.expect(Coordinate.zero.isValid());
}

test "Coordinate distanceTo" {
    const sf = Coordinate.init(37.7749, -122.4194);
    const la = Coordinate.init(34.0522, -118.2437);
    const distance = sf.distanceTo(la);
    // SF to LA is approximately 559 km
    try std.testing.expect(distance > 550000 and distance < 570000);
}

test "Coordinate bearingTo" {
    const origin = Coordinate.init(0, 0);
    const north = Coordinate.init(1, 0);
    const bearing = origin.bearingTo(north);
    try std.testing.expect(bearing < 1.0 or bearing > 359.0); // Should be ~0 degrees (north)
}

test "Coordinate coordinateAtDistance" {
    const origin = Coordinate.init(0, 0);
    const moved = origin.coordinateAtDistance(111320, 0); // ~1 degree north
    try std.testing.expect(moved.latitude > 0.9 and moved.latitude < 1.1);
}

test "CoordinateSpan fromZoomLevel" {
    const span = CoordinateSpan.fromZoomLevel(10, 0);
    try std.testing.expect(span.latitude_delta > 0);
    try std.testing.expect(span.longitude_delta > 0);
}

test "MapRegion containsCoordinate" {
    const center = Coordinate.init(37.7749, -122.4194);
    const region = MapRegion.fromCenterAndRadius(center, 10000);
    try std.testing.expect(region.containsCoordinate(center));
    try std.testing.expect(!region.containsCoordinate(Coordinate.init(0, 0)));
}

test "MapRegion expand" {
    const region = MapRegion.init(Coordinate.zero, CoordinateSpan.init(1.0, 1.0));
    const expanded = region.expand(2.0);
    try std.testing.expectEqual(@as(f64, 2.0), expanded.span.latitude_delta);
}

test "BoundingBox fromCoordinates" {
    const coords = [_]Coordinate{
        Coordinate.init(10, 20),
        Coordinate.init(30, 40),
        Coordinate.init(20, 30),
    };
    const bounds = BoundingBox.fromCoordinates(&coords).?;
    try std.testing.expectEqual(@as(f64, 10.0), bounds.south_west.latitude);
    try std.testing.expectEqual(@as(f64, 30.0), bounds.north_east.latitude);
}

test "BoundingBox center" {
    const bounds = BoundingBox.init(Coordinate.init(0, 0), Coordinate.init(10, 10));
    const center = bounds.center();
    try std.testing.expectEqual(@as(f64, 5.0), center.latitude);
    try std.testing.expectEqual(@as(f64, 5.0), center.longitude);
}

test "BoundingBox intersects" {
    const b1 = BoundingBox.init(Coordinate.init(0, 0), Coordinate.init(10, 10));
    const b2 = BoundingBox.init(Coordinate.init(5, 5), Coordinate.init(15, 15));
    const b3 = BoundingBox.init(Coordinate.init(20, 20), Coordinate.init(30, 30));
    try std.testing.expect(b1.intersects(b2));
    try std.testing.expect(!b1.intersects(b3));
}

test "MapCamera withZoom clamps" {
    const camera = MapCamera.init(Coordinate.zero).withZoom(30.0);
    try std.testing.expectEqual(@as(f32, 22.0), camera.zoom);
}

test "MapCamera withPitch clamps" {
    const camera = MapCamera.init(Coordinate.zero).withPitch(100.0);
    try std.testing.expectEqual(@as(f32, 90.0), camera.pitch);
}

test "MarkerColor toRGB" {
    const rgb = MarkerColor.red.toRGB();
    try std.testing.expectEqual(@as(u8, 255), rgb.r);
}

test "MapMarker builder pattern" {
    const marker = MapMarker.init(1, Coordinate.zero)
        .withTitle("Test")
        .withColor(.green)
        .draggable(true);
    try std.testing.expectEqualStrings("Test", marker.title.?);
    try std.testing.expectEqual(MarkerColor.green, marker.color);
    try std.testing.expect(marker.is_draggable);
}

test "StrokePattern dashLengths" {
    try std.testing.expectEqual(@as(usize, 0), StrokePattern.solid.dashLengths().len);
    try std.testing.expectEqual(@as(usize, 2), StrokePattern.dashed.dashLengths().len);
}

test "MapPolyline totalDistance" {
    var polyline = MapPolyline.init(std.testing.allocator, 1);
    defer polyline.deinit(std.testing.allocator);

    try polyline.addPoint(std.testing.allocator, Coordinate.init(0, 0));
    try polyline.addPoint(std.testing.allocator, Coordinate.init(1, 0));

    const distance = polyline.totalDistance();
    try std.testing.expect(distance > 110000 and distance < 112000); // ~111km
}

test "MapCircle containsCoordinate" {
    const circle = MapCircle.init(1, Coordinate.init(0, 0), 1000);
    try std.testing.expect(circle.containsCoordinate(Coordinate.init(0, 0)));
    try std.testing.expect(!circle.containsCoordinate(Coordinate.init(1, 1)));
}

test "TransportType properties" {
    try std.testing.expectEqualStrings("Driving", TransportType.automobile.toString());
    try std.testing.expect(TransportType.automobile.averageSpeed() > TransportType.walking.averageSpeed());
}

test "Route formattedDistance" {
    var route = Route.init(std.testing.allocator);
    defer route.deinit(std.testing.allocator);

    route.distance_meters = 500;
    try std.testing.expectEqualStrings("< 1 km", route.formattedDistance());

    route.distance_meters = 5000;
    try std.testing.expectEqualStrings("> 1 km", route.formattedDistance());
}

test "GeocodingResult builder" {
    const result = GeocodingResult.init(Coordinate.init(37.7749, -122.4194))
        .withAddress("123 Main St")
        .withCity("San Francisco")
        .withCountry("United States", "US");
    try std.testing.expectEqualStrings("123 Main St", result.formatted_address.?);
    try std.testing.expectEqualStrings("San Francisco", result.city.?);
    try std.testing.expectEqualStrings("US", result.country_code.?);
}

test "POICategory properties" {
    try std.testing.expectEqualStrings("Restaurant", POICategory.restaurant.toString());
    try std.testing.expectEqualStrings("fork.knife", POICategory.restaurant.icon());
}

test "PointOfInterest distanceFrom" {
    const poi = PointOfInterest.init("1", "Test", Coordinate.init(0, 0), .restaurant);
    const distance = poi.distanceFrom(Coordinate.init(1, 0));
    try std.testing.expect(distance > 110000); // ~111km
}

test "PointOfInterest priceLevelString" {
    var poi = PointOfInterest.init("1", "Test", Coordinate.zero, .cafe);
    try std.testing.expectEqualStrings("", poi.priceLevelString());
    poi.price_level = 2;
    try std.testing.expectEqualStrings("$$", poi.priceLevelString());
}

test "MapEvent isUserInteraction" {
    try std.testing.expect(MapEvent.tap.isUserInteraction());
    try std.testing.expect(!MapEvent.region_changed.isUserInteraction());
}

test "UserTrackingMode toString" {
    try std.testing.expectEqualStrings("Follow", UserTrackingMode.follow.toString());
}

test "MapConfiguration builder" {
    const config = MapConfiguration.defaults()
        .withProvider(.google_maps)
        .withMapType(.satellite)
        .withTraffic(true);
    try std.testing.expectEqual(MapProvider.google_maps, config.provider);
    try std.testing.expectEqual(MapType.satellite, config.map_type);
    try std.testing.expect(config.shows_traffic);
}

test "MapView init and deinit" {
    var map = MapView.init(std.testing.allocator);
    defer map.deinit();

    try std.testing.expectEqual(@as(usize, 0), map.markerCount());
}

test "MapView addMarker" {
    var map = MapView.init(std.testing.allocator);
    defer map.deinit();

    const marker = try map.addMarker(Coordinate.init(37.7749, -122.4194));
    try std.testing.expectEqual(@as(u64, 1), marker.id);
    try std.testing.expectEqual(@as(usize, 1), map.markerCount());
}

test "MapView removeMarker" {
    var map = MapView.init(std.testing.allocator);
    defer map.deinit();

    _ = try map.addMarker(Coordinate.zero);
    try std.testing.expect(map.removeMarker(1));
    try std.testing.expectEqual(@as(usize, 0), map.markerCount());
}

test "MapView selectMarker" {
    var map = MapView.init(std.testing.allocator);
    defer map.deinit();

    _ = try map.addMarker(Coordinate.zero);
    map.selectMarker(1);
    try std.testing.expectEqual(@as(?u64, 1), map.selected_marker_id);
}

test "MapView overlays" {
    var map = MapView.init(std.testing.allocator);
    defer map.deinit();

    _ = try map.addPolyline();
    _ = try map.addPolygon();
    _ = try map.addCircle(Coordinate.zero, 100);

    try std.testing.expectEqual(@as(usize, 3), map.overlayCount());
}

test "isMapsAvailable" {
    try std.testing.expect(isMapsAvailable());
}

test "defaultProvider" {
    const provider = defaultProvider();
    try std.testing.expectEqual(MapProvider.apple_maps, provider);
}
