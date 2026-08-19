//! craft's injected JavaScript, tested without a window.
//!
//! Six JS files are spliced into every webview craft opens, and until now none
//! of them had a test. The only way to exercise `window.craft.gestures` was to
//! launch an app and swipe a trackpad — so a regression there is found by a
//! person noticing the feel is wrong, which is not a test strategy.
//!
//! zig-js runs them headlessly: no WebKit, no window, no WebContent process,
//! and deterministic. These are the same bytes `@embedFile`d into the binary,
//! not a copy that can drift.
//!
//! Opt-in (`zig build test -Djs-tests`) because it needs the sibling checkout
//! at `~/Code/Libraries/zig-js`, which a consumer installing craft from npm
//! will not have. The rest of the suite must keep working without it.

const std = @import("std");
const js = @import("js");
const testing = std.testing;
const bridge_menu = @import("../src/bridge_menu.zig");

// Supplied by build.zig as named imports — a test module cannot embed
// files outside its own package path.
const GESTURES = @embedFile("craft-gestures.js");
const BRIDGE = @embedFile("craft-bridge.js");

/// A context with the globals a browser would supply.
///
/// Deliberately minimal: whatever these scripts need beyond it is a dependency
/// on the DOM, and finding that out is half the value of running them here.
fn browserContext(allocator: std.mem.Allocator) !*js.Context {
    const ctx = try js.Context.create(allocator);
    errdefer ctx.destroy();
    _ = try ctx.evaluate(
        \\var window = {};
        \\var globalThis = globalThis || window;
    );
    return ctx;
}

/// Evaluate and read the result as text.
///
/// `Value.toString` takes an **arena** — it allocates internally and the slice
/// it hands back is not a single freeable allocation, so passing the testing
/// allocator and freeing the result aborts on "free of invalid memory". The
/// arena is owned by the caller and released whole.
fn stringOf(arena: std.mem.Allocator, ctx: *js.Context, source: []const u8) ![]const u8 {
    const value = try ctx.evaluate(source);
    return try value.toString(arena);
}

/// A context plus the arena its string conversions allocate from.
const Fixture = struct {
    arena: std.heap.ArenaAllocator,
    ctx: *js.Context,

    fn init() !Fixture {
        var arena = std.heap.ArenaAllocator.init(testing.allocator);
        errdefer arena.deinit();
        const ctx = try browserContext(testing.allocator);
        return .{ .arena = arena, .ctx = ctx };
    }

    fn deinit(self: *Fixture) void {
        self.ctx.destroy();
        self.arena.deinit();
    }

    fn text(self: *Fixture, source: []const u8) ![]const u8 {
        return stringOf(self.arena.allocator(), self.ctx, source);
    }
};

test "the gesture registry installs even when no host ever emits" {
    // This is what makes unconditional injection safe: callers feature-detect
    // `onSwipe` once and keep their wheel fallback. If it were absent on a
    // host without gesture support, every caller would need two code paths.
    var fx = try Fixture.init();
    defer fx.deinit();
    const ctx = fx.ctx;

    _ = try ctx.evaluate(GESTURES);

    const kind = try fx.text("typeof window.craft.gestures.onSwipe");
    try testing.expectEqualStrings("function", kind);
}

test "a subscriber receives phases in order, with their deltas" {
    var fx = try Fixture.init();
    defer fx.deinit();
    const ctx = fx.ctx;

    _ = try ctx.evaluate(GESTURES);
    _ = try ctx.evaluate(
        \\var seen = [];
        \\window.craft.gestures.onSwipe(function (s) { seen.push(s.phase + ':' + s.deltaX) });
        \\window.craft.gestures._emit({ axis: 'horizontal', phase: 'begin',  deltaX: 4, deltaY: 0 });
        \\window.craft.gestures._emit({ axis: 'horizontal', phase: 'change', deltaX: 9, deltaY: 0 });
        \\window.craft.gestures._emit({ axis: 'horizontal', phase: 'end',    deltaX: 0, deltaY: 0 });
    );

    const seen = try fx.text("seen.join('|')");
    try testing.expectEqualStrings("begin:4|change:9|end:0", seen);
}

