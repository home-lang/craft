const std = @import("std");

/// Build the script used when a native sidebar selection navigates its webview.
///
/// The URL is serialized as JSON instead of interpolated into a quoted
/// JavaScript string. Sidebar configuration is user-authored, so quotes,
/// backslashes, control characters, and Unicode must never change the script's
/// structure.
pub fn buildNavigationScript(allocator: std.mem.Allocator, url: []const u8) ![]u8 {
    var script: std.Io.Writer.Allocating = .init(allocator);
    defer script.deinit();

    const writer = &script.writer;
    try writer.writeAll("(() => { const url = ");
    try std.json.Stringify.value(url, .{}, writer);
    try writer.writeAll("; return typeof window.navigate === 'function' ? window.navigate(url) : (window.location.href = url); })()");

    return script.toOwnedSlice();
}
