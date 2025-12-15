//! Cross-platform Augmented Reality module for Craft
//! Provides ARKit (iOS) and ARCore (Android) integration
//! for AR experiences, tracking, and scene understanding.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// AR platform type
pub const ARPlatform = enum {
    arkit, // Apple ARKit (iOS)
    arcore, // Google ARCore (Android)
    unknown,

    pub fn toString(self: ARPlatform) []const u8 {
        return switch (self) {
            .arkit => "ARKit",
            .arcore => "ARCore",
            .unknown => "Unknown",
        };
    }

    pub fn manufacturer(self: ARPlatform) []const u8 {
        return switch (self) {
            .arkit => "Apple",
            .arcore => "Google",
            .unknown => "Unknown",
        };
    }
};

/// AR session configuration type
pub const ARConfigurationType = enum {
    world_tracking, // 6DOF world tracking
    face_tracking, // Face tracking
    image_tracking, // Image detection and tracking
    object_tracking, // 3D object detection
    body_tracking, // Body pose estimation
    geo_tracking, // Location-based AR

    pub fn toString(self: ARConfigurationType) []const u8 {
        return switch (self) {
            .world_tracking => "World Tracking",
            .face_tracking => "Face Tracking",
            .image_tracking => "Image Tracking",
            .object_tracking => "Object Tracking",
            .body_tracking => "Body Tracking",
            .geo_tracking => "Geo Tracking",
        };
    }

    pub fn requiresRearCamera(self: ARConfigurationType) bool {
        return switch (self) {
            .world_tracking, .image_tracking, .object_tracking, .body_tracking, .geo_tracking => true,
            .face_tracking => false,
        };
    }

    pub fn requiresFrontCamera(self: ARConfigurationType) bool {
        return self == .face_tracking;
    }
};

/// Tracking state
pub const TrackingState = enum {
    not_available,
    limited,
    normal,

    pub fn toString(self: TrackingState) []const u8 {
        return switch (self) {
            .not_available => "Not Available",
            .limited => "Limited",
            .normal => "Normal",
        };
    }

    pub fn isTracking(self: TrackingState) bool {
        return self == .normal;
    }

    pub fn isLimited(self: TrackingState) bool {
        return self == .limited;
    }
};

/// Tracking state reason (when limited)
pub const TrackingStateReason = enum {
    none,
    initializing,
    excessive_motion,
    insufficient_features,
    relocalizing,

    pub fn toString(self: TrackingStateReason) []const u8 {
        return switch (self) {
            .none => "None",
            .initializing => "Initializing",
            .excessive_motion => "Excessive Motion",
            .insufficient_features => "Insufficient Features",
            .relocalizing => "Relocalizing",
        };
    }

    pub fn userMessage(self: TrackingStateReason) []const u8 {
        return switch (self) {
            .none => "",
            .initializing => "Initializing AR session...",
            .excessive_motion => "Move your device more slowly",
            .insufficient_features => "Point at more textured surfaces",
            .relocalizing => "Returning to previous location...",
        };
    }
};

/// Plane detection mode
pub const PlaneDetection = enum {
    none,
    horizontal,
    vertical,
    horizontal_and_vertical,

    pub fn toString(self: PlaneDetection) []const u8 {
        return switch (self) {
            .none => "None",
            .horizontal => "Horizontal",
            .vertical => "Vertical",
            .horizontal_and_vertical => "Horizontal and Vertical",
        };
    }

    pub fn detectsHorizontal(self: PlaneDetection) bool {
        return self == .horizontal or self == .horizontal_and_vertical;
    }

    pub fn detectsVertical(self: PlaneDetection) bool {
        return self == .vertical or self == .horizontal_and_vertical;
    }
};