test "unsubscribing stops delivery" {
    // A leak here costs one listener per mount and only shows up after
    // navigating a few times, by which point the cause is hard to see.
    var fx = try Fixture.init();
    defer fx.deinit();
    const ctx = fx.ctx;

    _ = try ctx.evaluate(GESTURES);
    _ = try ctx.evaluate(
        \\var count = 0;
        \\var off = window.craft.gestures.onSwipe(function () { count++ });
        \\window.craft.gestures._emit({ axis: 'horizontal', phase: 'begin', deltaX: 1, deltaY: 0 });
        \\off();
        \\window.craft.gestures._emit({ axis: 'horizontal', phase: 'change', deltaX: 1, deltaY: 0 });
        \\window.craft.gestures._emit({ axis: 'horizontal', phase: 'end', deltaX: 0, deltaY: 0 });
    );

    const count = try fx.text("String(count)");
    try testing.expectEqualStrings("1", count);
}

test "a non-function subscriber is ignored rather than breaking the next emit" {
    // `onSwipe` must always return something callable: callers store the result
    // and invoke it on teardown without checking.
    var fx = try Fixture.init();
    defer fx.deinit();
    const ctx = fx.ctx;

    _ = try ctx.evaluate(GESTURES);
    _ = try ctx.evaluate(
        \\var offBad = window.craft.gestures.onSwipe(null);
        \\var reached = 0;
        \\window.craft.gestures.onSwipe(function () { reached++ });
        \\offBad();
        \\window.craft.gestures._emit({ axis: 'horizontal', phase: 'begin', deltaX: 1, deltaY: 0 });
    );

    const kind = try fx.text("typeof offBad");
    try testing.expectEqualStrings("function", kind);

    const reached = try fx.text("String(reached)");
    try testing.expectEqualStrings("1", reached);
}

test "installing twice keeps the first registry and its subscribers" {
    // The script is injected as a document-start user script, and a page that
    // navigates within the same webview can run it again. Replacing the
    // registry would silently drop everyone who had already subscribed.
    var fx = try Fixture.init();
    defer fx.deinit();
    const ctx = fx.ctx;

    _ = try ctx.evaluate(GESTURES);
    _ = try ctx.evaluate(
        \\var hits = 0;
        \\window.craft.gestures.onSwipe(function () { hits++ });
    );
    _ = try ctx.evaluate(GESTURES);
    _ = try ctx.evaluate("window.craft.gestures._emit({ axis: 'horizontal', phase: 'begin', deltaX: 1, deltaY: 0 });");

    const hits = try fx.text("String(hits)");
    try testing.expectEqualStrings("1", hits);
}

test "the bridge script parses" {
    // Not a behaviour test — the bridge needs `webkit.messageHandlers`, which
    // only a real webview has. But a syntax error in an injected script fails
    // silently in a webview: the page loads, the bridge is simply absent, and
    // every craft.* call rejects with no clue why. Parsing it here turns that
    // into a build failure.
    var fx = try Fixture.init();
    defer fx.deinit();
    const ctx = fx.ctx;

    _ = ctx.evaluate(BRIDGE) catch |err| switch (err) {
        // A JS-level throw is expected and fine: it means the source parsed and
        // execution got far enough to miss a browser API. A parse error is not,
        // and that is the failure this test exists to catch.
        error.Throw => return,
        else => return err,
    };
}

/// The slice of a webview the bridge script touches while it loads, plus a
/// recorder in place of `webkit.messageHandlers.craft`.
///
/// Everything native would do with a posted message begins with these bytes,
/// so capturing them is capturing the whole JS half of the contract.
const WEBVIEW_HOST =
    \\var posted = [];
    \\window.webkit = { messageHandlers: { craft: { postMessage: function (m) { posted.push(m) } } } };
    \\window.addEventListener = function () {};
    \\window.removeEventListener = function () {};
    \\window.dispatchEvent = function () { return true };
    \\function CustomEvent(type, init) { this.type = type; this.detail = init && init.detail }
    \\var document = { readyState: 'complete', addEventListener: function () {} };
