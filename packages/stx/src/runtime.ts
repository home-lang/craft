/**
 * STX Reactivity Runtime
 *
 * Signal-based reactivity aligned with the stx syntax migration.
 * - state(val) — read via count(), write via count.set() / count.update()
 * - derived(fn) — computed value, read via fn()
 * - effect(fn) — side effects that auto-track dependencies
 * - batch(fn) — batch multiple updates
 */

type Subscriber = () => void

let currentEffect: Subscriber | null = null
let batchDepth = 0
const pendingEffects = new Set<Subscriber>()

/**
 * A reactive state signal. Call it to read, use .set() or .update() to write.
 */
export interface State<T> {
  /** Read the current value */
  (): T
  /** Set a new value */
  set(value: T): void
  /** Update value with a function */
  update(fn: (current: T) => T): void
  /** Subscribe to changes */
  subscribe(fn: (value: T) => void): () => void
}

/**
 * A derived (computed) signal. Call it to read.
 */
export interface Derived<T> {
  /** Read the current derived value */
  (): T
  /** Subscribe to changes */
  subscribe(fn: (value: T) => void): () => void
}

function notify(subscribers: Set<Subscriber>): void {
  for (const sub of subscribers) {
    if (batchDepth > 0) {
      pendingEffects.add(sub)
    }
    else {
      sub()
    }
  }
}

/**
 * Create a reactive state signal.
 *
 * @example
 * const count = state(0)
 * count()          // read: 0
 * count.set(5)     // write
 * count.update(n => n + 1) // update
 */
export function state<T>(initialValue: T): State<T> {
  let value = initialValue
  const subscribers = new Set<Subscriber>()

  const s = (() => {
    if (currentEffect) {
      subscribers.add(currentEffect)
    }
    return value
  }) as State<T>

  s.set = (newValue: T) => {
    if (Object.is(value, newValue)) return
    value = newValue
    notify(subscribers)
  }

  s.update = (fn: (current: T) => T) => {
    s.set(fn(value))
  }

  s.subscribe = (fn: (value: T) => void) => {
    const subscriber: Subscriber = () => fn(s())
    subscribers.add(subscriber)
    return () => subscribers.delete(subscriber)
  }

  return s
}

/**
 * Create a derived (computed) value from other signals.
 *
 * @example
 * const count = state(0)
 * const doubled = derived(() => count() * 2)
 * doubled() // 0
 * count.set(5)
 * doubled() // 10
 */
export function derived<T>(fn: () => T): Derived<T> {
  let cachedValue: T
  let dirty = true
  const subscribers = new Set<Subscriber>()

  const recompute: Subscriber = () => {
    dirty = true
    notify(subscribers)
  }

  const d = (() => {
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
  }) as Derived<T>

  d.subscribe = (callback: (value: T) => void) => {
    const subscriber: Subscriber = () => callback(d())
    subscribers.add(subscriber)
    return () => subscribers.delete(subscriber)
  }

  return d
}

/**
 * Run a side-effect whenever its signal dependencies change.
 * Returns a cleanup function.
 *
 * @example
 * const name = state('world')
 * effect(() => console.log(`Hello ${name()}`))
 * name.set('stx') // logs: Hello stx
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
 *
 * @example
 * batch(() => {
 *   count.set(1)
 *   name.set('stx')
 * }) // effects run once after both updates
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

// ============================================================================
// Lifecycle Hooks
// ============================================================================

type LifecycleHook = () => void | (() => void)

let mountHooks: LifecycleHook[] | null = null
let destroyHooks: LifecycleHook[] | null = null
let updateHooks: LifecycleHook[] | null = null

/** @internal Collect lifecycle hooks during component setup */
export function _collectLifecycleHooks(): {
  mount: LifecycleHook[]
  destroy: LifecycleHook[]
  update: LifecycleHook[]
} {
  mountHooks = []
  destroyHooks = []
  updateHooks = []
  return { mount: mountHooks, destroy: destroyHooks, update: updateHooks }
}

/** @internal Stop collecting lifecycle hooks */
export function _stopCollecting(): void {
  mountHooks = null
  destroyHooks = null
  updateHooks = null
}

/**
 * Register a callback to run when the component is mounted to the DOM.
 *
 * @example
 * onMount(() => {
 *   console.log('mounted!')
 *   return () => console.log('cleanup')
 * })
 */
export function onMount(fn: LifecycleHook): void {
  if (mountHooks) mountHooks.push(fn)
}

/**
 * Register a callback to run when the component is destroyed.
 *
 * @example
 * onDestroy(() => clearInterval(timer))
 */
export function onDestroy(fn: LifecycleHook): void {
  if (destroyHooks) destroyHooks.push(fn)
}

/**
 * Register a callback to run after each reactive update.
 *
 * @example
 * onUpdate(() => console.log('component updated'))
 */
export function onUpdate(fn: LifecycleHook): void {
  if (updateHooks) updateHooks.push(fn)
}

/**
 * Wait for the next DOM update tick.
 *
 * @example
 * count.set(5)
 * await nextTick()
 * // DOM is now updated
 */
export function nextTick(): Promise<void> {
  return new Promise(resolve => {
    requestAnimationFrame(() => resolve())
  })
}
