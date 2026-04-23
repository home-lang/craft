/**
 * Thin Craft-specific wrapper around ts-maps' `saveOfflineRegion` that
 * writes tile bytes to the app's sandboxed filesystem via the
 * {@link createFilesystemBackend} adapter.
 *
 * Typical usage from a Craft app:
 *
 *   ```ts
 *   import { saveOfflineRegionToFilesystem } from '@craft-native/ts-maps'
 *   import { app } from '@craft-native/craft'
 *
 *   await saveOfflineRegionToFilesystem({
 *     baseDir: `${await app.dataDir()}/tiles`,
 *     tileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
 *     bounds: mapViewBounds,
 *     zoomRange: [10, 14],
 *   })
 *   ```
 *
 * The download runs with bounded concurrency and respects `AbortSignal`,
 * so a user canceling the region pre-cache tears the job down cleanly.
 *
 * @module @craft-native/ts-maps/offlineRegion
 */

import type {
  OfflineBoundsLike,
  OfflineProgressEmitter,
  OfflineRegionResult,
  TileCacheOptions,
} from 'ts-maps'
import { saveOfflineRegion, TileCache } from 'ts-maps'
import { createFilesystemBackend } from './FilesystemTileBackend'

export interface FilesystemOfflineRegionOptions {
  /** Sandbox directory for tile files. Created on first write. */
  baseDir: string
  /** Tile URL template — `{z}/{x}/{y}` placeholders are substituted. */
  tileUrl: string
  bounds: OfflineBoundsLike
  zoomRange: [minZ: number, maxZ: number]
  concurrency?: number
  signal?: AbortSignal
  /** Optional overrides for the `TileCache` wrapping the filesystem backend. */
  cacheOptions?: Omit<TileCacheOptions, 'backend'>
}

/**
 * Pre-download every tile inside `bounds` across `zoomRange` and persist
 * it to disk under `baseDir`. Returns counts of saved / cached-already /
 * failed tiles.
 */
export function saveOfflineRegionToFilesystem(
  opts: FilesystemOfflineRegionOptions,
  emitter?: OfflineProgressEmitter,
): Promise<OfflineRegionResult> {
  const cache = new TileCache({
    ...opts.cacheOptions,
    backend: createFilesystemBackend({ baseDir: opts.baseDir }),
  })
  return saveOfflineRegion(
    {
      bounds: opts.bounds,
      zoomRange: opts.zoomRange,
      tileUrl: opts.tileUrl,
      concurrency: opts.concurrency,
      signal: opts.signal,
      cache,
    },
    emitter,
  )
}

/**
 * Build a standalone {@link TileCache} whose persistence layer is the
 * Craft sandbox filesystem. Useful when a map instance needs to serve
 * pre-saved tiles at runtime (not just pre-download them).
 */
export function createFilesystemTileCache(
  baseDir: string,
  cacheOptions?: Omit<TileCacheOptions, 'backend'>,
): TileCache {
  return new TileCache({
    ...cacheOptions,
    backend: createFilesystemBackend({ baseDir }),
  })
}
