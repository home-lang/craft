import { describe, expect, it } from 'bun:test'
import { createBrowserPlatform } from '../browser'
import { createBrowserStorage } from '../browser/storage'

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

describe('browser host session', () => {
  it('reports each sign-in, account switch and sign-out once, with the previous token', async () => {
    await withPlatform(async (platform) => {
      const signal = new AbortController().signal
      const messages: unknown[] = []
      const heard: unknown[] = []
      platform.emit((type, payload) => { if (type === 'SESSION_CHANGED') messages.push(payload) })
      const session = platform.craft.session as { key: string, token: () => string | null, onChange: (cb: (t: string | null, p: string | null) => void) => () => void }
      expect(session.key).toBe('auth.token')
      expect(session.token()).toBeNull()
      const stop = session.onChange((token, previous) => heard.push([token, previous, session.token()]))
      await platform.call('SecureStorage', 'set', ['auth.token', 'ava'], signal)
      await platform.call('SecureStorage', 'set', ['auth.token', 'ava'], signal)
      await platform.call('SecureStorage', 'set', ['private-key', 'not-a-session'], signal)
      await platform.call('SecureStorage', 'set', ['auth.token', 'ben'], signal)
      await platform.call('SecureStorage', 'remove', ['auth.token'], signal)
      stop()
      await platform.call('SecureStorage', 'set', ['auth.token', 'cy'], signal)
      expect(heard).toEqual([['ava', null, 'ava'], ['ben', 'ava', 'ben'], [null, 'ben', null]])
      expect(messages).toEqual([
        { key: 'auth.token', token: 'ava', previous: null },
        { key: 'auth.token', token: 'ben', previous: 'ava' },
        { key: 'auth.token', token: null, previous: 'ben' },
        { key: 'auth.token', token: 'cy', previous: null },
      ])
    })
  })

  it('follows a configured token key', async () => {
    await withPlatform(async (platform, saved) => {
      const signal = new AbortController().signal
      const heard: unknown[] = []
      ;(platform.craft.session as any).onChange((token: string | null) => heard.push(token))
      await platform.call('SecureStorage', 'set', ['auth.token', 'ignored'], signal)
      await platform.call('SecureStorage', 'set', ['hq.session', 'ava'], signal)
      expect(saved.getItem('auth_token')).toBe('ava')
      expect((platform.craft.session as any).token()).toBe('ava')
      expect(heard).toEqual(['ava'])
    }, {}, { sessionTokenKey: 'hq.session' })
  })
})

describe('browser storage session callback', () => {
  it('reports a cross-tab change once storage moved to the new account', async () => {
    const saved = memoryStorage()
    const heard: unknown[] = []
    const browser = await createBrowserStorage({
      storage: saved, namespace: 'app', tokenKey: 'auth_token', hash: async value => `hash-${value}`, changed: () => {}, lock: null,
      sessionChanged: (token, previous) => heard.push([token, previous, browser.scope()]),
    })
    saved.setItem('auth_token', 'ava')
    await browser.accountChanged()
    saved.setItem('auth_token', 'ben')
    saved.setItem('auth_token', 'cy')
    await Promise.all([browser.accountChanged(), browser.accountChanged()])
    expect(heard).toEqual([['ava', null, 'hash-ava'], ['cy', 'ava', 'hash-cy']])
  })
})
