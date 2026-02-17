/**
 * Craft Startup Performance
 * Lazy loading, precompilation, and cold start optimization
 */

// Types
export interface LazyModule<T> {
  load(): Promise<T>
  isLoaded(): boolean
  preload(): void
}

export interface PrecompiledAsset {
  path: string
  hash: string
  type: 'html' | 'css' | 'js' | 'json'
  compressed?: boolean
  size: number
}

export interface StartupMetrics {
  coldStartTime: number
  timeToFirstByte: number
  timeToFirstPaint: number
  timeToInteractive: number
  modulesLoaded: number
  totalModuleSize: number
  cacheHits: number
  cacheMisses: number
}

// Lazy Module Loader
export class LazyLoader<T> implements LazyModule<T> {
  private module: T | null = null
  private loading: Promise<T> | null = null
  private preloading = false

  constructor(
    private factory: () => Promise<T>,
    private options?: {
      preloadDelay?: number
      onLoad?: (module: T) => void
      onError?: (error: Error) => void
    }
  ) {}

  async load(): Promise<T> {
    if (this.module) return this.module

    if (this.loading) return this.loading

    this.loading = this.factory()
      .then((mod) => {
        this.module = mod
        this.loading = null
        this.options?.onLoad?.(mod)
        return mod
      })
      .catch((error) => {
        this.loading = null
        this.options?.onError?.(error)
        throw error
      })

    return this.loading
  }

  isLoaded(): boolean {
    return this.module !== null
  }

  preload(): void {
    if (this.preloading || this.module) return
    this.preloading = true

    const delay = this.options?.preloadDelay ?? 100
    setTimeout(() => {
      if (!this.module && !this.loading) {
        this.load().catch(() => {})
      }
    }, delay)
  }
}

// Module Registry for lazy loading
export class ModuleRegistry {
  private modules = new Map<string, LazyLoader<unknown>>()
  private loadOrder: string[] = []
  private metrics: Map<string, { loadTime: number; size: number }> = new Map()

  /**
   * Register a lazy module
   */
  register<T>(name: string, factory: () => Promise<T>, options?: { priority?: number; preload?: boolean }): void {
    const loader = new LazyLoader(factory, {
      onLoad: () => {
        this.loadOrder.push(name)
      },
    })

    this.modules.set(name, loader as LazyLoader<unknown>)

    if (options?.preload) {
      loader.preload()
    }
  }

  /**
   * Get a module (lazy loads if needed)
   */
  async get<T>(name: string): Promise<T> {
    const loader = this.modules.get(name)
    if (!loader) {
      throw new Error(`Module '${name}' not registered`)
    }

    const startTime = performance.now()
    const result = await loader.load()
    const loadTime = performance.now() - startTime

    this.metrics.set(name, {
      loadTime,
      size: this.estimateSize(result),
    })

    return result as T
  }

  /**
   * Preload modules by priority
   */
  preloadByPriority(priorities: string[]): void {
    for (const name of priorities) {
      const loader = this.modules.get(name)
      if (loader) {
        loader.preload()
      }
    }
  }

  /**
   * Get load metrics
   */
  getMetrics(): Map<string, { loadTime: number; size: number }> {
    return new Map(this.metrics)
  }

  /**
   * Get load order
   */
  getLoadOrder(): string[] {
    return [...this.loadOrder]
  }

  private estimateSize(obj: unknown): number {
    try {
      return JSON.stringify(obj).length
    } catch {
      return 0
    }
  }
}

// Asset Precompiler
export class AssetPrecompiler {
  private cache = new Map<string, PrecompiledAsset>()
  private cacheDir: string

  constructor(cacheDir = '.craft/cache') {
    this.cacheDir = cacheDir
  }

  /**
   * Precompile HTML template
   */
  precompileHTML(html: string, options?: { minify?: boolean; inlineCSS?: boolean; inlineJS?: boolean }): string {
    let result = html

    if (options?.minify) {
      result = this.minifyHTML(result)
    }

    return result
  }

  /**
   * Precompile CSS
   */
  precompileCSS(css: string, options?: { minify?: boolean; prefix?: string }): string {
    let result = css

    if (options?.prefix) {
      result = this.prefixCSS(result, options.prefix)
    }

    if (options?.minify) {
      result = this.minifyCSS(result)
    }

    return result
  }

  /**
   * Precompile JavaScript
   */
  precompileJS(js: string, options?: { minify?: boolean; target?: 'es5' | 'es6' | 'esnext' }): string {
    let result = js

    if (options?.minify) {
      result = this.minifyJS(result)
    }

    return result
  }

  /**
   * Generate precompiled asset manifest
   */
  generateManifest(assets: PrecompiledAsset[]): string {
    return JSON.stringify(
      {
        version: '1.0',
        generated: new Date().toISOString(),
        assets: assets.map((a) => ({
          path: a.path,
          hash: a.hash,
          type: a.type,
          compressed: a.compressed,
          size: a.size,
        })),
      },
      null,
      2
    )
  }

