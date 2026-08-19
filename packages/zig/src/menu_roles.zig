//! Standard menu behaviors, by name.
//!
//! A *role* is the portable name for a menu item that the operating system
//! already knows how to perform: "copy", "quit", "minimize". Items built from a
//! role get the matching AppKit selector and a **nil target**, so AppKit walks
//! the responder chain to find something that implements it.
//!
//! That indirection is the whole point for the clipboard items. `cut:`,
//! `copy:` and `paste:` have to land on whatever is focused — the field editor
//! inside a text field, or the WKWebView itself — and neither is reachable from
//! a handler of ours. A menu item that posts an event to the page instead can
//! only ever paste into a page that implemented pasting, which is not what a
//! user pressing Cmd+V is asking for.
//!
//! Two callers share this table:
//!
//!  - `bridge_menu.zig`, for `role` on items an app declares through
//!    `craft.menu.set()`.
//!  - `macos.zig`, for the default menu bar an app gets when it declares
//!    nothing at all.
//!
//! Keeping it here rather than in either of them means the default bar and the
//! bridge can't disagree about what "copy" means, and the table can be tested
//! without an NSApplication.

const std = @import("std");

/// Every role, with the AppKit selector it performs.
///
/// The receiver is left to the responder chain, so the selectors span several
/// classes: NSApplication (`terminate:`, `hide:`), NSWindow (`performClose:`,
/// `performMiniaturize:`), NSResponder / the field editor (`cut:`, `undo:`),
/// and WKWebView (`reload:`, `reloadFromOrigin:`).
pub const table = [_]struct { name: []const u8, selector: [*:0]const u8 }{
    .{ .name = "about", .selector = "orderFrontStandardAboutPanel:" },
    .{ .name = "hide", .selector = "hide:" },
    .{ .name = "hideOthers", .selector = "hideOtherApplications:" },
    .{ .name = "showAll", .selector = "unhideAllApplications:" },
    .{ .name = "quit", .selector = "terminate:" },
    .{ .name = "undo", .selector = "undo:" },
    .{ .name = "redo", .selector = "redo:" },
    .{ .name = "cut", .selector = "cut:" },
    .{ .name = "copy", .selector = "copy:" },
    .{ .name = "paste", .selector = "paste:" },
    .{ .name = "delete", .selector = "delete:" },
    .{ .name = "selectAll", .selector = "selectAll:" },
    .{ .name = "close", .selector = "performClose:" },
    .{ .name = "minimize", .selector = "performMiniaturize:" },
    .{ .name = "zoom", .selector = "performZoom:" },
    .{ .name = "front", .selector = "arrangeInFront:" },
    .{ .name = "fullscreen", .selector = "toggleFullScreen:" },
    .{ .name = "reload", .selector = "reload:" },
    .{ .name = "forceReload", .selector = "reloadFromOrigin:" },
};

/// The selector for `role`, or null if the role is not one we know.
///
/// Case-insensitive, because the role arrives as JSON written by hand and
/// "selectAll" / "selectall" are the same intent. Usable at comptime, which is
/// how `macos.zig` proves its default menu bar only names roles that exist.
pub fn selectorFor(role: []const u8) ?[*:0]const u8 {
    for (table) |entry| {
        if (std.ascii.eqlIgnoreCase(role, entry.name)) return entry.selector;
    }
    return null;
}

test "roles resolve regardless of how they were cased" {
    try std.testing.expectEqualStrings("copy:", std.mem.span(selectorFor("copy").?));
    try std.testing.expectEqualStrings("selectAll:", std.mem.span(selectorFor("selectall").?));
    try std.testing.expectEqualStrings("terminate:", std.mem.span(selectorFor("QUIT").?));
}

test "an unknown role resolves to nothing rather than to something wrong" {
    // The bridge relies on this: an unrecognized role falls back to an id item
    // that forwards to the page, so a newer JS surface degrades to an event
    // rather than to a dead menu item.
    try std.testing.expect(selectorFor("") == null);
    try std.testing.expect(selectorFor("paste-and-match-style") == null);
    // A prefix must not match — "cut" is a role, "cutlery" is not.
    try std.testing.expect(selectorFor("cutlery") == null);
}

test "every selector is a one-argument action selector" {
    // AppKit action selectors take the sender, so each must end in exactly one
    // colon. A selector missing it is dispatched with the wrong signature and
    // the item is auto-disabled — the failure mode #29 was.
    for (table) |entry| {
        const selector = std.mem.span(entry.selector);
        try std.testing.expect(selector.len > 1);
        try std.testing.expectEqual(@as(u8, ':'), selector[selector.len - 1]);
        try std.testing.expectEqual(@as(?usize, selector.len - 1), std.mem.indexOfScalar(u8, selector, ':'));
    }
}

test "role names are unique" {
    // A duplicate would silently shadow, and the second spelling would never
    // be reachable.
    for (table, 0..) |a, i| {
        for (table[i + 1 ..]) |b| {
            try std.testing.expect(!std.ascii.eqlIgnoreCase(a.name, b.name));
        }
    }
}
