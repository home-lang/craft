/**
 * Craft Clipboard API
 * Read and write to the system clipboard
 * @module @craft-native/api/clipboard
 */

import { getBridge } from '../bridge/core'

/** Default timeout for callback-style clipboard reads. */
const CLIPBOARD_READ_TIMEOUT_MS = 5000

/**
 * Push a {resolve,reject} pair onto `window.__craftBridgePending[bucket]` and
 * arrange for it to be cleaned up after `CLIPBOARD_READ_TIMEOUT_MS` if the
 * native side never responds. Without this, every read that the host
 * silently drops keeps closures alive forever.
 */
function pendingWithTimeout<T>(
  bucket: string,
  startNative: () => void,
): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const w = window as unknown as {
      __craftBridgePending?: Record<string, Array<{ resolve: (v: T) => void; reject: (e: unknown) => void }>>
    }
    w.__craftBridgePending = w.__craftBridgePending || {}
    const list = w.__craftBridgePending[bucket] = w.__craftBridgePending[bucket] || []
    let settled = false
    const wrappedResolve = (v: T) => {
      if (settled) return
      settled = true
      clearTimeout(timer)
      const idx = list.indexOf(entry)
      if (idx >= 0) list.splice(idx, 1)
      resolve(v)
    }
    const wrappedReject = (e: unknown) => {
      if (settled) return
      settled = true
      clearTimeout(timer)
      const idx = list.indexOf(entry)
      if (idx >= 0) list.splice(idx, 1)
      reject(e)
    }
    const entry = { resolve: wrappedResolve, reject: wrappedReject }
    list.push(entry)
    // The handle returned here is captured by the closures above so they
    // can clearTimeout(timer) when the native side finally resolves.
    // eslint-disable-next-line pickier/no-unused-vars
    const timer: ReturnType<typeof setTimeout> = setTimeout(() => {
      wrappedReject(new Error(`[clipboard] ${bucket} timed out after ${CLIPBOARD_READ_TIMEOUT_MS}ms`))
    }, CLIPBOARD_READ_TIMEOUT_MS)
    startNative()
  })
}

// ============================================================================
// Types
// ============================================================================

/**
 * Clipboard content types
 */
export type ClipboardFormat = 'text' | 'html' | 'rtf' | 'image'

/**
 * Clipboard data with multiple formats
 */
export interface ClipboardData {
  /** Plain text content */
  text?: string
  /** HTML content */
  html?: string
  /** RTF content */
  rtf?: string
  /** Image as data URL or base64 */
  image?: string
}

// ============================================================================
// Clipboard Functions
// ============================================================================

/**
 * Write text to clipboard
 * @param text Text to copy
 */
export async function writeText(text: string): Promise<void> {
  if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
    return new Promise((resolve, _reject) => {
      const w = window as any
      w.webkit.messageHandlers.craft.postMessage({
        type: 'clipboard',
        action: 'writeText',
        data: { text }
      })
      // Fire-and-forget: resolve immediately on WebKit path
      resolve()
    })
  }

  const bridge = getBridge()
  return bridge.request('clipboard.writeText', { text })
}

/**
 * Read text from clipboard
 * @returns Clipboard text content
 */
export async function readText(): Promise<string> {
  if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
    const payload = await pendingWithTimeout<{ text?: string } | undefined>('readText', () => {
      ;(window as any).webkit.messageHandlers.craft.postMessage({
        type: 'clipboard',
        action: 'readText',
      })
    })
    return payload && typeof payload.text === 'string' ? payload.text : ''
  }

  const bridge = getBridge()
  return bridge.request('clipboard.readText')
}

/**
 * Write HTML to clipboard
 * @param html HTML content to copy
 */
export async function writeHTML(html: string): Promise<void> {
  if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
    return new Promise((resolve) => {
      (window as any).webkit.messageHandlers.craft.postMessage({
        type: 'clipboard',
        action: 'writeHTML',
        data: { html }
      })
      resolve()
    })
  }

  const bridge = getBridge()
  return bridge.request('clipboard.writeHTML', { html })
}

