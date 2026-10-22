//! Persistent, single-owner native JavaScript hosting. No WebView is involved.
const std = @import("std");
const js = @import("js");
const types = @import("js_host_types.zig");
pub const Error = types.Error;
pub const Handle = types.Handle;
pub const Options = types.Options;
pub const Value = types.Value;
pub const Kind = types.Kind;
pub const TypedArrayKind = types.TypedArrayKind;

// Runtime identity is process-wide, atomic and saturating. Address reuse after
// disposal can never turn a foreign numeric handle into a valid local handle.
var identity: std.atomic.Value(u64) = .init(1);
fn nextIdentity() Error!u64 {
    var current = identity.load(.monotonic);
    while (current != std.math.maxInt(u64)) {
        if (identity.cmpxchgWeak(current, current + 1, .monotonic, .monotonic)) |observed| {
            current = observed;
        } else return current;
    }
    return error.LimitExceeded;
}

fn translate(err: anyerror) Error {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.Throw => error.Throw,
        error.WrongThread => error.WrongThread,
        error.UnsupportedHostMode => error.UnsupportedHostMode,
        error.InvalidHandle => error.InvalidHandle,
        error.InvalidString => error.InvalidString,
        error.InvalidBuffer => error.InvalidBuffer,
        error.OutOfBounds => error.OutOfBounds,
        error.Terminated => error.Terminated,
        error.OptShortCircuit => error.Engine,
        else => error.Parse,
    };
}

