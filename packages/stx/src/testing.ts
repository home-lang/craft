/**
 * STX Testing Utilities
 *
 * Helpers for testing stx components and composables.
 *
 * - render() — render a component into a test container
 * - fireEvent — dispatch DOM events
 * - waitFor() — wait for a condition to be true
 * - flushPromises() — flush all pending microtasks
 * - Custom matchers for stx components
 */

import { state, effect, batch } from './runtime'
import type { State } from './runtime'

// ============================================================================
// Render
// ============================================================================

export interface RenderResult {
  /** The container element */
  container: HTMLElement
  /** Find first matching element */
  find: (selector: string) => HTMLElement | null
  /** Find all matching elements */
  findAll: (selector: string) => HTMLElement[]
  /** Get text content of the container */
  text: () => string
  /** Get all attributes of the first matching element */
  attributes: (selector: string) => Record<string, string>
  /** Get classes of the first matching element */
  classes: (selector: string) => string[]
  /** Unmount and clean up */
  unmount: () => void
}

/**
 * Render a component or element into a test container.
 *
 * @example
 * const { find, text, unmount } = render(Button({ variant: 'primary' }, 'Click me'))
 * expect(text()).toBe('Click me')
 * unmount()
 */
export function render(element: HTMLElement | (() => HTMLElement)): RenderResult {
  const container = createContainer()
  const el = typeof element === 'function' ? element() : element
  container.appendChild(el)

  return {
    container,
    find: (selector: string) => container.querySelector(selector),
    findAll: (selector: string) => [...container.querySelectorAll(selector)] as HTMLElement[],
    text: () => container.textContent ?? '',
    attributes: (selector: string) => {
      const target = container.querySelector(selector)
      if (!target) return {}
      const attrs: Record<string, string> = {}
      for (const attr of target.attributes) {
        attrs[attr.name] = attr.value
      }
      return attrs
    },
    classes: (selector: string) => {
      const target = container.querySelector(selector)
      return target ? [...target.classList] : []
    },
    unmount: () => {
      container.innerHTML = ''
      container.remove()
    },
  }
}

// ============================================================================
// Fire Event
// ============================================================================

/**
 * Dispatch DOM events on elements.
 *
 * @example
 * fireEvent.click(button)
 * fireEvent.input(input, { target: { value: 'hello' } })
 */
export const fireEvent = {
  click(el: HTMLElement): void {
    el.dispatchEvent(new MouseEvent('click', { bubbles: true }))
  },

  dblclick(el: HTMLElement): void {
    el.dispatchEvent(new MouseEvent('dblclick', { bubbles: true }))
  },

  input(el: HTMLElement, init?: { target?: { value?: string } }): void {
    if (init?.target?.value !== undefined) {
      (el as HTMLInputElement).value = init.target.value
    }
    el.dispatchEvent(new Event('input', { bubbles: true }))
  },

  change(el: HTMLElement, init?: { target?: { value?: string } }): void {
    if (init?.target?.value !== undefined) {
      (el as HTMLInputElement).value = init.target.value
    }
    el.dispatchEvent(new Event('change', { bubbles: true }))
  },

  focus(el: HTMLElement): void {
    el.dispatchEvent(new FocusEvent('focus'))
  },

  blur(el: HTMLElement): void {
    el.dispatchEvent(new FocusEvent('blur'))
  },

  keydown(el: HTMLElement, init?: KeyboardEventInit): void {
    el.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true, ...init }))
  },

  keyup(el: HTMLElement, init?: KeyboardEventInit): void {
    el.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true, ...init }))
  },

  submit(el: HTMLElement): void {
    el.dispatchEvent(new Event('submit', { bubbles: true }))
  },

  mouseenter(el: HTMLElement): void {
    el.dispatchEvent(new MouseEvent('mouseenter'))
  },

  mouseleave(el: HTMLElement): void {
    el.dispatchEvent(new MouseEvent('mouseleave'))
  },
}

// ============================================================================
// Async Helpers
// ============================================================================

/**
 * Wait for a condition to be true.
 *
 * @example
 * await waitFor(() => el.textContent === 'loaded')
 */
export async function waitFor(
  condition: () => boolean,
  options?: { timeout?: number; interval?: number },
): Promise<void> {
  const timeout = options?.timeout ?? 3000
  const interval = options?.interval ?? 50
  const start = Date.now()

  while (!condition()) {
    if (Date.now() - start > timeout) {
      throw new Error(`waitFor timed out after ${timeout}ms`)
    }
    await new Promise(resolve => setTimeout(resolve, interval))
  }
}

/**
 * Wait for an element matching selector to appear.
 */
export async function waitForElement(
  container: HTMLElement,
  selector: string,
  options?: { timeout?: number },
): Promise<HTMLElement> {
  await waitFor(() => container.querySelector(selector) !== null, options)
  return container.querySelector(selector) as HTMLElement
}

/**
 * Flush all pending microtasks and promises.
 */
export async function flushPromises(): Promise<void> {
  await new Promise(resolve => setTimeout(resolve, 0))
}

// ============================================================================
// Test Context
// ============================================================================

const containers: HTMLElement[] = []

function createContainer(): HTMLElement {
  if (typeof document === 'undefined') {
    // Mock for non-browser test env
    return {
      appendChild: () => {},
      querySelector: () => null,
      querySelectorAll: () => [],
      innerHTML: '',
      textContent: '',
      remove: () => {},
      classList: { add: () => {}, remove: () => {}, toggle: () => {} },
      attributes: [],
    } as unknown as HTMLElement
  }

  const container = document.createElement('div')
  container.setAttribute('data-stx-test', '')
  document.body.appendChild(container)
  containers.push(container)
  return container
}

/**
 * Clean up all test containers.
 * Call in afterEach or afterAll.
 */
export function cleanup(): void {
  for (const container of containers) {
    container.innerHTML = ''
    container.remove()
  }
  containers.length = 0
}

// ============================================================================
// Custom Matchers (assertion helpers)
// ============================================================================

/**
 * Assert element contains text.
 */
export function toContainText(el: HTMLElement, text: string): boolean {
  return (el.textContent ?? '').includes(text)
}

/**
 * Assert element has a CSS class.
 */
export function toHaveClass(el: HTMLElement, className: string): boolean {
  return el.classList.contains(className)
}

/**
 * Assert element has an attribute with optional value.
 */
export function toHaveAttribute(el: HTMLElement, attr: string, value?: string): boolean {
  if (!el.hasAttribute(attr)) return false
  if (value !== undefined) return el.getAttribute(attr) === value
  return true
}

/**
 * Assert element is visible (not display:none).
 */
export function toBeVisible(el: HTMLElement): boolean {
  return el.style.display !== 'none' && !el.hidden
}
