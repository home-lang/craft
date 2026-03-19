/**
 * STX Reactivity Runtime
 *
 * Minimal signal-based reactivity system for stx components.
 * Provides signal(), computed(), and effect() primitives.
 */

type Subscriber = () => void

let currentEffect: Subscriber | null = null
let batchDepth = 0
const pendingEffects = new Set<Subscriber>()

export interface ReadonlySignal<T> {
  readonly value: T
  subscribe(fn: (value: T) => void): () => void
}

export interface Signal<T> extends ReadonlySignal<T> {
  value: T
}

export interface Computed<T> extends ReadonlySignal<T> {
  readonly value: T
}

/**
 * Create a reactive signal.
 */
export function signal<T>(initialValue: T): Signal<T> {
  let value = initialValue
  const subscribers = new Set<Subscriber>()

  const sig = {
    get value(): T {
      if (currentEffect) {
        subscribers.add(currentEffect)
      }
      return value
    },

    set value(newValue: T) {
      if (Object.is(value, newValue)) return
      value = newValue
      for (const sub of subscribers) {
        if (batchDepth > 0) {
          pendingEffects.add(sub)
        }
        else {
          sub()
        }
      }
    },

    subscribe(fn: (value: T) => void): () => void {
      const subscriber: Subscriber = () => fn(sig.value)
      subscribers.add(subscriber)
      return () => subscribers.delete(subscriber)
    },
  }

  return sig
}

/**
 * Create a computed (derived) value from signals.
 */
export function computed<T>(fn: () => T): Computed<T> {
  let cachedValue: T
  let dirty = true
  const subscribers = new Set<Subscriber>()

  const recompute: Subscriber = () => {
    dirty = true
    for (const sub of subscribers) {
      if (batchDepth > 0) {
        pendingEffects.add(sub)
      }
      else {
        sub()
      }
    }
  }

  const comp: Computed<T> = {
    get value(): T {
      if (currentEffect) {
        subscribers.add(currentEffect)
      }
      if (dirty) {
        const prev = currentEffect
        currentEffect = recompute
        try {
          cachedValue = fn()
        }
        finally {
          currentEffect = prev
        }
        dirty = false
      }
      return cachedValue
    },

    subscribe(callback: (value: T) => void): () => void {
      const subscriber: Subscriber = () => callback(comp.value)
      subscribers.add(subscriber)
      return () => subscribers.delete(subscriber)
    },
  }

  return comp
}

/**
 * Run a side-effect whenever its signal dependencies change.
 * Returns a cleanup function.
 */
export function effect(fn: () => void | (() => void)): () => void {
  let cleanup: void | (() => void)

  const execute: Subscriber = () => {
    if (typeof cleanup === 'function') cleanup()
    const prev = currentEffect
    currentEffect = execute
    try {
      cleanup = fn()
    }
    finally {
      currentEffect = prev
    }
  }

  execute()

  return () => {
    if (typeof cleanup === 'function') cleanup()
  }
}

/**
 * Batch multiple signal updates into a single flush.
 */
export function batch(fn: () => void): void {
  batchDepth++
  try {
    fn()
  }
  finally {
    batchDepth--
    if (batchDepth === 0) {
      const effects = [...pendingEffects]
      pendingEffects.clear()
      for (const eff of effects) {
        eff()
      }
    }
  }
}
