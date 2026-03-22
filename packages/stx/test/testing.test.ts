import { describe, expect, test } from 'bun:test'
import { fireEvent, waitFor, flushPromises, cleanup, toContainText, toHaveClass, toHaveAttribute, toBeVisible } from '../src/testing'

describe('testing utilities', () => {
  test('fireEvent has standard event methods', () => {
    expect(typeof fireEvent.click).toBe('function')
    expect(typeof fireEvent.input).toBe('function')
    expect(typeof fireEvent.change).toBe('function')
    expect(typeof fireEvent.focus).toBe('function')
    expect(typeof fireEvent.blur).toBe('function')
    expect(typeof fireEvent.keydown).toBe('function')
    expect(typeof fireEvent.keyup).toBe('function')
    expect(typeof fireEvent.submit).toBe('function')
    expect(typeof fireEvent.mouseenter).toBe('function')
    expect(typeof fireEvent.mouseleave).toBe('function')
    expect(typeof fireEvent.dblclick).toBe('function')
  })

  test('waitFor resolves when condition is true', async () => {
    let ready = false
    setTimeout(() => { ready = true }, 10)
    await waitFor(() => ready, { timeout: 1000 })
    expect(ready).toBe(true)
  })

  test('waitFor throws on timeout', async () => {
    let threw = false
    try {
      await waitFor(() => false, { timeout: 50, interval: 10 })
    }
    catch {
      threw = true
    }
    expect(threw).toBe(true)
  })

  test('flushPromises resolves', async () => {
    let resolved = false
    Promise.resolve().then(() => { resolved = true })
    await flushPromises()
    expect(resolved).toBe(true)
  })

  test('cleanup is a function', () => {
    expect(typeof cleanup).toBe('function')
  })

  test('assertion helpers work with mock elements', () => {
    const el = {
      textContent: 'Hello World',
      classList: { contains: (c: string) => c === 'active' },
      hasAttribute: (a: string) => a === 'disabled',
      getAttribute: (a: string) => a === 'disabled' ? '' : null,
      style: { display: '' },
      hidden: false,
    } as unknown as HTMLElement

    expect(toContainText(el, 'Hello')).toBe(true)
    expect(toContainText(el, 'Nope')).toBe(false)
    expect(toHaveClass(el, 'active')).toBe(true)
    expect(toHaveClass(el, 'hidden')).toBe(false)
    expect(toHaveAttribute(el, 'disabled')).toBe(true)
    expect(toHaveAttribute(el, 'readonly')).toBe(false)
    expect(toBeVisible(el)).toBe(true)
  })
})
