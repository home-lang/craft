import { state } from '../runtime'
import type { State } from '../runtime'

interface Ref<T extends HTMLElement = HTMLElement> {
  /** The DOM element (null until mounted) */
  value: T | null
  /** Alias for .value (React-style) */
  current: T | null
  /** Bind to an element — used internally by the template compiler */
  _bind(el: T): void
}

/**
 * Create a reactive DOM reference.
 * Auto-imported in stx scripts.
 *
 * @example
 * // In <script>
 * const inputRef = useRef<HTMLInputElement>('input')
 *
 * onMount(() => {
 *   inputRef.value?.focus()
 * })
 *
 * // In <template>
 * <input ref="input" />
 */
export function useRef<T extends HTMLElement = HTMLElement>(_name?: string): Ref<T> {
  const elState = state<T | null>(null)

  const ref: Ref<T> = {
    get value() { return elState() },
    get current() { return elState() },
    _bind(el: T) { elState.set(el) },
  }

  return ref
}
