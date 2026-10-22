//! Disabled native hosting always reports Unavailable.
const std = @import("std");
const types = @import("js_host_types.zig");
pub const Error = types.Error;
pub const Handle = types.Handle;
pub const Options = types.Options;
pub const Value = types.Value;
pub const Kind = types.Kind;
pub const TypedArrayKind = types.TypedArrayKind;

pub const PersistentRuntime = struct {
    pub fn init(allocator: std.mem.Allocator, options: Options) Error!PersistentRuntime {
        _ = allocator;
        _ = options;
        return error.Unavailable;
    }
    pub fn deinit(self: *PersistentRuntime) Error!void {
        _ = self;
        return error.Unavailable;
    }
    pub fn evaluate(self: *PersistentRuntime, source: []const u8) Error!Handle {
        _ = self;
        _ = source;
        return error.Unavailable;
    }
    pub fn create(self: *PersistentRuntime, input: Value) Error!Handle {
        _ = self;
        _ = input;
        return error.Unavailable;
    }
    pub fn call(self: *PersistentRuntime, function: Handle, receiver: ?Handle, arguments: []const Handle) Error!Handle {
        _ = self;
        _ = function;
        _ = receiver;
        _ = arguments;
        return error.Unavailable;
    }
    pub fn release(self: *PersistentRuntime, handle: Handle) Error!void {
        _ = self;
        _ = handle;
        return error.Unavailable;
    }
    pub fn kind(self: *PersistentRuntime, handle: Handle) Error!Kind {
        _ = self;
        _ = handle;
        return error.Unavailable;
    }
    pub fn number(self: *PersistentRuntime, handle: Handle) Error!f64 {
        _ = self;
        _ = handle;
        return error.Unavailable;
    }
    pub fn boolean(self: *PersistentRuntime, handle: Handle) Error!bool {
        _ = self;
        _ = handle;
        return error.Unavailable;
    }
    pub fn copyString(self: *PersistentRuntime, handle: Handle, allocator: std.mem.Allocator) Error![]u8 {
        _ = self;
        _ = handle;
        _ = allocator;
        return error.Unavailable;
    }
    pub fn exception(self: *PersistentRuntime) Error!?Handle {
        _ = self;
        return error.Unavailable;
    }
    pub fn copyBuffer(self: *PersistentRuntime, handle: Handle, offset: usize, destination: []u8) Error!void {
        _ = self;
        _ = handle;
        _ = offset;
        _ = destination;
        return error.Unavailable;
    }
    pub fn writeBuffer(self: *PersistentRuntime, handle: Handle, offset: usize, source: []const u8) Error!void {
        _ = self;
        _ = handle;
        _ = offset;
        _ = source;
        return error.Unavailable;
    }
    pub fn collect(self: *PersistentRuntime) Error!void {
        _ = self;
        return error.Unavailable;
    }
    pub fn interrupt(self: *PersistentRuntime) Error!void {
        _ = self;
        return error.Unavailable;
    }
};
