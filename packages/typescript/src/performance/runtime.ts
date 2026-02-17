/**
 * Craft Runtime Performance
 * GPU acceleration, memory optimization, and animation performance
 */

// Types
export interface GPUCapabilities {
  vendor: string
  renderer: string
  webglVersion: number
  maxTextureSize: number
  maxViewportDims: [number, number]
  supportedExtensions: string[]
  hardwareAccelerated: boolean
}

export interface MemoryInfo {
  usedJSHeapSize: number
  totalJSHeapSize: number
  jsHeapSizeLimit: number
  usedPercentage: number
}

export interface AnimationMetrics {
  fps: number
  frameTime: number
  droppedFrames: number
  jank: number
}

export interface ObjectPool<T> {
  acquire(): T
  release(obj: T): void
  size(): number
  available(): number
}

// GPU Acceleration
export class GPUAccelerator {
  private gl: WebGLRenderingContext | WebGL2RenderingContext | null = null
  private capabilities: GPUCapabilities | null = null

  /**
   * Initialize GPU context
   */
  async initialize(): Promise<GPUCapabilities> {
    if (this.capabilities) return this.capabilities

    const canvas = document.createElement('canvas')
    this.gl = canvas.getContext('webgl2') || canvas.getContext('webgl')

    if (!this.gl) {
      throw new Error('WebGL not supported')
    }

    const debugInfo = this.gl.getExtension('WEBGL_debug_renderer_info')
    const vendor = debugInfo ? this.gl.getParameter(debugInfo.UNMASKED_VENDOR_WEBGL) : 'Unknown'
    const renderer = debugInfo ? this.gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL) : 'Unknown'

    this.capabilities = {
      vendor,
      renderer,
      webglVersion: this.gl instanceof WebGL2RenderingContext ? 2 : 1,
      maxTextureSize: this.gl.getParameter(this.gl.MAX_TEXTURE_SIZE),
      maxViewportDims: this.gl.getParameter(this.gl.MAX_VIEWPORT_DIMS),
      supportedExtensions: this.gl.getSupportedExtensions() || [],
      hardwareAccelerated: !renderer.toLowerCase().includes('swiftshader') && !renderer.toLowerCase().includes('llvmpipe'),
    }

    return this.capabilities
  }

  /**
   * Get GPU capabilities
   */
  getCapabilities(): GPUCapabilities | null {
    return this.capabilities
  }

  /**
   * Check if GPU is hardware accelerated
   */
  isHardwareAccelerated(): boolean {
    return this.capabilities?.hardwareAccelerated ?? false
  }

  /**
   * Check WebGL extension support
   */
  supportsExtension(name: string): boolean {
    return this.capabilities?.supportedExtensions.includes(name) ?? false
  }

  /**
   * Apply GPU-accelerated transform
   */
  applyGPUTransform(element: HTMLElement, transform: { translateX?: number; translateY?: number; translateZ?: number; rotateX?: number; rotateY?: number; rotateZ?: number; scale?: number; scaleX?: number; scaleY?: number }): void {
    const transforms: string[] = []

    if (transform.translateX !== undefined || transform.translateY !== undefined || transform.translateZ !== undefined) {
      transforms.push(`translate3d(${transform.translateX ?? 0}px, ${transform.translateY ?? 0}px, ${transform.translateZ ?? 0}px)`)
    }

    if (transform.rotateX !== undefined) transforms.push(`rotateX(${transform.rotateX}deg)`)
    if (transform.rotateY !== undefined) transforms.push(`rotateY(${transform.rotateY}deg)`)
    if (transform.rotateZ !== undefined) transforms.push(`rotateZ(${transform.rotateZ}deg)`)

    if (transform.scale !== undefined) {
      transforms.push(`scale3d(${transform.scale}, ${transform.scale}, 1)`)
    } else if (transform.scaleX !== undefined || transform.scaleY !== undefined) {
      transforms.push(`scale3d(${transform.scaleX ?? 1}, ${transform.scaleY ?? 1}, 1)`)
    }

    element.style.transform = transforms.join(' ')
    element.style.willChange = 'transform'
  }

  /**
   * Enable GPU compositing for element
   */
  enableCompositing(element: HTMLElement): void {
    element.style.transform = 'translateZ(0)'
    element.style.willChange = 'transform'
    element.style.backfaceVisibility = 'hidden'
  }

  /**
   * Disable GPU compositing for element
   */
  disableCompositing(element: HTMLElement): void {
    element.style.transform = ''
    element.style.willChange = 'auto'
    element.style.backfaceVisibility = ''
  }
}

