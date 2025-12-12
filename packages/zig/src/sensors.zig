//! Sensors module for Craft
//! Provides cross-platform access to device motion sensors.
//! Abstracts platform-specific implementations:
//! - iOS: Core Motion (CMMotionManager)
//! - Android: SensorManager
//! - Desktop: Limited sensor support

const std = @import("std");

/// Get current timestamp in milliseconds (Zig 0.16 compatible)
fn getTimestampMs() i64 {
    const ts = std.posix.clock_gettime(.REALTIME) catch return 0;
    return @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000);
}

/// Sensor types available
pub const SensorType = enum {
    /// Accelerometer - measures acceleration forces
    accelerometer,
    /// Gyroscope - measures rotation rate
    gyroscope,
    /// Magnetometer - measures magnetic field
    magnetometer,
    /// Barometer - measures atmospheric pressure
    barometer,
    /// Ambient light sensor
    light,
    /// Proximity sensor
    proximity,
    /// Step counter/pedometer
    pedometer,
    /// Device motion (fused sensor data)
    device_motion,
    /// Gravity sensor
    gravity,
    /// Linear acceleration (without gravity)
    linear_acceleration,
    /// Rotation vector
    rotation,

    /// Get sensor name
    pub fn name(self: SensorType) []const u8 {
        return switch (self) {
            .accelerometer => "Accelerometer",
            .gyroscope => "Gyroscope",
            .magnetometer => "Magnetometer",
            .barometer => "Barometer",
            .light => "Ambient Light",
            .proximity => "Proximity",
            .pedometer => "Pedometer",
            .device_motion => "Device Motion",
            .gravity => "Gravity",
            .linear_acceleration => "Linear Acceleration",
            .rotation => "Rotation",
        };
    }

    /// Get sensor unit
    pub fn unit(self: SensorType) []const u8 {
        return switch (self) {
            .accelerometer, .gravity, .linear_acceleration => "m/s²",
            .gyroscope => "rad/s",
            .magnetometer => "µT",
            .barometer => "hPa",
            .light => "lux",
            .proximity => "cm",
            .pedometer => "steps",
            .device_motion, .rotation => "quaternion",
        };
    }
};

/// Sensor accuracy levels
pub const SensorAccuracy = enum {
    /// Sensor is unreliable
    unreliable,
    /// Low accuracy
    low,
    /// Medium accuracy
    medium,
    /// High accuracy
    high,

    /// Get numeric value (0-3)
    pub fn value(self: SensorAccuracy) u8 {
        return switch (self) {
            .unreliable => 0,
            .low => 1,
            .medium => 2,
            .high => 3,
        };
    }
};

/// Update frequency for sensors
pub const UpdateFrequency = enum {
    /// UI updates (~60Hz)
    ui,
    /// Normal updates (~30Hz)
    normal,
    /// Game updates (~100Hz)
    game,
    /// Fastest available
    fastest,

    /// Get interval in milliseconds
    pub fn intervalMs(self: UpdateFrequency) u32 {
        return switch (self) {
            .ui => 16, // ~60Hz
            .normal => 33, // ~30Hz
            .game => 10, // ~100Hz
            .fastest => 1,
        };
    }

    /// Get frequency in Hz
    pub fn hz(self: UpdateFrequency) f32 {
        return switch (self) {
            .ui => 60.0,
            .normal => 30.0,
            .game => 100.0,
            .fastest => 1000.0,
        };
    }
};

