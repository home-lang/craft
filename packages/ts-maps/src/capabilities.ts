/**
 * Runtime capability probe for Craft apps hosting `ts-maps` inside a
 * WebView. The map renderer prefers WebGL2 and falls back to Canvas2D
 * when it isn't available; this helper exposes the probe so the host
 * app can pick the right renderer up front (and surface the decision to
 * users on older devices).
 *
 * All checks are side-effect-free and safe to call during render: the
 * probe creates a throw-away canvas, asks for the relevant context, and
 * discards it.
 *
 * @module @craft-native/ts-maps/capabilities
 */

export interface MapRendererCapabilities {
  /** WebGL2 context is obtainable. */
  webgl2: boolean
  /** WebGL1 context is obtainable (fallback). */
  webgl1: boolean
  /** `OffscreenCanvas` exists on the global scope. */
  offscreenCanvas: boolean
  /** `navigator.hardwareConcurrency` — tile-worker parallelism hint. */
  hardwareConcurrency: number
  /** `window.devicePixelRatio` — retina-like displays report >1. */
  devicePixelRatio: number
  /** Pointer events are supported (required for the two-finger gestures). */
  pointerEvents: boolean
  /** Touch events are supported (used as a pointer-event fallback). */
  touchEvents: boolean
  /** Best renderer given the probe result. */
  preferredRenderer: 'webgl' | 'canvas2d'
}

/**
 * Probe the host runtime. Safe to call in any environment — when neither
 * `window` nor `document` is available (Node / SSR) the probe returns a
 * conservative zero-capabilities object.
 */
export function probeCapabilities(): MapRendererCapabilities {
  if (typeof document === 'undefined' || typeof window === 'undefined') {
    return {
      webgl2: false,
      webgl1: false,
      offscreenCanvas: false,
      hardwareConcurrency: 1,
      devicePixelRatio: 1,
      pointerEvents: false,
      touchEvents: false,
      preferredRenderer: 'canvas2d',
    }
  }

  const canvas = document.createElement('canvas')
  // Narrow-scope try/catch per context kind — some browsers throw
  // `SecurityError` when a context type is blocked by a permission policy.
  let webgl2 = false
  let webgl1 = false
  try {
    const gl2 = canvas.getContext('webgl2')
    webgl2 = gl2 !== null && gl2 !== undefined
  }
  catch { /* webgl2 unavailable */ }
  if (!webgl2) {
    try {
      const gl1 = canvas.getContext('webgl') ?? canvas.getContext('experimental-webgl')
      webgl1 = gl1 !== null && gl1 !== undefined
    }
    catch { /* webgl1 unavailable */ }
  }

  const offscreenCanvas = typeof (globalThis as any).OffscreenCanvas === 'function'
  const nav = (globalThis as any).navigator as Navigator | undefined
  const hardwareConcurrency = Math.max(1, Math.floor(nav?.hardwareConcurrency ?? 1))
  const devicePixelRatio = Math.max(1, (window as any).devicePixelRatio ?? 1)
  const pointerEvents = typeof (globalThis as any).PointerEvent === 'function'
  const touchEvents = 'ontouchstart' in window
    || (nav !== undefined && (nav as any).maxTouchPoints > 0)

  return {
    webgl2,
    webgl1,
    offscreenCanvas,
    hardwareConcurrency,
    devicePixelRatio,
    pointerEvents,
    touchEvents,
    preferredRenderer: webgl2 ? 'webgl' : 'canvas2d',
  }
}

/**
 * True when the probe thinks this host can run the WebGL-backed renderer
 * comfortably. Callers typically use this to gate advanced features like
 * fill-extrusion or hillshade on cheap older phones.
 */
export function supportsAdvancedRendering(caps?: MapRendererCapabilities): boolean {
  const probe = caps ?? probeCapabilities()
  return probe.webgl2 && probe.hardwareConcurrency >= 2 && probe.pointerEvents
}