/// Plane classification
pub const PlaneClassification = enum {
    none,
    wall,
    floor,
    ceiling,
    table,
    seat,
    window,
    door,

    pub fn toString(self: PlaneClassification) []const u8 {
        return switch (self) {
            .none => "Unknown",
            .wall => "Wall",
            .floor => "Floor",
            .ceiling => "Ceiling",
            .table => "Table",
            .seat => "Seat",
            .window => "Window",
            .door => "Door",
        };
    }

    pub fn isHorizontal(self: PlaneClassification) bool {
        return switch (self) {
            .floor, .ceiling, .table, .seat => true,
            else => false,
        };
    }

    pub fn isVertical(self: PlaneClassification) bool {
        return switch (self) {
            .wall, .window, .door => true,
            else => false,
        };
    }
};

/// Light estimation mode
pub const LightEstimation = enum {
    disabled,
    ambient_intensity,
    environment_probes,

    pub fn toString(self: LightEstimation) []const u8 {
        return switch (self) {
            .disabled => "Disabled",
            .ambient_intensity => "Ambient Intensity",
            .environment_probes => "Environment Probes",
        };
    }
};

/// 3D Vector
pub const Vector3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub const zero: Vector3 = .{ .x = 0, .y = 0, .z = 0 };
    pub const one: Vector3 = .{ .x = 1, .y = 1, .z = 1 };
    pub const up: Vector3 = .{ .x = 0, .y = 1, .z = 0 };
    pub const forward: Vector3 = .{ .x = 0, .y = 0, .z = -1 };
    pub const right: Vector3 = .{ .x = 1, .y = 0, .z = 0 };

    pub fn init(x: f32, y: f32, z: f32) Vector3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(self: Vector3, other: Vector3) Vector3 {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
        };
    }

    pub fn subtract(self: Vector3, other: Vector3) Vector3 {
        return .{
            .x = self.x - other.x,
            .y = self.y - other.y,
            .z = self.z - other.z,
        };
    }

    pub fn scale(self: Vector3, factor: f32) Vector3 {
        return .{
            .x = self.x * factor,
            .y = self.y * factor,
            .z = self.z * factor,
        };
    }

    pub fn length(self: Vector3) f32 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub fn lengthSquared(self: Vector3) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn normalized(self: Vector3) Vector3 {
        const len = self.length();
        if (len == 0) return Vector3.zero;
        return self.scale(1.0 / len);
    }

    pub fn dot(self: Vector3, other: Vector3) f32 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub fn cross(self: Vector3, other: Vector3) Vector3 {
        return .{
            .x = self.y * other.z - self.z * other.y,
            .y = self.z * other.x - self.x * other.z,
            .z = self.x * other.y - self.y * other.x,
        };
    }

    pub fn distance(self: Vector3, other: Vector3) f32 {
        return self.subtract(other).length();
    }
};

/// Quaternion for rotation
pub const Quaternion = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub const identity: Quaternion = .{ .x = 0, .y = 0, .z = 0, .w = 1 };

    pub fn init(x: f32, y: f32, z: f32, w: f32) Quaternion {
        return .{ .x = x, .y = y, .z = z, .w = w };
    }

    pub fn fromEuler(pitch: f32, yaw: f32, roll: f32) Quaternion {
        const cp = @cos(pitch * 0.5);
        const sp = @sin(pitch * 0.5);
        const cy = @cos(yaw * 0.5);
        const sy = @sin(yaw * 0.5);
        const cr = @cos(roll * 0.5);
        const sr = @sin(roll * 0.5);

        return .{
            .w = cp * cy * cr + sp * sy * sr,
            .x = sp * cy * cr - cp * sy * sr,
            .y = cp * sy * cr + sp * cy * sr,
            .z = cp * cy * sr - sp * sy * cr,
        };
    }

    pub fn length(self: Quaternion) f32 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w);
    }

    pub fn normalized(self: Quaternion) Quaternion {
        const len = self.length();
        if (len == 0) return Quaternion.identity;
        return .{
            .x = self.x / len,
            .y = self.y / len,
            .z = self.z / len,
            .w = self.w / len,
        };
    }

    pub fn multiply(self: Quaternion, other: Quaternion) Quaternion {
        return .{
            .w = self.w * other.w - self.x * other.x - self.y * other.y - self.z * other.z,
            .x = self.w * other.x + self.x * other.w + self.y * other.z - self.z * other.y,
            .y = self.w * other.y - self.x * other.z + self.y * other.w + self.z * other.x,
            .z = self.w * other.z + self.x * other.y - self.y * other.x + self.z * other.w,
        };
    }
};

