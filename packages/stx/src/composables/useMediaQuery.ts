import { state } from '../runtime'
import type { State } from '../runtime'

/**
 * Reactive media query matching.
 *
 * @example
 * const isMobile = useMediaQuery('(max-width: 768px)')
 * if (isMobile()) { ... }
 */
export function useMediaQuery(query: string): State<boolean> {
  const matches = state(false)

  if (typeof window !== 'undefined') {
    const mq = window.matchMedia(query)
    matches.set(mq.matches)
    mq.addEventListener('change', (e) => {
      matches.set(e.matches)
    })
  }

  return matches
}
