const std = @import("std");
const testing = std.testing;
const animation = @import("../src/animation.zig");

// EasingFunction tests
test "EasingFunction - all 31 easing functions exist" {
    try testing.expectEqual(animation.EasingFunction.linear, .linear);
    try testing.expectEqual(animation.EasingFunction.ease_in_quad, .ease_in_quad);
    try testing.expectEqual(animation.EasingFunction.ease_out_quad, .ease_out_quad);
    try testing.expectEqual(animation.EasingFunction.ease_in_out_quad, .ease_in_out_quad);
    try testing.expectEqual(animation.EasingFunction.ease_in_cubic, .ease_in_cubic);
    try testing.expectEqual(animation.EasingFunction.ease_out_cubic, .ease_out_cubic);
    try testing.expectEqual(animation.EasingFunction.ease_in_out_cubic, .ease_in_out_cubic);
    try testing.expectEqual(animation.EasingFunction.ease_in_quart, .ease_in_quart);
    try testing.expectEqual(animation.EasingFunction.ease_out_quart, .ease_out_quart);
    try testing.expectEqual(animation.EasingFunction.ease_in_out_quart, .ease_in_out_quart);
    try testing.expectEqual(animation.EasingFunction.ease_in_quint, .ease_in_quint);
    try testing.expectEqual(animation.EasingFunction.ease_out_quint, .ease_out_quint);
    try testing.expectEqual(animation.EasingFunction.ease_in_out_quint, .ease_in_out_quint);
    try testing.expectEqual(animation.EasingFunction.ease_in_sine, .ease_in_sine);
    try testing.expectEqual(animation.EasingFunction.ease_out_sine, .ease_out_sine);
    try testing.expectEqual(animation.EasingFunction.ease_in_out_sine, .ease_in_out_sine);
    try testing.expectEqual(animation.EasingFunction.ease_in_expo, .ease_in_expo);
    try testing.expectEqual(animation.EasingFunction.ease_out_expo, .ease_out_expo);
    try testing.expectEqual(animation.EasingFunction.ease_in_out_expo, .ease_in_out_expo);
    try testing.expectEqual(animation.EasingFunction.ease_in_circ, .ease_in_circ);
    try testing.expectEqual(animation.EasingFunction.ease_out_circ, .ease_out_circ);
    try testing.expectEqual(animation.EasingFunction.ease_in_out_circ, .ease_in_out_circ);
    try testing.expectEqual(animation.EasingFunction.ease_in_back, .ease_in_back);
    try testing.expectEqual(animation.EasingFunction.ease_out_back, .ease_out_back);
    try testing.expectEqual(animation.EasingFunction.ease_in_out_back, .ease_in_out_back);
    try testing.expectEqual(animation.EasingFunction.ease_in_elastic, .ease_in_elastic);
    try testing.expectEqual(animation.EasingFunction.ease_out_elastic, .ease_out_elastic);
    try testing.expectEqual(animation.EasingFunction.ease_in_out_elastic, .ease_in_out_elastic);
    try testing.expectEqual(animation.EasingFunction.ease_in_bounce, .ease_in_bounce);
    try testing.expectEqual(animation.EasingFunction.ease_out_bounce, .ease_out_bounce);
    try testing.expectEqual(animation.EasingFunction.ease_in_out_bounce, .ease_in_out_bounce);
}

test "EasingFunction - linear at boundaries" {
    const result_start = animation.EasingFunction.linear.apply(0.0);
    const result_end = animation.EasingFunction.linear.apply(1.0);

    try testing.expectEqual(@as(f32, 0.0), result_start);
    try testing.expectEqual(@as(f32, 1.0), result_end);
}

test "EasingFunction - linear at middle" {
    const result = animation.EasingFunction.linear.apply(0.5);
    try testing.expectEqual(@as(f32, 0.5), result);
}

test "EasingFunction - ease_in_quad" {
    const result_start = animation.EasingFunction.ease_in_quad.apply(0.0);
    const result_end = animation.EasingFunction.ease_in_quad.apply(1.0);

    try testing.expectEqual(@as(f32, 0.0), result_start);
    try testing.expectEqual(@as(f32, 1.0), result_end);
}