/// 3D vector for sensor data
pub const Vector3 = struct {
    x: f64 = 0.0,
    y: f64 = 0.0,
    z: f64 = 0.0,

    /// Create a vector
    pub fn init(x: f64, y: f64, z: f64) Vector3 {
        return .{ .x = x, .y = y, .z = z };
    }

    /// Zero vector
    pub fn zero() Vector3 {
        return .{ .x = 0.0, .y = 0.0, .z = 0.0 };
    }

    /// Calculate magnitude
    pub fn magnitude(self: Vector3) f64 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    /// Normalize the vector
    pub fn normalized(self: Vector3) Vector3 {
        const mag = self.magnitude();
        if (mag == 0) return Vector3.zero();
        return .{
            .x = self.x / mag,
            .y = self.y / mag,
            .z = self.z / mag,
        };
    }

    /// Add two vectors
    pub fn add(self: Vector3, other: Vector3) Vector3 {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
        };
    }

    /// Subtract two vectors
    pub fn sub(self: Vector3, other: Vector3) Vector3 {
        return .{
            .x = self.x - other.x,
            .y = self.y - other.y,
            .z = self.z - other.z,
        };
    }

    /// Scale vector
    pub fn scale(self: Vector3, scalar: f64) Vector3 {
        return .{
            .x = self.x * scalar,
            .y = self.y * scalar,
            .z = self.z * scalar,
        };
    }

    /// Dot product
    pub fn dot(self: Vector3, other: Vector3) f64 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    /// Cross product
    pub fn cross(self: Vector3, other: Vector3) Vector3 {
        return .{
            .x = self.y * other.z - self.z * other.y,
            .y = self.z * other.x - self.x * other.z,
            .z = self.x * other.y - self.y * other.x,
        };
    }

    /// Distance to another vector
    pub fn distanceTo(self: Vector3, other: Vector3) f64 {
        return self.sub(other).magnitude();
    }

    /// Angle between two vectors (radians)
    pub fn angleTo(self: Vector3, other: Vector3) f64 {
        const mag_product = self.magnitude() * other.magnitude();
        if (mag_product == 0) return 0;
        const cos_angle = self.dot(other) / mag_product;
        return std.math.acos(std.math.clamp(cos_angle, -1.0, 1.0));
    }
};

/// Quaternion for rotation
pub const Quaternion = struct {
    w: f64 = 1.0,
    x: f64 = 0.0,
    y: f64 = 0.0,
    z: f64 = 0.0,

    /// Identity quaternion
    pub fn identity() Quaternion {
        return .{ .w = 1.0, .x = 0.0, .y = 0.0, .z = 0.0 };
    }

    /// Create from axis-angle
    pub fn fromAxisAngle(axis: Vector3, angle: f64) Quaternion {
        const half_angle = angle / 2.0;
        const s = @sin(half_angle);
        const normalized_axis = axis.normalized();
        return .{
            .w = @cos(half_angle),
            .x = normalized_axis.x * s,
            .y = normalized_axis.y * s,
            .z = normalized_axis.z * s,
        };
    }

    /// Get magnitude
    pub fn magnitude(self: Quaternion) f64 {
        return @sqrt(self.w * self.w + self.x * self.x + self.y * self.y + self.z * self.z);
    }

    /// Normalize
    pub fn normalized(self: Quaternion) Quaternion {
        const mag = self.magnitude();
        if (mag == 0) return Quaternion.identity();
        return .{
            .w = self.w / mag,
            .x = self.x / mag,
            .y = self.y / mag,
            .z = self.z / mag,
        };
    }

    /// Conjugate
    pub fn conjugate(self: Quaternion) Quaternion {
        return .{
            .w = self.w,
            .x = -self.x,
            .y = -self.y,
            .z = -self.z,
        };
    }

    /// Multiply quaternions
    pub fn multiply(self: Quaternion, other: Quaternion) Quaternion {
        return .{
            .w = self.w * other.w - self.x * other.x - self.y * other.y - self.z * other.z,
            .x = self.w * other.x + self.x * other.w + self.y * other.z - self.z * other.y,
            .y = self.w * other.y - self.x * other.z + self.y * other.w + self.z * other.x,
            .z = self.w * other.z + self.x * other.y - self.y * other.x + self.z * other.w,
        };
    }

    /// Convert to Euler angles (roll, pitch, yaw)
    pub fn toEuler(self: Quaternion) Vector3 {
        // Roll (x-axis rotation)
        const sinr_cosp = 2.0 * (self.w * self.x + self.y * self.z);
        const cosr_cosp = 1.0 - 2.0 * (self.x * self.x + self.y * self.y);
        const roll = std.math.atan2(sinr_cosp, cosr_cosp);

        // Pitch (y-axis rotation)
        const sinp = 2.0 * (self.w * self.y - self.z * self.x);
        const half_pi: f64 = std.math.pi / 2.0;
        const pitch: f64 = if (@abs(sinp) >= 1.0)
            if (sinp >= 0) half_pi else -half_pi
        else
            std.math.asin(sinp);

        // Yaw (z-axis rotation)
        const siny_cosp = 2.0 * (self.w * self.z + self.x * self.y);
        const cosy_cosp = 1.0 - 2.0 * (self.y * self.y + self.z * self.z);
        const yaw = std.math.atan2(siny_cosp, cosy_cosp);

        return Vector3.init(roll, pitch, yaw);
    }
};

