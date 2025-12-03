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
    return new Promise((resolve) => {
      (window as any).webkit.messageHandlers.craft.postMessage({
        type: 'clipboard',
        action: 'writeText',
        data: { text }
      })
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
    return new Promise((resolve) => {
      (window as any).webkit.messageHandlers.craft.postMessage({
        type: 'clipboard',
        action: 'readText'
      })
      // For now return empty - actual implementation needs callback
      resolve('')
    })
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
    return new Promise((resolve) => {
      (window as any).webkit.messageHandlers.craft.postMessage({
        type: 'clipboard',
        action: 'readHTML'
      })
      resolve('')
    })
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
    return new Promise((resolve) => {
      (window as any).webkit.messageHandlers.craft.postMessage({
        type: 'clipboard',
        action: 'hasText'
      })
      resolve(false)
    })
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
    return new Promise((resolve) => {
      (window as any).webkit.messageHandlers.craft.postMessage({
        type: 'clipboard',
        action: 'hasHTML'
      })
      resolve(false)
    })
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
    return new Promise((resolve) => {
      (window as any).webkit.messageHandlers.craft.postMessage({
        type: 'clipboard',
        action: 'hasImage'
      })
      resolve(false)
    })
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

export const clipboard = {
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
