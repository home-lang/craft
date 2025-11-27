/**
 * Craft Performance Benchmarking Suite
 * Measures startup time, memory usage, rendering performance, and bridge latency
 */

export interface BenchmarkResult {
  name: string
  iterations: number
  totalTime: number
  averageTime: number
  minTime: number
  maxTime: number
  stdDev: number
  opsPerSecond: number
  memoryUsed?: number
}

export interface BenchmarkSuite {
  name: string
  results: BenchmarkResult[]
  totalTime: number
  timestamp: Date
  platform: string
  version: string
}

/**
 * Benchmark runner
 */
export class Benchmark {
  private name: string
  private fn: () => void | Promise<void>
  private iterations: number
  private warmupIterations: number
  private times: number[] = []

  constructor(
    name: string,
    fn: () => void | Promise<void>,
    options: { iterations?: number; warmup?: number } = {}
  ) {
    this.name = name
    this.fn = fn
    this.iterations = options.iterations || 100
    this.warmupIterations = options.warmup || 10
  }

  /**
   * Run the benchmark
   */
  async run(): Promise<BenchmarkResult> {
    // Warmup
    for (let i = 0; i < this.warmupIterations; i++) {
      await this.fn()
    }

    // Force GC if available
    if (typeof globalThis.gc === 'function') {
      globalThis.gc()
    }

    const memoryBefore = this.getMemoryUsage()

    // Run iterations
    this.times = []
    for (let i = 0; i < this.iterations; i++) {
      const start = performance.now()
      await this.fn()
      const end = performance.now()
      this.times.push(end - start)
    }

    const memoryAfter = this.getMemoryUsage()

    return this.calculateResults(memoryAfter - memoryBefore)
  }

  private getMemoryUsage(): number {
    if (typeof process !== 'undefined' && process.memoryUsage) {
      return process.memoryUsage().heapUsed
    }
    // @ts-expect-error - performance.memory is non-standard
    if (performance.memory) {
      // @ts-expect-error - performance.memory is non-standard
      return performance.memory.usedJSHeapSize
    }
    return 0
  }

  private calculateResults(memoryUsed: number): BenchmarkResult {
    const totalTime = this.times.reduce((a, b) => a + b, 0)
    const averageTime = totalTime / this.iterations
    const minTime = Math.min(...this.times)
    const maxTime = Math.max(...this.times)

    // Calculate standard deviation
    const squaredDiffs = this.times.map(t => Math.pow(t - averageTime, 2))
    const avgSquaredDiff = squaredDiffs.reduce((a, b) => a + b, 0) / this.iterations
    const stdDev = Math.sqrt(avgSquaredDiff)

    const opsPerSecond = 1000 / averageTime

    return {
      name: this.name,
      iterations: this.iterations,
      totalTime,
      averageTime,
      minTime,
      maxTime,
      stdDev,
      opsPerSecond,
      memoryUsed: memoryUsed > 0 ? memoryUsed : undefined
    }
  }
}

/**
 * Create a benchmark suite
 */
export class BenchmarkSuiteRunner {
  private name: string
  private benchmarks: Benchmark[] = []

  constructor(name: string) {
    this.name = name
  }

  /**
   * Add a benchmark to the suite
   */
  add(
    name: string,
    fn: () => void | Promise<void>,
    options?: { iterations?: number; warmup?: number }
  ): this {
    this.benchmarks.push(new Benchmark(name, fn, options))
    return this
  }

  /**
   * Run all benchmarks in the suite
   */
  async run(): Promise<BenchmarkSuite> {
    const startTime = performance.now()
    const results: BenchmarkResult[] = []

    for (const benchmark of this.benchmarks) {
      console.log(`Running benchmark: ${benchmark['name']}`)
      const result = await benchmark.run()
      results.push(result)
      this.printResult(result)
    }

    const endTime = performance.now()

    return {
      name: this.name,
      results,
      totalTime: endTime - startTime,
      timestamp: new Date(),
      platform: typeof process !== 'undefined' ? process.platform : 'browser',
      version: '1.0.0'
    }
  }

  private printResult(result: BenchmarkResult): void {
    console.log(`
  ${result.name}:
    Average: ${result.averageTime.toFixed(3)}ms
    Min: ${result.minTime.toFixed(3)}ms
    Max: ${result.maxTime.toFixed(3)}ms
    Std Dev: ${result.stdDev.toFixed(3)}ms
    Ops/sec: ${result.opsPerSecond.toFixed(2)}
    ${result.memoryUsed ? `Memory: ${(result.memoryUsed / 1024 / 1024).toFixed(2)}MB` : ''}
`)
  }
}

