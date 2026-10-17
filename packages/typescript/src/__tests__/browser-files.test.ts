import { describe, expect, it } from 'bun:test'
import { createBrowserPlatform } from '../browser'

async function fixture(run: (platform: Awaited<ReturnType<typeof createBrowserPlatform>>) => Promise<void>, extra: Record<string, unknown> = {}) {
  const data = new Map<string, string>()
  const saved = new Map<string, PropertyDescriptor | undefined>()
  const globals: Record<string, unknown> = {
    localStorage: { get length() { return data.size }, getItem: (key: string) => data.get(key) ?? null, setItem: (key: string, value: string) => data.set(key, value), removeItem: (key: string) => data.delete(key), key: (i: number) => [...data.keys()][i] ?? null },
    window: { addEventListener() {}, removeEventListener() {} },
    location: { origin: 'https://fixture.invalid', href: 'https://fixture.invalid/m' },
    navigator: { language: 'en', userAgent: 'Fixture' },
    ...extra,
  }
  for (const [key, value] of Object.entries(globals)) {
    saved.set(key, Object.getOwnPropertyDescriptor(globalThis, key))
    Object.defineProperty(globalThis, key, { configurable: true, writable: true, value })
  }
  let platform: Awaited<ReturnType<typeof createBrowserPlatform>> | undefined
  try { platform = await createBrowserPlatform({ namespace: 'fixture', tokenKey: 'auth_token' }); await run(platform) }
  finally {
    platform?.dispose()
    for (const [key, descriptor] of saved) { if (descriptor) Object.defineProperty(globalThis, key, descriptor); else Reflect.deleteProperty(globalThis, key) }
  }
}

describe('browser files across the JSON capability protocol', () => {
  it('materializes a descriptor back into a real File with unchanged bytes for multipart', async () => {
    await fixture(async (platform) => {
      const descriptor = await platform.call('Files', 'write', ['route.gpx', '<gpx/>', { type: 'application/gpx+xml' }], new AbortController().signal)
      const returned = platform.resolveFile(JSON.parse(JSON.stringify(descriptor))) as File
      expect(returned).toBeInstanceOf(File)
      expect(returned.name).toBe('route.gpx')
      expect(await returned.text()).toBe('<gpx/>')
      const form = new FormData(); form.append('file', returned)
      expect((form.get('file') as File).name).toBe('route.gpx')
      expect(await (form.get('file') as File).text()).toBe('<gpx/>')
    })
  })

  it('forgets prior account file handles and rejects work after disposal or cancellation', async () => {
    await fixture(async (platform) => {
      const signal = new AbortController().signal
      await platform.call('SecureStorage', 'set', ['auth.token', 'ava'], signal)
      const descriptor = await platform.call('Files', 'write', ['private.txt', 'private', {}], signal)
      await platform.call('SecureStorage', 'set', ['auth.token', 'ben'], signal)
      expect(platform.resolveFile(descriptor)).not.toBeInstanceOf(File)
      const aborted = new AbortController(); aborted.abort()
      await expect(platform.call('Files', 'write', ['cancelled.txt', 'no', {}], aborted.signal)).rejects.toMatchObject({ name: 'AbortError' })
      platform.dispose()
      await expect(platform.call('Files', 'write', ['disposed.txt', 'no', {}], signal)).rejects.toMatchObject({ name: 'AbortError' })
      expect(platform.capabilities).not.toContain('health')
      expect(platform.capabilities).not.toContain('push')
    })
  })

  it('clears cached browser videos and rejects downloads that settle after the clear', async () => {
    const entries = new Map<string, Response>()
    let holdCommit = false
    let committing = false
    let releaseCommit!: () => void
    const cache = {
      match: async (key: string | Request) => entries.get(typeof key === 'string' ? key : key.url)?.clone(),
      put: async (key: string, value: Response) => {
        if (holdCommit) {
          holdCommit = false
          committing = true
          await new Promise<void>(resolve => { releaseCommit = resolve })
        }
        entries.set(key, value)
      },
      keys: async () => [...entries.keys()].map(url => new Request(url)),
      delete: async (key: Request) => entries.delete(key.url),
    }
    const caches = { open: async () => cache, delete: async () => { entries.clear(); return true } }
    let release!: (value: Response) => void
    let held = false
    await fixture(async (platform) => {
      const signal = new AbortController().signal
      const url = 'https://fixture.invalid/video.mp4'
      entries.set(url, new Response('old video'))
      expect(await platform.call('Media', 'clear', [], signal)).toBe(1)
      expect(await platform.call('Media', 'path', [url], signal)).toBeNull()
      const old = platform.call('Media', 'keep', [url, {}], signal)
      while (!held) await Bun.sleep(1)
      expect(await platform.call('Media', 'clear', [], signal)).toBe(0)
      release(new Response('cancelled download'))
      await expect(old).rejects.toMatchObject({ name: 'AbortError' })
      expect(entries.size).toBe(0)
      expect(await platform.call('Media', 'keep', [url, {}], signal)).toMatchObject({ ok: true })
      expect(await entries.get(url)?.text()).toBe('new video')
      // Cache.put is not abortable: the clear must wait for it, and the
      // replacement transfer must commit after the clear finishes.
      holdCommit = true
      const nextUrl = 'https://fixture.invalid/committing.mp4'
      const oldCommit = platform.call('Media', 'keep', [nextUrl, {}], signal)
      while (!committing) await Bun.sleep(1)
      const clearing = platform.call('Media', 'clear', [], signal)
      const replacement = platform.call('Media', 'keep', [nextUrl, {}], signal)
      releaseCommit()
      await expect(oldCommit).rejects.toMatchObject({ name: 'AbortError' })
      expect(await clearing).toBe(2)
      expect(await replacement).toMatchObject({ ok: true })
      expect([...entries.keys()]).toEqual([nextUrl])
    }, {
      window: { addEventListener() {}, removeEventListener() {}, caches }, caches,
      fetch: async () => {
        if (!held) { held = true; return new Promise<Response>(resolve => { release = resolve }) }
        return new Response('new video')
      },
    })
  })
})
