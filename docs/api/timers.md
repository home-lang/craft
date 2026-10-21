# Background deadlines

On macOS, `craft.timers.sleep(delayMs, { signal })` waits on the native main
run loop. It keeps working while a tray popover is hidden and WebKit throttles
DOM timers. Use it for application work such as debouncing native events.

```typescript
const cancellation = new AbortController()
await window.craft.timers.sleep(1000, { signal: cancellation.signal })
```

`delayMs` must be an integer from zero through 86,400,000 (one day). Aborting
rejects with `AbortError` and cancels the native deadline. Each page may have
multiple concurrent deadlines; replies are correlated to their requests even
when they complete out of order. The runtime has a bounded pool of 256 timers
and reports `Busy` when it is full, independently of other asynchronous APIs.

The runtime releases timers and their native activity when they complete, are
cancelled, or their page navigates or is destroyed. The scoped activity permits
normal display and system sleep; it does not prevent the user sleeping the Mac.
Deadlines may run later after sleep or when the system is busy.

Stacks applications can import `backgroundDelay` from
`@stacksjs/desktop/browser` instead. It uses this native API inside Craft and
browser timers on the web. A native runtime missing the capability reports an
error so an application cannot silently depend on throttled DOM timers.
