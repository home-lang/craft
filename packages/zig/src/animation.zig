const std = @import("std");

/// Animation System
/// Provides comprehensive animation support with easing functions and transitions

pub const EasingFunction = enum {
    linear,
    ease_in_quad,
    ease_out_quad,
    ease_in_out_quad,
    ease_in_cubic,
    ease_out_cubic,
    ease_in_out_cubic,
    ease_in_quart,
    ease_out_quart,
    ease_in_out_quart,
    ease_in_quint,
    ease_out_quint,
    ease_in_out_quint,
    ease_in_sine,
    ease_out_sine,
    ease_in_out_sine,
    ease_in_expo,
    ease_out_expo,
    ease_in_out_expo,
    ease_in_circ,
    ease_out_circ,
    ease_in_out_circ,
    ease_in_back,
    ease_out_back,
    ease_in_out_back,
    ease_in_elastic,
    ease_out_elastic,
    ease_in_out_elastic,
    ease_in_bounce,
    ease_out_bounce,
    ease_in_out_bounce,

    pub fn apply(self: EasingFunction, t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        return switch (self) {
            .linear => clamped,
            .ease_in_quad => clamped * clamped,
            .ease_out_quad => clamped * (2.0 - clamped),
            .ease_in_out_quad => if (clamped < 0.5) 2.0 * clamped * clamped else -1.0 + (4.0 - 2.0 * clamped) * clamped,
            .ease_in_cubic => clamped * clamped * clamped,
            .ease_out_cubic => blk: {
                const x = clamped - 1.0;
                break :blk x * x * x + 1.0;
            },
            .ease_in_out_cubic => if (clamped < 0.5) 4.0 * clamped * clamped * clamped else blk: {
                const x = (2.0 * clamped - 2.0);
                break :blk (x * x * x + 2.0) / 2.0;
            },
            .ease_in_sine => 1.0 - @cos((clamped * std.math.pi) / 2.0),
            .ease_out_sine => @sin((clamped * std.math.pi) / 2.0),
            .ease_in_out_sine => -(@cos(std.math.pi * clamped) - 1.0) / 2.0,
            .ease_in_expo => if (clamped == 0.0) 0.0 else std.math.pow(f32, 2.0, 10.0 * clamped - 10.0),
            .ease_out_expo => if (clamped == 1.0) 1.0 else 1.0 - std.math.pow(f32, 2.0, -10.0 * clamped),
            .ease_in_out_expo => if (clamped == 0.0) 0.0 else if (clamped == 1.0) 1.0 else if (clamped < 0.5) std.math.pow(f32, 2.0, 20.0 * clamped - 10.0) / 2.0 else (2.0 - std.math.pow(f32, 2.0, -20.0 * clamped + 10.0)) / 2.0,
            .ease_out_bounce => easeOutBounce(clamped),
            .ease_in_bounce => 1.0 - easeOutBounce(1.0 - clamped),
            .ease_in_out_bounce => if (clamped < 0.5) (1.0 - easeOutBounce(1.0 - 2.0 * clamped)) / 2.0 else (1.0 + easeOutBounce(2.0 * clamped - 1.0)) / 2.0,
            else => clamped, // Fallback for complex easings
        };
    }

    fn easeOutBounce(t: f32) f32 {
        const n1: f32 = 7.5625;
        const d1: f32 = 2.75;

        if (t < 1.0 / d1) {
            return n1 * t * t;
        } else if (t < 2.0 / d1) {
            const t2 = t - 1.5 / d1;
            return n1 * t2 * t2 + 0.75;
        } else if (t < 2.5 / d1) {
            const t2 = t - 2.25 / d1;
            return n1 * t2 * t2 + 0.9375;
        } else {
            const t2 = t - 2.625 / d1;
            return n1 * t2 * t2 + 0.984375;
        }
    }
};

pub const AnimationState = enum {
    idle,
    running,
    paused,
    completed,
    canceled,
};

