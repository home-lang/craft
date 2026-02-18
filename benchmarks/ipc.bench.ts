#!/usr/bin/env bun

/**
 * IPC Pattern Benchmark
 *
 * Measures the serialization overhead of each framework's IPC protocol.
 *
 * All three frameworks use JSON serialization when crossing the JS ↔ native
 * boundary. The difference is the MESSAGE FORMAT (envelope structure):
 *
 * - Craft:    Minimal envelope via WebKit message handlers
 *             { type, payload }
 *
 * - Tauri:    Invoke-style envelope via WebKit message handlers + serde
 *             { cmd, callback, error, payload: { __tauriModule, message } }
 *
 * - Electron: IPC channel envelope via Chromium structured clone
 *             { channel, sender: { id }, args: [...] }
 *
 * This is a fair comparison: same serialization mechanism (JSON.stringify/parse),
 * measuring the actual protocol overhead of each framework's message format.
 */
import { bench, boxplot, run, summary } from 'mitata'
import { header } from './utils'

header('IPC Protocol Overhead')

// Shared test payload — identical data for all frameworks
const PAYLOAD = {
  action: 'updateTitle',
  data: {
    title: 'Hello World',
    timestamp: 1708200000000,
    metadata: { source: 'renderer', priority: 1 },
  },
}

// ---------------------------------------------------------------------------
// Single message round-trip
// ---------------------------------------------------------------------------
boxplot(() => {
  summary(() => {
    bench('Craft', () => {
      // Craft's WebKit bridge: minimal JSON envelope
      // JS → native: webkit.messageHandlers.craft.postMessage(json)
      const request = JSON.stringify({
        type: 'invoke',
        payload: PAYLOAD,
      })
      const parsed = JSON.parse(request)

      // Native → JS: evaluateJavaScript callback
      const response = JSON.stringify({
        type: 'result',
        payload: { ok: true },
      })
      JSON.parse(response)

      return parsed.payload.action
    })

    bench('Tauri', () => {
      // Tauri's invoke protocol: structured command envelope
      // JS → Rust: window.__TAURI_INTERNALS__.invoke(cmd, payload)
      const request = JSON.stringify({
        cmd: 'plugin:app|invoke',
        callback: 1,
        error: 2,
        payload: {
          __tauriModule: 'App',
          message: PAYLOAD,
        },
      })
      const parsed = JSON.parse(request)

      // Rust → JS: resolve callback with result
      const response = JSON.stringify({
        id: 1,
        result: { ok: true },
      })
      JSON.parse(response)

      return parsed.payload.message.action
    })

    bench('Electron', () => {
      // Electron's IPC: channel-based message passing
      // Renderer → Main: ipcRenderer.invoke(channel, ...args)
      const request = JSON.stringify({
        channel: 'app:invoke',
        sender: { id: 1 },
        args: [PAYLOAD],
      })
      const parsed = JSON.parse(request)

      // Main → Renderer: event.reply or ipcMain.handle return
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
        const wire = JSON.stringify({
          type: 'event',
          payload: { action: 'update', value: i },
        })
        const msg = JSON.parse(wire)
        sum += msg.payload.value
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
