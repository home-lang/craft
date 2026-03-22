/**
 * STX Keep-Alive
 *
 * Cache component instances to preserve state across navigations.
 * Supports LRU eviction, scroll preservation, and activated/deactivated hooks.
 */

import { state } from './runtime'
import type { State } from './runtime'

export interface KeepAliveOptions {
  max?: number
  include?: string[]
  exclude?: string[]
}

interface CacheEntry {
  element: HTMLElement
  scrollTop: number
  scrollLeft: number
  timestamp: number
}

/**
 * Create a keep-alive cache for component instances.
 *
 * @example
 * const cache = createKeepAlive({ max: 10 })
 *
 * // Cache a page
 * cache.set('home', homeElement)
 *
 * // Restore cached page
 * const cached = cache.get('home')
 * if (cached) outlet.appendChild(cached)
 */
export function createKeepAlive(options: KeepAliveOptions = {}) {
  const cacheMap = new Map<string, CacheEntry>()
  const max = options.max ?? 10
  const activeKey = state<string | null>(null)

  function shouldCache(key: string): boolean {
    if (options.include && !options.include.includes(key)) return false
    if (options.exclude && options.exclude.includes(key)) return false
    return true
  }

  function evictLRU(): void {
    if (cacheMap.size <= max) return

    let oldestKey: string | null = null
    let oldestTime = Infinity

    for (const [key, entry] of cacheMap) {
      if (key !== activeKey() && entry.timestamp < oldestTime) {
        oldestTime = entry.timestamp
        oldestKey = key
      }
    }

    if (oldestKey) {
      const entry = cacheMap.get(oldestKey)
      if (entry) {
        fireHook(entry.element, 'deactivated')
      }
      cacheMap.delete(oldestKey)
    }
  }

  function fireHook(el: HTMLElement, hook: 'activated' | 'deactivated'): void {
    el.dispatchEvent(new CustomEvent(`stx:${hook}`))
  }

  return {
    /** Store an element in the cache */
    set(key: string, element: HTMLElement): void {
      if (!shouldCache(key)) return

      // Save scroll position
      const scrollEl = element.querySelector('[data-keep-scroll]') as HTMLElement | null
      const scrollTop = scrollEl?.scrollTop ?? 0
      const scrollLeft = scrollEl?.scrollLeft ?? 0

      cacheMap.set(key, { element, scrollTop, scrollLeft, timestamp: Date.now() })
      evictLRU()
    },

    /** Retrieve a cached element */
    get(key: string): HTMLElement | null {
      const entry = cacheMap.get(key)
      if (!entry) return null

      // Update timestamp (LRU)
      entry.timestamp = Date.now()

      // Restore scroll position
      const scrollEl = entry.element.querySelector('[data-keep-scroll]') as HTMLElement | null
      if (scrollEl) {
        requestAnimationFrame(() => {
          scrollEl.scrollTop = entry.scrollTop
          scrollEl.scrollLeft = entry.scrollLeft
        })
      }

      return entry.element
    },

    /** Check if a key is cached */
    has(key: string): boolean {
      return cacheMap.has(key)
    },

    /** Activate a cached component (fires onActivated) */
    activate(key: string): void {
      const prev = activeKey()
      if (prev && prev !== key) {
        const prevEntry = cacheMap.get(prev)
        if (prevEntry) fireHook(prevEntry.element, 'deactivated')
      }

      activeKey.set(key)
      const entry = cacheMap.get(key)
      if (entry) fireHook(entry.element, 'activated')
    },

    /** Remove from cache */
    remove(key: string): void {
      const entry = cacheMap.get(key)
      if (entry) fireHook(entry.element, 'deactivated')
      cacheMap.delete(key)
    },

    /** Clear all cached entries */
    clear(): void {
      for (const [, entry] of cacheMap) {
        fireHook(entry.element, 'deactivated')
      }
      cacheMap.clear()
      activeKey.set(null)
    },

    /** Get all cached keys */
    getCacheKeys(): string[] {
      return [...cacheMap.keys()]
    },

    /** Current cache size */
    get size(): number {
      return cacheMap.size
    },

    /** Active key signal */
    activeKey,
  }
}
