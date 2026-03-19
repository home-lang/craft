import { state } from '../runtime'
import type { State } from '../runtime'

interface CraftBridge {
  [key: string]: unknown
}

declare global {
  interface Window {
    craft?: CraftBridge
  }
}

/**
 * Access the Craft bridge API via signals.
 * Waits for the bridge to become available.
 *
 * @example
 * const { craft, isReady } = useCraft()
 * if (isReady()) {
 *   craft()?.someApi()
 * }
 */
export function useCraft(): { craft: State<CraftBridge | null>; isReady: State<boolean> } {
  const craft = state<CraftBridge | null>(null)
  const isReady = state(false)

  const check = () => {
    if (typeof window !== 'undefined' && window.craft) {
      craft.set(window.craft)
      isReady.set(true)
      return true
    }
    return false
  }

  if (!check()) {
    if (typeof window !== 'undefined') {
      window.addEventListener('craftReady', () => {
        check()
      }, { once: true })
    }
  }

  return { craft, isReady }
}