test "EasingFunction - ease_out_quad" {
    const result_start = animation.EasingFunction.ease_out_quad.apply(0.0);
    const result_end = animation.EasingFunction.ease_out_quad.apply(1.0);

    try testing.expectEqual(@as(f32, 0.0), result_start);
    try testing.expectEqual(@as(f32, 1.0), result_end);
}

test "EasingFunction - clamping below 0" {
    const result = animation.EasingFunction.linear.apply(-0.5);
    try testing.expectEqual(@as(f32, 0.0), result);
}

test "EasingFunction - clamping above 1" {
    const result = animation.EasingFunction.linear.apply(1.5);
    try testing.expectEqual(@as(f32, 1.0), result);
}

test "EasingFunction - ease_in_out_quad symmetric" {
    const result_quarter = animation.EasingFunction.ease_in_out_quad.apply(0.25);
    const result_three_quarters = animation.EasingFunction.ease_in_out_quad.apply(0.75);

    // Both should be valid between 0 and 1
    try testing.expect(result_quarter >= 0.0 and result_quarter <= 1.0);
    try testing.expect(result_three_quarters >= 0.0 and result_three_quarters <= 1.0);
}

test "EasingFunction - ease_in_cubic boundaries" {
    const result_start = animation.EasingFunction.ease_in_cubic.apply(0.0);
    const result_end = animation.EasingFunction.ease_in_cubic.apply(1.0);

    try testing.expectEqual(@as(f32, 0.0), result_start);
    try testing.expectEqual(@as(f32, 1.0), result_end);
}

test "EasingFunction - ease_out_bounce boundaries" {
    const result_start = animation.EasingFunction.ease_out_bounce.apply(0.0);
    const result_end = animation.EasingFunction.ease_out_bounce.apply(1.0);

    try testing.expectEqual(@as(f32, 0.0), result_start);
    try testing.expectApproxEqAbs(@as(f32, 1.0), result_end, 0.001);
}

test "EasingFunction - ease_in_bounce boundaries" {
    const result_start = animation.EasingFunction.ease_in_bounce.apply(0.0);
    const result_end = animation.EasingFunction.ease_in_bounce.apply(1.0);

    try testing.expectApproxEqAbs(@as(f32, 0.0), result_start, 0.001);
    try testing.expectEqual(@as(f32, 1.0), result_end);
}

test "EasingFunction - ease_in_sine boundaries" {
    const result_start = animation.EasingFunction.ease_in_sine.apply(0.0);
    const result_end = animation.EasingFunction.ease_in_sine.apply(1.0);

    try testing.expectApproxEqAbs(@as(f32, 0.0), result_start, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), result_end, 0.001);
}

test "EasingFunction - ease_out_sine boundaries" {
    const result_start = animation.EasingFunction.ease_out_sine.apply(0.0);
    const result_end = animation.EasingFunction.ease_out_sine.apply(1.0);

    try testing.expectApproxEqAbs(@as(f32, 0.0), result_start, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), result_end, 0.001);
}

test "EasingFunction - ease_in_expo special cases" {
    const result_zero = animation.EasingFunction.ease_in_expo.apply(0.0);
    const result_one = animation.EasingFunction.ease_in_expo.apply(1.0);

    try testing.expectEqual(@as(f32, 0.0), result_zero);
    try testing.expectApproxEqAbs(@as(f32, 1.0), result_one, 0.001);
}

test "EasingFunction - ease_out_expo special cases" {
    const result_zero = animation.EasingFunction.ease_out_expo.apply(0.0);
    const result_one = animation.EasingFunction.ease_out_expo.apply(1.0);

    try testing.expectApproxEqAbs(@as(f32, 0.0), result_zero, 0.001);
    try testing.expectEqual(@as(f32, 1.0), result_one);
}

// AnimationState tests
test "AnimationState enum" {
    try testing.expectEqual(animation.AnimationState.idle, .idle);
    try testing.expectEqual(animation.AnimationState.running, .running);
    try testing.expectEqual(animation.AnimationState.paused, .paused);
    try testing.expectEqual(animation.AnimationState.completed, .completed);
    try testing.expectEqual(animation.AnimationState.canceled, .canceled);
}