/// Transform (position, rotation, scale)
pub const Transform = struct {
    position: Vector3,
    rotation: Quaternion,
    scl: Vector3,

    pub const identity: Transform = .{
        .position = Vector3.zero,
        .rotation = Quaternion.identity,
        .scl = Vector3.one,
    };

    pub fn init(position: Vector3, rotation: Quaternion, scl: Vector3) Transform {
        return .{
            .position = position,
            .rotation = rotation,
            .scl = scl,
        };
    }

    pub fn fromPosition(position: Vector3) Transform {
        return .{
            .position = position,
            .rotation = Quaternion.identity,
            .scl = Vector3.one,
        };
    }

    pub fn translate(self: Transform, offset: Vector3) Transform {
        return .{
            .position = self.position.add(offset),
            .rotation = self.rotation,
            .scl = self.scl,
        };
    }
};

/// AR anchor types
pub const AnchorType = enum {
    plane,
    image,
    object,
    face,
    body,
    geo,
    custom,

    pub fn toString(self: AnchorType) []const u8 {
        return switch (self) {
            .plane => "Plane",
            .image => "Image",
            .object => "Object",
            .face => "Face",
            .body => "Body",
            .geo => "Geo",
            .custom => "Custom",
        };
    }
};

/// AR anchor
pub const ARAnchor = struct {
    id: []const u8,
    anchor_type: AnchorType,
    transform: Transform,
    tracking_state: TrackingState,
    is_tracked: bool,

    pub fn init(id: []const u8, anchor_type: AnchorType, transform: Transform) ARAnchor {
        return .{
            .id = id,
            .anchor_type = anchor_type,
            .transform = transform,
            .tracking_state = .normal,
            .is_tracked = true,
        };
    }

    pub fn getPosition(self: ARAnchor) Vector3 {
        return self.transform.position;
    }

    pub fn distanceFrom(self: ARAnchor, point: Vector3) f32 {
        return self.transform.position.distance(point);
    }
};

/// AR plane anchor
pub const ARPlaneAnchor = struct {
    base: ARAnchor,
    extent: Vector3,
    classification: PlaneClassification,
    alignment: PlaneAlignment,

    pub const PlaneAlignment = enum {
        horizontal,
        vertical,
        any,

        pub fn toString(self: PlaneAlignment) []const u8 {
            return switch (self) {
                .horizontal => "Horizontal",
                .vertical => "Vertical",
                .any => "Any",
            };
        }
    };

    pub fn init(id: []const u8, transform: Transform, extent: Vector3) ARPlaneAnchor {
        return .{
            .base = ARAnchor.init(id, .plane, transform),
            .extent = extent,
            .classification = .none,
            .alignment = .horizontal,
        };
    }

    pub fn getArea(self: ARPlaneAnchor) f32 {
        return self.extent.x * self.extent.z;
    }

    pub fn isLargeEnough(self: ARPlaneAnchor, min_area: f32) bool {
        return self.getArea() >= min_area;
    }
};

/// AR image anchor
pub const ARImageAnchor = struct {
    base: ARAnchor,
    reference_image_name: []const u8,
    physical_size: struct { width: f32, height: f32 },

    pub fn init(id: []const u8, transform: Transform, image_name: []const u8) ARImageAnchor {
        return .{
            .base = ARAnchor.init(id, .image, transform),
            .reference_image_name = image_name,
            .physical_size = .{ .width = 0, .height = 0 },
        };
    }
};

