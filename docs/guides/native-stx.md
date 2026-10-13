# Native STX on iOS and Android

Craft's experimental `native` mobile renderer runs a compiled STX route bundle
without a browser view. iOS evaluates the bundle with JavaScriptCore and creates
UIKit controls. Android evaluates the same bundle with JavaScriptSandbox and
creates Android views. Native mode never creates `WKWebView` or `WebView`, and it
fails visibly when its bundle or JavaScript runtime is unavailable.

The default renderer remains `web`. Opting into native mode does not change an
existing web-rendered application.

## Build the same bundle for both platforms

Configure routes in `native.config.json`, then compile from the directory that
contains that file with the stx CLI:

```bash
stx native compile --format bundle --output ./native-screen.js

craft ios init MyApp --renderer native --output ./ios
craft ios build --output ./ios --native-bundle ./native-screen.js

craft android init MyApp --package com.example.myapp --renderer native --output ./android
craft android build --output ./android --native-bundle ./native-screen.js
```

Native mode does not accept a web distribution (`--html-path`) or a
development server (`--dev-server`). The bundle must be local at build time:
`--native-bundle`, or `nativeBundle` in the config, which `init` and every
`build` install as `dist/native-screen.js`. `devServerURL` in the config is
still allowed: in native mode it names the app's site (see below).

## Native script and lifecycle semantics

The native compiler runs each route's client script through the shared stx
signals runtime. Use `state`, `derived`, and `effect` in ordinary `<script>`
blocks; bindings update native controls through the mutation protocol. Native
scripts also receive the `globalThis.craft` route, navigation, storage, and
capability APIs from the host.

The maintained Mobile E2E workflow checks out one exact stx compiler commit for
both simulator hosts. Update the iOS and Android refs together; the workflow
contract test rejects compiler skew between them.
The current pair is pinned to `78c6b5759588c9f2c12827e92e370e707d4d9dbc`,
which carries ordinary native event aliases and preserves Modal child content.

The host-neutral layout contract lives in Craft's Zig runtime at
`packages/zig/src/native_layout.zig`. It defines the shared row/column flex
and equal-track grid rules for basis, positive growth, negative shrink, gap,
per-edge margins, parent padding, min/max bounds, row/column gaps, justification,
and cross-axis alignment while leaving intrinsic measurement (especially text) to
the platform host. UIKit and Android adapters must preserve these values when
mounting the resulting frames; platform-specific measurement must not fork the distribution rules.

Use `onMount` and `onDestroy` for route-scoped lifecycle work. Craft disposes
the screen runtime before a native screen is removed or replaced, so effects,
capability requests, and registered cleanup callbacks do not leak into the
next route.

## Current component contract

| STX primitive | iOS | Android |
| --- | --- | --- |
| `View`, `SafeAreaView` | `CraftNativeFlowView` | `CraftNativeFlexLayout` (a `LinearLayout`) |
| `KeyboardAvoidingView` | `CraftNativeKeyboardAvoidingView` | `CraftNativeKeyboardAvoidingView` |
| `Text` | `UILabel` | `TextView` |
| `Button` | `UIButton` | `Button` |
| `Link` | underlined `UIButton` | underlined clickable `TextView` |
| `Pressable`, `TouchableOpacity`, `TouchableHighlight` | `CraftNativeFlowView` | `CraftNativeFlexLayout` |
| `TextInput` | `UITextField` | `EditText` |
| `Checkbox` | `UIButton` with system checkbox symbols | `CheckBox` |
| `Picker` | `UIPickerView` | `Spinner` |
| `DatePicker` | `UIDatePicker` | `DatePicker` / `TimePicker` |
| `Modal` | `CraftNativeModalView` | `CraftNativeModalView` (`FrameLayout`) |
| `Switch` | `UISwitch` | `Switch` |
| `Slider` | `UISlider` | `SeekBar` |
| `ActivityIndicator` | `UIActivityIndicatorView` | `ProgressBar` |
| `Icon` | `CraftNativeIconView` (`UIImageView`) | `CraftNativeIconView` (`TextView`) |
| `Image` | `UIImageView` | `ImageView` |
| `ImageBackground` | `CraftNativeImageBackgroundView` | `CraftNativeImageBackgroundView` |
| `Video` | `CraftNativeVideoView` (`AVPlayerViewController`) | `CraftNativeVideoView` (`VideoView`) |
| `Svg` | `CraftNativeSvgView` | `CraftNativeSvgView` |
| `G`, `SvgText` | drawn inside `CraftNativeSvgView` | drawn inside `CraftNativeSvgView` |
| `ScrollView` | `UIScrollView` | `ScrollView` or `HorizontalScrollView` |
| `SectionList` | `UIScrollView` (slot fallback) | `ScrollView` or `HorizontalScrollView` (slot fallback) |
| `FlatList` | `UICollectionView` | `RecyclerView` |

On iOS, `CraftNativeFlowView` remains a `UIStackView` subclass for source and
accessibility compatibility while supplying the shared wrapping and positioning
rules; Android keeps the corresponding `LinearLayout` compatibility surface.
Both native hosts follow the configured `appearance` (`system`, `light`, or
`dark`) and reapply theme-default controls when the system trait changes without
recreating the screen. When `appearance` is omitted, the legacy `darkMode`
boolean pins the host for compatibility. On Android, set `backgroundColorDark`
to let the generated Material DayNight theme swap the native background when
the system enters night mode; iOS resolves the same color dynamically.
Both generated hosts keep native content inside platform safe-area insets,
including Android system bars and display cutouts.
CI also checks the host-neutral component and fallback contract against both
generated renderers, so a platform can’t silently lose a native primitive.

