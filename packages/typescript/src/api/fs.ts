/**
 * @fileoverview Craft File System API
 * @description Provides native file system access through the Craft bridge.
 * Works in both browser (via native bridge) and Node.js environments.
 * @module @craft-native/api/fs
 *
 * @example
 * ```typescript
 * import { fs, readBinaryFile, stat, watch } from '@craft-native/api/fs'
 *
 * // Read a text file
 * const content = await fs.readFile('/path/to/file.txt')
 *
 * // Write to a file
 * await fs.writeFile('/path/to/output.txt', 'Hello, World!')
 *
 * // List directory contents
 * const files = await fs.readDir('/path/to/directory')
 *
 * // Watch for changes (returns a Promise<() => void>)
 * const unwatch = await watch('/path/to/watch', (event, filename) => {
 *   console.log(`${event}: ${filename}`)
 * })
 * ```
 */

import type { CraftFileSystemAPI } from '../types'

/**
 * Get the native Craft file system bridge, or null if not in Craft environment.
 */
function getCraftFs(): CraftFileSystemAPI | null {
  if (typeof window !== 'undefined' && (window as any).craft?.fs) {
    return (window as any).craft.fs
  }
  return null
}

/**
 * Validate a file path to prevent directory traversal attacks.
 *
 * Rejects:
 *   - Any `..` segment (including after URL-decoding, since the host bridge may
 *     percent-decode before opening the file)
 *   - Embedded NULs (truncate filenames in C APIs)
 *   - Empty/whitespace-only paths
 *
 * When a `root` is provided, additionally asserts that the resolved absolute
 * path is contained within `root` (best-effort — symlinks are still resolved
 * by the OS at open time).
 */
export function validatePath(path: string, root?: string): void {
  if (typeof path !== 'string' || path.length === 0) {
    throw new Error('Invalid path: must be a non-empty string')
  }

  // Block null bytes (can truncate paths in C APIs)
  if (path.includes('\0')) {
    throw new Error('Invalid path: contains null byte')
  }

  // Decode percent-encoded sequences before splitting so an attacker can't
  // sneak `..` past us as `%2e%2e`.
  let decoded = path
  try {
    decoded = decodeURIComponent(path)
  }
  catch {
    // decodeURIComponent throws on malformed sequences; treat the raw path as
    // suspect rather than failing open.
    throw new Error('Invalid path: malformed percent-encoding')
  }

  // Normalize backslashes to forward slashes and split on / segments.
  const segments = decoded.replace(/\\/g, '/').split('/')
  for (const segment of segments) {
    if (segment === '..') {
      throw new Error(`Path traversal detected: "${path}" contains a ".." segment`)
    }
  }

  if (root) {
    // Best-effort containment check (browser path-resolve is approximate).
    const baseAbs = root.endsWith('/') ? root : `${root}/`
    const resolved = decoded.startsWith('/') ? decoded : `${baseAbs}${decoded}`
    if (!resolved.startsWith(baseAbs) && resolved !== root) {
      throw new Error(`Path escapes root: "${path}" not within "${root}"`)
    }
  }
}

/**
 * File system API implementation.
 * Uses the native Craft bridge for file operations when running in a Craft app,
 * with automatic fallback to Node.js APIs when running in a Node environment.
 *
 * @example
 * ```typescript
 * import { fs } from '@craft-native/api/fs'
 *
 * // Check if a file exists before reading
 * if (await fs.exists('/config.json')) {
 *   const config = JSON.parse(await fs.readFile('/config.json'))
 * }
 * ```
 */
