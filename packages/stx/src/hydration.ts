/**
 * STX Partial Hydration (Islands Architecture)
 *
 * Strategies for selectively hydrating interactive components:
 * - @client:load    — Hydrate immediately on page load
 * - @client:idle    — Hydrate when browser is idle (requestIdleCallback)
 * - @client:visible — Hydrate when element enters viewport (IntersectionObserver)
 * - @client:media   — Hydrate when media query matches
 * - @client:hover   — Hydrate on first mouse hover
 * - @client:event   — Hydrate on a specific DOM event
 * - @client:only    — Only render on client, skip SSR
 * - @static         — Never hydrate, static HTML only
 */

import { state } from './runtime'
import type { State } from './runtime'

export type HydrationStrategy =
  | 'load'
  | 'idle'
  | 'visible'
  | 'media'
  | 'hover'
  | 'event'
  | 'only'
  | 'static'

export interface HydrationOptions {
  /** For 'media' strategy: the media query string */
  query?: string
  /** For 'event' strategy: the event name to listen for */
  event?: string
  /** For 'visible' strategy: IntersectionObserver root margin */
  rootMargin?: string
  /** For 'visible' strategy: visibility threshold (0-1) */
  threshold?: number
}

interface IslandEntry {
  id: string
  element: HTMLElement
  hydrate: () => void | Promise<void>
  strategy: HydrationStrategy
  hydrated: State<boolean>
  cleanup?: () => void
}

const islands = new Map<string, IslandEntry>()
let islandCounter = 0

/**
 * Register an island for hydration with a given strategy.
 *
 * @example
 * // Hydrate when visible
 * hydrateIsland(el, () => mountChart(el), 'visible')
 *
 * // Hydrate when media query matches
 * hydrateIsland(el, () => mountWidget(el), 'media', { query: '(min-width: 768px)' })
 */
export function hydrateIsland(
  element: HTMLElement,
  hydrate: () => void | Promise<void>,
  strategy: HydrationStrategy = 'load',
  options: HydrationOptions = {},
): string {
  const id = `stx-island-${++islandCounter}`
  element.setAttribute('data-stx-island', id)

  const hydrated = state(false)

  const doHydrate = async () => {
    if (hydrated()) return
    try {
      await hydrate()
      hydrated.set(true)
      element.setAttribute('data-stx-hydrated', '')
      element.dispatchEvent(new CustomEvent('stx:hydrated', { detail: { id } }))
    }
    catch (err) {
      console.error(`[stx-hydration] Failed to hydrate island ${id}:`, err)
    }
  }

  const entry: IslandEntry = { id, element, hydrate: doHydrate, strategy, hydrated }
  islands.set(id, entry)

  // Set up strategy
  entry.cleanup = setupStrategy(element, doHydrate, strategy, options)

  return id
}

/**
 * Hydrate by strategy name — convenience wrapper.
 */
export function hydrateByStrategy(
  element: HTMLElement,
  hydrate: () => void | Promise<void>,
  strategy: HydrationStrategy,
  options?: HydrationOptions,
): string {
  return hydrateIsland(element, hydrate, strategy, options)
}

/**
 * Hydrate all registered islands that haven't been hydrated yet.
 */
export function hydrateAll(): void {
  for (const [, entry] of islands) {
    if (!entry.hydrated()) {
      entry.hydrate()
    }
  }
}

/**
 * Check if an island has been hydrated.
 */
export function isHydrated(id: string): boolean {
  return islands.get(id)?.hydrated() ?? false
}

/**
 * Run a callback when an island is hydrated.
 */
export function onHydrated(id: string, callback: () => void): () => void {
  const entry = islands.get(id)
  if (!entry) return () => {}

  if (entry.hydrated()) {
    callback()
    return () => {}
  }

  return entry.hydrated.subscribe((hydrated) => {
    if (hydrated) callback()
  })
}

/**
 * Remove an island registration and clean up its strategy listener.
 */
export function removeIsland(id: string): void {
  const entry = islands.get(id)
  if (entry) {
    entry.cleanup?.()
    islands.delete(id)
  }
}

/**
 * Get all registered island IDs.
 */
export function getIslandIds(): string[] {
  return [...islands.keys()]
}

// ============================================================================
// Strategy implementations
// ============================================================================

function setupStrategy(
  element: HTMLElement,
  hydrate: () => void,
  strategy: HydrationStrategy,
  options: HydrationOptions,
): (() => void) | undefined {
  switch (strategy) {
    case 'load':
      // Hydrate immediately
      if (typeof document !== 'undefined') {
        if (document.readyState === 'loading') {
          const handler = () => { hydrate(); document.removeEventListener('DOMContentLoaded', handler) }
          document.addEventListener('DOMContentLoaded', handler)
          return () => document.removeEventListener('DOMContentLoaded', handler)
        }
        queueMicrotask(hydrate)
      }
      return undefined

    case 'idle':
      // Hydrate when browser is idle
      if (typeof requestIdleCallback !== 'undefined') {
        const id = requestIdleCallback(() => hydrate())
        return () => cancelIdleCallback(id)
      }
      // Fallback: setTimeout
      const timer = setTimeout(hydrate, 200)
      return () => clearTimeout(timer)

    case 'visible':
      // Hydrate when element enters viewport
      if (typeof IntersectionObserver !== 'undefined') {
        const observer = new IntersectionObserver(
          (entries) => {
            for (const entry of entries) {
              if (entry.isIntersecting) {
                hydrate()
                observer.disconnect()
              }
            }
          },
          {
            rootMargin: options.rootMargin ?? '0px',
            threshold: options.threshold ?? 0,
          },
        )
        observer.observe(element)
        return () => observer.disconnect()
      }
      // Fallback: hydrate on load
      queueMicrotask(hydrate)
      return undefined

    case 'media':
      // Hydrate when media query matches
      if (typeof window !== 'undefined' && options.query) {
        const mq = window.matchMedia(options.query)
        if (mq.matches) {
          queueMicrotask(hydrate)
          return undefined
        }
        const handler = (e: MediaQueryListEvent) => {
          if (e.matches) {
            hydrate()
            mq.removeEventListener('change', handler)
          }
        }
        mq.addEventListener('change', handler)
        return () => mq.removeEventListener('change', handler)
      }
      return undefined

    case 'hover':
      // Hydrate on first hover
      const hoverHandler = () => {
        hydrate()
        element.removeEventListener('mouseenter', hoverHandler)
        element.removeEventListener('focusin', hoverHandler)
      }
      element.addEventListener('mouseenter', hoverHandler, { once: true })
      element.addEventListener('focusin', hoverHandler, { once: true })
      return () => {
        element.removeEventListener('mouseenter', hoverHandler)
        element.removeEventListener('focusin', hoverHandler)
      }

    case 'event':
      // Hydrate on specific event
      if (options.event) {
        const eventHandler = () => {
          hydrate()
          element.removeEventListener(options.event!, eventHandler)
        }
        element.addEventListener(options.event, eventHandler, { once: true })
        return () => element.removeEventListener(options.event!, eventHandler)
      }
      return undefined

    case 'only':
      // Client-only: hydrate immediately (no SSR content)
      queueMicrotask(hydrate)
      return undefined

    case 'static':
      // Never hydrate
      return undefined
  }
}
