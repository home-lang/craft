//! Host-neutral layout primitives for the native renderer.
//!
//! This is the host-neutral layout core for the native renderer. It owns the
//! pure single-line main-axis flex rule that can be shared by every host while
//! leaving intrinsic measurement (especially text) to a platform callback.

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
    flex_shrink: f32 = 0,
    min_width: ?f32 = null,
    max_width: ?f32 = null,
    min_height: ?f32 = null,
    max_height: ?f32 = null,
    gap: f32 = 0,
    margin_top: f32 = 0,
    margin_right: f32 = 0,
    margin_bottom: f32 = 0,
    margin_left: f32 = 0,
    grid: bool = false,
    grid_columns: u32 = 1,
    row_gap: f32 = 0,
    column_gap: f32 = 0,
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
/// A child consumes `flex_basis`, then its explicit main-axis size, then zero.
/// Positive remaining space is distributed by `flex_grow`; negative remaining
/// space is removed by `flex_shrink * basis`. Both results honor the child's
/// margins and min/max bounds. A grid parent uses equal columns and max-content
/// row tracks from explicit child heights; `row_gap` and `column_gap` are
/// independent.
/// Text and other intrinsic measurements are intentionally absent: a host
/// callback can provide those bases without leaking UIKit or Android concepts.
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

    const width = if (frame_index == 0) node.style.width orelse available.width else available.width;
    const height = if (frame_index == 0) node.style.height orelse available.height else available.height;
    frames[frame_index] = .{ .x = x, .y = y, .width = width, .height = height };

    if (node.children.len == 0) return frame_index + 1;
    if (node.style.grid) return layoutGrid(node, width, height, x, y, frame_index, frames);

    const main_size = if (node.style.direction == .row) width else height;
    const gap = @max(0, node.style.gap);
    const gap_count = if (node.children.len > 1) node.children.len - 1 else 0;
    const gap_total = gap * @as(f32, @floatFromInt(gap_count));
    var basis_total: f32 = gap_total;
    var grow_total: f32 = 0;
    var shrink_total: f32 = 0;
    for (node.children) |child| {
        basis_total += childMainBasis(child, node.style.direction) + mainMargins(child, node.style.direction);
        grow_total += positiveGrow(child.style.flex_grow);
        shrink_total += positiveShrink(child.style.flex_shrink) * childMainBasis(child, node.style.direction);
    }

    const free = main_size - basis_total;
    var next_index = frame_index + 1;
    var main_offset: f32 = 0;
    for (node.children, 0..) |child, index| {
        const basis = childMainBasis(child, node.style.direction);
        const child_main = if (free > 0)
            clampMain(child, node.style.direction, basis + if (grow_total > 0) free * positiveGrow(child.style.flex_grow) / grow_total else 0)
        else if (free < 0)
            clampMain(child, node.style.direction, basis - if (shrink_total > 0) (-free) * positiveShrink(child.style.flex_shrink) * basis / shrink_total else 0)
        else
            clampMain(child, node.style.direction, basis);
        const child_cross = childCrossSize(child, node.style.direction, width, height);
        const leading_margin = mainLeadingMargin(child, node.style.direction);
        const child_size = if (node.style.direction == .row)
            Size{ .width = child_main, .height = child_cross }
        else
            Size{ .width = child_cross, .height = child_main };
        const child_x = if (node.style.direction == .row) x + main_offset + leading_margin else x + crossLeadingMargin(child, node.style.direction);
        const child_y = if (node.style.direction == .row) y + crossLeadingMargin(child, node.style.direction) else y + main_offset + leading_margin;
        next_index = try layoutNode(child, child_size, child_x, child_y, next_index, frames);
        main_offset += mainMargins(child, node.style.direction) + child_main + if (index + 1 < node.children.len) gap else 0;
    }
    return next_index;
}