export const fs: CraftFileSystemAPI = {
  /**
   * Read file contents as a UTF-8 string.
   *
   * @param path - Absolute or relative path to the file
   * @returns Promise resolving to the file contents as a string
   * @throws {Error} If the file doesn't exist or cannot be read
   *
   * @example
   * ```typescript
   * const content = await fs.readFile('/Users/me/document.txt')
   * console.log(content)
   *
   * // Read JSON file
   * const data = JSON.parse(await fs.readFile('./config.json'))
   * ```
   */
  async readFile(path: string): Promise<string> {
    validatePath(path)
    const native = getCraftFs()
    if (native) return native.readFile(path)
    // Node.js fallback
    const { readFile } = await import('node:fs/promises')
    return readFile(path, 'utf-8')
  },

  /**
   * Write string content to a file.
   * Creates the file if it doesn't exist, overwrites if it does.
   *
   * @param path - Absolute or relative path to the file
   * @param content - String content to write
   * @returns Promise that resolves when write is complete
   * @throws {Error} If the directory doesn't exist or write fails
   *
   * @example
   * ```typescript
   * // Write text file
   * await fs.writeFile('/path/to/file.txt', 'Hello, World!')
   *
   * // Write JSON
   * await fs.writeFile('./config.json', JSON.stringify(config, null, 2))
   * ```
   */
  async writeFile(path: string, content: string): Promise<void> {
    validatePath(path)
    const native = getCraftFs()
    if (native) return native.writeFile(path, content)
    // Node.js fallback
    const { writeFile } = await import('node:fs/promises')
    return writeFile(path, content, 'utf-8')
  },

  /**
   * Read directory contents.
   * Returns an array of file and directory names (not full paths).
   *
   * @param path - Absolute or relative path to the directory
   * @returns Promise resolving to array of entry names
   * @throws {Error} If the directory doesn't exist or cannot be read
   *
   * @example
   * ```typescript
   * const entries = await fs.readDir('/Users/me/Documents')
   * // ['file1.txt', 'file2.pdf', 'subfolder']
   *
   * // Filter for specific files
   * const txtFiles = entries.filter(name => name.endsWith('.txt'))
   * ```
   */
  async readDir(path: string): Promise<string[]> {
    validatePath(path)
    const native = getCraftFs()
    if (native) return native.readDir(path)
    // Node.js fallback
    const { readdir } = await import('node:fs/promises')
    return readdir(path)
  },

  /**
   * Create a directory recursively.
   * Creates all parent directories if they don't exist.
   *
   * @param path - Absolute or relative path to create
   * @returns Promise that resolves when directory is created
   *
   * @example
   * ```typescript
   * // Creates /a/b/c even if /a and /a/b don't exist
   * await fs.mkdir('/a/b/c')
   * ```
   */
  async mkdir(path: string): Promise<void> {
    validatePath(path)
    const native = getCraftFs()
    if (native) return native.mkdir(path)
    // Node.js fallback
    const { mkdir } = await import('node:fs/promises')
    await mkdir(path, { recursive: true })
  },

  /**
   * Remove a file or directory.
   * Recursively removes directories and all their contents.
   *
   * @param path - Absolute or relative path to remove
   * @returns Promise that resolves when removal is complete
   *
   * @example
   * ```typescript
   * // Remove a file
   * await fs.remove('/path/to/file.txt')
   *
   * // Remove a directory and all contents
   * await fs.remove('/path/to/directory')
   * ```
   */
  async remove(path: string): Promise<void> {
    validatePath(path)
    const native = getCraftFs()
    if (native) return native.remove(path)
    // Node.js fallback
    const { rm } = await import('node:fs/promises')
    return rm(path, { recursive: true, force: true })
  },

  /**
   * Check if a path exists.
   *
   * @param path - Absolute or relative path to check
   * @returns Promise resolving to true if path exists, false otherwise
   *
   * @example
   * ```typescript
   * if (await fs.exists('/config.json')) {
   *   const config = await fs.readFile('/config.json')
   * }
else {
   *   console.log('Config file not found')
   * }
   * ```
   */
  async exists(path: string): Promise<boolean> {
    validatePath(path)
    const native = getCraftFs()
    if (native) return native.exists(path)
    // Node.js fallback
    const { access } = await import('node:fs/promises')
    try {
      await access(path)
      return true
    }
catch {
      return false
    }
  }
}

