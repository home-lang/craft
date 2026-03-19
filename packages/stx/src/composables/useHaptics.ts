import { useCraft } from './useCraft'

type HapticStyle = 'light' | 'medium' | 'heavy' | 'selection' | 'success' | 'warning' | 'error'

/**
 * Trigger haptic feedback on supported platforms (iOS, Android).
 *
 * @example
 * const { impact } = useHaptics()
 * impact('medium')
 */
export function useHaptics() {
  const { craft, isReady } = useCraft()

  const impact = (style: HapticStyle = 'medium') => {
    if (!isReady() || !craft()) return

    try {
      const bridge = craft()
      if (bridge && typeof bridge.haptic === 'function') {
        ;(bridge.haptic as (style: string) => void)(style)
      }
    }
    catch {
      // Haptics not supported on this platform
    }
  }

  return { impact }
}
