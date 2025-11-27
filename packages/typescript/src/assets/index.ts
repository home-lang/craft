/**
 * Craft Asset Optimization
 * Optimize images, SVGs, fonts, and other assets for production
 */

import { existsSync, readFileSync, writeFileSync, readdirSync, statSync, mkdirSync } from 'fs'
import { join, extname, basename, dirname } from 'path'
import { execSync } from 'child_process'

// Types
export interface AssetOptimizationOptions {
  inputDir: string
  outputDir: string
  images?: ImageOptions
  svg?: SvgOptions
  fonts?: FontOptions
  compress?: boolean
  verbose?: boolean
}

export interface ImageOptions {
  quality?: number // 0-100
  maxWidth?: number
  maxHeight?: number
  formats?: ('webp' | 'avif' | 'png' | 'jpg')[]
  progressive?: boolean
  stripMetadata?: boolean
}

export interface SvgOptions {
  minify?: boolean
  removeComments?: boolean
  removeDimensions?: boolean
  cleanupIds?: boolean
  removeUselessStrokeAndFill?: boolean
}

export interface FontOptions {
  subset?: string // Unicode ranges to include
  formats?: ('woff2' | 'woff' | 'ttf')[]
  hinting?: boolean
}

export interface AssetReport {
  totalFiles: number
  totalOriginalSize: number
  totalOptimizedSize: number
  savings: number
  savingsPercent: number
  files: AssetFileReport[]
}

export interface AssetFileReport {
  path: string
  type: 'image' | 'svg' | 'font' | 'other'
  originalSize: number
  optimizedSize: number
  savings: number
  savingsPercent: number
  generatedFormats?: string[]
}

// Asset Optimizer
export class AssetOptimizer {
  private options: AssetOptimizationOptions
  private report: AssetReport

  constructor(options: AssetOptimizationOptions) {
    this.options = {
      images: {
        quality: 80,
        maxWidth: 2048,
        maxHeight: 2048,
        formats: ['webp'],
        progressive: true,
        stripMetadata: true,
      },
      svg: {
        minify: true,
        removeComments: true,
        removeDimensions: false,
        cleanupIds: true,
        removeUselessStrokeAndFill: true,
      },
      fonts: {
        formats: ['woff2', 'woff'],
        hinting: true,
      },
      compress: true,
      verbose: false,
      ...options,
    }

    this.report = {
      totalFiles: 0,
      totalOriginalSize: 0,
      totalOptimizedSize: 0,
      savings: 0,
      savingsPercent: 0,
      files: [],
    }
  }

  /**
   * Optimize all assets in the input directory
   */
  async optimize(): Promise<AssetReport> {
    if (!existsSync(this.options.inputDir)) {
      throw new Error(`Input directory not found: ${this.options.inputDir}`)
    }

    mkdirSync(this.options.outputDir, { recursive: true })

    await this.processDirectory(this.options.inputDir)

    // Calculate totals
    this.report.savings = this.report.totalOriginalSize - this.report.totalOptimizedSize
    this.report.savingsPercent =
      this.report.totalOriginalSize > 0
        ? Math.round((this.report.savings / this.report.totalOriginalSize) * 100)
        : 0

    return this.report
  }

  private async processDirectory(dir: string): Promise<void> {
    const entries = readdirSync(dir)

    for (const entry of entries) {
      const fullPath = join(dir, entry)
      const stat = statSync(fullPath)

      if (stat.isDirectory()) {
        await this.processDirectory(fullPath)
      } else {
        await this.processFile(fullPath)
      }
    }
  }

  private async processFile(filePath: string): Promise<void> {
    const ext = extname(filePath).toLowerCase()
    const relativePath = filePath.replace(this.options.inputDir, '')
    const outputPath = join(this.options.outputDir, relativePath)

    mkdirSync(dirname(outputPath), { recursive: true })

    const originalSize = statSync(filePath).size
    let optimizedSize = originalSize
    let type: AssetFileReport['type'] = 'other'
    let generatedFormats: string[] = []

    try {
      if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].includes(ext)) {
        type = 'image'
        const result = await this.optimizeImage(filePath, outputPath)
        optimizedSize = result.size
        generatedFormats = result.formats
      } else if (ext === '.svg') {
        type = 'svg'
        optimizedSize = await this.optimizeSvg(filePath, outputPath)
      } else if (['.ttf', '.otf', '.woff', '.woff2'].includes(ext)) {
        type = 'font'
        const result = await this.optimizeFont(filePath, outputPath)
        optimizedSize = result.size
        generatedFormats = result.formats
      } else {
        // Copy file as-is
        writeFileSync(outputPath, readFileSync(filePath))
      }