`Switch` accepts the shared `trackColor` object (`false` and `true` states) and
`thumbColor`; iOS also honors `ios_backgroundColor` for the off-state track.
`Slider` accepts `minimumTrackTintColor`, `maximumTrackTintColor`, and
`thumbTintColor` on both hosts, with `step` snapping values before events are
delivered.
`Button.color` and `Link.color` set the native action-label color;
`style.color` remains the shared fallback when either prop is omitted.
`Pressable`, `TouchableOpacity`, and `TouchableHighlight` are native flow
containers with `onPress`/`onClick`, long-press, and disabled handling; disabled
containers block both press and long-press callbacks on both hosts.
`Picker` renders option children from `<select>`/`<option>` or the native
primitive, accepts `value`/`selectedValue`, and sends the selected option's
`value` plus `index` through `onValueChange` or `onChange`.
`Checkbox` accepts `checked`/`value`, `indeterminate`, and `disabled`, and
delivers a boolean `nativeEvent.value` through `onValueChange` or `onChange`.
An indeterminate checkbox is announced as `mixed` and becomes checked or
unchecked on the next user toggle.
`ImageBackground` uses the shared image source and load/error lifecycle while
mounting ordinary native children in a flex container over the image. Its
`resizeMode` follows the same `cover`, `contain`, `stretch`, and `center`
semantics as `Image`.
`KeyboardAvoidingView` responds to the native keyboard/IME inset. Its
`behavior` may be `padding`, `position`, or `height`, and
`keyboardVerticalOffset` subtracts from the overlap on both hosts.
`DatePicker` accepts `mode` (`date`, `time`, `datetime`/`datetime-local`, or
`countdown`), `value`, `minimumDate`, `maximumDate`, `minuteInterval`, and
`disabled`. Its `onValueChange`/`onChange` event includes a local `value`, an
ISO timestamp, and the Unix `timestamp` in milliseconds on both native hosts.
Countdown values are durations: numeric values are seconds and text values use
`HH:mm` or `HH:mm:ss`; their event value is always `HH:mm:ss`, `iso` is an
ISO-8601 duration such as `PT5400S`, and `timestamp` is the duration in
milliseconds. Native countdown controls clamp values to `23:59:59`.
`Modal` is parent-scoped: `visible` controls a native blocking layer around its
children, `transparent` removes the dimming scrim, and hidden modals do not
participate in layout or touch handling. `animationType` accepts `none`,
`fade`, or `slide`; `slide` enters from and exits toward the bottom edge on
both hosts. `onShow` and `onDismiss` fire on visibility transitions,
and `onRequestClose` fires when Android back or the modal blocker requests a
close. The default WebView renderer remains unchanged.
`Text` supports positive `numberOfLines` values and `ellipsizeMode` (`head`,
`middle`, `tail`, or `clip`) on both hosts; omitting the line count keeps the
label intrinsically multiline.
`ActivityIndicator` accepts `color`, `animating`, `hidesWhenStopped`, and
`size` (`small`, `large`, or a numeric point/unit value). The native host keeps
the indicator visible when animation is stopped only when `hidesWhenStopped` is
false; shared `display: 'none'` still takes precedence on both hosts.
`Image.alt` supplies the native accessibility label when an explicit
`accessibilityLabel` is not provided.

`Icon` is a native leaf with the shared `symbol`/`name` contract. iOS draws
SF Symbols through `UIImageView`; Android uses the maintained dependency-free
glyph map and renders an outlined circle for symbols it does not recognize.
Both hosts preserve the authored size, color, and accessibility metadata, and
neither creates a DOM or WebView fallback for an icon.

`Video` uses the platform player in native mode. Its `source` accepts a URI
string or `{ uri }`, while `autoplay`/`autoPlay`, `paused`, `loop`, `muted`,
`controls`, and `resizeMode` configure playback without creating a DOM video
element. The native player is stopped when its node is removed or replaced;
unsupported or empty sources remain inert instead of falling back to a WebView.

