/**
 * STX Styles — crosswind utility re-exports
 *
 * Re-exports the tw, cx, variants, and style utilities from the Craft SDK
 * so stx components have a single import source for crosswind styling.
 */

export type ClassValue =
  | string
  | number
  | boolean
  | null
  | undefined
  | ClassValue[]
  | Record<string, boolean | null | undefined>

export interface VariantConfig<V extends Record<string, Record<string, string>>> {
  base?: string
  variants: V
  defaultVariants?: { [K in keyof V]?: keyof V[K] }
  compoundVariants?: Array<{ [K in keyof V]?: keyof V[K] } & { className: string }>
}

/**
 * Tagged template for crosswind/Tailwind utility classes.
 */
export function tw(strings: TemplateStringsArray, ...values: unknown[]): string {
  let result = ''
  for (let i = 0; i < strings.length; i++) {
    result += strings[i]
    if (i < values.length) {
      result += String(values[i])
    }
  }
  return result.replace(/\s+/g, ' ').trim()
}

/**
 * Merge class names conditionally.
 */
export function cx(...inputs: ClassValue[]): string {
  const classes: string[] = []

  for (const input of inputs) {
    if (!input) continue
    if (typeof input === 'string' || typeof input === 'number') {
      classes.push(String(input))
    }
    else if (Array.isArray(input)) {
      const nested = cx(...input)
      if (nested) classes.push(nested)
    }
    else if (typeof input === 'object') {
      for (const [key, value] of Object.entries(input)) {
        if (value) classes.push(key)
      }
    }
  }

  return classes.join(' ')
}

/**
 * Create a variant-based class function (CVA-style).
 */
// eslint-disable-next-line pickier/no-unused-vars
export function variants<V extends Record<string, Record<string, string>>>(
  config: VariantConfig<V>,
): (props?: { [K in keyof V]?: keyof V[K] } & { className?: string }) => string {
  return (props = {}) => {
    const classes: string[] = []

    if (config.base) classes.push(config.base)

    for (const [variantKey, variantOptions] of Object.entries(config.variants)) {
      const value = props[variantKey as keyof V] ?? config.defaultVariants?.[variantKey as keyof V]
      if (value !== undefined && variantOptions[value as string]) {
        classes.push(variantOptions[value as string])
      }
    }

    if (config.compoundVariants) {
      for (const compound of config.compoundVariants) {
        const { className, ...conditions } = compound
        let matches = true

        for (const [key, value] of Object.entries(conditions)) {
          const propValue = props[key as keyof V] ?? config.defaultVariants?.[key as keyof V]
          if (propValue !== value) {
            matches = false
            break
          }
        }

        if (matches && className) classes.push(className)
      }
    }

    if (props.className) classes.push(props.className)

    return classes.join(' ')
  }
}

/**
 * Convert Tailwind classes to inline style object.
 */
export function style(classes: string): Record<string, string | number> {
  const result: Record<string, string | number> = {}
  const classList = classes.split(/\s+/).filter(Boolean)

  for (const cls of classList) {
    const parsed = parseClass(cls)
    if (parsed) Object.assign(result, parsed)
  }

  return result
}

function parseClass(cls: string): Record<string, string | number> | null {
  // Spacing
  const spacingMatch = cls.match(/^([pm])([trblxy])?-(\d+(?:\.\d+)?|px)$/)
  if (spacingMatch) {
    const [, type, side, value] = spacingMatch
    const numValue = value === 'px' ? 1 : Number.parseFloat(value) * 4
    const property = type === 'p' ? 'padding' : 'margin'

    if (!side) return { [property]: numValue }
    if (side === 'x') return { [`${property}Left`]: numValue, [`${property}Right`]: numValue }
    if (side === 'y') return { [`${property}Top`]: numValue, [`${property}Bottom`]: numValue }

    const sideMap: Record<string, string> = { t: 'Top', r: 'Right', b: 'Bottom', l: 'Left' }
    return { [`${property}${sideMap[side]}`]: numValue }
  }

  // Flex
  if (cls === 'flex') return { display: 'flex' }
  if (cls === 'flex-1') return { flex: 1 }
  if (cls === 'flex-row') return { flexDirection: 'row' }
  if (cls === 'flex-col') return { flexDirection: 'column' }
  if (cls === 'items-center') return { alignItems: 'center' }
  if (cls === 'items-start') return { alignItems: 'flex-start' }
  if (cls === 'justify-center') return { justifyContent: 'center' }
  if (cls === 'justify-between') return { justifyContent: 'space-between' }

  // Gap
  const gapMatch = cls.match(/^gap-(\d+(?:\.\d+)?)$/)
  if (gapMatch) return { gap: Number.parseFloat(gapMatch[1]) * 4 }

  // Border radius
  const roundedMap: Record<string, number> = {
    'rounded-none': 0, 'rounded-sm': 2, 'rounded': 4, 'rounded-md': 6,
    'rounded-lg': 8, 'rounded-xl': 12, 'rounded-2xl': 16, 'rounded-full': 9999,
  }
  if (roundedMap[cls] !== undefined) return { borderRadius: roundedMap[cls] }

  // Font size
  const fontSizeMap: Record<string, number> = {
    'text-xs': 12, 'text-sm': 14, 'text-base': 16, 'text-lg': 18,
    'text-xl': 20, 'text-2xl': 24, 'text-3xl': 30, 'text-4xl': 36,
  }
  if (fontSizeMap[cls]) return { fontSize: fontSizeMap[cls] }

  // Font weight
  const fontWeightMap: Record<string, string> = {
    'font-normal': '400', 'font-medium': '500', 'font-semibold': '600', 'font-bold': '700',
  }
  if (fontWeightMap[cls]) return { fontWeight: fontWeightMap[cls] }

  // Simple
  if (cls === 'text-center') return { textAlign: 'center' }
  if (cls === 'text-left') return { textAlign: 'left' }
  if (cls === 'text-right') return { textAlign: 'right' }
  if (cls === 'hidden') return { display: 'none' }
  if (cls === 'relative') return { position: 'relative' }
  if (cls === 'absolute') return { position: 'absolute' }
  if (cls === 'overflow-hidden') return { overflow: 'hidden' }

  return null
}