fn layoutGrid(
    node: Node,
    width: f32,
    height: f32,
    x: f32,
    y: f32,
    frame_index: usize,
    frames: []Frame,
) LayoutError!usize {
    const columns = @max(@as(u32, 1), node.style.grid_columns);
    const column_count: usize = @intCast(columns);
    const column_gap = @max(0, node.style.column_gap);
    const row_gap = @max(0, node.style.row_gap);
    const available_width = @max(0, width - column_gap * @as(f32, @floatFromInt(column_count - 1)));
    const cell_width = available_width / @as(f32, @floatFromInt(column_count));
    var next_index = frame_index + 1;
    var row_y = y;
    for (node.children, 0..) |child, index| {
        const row = index / column_count;
        const column = index % column_count;
        const row_height = gridRowHeight(node, row, column_count);
        const child_available_width = @max(0, cell_width - horizontalMargins(child));
        const child_width = clampMain(child, .row, @min(child_available_width, child.style.width orelse child_available_width));
        const available_height = @max(0, row_height - verticalMargins(child));
        const child_height = if (child.style.height == null and child.style.flex_basis == null)
            available_height
        else
            clamp(@min(available_height, child.style.height orelse child.style.flex_basis orelse 0), child.style.min_height, child.style.max_height);
        const child_x = x + @as(f32, @floatFromInt(column)) * (cell_width + column_gap) + child.style.margin_left;
        const child_y = row_y + child.style.margin_top;
        next_index = try layoutNode(child, .{ .width = child_width, .height = child_height }, child_x, child_y, next_index, frames);
        if (column + 1 == column_count or index + 1 == node.children.len) {
            row_y += row_height + row_gap;
        }
    }
    _ = height;
    return next_index;
}

fn gridRowHeight(node: Node, row: usize, column_count: usize) f32 {
    const start = row * column_count;
    const end = @min(node.children.len, start + column_count);
    var height: f32 = 0;
    for (node.children[start..end]) |child| {
        const child_height = child.style.height orelse child.style.flex_basis orelse 0;
        height = @max(height, clamp(child_height, child.style.min_height, child.style.max_height) + verticalMargins(child));
    }
    return height;
}

fn childMainBasis(node: Node, parent_direction: Axis) f32 {
    const explicit = if (parent_direction == .row) node.style.width else node.style.height;
    return clampMain(node, parent_direction, node.style.flex_basis orelse explicit orelse 0);
}

fn childCrossSize(node: Node, parent_direction: Axis, parent_width: f32, parent_height: f32) f32 {
    if (parent_direction == .row) {
        const available = @max(0, parent_height - verticalMargins(node));
        return clampCross(node, parent_direction, node.style.height orelse available);
    }
    const available = @max(0, parent_width - horizontalMargins(node));
    return clampCross(node, parent_direction, node.style.width orelse available);
}

fn mainLeadingMargin(node: Node, direction: Axis) f32 {
    return if (direction == .row) node.style.margin_left else node.style.margin_top;
}

fn crossLeadingMargin(node: Node, direction: Axis) f32 {
    return if (direction == .row) node.style.margin_top else node.style.margin_left;
}

fn mainMargins(node: Node, direction: Axis) f32 {
    return if (direction == .row)
        node.style.margin_left + node.style.margin_right
    else
        node.style.margin_top + node.style.margin_bottom;
}

fn horizontalMargins(node: Node) f32 {
    return node.style.margin_left + node.style.margin_right;
}

fn verticalMargins(node: Node) f32 {
    return node.style.margin_top + node.style.margin_bottom;
}

fn positiveGrow(value: f32) f32 {
    return @max(0, value);
}

fn positiveShrink(value: f32) f32 {
    return @max(0, value);
}

fn clampMain(node: Node, direction: Axis, value: f32) f32 {
    return if (direction == .row)
        clamp(value, node.style.min_width, node.style.max_width)
    else
        clamp(value, node.style.min_height, node.style.max_height);
}

fn clampCross(node: Node, direction: Axis, value: f32) f32 {
    return if (direction == .row)
        clamp(value, node.style.min_height, node.style.max_height)
    else
        clamp(value, node.style.min_width, node.style.max_width);
}

