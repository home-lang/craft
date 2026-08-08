//! The JS backend used when craft is built without zig-js.
//!
//! Craft's own JavaScript — anything that is not the page's — should not need
//! a browser engine. But the engine is a sibling checkout rather than a
//! fetchable package (see js_runtime.zig), so a default build has to compile
//! and run without it.
//!
//! This reports its absence instead of pretending. `available` is comptime, so
//! callers can refuse the work up front rather than discovering it at the point
//! of evaluation, and the CLI can print a fix rather than a stack trace.

const std = @import("std");

pub const available = false;

/// Matches the zig-js backend's error set, so `js_runtime` handles one shape.
pub const Error = error{ OutOfMemory, Unavailable, Throw, Parse };

pub const Context = struct {
    pub fn create(allocator: std.mem.Allocator) Error!*Context {
        _ = allocator;
        return Error.Unavailable;
    }

    pub fn destroy(self: *Context) void {
        _ = self;
    }

    pub fn evalToString(self: *Context, arena: std.mem.Allocator, source: []const u8) Error![]const u8 {
        _ = self;
        _ = arena;
        _ = source;
        return Error.Unavailable;
    }
};
