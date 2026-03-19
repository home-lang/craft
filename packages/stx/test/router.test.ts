import { describe, expect, test } from 'bun:test'

// Router tests focus on the parseable/testable parts since
// full navigation requires a browser environment (DOM, fetch, history)

describe('router module exports', () => {
  test('exports createRouter', async () => {
    const mod = await import('../src/router/index')
    expect(typeof mod.createRouter).toBe('function')
  })

  test('exports navigate', async () => {
    const mod = await import('../src/router/index')
    expect(typeof mod.navigate).toBe('function')
  })

  test('exports getCurrentRoute', async () => {
    const mod = await import('../src/router/index')
    expect(typeof mod.getCurrentRoute).toBe('function')
  })

  test('exports StxLink', async () => {
    const mod = await import('../src/router/index')
    expect(typeof mod.StxLink).toBe('function')
  })

  test('exports loadShell', async () => {
    const mod = await import('../src/router/index')
    expect(typeof mod.loadShell).toBe('function')
  })

  test('exports injectPage', async () => {
    const mod = await import('../src/router/index')
    expect(typeof mod.injectPage).toBe('function')
  })
})