Native screens have Web Audio: the standard `AudioContext` API, so code
written for a page (synthesised music, breath tones, filtered noise) runs
unchanged. On iOS (`CraftWebAudio.swift`) that is `AudioContext`
(`currentTime`, `sampleRate`, `state`, `resume()`/`suspend()`/`close()`,
`statechange`), `AudioParam` (`value`, `setValueAtTime`,
`linearRampToValueAtTime`, `exponentialRampToValueAtTime`, `setTargetAtTime`,
`setValueCurveAtTime`, `cancelScheduledValues`, `cancelAndHoldAtTime`, and a
node connected into a param), `GainNode`, `OscillatorNode` (sine, square,
sawtooth, triangle, `frequency`, `detune`), `AudioBuffer` and
`AudioBufferSourceNode` (`loop`, `loopStart`/`loopEnd`, offset, duration,
`playbackRate`, `detune`), `BiquadFilterNode` (all eight types),
`DelayNode` (in a feedback cycle too), `DynamicsCompressorNode` and
`ConvolverNode` (with the spec's normalisation), `connect()`/`disconnect()`,
`start()`/`stop()` and `onended`.

The graph renders in 128-frame quanta, as the spec describes, inside one
`AVAudioSourceNode` per context on the screen's `AVAudioEngine`; a step
sequencer's short-lived nodes are freed once the script lets go of them
(`FinalizationRegistry`) and they can no longer sound. The convolver runs its
first 512 taps directly and the rest as partitioned FFT convolution, so it adds
no latency. Approximations, inaudible for synthesis: square and sawtooth are
PolyBLEP band-limited rather than wavetables, a biquad takes its coefficients
once per quantum, the compressor has no look-ahead, and a 4-channel impulse
response uses its first two channels. The session is `.ambient`, mixing with
other audio and muted by the silent switch, as a web view's Web Audio is.
`decodeAudioData` refuses: play a file with `craft.audio`. Android still mixes
only oscillators and gains through `AudioTrack`. Both hosts tear the graph down
with the screen.

`Svg` is DOM-free in native mode: the compiler emits geometry commands for
shape nodes, `G` inherits fill/stroke paint, and `SvgText` draws text in the
same viewBox. Both hosts preserve inherited opacity, fill/stroke colors, line
caps, joins, and dash patterns; the iOS host applies those styles to each
`CGPath` before stroking. An SVG string that requires DOM APIs remains a WebView
concern.

`key` is scoped to sibling nodes. `testID` is also accepted as an identity for
existing screens. Unkeyed children reconcile by position. A rerender updates an
existing native control when its identity and type are unchanged, preserving
input focus, selection, draft text, and scroll objects. Duplicate sibling keys
fall back to positional identity rather than attaching state to the wrong view.

## Incremental update protocol

Generated native hosts advertise `mutationProtocolVersion: 1` on
`globalThis.__stxNativeBridge`. A current `stx native compile` bundle uses `MUTATE`
batches when that value is present and continues to send the original
whole-document `RENDER` message to older hosts. If a host rejects a mutation
batch, the bundle resynchronizes with `RENDER`, so a bundle can run against
both generations of Craft.

Every batch has one protocol version, a non-empty identifier, consecutive
revisions, and at least one operation:

```json
{
  "type": "MUTATE",
  "payload": {
    "version": 1,
    "batchId": "screen-4",
    "baseRevision": 3,
    "revision": 4,
    "operations": [
      {
        "op": "updateNode",
        "id": "root/key:counter",
        "patch": { "children": ["Count: 4"] }
      }
    ]
  }
}
```

Version 1 supports these operations:

| Operation | Required fields | Effect |
| --- | --- | --- |
| `createNode` | `id`, `node`; optional `root` | Creates a detached node, or the document root when `root` is `true` |
| `updateNode` | `id`, `patch` | Replaces supplied `props`, `style`, `events`, or text `children` fields |
| `insertChild` | `parentId`, `childId`, `index` | Attaches a detached node to a container |
| `moveChild` | `parentId`, `childId`, `index` | Reorders a child within its current parent |
| `removeNode` | `id` | Removes the node and its descendants |

`View`, `SafeAreaView`, `ScrollView`, and `SectionList` are the container node types. Node
children in `createNode` and `updateNode` may contain text only; node
relationships use `insertChild`. Indexes are zero-based and may equal the
current child count when inserting or moving to the end.

The host validates the complete batch against a copy of its retained tree. It
commits and advances the revision only if every operation succeeds, then sends:

```json
{
  "type": "MUTATION_ACK",
  "payload": { "version": 1, "batchId": "screen-4", "revision": 4 }
}
```

Malformed or stale batches leave both the native view tree and revision
unchanged. The reply is `MUTATION_ERROR` with `version`, `batchId`, `code`,
`message`, and, when an operation failed, its zero-based `operationIndex`.
Error codes are deterministic across iOS and Android: `INVALID_BATCH`,
`UNSUPPORTED_VERSION`, `REVISION_MISMATCH`, `INVALID_REVISION`,
`INVALID_OPERATION`, `UNKNOWN_OPERATION`, `INVALID_NODE`, `DUPLICATE_NODE`,
`ROOT_EXISTS`, `INVALID_PATCH`, `UNKNOWN_PARENT`, `UNKNOWN_NODE`,
`INVALID_PARENT`, `NODE_ATTACHED`, `CYCLE`, `INVALID_INDEX`, `NOT_A_CHILD`, and
`MISSING_ROOT`, and `INVALID_TREE`. A successful batch must leave every node
reachable from its single, unattached root.

Stable node IDs are derived from sibling-scoped `key` values, with `testID`
accepted for existing screens and position used as the fallback. Updating a
node keeps its native object, event bindings, accessibility metadata, input
focus and selection. Structural operations reconcile the affected parent
subtree and preserve unrelated controls and scroll views. Root replacement is
the only mutation path that intentionally performs a full native render.

The shared style subset is deliberately smaller than the public `ViewStyle`
type:

- numeric or percentage `width`, `height`, `minWidth`, `maxWidth`, `minHeight`,
  and `maxHeight` (percentages resolve against the parent's content box);
- `flexDirection` (`row`, `column`, and their reverse forms), `alignItems`,
  `alignSelf`, `justifyContent`, `flexWrap: 'wrap'`, `gap`, `rowGap`, and
  `columnGap`;
- `flex`, `flexGrow`, `flexShrink`, and numeric or percentage `flexBasis` distribute
  remaining or overflowing main-axis space per flex line while preserving
  gaps and margins;
- wrapped containers support `alignContent` (`flex-start`, `center`,
  `flex-end`, `space-between`, `space-around`, and `stretch`) for cross-axis
  line distribution;
- `display: 'grid'` with equal tracks from numeric `gridTemplateColumns` (or
  CSS-shaped `repeat(N, 1fr)` text), plus numeric `gridAutoRows`; grid children
  fill their track by default, pack in source order, and honor `alignSelf`,
  `columnGap`, and `rowGap`;
- `position: 'relative'` (the default) and `position: 'absolute'` with numeric
  `top`, `right`, `bottom`, and `left` insets;
- `padding`, its four side properties, `paddingHorizontal`, and
  `paddingVertical`;
- `backgroundColor`, `opacity`, `borderWidth`, `borderColor`, `borderRadius`,
  `overflow: 'hidden'`, and `display: 'none'`;
- for text: `color`, `fontFamily`, `fontSize`, `fontStyle`, `fontWeight`,
  `letterSpacing`, `lineHeight`, `textAlign`, `textDecorationLine`, and
  `textTransform`;
- for images: `resizeMode` (`contain`, `cover`, `stretch`, or `center`) and
  `tintColor` for template rendering.

`textTransform: 'capitalize'` uppercases the first character of each
space-delimited word while preserving the remaining characters on both hosts.
`textAlign: 'justify'` uses UIKit justification on iOS and inter-word
justification on Android when the platform API supports it.
Explicit `null` image style values are treated as unset, so a prop-level
`resizeMode` remains effective during reconciliation.

Colors use platform color syntax; hexadecimal colors are portable. Dimensions,
spacing, and font sizes are points on iOS and density-independent units on
Android. Both hosts use the same line-breaking, gap, min/max clamping, percentage
resolution, wrapped-line distribution, absolute inset, grid-track, and
stretch/center/flex-end rules; text and image intrinsic
sizes are measured by the host-native control, and `Button`/`Link` text uses the
same font, color, alignment, and decoration styles as `Text`. Generated hosts
pin the native screen root to the platform safe-area insets. Transforms and
shadows remain outside the native renderer
contract. Unsupported values are ignored rather than interpreted as CSS. Explicit `null`
layout values, including `alignSelf` and `position`, clear the previous value
and restore the host default during reconciliation.

When the Craft Zig runtime is linked, the mobile hosts use its flat
`craft_native_flex_row` ABI for one-line main-axis distribution and
`craft_native_flex_line_breaks`/`craft_native_flex_line_distribution` for wrapped
lines, plus `craft_native_cross_axis_position` for each item's cross-axis
alignment. These ABIs carry only plain numeric data—never UIKit or Android
types—so an SDK-only project can keep the equivalent host fallback until a
runtime is installed.

The same host-neutral layout core models a complete tree's main-axis
`justifyContent` distribution (`flex-start`, center, `flex-end`,
`space-between`, `space-around`, and `space-evenly`) for deterministic parity
tests. Cross-axis `alignItems` and per-child `alignSelf` use the same
host-neutral rule, including the default stretch behavior. Intrinsic text and
image measurement remains a host responsibility; the shared rule consumes
those measurements as numeric bases. Wrapped flex trees form lines from the
same numeric bases, distribute free cross-axis space, and then recurse into
each child without importing a host view type. `alignContent` controls that
line distribution with the same start, center, end, between, around, and
stretch options used by the mobile hosts. Grid rows use the same cross-axis
alignment rule, so a shorter child is centered or end-aligned inside an
intrinsically measured row instead of being forced to its top edge.

The same runtime also exports `craft_native_grid` for equal-track grids. It
accepts intrinsic measurements and alignment as plain data, leaving platform
views responsible only for measurement and mounting; hosts may fall back to
their local grid path when no runtime is linked. Both bridges reject
non-finite widths, positions, and frames from a malformed runtime payload and
take that same local fallback, so one bad value cannot poison native layout.

Scroll content is measured with an unbounded scroll-axis constraint, so intrinsic
text and image sizes contribute to the content extent instead of collapsing to
zero when the viewport supplies an unspecified size.

Views also support `onLayout`. The host calls it after the first native layout
and again only when that view's frame changes (including safe-area, rotation, or
responsive-size changes). The callback receives
`{ layout: { x, y, width, height } }`, measured in the view's parent coordinate
space. Values are points on iOS and density-independent units on Android;
removing a node removes its pending layout callback as well.
On iOS, keyboard frame changes are folded into the controller's additional safe
area while a native input is focused, so the same measurement contract updates
as the keyboard animates and returns to the original inset when it hides.

## Images and scrolling

Use `{ uri: value }` for an image source. Data-image URIs and HTTPS URLs work on
both platforms. A source with no URI scheme resolves from the iOS asset catalog
or Android app assets, so the asset must be packaged separately under the same
name for a shared bundle. Plain HTTP, file URLs, and other schemes are rejected.
Invalid data, missing bundled images, failed HTTPS downloads, and unsupported
schemes clear stale pixels, log a diagnostic, and expose a short accessibility
error value. That value remains stable when the native node is reconciled again;
it is not appended repeatedly. `onLoadStart`, `onLoad`, and `onLoadEnd` report the image lifecycle;
`onError` receives `nativeEvent.error.message` for failures. Route teardown and
node removal cancel outstanding downloads.

`ScrollView` uses `horizontal` (or a row flex direction) to choose its axis and
renders its children as native views. `scrollEnabled`, the platform scroll
indicators, and nested scrolling are native; Android forwards the nested-scroll
setting to its underlying platform scroller rather than shadowing the wrapper's
view API. `pagingEnabled` snaps `ScrollView` content to viewport-sized pages on
both hosts. `onScroll` reports
`contentOffset`, `contentSize`, and `layoutMeasurement`; `onScrollBeginDrag`
and `onScrollEndDrag` report the corresponding gesture boundaries.
`keyboardShouldPersistTaps` accepts `"never"` (the default), `"always"`, or
`"handled"`; it controls whether taps inside a scroll host dismiss the active
keyboard, preserving taps on native controls for the handled mode. The same
policy applies to `FlatList`, which inherits the scroll props.
`onMomentumScrollBegin` and `onMomentumScrollEnd` report the native deceleration
interval. `FlatList` forwards the same scroll, drag, and momentum callbacks from
its virtualized collection or recycler host, including the same
`contentOffset`, `contentSize`, and `layoutMeasurement` payload. `FlatList` now
accepts `onRefresh` and controlled
`refreshing`; pull-to-refresh is backed by UIKit's `UIRefreshControl` on iOS and
AndroidX `SwipeRefreshLayout` on Android. Use
`ScrollView` for bounded content and `FlatList` for data sets that need
recycling. `SectionList` currently follows the same native scroll host as
`ScrollView` for ordinary `.stx` slot children; grouped, virtualized section
data should use `FlatList` until the section-data protocol is added.

## Recycling lists

`FlatList` compiles a keyed item template into retained native rows. iOS uses a
diffable `UICollectionView` data source; Android uses `RecyclerView`, stable
IDs, and `DiffUtil`. Inserts, updates, moves, and removals reuse unaffected rows
instead of rebuilding the list. Visible text inputs retain their draft, focus,
accessibility metadata, and event handlers, and keyed updates retain the
viewport anchor. The simulator and emulator suites exercise this contract with
10,000 rows without materializing the full data set.

```stx
<script>
let people = [{ id: 'ada', name: 'Ada' }, { id: 'grace', name: 'Grace' }]

function loadMore() {
  // Guard duplicate requests while an asynchronous load is in flight.
}
</script>

<FlatList
  data={people}
  keyExtractor={item.id}
  numColumns={2}
  onEndReached={loadMore}
  onEndReachedThreshold={0.2}
>
  <Text listRole="header">People</Text>
  <View listRole="item" accessibilityLabel={item.name}>
    <Text>{index}: {item.name}</Text>
  </View>
  <View listRole="separator" style="height: 1" />
  <Text listRole="empty">Nobody here</Text>
  <Text listRole="footer">End of people</Text>
</FlatList>
```

The item template can reference `item` and its zero-based `index`.
`keyExtractor` must produce a stable, unique value; moving an item with the
same key keeps its native row state. `horizontal`, `inverted`, and
`numColumns` select the native layout. `numColumns` applies to vertical lists;
header, separator, empty, and footer content span every column. Empty content
is shown only when the data set has no items. Separator content is inserted
between item rows, never before the first or after the last.

`onEndReachedThreshold` is the fraction of data rows allowed to remain when
`onEndReached` fires. Header, separator, empty, and footer nodes do not count
toward the threshold and a chrome-only list does not fire it. A given content
signature fires at most once, but appending data creates a new signature and
may fire again if the viewport is still within the threshold; handlers should
therefore guard concurrent pagination requests.

Item rows participate in the same layout contract as ordinary views. Put an
`onLayout` handler on the `listRole="item"` root to receive measurements for
each materialized row; the callback runs when a row is laid out or its frame
changes after recycling, safe-area, orientation, or responsive-size updates.
Rows that are not materialized do not produce layout events until they become
visible, and recycled rows keep their keyed handler association.

For backward compatibility, a `FlatList` without a `listRole="item"` template
keeps its existing static children. Older compiled bundles also continue to
use whole-document `RENDER`; the native host accepts both that path and the
incremental mutation protocol.

When a keyed node changes its native type during reconciliation, the host
creates a control of the new type instead of reusing an incompatible view. This
keeps a `Button` changed to a `Link` (or another component class) from retaining
the old control's traits, listeners, or accessibility behavior.

## Events, accessibility, and navigation

`defaultValue` initializes an uncontrolled `TextInput` once; controlled
`value` continues to win on later renders without replacing the user's draft
when it is omitted. `onPress` and `onClick` deliver an empty `nativeEvent` from buttons and other
pressable native views. `onLongPress` fires once after the native long-press
gesture begins and also delivers an empty `nativeEvent`; removing the handler
releases the platform gesture recognizer. `TextInput` accepts `onChange` or `onChangeText` and
delivers `nativeEvent.text`; `onFocus`, `onBlur`, `onEndEditing`, and
`onSubmitEditing` are also native events and include the current text when
the event applies to a `TextInput`. `keyboardType`, `returnKeyType`,
`autoCapitalize`, `autoCorrect`, `secureTextEntry`, `editable`, and `autoFocus`
map to the platform input control. `placeholderTextColor`, `selectionColor`,
positive `maxLength`, `multiline`, and `numberOfLines` values are applied on
both hosts, including keyboard and return-key traits on multiline inputs. Shared text styles (`color`, `fontSize`, `fontFamily`, `fontWeight`,
`fontStyle`, `textAlign`, `letterSpacing`, and `lineHeight`) also apply to
native text inputs. When `fontSize` is omitted, text uses the shared 16-point
default on both hosts. Configuration changes are applied only when
their values change, so state reconciliation preserves the focused field and
its keyboard; UIKit text inputs retain their dynamic accessibility value unless
an explicit `accessibilityValue` prop overrides it. The host also restores the first responder around synchronous
native event callbacks and after a native tree reconciliation on the main UI
thread. The host keeps a weak anchor to the last focused field so a control
callback restores focus after dispatch and schedules a short delayed main-queue
handoff after UIKit finishes the touch, even if UIKit temporarily clears first
responder status while dispatching the event. `FlatList` supports `onEndReached`.
`ScrollView` and `FlatList` emit the scroll callbacks described above, accept
`bounces`, `alwaysBounceVertical`, and `alwaysBounceHorizontal` to control the
platform overscroll effect, and accept
`keyboardDismissMode="on-drag"` or `"interactive"`; omitting it keeps the
keyboard open while scrolling.

Removing `placeholderTextColor` or `selectionColor` from a reused `TextInput`
restores the platform theme default on both hosts instead of retaining the
previous native color.

Changing a keyed `TextInput` between single-line and `multiline` mode recreates
the platform control when its native class or mode is incompatible, while the
reconciler carries forward the current draft value.

Android handles `uiMode` changes in place: the active native document is
reconciled against the new DayNight resources, so theme-default text colors,
safe-area insets, and focused input state survive a light/dark transition.
On iOS, `traitCollectionDidChange` performs the same reconciliation so system
label/tint colors and native accessibility traits follow the new appearance.

`accessibilityLabel`, `accessibilityHint`, `accessibilityValue`,
`accessibilityState`, and `accessibilityRole` map to native accessibility
metadata and traits. The portable roles are `button`, `image`, `header`,
`link`, `search`, and `none`; unknown roles retain the platform control's
native class. `accessibilityState` supports `disabled`, `selected`, and
`checked`.

These fields are part of the exported `BaseProps`/`TextInputProps` types, so a
shared screen can keep its accessibility and keyboard contract type-safe before
it is compiled for either native host.

`craft.navigation.push`, `replace`, and `back` use the platform navigation
stack. A pushed route receives `craft.route.params`; returning to an earlier
route reveals its existing native tree and JavaScript state. Native events are
delivered only to the top route, and route teardown removes its subscriptions
and cancels its in-flight requests. On iOS, a native screen that contains a
horizontal `ScrollView` keeps the navigation back-swipe at the 32-point edge;
swipes across the pager, carousel, or chart remain available to that scroll
view.

## An all-native iOS app: paths, tabs and an app script

On its own, `renderer: "native"` is one screen and the stack it pushes. Add
`nativeScreens` (and, optionally, `tabs`) and the app gets the same shell a
hybrid app has (tab stacks, path routing, deep links) with no web view at
all: no `WKWebView` is ever created.

```json
{
  "renderer": "native",
  "devServerURL": "https://hq.training/m",
  "nativeScreens": {
    "/m": "Today",
    "/m/calendar": "Calendar",
    "/m/workout/:id": "Workout"
  },
  "tabs": [
    { "id": "/m", "title": "Today", "symbol": "sun.max" },
    { "id": "/m/calendar", "title": "Calendar", "symbol": "calendar" }
  ],
  "nativeBundle": "./native-screen.js",
  "nativeApp": "__app"
}
```

- `devServerURL` is the app's site. Its path is the path the app starts on
  (`/` without one), and the bundle reads it as `__stxNativeBridge.appURL`.
- Every tab id and the start path must be drawn by a native screen; `init` and
  `build` refuse the config otherwise, because there is no web view to fall
  back to.
- `craft.navigation.open(path)` opens a tab (switching to it), a native screen
  (pushed onto the visible tab, or popped back to if it is already in the
  stack), or, for a path no screen draws, the in-app browser
  (`SFSafariViewController`) at that path on the site's origin. A full `http(s)`
  address on the site's host is treated as its path; one on any other host
  opens in the in-app browser. With no `devServerURL`, a path no screen draws
  is logged and ignored.
- A deep link to a native path opens its screen in the tab that owns it. A
  universal link to the site's host that no screen draws opens in the in-app
  browser. Anything else reaches the screens as `DEEP_LINK`. A link that
  launched the app waits for the shell.
- Tab taps switch stacks natively. A screen that throws before its first frame
  keeps its own error, since there is no page to stand in for it.
- GPS (fixes, watches, the background route recorder and its relaunch
  restore) and Apple Music work here too: the app holds the web view's service
  coordinator without a web view, so `geolocation` and `music` are among the
  capabilities whenever `enableGeolocation` / `enableAppleMusic` are set. The
  single-screen native app (no `nativeScreens`) gets them as well.

### The app script (`nativeApp`)

`nativeApp` names a bundle route that has no screen (Stacks names it `__app`).
It runs once for the app's whole life, in its own JavaScriptCore context,
beside the screens, in a hybrid app or a native one. It is loaded after the
first screen's first frame is committed, so it never delays it. If background
work (a silent push or a background refresh) is waiting for it, it is loaded
at once instead, because a launch in the background draws no frame. Otherwise
it is loaded 1.5 seconds after launch at the latest.

- It gets every `APP_STATE`, not only while on top of a stack, and no
  `DEEP_LINK`.
- The app's events go to it instead of to the page, as the bridge message
  `CRAFT_EVENT { event, detail }`, which the stx runtime dispatches as a
  `CustomEvent` on the script's global: `craftNotificationResponse`,
  `craftNotificationReceived`, `craftSilentPush`, `craftBackgroundRefresh`,
  `craftShortcut` and `craftSiriShortcut`. Events that arrive before it has run
  its bundle (a notification tap that launched the app) are held and delivered
  in order once it has. Without an app script they go to the page as before;
  an all-native app with neither logs and drops them, and answers any
  background work at once.
- `craft.navigation.open(path)` opens in the shell as above, so
  `craft.navigation.open('/m/workout/5')` opens that screen in the visible tab
  and a tab path switches tabs. Opens made before the shell exists are held
  for it. `push`, `replace`, `back`, `popToRoot`, `setOptions` and
  `tabBarHidden` do nothing: it has no stack and no bar.
- A failure while loading is logged; nothing falls back.
- It answers background work with `craft.background.complete(ok, id?)`: the
  `Background.complete` capability with args `[ok, id?]` (no id finishes
  everything pending). The `background` capability is present when
  `backgroundRefresh.enabled` or `enablePushNotifications` is set. The `id`
  comes in the `craftSilentPush` / `craftBackgroundRefresh` detail; iOS is
  answered by itself after 25 seconds.

```js
addEventListener('craftNotificationResponse', (event) => {
  if (event.detail.path) craft.navigation.open(event.detail.path)
})
addEventListener('craftSilentPush', async (event) => {
  const ok = await sync().then(() => true, () => false)
  craft.background.complete(ok, event.detail.id)
})
```

### What every screen knows of the app

`__stxNativeBridge` carries `appURL` (the `devServerURL`, or `""`),
`appVersion` (`CFBundleShortVersionString`) and `appBuild`
(`CFBundleVersion`), beside `platform`, `capabilities`, `initialAppState` and
`colorScheme`.

### Snapshots

`craft.snapshots.get(name)` (sync) and `craft.snapshots.set(name, value)` (a
promise) read and write `Application Support/craft-snapshots/<name>.json`, the
same files a hybrid page's snapshots use. `craft.snapshots.clear(keep?)` (a
promise) deletes every snapshot except the names in the optional `keep` array,
for a sign-out: `await craft.snapshots.clear(['app'])`. Every removal reaches
every screen as `SNAPSHOT_CHANGED`. The host functions survive the runtime
assigning its own `craft.snapshots` object; a key the runtime defines itself
wins.

