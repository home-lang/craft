import { describe, expect, test } from 'bun:test'
import { createKeepAlive } from '../src/keepAlive'

describe('keep-alive', () => {
  function mockEl(id: string): HTMLElement {
    return { id, querySelector: () => null, dispatchEvent: () => true } as unknown as HTMLElement
  }

  test('set and get cached element', () => {
    const cache = createKeepAlive()
    const el = mockEl('home')

    cache.set('home', el)
    expect(cache.has('home')).toBe(true)
    expect(cache.get('home')).toBe(el)
  })

  test('returns null for uncached key', () => {
    const cache = createKeepAlive()
    expect(cache.get('missing')).toBeNull()
    expect(cache.has('missing')).toBe(false)
  })

  test('respects max cache size (LRU eviction)', () => {
    const cache = createKeepAlive({ max: 2 })

    cache.set('a', mockEl('a'))
    cache.set('b', mockEl('b'))
    cache.set('c', mockEl('c')) // should evict 'a'

    expect(cache.has('a')).toBe(false)
    expect(cache.has('b')).toBe(true)
    expect(cache.has('c')).toBe(true)
  })

  test('remove from cache', () => {
    const cache = createKeepAlive()
    cache.set('page', mockEl('page'))
    cache.remove('page')
    expect(cache.has('page')).toBe(false)
  })

  test('clear removes all entries', () => {
    const cache = createKeepAlive()
    cache.set('a', mockEl('a'))
    cache.set('b', mockEl('b'))
    cache.clear()
    expect(cache.size).toBe(0)
  })

  test('getCacheKeys returns all keys', () => {
    const cache = createKeepAlive()
    cache.set('x', mockEl('x'))
    cache.set('y', mockEl('y'))
    expect(cache.getCacheKeys()).toEqual(['x', 'y'])
  })

  test('exclude option prevents caching', () => {
    const cache = createKeepAlive({ exclude: ['settings'] })
    cache.set('settings', mockEl('settings'))
    expect(cache.has('settings')).toBe(false)
  })

  test('include option limits caching', () => {
    const cache = createKeepAlive({ include: ['home', 'about'] })
    cache.set('home', mockEl('home'))
    cache.set('other', mockEl('other'))
    expect(cache.has('home')).toBe(true)
    expect(cache.has('other')).toBe(false)
  })
})