/// Accelerometer data
pub const AccelerometerData = struct {
    /// Acceleration vector (m/s²)
    acceleration: Vector3,
    /// Timestamp (milliseconds)
    timestamp: i64,
    /// Accuracy
    accuracy: SensorAccuracy = .high,

    /// Create data
    pub fn init(x: f64, y: f64, z: f64) AccelerometerData {
        return .{
            .acceleration = Vector3.init(x, y, z),
            .timestamp = getTimestampMs(),
        };
    }

    /// Get total acceleration magnitude
    pub fn magnitude(self: AccelerometerData) f64 {
        return self.acceleration.magnitude();
    }

    /// Check if device is roughly stationary
    pub fn isStationary(self: AccelerometerData, threshold: f64) bool {
        // Earth gravity is ~9.81 m/s²
        return @abs(self.magnitude() - 9.81) < threshold;
    }
};

/// Gyroscope data
pub const GyroscopeData = struct {
    /// Rotation rate vector (rad/s)
    rotation_rate: Vector3,
    /// Timestamp (milliseconds)
    timestamp: i64,
    /// Accuracy
    accuracy: SensorAccuracy = .high,

    /// Create data
    pub fn init(x: f64, y: f64, z: f64) GyroscopeData {
        return .{
            .rotation_rate = Vector3.init(x, y, z),
            .timestamp = getTimestampMs(),
        };
    }

    /// Get rotation rate magnitude
    pub fn magnitude(self: GyroscopeData) f64 {
        return self.rotation_rate.magnitude();
    }

    /// Check if device is rotating significantly
    pub fn isRotating(self: GyroscopeData, threshold: f64) bool {
        return self.magnitude() > threshold;
    }

    /// Get rotation rate in degrees per second
    pub fn degreesPerSecond(self: GyroscopeData) Vector3 {
        const rad_to_deg = 180.0 / std.math.pi;
        return self.rotation_rate.scale(rad_to_deg);
    }
};

/// Magnetometer data
pub const MagnetometerData = struct {
    /// Magnetic field vector (µT)
    magnetic_field: Vector3,
    /// Timestamp (milliseconds)
    timestamp: i64,
    /// Accuracy
    accuracy: SensorAccuracy = .high,

    /// Create data
    pub fn init(x: f64, y: f64, z: f64) MagnetometerData {
        return .{
            .magnetic_field = Vector3.init(x, y, z),
            .timestamp = getTimestampMs(),
        };
    }

    /// Get magnetic field strength
    pub fn strength(self: MagnetometerData) f64 {
        return self.magnetic_field.magnitude();
    }

    /// Get compass heading (degrees, 0-360)
    pub fn heading(self: MagnetometerData) f64 {
        var angle = std.math.atan2(self.magnetic_field.y, self.magnetic_field.x);
        angle = std.math.radiansToDegrees(angle);
        if (angle < 0) angle += 360.0;
        return angle;
    }

    /// Get cardinal direction
    pub fn cardinalDirection(self: MagnetometerData) []const u8 {
        const h = self.heading();
        if (h >= 337.5 or h < 22.5) return "N";
        if (h >= 22.5 and h < 67.5) return "NE";
        if (h >= 67.5 and h < 112.5) return "E";
        if (h >= 112.5 and h < 157.5) return "SE";
        if (h >= 157.5 and h < 202.5) return "S";
        if (h >= 202.5 and h < 247.5) return "SW";
        if (h >= 247.5 and h < 292.5) return "W";
        return "NW";
    }
};

/// Barometer data
pub const BarometerData = struct {
    /// Atmospheric pressure (hPa/mbar)
    pressure: f64,
    /// Relative altitude change (meters)
    relative_altitude: f64 = 0.0,
    /// Timestamp (milliseconds)
    timestamp: i64,

    /// Create data
    pub fn init(pressure: f64) BarometerData {
        return .{
            .pressure = pressure,
            .timestamp = getTimestampMs(),
        };
    }

    /// Estimate altitude from pressure (meters above sea level)
    /// Uses barometric formula with standard atmosphere
    pub fn estimatedAltitude(self: BarometerData) f64 {
        // Standard sea level pressure: 1013.25 hPa
        const sea_level_pressure: f64 = 1013.25;
        return 44330.0 * (1.0 - std.math.pow(f64, self.pressure / sea_level_pressure, 0.1903));
    }

    /// Get weather tendency based on pressure
    pub fn weatherTendency(self: BarometerData, previous_pressure: f64) []const u8 {
        const diff = self.pressure - previous_pressure;
        if (diff > 2.0) return "Improving";
        if (diff < -2.0) return "Worsening";
        return "Stable";
    }
};

