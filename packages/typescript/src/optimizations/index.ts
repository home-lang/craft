/**
 * Framework-Specific Optimizations
 *
 * Performance optimizations for React, Vue, and Svelte.
 * These utilities are framework-agnostic at the core level
 * and integrate with specific frameworks when available.
 */

// ============================================================================
// React Optimizations
// ============================================================================

/**
 * Configuration for React-specific optimizations
 */
export interface ReactOptimizationConfig {
  /** Enable React DevTools in development */
  enableDevTools?: boolean
  /** Enable React Profiler */
  enableProfiler?: boolean
  /** Enable strict mode warnings */
  strictMode?: boolean
  /** Enable concurrent features */
  concurrent?: boolean
  /** Lazy loading chunk size limit in KB */
  lazyChunkLimit?: number
  /** Enable automatic batching */
  autoBatching?: boolean
}

/**
 * React optimization utilities
 *
 * Note: These functions require React to be installed in your project.
 * They gracefully handle cases where React is not available.
 */
export const reactOptimizations = {
  /**
   * Configure React for production
   */
  configureProduction(config: ReactOptimizationConfig = {}): void {
    if (typeof window !== 'undefined') {
      // Disable React DevTools in production
      if (!config.enableDevTools) {
        (window as any).__REACT_DEVTOOLS_GLOBAL_HOOK__ = { isDisabled: true }
      }
    }
  },

  /**
   * Create a lazy component factory function
   * Returns a function that creates lazy components when React is available
   */
  createLazyFactory(): <T>(
    factory: () => Promise<{ default: T }>,
    options?: { preload?: boolean }
  ) => { load: () => Promise<void> } {
    return <T>(
      factory: () => Promise<{ default: T }>,
      options: { preload?: boolean } = {}
    ) => {
      let componentPromise: Promise<{ default: T }> | null = null

      const load = async () => {
        if (!componentPromise) {
          componentPromise = factory()
        }
        await componentPromise
      }

      // Auto-preload if enabled
      if (options.preload) {
        if (typeof requestIdleCallback !== 'undefined') {
          requestIdleCallback(() => load())
        } else {
          setTimeout(() => load(), 0)
        }
      }

      return { load }
    }
  },

  /**
   * Create a debounce hook factory
   */
  createDebouncedValueHook<T>(delay: number): (value: T) => T {
    let timeoutId: ReturnType<typeof setTimeout> | null = null
    let debouncedValue: T

    return (value: T): T => {
      if (timeoutId) {
        clearTimeout(timeoutId)
      }

      timeoutId = setTimeout(() => {
        debouncedValue = value
        timeoutId = null
      }, delay)

      return debouncedValue ?? value
    }
  },

  /**
   * Create a throttle function
   */
  createThrottle<T extends (...args: any[]) => any>(
    fn: T,
    delay: number
  ): T {
    let lastRan = 0

    return ((...args: Parameters<T>) => {
      const now = Date.now()
      if (now - lastRan >= delay) {
        fn(...args)
        lastRan = now
      }
    }) as T
  }
}

// ============================================================================
// Vue Optimizations
// ============================================================================

/**
 * Configuration for Vue-specific optimizations
 */
export interface VueOptimizationConfig {
  /** Enable Vue DevTools in development */
  enableDevTools?: boolean
  /** Enable performance tracing */
  performance?: boolean
  /** Custom error handler */
  errorHandler?: (err: Error, vm: any, info: string) => void
  /** Custom warn handler */
  warnHandler?: (msg: string, vm: any, trace: string) => void
}

/**
 * Vue optimization utilities
 *
 * Note: These functions require Vue to be installed in your project.
 */
export const vueOptimizations = {
  /**
   * Configure Vue app for production
   */
  configureProduction(app: any, config: VueOptimizationConfig = {}): void {
    if (!app?.config) return

    // Disable devtools in production
    if (!config.enableDevTools && app.config.devtools !== undefined) {
      app.config.devtools = false
    }

    // Enable performance tracing if configured
    if (app.config.performance !== undefined) {
      app.config.performance = config.performance || false
    }

    // Set custom error handler
    if (config.errorHandler) {
      app.config.errorHandler = config.errorHandler
    }

    // Set custom warn handler
    if (config.warnHandler) {
      app.config.warnHandler = config.warnHandler
    }
  },

  /**
   * Create an async component loader configuration
   */
  createAsyncConfig(options: {
    delay?: number
    timeout?: number
    retries?: number
  } = {}): {
    delay: number
    timeout: number
    onError: (error: Error, retry: () => void, fail: () => void, attempts: number) => void
  } {
    const { delay = 200, timeout = 30000, retries = 3 } = options

    return {
      delay,
      timeout,
      onError(error: Error, retry: () => void, fail: () => void, attempts: number) {
        if (attempts <= retries) {
          retry()
        } else {
          fail()
        }
      }
    }
  },

  /**
   * Create a cached computed factory
   */
  createCacheFactory<T>(options: { maxAge?: number } = {}): {
    cache: Map<string, { value: T; timestamp: number }>
    get: (key: string, getter: () => T) => T
    invalidate: (key?: string) => void
  } {
    const { maxAge = 0 } = options
    const cache = new Map<string, { value: T; timestamp: number }>()

    return {
      cache,
      get(key: string, getter: () => T): T {
        const now = Date.now()
        const cached = cache.get(key)

        if (cached && (maxAge === 0 || now - cached.timestamp < maxAge)) {
          return cached.value
        }

        const value = getter()
        cache.set(key, { value, timestamp: now })
        return value
      },
      invalidate(key?: string) {
        if (key) {
          cache.delete(key)
        } else {
          cache.clear()
        }
      }
    }
  }
}

