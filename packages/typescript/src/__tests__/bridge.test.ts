/**
 * Bridge Core Tests
 *
 * Targets the high-risk paths: stream pre-registration buffering, offline
 * queue timeouts, backpressure, batch destroy race, protocol handshake.
 */

import { afterEach, describe, expect, it } from 'bun:test'
import { BRIDGE_PROTOCOL_VERSION, BridgeError, BridgeErrorCodes, NativeBridge } from '../bridge/core'

// Each test creates its own bridge so we can assert on internal state without
// global pollution. The bridge starts disconnected.

describe('NativeBridge — message IDs', () => {
  it('seeds the counter with a non-trivial random value', async () => {
    // Send two requests on a queued bridge and inspect the IDs in the
    // offline queue. They must be sequential to each other but the suffix
    // should not start near zero — old implementation always produced
    // `…_1` and `…_2` from a freshly-loaded page.
    const b = new NativeBridge({ enableOfflineQueue: true, retries: 0, timeout: 5_000 })
    void b.request('a').catch(() => {/* ignore timeout */})
    void b.request('b').catch(() => {/* ignore timeout */})

    const queue = (b as unknown as { offlineQueue: Array<{ id: string }> }).offlineQueue
    expect(queue.length).toBe(2)
    const suffixes = queue.map(m => Number.parseInt(m.id.split('_').pop()!, 36))
    expect(Number.isFinite(suffixes[0])).toBe(true)
    expect(suffixes[0]).toBeGreaterThan(1000)
    expect(suffixes[1]).toBe(suffixes[0] + 1)
    b.destroy()
  })
})

describe('NativeBridge — stream buffering', () => {
  it('buffers events that arrive before onData is registered', async () => {
    const b = new NativeBridge({ enableOfflineQueue: false })
    const ctrl = b.stream<number>('numbers')

    // Reach into the streams map to simulate native delivering early data
    const streams = (b as unknown as {
      streams: Map<string, { onData: (d: unknown) => void; onEnd: () => void; onError: (e: Error) => void }>
    }).streams
    const [, stream] = [...streams.entries()][0]
    stream.onData(1)
    stream.onData(2)

    const received: number[] = []
    ctrl.onData(n => received.push(n))
    expect(received).toEqual([1, 2])

    // New events after registration are delivered immediately
    stream.onData(3)
    expect(received).toEqual([1, 2, 3])

    b.destroy()
  })

  it('flushes a buffered error to onError once a handler registers', () => {
    const b = new NativeBridge({ enableOfflineQueue: false })
    const ctrl = b.stream('failing')
    const streams = (b as unknown as {
      streams: Map<string, { onError: (e: Error) => void }>
    }).streams
    const [, stream] = [...streams.entries()][0]
    stream.onError(new Error('boom'))

    let received: Error | undefined
    ctrl.onError(e => { received = e })
    expect(received?.message).toBe('boom')
    b.destroy()
  })
})

describe('NativeBridge — offline queue timeout', () => {
  it('rejects offline-queued requests after the configured timeout', async () => {
    const b = new NativeBridge({
      enableOfflineQueue: true,
      timeout: 25,
      retries: 0,
    })

    const start = Date.now()
    let err: unknown
    try {
      await b.request('does.not.matter')
    }
    catch (e) {
      err = e
    }
    const elapsed = Date.now() - start

    expect(err).toBeInstanceOf(BridgeError)
    expect((err as BridgeError).code).toBe(BridgeErrorCodes.TIMEOUT)
    expect(elapsed).toBeGreaterThanOrEqual(20) // ~25ms minus jitter
    expect(elapsed).toBeLessThan(500)

    // The dead message must be removed from the offline queue, otherwise a
    // late reconnect would deliver to a rejected request.
    const queue = (b as unknown as { offlineQueue: unknown[] }).offlineQueue
    expect(queue.length).toBe(0)

    b.destroy()
  })
})

describe('NativeBridge — backpressure', () => {
  it('rejects with BUSY when in-flight requests exceed the cap', async () => {
    const b = new NativeBridge({
      enableOfflineQueue: false, // direct path so requests stay pending
      maxConcurrentRequests: 2,
      retries: 0,
      timeout: 5_000,
    })
    // Force "connected" so requests aren't queued offline
    ;(b as unknown as { connected: boolean }).connected = true
    // Stub send so request() doesn't fail-fast on missing transport.
    ;(b as unknown as { send: (m: unknown) => boolean }).send = () => true

    // Two pending requests fill the slot
    const p1 = b.request('a').catch(() => {/* ignore */})
    const p2 = b.request('b').catch(() => {/* ignore */})

    let err: unknown
    try {
      await b.request('c')
    }
    catch (e) {
      err = e
    }
    expect(err).toBeInstanceOf(BridgeError)
    expect((err as BridgeError).code).toBe(BridgeErrorCodes.BUSY)

    b.destroy()
    await p1
    await p2
  })
})