// Memory Optimizer
export class MemoryOptimizer {
  private pools = new Map<string, ObjectPoolImpl<unknown>>()
  private pressureCallbacks: Array<(level: 'none' | 'moderate' | 'critical') => void> = []

  constructor() {
    this.setupMemoryPressureListener()
  }

  /**
   * Get current memory info
   */
  getMemoryInfo(): MemoryInfo | null {
    const memory = (performance as any).memory
    if (!memory) return null

    return {
      usedJSHeapSize: memory.usedJSHeapSize,
      totalJSHeapSize: memory.totalJSHeapSize,
      jsHeapSizeLimit: memory.jsHeapSizeLimit,
      usedPercentage: (memory.usedJSHeapSize / memory.jsHeapSizeLimit) * 100,
    }
  }

  /**
   * Create object pool
   */
  createPool<T>(name: string, factory: () => T, reset?: (obj: T) => void, initialSize = 10): ObjectPool<T> {
    const pool = new ObjectPoolImpl<T>(factory, reset, initialSize)
    this.pools.set(name, pool as ObjectPoolImpl<unknown>)
    return pool
  }

  /**
   * Get existing pool
   */
  getPool<T>(name: string): ObjectPool<T> | undefined {
    return this.pools.get(name) as ObjectPool<T> | undefined
  }

  /**
   * Create LRU cache
   */
  createLRUCache<K, V>(maxSize: number): LRUCache<K, V> {
    return new LRUCache<K, V>(maxSize)
  }

  /**
   * Register memory pressure callback
   */
  onMemoryPressure(callback: (level: 'none' | 'moderate' | 'critical') => void): () => void {
    this.pressureCallbacks.push(callback)
    return () => {
      const index = this.pressureCallbacks.indexOf(callback)
      if (index > -1) this.pressureCallbacks.splice(index, 1)
    }
  }

  /**
   * Force garbage collection hint
   */
  requestGC(): void {
    // Clear pools' available objects
    for (const pool of this.pools.values()) {
      pool.trim()
    }

    // Hint to GC (if available)
    if (typeof (window as any).gc === 'function') {
      ;(window as any).gc()
    }
  }

  private setupMemoryPressureListener(): void {
    // Check memory periodically
    setInterval(() => {
      const info = this.getMemoryInfo()
      if (!info) return

      let level: 'none' | 'moderate' | 'critical' = 'none'
      if (info.usedPercentage > 90) {
        level = 'critical'
      } else if (info.usedPercentage > 70) {
        level = 'moderate'
      }

      if (level !== 'none') {
        for (const callback of this.pressureCallbacks) {
          callback(level)
        }
      }
    }, 10000)
  }
}

// Object Pool Implementation
class ObjectPoolImpl<T> implements ObjectPool<T> {
  private _available: T[] = []
  private inUse = new Set<T>()

  constructor(
    private factory: () => T,
    private reset?: (obj: T) => void,
    initialSize = 0
  ) {
    for (let i = 0; i < initialSize; i++) {
      this._available.push(this.factory())
    }
  }

  acquire(): T {
    let obj: T
    if (this._available.length > 0) {
      obj = this._available.pop()!
    } else {
      obj = this.factory()
    }
    this.inUse.add(obj)
    return obj
  }

  release(obj: T): void {
    if (!this.inUse.has(obj)) return
    this.inUse.delete(obj)
    if (this.reset) this.reset(obj)
    this._available.push(obj)
  }

  size(): number {
    return this._available.length + this.inUse.size
  }

  available(): number {
    return this._available.length
  }

  trim(): void {
    // Keep only half of available objects
    const keep = Math.floor(this._available.length / 2)
    this._available.length = keep
  }
}

// LRU Cache
export class LRUCache<K, V> {
  private cache = new Map<K, V>()
  private maxSize: number

  constructor(maxSize: number) {
    this.maxSize = maxSize
  }

  get(key: K): V | undefined {
    if (!this.cache.has(key)) return undefined

    // Move to end (most recently used)
    const value = this.cache.get(key)!
    this.cache.delete(key)
    this.cache.set(key, value)
    return value
  }

  set(key: K, value: V): void {
    if (this.cache.has(key)) {
      this.cache.delete(key)
    } else if (this.cache.size >= this.maxSize) {
      // Remove least recently used (first item)
      const firstKey = this.cache.keys().next().value
      if (firstKey !== undefined) {
        this.cache.delete(firstKey)
      }
    }
    this.cache.set(key, value)
  }

  has(key: K): boolean {
    return this.cache.has(key)
  }

  delete(key: K): boolean {
    return this.cache.delete(key)
  }

  clear(): void {
    this.cache.clear()
  }

  size(): number {
    return this.cache.size
  }
}