/**
 * Read file as binary data (Uint8Array).
 * Use this for non-text files like images, PDFs, or other binary formats.
 *
 * @param path - Absolute or relative path to the file
 * @returns Promise resolving to file contents as Uint8Array
 * @throws {Error} If the file doesn't exist or cannot be read
 *
 * @example
 * ```typescript
 * // Read an image file
 * const imageData = await readBinaryFile('/path/to/image.png')
 *
 * // Convert to Blob for display
 * const blob = new Blob([imageData], { type: 'image/png' })
 * const url = URL.createObjectURL(blob)
 * ```
 */
export async function readBinaryFile(path: string): Promise<Uint8Array> {
  validatePath(path)
  if (typeof window !== 'undefined' && window.craft) {
    // Bridge call to read binary file
    const response = await (window.craft as any).bridge?.call('fs.readBinaryFile', { path })
    return new Uint8Array(response.data)
  }
  // Node.js fallback
  const { readFile } = await import('node:fs/promises')
  return readFile(path)
}

/**
 * Write binary data to a file.
 * Use this for non-text files like images, PDFs, or other binary formats.
 *
 * @param path - Absolute or relative path to the file
 * @param data - Binary data to write
 * @returns Promise that resolves when write is complete
 * @throws {Error} If the directory doesn't exist or write fails
 *
 * @example
 * ```typescript
 * // Write image data to file
 * const imageData = new Uint8Array([...])
 * await writeBinaryFile('/path/to/output.png', imageData)
 *
 * // Download and save a file
 * const response = await fetch('https://example.com/file.pdf')
 * const data = new Uint8Array(await response.arrayBuffer())
 * await writeBinaryFile('/downloads/file.pdf', data)
 * ```
 */
export async function writeBinaryFile(path: string, data: Uint8Array): Promise<void> {
  validatePath(path)
  if (typeof window !== 'undefined' && window.craft) {
    // Bridge call to write binary file
    await (window.craft as any).bridge?.call('fs.writeBinaryFile', { path, data: Array.from(data) })
    return
  }
  // Node.js fallback
  const { writeFile } = await import('node:fs/promises')
  return writeFile(path, data)
}

/**
 * File statistics information.
 *
 * @property size - File size in bytes
 * @property isFile - True if this is a regular file
 * @property isDirectory - True if this is a directory
 * @property modifiedAt - Date when the file was last modified
 * @property createdAt - Date when the file was created
 */
export interface FileStats {
  /** File size in bytes */
  size: number
  /** True if this is a regular file */
  isFile: boolean
  /** True if this is a directory */
  isDirectory: boolean
  /** Date when the file was last modified */
  modifiedAt: Date
  /** Date when the file was created */
  createdAt: Date
}

/**
 * Get file or directory statistics.
 *
 * @param path - Absolute or relative path to the file or directory
 * @returns Promise resolving to FileStats object
 * @throws {Error} If the path doesn't exist
 *
 * @example
 * ```typescript
 * const stats = await stat('/path/to/file.txt')
 *
 * console.log(`Size: ${stats.size} bytes`)
 * console.log(`Modified: ${stats.modifiedAt.toISOString()}`)
 *
 * if (stats.isDirectory) {
 *   const contents = await fs.readDir('/path/to/file.txt')
 * }
 * ```
 */
export async function stat(path: string): Promise<FileStats> {
  validatePath(path)
  if (typeof window !== 'undefined' && window.craft) {
    const response = await (window.craft as any).bridge?.call('fs.stat', { path })
    return {
      size: response.size,
      isFile: response.isFile,
      isDirectory: response.isDirectory,
      modifiedAt: new Date(response.modifiedAt),
      createdAt: new Date(response.createdAt),
    }
  }
  // Node.js fallback
  const { stat: nodeStat } = await import('node:fs/promises')
  const stats = await nodeStat(path)
  return {
    size: stats.size,
    isFile: stats.isFile(),
    isDirectory: stats.isDirectory(),
    modifiedAt: stats.mtime,
    createdAt: stats.birthtime,
  }
}

