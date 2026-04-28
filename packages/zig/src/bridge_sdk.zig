//! SDK Envelope Adapter
//!
//! The TypeScript SDK (`@craft-native/craft`'s `bridge/core.ts`) speaks a
//! richer protocol than the low-level `bridge.zig` `Bridge`:
//!
//!   request : `{id: string, type: "request", method: string, params?: any}`
//!   response: `{id: string, type: "response", result?: any, error?: { code, message }}`
//!   stream  : `{id, type: "stream", streamId, streamEvent: "data"|"end"|"error", result?, error?}`
//!
//! The low-level `Bridge.handleMessage(name, body)` only takes a method name
//! and a JSON body and returns a JSON body. This module wraps that core so a
//! WebKit / WebView2 message can be parsed, dispatched, and re-wrapped into
//! the response envelope the SDK expects.
//!
//! Without this layer the SDK's `bridge.handshake()` (and any other
//! request) sits in `pendingRequests` until it times out, because the JS
//! side keys responses by `id` and the Zig side never speaks `id` back.

const std = @import("std");
const bridge_mod = @import("bridge.zig");

const Bridge = bridge_mod.Bridge;

pub const SDK_PROTOCOL_VERSION: u32 = bridge_mod.BRIDGE_PROTOCOL_VERSION;

/// Errors specific to envelope parsing. Anything here should be reported back
/// over the bridge as `{type: "response", error: { code, message }}`.
pub const EnvelopeError = error{
    InvalidJson,
    MissingId,
    MissingType,
    UnknownType,
    MissingMethod,
};

/// Bridge error codes mirrored from the SDK's `BridgeErrorCodes`. The SDK
/// looks at the numeric code on errors so any reply built here MUST use one
/// of these values.
pub const ErrorCode = enum(i32) {
    unknown = -1,
    timeout = -2,
    queue_full = -3,
    binary_disabled = -4,
    expected_binary = -5,
    bridge_destroyed = -6,
    busy = -7,
    protocol_mismatch = -8,
};

/// Parse a request envelope and dispatch through the low-level bridge,
/// producing a response envelope as a newly-allocated JSON string. The
/// caller owns the returned slice.
///
/// On dispatch errors (handler not found, handler returned an error,
/// envelope malformed) the response envelope contains an `error` field
/// instead of `result` — the function itself only returns an error for
/// allocation failures.
pub fn handleEnvelope(
    bridge: *Bridge,
    allocator: std.mem.Allocator,
    request: []const u8,
) ![]u8 {
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, request, .{}) catch {
        return try writeError(allocator, "unknown", .invalid_json_id_unavailable, "request envelope is not valid JSON");
    };
    defer parsed.deinit();

    const root = parsed.value;
    if (root != .object) {
        return try writeError(allocator, "unknown", .invalid_json_id_unavailable, "request envelope must be a JSON object");
    }

    const id = idFromObject(root.object) orelse {
        return try writeError(allocator, "unknown", .invalid_json_id_unavailable, "request envelope is missing `id`");
    };

    const method_value = root.object.get("method") orelse {
        return try writeError(allocator, id, .missing_method, "request envelope is missing `method`");
    };
    if (method_value != .string) {
        return try writeError(allocator, id, .missing_method, "request envelope `method` must be a string");
    }
    const method = method_value.string;

    // Re-serialize `params` (or {} if absent) as the body the low-level
    // handler expects. Most handlers parse JSON themselves; passing them an
    // object is more predictable than a raw substring of the original.
    const params_body = blk: {
        const raw = root.object.get("params") orelse break :blk try allocator.dupe(u8, "{}");
        var buf: std.ArrayList(u8) = .{};
        defer buf.deinit(allocator);
        try std.json.stringify(raw, .{}, buf.writer(allocator));
        break :blk try buf.toOwnedSlice(allocator);
    };
    defer allocator.free(params_body);

    const body = bridge.handleMessage(method, params_body) catch |err| {
        const message = switch (err) {
            error.HandlerNotFound => "handler not found",
            else => @errorName(err),
        };
        return try writeError(allocator, id, .handler_failed, message);
    };

    return try writeOk(allocator, id, body);
}

const InternalError = enum {
    invalid_json_id_unavailable,
    missing_method,
    handler_failed,

    fn code(self: InternalError) i32 {
        return switch (self) {
            .invalid_json_id_unavailable, .missing_method => @intFromEnum(ErrorCode.protocol_mismatch),
            .handler_failed => @intFromEnum(ErrorCode.unknown),
        };
    }
};

fn idFromObject(obj: std.json.ObjectMap) ?[]const u8 {
    const v = obj.get("id") orelse return null;
    if (v != .string) return null;
    return v.string;
}

