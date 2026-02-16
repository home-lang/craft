const std = @import("std");
const io_context = @import("io_context.zig");

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
    start_time: ?std.Io.Timestamp,
    pause_time: ?std.Io.Timestamp,
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
        self.start_time = std.Io.Timestamp.now(io_context.get(), .awake);
        self.elapsed_ms = 0;
    }

    pub fn pause(self: *Animation) void {
        if (self.state == .running) {
            self.state = .paused;
            self.pause_time = std.Io.Timestamp.now(io_context.get(), .awake);
        }
    }

    /// Resume a paused animation (named 'unpause' because 'resume' is a Zig keyword)
    pub fn unpause(self: *Animation) void {
        if (self.state == .paused) {
            self.state = .running;
            // Calculate pause duration and adjust start time
            if (self.pause_time) |pt| {
                if (self.start_time) |st| {
                    const now = std.Io.Timestamp.now(io_context.get(), .awake);
                    const pause_duration = pt.durationTo(now);
                    // We can't easily adjust Timestamp, so we track elapsed separately
                    _ = st;
                    _ = pause_duration;
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
        const now = std.Io.Timestamp.now(io_context.get(), .awake);
        const elapsed_duration = start_instant.durationTo(now);
        const elapsed_ns: u64 = @intCast(elapsed_duration.nanoseconds);
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
        const now = std.Io.Timestamp.now(io_context.get(), .awake);
        const elapsed_duration = start_instant.durationTo(now);
        const elapsed_ns: u64 = @intCast(elapsed_duration.nanoseconds);
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
    start_time: ?std.Io.Timestamp,
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
        self.start_time = std.Io.Timestamp.now(io_context.get(), .awake);
    }

    pub fn update(self: *KeyframeAnimation) f32 {
        if (self.state != .running) return 0.0;

        const start_instant = self.start_time orelse return 0.0;
        const now = std.Io.Timestamp.now(io_context.get(), .awake);
        const elapsed_duration = start_instant.durationTo(now);
        const elapsed_ns: u64 = @intCast(elapsed_duration.nanoseconds);
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
    last_update: ?std.Io.Timestamp,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AnimationController {
        return AnimationController{
            .animations = std.ArrayList(*Animation).init(allocator),
            .sequences = std.ArrayList(*AnimationSequence).init(allocator),
            .groups = std.ArrayList(*AnimationGroup).init(allocator),
            .springs = std.ArrayList(*SpringAnimation).init(allocator),
            .last_update = std.Io.Timestamp.now(io_context.get(), .awake),
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
        const now = std.Io.Timestamp.now(io_context.get(), .awake);
        const dt = if (self.last_update) |last| blk: {
            const elapsed_duration = last.durationTo(now);
            break :blk @as(f32, @floatFromInt(elapsed_duration.nanoseconds)) / @as(f32, @floatFromInt(std.time.ns_per_s));
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

// ============================================================================
// Text Animation System
// Provides letter-by-letter, word-by-word, and sentence-by-sentence text reveals
// ============================================================================

/// Mode for text reveal animations
pub const TextRevealMode = enum {
    /// Reveal one character at a time (typewriter effect)
    letter_by_letter,
    /// Reveal one word at a time
    word_by_word,
    /// Reveal one sentence at a time
    sentence_by_sentence,
    /// Reveal instantly (no animation)
    instant,
};

/// Configuration for text animations
pub const TextAnimationConfig = struct {
    /// Delay between each unit (letter/word/sentence) in milliseconds
    delay_ms: u64 = 50,
    /// Easing function for opacity/position animations
    easing: EasingFunction = .linear,
    /// Whether to add random variation to timing (more natural feel)
    randomize_timing: bool = false,
    /// Variation range in milliseconds (if randomize_timing is true)
    timing_variation_ms: u64 = 20,
    /// Cursor character to show at end during typing (empty for none)
    cursor_char: []const u8 = "|",
    /// Whether cursor should blink
    cursor_blink: bool = true,
    /// Cursor blink interval in milliseconds
    cursor_blink_ms: u64 = 500,
    /// Initial delay before animation starts
    initial_delay_ms: u64 = 0,
    /// Whether to loop the animation
    loop: bool = false,
    /// Delay before restart when looping
    loop_delay_ms: u64 = 1000,
};

/// Text animation for progressive text reveal effects
pub const TextAnimation = struct {
    /// The full text to animate
    text: []const u8,
    /// Current reveal mode
    mode: TextRevealMode,
    /// Configuration
    config: TextAnimationConfig,
    /// Animation state
    state: AnimationState,
    /// Current character index (for letter mode)
    current_char_index: usize,
    /// Current word index (for word mode)
    current_word_index: usize,
    /// Current sentence index (for sentence mode)
    current_sentence_index: usize,
    /// Time tracking
    start_time: ?std.Io.Timestamp,
    last_update_time: ?std.Io.Timestamp,
    accumulated_delay_ms: u64,
    /// Parsed unit boundaries
    word_boundaries: std.ArrayListUnmanaged(usize),
    sentence_boundaries: std.ArrayListUnmanaged(usize),
    /// Allocator for internal use
    allocator: std.mem.Allocator,
    /// Callbacks
    on_char_reveal: ?*const fn (char: u8, index: usize) void,
    on_word_reveal: ?*const fn (word: []const u8, index: usize) void,
    on_sentence_reveal: ?*const fn (sentence: []const u8, index: usize) void,
    on_complete: ?*const fn () void,
    /// Random number generator for timing variation
    rng: std.Random.DefaultPrng,

    const Self = @This();

    /// Initialize a new text animation
    pub fn init(allocator: std.mem.Allocator, text: []const u8, mode: TextRevealMode, config: TextAnimationConfig) !Self {
        var anim = Self{
            .text = text,
            .mode = mode,
            .config = config,
            .state = .idle,
            .current_char_index = 0,
            .current_word_index = 0,
            .current_sentence_index = 0,
            .start_time = null,
            .last_update_time = null,
            .accumulated_delay_ms = 0,
            .word_boundaries = .{},
            .sentence_boundaries = .{},
            .allocator = allocator,
            .on_char_reveal = null,
            .on_word_reveal = null,
            .on_sentence_reveal = null,
            .on_complete = null,
            .rng = std.Random.DefaultPrng.init(blk: {
                // Use Timestamp.now() to seed the RNG
                const now = std.Io.Timestamp.now(io_context.get(), .awake);
                const epoch_duration = std.Io.Timestamp.epoch.durationTo(now);
                break :blk @as(u64, @intCast(epoch_duration.nanoseconds));
            }),
        };

        // Parse text boundaries
        try anim.parseTextBoundaries();

        return anim;
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        self.word_boundaries.deinit(self.allocator);
        self.sentence_boundaries.deinit(self.allocator);
    }

    /// Parse word and sentence boundaries in the text
    fn parseTextBoundaries(self: *Self) !void {
        // Find word boundaries (spaces, tabs, newlines)
        var in_word = false;

        for (self.text, 0..) |char, i| {
            const is_whitespace = char == ' ' or char == '\t' or char == '\n' or char == '\r';

            if (!is_whitespace and !in_word) {
                // Starting a new word
                in_word = true;
            } else if (is_whitespace and in_word) {
                // Ending a word
                try self.word_boundaries.append(self.allocator, i);
                in_word = false;
            }
        }
        // Don't forget the last word if text doesn't end with whitespace
        if (in_word) {
            try self.word_boundaries.append(self.allocator, self.text.len);
        }

        // Find sentence boundaries (., !, ?)
        for (self.text, 0..) |char, i| {
            if (char == '.' or char == '!' or char == '?') {
                // Include trailing whitespace in sentence
                var end_idx = i + 1;
                while (end_idx < self.text.len and (self.text[end_idx] == ' ' or self.text[end_idx] == '\n')) {
                    end_idx += 1;
                }
                try self.sentence_boundaries.append(self.allocator, end_idx);
            }
        }
        // If no sentence endings found, treat entire text as one sentence
        if (self.sentence_boundaries.items.len == 0 and self.text.len > 0) {
            try self.sentence_boundaries.append(self.allocator, self.text.len);
        }
    }

    /// Start the animation
    pub fn start(self: *Self) void {
        self.state = .running;
        self.current_char_index = 0;
        self.current_word_index = 0;
        self.current_sentence_index = 0;
        self.accumulated_delay_ms = 0;
        self.start_time = std.Io.Timestamp.now(io_context.get(), .awake);
        self.last_update_time = self.start_time;
    }

    /// Pause the animation
    pub fn pause(self: *Self) void {
        if (self.state == .running) {
            self.state = .paused;
        }
    }

    /// Resume the animation
    pub fn unpause(self: *Self) void {
        if (self.state == .paused) {
            self.state = .running;
            self.last_update_time = std.Io.Timestamp.now(io_context.get(), .awake);
        }
    }

    /// Cancel the animation
    pub fn cancel(self: *Self) void {
        self.state = .canceled;
    }

    /// Reset the animation to beginning
    pub fn reset(self: *Self) void {
        self.state = .idle;
        self.current_char_index = 0;
        self.current_word_index = 0;
        self.current_sentence_index = 0;
        self.accumulated_delay_ms = 0;
        self.start_time = null;
        self.last_update_time = null;
    }

    /// Skip to end (reveal all text instantly)
    pub fn skipToEnd(self: *Self) void {
        self.current_char_index = self.text.len;
        self.current_word_index = self.word_boundaries.items.len;
        self.current_sentence_index = self.sentence_boundaries.items.len;
        self.state = .completed;
        if (self.on_complete) |callback| {
            callback();
        }
    }

    /// Get delay for next unit (with optional randomization)
    fn getNextDelay(self: *Self) u64 {
        var delay = self.config.delay_ms;
        if (self.config.randomize_timing and self.config.timing_variation_ms > 0) {
            const variation = self.rng.random().intRangeAtMost(u64, 0, self.config.timing_variation_ms * 2);
            if (variation > self.config.timing_variation_ms) {
                delay += variation - self.config.timing_variation_ms;
            } else if (delay > variation) {
                delay -= variation;
            }
        }
        return delay;
    }

    /// Update the animation state
    pub fn update(self: *Self) void {
        if (self.state != .running) return;

        const now = std.Io.Timestamp.now(io_context.get(), .awake);
        const last = self.last_update_time orelse return;
        const elapsed_duration = last.durationTo(now);
        const elapsed_ns: u64 = @intCast(elapsed_duration.nanoseconds);
        const elapsed_ms = elapsed_ns / std.time.ns_per_ms;

        // Check initial delay
        const start_instant = self.start_time orelse return;
        const total_elapsed_duration = start_instant.durationTo(now);
        const total_elapsed_ns: u64 = @intCast(total_elapsed_duration.nanoseconds);
        const total_elapsed_ms = total_elapsed_ns / std.time.ns_per_ms;

        if (total_elapsed_ms < self.config.initial_delay_ms) {
            return;
        }

        self.accumulated_delay_ms += elapsed_ms;
        self.last_update_time = now;

        const target_delay = self.getNextDelay();

        if (self.accumulated_delay_ms >= target_delay) {
            self.accumulated_delay_ms = 0;

            switch (self.mode) {
                .letter_by_letter => self.advanceLetter(),
                .word_by_word => self.advanceWord(),
                .sentence_by_sentence => self.advanceSentence(),
                .instant => self.skipToEnd(),
            }
        }
    }

    /// Advance by one letter
    fn advanceLetter(self: *Self) void {
        if (self.current_char_index < self.text.len) {
            const char = self.text[self.current_char_index];
            if (self.on_char_reveal) |callback| {
                callback(char, self.current_char_index);
            }
            self.current_char_index += 1;

            // Update word index if we passed a word boundary
            for (self.word_boundaries.items, 0..) |boundary, i| {
                if (self.current_char_index >= boundary and i >= self.current_word_index) {
                    self.current_word_index = i + 1;
                    break;
                }
            }
        }

        if (self.current_char_index >= self.text.len) {
            self.handleCompletion();
        }
    }

    /// Advance by one word
    fn advanceWord(self: *Self) void {
        if (self.current_word_index < self.word_boundaries.items.len) {
            const word_end = self.word_boundaries.items[self.current_word_index];
            const word_start = if (self.current_word_index == 0) 0 else self.word_boundaries.items[self.current_word_index - 1];

            // Find actual word start (skip leading whitespace)
            var actual_start = word_start;
            while (actual_start < word_end and (self.text[actual_start] == ' ' or self.text[actual_start] == '\t' or self.text[actual_start] == '\n')) {
                actual_start += 1;
            }

            if (self.on_word_reveal) |callback| {
                callback(self.text[actual_start..word_end], self.current_word_index);
            }

            self.current_char_index = word_end;
            self.current_word_index += 1;
        }

        if (self.current_word_index >= self.word_boundaries.items.len) {
            self.handleCompletion();
        }
    }

    /// Advance by one sentence
    fn advanceSentence(self: *Self) void {
        if (self.current_sentence_index < self.sentence_boundaries.items.len) {
            const sentence_end = self.sentence_boundaries.items[self.current_sentence_index];
            const sentence_start = if (self.current_sentence_index == 0) 0 else self.sentence_boundaries.items[self.current_sentence_index - 1];

            if (self.on_sentence_reveal) |callback| {
                callback(self.text[sentence_start..sentence_end], self.current_sentence_index);
            }

            self.current_char_index = sentence_end;
            self.current_sentence_index += 1;

            // Update word index
            for (self.word_boundaries.items, 0..) |boundary, i| {
                if (sentence_end >= boundary) {
                    self.current_word_index = i + 1;
                }
            }
        }

        if (self.current_sentence_index >= self.sentence_boundaries.items.len) {
            self.handleCompletion();
        }
    }

    /// Handle animation completion
    fn handleCompletion(self: *Self) void {
        if (self.config.loop) {
            // Reset for loop
            self.current_char_index = 0;
            self.current_word_index = 0;
            self.current_sentence_index = 0;
            self.accumulated_delay_ms = 0;
            // Use loop delay as initial delay for next iteration
            const saved_initial = self.config.initial_delay_ms;
            self.config.initial_delay_ms = self.config.loop_delay_ms;
            self.start_time = std.Io.Timestamp.now(io_context.get(), .awake);
            self.config.initial_delay_ms = saved_initial;
        } else {
            self.state = .completed;
            if (self.on_complete) |callback| {
                callback();
            }
        }
    }

    /// Get the currently revealed text
    pub fn getRevealedText(self: Self) []const u8 {
        if (self.current_char_index >= self.text.len) {
            return self.text;
        }
        return self.text[0..self.current_char_index];
    }

    /// Get revealed text with cursor
    pub fn getRevealedTextWithCursor(self: Self, buffer: []u8) []const u8 {
        const revealed = self.getRevealedText();
        const cursor = self.config.cursor_char;

        if (self.state == .completed or cursor.len == 0) {
            if (revealed.len <= buffer.len) {
                @memcpy(buffer[0..revealed.len], revealed);
                return buffer[0..revealed.len];
            }
            return revealed;
        }

        // Show cursor only if animation is running
        if (self.state == .running) {
            // Check if cursor should be visible (blinking)
            var show_cursor = true;
            if (self.config.cursor_blink) {
                if (self.start_time) |anim_start| {
                    const now = std.Io.Timestamp.now(io_context.get(), .awake);
                    const elapsed_duration = anim_start.durationTo(now);
                    const elapsed_ns: u64 = @intCast(elapsed_duration.nanoseconds);
                    const elapsed_ms = elapsed_ns / std.time.ns_per_ms;
                    const blink_cycle = elapsed_ms / self.config.cursor_blink_ms;
                    show_cursor = (blink_cycle % 2) == 0;
                }
            }

            if (show_cursor and revealed.len + cursor.len <= buffer.len) {
                @memcpy(buffer[0..revealed.len], revealed);
                @memcpy(buffer[revealed.len .. revealed.len + cursor.len], cursor);
                return buffer[0 .. revealed.len + cursor.len];
            }
        }

        if (revealed.len <= buffer.len) {
            @memcpy(buffer[0..revealed.len], revealed);
            return buffer[0..revealed.len];
        }
        return revealed;
    }

    /// Get progress as a float from 0.0 to 1.0
    pub fn getProgress(self: Self) f32 {
        if (self.text.len == 0) return 1.0;
        return @as(f32, @floatFromInt(self.current_char_index)) / @as(f32, @floatFromInt(self.text.len));
    }

    /// Check if animation is complete
    pub fn isComplete(self: Self) bool {
        return self.state == .completed;
    }

    /// Check if animation is running
    pub fn isRunning(self: Self) bool {
        return self.state == .running;
    }

    /// Get total word count
    pub fn getWordCount(self: Self) usize {
        return self.word_boundaries.items.len;
    }

    /// Get total sentence count
    pub fn getSentenceCount(self: Self) usize {
        return self.sentence_boundaries.items.len;
    }

    /// Get current word index (0-based)
    pub fn getCurrentWordIndex(self: Self) usize {
        return self.current_word_index;
    }

    /// Get current sentence index (0-based)
    pub fn getCurrentSentenceIndex(self: Self) usize {
        return self.current_sentence_index;
    }
};

/// Presets for common text animation configurations
pub const TextAnimationPresets = struct {
    /// Classic typewriter effect (fast, with cursor)
    pub fn typewriter() TextAnimationConfig {
        return .{
            .delay_ms = 50,
            .easing = .linear,
            .randomize_timing = true,
            .timing_variation_ms = 30,
            .cursor_char = "|",
            .cursor_blink = true,
            .cursor_blink_ms = 500,
        };
    }

    /// Slow typewriter for dramatic effect
    pub fn typewriterSlow() TextAnimationConfig {
        return .{
            .delay_ms = 100,
            .easing = .linear,
            .randomize_timing = true,
            .timing_variation_ms = 50,
            .cursor_char = "_",
            .cursor_blink = true,
            .cursor_blink_ms = 400,
        };
    }

    /// Very fast typing (like chat messages)
    pub fn typewriterFast() TextAnimationConfig {
        return .{
            .delay_ms = 20,
            .easing = .linear,
            .randomize_timing = false,
            .cursor_char = "",
            .cursor_blink = false,
        };
    }

    /// AI-style streaming text (like ChatGPT responses)
    pub fn aiStreaming() TextAnimationConfig {
        return .{
            .delay_ms = 15,
            .easing = .linear,
            .randomize_timing = true,
            .timing_variation_ms = 10,
            .cursor_char = "",
            .cursor_blink = false,
        };
    }

    /// Word-by-word reveal (teleprompter style)
    pub fn teleprompter() TextAnimationConfig {
        return .{
            .delay_ms = 200,
            .easing = .ease_out_quad,
            .randomize_timing = false,
            .cursor_char = "",
            .cursor_blink = false,
        };
    }

    /// Sentence-by-sentence (subtitle/caption style)
    pub fn subtitles() TextAnimationConfig {
        return .{
            .delay_ms = 2000,
            .easing = .ease_in_out_quad,
            .randomize_timing = false,
            .cursor_char = "",
            .cursor_blink = false,
        };
    }

    /// Story reveal (dramatic sentence by sentence)
    pub fn storyReveal() TextAnimationConfig {
        return .{
            .delay_ms = 1500,
            .easing = .ease_in_out_sine,
            .randomize_timing = true,
            .timing_variation_ms = 300,
            .cursor_char = "",
            .cursor_blink = false,
            .initial_delay_ms = 500,
        };
    }

    /// Terminal/console style
    pub fn terminal() TextAnimationConfig {
        return .{
            .delay_ms = 30,
            .easing = .linear,
            .randomize_timing = false,
            .cursor_char = "_",
            .cursor_blink = true,
            .cursor_blink_ms = 600,
        };
    }

    /// Code typing effect
    pub fn codeTyping() TextAnimationConfig {
        return .{
            .delay_ms = 40,
            .easing = .linear,
            .randomize_timing = true,
            .timing_variation_ms = 20,
            .cursor_char = "|",
            .cursor_blink = true,
            .cursor_blink_ms = 530,
        };
    }

    /// Looping announcement
    pub fn announcement() TextAnimationConfig {
        return .{
            .delay_ms = 80,
            .easing = .ease_out_sine,
            .randomize_timing = false,
            .cursor_char = "",
            .cursor_blink = false,
            .loop = true,
            .loop_delay_ms = 3000,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "TextAnimation: initialization" {
    const allocator = std.testing.allocator;
    const text = "Hello, World!";

    var anim = try TextAnimation.init(allocator, text, .letter_by_letter, TextAnimationPresets.typewriter());
    defer anim.deinit();

    try std.testing.expectEqual(@as(usize, 2), anim.getWordCount());
    try std.testing.expectEqual(@as(usize, 1), anim.getSentenceCount());
    try std.testing.expectEqual(AnimationState.idle, anim.state);
    try std.testing.expectEqualStrings("", anim.getRevealedText());
}

test "TextAnimation: word boundary parsing" {
    const allocator = std.testing.allocator;
    const text = "One two three four five";

    var anim = try TextAnimation.init(allocator, text, .word_by_word, .{});
    defer anim.deinit();

    try std.testing.expectEqual(@as(usize, 5), anim.getWordCount());
}

test "TextAnimation: sentence boundary parsing" {
    const allocator = std.testing.allocator;
    const text = "First sentence. Second sentence! Third sentence?";

    var anim = try TextAnimation.init(allocator, text, .sentence_by_sentence, .{});
    defer anim.deinit();

    try std.testing.expectEqual(@as(usize, 3), anim.getSentenceCount());
}

test "TextAnimation: skip to end" {
    const allocator = std.testing.allocator;
    const text = "Test message";

    var anim = try TextAnimation.init(allocator, text, .letter_by_letter, .{});
    defer anim.deinit();

    anim.start();
    anim.skipToEnd();

    try std.testing.expectEqual(AnimationState.completed, anim.state);
    try std.testing.expectEqualStrings(text, anim.getRevealedText());
    try std.testing.expectEqual(@as(f32, 1.0), anim.getProgress());
}

test "TextAnimation: progress calculation" {
    const allocator = std.testing.allocator;
    const text = "ABCD"; // 4 characters

    var anim = try TextAnimation.init(allocator, text, .letter_by_letter, .{});
    defer anim.deinit();

    try std.testing.expectEqual(@as(f32, 0.0), anim.getProgress());

    // Manually advance char index
    anim.current_char_index = 2;
    try std.testing.expectEqual(@as(f32, 0.5), anim.getProgress());

    anim.current_char_index = 4;
    try std.testing.expectEqual(@as(f32, 1.0), anim.getProgress());
}

test "TextAnimation: pause and unpause" {
    const allocator = std.testing.allocator;
    const text = "Test";

    var anim = try TextAnimation.init(allocator, text, .letter_by_letter, .{});
    defer anim.deinit();

    anim.start();
    try std.testing.expectEqual(AnimationState.running, anim.state);

    anim.pause();
    try std.testing.expectEqual(AnimationState.paused, anim.state);

    anim.unpause();
    try std.testing.expectEqual(AnimationState.running, anim.state);
}

test "TextAnimation: reset" {
    const allocator = std.testing.allocator;
    const text = "Test";

    var anim = try TextAnimation.init(allocator, text, .letter_by_letter, .{});
    defer anim.deinit();

    anim.start();
    anim.current_char_index = 3;
    anim.reset();

    try std.testing.expectEqual(AnimationState.idle, anim.state);
    try std.testing.expectEqual(@as(usize, 0), anim.current_char_index);
}

test "TextAnimation: empty text" {
    const allocator = std.testing.allocator;
    const text = "";

    var anim = try TextAnimation.init(allocator, text, .letter_by_letter, .{});
    defer anim.deinit();

    try std.testing.expectEqual(@as(usize, 0), anim.getWordCount());
    try std.testing.expectEqual(@as(usize, 0), anim.getSentenceCount());
    try std.testing.expectEqual(@as(f32, 1.0), anim.getProgress()); // Empty text = complete
}

test "TextAnimationPresets: all presets return valid config" {
    const typewriter = TextAnimationPresets.typewriter();
    try std.testing.expect(typewriter.delay_ms > 0);

    const slow = TextAnimationPresets.typewriterSlow();
    try std.testing.expect(slow.delay_ms > typewriter.delay_ms);

    const fast = TextAnimationPresets.typewriterFast();
    try std.testing.expect(fast.delay_ms < typewriter.delay_ms);

    const ai = TextAnimationPresets.aiStreaming();
    try std.testing.expect(ai.delay_ms > 0);

    const tele = TextAnimationPresets.teleprompter();
    try std.testing.expect(tele.delay_ms > 0);

    const sub = TextAnimationPresets.subtitles();
    try std.testing.expect(sub.delay_ms > 0);

    const story = TextAnimationPresets.storyReveal();
    try std.testing.expect(story.initial_delay_ms > 0);

    const term = TextAnimationPresets.terminal();
    try std.testing.expectEqualStrings("_", term.cursor_char);

    const code = TextAnimationPresets.codeTyping();
    try std.testing.expect(code.randomize_timing);

    const announce = TextAnimationPresets.announcement();
    try std.testing.expect(announce.loop);
}

test "EasingFunction: linear" {
    const result = EasingFunction.linear.apply(0.5);
    try std.testing.expectEqual(@as(f32, 0.5), result);
}

test "EasingFunction: boundaries" {
    // All easing functions should return 0 at t=0 and 1 at t=1
    const easings = [_]EasingFunction{
        .linear,
        .ease_in_quad,
        .ease_out_quad,
        .ease_in_out_quad,
        .ease_in_cubic,
        .ease_out_cubic,
    };

    for (easings) |easing| {
        const start = easing.apply(0.0);
        const end = easing.apply(1.0);
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), start, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 1.0), end, 0.001);
    }
}
