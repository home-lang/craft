//! Geometry policy independent of AppKit, including secondary-display origins.
const std = @import("std");

/// AppKit adds small padding around titles. A larger change means the divider
/// is no longer anchored to the visible tray: native overflow or rearrangement.
pub fn anchorDisplaced(expected_gap: f64, marker_x: f64, marker_width: f64, tray_x: f64) bool {
    if (!std.math.isFinite(marker_x) or !std.math.isFinite(marker_width) or !std.math.isFinite(tray_x) or marker_width <= 0) return true;
    return @abs(tray_x - (marker_x + marker_width) - expected_gap) > 40;
}

test "native overflow releases the reserved width instead of blanking app menus" {
    try std.testing.expect(!anchorDisplaced(0, 546, 421, 975));
    try std.testing.expect(anchorDisplaced(0, 222, 421, 975));
}

test "moving the whole group across displays preserves its anchor" {
    try std.testing.expect(!anchorDisplaced(8, -966, 421, -537));
    try std.testing.expect(!anchorDisplaced(8, 2048, 421, 2477));
    try std.testing.expect(anchorDisplaced(8, 2048, 421, 2600));
}

test "invalid or removed geometry cannot confirm a collapse" {
    try std.testing.expect(anchorDisplaced(0, 0, 0, 0));
    try std.testing.expect(anchorDisplaced(0, std.math.nan(f64), 20, 40));
}
