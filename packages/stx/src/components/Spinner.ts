import { variants, cx } from '../styles'
import { h } from '../component'

export interface SpinnerProps {
  size?: 'sm' | 'md' | 'lg'
  class?: string
}

export const spinnerVariants = variants({
  base: 'animate-spin rounded-full border-2 border-current border-t-transparent',
  variants: {
    size: {
      sm: 'h-4 w-4',
      md: 'h-6 w-6',
      lg: 'h-8 w-8',
    },
  },
  defaultVariants: {
    size: 'md',
  },
})

export function Spinner(props: SpinnerProps = {}): HTMLElement {
  const className = cx(
    spinnerVariants({ size: props.size }),
    props.class,
  )

  return h('div', { class: className, role: 'status', 'aria-label': 'Loading' })
}
