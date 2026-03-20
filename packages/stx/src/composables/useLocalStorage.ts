import { state, effect } from '../runtime'
import type { State } from '../runtime'

/**
 * Reactive localStorage binding.
 *
 * @example
 * const theme = useLocalStorage('theme', 'light')
 * theme()      // 'light' (or stored value)
 * theme.set('dark')  // updates localStorage too
 */
export function useLocalStorage<T>(key: string, defaultValue: T): State<T> {
  let initial = defaultValue

  if (typeof window !== 'undefined') {
    try {
      const stored = localStorage.getItem(key)
      if (stored !== null) {
        initial = JSON.parse(stored)
      }
    }
    catch {
      // Invalid JSON, use default
    }
  }

  const s = state<T>(initial)

  // Sync to localStorage on change
  effect(() => {
    const value = s()
    if (typeof window !== 'undefined') {
      try {
        localStorage.setItem(key, JSON.stringify(value))
      }
      catch {
        // Storage full or unavailable
      }
    }
  })

  // Listen for changes from other tabs
  if (typeof window !== 'undefined') {
    window.addEventListener('storage', (e) => {
      if (e.key === key && e.newValue !== null) {
        try {
          s.set(JSON.parse(e.newValue))
        }
        catch {
          // Invalid JSON
        }
      }
    })
  }

  return s
}
