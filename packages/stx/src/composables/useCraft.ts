import { signal, effect } from '../runtime'
import type { Signal } from '../runtime'

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
 */
export function useCraft(): { craft: Signal<CraftBridge | null>; isReady: Signal<boolean> } {
  const craft = signal<CraftBridge | null>(null)
  const isReady = signal(false)

  const check = () => {
    if (typeof window !== 'undefined' && window.craft) {
      craft.value = window.craft
      isReady.value = true
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
