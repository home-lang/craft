/**
 * Helpers for accessing the native Craft runtime injected on `window.craft`.
 *
 * Prefer these over `(window as any).craft.*` so call sites are typed and we
 * have a single seam to mock in tests.
 */

import type { CraftBridgeAPI, CraftEventEmitter } from '../types'

type CraftBridge = CraftBridgeAPI & CraftEventEmitter

/** True when running inside a Craft webview (i.e. `window.craft` is present). */
export function isCraftRuntime(): boolean {
  return typeof window !== 'undefined' && !!window.craft
}

/** Returns the global Craft runtime, or null if running outside Craft. */
export function getCraft(): CraftBridge | null {
  if (typeof window === 'undefined') return null
  return (window.craft as CraftBridge | undefined) ?? null
}

/**
 * Returns the low-level bridge `call(method, params)` function, or null when
 * unavailable. Use this when you need to invoke a method that doesn't have a
 * typed wrapper yet.
 */
export function getNativeBridgeCall(): ((method: string, params?: unknown) => Promise<unknown>) | null {
  const c = getCraft() as (CraftBridge & { bridge?: { call?: (m: string, p?: unknown) => Promise<unknown> } }) | null
  return c?.bridge?.call ?? null
}

/**
 * Returns the standard "API unavailable" message used throughout the SDK.
 * Centralized so call sites are consistent and easy to grep for.
 */
export function craftUnavailableMessage(api: string): string {
  return `${api} not available. Must run in Craft environment.`
}

/** Throws a consistent error when an API is invoked outside Craft. */
export function requireCraftRuntime(api: string): CraftBridge {
  const c = getCraft()
  if (!c) {
    throw new Error(craftUnavailableMessage(api))
  }
  return c
}
