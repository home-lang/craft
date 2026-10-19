# Haptics API

Provide tactile feedback through device vibrations.

Haptics are feedback, so these methods never stop a flow for a capability the
app left off. On iOS, with `enableHaptics` off in `craft.config.json`, they
resolve without playing anything, the way the web fallback does on a device
with no vibration motor. They reject only when the native call itself fails.
The raw `window.craft.haptic()` is different: it rejects with
`CAPABILITY_DISABLED`, for code that needs to know.

The same calls work in a macOS desktop window, where they play on the Force
Touch trackpad. AppKit plays feedback only while a finger is on the trackpad and
the app is active, and stays silent on a Mac without one; either way the call
succeeds, because it means AppKit accepted the tap, not that it was felt. On
Linux and Windows there is nothing to play, so the helpers resolve without doing
anything and the raw `window.craft.haptic()` rejects with
`PLATFORM_NOT_SUPPORTED`.

There is no `isSupported()`, because the hosts cannot answer it alike: Android
can report whether the device has a vibrator, but AppKit cannot tell whether a
Force Touch trackpad is attached, let alone under the user's finger. Call the
helpers unconditionally. Code that must know whether the host serves haptics at
all can call the raw `window.craft.haptic()` and read its rejection.

## Import

```typescript
import { haptics } from 'craft-native'
```

## Methods

### haptics.impact(style)

Trigger an impact haptic feedback. Use for button presses, selections, and UI interactions.

```typescript
// Light impact - subtle tap
await haptics.impact('light')

// Medium impact - standard feedback
await haptics.impact('medium')

// Heavy impact - strong tap
await haptics.impact('heavy')

// Rigid impact (iOS only) - sharp, precise tap
await haptics.impact('rigid')

// Soft impact (iOS only) - gentle, rounded tap
await haptics.impact('soft')
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| style | `'light' \| 'medium' \| 'heavy' \| 'rigid' \| 'soft'` | Impact intensity |

**Returns:** `Promise<void>`

---

### haptics.notification(type)

Trigger a notification haptic. Use to indicate success, warning, or error states.

```typescript
// Success - positive feedback
await haptics.notification('success')

// Warning - cautionary feedback
await haptics.notification('warning')

// Error - negative feedback
await haptics.notification('error')
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| type | `'success' \| 'warning' \| 'error'` | Notification type |

**Returns:** `Promise<void>`

---

### haptics.selection()

Trigger a selection haptic. Use for selection changes like toggles, pickers, and sliders.

```typescript
// Selection feedback - very light tap
await haptics.selection()
```

**Returns:** `Promise<void>`

---

### haptics.vibrate(pattern?)

Trigger a vibration with optional pattern (primarily Android).

```typescript
// Simple vibration
await haptics.vibrate()

// Pattern: [wait, vibrate, wait, vibrate, ...]
await haptics.vibrate([0, 100, 50, 100])

// Long vibration
await haptics.vibrate([0, 500])
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| pattern | `number[]` | Vibration pattern in milliseconds |

**Returns:** `Promise<void>`

## Example Usage

```typescript
import { haptics } from 'craft-native'

// Button press feedback
async function onButtonPress() {
  await haptics.impact('light')
  // Perform action...
}

// Toggle switch
async function onToggle(isOn: boolean) {
  await haptics.selection()
  updateToggleState(isOn)
}

// Form submission
async function onSubmit() {
  try {
    await submitForm()
    await haptics.notification('success')
    showSuccessMessage()
  } catch (error) {
    await haptics.notification('error')
    showErrorMessage(error)
  }
}

// Slider with continuous feedback
let lastValue = 0
async function onSliderChange(value: number) {
  // Only trigger haptic when crossing major values
  const roundedValue = Math.round(value / 10) * 10
  if (roundedValue !== lastValue) {
    lastValue = roundedValue
    await haptics.selection()
  }
}

// Delete confirmation
async function confirmDelete() {
  await haptics.notification('warning')
  const confirmed = await showConfirmDialog('Delete this item?')

  if (confirmed) {
    await deleteItem()
    await haptics.notification('success')
  }
}