/// AR face anchor (for face tracking)
pub const ARFaceAnchor = struct {
    base: ARAnchor,
    look_at_point: Vector3,
    left_eye_transform: Transform,
    right_eye_transform: Transform,
    blend_shapes: ?[]const BlendShape,

    pub const BlendShape = struct {
        name: []const u8,
        value: f32, // 0.0 to 1.0

        pub fn init(name: []const u8, value: f32) BlendShape {
            return .{
                .name = name,
                .value = std.math.clamp(value, 0, 1),
            };
        }
    };

    pub fn init(id: []const u8, transform: Transform) ARFaceAnchor {
        return .{
            .base = ARAnchor.init(id, .face, transform),
            .look_at_point = Vector3.forward,
            .left_eye_transform = Transform.identity,
            .right_eye_transform = Transform.identity,
            .blend_shapes = null,
        };
    }
};

/// Hit test result type
pub const HitTestResultType = enum {
    feature_point,
    estimated_horizontal_plane,
    estimated_vertical_plane,
    existing_plane,
    existing_plane_using_extent,
    existing_plane_using_geometry,

    pub fn toString(self: HitTestResultType) []const u8 {
        return switch (self) {
            .feature_point => "Feature Point",
            .estimated_horizontal_plane => "Estimated Horizontal Plane",
            .estimated_vertical_plane => "Estimated Vertical Plane",
            .existing_plane => "Existing Plane",
            .existing_plane_using_extent => "Existing Plane (Extent)",
            .existing_plane_using_geometry => "Existing Plane (Geometry)",
        };
    }

    pub fn priority(self: HitTestResultType) u8 {
        return switch (self) {
            .existing_plane_using_geometry => 6,
            .existing_plane_using_extent => 5,
            .existing_plane => 4,
            .estimated_horizontal_plane => 3,
            .estimated_vertical_plane => 2,
            .feature_point => 1,
        };
    }
};

/// Hit test result
pub const HitTestResult = struct {
    result_type: HitTestResultType,
    distance: f32,
    world_transform: Transform,
    anchor: ?ARAnchor,

    pub fn init(result_type: HitTestResultType, distance: f32, transform: Transform) HitTestResult {
        return .{
            .result_type = result_type,
            .distance = distance,
            .world_transform = transform,
            .anchor = null,
        };
    }

    pub fn getPosition(self: HitTestResult) Vector3 {
        return self.world_transform.position;
    }
};

/// Light estimate
pub const LightEstimate = struct {
    ambient_intensity: f32, // 0-2000 lux
    ambient_color_temperature: f32, // Kelvin
    primary_light_direction: ?Vector3,
    primary_light_intensity: ?f32,

    pub fn init() LightEstimate {
        return .{
            .ambient_intensity = 1000,
            .ambient_color_temperature = 6500,
            .primary_light_direction = null,
            .primary_light_intensity = null,
        };
    }

    pub fn getNormalizedIntensity(self: LightEstimate) f32 {
        return std.math.clamp(self.ambient_intensity / 1000.0, 0, 2);
    }

    pub fn isIndoor(self: LightEstimate) bool {
        return self.ambient_intensity < 500;
    }

    pub fn isOutdoor(self: LightEstimate) bool {
        return self.ambient_intensity > 10000;
    }
};

/// AR frame (single frame of AR data)
pub const ARFrame = struct {
    timestamp: i64,
    tracking_state: TrackingState,
    tracking_state_reason: TrackingStateReason,
    camera_transform: Transform,
    light_estimate: ?LightEstimate,
    anchors_count: u32,

    pub fn init(timestamp: i64) ARFrame {
        return .{
            .timestamp = timestamp,
            .tracking_state = .not_available,
            .tracking_state_reason = .initializing,
            .camera_transform = Transform.identity,
            .light_estimate = null,
            .anchors_count = 0,
        };
    }

    pub fn isTrackingNormal(self: ARFrame) bool {
        return self.tracking_state == .normal;
    }

    pub fn getCameraPosition(self: ARFrame) Vector3 {
        return self.camera_transform.position;
    }
};

