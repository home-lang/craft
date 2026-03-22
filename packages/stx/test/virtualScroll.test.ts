import { describe, expect, test } from 'bun:test'

describe('virtual scrolling', () => {
  test('exports createVirtualList', async () => {
    const mod = await import('../src/virtualScroll')
    expect(typeof mod.createVirtualList).toBe('function')
  })

  test('exports createVirtualGrid', async () => {
    const mod = await import('../src/virtualScroll')
    expect(typeof mod.createVirtualGrid).toBe('function')
  })
})
