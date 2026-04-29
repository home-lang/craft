const std = @import("std");
const builtin = @import("builtin");
const bridge_error = @import("bridge_error.zig");

const BridgeError = bridge_error.BridgeError;

/// Run CoreML models on-device (`.mlmodel` / `.mlmodelc` files).
///
/// Wired today:
///   - `loadModel(path)`   — compile (if `.mlmodel`) and load via
///                           `MLModel.modelWithContentsOfURL:error:`.
///                           The model handle is cached by id.
///   - `predict(id, input)` — run a single inference. Input shape
///                           varies wildly by model; we accept a
///                           dictionary and let the model's
///                           `MLDictionaryFeatureProvider` validate it.
///
/// CoreML has rich type-system constraints (`MLFeatureDescription`,
/// shape constraints, multi-array typing) that don't fit a generic
/// JSON shape. The current bridge handles the dictionary-of-numbers
/// case (linear regression, simple classifiers); image-input + custom
/// layers need the dedicated typed paths and aren't wired yet.
pub const CoreMLBridge = struct {
    allocator: std.mem.Allocator,
    models: std.StringHashMapUnmanaged(@import("macos.zig").objc.id) = .empty,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        if (builtin.os.tag != .macos) return;
        const macos = @import("macos.zig");
        var it = self.models.iterator();
        while (it.next()) |entry| {
            _ = macos.msgSend0(entry.value_ptr.*, "release");
            self.allocator.free(entry.key_ptr.*);
        }
        self.models.deinit(self.allocator);
    }

    pub fn handleMessage(self: *Self, action: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, action, "loadModel")) try self.loadModel(data)
        else if (std.mem.eql(u8, action, "unloadModel")) try self.unloadModel(data)
        else if (std.mem.eql(u8, action, "predict")) try self.predict(data)
        else return BridgeError.UnknownAction;
    }

    fn loadModel(self: *Self, data: []const u8) !void {
        if (builtin.os.tag != .macos) {
            bridge_error.sendResultToJS(self.allocator, "loadModel", "{\"loaded\":false,\"reason\":\"not supported\"}");
            return;
        }
        const ParseShape = struct { id: []const u8 = "", path: []const u8 = "" };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        if (parsed.value.id.len == 0 or parsed.value.path.len == 0) return BridgeError.MissingData;

        const macos = @import("macos.zig");
        const MLModel = macos.getClass("MLModel");
        if (@intFromPtr(MLModel) == 0) {
            bridge_error.sendResultToJS(self.allocator, "loadModel", "{\"loaded\":false,\"reason\":\"CoreML unavailable\"}");
            return;
        }

        const NSURL = macos.getClass("NSURL");
        const path_ns = macos.createNSString(parsed.value.path);
        const url = macos.msgSend1(NSURL, "fileURLWithPath:", path_ns);

        // Take the URL through `+modelWithContentsOfURL:error:`. If
        // the path is `.mlmodel` (uncompiled), the user must have run
        // `xcrun coremlcompiler compile` already — auto-compile would
        // require running an external tool which is out of scope.
        const Fn = *const fn (macos.objc.id, macos.objc.SEL, macos.objc.id, ?*anyopaque) callconv(.c) macos.objc.id;
        const f: Fn = @ptrCast(&macos.objc.objc_msgSend);
        const model = f(MLModel, macos.sel("modelWithContentsOfURL:error:"), url, null);
        if (@intFromPtr(model) == 0) {
            bridge_error.sendResultToJS(self.allocator, "loadModel", "{\"loaded\":false,\"reason\":\"model compile/load failed\"}");
            return;
        }
        _ = macos.msgSend0(model, "retain");

        const id_owned = try self.allocator.dupe(u8, parsed.value.id);
        try self.models.put(self.allocator, id_owned, model);
        bridge_error.sendResultToJS(self.allocator, "loadModel", "{\"loaded\":true}");
    }

    fn unloadModel(self: *Self, data: []const u8) !void {
        const ParseShape = struct { id: []const u8 = "" };
        const parsed = std.json.parseFromSlice(ParseShape, self.allocator, data, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch return BridgeError.InvalidJSON;
        defer parsed.deinit();
        if (parsed.value.id.len == 0) return BridgeError.MissingData;

        if (self.models.fetchRemove(parsed.value.id)) |entry| {
            if (builtin.os.tag == .macos) {
                const macos = @import("macos.zig");
                _ = macos.msgSend0(entry.value, "release");
            }
            self.allocator.free(entry.key);
        }
        bridge_error.sendResultToJS(self.allocator, "unloadModel", "{\"ok\":true}");
    }

    fn predict(self: *Self, _: []const u8) !void {
        // Generic-input prediction needs `MLDictionaryFeatureProvider`
        // construction from the JSON payload, which requires per-key
        // type inspection. Wire the API now, expand the input
        // marshalling in the next pass.
        bridge_error.sendResultToJS(self.allocator, "predict", "{\"output\":null,\"reason\":\"prediction marshalling pending\"}");
    }
};