/// AR session state
pub const ARSessionState = enum {
    not_started,
    running,
    paused,
    interrupted,
    failed,

    pub fn toString(self: ARSessionState) []const u8 {
        return switch (self) {
            .not_started => "Not Started",
            .running => "Running",
            .paused => "Paused",
            .interrupted => "Interrupted",
            .failed => "Failed",
        };
    }

    pub fn isActive(self: ARSessionState) bool {
        return self == .running;
    }
};

/// AR event types
pub const AREventType = enum {
    session_started,
    session_paused,
    session_resumed,
    session_failed,
    frame_updated,
    anchor_added,
    anchor_updated,
    anchor_removed,
    tracking_state_changed,
    camera_did_change_tracking_state,
};

/// AR event
pub const AREvent = struct {
    event_type: AREventType,
    anchor_id: ?[]const u8,
    error_message: ?[]const u8,
    timestamp: i64,

    pub fn create(event_type: AREventType) AREvent {
        return .{
            .event_type = event_type,
            .anchor_id = null,
            .error_message = null,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn forAnchor(event_type: AREventType, anchor_id: []const u8) AREvent {
        return .{
            .event_type = event_type,
            .anchor_id = anchor_id,
            .error_message = null,
            .timestamp = getCurrentTimestamp(),
        };
    }

    pub fn withError(event_type: AREventType, error_msg: []const u8) AREvent {
        return .{
            .event_type = event_type,
            .anchor_id = null,
            .error_message = error_msg,
            .timestamp = getCurrentTimestamp(),
        };
    }
};

/// AR callback type
pub const ARCallback = *const fn (event: AREvent) void;

/// AR session configuration
pub const ARSessionConfiguration = struct {
    configuration_type: ARConfigurationType,
    plane_detection: PlaneDetection,
    light_estimation: LightEstimation,
    auto_focus_enabled: bool,
    provide_audio_data: bool,
    frame_semantics: FrameSemantics,

    pub const FrameSemantics = enum {
        none,
        person_segmentation,
        body_detection,
        scene_depth,

        pub fn toString(self: FrameSemantics) []const u8 {
            return switch (self) {
                .none => "None",
                .person_segmentation => "Person Segmentation",
                .body_detection => "Body Detection",
                .scene_depth => "Scene Depth",
            };
        }
    };

    pub fn init(config_type: ARConfigurationType) ARSessionConfiguration {
        return .{
            .configuration_type = config_type,
            .plane_detection = .horizontal_and_vertical,
            .light_estimation = .ambient_intensity,
            .auto_focus_enabled = true,
            .provide_audio_data = false,
            .frame_semantics = .none,
        };
    }

    pub fn worldTracking() ARSessionConfiguration {
        return init(.world_tracking);
    }

    pub fn faceTracking() ARSessionConfiguration {
        var config = init(.face_tracking);
        config.plane_detection = .none;
        return config;
    }

    pub fn imageTracking() ARSessionConfiguration {
        var config = init(.image_tracking);
        config.plane_detection = .none;
        return config;
    }
};

/// AR session
pub const ARSession = struct {
    allocator: Allocator,
    platform: ARPlatform,
    configuration: ARSessionConfiguration,
    state: ARSessionState,
    current_frame: ?ARFrame,
    anchors: std.ArrayListUnmanaged(ARAnchor),
    callbacks: std.ArrayListUnmanaged(ARCallback),
    frames_processed: u64,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .platform = .unknown,
            .configuration = ARSessionConfiguration.worldTracking(),
            .state = .not_started,
            .current_frame = null,
            .anchors = .{},
            .callbacks = .{},
            .frames_processed = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.anchors.deinit(self.allocator);
        self.callbacks.deinit(self.allocator);
    }

    /// Add event callback
    pub fn addCallback(self: *Self, callback: ARCallback) !void {
        try self.callbacks.append(self.allocator, callback);
    }

    /// Remove event callback
    pub fn removeCallback(self: *Self, callback: ARCallback) bool {
        for (self.callbacks.items, 0..) |cb, i| {
            if (cb == callback) {
                _ = self.callbacks.orderedRemove(i);
                return true;
            }
        }
        return false;
    }

    /// Run session with configuration
    pub fn run(self: *Self, configuration: ARSessionConfiguration) void {
        self.configuration = configuration;
        self.state = .running;
        self.notifyCallbacks(AREvent.create(.session_started));
    }

    /// Pause session
    pub fn pause(self: *Self) void {
        if (self.state == .running) {
            self.state = .paused;
            self.notifyCallbacks(AREvent.create(.session_paused));
        }
    }

    /// Resume session
    pub fn resumeSession(self: *Self) void {
        if (self.state == .paused) {
            self.state = .running;
            self.notifyCallbacks(AREvent.create(.session_resumed));
        }
    }

    /// Check if session is running
    pub fn isRunning(self: Self) bool {
        return self.state.isActive();
    }

    /// Get current state
    pub fn getState(self: Self) ARSessionState {
        return self.state;
    }

    /// Add anchor
    pub fn addAnchor(self: *Self, anchor: ARAnchor) !void {
        try self.anchors.append(self.allocator, anchor);
        self.notifyCallbacks(AREvent.forAnchor(.anchor_added, anchor.id));
    }

    /// Remove anchor by ID
    pub fn removeAnchor(self: *Self, anchor_id: []const u8) bool {
        for (self.anchors.items, 0..) |anchor, i| {
            if (std.mem.eql(u8, anchor.id, anchor_id)) {
                _ = self.anchors.orderedRemove(i);
                self.notifyCallbacks(AREvent.forAnchor(.anchor_removed, anchor_id));
                return true;
            }
        }
        return false;
    }

    /// Get anchor by ID
    pub fn getAnchor(self: Self, anchor_id: []const u8) ?ARAnchor {
        for (self.anchors.items) |anchor| {
            if (std.mem.eql(u8, anchor.id, anchor_id)) {
                return anchor;
            }
        }
        return null;
    }

    /// Get all anchors
    pub fn getAnchors(self: Self) []const ARAnchor {
        return self.anchors.items;
    }

    /// Get anchor count
    pub fn getAnchorCount(self: Self) usize {
        return self.anchors.items.len;
    }

    /// Update frame (called by platform)
    pub fn updateFrame(self: *Self, frame: ARFrame) void {
        self.current_frame = frame;
        self.frames_processed += 1;
        self.notifyCallbacks(AREvent.create(.frame_updated));
    }

    /// Get current frame
    pub fn getCurrentFrame(self: Self) ?ARFrame {
        return self.current_frame;
    }

    fn notifyCallbacks(self: *Self, event: AREvent) void {
        for (self.callbacks.items) |callback| {
            callback(event);
        }
    }
};

/// Check if AR is available on the device
pub fn isARAvailable() bool {
    // Platform-specific implementation would go here
    return true;
}

/// Check if specific configuration is supported
pub fn isConfigurationSupported(config_type: ARConfigurationType) bool {
    // Platform-specific implementation would go here
    _ = config_type;
    return true;
}

/// Get current timestamp in milliseconds
fn getCurrentTimestamp() i64 {
    const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
    return @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000);
}