/// Append a slice as a JSON string literal (with surrounding quotes and full
/// escaping) to `writer`. Required because `std.fmt.allocPrint("{s}", .{s})`
/// does NOT escape JSON specials, and an `id` containing a quote or
/// backslash would otherwise produce malformed output that breaks every
/// subsequent message on the bridge.
fn writeJsonString(writer: anytype, s: []const u8) !void {
    try writer.writeByte('"');
    for (s) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            0x08 => try writer.writeAll("\\b"),
            0x0c => try writer.writeAll("\\f"),
            else => {
                if (c < 0x20) {
                    // \u00XX for other control chars
                    try writer.print("\\u{x:0>4}", .{c});
                } else {
                    try writer.writeByte(c);
                }
            },
        }
    }
    try writer.writeByte('"');
}

fn writeOk(allocator: std.mem.Allocator, id: []const u8, body: []const u8) ![]u8 {
    // The low-level handler returns either a JSON value as text or a static
    // string like "OK". We embed it verbatim; if it isn't valid JSON the
    // SDK will surface a parse error which is louder than the silence we
    // have today.
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);
    try w.writeAll("{\"id\":");
    try writeJsonString(w, id);
    try w.writeAll(",\"type\":\"response\",\"result\":");
    try w.writeAll(body);
    try w.writeByte('}');
    return try buf.toOwnedSlice(allocator);
}

fn writeError(
    allocator: std.mem.Allocator,
    id: []const u8,
    err: InternalError,
    message: []const u8,
) ![]u8 {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(allocator);
    const w = buf.writer(allocator);
    try w.writeAll("{\"id\":");
    try writeJsonString(w, id);
    try w.print(",\"type\":\"response\",\"error\":{{\"code\":{d},\"message\":", .{err.code()});
    try writeJsonString(w, message);
    try w.writeAll("}}");
    return try buf.toOwnedSlice(allocator);
}

// ---------------------------------------------------------------------------
// Tests

const testing = std.testing;

fn makeBridge() Bridge {
    return Bridge.init(testing.allocator);
}

fn dummyOk(message: []const u8) ![]const u8 {
    _ = message;
    return "{\"ok\":true}";
}

test "handleEnvelope returns response on success" {
    var bridge = makeBridge();
    defer bridge.deinit();
    try bridge.registerHandler("ping", dummyOk);

    const out = try handleEnvelope(&bridge, testing.allocator, "{\"id\":\"abc\",\"type\":\"request\",\"method\":\"ping\"}");
    defer testing.allocator.free(out);
    try testing.expectEqualStrings(
        "{\"id\":\"abc\",\"type\":\"response\",\"result\":{\"ok\":true}}",
        out,
    );
}

test "handleEnvelope returns error envelope when method missing" {
    var bridge = makeBridge();
    defer bridge.deinit();

    const out = try handleEnvelope(&bridge, testing.allocator, "{\"id\":\"abc\",\"type\":\"request\"}");
    defer testing.allocator.free(out);
    try testing.expect(std.mem.indexOf(u8, out, "\"error\"") != null);
    try testing.expect(std.mem.indexOf(u8, out, "missing `method`") != null);
}

test "handleEnvelope returns error envelope when JSON is malformed" {
    var bridge = makeBridge();
    defer bridge.deinit();

    const out = try handleEnvelope(&bridge, testing.allocator, "not json");
    defer testing.allocator.free(out);
    try testing.expect(std.mem.indexOf(u8, out, "\"error\"") != null);
}

test "handleEnvelope dispatches handshake handler" {
    var bridge = makeBridge();
    defer bridge.deinit();
    try bridge.registerDefaults();

    const out = try handleEnvelope(&bridge, testing.allocator, "{\"id\":\"hs1\",\"type\":\"request\",\"method\":\"_handshake\"}");
    defer testing.allocator.free(out);
    try testing.expect(std.mem.indexOf(u8, out, "\"version\":1") != null);
    try testing.expect(std.mem.indexOf(u8, out, "\"id\":\"hs1\"") != null);
}

test "writeJsonString escapes specials" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(testing.allocator);
    try writeJsonString(buf.writer(testing.allocator), "say \"hi\"\\backslash\nnewline");
    try testing.expectEqualStrings("\"say \\\"hi\\\"\\\\backslash\\nnewline\"", buf.items);
}

test "handleEnvelope escapes id with quotes/backslashes" {
    var bridge = makeBridge();
    defer bridge.deinit();
    try bridge.registerHandler("ping", dummyOk);

    // An id that contains a quote and backslash. Without escaping, the
    // resulting JSON envelope is broken and the SDK rejects every
    // subsequent message.
    const req =
        "{\"id\":\"abc\\\"x\\\\y\",\"type\":\"request\",\"method\":\"ping\"}";
    const out = try handleEnvelope(&bridge, testing.allocator, req);
    defer testing.allocator.free(out);
    // Output should be valid JSON we can re-parse.
    var parsed = try std.json.parseFromSlice(std.json.Value, testing.allocator, out, .{});
    defer parsed.deinit();
    try testing.expectEqualStrings("abc\"x\\y", parsed.value.object.get("id").?.string);
}