      const fileReport: AssetFileReport = {
        path: relativePath,
        type,
        originalSize,
        optimizedSize,
        savings: originalSize - optimizedSize,
        savingsPercent:
          originalSize > 0 ? Math.round(((originalSize - optimizedSize) / originalSize) * 100) : 0,
        generatedFormats: generatedFormats.length > 0 ? generatedFormats : undefined,
      }

      this.report.files.push(fileReport)
      this.report.totalFiles++
      this.report.totalOriginalSize += originalSize
      this.report.totalOptimizedSize += optimizedSize

      if (this.options.verbose) {
        const savingsStr =
          fileReport.savings > 0
            ? `-${this.formatSize(fileReport.savings)} (${fileReport.savingsPercent}%)`
            : 'no change'
        console.log(`  ${relativePath}: ${savingsStr}`)
      }
    } catch (error) {
      console.error(`Failed to process ${filePath}:`, error)
      // Copy original file on error
      writeFileSync(outputPath, readFileSync(filePath))
    }
  }

  private async optimizeImage(
    inputPath: string,
    outputPath: string
  ): Promise<{ size: number; formats: string[] }> {
    const opts = this.options.images!
    const formats: string[] = []
    let totalSize = 0

    // Use sharp if available, otherwise fall back to ImageMagick
    try {
      // Try to use sharp
      const sharp = await import('sharp').catch(() => null)

      if (sharp) {
        let pipeline = sharp.default(inputPath)

        // Resize if needed
        if (opts.maxWidth || opts.maxHeight) {
          pipeline = pipeline.resize(opts.maxWidth, opts.maxHeight, {
            fit: 'inside',
            withoutEnlargement: true,
          })
        }

        // Strip metadata
        if (opts.stripMetadata) {
          pipeline = pipeline.rotate() // Auto-rotate based on EXIF then strip
        }

        // Generate requested formats
        for (const format of opts.formats || ['webp']) {
          const formatPath = outputPath.replace(/\.[^.]+$/, `.${format}`)

          switch (format) {
            case 'webp':
              await pipeline.webp({ quality: opts.quality }).toFile(formatPath)
              break
            case 'avif':
              await pipeline.avif({ quality: opts.quality }).toFile(formatPath)
              break
            case 'png':
              await pipeline
                .png({ compressionLevel: 9, progressive: opts.progressive })
                .toFile(formatPath)
              break
            case 'jpg':
              await pipeline
                .jpeg({ quality: opts.quality, progressive: opts.progressive })
                .toFile(formatPath)
              break
          }

          formats.push(format)
          totalSize += statSync(formatPath).size
        }
      } else {
        // Fall back to ImageMagick
        const quality = opts.quality || 80
        const resize = opts.maxWidth ? `-resize ${opts.maxWidth}x${opts.maxHeight}\\>` : ''
        const strip = opts.stripMetadata ? '-strip' : ''

        execSync(`convert "${inputPath}" ${resize} ${strip} -quality ${quality} "${outputPath}"`)
        totalSize = statSync(outputPath).size
        formats.push(extname(outputPath).slice(1))
      }
    } catch {
      // If all else fails, just copy the file
      writeFileSync(outputPath, readFileSync(inputPath))
      totalSize = statSync(outputPath).size
    }

    return { size: totalSize / formats.length, formats }
  }

  private async optimizeSvg(inputPath: string, outputPath: string): Promise<number> {
    const opts = this.options.svg!
    let content = readFileSync(inputPath, 'utf-8')

    if (opts.minify) {
      // Basic SVG minification
      content = content
        // Remove comments
        .replace(/<!--[\s\S]*?-->/g, '')
        // Remove unnecessary whitespace
        .replace(/>\s+</g, '><')
        // Remove empty attributes
        .replace(/\s+([a-z-]+)=""/gi, '')
        // Collapse whitespace
        .replace(/\s+/g, ' ')
        .trim()
    }

    if (opts.removeComments) {
      content = content.replace(/<!--[\s\S]*?-->/g, '')
    }

    if (opts.removeDimensions) {
      content = content.replace(/\s+(width|height)="[^"]*"/gi, '')
    }

    if (opts.removeUselessStrokeAndFill) {
      content = content
        .replace(/stroke="none"/gi, '')
        .replace(/fill="none"/gi, '')
        .replace(/stroke-width="0"/gi, '')
    }

    writeFileSync(outputPath, content)
    return statSync(outputPath).size
  }

  private async optimizeFont(
    inputPath: string,
    outputPath: string
  ): Promise<{ size: number; formats: string[] }> {
    const opts = this.options.fonts!
    const formats: string[] = []
    let totalSize = 0
    const baseName = basename(outputPath).replace(/\.[^.]+$/, '')
    const outDir = dirname(outputPath)

    // Try to use fonttools for subsetting
    const hasSubset = opts.subset && this.commandExists('pyftsubset')

    for (const format of opts.formats || ['woff2', 'woff']) {
      const formatPath = join(outDir, `${baseName}.${format}`)

      try {
        if (hasSubset) {
          // Subset font
          const unicodeRange = opts.subset || 'U+0000-00FF'
          const flavorFlag = format === 'woff2' ? '--flavor=woff2' : format === 'woff' ? '--flavor=woff' : ''

          execSync(
            `pyftsubset "${inputPath}" --unicodes="${unicodeRange}" ${flavorFlag} --output-file="${formatPath}"`
          )
        } else if (this.commandExists('woff2_compress') && format === 'woff2') {
          // Just compress to woff2
          const tempPath = formatPath.replace('.woff2', '.ttf')
          writeFileSync(tempPath, readFileSync(inputPath))
          execSync(`woff2_compress "${tempPath}"`)
        } else {
          // Copy as-is
          writeFileSync(formatPath, readFileSync(inputPath))
        }

        if (existsSync(formatPath)) {
          formats.push(format)
          totalSize += statSync(formatPath).size
        }
      } catch {
        // Copy original format on error
        writeFileSync(outputPath, readFileSync(inputPath))
        totalSize = statSync(outputPath).size
        formats.push(extname(outputPath).slice(1))
      }
    }

    return { size: totalSize / Math.max(formats.length, 1), formats }
  }

  private commandExists(command: string): boolean {
    try {
      execSync(`which ${command}`, { stdio: 'ignore' })
      return true
    } catch {
      return false
    }
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes}B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)}KB`
    return `${(bytes / (1024 * 1024)).toFixed(1)}MB`
  }
}

// CLI Command
export async function assetsCommand(args: string[]): Promise<void> {
  const [subcommand, ...rest] = args

  switch (subcommand) {
    case 'optimize': {
      const inputDir = rest[0] || './assets'
      const outputDir = rest[1] || './dist/assets'

      console.log(`Optimizing assets from ${inputDir}...`)

      const optimizer = new AssetOptimizer({
        inputDir,
        outputDir,
        verbose: rest.includes('--verbose') || rest.includes('-v'),
      })

      const report = await optimizer.optimize()

      console.log(`