pub const Animation = struct {
    start_value: f32,
    end_value: f32,
    duration_ms: u64,
    easing: EasingFunction,
    state: AnimationState,
    elapsed_ms: u64,
    start_time: ?std.time.Instant,
    pause_time: ?std.time.Instant,
    on_update: ?*const fn (f32) void,
    on_complete: ?*const fn () void,

    pub fn init(start_val: f32, end_val: f32, duration_ms: u64, easing: EasingFunction) Animation {
        return Animation{
            .start_value = start_val,
            .end_value = end_val,
            .duration_ms = duration_ms,
            .easing = easing,
            .state = .idle,
            .elapsed_ms = 0,
            .start_time = null,
            .pause_time = null,
            .on_update = null,
            .on_complete = null,
        };
    }

    pub fn start(self: *Animation) void {
        self.state = .running;
        self.start_time = std.time.Instant.now() catch null;
        self.elapsed_ms = 0;
    }

    pub fn pause(self: *Animation) void {
        if (self.state == .running) {
            self.state = .paused;
            self.pause_time = std.time.Instant.now() catch null;
        }
    }

    /// Resume a paused animation (named 'unpause' because 'resume' is a Zig keyword)
    pub fn unpause(self: *Animation) void {
        if (self.state == .paused) {
            self.state = .running;
            // Calculate pause duration and adjust start time
            if (self.pause_time) |pt| {
                if (self.start_time) |st| {
                    const now = std.time.Instant.now() catch return;
                    const pause_duration_ns = now.since(pt);
                    // We can't easily adjust Instant, so we track elapsed separately
                    _ = st;
                    _ = pause_duration_ns;
                }
            }
        }
    }

    pub fn cancel(self: *Animation) void {
        self.state = .canceled;
    }

    pub fn reset(self: *Animation) void {
        self.state = .idle;
        self.elapsed_ms = 0;
        self.start_time = null;
        self.pause_time = null;
    }

    pub fn update(self: *Animation) f32 {
        if (self.state != .running) {
            return if (self.state == .completed) self.end_value else self.start_value;
        }

        const start_instant = self.start_time orelse return self.start_value;
        const now = std.time.Instant.now() catch return self.start_value;
        const elapsed_ns = now.since(start_instant);
        self.elapsed_ms = elapsed_ns / std.time.ns_per_ms;

        if (self.elapsed_ms >= self.duration_ms) {
            self.state = .completed;
            if (self.on_complete) |callback| {
                callback();
            }
            return self.end_value;
        }

        const progress = @as(f32, @floatFromInt(self.elapsed_ms)) / @as(f32, @floatFromInt(self.duration_ms));
        const eased = self.easing.apply(progress);
        const current = self.start_value + (self.end_value - self.start_value) * eased;

        if (self.on_update) |callback| {
            callback(current);
        }

        return current;
    }

    pub fn getCurrentValue(self: Animation) f32 {
        if (self.state == .completed) return self.end_value;
        if (self.state != .running) return self.start_value;

        const start_instant = self.start_time orelse return self.start_value;
        const now = std.time.Instant.now() catch return self.start_value;
        const elapsed_ns = now.since(start_instant);
        const elapsed = elapsed_ns / std.time.ns_per_ms;

        if (elapsed >= self.duration_ms) return self.end_value;

        const progress = @as(f32, @floatFromInt(elapsed)) / @as(f32, @floatFromInt(self.duration_ms));
        const eased = self.easing.apply(progress);
        return self.start_value + (self.end_value - self.start_value) * eased;
    }

    pub fn isComplete(self: Animation) bool {
        return self.state == .completed;
    }

    pub fn isRunning(self: Animation) bool {
        return self.state == .running;
    }
};

pub const Keyframe = struct {
    time: f32, // 0.0 to 1.0
    value: f32,
    easing: EasingFunction,
};

