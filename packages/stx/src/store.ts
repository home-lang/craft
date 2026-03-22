/* eslint-disable pickier/no-unused-vars */
/**
 * STX Store — Pinia-inspired state management
 *
 * Provides defineStore() for creating reactive stores with
 * state, getters, actions, $subscribe, $patch, $reset, and persistence.
 */

import { state, effect } from './runtime'
import type { State } from './runtime'

export interface StoreDefinition<S extends Record<string, unknown>, G extends Record<string, unknown>, A extends Record<string, (...args: unknown[]) => unknown>> {
  state: () => S
  getters?: G & ThisType<S & G>
  actions?: A & ThisType<S & G & A & StoreInstance<S, G, A>>
  persist?: PersistOptions | boolean
}

export interface PersistOptions {
  key?: string
  storage?: 'localStorage' | 'sessionStorage' | 'memory'
  paths?: string[]
}

export interface StoreInstance<S extends Record<string, unknown>, G extends Record<string, unknown>, A extends Record<string, (...args: unknown[]) => unknown>> {
  $id: string
  $state: S
  $patch: (partial: Partial<S> | ((state: S) => void)) => void
  $reset: () => void
  $subscribe: (callback: (state: S) => void) => () => void
  $dispose: () => void
}

type StoreReturn<S extends Record<string, unknown>, G extends Record<string, unknown>, A extends Record<string, (...args: unknown[]) => unknown>> =
  { [K in keyof S]: State<S[K]> } & G & A & StoreInstance<S, G, A>

const storeRegistry = new Map<string, unknown>()
const memoryStorage = new Map<string, string>()

function getStorage(type: 'localStorage' | 'sessionStorage' | 'memory'): { getItem(k: string): string | null; setItem(k: string, v: string): void } {
  if (type === 'memory') {
    return {
      getItem: (k: string) => memoryStorage.get(k) ?? null,
      setItem: (k: string, v: string) => memoryStorage.set(k, v),
    }
  }
  if (typeof window !== 'undefined') {
    return type === 'sessionStorage' ? sessionStorage : localStorage
  }
  return { getItem: () => null, setItem: () => {} }
}

/**
 * Define a reactive store.
 *
 * @example
 * const useCounter = defineStore('counter', {
 *   state: () => ({ count: 0 }),
 *   getters: {
 *     doubled() { return this.count * 2 }
 *   },
 *   actions: {
 *     increment() { this.count++ }
 *   }
 * })
 *
 * const counter = useCounter()
 * counter.count()       // 0
 * counter.increment()
 * counter.doubled       // 2
 */
export function defineStore<
  S extends Record<string, unknown>,
  G extends Record<string, unknown>,
  A extends Record<string, (...args: unknown[]) => unknown>,
>(id: string, definition: StoreDefinition<S, G, A>): () => StoreReturn<S, G, A> {
  return () => {
    // Return existing instance if already created
    if (storeRegistry.has(id)) {
      return storeRegistry.get(id) as StoreReturn<S, G, A>
    }

    const initialState = definition.state()
    const subscribers: Array<(state: S) => void> = []
    const cleanups: Array<() => void> = []

    // Create reactive state signals
    const signals: Record<string, State<unknown>> = {}
    for (const [key, value] of Object.entries(initialState)) {
      signals[key] = state(value)
    }

    // Persistence
    const persistOpts = definition.persist
      ? typeof definition.persist === 'boolean'
        ? { key: `stx-store-${id}`, storage: 'localStorage' as const }
        : { key: definition.persist.key ?? `stx-store-${id}`, storage: definition.persist.storage ?? 'localStorage' }
      : null

    if (persistOpts) {
      const storage = getStorage(persistOpts.storage)
      const saved = storage.getItem(persistOpts.key!)
      if (saved) {
        try {
          const parsed = JSON.parse(saved)
          for (const [key, value] of Object.entries(parsed)) {
            if (signals[key]) (signals[key] as State<unknown>).set(value)
          }
        }
        catch { /* invalid stored data */ }
      }

      // Auto-persist on change
      for (const [key, sig] of Object.entries(signals)) {
        const unsub = sig.subscribe(() => {
          const current: Record<string, unknown> = {}
          for (const [k, s] of Object.entries(signals)) {
            current[k] = s()
          }
          storage.setItem(persistOpts.key!, JSON.stringify(current))
        })
        cleanups.push(unsub)
      }
    }

    // Build the store proxy that provides `this` context for getters/actions
    const getCurrentState = (): S => {
      const s: Record<string, unknown> = {}
      for (const [key, sig] of Object.entries(signals)) {
        s[key] = sig()
      }
      return s as S
    }

    // Build store instance
    const instance: Record<string, unknown> = {}

    // Expose signals as properties
    for (const [key, sig] of Object.entries(signals)) {
      instance[key] = sig
    }

    // Getters (computed from state via `this`)
    if (definition.getters) {
      for (const [key, getter] of Object.entries(definition.getters)) {
        Object.defineProperty(instance, key, {
          get: () => {
            const ctx = getCurrentState()
            return (getter as Function).call(ctx)
          },
          enumerable: true,
        })
      }
    }

    // Actions (bound to store context)
    if (definition.actions) {
      for (const [key, action] of Object.entries(definition.actions)) {
        instance[key] = (...args: unknown[]) => {
          // Build a mutable proxy for `this` in actions
          const proxy = new Proxy({} as Record<string, unknown>, {
            get(_target, prop: string) {
              if (signals[prop]) return signals[prop]()
              if (instance[prop]) return instance[prop]
              return undefined
            },
            set(_target, prop: string, value: unknown) {
              if (signals[prop]) (signals[prop] as State<unknown>).set(value)
              return true
            },
          })
          const result = (action as Function).apply(proxy, args)
          // Notify subscribers
          for (const sub of subscribers) sub(getCurrentState())
          return result
        }
      }
    }

    // Store methods
    instance.$id = id

    Object.defineProperty(instance, '$state', {
      get: getCurrentState,
    })

    instance.$patch = (partial: Partial<S> | ((state: S) => void)) => {
      if (typeof partial === 'function') {
        const proxy = new Proxy(getCurrentState(), {
          set(_target, prop: string, value: unknown) {
            if (signals[prop]) (signals[prop] as State<unknown>).set(value)
            return true
          },
        })
        partial(proxy)
      }
      else {
        for (const [key, value] of Object.entries(partial)) {
          if (signals[key]) (signals[key] as State<unknown>).set(value)
        }
      }
      for (const sub of subscribers) sub(getCurrentState())
    }

    instance.$reset = () => {
      const fresh = definition.state()
      for (const [key, value] of Object.entries(fresh)) {
        if (signals[key]) (signals[key] as State<unknown>).set(value)
      }
      for (const sub of subscribers) sub(getCurrentState())
    }

    instance.$subscribe = (callback: (state: S) => void) => {
      subscribers.push(callback)
      return () => {
        const idx = subscribers.indexOf(callback)
        if (idx >= 0) subscribers.splice(idx, 1)
      }
    }

    instance.$dispose = () => {
      for (const cleanup of cleanups) cleanup()
      cleanups.length = 0
      subscribers.length = 0
      storeRegistry.delete(id)
    }

    storeRegistry.set(id, instance)
    return instance as StoreReturn<S, G, A>
  }
}
