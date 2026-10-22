//! Craft's own JavaScript runtime — no webview, no WebKit, no JSC.
//!
//! Craft executes JavaScript in two quite different places, and they are worth
//! keeping apart:
//!
//!   - **The page's JavaScript** runs inside WKWebView's WebContent process, on
//!     WebKit's own JSC. Craft does not own that engine and cannot replace it
//!     without replacing the webview, which is the whole product. Nothing here
//!     touches it.
//!
//!   - **Craft's own JavaScript** — a tray handler, a scheduled task, a config
//!     file, a script the CLI is handed — had no home. The only way to run any
//!     of it was to create a WKWebView, which means a WebContent process, tens
//!     of megabytes and a few hundred milliseconds to call one function. A
//!     menubar-only app, which has no window by definition, simply could not.
//!
//! This is a home for the second kind, on a first-party engine.
//!
//! The backend is chosen at build time. With `-Djs-runtime` it is zig-js; by
//! default it is a stub that reports its own absence, because zig-js resolves
//! through a sibling checkout rather than a fetchable package — its own
//! dependencies use relative paths, so it cannot be a `.url` dependency until
//! those are published. A default build must still compile on CI and ship to
//! npm, so the feature is opt-in until that changes rather than a hard break.

const std = @import("std");
const backend = @import("js_backend");

/// Whether this build can actually evaluate. Comptime, so callers can refuse
/// the work before setting anything up.
pub const available = backend.available;

pub const Error = backend.Error;

/// Told to the user rather than logged: an unavailable runtime is a build
/// choice, and the fix is a flag they can pass.
pub const unavailable_message =
    "this craft was built without the JavaScript runtime; rebuild with `zig build -Djs-runtime`";

/// A JavaScript evaluation context.
///
/// One context is one global object. Callers that need isolation between
/// scripts create one each; callers accumulating state across calls keep one.
pub const Runtime = struct {
    ctx: *backend.Context,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Error!Runtime {
        return .{ .ctx = try backend.Context.create(allocator), .allocator = allocator };
    }

    pub fn deinit(self: *Runtime) void {
        self.ctx.destroy();
    }

    /// Evaluate `source`, returning its result rendered as text.
    ///
    /// The result is allocated in `arena` and lives until the caller releases
    /// it. See the backend for why this is an arena and not a general
    /// allocator.
    pub fn evalToString(self: *Runtime, arena: std.mem.Allocator, source: []const u8) Error![]const u8 {
        return self.ctx.evalToString(arena, source);
    }
};

/// Evaluate one script and return its result — the whole lifecycle, for a
/// caller that has exactly one thing to run.
pub fn evalOnce(allocator: std.mem.Allocator, arena: std.mem.Allocator, source: []const u8) Error![]const u8 {
    var runtime = try Runtime.init(allocator);
    defer runtime.deinit();

    const result = try runtime.evalToString(arena, source);
    // Copied before the context dies. A string result can be backed by memory
    // the context owns rather than by the arena, so returning it directly left
    // the caller holding freed bytes — which showed up as a segfault while
    // *printing* the answer, several frames from the cause. Numbers survived,
    // because formatting them allocates fresh.
    return arena.dupe(u8, result) catch Error.OutOfMemory;
}

// -- tests -------------------------------------------------------------------
//
// These run in both configurations on purpose. Without the backend they pin
// that the absence is reported cleanly rather than crashing, which is the
// behaviour a default build actually ships.

const testing = std.testing;

test "availability is knowable at comptime" {
    // Callers branch on this to avoid setting up work they cannot do.
    try testing.expect(@TypeOf(available) == bool);
}

test "an unavailable runtime refuses rather than crashing" {
    if (available) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    try testing.expectError(
        Error.Unavailable,
        evalOnce(testing.allocator, arena.allocator(), "1 + 1"),
    );
}

test "evaluates arithmetic" {
    if (!available) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const result = try evalOnce(testing.allocator, arena.allocator(), "40 + 2");
    try testing.expectEqualStrings("42", result);
}

test "a string result outlives the context that produced it" {
    // The bug this pins: `evalOnce` destroys the context before returning, and
    // a string can be backed by context-owned memory. Numbers hid it — they
    // are formatted into the arena — so only a string result fails.
    if (!available) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const result = try evalOnce(testing.allocator, arena.allocator(), "['a','b','c'].join('-')");
    try testing.expectEqualStrings("a-b-c", result);
}

test "a context keeps state across evaluations" {
    // What separates a runtime from a calculator: a tray handler defined once
    // and called on each click.
    if (!available) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var runtime = try Runtime.init(testing.allocator);
    defer runtime.deinit();

    _ = try runtime.evalToString(arena.allocator(), "var clicks = 0; function onClick() { return ++clicks }");
    _ = try runtime.evalToString(arena.allocator(), "onClick()");
    const third = try runtime.evalToString(arena.allocator(), "onClick()");

    try testing.expectEqualStrings("2", third);
}

test "two runtimes do not share globals" {
    if (!available) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var first = try Runtime.init(testing.allocator);
    defer first.deinit();
    var second = try Runtime.init(testing.allocator);
    defer second.deinit();

    _ = try first.evalToString(arena.allocator(), "var secret = 'first'");
    const seen = try second.evalToString(arena.allocator(), "typeof secret");

    try testing.expectEqualStrings("undefined", seen);
}

test "a thrown error is reported as a throw, not a parse failure" {
    // The caller shows these differently: one is the script's logic, the other
    // is its syntax.
    if (!available) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    try testing.expectError(
        Error.Throw,
        evalOnce(testing.allocator, arena.allocator(), "throw new Error('nope')"),
    );
}

test "a syntax error is reported as a parse failure" {
    if (!available) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    try testing.expectError(
        Error.Parse,
        evalOnce(testing.allocator, arena.allocator(), "function ("),
    );
}

test "runs without any browser globals" {
    // The point of the runtime: no DOM, no window, nothing borrowed from a
    // webview. A script that assumes them should say so plainly.
    if (!available) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const kind = try evalOnce(testing.allocator, arena.allocator(), "typeof window");
    try testing.expectEqualStrings("undefined", kind);
}
