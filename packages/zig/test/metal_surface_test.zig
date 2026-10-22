//! Real AppKit window, native CAMetalLayer and GPU readback via public Craft.
const std = @import("std");
const metal = @import("craft").metal_surface;
const Object = ?*anyopaque;
const Size = extern struct { width: f64, height: f64 };
const Rect = extern struct { origin: extern struct { x: f64, y: f64 }, size: Size };
extern "c" fn objc_getClass([*:0]const u8) Object;
extern "c" fn sel_registerName([*:0]const u8) Object;
extern "c" fn objc_msgSend() void;
fn send(comptime T: type, receiver: Object, name: [*:0]const u8) T {
    const call: *const fn (Object, Object) callconv(.c) T = @ptrCast(&objc_msgSend);
    return call(receiver, sel_registerName(name));
}
fn send1(comptime T: type, receiver: Object, name: [*:0]const u8, arg: anytype) T {
    const call: *const fn (Object, Object, @TypeOf(arg)) callconv(.c) T = @ptrCast(&objc_msgSend);
    return call(receiver, sel_registerName(name), arg);
}
fn pump() void {
    const date = send1(Object, objc_getClass("NSDate"), "dateWithTimeIntervalSinceNow:", @as(f64, 0.02));
    send1(void, send(Object, objc_getClass("NSRunLoop"), "mainRunLoop"), "runUntilDate:", date);
}

