import { expect, test } from 'bun:test'
import { createBrowserPlatform } from '../browser'

async function fixture(run: (host: Awaited<ReturnType<typeof createBrowserPlatform>>, sounds: FakeAudio[]) => Promise<void>) {
  const sounds: FakeAudio[] = []
  const data = new Map<string, string>()
  const saved = new Map<string, PropertyDescriptor | undefined>()
  const globals = {
    localStorage: { get length() { return data.size }, getItem: (key: string) => data.get(key) ?? null, setItem: (key: string, value: string) => { data.set(key, value) }, removeItem: (key: string) => data.delete(key), key: (i: number) => [...data.keys()][i] ?? null },
    window: { addEventListener() {}, removeEventListener() {} }, document: undefined,
    location: { origin: 'https://fixture.invalid', href: 'https://fixture.invalid/' },
    navigator: { language: 'en', userAgent: 'Fixture' },
    Audio: class extends FakeAudio { constructor(src: string) { super(src); sounds.push(this) } },
  }
  for (const [key, value] of Object.entries(globals)) { saved.set(key, Object.getOwnPropertyDescriptor(globalThis, key)); Object.defineProperty(globalThis, key, { configurable: true, writable: true, value }) }
  let host: Awaited<ReturnType<typeof createBrowserPlatform>> | undefined
  try { host = await createBrowserPlatform(); await run(host, sounds) }
  finally { host?.dispose(); for (const [key, descriptor] of saved) { if (descriptor) Object.defineProperty(globalThis, key, descriptor); else Reflect.deleteProperty(globalThis, key) } }
}
class FakeAudio {
  paused = true
  volume = 1
  loop = false
  onended: (() => void) | null = null
  onerror: (() => void) | null = null
  error = null
  constructor(public src: string) {}
  async play() { this.paused = false }
  pause() { this.paused = true }
  removeAttribute(name: string) { if (name === 'src') this.src = '' }
}
const signal = () => new AbortController().signal

test('simultaneous plays of one ID retain only the newest audio owner', async () => {
  await fixture(async (host, sounds) => {
    const first = host.call('Audio', 'play', ['ambient', '/birds.wav', { loop: true }], signal()).catch(error => error)
    const second = host.call('Audio', 'play', ['ambient', '/birds.wav', { loop: true }], signal())
    expect(await first).toMatchObject({ name: 'AbortError' })
    expect(await second).toBe(true)
    expect(sounds.filter(sound => !sound.paused)).toHaveLength(1)
    await host.call('Audio', 'stopAll', [], signal())
    expect(sounds.every(sound => sound.paused && !sound.src)).toBe(true)
  })
})

test('stopping or disposing pending media never constructs or starts delayed audio', async () => {
  for (const action of ['stop', 'stopAll', 'dispose']) await fixture(async (host, sounds) => {
    let release!: (url: string) => void
    let entered!: () => void
    const waiting = new Promise<void>(resolve => { entered = resolve })
    host.resolveMedia = () => { entered(); return new Promise(resolve => { release = resolve }) }
    const playing = host.call('Audio', 'play', ['ambient', '/birds.wav', {}], signal()).catch(error => error)
    await waiting
    if (action === 'dispose') host.dispose()
    else await host.call('Audio', action, ['ambient'], signal())
    release('/birds.wav')
    expect(await playing).toMatchObject({ name: 'AbortError' })
    expect(sounds).toHaveLength(0)
  })
})

test('disposal and cancellation silence an audio element whose play promise is pending', async () => {
  for (const dispose of [true, false]) await fixture(async (host, sounds) => {
    let release!: () => void
    let entered!: () => void
    const waiting = new Promise<void>(resolve => { entered = resolve })
    const original = FakeAudio.prototype.play
    FakeAudio.prototype.play = async function () { this.paused = false; entered(); await new Promise<void>(resolve => { release = resolve }) }
    try {
      const abort = new AbortController()
      const playing = host.call('Audio', 'play', ['ambient', '/birds.wav', {}], abort.signal).catch(error => error)
      await waiting
      if (dispose) host.dispose(); else abort.abort()
      expect(sounds.every(sound => sound.paused && !sound.src)).toBe(true)
      release()
      expect(await playing).toMatchObject({ name: 'AbortError' })
    }
    finally { FakeAudio.prototype.play = original }
  })
})

test('a replaced element ending cannot remove its successor, and rejected playback releases ownership', async () => {
  await fixture(async (host, sounds) => {
    await host.call('Audio', 'play', ['ambient', '/one.wav', {}], signal())
    const ended = sounds[0]!.onended!
    await host.call('Audio', 'play', ['ambient', '/two.wav', {}], signal())
    ended()
    await host.call('Audio', 'stopAll', [], signal())
    expect(sounds.every(sound => sound.paused && !sound.src)).toBe(true)
    const original = FakeAudio.prototype.play
    FakeAudio.prototype.play = async () => { throw new Error('Autoplay denied') }
    try { await expect(host.call('Audio', 'play', ['ambient', '/denied.wav', {}], signal())).rejects.toThrow('Autoplay denied') }
    finally { FakeAudio.prototype.play = original }
    expect(sounds.every(sound => sound.paused && !sound.src)).toBe(true)
  })
})