  private minifyHTML(html: string): string {
    return html
      .replace(/\s+/g, ' ')
      .replace(/>\s+</g, '><')
      .replace(/<!--.*?-->/g, '')
      .trim()
  }

  private minifyCSS(css: string): string {
    return css
      .replace(/\/\*[\s\S]*?\*\//g, '')
      .replace(/\s+/g, ' ')
      .replace(/\s*([{}:;,])\s*/g, '$1')
      .replace(/;}/g, '}')
      .trim()
  }

  private minifyJS(js: string): string {
    // Basic minification - in production use a proper minifier
    return js
      .replace(/\/\/.*$/gm, '')
      .replace(/\/\*[\s\S]*?\*\//g, '')
      .replace(/\s+/g, ' ')
      .trim()
  }

  private prefixCSS(css: string, prefix: string): string {
    // Add vendor prefix to CSS properties that need it
    const prefixedProperties = ['transform', 'transition', 'animation', 'flex', 'grid']

    for (const prop of prefixedProperties) {
      const regex = new RegExp(`(${prop}\\s*:)`, 'g')
      css = css.replace(regex, `${prefix}$1`)
    }

    return css
  }
}

// Cold Start Optimizer
export class ColdStartOptimizer {
  private startTime: number
  private marks = new Map<string, number>()
  private measures: Array<{ name: string; start: string; end: string; duration: number }> = []

  constructor() {
    this.startTime = performance.now()
    this.mark('app-init')
  }

  /**
   * Mark a point in startup
   */
  mark(name: string): void {
    this.marks.set(name, performance.now())
  }

  /**
   * Measure between two marks
   */
  measure(name: string, startMark: string, endMark: string): number {
    const start = this.marks.get(startMark)
    const end = this.marks.get(endMark)

    if (start === undefined || end === undefined) {
      return -1
    }

    const duration = end - start
    this.measures.push({ name, start: startMark, end: endMark, duration })
    return duration
  }

  /**
   * Get time since start
   */
  timeSinceStart(): number {
    return performance.now() - this.startTime
  }

  /**
   * Get startup metrics
   */
  getMetrics(): StartupMetrics {
    const tfb = this.marks.get('first-byte') ?? 0
    const tfp = this.marks.get('first-paint') ?? 0
    const tti = this.marks.get('interactive') ?? 0

    return {
      coldStartTime: this.timeSinceStart(),
      timeToFirstByte: tfb - this.startTime,
      timeToFirstPaint: tfp - this.startTime,
      timeToInteractive: tti - this.startTime,
      modulesLoaded: 0,
      totalModuleSize: 0,
      cacheHits: 0,
      cacheMisses: 0,
    }
  }

  /**
   * Get all measures
   */
  getMeasures(): Array<{ name: string; start: string; end: string; duration: number }> {
    return [...this.measures]
  }

  /**
   * Report metrics
   */
  report(): string {
    const metrics = this.getMetrics()
    const measures = this.getMeasures()

    let report = '=== Startup Performance Report ===\n\n'
    report += `Cold Start Time: ${metrics.coldStartTime.toFixed(2)}ms\n`
    report += `Time to First Byte: ${metrics.timeToFirstByte.toFixed(2)}ms\n`
    report += `Time to First Paint: ${metrics.timeToFirstPaint.toFixed(2)}ms\n`
    report += `Time to Interactive: ${metrics.timeToInteractive.toFixed(2)}ms\n\n`

    if (measures.length > 0) {
      report += 'Measures:\n'
      for (const m of measures) {
        report += `  ${m.name}: ${m.duration.toFixed(2)}ms (${m.start} → ${m.end})\n`
      }
    }

    return report
  }
}

// Binary Size Reducer
export class BinarySizeReducer {
  /**
   * Analyze bundle for tree shaking opportunities
   */
  analyzeTreeShaking(code: string): {
    unusedExports: string[]
    unusedImports: string[]
    suggestions: string[]
  } {
    const unusedExports: string[] = []
    const unusedImports: string[] = []
    const suggestions: string[] = []

    // Find all exports
    const exportMatches = code.matchAll(/export\s+(?:const|let|var|function|class)\s+(\w+)/g)
    const exports = [...exportMatches].map((m) => m[1])

    // Find all imports
    const importMatches = code.matchAll(/import\s+\{([^}]+)\}\s+from/g)
    const imports = [...importMatches].flatMap((m) =>
      m[1]
        .split(',')
        .map((i) => i.trim().split(' as ')[0])
        .filter(Boolean)
    )

    // Check for unused exports (simplified check)
    for (const exp of exports) {
      const regex = new RegExp(`\\b${exp}\\b`, 'g')
      const matches = code.match(regex)
      if (matches && matches.length <= 2) {
        // Only definition + export
        unusedExports.push(exp)
      }
    }

