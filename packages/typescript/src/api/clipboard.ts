/**
 * Craft Clipboard API
 * Read and write to the system clipboard
 * @module @craft/api/clipboard
 */

import { getBridge } from '../bridge/core'

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
    return new Promise((resolve, reject) => {
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
    return new Promise<string>((resolve, reject) => {
      const w = window as any
      w.__craftBridgePending = w.__craftBridgePending || {}
      w.__craftBridgePending.readText = w.__craftBridgePending.readText || []
      w.__craftBridgePending.readText.push({ resolve, reject })

      w.webkit.messageHandlers.craft.postMessage({
        type: 'clipboard',
        action: 'readText'
      })
    }).then((payload: any) => (payload && typeof payload.text === 'string' ? payload.text : ''))
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
    return new Promise<string>((resolve, reject) => {
      const w = window as any
      w.__craftBridgePending = w.__craftBridgePending || {}
      w.__craftBridgePending.readHTML = w.__craftBridgePending.readHTML || []
      w.__craftBridgePending.readHTML.push({ resolve, reject })

      w.webkit.messageHandlers.craft.postMessage({
        type: 'clipboard',
        action: 'readHTML'
      })
    }).then((payload: any) => (payload && typeof payload.html === 'string' ? payload.html : ''))
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
    return new Promise<boolean>((resolve, reject) => {
      const w = window as any
      w.__craftBridgePending = w.__craftBridgePending || {}
      w.__craftBridgePending.hasText = w.__craftBridgePending.hasText || []
      w.__craftBridgePending.hasText.push({ resolve, reject })

      w.webkit.messageHandlers.craft.postMessage({
        type: 'clipboard',
        action: 'hasText'
      })
    }).then((payload: any) => !!(payload && (payload.value === true)))
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
    return new Promise<boolean>((resolve, reject) => {
      const w = window as any
      w.__craftBridgePending = w.__craftBridgePending || {}
      w.__craftBridgePending.hasHTML = w.__craftBridgePending.hasHTML || []
      w.__craftBridgePending.hasHTML.push({ resolve, reject })

      w.webkit.messageHandlers.craft.postMessage({
        type: 'clipboard',
        action: 'hasHTML'
      })
    }).then((payload: any) => !!(payload && (payload.value === true)))
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
    return new Promise<boolean>((resolve, reject) => {
      const w = window as any
      w.__craftBridgePending = w.__craftBridgePending || {}
      w.__craftBridgePending.hasImage = w.__craftBridgePending.hasImage || []
      w.__craftBridgePending.hasImage.push({ resolve, reject })

      w.webkit.messageHandlers.craft.postMessage({
        type: 'clipboard',
        action: 'hasImage'
      })
    }).then((payload: any) => !!(payload && (payload.value === true)))
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
    readText().catch(() => undefined),
    readHTML().catch(() => undefined),
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
  writeText: writeText,
  readText: readText,
  writeHTML: writeHTML,
  readHTML: readHTML,
  clear: clear,
  hasText: hasText,
  hasHTML: hasHTML,
  hasImage: hasImage,
  write: write,
  read: read,
}

export default clipboard
