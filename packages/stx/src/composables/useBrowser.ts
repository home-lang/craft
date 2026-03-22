/**
 * Browser Composables
 *
 * Reactive wrappers for common browser APIs.
 */

import { state, effect, onDestroy } from '../runtime'
import type { State } from '../runtime'

/**
 * Reactive event listener with automatic cleanup.
 */
export function useEventListener<K extends keyof WindowEventMap>(
  target: EventTarget | null | undefined,
  event: K,
  handler: (e: WindowEventMap[K]) => void,
  options?: AddEventListenerOptions,
): () => void {
  if (!target) return () => {}
  target.addEventListener(event, handler as EventListener, options)
  const cleanup = () => target.removeEventListener(event, handler as EventListener, options)
  onDestroy(cleanup)
  return cleanup
}

/**
 * Reactive window size.
 */
export function useWindowSize(): { width: State<number>; height: State<number> } {
  const width = state(typeof window !== 'undefined' ? window.innerWidth : 0)
  const height = state(typeof window !== 'undefined' ? window.innerHeight : 0)

  if (typeof window !== 'undefined') {
    useEventListener(window, 'resize', () => {
      width.set(window.innerWidth)
      height.set(window.innerHeight)
    })
  }

  return { width, height }
}

/**
 * Reactive online/offline status.
 */
export function useOnline(): State<boolean> {
  const online = state(typeof navigator !== 'undefined' ? navigator.onLine : true)

  if (typeof window !== 'undefined') {
    useEventListener(window, 'online', () => online.set(true))
    useEventListener(window, 'offline', () => online.set(false))
  }

  return online
}

/**
 * Reactive clipboard read/write.
 */
export function useClipboard(): {
  text: State<string>
  copy: (value: string) => Promise<void>
  copied: State<boolean>
} {
  const text = state('')
  const copied = state(false)

  const copy = async (value: string) => {
    if (typeof navigator !== 'undefined' && navigator.clipboard) {
      await navigator.clipboard.writeText(value)
      text.set(value)
      copied.set(true)
      setTimeout(() => copied.set(false), 2000)
    }
  }

  return { text, copy, copied }
}

/**
 * Reactive document title.
 */
export function useTitle(initialTitle?: string): State<string> {
  const title = state(initialTitle ?? (typeof document !== 'undefined' ? document.title : ''))

  effect(() => {
    if (typeof document !== 'undefined') {
      document.title = title()
    }
  })

  return title
}

/**
 * Reactive boolean toggle.
 */
export function useToggle(initial: boolean = false): [State<boolean>, () => void] {
  const value = state(initial)
  const toggle = () => value.update(v => !v)
  return [value, toggle]
}

/**
 * Reactive counter with increment/decrement/reset.
 */
export function useCounter(initial: number = 0): {
  count: State<number>
  increment: (by?: number) => void
  decrement: (by?: number) => void
  reset: () => void
} {
  const count = state(initial)
  return {
    count,
    increment: (by = 1) => count.update(n => n + by),
    decrement: (by = 1) => count.update(n => n - by),
    reset: () => count.set(initial),
  }
}

/**
 * Reactive interval.
 */
export function useInterval(callback: () => void, ms: number): { start: () => void; stop: () => void; active: State<boolean> } {
  const active = state(false)
  let id: ReturnType<typeof setInterval> | null = null

  const stop = () => {
    if (id !== null) {
      clearInterval(id)
      id = null
    }
    active.set(false)
  }

  const start = () => {
    stop()
    id = setInterval(callback, ms)
    active.set(true)
  }

  onDestroy(stop)
  return { start, stop, active }
}

/**
 * Reactive timeout.
 */
export function useTimeout(callback: () => void, ms: number): { start: () => void; stop: () => void; pending: State<boolean> } {
  const pending = state(false)
  let id: ReturnType<typeof setTimeout> | null = null

  const stop = () => {
    if (id !== null) {
      clearTimeout(id)
      id = null
    }
    pending.set(false)
  }

  const start = () => {
    stop()
    pending.set(true)
    id = setTimeout(() => {
      callback()
      pending.set(false)
      id = null
    }, ms)
  }

  onDestroy(stop)
  return { start, stop, pending }
}

/**
 * Reactive mouse position.
 */
export function useMouse(): { x: State<number>; y: State<number> } {
  const x = state(0)
  const y = state(0)

  if (typeof window !== 'undefined') {
    useEventListener(window, 'mousemove', (e: MouseEvent) => {
      x.set(e.clientX)
      y.set(e.clientY)
    })
  }

  return { x, y }
}

/**
 * Reactive scroll position.
 */
export function useScroll(): { x: State<number>; y: State<number> } {
  const x = state(0)
  const y = state(0)

  if (typeof window !== 'undefined') {
    useEventListener(window, 'scroll', () => {
      x.set(window.scrollX)
      y.set(window.scrollY)
    }, { passive: true })
  }

  return { x, y }
}

/**
 * Reactive focus tracking.
 */
export function useFocus(target?: HTMLElement): { focused: State<boolean>; focus: () => void; blur: () => void } {
  const focused = state(false)

  if (target) {
    useEventListener(target, 'focus', () => focused.set(true))
    useEventListener(target, 'blur', () => focused.set(false))
  }

  return {
    focused,
    focus: () => target?.focus(),
    blur: () => target?.blur(),
  }
}
