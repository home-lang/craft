//! Host-neutral layout primitives for the native renderer.
//!
//! This is deliberately a spike, not a second renderer. It owns the pure
//! main-axis flex rule that can be shared by every host while leaving intrinsic
//! measurement (especially text) to a platform callback in a later phase.

const std = @import("std");

pub const Axis = enum {
    row,
    column,
};

pub const Size = struct {
    width: f32,
    height: f32,
};

pub const Frame = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const Style = struct {
    direction: Axis = .row,
    width: ?f32 = null,
    height: ?f32 = null,
    flex_basis: ?f32 = null,
    flex_grow: f32 = 0,
};

pub const Node = struct {
    style: Style = .{},
    children: []const Node = &.{},
};

pub const LayoutError = error{
    FrameBufferTooSmall,
};

/// Computes a tree's absolute frames without importing any platform type.
///
/// The root uses its explicit size when present and otherwise the viewport.
/// A child consumes `flex_basis`, then its explicit main-axis size, then zero;
/// positive remaining space is distributed by `flex_grow`. Cross-axis sizing
/// uses the child's explicit size or the parent size. Text and other intrinsic
/// measurements are intentionally absent: a future host callback can provide
/// those bases without leaking UIKit or Android concepts into this module.
pub fn layout(root: Node, viewport: Size, frames: []Frame) LayoutError!usize {
    if (frames.len == 0) return error.FrameBufferTooSmall;
    return layoutNode(root, viewport, 0, 0, 0, frames);
}

fn layoutNode(
    node: Node,
    available: Size,
    x: f32,
    y: f32,
    frame_index: usize,
    frames: []Frame,
) LayoutError!usize {
    if (frame_index >= frames.len) return error.FrameBufferTooSmall;

    const width = node.style.width orelse available.width;
    const height = node.style.height orelse available.height;
    frames[frame_index] = .{ .x = x, .y = y, .width = width, .height = height };

    if (node.children.len == 0) return frame_index + 1;

    const main_size = if (node.style.direction == .row) width else height;
    var basis_total: f32 = 0;
    var grow_total: f32 = 0;
    for (node.children) |child| {
        basis_total += childMainBasis(child, node.style.direction);
        grow_total += positiveGrow(child.style.flex_grow);
    }

    const remaining = @max(0, main_size - basis_total);
    var next_index = frame_index + 1;
    var main_offset: f32 = 0;
    for (node.children) |child| {
        const basis = childMainBasis(child, node.style.direction);
        const grow = positiveGrow(child.style.flex_grow);
        const child_main = basis + if (grow_total > 0) remaining * grow / grow_total else 0;
        const child_cross = childCrossSize(child, node.style.direction, width, height);
        const child_size = if (node.style.direction == .row)
            Size{ .width = child_main, .height = child_cross }
        else
            Size{ .width = child_cross, .height = child_main };
        const child_x = if (node.style.direction == .row) x + main_offset else x;
        const child_y = if (node.style.direction == .row) y else y + main_offset;
        next_index = try layoutNode(child, child_size, child_x, child_y, next_index, frames);
        main_offset += child_main;
    }
    return next_index;
}

fn childMainBasis(node: Node, parent_direction: Axis) f32 {
    const explicit = if (parent_direction == .row) node.style.width else node.style.height;
    return @max(0, node.style.flex_basis orelse explicit orelse 0);
}

fn childCrossSize(node: Node, parent_direction: Axis, parent_width: f32, parent_height: f32) f32 {
    return if (parent_direction == .row)
        @max(0, node.style.height orelse parent_height)
    else
        @max(0, node.style.width orelse parent_width);
}

fn positiveGrow(value: f32) f32 {
    return @max(0, value);
}

test "distributes positive flex grow from a shared basis" {
    const children = [_]Node{
        .{ .style = .{ .flex_basis = 40, .flex_grow = 1 } },
        .{ .style = .{ .flex_basis = 20, .flex_grow = 2 } },
    };
    const root = Node{
        .style = .{ .direction = .row, .width = 180, .height = 48 },
        .children = &children,
    };
    var frames: [3]Frame = undefined;

    const count = try layout(root, .{ .width = 180, .height = 48 }, &frames);
    try std.testing.expectEqual(@as(usize, 3), count);
    try std.testing.expectEqual(@as(f32, 0), frames[1].x);
    try std.testing.expectEqual(@as(f32, 80), frames[1].width);
    try std.testing.expectEqual(@as(f32, 80), frames[2].x);
    try std.testing.expectEqual(@as(f32, 100), frames[2].width);
    try std.testing.expectEqual(@as(f32, 48), frames[1].height);
}

test "uses viewport size when the root is intrinsic" {
    var frames: [1]Frame = undefined;
    const count = try layout(.{}, .{ .width = 320, .height = 640 }, &frames);
    try std.testing.expectEqual(@as(usize, 1), count);
    try std.testing.expectEqual(@as(f32, 320), frames[0].width);
    try std.testing.expectEqual(@as(f32, 640), frames[0].height);
}

test "recurses across row and column axes without host concepts" {
    const grandchildren = [_]Node{
        .{ .style = .{ .flex_basis = 10, .flex_grow = 1 } },
        .{ .style = .{ .flex_basis = 10, .flex_grow = 1 } },
    };
    const child = Node{
        .style = .{ .direction = .column, .width = 80, .height = 60 },
        .children = &grandchildren,
    };
    const children = [_]Node{child};
    const root = Node{
        .style = .{ .direction = .row, .width = 160, .height = 100 },
        .children = &children,
    };
    var frames: [4]Frame = undefined;

    const count = try layout(root, .{ .width = 160, .height = 100 }, &frames);
    try std.testing.expectEqual(@as(usize, 4), count);
    try std.testing.expectEqual(@as(f32, 80), frames[1].width);
    try std.testing.expectEqual(@as(f32, 30), frames[2].height);
    try std.testing.expectEqual(@as(f32, 30), frames[3].height);
    try std.testing.expectEqual(@as(f32, 30), frames[3].y);
}