// ============================================================================
// Tests
// ============================================================================

test "ARPlatform toString" {
    try std.testing.expectEqualStrings("ARKit", ARPlatform.arkit.toString());
    try std.testing.expectEqualStrings("ARCore", ARPlatform.arcore.toString());
}

test "ARConfigurationType properties" {
    try std.testing.expect(ARConfigurationType.world_tracking.requiresRearCamera());
    try std.testing.expect(!ARConfigurationType.face_tracking.requiresRearCamera());
    try std.testing.expect(ARConfigurationType.face_tracking.requiresFrontCamera());
}

test "TrackingState properties" {
    try std.testing.expect(TrackingState.normal.isTracking());
    try std.testing.expect(!TrackingState.limited.isTracking());
    try std.testing.expect(TrackingState.limited.isLimited());
}

test "TrackingStateReason userMessage" {
    try std.testing.expectEqualStrings("", TrackingStateReason.none.userMessage());
    try std.testing.expect(TrackingStateReason.excessive_motion.userMessage().len > 0);
}

test "PlaneDetection properties" {
    try std.testing.expect(PlaneDetection.horizontal.detectsHorizontal());
    try std.testing.expect(!PlaneDetection.horizontal.detectsVertical());
    try std.testing.expect(PlaneDetection.horizontal_and_vertical.detectsHorizontal());
    try std.testing.expect(PlaneDetection.horizontal_and_vertical.detectsVertical());
}