// ============================================================================
// Svelte Optimizations
// ============================================================================

/**
 * Configuration for Svelte-specific optimizations
 */
export interface SvelteOptimizationConfig {
  /** Enable dev mode */
  dev?: boolean
  /** Enable CSS optimization */
  cssOptimization?: boolean
  /** Hydration strategy */
  hydration?: 'full' | 'partial' | 'none'
}

/**
 * Svelte optimization utilities
 *
 * Note: These functions require Svelte to be installed in your project.
 */
export const svelteOptimizations = {
  /**
   * Create a memoization wrapper for derived values
   */
  createMemoizer<T, U>(
    fn: (value: T) => U,
    isEqual?: (a: U, b: U) => boolean
  ): (value: T) => U {
    let lastInput: T | undefined
    let lastOutput: U | undefined

    return (value: T): U => {
      if (lastInput !== undefined && lastInput === value && lastOutput !== undefined) {
        return lastOutput
      }

      const newOutput = fn(value)

      if (lastOutput !== undefined && isEqual && isEqual(lastOutput, newOutput)) {
        return lastOutput
      }

      lastInput = value
      lastOutput = newOutput
      return newOutput
    }
  },

  /**
   * Create a debounced setter
   */
  createDebouncedSetter<T>(delay: number = 300): {
    set: (value: T, callback: (value: T) => void) => void
    cancel: () => void
  } {
    let timeout: ReturnType<typeof setTimeout> | undefined

    return {
      set(value: T, callback: (value: T) => void) {
        if (timeout) {
          clearTimeout(timeout)
        }
        timeout = setTimeout(() => {
          callback(value)
          timeout = undefined
        }, delay)
      },
      cancel() {
        if (timeout) {
          clearTimeout(timeout)
          timeout = undefined
        }
      }
    }
  },

  /**
   * Create a throttled setter
   */
  createThrottledSetter<T>(delay: number = 100): {
    set: (value: T, callback: (value: T) => void) => void
  } {
    let lastRan = 0
    let pending: { value: T; callback: (value: T) => void } | undefined
    let timeout: ReturnType<typeof setTimeout> | undefined

    return {
      set(value: T, callback: (value: T) => void) {
        const now = Date.now()

        if (now - lastRan >= delay) {
          callback(value)
          lastRan = now
        } else {
          pending = { value, callback }

          if (!timeout) {
            timeout = setTimeout(() => {
              if (pending) {
                pending.callback(pending.value)
                pending = undefined
              }
              lastRan = Date.now()
              timeout = undefined
            }, delay - (now - lastRan))
          }
        }
      }
    }
  },

  /**
   * Create an intersection observer action config
   */
  createLazyActionConfig(options: {
    threshold?: number
    rootMargin?: string
  } = {}): IntersectionObserverInit {
    return {
      threshold: options.threshold ?? 0,
      rootMargin: options.rootMargin ?? '50px'
    }
  },

  /**
   * Create transition configuration with hardware acceleration hints
   */
  createAcceleratedTransitionConfig(
    type: 'fade' | 'slide' | 'scale',
    options: { duration?: number; easing?: string } = {}
  ): {
    type: string
    duration: number
    easing: string
    willChange: string
  } {
    const { duration = 300, easing = 'cubic-bezier(0.4, 0, 0.2, 1)' } = options

    const willChangeMap = {
      fade: 'opacity',
      slide: 'transform, opacity',
      scale: 'transform, opacity'
    }

    return {
      type,
      duration,
      easing,
      willChange: willChangeMap[type]
    }
  }
}

// ============================================================================
// Common Optimizations
// ============================================================================

/**
 * Common optimization utilities for all frameworks
 */
