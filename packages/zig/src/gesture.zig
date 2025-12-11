const std = @import("std");

/// Gesture Recognition Module
/// Provides comprehensive touch and trackpad gesture recognition for Craft apps.
/// Supports tap, long press, swipe, pinch, rotation, and pan gestures.

// =============================================================================
// Touch Point and Event Types
// =============================================================================

/// Represents a single touch point
pub const TouchPoint = struct {
    id: u32,
    x: f32,
    y: f32,
    pressure: f32 = 1.0,
    timestamp: i64,

    pub fn distance(self: TouchPoint, other: TouchPoint) f32 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        return @sqrt(dx * dx + dy * dy);
    }
};

/// Touch event phase
pub const TouchPhase = enum {
    began,
    moved,
    stationary,
    ended,
    cancelled,
};

/// Touch event containing all active touches
pub const TouchEvent = struct {
    touches: []const TouchPoint,
    phase: TouchPhase,
    timestamp: i64,
};

// =============================================================================
// Gesture Types and States
// =============================================================================

/// Types of gestures that can be recognized
pub const GestureType = enum {
    tap,
    double_tap,
    triple_tap,
    long_press,
    swipe_left,
    swipe_right,
    swipe_up,
    swipe_down,
    pinch,
    rotation,
    pan,
    edge_swipe_left,
    edge_swipe_right,
    edge_swipe_top,
    edge_swipe_bottom,
};

/// Gesture recognition state
pub const GestureState = enum {
    possible, // Gesture recognition has not started
    began, // Gesture recognition started
    changed, // Gesture value has changed
    ended, // Gesture recognition ended successfully
    cancelled, // Gesture was cancelled
    failed, // Gesture recognition failed
};

/// Direction for swipe gestures
pub const SwipeDirection = enum {
    left,
    right,
    up,
    down,

    pub fn fromVelocity(vx: f32, vy: f32) ?SwipeDirection {
        const abs_vx = @abs(vx);
        const abs_vy = @abs(vy);

        if (abs_vx > abs_vy) {
            if (vx < 0) return .left;
            if (vx > 0) return .right;
        } else {
            if (vy < 0) return .up;
            if (vy > 0) return .down;
        }
        return null;
    }
};

// =============================================================================
// Gesture Data Structures
// =============================================================================

/// Data for tap gestures
pub const TapData = struct {
    tap_count: u32,
    position: struct { x: f32, y: f32 },
};

/// Data for long press gesture
pub const LongPressData = struct {
    position: struct { x: f32, y: f32 },
    duration_ms: u64,
};

/// Data for swipe gesture
pub const SwipeData = struct {
    direction: SwipeDirection,
    velocity: struct { x: f32, y: f32 },
    start_position: struct { x: f32, y: f32 },
    end_position: struct { x: f32, y: f32 },
};

/// Data for pinch gesture
pub const PinchData = struct {
    scale: f32, // 1.0 = no change, >1.0 = zoom in, <1.0 = zoom out
    velocity: f32, // Scale change per second
    center: struct { x: f32, y: f32 },
};

/// Data for rotation gesture
pub const RotationData = struct {
    angle: f32, // Rotation angle in radians
    velocity: f32, // Radians per second
    center: struct { x: f32, y: f32 },
};

/// Data for pan gesture
pub const PanData = struct {
    translation: struct { x: f32, y: f32 },
    velocity: struct { x: f32, y: f32 },
    position: struct { x: f32, y: f32 },
};

/// Union of all gesture data types
pub const GestureData = union(GestureType) {
    tap: TapData,
    double_tap: TapData,
    triple_tap: TapData,
    long_press: LongPressData,
    swipe_left: SwipeData,
    swipe_right: SwipeData,
    swipe_up: SwipeData,
    swipe_down: SwipeData,
    pinch: PinchData,
    rotation: RotationData,
    pan: PanData,
    edge_swipe_left: SwipeData,
    edge_swipe_right: SwipeData,
    edge_swipe_top: SwipeData,
    edge_swipe_bottom: SwipeData,
};

/// Complete gesture event
pub const GestureEvent = struct {
    gesture_type: GestureType,
    state: GestureState,
    data: GestureData,
    timestamp: i64,
};

// =============================================================================
// Gesture Configuration
// =============================================================================

/// Configuration for gesture recognition
pub const GestureConfig = struct {
    // Tap configuration
    tap_max_duration_ms: u64 = 300,
    tap_max_distance: f32 = 10.0,
    double_tap_max_interval_ms: u64 = 300,
    triple_tap_max_interval_ms: u64 = 300,

    // Long press configuration
    long_press_min_duration_ms: u64 = 500,
    long_press_max_movement: f32 = 10.0,

    // Swipe configuration
    swipe_min_distance: f32 = 50.0,
    swipe_min_velocity: f32 = 100.0,
    swipe_max_duration_ms: u64 = 500,

    // Pinch configuration
    pinch_min_scale_change: f32 = 0.02,

    // Rotation configuration
    rotation_min_angle_change: f32 = 0.05, // radians (~3 degrees)

    // Pan configuration
    pan_min_distance: f32 = 5.0,

    // Edge swipe configuration
    edge_threshold: f32 = 20.0, // pixels from edge
    screen_width: f32 = 390.0, // Default iPhone width
    screen_height: f32 = 844.0, // Default iPhone height

    // General
    touch_slop: f32 = 8.0, // Minimum movement to consider gesture started
};

