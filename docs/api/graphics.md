# Graphics capabilities

Craft's standalone CPU raster core is [`graphics.zig`](../../packages/zig/src/graphics.zig).
It imports Zig's standard library and has no window, kernel, WebView or GPU dependency.
The existing [`renderer.zig`](../../packages/zig/src/renderer.zig) types alias the same core.

| Operation | Executed behavior |
| --- | --- |
| `Canvas.clear`, `setPixel` | Replace stored pixels, including alpha |
| `drawRect`, `drawCircle`, `drawLine` | Replace covered pixels after clipping to the frame |
| `drawBitmap` | Composite an unscaled atlas region using straight-alpha source-over |
| `Canvas.drawText` | Family/system font lookup returns `TextRenderingUnavailable` |
| `scene.drawSprite` | Affine nearest-neighbor atlas sprites, masked tint and clipping |
| `scene.drawTriangle` | Affine UV sampling with a top-left shared-edge rule |
| `scene.drawText` | Explicit borrowed bitmap-font glyphs with UTF-8 and newlines |
| `scene.drawFrame` | Ordered commands with validation and aggregate budgets before writes |
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

## CPU scene drawing

Import `graphics.scene` (also available as `renderer.scene`). Its functions draw
into the same owned `Canvas`; they allocate no asset, command or per-frame storage.
All source slices are borrowed synchronously and are never retained. Do not modify
inputs concurrently with a draw. All supplied assets, masks, text, glyph tables and
command storage must be disjoint from the writable canvas.

`drawSprite(&canvas, sprite, limits)` takes a `Bitmap`, an integer atlas `source`
rectangle and a `Transform`. Local pixel-edge coordinates map to frame coordinates
as `x' = a*x + c*y + tx`, `y' = b*x + d*y + ty`. The identity is the default.
Sampling inverse-maps destination pixel centers and selects the source pixel with
`floor`, so scaling, rotation, mirroring and shear share the same nearest-neighbor
contract. Singular, nonfinite or numerically unrepresentable transforms fail.
Optional `clip` rectangles intersect the canvas before rasterization.

A `Tint` multiplies straight RGBA channels using rounded 8-bit arithmetic. Its
optional atlas-sized one-byte-per-pixel `mask` blends that result with the original
pixel using mask coverage. An absent mask applies tint to every source pixel;
zero coverage preserves the original. Player masks use full-atlas coordinates,
including when drawing an atlas subregion. This is an explicit pixel operation,
not a claim about any original game's palette rules.

`drawTriangle` takes three `Vertex` values with frame-space `x`, `y` and normalized
`u`, `v` in `[0,1]`. UVs interpolate affinely; nearest sampling clamps the upper
endpoint to the last atlas texel. Either winding is supported. Pixel-center
coverage uses the top-left edge rule, so adjacent triangles do not double-blend
their shared edge. Degenerate triangles and invalid coordinates/UVs fail before
writes. This API supplies 2D textured terrain, without perspective correction or
a hardware pipeline.

`drawText` requires a `BitmapFont` containing its RGBA atlas, sorted unique Unicode
scalar `Glyph` records and a positive `line_height`. Each glyph supplies an atlas
rectangle, integer bearing and advance. The origin is a top-left pen; newline
resets horizontal advance and adds line height. The complete string and font are
validated before drawing, including missing glyphs. The same affine transform,
mask/tint and clip semantics apply to glyph sprites. System font discovery,
TrueType rasterization, shaping, bidirectional layout and kerning are not provided.
The separate family-based `Canvas.drawText` continues to return an explicit error.

`drawFrame` accepts a borrowed slice of `Command` values (`sprite`, `triangle`,
`text`) and executes it in slice order using straight-alpha source-over. Every
command is validated before the first write, so a later invalid command cannot
leave an earlier command's pixels behind. The default `scene.Limits` are:

| Limit | Default |
| --- | --- |
| Asset bytes | 64 MiB of unique typed views, including masks and glyph records |
| Unique asset views | 1,024 per frame, with a fixed supported maximum |
| Clipped bounding-box pixel work | 67,108,864 pixels |
| Font glyph count | 4,096 per font |
| UTF-8 text bytes | 1 MiB |
| Frame commands | 65,536 |

Asset bytes count identical typed views once within a frame. A view's identity is
its role (RGBA atlas, player mask or glyph metadata), start address and exact byte
length. A full atlas is charged even when commands sample different subregions.
Different offsets, lengths and roles remain separate charges, including partially
overlapping views. Each command still receives complete validation. Deduplication
never removes a command's pixel-work or text-byte charge.

The frame uses a fixed 2,048-slot table with at most 1,024 unique views. Its entries
occupy 48 KiB on 64-bit targets, plus two counters and ordinary call frames. Hosts
must budget that stack storage separately from canvas pixels and borrowed inputs.
No allocator or global cache supplies the table, and all stored addresses expire
at function return. Lookups use bounded probing; exhaustion returns
`AssetViewLimitExceeded` before drawing. `max_asset_views` can select a smaller
limit, including zero for an empty frame. Values above
`scene.max_supported_asset_views` return `InvalidAssetViewLimit`.

Pixel work and text bytes still accumulate across every frame command. Hosts can
explicitly set different byte/work limits; all budget arithmetic is checked.
Offscreen geometry is clipped before iteration. Canvas allocation retains its
separate pixel budget and allocator error contract. A scene draw does not request
more memory, even if that allocator can no longer allocate. Rejected work returns
an error before changing the canvas.

## Hardware capability boundary

The separate [`craft.metal_surface`](../guides/metal-surface.md) API presents
completed opaque CPU frames through a native `CAMetalLayer`. Its macOS fixture
compares actual drawable pixels, including resize and backing scale. This is a
surface adapter, with separate error and memory contracts. It does not change
the legacy GPU pipeline's capabilities below. iOS presentation and native game
integration still require their own execution evidence.

[`GPU.getRenderingCapabilities`](../../packages/zig/src/gpu.zig) describes
implemented execution separately from requested backend settings and hardware
discovery. Currently it reports RGBA8 offscreen clear, with hardware canvas, shader
compilation, drawing, compute, presentation, hardware video decode, post-processing,
ray tracing and multi-GPU discovery unavailable.

Unavailable draw, indexed draw, mesh, compute, effects, decoder, ray-tracing and
enumeration calls return `UnsupportedOperation`. Shader compilation returns
`ShaderCompilationUnavailable`. An unexecuted ray query does not return a successful
miss, and an undecoded stream does not return successful empty video bytes.
Unsupported work does not increment successful render statistics. CPU query timing
is not GPU execution evidence. Offscreen pixel allocation is not native presentation.

Offscreen `Texture.init` limits each attachment to 64 MiB, with an explicit
`Texture.initWithLimits` byte budget for hosts requiring a different bound. A render
target can own both color and depth attachments. Resizing temporarily owns the old
and new storage, then commits both attachments together. An allocation failure
retains the entire previous frame and releases temporary storage. Upload and
download require exactly matching byte counts, and do not write a rejected buffer.
RGBA8 clears reject nonfinite or out-of-range channels before changing either
attachment. Other clear formats return `UnsupportedOperation`.

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
platform rendering require their own execution evidence. Scene tests compare actual
transformed sprite, masked tint, shared-edge triangle, UV atlas, UTF-8 glyph and
ordered-alpha pixels. They also retain invalid-input, all-or-nothing frame,
unique-view byte/count budgets, metadata exhaustion, aliasing and allocation-free
repeated-frame checks.