/**
 * Pre-built Craft benchmarks
 */
export const craftBenchmarks = {
  /**
   * Measure app startup time
   */
  startupTime: async (): Promise<BenchmarkResult> => {
    const bench = new Benchmark('Startup Time', async () => {
      // Simulate app initialization
      await new Promise(r => setTimeout(r, 1))
    }, { iterations: 10, warmup: 2 })

    return bench.run()
  },

  /**
   * Measure bridge call latency
   */
  bridgeLatency: async (): Promise<BenchmarkResult> => {
    const bench = new Benchmark('Bridge Latency', async () => {
      // Simulate bridge call
      if (typeof window !== 'undefined' && (window as any).craft) {
        await (window as any).craft.invoke('ping', {})
      }
    }, { iterations: 1000, warmup: 100 })

    return bench.run()
  },

  /**
   * Measure DOM rendering performance
   */
  renderPerformance: async (): Promise<BenchmarkResult> => {
    const bench = new Benchmark('DOM Render', () => {
      const container = document.createElement('div')
      for (let i = 0; i < 100; i++) {
        const el = document.createElement('div')
        el.textContent = `Item ${i}`
        container.appendChild(el)
      }
      document.body.appendChild(container)
      document.body.removeChild(container)
    }, { iterations: 100, warmup: 10 })

    return bench.run()
  },

  /**
   * Measure JSON serialization performance
   */
  jsonSerialization: async (): Promise<BenchmarkResult> => {
    const testData = {
      array: Array.from({ length: 1000 }, (_, i) => ({
        id: i,
        name: `Item ${i}`,
        value: Math.random()
      }))
    }

    const bench = new Benchmark('JSON Serialization', () => {
      const json = JSON.stringify(testData)
      JSON.parse(json)
    }, { iterations: 1000, warmup: 100 })

    return bench.run()
  },

  /**
   * Measure memory allocation patterns
   */
  memoryAllocation: async (): Promise<BenchmarkResult> => {
    const bench = new Benchmark('Memory Allocation', () => {
      const arrays: number[][] = []
      for (let i = 0; i < 100; i++) {
        arrays.push(Array.from({ length: 1000 }, () => Math.random()))
      }
      // Let GC clean up
    }, { iterations: 50, warmup: 5 })

    return bench.run()
  }
}

/**
 * Create a new benchmark suite
 */
export function createSuite(name: string): BenchmarkSuiteRunner {
  return new BenchmarkSuiteRunner(name)
}

/**
 * Run a quick performance check
 */
export async function quickCheck(): Promise<void> {
  console.log('Running Craft Performance Quick Check...\n')

  const suite = createSuite('Craft Quick Check')
    .add('JSON Parse/Stringify', () => {
      const data = { foo: 'bar', num: 123, arr: [1, 2, 3] }
      JSON.parse(JSON.stringify(data))
    })
    .add('DOM Create/Remove', () => {
      const el = document.createElement('div')
      document.body.appendChild(el)
      document.body.removeChild(el)
    })
    .add('Array Operations', () => {
      const arr = Array.from({ length: 1000 }, (_, i) => i)
      arr.map(x => x * 2).filter(x => x > 500).reduce((a, b) => a + b, 0)
    })

  await suite.run()
}

/**
 * Format benchmark results as markdown
 */
export function formatResultsMarkdown(suite: BenchmarkSuite): string {
  let md = `# Benchmark Results: ${suite.name}\n\n`
  md += `- **Date**: ${suite.timestamp.toISOString()}\n`
  md += `- **Platform**: ${suite.platform}\n`
  md += `- **Total Time**: ${suite.totalTime.toFixed(2)}ms\n\n`
  md += `| Benchmark | Average | Min | Max | Ops/sec |\n`
  md += `|-----------|---------|-----|-----|--------|\n`

  for (const result of suite.results) {
    md += `| ${result.name} | ${result.averageTime.toFixed(3)}ms | ${result.minTime.toFixed(3)}ms | ${result.maxTime.toFixed(3)}ms | ${result.opsPerSecond.toFixed(2)} |\n`
  }

  return md
}