/**
 * Read HTML from clipboard
 * @returns Clipboard HTML content
 */
export async function readHTML(): Promise<string> {
  if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
    const payload = await pendingWithTimeout<{ html?: string } | undefined>('readHTML', () => {
      ;(window as any).webkit.messageHandlers.craft.postMessage({
        type: 'clipboard',
        action: 'readHTML',
      })
    })
    return payload && typeof payload.html === 'string' ? payload.html : ''
  }

  const bridge = getBridge()
  return bridge.request('clipboard.readHTML')
}

/**
 * Clear clipboard contents
 */
export async function clear(): Promise<void> {
  if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
    return new Promise((resolve) => {
      (window as any).webkit.messageHandlers.craft.postMessage({
        type: 'clipboard',
        action: 'clear'
      })
      resolve()
    })
  }

  const bridge = getBridge()
  return bridge.request('clipboard.clear')
}

/**
 * Check if clipboard has text content
 * @returns true if clipboard contains text
 */
export async function hasText(): Promise<boolean> {
  if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
    const payload = await pendingWithTimeout<{ value?: boolean } | undefined>('hasText', () => {
      ;(window as any).webkit.messageHandlers.craft.postMessage({
        type: 'clipboard',
        action: 'hasText',
      })
    })
    return !!(payload && payload.value === true)
  }

  const bridge = getBridge()
  return bridge.request('clipboard.hasText')
}

/**
 * Check if clipboard has HTML content
 * @returns true if clipboard contains HTML
 */
export async function hasHTML(): Promise<boolean> {
  if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
    const payload = await pendingWithTimeout<{ value?: boolean } | undefined>('hasHTML', () => {
      ;(window as any).webkit.messageHandlers.craft.postMessage({
        type: 'clipboard',
        action: 'hasHTML',
      })
    })
    return !!(payload && payload.value === true)
  }

  const bridge = getBridge()
  return bridge.request('clipboard.hasHTML')
}

/**
 * Check if clipboard has image content
 * @returns true if clipboard contains image
 */
export async function hasImage(): Promise<boolean> {
  if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
    const payload = await pendingWithTimeout<{ value?: boolean } | undefined>('hasImage', () => {
      ;(window as any).webkit.messageHandlers.craft.postMessage({
        type: 'clipboard',
        action: 'hasImage',
      })
    })
    return !!(payload && payload.value === true)
  }

  const bridge = getBridge()
  return bridge.request('clipboard.hasImage')
}

/**
 * Write multiple formats to clipboard at once
 * @param data Clipboard data with multiple formats
 */
export async function write(data: ClipboardData): Promise<void> {
  // Write each format that's present
  const promises: Promise<void>[] = []

  if (data.text) {
    promises.push(writeText(data.text))
  }
  if (data.html) {
    promises.push(writeHTML(data.html))
  }

  await Promise.all(promises)
}

/**
 * Read all available formats from clipboard
 * @returns Clipboard data with all available formats
 */
export async function read(): Promise<ClipboardData> {
  const [text, html] = await Promise.all([
    readText().catch((err) => {
      console.debug('[Craft Clipboard] readText failed:', err)
      return undefined
    }),
    readHTML().catch((err) => {
      console.debug('[Craft Clipboard] readHTML failed:', err)
      return undefined
    }),
  ])

  return {
    text: text || undefined,
    html: html || undefined,
  }
}

// ============================================================================
// Convenience exports
// ============================================================================

export const clipboard: {
  writeText: typeof writeText
  readText: typeof readText
  writeHTML: typeof writeHTML
  readHTML: typeof readHTML
  clear: typeof clear
  hasText: typeof hasText
  hasHTML: typeof hasHTML
  hasImage: typeof hasImage
  write: typeof write
  read: typeof read
} = {
  writeText,
  readText,
  writeHTML,
  readHTML,
  clear,
  hasText,
  hasHTML,
  hasImage,
  write,
  read,
}

export default clipboard