## Capability bridge

The generated iOS and Android hosts advertise a versioned capability bridge on
`globalThis.__stxNativeBridge`:

```ts
globalThis.craft.platform // 'ios' or 'android'
globalThis.craft.capabilityProtocolVersion // 1
globalThis.craft.capabilities.storage // true when enabled
globalThis.craft.capabilities.secureStorage // true when enabled
globalThis.craft.capabilities.biometric // true when enabled
```

The shared asynchronous surface is:

```ts
await craft.storage.set('profile', { name: 'Ada' })
const profile = await craft.storage.get('profile')
await craft.db.execute('CREATE TABLE IF NOT EXISTS notes (text TEXT)')
const notes = await craft.db.query('SELECT text FROM notes')
await craft.db.beginTransaction()
await craft.db.commit() // or await craft.db.rollback()

const stopState = craft.lifecycle.onStateChange((state) => console.log(state))
const state = craft.lifecycle.getState() // synchronous current state
const initial = await craft.deepLinks.getInitialURL()
const stopLinks = craft.deepLinks.onLink((link) => console.log(link.url))
const id = await craft.notifications.schedule({ title: 'Reminder', delay: 60_000 })
await craft.notifications.cancel(id)

const photo = await craft.files.pickImage({ source: 'library' })
const form = new FormData()
form.append('photo', photo)
const upload = await fetch('https://api.example.com/upload', {
  method: 'POST',
  body: form,
})
const exportFile = await craft.files.write('route.csv', 'name,distance\nLoop,5', { type: 'text/csv' })
await craft.files.remove(exportFile.path)

await craft.secureStorage.set('session-token', 'secret')
const token = await craft.secureStorage.get('session-token')
await craft.secureStorage.delete('session-token')
const available = await craft.biometrics.isAvailable()
const biometricType = await craft.biometrics.getBiometricType()
if (available) await craft.biometrics.authenticate('Unlock WildLoop')
```

