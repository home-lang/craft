# WebView-free native navigation fixture

The three `.stx` screens and `native.config.json` exercise a native push with parameters, an in-app back action, UIKit's back button and edge-swipe, and replace. Home owns a keyboard-configured `TextInput`, `Picker`, `Checkbox`, date/time/countdown pickers, submit counter, counter, keyed `ScrollView`, a horizontal carousel whose swipe must take precedence over the tab shell, a network-free native `Video` mount (empty URI), a host-native `Icon`, and a DOM-free `svg` containing a grouped path and text node; the details list covers row moves, focused-input retention, insertion, empty content, and controlled pull-to-refresh. The native list unit fixture separately verifies virtualized `FlatList` scroll, drag, momentum, recycling, and refresh-control forwarding. Returning home must reveal the same values, not a freshly compiled screen. The simulator test also checks that the app exposes no WebView and that Icon/Video/SVG accessibility survives native mounting.

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
line distribution, including `space-evenly`, available through the shared
`alignContent` contract. The iOS host maps `space-evenly` to the shared code
before falling back locally, so the maintained fixture covers both paths.
The form path carries a keyed draft across a single-line/multiline input mode
change even though UIKit must replace the underlying control class. Keyed
ScrollView rows retain their drafts while the collection is reordered.
The UI gate locates the keyed row input relative to its row label and scrolls
controls into the root viewport before interacting, so unrelated fields and
screen-height changes cannot silently change which native control is tested.

From the Craft repository, with `@stacksjs/stx` available as `stx` (the
maintained CI checkout is pinned to
`9282a03eadb7ccc77ba17373adcda958761ef3aa`):

```bash
bun packages/ios/scripts/test-native-navigation.ts
```

The script invokes `stx native compile` from the shared `@stacksjs/stx`
repository and verifies that it emitted mutation-protocol support,
generates a temporary iOS app, boots an available simulator, and runs
`NativeNavigationUITests.swift`. CI pins the stx compiler commit and
runs the same script on iOS and Android. For an unreleased sibling checkout,
set `STX_CLI=../stx/packages/stx/bin/cli.ts`; native support is part of
`@stacksjs/stx`, so do not install the historical `stx-native` package or
compiler. The pinned compiler sends the initial tree as one atomic render,
then uses keyed mutations for later updates.

`--prepare-only` compiles the `.stx` bundle and generates the Xcode fixture
without requiring an installed or bootable simulator. Set
`CRAFT_KEEP_NATIVE_NAVIGATION_PROJECT=1` to keep the generated project for
inspection; the normal command remains the CI simulator gate.
