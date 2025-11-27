/**
 * Craft Bundle Optimizer
 * Code splitting, tree shaking, and bundle optimization
 */

import { existsSync, readFileSync, writeFileSync, mkdirSync, statSync } from 'fs'
import { join, dirname, basename, extname } from 'path'
import { execSync } from 'child_process'
import { createHash } from 'crypto'
import { gzip, brotliCompress } from 'zlib'
import { promisify } from 'util'

const gzipAsync = promisify(gzip)
const brotliAsync = promisify(brotliCompress)

// Types
export interface BundleOptimizerConfig {
  input: string | string[]
  outDir: string
  splitting?: boolean
  treeshaking?: boolean
  minify?: boolean
  sourcemap?: boolean | 'external' | 'inline'
  target?: 'browser' | 'node' | 'bun'
  format?: 'esm' | 'cjs' | 'iife'
  external?: string[]
  define?: Record<string, string>
  compress?: {
    gzip?: boolean
    brotli?: boolean
  }
  analyze?: boolean
  maxChunkSize?: number // KB
  manualChunks?: Record<string, string[]>
}

export interface BundleResult {
  files: BundleFile[]
  totalSize: number
  totalCompressedSize: number
  chunks: ChunkInfo[]
  warnings: string[]
  buildTime: number
}

export interface BundleFile {
  path: string
  size: number
  gzipSize?: number
  brotliSize?: number
  isEntry: boolean
  hash: string
}

export interface ChunkInfo {
  name: string
  size: number
  modules: string[]
  imports: string[]
  exports: string[]
}

// Bundle Optimizer
export class BundleOptimizer {
  private config: BundleOptimizerConfig

  constructor(config: BundleOptimizerConfig) {
    this.config = {
      splitting: true,
      treeshaking: true,
      minify: true,
      sourcemap: 'external',
      target: 'browser',
      format: 'esm',
      external: [],
      define: {},
      compress: { gzip: true, brotli: true },
      analyze: false,
      maxChunkSize: 250,
      ...config,
    }
  }

  /**
   * Build and optimize bundle
   */
  async build(): Promise<BundleResult> {
    const startTime = Date.now()
    const warnings: string[] = []

    // Ensure output directory exists
    mkdirSync(this.config.outDir, { recursive: true })

    // Use Bun's bundler if available
    const result = await this.bundleWithBun()

    // Post-processing
    const files: BundleFile[] = []
    let totalSize = 0
    let totalCompressedSize = 0

    for (const file of result.outputs) {
      const filePath = join(this.config.outDir, file.path)
      const content = file.contents

      // Calculate sizes
      const size = content.length
      totalSize += size

      // Compress
      let gzipSize: number | undefined
      let brotliSize: number | undefined

      if (this.config.compress?.gzip) {
        const gzipped = await gzipAsync(content)
        gzipSize = gzipped.length
        writeFileSync(filePath + '.gz', gzipped)
      }

      if (this.config.compress?.brotli) {
        const brotlied = await brotliAsync(content)
        brotliSize = brotlied.length
        writeFileSync(filePath + '.br', brotlied)
      }

      totalCompressedSize += gzipSize || size

      // Generate hash
      const hash = createHash('md5').update(content).digest('hex').slice(0, 8)

      files.push({
        path: file.path,
        size,
        gzipSize,
        brotliSize,
        isEntry: file.kind === 'entry-point',
        hash,
      })

      // Write file
      writeFileSync(filePath, content)

      // Check chunk size
      if (size > this.config.maxChunkSize! * 1024) {
        warnings.push(`Chunk ${file.path} (${formatSize(size)}) exceeds max size of ${this.config.maxChunkSize}KB`)
      }
    }

    // Generate chunks info
    const chunks: ChunkInfo[] = result.outputs.map((output) => ({
      name: output.path,
      size: output.contents.length,
      modules: output.imports || [],
      imports: [],
      exports: output.exports || [],
    }))

    const buildTime = Date.now() - startTime

    // Generate analysis if requested
    if (this.config.analyze) {
      this.generateAnalysis(files, chunks)
    }

    return {
      files,
      totalSize,
      totalCompressedSize,
      chunks,
      warnings,
      buildTime,
    }
  }

  /**
   * Bundle using Bun's bundler
   */
  private async bundleWithBun(): Promise<{ outputs: Array<{ path: string; contents: Buffer; kind: string; imports?: string[]; exports?: string[] }> }> {
    const entrypoints = Array.isArray(this.config.input) ? this.config.input : [this.config.input]

    try {
      const result = await Bun.build({
        entrypoints,
        outdir: this.config.outDir,
        splitting: this.config.splitting,
        minify: this.config.minify,
        sourcemap: this.config.sourcemap as any,
        target: this.config.target as any,
        format: this.config.format as any,
        external: this.config.external,
        define: this.config.define,
        naming: {
          entry: '[name]-[hash].[ext]',
          chunk: 'chunks/[name]-[hash].[ext]',
        },
      })

      if (!result.success) {
        throw new Error(result.logs.map((l) => l.message).join('\n'))
      }

      return {
        outputs: result.outputs.map((output) => ({
          path: output.path.replace(this.config.outDir + '/', ''),
          contents: Buffer.from(output.text()),
          kind: output.kind,
        })),
      }
    } catch (error: any) {
      // Fallback to esbuild if Bun.build is not available
      return this.bundleWithEsbuild()
    }
  }

