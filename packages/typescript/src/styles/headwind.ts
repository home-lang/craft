/**
 * @fileoverview Headwind CSS Integration
 * @description Integration with zig-headwind, a blazing-fast Tailwind CSS alternative built in Zig.
 * Provides utility-first CSS styling with Tailwind-compatible class names.
 * @module @craft/styles/headwind
 *
 * @example
 * ```typescript
 * import { tw, cx, variants, style } from '@craft/styles/headwind'
 *
 * // Use Tailwind-compatible classes
 * const buttonClass = tw`px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600`
 *
 * // Conditional classes
 * const className = cx(
 *   'base-class',
 *   isActive && 'active',
 *   { 'disabled': isDisabled }
 * )
 *
 * // Create variant-based styles
 * const button = variants({
 *   base: 'px-4 py-2 rounded font-medium transition-colors',
 *   variants: {
 *     intent: {
 *       primary: 'bg-blue-500 text-white hover:bg-blue-600',
 *       secondary: 'bg-gray-200 text-gray-900 hover:bg-gray-300',
 *       danger: 'bg-red-500 text-white hover:bg-red-600'
 *     },
 *     size: {
 *       sm: 'text-sm px-3 py-1.5',
 *       md: 'text-base px-4 py-2',
 *       lg: 'text-lg px-6 py-3'
 *     }
 *   },
 *   defaultVariants: {
 *     intent: 'primary',
 *     size: 'md'
 *   }
 * })
 *
 * // Use the variant
 * const className = button({ intent: 'danger', size: 'lg' })
 * ```
 */

// ============================================================================
// Core Utilities
// ============================================================================

/**
 * Tagged template literal for Tailwind/Headwind classes.
 * Provides syntax highlighting and potential compile-time validation.
 *
 * @example
 * ```typescript
 * const className = tw`flex items-center justify-center p-4 bg-blue-500`
 * ```
 */
export function tw(strings: TemplateStringsArray, ...values: unknown[]): string {
  let result = ''
  for (let i = 0; i < strings.length; i++) {
    result += strings[i]
    if (i < values.length) {
      result += String(values[i])
    }
  }
  // Normalize whitespace
  return result.replace(/\s+/g, ' ').trim()
}

/**
 * Type for class value inputs.
 */
export type ClassValue =
  | string
  | number
  | boolean
  | null
  | undefined
  | ClassValue[]
  | Record<string, boolean | null | undefined>

/**
 * Merge class names conditionally.
 * Supports strings, arrays, objects, and falsy values.
 *
 * @example
 * ```typescript
 * // String classes
 * cx('foo', 'bar') // 'foo bar'
 *
 * // Conditional classes
 * cx('base', isActive && 'active', isDisabled && 'disabled')
 *
 * // Object syntax
 * cx('base', { active: isActive, disabled: isDisabled })
 *
 * // Mixed
 * cx('base', ['array', 'of', 'classes'], { conditional: true })
 * ```
 */
export function cx(...inputs: ClassValue[]): string {
  const classes: string[] = []

  for (const input of inputs) {
    if (!input) continue

    if (typeof input === 'string' || typeof input === 'number') {
      classes.push(String(input))
    } else if (Array.isArray(input)) {
      const nested = cx(...input)
      if (nested) classes.push(nested)
    } else if (typeof input === 'object') {
      for (const [key, value] of Object.entries(input)) {
        if (value) classes.push(key)
      }
    }
  }

  return classes.join(' ')
}

// ============================================================================
// Variants System
// ============================================================================

/**
 * Variant configuration type.
 */
export interface VariantConfig<V extends Record<string, Record<string, string>>> {
  /** Base classes always applied */
  base?: string
  /** Variant definitions */
  variants: V
  /** Default variant values */
  defaultVariants?: { [K in keyof V]?: keyof V[K] }
  /** Compound variants for specific combinations */
  compoundVariants?: Array<{
    [K in keyof V]?: keyof V[K]
  } & { className: string }>
}

/**
 * Create a variant-based style function.
 * Similar to CVA (class-variance-authority) or Stitches variants.
 *
 * @example
 * ```typescript
 * const button = variants({
 *   base: 'inline-flex items-center justify-center rounded-md font-medium',
 *   variants: {
 *     intent: {
 *       primary: 'bg-blue-500 text-white hover:bg-blue-600',
 *       secondary: 'bg-gray-100 text-gray-900 hover:bg-gray-200',
 *       ghost: 'hover:bg-gray-100'
 *     },
 *     size: {
 *       sm: 'h-8 px-3 text-sm',
 *       md: 'h-10 px-4 text-sm',
 *       lg: 'h-12 px-6 text-base'
 *     },
 *     disabled: {
 *       true: 'opacity-50 cursor-not-allowed'
 *     }
 *   },
 *   defaultVariants: {
 *     intent: 'primary',
 *     size: 'md'
 *   },
 *   compoundVariants: [
 *     {
 *       intent: 'primary',
 *       disabled: true,
 *       className: 'bg-blue-300'
 *     }
 *   ]
 * })
 *
 * // Usage
 * button() // Uses defaults
 * button({ intent: 'secondary' })
 * button({ intent: 'primary', size: 'lg', disabled: true })
 * ```
 */
