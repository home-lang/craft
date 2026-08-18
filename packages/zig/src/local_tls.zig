//! The half of the local-development TLS exception that has no AppKit in it.
//!
//! `macos.zig` owns the `WKNavigationDelegate`; this owns the two decisions it
//! makes — whether the process opted in at all, and whether a host name is this
//! machine. Both are security-relevant and neither needs a window, so they live
//! here where they can be tested.

const std = @import("std");

/// The environment variable that turns the exception on.
///
/// Deliberately an environment variable rather than a `WindowStyle` field or a
/// CLI flag, which is how every other window option travels. Those options are
/// written in `craft.config.ts` and ship inside the built app; a certificate
/// bypass that can be committed to an app's config is a bypass that eventually
/// ships to users who never asked for it. This one is set on the machine doing
/// the development and cannot be baked into the artefact.
pub const env_var = "CRAFT_ALLOW_LOCAL_TLS";

/// Whether the environment opted this process in. `raw` is the value of
/// `env_var`, or null when it is unset.
///
/// Unset, empty, `0`, `false` and `no` all mean no. Anything else means yes:
/// the variable exists only to be switched on deliberately, so an unrecognised
/// value is far likelier to be someone trying to enable it than someone trying
/// to disable it.
pub fn allowedByEnv(raw: ?[]const u8) bool {
    const value = raw orelse return false;
    if (value.len == 0) return false;
    return !std.ascii.eqlIgnoreCase(value, "0") and
        !std.ascii.eqlIgnoreCase(value, "false") and
        !std.ascii.eqlIgnoreCase(value, "no");
}

/// Whether `host` names this machine over loopback.
///
/// Two families count: the loopback literals, and the `localhost` reserved TLD
/// (RFC 6761 §6.3), which is what a local CA like tlsx issues for —
/// `dashboard.stacks.localhost` and friends.
///
/// This is a check on the *name* the webview was asked to load, not on the
/// address the connection reached: WKWebView does not hand us the peer, and
/// `foo.localhost` resolving to loopback is a convention the resolver honours
/// rather than something verifiable from here. That gap is exactly why the
/// whole path is behind `env_var` instead of being on by default.
///
/// Matching is case-insensitive because DNS names are. A case-folded miss would
/// fail safe, but it would fail *confusingly* — `https://Dashboard.localhost`
/// working and `https://dashboard.localhost` not is nobody's idea of a good
/// afternoon.
pub fn isLocalHostName(host: []const u8) bool {
    if (host.len == 0) return false;

    // `NSURLProtectionSpace` hands back a bare host, but tolerate the URL's
    // bracketed IPv6 form in case this is ever called with one.
    const bare = if (host.len >= 2 and host[0] == '[' and host[host.len - 1] == ']')
        host[1 .. host.len - 1]
    else
        host;

    if (std.ascii.eqlIgnoreCase(bare, "localhost")) return true;
    if (isLoopbackLiteral(bare)) return true;

    // `*.localhost`, but not a bare `.localhost`: a leading-dot host is not a
    // name anything can reach, so matching it would widen the exception for
    // nothing.
    const suffix = ".localhost";
    return bare.len > suffix.len and
        std.ascii.eqlIgnoreCase(bare[bare.len - suffix.len ..], suffix);
}

/// Whether `host` is an IP literal in a loopback range.
///
/// The whole of 127.0.0.0/8 counts, not just 127.0.0.1 — a local proxy handing
/// each service its own 127.0.0.x is an ordinary way to keep them apart.
/// Anything that is not an IP literal at all is not our business: it comes back
/// false and is judged as a name instead.
///
/// Parsed by hand because this Zig has no `std.net`. Both parsers are strict
/// and reject on anything they do not fully understand, which is the direction
/// a check like this should fail in: an address we cannot read is an address we
/// do not trust. That also disposes of the octal trick — `0177.0.0.1` is
/// 127.0.0.1 to `inet_aton` and a four-digit group to this, so it is refused.
fn isLoopbackLiteral(host: []const u8) bool {
    if (parseIp4(host)) |octets| return octets[0] == 127;
    if (parseIp6(host)) |groups| {
        for (groups[0..7]) |group| {
            if (group != 0) return false;
        }
        return groups[7] == 1;
    }
    return false;
}

/// Dotted-quad only: exactly four groups of one to three decimal digits, each
/// no more than 255.
fn parseIp4(host: []const u8) ?[4]u8 {
    var octets: [4]u8 = undefined;
    var parts = std.mem.splitScalar(u8, host, '.');
    for (&octets) |*octet| {
        const part = parts.next() orelse return null;
        if (part.len == 0 or part.len > 3) return null;
        octet.* = std.fmt.parseInt(u8, part, 10) catch return null;
    }
    if (parts.next() != null) return null;
    return octets;
}

/// Eight 16-bit groups, with at most one `::` standing in for a run of zeroes.
fn parseIp6(host: []const u8) ?[8]u16 {
    if (std.mem.indexOf(u8, host, "::")) |elision| {
        const head = host[0..elision];
        const tail = host[elision + 2 ..];
        // A second `::` is not a shorthand, it is a malformed address.
        if (std.mem.indexOf(u8, tail, "::") != null) return null;

        var groups: [8]u16 = @splat(0);
        const head_len = fillGroups(&groups, head, 0) orelse return null;
        // The elision has to stand for at least one group, so the two halves
        // together must leave room.
        const tail_len = countGroups(tail) orelse return null;
        if (head_len + tail_len >= 8) return null;
        _ = fillGroups(groups[8 - tail_len ..], tail, 0) orelse return null;
        return groups;
    }

    var groups: [8]u16 = @splat(0);
    const written = fillGroups(&groups, host, 0) orelse return null;
    if (written != 8) return null;
    return groups;
}