Storage is JSON-serializable and survives process termination. SQLite is stored
in the app's persistent data directory and supports typed string, number,
boolean, and null parameters. `execute` resolves to `{ rowsAffected,
lastInsertId }`; transaction methods resolve to `true` on success. Local
notification schedules are persisted by the OS on iOS and through
`AlarmManager` on Android, so they do not depend on a running JavaScript
process. The Android receiver is registered only for native-renderer projects.

`enableLocalDatabase`, `enableLocalNotifications`, and `enableDeepLinks` are
explicit configuration gates. `enableSecureStorage` and `enableBiometric` gate
the corresponding secure-storage and biometric methods. Secure storage accepts
string values and persists them in the iOS Keychain or Android encrypted
preferences; a missing key resolves to `null`. Biometric availability is a
device check, so an enabled simulator or emulator may still report `false`.
A disabled or unavailable capability rejects with
`CAPABILITY_DISABLED` or `NOT_SUPPORTED`; malformed keys, SQL, or notification
arguments reject with `INVALID_ARGUMENT`. Every request has a 30-second native
deadline. A timeout rejects with `TIMEOUT`, sends `API_CANCEL`, and native route
teardown cancels any remaining work. Unsupported protocol versions reject with
`UNSUPPORTED_VERSION`.

`deepLinks.getInitialURL()` claims the launch URL once for the native app
process. It can be called from any route, but later routes receive `null`; a
URL delivered through `deepLinks.onLink` is marked `initial: true`. URLs received
through a resumed activity or scene are marked `initial: false` and remain
available to subscribers even after the launch URL has been claimed. Android
persists the launch claim across activity recreation, so rotation and process
handoff do not replay a stale intent.