export function variants<V extends Record<string, Record<string, string>>>(
  config: VariantConfig<V>
): (props?: { [K in keyof V]?: keyof V[K] } & { className?: string }) => string {
  return (props = {}) => {
    const classes: string[] = []

    // Add base classes
    if (config.base) {
      classes.push(config.base)
    }

    // Apply variants
    for (const [variantKey, variantOptions] of Object.entries(config.variants)) {
      const value = props[variantKey as keyof V] ??
                   config.defaultVariants?.[variantKey as keyof V]

      if (value !== undefined && variantOptions[value as string]) {
        classes.push(variantOptions[value as string])
      }
    }

    // Apply compound variants
    if (config.compoundVariants) {
      for (const compound of config.compoundVariants) {
        const { className, ...conditions } = compound
        let matches = true

        for (const [key, value] of Object.entries(conditions)) {
          const propValue = props[key as keyof V] ??
                           config.defaultVariants?.[key as keyof V]
          if (propValue !== value) {
            matches = false
            break
          }
        }

        if (matches && className) {
          classes.push(className)
        }
      }
    }

    // Add custom className
    if (props.className) {
      classes.push(props.className)
    }

    return classes.join(' ')
  }
}

// ============================================================================
// Style Objects
// ============================================================================

/**
 * Convert Tailwind classes to inline style object.
 * Useful for React Native or platforms that don't support CSS classes.
 *
 * @example
 * ```typescript
 * const styles = style('p-4 bg-blue-500 text-white rounded-lg')
 * // { padding: 16, backgroundColor: '#3b82f6', color: '#ffffff', borderRadius: 8 }
 * ```
 */
export function style(classes: string): Record<string, string | number> {
  const result: Record<string, string | number> = {}
  const classList = classes.split(/\s+/).filter(Boolean)

  for (const cls of classList) {
    const parsed = parseClass(cls)
    if (parsed) {
      Object.assign(result, parsed)
    }
  }

  return result
}

// ============================================================================
// Class Parsing
// ============================================================================

/**
 * Parse a single Tailwind class to style object.
 */
