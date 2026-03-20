/**
 * STX Composables
 *
 * Signal-based composables for accessing Craft bridge APIs,
 * browser APIs, and common reactive patterns.
 */

// Craft bridge
export { useCraft } from './useCraft'
export { usePlatform } from './usePlatform'
export type { PlatformInfo } from './usePlatform'
export { useTheme } from './useTheme'
export { useHaptics } from './useHaptics'

// DOM
export { useRef } from './useRef'

// Browser
export { useLocalStorage } from './useLocalStorage'
export { useMediaQuery } from './useMediaQuery'

// Data
export { useFetch } from './useFetch'

// Timing
export { useDebounce, useDebouncedValue } from './useDebounce'

// Head
export { useHead, useSeoMeta } from './useHead'