// Animation Performance Monitor
export class AnimationMonitor {
  private frameCount = 0
  private lastFrameTime = 0
  private frameTimes: number[] = []
  private droppedFrames = 0
  private rafId: number | null = null
  private callbacks: Array<(metrics: AnimationMetrics) => void> = []
  private running = false

  /**
   * Start monitoring
   */
  start(): void {
    if (this.running) return
    this.running = true
    this.lastFrameTime = performance.now()
    this.tick()
  }

  /**
   * Stop monitoring
   */
  stop(): void {
    this.running = false
    if (this.rafId !== null) {
      cancelAnimationFrame(this.rafId)
      this.rafId = null
    }
  }

  /**
   * Get current metrics
   */
  getMetrics(): AnimationMetrics {
    const avgFrameTime = this.frameTimes.length > 0 ? this.frameTimes.reduce((a, b) => a + b, 0) / this.frameTimes.length : 16.67

    const fps = 1000 / avgFrameTime

    // Calculate jank (variance in frame times)
    let jank = 0
    if (this.frameTimes.length > 1) {
      const mean = avgFrameTime
      const variance = this.frameTimes.reduce((sum, t) => sum + Math.pow(t - mean, 2), 0) / this.frameTimes.length
      jank = Math.sqrt(variance)
    }

    return {
      fps: Math.round(fps * 10) / 10,
      frameTime: Math.round(avgFrameTime * 100) / 100,
      droppedFrames: this.droppedFrames,
      jank: Math.round(jank * 100) / 100,
    }
  }

  /**
   * Register metrics callback
   */
  onMetrics(callback: (metrics: AnimationMetrics) => void): () => void {
    this.callbacks.push(callback)
    return () => {
      const index = this.callbacks.indexOf(callback)
      if (index > -1) this.callbacks.splice(index, 1)
    }
  }

  /**
   * Reset metrics
   */
  reset(): void {
    this.frameCount = 0
    this.frameTimes = []
    this.droppedFrames = 0
  }

  private tick(): void {
    if (!this.running) return

    const now = performance.now()
    const frameTime = now - this.lastFrameTime

    this.frameTimes.push(frameTime)
    if (this.frameTimes.length > 60) {
      this.frameTimes.shift()
    }

    // Detect dropped frames (> 50ms = dropped at 60fps)
    if (frameTime > 50) {
      this.droppedFrames++
    }

    this.frameCount++
    this.lastFrameTime = now

    // Report every 60 frames
    if (this.frameCount % 60 === 0) {
      const metrics = this.getMetrics()
      for (const callback of this.callbacks) {
        callback(metrics)
      }
    }

    this.rafId = requestAnimationFrame(() => this.tick())
  }
}

// Animation Frame Scheduler
export class FrameScheduler {
  private tasks: Array<{ callback: () => void; priority: number }> = []
  private rafId: number | null = null
  private running = false
  private frameDeadline = 16 // Target 60fps

  /**
   * Schedule a task for next frame
   */
  schedule(callback: () => void, priority: 'high' | 'normal' | 'low' = 'normal'): void {
    const priorityValue = priority === 'high' ? 0 : priority === 'normal' ? 1 : 2
    this.tasks.push({ callback, priority: priorityValue })
    this.tasks.sort((a, b) => a.priority - b.priority)

    if (!this.running) {
      this.start()
    }
  }

  /**
   * Start scheduler
   */
  start(): void {
    if (this.running) return
    this.running = true
    this.processFrame()
  }

  /**
   * Stop scheduler
   */
  stop(): void {
    this.running = false
    if (this.rafId !== null) {
      cancelAnimationFrame(this.rafId)
      this.rafId = null
    }
  }

  /**
   * Clear all pending tasks
   */
  clear(): void {
    this.tasks = []
  }

  private processFrame(): void {
    if (!this.running) return

    const frameStart = performance.now()

    while (this.tasks.length > 0) {
      const elapsed = performance.now() - frameStart
      if (elapsed >= this.frameDeadline) break

      const task = this.tasks.shift()
      if (task) {
        try {
          task.callback()
        } catch (error) {
          console.error('Frame task error:', error)
        }
      }
    }

    if (this.tasks.length > 0 || this.running) {
      this.rafId = requestAnimationFrame(() => this.processFrame())
    }
  }
}