function parseClass(cls: string): Record<string, string | number> | null {
  // Spacing
  const spacingMatch = cls.match(/^([pm])([trblxy])?-(\d+(?:\.\d+)?|px)$/)
  if (spacingMatch) {
    const [, type, side, value] = spacingMatch
    const numValue = value === 'px' ? 1 : parseFloat(value) * 4
    const property = type === 'p' ? 'padding' : 'margin'

    if (!side) return { [property]: numValue }
    if (side === 'x') return { [`${property}Left`]: numValue, [`${property}Right`]: numValue }
    if (side === 'y') return { [`${property}Top`]: numValue, [`${property}Bottom`]: numValue }

    const sideMap: Record<string, string> = { t: 'Top', r: 'Right', b: 'Bottom', l: 'Left' }
    return { [`${property}${sideMap[side]}`]: numValue }
  }

  // Width/Height
  const sizeMatch = cls.match(/^(w|h|min-w|max-w|min-h|max-h)-(\d+|full|screen|auto)$/)
  if (sizeMatch) {
    const [, prop, value] = sizeMatch
    const propMap: Record<string, string> = {
      w: 'width', h: 'height',
      'min-w': 'minWidth', 'max-w': 'maxWidth',
      'min-h': 'minHeight', 'max-h': 'maxHeight'
    }
    const valMap: Record<string, string | number> = {
      full: '100%', screen: '100vh', auto: 'auto'
    }
    const numValue = valMap[value] ?? parseFloat(value) * 4
    return { [propMap[prop]]: numValue }
  }

  // Flex
  if (cls === 'flex') return { display: 'flex' }
  if (cls === 'flex-1') return { flex: 1 }
  if (cls === 'flex-row') return { flexDirection: 'row' }
  if (cls === 'flex-col') return { flexDirection: 'column' }
  if (cls === 'flex-wrap') return { flexWrap: 'wrap' }
  if (cls === 'items-center') return { alignItems: 'center' }
  if (cls === 'items-start') return { alignItems: 'flex-start' }
  if (cls === 'items-end') return { alignItems: 'flex-end' }
  if (cls === 'justify-center') return { justifyContent: 'center' }
  if (cls === 'justify-start') return { justifyContent: 'flex-start' }
  if (cls === 'justify-end') return { justifyContent: 'flex-end' }
  if (cls === 'justify-between') return { justifyContent: 'space-between' }
  if (cls === 'justify-around') return { justifyContent: 'space-around' }

  // Gap
  const gapMatch = cls.match(/^gap-(\d+(?:\.\d+)?)$/)
  if (gapMatch) return { gap: parseFloat(gapMatch[1]) * 4 }

  // Border radius
  const roundedMap: Record<string, number | string> = {
    'rounded-none': 0,
    'rounded-sm': 2,
    'rounded': 4,
    'rounded-md': 6,
    'rounded-lg': 8,
    'rounded-xl': 12,
    'rounded-2xl': 16,
    'rounded-3xl': 24,
    'rounded-full': 9999
  }
  if (roundedMap[cls] !== undefined) return { borderRadius: roundedMap[cls] }

  // Font size
  const fontSizeMap: Record<string, number> = {
    'text-xs': 12, 'text-sm': 14, 'text-base': 16, 'text-lg': 18,
    'text-xl': 20, 'text-2xl': 24, 'text-3xl': 30, 'text-4xl': 36
  }
  if (fontSizeMap[cls]) return { fontSize: fontSizeMap[cls] }

  // Font weight
  const fontWeightMap: Record<string, string | number> = {
    'font-thin': '100', 'font-extralight': '200', 'font-light': '300',
    'font-normal': '400', 'font-medium': '500', 'font-semibold': '600',
    'font-bold': '700', 'font-extrabold': '800', 'font-black': '900'
  }
  if (fontWeightMap[cls]) return { fontWeight: fontWeightMap[cls] }

  // Text align
  if (cls === 'text-left') return { textAlign: 'left' }
  if (cls === 'text-center') return { textAlign: 'center' }
  if (cls === 'text-right') return { textAlign: 'right' }

  // Colors (simplified - full implementation would have all Tailwind colors)
  const colorMatch = cls.match(/^(bg|text|border)-(\w+)-(\d{2,3})$/)
  if (colorMatch) {
    const [, property, color, shade] = colorMatch
    const colorValue = getColor(color, parseInt(shade))
    if (colorValue) {
      const propMap: Record<string, string> = {
        bg: 'backgroundColor',
        text: 'color',
        border: 'borderColor'
      }
      return { [propMap[property]]: colorValue }
    }
  }

  // Simple colors
  if (cls === 'bg-white') return { backgroundColor: '#ffffff' }
  if (cls === 'bg-black') return { backgroundColor: '#000000' }
  if (cls === 'bg-transparent') return { backgroundColor: 'transparent' }
  if (cls === 'text-white') return { color: '#ffffff' }
  if (cls === 'text-black') return { color: '#000000' }

  // Opacity
  const opacityMatch = cls.match(/^opacity-(\d+)$/)
  if (opacityMatch) return { opacity: parseInt(opacityMatch[1]) / 100 }

  // Position
  if (cls === 'relative') return { position: 'relative' }
  if (cls === 'absolute') return { position: 'absolute' }

  // Display
  if (cls === 'hidden') return { display: 'none' }
  if (cls === 'block') return { display: 'block' }
  if (cls === 'inline') return { display: 'inline' }

  // Overflow
  if (cls === 'overflow-hidden') return { overflow: 'hidden' }
  if (cls === 'overflow-scroll') return { overflow: 'scroll' }
  if (cls === 'overflow-auto') return { overflow: 'auto' }

  return null
}

/**
 * Get color value from Tailwind color palette.
 */
