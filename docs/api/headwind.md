# Headwind CSS API

Headwind provides Tailwind CSS-style utilities for styling Craft applications. It includes template literal support, class merging, and variant-based styling.

## Import

```typescript
import { tw, cx, variants, style } from 'ts-craft'
```

## tw - Template Literal Styling

Apply Tailwind-style classes using tagged template literals.

```typescript
// Basic usage
const className = tw`flex items-center justify-center p-4`

// Dynamic classes
const isActive = true
const buttonClass = tw`
  px-4 py-2 rounded-lg
  ${isActive ? 'bg-blue-500 text-white' : 'bg-gray-200 text-gray-700'}
`

// With interpolation
const size = 'lg'
const spacing = tw`p-${size === 'lg' ? '6' : '4'}`
```

## cx - Class Merging

Merge class names conditionally (similar to clsx/classnames).

```typescript
// Basic merging
const className = cx('base-class', 'another-class')
// Result: "base-class another-class"

// Conditional classes
const className = cx(
  'btn',
  isActive && 'btn-active',
  isDisabled && 'btn-disabled',
  size === 'large' ? 'btn-lg' : 'btn-sm'
)

// Array of classes
const className = cx([
  'flex',
  'items-center',
  condition && 'justify-between'
])

// Object syntax
const className = cx({
  'btn': true,
  'btn-primary': variant === 'primary',
  'btn-secondary': variant === 'secondary',
  'btn-disabled': isDisabled
})

// Combined
const className = cx(
  'base',
  ['array', 'of', 'classes'],
  { 'conditional': true },
  someVariable && 'dynamic'
)
```

## variants - Variant-Based Styling

Create component variants with type-safe props (similar to CVA - Class Variance Authority).

```typescript
// Define button variants
const button = variants({
  base: 'inline-flex items-center justify-center rounded-md font-medium transition-colors',

  variants: {
    variant: {
      primary: 'bg-blue-500 text-white hover:bg-blue-600',
      secondary: 'bg-gray-200 text-gray-900 hover:bg-gray-300',
      outline: 'border border-gray-300 bg-transparent hover:bg-gray-100',
      ghost: 'bg-transparent hover:bg-gray-100',
      destructive: 'bg-red-500 text-white hover:bg-red-600'
    },
    size: {
      sm: 'h-8 px-3 text-sm',
      md: 'h-10 px-4 text-base',
      lg: 'h-12 px-6 text-lg'
    },
    fullWidth: {
      true: 'w-full',
      false: ''
    }
  },

  compoundVariants: [
    {
      variant: 'primary',
      size: 'lg',
      className: 'shadow-lg'
    },
    {
      variant: ['primary', 'destructive'],
      className: 'font-bold'
    }
  ],

  defaultVariants: {
    variant: 'primary',
    size: 'md',
    fullWidth: false
  }
})

// Usage
button()
// Result: "inline-flex items-center ... bg-blue-500 text-white ... h-10 px-4 text-base"

button({ variant: 'secondary', size: 'lg' })
// Result: "inline-flex items-center ... bg-gray-200 text-gray-900 ... h-12 px-6 text-lg"

button({ variant: 'outline', fullWidth: true })
// Result: "inline-flex items-center ... border border-gray-300 ... h-10 px-4 ... w-full"
```

### Complex Example

```typescript
const card = variants({
  base: 'rounded-lg border transition-shadow',

  variants: {
    variant: {
      elevated: 'bg-white shadow-md hover:shadow-lg',
      outlined: 'bg-transparent border-gray-200',
      filled: 'bg-gray-100 border-transparent'
    },
    padding: {
      none: 'p-0',
      sm: 'p-3',
      md: 'p-4',
      lg: 'p-6'
    },
    interactive: {
      true: 'cursor-pointer',
      false: ''
    }
  },

  compoundVariants: [
    {
      variant: 'elevated',
      interactive: true,
      className: 'hover:shadow-xl active:shadow-md'
    }
  ],

  defaultVariants: {
    variant: 'elevated',
    padding: 'md',
    interactive: false
  }
})

// Usage
card()
card({ variant: 'outlined', padding: 'lg' })
card({ interactive: true })
```

## style - Convert to Inline Styles

Convert Tailwind classes to inline style objects for use with style attributes.

