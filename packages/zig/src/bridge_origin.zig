//! Native bridge trust follows app-directed loads, never page navigation.
//! The platform supplies canonical URL parts and unforgeable frame metadata.
const std = @import("std");

pub const URL = struct {
    scheme: []const u8,
    host: []const u8,
    port: u64 = 0,
    path: []const u8 = "",

    fn effectivePort(self: URL) u64 {
        if (self.port != 0) return self.port;
        if (std.ascii.eqlIgnoreCase(self.scheme, "https")) return 443;
        if (std.ascii.eqlIgnoreCase(self.scheme, "http")) return 80;
        return 0;
    }
};

pub fn sameOrigin(trusted: URL, candidate: URL) bool {
    return std.ascii.eqlIgnoreCase(trusted.scheme, candidate.scheme) and
        std.ascii.eqlIgnoreCase(trusted.host, candidate.host) and
        trusted.effectivePort() == candidate.effectivePort();
}

pub fn allowsNavigation(trusted: URL, candidate: URL, inline_html: bool) bool {
    if (!sameOrigin(trusted, candidate)) return false;
    if (inline_html) return false;
    if (std.ascii.eqlIgnoreCase(trusted.scheme, "file"))
        return std.mem.eql(u8, trusted.path, candidate.path);
    return (std.ascii.eqlIgnoreCase(trusted.scheme, "https") or
        std.ascii.eqlIgnoreCase(trusted.scheme, "http")) and trusted.host.len > 0;
}

pub fn allowsBridge(trusted: URL, frame_origin: URL, frame_url: URL, main_frame: bool, inline_html: bool) bool {
    if (!main_frame or !sameOrigin(trusted, frame_origin)) return false;
    if (inline_html and std.ascii.eqlIgnoreCase(frame_url.scheme, "about") and
        std.mem.eql(u8, frame_url.path, "blank")) return true;
    if (inline_html) return sameOrigin(trusted, frame_url) and std.mem.eql(u8, trusted.path, frame_url.path);
    return allowsNavigation(trusted, frame_url, false);
}

test "bridge messages require the trusted origin and main frame" {
    const local = URL{ .scheme = "https", .host = "app.example", .path = "/" };
    const remote = URL{ .scheme = "https", .host = "evil.example", .path = "/" };
    try std.testing.expect(allowsBridge(local, local, local, true, false));
    try std.testing.expect(!allowsBridge(local, remote, remote, true, false));
    try std.testing.expect(!allowsBridge(local, local, local, false, false));
    try std.testing.expect(!allowsBridge(local, remote, local, true, false));
    try std.testing.expect(!allowsNavigation(local, .{ .scheme = "https", .host = "app.example", .port = 8443 }, false));
    try std.testing.expect(!allowsNavigation(local, .{ .scheme = "http", .host = "app.example" }, false));
    try std.testing.expect(allowsNavigation(local, .{ .scheme = "HTTPS", .host = "APP.EXAMPLE", .port = 443, .path = "/next" }, false));
}

test "inline HTML and file documents cannot navigate into other privileged documents" {
    const file = URL{ .scheme = "file", .host = "", .path = "/app/index.html" };
    try std.testing.expect(allowsNavigation(file, file, false));
    try std.testing.expect(!allowsNavigation(file, .{ .scheme = "file", .host = "", .path = "/tmp/evil.html" }, false));
    const html = URL{ .scheme = "http", .host = "localhost", .path = "/" };
    try std.testing.expect(allowsBridge(html, html, .{ .scheme = "about", .host = "", .path = "blank" }, true, true));
    try std.testing.expect(!allowsBridge(html, html, .{ .scheme = "http", .host = "localhost", .path = "/evil" }, true, true));
    try std.testing.expect(!allowsBridge(html, html, .{ .scheme = "data", .host = "", .path = "x" }, true, true));
}
