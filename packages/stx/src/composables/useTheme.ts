import { state, effect } from '../runtime'
import type { State } from '../runtime'

/**
 * Reactive dark/light theme detection and toggling.
 *
 * @example
 * const { isDark, toggle } = useTheme()
 * if (isDark()) { ... }
 * toggle() // switch theme
 */
export function useTheme(): {
  isDark: State<boolean>
  toggle: () => void
} {
  const prefersDark = typeof window !== 'undefined'
    ? window.matchMedia('(prefers-color-scheme: dark)').matches
    : false

  const isDark = state(prefersDark)

  if (typeof window !== 'undefined') {
    const mq = window.matchMedia('(prefers-color-scheme: dark)')
    mq.addEventListener('change', (e) => {
      isDark.set(e.matches)
    })
  }

  effect(() => {
    if (typeof document !== 'undefined') {
      document.documentElement.classList.toggle('dark', isDark())
    }
  })

  const toggle = () => {
    isDark.update(v => !v)
  }

  return { isDark, toggle }
}