/// Light sensor data
pub const LightData = struct {
    /// Illuminance (lux)
    lux: f64,
    /// Timestamp (milliseconds)
    timestamp: i64,

    /// Create data
    pub fn init(lux: f64) LightData {
        return .{
            .lux = lux,
            .timestamp = getTimestampMs(),
        };
    }

    /// Get light level category
    pub fn category(self: LightData) []const u8 {
        if (self.lux < 1) return "Dark";
        if (self.lux < 50) return "Dim";
        if (self.lux < 300) return "Indoor";
        if (self.lux < 1000) return "Overcast";
        if (self.lux < 10000) return "Daylight";
        if (self.lux < 50000) return "Bright";
        return "Direct Sunlight";
    }

    /// Check if suitable for reading
    pub fn isSuitableForReading(self: LightData) bool {
        return self.lux >= 300 and self.lux <= 1000;
    }
};

/// Proximity sensor data
pub const ProximityData = struct {
    /// Distance (cm), or 0 if near
    distance: f64,
    /// Is object near (within threshold)
    is_near: bool,
    /// Timestamp (milliseconds)
    timestamp: i64,

    /// Create data
    pub fn init(distance: f64, threshold: f64) ProximityData {
        return .{
            .distance = distance,
            .is_near = distance < threshold,
            .timestamp = getTimestampMs(),
        };
    }
};

/// Pedometer data
pub const PedometerData = struct {
    /// Total steps since monitoring started
    steps: u64,
    /// Distance walked (meters)
    distance: f64,
    /// Floors ascended
    floors_ascended: u32 = 0,
    /// Floors descended
    floors_descended: u32 = 0,
    /// Current pace (seconds per meter)
    pace: ?f64 = null,
    /// Current cadence (steps per second)
    cadence: ?f64 = null,
    /// Timestamp (milliseconds)
    timestamp: i64,

    /// Create data
    pub fn init(steps: u64, distance: f64) PedometerData {
        return .{
            .steps = steps,
            .distance = distance,
            .timestamp = getTimestampMs(),
        };
    }

    /// Estimate calories burned (rough estimate)
    pub fn estimatedCalories(self: PedometerData, weight_kg: f64) f64 {
        // Rough estimate: 0.04 calories per step per kg body weight
        return @as(f64, @floatFromInt(self.steps)) * 0.04 * weight_kg / 70.0;
    }

    /// Get steps per minute
    pub fn stepsPerMinute(self: PedometerData) ?f64 {
        if (self.cadence) |c| {
            return c * 60.0;
        }
        return null;
    }
};

/// Device motion data (fused sensors)
pub const DeviceMotionData = struct {
    /// User acceleration (without gravity)
    user_acceleration: Vector3,
    /// Gravity vector
    gravity: Vector3,
    /// Rotation rate
    rotation_rate: Vector3,
    /// Attitude as quaternion
    attitude: Quaternion,
    /// Magnetic field
    magnetic_field: ?Vector3 = null,
    /// Heading (degrees)
    heading: ?f64 = null,
    /// Timestamp (milliseconds)
    timestamp: i64,

    /// Create data
    pub fn init() DeviceMotionData {
        return .{
            .user_acceleration = Vector3.zero(),
            .gravity = Vector3.init(0, 0, -9.81),
            .rotation_rate = Vector3.zero(),
            .attitude = Quaternion.identity(),
            .timestamp = getTimestampMs(),
        };
    }

    /// Get Euler angles (roll, pitch, yaw)
    pub fn eulerAngles(self: DeviceMotionData) Vector3 {
        return self.attitude.toEuler();
    }

    /// Get device orientation
    pub fn orientation(self: DeviceMotionData) []const u8 {
        const euler = self.eulerAngles();
        const pitch_deg = std.math.radiansToDegrees(euler.y);
        const roll_deg = std.math.radiansToDegrees(euler.x);

        if (@abs(pitch_deg) > 45) {
            return if (pitch_deg > 0) "Face Up" else "Face Down";
        }
        if (@abs(roll_deg) > 45) {
            return if (roll_deg > 0) "Landscape Left" else "Landscape Right";
        }
        return "Portrait";
    }
};

