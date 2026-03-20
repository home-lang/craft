import { state, effect } from '../runtime'
import type { State } from '../runtime'

/**
 * Debounce a signal value — only updates after the delay.
 *
 * @example
 * const search = state('')
 * const debouncedSearch = useDebouncedValue(search, 300)
 *
 * // debouncedSearch() updates 300ms after last search.set()
 */
export function useDebouncedValue<T>(source: State<T>, delay: number = 300): State<T> {
  const debounced = state<T>(source())
  let timer: ReturnType<typeof setTimeout> | null = null

  effect(() => {
    const value = source()
    if (timer) clearTimeout(timer)
    timer = setTimeout(() => {
      debounced.set(value)
    }, delay)
  })

  return debounced
}

/**
 * Create a debounced function.
 *
 * @example
 * const save = useDebounce(() => api.save(data()), 500)
 * save() // only fires after 500ms of inactivity
 */
export function useDebounce<T extends (...args: unknown[]) => unknown>(
  fn: T,
  delay: number = 300,
): (...args: Parameters<T>) => void {
  let timer: ReturnType<typeof setTimeout> | null = null

  return (...args: Parameters<T>) => {
    if (timer) clearTimeout(timer)
    timer = setTimeout(() => fn(...args), delay)
  }
}