// Long press action
async function onLongPress() {
  await haptics.impact('heavy')
  showContextMenu()
}

// Tab selection
async function onTabSelect(tabId: string) {
  await haptics.impact('light')
  switchToTab(tabId)
}

// Pull to refresh
async function onRefreshStart() {
  await haptics.impact('medium')
}

async function onRefreshComplete(success: boolean) {
  await haptics.notification(success ? 'success' : 'error')
}
```

## Best Practices

1. **Use sparingly** - Too much haptic feedback becomes annoying
2. **Match intensity to action** - Light for selections, heavy for important actions
3. **Be consistent** - Use the same haptic type for similar actions
4. **Respect user preferences** - Some users disable haptics for accessibility
5. **Test on real devices** - Simulators don't provide accurate haptic feedback

## Platform Differences

| Feature | iOS | Android | macOS | Browser |
|---------|-----|---------|-------|---------|
| Impact styles | All 5 styles | All 5 on native screens; 3 timed weights in a WebView | `heavy` plays LevelChange, the rest Generic | Vibration API timings |
| Notification types | All 3 types | All 3 on native screens; vibration patterns in a WebView | `error` plays LevelChange, the rest Generic | Vibration API patterns |
| Selection | Yes | Yes | Alignment | 5 ms |
| Custom patterns | Limited | Full support | One tap if the pattern fires at all | `navigator.vibrate` |
| Without support | Resolves | Resolves | Resolves | Resolves (`false`) |

### Android native screens

A native screen (`renderer: 'native'`, or the stx native bundle) plays the same
names iOS does, so `Haptics.impact`, `Haptics.notification`,
`Haptics.selection` and `Haptics.prepare` reach `CraftNativeHaptics`. Like
iOS, `impact` accepts any of the nine names, so a runtime that sends everything
through `impact` still plays a notification as one.

The screen's own haptic feedback plays first. It needs no `VIBRATE` permission
and follows the system's touch-feedback setting, the way UIKit's generators
follow System Haptics, so a person who turned haptics off feels nothing and the
call answers `false`.

| Style | View feedback (`HapticFeedbackConstants`) | Vibrator fallback (API 29+ / 26-28) |
|-------|--------------------------------------------|-------------------------------------|
| `light` | `KEYBOARD_TAP` | `EFFECT_TICK` / 10 ms |
| `medium`, unknown | `VIRTUAL_KEY` | `EFFECT_CLICK` / 20 ms |
| `heavy` | `LONG_PRESS` | `EFFECT_HEAVY_CLICK` / 50 ms |
| `soft` | `TEXT_HANDLE_MOVE` (API 27+), else `CLOCK_TICK` | `EFFECT_TICK` / 8 ms |
| `rigid` | `CONTEXT_CLICK` | `EFFECT_CLICK` / 25 ms |
| `selection` | `SEGMENT_TICK` (API 34+), else `CLOCK_TICK` | `EFFECT_TICK` / 5 ms |
| `success` | `CONFIRM` (API 30+) | `EFFECT_DOUBLE_CLICK` / 30-50-30 |
| `warning` | none | `EFFECT_DOUBLE_CLICK` / 50-100-50 |
| `error` | `REJECT` (API 30+) | `EFFECT_HEAVY_CLICK` / 100-50-100 |

The vibrator plays only a style with no feedback constant on the device's API
level, or when the screen is not attached. `prepare` warms nothing on Android
and answers `true`. With `enableHaptics` off, each call answers
`CAPABILITY_DISABLED`, which the helpers swallow.

### Browser host

`craft-native/browser` (stx native screens running in a browser tab) plays
through `navigator.vibrate`. Desktop browsers and Safari have no Vibration API,
so the call resolves `false` rather than rejecting with `UNSUPPORTED`: haptics
are feedback and never fail a flow.

A Mac trackpad has three feedback patterns (Generic, Alignment, LevelChange)
and no intensity or duration, which is why the styles fold onto them. Linux
and Windows have no haptics API, so every method resolves without playing
anything there.

## Types

```typescript
type ImpactStyle = 'light' | 'medium' | 'heavy' | 'rigid' | 'soft'

type NotificationType = 'success' | 'warning' | 'error'
```
