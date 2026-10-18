import { secureUUID } from './bridge/ids'
import { createBrowserStorage } from './browser/storage'
import { showBrowserDialog, type BrowserDialogOptions } from './browser/dialogs'

export interface BrowserPlatformOptions {
  namespace?: string
  tokenKey?: string
  accountKeys?: string[]
  /** App metadata shared with native hosts; no device capabilities are implied. */
  appURL?: string
  locale?: string
  /** Application-owned deep-link schemes; arbitrary executable schemes are rejected. */
  urlSchemes?: string[]
}

export interface BrowserPlatform {
  craft: Record<string, unknown>
  capabilities: string[]
  call: (module: string, method: string, args: unknown[], signal: AbortSignal) => Promise<unknown>
  navigate: (path: string, replace?: boolean) => void
  emit: (listener: (type: string, payload: unknown) => void) => () => void
  resolveMedia: (url: string) => Promise<string>
  resolveFile: (value: unknown) => unknown
  dispose: () => void
}

type Options = Record<string, unknown>
const object = (value: unknown): Options => value !== null && typeof value === 'object' ? value as Options : {}
const unsupported = (module: string, method: string): never => { throw Object.assign(new Error(`${module}.${method} is not available in this browser`), { code: 'UNSUPPORTED' }) }

/** Real browser counterparts for the portable Craft services. Device-only APIs remain absent. */
export async function createBrowserPlatform(options: BrowserPlatformOptions = {}): Promise<BrowserPlatform> {
  const namespace = options.namespace ?? 'craft'
  const protocols = new Set(['https:', 'http:', 'mailto:', 'tel:', 'webcal:', ...(options.urlSchemes ?? []).filter(name => /^[a-z][a-z\d+.-]*$/i.test(name) && !/^(?:javascript|data|vbscript|file)$/i.test(name)).map(name => name + ':')])
  const listeners = new Set<(type: string, payload: unknown) => void>()
  const emit = (type: string, payload: unknown): void => { for (const listener of listeners) listener(type, payload) }
  const persistence = await createBrowserStorage({
    storage: localStorage, namespace, tokenKey: options.tokenKey ?? 'craft.auth.token', accountKeys: options.accountKeys,
    hash: async value => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value))), byte => byte.toString(16).padStart(2, '0')).join(''),
    changed: name => emit('SNAPSHOT_CHANGED', { name }),
  })
  await persistence.craft.snapshots.set('app', { apiBase: `${location.origin}/api`, locale: options.locale ?? (navigator.language.startsWith('de') ? 'de' : 'en') })
  const files = new Map<string, File>()
  const mediaURLs = new Map<string, string>()
  const sounds = new Map<string, HTMLAudioElement>()
  const fades = new Map<HTMLAudioElement, { frame: number, done: () => void }>()
  const cancelFade = (sound: HTMLAudioElement): void => {
    const fade = fades.get(sound)
    if (fade) { cancelAnimationFrame(fade.frame); fades.delete(sound); fade.done() }
  }
  const fade = (sound: HTMLAudioElement, volume: number, milliseconds: number): Promise<void> => {
    cancelFade(sound)
    const to = Math.max(0, Math.min(1, volume))
    if (!Number.isFinite(milliseconds) || milliseconds <= 0) { sound.volume = to; return Promise.resolve() }
    const from = sound.volume
    const start = performance.now()
    return new Promise((resolve) => {
      const tick = (now: number): void => {
        const progress = Math.min(1, (now - start) / milliseconds)
        sound.volume = from + (to - from) * progress
        if (progress < 1) fades.set(sound, { frame: requestAnimationFrame(tick), done: resolve })
        else { fades.delete(sound); resolve() }
      }
      fades.set(sound, { frame: requestAnimationFrame(tick), done: resolve })
    })
  }
  const stopSound = async (id: string, milliseconds = 0): Promise<void> => {
    const sound = sounds.get(id)
    if (!sound) return
    await fade(sound, 0, sound.paused ? 0 : milliseconds)
    if (sounds.get(id) !== sound) return
    sound.pause(); sound.removeAttribute('src'); sounds.delete(id)
  }
  const lifetime = new AbortController()
  let account = new AbortController()
  let mediaTransfers = new AbortController()
  let mediaWrites: Promise<unknown> = Promise.resolve()
  // Cache.put cannot be aborted. Clear waits for any already committing
  // download, while later downloads commit after that clear completes.
  const writeMedia = <T>(work: () => Promise<T>): Promise<T> => {
    const write = mediaWrites.then(work)
    mediaWrites = write.catch(() => {})
    return write
  }
  let mediaScope = persistence.scope()
  let wakeLock: WakeLockSentinel | null = null
  let disposed = false
  const cacheName = (): string => `${namespace}:media:${persistence.scope()}`
  const file = (body: BlobPart[], name: string, type: string): { path: string, name: string, type: string, size: number } => {
    const created = new File(body, name, { type }) as File & { path: string }
    created.path = URL.createObjectURL(created)
    files.set(created.path, created)
    return { path: created.path, name: created.name, type: created.type, size: created.size }
  }
  const getFile = (value: unknown): File | null => value instanceof File ? value : files.get(typeof value === 'string' ? value : String(object(value).path ?? '')) ?? null
  const navigate = (path: string, replace = false): void => {
    const url = new URL(path, location.href)
    if (!protocols.has(url.protocol)) throw new TypeError('Unsupported navigation URL')
    if (url.origin === location.origin && !url.pathname.startsWith('/')) throw new TypeError('Invalid application path')
    if (replace) location.replace(url.href)
    else location.assign(url.href)
  }
  const resetAccount = async (): Promise<void> => {
    const previousCache = `${namespace}:media:${mediaScope}`
    account.abort()
    account = new AbortController()
    for (const path of files.keys()) URL.revokeObjectURL(path)
    for (const path of mediaURLs.values()) URL.revokeObjectURL(path)
    files.clear(); mediaURLs.clear()
    for (const audio of sounds.values()) { cancelFade(audio); audio.pause(); audio.src = '' }
    sounds.clear()
    await persistence.accountChanged()
    mediaScope = persistence.scope()
    if ('caches' in window && previousCache !== cacheName()) await caches.delete(previousCache)
  }
  const storageEvent = (event: StorageEvent): void => {
    if (event.key === (options.tokenKey ?? 'craft.auth.token') || event.key === null)
      void resetAccount().then(() => { if (!disposed) location.reload() })
  }
  window.addEventListener('storage', storageEvent)
  const capabilityNames = ['storage', 'secureStorage', 'lifecycle', 'dialog', 'browser', 'linking', 'files', 'share', 'device']
  if (persistence.atomicStorage) capabilityNames.push('storageCompareAndSet', 'storageSetIfAbsent')
  if (typeof globalThis.crypto?.randomUUID === 'function' || typeof globalThis.crypto?.getRandomValues === 'function') capabilityNames.push('crypto')
  if (navigator.clipboard) capabilityNames.push('clipboard')
  if ('vibrate' in navigator) capabilityNames.push('haptics')
  if ('speechSynthesis' in window) capabilityNames.push('speech')
  if ('wakeLock' in navigator) capabilityNames.push('keepAwake')
  if ('caches' in window) capabilityNames.push('media')
  if (typeof Audio === 'function') capabilityNames.push('audio')

  const platform: BrowserPlatform = {
    craft: { ...persistence.craft },
    capabilities: capabilityNames,
    navigate,
    emit(listener) { listeners.add(listener); return () => listeners.delete(listener) },
    resolveFile(value) {
      if (!value || typeof value !== 'object') return value
      const saved = getFile(value)
      return saved ? Object.assign(saved, Object.fromEntries(Object.entries(value).filter(([key]) => !['name', 'size', 'type'].includes(key)))) : value
    },
    async resolveMedia(url) {
      if (!('caches' in window)) return url
      const scope = persistence.scope()
      const transfer = mediaTransfers.signal
      const existing = mediaURLs.get(url)
      if (existing) return existing
      const saved = await (await caches.open(cacheName())).match(url)
      if (!saved) return url
      const local = URL.createObjectURL(await saved.blob())
      if (disposed || transfer.aborted || scope !== persistence.scope()) { URL.revokeObjectURL(local); return url }
      mediaURLs.set(url, local)
      return local
    },
    async call(module, method, args, signal) {
      if (disposed || signal.aborted) throw new DOMException('Aborted', 'AbortError')
      signal = AbortSignal.any([signal, lifetime.signal, account.signal])
      const first = object(args[0])
      if (module === 'Storage' || module === 'SecureStorage') {
        const before = persistence.craft.secureStorage.getSync('auth.token')
        const answer = await persistence.call(module, method, args)
        if (before !== persistence.craft.secureStorage.getSync('auth.token')) await resetAccount()
        return answer
      }
      if (module === 'Crypto' && method === 'randomUUID') return secureUUID()
      if (module === 'Dialog') return showBrowserDialog(method, first as BrowserDialogOptions, signal)
      if (module === 'Device' && method === 'getInfo') return { platform: 'web', userAgent: navigator.userAgent, language: navigator.language, native: false }
      if (module === 'Haptics') { if (typeof navigator.vibrate !== 'function') return unsupported(module, method); navigator.vibrate(method === 'selection' ? 5 : 10); return true }
      if (module === 'Clipboard') { if (!navigator.clipboard) return unsupported(module, method); if (method === 'write') { await navigator.clipboard.writeText(String(args[0])); return true } if (method === 'read') return navigator.clipboard.readText() }
      if (module === 'Linking') { const url = new URL(String(args[0]), location.href); const allowed = protocols.has(url.protocol); if (method === 'canOpenURL') return allowed; if (method === 'openURL' && allowed) { navigate(url.href); return true } return false }
      if (module === 'Browser' && method === 'open') { const url = new URL(String(args[0]), location.href); if (!['https:', 'http:'].includes(url.protocol)) throw new TypeError('Browser URLs must use HTTP or HTTPS'); const popup = window.open('about:blank', '_blank'); if (!popup) throw Object.assign(new Error('Allow popups to open this page'), { code: 'POPUP_BLOCKED' }); popup.opener = null; popup.location.replace(url.href); return { opened: true } }
      if (module === 'Files') {
        if (method === 'pickImage' || method === 'pickVideo') return new Promise((resolve, reject) => {
          const input = document.createElement('input'); input.type = 'file'; input.accept = method === 'pickVideo' ? 'video/*' : 'image/*'; input.style.display = 'none'; if (first.source === 'camera') input.setAttribute('capture', 'environment')
          const done = (value: unknown): void => { signal.removeEventListener('abort', abort); input.remove(); resolve(value) }
          const abort = (): void => { signal.removeEventListener('abort', abort); input.remove(); reject(signal.reason) }
          signal.addEventListener('abort', abort, { once: true }); input.addEventListener('cancel', () => done(null), { once: true }); input.onchange = () => { const chosen = input.files?.[0]; if (chosen && typeof first.maxBytes === 'number' && chosen.size > first.maxBytes) { signal.removeEventListener('abort', abort); input.remove(); reject(Object.assign(new Error('The selected video is too large'), { code: 'FILE_TOO_LARGE' })); return } done(chosen ? file([chosen], chosen.name, chosen.type) : null) }; document.body.append(input); input.click()
        })
        if (method === 'download') {
          const settings = object(args[1]); const response = await fetch(String(args[0]), { headers: settings.headers as HeadersInit, signal, cache: 'no-store' })
          if (!response.ok) return { ok: false, status: response.status, body: await response.text() }
          const body = await response.blob(); signal.throwIfAborted(); const disposition = response.headers.get('content-disposition') ?? ''; const name = typeof settings.name === 'string' ? settings.name : /filename="?([^";]+)/i.exec(disposition)?.[1] ?? 'download'
          return Object.assign(file([body], name, body.type), { ok: true, status: response.status })
        }
        if (method === 'write') { const settings = object(args[2]); const contents = settings.encoding === 'base64' ? Uint8Array.from(atob(String(args[1])), letter => letter.charCodeAt(0)) : String(args[1]); return file([contents], String(args[0]), String(settings.type ?? 'application/octet-stream')) }
        if (method === 'remove') { const path = String(args[0]); const found = files.delete(path); if (found) URL.revokeObjectURL(path); return found }
      }
      if (module === 'Share' && method === 'share') {
        const shared = Array.isArray(first.files) ? first.files.map(getFile).filter((value): value is File => value !== null) : []
        if (typeof first.image === 'string') {
          const response = await fetch(first.image, { signal })
          if (!response.ok) throw new Error(`Image download failed (${response.status})`)
          const image = await response.blob()
          signal.throwIfAborted()
          const name = /filename="?([^";]+)/i.exec(response.headers.get('content-disposition') ?? '')?.[1] ?? `image.${image.type === 'image/png' ? 'png' : 'jpg'}`
          shared.push(new File([image], name, { type: image.type }))
        }
        const url = typeof first.url === 'string' ? first.url : undefined
        const data: ShareData = { title: typeof first.title === 'string' ? first.title : undefined, text: typeof first.text === 'string' ? first.text : undefined, ...(shared.length ? { files: shared } : {}), ...(url ? { url } : {}) }
        const native = typeof navigator.share === 'function' && (!navigator.canShare || navigator.canShare(data))
        const answer = await showBrowserDialog('actionSheet', { title: String(first.title ?? 'Share'), buttons: [...(native ? [{ id: 'share', title: 'Share…' }] : []), ...(shared.length ? [{ id: 'download', title: 'Save file' }] : []), ...(url && navigator.clipboard ? [{ id: 'copy', title: 'Copy link' }] : [])] }, signal)
        if (answer === 'share') { try { await navigator.share(data); return true } catch (error) { if (error instanceof Error && error.name === 'AbortError') return false; throw error } }
        if (answer === 'copy' && url) { await navigator.clipboard.writeText(url); return true }
        if (answer === 'download') { for (const item of shared) { const link = document.createElement('a'); const local = URL.createObjectURL(item); link.href = local; link.download = item.name; document.body.append(link); link.click(); link.remove(); setTimeout(() => URL.revokeObjectURL(local), 1000) } return true }
        return false
      }
      if (module === 'KeepAwake' && method === 'set') { if (!('wakeLock' in navigator)) return unsupported(module, method); if (args[0] !== false) { await wakeLock?.release(); wakeLock = await navigator.wakeLock.request('screen') } else { await wakeLock?.release(); wakeLock = null } return true }
      if (module === 'Speech') {
        if (!('speechSynthesis' in window)) return unsupported(module, method)
        if (method === 'stop') { speechSynthesis.cancel(); return true }
        if (method === 'speak') return new Promise((resolve, reject) => { const utterance = new SpeechSynthesisUtterance(String(args[0])); const settings = object(args[1]); utterance.lang = String(settings.language ?? settings.lang ?? options.locale ?? navigator.language); if (typeof settings.rate === 'number') utterance.rate = settings.rate; utterance.onend = () => { signal.removeEventListener('abort', abort); resolve(true) }; utterance.onerror = event => { signal.removeEventListener('abort', abort); if (event.error === 'canceled' || event.error === 'interrupted') resolve(false); else reject(new Error(event.error)) }; const abort = (): void => { speechSynthesis.cancel(); resolve(false) }; signal.addEventListener('abort', abort, { once: true }); speechSynthesis.speak(utterance) })
      }
      if (module === 'Audio') {
        const id = String(args[0]); const sound = sounds.get(id)
        if (method === 'play') { await stopSound(id); const audio = new Audio(await platform.resolveMedia(String(args[1]))); const settings = object(args[2]); audio.loop = Boolean(settings.loop); const volume = Math.max(0, Math.min(1, Number(settings.volume ?? 1))); audio.volume = Number(settings.fadeIn) > 0 ? 0 : volume; audio.onended = () => { sounds.delete(id); emit('SOUND_EVENT', { id, event: 'ended' }) }; audio.onerror = () => { sounds.delete(id); emit('SOUND_EVENT', { id, event: 'error', message: audio.error?.message }) }; sounds.set(id, audio); await audio.play(); void fade(audio, volume, Number(settings.fadeIn ?? 0)); return true }
        if (method === 'stopAll') { await Promise.all([...sounds.keys()].map(key => stopSound(key, Number(first.fadeOut ?? 0)))); return true }
        if (!sound) return false
        if (method === 'pause') { sound.pause(); return true }
        if (method === 'resume') { await sound.play(); return true }
        if (method === 'stop') { await stopSound(id, Number(object(args[1]).fadeOut ?? 0)); return true }
        if (method === 'setVolume') { await fade(sound, Number(args[1]), Number(object(args[2]).fade ?? 0)); return true }
      }
      if (module === 'Media') {
        if (!('caches' in window)) return unsupported(module, method)
        if (method === 'clear') {
          mediaTransfers.abort()
          mediaTransfers = new AbortController()
          const name = cacheName()
          return writeMedia(async () => {
            const cache = await caches.open(name)
            let removed = 0
            for (const entry of await cache.keys()) {
              if (await cache.delete(entry)) removed++
              const local = mediaURLs.get(entry.url)
              if (local) URL.revokeObjectURL(local)
              mediaURLs.delete(entry.url)
            }
            return removed
          })
        }
        signal = AbortSignal.any([signal, mediaTransfers.signal])
        const cache = await caches.open(cacheName())
        if (method === 'keep') {
          const url = String(args[0]); const settings = object(args[1]); const connection = (navigator as Navigator & { connection?: { type?: string, saveData?: boolean } }).connection
          if (settings.cellular === false && (!['wifi', 'ethernet'].includes(connection?.type ?? '') || connection?.saveData)) return { ok: false, reason: connection?.type ? 'cellular' : 'network-unknown' }
          const old = await cache.match(url)
          if (old) return { ok: true, url, path: url, size: Number(old.headers.get('x-craft-size') ?? 0) }
          const response = await fetch(url, { headers: settings.headers as HeadersInit, signal })
          if (!response.ok) return { ok: false, status: response.status }
          const body = await response.blob(); signal.throwIfAborted(); const headers = new Headers(response.headers); headers.set('x-craft-size', String(body.size))
          await writeMedia(async () => { signal.throwIfAborted(); await cache.put(url, new Response(body, { headers, status: response.status })); signal.throwIfAborted() })
          return { ok: true, url, path: url, size: body.size }
        }
        if (method === 'path') return (await cache.match(String(args[0]))) ? String(args[0]) : null
        if (method === 'usage') { const entries = await cache.keys(); let bytes = 0; for (const entry of entries) bytes += Number((await cache.match(entry))?.headers.get('x-craft-size') ?? 0); return { bytes, count: entries.length } }
        if (method === 'prune') { const keep = new Set(Array.isArray(args[0]) ? args[0].map(String) : []); let removed = 0; for (const entry of await cache.keys()) if (!keep.has(entry.url)) { await cache.delete(entry); const local = mediaURLs.get(entry.url); if (local) URL.revokeObjectURL(local); mediaURLs.delete(entry.url); removed++ } return removed }
      }
      return unsupported(module, method)
    },
    dispose() {
      if (disposed) return
      disposed = true
      window.removeEventListener('storage', storageEvent)
      lifetime.abort()
      account.abort()
      for (const path of files.keys()) URL.revokeObjectURL(path)
      for (const path of mediaURLs.values()) URL.revokeObjectURL(path)
      files.clear(); mediaURLs.clear()
      for (const audio of sounds.values()) { cancelFade(audio); audio.pause(); audio.src = '' }
      sounds.clear()
      void wakeLock?.release()
      listeners.clear()
    },
  }
  return platform
}
