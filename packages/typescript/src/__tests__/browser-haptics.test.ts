import { describe, expect, it } from 'bun:test'
import { browserHapticPattern, createBrowserPlatform } from '../browser'

function memoryStorage(): Storage {
  const data = new Map<string, string>()
  return { get length() { return data.size }, key: index => [...data.keys()][index] ?? null, getItem: key => data.get(key) ?? null, setItem: (key, value) => { data.set(key, String(value)) }, removeItem: key => { data.delete(key) }, clear: () => data.clear() }
}

type Platform = Awaited<ReturnType<typeof createBrowserPlatform>>

async function withPlatform(run: (platform: Platform, saved: Storage) => Promise<void>, extra: Record<string, unknown> = {}, options: Parameters<typeof createBrowserPlatform>[0] = {}) {
  const saved = memoryStorage()
  const previous = new Map<string, PropertyDescriptor | undefined>()
  const globals: Record<string, unknown> = {
    localStorage: saved,
    window: { addEventListener() {}, removeEventListener() {} },
    location: { origin: 'https://fixture.invalid', href: 'https://fixture.invalid/m' },
    navigator: { language: 'en', userAgent: 'Fixture' },
    ...extra,
  }
  for (const [key, value] of Object.entries(globals)) {
    previous.set(key, Object.getOwnPropertyDescriptor(globalThis, key))
    Object.defineProperty(globalThis, key, { configurable: true, writable: true, value })
  }
  let platform: Platform | undefined
  try {
    platform = await createBrowserPlatform({ namespace: 'fixture', tokenKey: 'auth_token', ...options })
    await run(platform, saved)
  }
  finally {
    platform?.dispose()
    for (const [key, descriptor] of previous) { if (descriptor) Object.defineProperty(globalThis, key, descriptor); else Reflect.deleteProperty(globalThis, key) }
  }
}

describe('browser host haptics', () => {
  it('resolves without the Vibration API instead of rejecting', async () => {
    await withPlatform(async (platform) => {
      const signal = new AbortController().signal
      expect(await platform.call('Haptics', 'impact', ['heavy'], signal)).toBe(false)
      expect(await platform.call('Haptics', 'notification', ['error'], signal)).toBe(false)
      expect(await platform.call('Haptics', 'selection', [], signal)).toBe(false)
      expect(await platform.call('Haptics', 'prepare', [], signal)).toBe(false)
      expect(platform.capabilities).not.toContain('haptics')
    })
  })

  it('plays each style through navigator.vibrate and survives a throwing one', async () => {
    const played: unknown[] = []
    let throwing = false
    const navigator = { language: 'en', userAgent: 'Fixture', vibrate: (pattern: unknown) => { if (throwing) throw new Error('blocked'); played.push(pattern); return true } }
    await withPlatform(async (platform) => {
      const signal = new AbortController().signal
      expect(platform.capabilities).toContain('haptics')
      expect(await platform.call('Haptics', 'impact', ['light'], signal)).toBe(true)
      expect(await platform.call('Haptics', 'impact', ['success'], signal)).toBe(true)
      expect(await platform.call('Haptics', 'notification', ['warning'], signal)).toBe(true)
      expect(await platform.call('Haptics', 'selection', [], signal)).toBe(true)
      expect(await platform.call('Haptics', 'prepare', ['impact'], signal)).toBe(false)
      throwing = true
      expect(await platform.call('Haptics', 'impact', ['medium'], signal)).toBe(false)
    }, { navigator })
    expect(played).toEqual([10, [10, 30, 10], [30, 30, 30], 5])
  })

  it('maps the iOS styles to Vibration API timings', () => {
    expect(browserHapticPattern('impact', 'rigid')).toBe(25)
    expect(browserHapticPattern('impact', 'soft')).toBe(8)
    expect(browserHapticPattern('impact', 'unknown')).toBe(20)
    expect(browserHapticPattern('impact', undefined)).toBe(20)
    expect(browserHapticPattern('impact', 'selection')).toBe(5)
    expect(browserHapticPattern('notification', undefined)).toEqual([10, 30, 10])
    expect(browserHapticPattern('notification', 'error')).toEqual([50, 50, 50, 50, 50])
    expect(browserHapticPattern('prepare', 'impact')).toBeNull()
  })
})