test "PlaneClassification properties" {
    try std.testing.expect(PlaneClassification.floor.isHorizontal());
    try std.testing.expect(PlaneClassification.wall.isVertical());
    try std.testing.expect(!PlaneClassification.floor.isVertical());
}

test "Vector3 operations" {
    const v1 = Vector3.init(1, 2, 3);
    const v2 = Vector3.init(4, 5, 6);

    const sum = v1.add(v2);
    try std.testing.expectApproxEqAbs(@as(f32, 5), sum.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 7), sum.y, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 9), sum.z, 0.01);

    const diff = v2.subtract(v1);
    try std.testing.expectApproxEqAbs(@as(f32, 3), diff.x, 0.01);
}

test "Vector3 length" {
    const v = Vector3.init(3, 4, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 5), v.length(), 0.01);
}

test "Vector3 normalized" {
    const v = Vector3.init(3, 4, 0);
    const n = v.normalized();
    try std.testing.expectApproxEqAbs(@as(f32, 1), n.length(), 0.01);
}

test "Vector3 dot product" {
    const v1 = Vector3.init(1, 0, 0);
    const v2 = Vector3.init(0, 1, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0), v1.dot(v2), 0.01);

    const v3 = Vector3.init(1, 0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 1), v1.dot(v3), 0.01);
}

test "Vector3 cross product" {
    const x = Vector3.init(1, 0, 0);
    const y = Vector3.init(0, 1, 0);
    const z = x.cross(y);
    try std.testing.expectApproxEqAbs(@as(f32, 0), z.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0), z.y, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1), z.z, 0.01);
}

test "Quaternion identity" {
    const q = Quaternion.identity;
    try std.testing.expectApproxEqAbs(@as(f32, 1), q.length(), 0.01);
}

test "Quaternion normalized" {
    const q = Quaternion.init(1, 2, 3, 4);
    const n = q.normalized();
    try std.testing.expectApproxEqAbs(@as(f32, 1), n.length(), 0.01);
}

test "Transform identity" {
    const t = Transform.identity;
    try std.testing.expectApproxEqAbs(@as(f32, 0), t.position.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1), t.scl.x, 0.01);
}

test "Transform translate" {
    const t = Transform.identity;
    const moved = t.translate(Vector3.init(5, 0, 0));
    try std.testing.expectApproxEqAbs(@as(f32, 5), moved.position.x, 0.01);
}

test "ARAnchor init" {
    const anchor = ARAnchor.init("anchor1", .plane, Transform.identity);
    try std.testing.expectEqualStrings("anchor1", anchor.id);
    try std.testing.expectEqual(AnchorType.plane, anchor.anchor_type);
    try std.testing.expect(anchor.is_tracked);
}

test "ARPlaneAnchor getArea" {
    const plane = ARPlaneAnchor.init("plane1", Transform.identity, Vector3.init(2, 0, 3));
    try std.testing.expectApproxEqAbs(@as(f32, 6), plane.getArea(), 0.01);
}

test "ARPlaneAnchor isLargeEnough" {
    const plane = ARPlaneAnchor.init("plane1", Transform.identity, Vector3.init(2, 0, 3));
    try std.testing.expect(plane.isLargeEnough(5));
    try std.testing.expect(!plane.isLargeEnough(10));
}

