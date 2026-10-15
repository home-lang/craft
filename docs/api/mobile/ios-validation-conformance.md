# iOS Zig/Swift validation conformance

This table records the input cases where the Zig-native iOS bridge is
deliberately stricter than the generated Swift shim. It is keyed by the action
and malformed or conflicting input, so a change to either host has a concrete
place to update. The Zig result names the public bridge error; the Swift column
describes what an app observing the legacy shim actually sees.

| Action | Input | Zig-native result | Legacy Swift behavior | Platform exercise | Evidence |
| --- | --- | --- | --- | --- | --- |
| `notifications.cancel` | Missing `id` (or a non-string `id`) | Rejects with `MissingData` or `InvalidParameter`; the promise settles with a specific error. | Rejects with the less-specific `INVALID_ARGUMENT`; it does not hang. | No simulator required for validation; exercising UserNotifications cancellation still needs iOS. | `packages/zig/src/bridge_mobile_notifcancel.zig`: `a missing id is refused rather than defaulted` and `a non-string id is refused`; Swift dispatcher in `packages/ios/templates/CraftApp.swift`. |
| `notifications.cancel` | `id` containing `\\u0000` | Rejects with `InvalidParameter` before touching UserNotifications. | Accepts the length-aware Swift string and resolves the harmless no-op; Zig refuses because its Objective-C C-string route could truncate the identifier. | No simulator required for validation; exercising UserNotifications cancellation still needs iOS. | `packages/zig/src/bridge_mobile_notifcancel.zig`: `an id with an embedded NUL is refused, not truncated`; Swift helper `cancelLocalNotification`. |
| `background.schedule` / `background.cancel` | `taskId` containing `\\u0000` | Rejects with `InvalidParameter`; no truncated task is submitted or cancelled. | Carries the Swift `String` through interpolation; the Zig Objective-C route refuses the value before it can truncate. | No simulator required for validation; submitting a BGTask still needs iOS. | `packages/zig/src/bridge_mobile_bgtasks.zig`: `a taskId with an embedded NUL is refused, not truncated`. |
| `files.saveFile` | Filename is empty, `.`, `..`, contains `/`, or contains NUL. | Rejects with `InvalidParameter` before joining a path. | The shim joins the unsanitized string to `Documents`; traversal can escape the app-owned directory and C-string conversion can truncate. | No simulator required for validation; an on-device container write is an iOS exercise. | `packages/zig/src/bridge_mobile_filepicker.zig`: `validateFilename` and filename tests; Swift `CraftNativeFiles.safeName`/legacy `saveFile` path. |
| `files.saveFile` | `data:` URL has the wrong comma count or invalid base64. | Rejects with `InvalidParameter`; no successful write is reported. | The shim skips the write but still resolves the destination path, making a nonexistent file look successful. | No simulator required for validation; an on-device container write is an iOS exercise. | `packages/zig/src/bridge_mobile_filepicker.zig`: `decodeSaveBytes` and malformed data-URL tests. |
| `files.pickFile` | A declared type cannot resolve to a MIME type, extension, or UTI (for example `public.pdf`). | Rejects the request with `InvalidParameter` instead of silently dropping the filter. | `compactMap` removes the unsupported type and presents a picker with fewer—or no—allowed types. | Type validation is host-neutral; picker presentation and delegate behavior require an iOS simulator/device. | `packages/zig/src/bridge_mobile_filepicker.zig`: picker-type contract comments/tests; Swift type mapping in `packages/ios/templates/CraftApp.swift`. |

These are intentional safety differences, not a request to weaken the Zig
bridge or change successful reply shapes. Cases where the shim and Zig agree
remain in the per-module tests and do not need a row here.

The table uses the public native capability names (`notifications.cancel`,
`background.schedule`, and so on). The checked-in conformance test maps those
names to the legacy Swift dispatcher actions and verifies that every evidence
path still exists; cases marked “No simulator required” are exercised by the
host-neutral Zig tests, while the remaining rows still need an iOS runtime
exercise for their native side effect.