pub const KeyframeAnimation = struct {
    keyframes: []const Keyframe,
    duration_ms: u64,
    state: AnimationState,
    elapsed_ms: u64,
    start_time: ?std.time.Instant,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, keyframes: []const Keyframe, duration_ms: u64) !KeyframeAnimation {
        return KeyframeAnimation{
            .keyframes = keyframes,
            .duration_ms = duration_ms,
            .state = .idle,
            .elapsed_ms = 0,
            .start_time = null,
            .allocator = allocator,
        };
    }

    pub fn start(self: *KeyframeAnimation) void {
        self.state = .running;
        self.start_time = std.time.Instant.now() catch null;
    }

    pub fn update(self: *KeyframeAnimation) f32 {
        if (self.state != .running) return 0.0;

        const start_instant = self.start_time orelse return 0.0;
        const now = std.time.Instant.now() catch return 0.0;
        const elapsed_ns = now.since(start_instant);
        self.elapsed_ms = elapsed_ns / std.time.ns_per_ms;

        if (self.elapsed_ms >= self.duration_ms) {
            self.state = .completed;
            return self.keyframes[self.keyframes.len - 1].value;
        }

        const progress = @as(f32, @floatFromInt(self.elapsed_ms)) / @as(f32, @floatFromInt(self.duration_ms));

        // Find surrounding keyframes
        var prev_kf = self.keyframes[0];
        var next_kf = self.keyframes[self.keyframes.len - 1];

        for (self.keyframes, 0..) |kf, i| {
            if (kf.time <= progress) {
                prev_kf = kf;
                if (i + 1 < self.keyframes.len) {
                    next_kf = self.keyframes[i + 1];
                }
            } else {
                break;
            }
        }

        // Interpolate between keyframes
        const segment_progress = if (next_kf.time - prev_kf.time > 0.0) (progress - prev_kf.time) / (next_kf.time - prev_kf.time) else 0.0;

        const eased = prev_kf.easing.apply(segment_progress);
        return prev_kf.value + (next_kf.value - prev_kf.value) * eased;
    }
};

pub const SpringAnimation = struct {
    position: f32,
    velocity: f32,
    target: f32,
    stiffness: f32,
    damping: f32,
    mass: f32,
    state: AnimationState,
    threshold: f32,

    pub fn init(initial: f32, target: f32) SpringAnimation {
        return SpringAnimation{
            .position = initial,
            .velocity = 0.0,
            .target = target,
            .stiffness = 200.0,
            .damping = 10.0,
            .mass = 1.0,
            .state = .idle,
            .threshold = 0.01,
        };
    }

    pub fn start(self: *SpringAnimation) void {
        self.state = .running;
    }

    pub fn update(self: *SpringAnimation, dt: f32) f32 {
        if (self.state != .running) return self.position;

        const spring_force = -self.stiffness * (self.position - self.target);
        const damping_force = -self.damping * self.velocity;
        const acceleration = (spring_force + damping_force) / self.mass;

        self.velocity += acceleration * dt;
        self.position += self.velocity * dt;

        // Check if spring has settled
        if (@abs(self.position - self.target) < self.threshold and @abs(self.velocity) < self.threshold) {
            self.position = self.target;
            self.velocity = 0.0;
            self.state = .completed;
        }

        return self.position;
    }

    pub fn setTarget(self: *SpringAnimation, target: f32) void {
        self.target = target;
        self.state = .running;
    }
};

