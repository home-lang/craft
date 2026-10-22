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

pub const Error = error{
    OutOfMemory,
    Unavailable,
    Throw,
    Parse,
    InvalidHandle,
    WrongContext,
    TypeMismatch,
    BufferSizeMismatch,
    BufferTooLarge,
    TooManyArguments,
    UnsupportedResult,
};

const max_buffer_bytes: usize = 64 * 1024 * 1024;
const max_call_arguments: usize = 64;

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

const PersistentKind = enum { function, uint8_buffer };

const PersistentHandle = struct {
    owner: ?*Context,
    root: ?*js.Context.ProtectedValue,
    allocator: std.mem.Allocator,
    kind: PersistentKind,

    fn dispose(self: *PersistentHandle) void {
        const allocator = self.allocator;
        if (self.owner) |owner| {
            if (self.root) |root| _ = owner.inner.unprotectValue(root);
            for (owner.handles.items, 0..) |candidate, index| {
                if (candidate == self) {
                    _ = owner.handles.swapRemove(index);
                    break;
                }
            }
        }
        self.owner = null;
        self.root = null;
        allocator.destroy(self);
    }
};

pub const Persistent = struct {
    handle: ?*PersistentHandle = null,

    pub fn deinit(self: *Persistent) void {
        const handle = self.handle orelse return;
        self.handle = null;
        handle.dispose();
    }
};

