/**
 * Craft Clipboard API
 * Read and write to the system clipboard
 * @module @craft-native/api/clipboard
 */

import { getBridge } from '../bridge/core'
import { isWebKitHost, postWebKit, webkitRequest } from '../bridge/webkit-pending'

/** Default timeout for callback-style clipboard reads. */
const CLIPBOARD_READ_TIMEOUT_MS = 5000

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
  if (isWebKitHost()) {
    postWebKit({ type: 'clipboard', action: 'writeText', data: { text } })
    return
  }

  const bridge = getBridge()
  return bridge.request('clipboard.writeText', { text })
}

/**
 * Read text from clipboard
 * @returns Clipboard text content
 */
export async function readText(): Promise<string> {
  if (isWebKitHost()) {
    const payload = await webkitRequest<{ text?: string } | undefined>(
      'readText',
      { type: 'clipboard', action: 'readText' },
      { timeoutMs: CLIPBOARD_READ_TIMEOUT_MS },
    )
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
  if (isWebKitHost()) {
    postWebKit({ type: 'clipboard', action: 'writeHTML', data: { html } })
    return
  }

  const bridge = getBridge()
  return bridge.request('clipboard.writeHTML', { html })
}

/**
 * Read HTML from clipboard
 * @returns Clipboard HTML content
 */
export async function readHTML(): Promise<string> {
  if (isWebKitHost()) {
    const payload = await webkitRequest<{ html?: string } | undefined>(
      'readHTML',
      { type: 'clipboard', action: 'readHTML' },
      { timeoutMs: CLIPBOARD_READ_TIMEOUT_MS },
    )
    return payload && typeof payload.html === 'string' ? payload.html : ''
  }

  const bridge = getBridge()
  return bridge.request('clipboard.readHTML')
}

/**
 * Clear clipboard contents
 */
export async function clear(): Promise<void> {
  if (isWebKitHost()) {
    postWebKit({ type: 'clipboard', action: 'clear' })
    return
  }

  const bridge = getBridge()
  return bridge.request('clipboard.clear')
}

/**
 * Check if clipboard has text content
 * @returns true if clipboard contains text
 */
export async function hasText(): Promise<boolean> {
  if (isWebKitHost()) {
    const payload = await webkitRequest<{ value?: boolean } | undefined>(
      'hasText',
      { type: 'clipboard', action: 'hasText' },
      { timeoutMs: CLIPBOARD_READ_TIMEOUT_MS },
    )
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
  if (isWebKitHost()) {
    const payload = await webkitRequest<{ value?: boolean } | undefined>(
      'hasHTML',
      { type: 'clipboard', action: 'hasHTML' },
      { timeoutMs: CLIPBOARD_READ_TIMEOUT_MS },
    )
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
  if (isWebKitHost()) {
    const payload = await webkitRequest<{ value?: boolean } | undefined>(
      'hasImage',
      { type: 'clipboard', action: 'hasImage' },
      { timeoutMs: CLIPBOARD_READ_TIMEOUT_MS },
    )
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
