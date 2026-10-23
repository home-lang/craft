//! Native presentation of the CPU graphics core's 0xAARRGGBB pixel words.
//! The caller owns a layer-backed NSView/UIView. No web renderer is involved.
const std = @import("std");
const builtin = @import("builtin");
const objc = @import("objc_runtime.zig").objc;

pub const supported = builtin.os.tag == .macos or builtin.os.tag == .ios;
pub const Error = error{ Unavailable, MainThreadRequired, InvalidView, UnattachedView, InvalidSize, BufferLimitExceeded, AllocationFailed, Disposed, Suspended, InvalidFrame, DrawableUnavailable, GPUFailed, GPUTimeout, NoFrame };
pub const Config = struct {
    /// Total bytes in the shared upload and readback buffers, excluding the
    /// caller's frame and the driver's two bounded drawable textures.
    max_buffer_bytes: usize = 64 * 1024 * 1024,
    /// GPU completion budget after submission. Drawable acquisition separately
    /// uses CAMetalLayer's one-second timeout, never its unbounded mode.
    command_timeout_ms: u32 = 1000,
};
pub const Metrics = struct { width: u32 = 0, height: u32 = 0, scale: f64 = 1 };
pub const Layout = struct {
    row_bytes: usize,
    buffer_bytes: usize,

    pub fn init(width: u32, height: u32, budget: usize) Error!Layout {
        if (width == 0 or height == 0 or width > 8192 or height > 8192) return error.InvalidSize;
        const row = std.math.add(usize, try mul(width, 4), 255) catch return error.BufferLimitExceeded;
        const length = try mul(row & ~@as(usize, 255), height);
        if (try mul(length, 2) > budget) return error.BufferLimitExceeded;
        return .{ .row_bytes = row & ~@as(usize, 255), .buffer_bytes = length };
    }
};
fn mul(a: usize, b: usize) Error!usize {
    return std.math.mul(usize, a, b) catch error.BufferLimitExceeded;
}

pub const Surface = if (supported) AppleSurface else UnavailableSurface;
const UnavailableSurface = struct {
    pub fn init(_: ?*anyopaque, _: Config) Error!UnavailableSurface {
        return error.Unavailable;
    }
    pub fn resize(_: *@This()) Error!Metrics {
        return error.Unavailable;
    }
    pub fn present(_: *@This(), _: []const u32) Error!void {
        return error.Unavailable;
    }
    pub fn readPixels(_: *@This(), _: []u32) Error!void {
        return error.Unavailable;
    }
    pub fn setSuspended(_: *@This(), _: bool) Error!void {
        return error.Unavailable;
    }
    pub fn deinit(_: *@This()) Error!void {
        return error.Unavailable;
    }
};
const Point = extern struct { x: f64, y: f64 };
const Size = extern struct { width: f64, height: f64 };
const Rect = extern struct { origin: Point, size: Size };
const Extent = extern struct { width: usize, height: usize, depth: usize = 1 };
const Origin = extern struct { x: usize = 0, y: usize = 0, z: usize = 0 };
const Object = ?*anyopaque;
extern "Metal" fn MTLCreateSystemDefaultDevice() Object;
extern "QuartzCore" fn CACurrentMediaTime() f64;
extern "c" fn pthread_main_np() c_int;
extern "c" fn usleep(c_uint) c_int;

fn message(comptime T: type, receiver: Object, name: [*:0]const u8) T {
    const call: *const fn (Object, Object) callconv(.c) T = @ptrCast(&objc.objc_msgSend);
    return call(receiver, objc.sel_registerName(name));
}
fn message1(comptime T: type, receiver: Object, name: [*:0]const u8, argument: anytype) T {
    const call: *const fn (Object, Object, @TypeOf(argument)) callconv(.c) T = @ptrCast(&objc.objc_msgSend);
    return call(receiver, objc.sel_registerName(name), argument);
}
fn release(object: Object) void {
    if (object != null) message(void, object, "release");
}

