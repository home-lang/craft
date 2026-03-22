import { describe, expect, test } from 'bun:test'
import { defineStore } from '../src/store'
import { state } from '../src/runtime'

describe('defineStore', () => {
  test('create store with state', () => {
    const useCounter = defineStore('test-counter', {
      state: () => ({ count: 0 }),
    })

    const store = useCounter()
    expect(store.count()).toBe(0)
  })

  test('return same instance on subsequent calls', () => {
    const useStore = defineStore('test-singleton', {
      state: () => ({ x: 1 }),
    })

    const a = useStore()
    const b = useStore()
    expect(a).toBe(b)

    // Cleanup
    a.$dispose()
  })

  test('$patch with object', () => {
    const useStore = defineStore('test-patch-obj', {
      state: () => ({ a: 1, b: 2 }),
    })

    const store = useStore()
    store.$patch({ a: 10 })
    expect(store.a()).toBe(10)
    expect(store.b()).toBe(2)

    store.$dispose()
  })

  test('$reset restores initial state', () => {
    const useStore = defineStore('test-reset', {
      state: () => ({ count: 0 }),
    })

    const store = useStore()
    ;(store.count as ReturnType<typeof state>).set(42)
    expect(store.count()).toBe(42)

    store.$reset()
    expect(store.count()).toBe(0)

    store.$dispose()
  })

  test('$subscribe notifies on changes', () => {
    const useStore = defineStore('test-subscribe', {
      state: () => ({ value: 'a' }),
    })

    const store = useStore()
    const received: string[] = []

    store.$subscribe((s: Record<string, unknown>) => {
      received.push(s.value as string)
    })

    store.$patch({ value: 'b' })
    store.$patch({ value: 'c' })

    expect(received).toEqual(['b', 'c'])

    store.$dispose()
  })

  test('$dispose cleans up', () => {
    const useStore = defineStore('test-dispose', {
      state: () => ({ x: 0 }),
    })

    const store = useStore()
    store.$dispose()

    // New call creates fresh instance
    const store2 = useStore()
    expect(store2).not.toBe(store)
    store2.$dispose()
  })

  test('getters compute from state', () => {
    const useStore = defineStore('test-getters', {
      state: () => ({ count: 5 }),
      getters: {
        doubled() { return (this as unknown as { count: number }).count * 2 },
      },
    })

    const store = useStore()
    expect(store.doubled).toBe(10)

    store.$dispose()
  })
})