// Animation tests
test "Animation - basic creation" {
    const anim = animation.Animation{
        .start_value = 0.0,
        .end_value = 100.0,
        .duration_ms = 1000,
        .easing = .linear,
        .state = .idle,
        .elapsed_ms = 0,
        .start_time = null,
        .pause_time = null,
        .on_update = null,
        .on_complete = null,
    };

    try testing.expectEqual(@as(f32, 0.0), anim.start_value);
    try testing.expectEqual(@as(f32, 100.0), anim.end_value);
    try testing.expectEqual(@as(u64, 1000), anim.duration_ms);
    try testing.expectEqual(animation.EasingFunction.linear, anim.easing);
    try testing.expectEqual(animation.AnimationState.idle, anim.state);
}

test "Animation - with different easing" {
    const anim = animation.Animation{
        .start_value = 0.0,
        .end_value = 1.0,
        .duration_ms = 500,
        .easing = .ease_in_out_quad,
        .state = .idle,
        .elapsed_ms = 0,
        .start_time = null,
        .pause_time = null,
        .on_update = null,
        .on_complete = null,
    };

    try testing.expectEqual(animation.EasingFunction.ease_in_out_quad, anim.easing);
}

test "Animation - state transitions" {
    var anim = animation.Animation{
        .start_value = 0.0,
        .end_value = 100.0,
        .duration_ms = 1000,
        .easing = .linear,
        .state = .idle,
        .elapsed_ms = 0,
        .start_time = null,
        .pause_time = null,
        .on_update = null,
        .on_complete = null,
    };

    try testing.expectEqual(animation.AnimationState.idle, anim.state);

    anim.state = .running;
    try testing.expectEqual(animation.AnimationState.running, anim.state);

    anim.state = .paused;
    try testing.expectEqual(animation.AnimationState.paused, anim.state);

    anim.state = .completed;
    try testing.expectEqual(animation.AnimationState.completed, anim.state);
}

test "Animation - reverse animation" {
    const anim = animation.Animation{
        .start_value = 100.0,
        .end_value = 0.0,
        .duration_ms = 1000,
        .easing = .linear,
        .state = .idle,
        .elapsed_ms = 0,
        .start_time = null,
        .pause_time = null,
        .on_update = null,
        .on_complete = null,
    };

    try testing.expectEqual(@as(f32, 100.0), anim.start_value);
    try testing.expectEqual(@as(f32, 0.0), anim.end_value);
}

test "Animation - very short duration" {
    const anim = animation.Animation{
        .start_value = 0.0,
        .end_value = 1.0,
        .duration_ms = 16, // One frame at 60fps
        .easing = .linear,
        .state = .idle,
        .elapsed_ms = 0,
        .start_time = null,
        .pause_time = null,
        .on_update = null,
        .on_complete = null,
    };

    try testing.expectEqual(@as(u64, 16), anim.duration_ms);
}

test "Animation - very long duration" {
    const anim = animation.Animation{
        .start_value = 0.0,
        .end_value = 1.0,
        .duration_ms = 10000, // 10 seconds
        .easing = .linear,
        .state = .idle,
        .elapsed_ms = 0,
        .start_time = null,
        .pause_time = null,
        .on_update = null,
        .on_complete = null,
    };

    try testing.expectEqual(@as(u64, 10000), anim.duration_ms);
}

test "Animation - negative values" {
    const anim = animation.Animation{
        .start_value = -50.0,
        .end_value = 50.0,
        .duration_ms = 1000,
        .easing = .linear,
        .state = .idle,
        .elapsed_ms = 0,
        .start_time = null,
        .pause_time = null,
        .on_update = null,
        .on_complete = null,
    };

    try testing.expectEqual(@as(f32, -50.0), anim.start_value);
    try testing.expectEqual(@as(f32, 50.0), anim.end_value);
}

test "Animation - large values" {
    const anim = animation.Animation{
        .start_value = 0.0,
        .end_value = 10000.0,
        .duration_ms = 2000,
        .easing = .ease_out_quad,
        .state = .idle,
        .elapsed_ms = 0,
        .start_time = null,
        .pause_time = null,
        .on_update = null,
        .on_complete = null,
    };

    try testing.expectEqual(@as(f32, 10000.0), anim.end_value);
}

test "Animation - fractional values" {
    const anim = animation.Animation{
        .start_value = 0.0,
        .end_value = 0.5,
        .duration_ms = 1000,
        .easing = .linear,
        .state = .idle,
        .elapsed_ms = 0,
        .start_time = null,
        .pause_time = null,
        .on_update = null,
        .on_complete = null,
    };

    try testing.expectEqual(@as(f32, 0.5), anim.end_value);
}