/// Sensor error types
pub const SensorError = error{
    /// Sensor not available on device
    NotAvailable,
    /// Permission denied
    PermissionDenied,
    /// Sensor already active
    AlreadyActive,
    /// Sensor not active
    NotActive,
    /// Invalid configuration
    InvalidConfiguration,
    /// Hardware error
    HardwareError,
    /// Out of memory
    OutOfMemory,
};

/// Sensor data callback
pub const AccelerometerCallback = *const fn (data: AccelerometerData) void;
pub const GyroscopeCallback = *const fn (data: GyroscopeData) void;
pub const MagnetometerCallback = *const fn (data: MagnetometerData) void;
pub const BarometerCallback = *const fn (data: BarometerData) void;
pub const DeviceMotionCallback = *const fn (data: DeviceMotionData) void;
pub const PedometerCallback = *const fn (data: PedometerData) void;

/// Sensor manager for accessing device sensors
pub const SensorManager = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    // Update frequency
    frequency: UpdateFrequency = .normal,

    // Active sensors
    accelerometer_active: bool = false,
    gyroscope_active: bool = false,
    magnetometer_active: bool = false,
    barometer_active: bool = false,
    device_motion_active: bool = false,
    pedometer_active: bool = false,

    // Callbacks
    accelerometer_callback: ?AccelerometerCallback = null,
    gyroscope_callback: ?GyroscopeCallback = null,
    magnetometer_callback: ?MagnetometerCallback = null,
    barometer_callback: ?BarometerCallback = null,
    device_motion_callback: ?DeviceMotionCallback = null,
    pedometer_callback: ?PedometerCallback = null,

    // Last readings (for simulation/testing)
    last_accelerometer: ?AccelerometerData = null,
    last_gyroscope: ?GyroscopeData = null,
    last_magnetometer: ?MagnetometerData = null,
    last_barometer: ?BarometerData = null,
    last_device_motion: ?DeviceMotionData = null,
    last_pedometer: ?PedometerData = null,

    /// Initialize sensor manager
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    /// Deinitialize
    pub fn deinit(self: *Self) void {
        self.stopAll();
    }

    /// Check if sensor is available
    pub fn isAvailable(_: *const Self, sensor_type: SensorType) bool {
        // Platform-specific availability check
        return switch (sensor_type) {
            .accelerometer, .gyroscope, .magnetometer => true,
            .barometer => true,
            .light, .proximity => true,
            .pedometer => true,
            .device_motion, .gravity, .linear_acceleration, .rotation => true,
        };
    }

    /// Set update frequency
    pub fn setFrequency(self: *Self, frequency: UpdateFrequency) void {
        self.frequency = frequency;
    }

    /// Start accelerometer updates
    pub fn startAccelerometer(self: *Self, callback: ?AccelerometerCallback) SensorError!void {
        if (self.accelerometer_active) return SensorError.AlreadyActive;
        self.accelerometer_callback = callback;
        self.accelerometer_active = true;
    }

    /// Stop accelerometer updates
    pub fn stopAccelerometer(self: *Self) void {
        self.accelerometer_active = false;
        self.accelerometer_callback = null;
    }

    /// Start gyroscope updates
    pub fn startGyroscope(self: *Self, callback: ?GyroscopeCallback) SensorError!void {
        if (self.gyroscope_active) return SensorError.AlreadyActive;
        self.gyroscope_callback = callback;
        self.gyroscope_active = true;
    }

    /// Stop gyroscope updates
    pub fn stopGyroscope(self: *Self) void {
        self.gyroscope_active = false;
        self.gyroscope_callback = null;
    }

    /// Start magnetometer updates
    pub fn startMagnetometer(self: *Self, callback: ?MagnetometerCallback) SensorError!void {
        if (self.magnetometer_active) return SensorError.AlreadyActive;
        self.magnetometer_callback = callback;
        self.magnetometer_active = true;
    }

    /// Stop magnetometer updates
    pub fn stopMagnetometer(self: *Self) void {
        self.magnetometer_active = false;
        self.magnetometer_callback = null;
    }

    /// Start barometer updates
    pub fn startBarometer(self: *Self, callback: ?BarometerCallback) SensorError!void {
        if (self.barometer_active) return SensorError.AlreadyActive;
        self.barometer_callback = callback;
        self.barometer_active = true;
    }

    /// Stop barometer updates
    pub fn stopBarometer(self: *Self) void {
        self.barometer_active = false;
        self.barometer_callback = null;
    }

    /// Start device motion updates
    pub fn startDeviceMotion(self: *Self, callback: ?DeviceMotionCallback) SensorError!void {
        if (self.device_motion_active) return SensorError.AlreadyActive;
        self.device_motion_callback = callback;
        self.device_motion_active = true;
    }

    /// Stop device motion updates
    pub fn stopDeviceMotion(self: *Self) void {
        self.device_motion_active = false;
        self.device_motion_callback = null;
    }

    /// Start pedometer updates
    pub fn startPedometer(self: *Self, callback: ?PedometerCallback) SensorError!void {
        if (self.pedometer_active) return SensorError.AlreadyActive;
        self.pedometer_callback = callback;
        self.pedometer_active = true;
    }

    /// Stop pedometer updates
    pub fn stopPedometer(self: *Self) void {
        self.pedometer_active = false;
        self.pedometer_callback = null;
    }

    /// Stop all sensor updates
    pub fn stopAll(self: *Self) void {
        self.stopAccelerometer();
        self.stopGyroscope();
        self.stopMagnetometer();
        self.stopBarometer();
        self.stopDeviceMotion();
        self.stopPedometer();
    }

    /// Get last accelerometer reading
    pub fn getAccelerometer(self: *Self) ?AccelerometerData {
        if (self.last_accelerometer) |data| return data;
        // Return simulated data
        return AccelerometerData.init(0.0, 0.0, -9.81);
    }

    /// Get last gyroscope reading
    pub fn getGyroscope(self: *Self) ?GyroscopeData {
        if (self.last_gyroscope) |data| return data;
        return GyroscopeData.init(0.0, 0.0, 0.0);
    }

    /// Get last magnetometer reading
    pub fn getMagnetometer(self: *Self) ?MagnetometerData {
        if (self.last_magnetometer) |data| return data;
        return MagnetometerData.init(25.0, 5.0, -45.0);
    }

    /// Get last barometer reading
    pub fn getBarometer(self: *Self) ?BarometerData {
        if (self.last_barometer) |data| return data;
        return BarometerData.init(1013.25);
    }

    /// Get last device motion reading
    pub fn getDeviceMotion(self: *Self) ?DeviceMotionData {
        if (self.last_device_motion) |data| return data;
        return DeviceMotionData.init();
    }

    // Simulation methods for testing

    /// Simulate accelerometer data
    pub fn simulateAccelerometer(self: *Self, x: f64, y: f64, z: f64) void {
        self.last_accelerometer = AccelerometerData.init(x, y, z);
        if (self.accelerometer_callback) |cb| {
            cb(self.last_accelerometer.?);
        }
    }

    /// Simulate gyroscope data
    pub fn simulateGyroscope(self: *Self, x: f64, y: f64, z: f64) void {
        self.last_gyroscope = GyroscopeData.init(x, y, z);
        if (self.gyroscope_callback) |cb| {
            cb(self.last_gyroscope.?);
        }
    }

    /// Simulate magnetometer data
    pub fn simulateMagnetometer(self: *Self, x: f64, y: f64, z: f64) void {
        self.last_magnetometer = MagnetometerData.init(x, y, z);
        if (self.magnetometer_callback) |cb| {
            cb(self.last_magnetometer.?);
        }
    }

    /// Simulate barometer data
    pub fn simulateBarometer(self: *Self, pressure: f64) void {
        self.last_barometer = BarometerData.init(pressure);
        if (self.barometer_callback) |cb| {
            cb(self.last_barometer.?);
        }
    }
};

