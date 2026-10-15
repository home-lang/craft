# Android native navigation fixture

This uses the same three `.stx` screens as the iOS navigation test in
`packages/ios/fixtures/native-navigation`. The compiler produces one route
bundle, and the generated Android app hosts it in native views with a
JavaScriptSandbox isolate per screen.

With a sibling `stx` checkout and an Android SDK/emulator available:

```bash
bun packages/android/scripts/test-native-navigation.ts
```

The instrumentation test checks native control classes, including the `Spinner`
rendered for the `Picker`, `CraftNativeVideoView` for the network-free native
`Video` mount, and
`CraftNativeIconView` for the shared symbol fixture, `CraftNativeSvgView` for the grouped SVG fixture, rendered route
parameters, push/replace/back (including Android's Back key), retained input
identity and value, text-input submission, and the absence of any `WebView` in
the activity view tree. Scroll callbacks are attached to the underlying Android
scroller rather than the native wrapper, so nested scroll offsets come from the
platform control that actually moves. The test locates that underlying
`HorizontalScrollView` or `ScrollView` through the wrapper's `testID` instead
of depending on the wrapper's implementation class. The details `ScrollView` also exercises
the same swipe-to-refresh and keyed-row insertion path as iOS; the dedicated
`NativeFlatListTest` continues to cover recycling and virtualized row layout.
The maintained navigation test drives the shell's public tab-swipe callbacks
because the hosted emulator cannot reliably inject a window-targeted touch
sequence; the real interactive transition still runs, while the touch
interception and nested-scroll ownership rules remain source-contract tested.
The shared home route also exercises Android's native `DatePicker` and
`TimePicker`, including date bounds, minute-interval snapping, and the shared
value/ISO/timestamp event payload.

The navigation section also verifies the shared runtime lifecycle: a pushed
details screen gets fresh state, the unmount marker runs after the Android Back
path, and replacement disposes the outgoing screen before the new route is
opened.
The capability fixture also starts an emulator-local HTTP endpoint and sends a
text-body request through the advertised `fetch` capability. It checks the
authorization header, response status, headers and body, using the same bounded
request/response contract as the maintained iOS host. Invalid methods, body
types, and header values are rejected before the local endpoint is contacted,
keeping malformed calls consistent across both native hosts.
The shared Home route uses the STX signal and lifecycle APIs supplied by the
shared runtime. Mutable values use `state()`, and `onDestroy` records route
teardown when Android Back or replace closes a screen.
Home also supplies the same two right navigation buttons as the iOS fixture,
so the native shell exercises the shared `rightButtons` contract while the
platform-specific iOS UI gate checks their floating geometry.
The scroll wrapper remains touch-enabled without a refresh handler; only its
pull-to-refresh interception is disabled, so nested horizontal carousels still
receive their own gestures.
The root overflow assertion also resolves the underlying `ScrollView` through
the wrapper rather than casting the `CraftNativeScrollView` test-ID host.
Pixel-sensitive gap assertions compare density-scaled points with a one-pixel
tolerance, so fractional Android densities do not turn correct native rounding
into a fixture failure.
The Android tab shell also defers swipe tracking at touch-down over a native
horizontal scroller and disallows ancestor interception for that sequence,
letting that child receive the complete gesture.
Horizontal scroll content is measured on an unbounded width axis, so an
explicitly wider carousel remains scrollable instead of collapsing to its
viewport width.
The host reapplies that axis after content-container style reconciliation, so
reactive style updates cannot silently turn the horizontal content back into a
bounded vertical flex column.
The native form coverage also keeps a keyed input's draft while changing its
single-line/multiline mode, recreating the incompatible platform control, and
the iOS fixture runs the same mode-transition and recycled-row assertions.
The image control also verifies that an explicit `null` tint style clears the
previous native color filter during an incremental update.
The shared name field is controlled, so its value and caret remain stable
while the native renderer applies each change on both hosts.
The style and accessibility checks wait for their mutation-driven status text
before inspecting the updated native control, so the fixture does not race the
asynchronous JavaScript-to-view reconciliation.
Native control events are asynchronous too; assertions that observe event-driven
status use `awaitText` rather than reading the view immediately after a platform
click, selection, slider movement, modal lifecycle callback, or a visual-property
update.
Test identities stay in Android view tags, leaving visible text available to
accessibility services unless a label or value is explicitly supplied.
Returning to a retained route reapplies native theme defaults before it becomes
visible, so a dark-mode change while another route is open cannot leave stale
colors behind.
CI uses `@stacksjs/stx` (`stx native compile`) pinned at
`1bb9d581d88517778b10333f57c2be41bae9fd0e`. For an unreleased sibling
checkout, set `STX_CLI=../stx/packages/stx/bin/cli.ts`; native support is part
of `@stacksjs/stx`, so do not install the historical `stx-native` package or
compiler. The compiler installs an initial tree atomically before sending
incremental keyed mutations.

`--prepare-only` compiles the `.stx` bundle and generates the Android fixture
without needing an emulator. Set `CRAFT_KEEP_ANDROID_NATIVE_PROJECT=1` to keep
the generated project for inspection. On an emulator failure, the test prints
the activity's native view tree and the harness dumps `CraftNativeAndroid`
errors from logcat.
