# Background API

Run work when the system wakes the app: a silent push, or the scheduled
background refresh. Each wake is a task the app must answer.

## Import

```typescript
import { background } from 'craft-native/mobile'
```

On a native stx screen or the app script (`nativeApp`) the same calls are
`window.craft.background`, and the wakes arrive as `craftSilentPush` and
`craftBackgroundRefresh` events on the script's global.

## Configuration

| Wake | iOS | Android (native renderer) |
|------|-----|---------------------------|
| Silent push | `enablePushNotifications` and a `content-available` push | `enablePushNotifications` and an FCM data message |
| Scheduled refresh | `backgroundRefresh: { enabled: true }` (BGAppRefreshTask) | `backgroundRefresh: { enabled: true, minimumIntervalMinutes }` (WorkManager) |

## Methods

### background.onSilentPush(callback)

A content-available push arrived. The detail carries the task's `id` and the
push's `payload`.

```typescript
background.onSilentPush(async ({ id, payload }) => {
  const ok = await syncInbox(payload).then(() => true, () => false)
  await background.complete(ok, id)
})
```

**Returns:** `() => void`, which unsubscribes.

---

### background.onRefresh(callback)

The system woke the app to refresh. The detail carries the task's `id`.

```typescript
background.onRefresh(async ({ id }) => {
  const ok = await refreshToday().then(() => true, () => false)
  await background.complete(ok, id)
})
```

**Returns:** `() => void`, which unsubscribes.

---

### background.complete(ok?, id?)

Finish a task. `ok` (default `true`) is whether the work succeeded; iOS hands
it to the system as the task's result. Pass the event's `id` to finish that
task alone. Without an `id`, every pending task finishes, so a push handler
that settles while a refresh is still working would end the refresh early.
Always pass the `id` when the event gave one.

iOS ends a task the app has not answered after 25 seconds. Resolves whether the
host took the answer, and `false` off a Craft shell.

| Name | Type | Description |
|------|------|-------------|
| ok | `boolean` | Whether the work succeeded |
| id | `string` | The `id` from the event's detail |

**Returns:** `Promise<boolean>`

The native capability behind it is `Background.complete` with args
`[ok, id | null]`.

## Types

```typescript
interface BackgroundWorkEvent {
  /** Pass to `background.complete` to answer this one. */
  id?: string
  /** The push's payload, for a silent push. */
  payload?: Record<string, unknown>
}
```