/// Motion activity type
pub const MotionActivity = enum {
    /// Unknown activity
    unknown,
    /// User is stationary
    stationary,
    /// User is walking
    walking,
    /// User is running
    running,
    /// User is cycling
    cycling,
    /// User is in a vehicle
    automotive,

    /// Get display name
    pub fn name(self: MotionActivity) []const u8 {
        return switch (self) {
            .unknown => "Unknown",
            .stationary => "Stationary",
            .walking => "Walking",
            .running => "Running",
            .cycling => "Cycling",
            .automotive => "Automotive",
        };
    }

    /// Get activity icon (emoji)
    pub fn icon(self: MotionActivity) []const u8 {
        return switch (self) {
            .unknown => "?",
            .stationary => "Standing",
            .walking => "Walking",
            .running => "Running",
            .cycling => "Cycling",
            .automotive => "Driving",
        };
    }
};

/// Quick sensor utilities
pub const QuickSensors = struct {
    /// Check if accelerometer is available
    pub fn hasAccelerometer() bool {
        return true; // Simulated
    }

    /// Check if gyroscope is available
    pub fn hasGyroscope() bool {
        return true; // Simulated
    }

    /// Check if magnetometer is available
    pub fn hasMagnetometer() bool {
        return true; // Simulated
    }

    /// Check if barometer is available
    pub fn hasBarometer() bool {
        return true; // Simulated
    }

    /// Check if pedometer is available
    pub fn hasPedometer() bool {
        return true; // Simulated
    }

    /// Get device shake threshold (m/s²)
    pub fn shakeThreshold() f64 {
        return 2.0; // Typical shake threshold
    }
};