pub const PersistentRuntime = struct {
    const Slot = struct { value: ?*js.Context.ProtectedValue = null, generation: u64 = 1 };
    context: ?*js.Context,
    allocator: std.mem.Allocator,
    slots: []Slot,
    options: Options,
    runtime_id: u64,
    owner: std.Thread.Id,

    pub fn init(allocator: std.mem.Allocator, options: Options) Error!PersistentRuntime {
        if (options.max_handles == 0 or options.max_handles > 65536 or options.max_arguments > 4096 or options.heap_limit_bytes == 0)
            return error.LimitExceeded;
        const runtime_id = try nextIdentity();
        const slots = allocator.alloc(Slot, options.max_handles) catch return error.OutOfMemory;
        errdefer allocator.free(slots);
        @memset(slots, .{});
        const context = js.Context.createWith(allocator, .{
            .enable_gc = true,
            .heap_limit_bytes = options.heap_limit_bytes,
        }) catch return error.OutOfMemory;
        return .{ .context = context, .allocator = allocator, .slots = slots, .options = options, .runtime_id = runtime_id, .owner = std.Thread.getCurrentId() };
    }

    fn live(self: *PersistentRuntime) Error!*js.Context {
        if (std.Thread.getCurrentId() != self.owner) return error.WrongThread;
        return self.context orelse error.Closed;
    }

    fn slot(self: *PersistentRuntime, handle: Handle) Error!*Slot {
        _ = try self.live();
        if (handle.runtime != self.runtime_id or handle.slot >= self.slots.len) return error.InvalidHandle;
        const entry = &self.slots[handle.slot];
        if (entry.value == null or entry.generation != handle.generation) return error.InvalidHandle;
        return entry;
    }

    fn vacancy(self: *PersistentRuntime) Error!usize {
        _ = try self.live();
        for (self.slots, 0..) |entry, index| {
            if (entry.value == null and entry.generation != std.math.maxInt(u64)) return index;
        }
        return error.LimitExceeded;
    }

    fn adopt(self: *PersistentRuntime, index: usize, protected: *js.Context.ProtectedValue) Handle {
        self.slots[index].value = protected;
        return .{ .runtime = self.runtime_id, .slot = @intCast(index), .generation = self.slots[index].generation };
    }

    /// Idempotent on the owner thread. Join any interrupting watchdog before
    /// disposal; no runtime operation may overlap disposal or another entry.
    pub fn deinit(self: *PersistentRuntime) Error!void {
        if (std.Thread.getCurrentId() != self.owner) return error.WrongThread;
        if (self.context) |context| {
            context.destroy();
            self.context = null;
            self.allocator.free(self.slots);
            self.slots = &.{};
        }
    }

    pub fn evaluate(self: *PersistentRuntime, source: []const u8) Error!Handle {
        const context = try self.live();
        if (source.len > self.options.max_input_bytes) return error.LimitExceeded;
        const index = try self.vacancy();
        return self.adopt(index, context.evaluateProtected(source) catch |err| return translate(err));
    }

    pub fn create(self: *PersistentRuntime, input: Value) Error!Handle {
        const context = try self.live();
        const index = try self.vacancy();
        const value: js.Context.HostValue = switch (input) {
            .undefined => .undefined,
            .null => .null,
            .boolean => |input_boolean| .{ .boolean = input_boolean },
            .number => |input_number| .{ .number = input_number },
            .string => |string| string: {
                if (string.len > self.options.max_input_bytes) return error.LimitExceeded;
                break :string .{ .string = string };
            },
            .typed_array => |array| array: {
                if (array.bytes.len > self.options.max_input_bytes) return error.LimitExceeded;
                break :array .{ .typed_array = .{ .kind = switch (array.kind) {
                    .u8_clamped => .u8c,
                    .bigint64 => .i64,
                    .biguint64 => .u64,
                    inline else => |array_kind| @field(@TypeOf(@as(js.Context.HostValue, .{ .typed_array = undefined }).typed_array.kind), @tagName(array_kind)),
                }, .bytes = array.bytes } };
            },
        };
        return self.adopt(index, context.createHostValue(value) catch |err| return translate(err));
    }

    pub fn call(self: *PersistentRuntime, function: Handle, receiver: ?Handle, arguments: []const Handle) Error!Handle {
        const context = try self.live();
        if (arguments.len > self.options.max_arguments) return error.LimitExceeded;
        const index = try self.vacancy();
        const callback = (try self.slot(function)).value.?;
        const this = if (receiver) |handle| (try self.slot(handle)).value.? else null;
        const retained = self.allocator.alloc(*js.Context.ProtectedValue, arguments.len) catch return error.OutOfMemory;
        defer self.allocator.free(retained);
        for (arguments, retained) |handle, *argument| argument.* = (try self.slot(handle)).value.?;
        return self.adopt(index, context.callProtected(callback, this, retained) catch |err| return translate(err));
    }

    pub fn release(self: *PersistentRuntime, handle: Handle) Error!void {
        const context = try self.live();
        const entry = try self.slot(handle);
        if (!context.unprotectValue(entry.value.?)) return error.Engine;
        entry.value = null;
        entry.generation += 1;
    }

    pub fn kind(self: *PersistentRuntime, handle: Handle) Error!Kind {
        return switch ((try self.slot(handle)).value.?.get().kind()) {
            inline else => |tag| @field(Kind, @tagName(tag)),
        };
    }

    pub fn number(self: *PersistentRuntime, handle: Handle) Error!f64 {
        const value = (try self.slot(handle)).value.?.get();
        if (!value.isNumber()) return error.WrongType;
        return value.asNum();
    }

    pub fn boolean(self: *PersistentRuntime, handle: Handle) Error!bool {
        const value = (try self.slot(handle)).value.?.get();
        if (!value.isBoolean()) return error.WrongType;
        return value.asBool();
    }

    /// An owned WTF-8 string snapshot. Free it using the supplied allocator.
    /// Encoding length is checked before allocating, including flat Latin-1.
    pub fn copyString(self: *PersistentRuntime, handle: Handle, allocator: std.mem.Allocator) Error![]u8 {
        const value = (try self.slot(handle)).value.?.get();
        if (!value.isString()) return error.WrongType;
        var length = value.asStr().len;
        if (value.strIsFlatLatin1()) {
            for (value.asStr()) |byte| {
                if (byte >= 128) length = std.math.add(usize, length, 1) catch return error.LimitExceeded;
            }
        }
        if (length > self.options.max_output_bytes) return error.LimitExceeded;
        return value.asWtf8Owned(allocator) catch error.OutOfMemory;
    }

    /// Retain the last engine-thrown value without coercing it or running a
    /// user-defined toString. Returns null when the last engine entry did not throw.
    pub fn exception(self: *PersistentRuntime) Error!?Handle {
        const context = try self.live();
        const value = context.exception orelse return null;
        const index = try self.vacancy();
        return self.adopt(index, context.protectValue(value) catch return error.OutOfMemory);
    }

    pub fn copyBuffer(self: *PersistentRuntime, handle: Handle, offset: usize, destination: []u8) Error!void {
        const context = try self.live();
        if (destination.len > self.options.max_output_bytes) return error.LimitExceeded;
        context.copyTypedArrayBytes((try self.slot(handle)).value.?, offset, destination) catch |err| return translate(err);
    }

    pub fn writeBuffer(self: *PersistentRuntime, handle: Handle, offset: usize, source: []const u8) Error!void {
        const context = try self.live();
        if (source.len > self.options.max_input_bytes) return error.LimitExceeded;
        context.writeTypedArrayBytes((try self.slot(handle)).value.?, offset, source) catch |err| return translate(err);
    }

    pub fn collect(self: *PersistentRuntime) Error!void {
        const context = try self.live();
        context.collectGarbage();
    }

    /// Thread-safe only while this runtime stays alive. The owner must join the
    /// watchdog before deinit. Interruption is terminal for the engine context.
    pub fn interrupt(self: *PersistentRuntime) Error!void {
        const context = self.context orelse return error.Closed;
        context.requestTermination();
    }
};