```typescript
// Convert classes to style object
const styles = style('flex items-center justify-center p-4 bg-blue-500 rounded-lg')
// Result: {
//   display: 'flex',
//   alignItems: 'center',
//   justifyContent: 'center',
//   padding: '1rem',
//   backgroundColor: '#3b82f6',
//   borderRadius: '0.5rem'
// }

// Use with element
element.style = style('text-lg font-bold text-gray-900')
```

## Supported Classes

### Layout

```
flex, inline-flex, block, inline-block, hidden
flex-row, flex-col, flex-row-reverse, flex-col-reverse
flex-wrap, flex-nowrap, flex-wrap-reverse
items-start, items-center, items-end, items-stretch, items-baseline
justify-start, justify-center, justify-end, justify-between, justify-around, justify-evenly
flex-1, flex-auto, flex-initial, flex-none
grow, grow-0, shrink, shrink-0
```

### Spacing

```
p-{0-12}, px-{0-12}, py-{0-12}, pt-{0-12}, pr-{0-12}, pb-{0-12}, pl-{0-12}
m-{0-12}, mx-{0-12}, my-{0-12}, mt-{0-12}, mr-{0-12}, mb-{0-12}, ml-{0-12}
m-auto, mx-auto, my-auto
gap-{0-12}, gap-x-{0-12}, gap-y-{0-12}
space-x-{0-12}, space-y-{0-12}
```

### Sizing

```
w-{0-96}, w-full, w-screen, w-auto, w-1/2, w-1/3, w-2/3, w-1/4, w-3/4
h-{0-96}, h-full, h-screen, h-auto
min-w-0, min-w-full, max-w-{xs-7xl}, max-w-full, max-w-none
min-h-0, min-h-full, min-h-screen, max-h-{0-96}, max-h-full, max-h-screen
```

### Typography

```
text-{xs-9xl}
font-{thin, extralight, light, normal, medium, semibold, bold, extrabold, black}
text-left, text-center, text-right, text-justify
uppercase, lowercase, capitalize, normal-case
truncate, line-clamp-{1-6}
leading-{none, tight, snug, normal, relaxed, loose}
tracking-{tighter, tight, normal, wide, wider, widest}
```

### Colors

```
text-{color}-{shade}
bg-{color}-{shade}
border-{color}-{shade}

Colors: slate, gray, zinc, neutral, stone, red, orange, amber, yellow, lime,
        green, emerald, teal, cyan, sky, blue, indigo, violet, purple, fuchsia,
        pink, rose, white, black, transparent

Shades: 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950
```

### Borders

```
border, border-{0-8}
border-t, border-r, border-b, border-l
rounded, rounded-{none, sm, md, lg, xl, 2xl, 3xl, full}
rounded-t-{size}, rounded-r-{size}, rounded-b-{size}, rounded-l-{size}
```

### Effects

```
shadow, shadow-{sm, md, lg, xl, 2xl, none}
opacity-{0, 25, 50, 75, 100}
```

### Positioning

```
relative, absolute, fixed, sticky
inset-{0-12}, inset-auto
top-{0-12}, right-{0-12}, bottom-{0-12}, left-{0-12}
z-{0, 10, 20, 30, 40, 50, auto}
```

### Overflow

```
overflow-{auto, hidden, visible, scroll}
overflow-x-{auto, hidden, visible, scroll}
overflow-y-{auto, hidden, visible, scroll}
```

### Transitions

```
transition, transition-{none, all, colors, opacity, shadow, transform}
duration-{75, 100, 150, 200, 300, 500, 700, 1000}
ease-{linear, in, out, in-out}
```

## Example Usage

```typescript
import { tw, cx, variants, style } from 'ts-craft'

// Navigation component
const nav = variants({
  base: 'flex items-center',
  variants: {
    direction: {
      horizontal: 'flex-row space-x-4',
      vertical: 'flex-col space-y-2'
    }
  },
  defaultVariants: {
    direction: 'horizontal'
  }
})

// Button with dynamic state
function renderButton(props: {
  variant: 'primary' | 'secondary'
  disabled?: boolean
  loading?: boolean
}) {
  const className = cx(
    button({ variant: props.variant }),
    props.disabled && 'opacity-50 cursor-not-allowed',
    props.loading && 'animate-pulse'
  )

  return `<button class="${className}">Click me</button>`
}

// Inline styles for dynamic elements
function createTooltip(text: string) {
  const tooltip = document.createElement('div')
  Object.assign(tooltip.style, style(`
    absolute z-50 px-2 py-1
    bg-gray-900 text-white text-sm
    rounded shadow-lg
  `))
  tooltip.textContent = text
  return tooltip
}
```