// =============================================================================
// Gesture Recognizer Base
// =============================================================================

/// Callback type for gesture events
pub const GestureCallback = *const fn (event: GestureEvent) void;

/// Base gesture recognizer interface
pub const GestureRecognizer = struct {
    gesture_type: GestureType,
    state: GestureState,
    enabled: bool,
    callback: ?GestureCallback,
    config: GestureConfig,

    // Internal tracking
    start_time: i64,
    start_position: struct { x: f32, y: f32 },
    current_position: struct { x: f32, y: f32 },
    touch_count: u32,

    const Self = @This();

    pub fn init(gesture_type: GestureType, config: GestureConfig) Self {
        return Self{
            .gesture_type = gesture_type,
            .state = .possible,
            .enabled = true,
            .callback = null,
            .config = config,
            .start_time = 0,
            .start_position = .{ .x = 0, .y = 0 },
            .current_position = .{ .x = 0, .y = 0 },
            .touch_count = 0,
        };
    }

    pub fn setCallback(self: *Self, callback: GestureCallback) void {
        self.callback = callback;
    }

    pub fn reset(self: *Self) void {
        self.state = .possible;
        self.start_time = 0;
        self.touch_count = 0;
    }

    fn emit(self: *Self, data: GestureData, timestamp: i64) void {
        if (self.callback) |cb| {
            cb(.{
                .gesture_type = self.gesture_type,
                .state = self.state,
                .data = data,
                .timestamp = timestamp,
            });
        }
    }
};

// =============================================================================
// Tap Recognizer
// =============================================================================

pub const TapRecognizer = struct {
    base: GestureRecognizer,
    required_taps: u32,
    tap_count: u32,
    last_tap_time: i64,
    last_tap_position: struct { x: f32, y: f32 },

    const Self = @This();

    pub fn init(required_taps: u32, config: GestureConfig) Self {
        const gesture_type: GestureType = switch (required_taps) {
            1 => .tap,
            2 => .double_tap,
            3 => .triple_tap,
            else => .tap,
        };

        return Self{
            .base = GestureRecognizer.init(gesture_type, config),
            .required_taps = required_taps,
            .tap_count = 0,
            .last_tap_time = 0,
            .last_tap_position = .{ .x = 0, .y = 0 },
        };
    }

    pub fn handleTouch(self: *Self, event: TouchEvent) void {
        if (!self.base.enabled or event.touches.len == 0) return;

        const touch = event.touches[0];

        switch (event.phase) {
            .began => {
                self.base.start_time = event.timestamp;
                self.base.start_position = .{ .x = touch.x, .y = touch.y };
                self.base.state = .possible;
            },
            .moved => {
                // Check if moved too far
                const dx = touch.x - self.base.start_position.x;
                const dy = touch.y - self.base.start_position.y;
                const distance = @sqrt(dx * dx + dy * dy);

                if (distance > self.base.config.tap_max_distance) {
                    self.base.state = .failed;
                }
            },
            .ended => {
                if (self.base.state == .failed) {
                    self.reset();
                    return;
                }

                // Check duration
                const duration = event.timestamp - self.base.start_time;
                if (duration > @as(i64, @intCast(self.base.config.tap_max_duration_ms))) {
                    self.base.state = .failed;
                    self.reset();
                    return;
                }

                // Check interval from last tap
                const interval = event.timestamp - self.last_tap_time;
                const max_interval = switch (self.required_taps) {
                    2 => self.base.config.double_tap_max_interval_ms,
                    3 => self.base.config.triple_tap_max_interval_ms,
                    else => self.base.config.double_tap_max_interval_ms,
                };

                if (self.tap_count > 0 and interval > @as(i64, @intCast(max_interval))) {
                    // Reset tap count if too long between taps
                    self.tap_count = 0;
                }

                // Check position from last tap
                if (self.tap_count > 0) {
                    const dx = touch.x - self.last_tap_position.x;
                    const dy = touch.y - self.last_tap_position.y;
                    const distance = @sqrt(dx * dx + dy * dy);
                    if (distance > self.base.config.tap_max_distance * 2) {
                        self.tap_count = 0;
                    }
                }

                self.tap_count += 1;
                self.last_tap_time = event.timestamp;
                self.last_tap_position = .{ .x = touch.x, .y = touch.y };

                if (self.tap_count >= self.required_taps) {
                    self.base.state = .ended;
                    self.base.emit(.{
                        .tap = .{
                            .tap_count = self.tap_count,
                            .position = .{ .x = touch.x, .y = touch.y },
                        },
                    }, event.timestamp);
                    self.reset();
                }
            },
            .cancelled => {
                self.base.state = .cancelled;
                self.reset();
            },
            .stationary => {},
        }
    }

    pub fn reset(self: *Self) void {
        self.base.reset();
        self.tap_count = 0;
    }
};

// =============================================================================
// Long Press Recognizer
// =============================================================================