pub const Context = struct {
    inner: *js.Context,
    // Kept so `destroy` can free the wrapper it allocated. Without it the
    // wrapper leaked on every evaluation.
    allocator: std.mem.Allocator,
    handles: std.ArrayListUnmanaged(*PersistentHandle) = .empty,
    last_error: [256]u8 = undefined,
    last_error_len: usize = 0,

    pub fn create(allocator: std.mem.Allocator) Error!*Context {
        return createWithOptions(allocator, false);
    }

    pub fn createWithOptions(allocator: std.mem.Allocator, enable_gc: bool) Error!*Context {
        const inner = js.Context.createWith(allocator, .{ .enable_gc = enable_gc }) catch return Error.OutOfMemory;
        errdefer inner.destroy();

        const self = allocator.create(Context) catch return Error.OutOfMemory;
        self.* = .{ .inner = inner, .allocator = allocator };
        return self;
    }

    pub fn destroy(self: *Context) void {
        for (self.handles.items) |handle| {
            handle.owner = null;
            handle.root = null;
        }
        self.handles.deinit(self.allocator);
        const allocator = self.allocator;
        self.inner.destroy();
        allocator.destroy(self);
    }

    fn rememberError(self: *Context, message: []const u8) void {
        const count = @min(message.len, self.last_error.len);
        @memcpy(self.last_error[0..count], message[0..count]);
        self.last_error_len = count;
    }

    fn fail(self: *Context, comptime err: Error, message: []const u8) Error {
        self.rememberError(message);
        return err;
    }

    pub fn lastError(self: *const Context) []const u8 {
        return self.last_error[0..self.last_error_len];
    }

    /// Evaluate and render the result as text.
    ///
    /// `arena` rather than a general allocator: zig-js's `toString` allocates
    /// internally and the slice it returns is not a single freeable
    /// allocation, so freeing it individually aborts on invalid free.
    pub fn evalToString(self: *Context, arena: std.mem.Allocator, source: []const u8) Error![]const u8 {
        self.last_error_len = 0;
        const evaluated = self.inner.evaluate(source) catch |err| return switch (err) {
            error.OutOfMemory => self.fail(Error.OutOfMemory, "JavaScript runtime ran out of memory"),
            // A JS-level throw and a parse failure are different problems for
            // the caller: one is the script's logic, the other is its syntax.
            error.Throw => self.fail(Error.Throw, "JavaScript evaluation threw"),
            else => self.fail(Error.Parse, "JavaScript source failed to parse"),
        };
        return evaluated.toString(arena) catch self.fail(Error.OutOfMemory, "JavaScript result could not be rendered");
    }

    fn mapEvalError(self: *Context, err: anyerror) Error {
        return switch (err) {
            error.OutOfMemory => self.fail(Error.OutOfMemory, "JavaScript runtime ran out of memory"),
            error.Throw => self.fail(Error.Throw, "JavaScript callback threw"),
            else => self.fail(Error.Throw, "JavaScript callback failed"),
        };
    }

    fn retain(self: *Context, retained: js.Value, kind: PersistentKind) Error!Persistent {
        const root = self.inner.protectValue(retained) catch return self.fail(Error.OutOfMemory, "could not retain JavaScript value");
        errdefer _ = self.inner.unprotectValue(root);
        const handle = self.allocator.create(PersistentHandle) catch return self.fail(Error.OutOfMemory, "could not allocate persistent handle");
        errdefer self.allocator.destroy(handle);
        handle.* = .{ .owner = self, .root = root, .allocator = self.allocator, .kind = kind };
        self.handles.append(self.allocator, handle) catch return self.fail(Error.OutOfMemory, "could not register persistent handle");
        return .{ .handle = handle };
    }

    fn getValue(self: *Context, handle: *const Persistent, expected: PersistentKind) Error!js.Value {
        const record = handle.handle orelse return self.fail(Error.InvalidHandle, "persistent handle has been disposed");
        if (record.owner == null or record.root == null) return self.fail(Error.InvalidHandle, "persistent handle belongs to a disposed runtime");
        if (record.owner.? != self) return self.fail(Error.WrongContext, "persistent handle belongs to another runtime");
        if (record.kind != expected) return self.fail(Error.TypeMismatch, "persistent handle has the wrong type");
        return record.root.?.get();
    }

    pub fn persistFunction(self: *Context, source: []const u8) Error!Persistent {
        self.last_error_len = 0;
        const function = self.inner.evaluate(source) catch |err| return self.mapEvalError(err);
        if (!function.isCallable()) return self.fail(Error.TypeMismatch, "persistent source did not evaluate to a function");
        return self.retain(function, .function);
    }

    pub fn createUint8Buffer(self: *Context, bytes: []const u8) Error!Persistent {
        self.last_error_len = 0;
        if (bytes.len > max_buffer_bytes) return self.fail(Error.BufferTooLarge, "typed buffer exceeds the 64 MiB host limit");

        const gc_saved = js.gc.setActiveContext(self.inner);
        defer js.gc.restoreActiveContext(gc_saved);
        var machine = self.inner.interpreter();
        self.inner.pushActiveInterpreter(&machine) catch return self.fail(Error.OutOfMemory, "could not enter JavaScript runtime");
        defer self.inner.popActiveInterpreter(&machine);
        const created = machine.makeUninitializedTypedArray(.u8, bytes.len) catch |err| return self.mapEvalError(err);
        const typed = created.asObj().typedArray() orelse return self.fail(Error.TypeMismatch, "runtime did not create a Uint8Array");
        const backing = typed.buffer.arrayBuffer() orelse return self.fail(Error.TypeMismatch, "Uint8Array has no ArrayBuffer backing");
        @memcpy(backing.bytes()[typed.byte_offset..][0..bytes.len], bytes);
        return self.retain(created, .uint8_buffer);
    }

    pub fn readUint8Buffer(self: *Context, buffer: *const Persistent, arena: std.mem.Allocator) Error![]const u8 {
        const buffer_value = try self.getValue(buffer, .uint8_buffer);
        const typed = buffer_value.asObj().typedArray() orelse return self.fail(Error.TypeMismatch, "persistent value is not a typed buffer");
        const length = typed.currentLength() orelse return self.fail(Error.InvalidHandle, "typed buffer is detached or out of bounds");
        const bytes = typed.buffer.arrayBuffer().?.bytes();
        if (typed.byte_offset > bytes.len or length > bytes.len - typed.byte_offset)
            return self.fail(Error.InvalidHandle, "typed buffer range is invalid");
        return arena.dupe(u8, bytes[typed.byte_offset..][0..length]) catch self.fail(Error.OutOfMemory, "could not copy typed buffer");
    }

    pub fn writeUint8Buffer(self: *Context, buffer: *const Persistent, bytes: []const u8) Error!void {
        const buffer_value = try self.getValue(buffer, .uint8_buffer);
        const typed = buffer_value.asObj().typedArray() orelse return self.fail(Error.TypeMismatch, "persistent value is not a typed buffer");
        const length = typed.currentLength() orelse return self.fail(Error.InvalidHandle, "typed buffer is detached or out of bounds");
        if (bytes.len != length) return self.fail(Error.BufferSizeMismatch, "typed buffer writes must match the view length");
        const backing = typed.buffer.arrayBuffer().?;
        const destination = backing.bytes();
        if (typed.byte_offset > destination.len or length > destination.len - typed.byte_offset)
            return self.fail(Error.InvalidHandle, "typed buffer range is invalid");
        @memcpy(destination[typed.byte_offset..][0..length], bytes);
    }

    pub fn call(self: *Context, callback: *const Persistent, arena: std.mem.Allocator, args: []const Argument) Error!Result {
        self.last_error_len = 0;
        if (args.len > max_call_arguments) return self.fail(Error.TooManyArguments, "persistent calls accept at most 64 arguments");
        const function = try self.getValue(callback, .function);

        var values: std.ArrayListUnmanaged(js.Value) = .empty;
        try values.ensureTotalCapacity(self.inner.arena(), args.len);
        for (args) |arg| {
            const converted = switch (arg) {
                .number => |n| js.Value.num(n),
                .integer => |n| js.Value.num(@floatFromInt(n)),
                .boolean => |b| js.Value.boolVal(b),
                .text => |text| js.Value.strAlloc(self.inner.arena(), text) catch return self.fail(Error.OutOfMemory, "could not allocate callback text argument"),
                .buffer => |buffer| try self.getValue(buffer, .uint8_buffer),
            };
            values.appendAssumeCapacity(converted);
        }

        const gc_saved = js.gc.setActiveContext(self.inner);
        defer js.gc.restoreActiveContext(gc_saved);
        var machine = self.inner.interpreter();
        self.inner.pushActiveInterpreter(&machine) catch return self.fail(Error.OutOfMemory, "could not enter JavaScript runtime");
        defer self.inner.popActiveInterpreter(&machine);
        const result = machine.callValue(function, values.items) catch |err| return self.mapEvalError(err);
        return switch (result.kind()) {
            .undefined => .undefined,
            .null => .null,
            .boolean => .{ .boolean = result.asBool() },
            .number => .{ .number = result.asNum() },
            .string => .{ .text = arena.dupe(u8, result.asWtf8(arena) catch return self.fail(Error.OutOfMemory, "could not copy callback result")) catch return self.fail(Error.OutOfMemory, "could not copy callback result") },
            .object => self.fail(Error.UnsupportedResult, "persistent calls return only primitive values"),
        };
    }

    pub fn compact(self: *Context) void {
        if (!self.inner.requestGarbageCompaction()) return;
        _ = self.inner.compactGarbage();
    }
};