    if (unusedExports.length > 0) {
      suggestions.push(`Consider removing unused exports: ${unusedExports.join(', ')}`)
    }

    // Check for large dependencies
    const largeDepPatterns = ['lodash', 'moment', 'rxjs']
    for (const dep of largeDepPatterns) {
      if (code.includes(`from '${dep}'`) || code.includes(`from "${dep}"`)) {
        suggestions.push(`Consider using tree-shakeable alternative to '${dep}'`)
      }
    }

    return { unusedExports, unusedImports, suggestions }
  }

  /**
   * Get dead code elimination suggestions
   */
  getDeadCodeSuggestions(code: string): string[] {
    const suggestions: string[] = []

    // Check for console.log in production
    if (code.includes('console.log')) {
      suggestions.push('Remove console.log statements for production')
    }

    // Check for debugger statements
    if (code.includes('debugger')) {
      suggestions.push('Remove debugger statements')
    }

    // Check for development-only code
    if (code.includes('process.env.NODE_ENV')) {
      suggestions.push('Ensure development-only code is stripped in production builds')
    }

    return suggestions
  }
}

// Startup Cache
export class StartupCache {
  private cache: Map<string, { data: unknown; timestamp: number; size: number }> = new Map()
  private maxSize: number
  private currentSize = 0
  private hits = 0
  private misses = 0

  constructor(maxSizeBytes: number = 50 * 1024 * 1024) {
    // 50MB default
    this.maxSize = maxSizeBytes
  }

  /**
   * Get item from cache
   */
  get<T>(key: string): T | undefined {
    const item = this.cache.get(key)
    if (item) {
      this.hits++
      return item.data as T
    }
    this.misses++
    return undefined
  }

  /**
   * Set item in cache
   */
  set(key: string, data: unknown): void {
    const size = this.estimateSize(data)

    // Evict if needed
    while (this.currentSize + size > this.maxSize && this.cache.size > 0) {
      this.evictOldest()
    }

    if (size <= this.maxSize) {
      this.cache.set(key, { data, timestamp: Date.now(), size })
      this.currentSize += size
    }
  }

  /**
   * Check if key exists
   */
  has(key: string): boolean {
    return this.cache.has(key)
  }

  /**
   * Clear cache
   */
  clear(): void {
    this.cache.clear()
    this.currentSize = 0
  }

  /**
   * Get cache stats
   */
  getStats(): { hits: number; misses: number; hitRate: number; size: number; itemCount: number } {
    const total = this.hits + this.misses
    return {
      hits: this.hits,
      misses: this.misses,
      hitRate: total > 0 ? this.hits / total : 0,
      size: this.currentSize,
      itemCount: this.cache.size,
    }
  }

  private evictOldest(): void {
    let oldestKey: string | null = null
    let oldestTime = Infinity

    for (const [key, value] of this.cache) {
      if (value.timestamp < oldestTime) {
        oldestTime = value.timestamp
        oldestKey = key
      }
    }

    if (oldestKey) {
      const item = this.cache.get(oldestKey)
      if (item) {
        this.currentSize -= item.size
      }
      this.cache.delete(oldestKey)
    }
  }

  private estimateSize(data: unknown): number {
    try {
      return JSON.stringify(data).length * 2 // UTF-16 encoding
    } catch {
      return 1024 // Default estimate
    }
  }
}

// Global instances
let moduleRegistry: ModuleRegistry | null = null
let coldStartOptimizer: ColdStartOptimizer | null = null
let startupCache: StartupCache | null = null

export function getModuleRegistry(): ModuleRegistry {
  if (!moduleRegistry) {
    moduleRegistry = new ModuleRegistry()
  }
  return moduleRegistry
}

export function getColdStartOptimizer(): ColdStartOptimizer {
  if (!coldStartOptimizer) {
    coldStartOptimizer = new ColdStartOptimizer()
  }
  return coldStartOptimizer
}

export function getStartupCache(): StartupCache {
  if (!startupCache) {
    startupCache = new StartupCache()
  }
  return startupCache
}

const _exports: {
  LazyLoader: typeof LazyLoader;
  ModuleRegistry: typeof ModuleRegistry;
  AssetPrecompiler: typeof AssetPrecompiler;
  ColdStartOptimizer: typeof ColdStartOptimizer;
  BinarySizeReducer: typeof BinarySizeReducer;
  StartupCache: typeof StartupCache;
  getModuleRegistry: typeof getModuleRegistry;
  getColdStartOptimizer: typeof getColdStartOptimizer;
  getStartupCache: typeof getStartupCache;
} = {
  LazyLoader,
  ModuleRegistry,
  AssetPrecompiler,
  ColdStartOptimizer,
  BinarySizeReducer,
  StartupCache,
  getModuleRegistry,
  getColdStartOptimizer,
  getStartupCache,
};
export default _exports;