pub const LongPressRecognizer = struct {
    base: GestureRecognizer,
    press_start: i64,

    const Self = @This();

    pub fn init(config: GestureConfig) Self {
        return Self{
            .base = GestureRecognizer.init(.long_press, config),
            .press_start = 0,
        };
    }

    pub fn handleTouch(self: *Self, event: TouchEvent) void {
        if (!self.base.enabled or event.touches.len == 0) return;

        const touch = event.touches[0];

        switch (event.phase) {
            .began => {
                self.press_start = event.timestamp;
                self.base.start_position = .{ .x = touch.x, .y = touch.y };
                self.base.state = .possible;
            },
            .moved => {
                const dx = touch.x - self.base.start_position.x;
                const dy = touch.y - self.base.start_position.y;
                const distance = @sqrt(dx * dx + dy * dy);

                if (distance > self.base.config.long_press_max_movement) {
                    self.base.state = .failed;
                }
            },
            .stationary => {
                if (self.base.state != .possible) return;

                const duration: u64 = @intCast(event.timestamp - self.press_start);
                if (duration >= self.base.config.long_press_min_duration_ms) {
                    self.base.state = .began;
                    self.base.emit(.{
                        .long_press = .{
                            .position = .{ .x = touch.x, .y = touch.y },
                            .duration_ms = duration,
                        },
                    }, event.timestamp);
                }
            },
            .ended => {
                if (self.base.state == .began) {
                    self.base.state = .ended;
                    const duration: u64 = @intCast(event.timestamp - self.press_start);
                    self.base.emit(.{
                        .long_press = .{
                            .position = .{ .x = touch.x, .y = touch.y },
                            .duration_ms = duration,
                        },
                    }, event.timestamp);
                }
                self.base.reset();
            },
            .cancelled => {
                self.base.state = .cancelled;
                self.base.reset();
            },
        }
    }

    /// Poll for long press (call periodically if using polling model)
    pub fn update(self: *Self, current_time: i64, current_position: struct { x: f32, y: f32 }) void {
        if (self.base.state != .possible or self.press_start == 0) return;

        const duration: u64 = @intCast(current_time - self.press_start);
        if (duration >= self.base.config.long_press_min_duration_ms) {
            self.base.state = .began;
            self.base.emit(.{
                .long_press = .{
                    .position = current_position,
                    .duration_ms = duration,
                },
            }, current_time);
        }
    }
};

// =============================================================================
// Swipe Recognizer
// =============================================================================

pub const SwipeRecognizer = struct {
    base: GestureRecognizer,
    allowed_directions: []const SwipeDirection,
    start_time: i64,
    start_pos: struct { x: f32, y: f32 },

    const Self = @This();

    pub fn init(directions: []const SwipeDirection, config: GestureConfig) Self {
        return Self{
            .base = GestureRecognizer.init(.swipe_right, config), // Will be updated on detection
            .allowed_directions = directions,
            .start_time = 0,
            .start_pos = .{ .x = 0, .y = 0 },
        };
    }

    pub fn handleTouch(self: *Self, event: TouchEvent) void {
        if (!self.base.enabled or event.touches.len == 0) return;

        const touch = event.touches[0];

        switch (event.phase) {
            .began => {
                self.start_time = event.timestamp;
                self.start_pos = .{ .x = touch.x, .y = touch.y };
                self.base.state = .possible;
            },
            .moved => {
                self.base.current_position = .{ .x = touch.x, .y = touch.y };
            },
            .ended => {
                if (self.base.state != .possible) {
                    self.base.reset();
                    return;
                }

                const dx = touch.x - self.start_pos.x;
                const dy = touch.y - self.start_pos.y;
                const distance = @sqrt(dx * dx + dy * dy);

                // Check minimum distance
                if (distance < self.base.config.swipe_min_distance) {
                    self.base.state = .failed;
                    self.base.reset();
                    return;
                }

                // Check duration
                const duration = event.timestamp - self.start_time;
                if (duration > @as(i64, @intCast(self.base.config.swipe_max_duration_ms))) {
                    self.base.state = .failed;
                    self.base.reset();
                    return;
                }

                // Calculate velocity
                const duration_sec = @as(f32, @floatFromInt(duration)) / 1000.0;
                const vx = dx / duration_sec;
                const vy = dy / duration_sec;
                const velocity = @sqrt(vx * vx + vy * vy);

                // Check minimum velocity
                if (velocity < self.base.config.swipe_min_velocity) {
                    self.base.state = .failed;
                    self.base.reset();
                    return;
                }

                // Determine direction
                if (SwipeDirection.fromVelocity(vx, vy)) |direction| {
                    // Check if direction is allowed
                    var allowed = false;
                    for (self.allowed_directions) |d| {
                        if (d == direction) {
                            allowed = true;
                            break;
                        }
                    }

                    if (allowed) {
                        self.base.state = .ended;
                        const gesture_type: GestureType = switch (direction) {
                            .left => .swipe_left,
                            .right => .swipe_right,
                            .up => .swipe_up,
                            .down => .swipe_down,
                        };
                        self.base.gesture_type = gesture_type;

                        const swipe_data = SwipeData{
                            .direction = direction,
                            .velocity = .{ .x = vx, .y = vy },
                            .start_position = self.start_pos,
                            .end_position = .{ .x = touch.x, .y = touch.y },
                        };

                        self.base.emit(switch (direction) {
                            .left => .{ .swipe_left = swipe_data },
                            .right => .{ .swipe_right = swipe_data },
                            .up => .{ .swipe_up = swipe_data },
                            .down => .{ .swipe_down = swipe_data },
                        }, event.timestamp);
                    }
                }

                self.base.reset();
            },
            .cancelled => {
                self.base.state = .cancelled;
                self.base.reset();
            },
            .stationary => {},
        }
    }
};

// =============================================================================
// Pinch Recognizer
// =============================================================================

