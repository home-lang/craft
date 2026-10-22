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

pub const Argument = union(enum) {
    number: f64,
    integer: i64,
    boolean: bool,
    text: []const u8,
    buffer: *const Persistent,
};

pub const Result = union(enum) {
    undefined,
    null,
    boolean: bool,
    number: f64,
    text: []const u8,
};

pub const Persistent = struct {
    pub fn deinit(self: *Persistent) void {
        self.* = .{};
    }
};

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

    pub fn persistFunction(self: *Context, source: []const u8) Error!Persistent {
        _ = self;
        _ = source;
        return Error.Unavailable;
    }

    pub fn createUint8Buffer(self: *Context, bytes: []const u8) Error!Persistent {
        _ = self;
        _ = bytes;
        return Error.Unavailable;
    }

    pub fn readUint8Buffer(self: *Context, buffer: *const Persistent, arena: std.mem.Allocator) Error![]const u8 {
        _ = self;
        _ = buffer;
        _ = arena;
        return Error.Unavailable;
    }

    pub fn writeUint8Buffer(self: *Context, buffer: *const Persistent, bytes: []const u8) Error!void {
        _ = self;
        _ = buffer;
        _ = bytes;
        return Error.Unavailable;
    }

    pub fn call(self: *Context, callback: *const Persistent, arena: std.mem.Allocator, args: []const Argument) Error!Result {
        _ = self;
        _ = callback;
        _ = arena;
        _ = args;
        return Error.Unavailable;
    }

    pub fn compact(self: *Context) void {
        _ = self;
    }

    pub fn lastError(self: *const Context) []const u8 {
        _ = self;
        return "JavaScript runtime unavailable";
    }
};
