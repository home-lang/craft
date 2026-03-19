import { signal, effect } from '../runtime'
import type { Signal } from '../runtime'

/**
 * Reactive dark/light theme detection and toggling.
 */
export function useTheme(): {
  isDark: Signal<boolean>
  toggle: () => void
} {
  const prefersDark = typeof window !== 'undefined'
    ? window.matchMedia('(prefers-color-scheme: dark)').matches
    : false

  const isDark = signal(prefersDark)

  if (typeof window !== 'undefined') {
    const mq = window.matchMedia('(prefers-color-scheme: dark)')
    mq.addEventListener('change', (e) => {
      isDark.value = e.matches
    })
  }

  effect(() => {
    if (typeof document !== 'undefined') {
      document.documentElement.classList.toggle('dark', isDark.value)
    }
  })

  const toggle = () => {
    isDark.value = !isDark.value
  }

  return { isDark, toggle }
}
