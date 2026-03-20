import { state, effect } from '../runtime'
import type { State } from '../runtime'

interface FetchResult<T> {
  data: State<T | null>
  error: State<Error | null>
  loading: State<boolean>
  refetch: () => Promise<void>
}

interface FetchOptions<T> {
  initialData?: T | null
  immediate?: boolean
  headers?: Record<string, string>
}

/**
 * Reactive data fetching.
 *
 * @example
 * const { data, loading, error } = useFetch<User[]>('/api/users')
 *
 * // With options
 * const { data, refetch } = useFetch('/api/data', {
 *   initialData: [],
 *   headers: { Authorization: 'Bearer ...' }
 * })
 */
export function useFetch<T>(url: string | State<string>, options: FetchOptions<T> = {}): FetchResult<T> {
  const data = state<T | null>(options.initialData ?? null)
  const error = state<Error | null>(null)
  const loading = state(false)

  const doFetch = async () => {
    const resolvedUrl = typeof url === 'function' ? url() : url
    loading.set(true)
    error.set(null)

    try {
      const response = await fetch(resolvedUrl, {
        headers: options.headers,
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }

      const json = await response.json()
      data.set(json as T)
    }
    catch (err) {
      error.set(err instanceof Error ? err : new Error(String(err)))
    }
    finally {
      loading.set(false)
    }
  }

  // Auto-fetch if URL is reactive
  if (typeof url === 'function' && 'subscribe' in url) {
    effect(() => {
      url() // track
      doFetch()
    })
  }
  else if (options.immediate !== false) {
    doFetch()
  }

  return { data, error, loading, refetch: doFetch }
}