pub const AnimationSequence = struct {
    animations: std.ArrayList(*Animation),
    current_index: usize,
    state: AnimationState,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AnimationSequence {
        return AnimationSequence{
            .animations = std.ArrayList(*Animation).init(allocator),
            .current_index = 0,
            .state = .idle,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AnimationSequence) void {
        self.animations.deinit();
    }

    pub fn add(self: *AnimationSequence, animation: *Animation) !void {
        try self.animations.append(animation);
    }

    pub fn start(self: *AnimationSequence) void {
        if (self.animations.items.len > 0) {
            self.state = .running;
            self.current_index = 0;
            self.animations.items[0].start();
        }
    }

    pub fn update(self: *AnimationSequence) void {
        if (self.state != .running) return;
        if (self.current_index >= self.animations.items.len) {
            self.state = .completed;
            return;
        }

        const current = self.animations.items[self.current_index];
        _ = current.update();

        if (current.isComplete()) {
            self.current_index += 1;
            if (self.current_index < self.animations.items.len) {
                self.animations.items[self.current_index].start();
            } else {
                self.state = .completed;
            }
        }
    }
};

pub const AnimationGroup = struct {
    animations: std.ArrayList(*Animation),
    state: AnimationState,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AnimationGroup {
        return AnimationGroup{
            .animations = std.ArrayList(*Animation).init(allocator),
            .state = .idle,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AnimationGroup) void {
        self.animations.deinit();
    }

    pub fn add(self: *AnimationGroup, animation: *Animation) !void {
        try self.animations.append(animation);
    }

    pub fn start(self: *AnimationGroup) void {
        self.state = .running;
        for (self.animations.items) |anim| {
            anim.start();
        }
    }

    pub fn update(self: *AnimationGroup) void {
        if (self.state != .running) return;

        var all_complete = true;
        for (self.animations.items) |anim| {
            _ = anim.update();
            if (!anim.isComplete()) {
                all_complete = false;
            }
        }

        if (all_complete) {
            self.state = .completed;
        }
    }

    pub fn pause(self: *AnimationGroup) void {
        for (self.animations.items) |anim| {
            anim.pause();
        }
        self.state = .paused;
    }

    /// Resume all paused animations (named 'unpause' because 'resume' is a Zig keyword)
    pub fn unpause(self: *AnimationGroup) void {
        for (self.animations.items) |anim| {
            anim.unpause();
        }
        self.state = .running;
    }
};

pub const Transition = struct {
    property: []const u8,
    animation: Animation,
    active: bool,

    pub fn init(property: []const u8, start_val: f32, end_val: f32, duration_ms: u64, easing: EasingFunction) Transition {
        return Transition{
            .property = property,
            .animation = Animation.init(start_val, end_val, duration_ms, easing),
            .active = false,
        };
    }

    pub fn start(self: *Transition) void {
        self.active = true;
        self.animation.start();
    }

    pub fn update(self: *Transition) ?f32 {
        if (!self.active) return null;
        const value = self.animation.update();
        if (self.animation.isComplete()) {
            self.active = false;
        }
        return value;
    }
};

pub const AnimationController = struct {
    animations: std.ArrayList(*Animation),
    sequences: std.ArrayList(*AnimationSequence),
    groups: std.ArrayList(*AnimationGroup),
    springs: std.ArrayList(*SpringAnimation),
    last_update: ?std.time.Instant,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AnimationController {
        return AnimationController{
            .animations = std.ArrayList(*Animation).init(allocator),
            .sequences = std.ArrayList(*AnimationSequence).init(allocator),
            .groups = std.ArrayList(*AnimationGroup).init(allocator),
            .springs = std.ArrayList(*SpringAnimation).init(allocator),
            .last_update = std.time.Instant.now() catch null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AnimationController) void {
        self.animations.deinit();
        self.sequences.deinit();
        self.groups.deinit();
        self.springs.deinit();
    }

    pub fn addAnimation(self: *AnimationController, animation: *Animation) !void {
        try self.animations.append(animation);
    }

    pub fn addSequence(self: *AnimationController, sequence: *AnimationSequence) !void {
        try self.sequences.append(sequence);
    }

    pub fn addGroup(self: *AnimationController, group: *AnimationGroup) !void {
        try self.groups.append(group);
    }

    pub fn addSpring(self: *AnimationController, spring: *SpringAnimation) !void {
        try self.springs.append(spring);
    }

    pub fn update(self: *AnimationController) void {
        const now = std.time.Instant.now() catch return;
        const dt = if (self.last_update) |last| blk: {
            const elapsed_ns = now.since(last);
            break :blk @as(f32, @floatFromInt(elapsed_ns)) / @as(f32, @floatFromInt(std.time.ns_per_s));
        } else 0.016; // Default to ~60fps if no last update
        self.last_update = now;

        // Update all animations
        for (self.animations.items) |anim| {
            _ = anim.update();
        }

        // Update sequences
        for (self.sequences.items) |seq| {
            seq.update();
        }

        // Update groups
        for (self.groups.items) |group| {
            group.update();
        }

        // Update springs
        for (self.springs.items) |spring| {
            _ = spring.update(dt);
        }
    }

    pub fn pauseAll(self: *AnimationController) void {
        for (self.animations.items) |anim| {
            anim.pause();
        }
        for (self.groups.items) |group| {
            group.pause();
        }
    }

    /// Resume all paused animations (named 'unpauseAll' because 'resume' is a Zig keyword)
    pub fn unpauseAll(self: *AnimationController) void {
        for (self.animations.items) |anim| {
            anim.unpause();
        }
        for (self.groups.items) |group| {
            group.unpause();
        }
    }

    pub fn cancelAll(self: *AnimationController) void {
        for (self.animations.items) |anim| {
            anim.cancel();
        }
    }
};

/// Common animation presets
pub const Presets = struct {
    // Fade animations
    pub fn fadeIn(duration_ms: u64) Animation {
        return Animation.init(0.0, 1.0, duration_ms, .ease_in_out_quad);
    }

    pub fn fadeOut(duration_ms: u64) Animation {
        return Animation.init(1.0, 0.0, duration_ms, .ease_in_out_quad);
    }

    pub fn fadeInSlow(duration_ms: u64) Animation {
        return Animation.init(0.0, 1.0, duration_ms, .ease_in_sine);
    }

    pub fn fadeOutSlow(duration_ms: u64) Animation {
        return Animation.init(1.0, 0.0, duration_ms, .ease_out_sine);
    }

    // Slide animations
    pub fn slideIn(start: f32, end: f32, duration_ms: u64) Animation {
        return Animation.init(start, end, duration_ms, .ease_out_cubic);
    }

    pub fn slideOut(start: f32, end: f32, duration_ms: u64) Animation {
        return Animation.init(start, end, duration_ms, .ease_in_cubic);
    }

    pub fn slideInLeft(duration_ms: u64) Animation {
        return Animation.init(-100.0, 0.0, duration_ms, .ease_out_cubic);
    }

    pub fn slideInRight(duration_ms: u64) Animation {
        return Animation.init(100.0, 0.0, duration_ms, .ease_out_cubic);
    }

    pub fn slideInTop(duration_ms: u64) Animation {
        return Animation.init(-100.0, 0.0, duration_ms, .ease_out_cubic);
    }

    pub fn slideInBottom(duration_ms: u64) Animation {
        return Animation.init(100.0, 0.0, duration_ms, .ease_out_cubic);
    }

    // Bounce animations
    pub fn bounce(start: f32, end: f32, duration_ms: u64) Animation {
        return Animation.init(start, end, duration_ms, .ease_out_bounce);
    }

    pub fn bounceIn(duration_ms: u64) Animation {
        return Animation.init(0.0, 1.0, duration_ms, .ease_out_bounce);
    }

    pub fn bounceOut(duration_ms: u64) Animation {
        return Animation.init(1.0, 0.0, duration_ms, .ease_in_bounce);
    }

    // Elastic animations
    pub fn elastic(start: f32, end: f32, duration_ms: u64) Animation {
        return Animation.init(start, end, duration_ms, .ease_out_elastic);
    }

    pub fn elasticIn(duration_ms: u64) Animation {
        return Animation.init(0.0, 1.0, duration_ms, .ease_in_elastic);
    }

    pub fn elasticOut(duration_ms: u64) Animation {
        return Animation.init(1.0, 0.0, duration_ms, .ease_out_elastic);
    }

    // Scale animations
    pub fn scaleIn(duration_ms: u64) Animation {
        return Animation.init(0.0, 1.0, duration_ms, .ease_out_back);
    }

    pub fn scaleOut(duration_ms: u64) Animation {
        return Animation.init(1.0, 0.0, duration_ms, .ease_in_back);
    }

    pub fn scaleUp(duration_ms: u64) Animation {
        return Animation.init(1.0, 1.2, duration_ms, .ease_out_quad);
    }

    pub fn scaleDown(duration_ms: u64) Animation {
        return Animation.init(1.0, 0.8, duration_ms, .ease_in_quad);
    }

    // Rotate animations
    pub fn rotate(start_deg: f32, end_deg: f32, duration_ms: u64) Animation {
        return Animation.init(start_deg, end_deg, duration_ms, .ease_in_out_cubic);
    }

    pub fn rotate360(duration_ms: u64) Animation {
        return Animation.init(0.0, 360.0, duration_ms, .linear);
    }

    pub fn rotateBack(duration_ms: u64) Animation {
        return Animation.init(0.0, 360.0, duration_ms, .ease_in_out_back);
    }

    // Pulse/heartbeat animations
    pub fn pulse(duration_ms: u64) Animation {
        return Animation.init(1.0, 1.1, duration_ms, .ease_in_out_sine);
    }

    pub fn heartbeat(duration_ms: u64) Animation {
        return Animation.init(1.0, 1.3, duration_ms, .ease_in_out_bounce);
    }

    // Shake/wobble animations
    pub fn shake(intensity: f32, duration_ms: u64) Animation {
        return Animation.init(-intensity, intensity, duration_ms, .ease_in_out_elastic);
    }

    pub fn wobble(duration_ms: u64) Animation {
        return Animation.init(-15.0, 15.0, duration_ms, .ease_in_out_elastic);
    }

    // Flip animations
    pub fn flipX(duration_ms: u64) Animation {
        return Animation.init(0.0, 180.0, duration_ms, .ease_in_out_back);
    }

    pub fn flipY(duration_ms: u64) Animation {
        return Animation.init(0.0, 180.0, duration_ms, .ease_in_out_back);
    }

    // Zoom animations
    pub fn zoomIn(duration_ms: u64) Animation {
        return Animation.init(0.3, 1.0, duration_ms, .ease_out_back);
    }

    pub fn zoomOut(duration_ms: u64) Animation {
        return Animation.init(1.0, 0.0, duration_ms, .ease_in_back);
    }

    // Roll animations
    pub fn rollIn(duration_ms: u64) Animation {
        return Animation.init(-120.0, 0.0, duration_ms, .ease_out_back);
    }

    pub fn rollOut(duration_ms: u64) Animation {
        return Animation.init(0.0, 120.0, duration_ms, .ease_in_back);
    }

    // Light speed animations
    pub fn lightSpeedIn(duration_ms: u64) Animation {
        return Animation.init(-100.0, 0.0, duration_ms, .ease_out_circ);
    }

    pub fn lightSpeedOut(duration_ms: u64) Animation {
        return Animation.init(0.0, 100.0, duration_ms, .ease_in_circ);
    }

    // Hinge animation
    pub fn hinge(duration_ms: u64) Animation {
        return Animation.init(0.0, 80.0, duration_ms, .ease_in_out_cubic);
    }

    // Jack in the box
    pub fn jackInTheBox(duration_ms: u64) Animation {
        return Animation.init(0.1, 1.0, duration_ms, .ease_in_out_bounce);
    }
};
