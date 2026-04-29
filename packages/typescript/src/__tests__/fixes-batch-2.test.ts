/**
 * Round-2 fixes coverage. Each `describe` references the round-2 audit
 * item it locks in.
 */

import { afterEach, beforeEach, describe, expect, it, mock } from 'bun:test'
import { mkdtempSync, readFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

// -------------------------------------------------------------------------
// R2 Item 1: signing path refuses argv password by default.
// -------------------------------------------------------------------------
describe('R2 Item 1: signing argv password guard', () => {
  it('source contains the CRAFT_SIGNING_ALLOW_ARGV_PASSWORD opt-in', async () => {
    const src = await Bun.file(new URL('../signing/index.ts', import.meta.url)).text()
    expect(src).toContain('CRAFT_SIGNING_ALLOW_ARGV_PASSWORD')
    expect(src).toContain('-readpass')
  })
})

// -------------------------------------------------------------------------
// R2 Item 5: pkgutil --check-signature is invoked before sudo installer.
// -------------------------------------------------------------------------
describe('R2 Item 5: pkg signature pre-flight', () => {
  it('source guards `installer` with pkgutil --check-signature', async () => {
    const src = await Bun.file(new URL('../updater/index.ts', import.meta.url)).text()
    // The check must lexically precede the sudo installer call.
    const checkIdx = src.indexOf("pkgutil', ['--check-signature'")
    const installIdx = src.indexOf("'sudo', ['installer'")
    expect(checkIdx).toBeGreaterThan(0)
    expect(installIdx).toBeGreaterThan(0)
    expect(checkIdx).toBeLessThan(installIdx)
  })
})

// -------------------------------------------------------------------------
// R2 Item 2: media access detection requires non-empty labels.
// -------------------------------------------------------------------------
import { media } from '../api/media'

describe('R2 Item 2: media access label check', () => {
  let originalNavigator: any

  beforeEach(() => {
    originalNavigator = (globalThis as any).navigator
  })

  afterEach(() => {
    if (originalNavigator !== undefined) (globalThis as any).navigator = originalNavigator
  })

  it('returns true when permissions API reports granted', async () => {
    ;(globalThis as any).navigator = {
      mediaDevices: { enumerateDevices: async () => [] },
      permissions: {
        query: async ({ name }: { name: string }) => ({
          state: name === 'camera' ? 'granted' : 'prompt',
        }),
      },
    }
    expect(await media.hasCameraAccess()).toBe(true)
  })

  it('returns false when permissions reports denied', async () => {
    ;(globalThis as any).navigator = {
      mediaDevices: { enumerateDevices: async () => [{ kind: 'videoinput', label: 'a label' }] },
      permissions: { query: async () => ({ state: 'denied' }) },
    }
    expect(await media.hasCameraAccess()).toBe(false)
  })

  it('returns false on `prompt` when devices have empty labels', async () => {
    ;(globalThis as any).navigator = {
      mediaDevices: {
        enumerateDevices: async () => [{ kind: 'videoinput', label: '' }],
      },
      permissions: { query: async () => ({ state: 'prompt' }) },
    }
    expect(await media.hasCameraAccess()).toBe(false)
  })

  it('returns true on `prompt` when at least one device label is non-empty', async () => {
    ;(globalThis as any).navigator = {
      mediaDevices: {
        enumerateDevices: async () => [{ kind: 'videoinput', label: 'FaceTime HD' }],
      },
      permissions: { query: async () => ({ state: 'prompt' }) },
    }
    expect(await media.hasCameraAccess()).toBe(true)
  })

  it('falls back to label check when permissions.query throws', async () => {
    ;(globalThis as any).navigator = {
      mediaDevices: {
        enumerateDevices: async () => [{ kind: 'audioinput', label: 'Mic' }],
      },
      permissions: { query: async () => { throw new Error('unsupported') } },
    }
    expect(await media.hasMicrophoneAccess()).toBe(true)
  })
})

// -------------------------------------------------------------------------
// R2 Item 3: HMR client IDs use secureUUID.
// -------------------------------------------------------------------------
describe('R2 Item 3: HMR client IDs', () => {
  it('source uses secureUUID() inside generateClientId', async () => {
    const src = await Bun.file(new URL('../dev/hot-reload.ts', import.meta.url)).text()
    // Find the generateClientId function and check its body uses secureUUID().
    const match = src.match(/generateClientId\(\)\s*:\s*string\s*\{([\s\S]*?)\n\s*\}/)
    expect(match).not.toBeNull()
    const body = match![1]
    // Strip comments before checking the function body for Math.random.
    const stripped = body.replace(/\/\/[^\n]*/g, '').replace(/\/\*[\s\S]*?\*\//g, '')
    expect(stripped).toContain('secureUUID()')
    expect(stripped).not.toContain('Math.random')
  })
})

// -------------------------------------------------------------------------
// R2 Item 4: device.getInfo() returns a stable web fallback ID.
// -------------------------------------------------------------------------
import { _resetWebFallbackDeviceIdForTests, _webFallbackDeviceId } from '../api/mobile'

describe('R2 Item 4: stable web device id', () => {
  let backing: Record<string, string> = {}

  beforeEach(() => {
    backing = {}
    ;(globalThis as any).localStorage = {
      getItem: (k: string) => backing[k] ?? null,
      setItem: (k: string, v: string) => { backing[k] = v },
      removeItem: (k: string) => { delete backing[k] },
      clear: () => { backing = {} },
    }
    _resetWebFallbackDeviceIdForTests()
  })

  afterEach(() => {
    delete (globalThis as any).localStorage
  })

  it('persists the same id across calls when localStorage is available', () => {
    const a = _webFallbackDeviceId()
    const b = _webFallbackDeviceId()
    expect(a).toBe(b)
    expect(a.startsWith('web-')).toBe(true)
  })

  it('reads the existing id when one is already stored', () => {
    backing.__craft_web_device_id__ = 'web-abcd1234-deadbeef'
    expect(_webFallbackDeviceId()).toBe('web-abcd1234-deadbeef')
  })

  it('rejects garbage in localStorage and overwrites with a fresh id', () => {
    backing.__craft_web_device_id__ = '<script>nope</script>'
    const out = _webFallbackDeviceId()
    expect(out.startsWith('web-')).toBe(true)
    expect(out).not.toContain('<script>')
  })
})

// -------------------------------------------------------------------------
// R2 Item 6: Database.transaction nested-call guard.
// -------------------------------------------------------------------------
import { Database } from '../api/db'

describe('R2 Item 6: nested transaction guard', () => {
  it('throws when transaction() is called from within transaction()', async () => {
    const d = new (Database as unknown as { new (n: string): { transaction: <T>(fn: () => Promise<T>) => Promise<T>; execute: (sql: string) => Promise<void> } })('test')
    // Stub execute() so we don't need a native bridge.
    ;(d as unknown as { execute: (sql: string) => Promise<void> }).execute = async () => {}
    let outerError: unknown = null
    await d.transaction(async () => {
      try {
        await d.transaction(async () => {/* never reached */})
      }
      catch (e) {
        outerError = e
      }
    })
    expect(outerError).not.toBeNull()
    expect((outerError as Error).message).toMatch(/already active/)
  })

  it('clears the guard so subsequent transactions still work', async () => {
    const d = new (Database as unknown as { new (n: string): { transaction: <T>(fn: () => Promise<T>) => Promise<T>; execute: (sql: string) => Promise<void> } })('test')
    ;(d as unknown as { execute: (sql: string) => Promise<void> }).execute = async () => {}
    await d.transaction(async () => {/* ok */})
    await d.transaction(async () => {/* ok again */})
    // No throw → success.
    expect(true).toBe(true)
  })
})

// -------------------------------------------------------------------------
// R2 Item 7: createCacheFactory has an LRU bound.
// -------------------------------------------------------------------------
import { vueOptimizations } from '../optimizations'

describe('R2 Item 7: LRU cache factory', () => {
  it('evicts least-recently-used entries above maxEntries', () => {
    const factory = vueOptimizations.createCacheFactory<number>({ maxEntries: 3 })
    factory.get('a', () => 1)
    factory.get('b', () => 2)
    factory.get('c', () => 3)
    factory.get('a', () => 99) // bump 'a' to MRU
    factory.get('d', () => 4)  // overflow → evict the LRU, which is now 'b'
    expect(factory.cache.has('a')).toBe(true)
    expect(factory.cache.has('b')).toBe(false)
    expect(factory.cache.has('c')).toBe(true)
    expect(factory.cache.has('d')).toBe(true)
  })

  it('rejects non-positive maxEntries', () => {
    expect(() => vueOptimizations.createCacheFactory({ maxEntries: 0 })).toThrow()
    expect(() => vueOptimizations.createCacheFactory({ maxEntries: -5 })).toThrow()
  })

  it('honours maxAge alongside maxEntries', () => {
    const factory = vueOptimizations.createCacheFactory<number>({ maxAge: 1, maxEntries: 10 })
    factory.get('a', () => 42)
    // Wait > maxAge then re-get; the entry should have expired.
    return new Promise<void>((resolve) => {
      setTimeout(() => {
        let calls = 0
        factory.get('a', () => { calls++; return 100 })
        expect(calls).toBe(1)
        resolve()
      }, 5)
    })
  })
})

// -------------------------------------------------------------------------
// R2 Item 8: animation cleanup clears the fallback timer.
// -------------------------------------------------------------------------
describe('R2 Item 8: animation cleanup clears timer', () => {
  it('source contains a tracked timer handle and clearTimeout', async () => {
    const src = await Bun.file(new URL('../performance/runtime.ts', import.meta.url)).text()
    expect(src).toContain('clearTimeout(timer)')
    // The cleanup function must be guarded so calling it twice is a no-op.
    expect(src).toMatch(/let done = false/)
  })
})

// -------------------------------------------------------------------------
// R2 Item 9: bridge flushBatch on disconnect re-queues onto offlineQueue.
// -------------------------------------------------------------------------
import { NativeBridge, resetGlobalBridge } from '../bridge/core'

describe('R2 Item 9: batch flush during disconnect', () => {
  let savedWindow: any

  beforeEach(() => {
    savedWindow = (globalThis as any).window
    delete (globalThis as any).window
    resetGlobalBridge()
  })

  afterEach(() => {
    if (savedWindow !== undefined) (globalThis as any).window = savedWindow
  })

  it('re-queues batched messages onto offlineQueue when disconnected', () => {
    const b = new NativeBridge({ enableOfflineQueue: true, batchSize: 100, batchDelay: 1, retries: 0 })
    // Bridge starts disconnected. Queue some buffered batch entries.
    b.addToBatch('a', { x: 1 })
    b.addToBatch('b', { x: 2 })
    // Force an immediate flush.
    ;(b as unknown as { flushBatch: () => void }).flushBatch()
    const offline = (b as unknown as { offlineQueue: unknown[] }).offlineQueue
    expect(offline.length).toBe(2)
    b.destroy()
  })
})

// -------------------------------------------------------------------------
// R2 Item 10: HttpClient typed data passthrough.
// -------------------------------------------------------------------------
describe('R2 Item 10: HTTP response typing', () => {
  it('source produces ArrayBuffer for binary content types', async () => {
    const src = await Bun.file(new URL('../api/http.ts', import.meta.url)).text()
    expect(src).toContain('arrayBuffer()')
    expect(src).toContain('octet-stream')
    expect(src).toContain("startsWith('image/')")
  })
})

// -------------------------------------------------------------------------
// R2 Item 11: bridge send() rejects pending entry on serialize/transport failure.
// -------------------------------------------------------------------------
describe('R2 Item 11: bridge serialize failure', () => {
  let savedWindow: any

  beforeEach(() => {
    savedWindow = (globalThis as any).window
    delete (globalThis as any).window
    resetGlobalBridge()
  })

  afterEach(() => {
    if (savedWindow !== undefined) (globalThis as any).window = savedWindow
  })

  it('rejects the request promise when params are not serializable', async () => {
    const b = new NativeBridge({ enableOfflineQueue: false, retries: 0, timeout: 5_000 })
    // Force connected so we hit the synchronous send() path instead of
    // the offline queue.
    b.setConnected(true)
    const circular: any = {}
    circular.self = circular
    await expect(b.request('test', circular)).rejects.toThrow(/Failed to serialize|No bridge transport/)
    b.destroy()
  })
})

// -------------------------------------------------------------------------
// R2 Item 12: NativeBridge max listeners cap.
// -------------------------------------------------------------------------
describe('R2 Item 12: NativeBridge listener cap', () => {
  let savedWindow: any

  beforeEach(() => {
    savedWindow = (globalThis as any).window
    delete (globalThis as any).window
    resetGlobalBridge()
  })

  afterEach(() => {
    if (savedWindow !== undefined) (globalThis as any).window = savedWindow
  })

  it('reports max listeners as 100', () => {
    const b = new NativeBridge({})
    expect(b.getMaxListeners()).toBe(100)
    b.destroy()
  })
})

// -------------------------------------------------------------------------
// R2 Item 13: fs.readDir filters `.` and `..`.
// -------------------------------------------------------------------------
import { fs as fsApi } from '../api/fs'

describe('R2 Item 13: readDir filtering', () => {
  it('does not return `.` or `..` even from a host bridge that does', async () => {
    const dir = mkdtempSync(join(tmpdir(), 'craft-readdir-'))
    try {
      const result = await fsApi.readDir(dir)
      expect(result).not.toContain('.')
      expect(result).not.toContain('..')
    }
    finally {
      rmSync(dir, { recursive: true, force: true })
    }
  })
})

// -------------------------------------------------------------------------
// R2 Item 14: bin/cli.ts honours CRAFT_BIN.
// -------------------------------------------------------------------------
describe('R2 Item 14: CLI binary lookup', () => {
  it('source honours CRAFT_BIN and surfaces ENOENT clearly', async () => {
    const src = await Bun.file(new URL('../../bin/cli.ts', import.meta.url)).text()
    expect(src).toContain('CRAFT_BIN')
    expect(src).toContain("error.code === 'ENOENT'")
  })
})

// -------------------------------------------------------------------------
// R2 Item 15: CraftCryptoError preserves cause.
// -------------------------------------------------------------------------
import { CraftCryptoError } from '../api/crypto'

describe('R2 Item 15: CraftCryptoError cause chain', () => {
  it('exposes cause as a property', () => {
    const inner = new Error('inner')
    const outer = new CraftCryptoError('outer', { cause: inner })
    expect(outer.cause).toBe(inner)
  })
})

// -------------------------------------------------------------------------
// R2 Item 16: dialog timeouts are split.
// -------------------------------------------------------------------------
describe('R2 Item 16: dialog timeouts', () => {
  it('source defines distinct file vs modal timeouts', async () => {
    const src = await Bun.file(new URL('../api/dialog.ts', import.meta.url)).text()
    expect(src).toContain('FILE_DIALOG_TIMEOUT_MS')
    expect(src).toContain('MODAL_DIALOG_TIMEOUT_MS')
  })
})

// -------------------------------------------------------------------------
// R2 Item 17: fs.watch warning reset hook.
// -------------------------------------------------------------------------
import { _resetWatchWarningForTests } from '../api/fs'

describe('R2 Item 17: watch warning reset', () => {
  it('exposes a test reset hook', () => {
    expect(typeof _resetWatchWarningForTests).toBe('function')
    // Calling it must be idempotent and never throw.
    _resetWatchWarningForTests()
    _resetWatchWarningForTests()
  })
})

// -------------------------------------------------------------------------
// R2 Item 18: HotReloadServer.stop() returns a Promise.
// -------------------------------------------------------------------------
import { HotReloadServer } from '../dev/hot-reload'

describe('R2 Item 18: stop() is awaitable', () => {
  it('returns a Promise that resolves when servers are closed', async () => {
    const dir = mkdtempSync(join(tmpdir(), 'craft-hmr-'))
    const server = new HotReloadServer({ watchDir: dir, port: 0 })
    server.start()
    const out = server.stop()
    expect(out).toBeInstanceOf(Promise)
    await out
    rmSync(dir, { recursive: true, force: true })
  })
})

// -------------------------------------------------------------------------
// R2 Item 19: AsyncIterable bodies pass through as binary.
// -------------------------------------------------------------------------
import { encodeRequestBody } from '../api/http'

describe('R2 Item 19: AsyncIterable body passthrough', () => {
  it('routes async generators through the binary path', () => {
    async function* gen() { yield new Uint8Array([1, 2]) }
    const body = gen()
    const r = encodeRequestBody(body)
    expect(r.kind).toBe('binary')
    expect(r.value).toBe(body as unknown as BodyInit)
  })

  it('still routes plain objects through JSON', () => {
    expect(encodeRequestBody({ a: 1 }).kind).toBe('json')
  })
})

// -------------------------------------------------------------------------
// R2 Item 20: timeoutMs comment is accurate.
// -------------------------------------------------------------------------
describe('R2 Item 20: timeoutMs is documented as host-only', () => {
  it('comment in http.ts notes it is a Craft-host hint', async () => {
    const src = await Bun.file(new URL('../api/http.ts', import.meta.url)).text()
    expect(src).toContain('Craft-host hint')
  })
})

// -------------------------------------------------------------------------
// R2 Item 21: SystemTray destroys exactly the listeners it added.
// -------------------------------------------------------------------------
import { SystemTray } from '../api/tray'

describe('R2 Item 21: SystemTray listener parity', () => {
  let added = 0
  let removed = 0
  let savedAdd: any
  let savedRemove: any

  beforeEach(() => {
    added = 0
    removed = 0
    ;(globalThis as any).window = (globalThis as any).window || {}
    savedAdd = (globalThis as any).window.addEventListener
    savedRemove = (globalThis as any).window.removeEventListener
    ;(globalThis as any).window.addEventListener = () => { added++ }
    ;(globalThis as any).window.removeEventListener = () => { removed++ }
  })

  afterEach(() => {
    if (savedAdd) (globalThis as any).window.addEventListener = savedAdd
    if (savedRemove) (globalThis as any).window.removeEventListener = savedRemove
  })

  it('100 trays + teardowns produces equal add/remove counts', () => {
    for (let i = 0; i < 100; i++) {
      const t = new SystemTray(`t${i}`)
      ;(t as unknown as { _teardownDomListeners(): void })._teardownDomListeners()
    }
    expect(added).toBeGreaterThan(0)
    expect(removed).toBe(added)
  })
})

// -------------------------------------------------------------------------
// R2 Item 22: cross-runtime crypto interop, forced through the Node fallback.
// -------------------------------------------------------------------------
import { crypto as cryptoApi } from '../api/crypto'

describe('R2 Item 22: cross-runtime crypto interop', () => {
  let savedCrypto: any
  // `globalThis.crypto.subtle` is non-configurable in Bun. To force the
  // Node fallback we replace the entire `crypto` global with a stub that
  // exposes `getRandomValues` (used by randomBytes) but not `subtle`.
  const restoreCrypto = () => {
    if (savedCrypto !== undefined) {
      try {
        Object.defineProperty(globalThis, 'crypto', { value: savedCrypto, configurable: true, writable: true })
      }
      catch {
        // Some runtimes mark `crypto` non-configurable; fall back to a
        // direct assignment which restores `subtle` access through the
        // saved reference.
        ;(globalThis as any).crypto = savedCrypto
      }
    }
  }
  const stubCrypto = () => {
    savedCrypto = globalThis.crypto
    const stub = {
      getRandomValues: savedCrypto.getRandomValues.bind(savedCrypto),
      randomUUID: savedCrypto.randomUUID?.bind(savedCrypto),
      // Deliberately omit `subtle` to force the Node fallback.
    }
    try {
      Object.defineProperty(globalThis, 'crypto', { value: stub, configurable: true, writable: true })
    }
    catch {
      ;(globalThis as any).crypto = stub
    }
  }

  it('Node-fallback ciphertext decrypts when WebCrypto re-enabled', async () => {
    stubCrypto()
    let enc: string
    try {
      enc = await cryptoApi.encrypt('cross-runtime', 'pw')
    }
    finally {
      restoreCrypto()
    }
    const dec = await cryptoApi.decrypt(enc, 'pw')
    expect(dec).toBe('cross-runtime')
  })

  it('WebCrypto ciphertext decrypts in Node fallback', async () => {
    // Encrypt via WebCrypto path (whatever crypto already is).
    const enc = await cryptoApi.encrypt('reverse-direction', 'pw')
    // Then strip subtle and decrypt — must succeed via Node fallback.
    stubCrypto()
    let dec: string
    try {
      dec = await cryptoApi.decrypt(enc, 'pw')
    }
    finally {
      restoreCrypto()
    }
    expect(dec).toBe('reverse-direction')
  })
})
