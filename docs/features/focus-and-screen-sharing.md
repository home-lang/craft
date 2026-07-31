# Focus & Screen Sharing

Two macOS bridges that exist for the same class of app: something that needs to
know when you are presenting, and needs to silence the machine while you are.

## Screen sharing

`window.craft.screenSharing` answers "is my screen being shared or recorded
right now?" — a question macOS deliberately does not expose directly. Four
independent signals are combined:

| Signal | Source | Fires when |
| --- | --- | --- |
| `systemScreenShare` | `CGSessionCopyCurrentDictionary()` → `CGSSessionScreenIsShared` | macOS Screen Sharing / Apple Remote Desktop has the session |
| `remoteSession` | the same dictionary's `kCGSSessionOnConsoleKey` | the session is driven from somewhere other than this console |
| `conferenceSharing` | on-screen window list | a conferencing app is showing its live sharing control |
| `screenRecording` | on-screen window list | a recorder is capturing the screen |

The two window-list signals match the **sharing indicator** — the floating
control an app shows *only while a share is live* — never the application
itself. This distinction is the whole design: "Zoom is running" or "Chrome is
frontmost" describes most of a working day, and an app that acts on it silences
notifications permanently.

```typescript
const state = await window.craft.screenSharing.getState()
// {
//   sharing: true,
//   signals: { systemScreenShare: false, remoteSession: false,
//              conferenceSharing: true, screenRecording: false },
//   sources: [{ app: 'zoom.us', window: 'as_toolbar', kind: 'conference' }]
// }
```

### Watching for changes

None of the signals has a system notification, so detection polls. `watch()`
runs an `NSTimer` on the main run loop and evaluates the signals each tick, but
only touches the webview when the resolved state actually differs — a share
that stays up for an hour costs one window-list walk per interval and zero
JavaScript evaluations.

```typescript
const off = window.craft.screenSharing.onChange((state) => {
  console.log(state.sharing ? 'presenting' : 'clear', state.sources)
})

// Emits once immediately, then on every change. 250ms–60s.
await window.craft.screenSharing.watch(2000)

// Later
await window.craft.screenSharing.unwatch()
off()
```

Each tick is one `CGWindowListCopyWindowInfo` call — a window-server round trip
on the order of a millisecond. The default 2s cadence is effectively free;
raise it if you would rather trade detection latency for even less work.

## Focus / Do Not Disturb

`window.craft.focus` reads and writes macOS Focus. **Reading and writing are
different privilege levels**, and it is worth understanding why before you
design around them.

### Reading is public API

`INFocusStatusCenter` (Intents.framework) has reported Focus state since
macOS 12. It is permission-gated: your app must call `requestAuthorization()`
and declare `NSFocusStatusUsageDescription` in its `Info.plist`.

```typescript
const auth = await window.craft.focus.requestAuthorization()
// 'notDetermined' | 'restricted' | 'denied' | 'authorized' | 'unsupported'

const status = await window.craft.focus.getStatus()
// { supported: true, isFocused: false, authorization: 'authorized' }
```

`isFocused` is `null` — not `false` — when the system declines to answer, which
is almost always because authorization has not been granted. Treat the two
cases differently; a `null` means "ask for permission", not "notifications are
flowing".

### Writing is not available to third-party apps

The system service that owns Focus (`donotdisturbd`, reached through
`DNDModeAssertionService`) rejects every XPC client that does not hold
`com.apple.private.donotdisturb.mode.assertion.client-identifiers`. That
entitlement is Apple-only — Control Center and Shortcuts hold it, your app
cannot. The approaches that circulate for working around this are all dead or
breaking:

- `defaults -currentHost write com.apple.notificationcenterui doNotDisturb`
  stopped having any effect after Big Sur.
- Writing `~/Library/DoNotDisturb/DB/Assertions.json` stopped working when the
  store moved out of user-readable files.
- UI-scripting Control Center through System Events needs Accessibility access
  and breaks whenever the menu-bar layout changes.

What *is* sanctioned is letting Shortcuts perform the mutation on the user's
behalf. A shortcut containing the **Set Focus** action has the entitlement;
running it by name does not require your app to have anything.

```typescript
await window.craft.focus.setEnabled(true, {
  onShortcut: 'Hush Focus On',
  offShortcut: 'Hush Focus Off',
})
```

The shortcut name is passed as a single `argv` entry to `/usr/bin/shortcuts`.
There is no shell in the path, so a name cannot be used for command injection;
control characters and names over 255 bytes are rejected outright.

### Inside the App Sandbox

A sandboxed app — which is to say any app destined for the Mac App Store —
cannot spawn a binary outside its own bundle, so the CLI route is closed. What
it *can* do is ask LaunchServices to open a URL, and Shortcuts registers
`shortcuts://run-shortcut`. Craft detects the sandbox and switches
automatically; `strategy` forces the choice:

```typescript
await window.craft.focus.setEnabled(true, {
  onShortcut: 'Hush Focus On',
  strategy: 'url', // 'auto' (default) | 'cli' | 'url'
})
```

The two routes are not equivalent, and the result says which you got. The CLI
reports the shortcut's real exit status. The URL scheme is fire-and-forget:
LaunchServices confirms it handed the URL to Shortcuts, never that the
shortcut ran, so the result carries `dispatched: true` instead of an
`exitCode`. That is why `auto` only falls back to the URL when it has to.

Enumeration is closed under sandbox for the same reason, so `listShortcuts()`
returns an empty array there. Use `listShortcutsResult()` when the difference
matters — `canList: false` means *could not check*, which should not send a
user through a setup flow they have already completed.

### Verifying setup

Because the shortcuts are user-created, check for them before offering the
feature rather than failing at the moment the user needs it:

```typescript
const shortcuts = await window.craft.focus.listShortcuts()
const ready = shortcuts.includes('Hush Focus On') && shortcuts.includes('Hush Focus Off')
```

`runShortcut(name)` is the escape hatch for anything beyond an on/off pair —
per-mode shortcuts, timed Focus, or a shortcut that also sets a status
elsewhere.

## Platform support

Both bridges are macOS-only. On Linux and Windows `getStatus()` reports
`supported: false`, `getState()` reports no signals, and the mutating calls
return `{ ok: false }` rather than throwing — so a cross-platform app can call
them unconditionally and branch on the result.
