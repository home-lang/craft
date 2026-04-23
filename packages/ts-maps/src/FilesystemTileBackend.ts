/**
 * Filesystem-backed tile persistence for `ts-maps` `TileCache`.
 *
 * Wraps Craft's `fs` bridge (which transparently falls back to `node:fs`
 * when running outside a Craft WebView) so that tile bytes for an
 * offline region are written to an app-sandboxed directory rather than
 * IndexedDB. Returned objects plug straight into `TileCache` via its
 * `backend` option.
 *
 * Each cached tile is serialised as a single `.tsm` file containing:
 *
 *   magic      4 bytes    "TSMT"
 *   version    1 byte     0x01
 *   keyLen     4 bytes    little-endian uint32
 *   mimeLen    4 bytes    little-endian uint32
 *   etagLen    4 bytes    little-endian uint32 (0 = no etag)
 *   updatedAt  8 bytes    little-endian float64 (ms epoch)
 *   expiresAt  8 bytes    little-endian float64 (ms epoch, 0 = no expiry)
 *   dataLen    4 bytes    little-endian uint32
 *   key        keyLen bytes  UTF-8
 *   mime       mimeLen bytes UTF-8
 *   etag       etagLen bytes UTF-8
 *   data       dataLen bytes payload
 *
 * Filenames are `<hash>.tsm` where `<hash>` is a 64-bit FNV-1a of the
 * URL (two 32-bit passes with different seeds) rendered in base36. That
 * keeps filenames short, URL-safe, and collision-resistant enough for
 * the tile counts an offline region realistically produces.
 *
 * @module @craft-native/ts-maps/FilesystemTileBackend
 */

import type { Backend, CachedTile } from 'ts-maps'
// Import the fs helpers directly from their source module rather than from
// the `@craft-native/craft` package root, matching how `MapView` talks to
// the bridge — keeps the type graph narrow.
import { fs, readBinaryFile, writeBinaryFile } from '../../typescript/src/api/fs'

export interface FilesystemBackendOptions {
  /**
   * Directory where tile files are stored. Created on first write if it
   * doesn't exist. On Craft apps this is typically something like
   * `app.dataDir + '/tiles'` — the caller resolves the platform-specific
   * path and passes it in.
   */
  baseDir: string
}

const MAGIC = [0x54, 0x53, 0x4D, 0x54] // "TSMT"
const VERSION = 0x01
const FILE_SUFFIX = '.tsm'

/**
 * Construct a {@link Backend} that persists tiles under `baseDir`.
 * Pass the returned object to `new TileCache({ backend })` (or to the
 * cache used by `saveOfflineRegion`).
 */
export function createFilesystemBackend(opts: FilesystemBackendOptions): Backend {
  const baseDir = stripTrailingSlash(opts.baseDir)
  let ensured = false

  async function ensureDir(): Promise<void> {
    if (ensured)
      return
    if (!(await fs.exists(baseDir)))
      await fs.mkdir(baseDir)
    ensured = true
  }

  function filePath(key: string): string {
    return `${baseDir}/${hashKey(key)}${FILE_SUFFIX}`
  }

  return {
    async get(key: string): Promise<CachedTile | undefined> {
      const path = filePath(key)
      if (!(await fs.exists(path)))
        return undefined
      try {
        const bytes = await readBinaryFile(path)
        const decoded = decodeTile(bytes)
        // Guard against FNV collisions: if the stored key doesn't match
        // the requested URL we treat it as a miss rather than serving the
        // wrong payload.
        if (decoded.key !== key)
          return undefined
        return decoded
      }
      catch {
        return undefined
      }
    },

    async put(tile: CachedTile): Promise<void> {
      await ensureDir()
      const payload = encodeTile(tile)
      await writeBinaryFile(filePath(tile.key), payload)
    },

    async delete(key: string): Promise<void> {
      const path = filePath(key)
      try {
        if (await fs.exists(path))
          await fs.remove(path)
      }
      catch {
        // swallow: a missing tile is not an error for our caller
      }
    },

    async clear(): Promise<void> {
      try {
        if (!(await fs.exists(baseDir)))
          return
        const entries = await fs.readDir(baseDir)
        for (const name of entries) {
          if (!name.endsWith(FILE_SUFFIX))
            continue
          try {
            await fs.remove(`${baseDir}/${name}`)
          }
          catch { /* ignore per-entry failure */ }
        }
      }
      catch { /* ignore */ }
    },

    async all(): Promise<CachedTile[]> {
      if (!(await fs.exists(baseDir)))
        return []
      let entries: string[]
      try {
        entries = await fs.readDir(baseDir)
      }
      catch {
        return []
      }
      const out: CachedTile[] = []
      for (const name of entries) {
        if (!name.endsWith(FILE_SUFFIX))
          continue
        try {
          const bytes = await readBinaryFile(`${baseDir}/${name}`)
          out.push(decodeTile(bytes))
        }
        catch {
          // skip unreadable / corrupt entries
        }
      }
      return out
    },
  }
}

