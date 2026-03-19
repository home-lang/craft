import { describe, expect, test } from 'bun:test'
import { state, derived, effect, batch } from '../src/runtime'

describe('state', () => {
  test('read initial value', () => {
    const count = state(0)
    expect(count()).toBe(0)
  })

  test('set value', () => {
    const count = state(0)
    count.set(5)
    expect(count()).toBe(5)
  })

  test('update value with function', () => {
    const count = state(0)
    count.update(n => n + 1)
    expect(count()).toBe(1)
    count.update(n => n * 3)
    expect(count()).toBe(3)
  })

  test('skip update on same value', () => {
    let effectCount = 0
    const count = state(0)
    effect(() => {
      count()
      effectCount++
    })
    effectCount = 0

    count.set(0) // same value
    expect(effectCount).toBe(0)
  })

  test('subscribe', () => {
    const values: number[] = []
    const count = state(0)
    const unsub = count.subscribe(v => values.push(v))

    count.set(1)
    count.set(2)
    unsub()
    count.set(3)

    expect(values).toEqual([1, 2])
  })
})

describe('derived', () => {
  test('compute from state', () => {
    const count = state(2)
    const doubled = derived(() => count() * 2)
    expect(doubled()).toBe(4)
  })

  test('recompute on dependency change', () => {
    const count = state(1)
    const doubled = derived(() => count() * 2)

    count.set(5)
    expect(doubled()).toBe(10)
  })

  test('lazy evaluation', () => {
    let computeCount = 0
    const count = state(0)
    const doubled = derived(() => {
      computeCount++
      return count() * 2
    })

    expect(computeCount).toBe(0) // not computed yet
    doubled() // first access
    expect(computeCount).toBe(1)
    doubled() // cached
    expect(computeCount).toBe(1)
  })

  test('chain derived values', () => {
    const a = state(1)
    const b = derived(() => a() + 1)
    const c = derived(() => b() * 2)

    expect(c()).toBe(4) // (1+1)*2
    a.set(5)
    expect(c()).toBe(12) // (5+1)*2
  })
})

describe('effect', () => {
  test('run immediately', () => {
    let ran = false
    effect(() => { ran = true })
    expect(ran).toBe(true)
  })

  test('re-run on dependency change', () => {
    const values: number[] = []
    const count = state(0)

    effect(() => {
      values.push(count())
    })

    count.set(1)
    count.set(2)
    expect(values).toEqual([0, 1, 2])
  })

  test('cleanup on re-run', () => {
    let cleanedUp = false
    const count = state(0)

    effect(() => {
      count()
      return () => { cleanedUp = true }
    })

    expect(cleanedUp).toBe(false)
    count.set(1)
    expect(cleanedUp).toBe(true)
  })

  test('cleanup on dispose', () => {
    let cleanedUp = false
    const dispose = effect(() => {
      return () => { cleanedUp = true }
    })

    expect(cleanedUp).toBe(false)
    dispose()
    expect(cleanedUp).toBe(true)
  })
})

describe('batch', () => {
  test('defer effects until batch completes', () => {
    const values: number[] = []
    const a = state(0)
    const b = state(0)

    effect(() => {
      values.push(a() + b())
    })

    values.length = 0 // clear initial

    batch(() => {
      a.set(1)
      b.set(2)
    })

    // Should only record the final state, not intermediate
    expect(values).toEqual([3])
  })
})