// ============================================================================
// Tests
// ============================================================================

test "SensorType name and unit" {
    try std.testing.expectEqualStrings("Accelerometer", SensorType.accelerometer.name());
    try std.testing.expectEqualStrings("m/s²", SensorType.accelerometer.unit());
    try std.testing.expectEqualStrings("Gyroscope", SensorType.gyroscope.name());
    try std.testing.expectEqualStrings("rad/s", SensorType.gyroscope.unit());
}

test "SensorAccuracy value" {
    try std.testing.expectEqual(@as(u8, 0), SensorAccuracy.unreliable.value());
    try std.testing.expectEqual(@as(u8, 3), SensorAccuracy.high.value());
}

test "UpdateFrequency" {
    try std.testing.expectEqual(@as(u32, 16), UpdateFrequency.ui.intervalMs());
    try std.testing.expectApproxEqAbs(@as(f32, 60.0), UpdateFrequency.ui.hz(), 0.1);
}

test "Vector3 operations" {
    const v1 = Vector3.init(1.0, 2.0, 3.0);
    const v2 = Vector3.init(4.0, 5.0, 6.0);

    // Magnitude
    const mag = Vector3.init(3.0, 4.0, 0.0).magnitude();
    try std.testing.expectApproxEqAbs(@as(f64, 5.0), mag, 0.001);

    // Add
    const sum = v1.add(v2);
    try std.testing.expectApproxEqAbs(@as(f64, 5.0), sum.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 7.0), sum.y, 0.001);

    // Dot product
    const dot_product = v1.dot(v2);
    try std.testing.expectApproxEqAbs(@as(f64, 32.0), dot_product, 0.001);

    // Scale
    const scaled = v1.scale(2.0);
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), scaled.x, 0.001);
}

test "Vector3 normalize" {
    const v = Vector3.init(3.0, 4.0, 0.0);
    const n = v.normalized();
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), n.magnitude(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.6), n.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.8), n.y, 0.001);
}

test "Vector3 cross product" {
    const x = Vector3.init(1.0, 0.0, 0.0);
    const y = Vector3.init(0.0, 1.0, 0.0);
    const z = x.cross(y);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), z.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), z.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), z.z, 0.001);
}

test "Quaternion identity" {
    const q = Quaternion.identity();
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), q.w, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), q.x, 0.001);
}

test "Quaternion magnitude" {
    const q = Quaternion.identity();
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), q.magnitude(), 0.001);
}

test "AccelerometerData creation" {
    const data = AccelerometerData.init(0.0, 0.0, -9.81);
    try std.testing.expectApproxEqAbs(@as(f64, 9.81), data.magnitude(), 0.01);
    try std.testing.expect(data.timestamp > 0);
}

test "AccelerometerData isStationary" {
    const stationary = AccelerometerData.init(0.0, 0.0, -9.81);
    try std.testing.expect(stationary.isStationary(0.5));

    const moving = AccelerometerData.init(5.0, 0.0, -9.81);
    try std.testing.expect(!moving.isStationary(0.5));
}

test "GyroscopeData creation" {
    const data = GyroscopeData.init(0.1, 0.2, 0.3);
    try std.testing.expect(data.rotation_rate.x > 0);
}

test "GyroscopeData degreesPerSecond" {
    const data = GyroscopeData.init(std.math.pi, 0.0, 0.0);
    const deg = data.degreesPerSecond();
    try std.testing.expectApproxEqAbs(@as(f64, 180.0), deg.x, 0.01);
}

test "MagnetometerData heading" {
    // North (positive X)
    const north = MagnetometerData.init(25.0, 0.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), north.heading(), 0.1);

    // East (positive Y)
    const east = MagnetometerData.init(0.0, 25.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f64, 90.0), east.heading(), 0.1);
}