/// Write the colon-separated groups of `text` into `out`, returning how many
/// there were, or null if any group is malformed or there are too many. An
/// empty `text` is zero groups, which is what each side of a leading or
/// trailing `::` looks like.
fn fillGroups(out: []u16, text: []const u8, start: usize) ?usize {
    if (text.len == 0) return start;
    var written = start;
    var parts = std.mem.splitScalar(u8, text, ':');
    while (parts.next()) |part| {
        if (part.len == 0 or part.len > 4) return null;
        if (written == out.len) return null;
        out[written] = std.fmt.parseInt(u16, part, 16) catch return null;
        written += 1;
    }
    return written;
}

fn countGroups(text: []const u8) ?usize {
    var scratch: [8]u16 = undefined;
    return fillGroups(&scratch, text, 0);
}

// =============================================================================

const testing = std.testing;

test "the exception is off unless something switches it on" {
    try testing.expect(!allowedByEnv(null));
    try testing.expect(!allowedByEnv(""));
    try testing.expect(!allowedByEnv("0"));
    try testing.expect(!allowedByEnv("false"));
    try testing.expect(!allowedByEnv("FALSE"));
    try testing.expect(!allowedByEnv("no"));
}

test "anything else in the variable means the developer meant to set it" {
    try testing.expect(allowedByEnv("1"));
    try testing.expect(allowedByEnv("true"));
    try testing.expect(allowedByEnv("yes"));
    // Not a value anyone would type on purpose, but someone who exported this
    // variable at all was trying to turn it on, not off.
    try testing.expect(allowedByEnv("please"));
}

test "loopback literals and localhost are local" {
    try testing.expect(isLocalHostName("localhost"));
    try testing.expect(isLocalHostName("LocalHost"));
    try testing.expect(isLocalHostName("127.0.0.1"));
    // A local proxy giving each service its own loopback address.
    try testing.expect(isLocalHostName("127.0.0.2"));
    try testing.expect(isLocalHostName("127.255.255.254"));
    try testing.expect(isLocalHostName("::1"));
    try testing.expect(isLocalHostName("[::1]"));
    try testing.expect(isLocalHostName("0:0:0:0:0:0:0:1"));
}

test "subdomains of the localhost TLD are local" {
    try testing.expect(isLocalHostName("dashboard.stacks.localhost"));
    try testing.expect(isLocalHostName("api.localhost"));
    try testing.expect(isLocalHostName("Dashboard.Stacks.LOCALHOST"));
}

test "a name that merely looks local is not" {
    // The whole point of the suffix check: these are ordinary internet hosts
    // that an attacker controls, and none of them may skip validation.
    try testing.expect(!isLocalHostName("localhost.evil.com"));
    try testing.expect(!isLocalHostName("notlocalhost"));
    try testing.expect(!isLocalHostName("mylocalhost"));
    try testing.expect(!isLocalHostName("localhost.com"));
    try testing.expect(!isLocalHostName("evil.com"));
    try testing.expect(!isLocalHostName(""));
    // A leading-dot host reaches nothing; matching it would widen the
    // exception for no one's benefit.
    try testing.expect(!isLocalHostName(".localhost"));
}

test "an address the parser cannot fully read is refused" {
    // `inet_aton` reads a leading zero as octal and makes this 127.0.0.1. The
    // parser here only speaks decimal dotted-quad, so it declines instead.
    try testing.expect(!isLocalHostName("0177.0.0.1"));
    try testing.expect(!isLocalHostName("127.0.0.1.5"));
    try testing.expect(!isLocalHostName("127.0.0"));
    try testing.expect(!isLocalHostName("127.0.0.256"));
    try testing.expect(!isLocalHostName("127..0.1"));
    // A host with the port still attached is not a host; fail safe rather than
    // trying to guess where it ends.
    try testing.expect(!isLocalHostName("127.0.0.1:3000"));
    // Two elisions is malformed, not doubly convenient.
    try testing.expect(!isLocalHostName("::1::1"));
    try testing.expect(!isLocalHostName("0:0:0:0:0:0:1"));
    try testing.expect(!isLocalHostName("::10000"));
    // `::` on its own is the unspecified address, which is not loopback.
    try testing.expect(!isLocalHostName("::"));
    try testing.expect(!isLocalHostName("1::"));
}

test "non-loopback addresses are not local" {
    try testing.expect(!isLocalHostName("128.0.0.1"));
    try testing.expect(!isLocalHostName("126.255.255.255"));
    try testing.expect(!isLocalHostName("192.168.1.10"));
    try testing.expect(!isLocalHostName("10.0.0.1"));
    try testing.expect(!isLocalHostName("0.0.0.0"));
    try testing.expect(!isLocalHostName("::2"));
    // A private-range address is still someone else's machine. `localhost` is
    // about this process's own loopback, and nothing more.
    try testing.expect(!isLocalHostName("169.254.1.1"));
}