describe('NativeBridge — destroy', () => {
  it('rejects pending requests with BRIDGE_DESTROYED', async () => {
    const b = new NativeBridge({ retries: 0, timeout: 10_000, enableOfflineQueue: false })
    ;(b as unknown as { connected: boolean }).connected = true
    ;(b as unknown as { send: (m: unknown) => boolean }).send = () => true
    const promise = b.request('x')
    b.destroy()
    let err: unknown
    try {
      await promise
    }
    catch (e) {
      err = e
    }
    expect(err).toBeInstanceOf(BridgeError)
    expect((err as BridgeError).code).toBe(BridgeErrorCodes.BRIDGE_DESTROYED)
  })

  it('flushBatch is a no-op once destroyed', () => {
    const b = new NativeBridge({ batchSize: 100, batchDelay: 5 })
    b.addToBatch('first')
    b.addToBatch('second')

    const sendCalls: unknown[] = []
    ;(b as unknown as { send: (m: unknown) => void }).send = (m) => { sendCalls.push(m) }

    b.destroy()

    // flushBatch is private; trigger via the timer path manually.
    ;(b as unknown as { flushBatch: () => void }).flushBatch()

    expect(sendCalls.length).toBe(0)
  })

  it('is idempotent', () => {
    const b = new NativeBridge()
    b.destroy()
    expect(() => b.destroy()).not.toThrow()
  })
})

describe('NativeBridge — fail-fast on missing transport', () => {
  it('rejects immediately when no transport is wired (no waiting for timeout)', async () => {
    const b = new NativeBridge({
      enableOfflineQueue: false,
      retries: 0,
      timeout: 10_000,
    })
    ;(b as unknown as { connected: boolean }).connected = true
    // Default send returns false in this test env (no window.webkit, no
    // CraftBridge, no craftIPC, no process.send) — so request() should
    // reject within milliseconds, not 10 seconds.
    const start = Date.now()
    let err: unknown
    try {
      await b.request('a')
    }
    catch (e) {
      err = e
    }
    expect(Date.now() - start).toBeLessThan(500)
    expect(err).toBeInstanceOf(BridgeError)
    expect((err as BridgeError).code).toBe(BridgeErrorCodes.UNKNOWN)
    b.destroy()
  })
})

describe('NativeBridge — stream cancel idempotency', () => {
  it('second cancel() does not delete or re-send', () => {
    const b = new NativeBridge({ enableOfflineQueue: false })
    ;(b as unknown as { connected: boolean }).connected = true
    const sent: Array<{ method?: string }> = []
    ;(b as unknown as { send: (m: unknown) => boolean }).send = (m) => {
      sent.push(m as { method?: string })
      return true
    }

    const ctrl = b.stream('numbers')
    const initialCancels = sent.filter(m => m.method === '_cancelStream').length
    ctrl.cancel()
    ctrl.cancel()
    ctrl.cancel()
    const finalCancels = sent.filter(m => m.method === '_cancelStream').length
    expect(finalCancels - initialCancels).toBe(1)
    b.destroy()
  })
})

describe('NativeBridge — stream buffer cap', () => {
  it('fires BUFFER_OVERFLOW (BUSY) when buffer fills with no consumer', () => {
    const b = new NativeBridge({ enableOfflineQueue: false })
    ;(b as unknown as { connected: boolean }).connected = true
    ;(b as unknown as { send: (m: unknown) => boolean }).send = () => true

    const ctrl = b.stream<number>('numbers', undefined, { bufferLimit: 3 })
    const streams = (b as unknown as {
      streams: Map<string, { onData: (d: unknown) => void; onError: (e: Error) => void }>
    }).streams
    const [, stream] = [...streams.entries()][0]
    stream.onData(1)
    stream.onData(2)
    stream.onData(3)
    stream.onData(4) // fourth event triggers overflow

    let received: Error | undefined
    ctrl.onError(e => { received = e })
    expect(received).toBeInstanceOf(BridgeError)
    expect((received as BridgeError).code).toBe(BridgeErrorCodes.BUSY)
    b.destroy()
  })
})

describe('NativeBridge — protocol handshake', () => {
  it('exposes the protocol version constant', () => {
    expect(typeof BRIDGE_PROTOCOL_VERSION).toBe('number')
    expect(BRIDGE_PROTOCOL_VERSION).toBeGreaterThanOrEqual(1)
  })

  it('handshake rejects on version mismatch', async () => {
    const b = new NativeBridge({ retries: 0, timeout: 100, enableOfflineQueue: false })
    ;(b as unknown as { connected: boolean }).connected = true
    // Stub send: when we see a `_handshake` request, simulate the native side
    // replying with the wrong version.
    ;(b as unknown as { send: (m: unknown) => void }).send = (m: unknown) => {
      const msg = m as { id: string; method?: string }
      if (msg.method === '_handshake') {
        ;(b as unknown as { handleResponse: (r: unknown) => void }).handleResponse({
          id: msg.id,
          type: 'response',
          result: { version: 999 },
        })
      }
    }

    let err: unknown
    try {
      await b.handshake()
    }
    catch (e) {
      err = e
    }
    expect(err).toBeInstanceOf(BridgeError)
    expect((err as BridgeError).code).toBe(BridgeErrorCodes.PROTOCOL_MISMATCH)
    b.destroy()
  })
})

let cleanup: Array<() => void> = []
afterEach(() => {
  for (const fn of cleanup) fn()
  cleanup = []
})