The old flat notification methods (`scheduleNotification`,
`cancelNotification`, `cancelAllNotifications`, and `getPendingNotifications`)
remain available as aliases. Existing device info, clipboard, haptics,
mutation, and legacy web-renderer behavior are unchanged. To migrate a web
screen, keep the existing `craft-native/mobile` calls and use the nested
capability methods only where persistence or native lifecycle behavior is
needed; browser-rendered apps continue using their existing web fallbacks.

The `files` capability keeps picked, downloaded, and generated files in an
app-owned temporary directory that survives Activity recreation; stale entries
are swept after a day. `craft.files.remove` rejects paths outside that
directory. When the host advertises `files`, its `FormData`
implementation accepts text fields and those file descriptors;
`Network.fetch` assembles the multipart body natively, so file bytes do not
pass through JavaScriptCore as base64. Without that capability, native
`FormData` is not installed and the text-only fetch contract below remains
unchanged. `craft.files.download` resolves a non-2xx response as
`{ ok: false, status, body }`; transport failures still reject with the native
network error codes.

### Network requests and timers

JavaScriptCore has no `fetch` and no timers. The iOS host supplies both, and
advertises `fetch` in `__stxNativeBridge.capabilities`; a current `stx native compile`
bundle then installs a global `fetch` with the familiar subset:

