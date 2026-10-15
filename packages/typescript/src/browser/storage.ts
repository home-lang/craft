export interface BrowserStorageOptions {
  storage: Storage
  namespace: string
  tokenKey: string
  /** Existing website identity keys to forget whenever its token changes. */
  accountKeys?: string[]
  hash: (value: string) => Promise<string>
  changed: (name: string) => void
}

export interface BrowserStorage {
  craft: {
    storage: { getSync: (key: string) => unknown, setSync: (key: string, value: unknown) => void }
    secureStorage: { getSync: (key: string) => string | null }
    snapshots: { get: (name: string) => unknown, set: (name: string, value: unknown) => Promise<boolean>, clear: (keep?: string[]) => Promise<boolean>, keys: () => string[] }
  }
  call: (module: string, method: string, args: unknown[]) => Promise<unknown>
  accountChanged: () => Promise<void>
  scope: () => string
}

/** Browser persistence has browser security semantics; it does not claim to be a Keychain. */
export async function createBrowserStorage(options: BrowserStorageOptions): Promise<BrowserStorage> {
  const { storage, namespace, tokenKey, changed } = options
  const prefix = `${namespace}:`
  let token = storage.getItem(tokenKey)
  let scope = token ? await options.hash(token) : 'guest'
  let transitioning = false
  let revision = 0
  let transition: Promise<void> | null = null
  const available = (): boolean => !transitioning && storage.getItem(tokenKey) === token
  const key = (name: string): string => `${prefix}account:${scope}:${name}`
  const snapshotKey = (name: string): string => name === 'app' ? `${prefix}app` : key(`snapshot:${name}`)
  const keys = (base: string): string[] => Array.from({ length: storage.length }, (_, index) => storage.key(index)).filter((value): value is string => value !== null && value.startsWith(base))
  const read = (name: string): unknown => {
    if (!available()) return null
    const value = storage.getItem(key(`storage:${name}`))
    if (value === null) return null
    try { return JSON.parse(value) } catch { return null }
  }
  const accountChanged = async (): Promise<void> => {
    const next = storage.getItem(tokenKey)
    if (next === token) { await transition; return }
    const previous = scope
    const current = ++revision
    transitioning = true
    // Remove only the previous account's data. An account change must never
    // expose its retained first frame to the next person, even in another tab.
    for (const name of keys(`${prefix}account:${previous}:`)) storage.removeItem(name)
    for (const name of options.accountKeys ?? []) { if (name !== tokenKey) storage.removeItem(name) }
    token = next
    transition = (async () => {
      const nextScope = next ? await options.hash(next) : 'guest'
      if (current !== revision) return
      scope = nextScope
      transitioning = false
      changed('session')
    })()
    await transition
  }
  const secureKey = (name: string): string => name === 'auth.token' ? tokenKey : key(`credential:${name}`)
  return {
    scope: () => scope,
    accountChanged,
    craft: {
      storage: { getSync: read, setSync: (name, value) => { if (available()) storage.setItem(key(`storage:${name}`), JSON.stringify(value)) } },
      secureStorage: { getSync: name => name === 'auth.token' || available() ? storage.getItem(secureKey(name)) : null },
      snapshots: {
        get: (name) => {
          if (!available() && name !== 'app') return null
          const value = storage.getItem(snapshotKey(name))
          if (value === null) return null
          try { return JSON.parse(value) } catch { return value }
        },
        async set(name, value) { if (name !== 'app' && !available()) return false; storage.setItem(snapshotKey(name), typeof value === 'string' ? value : JSON.stringify(value)); changed(name); return true },
        async clear(keep = []) { if (!available()) return false; for (const name of keys(key('snapshot:'))) { const label = name.slice(key('snapshot:').length); if (!keep.includes(label)) { storage.removeItem(name); changed(label) } } if (!keep.includes('app')) storage.removeItem(snapshotKey('app')); return true },
        keys: () => available() ? keys(key('snapshot:')).map(name => name.slice(key('snapshot:').length)) : [],
      },
    },
    async call(module, method, args) {
      await accountChanged()
      const name = String(args[0] ?? '')
      if (module === 'Storage') {
        if (method === 'get') return read(name)
        if (method === 'set') { storage.setItem(key(`storage:${name}`), JSON.stringify(args[1])); return true }
        if (method === 'remove') { storage.removeItem(key(`storage:${name}`)); return true }
        if (method === 'keys') return keys(key('storage:')).map(item => item.slice(key('storage:').length))
        if (method === 'clear') { for (const item of keys(key('storage:'))) storage.removeItem(item); return true }
      }
      if (module === 'SecureStorage') {
        if (method === 'get') return storage.getItem(secureKey(name))
        if (method === 'set') { storage.setItem(secureKey(name), String(args[1])); if (name === 'auth.token') await accountChanged(); return true }
        if (method === 'remove') { storage.removeItem(secureKey(name)); if (name === 'auth.token') await accountChanged(); return true }
        if (method === 'clear') { for (const item of keys(key('credential:'))) storage.removeItem(item); storage.removeItem(tokenKey); await accountChanged(); return true }
      }
      throw Object.assign(new Error(`Unsupported browser storage operation ${module}.${method}`), { code: 'UNSUPPORTED' })
    },
  }
}