pub const PinchRecognizer = struct {
    base: GestureRecognizer,
    initial_distance: f32,
    previous_distance: f32,
    last_update_time: i64,

    const Self = @This();

    pub fn init(config: GestureConfig) Self {
        return Self{
            .base = GestureRecognizer.init(.pinch, config),
            .initial_distance = 0,
            .previous_distance = 0,
            .last_update_time = 0,
        };
    }

    pub fn handleTouch(self: *Self, event: TouchEvent) void {
        if (!self.base.enabled) return;

        // Pinch requires exactly 2 touches
        if (event.touches.len != 2) {
            if (self.base.state == .changed or self.base.state == .began) {
                self.base.state = .ended;
                self.base.reset();
            }
            return;
        }

        const touch1 = event.touches[0];
        const touch2 = event.touches[1];
        const current_distance = touch1.distance(touch2);
        const center_x = (touch1.x + touch2.x) / 2.0;
        const center_y = (touch1.y + touch2.y) / 2.0;

        switch (event.phase) {
            .began => {
                self.initial_distance = current_distance;
                self.previous_distance = current_distance;
                self.last_update_time = event.timestamp;
                self.base.state = .began;

                self.base.emit(.{
                    .pinch = .{
                        .scale = 1.0,
                        .velocity = 0,
                        .center = .{ .x = center_x, .y = center_y },
                    },
                }, event.timestamp);
            },
            .moved => {
                if (self.initial_distance == 0) return;

                const scale = current_distance / self.initial_distance;
                const scale_change = @abs(current_distance - self.previous_distance) / self.initial_distance;

                if (scale_change >= self.base.config.pinch_min_scale_change) {
                    self.base.state = .changed;

                    // Calculate velocity
                    const dt = @as(f32, @floatFromInt(event.timestamp - self.last_update_time)) / 1000.0;
                    const velocity = if (dt > 0) (current_distance - self.previous_distance) / dt / self.initial_distance else 0;

                    self.base.emit(.{
                        .pinch = .{
                            .scale = scale,
                            .velocity = velocity,
                            .center = .{ .x = center_x, .y = center_y },
                        },
                    }, event.timestamp);

                    self.previous_distance = current_distance;
                    self.last_update_time = event.timestamp;
                }
            },
            .ended => {
                if (self.base.state == .changed or self.base.state == .began) {
                    self.base.state = .ended;
                    const scale = current_distance / self.initial_distance;
                    self.base.emit(.{
                        .pinch = .{
                            .scale = scale,
                            .velocity = 0,
                            .center = .{ .x = center_x, .y = center_y },
                        },
                    }, event.timestamp);
                }
                self.reset();
            },
            .cancelled => {
                self.base.state = .cancelled;
                self.reset();
            },
            .stationary => {},
        }
    }

    pub fn reset(self: *Self) void {
        self.base.reset();
        self.initial_distance = 0;
        self.previous_distance = 0;
    }
};

// =============================================================================
// Rotation Recognizer
// =============================================================================

pub const RotationRecognizer = struct {
    base: GestureRecognizer,
    initial_angle: f32,
    previous_angle: f32,
    total_rotation: f32,
    last_update_time: i64,

    const Self = @This();

    pub fn init(config: GestureConfig) Self {
        return Self{
            .base = GestureRecognizer.init(.rotation, config),
            .initial_angle = 0,
            .previous_angle = 0,
            .total_rotation = 0,
            .last_update_time = 0,
        };
    }

    fn calculateAngle(touch1: TouchPoint, touch2: TouchPoint) f32 {
        return std.math.atan2(touch2.y - touch1.y, touch2.x - touch1.x);
    }

    pub fn handleTouch(self: *Self, event: TouchEvent) void {
        if (!self.base.enabled) return;

        // Rotation requires exactly 2 touches
        if (event.touches.len != 2) {
            if (self.base.state == .changed or self.base.state == .began) {
                self.base.state = .ended;
                self.base.reset();
            }
            return;
        }

        const touch1 = event.touches[0];
        const touch2 = event.touches[1];
        const current_angle = calculateAngle(touch1, touch2);
        const center_x = (touch1.x + touch2.x) / 2.0;
        const center_y = (touch1.y + touch2.y) / 2.0;

        switch (event.phase) {
            .began => {
                self.initial_angle = current_angle;
                self.previous_angle = current_angle;
                self.total_rotation = 0;
                self.last_update_time = event.timestamp;
                self.base.state = .began;

                self.base.emit(.{
                    .rotation = .{
                        .angle = 0,
                        .velocity = 0,
                        .center = .{ .x = center_x, .y = center_y },
                    },
                }, event.timestamp);
            },
            .moved => {
                var angle_change = current_angle - self.previous_angle;

                // Handle angle wrapping
                if (angle_change > std.math.pi) {
                    angle_change -= 2.0 * std.math.pi;
                } else if (angle_change < -std.math.pi) {
                    angle_change += 2.0 * std.math.pi;
                }

                if (@abs(angle_change) >= self.base.config.rotation_min_angle_change) {
                    self.total_rotation += angle_change;
                    self.base.state = .changed;

                    // Calculate velocity
                    const dt = @as(f32, @floatFromInt(event.timestamp - self.last_update_time)) / 1000.0;
                    const velocity = if (dt > 0) angle_change / dt else 0;

                    self.base.emit(.{
                        .rotation = .{
                            .angle = self.total_rotation,
                            .velocity = velocity,
                            .center = .{ .x = center_x, .y = center_y },
                        },
                    }, event.timestamp);

                    self.previous_angle = current_angle;
                    self.last_update_time = event.timestamp;
                }
            },
            .ended => {
                if (self.base.state == .changed or self.base.state == .began) {
                    self.base.state = .ended;
                    self.base.emit(.{
                        .rotation = .{
                            .angle = self.total_rotation,
                            .velocity = 0,
                            .center = .{ .x = center_x, .y = center_y },
                        },
                    }, event.timestamp);
                }
                self.reset();
            },
            .cancelled => {
                self.base.state = .cancelled;
                self.reset();
            },
            .stationary => {},
        }
    }

    pub fn reset(self: *Self) void {
        self.base.reset();
        self.initial_angle = 0;
        self.previous_angle = 0;
        self.total_rotation = 0;
    }
};

