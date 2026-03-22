/**
 * STX Error Boundaries
 *
 * Catch and handle rendering errors gracefully.
 * Supports fallback UI, retry, and nested boundaries.
 */

/* eslint-disable pickier/no-unused-vars */
import { state, effect } from './runtime'
import { h } from './component'
import type { State } from './runtime'

export interface ErrorBoundaryOptions {
  id?: string
  logErrors?: boolean
  onError?: (error: Error, info: { componentStack?: string }) => void
}

export interface ErrorBoundaryInstance {
  error: State<Error | null>
  hasError: () => boolean
  retry: () => void
  reset: () => void
}

/**
 * Create an error boundary that wraps content with error handling.
 *
 * @example
 * const boundary = createErrorBoundary({
 *   logErrors: true,
 *   onError: (err) => reportError(err)
 * })
 *
 * const el = boundary.wrap(
 *   () => riskyComponent(),
 *   () => h('div', { class: 'text-red-500' }, 'Something went wrong')
 * )
 */
export function createErrorBoundary(options: ErrorBoundaryOptions = {}): ErrorBoundaryInstance & {
  wrap: (content: () => HTMLElement, fallback?: (error: Error, retry: () => void) => HTMLElement) => HTMLElement
} {
  const error = state<Error | null>(null)
  let contentFn: (() => HTMLElement) | null = null
  let container: HTMLElement | null = null

  const instance: ErrorBoundaryInstance = {
    error,
    hasError: () => error() !== null,
    retry: () => {
      error.set(null)
      if (contentFn && container) {
        renderContent(container, contentFn)
      }
    },
    reset: () => {
      error.set(null)
    },
  }

  function renderContent(target: HTMLElement, fn: () => HTMLElement): void {
    target.innerHTML = ''
    try {
      const content = fn()
      target.appendChild(content)
    }
    catch (err) {
      const e = err instanceof Error ? err : new Error(String(err))
      error.set(e)

      if (options.logErrors !== false) {
        console.error(`[stx-error-boundary${options.id ? `:${options.id}` : ''}]`, e)
      }

      options.onError?.(e, {})

      // Dispatch event
      if (typeof window !== 'undefined') {
        window.dispatchEvent(new CustomEvent('stx:error', { detail: { error: e, boundaryId: options.id } }))
      }
    }
  }

  return {
    ...instance,

    wrap(content: () => HTMLElement, fallback?: (error: Error, retry: () => void) => HTMLElement): HTMLElement {
      contentFn = content
      container = h('div', { 'data-stx-error-boundary': options.id ?? '' })

      // Initial render
      renderContent(container, content)

      // Reactive fallback swap
      effect(() => {
        const err = error()
        if (err && fallback && container) {
          container.innerHTML = ''
          container.appendChild(fallback(err, instance.retry))
        }
      })

      return container
    },
  }
}

/**
 * Higher-order function to wrap a component with error boundary.
 */
export function withErrorBoundary(
  component: () => HTMLElement,
  fallback: (error: Error, retry: () => void) => HTMLElement,
  options?: ErrorBoundaryOptions,
): HTMLElement {
  const boundary = createErrorBoundary(options)
  return boundary.wrap(component, fallback)
}