pub fn main() !void {
    var heap: std.heap.DebugAllocator(.{}) = .init;
    defer std.debug.assert(heap.deinit() == .ok);
    const allocator = heap.allocator();
    const pool = send(Object, send(Object, objc_getClass("NSAutoreleasePool"), "alloc"), "init");
    defer send(void, pool, "drain");
    const app = send(Object, objc_getClass("NSApplication"), "sharedApplication");
    _ = send1(bool, app, "setActivationPolicy:", @as(isize, 1));
    send(void, app, "finishLaunching");
    const create: *const fn (Object, Object, Rect, usize, usize, bool) callconv(.c) Object = @ptrCast(&objc_msgSend);
    const window = create(send(Object, objc_getClass("NSWindow"), "alloc"), sel_registerName("initWithContentRect:styleMask:backing:defer:"), .{ .origin = .{ .x = 40, .y = 40 }, .size = .{ .width = 256, .height = 192 } }, 11, 2, false) orelse return error.WindowUnavailable;
    send1(void, window, "setReleasedWhenClosed:", false);
    defer {
        send(void, window, "close");
        send(void, window, "release");
    }
    send1(void, window, "setTitle:", send1(Object, objc_getClass("NSString"), "stringWithUTF8String:", @as([*:0]const u8, "Craft Metal surface fixture")));
    const view = send(Object, window, "contentView") orelse return error.ViewUnavailable;
    send1(void, view, "setWantsLayer:", true);
    send(void, window, "orderFrontRegardless");
    pump();
    const parent_layer = send(Object, view, "layer");
    const initial_layers = send(usize, send(Object, parent_layer, "sublayers"), "count");
    try std.testing.expectError(error.InvalidView, metal.Surface.init(null, .{}));
    try std.testing.expectError(error.BufferLimitExceeded, metal.Surface.init(view, .{ .max_buffer_bytes = 1 }));
    try std.testing.expectEqual(initial_layers, send(usize, send(Object, parent_layer, "sublayers"), "count"));
    var surface = try metal.Surface.init(view, .{ .max_buffer_bytes = 4 * 1024 * 1024 });
    var disposed = false;
    defer if (!disposed) surface.deinit() catch unreachable;
    try std.testing.expectEqual(initial_layers + 1, send(usize, send(Object, parent_layer, "sublayers"), "count"));
    var metrics = try surface.resize();
    try std.testing.expect(metrics.width > 0 and metrics.height > 0 and metrics.scale >= 1);
    try std.testing.expectEqual(@as(u32, @intFromFloat(256 * metrics.scale)), metrics.width);
    try std.testing.expectEqual(@as(u32, @intFromFloat(192 * metrics.scale)), metrics.height);
    try std.testing.expectError(error.NoFrame, surface.readPixels(&.{}));
    try std.testing.expectError(error.InvalidFrame, surface.present(&.{}));
    var pixels = try allocator.alloc(u32, @as(usize, metrics.width) * metrics.height);
    defer allocator.free(pixels);
    var readback = try allocator.alloc(u32, pixels.len);
    defer allocator.free(readback);
    @memset(pixels, 0x80ffffff);
    try std.testing.expectError(error.InvalidFrame, surface.present(pixels));
    var frames: usize = 0;
    for (0..60) |frame| {
        if (frame == 30) {
            send1(void, window, "setContentSize:", Size{ .width = 160, .height = 120 });
            pump();
            metrics = try surface.resize();
            try std.testing.expectEqual(@as(u32, @intFromFloat(160 * metrics.scale)), metrics.width);
            try std.testing.expectEqual(@as(u32, @intFromFloat(120 * metrics.scale)), metrics.height);
            pixels = try allocator.realloc(pixels, @as(usize, metrics.width) * metrics.height);
            readback = try allocator.realloc(readback, pixels.len);
            try std.testing.expectError(error.NoFrame, surface.readPixels(readback));
        }
        for (pixels, 0..) |*pixel, i| {
            const x = i % metrics.width;
            const y = i / metrics.width;
            pixel.* = if (x == frame % metrics.width) 0xffffffff else if (x < metrics.width / 2 and y < metrics.height / 2) 0xffe02040 else if (x >= metrics.width / 2 and y < metrics.height / 2) 0xff20c060 else if (x < metrics.width / 2) 0xff2040e0 else 0xffd0a020;
        }
        try surface.present(pixels);
        try surface.readPixels(readback);
        try std.testing.expectEqualSlices(u32, pixels, readback);
        pump();
        frames += 1;
    }
    try surface.setSuspended(true);
    try std.testing.expectError(error.Suspended, surface.present(pixels));
    try surface.setSuspended(false);
    try surface.present(pixels);
    try surface.readPixels(readback);
    try std.testing.expectEqualSlices(u32, pixels, readback);
    const WrongThread = struct {
        fn run(value: *metal.Surface, result: *bool) void {
            _ = value.resize() catch |err| {
                result.* = err == error.MainThreadRequired;
                return;
            };
        }
    };
    var rejected = false;
    const thread = try std.Thread.spawn(.{}, WrongThread.run, .{ &surface, &rejected });
    thread.join();
    try std.testing.expect(rejected);
    try surface.deinit();
    disposed = true;
    try std.testing.expectEqual(initial_layers, send(usize, send(Object, parent_layer, "sublayers"), "count"));
    try std.testing.expectError(error.Disposed, surface.present(pixels));
    try std.testing.expectError(error.Disposed, surface.deinit());
    const existing = try metal.Layout.init(metrics.width, metrics.height, std.math.maxInt(usize));
    var bounded = try metal.Surface.init(view, .{ .max_buffer_bytes = 2 * existing.buffer_bytes });
    defer bounded.deinit() catch unreachable;
    try bounded.present(pixels);
    send1(void, window, "setContentSize:", Size{ .width = 128, .height = 96 });
    pump();
    // The smaller replacement fits by itself, but both live buffer pairs do
    // not. Refuse before allocation, then prove the old frame is still owned.
    try std.testing.expectError(error.BufferLimitExceeded, bounded.resize());
    try bounded.readPixels(readback);
    try std.testing.expectEqualSlices(u32, pixels, readback);
    send1(void, window, "setContentSize:", Size{ .width = 160, .height = 120 });
    pump();
    try bounded.present(pixels);
    std.debug.print("Native Metal presentation passed: {d} frames compared, scale {d}, real resize, suspension, wrong-thread rejection and disposal.\n", .{ frames + 1, metrics.scale });
}