// =============================================================================
// Pan Recognizer
// =============================================================================

pub const PanRecognizer = struct {
    base: GestureRecognizer,
    start_pos: struct { x: f32, y: f32 },
    previous_pos: struct { x: f32, y: f32 },
    last_update_time: i64,
    min_touches: u32,
    max_touches: u32,

    const Self = @This();

    pub fn init(min_touches: u32, max_touches: u32, config: GestureConfig) Self {
        return Self{
            .base = GestureRecognizer.init(.pan, config),
            .start_pos = .{ .x = 0, .y = 0 },
            .previous_pos = .{ .x = 0, .y = 0 },
            .last_update_time = 0,
            .min_touches = min_touches,
            .max_touches = max_touches,
        };
    }

    fn getAveragePosition(touches: []const TouchPoint) struct { x: f32, y: f32 } {
        var sum_x: f32 = 0;
        var sum_y: f32 = 0;
        for (touches) |t| {
            sum_x += t.x;
            sum_y += t.y;
        }
        const count: f32 = @floatFromInt(touches.len);
        return .{ .x = sum_x / count, .y = sum_y / count };
    }

    pub fn handleTouch(self: *Self, event: TouchEvent) void {
        if (!self.base.enabled) return;

        const touch_count = event.touches.len;
        if (touch_count < self.min_touches or touch_count > self.max_touches) {
            if (self.base.state == .changed or self.base.state == .began) {
                self.base.state = .ended;
                const pos = if (touch_count > 0) getAveragePosition(event.touches) else self.previous_pos;
                const translation = .{
                    .x = pos.x - self.start_pos.x,
                    .y = pos.y - self.start_pos.y,
                };
                self.base.emit(.{
                    .pan = .{
                        .translation = translation,
                        .velocity = .{ .x = 0, .y = 0 },
                        .position = pos,
                    },
                }, event.timestamp);
            }
            self.reset();
            return;
        }

        const pos = getAveragePosition(event.touches);

        switch (event.phase) {
            .began => {
                self.start_pos = pos;
                self.previous_pos = pos;
                self.last_update_time = event.timestamp;
                self.base.state = .possible;
            },
            .moved => {
                const dx = pos.x - self.start_pos.x;
                const dy = pos.y - self.start_pos.y;
                const distance = @sqrt(dx * dx + dy * dy);

                if (self.base.state == .possible) {
                    if (distance >= self.base.config.pan_min_distance) {
                        self.base.state = .began;

                        self.base.emit(.{
                            .pan = .{
                                .translation = .{ .x = dx, .y = dy },
                                .velocity = .{ .x = 0, .y = 0 },
                                .position = pos,
                            },
                        }, event.timestamp);
                    }
                } else if (self.base.state == .began or self.base.state == .changed) {
                    self.base.state = .changed;

                    // Calculate velocity
                    const dt = @as(f32, @floatFromInt(event.timestamp - self.last_update_time)) / 1000.0;
                    const vx = if (dt > 0) (pos.x - self.previous_pos.x) / dt else 0;
                    const vy = if (dt > 0) (pos.y - self.previous_pos.y) / dt else 0;

                    self.base.emit(.{
                        .pan = .{
                            .translation = .{ .x = dx, .y = dy },
                            .velocity = .{ .x = vx, .y = vy },
                            .position = pos,
                        },
                    }, event.timestamp);

                    self.previous_pos = pos;
                    self.last_update_time = event.timestamp;
                }
            },
            .ended => {
                if (self.base.state == .changed or self.base.state == .began) {
                    self.base.state = .ended;

                    // Calculate final velocity
                    const dt = @as(f32, @floatFromInt(event.timestamp - self.last_update_time)) / 1000.0;
                    const vx = if (dt > 0) (pos.x - self.previous_pos.x) / dt else 0;
                    const vy = if (dt > 0) (pos.y - self.previous_pos.y) / dt else 0;

                    self.base.emit(.{
                        .pan = .{
                            .translation = .{
                                .x = pos.x - self.start_pos.x,
                                .y = pos.y - self.start_pos.y,
                            },
                            .velocity = .{ .x = vx, .y = vy },
                            .position = pos,
                        },
                    }, event.timestamp);
                }
                self.reset();
            },
            .cancelled => {
                self.base.state = .cancelled;
                self.reset();
            },
            .stationary => {},
        }
    }

    pub fn reset(self: *Self) void {
        self.base.reset();
        self.start_pos = .{ .x = 0, .y = 0 };
        self.previous_pos = .{ .x = 0, .y = 0 };
    }
};

