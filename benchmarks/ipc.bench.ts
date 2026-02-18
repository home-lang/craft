#!/usr/bin/env bun

/**
 * IPC Pattern Benchmark
 *
 * Measures the serialization overhead of each framework's IPC protocol.
 *
 * All three frameworks use JSON serialization when crossing the JS <-> native
 * boundary. The difference is the MESSAGE FORMAT (envelope structure):
 *
 * - Craft:    Minimal envelope via WebKit message handlers
 *             Request:  { t, a, d }  (single-char keys for minimal overhead)
 *             Response: raw result (no envelope — callback invoked directly)
 *
 * - Tauri:    Invoke-style envelope via WebKit message handlers + serde
 *             Request:  { cmd, callback, error, payload: { __tauriModule, message } }
 *             Response: { id, result }
 *
 * - Electron: IPC channel envelope via Chromium structured clone
 *             Request:  { channel, sender: { id }, args: [...] }
 *             Response: { channel, requestId, result }
 *
 * This is a fair comparison: same serialization mechanism (JSON.stringify/parse),
 * measuring the actual protocol overhead of each framework's message format.
 */
import { bench, boxplot, run, summary } from 'mitata'
import { header } from './utils'

header('IPC Protocol Overhead')

// Shared test data — identical content for all frameworks
const DATA = {
  title: 'Hello World',
  timestamp: 1708200000000,
  metadata: { source: 'renderer', priority: 1 },
}

// ---------------------------------------------------------------------------
// Single message round-trip
// ---------------------------------------------------------------------------
boxplot(() => {
  summary(() => {
    bench('Craft', () => {
      // Craft's WebKit bridge: minimal JSON envelope with single-char keys
      // JS -> native: webkit.messageHandlers.craft.postMessage(json)
      const request = JSON.stringify({
        t: 'window',
        a: 'updateTitle',
        d: DATA,
      })
      const parsed = JSON.parse(request)

      // Native -> JS: evaluateJavaScript("__craftBridgeResult('action', payload)")
      // No response envelope — just the raw result data
      const response = JSON.stringify({ ok: true })
      JSON.parse(response)

      return parsed.a
    })

    bench('Tauri', () => {
      // Tauri's invoke protocol: structured command envelope
      // JS -> Rust: window.__TAURI_INTERNALS__.invoke(cmd, payload)
      const request = JSON.stringify({
        cmd: 'plugin:app|invoke',
        callback: 1,
        error: 2,
        payload: {
          __tauriModule: 'App',
          message: { action: 'updateTitle', data: DATA },
        },
      })
      const parsed = JSON.parse(request)

      // Rust -> JS: resolve callback with result envelope
      const response = JSON.stringify({
        id: 1,
        result: { ok: true },
      })
      JSON.parse(response)

      return parsed.payload.message.action
    })

    bench('Electron', () => {
      // Electron's IPC: channel-based message passing
      // Renderer -> Main: ipcRenderer.invoke(channel, ...args)
      const request = JSON.stringify({
        channel: 'app:invoke',
        sender: { id: 1 },
        args: [{ action: 'updateTitle', data: DATA }],
      })
      const parsed = JSON.parse(request)

      // Main -> Renderer: event.reply or ipcMain.handle return
      const response = JSON.stringify({
        channel: 'app:invoke',
        requestId: 1,
        result: { ok: true },
      })
      JSON.parse(response)

      return parsed.args[0].action
    })
  })
})

// ---------------------------------------------------------------------------
// Batch message throughput (1000 messages)
// ---------------------------------------------------------------------------
boxplot(() => {
  summary(() => {
    bench('Craft - 1k messages', () => {
      let sum = 0
      for (let i = 0; i < 1000; i++) {
        // Minimal request envelope with single-char keys
        const wire = JSON.stringify({
          t: 'event',
          a: 'update',
          d: { value: i },
        })
        const msg = JSON.parse(wire)
        sum += msg.d.value
      }
      return sum
    })

    bench('Tauri - 1k messages', () => {
      let sum = 0
      for (let i = 0; i < 1000; i++) {
        const wire = JSON.stringify({
          cmd: 'plugin:app|invoke',
          callback: i,
          error: i + 1,
          payload: { action: 'update', value: i },
        })
        const msg = JSON.parse(wire)
        sum += msg.payload.value
      }
      return sum
    })

    bench('Electron - 1k messages', () => {
      let sum = 0
      for (let i = 0; i < 1000; i++) {
        const wire = JSON.stringify({
          channel: 'ipc',
          sender: { id: 1 },
          args: [{ action: 'update', value: i }],
        })
        const msg = JSON.parse(wire)
        sum += msg.args[0].value
      }
      return sum
    })
  })
})

await run()