;

test "craft.menu.set posts what bridge_menu.zig's parser reads" {
    // The one path that matters, end to end and without a window: the real
    // injected script builds the message, and the real native parser decodes
    // it. Both halves of the #27 contract mismatch were individually
    // "covered" — bridge.test.ts hand-built its bridge messages and the zig
    // menu tests asserted against a struct nothing rendered — so six menu
    // methods could no-op with a green suite. Only a test that carries one
    // payload across the boundary can catch that.
    var fx = try Fixture.init();
    defer fx.deinit();
    const ctx = fx.ctx;

    _ = try ctx.evaluate(WEBVIEW_HOST);
    _ = try ctx.evaluate(BRIDGE);
    _ = try ctx.evaluate(
        \\window.craft.menu.set({ menus: [
        \\  { label: 'Edit', items: [
        \\    { role: 'copy', label: 'Copy', shortcut: 'cmd+c' },
        \\    { separator: true },
        \\    { id: 'find', label: 'Find in Page', shortcut: 'cmd+f', icon: 'search' },
        \\  ] },
        \\] });
    );

    try testing.expectEqualStrings("1", try fx.text("String(posted.length)"));

    // `t` picks the bridge, `a` picks the branch inside it. A wrong `a` is not
    // an error on the native side, only a log line — hence the shared constant.
    try testing.expectEqualStrings("menu", try fx.text("posted[0].t"));
    try testing.expectEqualStrings(bridge_menu.action_set_app_menu, try fx.text("posted[0].a"));

    const payload = try fx.text("posted[0].d");
    const parsed = try bridge_menu.parseAppMenu(testing.allocator, payload);
    defer parsed.deinit();

    const menus = parsed.value.menus orelse return error.NoMenusParsed;
    try testing.expectEqual(@as(usize, 1), menus.len);
    try testing.expectEqualStrings("Edit", menus[0].label.?);

    const items = menus[0].items orelse return error.NoItemsParsed;
    try testing.expectEqual(@as(usize, 3), items.len);

    // A role item: native wires it to an AppKit selector with a nil target, so
    // the responder chain performs it. The id is absent and must stay optional.
    try testing.expectEqualStrings("copy", items[0].role.?);
    try testing.expectEqualStrings("Copy", items[0].label.?);
    try testing.expectEqualStrings("cmd+c", items[0].shortcut.?);
    try testing.expect(items[0].id == null);

    try testing.expect(items[1].separator.?);

    // An id item: native routes clicks back to the page as `craft:menu:action`.
    try testing.expectEqualStrings("find", items[2].id.?);
    try testing.expectEqualStrings("Find in Page", items[2].label.?);
    try testing.expectEqualStrings("cmd+f", items[2].shortcut.?);
    try testing.expectEqualStrings("search", items[2].icon.?);
    try testing.expect(items[2].role == null);
}

test "an empty menu bar is a parse, not a failure" {
    // `craft.menu.set()` with no argument sends `{}`. Clearing the bar is a
    // legitimate thing to ask for, and it must not come back as InvalidJSON —
    // which would reject the call and leave the previous bar in place.
    var fx = try Fixture.init();
    defer fx.deinit();
    const ctx = fx.ctx;

    _ = try ctx.evaluate(WEBVIEW_HOST);
    _ = try ctx.evaluate(BRIDGE);
    _ = try ctx.evaluate("window.craft.menu.set();");

    const payload = try fx.text("posted[0].d");
    const parsed = try bridge_menu.parseAppMenu(testing.allocator, payload);
    defer parsed.deinit();

    try testing.expect(parsed.value.menus == null);
}