test "HitTestResultType priority" {
    try std.testing.expect(HitTestResultType.existing_plane_using_geometry.priority() >
        HitTestResultType.feature_point.priority());
}

test "LightEstimate properties" {
    var estimate = LightEstimate.init();
    try std.testing.expectApproxEqAbs(@as(f32, 1), estimate.getNormalizedIntensity(), 0.01);

    estimate.ambient_intensity = 300;
    try std.testing.expect(estimate.isIndoor());

    estimate.ambient_intensity = 15000;
    try std.testing.expect(estimate.isOutdoor());
}

test "ARFrame init" {
    const frame = ARFrame.init(12345);
    try std.testing.expectEqual(@as(i64, 12345), frame.timestamp);
    try std.testing.expectEqual(TrackingState.not_available, frame.tracking_state);
}

test "ARSessionState properties" {
    try std.testing.expect(ARSessionState.running.isActive());
    try std.testing.expect(!ARSessionState.paused.isActive());
}

test "AREvent create" {
    const event = AREvent.create(.session_started);
    try std.testing.expectEqual(AREventType.session_started, event.event_type);
}

test "AREvent forAnchor" {
    const event = AREvent.forAnchor(.anchor_added, "anchor1");
    try std.testing.expectEqualStrings("anchor1", event.anchor_id.?);
}

test "ARSessionConfiguration init" {
    const config = ARSessionConfiguration.worldTracking();
    try std.testing.expectEqual(ARConfigurationType.world_tracking, config.configuration_type);
    try std.testing.expectEqual(PlaneDetection.horizontal_and_vertical, config.plane_detection);
}

test "ARSessionConfiguration faceTracking" {
    const config = ARSessionConfiguration.faceTracking();
    try std.testing.expectEqual(ARConfigurationType.face_tracking, config.configuration_type);
    try std.testing.expectEqual(PlaneDetection.none, config.plane_detection);
}

test "ARSession init and deinit" {
    const allocator = std.testing.allocator;
    var session = ARSession.init(allocator);
    defer session.deinit();

    try std.testing.expectEqual(ARSessionState.not_started, session.getState());
    try std.testing.expect(!session.isRunning());
}

test "ARSession run" {
    const allocator = std.testing.allocator;
    var session = ARSession.init(allocator);
    defer session.deinit();

    session.run(ARSessionConfiguration.worldTracking());
    try std.testing.expect(session.isRunning());
}

test "ARSession pause and resume" {
    const allocator = std.testing.allocator;
    var session = ARSession.init(allocator);
    defer session.deinit();

    session.run(ARSessionConfiguration.worldTracking());
    session.pause();
    try std.testing.expect(!session.isRunning());
    try std.testing.expectEqual(ARSessionState.paused, session.getState());

    session.resumeSession();
    try std.testing.expect(session.isRunning());
}

test "ARSession anchors" {
    const allocator = std.testing.allocator;
    var session = ARSession.init(allocator);
    defer session.deinit();

    const anchor = ARAnchor.init("test_anchor", .plane, Transform.identity);
    try session.addAnchor(anchor);

    try std.testing.expectEqual(@as(usize, 1), session.getAnchorCount());

    const retrieved = session.getAnchor("test_anchor");
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualStrings("test_anchor", retrieved.?.id);

    try std.testing.expect(session.removeAnchor("test_anchor"));
    try std.testing.expectEqual(@as(usize, 0), session.getAnchorCount());
}

test "ARSession updateFrame" {
    const allocator = std.testing.allocator;
    var session = ARSession.init(allocator);
    defer session.deinit();

    var frame = ARFrame.init(12345);
    frame.tracking_state = .normal;
    session.updateFrame(frame);

    const current = session.getCurrentFrame();
    try std.testing.expect(current != null);
    try std.testing.expectEqual(@as(i64, 12345), current.?.timestamp);
    try std.testing.expectEqual(@as(u64, 1), session.frames_processed);
}

test "isARAvailable" {
    try std.testing.expect(isARAvailable());
}
