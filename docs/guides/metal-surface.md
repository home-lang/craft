# Native Metal surface

`craft.metal_surface.Surface` presents opaque CPU frames through a `CAMetalLayer`
attached to a native view. The host supplies a layer-backed `NSView` on macOS or
a `UIView` on iOS, already attached to a window. Every operation runs on the main
thread. The surface retains its view and removes its own child layer on disposal.
Keep one owning surface value; copying it does not create a second owner.

```zig
const metal = @import("craft").metal_surface;
var surface = try metal.Surface.init(native_view, .{});
defer surface.deinit() catch unreachable;
const metrics = try surface.resize();
const pixels = try allocator.alloc(u32, @as(usize, metrics.width) * metrics.height);
defer allocator.free(pixels);
@memset(pixels, 0xff18241b);
try surface.present(pixels);
```

Frames contain `0xAARRGGBB` words, with alpha 255 in every final pixel. Compose
sprite alpha in the CPU graphics core first. `resize()` reads the view's actual
bounds and window backing scale. `present()` checks those dimensions again,
refuses a stale or translucent frame, uploads BGRA bytes, and submits a native
blit and presentation. It waits for GPU completion within the configured budget.
`readPixels()` returns pixels copied from the drawable texture by Metal, rather
than returning a copy of the caller's frame.

The upload and readback buffers have 256-byte row alignment and a combined
64 MiB default limit, including old and replacement buffers during resize.
A resize that would exceed that peak returns `BufferLimitExceeded` before
allocating and keeps the existing buffers intact. The driver has a separate
two-drawable pool. Dimensions
are bounded to 8192 pixels per side. Driver overhead and the caller's frame
are outside the shared-buffer byte budget. Shared buffers work on Apple, Intel
and AMD GPUs; this API does not assume shared textures work on every GPU.

Call `setSuspended(true)` before pausing a host. Presentation then returns
`Suspended`; resuming permits frames again. Invalid views, detached windows,
empty sizes, budget failures and unavailable drawables return errors. GPU
failure or completion timeout makes the surface terminal: dispose and recreate
it. Drawable acquisition retains Metal's one-second timeout. A submitted command
retains its resources even if a timeout occurs before disposal.

`supported` describes the platform API. Device creation can still return
`Unavailable`. Other platforms refuse every operation. This surface does not
change the legacy GPU renderer's capability flags or implement Vulkan.

Run `zig build test-metal-surface` with Craft's pinned compiler. It runs portable
layout and unsupported-platform checks everywhere and a real AppKit/Metal
fixture on macOS. The native fixture compares every GPU pixel across 61 presented
frames, a real resize and backing scale, suspension, main-thread enforcement,
buffer-budget refusal and layer removal. It is included in `zig build test`.

The current execution evidence covers macOS. iOS requires its native host fixture
and actual device or simulator acceptance before claiming iOS presentation.
Native game input, frame clocks and the stx HUD remain separate integrations.