// =============================================================================
// Edge Swipe Recognizer
// =============================================================================

pub const EdgeSwipeRecognizer = struct {
    base: GestureRecognizer,
    edge: Edge,
    start_pos: struct { x: f32, y: f32 },
    start_time: i64,

    pub const Edge = enum {
        left,
        right,
        top,
        bottom,
    };

    const Self = @This();

    pub fn init(edge: Edge, config: GestureConfig) Self {
        const gesture_type: GestureType = switch (edge) {
            .left => .edge_swipe_left,
            .right => .edge_swipe_right,
            .top => .edge_swipe_top,
            .bottom => .edge_swipe_bottom,
        };

        return Self{
            .base = GestureRecognizer.init(gesture_type, config),
            .edge = edge,
            .start_pos = .{ .x = 0, .y = 0 },
            .start_time = 0,
        };
    }

    fn isNearEdge(self: *Self, x: f32, y: f32) bool {
        const threshold = self.base.config.edge_threshold;
        return switch (self.edge) {
            .left => x < threshold,
            .right => x > self.base.config.screen_width - threshold,
            .top => y < threshold,
            .bottom => y > self.base.config.screen_height - threshold,
        };
    }

    pub fn handleTouch(self: *Self, event: TouchEvent) void {
        if (!self.base.enabled or event.touches.len == 0) return;

        const touch = event.touches[0];

        switch (event.phase) {
            .began => {
                if (self.isNearEdge(touch.x, touch.y)) {
                    self.start_pos = .{ .x = touch.x, .y = touch.y };
                    self.start_time = event.timestamp;
                    self.base.state = .possible;
                } else {
                    self.base.state = .failed;
                }
            },
            .moved => {
                // Track movement
                self.base.current_position = .{ .x = touch.x, .y = touch.y };
            },
            .ended => {
                if (self.base.state != .possible) {
                    self.base.reset();
                    return;
                }

                const dx = touch.x - self.start_pos.x;
                const dy = touch.y - self.start_pos.y;
                const distance = @sqrt(dx * dx + dy * dy);

                // Check minimum distance
                if (distance < self.base.config.swipe_min_distance) {
                    self.base.state = .failed;
                    self.base.reset();
                    return;
                }

                // Verify swipe direction matches edge
                const valid_direction = switch (self.edge) {
                    .left => dx > 0 and @abs(dx) > @abs(dy),
                    .right => dx < 0 and @abs(dx) > @abs(dy),
                    .top => dy > 0 and @abs(dy) > @abs(dx),
                    .bottom => dy < 0 and @abs(dy) > @abs(dx),
                };

                if (valid_direction) {
                    self.base.state = .ended;

                    const duration = event.timestamp - self.start_time;
                    const duration_sec = @as(f32, @floatFromInt(duration)) / 1000.0;
                    const vx = dx / duration_sec;
                    const vy = dy / duration_sec;

                    const direction: SwipeDirection = switch (self.edge) {
                        .left => .right,
                        .right => .left,
                        .top => .down,
                        .bottom => .up,
                    };

                    const swipe_data = SwipeData{
                        .direction = direction,
                        .velocity = .{ .x = vx, .y = vy },
                        .start_position = self.start_pos,
                        .end_position = .{ .x = touch.x, .y = touch.y },
                    };

                    self.base.emit(switch (self.edge) {
                        .left => .{ .edge_swipe_left = swipe_data },
                        .right => .{ .edge_swipe_right = swipe_data },
                        .top => .{ .edge_swipe_top = swipe_data },
                        .bottom => .{ .edge_swipe_bottom = swipe_data },
                    }, event.timestamp);
                }

                self.base.reset();
            },
            .cancelled => {
                self.base.state = .cancelled;
                self.base.reset();
            },
            .stationary => {},
        }
    }
};

// =============================================================================
// Gesture Manager
// =============================================================================

