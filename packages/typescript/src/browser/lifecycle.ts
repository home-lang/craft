export type BrowserAppState = 'active' | 'background'

/** Browser lifecycle shares the native APP_STATE contract, including bfcache navigation. */
export function createBrowserLifecycle(
  page: Pick<Document, 'hidden' | 'addEventListener' | 'removeEventListener'>,
  host: Pick<Window, 'addEventListener' | 'removeEventListener'>,
  changed: (state: BrowserAppState) => void,
) {
  let state: BrowserAppState = page.hidden ? 'background' : 'active'
  const listeners = new Set<(state: BrowserAppState) => void>()
  let disposed = false
  const set = (next: BrowserAppState): void => {
    if (disposed || state === next) return
    state = next
    changed(state)
    for (const listener of [...listeners]) {
      try { listener(state) }
      catch (error) { console.error('craft.lifecycle listener failed', error) }
    }
  }
  const visibility = (): void => set(page.hidden ? 'background' : 'active')
  const hide = (): void => set('background')
  page.addEventListener('visibilitychange', visibility)
  host.addEventListener('pagehide', hide)
  host.addEventListener('pageshow', visibility)
  return {
    getState: (): BrowserAppState => state,
    onStateChange(callback: (state: BrowserAppState) => void): () => void {
      if (typeof callback !== 'function') throw new TypeError('lifecycle.onStateChange needs a function')
      if (disposed) return () => {}
      listeners.add(callback)
      return () => { listeners.delete(callback) }
    },
    dispose(): void {
      if (disposed) return
      disposed = true
      page.removeEventListener('visibilitychange', visibility)
      host.removeEventListener('pagehide', hide)
      host.removeEventListener('pageshow', visibility)
      listeners.clear()
    },
  }
}