export const commonOptimizations = {
  /**
   * Defer non-critical JavaScript execution
   */
  defer(fn: () => void): void {
    if (typeof requestIdleCallback !== 'undefined') {
      requestIdleCallback(fn)
    } else {
      setTimeout(fn, 0)
    }
  },

  /**
   * Preload critical resources
   */
  preload(urls: string[], type: 'script' | 'style' | 'image' | 'font'): void {
    if (typeof document === 'undefined') return

    urls.forEach((url) => {
      const link = document.createElement('link')
      link.rel = 'preload'
      link.href = url
      link.as = type

      if (type === 'font') {
        link.crossOrigin = 'anonymous'
      }

      document.head.appendChild(link)
    })
  },

  /**
   * Prefetch resources for future navigation
   */
  prefetch(urls: string[]): void {
    if (typeof document === 'undefined') return

    urls.forEach((url) => {
      const link = document.createElement('link')
      link.rel = 'prefetch'
      link.href = url
      document.head.appendChild(link)
    })
  },

  /**
   * Create an intersection observer for lazy loading
   */
  createLazyLoader(
    callback: (entry: IntersectionObserverEntry) => void,
    options: IntersectionObserverInit = {}
  ): IntersectionObserver | null {
    if (typeof IntersectionObserver === 'undefined') {
      return null
    }

    return new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          callback(entry)
        }
      })
    }, {
      rootMargin: '50px',
      threshold: 0,
      ...options
    })
  },

  /**
   * Measure component render time
   */
  measureRender(name: string): { start: () => void; end: () => void } {
    let startTime: number

    return {
      start() {
        if (typeof performance !== 'undefined') {
          startTime = performance.now()
          performance.mark(`${name}-start`)
        }
      },
      end() {
        if (typeof performance !== 'undefined' && startTime) {
          const endTime = performance.now()
          performance.mark(`${name}-end`)
          performance.measure(name, `${name}-start`, `${name}-end`)

          if (typeof process !== 'undefined' && process.env?.NODE_ENV === 'development') {
            console.log(`[Craft] ${name} rendered in ${(endTime - startTime).toFixed(2)}ms`)
          }
        }
      }
    }
  },

  /**
   * Create a memoized function
   */
  memoize<T extends (...args: any[]) => any>(
    fn: T,
    options: {
      maxSize?: number
      ttl?: number
    } = {}
  ): T {
    const { maxSize = 100, ttl = 0 } = options

    const cache = new Map<string, { value: ReturnType<T>; timestamp: number }>()
    const keys: string[] = []

    return ((...args: Parameters<T>) => {
      const key = JSON.stringify(args)
      const now = Date.now()

      const cached = cache.get(key)
      if (cached) {
        if (ttl === 0 || now - cached.timestamp < ttl) {
          return cached.value
        }
        cache.delete(key)
        keys.splice(keys.indexOf(key), 1)
      }

      const value = fn(...args)

      cache.set(key, { value, timestamp: now })
      keys.push(key)

      // Evict oldest entries if over max size
      while (keys.length > maxSize) {
        const oldKey = keys.shift()!
        cache.delete(oldKey)
      }

      return value
    }) as T
  },

  /**
   * Batch DOM updates using requestAnimationFrame
   */
  batchDOMUpdates(updates: Array<() => void>): void {
    if (typeof requestAnimationFrame !== 'undefined') {
      requestAnimationFrame(() => {
        updates.forEach((update) => update())
      })
    } else {
      updates.forEach((update) => update())
    }
  },

  /**
   * Create a debounce function
   */
  debounce<T extends (...args: any[]) => any>(
    fn: T,
    delay: number
  ): T & { cancel: () => void } {
    let timeoutId: ReturnType<typeof setTimeout> | undefined

    const debounced = ((...args: Parameters<T>) => {
      if (timeoutId) {
        clearTimeout(timeoutId)
      }
      timeoutId = setTimeout(() => {
        fn(...args)
        timeoutId = undefined
      }, delay)
    }) as T & { cancel: () => void }

    debounced.cancel = () => {
      if (timeoutId) {
        clearTimeout(timeoutId)
        timeoutId = undefined
      }
    }

    return debounced
  },

  /**
   * Create a throttle function
   */
  throttle<T extends (...args: any[]) => any>(
    fn: T,
    delay: number
  ): T {
    let lastRan = 0

    return ((...args: Parameters<T>) => {
      const now = Date.now()
      if (now - lastRan >= delay) {
        fn(...args)
        lastRan = now
      }
    }) as T
  },

  /**
   * Detect if running in a low-power mode or reduced motion preference
   */
  detectReducedMotion(): boolean {
    if (typeof window === 'undefined') return false
    return window.matchMedia('(prefers-reduced-motion: reduce)').matches
  },

  /**
   * Detect if running on a low-end device
   */
  detectLowEndDevice(): boolean {
    if (typeof navigator === 'undefined') return false

    // Check for limited memory (< 4GB)
    const memory = (navigator as any).deviceMemory
    if (memory && memory < 4) return true

    // Check for limited CPU cores (< 4)
    const cores = navigator.hardwareConcurrency
    if (cores && cores < 4) return true

    // Check for save-data header preference
    const connection = (navigator as any).connection
    if (connection?.saveData) return true

    return false
  },

  /**
   * Create an adaptive quality level based on device capabilities
   */
  getAdaptiveQuality(): 'low' | 'medium' | 'high' {
    const isLowEnd = commonOptimizations.detectLowEndDevice()
    const prefersReducedMotion = commonOptimizations.detectReducedMotion()

    if (isLowEnd || prefersReducedMotion) return 'low'

    // Check for high refresh rate display
    if (typeof window !== 'undefined') {
      const dpr = window.devicePixelRatio || 1
      if (dpr >= 2) return 'high'
    }

    return 'medium'
  }
}
