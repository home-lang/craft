# Session API

Follow the signed-in account: the sign-in token an app keeps in secure storage,
and every change of it.

Apps scope native screens to an account: one person's data must never show
under another's sign-in. Instead of comparing a snapshot on every change,
listen for the account itself. Craft reports a change of the token whoever made
it: a native screen's `craft.secureStorage.set` or `remove` (a native sign-in
or sign-out), a `clear`, the web page's own sign-in through a `shareStorage`
key, or another browser tab.

## Import

```typescript
import { session } from 'craft-native/mobile'
```

On a native stx screen and in an iOS hybrid page the same API is also
`window.craft.session`.

## Configuration

The token lives in secure storage under `sessionTokenKey`, `auth.token` unless
the Craft config names another key:

```json
{
  "enableSecureStorage": true,
  "sessionTokenKey": "auth.token",
  "shareStorage": { "auth_token": "auth.token" }
}
```

`shareStorage` maps the page's web-storage key (`auth_token`) to that
secure-storage key, so the page's sign-in moves the account for native screens
and a native sign-in reaches the page. The browser host takes the same option
as `createBrowserPlatform({ sessionTokenKey })`, beside `tokenKey`, the
localStorage key the website keeps the token under.

## Methods

### session.token()

The sign-in token now, or `null` when signed out. An empty token reads as
`null`.

```typescript
const token = session.token()
if (!token) showSignIn()
```

**Returns:** `string | null`

---

### session.onChange(callback)

Hear each change of the token, with the new token and the one before it
(`null` for none). It fires once per change, after storage holds the new value,
so `craft.secureStorage.getSync('auth.token')` inside the callback already
reads the new token. Every screen and the page hear it, including the one that
wrote it. Writing the token it already holds is no change.

```typescript
const stop = session.onChange((token, previous) => {
  if (!token) return showSignIn()            // signed out
  if (previous && previous !== token) resetForAnotherAccount()
  else loadForNewSignIn()
})

// later
stop()
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| callback | `(token: string \| null, previous: string \| null) => void` | Called on each change |

**Returns:** `() => void`, which unsubscribes.

## Events

| Where | Name | Payload |
|-------|------|---------|
| Native screen (iOS, Android, browser host) | `SESSION_CHANGED` bridge message | `{ key, token, previous }` |
| iOS hybrid page | `craftsession` window event | `detail: { key, token, previous }` |

`key` is the secure-storage key on a native screen and the page's own
web-storage key on the page. `token` and `previous` are strings or `null`. The
SDK exports the names as `SESSION_MESSAGE` and `SESSION_EVENT`, and the default
key as `DEFAULT_SESSION_TOKEN_KEY`.

The page still gets `craftsharedstorage { key, value }` when a native screen
writes any shared key; `craftsession` is the account-level event for the token
alone, and it also fires for the page's own sign-in.

## Hosts

| Host | `craft.session` | Change source |
|------|-----------------|---------------|
| iOS native screens | Installed by the screen host (`keep('session')`) | `CraftSession` in CraftNativeActions.swift: every `SecureStorage` write of the key and every `clear`, plus the page's `shareStorage` writes (CraftHybrid.swift) |
| Android native screens | Installed by the isolate prelude | Each isolate's `SYNC_UPDATE` for the secure store, which every write broadcasts to every isolate, the writer's included |
| iOS hybrid page | Installed by the hybrid page script when a `shareStorage` key maps to `sessionTokenKey` | The page's own storage writes and adopted native writes |
| Browser host | `platform.craft.session`, plus `SESSION_CHANGED` through `platform.emit` | Its storage's account transition: a write here, or another tab's |

A runtime that assigns its own `craft.session` (stx's bridge) keeps the host's
`token`, `onChange` and `key` for anything it leaves out, as with
`craft.secureStorage.getSync`.

Each native host also gives its bridge object the key as
`__stxNativeBridge.sessionTokenKey`.

## Exposing it from a screen runtime

A runtime that owns the bridge protocol (stx's `craft-bridge.ts`) can expose
the API from the message alone:

```typescript
const key = nativeBridge.sessionTokenKey || 'auth.token'
craft.session = {
  key,
  token: () => craft.secureStorage.getSync(key) || null,
  onChange: callback => protocol.on('SESSION_CHANGED', ({ payload }) =>
    callback(payload?.token ?? null, payload?.previous ?? null)),
}
```

## Example: one screen, one account

```typescript
import { session } from 'craft-native/mobile'

let account = session.token()
const stop = session.onChange((token) => {
  if (token === account) return
  account = token
  clearScreenState()
  if (token) reload()
})
```