function getColor(color: string, shade: number): string | null {
  const colors: Record<string, Record<number, string>> = {
    slate: { 50: '#f8fafc', 100: '#f1f5f9', 200: '#e2e8f0', 300: '#cbd5e1', 400: '#94a3b8', 500: '#64748b', 600: '#475569', 700: '#334155', 800: '#1e293b', 900: '#0f172a' },
    gray: { 50: '#f9fafb', 100: '#f3f4f6', 200: '#e5e7eb', 300: '#d1d5db', 400: '#9ca3af', 500: '#6b7280', 600: '#4b5563', 700: '#374151', 800: '#1f2937', 900: '#111827' },
    red: { 50: '#fef2f2', 100: '#fee2e2', 200: '#fecaca', 300: '#fca5a5', 400: '#f87171', 500: '#ef4444', 600: '#dc2626', 700: '#b91c1c', 800: '#991b1b', 900: '#7f1d1d' },
    orange: { 50: '#fff7ed', 100: '#ffedd5', 200: '#fed7aa', 300: '#fdba74', 400: '#fb923c', 500: '#f97316', 600: '#ea580c', 700: '#c2410c', 800: '#9a3412', 900: '#7c2d12' },
    yellow: { 50: '#fefce8', 100: '#fef9c3', 200: '#fef08a', 300: '#fde047', 400: '#facc15', 500: '#eab308', 600: '#ca8a04', 700: '#a16207', 800: '#854d0e', 900: '#713f12' },
    green: { 50: '#f0fdf4', 100: '#dcfce7', 200: '#bbf7d0', 300: '#86efac', 400: '#4ade80', 500: '#22c55e', 600: '#16a34a', 700: '#15803d', 800: '#166534', 900: '#14532d' },
    blue: { 50: '#eff6ff', 100: '#dbeafe', 200: '#bfdbfe', 300: '#93c5fd', 400: '#60a5fa', 500: '#3b82f6', 600: '#2563eb', 700: '#1d4ed8', 800: '#1e40af', 900: '#1e3a8a' },
    indigo: { 50: '#eef2ff', 100: '#e0e7ff', 200: '#c7d2fe', 300: '#a5b4fc', 400: '#818cf8', 500: '#6366f1', 600: '#4f46e5', 700: '#4338ca', 800: '#3730a3', 900: '#312e81' },
    purple: { 50: '#faf5ff', 100: '#f3e8ff', 200: '#e9d5ff', 300: '#d8b4fe', 400: '#c084fc', 500: '#a855f7', 600: '#9333ea', 700: '#7e22ce', 800: '#6b21a8', 900: '#581c87' },
    pink: { 50: '#fdf2f8', 100: '#fce7f3', 200: '#fbcfe8', 300: '#f9a8d4', 400: '#f472b6', 500: '#ec4899', 600: '#db2777', 700: '#be185d', 800: '#9d174d', 900: '#831843' }
  }

  return colors[color]?.[shade] ?? null
}

// ============================================================================
// Headwind CLI Integration
// ============================================================================

/**
 * Headwind CLI configuration.
 */
export interface HeadwindConfig {
  /** Content paths to scan for classes */
  content: string[]
  /** Output CSS file path */
  output: string
  /** Enable minification */
  minify?: boolean
  /** Dark mode strategy */
  darkMode?: 'class' | 'media'
  /** Custom theme extensions */
  theme?: {
    extend?: {
      colors?: Record<string, string | Record<string, string>>
      spacing?: Record<string, string>
      fontSize?: Record<string, string>
      fontFamily?: Record<string, string[]>
      borderRadius?: Record<string, string>
    }
  }
  /** Enable JIT mode */
  jit?: boolean
}

/**
 * Generate Headwind configuration file.
 *
 * @example
 * const config = generateConfig({
 *   content: ['./src/components/*.tsx'],
 *   output: './dist/styles.css',
 *   minify: true,
 *   darkMode: 'class',
 *   theme: {
 *     extend: {
 *       colors: {
 *         brand: { 50: '#f0f9ff', 500: '#3b82f6', 900: '#1e3a8a' }
 *       }
 *     }
 *   }
 * })
 */
export function generateConfig(options: HeadwindConfig): string {
  return JSON.stringify({
    content: options.content,
    output: options.output,
    minify: options.minify ?? false,
    darkMode: options.darkMode ?? 'class',
    jit: options.jit ?? true,
    theme: options.theme ?? {}
  }, null, 2)
}

/**
 * Build CSS using Headwind CLI.
 * Requires zig-headwind to be installed.
 *
 * @example
 * await buildCSS({
 *   content: ['./src/components/*.tsx'],
 *   output: './public/styles.css',
 *   minify: process.env.NODE_ENV === 'production'
 * })
 */
export async function buildCSS(options: HeadwindConfig): Promise<void> {
  if (typeof window !== 'undefined') {
    console.warn('buildCSS can only be run in Node.js environment')
    return
  }

  const { exec } = await import('child_process')
  const { promisify } = await import('util')
  const execAsync = promisify(exec)

  const args = [
    'build',
    '--content', options.content.join(','),
    '--output', options.output
  ]

  if (options.minify) args.push('--minify')

  try {
    await execAsync(`headwind ${args.join(' ')}`)
    console.log(`CSS built successfully: ${options.output}`)
  } catch (error) {
    console.error('Failed to build CSS:', error)
    throw error
  }
}

// ============================================================================
// Exports
// ============================================================================

export default {
  tw,
  cx,
  variants,
  style,
  generateConfig,
  buildCSS
}
