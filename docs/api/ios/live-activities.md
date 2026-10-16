# Live Activities API

Craft exposes Live Activities through the browser-safe `craft-native/mobile`
entrypoint. Enable `enableLiveActivities` in the iOS app configuration before
using this API.

## Start and retain a handle

`start` returns a handle bound to the ActivityKit activity that was created.
Its `update` and `end` methods cannot affect another activity.

```ts
import { liveActivities } from 'craft-native/mobile'

const recordingActivity = await liveActivities.start({
  activityId: recording.id,
  title: 'WildLoop',
  status: 'Recording',
  distanceMeters: 0,
  durationSeconds: 0,
})

await recordingActivity.update({
  distanceMeters: 1609,
  durationSeconds: 480,
})

await recordingActivity.end({ status: 'Saved' })
```

Persist `recordingActivity.id` when the app must restore the association after
a background transition. The same activity can then be addressed explicitly:

```ts
await liveActivities.update(savedActivityId, { distanceMeters: 2400 })
await liveActivities.end(savedActivityId, { status: 'Saved' })
```

Several handles may be active at once. Each handle and explicit ID call targets
only its matching ActivityKit activity.

## Migrating singleton calls

The former singleton forms remain available for one release, but are
deprecated:

```ts
await liveActivities.update({ progress: 0.5 })
await liveActivities.end()
```

Keep the handle returned from `start`, or persist its `id`, and migrate to one
of the scoped forms above. Singleton calls select the first active activity and
cannot safely be used when more than one activity exists.

## Native STX screens and session timers

With `enableLiveActivities`, native screens expose `craft.liveActivity` over the
same process-owned ActivityKit service as the web bridge. `isAvailable()` checks
OS support and the user's current authorization; `list()` returns existing IDs.
Starting the same application `activityId` reattaches instead of creating a duplicate.
No activity is fabricated on an unsupported host.

`timerStartedAt` and `timerEndsAt` are Unix epoch **milliseconds**. The widget uses
SwiftUI's system-rendered dates, so elapsed time and countdowns advance while the
app is suspended. Send updates at meaningful state transitions and for changing
metrics, rather than every timer tick. A paused presentation uses the supplied
`durationSeconds` or `remainingSeconds`; clear timer anchors with `null` and set
`paused: true`. Resuming supplies new anchors with paused time removed.

```ts
if (await liveActivities.isAvailable()) {
  const activity = await liveActivities.start({
    activityId: 'practice-123',
    title: 'Evening unwind',
    detail: 'Relax · Sleep',
    status: 'Time remaining',
    symbol: 'moon.stars.fill',
    tint: '#30b0c7',
    deepLink: 'myapp://relax/123',
    timerStartedAt: Date.now(),
    timerEndsAt: Date.now() + 180_000,
    staleAt: Date.now() + 180_000,
    staleStatus: 'Open app to update',
    showsDistance: false,
  })
  // End when the session completes, is discarded, or its account signs out.
  await activity.end()
}
```

`deepLink` opens the session from the Lock Screen and every Dynamic Island
presentation. `symbol` is an SF Symbol; `tint` accepts a six-digit hex color.
Distance uses the device's measurement formatting, and `showsDistance: false`
hides it for sessions without GPS. Optional `heartRate` is marked privacy-sensitive.

A timer does not give JavaScript background execution or schedule future step
updates. Use `staleAt` and localized `staleStatus` when the current step may have
ended while the app was suspended. Reconcile `list()` after relaunch and end
orphaned sessions. Ending dismisses the presentation immediately.
