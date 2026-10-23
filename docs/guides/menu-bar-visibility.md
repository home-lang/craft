# Native menu bar visibility

Craft exposes two explicitly selected macOS grouping backends. A normal tray app
creates no grouping control. The `nativeVisibility` backend requires macOS 27,
a direct, non-sandboxed build and Accessibility access. It uses the private
MenuBarClientCore assessment-mode visibility API researched in
[Hidden Bar](https://github.com/dwarvesf/hidden). Apple can change this API;
unavailability never selects the legacy width-based backend automatically.

```ts
const native = useNativeDesktop()
native.onReady(async ({ menubar }) => {
  await menubar?.init({ backend: 'nativeVisibility' })
  const state = await menubar?.getState()
  // Offer a user-initiated permission action when available && !authorized.
  // await menubar?.requestPermission()
})
```

The backend adds one compact status button. Command-drag icons to its left
(right in a right-to-left interface) to include their applications in the hidden
group. Click the button or call `toggle()` to hide/reveal it. `collapse()` reads
the unrestricted arrangement asynchronously, then activates a visibility
assertion; `busy` describes this in-flight work. `collapsed` becomes true only
when macOS confirms activation. No status item is widened.

Hiding applies per app, so a visible sibling keeps every icon from that app
visible. System controls and the owning app are protected. Missing or incomplete
Accessibility geometry stays visible. Apps launched during a collapsed session
may remain hidden until the next reveal, when the unrestricted layout is read
again. Native system overflow remains under macOS control when revealed icons
exceed the available space; this API cannot pin app menus above system overflow.

`getState()` and `onStateChange` expose availability, authorization, busy state,
errors and the actual hidden-app count. Permission loss and activation failure
restore icons. Generation tokens prevent late activation callbacks from winning
after reveal, disable or quit. A 20-second deadline releases stalled activations.
`expand()` cancels pending work and releases the assertion; `destroy()` also
removes the control. Process exit releases the OS-owned assertion.

The default `init()` remains the legacy backend for existing consumers. Select
native visibility explicitly; do not combine both controllers. Private visibility
must not be used in App Store submissions. The native tests exercise lifecycle
failure paths with controlled replies and the real bridge with the packaged
runtime, without granting Accessibility access.
