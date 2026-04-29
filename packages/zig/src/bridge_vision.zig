const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Vision framework bridge — OCR, face detection, barcode scanning.
///
/// The full flow per request type:
///   - load image from disk via `CGImageSourceCreateWithURL`
///   - build the appropriate `VNRequest` (`VNRecognizeTextRequest`,
///     `VNDetectFaceRectanglesRequest`, `VNDetectBarcodesRequest`)
///   - run via `VNImageRequestHandler.performRequests:`
///   - serialize each result's `boundingBox` + payload into JSON
///
/// The JS surface is in place; the request execution is the next
/// implementation step. Today every action returns an empty result
/// array so callers can write feature-detection branching.
pub const VisionBridge = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(a: std.mem.Allocator) Self {
        return .{ .allocator = a };
    }

    pub fn deinit(_: *Self) void {}

    pub fn handleMessage(self: *Self, action: []const u8, _: []const u8) !void {
        if (std.mem.eql(u8, action, "recognizeText") or
            std.mem.eql(u8, action, "detectFaces") or
            std.mem.eql(u8, action, "detectBarcodes"))
        {
            bridge_error.sendResultToJS(self.allocator, action, "{\"results\":[],\"reason\":\"Vision wiring pending\"}");
        } else return BridgeError.UnknownAction;
    }
};