```ts
const response = await fetch('https://api.example.com/today', {
  method: 'POST', // default GET
  headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ days: 7 }), // a string, or omitted
})
if (response.ok) today = await response.json() // or await response.text()
response.status // also statusText, url, redirected, headers.get(name)
```

Each call is one `Network.fetch` capability request served by a `URLSession`
data task, so it shares the 30-second deadline, `API_CANCEL`, and route
teardown cancellation of the other capabilities: a closed screen cancels its
transfers. Only absolute `http` and `https` URLs are accepted (plain HTTP still
needs an App Transport Security exception, as the template has for
`localhost`); bodies are UTF-8 text both ways, a `GET` or `HEAD` with a body is
rejected, and a response larger than 8 MB rejects with `RESPONSE_TOO_LARGE`.
Transport failures reject with a `TypeError` whose `code` is `NETWORK_ERROR` or
`TIMEOUT`; HTTP error statuses resolve normally with `ok: false`. Streaming
bodies, `AbortSignal`, and arbitrary binary bodies are not part of the subset.
`FormData` is supported only when the host advertises `files`; it is limited
to text fields and files created by `craft.files`. Cookies use the app's
shared `HTTPCookieStorage`.

`setTimeout` and `clearTimeout` are installed when the context lacks them. The
callbacks stay in JavaScript, the deadline runs on the main queue, and route
teardown cancels every pending timer.

## Verification

The repository exercises the same compiled multi-route fixture on both
platforms:

```bash
bun packages/ios/scripts/test-native-render.ts
bun packages/ios/scripts/test-native-navigation.ts
bun packages/android/scripts/test-native-navigation.ts
cd benchmarks && bun run bench:native-mutations
```

The iOS commands require macOS and a bootable simulator. The native-render
runner keeps XCTest output visible so interaction failures include their
assertion messages and source lines in CI. The Android command requires
`ANDROID_HOME`, `adb`, Gradle, and a running emulator. CI is the source
of truth when those platform prerequisites are unavailable locally. The
host-neutral benchmark includes 100, 1,000, and 10,000-node full renders and
single-node mutations; the platform suites separately verify native recycling,
capability persistence across relaunch, and notification cancellation.

When a style or color prop is removed during reconciliation, reused native
controls reset that value to the platform default instead of retaining stale
state.
