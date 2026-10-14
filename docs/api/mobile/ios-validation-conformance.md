# iOS Zig/Swift validation conformance

This table records the input cases where the Zig-native iOS bridge is
deliberately stricter than the generated Swift shim. It is keyed by the action
and malformed or conflicting input, so a change to either host has a concrete
place to update. The Zig result names the public bridge error; the Swift column
describes what an app observing the legacy shim actually sees.

| Action | Input | Zig-native result | Legacy Swift behavior | Evidence |
| --- | --- | --- | --- | --- |
| `notifications.cancel` | Missing `id` (or a non-string `id`) | Rejects with `MissingData` or `InvalidParameter`; the promise settles. | The dispatcher has no reply branch, so the untimed promise remains pending. | `packages/zig/src/bridge_mobile_notifcancel.zig`: `a missing taskId...`-style malformed-input tests and module contract; Swift dispatcher in `packages/ios/templates/CraftApp.swift`. |
| `notifications.cancel` | `id` containing `\\u0000` | Rejects with `InvalidParameter` before touching UserNotifications. | `stringWithUTF8String:` truncates at the NUL and can cancel a different identifier while resolving success. | `packages/zig/src/bridge_mobile_notifcancel.zig`: `an id with an embedded NUL is refused, not truncated`. |
| `background.schedule` / `background.cancel` | `taskId` containing `\\u0000` | Rejects with `InvalidParameter`; no truncated task is submitted or cancelled. | The Objective-C string conversion truncates the identifier, so the native request and the reply can name different tasks. | `packages/zig/src/bridge_mobile_bgtasks.zig`: `a taskId with an embedded NUL is refused, not truncated`. |
| `files.saveFile` | Filename is empty, `.`, `..`, contains `/`, or contains NUL. | Rejects with `InvalidParameter` before joining a path. | The shim joins the unsanitized string to `Documents`; traversal can escape the app-owned directory and C-string conversion can truncate. | `packages/zig/src/bridge_mobile_filepicker.zig`: `validateFilename` and filename tests; Swift `CraftNativeFiles.safeName`/legacy `saveFile` path. |
| `files.saveFile` | `data:` URL has the wrong comma count or invalid base64. | Rejects with `InvalidParameter`; no successful write is reported. | The shim skips the write but still resolves the destination path, making a nonexistent file look successful. | `packages/zig/src/bridge_mobile_filepicker.zig`: `decodeSaveBytes` and malformed data-URL tests. |
| `files.pickFile` | A declared type cannot resolve to a MIME type, extension, or UTI (for example `public.pdf`). | Rejects the request with `InvalidParameter` instead of silently dropping the filter. | `compactMap` removes the unsupported type and presents a picker with fewer—or no—allowed types. | `packages/zig/src/bridge_mobile_filepicker.zig`: picker-type contract comments/tests; Swift type mapping in `packages/ios/templates/CraftApp.swift`. |

These are intentional safety differences, not a request to weaken the Zig
bridge or change successful reply shapes. Cases where the shim and Zig agree
remain in the per-module tests and do not need a row here.
