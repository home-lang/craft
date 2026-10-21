const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");
const io_context = @import("io_context.zig");

const BridgeError = bridge_error.BridgeError;

/// Focus / Do Not Disturb bridge (macOS).
///
/// ## What macOS actually allows
///
/// Reading and writing Focus are two different privilege levels, and it is
/// worth being precise about them because the naive approaches that circulate
/// (writing `com.apple.notificationcenterui doNotDisturb` with `defaults`,
/// poking `~/Library/DoNotDisturb/DB/Assertions.json`, UI-scripting Control
/// Center) are either dead on current macOS or hopelessly brittle.
///
///   * **Reading** — `INFocusStatusCenter` (Intents.framework) is public API
///     since macOS 12 and reports whether the user is currently in *any*
///     Focus. It is permission-gated: the app must call
///     `requestAuthorization` and ship `NSFocusStatusUsageDescription` in its
///     `Info.plist`. That is what `getStatus` uses.
///
///   * **Writing** — the system service (`donotdisturbd`, reached through
///     `DNDModeAssertionService`) rejects every client that does not hold
///     `com.apple.private.donotdisturb.mode.assertion.client-identifiers`.
///     That entitlement is Apple-only; Control Center and Shortcuts hold it,
///     third-party apps cannot. The one sanctioned path left is to let
///     **Shortcuts** perform the mutation on the user's behalf: a shortcut
///     containing the *Set Focus* action, invoked through the `shortcuts`
///     CLI. `setEnabled` does exactly that, with no shell in between — the
///     binary is exec'd directly with an argv, so shortcut names cannot be
///     used for command injection.
///
/// Apps are expected to guide the user through creating the two shortcuts
/// once (see `listShortcuts` to verify they exist) and then drive them from
/// code. There is no supported alternative; anything else either needs an
/// Apple-private entitlement or breaks on the next macOS release.
pub const FocusBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(_: *Self) void {}

    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        self.dispatch(action, data) catch |err| {
            const mapped: BridgeError = switch (err) {
                BridgeError.MissingData => BridgeError.MissingData,
                BridgeError.InvalidJSON => BridgeError.InvalidJSON,
                BridgeError.InvalidParameter => BridgeError.InvalidParameter,
                BridgeError.UnknownAction => return err,
                else => BridgeError.NativeCallFailed,
            };
            bridge_error.sendErrorToJS(self.allocator, action, mapped);
        };
    }

    fn dispatch(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "getStatus")) {
            try self.getStatus();
        } else if (std.mem.eql(u8, action, "requestAuthorization")) {
            try self.requestAuthorization();
        } else if (std.mem.eql(u8, action, "setEnabled")) {
            try self.setEnabled(data);
        } else if (std.mem.eql(u8, action, "runShortcut")) {
            try self.runShortcut(data);
        } else if (std.mem.eql(u8, action, "listShortcuts")) {
            try self.listShortcuts();
        } else {
            return BridgeError.UnknownAction;
        }
    }

    // -------------------------------------------------------------------------
    // Status
    // -------------------------------------------------------------------------

    fn getStatus(self: *Self) !void {
        if (comptime builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "getStatus", unsupported_status_json);
            return;
        }
        const center = focusStatusCenter() orelse {
            bridge_error.sendResultToJS(self.allocator, "getStatus", unsupported_status_json);
            return;
        };
        const macos = @import("macos.zig");

        const auth = authorizationName(msgSendLong(center, "authorizationStatus"));

        // -[INFocusStatus isFocused] is a *nullable* NSNumber: nil means the
        // system declined to say (typically because authorization has not been
        // granted), which is not the same as "not focused".
        const status = macos.msgSend0(center, "focusStatus");
        var focused_json: []const u8 = "null";
        if (@intFromPtr(status) != 0) {
            const number = macos.msgSend0(status, "isFocused");
            if (@intFromPtr(number) != 0) {
                focused_json = if (msgSendBool(number, "boolValue")) "true" else "false";
            }
        }

        var buf: [160]u8 = undefined;
        const json = try std.fmt.bufPrint(
            &buf,
            "{{\"supported\":true,\"isFocused\":{s},\"authorization\":\"{s}\"}}",
            .{ focused_json, auth },
        );
        bridge_error.sendResultToJS(self.allocator, "getStatus", json);
    }

    /// Authorization may complete on another queue after the system prompt.
    /// Capture the bridge request and return to AppKit instead of nesting a
    /// run loop and replying with a stale authorization value after a timeout.
    fn requestAuthorization(self: *Self) !void {
        if (comptime builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "requestAuthorization", "{\"authorization\":\"unsupported\"}");
            return;
        }
        const center = focusStatusCenter() orelse {
            bridge_error.sendResultToJS(self.allocator, "requestAuthorization", "{\"authorization\":\"unsupported\"}");
            return;
        };
        const macos = @import("macos.zig");
        const pending = @import("ios_async.zig");
        const ticket = pending.acquire("requestAuthorization") orelse return BridgeError.Busy;
        const block = AuthBlock{ .index = ticket.index, .generation = ticket.generation };
        const Fn = *const fn (macos.objc.id, macos.objc.SEL, *const anyopaque) callconv(.c) void;
        const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
        f(center, macos.sel("requestAuthorizationWithCompletionHandler:"), &block);
    }

    // -------------------------------------------------------------------------
    // Mutation (via Shortcuts)
    // -------------------------------------------------------------------------

    /// `{"enabled":true,"onShortcut":"Hush Focus On","offShortcut":"Hush Focus Off"}`
    fn setEnabled(self: *Self, data: []const u8) !void {
        const Params = struct {
            enabled: bool = false,
            onShortcut: []const u8 = "",
            offShortcut: []const u8 = "",
            strategy: []const u8 = "auto",
        };
        const parsed = std.json.parseFromSlice(Params, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();

        const name = if (parsed.value.enabled) parsed.value.onShortcut else parsed.value.offShortcut;
        if (name.len == 0) return BridgeError.MissingData;
        try self.executeShortcut("setEnabled", name, resolveStrategy(parsed.value.strategy));
    }

    /// `{"name":"Some Shortcut"}` — the generic escape hatch for apps that
    /// drive more than an on/off pair (per-mode shortcuts, timed focus, …).
    fn runShortcut(self: *Self, data: []const u8) !void {
        const Params = struct { name: []const u8 = "", strategy: []const u8 = "auto" };
        const parsed = std.json.parseFromSlice(Params, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        if (parsed.value.name.len == 0) return BridgeError.MissingData;
        try self.executeShortcut("runShortcut", parsed.value.name, resolveStrategy(parsed.value.strategy));
    }

    fn executeShortcut(self: *Self, action: []const u8, name: []const u8, strategy: Strategy) !void {
        if (comptime builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, action, "{\"ok\":false,\"error\":\"unsupported platform\"}");
            return;
        }
        try validateShortcutName(name);

        if (strategy == .url) {
            try self.openShortcutUrl(action, name);
            return;
        }

        const pending = @import("ios_async.zig");
        const ticket = pending.acquire(action) orelse return BridgeError.Busy;
        const allocator = std.heap.c_allocator;
        const work = allocator.create(ShortcutWork) catch {
            pending.abandon(ticket);
            return error.OutOfMemory;
        };
        work.* = .{ .ticket = ticket, .name = allocator.dupe(u8, name) catch {
            allocator.destroy(work);
            pending.abandon(ticket);
            return error.OutOfMemory;
        } };
        const thread = std.Thread.spawn(.{}, runShortcutWork, .{work}) catch {
            allocator.free(work.name);
            allocator.destroy(work);
            pending.abandon(ticket);
            return BridgeError.NativeCallFailed;
        };
        thread.detach();
    }

    /// Hand `shortcuts://run-shortcut?name=…` to LaunchServices.
    ///
    /// The sandbox-legal route. It is fire-and-forget by construction: the
    /// reply says the URL was accepted, never whether the shortcut ran, so the
    /// result carries `dispatched:true` rather than pretending to an exit
    /// status it does not have.
    fn openShortcutUrl(self: *Self, action: []const u8, name: []const u8) !void {
        const macos = @import("macos.zig");

        const encoded = try percentEncode(self.allocator, name);
        defer self.allocator.free(encoded);

        const url = try std.fmt.allocPrintSentinel(
            self.allocator,
            "shortcuts://run-shortcut?name={s}",
            .{encoded},
            0,
        );
        defer self.allocator.free(url);

        const NSString = macos.getClass("NSString");
        const url_str = macos.msgSend1(NSString, "stringWithUTF8String:", url.ptr);
        const NSURL = macos.getClass("NSURL");
        const nsurl = macos.msgSend1(NSURL, "URLWithString:", url_str);
        if (@intFromPtr(nsurl) == 0) return BridgeError.InvalidParameter;

        const NSWorkspace = macos.getClass("NSWorkspace");
        const workspace = macos.msgSend0(NSWorkspace, "sharedWorkspace");
        const opened = msgSendBool1(workspace, "openURL:", nsurl);

        var out: std.ArrayListUnmanaged(u8) = .empty;
        defer out.deinit(self.allocator);
        try out.appendSlice(self.allocator, if (opened) "{\"ok\":true," else "{\"ok\":false,");
        try out.appendSlice(self.allocator, "\"strategy\":\"url\",\"dispatched\":");
        try out.appendSlice(self.allocator, if (opened) "true" else "false");
        try out.appendSlice(self.allocator, ",\"shortcut\":\"");
        try bridge_error.appendJsonEscaped(self.allocator, &out, name);
        try out.appendSlice(self.allocator, "\"");
        if (!opened) {
            try out.appendSlice(self.allocator, ",\"error\":\"Shortcuts did not accept the request — is the Shortcuts app available?\"");
        }
        try out.append(self.allocator, '}');

        bridge_error.sendResultToJS(self.allocator, action, out.items);
    }

    /// Names of every shortcut installed for the current user. Apps use this
    /// to verify their Focus shortcuts exist before offering the feature.
    fn listShortcuts(self: *Self) !void {
        if (comptime builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "listShortcuts", unavailable_list_json);
            return;
        }
        // Enumerating means running the CLI, which the App Sandbox forbids. A
        // sandboxed app gets `canList:false` — meaningfully different from an
        // empty list, which would otherwise read as "the user has no shortcuts"
        // and send them into a setup flow they have already completed.
        if (isSandboxed()) {
            bridge_error.sendResultToJS(self.allocator, "listShortcuts", unavailable_list_json);
            return;
        }
        const io = io_context.get();
        var child = std.process.spawn(io, .{
            .argv = &.{ shortcuts_binary, "list" },
            .stdout = .pipe,
            .stderr = .ignore,
            .stdin = .ignore,
        }) catch {
            bridge_error.sendResultToJS(self.allocator, "listShortcuts", unavailable_list_json);
            return;
        };

        var stdout_buf: std.ArrayListUnmanaged(u8) = .empty;
        defer stdout_buf.deinit(self.allocator);
        if (child.stdout) |stdout_file| drain(io, stdout_file, &stdout_buf, self.allocator) catch {};
        _ = child.wait(io) catch {};

        var out: std.ArrayListUnmanaged(u8) = .empty;
        defer out.deinit(self.allocator);
        try out.appendSlice(self.allocator, "{\"canList\":true,\"shortcuts\":[");
        var first = true;
        var lines = std.mem.splitScalar(u8, stdout_buf.items, '\n');
        while (lines.next()) |raw| {
            const line = std.mem.trim(u8, raw, " \t\r");
            if (line.len == 0) continue;
            if (!first) try out.append(self.allocator, ',');
            first = false;
            try out.append(self.allocator, '"');
            try bridge_error.appendJsonEscaped(self.allocator, &out, line);
            try out.append(self.allocator, '"');
        }
        try out.appendSlice(self.allocator, "]}");
        bridge_error.sendResultToJS(self.allocator, "listShortcuts", out.items);
    }
};

