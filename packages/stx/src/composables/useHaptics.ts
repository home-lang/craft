import { useCraft } from './useCraft'

type HapticStyle = 'light' | 'medium' | 'heavy' | 'selection' | 'success' | 'warning' | 'error'

/**
 * Trigger haptic feedback on supported platforms (iOS, Android).
 */
export function useHaptics() {
  const { craft, isReady } = useCraft()

  const impact = (style: HapticStyle = 'medium') => {
    if (!isReady.value || !craft.value) return

    try {
      if (typeof craft.value.haptic === 'function') {
        ;(craft.value.haptic as (style: string) => void)(style)
      }
    }
    catch {
      // Haptics not supported on this platform
    }
  }

  return { impact }
}
