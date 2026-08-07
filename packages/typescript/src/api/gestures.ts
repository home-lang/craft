/**
 * @fileoverview Trackpad gesture phases
 * @description Real swipe begin/change/end from the host's `NSEvent`, rather
 * than inferred from a phase-less `wheel` stream.
 * @module @craft-native/api/gestures
 */

// ============================================================================
// Types
// ============================================================================

export type SwipeAxis = 'horizontal' | 'vertical'
export type SwipePhase = 'begin' | 'change' | 'end'

export interface SwipeEvent {
  /** Which way the gesture was locked at `begin`. Never changes mid-gesture. */
  axis: SwipeAxis
  phase: SwipePhase
  /**
   * Points since the previous event. Positive scrolls content left — i.e.
   * advances to the next item — matching a DOM wheel event's `deltaX`.
   */
  deltaX: number
  deltaY: number
  /** Points per second at release. Only meaningful on `end`. */
  velocityX: number
  /**
   * True once the fingers have lifted and the OS is coasting. The macOS host
   * drops momentum entirely so a swipe settles at finger-up, so this is
   * currently always `false` there; it exists for hosts that choose to forward
   * the tail.
   */
  momentum: boolean
}

export type SwipeListener = (swipe: SwipeEvent) => void
export type Unsubscribe = () => void

export interface GesturesAPI {
  onSwipe: (listener: SwipeListener) => Unsubscribe
}

// ============================================================================
// API
// ============================================================================

/**
 * Whether the host forwards real gesture phases.
 *
 * Note this is `true` as soon as the registry is installed, which happens in
 * every Craft window — it does **not** promise that a swipe will ever arrive.
 * A host that never emits leaves the registry dormant, which is deliberate:
 * callers keep their own `wheel` fallback bound and let the native stream
 * supersede it on the first `begin` it delivers.
 */
export function hasNativeGestures(): boolean {
  return typeof globalThis.window?.craft?.gestures?.onSwipe === 'function'
}

/**
 * Subscribe to swipe phases. Returns an unsubscribe function; calling it more
 * than once is safe.
 *
 * In a plain browser this is a no-op returning a no-op, so it is safe to call
 * unconditionally.
 *
 * @example
 * ```ts
 * const off = onSwipe((swipe) => {
 *   if (swipe.axis !== 'horizontal') return
 *   if (swipe.phase === 'begin') beginDrag()
 *   else if (swipe.phase === 'end') settle(swipe.velocityX)
 *   else track(swipe.deltaX)
 * })
 * ```
 */
export function onSwipe(listener: SwipeListener): Unsubscribe {
  const gestures = globalThis.window?.craft?.gestures
  if (typeof gestures?.onSwipe !== 'function') return () => {}
  return gestures.onSwipe(listener)
}

/** Namespace form, for `import { gestures } from 'craft-native'`. */
export const gestures: {
  hasNativeGestures: () => boolean
  onSwipe: (listener: SwipeListener) => Unsubscribe
} = { hasNativeGestures, onSwipe }