// GPU-Accelerated Transitions
export class GPUTransition {
  /**
   * Create a GPU-accelerated transition
   */
  static create(
    element: HTMLElement,
    properties: {
      from: Record<string, string | number>
      to: Record<string, string | number>
      duration: number
      easing?: string
      delay?: number
    }
  ): Promise<void> {
    return new Promise((resolve) => {
      // Apply initial state
      Object.assign(element.style, properties.from)

      // Force reflow
      element.offsetHeight

      // Setup transition
      element.style.transition = `all ${properties.duration}ms ${properties.easing || 'ease'} ${properties.delay || 0}ms`
      element.style.willChange = Object.keys(properties.to).join(', ')

      // Apply final state
      requestAnimationFrame(() => {
        Object.assign(element.style, properties.to)
      })

      // Cleanup after transition
      const cleanup = () => {
        element.style.transition = ''
        element.style.willChange = ''
        element.removeEventListener('transitionend', cleanup)
        resolve()
      }

      element.addEventListener('transitionend', cleanup, { once: true })

      // Fallback timeout
      setTimeout(cleanup, properties.duration + (properties.delay || 0) + 100)
    })
  }

  /**
   * Animate transform with GPU acceleration
   */
  static async transform(
    element: HTMLElement,
    keyframes: Array<{
      transform?: string
      opacity?: number
      offset?: number
    }>,
    options: {
      duration: number
      easing?: string
      fill?: 'none' | 'forwards' | 'backwards' | 'both'
    }
  ): Promise<void> {
    // Enable GPU compositing
    element.style.willChange = 'transform, opacity'

    const animation = element.animate(keyframes, {
      duration: options.duration,
      easing: options.easing || 'ease',
      fill: options.fill || 'forwards',
    })

    await animation.finished

    // Cleanup
    element.style.willChange = ''
  }
}

// Reduce Motion Support
export class ReduceMotion {
  private static mediaQuery = typeof window !== 'undefined' ? window.matchMedia('(prefers-reduced-motion: reduce)') : null

  /**
   * Check if reduced motion is preferred
   */
  static isEnabled(): boolean {
    return this.mediaQuery?.matches ?? false
  }

  /**
   * Listen for changes
   */
  static onChange(callback: (enabled: boolean) => void): () => void {
    if (!this.mediaQuery) return () => {}

    const handler = (e: MediaQueryListEvent) => callback(e.matches)
    this.mediaQuery.addEventListener('change', handler)
    return () => this.mediaQuery?.removeEventListener('change', handler)
  }

  /**
   * Get appropriate duration based on preference
   */
  static getDuration(normalDuration: number, reducedDuration = 0): number {
    return this.isEnabled() ? reducedDuration : normalDuration
  }

  /**
   * Apply motion-safe animation
   */
  static animate(element: HTMLElement, keyframes: Keyframe[], options: KeyframeAnimationOptions): Animation | null {
    if (this.isEnabled()) {
      // Apply final state immediately
      if (keyframes.length > 0) {
        const finalFrame = keyframes[keyframes.length - 1]
        Object.assign(element.style, finalFrame)
      }
      return null
    }

    return element.animate(keyframes, options)
  }
}

// Global instances
let gpuAccelerator: GPUAccelerator | null = null
let memoryOptimizer: MemoryOptimizer | null = null
let animationMonitor: AnimationMonitor | null = null
let frameScheduler: FrameScheduler | null = null

export function getGPUAccelerator(): GPUAccelerator {
  if (!gpuAccelerator) {
    gpuAccelerator = new GPUAccelerator()
  }
  return gpuAccelerator
}

export function getMemoryOptimizer(): MemoryOptimizer {
  if (!memoryOptimizer) {
    memoryOptimizer = new MemoryOptimizer()
  }
  return memoryOptimizer
}

export function getAnimationMonitor(): AnimationMonitor {
  if (!animationMonitor) {
    animationMonitor = new AnimationMonitor()
  }
  return animationMonitor
}

export function getFrameScheduler(): FrameScheduler {
  if (!frameScheduler) {
    frameScheduler = new FrameScheduler()
  }
  return frameScheduler
}

const _exports: {
  GPUAccelerator: typeof GPUAccelerator;
  MemoryOptimizer: typeof MemoryOptimizer;
  LRUCache: typeof LRUCache;
  AnimationMonitor: typeof AnimationMonitor;
  FrameScheduler: typeof FrameScheduler;
  GPUTransition: typeof GPUTransition;
  ReduceMotion: typeof ReduceMotion;
  getGPUAccelerator: typeof getGPUAccelerator;
  getMemoryOptimizer: typeof getMemoryOptimizer;
  getAnimationMonitor: typeof getAnimationMonitor;
  getFrameScheduler: typeof getFrameScheduler;
} = {
  GPUAccelerator,
  MemoryOptimizer,
  LRUCache,
  AnimationMonitor,
  FrameScheduler,
  GPUTransition,
  ReduceMotion,
  getGPUAccelerator,
  getMemoryOptimizer,
  getAnimationMonitor,
  getFrameScheduler,
};
export default _exports;