const AppleSurface = struct {
    view: Object = null,
    layer: Object = null,
    device: Object = null,
    queue: Object = null,
    upload: Object = null,
    readback: Object = null,
    metrics: Metrics = .{},
    layout: Layout = .{ .row_bytes = 0, .buffer_bytes = 0 },
    config: Config,
    frames: u64 = 0,
    suspended: bool = false,
    disposed: bool = false,
    faulted: bool = false,

    pub fn init(view: Object, config: Config) Error!AppleSurface {
        if (pthread_main_np() == 0) return error.MainThreadRequired;
        if (view == null or config.max_buffer_bytes == 0 or config.command_timeout_ms == 0 or config.command_timeout_ms > 5000) return error.InvalidView;
        const view_class = objc.objc_getClass(if (builtin.os.tag == .macos) "NSView" else "UIView") orelse return error.Unavailable;
        if (!message1(bool, view, "isKindOfClass:", view_class)) return error.InvalidView;
        const parent = message(Object, view, "layer") orelse return error.InvalidView;
        var self: AppleSurface = .{ .config = config, .view = message(Object, view, "retain") };
        errdefer self.disposeOwned();
        self.device = MTLCreateSystemDefaultDevice() orelse return error.Unavailable;
        self.queue = message(Object, self.device, "newCommandQueue") orelse return error.AllocationFailed;
        self.layer = message(Object, message(Object, objc.objc_getClass("CAMetalLayer"), "alloc"), "init") orelse return error.AllocationFailed;
        message1(void, self.layer, "setDevice:", self.device);
        message1(void, self.layer, "setPixelFormat:", @as(usize, 80)); // MTLPixelFormatBGRA8Unorm
        message1(void, self.layer, "setFramebufferOnly:", false); // blit upload and readback
        message1(void, self.layer, "setAllowsNextDrawableTimeout:", true);
        message1(void, self.layer, "setMaximumDrawableCount:", @as(usize, 2));
        message1(void, self.layer, "setOpaque:", true);
        _ = try self.resize();
        message1(void, parent, "addSublayer:", self.layer);
        return self;
    }

    fn check(self: *AppleSurface) Error!void {
        if (self.disposed) return error.Disposed;
        if (pthread_main_np() == 0) return error.MainThreadRequired;
        if (self.faulted) return error.GPUFailed;
    }

    /// Read actual native view geometry and backing scale. Allocation failure
    /// leaves the previous buffers owned and intact; no partial frame is sent.
    pub fn resize(self: *AppleSurface) Error!Metrics {
        try self.check();
        const window = message(Object, self.view, "window") orelse return error.UnattachedView;
        const scale = if (builtin.os.tag == .macos) message(f64, window, "backingScaleFactor") else message(f64, message(Object, window, "screen"), "scale");
        const bounds = objc.msgSendStret(Rect, self.view, objc.sel_registerName("bounds"));
        if (!std.math.isFinite(scale) or scale <= 0 or scale > 8 or !std.math.isFinite(bounds.origin.x) or !std.math.isFinite(bounds.origin.y) or !std.math.isFinite(bounds.size.width) or !std.math.isFinite(bounds.size.height) or bounds.size.width < 0 or bounds.size.height < 0) return error.InvalidSize;
        const width = @ceil(bounds.size.width * scale);
        const height = @ceil(bounds.size.height * scale);
        if (width > 8192 or height > 8192) return error.InvalidSize;
        const next: Metrics = .{ .width = @intFromFloat(width), .height = @intFromFloat(height), .scale = scale };
        if (next.width == 0 or next.height == 0) return error.InvalidSize;
        const layout = try Layout.init(next.width, next.height, self.config.max_buffer_bytes);
        if (layout.buffer_bytes != self.layout.buffer_bytes) {
            const combined = std.math.add(usize, layout.buffer_bytes, self.layout.buffer_bytes) catch return error.BufferLimitExceeded;
            if (try mul(combined, 2) > self.config.max_buffer_bytes) return error.BufferLimitExceeded;
            const create: *const fn (Object, Object, usize, usize) callconv(.c) Object = @ptrCast(&objc.objc_msgSend);
            // Shared MTLBuffers are supported on Apple, Intel and AMD GPUs.
            // This does not assume shared MTLTextures work on non-Apple GPUs.
            const upload = create(self.device, objc.sel_registerName("newBufferWithLength:options:"), layout.buffer_bytes, 0) orelse return error.AllocationFailed;
            errdefer release(upload);
            const readback = create(self.device, objc.sel_registerName("newBufferWithLength:options:"), layout.buffer_bytes, 0) orelse return error.AllocationFailed;
            release(self.upload);
            release(self.readback);
            self.upload = upload;
            self.readback = readback;
            self.frames = 0;
        }
        if (next.width != self.metrics.width or next.height != self.metrics.height) self.frames = 0;
        self.metrics = next;
        self.layout = layout;
        const transaction = objc.objc_getClass("CATransaction");
        message(void, transaction, "begin");
        message1(void, transaction, "setDisableActions:", true);
        message1(void, self.layer, "setFrame:", bounds);
        message1(void, self.layer, "setContentsScale:", scale);
        message1(void, self.layer, "setDrawableSize:", Size{ .width = width, .height = height });
        message(void, transaction, "commit");
        return next;
    }

    pub fn setSuspended(self: *AppleSurface, suspended: bool) Error!void {
        try self.check();
        self.suspended = suspended;
    }

    /// Present a completed opaque frame. Sprite alpha is composited by the CPU
    /// graphics core before presentation; a translucent final frame is refused.
    pub fn present(self: *AppleSurface, pixels: []const u32) Error!void {
        try self.check();
        if (self.suspended) return error.Suspended;
        const metrics = try self.resize();
        if (pixels.len != try mul(metrics.width, metrics.height)) return error.InvalidFrame;
        const pool = message(Object, message(Object, objc.objc_getClass("NSAutoreleasePool"), "alloc"), "init");
        defer message(void, pool, "drain");
        const data: [*]u8 = @ptrCast(message(Object, self.upload, "contents") orelse return error.AllocationFailed);
        for (pixels, 0..) |pixel, index| {
            if (pixel >> 24 != 255) return error.InvalidFrame;
            const offset = (index / metrics.width) * self.layout.row_bytes + (index % metrics.width) * 4;
            data[offset] = @truncate(pixel);
            data[offset + 1] = @truncate(pixel >> 8);
            data[offset + 2] = @truncate(pixel >> 16);
            data[offset + 3] = @truncate(pixel >> 24);
        }
        const drawable = message(Object, self.layer, "nextDrawable") orelse return error.DrawableUnavailable;
        const texture = message(Object, drawable, "texture") orelse return error.DrawableUnavailable;
        if (message(usize, texture, "width") != metrics.width or message(usize, texture, "height") != metrics.height) return error.InvalidFrame;
        const command = message(Object, self.queue, "commandBuffer") orelse return error.AllocationFailed;
        const encoder = message(Object, command, "blitCommandEncoder") orelse return error.AllocationFailed;
        const extent: Extent = .{ .width = metrics.width, .height = metrics.height };
        const upload: *const fn (Object, Object, Object, usize, usize, usize, Extent, Object, usize, usize, Origin) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
        upload(encoder, objc.sel_registerName("copyFromBuffer:sourceOffset:sourceBytesPerRow:sourceBytesPerImage:sourceSize:toTexture:destinationSlice:destinationLevel:destinationOrigin:"), self.upload, 0, self.layout.row_bytes, self.layout.buffer_bytes, extent, texture, 0, 0, .{});
        const readback: *const fn (Object, Object, Object, usize, usize, Origin, Extent, Object, usize, usize, usize) callconv(.c) void = @ptrCast(&objc.objc_msgSend);
        readback(encoder, objc.sel_registerName("copyFromTexture:sourceSlice:sourceLevel:sourceOrigin:sourceSize:toBuffer:destinationOffset:destinationBytesPerRow:destinationBytesPerImage:"), texture, 0, 0, .{}, extent, self.readback, 0, self.layout.row_bytes, self.layout.buffer_bytes);
        message(void, encoder, "endEncoding");
        message1(void, command, "presentDrawable:", drawable);
        const deadline = CACurrentMediaTime() + @as(f64, @floatFromInt(self.config.command_timeout_ms)) / 1000;
        message(void, command, "commit");
        while (true) {
            const status = message(usize, command, "status");
            if (status == 5) {
                self.faulted = true;
                return error.GPUFailed;
            }
            if (CACurrentMediaTime() > deadline) {
                self.faulted = true;
                return error.GPUTimeout;
            }
            if (status == 4) break;
            _ = usleep(1000);
        }
        self.frames +|= 1;
    }

    /// Read pixels copied back from the actual drawable texture by Metal.
    pub fn readPixels(self: *AppleSurface, destination: []u32) Error!void {
        try self.check();
        if (self.frames == 0) return error.NoFrame;
        if (destination.len != try mul(self.metrics.width, self.metrics.height)) return error.InvalidFrame;
        const data: [*]const u8 = @ptrCast(message(Object, self.readback, "contents") orelse return error.AllocationFailed);
        for (destination, 0..) |*pixel, index| {
            const offset = (index / self.metrics.width) * self.layout.row_bytes + (index % self.metrics.width) * 4;
            pixel.* = @as(u32, data[offset]) | (@as(u32, data[offset + 1]) << 8) | (@as(u32, data[offset + 2]) << 16) | (@as(u32, data[offset + 3]) << 24);
        }
    }

    fn disposeOwned(self: *AppleSurface) void {
        if (self.layer != null) message(void, self.layer, "removeFromSuperlayer");
        release(self.upload);
        release(self.readback);
        release(self.queue);
        release(self.layer);
        release(self.device);
        release(self.view);
        self.disposed = true;
    }
    pub fn deinit(self: *AppleSurface) Error!void {
        if (self.disposed) return error.Disposed;
        if (pthread_main_np() == 0) return error.MainThreadRequired;
        // A submitted command retains its resources until completion, including
        // when a timeout made the surface terminally faulted.
        self.disposeOwned();
    }
};

test "frame buffers have aligned rows and reject invalid dimensions and budgets" {
    const layout = try Layout.init(65, 3, 3072);
    try std.testing.expectEqual(@as(usize, 512), layout.row_bytes);
    try std.testing.expectEqual(@as(usize, 1536), layout.buffer_bytes);
    try std.testing.expectError(error.BufferLimitExceeded, Layout.init(65, 3, 3071));
    try std.testing.expectError(error.InvalidSize, Layout.init(0, 1, 4096));
    try std.testing.expectError(error.InvalidSize, Layout.init(std.math.maxInt(u32), 1, std.math.maxInt(usize)));
    if (!supported) {
        try std.testing.expectError(error.Unavailable, Surface.init(null, .{}));
        var missing: Surface = .{};
        try std.testing.expectError(error.Unavailable, missing.resize());
        try std.testing.expectError(error.Unavailable, missing.present(&.{}));
        try std.testing.expectError(error.Unavailable, missing.readPixels(&.{}));
        try std.testing.expectError(error.Unavailable, missing.setSuspended(true));
        try std.testing.expectError(error.Unavailable, missing.deinit());
    }
}