// ---------------------------------------------------------------------------
// Encoding
// ---------------------------------------------------------------------------

function encodeTile(tile: CachedTile): Uint8Array {
  const enc = new TextEncoder()
  const key = enc.encode(tile.key)
  const mime = enc.encode(tile.mime)
  const etag = enc.encode(tile.etag ?? '')

  const headerLen = 4 + 1 + 4 + 4 + 4 + 8 + 8 + 4
  const total = headerLen + key.length + mime.length + etag.length + tile.data.length
  const buf = new Uint8Array(total)
  const view = new DataView(buf.buffer)

  let o = 0
  buf[o++] = MAGIC[0]
  buf[o++] = MAGIC[1]
  buf[o++] = MAGIC[2]
  buf[o++] = MAGIC[3]
  buf[o++] = VERSION
  view.setUint32(o, key.length, true); o += 4
  view.setUint32(o, mime.length, true); o += 4
  view.setUint32(o, etag.length, true); o += 4
  view.setFloat64(o, tile.updatedAt, true); o += 8
  view.setFloat64(o, tile.expiresAt ?? 0, true); o += 8
  view.setUint32(o, tile.data.length, true); o += 4

  buf.set(key, o); o += key.length
  buf.set(mime, o); o += mime.length
  buf.set(etag, o); o += etag.length
  buf.set(tile.data, o)

  return buf
}

function decodeTile(bytes: Uint8Array): CachedTile {
  if (bytes.length < 37)
    throw new Error('truncated tile record')
  if (bytes[0] !== MAGIC[0] || bytes[1] !== MAGIC[1] || bytes[2] !== MAGIC[2] || bytes[3] !== MAGIC[3])
    throw new Error('bad tile magic')
  if (bytes[4] !== VERSION)
    throw new Error(`unsupported tile version ${bytes[4]}`)

  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength)
  let o = 5
  const keyLen = view.getUint32(o, true); o += 4
  const mimeLen = view.getUint32(o, true); o += 4
  const etagLen = view.getUint32(o, true); o += 4
  const updatedAt = view.getFloat64(o, true); o += 8
  const expiresAtRaw = view.getFloat64(o, true); o += 8
  const dataLen = view.getUint32(o, true); o += 4

  const dec = new TextDecoder()
  const key = dec.decode(bytes.subarray(o, o + keyLen)); o += keyLen
  const mime = dec.decode(bytes.subarray(o, o + mimeLen)); o += mimeLen
  const etag = etagLen > 0 ? dec.decode(bytes.subarray(o, o + etagLen)) : undefined
  o += etagLen
  const data = bytes.subarray(o, o + dataLen).slice()

  return {
    key,
    data,
    mime,
    etag,
    updatedAt,
    expiresAt: expiresAtRaw > 0 ? expiresAtRaw : undefined,
    bytes: data.length,
  }
}

// ---------------------------------------------------------------------------
// Hash. Two FNV-1a-32 passes with different seeds — effectively a 64-bit
// hash. Good enough for tile-scale workloads; `get()` re-verifies the
// stored key against the request to catch the collision case.
// ---------------------------------------------------------------------------

function hashKey(key: string): string {
  let a = 0x811C9DC5 >>> 0
  let b = 0xCBF29CE4 >>> 0
  for (let i = 0; i < key.length; i++) {
    const c = key.charCodeAt(i)
    a ^= c
    a = Math.imul(a, 0x01000193) >>> 0
    b ^= c
    b = Math.imul(b, 0x00000105) >>> 0
  }
  return `${a.toString(36)}${b.toString(36)}`
}

function stripTrailingSlash(path: string): string {
  return path.replace(/\/+$/, '')
}