Asset Optimization Complete
===========================
Total files: ${report.totalFiles}
Original size: ${formatSize(report.totalOriginalSize)}
Optimized size: ${formatSize(report.totalOptimizedSize)}
Savings: ${formatSize(report.savings)} (${report.savingsPercent}%)
`)
      break
    }

    case 'analyze': {
      const dir = rest[0] || './assets'

      if (!existsSync(dir)) {
        console.error(`Directory not found: ${dir}`)
        process.exit(1)
      }

      console.log(`Analyzing assets in ${dir}...`)

      const analysis = analyzeAssets(dir)

      console.log(`
Asset Analysis
==============
Images: ${analysis.images.count} (${formatSize(analysis.images.size)})
SVGs: ${analysis.svgs.count} (${formatSize(analysis.svgs.size)})
Fonts: ${analysis.fonts.count} (${formatSize(analysis.fonts.size)})
Other: ${analysis.other.count} (${formatSize(analysis.other.size)})
Total: ${analysis.total.count} (${formatSize(analysis.total.size)})
`)
      break
    }

    default:
      console.log(`
Craft Asset Optimizer

Usage: craft assets <command> [options]

Commands:
  optimize [input] [output]  Optimize assets for production
  analyze [dir]              Analyze assets in directory

Options:
  --verbose, -v              Show detailed output

Examples:
  craft assets optimize ./src/assets ./dist/assets
  craft assets analyze ./src/assets
`)
  }
}

function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes}B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)}KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)}MB`
}

function analyzeAssets(dir: string): {
  images: { count: number; size: number }
  svgs: { count: number; size: number }
  fonts: { count: number; size: number }
  other: { count: number; size: number }
  total: { count: number; size: number }
} {
  const result = {
    images: { count: 0, size: 0 },
    svgs: { count: 0, size: 0 },
    fonts: { count: 0, size: 0 },
    other: { count: 0, size: 0 },
    total: { count: 0, size: 0 },
  }

  function walk(currentDir: string): void {
    const entries = readdirSync(currentDir)

    for (const entry of entries) {
      const fullPath = join(currentDir, entry)
      const stat = statSync(fullPath)

      if (stat.isDirectory()) {
        walk(fullPath)
      } else {
        const ext = extname(entry).toLowerCase()
        const size = stat.size

        if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.avif'].includes(ext)) {
          result.images.count++
          result.images.size += size
        } else if (ext === '.svg') {
          result.svgs.count++
          result.svgs.size += size
        } else if (['.ttf', '.otf', '.woff', '.woff2', '.eot'].includes(ext)) {
          result.fonts.count++
          result.fonts.size += size
        } else {
          result.other.count++
          result.other.size += size
        }

        result.total.count++
        result.total.size += size
      }
    }
  }

  walk(dir)
  return result
}

export default AssetOptimizer