  /**
   * Fallback bundler using esbuild CLI
   */
  private async bundleWithEsbuild(): Promise<{ outputs: Array<{ path: string; contents: Buffer; kind: string }> }> {
    const entrypoints = Array.isArray(this.config.input) ? this.config.input : [this.config.input]

    const args = [
      ...entrypoints,
      `--outdir=${this.config.outDir}`,
      `--bundle`,
      this.config.splitting ? '--splitting' : '',
      this.config.minify ? '--minify' : '',
      this.config.sourcemap ? `--sourcemap=${this.config.sourcemap}` : '',
      `--format=${this.config.format}`,
      `--target=${this.config.target === 'node' ? 'node18' : 'es2020'}`,
      ...this.config.external!.map((e) => `--external:${e}`),
      ...Object.entries(this.config.define || {}).map(([k, v]) => `--define:${k}=${v}`),
      '--metafile=meta.json',
    ].filter(Boolean)

    execSync(`bunx esbuild ${args.join(' ')}`, { cwd: process.cwd() })

    // Read outputs from metafile
    const metaPath = join(this.config.outDir, 'meta.json')
    const meta = JSON.parse(readFileSync(metaPath, 'utf-8'))

    const outputs = Object.keys(meta.outputs).map((outputPath) => ({
      path: outputPath.replace(this.config.outDir + '/', ''),
      contents: readFileSync(outputPath),
      kind: meta.outputs[outputPath].entryPoint ? 'entry-point' : 'chunk',
    }))

    return { outputs }
  }

  /**
   * Generate bundle analysis
   */
  private generateAnalysis(files: BundleFile[], chunks: ChunkInfo[]): void {
    const analysisPath = join(this.config.outDir, 'bundle-analysis.html')

    const totalSize = files.reduce((sum, f) => sum + f.size, 0)
    const totalGzip = files.reduce((sum, f) => sum + (f.gzipSize || f.size), 0)

    const html = `
<!DOCTYPE html>
<html>
<head>
  <title>Bundle Analysis</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: system-ui, sans-serif; padding: 24px; background: #f5f5f5; }
    h1 { margin-bottom: 24px; }
    .summary { display: flex; gap: 16px; margin-bottom: 24px; }
    .card { background: white; padding: 16px; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
    .card h3 { color: #666; font-size: 14px; margin-bottom: 8px; }
    .card .value { font-size: 24px; font-weight: 600; }
    .files { background: white; border-radius: 8px; overflow: hidden; }
    .file { display: flex; align-items: center; padding: 12px 16px; border-bottom: 1px solid #eee; }
    .file:last-child { border-bottom: none; }
    .file-name { flex: 1; font-family: monospace; }
    .file-size { min-width: 100px; text-align: right; }
    .file-bar { height: 4px; background: #e0e0e0; border-radius: 2px; margin-top: 4px; }
    .file-bar-fill { height: 100%; background: #4caf50; border-radius: 2px; }
    .entry { font-weight: 600; }
  </style>
</head>
<body>
  <h1>Bundle Analysis</h1>

  <div class="summary">
    <div class="card">
      <h3>Total Size</h3>
      <div class="value">${formatSize(totalSize)}</div>
    </div>
    <div class="card">
      <h3>Gzipped</h3>
      <div class="value">${formatSize(totalGzip)}</div>
    </div>
    <div class="card">
      <h3>Files</h3>
      <div class="value">${files.length}</div>
    </div>
  </div>

  <div class="files">
    ${files
      .sort((a, b) => b.size - a.size)
      .map(
        (file) => `
      <div class="file">
        <div class="file-name ${file.isEntry ? 'entry' : ''}">${file.path}</div>
        <div class="file-size">${formatSize(file.size)}</div>
        <div class="file-size" style="color: #888;">${formatSize(file.gzipSize || file.size)}</div>
      </div>
      <div class="file-bar">
        <div class="file-bar-fill" style="width: ${(file.size / totalSize) * 100}%"></div>
      </div>
    `
      )
      .join('')}
  </div>
</body>
</html>
`

    writeFileSync(analysisPath, html)
    console.log(`Bundle analysis saved to ${analysisPath}`)
  }
}

// Utility functions
function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes}B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)}KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)}MB`
}

// CLI Command
export async function bundleCommand(args: string[]): Promise<void> {
  const [input, ...rest] = args
  const outDir = rest.find((a) => a.startsWith('--out='))?.split('=')[1] || './dist'

  if (!input) {
    console.log(`
Craft Bundle Optimizer

Usage: craft bundle <input> [options]

Options:
  --out=<dir>          Output directory (default: ./dist)
  --minify             Minify output
  --no-minify          Skip minification
  --splitting          Enable code splitting
  --sourcemap          Generate sourcemaps
  --analyze            Generate bundle analysis
  --compress           Enable gzip/brotli compression

Examples:
  craft bundle src/index.ts --out=dist --minify --analyze
  craft bundle src/app.ts src/worker.ts --splitting
`)
    return
  }

  const optimizer = new BundleOptimizer({
    input,
    outDir,
    minify: !rest.includes('--no-minify'),
    splitting: rest.includes('--splitting'),
    sourcemap: rest.includes('--sourcemap') ? 'external' : false,
    analyze: rest.includes('--analyze'),
    compress: rest.includes('--compress') ? { gzip: true, brotli: true } : undefined,
  })

  console.log('Building bundle...')
  const result = await optimizer.build()

  console.log(`
Build complete in ${result.buildTime}ms

Files:
${result.files.map((f) => `  ${f.path} - ${formatSize(f.size)}${f.gzipSize ? ` (${formatSize(f.gzipSize)} gzip)` : ''}`).join('\n')}

Total: ${formatSize(result.totalSize)}${result.totalCompressedSize !== result.totalSize ? ` (${formatSize(result.totalCompressedSize)} compressed)` : ''}
`)

  if (result.warnings.length > 0) {
    console.log('\nWarnings:')
    result.warnings.forEach((w) => console.log(`  ⚠ ${w}`))
  }
}

export default BundleOptimizer
