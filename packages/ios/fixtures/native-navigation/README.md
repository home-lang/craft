# WebView-free native navigation fixture

The three `.stx` screens and `native.config.json` exercise a native push with parameters, an in-app back action, UIKit's back button and edge-swipe, and replace. Home owns a keyboard-configured `TextInput`, `Picker`, submit counter, counter, and keyed `ScrollView`; the details list covers row moves, focused-input retention, insertion, empty content, and controlled pull-to-refresh. The native list unit fixture separately verifies virtualized `FlatList` scroll, drag, momentum, recycling, and refresh-control forwarding. Returning home must reveal the same values, not a freshly compiled screen. The simulator test also checks that the app exposes no WebView.

`testSharedRuntimePushBackReplaceLifecycleAndStateIsolation` is the focused
navigation gate. It uses the shared runtime's state and lifecycle APIs to verify
route parameters, retained home state, fresh state for every pushed details screen,
explicit and UIKit back behavior, replace stack semantics, and `onDestroy`
cleanup after both pop and replace. The shared runtime provides `craft`,
signals, and lifecycle hooks to ordinary client scripts; mutable values use
`state()` so bindings and route parameters observe the same live values.
Run only that acceptance path with:

```bash
CRAFT_NATIVE_NAVIGATION_TEST=testSharedRuntimePushBackReplaceLifecycleAndStateIsolation bun packages/ios/scripts/test-native-navigation.ts
```

Keyed row replacement releases the previous native root before the new row type
is hosted, so old event, image, and pull-to-refresh handlers cannot leak across
reuse. Both native hosts attach the details screen's `ScrollView` refresh
handler to the platform refresh control.
Returning to a retained route also reapplies native theme defaults before the
controller appears, keeping dark-mode colors current after navigation.
Keyboard frame changes update the controller's additional safe area, keeping the
focused form controls and their `onLayout` measurements responsive.
The fixture also exercises parent-relative percentage sizing and keeps wrapped
line distribution available through the shared `alignContent` contract.
The form path carries a keyed draft across a single-line/multiline input mode
change even though UIKit must replace the underlying control class. Keyed
ScrollView rows retain their drafts while the collection is reordered.

From the Craft repository, with the sibling stx checkout at or after
`6151b9e73c` (where the compiler became `stx native compile`):

```bash
bun packages/ios/scripts/test-native-navigation.ts
```

The script verifies that the compiler emitted mutation-protocol support,
generates a temporary iOS app, boots an available simulator, and runs
`NativeNavigationUITests.swift`. CI pins the stx compiler commit and
runs the same script on iOS and Android. Its external checkout is installed
with `bun install --no-save` because Pantry's Bun 1.3.14 cannot frozen-install
the pinned lockfile. The pinned compiler sends the initial tree as one atomic
render, then uses keyed mutations for later updates.

`--prepare-only` compiles the `.stx` bundle and generates the Xcode fixture
without requiring an installed or bootable simulator. Set
`CRAFT_KEEP_NATIVE_NAVIGATION_PROJECT=1` to keep the generated project for
inspection; the normal command remains the CI simulator gate.
