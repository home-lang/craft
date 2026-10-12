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

/// C-compatible output frame shared by the iOS and Android grid bridges.
/// Keep this extern: hosts allocate a flat array and the exported ABI writes
/// these four floats directly into it.
pub const Frame = extern struct {
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
    padding_top: f32 = 0,
    padding_right: f32 = 0,
    padding_bottom: f32 = 0,
    padding_left: f32 = 0,
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

/// C-compatible input for the host bridge's one-line flex distribution.
/// `min` and `max` use a negative value to mean "unset".
pub const FlexItem = extern struct {
    basis: f32,
    grow: f32,
    shrink: f32,
    min: f32,
    max: f32,
    margin_start: f32,
    margin_end: f32,
};

/// C-compatible input for equal-track native grids. A negative or NaN
/// dimension means "use intrinsic"; `stretch` is 1 for the host's stretch
/// alignment and `alignment` is 0=start, 1=center, or 2=end.
pub const GridItem = extern struct {
    intrinsic_width: f32,
    intrinsic_height: f32,
    explicit_width: f32,
    explicit_height: f32,
    min_width: f32,
    max_width: f32,
    min_height: f32,
    max_height: f32,
    margin_left: f32,
    margin_right: f32,
    margin_top: f32,
    margin_bottom: f32,
    stretch: u32,
    alignment: u32,
};

/// Resolve an equal-track grid in content coordinates for native hosts.
pub export fn craft_native_grid(
    available_width: f32,
    available_height: f32,
    columns: u32,
    column_gap: f32,
    row_gap: f32,
    items: [*]const GridItem,
    item_count: usize,
    frames: [*]Frame,
) callconv(.c) c_int {
    if (item_count == 0) return 0;
    const column_count = @max(@as(usize, 1), @as(usize, @intCast(columns)));
    const width = finiteNonNegative(available_width);
    const height = finiteNonNegative(available_height);
    const safe_column_gap = finiteNonNegative(column_gap);
    const safe_row_gap = finiteNonNegative(row_gap);
    const cell_width = @max(0, width - safe_column_gap * @as(f32, @floatFromInt(column_count - 1))) /
        @as(f32, @floatFromInt(column_count));

    const row_count = (item_count + column_count - 1) / column_count;
    for (0..row_count) |row| {
        var row_height: f32 = 0;
        const start = row * column_count;
        const end = @min(item_count, start + column_count);
        for (items[start..end]) |item| {
            const intrinsic = optionalDimension(item.explicit_height, item.intrinsic_height);
            row_height = @max(row_height, clampBounds(intrinsic, item.min_height, item.max_height) + finiteNonNegative(item.margin_top) + finiteNonNegative(item.margin_bottom));
        }
        var row_y: f32 = 0;
        for (0..row) |prior| {
            const prior_start = prior * column_count;
            const prior_end = @min(item_count, prior_start + column_count);
            var prior_height: f32 = 0;
            for (items[prior_start..prior_end]) |item| {
                const intrinsic = optionalDimension(item.explicit_height, item.intrinsic_height);
                prior_height = @max(prior_height, clampBounds(intrinsic, item.min_height, item.max_height) + finiteNonNegative(item.margin_top) + finiteNonNegative(item.margin_bottom));
            }
            row_y += prior_height + safe_row_gap;
        }
        for (items[start..end], start..) |item, index| {
            const column = index % column_count;
            const available_item_width = @max(0, cell_width - finiteNonNegative(item.margin_left) - finiteNonNegative(item.margin_right));
            const requested_width = optionalDimension(item.explicit_width, item.intrinsic_width);
            const item_width = clampBounds(@min(available_item_width, if (item.stretch == 1 and isUnset(item.explicit_width)) available_item_width else requested_width), item.min_width, item.max_width);
            const available_item_height = @max(0, row_height - finiteNonNegative(item.margin_top) - finiteNonNegative(item.margin_bottom));
            const requested_height = optionalDimension(item.explicit_height, item.intrinsic_height);
            const item_height = clampBounds(@min(available_item_height, if (item.stretch == 1 and isUnset(item.explicit_height)) available_item_height else requested_height), item.min_height, item.max_height);
            const horizontal_space = @max(0, available_item_width - item_width);
            const vertical_space = @max(0, available_item_height - item_height);
            const align_x = if (item.alignment == 1) horizontal_space / 2 else if (item.alignment == 2) horizontal_space else 0;
            const align_y = if (item.alignment == 1) vertical_space / 2 else if (item.alignment == 2) vertical_space else 0;
            frames[index] = .{
                .x = @as(f32, @floatFromInt(column)) * (cell_width + safe_column_gap) + finiteNonNegative(item.margin_left) + align_x,
                .y = row_y + finiteNonNegative(item.margin_top) + align_y,
                .width = item_width,
                .height = item_height,
            };
        }
    }
    _ = height;
    return 0;
}

/// Distribute one flex line in content coordinates for native hosts.
/// Margins and gaps consume space; free space follows grow or shrink*basis;
/// each result is clamped to its bounds. Return 0 for success.
pub export fn craft_native_flex_row(
    available: f32,
    gap: f32,
    items: [*]const FlexItem,
    item_count: usize,
    widths: [*]f32,
    positions: [*]f32,
) callconv(.c) c_int {
    return craftNativeFlexRow(available, gap, 0, items, item_count, widths, positions);
}

/// ABI v2 flex row distribution. `justify` is 0=start, 1=center, 2=end,
/// 3=space-between, 4=space-around, or 5=space-evenly. The original export
/// remains available for older hosts and keeps start justification.
pub export fn craft_native_flex_row_justified(
    available: f32,
    gap: f32,
    justify: u32,
    items: [*]const FlexItem,
    item_count: usize,
    widths: [*]f32,
    positions: [*]f32,
) callconv(.c) c_int {
    return craftNativeFlexRow(available, gap, justify, items, item_count, widths, positions);
}

fn craftNativeFlexRow(
    available: f32,
    gap: f32,
    justify: u32,
    items: [*]const FlexItem,
    item_count: usize,
    widths: [*]f32,
    positions: [*]f32,
) c_int {
    if (item_count == 0) return 0;

    const safe_available = finiteNonNegative(available);
    const safe_gap = finiteNonNegative(gap);
    var basis_total = safe_gap * @as(f32, @floatFromInt(item_count - 1));
    var grow_total: f32 = 0;
    var shrink_total: f32 = 0;
    for (items[0..item_count]) |item| {
        const basis = finiteNonNegative(item.basis);
        basis_total += basis + finiteNonNegative(item.margin_start) + finiteNonNegative(item.margin_end);
        grow_total += positiveGrow(item.grow);
        shrink_total += positiveShrink(item.shrink) * basis;
    }

    const free = safe_available - basis_total;
    var used = safe_gap * @as(f32, @floatFromInt(item_count - 1));
    for (items[0..item_count], 0..) |item, index| {
        const basis = finiteNonNegative(item.basis);
        const raw = if (free > 0)
            basis + if (grow_total > 0) free * positiveGrow(item.grow) / grow_total else 0
        else if (free < 0)
            basis - if (shrink_total > 0) (-free) * positiveShrink(item.shrink) * basis / shrink_total else 0
        else
            basis;
        const width = clampBounds(raw, item.min, item.max);
        used += width + finiteNonNegative(item.margin_start) + finiteNonNegative(item.margin_end);
        widths[index] = width;
    }

    const remaining = @max(0, safe_available - used);
    var leading_space: f32 = 0;
    var between_space: f32 = 0;
    switch (justify) {
        1 => leading_space = remaining / 2,
        2 => leading_space = remaining,
        3 => {
            if (item_count > 1) between_space = remaining / @as(f32, @floatFromInt(item_count - 1));
        },
        4 => {
            leading_space = remaining / @as(f32, @floatFromInt(item_count * 2));
            between_space = remaining / @as(f32, @floatFromInt(item_count));
        },
        5 => {
            leading_space = remaining / @as(f32, @floatFromInt(item_count + 1));
            between_space = leading_space;
        },
        else => {},
    }

    var offset = leading_space;
    for (items[0..item_count], 0..) |item, index| {
        const leading = finiteNonNegative(item.margin_start);
        const trailing = finiteNonNegative(item.margin_end);
        positions[index] = offset + leading;
        offset += leading + widths[index] + trailing;
        if (index + 1 < item_count) offset += safe_gap + between_space;
    }
    return 0;
}

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
    const content_width = @max(0, width - node.style.padding_left - node.style.padding_right);
    const content_height = @max(0, height - node.style.padding_top - node.style.padding_bottom);
    const content_x = x + node.style.padding_left;
    const content_y = y + node.style.padding_top;
    if (node.style.grid) return layoutGrid(node, content_width, content_height, content_x, content_y, frame_index, frames);

    const main_size = if (node.style.direction == .row) content_width else content_height;
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
        const child_cross = childCrossSize(child, node.style.direction, content_width, content_height);
        const leading_margin = mainLeadingMargin(child, node.style.direction);
        const child_size = if (node.style.direction == .row)
            Size{ .width = child_main, .height = child_cross }
        else
            Size{ .width = child_cross, .height = child_main };
        const child_x = if (node.style.direction == .row) content_x + main_offset + leading_margin else content_x + crossLeadingMargin(child, node.style.direction);
        const child_y = if (node.style.direction == .row) content_y + crossLeadingMargin(child, node.style.direction) else content_y + main_offset + leading_margin;
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

fn finiteNonNegative(value: f32) f32 {
    return if (std.math.isNan(value) or value < 0) 0 else value;
}

fn clampBounds(value: f32, lower: f32, upper: f32) f32 {
    var result = finiteNonNegative(value);
    if (!std.math.isNan(lower) and lower >= 0) result = @max(result, lower);
    if (!std.math.isNan(upper) and upper >= 0) result = @min(result, upper);
    return result;
}

fn isUnset(value: f32) bool {
    return std.math.isNan(value) or value < 0;
}

fn optionalDimension(explicit: f32, intrinsic: f32) f32 {
    return finiteNonNegative(if (isUnset(explicit)) intrinsic else explicit);
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

test "insets flex and grid children by parent padding" {
    const children = [_]Node{
        .{ .style = .{ .flex_basis = 20 } },
        .{ .style = .{ .flex_basis = 20 } },
    };
    const flex_root = Node{
        .style = .{ .direction = .row, .width = 100, .height = 40, .padding_left = 8, .padding_top = 4, .padding_right = 12, .padding_bottom = 6 },
        .children = &children,
    };
    var flex_frames: [3]Frame = undefined;
    _ = try layout(flex_root, .{ .width = 100, .height = 40 }, &flex_frames);
    try std.testing.expectEqual(@as(f32, 8), flex_frames[1].x);
    try std.testing.expectEqual(@as(f32, 4), flex_frames[1].y);
    try std.testing.expectEqual(@as(f32, 30), flex_frames[1].height);

    const grid_children = [_]Node{.{ .style = .{ .height = 10 } }};
    const grid_root = Node{
        .style = .{ .grid = true, .grid_columns = 1, .width = 80, .height = 40, .padding_left = 5, .padding_top = 3, .padding_right = 7, .padding_bottom = 4 },
        .children = &grid_children,
    };
    var grid_frames: [2]Frame = undefined;
    _ = try layout(grid_root, .{ .width = 80, .height = 40 }, &grid_frames);
    try std.testing.expectEqual(@as(f32, 5), grid_frames[1].x);
    try std.testing.expectEqual(@as(f32, 3), grid_frames[1].y);
    try std.testing.expectEqual(@as(f32, 68), grid_frames[1].width);
}

test "exports the shared flex row contract with margins and bounds" {
    const items = [_]FlexItem{
        .{ .basis = 40, .grow = 1, .shrink = 1, .min = 30, .max = 70, .margin_start = 5, .margin_end = 7 },
        .{ .basis = 20, .grow = 2, .shrink = 1, .min = -1, .max = -1, .margin_start = 3, .margin_end = 4 },
    };
    var widths: [2]f32 = undefined;
    var positions: [2]f32 = undefined;
    try std.testing.expectEqual(@as(c_int, 0), craft_native_flex_row(180, 10, &items, items.len, &widths, &positions));
    try std.testing.expectApproxEqAbs(@as(f32, 70), widths[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 80.6667), widths[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5), positions[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 95), positions[1], 0.001);
}

test "exports justified flex positions" {
    const items = [_]FlexItem{
        .{ .basis = 20, .grow = 0, .shrink = 0, .min = -1, .max = -1, .margin_start = 0, .margin_end = 0 },
        .{ .basis = 20, .grow = 0, .shrink = 0, .min = -1, .max = -1, .margin_start = 0, .margin_end = 0 },
    };
    var widths: [2]f32 = undefined;
    var positions: [2]f32 = undefined;
    try std.testing.expectEqual(@as(c_int, 0), craft_native_flex_row_justified(100, 10, 1, &items, items.len, &widths, &positions));
    try std.testing.expectApproxEqAbs(@as(f32, 20), widths[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 25), positions[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 55), positions[1], 0.001);
}

test "exports equal-track grid frames with intrinsic rows and alignment" {
    const items = [_]GridItem{
        .{ .intrinsic_width = 20, .intrinsic_height = 12, .explicit_width = std.math.nan(f32), .explicit_height = std.math.nan(f32), .min_width = std.math.nan(f32), .max_width = std.math.nan(f32), .min_height = std.math.nan(f32), .max_height = std.math.nan(f32), .margin_left = 2, .margin_right = 3, .margin_top = 1, .margin_bottom = 2, .stretch = 0, .alignment = 1 },
        .{ .intrinsic_width = 10, .intrinsic_height = 20, .explicit_width = std.math.nan(f32), .explicit_height = std.math.nan(f32), .min_width = std.math.nan(f32), .max_width = std.math.nan(f32), .min_height = std.math.nan(f32), .max_height = std.math.nan(f32), .margin_left = 0, .margin_right = 0, .margin_top = 0, .margin_bottom = 0, .stretch = 1, .alignment = 0 },
        .{ .intrinsic_width = 30, .intrinsic_height = 10, .explicit_width = 40, .explicit_height = 10, .min_width = std.math.nan(f32), .max_width = std.math.nan(f32), .min_height = std.math.nan(f32), .max_height = std.math.nan(f32), .margin_left = 0, .margin_right = 0, .margin_top = 0, .margin_bottom = 0, .stretch = 0, .alignment = 2 },
    };
    var frames: [3]Frame = undefined;
    try std.testing.expectEqual(@as(c_int, 0), craft_native_grid(100, 80, 2, 10, 5, &items, items.len, &frames));
    try std.testing.expectApproxEqAbs(@as(f32, 12), frames[0].x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 20), frames[0].width, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 55), frames[1].x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 45), frames[1].width, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 25), frames[2].y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 40), frames[2].width, 0.001);
}
