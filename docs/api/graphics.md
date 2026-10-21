# Graphics capabilities

Craft's standalone CPU raster core is [`graphics.zig`](../../packages/zig/src/graphics.zig).
It imports Zig's standard library and has no window, kernel, WebView or GPU dependency.
The existing [`renderer.zig`](../../packages/zig/src/renderer.zig) types alias the same core.

| Operation | Executed behavior |
| --- | --- |
| `Canvas.clear`, `setPixel` | Replace stored pixels, including alpha |
| `drawRect`, `drawCircle`, `drawLine` | Replace covered pixels after clipping to the frame |
| `drawBitmap` | Composite an unscaled atlas region using straight-alpha source-over |
| `drawText` | Returns `TextRenderingUnavailable` without changing pixels |
| Native window or swapchain presentation | Not provided by this core |

Pixel words have the numeric format `0xAARRGGBB`. A bitmap borrows tightly packed
RGBA8 bytes synchronously. Drawing retains no source pointer. Invalid dimensions,
byte counts, source bounds or overlap with the writable canvas return an error
before changing the frame. A clipped or empty geometric region draws no pixels.

`Canvas.init` limits pixel storage to 64 MiB. A host can select its own explicit
budget using `Canvas.initWithLimits(allocator, width, height, .{ .max_pixels = n })`.
Dimensions and byte arithmetic are checked before allocation. Allocation failure
returns an error. The caller owns a canvas and calls `deinit` exactly once; copied
canvas values do not create a second owner. Do not mutate its storage or dimensions.
The legacy `Renderer` owns its one created canvas and rejects another creation
with `CanvasAlreadyExists`; callers must not separately deinitialize that canvas.

Primitive rasterization visits only clipped frame pixels or the visible major
axis of a line. Extreme offscreen coordinates cannot force iteration over the
entire offscreen geometry. Directed Bresenham tie behavior is preserved.

## Hardware capability boundary

[`GPU.getRenderingCapabilities`](../../packages/zig/src/gpu.zig) describes
implemented execution separately from requested backend settings and hardware
discovery. Currently it reports offscreen clear, with hardware canvas, shader
compilation, drawing, compute, presentation, hardware video decode, post-processing,
ray tracing and multi-GPU discovery unavailable.

Unavailable draw, indexed draw, mesh, compute, effects, decoder, ray-tracing and
enumeration calls return `UnsupportedOperation`. Shader compilation returns
`ShaderCompilationUnavailable`. An unexecuted ray query does not return a successful
miss, and an undecoded stream does not return successful empty video bytes.
Unsupported work does not increment successful render statistics. CPU query timing
is not GPU execution evidence. Offscreen pixel allocation is not native presentation.

## Verification

Run the maintained tests with the toolchain pinned by `pantry.lock`:

```sh
bun scripts/zig.ts --core build test:graphics test:renderer test:gpu
```

The standalone tests import the core directly and assert exact pixels, straight
alpha, directed line ties, buffer borrowing, budget rejection and allocation
failure cleanup. Renderer tests retain extreme-coordinate regressions and ownership
checks. GPU tests reject unavailable operations through their public interfaces.
These tests establish CPU behavior and explicit capability errors. Native surfaces,
terrain triangles, text and platform rendering require their own execution evidence.
