//! The JS backend backed by zig-js.
//!
//! This is the point of the exercise: craft's own JavaScript runs on a
//! first-party engine rather than on whatever the platform ships. It is not a
//! replacement for the page's JavaScript — that executes inside WebKit's
//! WebContent process, which craft does not own — but everything else craft
//! wants to evaluate no longer needs a webview to do it.
//!
//! Concretely, a menubar-only app had no way to run JavaScript at all short of
//! creating a hidden WKWebView: a whole WebContent process, tens of megabytes
//! and a few hundred milliseconds, to call one function.

const std = @import("std");
const js = @import("js");

pub const available = true;

pub const Error = error{ OutOfMemory, Unavailable, Throw, Parse };

pub const Context = struct {
    inner: *js.Context,
    // Kept so `destroy` can free the wrapper it allocated. Without it the
    // wrapper leaked on every evaluation.
    allocator: std.mem.Allocator,

    pub fn create(allocator: std.mem.Allocator) Error!*Context {
        const inner = js.Context.create(allocator) catch return Error.OutOfMemory;
        errdefer inner.destroy();

        const self = allocator.create(Context) catch return Error.OutOfMemory;
        self.* = .{ .inner = inner, .allocator = allocator };
        return self;
    }

    pub fn destroy(self: *Context) void {
        const allocator = self.allocator;
        self.inner.destroy();
        allocator.destroy(self);
    }

    /// Evaluate and render the result as text.
    ///
    /// `arena` rather than a general allocator: zig-js's `toString` allocates
    /// internally and the slice it returns is not a single freeable
    /// allocation, so freeing it individually aborts on invalid free.
    pub fn evalToString(self: *Context, arena: std.mem.Allocator, source: []const u8) Error![]const u8 {
        const value = self.inner.evaluate(source) catch |err| return switch (err) {
            error.OutOfMemory => Error.OutOfMemory,
            // A JS-level throw and a parse failure are different problems for
            // the caller: one is the script's logic, the other is its syntax.
            error.Throw => Error.Throw,
            else => Error.Parse,
        };
        return value.toString(arena) catch Error.OutOfMemory;
    }
};
