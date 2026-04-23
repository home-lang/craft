/**
 * Exercises `createFilesystemBackend` against a real temporary directory
 * via craft's `fs` Node.js fallback. The backend must behave identically
 * to the in-memory default `TileCache` backend for get / put / delete /
 * clear / all, with bytes surviving a full decode round-trip.
 */

import { afterEach, beforeEach, describe, expect, test } from 'bun:test'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { TileCache } from 'ts-maps'
import { createFilesystemBackend, createFilesystemTileCache } from '../src'

let baseDir: string

beforeEach(() => {
  baseDir = mkdtempSync(join(tmpdir(), 'ts-maps-fs-'))
})

afterEach(() => {
  rmSync(baseDir, { recursive: true, force: true })
})

describe('createFilesystemBackend', () => {
  test('round-trips a tile (data, mime, etag, timestamps)', async () => {
    const backend = createFilesystemBackend({ baseDir })
    const data = new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    const now = Date.now()

    await backend.put({
      key: 'https://example.com/tile/0/0/0.pbf',
      data,
      mime: 'application/x-protobuf',
      etag: 'W/"abc123"',
      updatedAt: now,
      expiresAt: now + 60_000,
      bytes: data.byteLength,
    })

    const got = await backend.get('https://example.com/tile/0/0/0.pbf')
    expect(got).toBeDefined()
    expect(got!.key).toBe('https://example.com/tile/0/0/0.pbf')
    expect(got!.mime).toBe('application/x-protobuf')
    expect(got!.etag).toBe('W/"abc123"')
    expect(got!.updatedAt).toBe(now)
    expect(got!.expiresAt).toBe(now + 60_000)
    expect(got!.bytes).toBe(10)
    expect(Array.from(got!.data)).toEqual(Array.from(data))
  })

  test('handles tiles with no etag and no expiry', async () => {
    const backend = createFilesystemBackend({ baseDir })
    await backend.put({
      key: 'https://example.com/a',
      data: new Uint8Array([42]),
      mime: 'image/png',
      updatedAt: 1,
      bytes: 1,
    })
    const got = await backend.get('https://example.com/a')
    expect(got!.etag).toBeUndefined()
    expect(got!.expiresAt).toBeUndefined()
  })

  test('get on a missing key returns undefined', async () => {
    const backend = createFilesystemBackend({ baseDir })
    expect(await backend.get('nope')).toBeUndefined()
  })

  test('delete removes the entry', async () => {
    const backend = createFilesystemBackend({ baseDir })
    await backend.put({
      key: 'k',
      data: new Uint8Array([1]),
      mime: 'x',
      updatedAt: 0,
      bytes: 1,
    })
    expect(await backend.get('k')).toBeDefined()
    await backend.delete('k')
    expect(await backend.get('k')).toBeUndefined()
  })

  test('delete of a missing key is a no-op', async () => {
    const backend = createFilesystemBackend({ baseDir })
    await backend.delete('never-existed')
    // no throw
  })

  test('all() returns every stored tile', async () => {
    const backend = createFilesystemBackend({ baseDir })
    for (let i = 0; i < 5; i++) {
      await backend.put({
        key: `k-${i}`,
        data: new Uint8Array([i]),
        mime: 'x',
        updatedAt: i,
        bytes: 1,
      })
    }
    const all = await backend.all()
    const keys = all.map(t => t.key).sort()
    expect(keys).toEqual(['k-0', 'k-1', 'k-2', 'k-3', 'k-4'])
  })

  test('clear() empties the store', async () => {
    const backend = createFilesystemBackend({ baseDir })
    await backend.put({
      key: 'k',
      data: new Uint8Array([1]),
      mime: 'x',
      updatedAt: 0,
      bytes: 1,
    })
    await backend.clear()
    expect(await backend.all()).toEqual([])
  })
})

describe('TileCache with filesystem backend', () => {
  test('get/put/size/prune all work through the ts-maps class', async () => {
    const cache = createFilesystemTileCache(baseDir, {
      maxBytes: 1024 * 1024,
      maxEntries: 100,
      ttlMs: 0,
    })

    await cache.put('url-1', new Uint8Array([1, 2, 3]), 'image/png')
    await cache.put('url-2', new Uint8Array([4, 5]), 'image/png')

    const tile = await cache.get('url-1')
    expect(tile).toBeDefined()
    expect(Array.from(tile!.data)).toEqual([1, 2, 3])
    expect(tile!.mime).toBe('image/png')

    const size = await cache.size()
    expect(size.entries).toBe(2)
    expect(size.bytes).toBe(5)

    await cache.delete('url-1')
    expect(await cache.get('url-1')).toBeUndefined()

    await cache.clear()
    expect((await cache.size()).entries).toBe(0)
  })

  test('prune evicts to respect maxEntries', async () => {
    const cache = createFilesystemTileCache(baseDir, {
      maxBytes: 10_000,
      maxEntries: 2,
      ttlMs: 0,
    })

    // Different updatedAt so the LRU ordering is deterministic.
    for (let i = 0; i < 4; i++) {
      await cache.put(`u-${i}`, new Uint8Array([i]), 'x')
      await new Promise(r => setTimeout(r, 1))
    }

    await cache.prune()
    const size = await cache.size()
    expect(size.entries).toBe(2)
  })

  test('honours ttlMs — expired entries vanish on get', async () => {
    const cache = new TileCache({
      backend: createFilesystemBackend({ baseDir }),
      ttlMs: 1,
    })
    await cache.put('k', new Uint8Array([1]), 'x')
    await new Promise(r => setTimeout(r, 5))
    expect(await cache.get('k')).toBeUndefined()
  })
})
