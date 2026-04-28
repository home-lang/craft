/**
 * Cryptographically-secure ID helpers shared across the bridge implementations.
 *
 * Math.random() is not safe for IDs that are routed back to the page (callback
 * IDs, webview IDs) — predictable IDs let injected JS hijack pending callbacks.
 * Use these helpers instead.
 */

/**
 * Returns a v4 UUID string. Falls back to crypto.getRandomValues when
 * randomUUID is unavailable. Throws if no Web Crypto is available at all,
 * which would indicate a non-browser, non-Node environment we don't support.
 */
export function secureUUID(): string {
  const c = globalThis.crypto as Crypto | undefined
  if (c && typeof c.randomUUID === 'function') {
    return c.randomUUID()
  }
  if (c && typeof c.getRandomValues === 'function') {
    const bytes = new Uint8Array(16)
    c.getRandomValues(bytes)
    bytes[6] = (bytes[6] & 0x0f) | 0x40
    bytes[8] = (bytes[8] & 0x3f) | 0x80
    const hex = Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('')
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`
  }
  throw new Error('[Craft] No Web Crypto available; cannot generate secure IDs')
}

/**
 * Returns a prefixed, secure ID, e.g. `webview_3f7a…`.
 */
export function secureId(prefix: string): string {
  return `${prefix}_${secureUUID()}`
}
