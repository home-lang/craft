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
rendered for the `Picker`, rendered route
parameters, push/replace/back (including Android's Back key), retained input
identity and value, text-input submission, and the absence of any `WebView` in
the activity view tree. Scroll callbacks are attached to the underlying Android
scroller rather than the native wrapper, so nested scroll offsets come from the
platform control that actually moves. The details `ScrollView` also exercises
the same swipe-to-refresh and keyed-row insertion path as iOS; the dedicated
`NativeFlatListTest` continues to cover recycling and virtualized row layout.

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
Test identities stay in Android view tags, leaving visible text available to
accessibility services unless a label or value is explicitly supplied.
Returning to a retained route reapplies native theme defaults before it becomes
visible, so a dark-mode change while another route is open cannot leave stale
colors behind.
CI uses `@stacksjs/stx` (`stx native compile`) pinned at
`b18eb551aefff100d2cad41192abd43de3fbd72d`. For an unreleased sibling
checkout, set `STX_CLI=../stx/packages/stx/bin/cli.ts`; there is no separate
`stx-native` package or compiler to install. The compiler installs an initial
tree atomically before sending incremental keyed mutations.

`--prepare-only` compiles the `.stx` bundle and generates the Android fixture
without needing an emulator. Set `CRAFT_KEEP_ANDROID_NATIVE_PROJECT=1` to keep
the generated project for inspection. On an emulator failure, the test prints
the activity's native view tree and the harness dumps `CraftNativeAndroid`
errors from logcat.
