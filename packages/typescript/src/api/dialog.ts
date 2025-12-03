/**
 * Craft Dialog API
 * Native file pickers and alert dialogs
 * @module @craft/api/dialog
 */

import { getBridge } from '../bridge/core'

// ============================================================================
// Types
// ============================================================================

/**
 * File filter for open/save dialogs
 */
export interface FileFilter {
  /** Filter display name (e.g., "Images") */
  name: string
  /** File extensions without dots (e.g., ["png", "jpg", "gif"]) */
  extensions: string[]
}

/**
 * Options for open file dialog
 */
export interface OpenDialogOptions {
  /** Dialog title */
  title?: string
  /** Default path to open */
  defaultPath?: string
  /** File filters */
  filters?: FileFilter[]
  /** Allow selecting multiple files */
  multiple?: boolean
  /** Allow selecting directories */
  directory?: boolean
  /** Show hidden files */
  showHiddenFiles?: boolean
}

/**
 * Options for save file dialog
 */
export interface SaveDialogOptions {
  /** Dialog title */
  title?: string
  /** Default path to save */
  defaultPath?: string
  /** Default file name */
  defaultName?: string
  /** File filters */
  filters?: FileFilter[]
  /** Show hidden files */
  showHiddenFiles?: boolean
}

/**
 * Alert dialog style
 */
export type AlertStyle = 'info' | 'warning' | 'critical'

/**
 * Options for alert dialog
 */
export interface AlertOptions {
  /** Dialog title (main message) */
  title: string
  /** Dialog message (secondary text) */
  message?: string
  /** Alert style */
  style?: AlertStyle
  /** Custom button labels */
  buttons?: string[]
}

/**
 * Options for confirm dialog
 */
export interface ConfirmOptions {
  /** Dialog title (main message) */
  title: string
  /** Dialog message (secondary text) */
  message?: string
  /** OK button label */
  okLabel?: string
  /** Cancel button label */
  cancelLabel?: string
}

/**
 * Result from open dialog
 */
export interface OpenDialogResult {
  /** Whether a file was selected (not cancelled) */
  canceled: boolean
  /** Selected file paths */
  filePaths: string[]
}

/**
 * Result from save dialog
 */
export interface SaveDialogResult {
  /** Whether save was cancelled */
  canceled: boolean
  /** Selected file path */
  filePath?: string
}

// ============================================================================
// Dialog Functions
// ============================================================================

/**
 * Show open file dialog
 * @param options Dialog options
 * @returns Selected file path(s)
 */
export async function openFile(options: OpenDialogOptions = {}): Promise<OpenDialogResult> {
  const action = options.multiple ? 'openFiles' : 'openFile'

  if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
    return new Promise((resolve) => {
      (window as any).webkit.messageHandlers.craft.postMessage({
        type: 'dialog',
        action,
        data: options
      })
      // For now, return empty result - actual implementation needs callback
      resolve({ canceled: false, filePaths: [] })
    })
  }

  const bridge = getBridge()
  return bridge.request(`dialog.${action}`, options)
}

/**
 * Show open folder dialog
 * @param options Dialog options
 * @returns Selected folder path
 */
export async function openFolder(options: Omit<OpenDialogOptions, 'multiple' | 'directory'> = {}): Promise<OpenDialogResult> {
  if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
    return new Promise((resolve) => {
      (window as any).webkit.messageHandlers.craft.postMessage({
        type: 'dialog',
        action: 'openFolder',
        data: options
      })
      resolve({ canceled: false, filePaths: [] })
    })
  }

  const bridge = getBridge()
  return bridge.request('dialog.openFolder', options)
}

/**
 * Show save file dialog
 * @param options Dialog options
 * @returns Selected save path
 */
export async function saveFile(options: SaveDialogOptions = {}): Promise<SaveDialogResult> {
  if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
    return new Promise((resolve) => {
      (window as any).webkit.messageHandlers.craft.postMessage({
        type: 'dialog',
        action: 'saveFile',
        data: options
      })
      resolve({ canceled: false })
    })
  }

  const bridge = getBridge()
  return bridge.request('dialog.saveFile', options)
}

/**
 * Show alert dialog
 * @param options Alert options or just a message string
 * @returns Button index that was clicked
 */
export async function showAlert(options: AlertOptions | string): Promise<number> {
  const opts = typeof options === 'string' ? { title: options } : options

  if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
    return new Promise((resolve) => {
      (window as any).webkit.messageHandlers.craft.postMessage({
        type: 'dialog',
        action: 'showAlert',
        data: opts
      })
      resolve(0)
    })
  }

  const bridge = getBridge()
  return bridge.request('dialog.showAlert', opts)
}

/**
 * Show confirm dialog with OK/Cancel buttons
 * @param options Confirm options or just a message string
 * @returns true if OK was clicked, false if cancelled
 */
export async function showConfirm(options: ConfirmOptions | string): Promise<boolean> {
  const opts = typeof options === 'string' ? { title: options } : options

  if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
    return new Promise((resolve) => {
      (window as any).webkit.messageHandlers.craft.postMessage({
        type: 'dialog',
        action: 'showConfirm',
        data: opts
      })
      resolve(true) // Default to true for now
    })
  }

  const bridge = getBridge()
  return bridge.request('dialog.showConfirm', opts)
}

/**
 * Show prompt dialog with text input
 * @param title Dialog title
 * @param defaultValue Default input value
 * @returns User input or null if cancelled
 */
export async function showPrompt(title: string, defaultValue?: string): Promise<string | null> {
  if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
    return new Promise((resolve) => {
      (window as any).webkit.messageHandlers.craft.postMessage({
        type: 'dialog',
        action: 'showPrompt',
        data: { title, defaultValue }
      })
      resolve(null)
    })
  }

  const bridge = getBridge()
  return bridge.request('dialog.showPrompt', { title, defaultValue })
}

// ============================================================================
// Convenience exports
// ============================================================================

export const dialog = {
  openFile,
  openFolder,
  saveFile,
  showAlert,
  showConfirm,
  showPrompt,
}

export default dialog
