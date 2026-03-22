import { describe, expect, test } from 'bun:test'
import { createErrorBoundary, withErrorBoundary } from '../src/errorBoundary'

describe('error boundary', () => {
  test('createErrorBoundary returns instance with expected API', () => {
    const boundary = createErrorBoundary()
    expect(typeof boundary.error).toBe('function') // State<Error | null>
    expect(typeof boundary.hasError).toBe('function')
    expect(typeof boundary.retry).toBe('function')
    expect(typeof boundary.reset).toBe('function')
    expect(typeof boundary.wrap).toBe('function')
  })

  test('withErrorBoundary is a function', () => {
    expect(typeof withErrorBoundary).toBe('function')
  })

  test('initial state has no error', () => {
    const boundary = createErrorBoundary()
    expect(boundary.error()).toBeNull()
    expect(boundary.hasError()).toBe(false)
  })

  test('reset clears error state', () => {
    const boundary = createErrorBoundary()
    // Manually set error via the state
    boundary.error.set(new Error('test'))
    expect(boundary.hasError()).toBe(true)

    boundary.reset()
    expect(boundary.error()).toBeNull()
    expect(boundary.hasError()).toBe(false)
  })
})