// =============================================================================
// Helpers
// =============================================================================

const ShortcutWork = struct {
    ticket: @import("ios_async.zig").Ticket,
    name: []u8,
};

fn runFocusProcess(allocator: std.mem.Allocator, argv: []const []const u8, timeout_ms: u32) !std.process.RunResult {
    const io = io_context.get();
    return std.process.run(allocator, io, .{
        .argv = argv,
        .stdout_limit = .limited(64 * 1024),
        .stderr_limit = .limited(64 * 1024),
        .timeout = (std.Io.Timeout{ .duration = .{ .clock = .awake, .raw = .fromMilliseconds(timeout_ms) } }).toDeadline(io),
    });
}

fn runShortcutWork(work: *ShortcutWork) void {
    const allocator = std.heap.c_allocator;
    defer allocator.destroy(work);
    defer allocator.free(work.name);
    const pending = @import("ios_async.zig");
    // Do not hold AppKit's main thread while Shortcuts handles a workflow.
    // The deadline also reaps an unresponsive CLI instead of hanging the app.
    const result = runFocusProcess(allocator, &.{ shortcuts_binary, "run", work.name }, 15_000) catch |err| {
        pending.deliverJson(work.ticket, if (err == error.Timeout)
            "{\"ok\":false,\"error\":\"Shortcut timed out; open Shortcuts and verify it completes.\"}"
        else
            "{\"ok\":false,\"error\":\"Shortcuts CLI did not complete.\"}");
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    const exit_code: i32 = switch (result.term) {
        .exited => |code| @intCast(code),
        .signal => |sig| -@as(i32, @intCast(@backingInt(sig))),
        else => -1,
    };
    const json = std.json.Stringify.valueAlloc(allocator, .{
        .ok = exit_code == 0,
        .strategy = "shortcut",
        .exitCode = exit_code,
        .shortcut = work.name,
        .@"error" = if (exit_code == 0) @as(?[]const u8, null) else std.mem.trim(u8, result.stderr, " \t\r\n"),
    }, .{}) catch {
        pending.deliverError(work.ticket);
        return;
    };
    defer allocator.free(json);
    pending.deliverJson(work.ticket, json);
}

const shortcuts_binary = "/usr/bin/shortcuts";

const unavailable_list_json = "{\"canList\":false,\"shortcuts\":[]}";

/// How a shortcut gets run.
///
/// `cli` execs `/usr/bin/shortcuts` and reports the shortcut's real exit
/// status. `url` opens `shortcuts://run-shortcut`, which is the only route the
/// App Sandbox permits — a sandboxed process may ask LaunchServices to open a
/// URL, but may not spawn a binary outside its bundle.
///
/// The two are not equivalent, and callers should know which they got: the URL
/// scheme is fire-and-forget. LaunchServices reports that it handed the URL to
/// Shortcuts, not that the shortcut ran or succeeded, so `ok` means "asked"
/// rather than "done". Where a real status is available, `cli` is the better
/// answer, which is why `auto` only falls back to `url` under sandbox.
pub const Strategy = enum { cli, url };

fn resolveStrategy(requested: []const u8) Strategy {
    if (std.mem.eql(u8, requested, "cli")) return .cli;
    if (std.mem.eql(u8, requested, "url")) return .url;
    // "auto", and anything unrecognised.
    return if (isSandboxed()) .url else .cli;
}

/// Whether this process is running inside the App Sandbox.
///
/// The container id is exported into every sandboxed process's environment and
/// is absent otherwise, which makes it the cheapest reliable marker — no
/// entitlement parsing, no private API.
fn isSandboxed() bool {
    if (comptime builtin.os.tag != .macos) return false;
    return c_getenv("APP_SANDBOX_CONTAINER_ID") != null;
}

/// Percent-encode a shortcut name for a query string.
///
/// Names routinely contain spaces, and may contain `&`, `#` or `+` — each of
/// which silently changes the parse if it goes through raw, so the shortcut
/// that runs is not the one that was asked for. Everything outside the
/// unreserved set is escaped.
fn percentEncode(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    const hex = "0123456789ABCDEF";
    for (value) |c| {
        const unreserved = (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or
            (c >= '0' and c <= '9') or c == '-' or c == '.' or c == '_' or c == '~';
        if (unreserved) {
            try out.append(allocator, c);
        } else {
            try out.append(allocator, '%');
            try out.append(allocator, hex[c >> 4]);
            try out.append(allocator, hex[c & 0x0F]);
        }
    }
    return out.toOwnedSlice(allocator);
}

const unsupported_status_json = "{\"supported\":false,\"isFocused\":null,\"authorization\":\"unsupported\"}";

/// Shortcut names are passed as a single argv entry, so no shell metacharacter
/// can reach a shell — there is none. What we do reject is control characters
/// and absurd lengths, which only ever indicate a caller bug or an attempt to
/// smuggle newlines into the CLI's own parsing.
fn validateShortcutName(name: []const u8) BridgeError!void {
    if (name.len > 255) return BridgeError.InvalidParameter;
    for (name) |c| {
        if (c < 0x20 or c == 0x7F) return BridgeError.InvalidParameter;
    }
}

fn drain(
    io: anytype,
    file: anytype,
    out: *std.ArrayListUnmanaged(u8),
    allocator: std.mem.Allocator,
) !void {
    var chunk: [4096]u8 = undefined;
    while (true) {
        const n = file.readStreaming(io, &.{&chunk}) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        if (n == 0) break;
        try out.appendSlice(allocator, chunk[0..n]);
    }
}

/// INFocusStatusAuthorizationStatus
fn authorizationName(status: c_long) []const u8 {
    return switch (status) {
        1 => "restricted",
        2 => "denied",
        3 => "authorized",
        else => "notDetermined",
    };
}

// -----------------------------------------------------------------------------
// Objective-C plumbing
// -----------------------------------------------------------------------------

extern "c" fn dlopen(path: [*:0]const u8, mode: c_int) ?*anyopaque;
extern "c" fn getenv(name: [*:0]const u8) ?[*:0]const u8;
const c_getenv = getenv;
const RTLD_LAZY: c_int = 0x1;

var intents_loaded = false;

/// Intents.framework is not in craft's link line — the bridge reaches it
/// through the ObjC runtime, so it has to be brought into the process first.
/// Loading is idempotent and cheap after the first call.
fn loadIntents() void {
    if (intents_loaded) return;
    intents_loaded = true;
    _ = dlopen("/System/Library/Frameworks/Intents.framework/Intents", RTLD_LAZY);
}

fn focusStatusCenter() ?@import("macos.zig").objc.id {
    if (comptime builtin.os.tag != .macos) return null;
    const macos = @import("macos.zig");
    loadIntents();
    const cls = macos.objc.objc_getClass("INFocusStatusCenter");
    if (cls == null) return null;
    const center = macos.msgSend0(cls, "defaultCenter");
    if (@intFromPtr(center) == 0) return null;
    return center;
}

fn msgSendLong(target: anytype, selector: [*:0]const u8) c_long {
    const macos = @import("macos.zig");
    const Fn = *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) c_long;
    const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
    return f(@ptrCast(target), macos.sel(selector));
}

fn msgSendBool1(target: anytype, selector: [*:0]const u8, arg: anytype) bool {
    const macos = @import("macos.zig");
    const Fn = *const fn (macos.objc.id, macos.objc.SEL, @TypeOf(arg)) callconv(.c) bool;
    const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
    return f(@ptrCast(target), macos.sel(selector), arg);
}

fn msgSendBool(target: anytype, selector: [*:0]const u8) bool {
    const macos = @import("macos.zig");
    const Fn = *const fn (macos.objc.id, macos.objc.SEL) callconv(.c) bool;
    const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
    return f(@ptrCast(target), macos.sel(selector));
}

// A capturing stack block is copied by Intents when it retains the callback.
// Its only captures are POD ticket fields; no copy/dispose callbacks are needed.
const BlockDescriptor = extern struct {
    reserved: usize = 0,
    size: usize,
};
extern var _NSConcreteStackBlock: anyopaque;
const auth_descriptor = BlockDescriptor{ .size = @sizeOf(AuthBlock) };
const AuthBlock = extern struct {
    isa: ?*anyopaque = &_NSConcreteStackBlock,
    flags: c_int = 0,
    reserved: c_int = 0,
    invoke: *const fn (*const AuthBlock, c_long) callconv(.c) void = authInvoke,
    descriptor: *const BlockDescriptor = &auth_descriptor,
    index: u32,
    generation: u32,
};

fn authInvoke(block: *const AuthBlock, status: c_long) callconv(.c) void {
    var buf: [96]u8 = undefined;
    const json = std.fmt.bufPrint(&buf, "{{\"authorization\":\"{s}\"}}", .{authorizationName(status)}) catch return;
    @import("ios_async.zig").deliverJson(.{ .index = @intCast(block.index), .generation = block.generation }, json);
}

// =============================================================================
// Tests
// =============================================================================

test "authorizationName maps every INFocusStatusAuthorizationStatus case" {
    try std.testing.expectEqualStrings("notDetermined", authorizationName(0));
    try std.testing.expectEqualStrings("restricted", authorizationName(1));
    try std.testing.expectEqualStrings("denied", authorizationName(2));
    try std.testing.expectEqualStrings("authorized", authorizationName(3));
    // Anything the OS adds later reads as "not determined" rather than
    // silently claiming authorization.
    try std.testing.expectEqualStrings("notDetermined", authorizationName(99));
}

test "resolveStrategy honours an explicit choice and defaults by environment" {
    try std.testing.expectEqual(Strategy.cli, resolveStrategy("cli"));
    try std.testing.expectEqual(Strategy.url, resolveStrategy("url"));
    // "auto" and anything unrecognised follow the sandbox, and this process is
    // not sandboxed, so both land on the strategy that reports a real status.
    try std.testing.expectEqual(Strategy.cli, resolveStrategy("auto"));
    try std.testing.expectEqual(Strategy.cli, resolveStrategy("nonsense"));
}

test "percentEncode escapes everything that would change the query's parse" {
    const a = try percentEncode(std.testing.allocator, "Hush Focus On");
    defer std.testing.allocator.free(a);
    try std.testing.expectEqualStrings("Hush%20Focus%20On", a);

    // `&` would start a new parameter, `#` a fragment, `+` decode as a space —
    // each silently runs a different shortcut than the one requested.
    const b = try percentEncode(std.testing.allocator, "A&B#C+D");
    defer std.testing.allocator.free(b);
    try std.testing.expectEqualStrings("A%26B%23C%2BD", b);

    const c = try percentEncode(std.testing.allocator, "safe-name_1.0~x");
    defer std.testing.allocator.free(c);
    try std.testing.expectEqualStrings("safe-name_1.0~x", c);
}

test "validateShortcutName rejects control characters and oversized names" {
    try validateShortcutName("Hush Focus On");
    try validateShortcutName("Focus — On (1h)");
    try std.testing.expectError(BridgeError.InvalidParameter, validateShortcutName("bad\nname"));
    try std.testing.expectError(BridgeError.InvalidParameter, validateShortcutName("bad\x00name"));
    var overlong: [256]u8 = undefined;
    @memset(&overlong, 'x');
    try std.testing.expectError(BridgeError.InvalidParameter, validateShortcutName(&overlong));
}

test "unresponsive Focus commands are bounded and reaped" {
    if (builtin.os.tag != .macos) return error.SkipZigTest;
    try std.testing.expectError(error.Timeout, runFocusProcess(std.testing.allocator, &.{ "/bin/sleep", "1" }, 20));
}