/**
 * Copy a file or directory to a new location.
 * Recursively copies directories and all their contents.
 *
 * @param src - Source path
 * @param dest - Destination path
 * @returns Promise that resolves when copy is complete
 * @throws {Error} If source doesn't exist or copy fails
 *
 * @example
 * ```typescript
 * // Copy a file
 * await copy('/path/to/source.txt', '/path/to/dest.txt')
 *
 * // Copy a directory
 * await copy('/path/to/srcDir', '/path/to/destDir')
 * ```
 */
export async function copy(src: string, dest: string): Promise<void> {
  validatePath(src)
  validatePath(dest)
  if (typeof window !== 'undefined' && window.craft) {
    await (window.craft as any).bridge?.call('fs.copy', { src, dest })
    return
  }
  // Node.js fallback. dereference: false stops a symlink under `src` from
  // tricking cp into writing files outside `dest`. verbatimSymlinks: true
  // keeps the link itself intact instead of resolving it relative to `dest`.
  const { cp } = await import('node:fs/promises')
  return cp(src, dest, {
    recursive: true,
    dereference: false,
    verbatimSymlinks: true,
  })
}

/**
 * Move or rename a file or directory.
 *
 * @param src - Current path
 * @param dest - New path
 * @returns Promise that resolves when move is complete
 * @throws {Error} If source doesn't exist or move fails
 *
 * @example
 * ```typescript
 * // Rename a file
 * await move('/path/to/old-name.txt', '/path/to/new-name.txt')
 *
 * // Move to different directory
 * await move('/downloads/file.txt', '/documents/file.txt')
 * ```
 */
export async function move(src: string, dest: string): Promise<void> {
  validatePath(src)
  validatePath(dest)
  if (typeof window !== 'undefined' && window.craft) {
    await (window.craft as any).bridge?.call('fs.move', { src, dest })
    return
  }
  // Node.js fallback
  const { rename } = await import('node:fs/promises')
  return rename(src, dest)
}

/**
 * Watch a file or directory for changes.
 * Returns a Promise that resolves with an unwatch function once the watcher
 * is fully initialized.
 *
 * Important: the returned unwatch function MUST be called when the watcher is
 * no longer needed. Forgotten watchers leak both the underlying OS handle and
 * the JS-side event listener.
 *
 * @param path - Path to watch
 * @param callback - Function called when changes occur
 * @returns Promise resolving to a function that stops watching
 *
 * @example
 * ```typescript
 * const stopWatching = await watch('/path/to/file.txt', (event, filename) => {
 *   console.log(`File ${filename} was ${event}`)
 * })
 *
 * // Later, stop watching
 * stopWatching()
 * ```
 */
export async function watch(
  path: string,
  callback: (event: string, filename: string) => void
): Promise<() => void> {
  validatePath(path)
  if (typeof window !== 'undefined' && window.craft) {
    const watchId = typeof globalThis.crypto !== 'undefined' && 'randomUUID' in globalThis.crypto
      ? (globalThis.crypto as Crypto).randomUUID()
      : `${Date.now()}_${performance.now()}`
    ;(window.craft as any).bridge?.call('fs.watch', { path, watchId })

    const handler = (event: CustomEvent) => {
      if (event.detail.watchId === watchId) {
        callback(event.detail.eventType, event.detail.filename)
      }
    }
    window.addEventListener('craft:fs:watch' as any, handler)

    return () => {
      window.removeEventListener('craft:fs:watch' as any, handler)
      ;(window.craft as any).bridge?.call('fs.unwatch', { watchId })
    }
  }

  // Node.js fallback — await the import so the caller's `unwatch` actually
  // closes the watcher (the previous fire-and-forget version sometimes
  // returned a stub that did nothing).
  const nodeFs = await import('node:fs')
  const watcher = nodeFs.watch(path, (event: string, filename: string | null) => {
    if (filename) callback(event, filename)
  })
  return () => watcher.close()
}

export default fs