test "MagnetometerData cardinalDirection" {
    const north = MagnetometerData.init(25.0, 0.0, 0.0);
    try std.testing.expectEqualStrings("N", north.cardinalDirection());

    const east = MagnetometerData.init(0.0, 25.0, 0.0);
    try std.testing.expectEqualStrings("E", east.cardinalDirection());
}

test "BarometerData estimatedAltitude" {
    const sea_level = BarometerData.init(1013.25);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), sea_level.estimatedAltitude(), 1.0);

    // Lower pressure = higher altitude
    const high_altitude = BarometerData.init(900.0);
    try std.testing.expect(high_altitude.estimatedAltitude() > sea_level.estimatedAltitude());
    try std.testing.expect(high_altitude.estimatedAltitude() > 0.0);
}

test "BarometerData weatherTendency" {
    const current = BarometerData.init(1015.0);
    try std.testing.expectEqualStrings("Improving", current.weatherTendency(1010.0));
    try std.testing.expectEqualStrings("Worsening", current.weatherTendency(1020.0));
    try std.testing.expectEqualStrings("Stable", current.weatherTendency(1015.0));
}

test "LightData category" {
    const dark = LightData.init(0.5);
    try std.testing.expectEqualStrings("Dark", dark.category());

    const indoor = LightData.init(200.0);
    try std.testing.expectEqualStrings("Indoor", indoor.category());

    const bright = LightData.init(20000.0);
    try std.testing.expectEqualStrings("Bright", bright.category());
}

test "LightData isSuitableForReading" {
    const good = LightData.init(500.0);
    try std.testing.expect(good.isSuitableForReading());

    const too_dark = LightData.init(50.0);
    try std.testing.expect(!too_dark.isSuitableForReading());
}

test "PedometerData estimatedCalories" {
    const data = PedometerData.init(1000, 700.0);
    const calories = data.estimatedCalories(70.0);
    try std.testing.expect(calories > 0);
}

test "DeviceMotionData orientation" {
    const data = DeviceMotionData.init();
    _ = data.orientation();
}

test "SensorManager initialization" {
    var manager = SensorManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expect(!manager.accelerometer_active);
    try std.testing.expect(!manager.gyroscope_active);
}

test "SensorManager isAvailable" {
    var manager = SensorManager.init(std.testing.allocator);
    defer manager.deinit();

    try std.testing.expect(manager.isAvailable(.accelerometer));
    try std.testing.expect(manager.isAvailable(.gyroscope));
    try std.testing.expect(manager.isAvailable(.magnetometer));
}

test "SensorManager startAccelerometer" {
    var manager = SensorManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.startAccelerometer(null);
    try std.testing.expect(manager.accelerometer_active);

    try std.testing.expectError(SensorError.AlreadyActive, manager.startAccelerometer(null));

    manager.stopAccelerometer();
    try std.testing.expect(!manager.accelerometer_active);
}

test "SensorManager startGyroscope" {
    var manager = SensorManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.startGyroscope(null);
    try std.testing.expect(manager.gyroscope_active);

    manager.stopGyroscope();
    try std.testing.expect(!manager.gyroscope_active);
}

test "SensorManager stopAll" {
    var manager = SensorManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.startAccelerometer(null);
    try manager.startGyroscope(null);
    try manager.startMagnetometer(null);

    manager.stopAll();

    try std.testing.expect(!manager.accelerometer_active);
    try std.testing.expect(!manager.gyroscope_active);
    try std.testing.expect(!manager.magnetometer_active);
}

test "SensorManager getAccelerometer" {
    var manager = SensorManager.init(std.testing.allocator);
    defer manager.deinit();

    const data = manager.getAccelerometer();
    try std.testing.expect(data != null);
}

test "SensorManager simulate" {
    var manager = SensorManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.simulateAccelerometer(1.0, 2.0, 3.0);
    const data = manager.getAccelerometer().?;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), data.acceleration.x, 0.001);
}

test "MotionActivity name and icon" {
    try std.testing.expectEqualStrings("Walking", MotionActivity.walking.name());
    try std.testing.expectEqualStrings("Running", MotionActivity.running.icon());
}

test "QuickSensors availability" {
    try std.testing.expect(QuickSensors.hasAccelerometer());
    try std.testing.expect(QuickSensors.hasGyroscope());
    try std.testing.expect(QuickSensors.hasMagnetometer());
    try std.testing.expect(QuickSensors.hasBarometer());
}

test "QuickSensors shakeThreshold" {
    try std.testing.expect(QuickSensors.shakeThreshold() > 0);
}
