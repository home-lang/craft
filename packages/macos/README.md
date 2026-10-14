# Craft native macOS

`buildMacOSNative` compiles an AppKit host for the stx native mutation protocol.
It renders controls directly using NSView, NSTextField, NSTextView, NSButton,
NSPopUpButton, NSOutlineView, NSScrollView, NSImageView, and AVPlayerView.
Windows, sheets, menus, file dialogs, previews, clipboard operations, and QR
codes use macOS APIs. The layout ABI and atomic mutation validator are shared
with Craft's mobile hosts.

The script engine is zig-js. Pass its checkout and built public static archive
as `zigJS: { source, library }`, and the pinned Zig compiler as `zig`.
The host imports zig-js's `ZigJS` module and owns its Objective-C bridge objects.
It never links the system JavaScriptCore or WebKit frameworks.

```ts
import { buildMacOSNative } from 'craft-native/macos'

await buildMacOSNative({
  outdir: 'dist/native',
  nativeBundle: 'dist/native-screen.js',
  zig: '/toolchain/zig',
  zigJS: { source: '/sources/zig-js', library: '/sources/zig-js/zig-out/lib/libzig-js.a' },
})
```

Launch the executable with `--api-url`, `--native-bundle`, `--title`, and an
optional `--route`. The HTTP agent's `/native/session` endpoint must establish
the session cookie. URLSession owns that cookie and shares it between windows.

This is a native control vocabulary, not an HTML renderer. Unsupported controls
produce a diagnostic and an explicit visible error. The native `Sidebar` accepts
sections of `{ id, header?, items: [{ id, label, icon?, badge? }] }` and sends an
`onValueChange` event. Desktop capabilities are exposed through `craft.desktop`.

An explicit `--test-dir` enables local file-based AppKit control automation.
It records actual control classes, frames, values, script errors, and view trees.
It is absent during normal launches. Tests should always use isolated data.