/// Manages multiple gesture recognizers
pub const GestureManager = struct {
    allocator: std.mem.Allocator,
    tap_recognizers: std.ArrayListUnmanaged(*TapRecognizer),
    long_press_recognizers: std.ArrayListUnmanaged(*LongPressRecognizer),
    swipe_recognizers: std.ArrayListUnmanaged(*SwipeRecognizer),
    pinch_recognizers: std.ArrayListUnmanaged(*PinchRecognizer),
    rotation_recognizers: std.ArrayListUnmanaged(*RotationRecognizer),
    pan_recognizers: std.ArrayListUnmanaged(*PanRecognizer),
    edge_swipe_recognizers: std.ArrayListUnmanaged(*EdgeSwipeRecognizer),
    config: GestureConfig,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: GestureConfig) Self {
        return Self{
            .allocator = allocator,
            .tap_recognizers = .{},
            .long_press_recognizers = .{},
            .swipe_recognizers = .{},
            .pinch_recognizers = .{},
            .rotation_recognizers = .{},
            .pan_recognizers = .{},
            .edge_swipe_recognizers = .{},
            .config = config,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.tap_recognizers.items) |r| self.allocator.destroy(r);
        for (self.long_press_recognizers.items) |r| self.allocator.destroy(r);
        for (self.swipe_recognizers.items) |r| self.allocator.destroy(r);
        for (self.pinch_recognizers.items) |r| self.allocator.destroy(r);
        for (self.rotation_recognizers.items) |r| self.allocator.destroy(r);
        for (self.pan_recognizers.items) |r| self.allocator.destroy(r);
        for (self.edge_swipe_recognizers.items) |r| self.allocator.destroy(r);

        self.tap_recognizers.deinit(self.allocator);
        self.long_press_recognizers.deinit(self.allocator);
        self.swipe_recognizers.deinit(self.allocator);
        self.pinch_recognizers.deinit(self.allocator);
        self.rotation_recognizers.deinit(self.allocator);
        self.pan_recognizers.deinit(self.allocator);
        self.edge_swipe_recognizers.deinit(self.allocator);
    }

    /// Add a tap recognizer
    pub fn addTapRecognizer(self: *Self, required_taps: u32, callback: GestureCallback) !*TapRecognizer {
        const recognizer = try self.allocator.create(TapRecognizer);
        recognizer.* = TapRecognizer.init(required_taps, self.config);
        recognizer.base.setCallback(callback);
        try self.tap_recognizers.append(self.allocator, recognizer);
        return recognizer;
    }

    /// Add a long press recognizer
    pub fn addLongPressRecognizer(self: *Self, callback: GestureCallback) !*LongPressRecognizer {
        const recognizer = try self.allocator.create(LongPressRecognizer);
        recognizer.* = LongPressRecognizer.init(self.config);
        recognizer.base.setCallback(callback);
        try self.long_press_recognizers.append(self.allocator, recognizer);
        return recognizer;
    }

    /// Add a swipe recognizer
    pub fn addSwipeRecognizer(self: *Self, directions: []const SwipeDirection, callback: GestureCallback) !*SwipeRecognizer {
        const recognizer = try self.allocator.create(SwipeRecognizer);
        recognizer.* = SwipeRecognizer.init(directions, self.config);
        recognizer.base.setCallback(callback);
        try self.swipe_recognizers.append(self.allocator, recognizer);
        return recognizer;
    }

    /// Add a pinch recognizer
    pub fn addPinchRecognizer(self: *Self, callback: GestureCallback) !*PinchRecognizer {
        const recognizer = try self.allocator.create(PinchRecognizer);
        recognizer.* = PinchRecognizer.init(self.config);
        recognizer.base.setCallback(callback);
        try self.pinch_recognizers.append(self.allocator, recognizer);
        return recognizer;
    }

    /// Add a rotation recognizer
    pub fn addRotationRecognizer(self: *Self, callback: GestureCallback) !*RotationRecognizer {
        const recognizer = try self.allocator.create(RotationRecognizer);
        recognizer.* = RotationRecognizer.init(self.config);
        recognizer.base.setCallback(callback);
        try self.rotation_recognizers.append(self.allocator, recognizer);
        return recognizer;
    }

    /// Add a pan recognizer
    pub fn addPanRecognizer(self: *Self, min_touches: u32, max_touches: u32, callback: GestureCallback) !*PanRecognizer {
        const recognizer = try self.allocator.create(PanRecognizer);
        recognizer.* = PanRecognizer.init(min_touches, max_touches, self.config);
        recognizer.base.setCallback(callback);
        try self.pan_recognizers.append(self.allocator, recognizer);
        return recognizer;
    }

    /// Add an edge swipe recognizer
    pub fn addEdgeSwipeRecognizer(self: *Self, edge: EdgeSwipeRecognizer.Edge, callback: GestureCallback) !*EdgeSwipeRecognizer {
        const recognizer = try self.allocator.create(EdgeSwipeRecognizer);
        recognizer.* = EdgeSwipeRecognizer.init(edge, self.config);
        recognizer.base.setCallback(callback);
        try self.edge_swipe_recognizers.append(self.allocator, recognizer);
        return recognizer;
    }

    /// Process a touch event through all recognizers
    pub fn handleTouch(self: *Self, event: TouchEvent) void {
        for (self.tap_recognizers.items) |r| r.handleTouch(event);
        for (self.long_press_recognizers.items) |r| r.handleTouch(event);
        for (self.swipe_recognizers.items) |r| r.handleTouch(event);
        for (self.pinch_recognizers.items) |r| r.handleTouch(event);
        for (self.rotation_recognizers.items) |r| r.handleTouch(event);
        for (self.pan_recognizers.items) |r| r.handleTouch(event);
        for (self.edge_swipe_recognizers.items) |r| r.handleTouch(event);
    }

    /// Reset all recognizers
    pub fn resetAll(self: *Self) void {
        for (self.tap_recognizers.items) |r| r.reset();
        for (self.long_press_recognizers.items) |r| r.base.reset();
        for (self.swipe_recognizers.items) |r| r.base.reset();
        for (self.pinch_recognizers.items) |r| r.reset();
        for (self.rotation_recognizers.items) |r| r.reset();
        for (self.pan_recognizers.items) |r| r.reset();
        for (self.edge_swipe_recognizers.items) |r| r.base.reset();
    }
};

// =============================================================================
// Gesture Presets
// =============================================================================

