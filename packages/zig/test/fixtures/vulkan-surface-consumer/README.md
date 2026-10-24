# Native Vulkan source consumer

This fixture consumes `craft.vulkan_surface` and `craft.graphics.scene` from an
unchanged archive of the package's declared source paths. The test-only C
transport calls the same public Zig methods available to native applications.
It does not duplicate the graphics implementation or use a web renderer.
The dependency selects `desktop-host = false`: the caller supplies its native
window, so the public module keeps SQLite and graphics dependencies while
omitting Craft's GTK/WebKit desktop host. The default profile still supplies
all normal window-host dependencies.

The Xlib host creates an owned window on an isolated X11 display. It presents
61 changing atlas/triangle/glyph frames, compares every GPU readback pixel with
the shared CPU scene, then compares every actual window pixel. It resizes,
unmaps and resumes with a fresh swapchain, receives real XTest pointer input,
and compares the corresponding scene mark. Captures contain only first-party
test colors. Two complete sessions must dispose successfully. A disposal timeout
retains the context and native window until process exit and fails acceptance.

Run on a Linux host with the pinned compiler, X11/XTest, Xvfb/Openbox and a
Vulkan1.1 driver supporting KHR or EXT swapchain maintenance:

```sh
bun scripts/test-vulkan-surface-linux.ts --output artifacts/native-vulkan-linux
```

The existing `zig-core` Linux job requires the native display test with the
Khronos validation layer enabled. It retains original logs, source/compiler and
executable identities, process disposal and four real PPM captures. Validation
errors, blank or stale frames, missing input, incomplete sessions and resource
ownership failures cannot pass. The runner bounds each command and cleans only
its unique generated consumer after its process groups have exited.

The public surface owns Vulkan resources; the caller owns the window and
serializes calls on the creating thread. Frames contain opaque 0xAARRGGBB
pixels. Upload/readback allocations have an explicit byte budget; swapchain
extent and image count are bounded separately. Resize errors leave presentation
unavailable when replacement cannot be created. Retry resize or dispose; do not
continue as though the old swapchain still exists. Timeout disposal retains all
resources until its pending acquisition, render and presentation fences finish.

This source change is under development. Local ownership tests and cross
compilation do not prove Linux native execution. Actual retained window output
and complete source/release acceptance are required before publication claims.
Windows and Android adapters and their native captures remain unfinished. The
fixture does not establish full native game rendering or Gold Edition fidelity.