fn clamp(value: f32, lower: ?f32, upper: ?f32) f32 {
    var result = @max(0, value);
    if (lower) |minimum| result = @max(result, minimum);
    if (upper) |maximum| result = @min(result, maximum);
    return result;
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

test "applies gap and shrink without crossing minimum bounds" {
    const children = [_]Node{
        .{ .style = .{ .flex_basis = 80, .flex_shrink = 1, .min_width = 60 } },
        .{ .style = .{ .flex_basis = 80, .flex_shrink = 1 } },
    };
    const root = Node{
        .style = .{ .direction = .row, .width = 130, .height = 20, .gap = 10 },
        .children = &children,
    };
    var frames: [3]Frame = undefined;

    _ = try layout(root, .{ .width = 130, .height = 20 }, &frames);
    try std.testing.expectEqual(@as(f32, 60), frames[1].width);
    try std.testing.expectEqual(@as(f32, 60), frames[2].width);
    try std.testing.expectEqual(@as(f32, 70), frames[2].x);
}

test "clamps positive flex growth to a maximum" {
    const children = [_]Node{
        .{ .style = .{ .flex_basis = 20, .flex_grow = 1, .max_width = 40 } },
        .{ .style = .{ .flex_basis = 20, .flex_grow = 1 } },
    };
    const root = Node{
        .style = .{ .direction = .row, .width = 140, .height = 20 },
        .children = &children,
    };
    var frames: [3]Frame = undefined;

    _ = try layout(root, .{ .width = 140, .height = 20 }, &frames);
    try std.testing.expectEqual(@as(f32, 40), frames[1].width);
    try std.testing.expectEqual(@as(f32, 70), frames[2].width);
}

test "places equal grid tracks and max-content rows" {
    const children = [_]Node{
        .{ .style = .{ .height = 20 } },
        .{ .style = .{ .height = 30 } },
        .{ .style = .{ .height = 10 } },
    };
    const root = Node{
        .style = .{ .grid = true, .grid_columns = 2, .width = 100, .height = 100, .column_gap = 10, .row_gap = 5 },
        .children = &children,
    };
    var frames: [4]Frame = undefined;

    _ = try layout(root, .{ .width = 100, .height = 100 }, &frames);
    try std.testing.expectEqual(@as(f32, 45), frames[1].width);
    try std.testing.expectEqual(@as(f32, 0), frames[1].x);
    try std.testing.expectEqual(@as(f32, 55), frames[2].x);
    try std.testing.expectEqual(@as(f32, 20), frames[1].height);
    try std.testing.expectEqual(@as(f32, 30), frames[2].height);
    try std.testing.expectEqual(@as(f32, 35), frames[3].y);
}

test "accounts for per-edge margins in flex and grid frames" {
    const flex_children = [_]Node{
        .{ .style = .{ .flex_basis = 20, .margin_left = 5, .margin_right = 7, .margin_top = 3, .margin_bottom = 4 } },
        .{ .style = .{ .flex_basis = 20 } },
    };
    const flex_root = Node{
        .style = .{ .direction = .row, .width = 100, .height = 40 },
        .children = &flex_children,
    };
    var flex_frames: [3]Frame = undefined;
    _ = try layout(flex_root, .{ .width = 100, .height = 40 }, &flex_frames);
    try std.testing.expectEqual(@as(f32, 5), flex_frames[1].x);
    try std.testing.expectEqual(@as(f32, 3), flex_frames[1].y);
    try std.testing.expectEqual(@as(f32, 33), flex_frames[1].height);
    try std.testing.expectEqual(@as(f32, 32), flex_frames[2].x);

    const grid_children = [_]Node{
        .{ .style = .{ .width = 60, .height = 10, .margin_left = 2, .margin_right = 3, .margin_top = 4, .margin_bottom = 5 } },
    };
    const grid_root = Node{
        .style = .{ .grid = true, .grid_columns = 2, .width = 100, .height = 40, .column_gap = 10 },
        .children = &grid_children,
    };
    var grid_frames: [2]Frame = undefined;
    _ = try layout(grid_root, .{ .width = 100, .height = 40 }, &grid_frames);
    try std.testing.expectEqual(@as(f32, 2), grid_frames[1].x);
    try std.testing.expectEqual(@as(f32, 4), grid_frames[1].y);
    try std.testing.expectEqual(@as(f32, 40), grid_frames[1].width);
    try std.testing.expectEqual(@as(f32, 10), grid_frames[1].height);
}