/// Pre-configured gesture setups for common use cases
pub const GesturePresets = struct {
    /// iOS-style navigation gestures
    pub fn iosNavigation() GestureConfig {
        return .{
            .edge_threshold = 20.0,
            .swipe_min_distance = 100.0,
            .swipe_min_velocity = 500.0,
            .screen_width = 390.0,
            .screen_height = 844.0,
        };
    }

    /// macOS trackpad gestures
    pub fn macosTrackpad() GestureConfig {
        return .{
            .pinch_min_scale_change = 0.01,
            .rotation_min_angle_change = 0.03,
            .swipe_min_distance = 30.0,
            .swipe_min_velocity = 50.0,
            .tap_max_distance = 5.0,
        };
    }

    /// Touch screen (tablet/phone)
    pub fn touchscreen() GestureConfig {
        return .{
            .tap_max_duration_ms = 250,
            .long_press_min_duration_ms = 400,
            .swipe_min_distance = 75.0,
            .swipe_min_velocity = 200.0,
            .pan_min_distance = 10.0,
        };
    }

    /// Gaming/precise input
    pub fn gaming() GestureConfig {
        return .{
            .tap_max_duration_ms = 150,
            .double_tap_max_interval_ms = 200,
            .swipe_min_velocity = 300.0,
            .pan_min_distance = 3.0,
            .touch_slop = 4.0,
        };
    }

    /// Accessibility (larger thresholds, longer timeouts)
    pub fn accessibility() GestureConfig {
        return .{
            .tap_max_duration_ms = 500,
            .tap_max_distance = 20.0,
            .double_tap_max_interval_ms = 500,
            .long_press_min_duration_ms = 800,
            .long_press_max_movement = 20.0,
            .swipe_min_distance = 100.0,
            .swipe_min_velocity = 50.0,
            .swipe_max_duration_ms = 1000,
            .touch_slop = 15.0,
        };
    }
};

// =============================================================================
// Tests
// =============================================================================

test "TouchPoint distance calculation" {
    const p1 = TouchPoint{ .id = 0, .x = 0, .y = 0, .timestamp = 0 };
    const p2 = TouchPoint{ .id = 1, .x = 3, .y = 4, .timestamp = 0 };
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), p1.distance(p2), 0.001);
}

test "SwipeDirection from velocity" {
    try std.testing.expectEqual(SwipeDirection.left, SwipeDirection.fromVelocity(-100, 0));
    try std.testing.expectEqual(SwipeDirection.right, SwipeDirection.fromVelocity(100, 0));
    try std.testing.expectEqual(SwipeDirection.up, SwipeDirection.fromVelocity(0, -100));
    try std.testing.expectEqual(SwipeDirection.down, SwipeDirection.fromVelocity(0, 100));
}

test "TapRecognizer single tap" {
    var recognizer = TapRecognizer.init(1, .{});
    try std.testing.expect(recognizer.required_taps == 1);
    try std.testing.expect(recognizer.base.state == .possible);
    try std.testing.expect(recognizer.tap_count == 0);
}

test "TapRecognizer double tap" {
    var recognizer = TapRecognizer.init(2, .{});
    try std.testing.expect(recognizer.required_taps == 2);
    try std.testing.expect(recognizer.base.gesture_type == .double_tap);
}

test "TapRecognizer triple tap" {
    var recognizer = TapRecognizer.init(3, .{});
    try std.testing.expect(recognizer.required_taps == 3);
    try std.testing.expect(recognizer.base.gesture_type == .triple_tap);
}

test "GestureConfig defaults" {
    const config = GestureConfig{};
    try std.testing.expect(config.tap_max_duration_ms == 300);
    try std.testing.expect(config.long_press_min_duration_ms == 500);
    try std.testing.expect(config.swipe_min_distance == 50.0);
}

test "GesturePresets" {
    const ios = GesturePresets.iosNavigation();
    try std.testing.expect(ios.edge_threshold == 20.0);

    const macos = GesturePresets.macosTrackpad();
    try std.testing.expect(macos.pinch_min_scale_change == 0.01);

    const a11y = GesturePresets.accessibility();
    try std.testing.expect(a11y.tap_max_duration_ms == 500);
}

test "GestureManager initialization" {
    const allocator = std.testing.allocator;
    var manager = GestureManager.init(allocator, .{});
    defer manager.deinit();

    try std.testing.expect(manager.tap_recognizers.items.len == 0);
}

test "PinchRecognizer state transitions" {
    var recognizer = PinchRecognizer.init(.{});
    try std.testing.expect(recognizer.base.state == .possible);
    try std.testing.expect(recognizer.initial_distance == 0);
}

test "RotationRecognizer angle calculation" {
    const t1 = TouchPoint{ .id = 0, .x = 0, .y = 0, .timestamp = 0 };
    const t2 = TouchPoint{ .id = 1, .x = 1, .y = 0, .timestamp = 0 };
    const angle = RotationRecognizer.calculateAngle(t1, t2);
    try std.testing.expectApproxEqAbs(@as(f32, 0), angle, 0.001);
}

test "PanRecognizer average position" {
    const touches = [_]TouchPoint{
        .{ .id = 0, .x = 0, .y = 0, .timestamp = 0 },
        .{ .id = 1, .x = 10, .y = 10, .timestamp = 0 },
    };
    const avg = PanRecognizer.getAveragePosition(&touches);
    try std.testing.expectApproxEqAbs(@as(f32, 5), avg.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5), avg.y, 0.001);
}

test "EdgeSwipeRecognizer edge detection" {
    var recognizer = EdgeSwipeRecognizer.init(.left, .{
        .edge_threshold = 20.0,
        .screen_width = 400.0,
        .screen_height = 800.0,
    });

    try std.testing.expect(recognizer.isNearEdge(5, 400));
    try std.testing.expect(!recognizer.isNearEdge(50, 400));
}
